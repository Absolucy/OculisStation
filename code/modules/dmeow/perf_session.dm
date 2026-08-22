/// lives in a global, not on the panel datum, so closing the window doesn't
/// strand the flip timer.
GLOBAL_DATUM(dmeow_perf_session, /datum/dmeow_perf_session)

/**
 * flips the JIT on and off on a fixed schedule so both arms see the same
 * workload, and marks the report at every flip so the JSON carries its schedule.
 *
 * the old shape (interpreter for 90s, then the JIT for the rest of the round)
 * never overlapped its arms in time, so "interpreter is 2x slower" was really
 * "the first 90s of a round are 2x busier". four MC-driven procs agreeing to
 * three digits is what gave it away.
 */
/datum/dmeow_perf_session
	/// interpreter calls before a proc gets compiled.
	var/threshold
	/// per-proc call modulus for the sampling profiler.
	var/sample_rate
	/// compile-and-settle before measuring. everything sampled during it is binned.
	var/warmup_seconds
	/// seconds each arm gets.
	var/window_seconds
	/// on/off pairs to run.
	var/cycles

	/// "idle" | "warmup" | "interleave" | "done". the tgui panel compares against
	/// these strings too, so they're not free to rename.
	var/phase = "idle"
	/// which A/B window we're in. even = JIT on, odd = JIT off - the panel mirrors
	/// that to label the arm.
	var/window_index = 0
	var/started_at = 0
	var/phase_ends_at = 0
	var/timer_id
	/// optional synthetic workload driven alongside the run.
	var/datum/dmeow_load/load
	/// filled in by finish(); the panel reads this instead of re-collecting.
	var/list/summary
	/// one row per SSair fire during the interleave, written out by finish().
	var/list/turf_rows = list()
	/// rows refused once turf_rows hit the cap. non-zero means the rows no longer
	/// sum to the round's turf count, so the cross-check against the perf report
	/// is off the table.
	var/turf_rows_dropped = 0
	/// fired once, at the end of finish(). the unattended runner uses this to
	/// shut the server down; nothing sets it on a panel-driven run.
	var/datum/callback/on_finish

/datum/dmeow_perf_session/New(threshold, sample_rate, warmup_seconds, window_seconds, cycles, datum/dmeow_load/load = null)
	. = ..()
	src.threshold = threshold
	src.sample_rate = sample_rate
	src.warmup_seconds = warmup_seconds
	src.window_seconds = window_seconds
	src.cycles = cycles
	src.load = load

/datum/dmeow_perf_session/Destroy()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null
	if(load)
		load.stop()
		QDEL_NULL(load)
	return ..()

/datum/dmeow_perf_session/proc/set_phase_timer(seconds, datum/callback/next)
	if(timer_id)
		deltimer(timer_id)
	phase_ends_at = world.time + seconds SECONDS
	timer_id = addtimer(next, seconds SECONDS, TIMER_STOPPABLE)

/// profiling has to be up before counting, or the hot procs promote before the
/// profiler exists and warmup measures nothing.
/datum/dmeow_perf_session/proc/begin()
	dmeow_perf_reset()
	dmeow_perf_start(sample_rate)
	dmeow_sample_rate = sample_rate
	started_at = world.time

	dmeow_set_hooks(TRUE)
	dmeow_enable_counting(threshold)
	dmeow_counting_threshold = threshold
	phase = "warmup"
	if(load)
		load.start()
	set_phase_timer(warmup_seconds, CALLBACK(src, PROC_REF(freeze)))

/// end of warmup. freeze the compiled set, then bin everything so far -
/// roundstart, mapload, lighting init, every LLVM compile stall.
///
/// the disable_counting isn't tidiness. turning native dispatch off doesn't turn
/// the auto-tier observer off, so compiled procs drop to the interpreter, get
/// spotted, and get recompiled inside every single interpreter window.
/datum/dmeow_perf_session/proc/freeze()
	timer_id = null
	dmeow_disable_counting()
	dmeow_counting_threshold = 0
	dmeow_perf_reset()
	window_index = 0
	phase = "interleave"
	dmeow_set_hooks(TRUE)
	mark_window(TRUE)
	set_phase_timer(window_seconds, CALLBACK(src, PROC_REF(flip)))

