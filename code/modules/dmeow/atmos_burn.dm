/// a synthetic workload an A/B run can point at, so both arms measure the same
/// thing instead of whatever the round was up to.
/datum/dmeow_load
	/// shown on the panel.
	var/name = "load"
	/// how many times the load has re-seeded so far.
	var/reseeds = 0
	/// what the last re-seed cost, in TICK_USAGE_REAL units. re-seeding runs on a
	/// timer outside SSair, and several procs on that path do compile, so it's an
	/// arm-asymmetric stall landing inside a measured window. worth seeing.
	var/reseed_ticks = 0
	/// most turfs of this load seen holding a hotspot at once, sampled at each
	/// re-seed. SSair.hotspots counts the whole station, so it can't answer "did
	/// *this* room catch fire" - and for the gradient room that question is the
	/// whole gate.
	var/interior_hotspots = 0

/datum/dmeow_load/proc/start()
	return

/datum/dmeow_load/proc/stop()
	return

/// one line of status for the panel.
/datum/dmeow_load/proc/describe()
	return name

/**
 * a sealed reserved room whose air gets re-seeded on a fixed period. holds
 * everything both workloads share; what the air is made of is the subtype's job.
 *
 * the re-seed period has to divide the A/B window exactly, or a room that runs
 * itself down puts back the time-varying workload the interleave exists to kill.
 */
/datum/dmeow_load/atmos_room
	/// interior edge length in turfs. the reservation is two wider, for walls.
	var/size = DMEOW_BURN_ROOM_SIZE
	var/reseed_period = DMEOW_BURN_RESEED_PERIOD
	var/datum/turf_reservation/reservation
	var/list/turf/open/interior = list()
	var/reseed_timer
	var/failure

/datum/dmeow_load/atmos_room/New(room_size)
	. = ..()
	if(room_size)
		size = room_size

/datum/dmeow_load/atmos_room/Destroy()
	stop()
	return ..()

/datum/dmeow_load/atmos_room/describe()
	if(failure)
		return "[name]: FAILED - [failure]"
	if(!reservation)
		return "[name]: idle"
	return "[name]: [length(interior)] turfs, [reseeds] re-seeds, every [reseed_period]s"

/datum/dmeow_load/atmos_room/start()
	if(reservation)
		return TRUE
	failure = null
	// turf_type_override makes the whole block plating up front, so building the
	// room is just a ring of ChangeTurf calls instead of one per cell.
	reservation = SSmapping.request_turf_block_reservation(
		size + 2,
		size + 2,
		turf_type_override = /turf/open/floor/plating,
	)
	if(!reservation)
		failure = "no reserved space available"
		world.log << "dmeow: [name] failed - [failure]"
		return FALSE

	build_room()
	seed()
	reseed_timer = addtimer(CALLBACK(src, PROC_REF(seed)), reseed_period SECONDS, TIMER_STOPPABLE | TIMER_LOOP)
	world.log << "dmeow: [name] up, [length(interior)] turfs, re-seeding every [reseed_period]s"
	return TRUE

/datum/dmeow_load/atmos_room/proc/build_room()
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	var/turf/top_right = reservation.top_right_turfs[1]
	for(var/turf/candidate as anything in block(bottom_left, top_right))
		if(candidate.x == bottom_left.x || candidate.x == top_right.x || candidate.y == bottom_left.y || candidate.y == top_right.y)
			candidate.ChangeTurf(/turf/closed/indestructible)
			continue
		interior += candidate

/// fills every interior turf and puts it back on SSair's active list. subtypes
/// decide what goes in; this one exists so start() has something to call.
/datum/dmeow_load/atmos_room/proc/seed()
	return

/datum/dmeow_load/atmos_room/stop()
	if(reseed_timer)
		deltimer(reseed_timer)
		reseed_timer = null
	for(var/turf/open/cell as anything in interior)
		if(cell.active_hotspot)
			qdel(cell.active_hotspot)
		SSair.remove_from_active(cell)
	interior.Cut()
	// Release() disconnects every turf from atmos and kills the excited group
	// before handing the block back. that's the bit a hand-rolled teardown always
	// forgets about.
	QDEL_NULL(reservation)
	return TRUE

/**
 * the room stuffed with plasma and oxygen and set on fire. copied off
 * _maps/templates/holodeck_burntest.dmm and seeded with BURNMIX_ATMOS, which
 * upstream already uses for exactly this.
 *
 * that mix sits at 370K, ~3K under FIRE_MINIMUM_TEMPERATURE_TO_EXIST, so it
 * needs lighting rather than catching on its own. deliberate upstream, kept here.
 */
/datum/dmeow_load/atmos_room/burn
	name = "atmos burn room"
	var/list/turf/open/ignition_points = list()

/// a grid of ignition points rather than the four interior corners, so a bigger
/// room burns the same way a small one does. four corners never reach the middle
/// of a 40x40 room inside one re-seed, and then the per-turf work stops looking
/// like the rounds already on record.
///
/// at size 10 this lands 4 points, same count as the corner list it replaces -
/// but inset, so re-baseline 10x10 before comparing it against a bigger room.
/datum/dmeow_load/atmos_room/burn/build_room()
	. = ..()
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	var/first = round(DMEOW_IGNITION_SPACING / 2)
	for(var/x_offset = first, x_offset < size, x_offset += DMEOW_IGNITION_SPACING)
		for(var/y_offset = first, y_offset < size, y_offset += DMEOW_IGNITION_SPACING)
			var/turf/open/point = locate(bottom_left.x + 1 + x_offset, bottom_left.y + 1 + y_offset, bottom_left.z)
			if(point)
				ignition_points += point

