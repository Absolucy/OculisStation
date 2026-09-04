/datum/slime_mutation
	abstract_type = /datum/slime_mutation
	/// The slime type we pass on if we succeed
	var/datum/slime_type/mutates_into
	/// Items still needed to feed the slime in order to mutate.
	/// Items are removed as the slime eats them.
	var/list/needed_items
	/// The mobs still needed to be latch fed in order to mutate - stored as [mob type] = health drained (reduced as the slime eats said mobs)
	var/alist/latch_needed
	/// If TRUE, then you can't get this color from a random mutator syringe
	var/syringe_blocked = FALSE

/datum/slime_mutation/proc/is_satisfied()
	return !length(needed_items) && !length(latch_needed)

/datum/slime_mutation/metal
	mutates_into = /datum/slime_type/metal
	needed_items = list(/obj/item/stack/sheet/iron)

/datum/slime_mutation/orange
	mutates_into = /datum/slime_type/orange
	needed_items = list(/obj/item/stack/sheet/mineral/plasma)

/datum/slime_mutation/purple
	mutates_into = /datum/slime_type/purple
	needed_items = list(/obj/item/stack/medical/wrap/gauze)

/datum/slime_mutation/blue
	mutates_into = /datum/slime_type/blue
	latch_needed = alist(/mob/living/basic/cockroach/iceroach = 50)

/datum/slime_mutation/cerulean
	mutates_into = /datum/slime_type/cerulean
	latch_needed = alist(/mob/living/basic/cockroach/recursive = 40)

/datum/slime_mutation/dark_blue
	mutates_into = /datum/slime_type/dark_blue
	latch_needed = alist(/mob/living/basic/xenofauna/diyaab = 75)

/datum/slime_mutation/red
	mutates_into = /datum/slime_type/red
	latch_needed = alist(/mob/living/basic/xenofauna/lavadog = 50)

/datum/slime_mutation/oil
	mutates_into = /datum/slime_type/oil
	latch_needed = alist(/mob/living/basic/xenofauna/dron = 65)

/datum/slime_mutation/yellow
	mutates_into = /datum/slime_type/yellow
	needed_items = list(/obj/item/stock_parts/power_store/cell)

/datum/slime_mutation/green
	mutates_into = /datum/slime_type/green
	latch_needed = alist(/mob/living/basic/xenofauna/greeblefly = 65)

/datum/slime_mutation/sepia
	mutates_into = /datum/slime_type/sepia
	latch_needed = alist(/mob/living/basic/xenofauna/possum = 65)

/datum/slime_mutation/black
	mutates_into = /datum/slime_type/black
	latch_needed = alist(/mob/living/basic/xenofauna/thoom = 50)

/datum/slime_mutation/silver
	mutates_into = /datum/slime_type/silver
	latch_needed = alist(/mob/living/basic/xenofauna/meatbeast = 80)

/datum/slime_mutation/gold
	mutates_into = /datum/slime_type/gold
	needed_items = list(/obj/item/stack/sheet/mineral/gold)

/datum/slime_mutation/adamantine
	mutates_into = /datum/slime_type/adamantine
	needed_items = list(/obj/item/rockroach_shell)

/datum/slime_mutation/darkpurple
	mutates_into = /datum/slime_type/darkpurple
	needed_items = list(/obj/item/slime_extract/purple)

/datum/slime_mutation/pink
	mutates_into = /datum/slime_type/pink
	latch_needed = alist(/mob/living/basic/xenofauna/thinbug = 80)

/datum/slime_mutation/pyrite
	mutates_into = /datum/slime_type/pyrite
	needed_items = list(/obj/item/toy/crayon/rainbow)

/datum/slime_mutation/bluespace
	mutates_into = /datum/slime_type/bluespace
	needed_items = list(/obj/item/stack/ore/bluespace_crystal)

/datum/slime_mutation/lightpink
	mutates_into = /datum/slime_type/lightpink
	latch_needed = alist(/mob/living/basic/xenofauna/voxslug = 80)

/datum/slime_mutation/darkgrey
	mutates_into = /datum/slime_type/unique/darkgrey
	needed_items = list(/obj/item/crusher_trophy/legion_skull)
	syringe_blocked = TRUE

/datum/slime_mutation/rainbow
	mutates_into = /datum/slime_type/rainbow
	needed_items = list(
		/obj/item/slime_extract/orange,
		/obj/item/slime_extract/purple,
		/obj/item/slime_extract/blue,
		/obj/item/slime_extract/metal,
		/obj/item/slime_extract/yellow,
		/obj/item/slime_extract/darkblue,
		/obj/item/slime_extract/darkpurple,
		/obj/item/slime_extract/silver,
	)
	syringe_blocked = TRUE
