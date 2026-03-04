/// Hides TRAIT_GENELESS.
#define TRAIT_FAKEGENES "fakegenes"

/// The user is "vampire aligned" - i.e a vampire or vassal.
/// Basically just check for `HAS_MIND_TRAIT(user, TRAIT_VAMPIRE_ALIGNED)` instead of `IS_VAMPIRE(user) || IS_VASSAL(user)`
#define TRAIT_VAMPIRE_ALIGNED "vampire_aligned"

/// Slimepeople with this trait will not lose limbs from low blood/nutrition.
#define TRAIT_SLIME_NO_CANNIBALIZE "slime_no_cannibalize"
