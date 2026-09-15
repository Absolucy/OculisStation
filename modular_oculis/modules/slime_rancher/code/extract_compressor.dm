#define COMPRESSOR_EFFECT_EXTRACTS 8
#define COMPRESSOR_COLOR_EXTRACTS 2
#define COMPRESSOR_BASE_BIOMASS_COST 8
#define COMPRESSOR_BIOMASS_PER_BIN_TIER 2
#define COMPRESSOR_BASE_CYCLE_TIME (90 SECONDS)
#define COMPRESSOR_CYCLE_TIME_PER_SERVO_TIER (20 SECONDS)
#define COMPRESSOR_LINK_RANGE 5
#define COMPRESSOR_FRIDGE_RANGE 1
#define COMPRESSOR_PLOP_PITCH_MIN 1
#define COMPRESSOR_PLOP_PITCH_MAX 1.8

/particles/slime/extract_compressor
	count = 20
	spawning = 0.15

/obj/machinery/extract_compressor
	name = "extract compressor"
	desc = "Crossbreeds slime extracts under pressure, no slime required."
	icon = 'modular_oculis/modules/slime_rancher/icons/compressor.dmi'
	icon_state = "cross_compressor"
	base_icon_state = "cross_compressor"
	layer = BELOW_OBJ_LAYER
	density = TRUE
	circuit = /obj/item/circuitboard/machine/extract_compressor

	/// Extracts feeding the crossbreed's effect half.
	var/list/obj/item/slime_extract/effect_extracts = list()
	/// Extracts feeding the crossbreed's color half.
	var/list/obj/item/slime_extract/color_extracts = list()
	/// Seconds accumulated into the current cycle.
	var/cycle_progress = 0
	/// Total seconds the current cycle needs. Set when a cycle starts.
	var/cycle_length = COMPRESSOR_BASE_CYCLE_TIME
	/// Biomass the current cycle will cost. Set when a cycle starts.
	var/cycle_biomass_cost = COMPRESSOR_BASE_BIOMASS_COST
	var/datum/weakref/linked_recycler_ref
	/// Key used with add_shared_particles/remove_shared_particles for the current cycle, null when idle.
	var/running_particle_key

	var/last_process

	/// "[effect]|[colour]" -> crossbreed path, built once from every non-abstract slimecross.
	var/static/alist/crossbreed_lookup
	/// slime_extract type -> list(colour, rgb_code), built once from every slime_type.
	var/static/alist/extract_color_lookup

/obj/machinery/extract_compressor/Initialize(mapload)
	. = ..()
	build_lookups()
	last_process = world.time
	register_context()

/obj/machinery/extract_compressor/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	context[SCREENTIP_CONTEXT_ALT_LMB] = "Eject both tanks"
	if(istype(held_item, /obj/item/slime_extract))
		context[SCREENTIP_CONTEXT_LMB] = "Load effect tank"
		context[SCREENTIP_CONTEXT_RMB] = "Load color tank"
	else if(istype(held_item, /obj/item/storage/bag/xeno))
		context[SCREENTIP_CONTEXT_LMB] = "Bulk-load effect tank"
		context[SCREENTIP_CONTEXT_RMB] = "Bulk-load color tank"
	else if(isnull(held_item))
		context[SCREENTIP_CONTEXT_LMB] = "Start compressing"
	return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/extract_compressor/post_machine_initialize()
	. = ..()
	link_nearest_recycler()

/obj/machinery/extract_compressor/Destroy()
	if(running_particle_key)
		remove_shared_particles(running_particle_key)
		running_particle_key = null
	QDEL_LIST(effect_extracts)
	QDEL_LIST(color_extracts)
	linked_recycler_ref = null
	return ..()

/obj/machinery/extract_compressor/proc/build_lookups()
	if(!isnull(crossbreed_lookup))
		return
	crossbreed_lookup = alist()
	for(var/obj/item/slimecross/cross_path as anything in subtypesof(/obj/item/slimecross))
		if(cross_path::colour == "null")
			continue // not a real crossbreed
		crossbreed_lookup["[cross_path::effect]|[cross_path::colour]"] = cross_path

	extract_color_lookup = alist()
	for(var/datum/slime_type/slime_type as anything in subtypesof(/datum/slime_type))
		if(!slime_type::core_type)
			continue
		extract_color_lookup[slime_type::core_type] = list(slime_type::colour, slime_type::rgb_code)

