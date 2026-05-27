/* This comment bypasses grep checks */ /var/__refscanner
#define REFSCANNER_DLL (world.system_type == MS_WINDOWS ? "datum_refscanner.dll" : (__refscanner ||= __detect_auxtools("datum_refscanner")))

GLOBAL_VAR_INIT(datum_refscanner_ready, FALSE)

/// Attempt to initialize datum_refscanner.dll. Returns TRUE on success.
/// Safe to call multiple times; init is only attempted once.
/proc/refscanner_ensure_ready()
	if(GLOB.datum_refscanner_ready)
		return TRUE
	try
		var/err = call_ext(REFSCANNER_DLL, "refscanner_init")()
		if(err)
			stack_trace("datum_refscanner: init error: [err]")
			return FALSE
	catch(var/exception/e)
		stack_trace("datum_refscanner: failed to load DLL: [e]")
		return FALSE
	GLOB.datum_refscanner_ready = TRUE
	return TRUE

/// Drain the findings buffer and return a list of finding strings, or null if empty.
/// Each entry is "holder_kind=<datum|atom_a|atom_b|global_var> holder_id=N var_name=foo".
/proc/refscanner_drain()
	if(!GLOB.datum_refscanner_ready)
		return null
	var/raw = call_ext(REFSCANNER_DLL, "refscanner_get_findings")()
	if(!raw)
		return null
	var/list/lines = splittext(raw, "\n")
	while(length(lines) && lines[length(lines)] == "")
		lines.len--
	return length(lines) ? lines : null

/// Drain native debug output from the scanner.
/proc/refscanner_debug_drain()
	if(!GLOB.datum_refscanner_ready)
		return null
	var/raw = call_ext(REFSCANNER_DLL, "refscanner_get_debug")()
	if(!raw)
		return null
	var/list/lines = splittext(raw, "\n")
	while(length(lines) && lines[length(lines)] == "")
		lines.len--
	return length(lines) ? lines : null

/proc/refscanner_findings_json()
	if(!GLOB.datum_refscanner_ready)
		return null
	return call_ext(REFSCANNER_DLL, "refscanner_get_findings_json")()

/// Arm one native scan. The DLL auto-disarms after the next erasure hook fires.
/proc/refscanner_arm_once()
	if(!GLOB.datum_refscanner_ready)
		return
	call_ext(REFSCANNER_DLL, "refscanner_arm")()

/proc/refscanner_clear()
	if(!GLOB.datum_refscanner_ready)
		return
	call_ext(REFSCANNER_DLL, "refscanner_clear")()

// Print a human-readable findings report to world.log.
// Returns the number of entries printed, or 0 if no findings.
//
// Example output:
//   === refscanner: 3 finding(s) ===
//   [finding]    datum #42 (/datum/reagents).reagent_list
//   [list]       list #88 [index 2] (len=5, refs=3)
//   [list_owner] datum #42 (/datum/reagents).reagent_list -> list #88
//   ===
/proc/refscanner_report()
	. = list()
	var/json = refscanner_findings_json()
	if(!json)
		return
	var/list/findings = json_decode(json)
	for(var/list/entry in findings)
		. += _refscanner_fmt_entry(entry)

/proc/_refscanner_fmt_entry(list/f)
	var/kind = f["holder_kind"]
	switch(kind)
		if("list")
			// The list itself holds the leaked reference directly.
			return "\[list\]       list #[f["list_id"]] \[index [f["index"]]\] (len=[f["length"]], refs=[f["ref_count"]])"

		if("list_owner")
			// A var or list slot holds a list that contains the leaked reference.
			var/owner_kind = f["owner_kind"]
			var/osrc
			if(owner_kind == "list")
				osrc = "list #[f["holder_id"]] \[index [f["index"]]\]"
			else
				osrc = _refscanner_fmt_holder(owner_kind, f["holder_id"], f["typepath"], f["var_name"])
			return "\[list_owner\] [osrc] -> list #[f["list_id"]]"

		else
			// A datum/obj/mob/global var holds the leaked reference directly.
			return "\[finding\]    [_refscanner_fmt_holder(kind, f["holder_id"], f["typepath"], f["var_name"])]"

