/datum/log_category/refscanner
	category = "refscanner"


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
			// The list itself holds the leaked reference directly (vector slot).
			return "\[list\]       list #[f["list_id"]] \[index [f["index"]]\] (len=[f["length"]], refs=[f["ref_count"]])"

		if("list_assoc_value")
			// The datum is held as an assoc value inside this list.
			return "\[list_assoc\]  list #[f["list_id"]] (assoc value) (len=[f["length"]], refs=[f["ref_count"]])"

		if("list_owner")
			// A var or list slot holds a list that contains the leaked reference.
			var/owner_kind = f["owner_kind"]
			var/osrc
			if(owner_kind == "list")
				osrc = "list #[f["holder_id"]] \[index [f["index"]]\]"
			else
				osrc = _refscanner_fmt_holder(owner_kind, f["holder_id"], f["typepath"], f["var_name"])
			return "\[list_owner\] [osrc] -> list #[f["list_id"]]"

		if("suspended_proc")
			// A sleeping proc's local variable / src / usr / dot holds the reference.
			var/proc_name = f["proc_name"] || "?proc"
			var/oloc = f["filename"] ? "[f["filename"]]:[f["line"]]" : "?"
			var/field = f["field"]
			if(field == "local")
				return "\[suspended_proc\] [proc_name] local#[f["local_index"]] @ [oloc]"
			else
				return "\[suspended_proc\] [proc_name] .[field] @ [oloc]"

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

#if defined(TESTING) || defined(ABSOLUTE_MINIMUM) || defined(SPACEMAN_DMM)
// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Holder datum that deliberately does NOT null held_ref in Destroy(),
/// simulating a reference leak for the native scanner to detect.
/datum/refscanner_test_holder
	var/datum/victim/held_ref

/datum/refscanner_test_holder/Destroy(force)
	return ..()

// ---------------------------------------------------------------------------
// Admin verb
// ---------------------------------------------------------------------------

GLOBAL_VAR(meow_a)
GLOBAL_VAR(meow_b)
GLOBAL_LIST(meow_c)
GLOBAL_LIST(meow_d)
GLOBAL_LIST(meow_e)

/datum/victim

/datum/victim/Destroy()
	..()
	return QDEL_HINT_HARDDEL_NOW

/client
	var/datum/victim/meow

/proc/eepy_proc(a)
	var/datum/victim/victim = a
	sleep(5 SECONDS)
	return victim

/proc/_refscanner_print_results(mob/user, scenario)
	var/list/lines = refscanner_report()
	if(!length(lines))
		to_chat(user, span_warning("=== RefScanner: [scenario] - no findings ==="))
		return
	to_chat(user, span_boldnotice("=== RefScanner: [scenario] - [length(lines)] finding(s) ==="))
	for(var/line in lines)
		to_chat(user, span_notice("  [line]"))

ADMIN_VERB(refscanner_run_test, R_DEBUG, "Test Native RefScanner", \
	"Runs two reference-leak scenarios through the native pre-erasure scanner.", \
	ADMIN_CATEGORY_DEBUG)

	if(!refscanner_ensure_ready())
		to_chat(user, span_warning("datum_refscanner.dll could not be loaded - check the game log for details."))
		return

	// --- Scenario 1: direct datum var + global var ---
	// holder.held_ref and GLOB.meow_b both point at victim; neither is nulled
	// before HardDelete, so the pre-erasure scan should report both.
	var/datum/refscanner_test_holder/holder = new()
	var/datum/victim/victim = new()
	holder.held_ref = victim
	GLOB.meow_a = holder
	GLOB.meow_b = victim
	GLOB.meow_d = list(
		victim = "meow",
	)
	GLOB.meow_e = list(
		"hi" = victim
	)
	user.meow = victim

	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(eepy_proc), victim)

	// refscanner_clear()
	// refscanner_arm_once()
	qdel(victim)
	_refscanner_print_results(user, "scenario 1 - direct datum+global refs")

	victim = null
	GLOB.meow_a = null
	GLOB.meow_b = null
	GLOB.meow_c = null
	GLOB.meow_e = null
	GLOB.meow_e = null
	holder.held_ref = null
	user.meow = null
	qdel(holder)

	// --- Scenario 2: nested lists (BFS owner chaining) ---
	// victim2 is held inside inner_list, which is an element of outer_list,
	// which is an element of GLOB.meow_c. The BFS expansion in the Rust scanner
	// should chase the chain: victim2 → inner_list → outer_list → meow_c backing
	// list, then report the global var meow_c as a list_owner.
	//
	// Expected output (four entries):
	//   [finding]    global #N.meow_b
	//   [list]       list #X [index 0] (len=1, ...)    <- inner_list
	//   [list_owner] list #Y [index 0] -> list #X      <- outer_list holds inner_list
	//   [list_owner] list #Z [index 0] -> list #Y      <- meow_c backing list holds outer_list
	//   [list_owner] global #M.meow_c -> list #Z       <- global meow_c holds the backing list
	var/datum/victim/victim2 = new()
	var/list/inner_list = list(victim2)
	var/list/outer_list = list(inner_list)
	GLOB.meow_b = victim2
	GLOB.meow_c = list(outer_list)
	GLOB.meow_d = list(
		list(victim) = "meow",
	)
	GLOB.meow_e = list(
		"hi" = list(victim)
	)
	user.meow = list(outer_list)

	// refscanner_clear()
	// refscanner_arm_once()
	qdel(victim2)

	victim2 = null
	inner_list = null
	outer_list = null
	GLOB.meow_b = null
	GLOB.meow_c = null
	GLOB.meow_d = null
	GLOB.meow_e = null
	user.meow = null
#endif
