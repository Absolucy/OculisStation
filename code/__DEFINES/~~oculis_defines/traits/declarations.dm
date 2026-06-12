// BEGIN TRAIT DEFINE

/// The trait that determines if someone has the traditional thinker quirk.
#define TRAIT_TRADITIONAL_THINKER "trait_traditional_thinker"
#define TRAIT_PINNED "pinned"

/// When checking who receives mail, people with this trait receive none.
#define TRAIT_NO_MAIL "trait_no_mail"

/// Used in the ANTIMEMETICS module.
#define TRAIT_AMNESTICS "trait_amnestics"
#define TRAIT_MNESTICS "trait_mnestics"

/// Hides TRAIT_GENELESS.
#define TRAIT_FAKEGENES "fakegenes"

/// The user is "vampire aligned" - i.e a vampire or vassal.
/// Basically just check for `HAS_MIND_TRAIT(user, TRAIT_VAMPIRE_ALIGNED)` instead of `IS_VAMPIRE(user) || IS_VASSAL(user)`
#define TRAIT_VAMPIRE_ALIGNED "vampire_aligned"

/// Slimepeople with this trait will not lose limbs from low blood/nutrition.
#define TRAIT_SLIME_NO_CANNIBALIZE "slime_no_cannibalize"

// END TRAIT DEFINES
