/**
 * Sol defines
 */
///How long Sol will last until it's night again.
#define TIME_BLOODSUCKER_DAY 180
///Base time nighttime should be in for, until Sol rises.
// Can't put defines in defines, so we have to use deciseconds.
#define TIME_BLOODSUCKER_NIGHT_MAX 1320 // 22 minutes
#define TIME_BLOODSUCKER_NIGHT_MIN 1020 // 17 minutes

///Time left to send an alert to Bloodsuckers about an incoming Sol.
#define TIME_BLOODSUCKER_DAY_WARN 90
///Time left to send an urgent alert to Bloodsuckers about an incoming Sol.
#define TIME_BLOODSUCKER_DAY_FINAL_WARN 30
///Time left to alert that Sol is rising.
#define TIME_BLOODSUCKER_BURN_INTERVAL 5

///How much time Sol can be 'off' by, keeping the time inconsistent.
#define TIME_BLOODSUCKER_SOL_DELAY 90

/**
 * Sol signals & Defines
 */
#define COMSIG_SOL_RANKUP_BLOODSUCKERS "comsig_sol_rankup_bloodsuckers"
#define COMSIG_SOL_RISE_TICK "comsig_sol_rise_tick"
#define COMSIG_SOL_NEAR_START "comsig_sol_near_start"
#define COMSIG_SOL_END "comsig_sol_end"
///Sent when a warning for Sol is meant to go out: (danger_level, vampire_warning_message, ghoul_warning_message)
#define COMSIG_SOL_WARNING_GIVEN "comsig_sol_warning_given"
