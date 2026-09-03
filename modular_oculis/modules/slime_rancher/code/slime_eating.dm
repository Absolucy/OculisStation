/mob/living/basic/slime
	/// Requirement typepaths (not object types - a stack sheet's subtype still counts) this slime has already eaten.
	var/list/eaten_items

/// returns a list of items this slime can eat for mutations (which it hasn't eaten already)
/mob/living/basic/slime/proc/get_wanted_item_types() as /list
	. = list()
	for(var/mutation_type in slime_type.possible_mutations)
		var/datum/slime_mutation/mutation = GLOB.slime_mutations[mutation_type]
		for(var/needed_type in mutation?.needed_items)
			if(!(needed_type in eaten_items))
				. += needed_type

/mob/living/basic/slime/proc/refresh_wanted_items()
	ai_controller?.override_blackboard_key(BB_SLIME_WANTED_ITEMS, typecacheof(get_wanted_item_types()))

/// Eats meal, whether it's sitting on the floor or in someone's hands. Returns TRUE if it was eaten.
/// silent skips the default "slurps up" message, for callers with their own wording (like when it yoinks an item out of your hand).
/mob/living/basic/slime/proc/eat_wanted_item(obj/item/meal, silent = FALSE)
	// bail on the AI's stale target regardless of what happens below - it either just got eaten,
	// or it's not wanted anymore, and either way the AI shouldn't keep whacking it
	if(ai_controller?.blackboard[BB_SLIME_ITEM_TARGET] == meal)
		ai_controller.clear_blackboard_key(BB_SLIME_ITEM_TARGET)

	var/list/wanted_types = get_wanted_item_types()
	var/list/matched_types = list()
	for(var/wanted_type in wanted_types)
		if(istype(meal, wanted_type))
			matched_types += wanted_type
	if(!length(matched_types))
		return FALSE

	var/meal_name = "\the [meal]" // get this bc eating it might delete the item

	if(isstack(meal))
		var/obj/item/stack/meal_stack = meal
		if(!meal_stack.use(1))
			return FALSE
	else
		var/mob/holder = meal.loc
		if(ismob(holder) && !holder.temporarilyRemoveItemFromInventory(meal))
			return FALSE
		qdel(meal)

	for(var/needed_type in matched_types)
		LAZYADD(eaten_items, needed_type)

	if(!silent)
		visible_message(
			span_notice("[src] slurps up [meal_name]!"),
			span_notice("You slurp up [meal_name]!")
		)
		balloon_alert_to_viewers("slurps up item")
	playsound(src, 'sound/items/eatfood.ogg', vol = 50, vary = TRUE) // yumy
	adjust_nutrition(5)
	refresh_wanted_items()
	return TRUE

/// The mutation this slime has fully fed for, if any. Random among ties.
/mob/living/basic/slime/proc/get_unlocked_mutation_type()
	var/list/unlocked = list()
	for(var/mutation_type in slime_type.possible_mutations)
		var/datum/slime_mutation/mutation = GLOB.slime_mutations[mutation_type]
		if(!length(mutation?.needed_items))
			continue
		if(length(mutation.needed_items - eaten_items))
			continue
		unlocked += mutation.mutates_into

	if(!length(unlocked))
		return null
	return pick(unlocked)

/mob/living/basic/slime/set_slime_type(new_type = SLIME_TYPE_RANDOM)
	. = ..()
	eaten_items = null
	refresh_wanted_items()

/mob/living/basic/slime/get_random_mutation()
	. = ..()
	if(transformative_effect == SLIME_TYPE_CERULEAN || transformative_effect == SLIME_TYPE_PYRITE)
		return
	return get_unlocked_mutation_type()

/// lets a slime eat a wanted item just by attacking it - covers both the AI's own melee attack leaf and a player clicking it themselves
/mob/living/basic/slime/on_slime_pre_attack(mob/living/basic/slime/our_slime, atom/target, proximity, modifiers)
	if(isitem(target) && our_slime.eat_wanted_item(target))
		return COMPONENT_HOSTILE_NO_ATTACK
	return ..()