/// copy_from and not merge, so every re-seed lands on exactly the same mixture
/// instead of watering down whatever burned off since the last one.
/datum/dmeow_load/atmos_room/burn/seed()
	if(!reservation)
		return
	var/timer = TICK_USAGE_REAL
	var/datum/gas_mixture/burn_mix = SSair.parse_gas_string(BURNMIX_ATMOS, /datum/gas_mixture/turf)
	var/lit = 0
	for(var/turf/open/cell as anything in interior)
		if(cell.active_hotspot)
			lit++
		cell.air.copy_from(burn_mix)
		cell.archive()
		SSair.add_to_active(cell)
	interior_hotspots = max(interior_hotspots, lit)
	// BURNMIX_ATMOS won't catch on its own, so light it. volume 100 turns into
	// one CELL_VOLUME of hotspot, same size a normal igniter makes.
	for(var/turf/open/point as anything in ignition_points)
		point.hotspot_expose(1000, 100, TRUE)
	reseeds++
	reseed_ticks = TICK_USAGE_REAL - timer

/datum/dmeow_load/atmos_room/burn/stop()
	. = ..()
	ignition_points.Cut()

/**
 * the same room with no fire in it: hot dense nitrogen in one half, cold thin
 * nitrogen in the other. gas movement, pressure equalisation and heat sharing
 * all run hard, and nothing reacts - every reaction in reactions.dm needs at
 * least one gas that isn't nitrogen, so this mix cannot combust.
 *
 * that is the point. with no fire there is no hotspot count to diverge between
 * the arms, so both arms provably process the same turfs and the only thing
 * left to compare is how long it took.
 *
 * half and half rather than a checkerboard: one front keeps moving gas for
 * longer, where a checkerboard has the steepest gradient everywhere and
 * flattens out fastest.
 */
/datum/dmeow_load/atmos_room/gradient
	name = "atmos gradient room"

/datum/dmeow_load/atmos_room/gradient/seed()
	if(!reservation)
		return
	var/timer = TICK_USAGE_REAL
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	var/turf/top_right = reservation.top_right_turfs[1]
	var/midpoint = (bottom_left.x + top_right.x) / 2
	var/datum/gas_mixture/hot_mix = SSair.parse_gas_string(DMEOW_GRADIENT_HOT, /datum/gas_mixture/turf)
	var/datum/gas_mixture/cold_mix = SSair.parse_gas_string(DMEOW_GRADIENT_COLD, /datum/gas_mixture/turf)
	var/lit = 0
	for(var/turf/open/cell as anything in interior)
		if(cell.active_hotspot)
			lit++
		cell.air.copy_from(cell.x < midpoint ? hot_mix : cold_mix)
		cell.archive()
		SSair.add_to_active(cell)
	// a running max, because a hotspot that flared and died between two re-seeds
	// still means the mix can burn and the room has lost its reason to exist.
	interior_hotspots = max(interior_hotspots, lit)
	reseeds++
	reseed_ticks = TICK_USAGE_REAL - timer

/// world param value -> load type. an unknown name returns null so the caller
/// can abort - falling back to the burn room would silently measure the wrong
/// workload for a whole round.
/proc/dmeow_load_type(load_name)
	switch(load_name)
		if("burn")
			return /datum/dmeow_load/atmos_room/burn
		if("gradient")
			return /datum/dmeow_load/atmos_room/gradient
	return null

/// standalone burn, for poking at the load without driving a whole A/B run.
GLOBAL_DATUM(dmeow_standalone_burn, /datum/dmeow_load/atmos_room/burn)

/// on/off for the standalone burn room, returning a status line. the verb and
/// the panel button share it so the "a run already owns one" guard can't go
/// missing from one of them - two burn rooms at once wreck the measurement.
/proc/dmeow_toggle_standalone_burn()
	if(GLOB.dmeow_perf_session?.load)
		return "the running profiling session owns the burn room"
	if(GLOB.dmeow_standalone_burn)
		QDEL_NULL(GLOB.dmeow_standalone_burn)
		return "burn room torn down"

	GLOB.dmeow_standalone_burn = new /datum/dmeow_load/atmos_room/burn()
	if(GLOB.dmeow_standalone_burn.start())
		return GLOB.dmeow_standalone_burn.describe()
	// describe() before the qdel, it's the only place the reason lives.
	var/failure = GLOB.dmeow_standalone_burn.describe()
	QDEL_NULL(GLOB.dmeow_standalone_burn)
	return failure

ADMIN_VERB(dmeow_burn_room, R_DEBUG, "dmeow burn room", "Toggle a sealed plasma fire for JIT load testing.", ADMIN_CATEGORY_DEBUG)
	message_admins("dmeow: [dmeow_toggle_standalone_burn()]")
