/datum/ai_controller/basic_controller/slime
	behavior_tree_json = "modular_oculis/modules/slime_rancher/code/slime.bt.json"

/// items the slime wants to eat, from BB_SLIME_WANTED_ITEMS, if it is set
/datum/target_source/slime_wanted_items

/datum/target_source/slime_wanted_items/collect_candidates(mob/living/pawn, datum/ai_controller/controller, range)
	var/list/wanted_types = controller.blackboard[BB_SLIME_WANTED_ITEMS]
	if(!length(wanted_types))
		return list()
	return typecache_filter_list(oview(range, pawn), wanted_types)

/// check to see if we're free to go eat items laying around
/datum/bt_node/decorator/bb_key_set/slime_can_forage

/datum/bt_node/decorator/bb_key_set/slime_can_forage/check_condition(datum/ai_controller/controller)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/basic/slime/slime_pawn = controller.pawn
	if(!istype(slime_pawn) || slime_pawn.buckled || IS_UNCONSCIOUS_OR_CRIT(slime_pawn))
		return FALSE
	return TRUE

/// small chance per tick for a slime to yoink a wanted item right out of an adjacent mob's hands
/// they don't chase people down, to be clear
/datum/bt_node/ai_behavior/snatch_held_item

/datum/bt_node/ai_behavior/snatch_held_item/perform(seconds_per_tick, datum/ai_controller/controller)
	if(!SPT_PROB(5, seconds_per_tick))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED

	var/mob/living/basic/slime/slime_pawn = controller.pawn
	var/list/wanted_types = controller.blackboard[BB_SLIME_WANTED_ITEMS]
	if(!istype(slime_pawn) || !length(wanted_types))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED

	for(var/mob/living/neighbor in oview(1, slime_pawn))
		for(var/obj/item/held in neighbor.held_items)
			if(!wanted_types[held.type])
				continue
			var/held_name = "\the [held]" // get this bc eating it might delete the item
			if(!slime_pawn.eat_wanted_item(held, silent = TRUE))
				continue
			slime_pawn.visible_message(
				span_notice("[slime_pawn] snatches [held_name] right out of [neighbor]'s hands!"),
				span_notice("You snatch [held_name] right out of [neighbor]'s hands!")
			)
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED

	return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