// Format "datum #42 (/datum/foo).bar" style descriptions.
/proc/_refscanner_fmt_holder(kind, holder_id, typepath, var_name)
	var/label
	switch(kind)
		if("datum")      label = "datum #[holder_id]"
		if("atom_a")     label = "obj #[holder_id]"
		if("atom_b")     label = "mob #[holder_id]"
		if("global_var") label = "global #[holder_id]"
		else             label = "[kind] #[holder_id]"
	if(typepath)
		label += " ([typepath])"
	if(var_name)
		label += ".[var_name]"
	return label

#ifdef TESTING
// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// A holder datum whose var keeps a reference to another datum after Destroy().
/// Used by the test verb to produce a detectable reference leak.
/datum/refscanner_test_holder
	var/datum/held_ref
	var/list/list_that_holds_ref

/datum/refscanner_test_holder/Destroy(force)
	// Deliberately do NOT null held_ref — this simulates the leak we want to detect.
	return ..()

// ---------------------------------------------------------------------------
// Admin verb
// ---------------------------------------------------------------------------

GLOBAL_VAR(meow_a)
GLOBAL_VAR(meow_b)

GLOBAL_LIST(meow_c)

ADMIN_VERB(refscanner_run_test, R_DEBUG, "Test Native RefScanner", \
	"Creates datum/global/list references, forces a hard-delete, then shows native pre/post-erasure scanner output.", \
	ADMIN_CATEGORY_DEBUG)

	if(!refscanner_ensure_ready())
		to_chat(user, span_warning("datum_refscanner.dll could not be loaded — check the game log for details."))
		return

	// holder.held_ref and GLOB.meow_b keep victim alive before erasure. On current
	// 516.1669 these references are erased by BYOND's own erasure() pass, so the
	// native hook returns pre-erasure/reftracker-style findings and uses debug
	// output to show what survives the post-erasure scan.
	var/datum/refscanner_test_holder/holder = new()
	var/datum/victim = new()
	holder.held_ref = victim
	holder.list_that_holds_ref = list(victim)
	GLOB.meow_a = holder
	GLOB.meow_b = victim
	// Also hold a reference via a list, to exercise the list scanner path.
	var/list/holder_list = list(victim)

	GLOB.meow_c = list(victim)

	// refscanner_arm_once()
	// del(victim)

	SSgarbage.HardDelete(victim)

	// var/list/findings = refscanner_drain()
	/* var/list/debug_lines = refscanner_debug_drain()
	var/findings = refscanner_findings_json() */

	victim = null
	GLOB.meow_a = null
	GLOB.meow_b = null
	GLOB.meow_c = null
	holder_list = null
	/* if(!findings)
		to_chat(user, span_notice("Native RefScanner returned no pre-erasure references. Check the debug trace for hook/scanner behavior."))
		if(debug_lines)
			to_chat(user, span_boldnotice("Native RefScanner debug:"))
			fdel("ref_debug.txt")
			var/debug_file = file("ref_debug.txt")
			debug_file << "Native RefScanner debug:"
			for(var/line in debug_lines)
				to_chat(user, span_notice("  [line]"))
				debug_file << "  [line]"
		else
			to_chat(user, span_warning("Native RefScanner debug buffer was empty."))
		qdel(holder)
		return

	if(debug_lines)
		to_chat(user, span_boldnotice("Native RefScanner debug:"))
		for(var/line in debug_lines)
			to_chat(user, span_notice("  [line]"))

	world.log << "\n[findings]\n"
	to_chat(world, boxed_message("[findings]")) */

	holder.held_ref = null
	holder.list_that_holds_ref = null
	qdel(holder)
#endif