/obj/machinery/extract_compressor/proc/link_nearest_recycler()
	if(get_recycler())
		return
	var/obj/machinery/biomass_recycler/closest
	var/closest_distance
	for(var/obj/machinery/biomass_recycler/recycler in range(COMPRESSOR_LINK_RANGE, src))
		var/distance = get_dist(src, recycler)
		if(isnull(closest_distance) || distance < closest_distance)
			closest = recycler
			closest_distance = distance
	if(closest)
		linked_recycler_ref = WEAKREF(closest)

/obj/machinery/extract_compressor/proc/get_recycler()
	var/obj/machinery/biomass_recycler/recycler = linked_recycler_ref?.resolve()
	if(isnull(recycler))
		linked_recycler_ref = null
	return recycler

/obj/machinery/extract_compressor/RefreshParts()
	. = ..()
	var/servo_tier = 1
	var/bin_tier = 1
	for(var/datum/stock_part/servo/servo in component_parts)
		servo_tier = max(servo_tier, servo.tier)
	for(var/datum/stock_part/matter_bin/matter_bin in component_parts)
		bin_tier = max(bin_tier, matter_bin.tier)
	cycle_length = max(COMPRESSOR_BASE_CYCLE_TIME - (servo_tier - 1) * COMPRESSOR_CYCLE_TIME_PER_SERVO_TIER, COMPRESSOR_CYCLE_TIME_PER_SERVO_TIER)
	cycle_biomass_cost = max(COMPRESSOR_BASE_BIOMASS_COST - (bin_tier - 1) * COMPRESSOR_BIOMASS_PER_BIN_TIER, COMPRESSOR_BIOMASS_PER_BIN_TIER)

/obj/machinery/extract_compressor/examine(mob/user)
	. = ..()
	if(!in_range(user, src) && !isobserver(user))
		return
	. += span_notice("The effect tank holds [length(effect_extracts)] of [COMPRESSOR_EFFECT_EXTRACTS] extracts.")
	. += span_notice("The color tank holds [length(color_extracts)] of [COMPRESSOR_COLOR_EXTRACTS] extracts.")
	if(length(effect_extracts) && length(color_extracts))
		var/obj/item/slimecross/result_path = get_resulting_crossbreed()
		. += result_path ? span_notice("This loadout will produce \a [result_path::name].") : span_warning("This loadout won't produce anything - no known crossbreed.")
	var/obj/machinery/biomass_recycler/recycler = get_recycler()
	. += recycler ? span_notice("It is linked to [recycler], with [recycler.biomass] biomass available.") : span_warning("It is not linked to a biomass recycler.")
	. += span_notice("A cycle takes [DisplayTimeText(cycle_length)] and costs [cycle_biomass_cost] biomass.")
	if(is_cycling())
		. += span_notice("It is currently compressing a batch.")

/obj/machinery/extract_compressor/proc/is_cycling()
	return cycle_progress > 0

/obj/machinery/extract_compressor/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(default_unfasten_wrench(user, tool))
		power_change()
		link_nearest_recycler()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/extract_compressor/screwdriver_act(mob/living/user, obj/item/tool)
	return default_deconstruction_screwdriver(user, tool)

/obj/machinery/extract_compressor/crowbar_act(mob/living/user, obj/item/tool)
	return default_pry_open(user, tool, close_after_pry = TRUE, deconstruct_on_fail = TRUE)

/obj/machinery/extract_compressor/update_icon_state()
	. = ..()
	if(is_cycling())
		icon_state = "[base_icon_state]_running"
	else if(!is_operational || panel_open)
		icon_state = "[base_icon_state]_off"
	else
		icon_state = base_icon_state

/obj/machinery/extract_compressor/update_overlays()
	. = ..()
	. += tank_fill_overlay("left", effect_extracts, COMPRESSOR_EFFECT_EXTRACTS)
	. += tank_fill_overlay("right", color_extracts, COMPRESSOR_COLOR_EXTRACTS)
	if(length(effect_extracts) || length(color_extracts))
		. += "[base_icon_state]_tank"
	if(is_cycling())
		. += emissive_appearance(icon, "[base_icon_state]_tank", src)

/obj/machinery/extract_compressor/proc/tank_fill_overlay(side, list/obj/item/slime_extract/tank, required)
	if(!length(tank))
		return null
	var/fraction = length(tank) / required
	var/fill_state = fraction >= 1 ? "full" : (fraction >= 0.5 ? "half" : "quarter")
	var/list/extract_color = extract_color_lookup[tank[1].type]
	var/rainbow = extract_color?[1] == SLIME_TYPE_RAINBOW
	var/state_suffix = rainbow ? "_rainbow" : ""
	var/mutable_appearance/fill = mutable_appearance(icon, "[base_icon_state]_[side]_[fill_state][state_suffix]")
	if(extract_color && !rainbow)
		fill.color = vibrant_tint(extract_color[2])
	return fill