/datum/dmeow_perf_session/proc/flip()
	timer_id = null
	window_index++
	if(window_index >= cycles * 2)
		finish()
		return
	var/hooks_on = !dmeow_hooks_enabled
	dmeow_set_hooks(hooks_on)
	mark_window(hooks_on)
	set_phase_timer(window_seconds, CALLBACK(src, PROC_REF(flip)))

/// the "on"/"off" prefix is a contract - dmeow_window_arms() splits it off at
/// the ":" and dmeow_window_pairs() matches those exact strings. reword it and
/// every row's pair count quietly goes to zero.
///
/// SSair.times_fired tags along because SSair is MC_TICK_CHECK bounded and
/// SS_BACKGROUND, so "burn for 15 seconds" does a wildly variable amount of
/// work. a starved window should be visible, not averaged in.
/datum/dmeow_perf_session/proc/mark_window(hooks_on)
	dmeow_perf_mark("[hooks_on ? "on" : "off"]:[SSair.times_fired]")

/**
 * one row per SSair fire that reached the active-turf phase, called from
 * air/fire() while the turf phase's timing is still in hand.
 *
 * gated on the interleave rather than on window_index, because window_index is
 * 0 during warmup as well as during the first interleave window. the profiler
 * gets away without that check only because freeze() resets it; a DM list has
 * no equivalent.
 *
 * riding the window mark label instead is not an option - dmeow_perf_mark()
 * *opens* a window, so a mark per fire would leave hundreds of windows and
 * nothing for dmeow_window_arms() and dmeow_window_pairs() to read.
 */
/datum/dmeow_perf_session/proc/record_turf_row(entry_part, pass_fresh, turf_delta)
	if(phase != "interleave")
		return
	if(length(turf_rows) >= DMEOW_TURF_ROW_LIMIT)
		turf_rows_dropped++
		return
	UNTYPED_LIST_ADD(turf_rows, list(
		"window" = window_index,
		"run" = SSair.fire_runs,
		"times_fired" = SSair.times_fired,
		"entry_part" = entry_part,
		"fresh" = pass_fresh,
		"turfs" = SSair.turfs_processed_last,
		"ticks" = turf_delta,
		// what's left in the queue, not state != SS_RUNNING. MC_TICK_CHECK sits
		// after the last turf is processed, so a pass that drained the queue can
		// still pause on it and would read as a bail.
		"remaining" = length(SSair.currentrun),
		"queue_at_start" = SSair.queue_at_pass_start,
		"hotspots" = length(SSair.hotspots),
		"excited_groups" = length(SSair.excited_groups),
		"tick_allocation" = SSair.tick_allocation_last,
		"reseeds" = load ? load.reseeds : 0,
		"reseed_ticks" = load ? load.reseed_ticks : 0,
		"room_hotspots" = load ? load.interior_hotspots : 0,
	))

/datum/dmeow_perf_session/proc/finish()
	timer_id = null
	phase = "done"
	// stop sampling before writing, or the last window keeps hoovering up
	// whatever the server does next and a second collect comes out dirtier.
	dmeow_perf_stop()
	dmeow_sample_rate = 0
	// put the server back how it normally runs, whichever arm we landed on.
	dmeow_set_hooks(TRUE)
	// describe() before stop(), or the room has already handed its reservation
	// back and the only thing left to say about it is "idle".
	var/load_description = load?.describe()
	if(load)
		load.stop()
	summary = dmeow_perf_collect()
	var/announcement = "A/B run finished but the profiler returned no report"
	if(summary)
		var/turf_file = dmeow_turf_rows_write(src, summary["file"], load_description)
		announcement = "A/B run finished, wrote [summary["file"]] and [turf_file] ([summary["compared"]] procs comparable)"
	message_admins("dmeow: [announcement]")
	world.log << "dmeow: [announcement]"
	on_finish?.Invoke()

/datum/dmeow_perf_session/proc/seconds_left()
	if(!phase_ends_at || phase == "done")
		return 0
	return max(0, round((phase_ends_at - world.time) / 10))

/proc/dmeow_perf_session_stop()
	if(!GLOB.dmeow_perf_session)
		return
	dmeow_perf_stop()
	dmeow_disable_counting()
	dmeow_sample_rate = 0
	dmeow_counting_threshold = 0
	QDEL_NULL(GLOB.dmeow_perf_session)
