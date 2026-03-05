/datum/dynamic_ruleset/roundstart/vampire
	name = "Vampires"
	config_tag = "Roundstart Vampire"
	preview_antag_datum = /datum/antagonist/vampire
	pref_flag = ROLE_VAMPIRE
	weight = 8
	min_pop = 15
	min_antag_cap = 2
	min_antag_cap = list("denominator" = 15, "offset" = 2)
	blacklisted_roles = list(
		JOB_CURATOR,
	)

/datum/dynamic_ruleset/roundstart/vampire/assign_role(datum/mind/candidate)
	candidate.add_antag_datum(/datum/antagonist/vampire)

/datum/dynamic_ruleset/midround/from_living/vampire
	name = "Vampire"
	config_tag = "Midround Vampire"
	preview_antag_datum = /datum/antagonist/vampire
	midround_type = LIGHT_MIDROUND
	pref_flag = ROLE_VAMPIRIC_ACCIDENT
	jobban_flag = ROLE_VAMPIRE
	weight = 8
	min_pop = 15
	blacklisted_roles = list(
		JOB_CURATOR,
	)

/datum/dynamic_ruleset/midround/from_living/vampire/assign_role(datum/mind/candidate)
	candidate.add_antag_datum(/datum/antagonist/vampire)

/datum/dynamic_ruleset/latejoin/vampire
	name = "Vampire"
	config_tag = "Latejoin Vampire"
	preview_antag_datum = /datum/antagonist/vampire
	pref_flag = ROLE_VAMPIRE_BREAKOUT
	jobban_flag = ROLE_VAMPIRE
	weight = 8
	min_pop = 15
	blacklisted_roles = list(
		JOB_CURATOR,
	)

/datum/dynamic_ruleset/latejoin/vampire/assign_role(datum/mind/candidate)
	candidate.add_antag_datum(/datum/antagonist/vampire)
