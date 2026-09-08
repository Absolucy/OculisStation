/proc/is_slime_pen_contained(atom/movable/mover)
	if(isslime(mover) || ismonkey(mover))
		return TRUE
	if(!isbasicmob(mover))
		return FALSE
	var/mob/living/basic/critter = mover
	return critter.biomass_value > 0

/obj/structure/slime_pen_barrier
	name = "containment field"
	desc = "A shimmering mesh strung between two pen posts. Slimes bounce off it. You won't."
	icon = 'modular_oculis/modules/slime_rancher/icons/slime_pen.dmi'
	icon_state = "barrier"
	flags_1 = ON_BORDER_1
	density = FALSE
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	move_resist = INFINITY
	can_astar_pass = CANASTARPASS_ALWAYS_PROC
	var/top_row = FALSE

/obj/structure/slime_pen_barrier/Initialize(mapload, new_dir, top_row = FALSE)
	. = ..()
	setDir(new_dir)
	src.top_row = top_row
	var/static/list/loc_connections = list(
		COMSIG_ATOM_EXIT = PROC_REF(on_exit),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	update_offsets()
	update_appearance()

/obj/structure/slime_pen_barrier/Destroy(force)
	var/obj/structure/slime_pen_barrier/twin = find_twin()
	if(twin)
		alpha = 0
		twin.update_appearance()
	return ..()

/// The barrier on the other side of our edge, if the neighboring pen has one.
/obj/structure/slime_pen_barrier/proc/find_twin() as /obj/structure/slime_pen_barrier
	var/turf/across = get_step(loc, dir)
	if(isnull(across))
		return null
	var/facing_us = REVERSE_DIR(dir)
	for(var/obj/structure/slime_pen_barrier/barrier in across)
		if(barrier.dir == facing_us && !QDELING(barrier))
			return barrier
	return null

/// Puts the sprite on the tile border and picks whether mobs draw in front of us or behind us.
/obj/structure/slime_pen_barrier/proc/update_offsets()
	switch(dir)
		if(NORTH)
			pixel_w = 0
			pixel_z = 13
			layer = BELOW_MOB_LAYER
		if(SOUTH)
			pixel_w = 0
			pixel_z = 0
			layer = ABOVE_MOB_LAYER
		if(EAST)
			pixel_w = 6
			pixel_z = 6
			layer = BELOW_MOB_LAYER + 0.02
		if(WEST)
			pixel_w = -6
			pixel_z = 6
			layer = BELOW_MOB_LAYER + 0.02

/obj/structure/slime_pen_barrier/update_appearance(updates = ALL)
	// two pens sharing an edge would draw the same fence twice, so the older one just hides lmao
	alpha = find_twin()?.alpha ? 0 : 255
	return ..()

/obj/structure/slime_pen_barrier/update_overlays()
	. = ..()
	if(!alpha)
		return
	var/mutable_appearance/glow = emissive_appearance(icon, "barrier", src)
	glow.dir = dir
	. += glow
	if(!top_row)
		return
	var/mutable_appearance/connector = mutable_appearance(icon, "barrier_half")
	connector.dir = dir
	connector.pixel_z = 7
	. += connector
	var/mutable_appearance/connector_glow = emissive_appearance(icon, "barrier_half", src)
	connector_glow.dir = dir
	connector_glow.pixel_z = 7
	. += connector_glow

/obj/structure/slime_pen_barrier/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	// we're not dense, so the parent always says yes and we're the only one who can say no
	if(border_dir == dir && should_block(mover))
		return FALSE

/obj/structure/slime_pen_barrier/proc/on_exit(datum/source, atom/movable/leaving, direction)
	SIGNAL_HANDLER
	if(direction != dir || leaving == src)
		return
	if(!should_block(leaving))
		return
	leaving.Bump(src)
	return COMPONENT_ATOM_BLOCK_EXIT

/obj/structure/slime_pen_barrier/proc/should_block(atom/movable/mover)
	if(!is_slime_pen_contained(mover))
		return FALSE
	var/mob/living/critter = mover
	if(critter.movement_type & PHASING)
		return FALSE
	if(critter.pulledby || critter.buckled || critter.throwing)
		return FALSE
	return TRUE

/obj/structure/slime_pen_barrier/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return dir != to_dir || !pass_info.slime_pen_contained
