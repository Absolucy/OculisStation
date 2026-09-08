#define SLIME_PEN_MAX_SIZE 9

/obj/item/slime_pen_post
	name = "slime pen post"
	desc = "A collapsible corner post. Plant four of them around a patch of floor and they'll string a containment fence between themselves."
	icon = 'modular_oculis/modules/slime_rancher/icons/slime_pen.dmi'
	icon_state = "corner"
	inhand_icon_state = null
	w_class = WEIGHT_CLASS_NORMAL
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/glass = SHEET_MATERIAL_AMOUNT)

/obj/item/slime_pen_post/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/deployable, 2 SECONDS, /obj/structure/slime_pen_post, direction_setting = FALSE)

/datum/design/slime_pen_post
	name = "Slime Pen Post"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/glass = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/slime_pen_post
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_XENOBIOLOGY,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/obj/structure/slime_pen_post
	name = "slime pen post"
	desc = "A corner post for a slime pen. Wrench it down, then click it to hook up with the other three."
	icon = 'modular_oculis/modules/slime_rancher/icons/slime_pen.dmi'
	icon_state = "corner"
	dir = NORTHEAST
	density = FALSE
	anchored = FALSE
	max_integrity = 100
	move_resist = INFINITY
	resistance_flags = LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	var/datum/slime_pen/pen
	var/barrier_color

/obj/structure/slime_pen_post/Initialize(mapload)
	. = ..()
	update_offsets()

/obj/structure/slime_pen_post/Destroy(force)
	QDEL_NULL(pen)
	return ..()

/obj/structure/slime_pen_post/examine(mob/user)
	. = ..()
	. += span_notice("It's marking the [dir2text(dir)] corner.")
	if(pen)
		. += span_notice("It's linked up. Click it to check on the slimes inside.")
	else if(anchored)
		. += span_notice("It's bolted down but not linked. Click it once the other three posts are placed.")
	else
		. += span_notice("Right-click to point it at a different corner, or wrench it down where it stands.")

/obj/structure/slime_pen_post/proc/update_offsets()
	// the post stands on the corner point of its tile, not in the middle of it
	pixel_w = (dir & EAST) ? 16 : -16
	if(dir & NORTH)
		pixel_z = 30
		layer = BELOW_MOB_LAYER + 0.01
	else
		pixel_z = -2
		layer = ABOVE_MOB_LAYER + 0.01

/obj/structure/slime_pen_post/update_overlays()
	. = ..()
	. += emissive_appearance(icon, "corner_e", src)

/obj/structure/slime_pen_post/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	pick_post(user)?.use_post(user)
	return TRUE

/obj/structure/slime_pen_post/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(anchored)
		balloon_alert(user, "unwrench it first!")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	dir = turn(dir, 90)
	update_offsets()
	balloon_alert(user, "[dir2text(dir)] corner")
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/structure/slime_pen_post/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	var/obj/structure/slime_pen_post/chosen = pick_post(user)
	if(isnull(chosen))
		return ITEM_INTERACT_BLOCKING
	if(chosen.pen)
		qdel(chosen.pen)
	chosen.default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/structure/slime_pen_post/proc/use_post(mob/living/user)
	if(pen)
		ui_interact(user)
		return
	if(!anchored)
		user.put_in_hands(new /obj/item/slime_pen_post(drop_location()))
		qdel(src)
		return
	try_link(user)

/obj/structure/slime_pen_post/proc/posts_sharing_corner() as /list
	var/list/found = list(src)
	var/turf/here = get_turf(src)
	if(isnull(here))
		return found
	var/our_east = (dir & EAST) ? 1 : 0
	var/our_north = (dir & NORTH) ? 1 : 0
	for(var/corner in GLOB.diagonals)
		if(corner == dir)
			continue
		var/turf/neighbor = locate(
			here.x + our_east - ((corner & EAST) ? 1 : 0),
			here.y + our_north - ((corner & NORTH) ? 1 : 0),
			here.z,
		)
		if(isnull(neighbor))
			continue
		for(var/obj/structure/slime_pen_post/post in neighbor)
			if(post.dir == corner)
				found += post
	return found

