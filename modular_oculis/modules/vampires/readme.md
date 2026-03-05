https://github.com/Monkestation/OculisStation/pull/48

## Vampire Antagonists

Module ID: VAMPIRES

### Description:

Adds a new antagonist, Vampires.

\[insert infodump here later\]

### TG Proc/File Changes:

- `code/game/objects/items/devices/scanners/sequence_scanner.dm`
  - `/obj/item/sequence_scanner/interact_with_atom`
- `code/modules/admin/sql_ban_system.dm`
  - `/datum/admins/proc/ban_panel`
- `code/modules/antagonists/brainwashing/brainwashing.dm`
  - `/proc/brainwash`
  - new proc: `/proc/unbrainwash`
- `code/modules/antagonists/heretic/influences.dm`
  - `/obj/effect/visible_heretic_influence/examine`
- `code/modules/mob/living/carbon/human/species_types/jellypeople.dm`
  - `/datum/species/jelly/proc/Cannibalize_Body`
- `code/modules/mob/living/carbon/carbon_defense.dm`
  - `/mob/living/carbon/proc/help_shake_act`
- `code/modules/mob/living/simple_animal/animal_defense.dm`
  - `/mob/living/simple_animal/attack_hand`
  - `/mob/living/simple_animal/attack_paw`

### Modular Overrides:

- `modular_oculis/master_files/code/datums/elements/art.dm`
  - `/datum/element/art/proc/apply_moodlet`
- `modular_oculis/master_files/code/game/machinery/newscaster/newscaster_data.dm`
  - `/datum/feed_network/New()`
- `modular_oculis/master_files/code/modules/reagents/reagent_containers/blood_pack.dm`
  - `/obj/item/reagent_containers/blood/attack`

### Defines:

- `code/__DEFINES/~~oculis_defines/dcs/signals/signals_mob/signals_mob_living.dm`
  - `COMSIG_LIVING_PET_ANIMAL`
  - `COMSIG_LIVING_HUG_CARBON`
  - `COMSIG_LIVING_APPRAISE_ART`
- `code/__DEFINES/~~oculis_defines/traits/declarations.dm`
  - `TRAIT_FAKEGENES`
  - `TRAIT_VAMPIRE_ALIGNED`
  - `TRAIT_SLIME_NO_CANNIBALIZE`
- `code/__DEFINES/~~oculis_defines/antagonists.dm`
  - `IS_VAMPIRE`
  - `IS_VASSAL`
- `code/__DEFINES/~~oculis_defines/crafting.dm`
  - `CAT_VAMPIRE`
- `code/__DEFINES/~~oculis_defines/factions.dm`
  - `FACTION_VAMPIRE`
- `code/__DEFINES/~~oculis_defines/language.dm`
  - `LANGUAGE_VAMPIRE`
  - `LANGUAGE_VASSAL`
- `code/__DEFINES/~~oculis_defines/role_preferences.dm`
  - `ROLE_VAMPIRE`
  - `ROLE_VAMPIRIC_ACCIDENT`
  - `ROLE_VAMPIRE_BREAKOUT`
  - `ROLE_VASSAL`
- `code/__DEFINES/~~oculis_defines/span.dm`
  - `span_awe`
- `code/__DEFINES/~~oculis_defines/vampires.dm`
  - Many vampire-related defines, too many to list

### Included files that are not contained in this module:

- `code/__HELPERS/~~oculis_helpers/view.dm`
- `modular_oculis/master_files/code/code/modules/client/client_colour.dm`
- `modular_oculis/master_files/code/game/objects/structures/crates_lockers/crates.dm`

### Credits:

- Absolucy
- TsunamiAnt
- TheCarnalest
- mrmanlikesbt
- Laikodaemon
- prolly many others I forgot