/obj/machinery/extract_compressor/proc/vibrant_tint(rgb)
	var/list/hsv = rgb2hsv(rgb)
	hsv[2] = min(hsv[2] * 1.3, 100)
	hsv[3] = min(hsv[3] * 1.15, 100)
	return hsv2rgb(hsv)

/obj/machinery/extract_compressor/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	. = try_insert(user, tool, effect_extracts, COMPRESSOR_EFFECT_EXTRACTS)
	if(. != NONE)
		return .
	return ..()

/obj/machinery/extract_compressor/item_interaction_secondary(mob/living/user, obj/item/tool, list/modifiers)
	. = try_insert(user, tool, color_extracts, COMPRESSOR_COLOR_EXTRACTS)
	if(. != NONE)
		return .
	return ..()

/obj/machinery/extract_compressor/proc/try_insert(mob/living/user, obj/item/tool, list/obj/item/slime_extract/tank, required)
	if(!is_operational || panel_open || is_cycling())
		return NONE
	if(istype(tool, /obj/item/storage/bag/xeno))
		var/inserted = 0
		for(var/obj/item/slime_extract/extract in tool)
			if(insert_extract(extract, tank, required))
				inserted++
				play_fill_plop(tank, required)
		if(!inserted)
			return NONE
		balloon_alert(user, "[inserted] extract\s inserted[prediction_suffix()]")
		update_appearance()
		return ITEM_INTERACT_SUCCESS
	if(!istype(tool, /obj/item/slime_extract))
		return NONE
	if(!insert_extract(tool, tank, required))
		balloon_alert(user, length(tank) >= required ? "tank full" : "wrong extract")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "extract inserted[prediction_suffix()]")
	play_fill_plop(tank, required)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/extract_compressor/proc/play_fill_plop(list/obj/item/slime_extract/tank, required)
	var/fraction = length(tank) / required
	var/pitch = COMPRESSOR_PLOP_PITCH_MIN + (fraction * (COMPRESSOR_PLOP_PITCH_MAX - COMPRESSOR_PLOP_PITCH_MIN))
	playsound(src, 'sound/items/vacuum/vacuum_ploop.ogg', vol = 35, frequency = pitch)

/// " - will make X" / " - no known crossbreed" once both tanks hold something, else "".
/obj/machinery/extract_compressor/proc/prediction_suffix()
	if(!length(effect_extracts) || !length(color_extracts))
		return ""
	var/obj/item/slimecross/result_path = get_resulting_crossbreed()
	return result_path ? " - will make [result_path::name]" : " - no known crossbreed"

/// Moves a matching extract into the tank. Returns FALSE without touching the extract if it doesn't fit.
/obj/machinery/extract_compressor/proc/insert_extract(obj/item/slime_extract/extract, list/obj/item/slime_extract/tank, required)
	if(length(tank) >= required)
		return FALSE
	if(tank == effect_extracts && !extract.crossbreed_modification)
		return FALSE
	if(tank == color_extracts && !extract_color_lookup[extract.type])
		return FALSE
	if(length(tank) && tank[1].type != extract.type)
		return FALSE
	extract.forceMove(src)
	tank += extract
	return TRUE

/obj/machinery/extract_compressor/click_alt(mob/user)
	if(is_cycling())
		balloon_alert(user, "busy")
		return CLICK_ACTION_BLOCKING
	eject_tank(effect_extracts, user)
	eject_tank(color_extracts, user)
	update_appearance()
	return CLICK_ACTION_SUCCESS

/obj/machinery/extract_compressor/proc/eject_tank(list/obj/item/slime_extract/tank, mob/user)
	for(var/obj/item/slime_extract/extract as anything in tank)
		extract.forceMove(drop_location())
	tank.Cut()

/obj/machinery/extract_compressor/interact(mob/user)
	. = ..()
	if(is_cycling())
		balloon_alert(user, "busy")
		return
	if(!length(effect_extracts) || !length(color_extracts))
		balloon_alert(user, "load both tanks")
		return
	refill_from_nearby_fridge(effect_extracts, COMPRESSOR_EFFECT_EXTRACTS)
	refill_from_nearby_fridge(color_extracts, COMPRESSOR_COLOR_EXTRACTS)
	start_cycle(user)