/obj/structure/slime_pen_post/proc/pick_post(mob/living/user) as /obj/structure/slime_pen_post
	var/list/candidates = posts_sharing_corner()
	if(length(candidates) == 1)
		return src
	var/list/choices = list()
	var/list/by_label = list()
	for(var/obj/structure/slime_pen_post/post as anything in candidates)
		var/label = "[dir2text(post.dir)] corner ([post.pen ? "linked" : "unlinked"])"
		choices[label] = image(icon = post.icon, icon_state = post.icon_state)
		by_label[label] = post
	var/picked = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	return by_label[picked]

// yee haw
/obj/structure/slime_pen_post/proc/find_partner(turf/from, direction, wanted_dir) as /obj/structure/slime_pen_post
	var/turf/scan = from
	for(var/step in 1 to SLIME_PEN_MAX_SIZE)
		for(var/obj/structure/slime_pen_post/post in scan)
			if(post != src && post.dir == wanted_dir && post.anchored && isnull(post.pen))
				return post
		scan = get_step(scan, direction)
		if(isnull(scan))
			return null
	return null

/// The one bit of this whole feature that assumes pens are rectangles. Returns the four posts, or null.
/obj/structure/slime_pen_post/proc/find_rectangle_layout() as /list
	var/turf/here = get_turf(src)
	if(isnull(here))
		return null
	var/inward_x = (dir & EAST) ? WEST : EAST
	var/inward_y = (dir & NORTH) ? SOUTH : NORTH
	var/obj/structure/slime_pen_post/across = find_partner(here, inward_x, (dir & (NORTH|SOUTH)) | inward_x)
	var/obj/structure/slime_pen_post/down = find_partner(here, inward_y, (dir & (EAST|WEST)) | inward_y)
	if(isnull(across) || isnull(down))
		return null
	var/turf/far = locate(across.x, down.y, here.z)
	if(isnull(far))
		return null
	for(var/obj/structure/slime_pen_post/post in far)
		if(post.dir == (inward_x | inward_y) && post.anchored && isnull(post.pen))
			return list(src, across, down, post)
	return null

/obj/structure/slime_pen_post/proc/try_link(mob/user)
	if(!anchored)
		balloon_alert(user, "bolt it down first!")
		return FALSE
	if(pen)
		return FALSE
	var/list/posts = find_rectangle_layout()
	if(isnull(posts))
		balloon_alert(user, "no matching posts!")
		return FALSE
	var/list/xs = list()
	var/list/ys = list()
	for(var/obj/structure/slime_pen_post/post as anything in posts)
		xs += post.x
		ys += post.y
	var/list/interior = block(locate(min(xs), min(ys), z), locate(max(xs), max(ys), z))
	for(var/turf/spot as anything in interior)
		if(spot.density)
			balloon_alert(user, "something's in the way!")
			return FALSE
		for(var/datum/slime_pen/other as anything in GLOB.slime_pens)
			if(spot in other.turfs)
				balloon_alert(user, "overlaps another pen!")
				return FALSE
	new /datum/slime_pen(interior, posts)
	return TRUE

/obj/structure/slime_pen_post/ui_interact(mob/user, datum/tgui/ui)
	if(isnull(pen))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SlimePen", "Slime Pen")
		ui.open()

/obj/structure/slime_pen_post/ui_data(mob/user)
	return pen?.ui_data(user)

/obj/structure/slime_pen_post/ui_static_data(mob/user)
	return pen?.ui_static_data(user)

/obj/structure/slime_pen_post/ui_act(action, list/params)
	. = ..()
	if(. || isnull(pen))
		return TRUE
	switch(action)
		if("set_color")
			pen.set_barrier_color(sanitize_hexcolor(params["color"], default = SLIME_PEN_DEFAULT_COLOR))
			return TRUE

// for mappers
/obj/structure/slime_pen_post/premade
	anchored = TRUE
	icon_state = MAP_SWITCH("corner", "corner_map")

/obj/structure/slime_pen_post/premade/Initialize(mapload)
	. = ..()
	if(!ISDIAGONALDIR(dir))
		log_mapping("mapped slime pen post at [AREACOORD(src)] faces [dir2text(dir)], which isn't a corner")
		CRASH("mapped slime pen post at [AREACOORD(src)] faces [dir2text(dir)], which isn't a corner")
	return INITIALIZE_HINT_LATELOAD

/obj/structure/slime_pen_post/premade/LateInitialize()
	if(isnull(pen))
		try_link()

#undef SLIME_PEN_MAX_SIZE
