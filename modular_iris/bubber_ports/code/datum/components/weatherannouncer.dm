/datum/component/weather_announcer
	var/warning_range_low = 60
	var/warning_range_high = TIME_VAMPIRE_DAY_WARN_1

/datum/component/weather_announcer/Initialize(
	state_normal,
	state_warning,
	state_danger,
	radar_z_trait,
)
	. = ..()
	RegisterSignal(SSsol, COMSIG_SOL_NEAR_START, PROC_REF(on_daylight_warning))

/datum/component/weather_announcer/Destroy(force)
	UnregisterSignal(SSsol, COMSIG_SOL_NEAR_START)
	return ..()

/datum/component/weather_announcer/proc/on_daylight_warning(datum/controller/subsystem/processing/sunlight)
	var/variability = rand(warning_range_low, warning_range_high)
	addtimer(CALLBACK(src, PROC_REF(warn_user)), variability)

/datum/component/weather_announcer/proc/warn_user()
	var/list/messages = list(
		"Detecting solar activity. Seek cover if vulnerable.",
		"Warning: Solar flares detected incoming within [TIME_VAMPIRE_DAY_WARN_1] seconds.",
		"Solar activity imminent within [TIME_VAMPIRE_DAY_WARN_1] seconds. Please find shelter.",
	)
	var/atom/movable/speaker = parent
	speaker?.say(pick(messages))