/// Tops a tank up from any extract fridge within COMPRESSOR_FRIDGE_RANGE, matching the type already loaded.
/obj/machinery/extract_compressor/proc/refill_from_nearby_fridge(list/obj/item/slime_extract/tank, required)
	if(length(tank) >= required || !length(tank))
		return
	var/wanted_type = tank[1].type
	for(var/obj/machinery/smartfridge/extract/fridge in range(COMPRESSOR_FRIDGE_RANGE, src))
		for(var/obj/item/slime_extract/extract in fridge.contents)
			if(extract.type != wanted_type)
				continue
			extract.forceMove(src)
			tank += extract
			if(length(tank) >= required)
				return

/obj/machinery/extract_compressor/proc/start_cycle(mob/user)
	if(length(effect_extracts) < COMPRESSOR_EFFECT_EXTRACTS)
		balloon_alert(user, "not enough effect extracts")
		return
	if(length(color_extracts) < COMPRESSOR_COLOR_EXTRACTS)
		balloon_alert(user, "not enough color extracts")
		return
	var/result_path = get_resulting_crossbreed()
	if(!result_path)
		balloon_alert(user, "no known crossbreed")
		return
	var/obj/machinery/biomass_recycler/recycler = get_recycler()
	if(!recycler || recycler.biomass < cycle_biomass_cost)
		balloon_alert(user, "not enough linked biomass")
		return

	cycle_progress = 1 // 0 means idle, so a fresh cycle starts just past that
	last_process = world.time
	var/list/color_info = extract_color_lookup[color_extracts[1].type]
	if(color_info?[1] == SLIME_TYPE_RAINBOW)
		running_particle_key = "extract_compressor_rainbow"
		add_shared_particles(/particles/slime/rainbow, running_particle_key)
	else
		var/particle_color = color_info ? vibrant_tint(color_info[2]) : COLOR_WHITE
		running_particle_key = "extract_compressor_[particle_color]"
		var/obj/effect/abstract/shared_particle_holder/holder = add_shared_particles(/particles/slime/extract_compressor, running_particle_key)
		holder.particles.color = particle_color
	playsound(src, 'sound/machines/hiss.ogg', vol = 30, vary = TRUE)
	update_appearance()

/obj/machinery/extract_compressor/proc/get_resulting_crossbreed()
	if(!length(effect_extracts) || !length(color_extracts))
		return null
	var/effect = effect_extracts[1].crossbreed_modification
	var/list/color_info = extract_color_lookup[color_extracts[1].type]
	if(!effect || !color_info)
		return null
	return crossbreed_lookup["[effect]|[color_info[1]]"]

/obj/machinery/extract_compressor/process()
	if(!is_cycling())
		return
	if(!is_operational)
		last_process = world.time
		return
	cycle_progress += world.time - last_process
	last_process = world.time
	use_energy(active_power_usage)
	if(cycle_progress < cycle_length)
		return
	finish_cycle()

/obj/machinery/extract_compressor/proc/finish_cycle()
	var/result_path = get_resulting_crossbreed()
	var/obj/machinery/biomass_recycler/recycler = get_recycler()
	cycle_progress = 0
	remove_shared_particles(running_particle_key)
	running_particle_key = null

	if(!result_path || !recycler || recycler.biomass < cycle_biomass_cost)
		update_appearance() // recipe or recycler went bad mid-cycle, leave the extracts for the player to sort out
		return

	QDEL_LIST(effect_extracts)
	QDEL_LIST(color_extracts)
	recycler.biomass -= cycle_biomass_cost
	new result_path(drop_location())
	playsound(src, 'sound/effects/splat.ogg', vol = 40, vary = TRUE)
	playsound(src, 'sound/machines/ping.ogg', vol = 35, vary = TRUE)
	update_appearance()

/obj/item/circuitboard/machine/extract_compressor
	name = "Extract Compressor"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/extract_compressor
	req_components = list(
		/datum/stock_part/matter_bin = 1,
		/datum/stock_part/servo = 1,
	)
	needs_anchored = FALSE

/datum/design/board/extract_compressor
	name = "Extract Compressor Board"
	desc = "The circuit board for an extract compressor."
	build_path = /obj/item/circuitboard/machine/extract_compressor
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

#undef COMPRESSOR_BASE_BIOMASS_COST
#undef COMPRESSOR_BASE_CYCLE_TIME
#undef COMPRESSOR_BIOMASS_PER_BIN_TIER
#undef COMPRESSOR_COLOR_EXTRACTS
#undef COMPRESSOR_CYCLE_TIME_PER_SERVO_TIER
#undef COMPRESSOR_EFFECT_EXTRACTS
#undef COMPRESSOR_FRIDGE_RANGE
#undef COMPRESSOR_LINK_RANGE
#undef COMPRESSOR_PLOP_PITCH_MAX
#undef COMPRESSOR_PLOP_PITCH_MIN
