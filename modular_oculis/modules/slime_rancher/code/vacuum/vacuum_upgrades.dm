/// Installed behavior and stat changes owned by one vacuum pack.
/datum/vacuum_upgrade
	/// Pack that owns this upgrade.
	var/obj/item/vacuum_pack/pack
	/// Display name used by pack examination.
	var/name = "vacuum"
	/// Added storage slots.
	var/capacity_bonus = 0
	/// Added suction range.
	var/range_bonus = 0
	/// Reduction to suction wind-up.
	var/capture_delay_reduction = 0
	/// Capability bitflag granted to the pack.
	var/capability = NONE

/datum/vacuum_upgrade/New(obj/item/vacuum_pack/pack)
	. = ..()
	src.pack = pack
	on_install()

/datum/vacuum_upgrade/Destroy()
	pack = null
	return ..()

/datum/vacuum_upgrade/proc/on_install()
	return

/datum/vacuum_upgrade/capacity
	name = "capacity"
	capacity_bonus = 5

/datum/vacuum_upgrade/range
	name = "range"
	range_bonus = 2

/datum/vacuum_upgrade/speed
	name = "speed"
	capture_delay_reduction = 0.5 SECONDS

/datum/vacuum_upgrade/pacify
	name = "pacify"
	capability = VACUUM_CAN_PACIFY

/datum/vacuum_upgrade/printer
	name = "printer"
	capability = VACUUM_CAN_PRINT

/// Uses its own trait source so other stasis effects survive release.
/datum/vacuum_upgrade/stasis
	name = "stasis"

/datum/vacuum_upgrade/stasis/on_install()
	RegisterSignal(pack, COMSIG_VACUUM_STORED, PROC_REF(on_stored))
	RegisterSignal(pack, COMSIG_VACUUM_RELEASED, PROC_REF(on_released))
	for(var/mob/living/occupant as anything in pack.occupants())
		apply_stasis(occupant)

/datum/vacuum_upgrade/stasis/Destroy()
	if(pack)
		UnregisterSignal(pack, list(COMSIG_VACUUM_STORED, COMSIG_VACUUM_RELEASED))
		for(var/mob/living/occupant as anything in pack.occupants())
			remove_stasis(occupant)
	return ..()

/datum/vacuum_upgrade/stasis/proc/on_stored(datum/source, mob/living/occupant)
	SIGNAL_HANDLER
	apply_stasis(occupant)

/datum/vacuum_upgrade/stasis/proc/on_released(datum/source, mob/living/occupant)
	SIGNAL_HANDLER
	remove_stasis(occupant)

/datum/vacuum_upgrade/stasis/proc/apply_stasis(mob/living/occupant)
	if(!QDELETED(occupant))
		ADD_TRAIT(occupant, TRAIT_STASIS, REF(src))

/datum/vacuum_upgrade/stasis/proc/remove_stasis(mob/living/occupant)
	if(!QDELETED(occupant))
		REMOVE_TRAIT(occupant, TRAIT_STASIS, REF(src))

/// Heals living occupants over elapsed time without reviving them.
/datum/vacuum_upgrade/healing
	name = "healing"
	var/last_process // we'll do our own delta time! with blackjack! and hookers!

/datum/vacuum_upgrade/healing/on_install()
	last_process = world.time
	START_PROCESSING(SSobj, src)

/datum/vacuum_upgrade/healing/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/datum/vacuum_upgrade/healing/process(seconds_per_tick)
	if(QDELETED(pack))
		return PROCESS_KILL
	var/delta_time = (world.time - last_process) * 0.1
	last_process = world.time
	for(var/mob/living/occupant as anything in pack.occupants())
		if(occupant.stat != DEAD)
			occupant.heal_overall_damage(brute = 1 * delta_time, burn = 1 * delta_time)

/obj/item/disk/vacuum_upgrade
	name = "vacuum upgrade disk"
	desc = "A one-use upgrade disk for a slime vacuum pack."
	icon_state = "rndmajordisk"
	abstract_type = /obj/item/disk/vacuum_upgrade
	/// Upgrade datum installed by this disk.
	var/upgrade_type

/obj/item/disk/vacuum_upgrade/capacity
	name = "vacuum capacity upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/capacity

/obj/item/disk/vacuum_upgrade/range
	name = "vacuum range upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/range

/obj/item/disk/vacuum_upgrade/speed
	name = "vacuum speed upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/speed

/obj/item/disk/vacuum_upgrade/stasis
	name = "vacuum stasis upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/stasis

/obj/item/disk/vacuum_upgrade/healing
	name = "vacuum healing upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/healing

/obj/item/disk/vacuum_upgrade/pacify
	name = "vacuum pacify upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/pacify

/obj/item/disk/vacuum_upgrade/printer
	name = "vacuum printer upgrade disk"
	upgrade_type = /datum/vacuum_upgrade/printer
