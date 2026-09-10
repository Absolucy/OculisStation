/// Handheld control nozzle paired to a slime vacuum pack.
/obj/item/vacuum_nozzle
	name = "slime vacuum nozzle"
	desc = "A nozzle attached to a slime vacuum pack."
	icon = 'modular_oculis/modules/slime_rancher/icons/vacuum.dmi'
	icon_state = "vacuum_nozzle"
	inhand_icon_state = "vacuum_nozzle"
	lefthand_file = 'modular_oculis/modules/slime_rancher/icons/vacuum_nozzle_lefthand.dmi'
	righthand_file = 'modular_oculis/modules/slime_rancher/icons/vacuum_nozzle_righthand.dmi'
	w_class = WEIGHT_CLASS_HUGE
	item_flags = NOBLUDGEON | ABSTRACT
	slot_flags = NONE
	resistance_flags = FIRE_PROOF | ACID_PROOF
	var/obj/item/vacuum_pack/pack
	var/datum/weakref/registered_user_ref

/obj/item/vacuum_nozzle/Initialize(mapload)
	. = ..()
	if(!istype(loc, /obj/item/vacuum_pack))
		return INITIALIZE_HINT_QDEL
	src.pack = loc
	register_item_context()

/obj/item/vacuum_nozzle/Destroy()
	unregister_user()
	if(pack?.nozzle == src)
		pack.nozzle = null
	pack = null
	return ..()

/obj/item/vacuum_nozzle/equipped(mob/user, slot, initial)
	. = ..()
	if(slot & ITEM_SLOT_HANDS)
		register_user(user)
	else
		pack?.retract_nozzle()

/obj/item/vacuum_nozzle/dropped(mob/user, silent)
	. = ..()
	unregister_user()
	pack?.retract_nozzle()

/obj/item/vacuum_nozzle/attack_self(mob/user, modifiers)
	. = ..()
	pack?.toggle_firing_mode(user)
	return TRUE

/obj/item/vacuum_nozzle/attack_self_secondary(mob/user, modifiers)
	. = ..()
	pack?.select_species(user)
	return TRUE

/obj/item/vacuum_nozzle/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!pack)
		return NONE
	if(istype(interacting_with, /obj/item/disk/vacuum_upgrade) && interacting_with.Adjacent(user))
		return pack.item_interaction(user, interacting_with)
	if(interacting_with == pack)
		pack.retract_nozzle()
		return ITEM_INTERACT_SUCCESS
	pack.primary_action(interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/obj/item/vacuum_nozzle/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	return interact_with_atom(interacting_with, user, modifiers)

/obj/item/vacuum_nozzle/interact_with_atom_secondary(atom/interacting_with, mob/living/user, list/modifiers)
	if(!pack)
		return NONE
	pack.print_species(interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/obj/item/vacuum_nozzle/ranged_interact_with_atom_secondary(atom/interacting_with, mob/living/user, list/modifiers)
	return interact_with_atom_secondary(interacting_with, user, modifiers)

/obj/item/vacuum_nozzle/add_item_context(obj/item/source, list/context, atom/target, mob/living/user)
	if(target == src)
		context[SCREENTIP_CONTEXT_LMB] = "Toggle firing mode"
		context[SCREENTIP_CONTEXT_RMB] = "Select printable species"
		return CONTEXTUAL_SCREENTIP_SET
	if(istype(target, /obj/machinery/biomass_recycler))
		context[SCREENTIP_CONTEXT_LMB] = "Link recycler"
	else if(ismonkey(target))
		context[SCREENTIP_CONTEXT_LMB] = "Recycle monkey"
	else if(isliving(target))
		context[SCREENTIP_CONTEXT_LMB] = "Capture creature"
	else
		context[SCREENTIP_CONTEXT_LMB] = "Launch stored creature"
	context[SCREENTIP_CONTEXT_RMB] = "Print and launch creature"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/vacuum_nozzle/proc/register_user(mob/living/user)
	var/mob/living/old_user = registered_user_ref?.resolve()
	if(old_user == user)
		return
	if(old_user)
		UnregisterSignal(old_user, COMSIG_MOB_ALTCLICKON)
	registered_user_ref = WEAKREF(user)
	RegisterSignal(user, COMSIG_MOB_ALTCLICKON, PROC_REF(on_user_altclick))

/obj/item/vacuum_nozzle/proc/unregister_user()
	var/mob/living/user = registered_user_ref?.resolve()
	if(user)
		UnregisterSignal(user, COMSIG_MOB_ALTCLICKON)
	registered_user_ref = null

/// Leaves ordinary Alt-click alone unless an eligible world-tile target exists.
/obj/item/vacuum_nozzle/proc/on_user_altclick(mob/living/source, atom/target)
	SIGNAL_HANDLER
	if(source.get_active_held_item() != src || !pack || pack.busy)
		return
	var/turf/target_turf = get_turf(target)
	if(!target_turf || (!isturf(target) && target.loc != target_turf))
		return
	if(!pack.has_selectable_target(target_turf, source))
		return
	INVOKE_ASYNC(pack, TYPE_PROC_REF(/obj/item/vacuum_pack, select_turf_target), target_turf, source)
	return COMSIG_MOB_CANCEL_CLICKON

/obj/effect/temp_visual/vacuum_intake
	duration = 0.5 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/vacuum_intake/Initialize(mapload, source_appearance, turf/destination)
	. = ..()
	appearance = copy_appearance_filter_overlays(source_appearance)
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/matrix/shrinking = matrix(transform)
	shrinking.Scale(0.25)
	if(destination)
		shrinking.Translate((destination.x - x) * ICON_SIZE_X, (destination.y - y) * ICON_SIZE_Y)
	animate(src, transform = shrinking, alpha = 0, time = duration, easing = QUAD_EASING|EASE_IN)
