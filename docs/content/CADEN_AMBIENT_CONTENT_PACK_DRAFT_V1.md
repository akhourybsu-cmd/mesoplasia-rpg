# Caden Ambient Content Pack — Draft v1

> **DRAFT / NON-CANON / DO NOT IMPORT INTO GODOT**
>
> This document is a reviewable content-preproduction package. It does **not** replace the current `.tres` dialogue resources, does not assign released production IDs, and does not authorize changes to game scenes, scripts, resources, or localization files.

## Document control

| Field | Value |
| --- | --- |
| Working title | Caden Ambient Content Pack — Draft v1 |
| Content state | Draft / non-canon |
| Intended story state | Festival-preparation Caden, before the demonic invasion |
| Repository reviewed | `akhourybsu-cmd/mesoplasia-rpg` |
| Repository baseline | `main` at `f28f57bc09066a9c89d55d520c1f4ecc8473d78b` |
| Prepared | 2026-08-31 |
| Suggested repository path | `docs/content/CADEN_AMBIENT_CONTENT_PACK_DRAFT_V1.md` |
| Production import authorized | No |
| Stable IDs authorized | No; every `draft.*` identifier below is a review handle only |

## Source basis

This draft was prepared from the current repository’s:

- `docs/architecture/GAME_VISION_AND_SCOPE.md`
- `docs/CADEN_VERTICAL_SLICE.md`
- `docs/architecture/DATA_CONTENT_AND_IDS.md`
- `docs/MASTER_WORKFLOW.md`
- current Caden dialogue resources under `data/dialogue/caden/`

The live `.tres` files remain the implementation source of truth. The variants below are additive candidates, not replacements.

## Scope boundary

This pack supports the **welcoming, pre-invasion Caden baseline** only. It may reference:

- Caden as a cozy traveler town outside Terrebonne;
- the player as an out-of-towner;
- increased travel connected to the Festival of the Six;
- ordinary movement through the five existing zones;
- immediate, visible environmental details.

It must not establish:

- the cause or warning signs of the coming demonic invasion;
- Caden’s permanent institutions or political structure;
- named residents, businesses, families, factions, religions, or histories;
- final Festival ceremonies, symbols, schedules, or traditions;
- final items, currency, economy, classes, ancestries, combat, rewards, or dungeon lore;
- released content IDs, localization keys, or production dialogue-rotation behavior.

---

# 1. Voice and Tone Guide

## Core voice

Caden’s ambient writing should feel **grounded, warm, concise, and observant**. Characters speak about what is immediately around them: roads, crowds, rest, supplies, paths, noise, and the nearby capital. They do not deliver history lectures.

## Sentence style

- Prefer one or two short lines per interaction.
- Favor complete, natural sentences over faux-medieval fragments.
- Use contractions where they sound natural.
- Keep the average line easy to read in the existing dialogue box.
- Let humor come from ordinary inconvenience or observation, not sarcasm-heavy banter.
- Avoid catchphrases unless a permanent character is later approved.
- Avoid making every NPC address the player directly.
- Avoid assuming the player’s ancestry, gender, class, wealth, destination, or personality.

## Vocabulary

Prefer ordinary words:

- road
- path
- square
- market
- room
- rest
- pack
- supplies
- crowd
- traveler
- visitor
- local
- capital
- Festival

Use proper nouns sparingly:

- Caden
- Terrebonne
- Festival of the Six
- Halcyon Age only when context genuinely calls for it

## Festival balance

Across a zone’s ambient pool:

- roughly one-third may refer to the Festival or Terrebonne-bound traffic;
- roughly one-third may describe immediate Caden activity;
- roughly one-third should be ordinary local observation with no Festival reference.

The Festival should explain increased traffic without making every resident sound employed by, devoted to, or fully informed about it.

## Tone to avoid

- lore dumps;
- prophecy, omens, or invasion foreshadowing;
- modern internet slang;
- exaggerated dialect spelling;
- constant quips;
- melodramatic reverence for Terrebonne;
- unexplained fantasy proper nouns;
- claims that all visitors share one motive;
- dialogue that turns a generic role into a permanent biography.

---

# 2. Canon-Risk Coding

Every proposed line below has a risk marker.

| Code | Meaning | Use |
| --- | --- | --- |
| `C0` | Uses established facts, immediate observation, or harmless conversational framing | Still draft; may proceed to ordinary editorial review |
| `C1` | Softly implies a recurring behavior, local norm, personal routine, demand pattern, or environmental purpose not explicitly approved | Creator review required before canon/import |
| `C2` | Depends on a materially unresolved world, location, Festival, institution, or story fact | Hold until the named lore gate is resolved |

A line marked `C0` is **not automatically canon**. It simply carries no identified new factual claim.

---

# 3. Current Generic Role Inventory

| Zone | Existing role ID | Speaker label | Existing subject |
| --- | --- | --- | --- |
| Wayfarer’s Approach | `wayfarers_resting_traveler` | Traveler | Resting in Caden before continuing toward the Festival. |
| Wayfarer’s Approach | `wayfarers_continuing_traveler` | Traveler | Preparing to continue toward Terrebonne. |
| Wayfarer’s Approach | `wayfarers_roadside_local` | Local | A local accustomed to travelers passing through Caden. |
| Marketplace | `market_stall_attendant` | Merchant | Attending a busy market stall while supplies move quickly. |
| Marketplace | `market_shopper` | Shopper | A shopper navigating a busier-than-usual market. |
| Marketplace | `market_supply_traveler` | Traveler | Gathering supplies before continuing toward Terrebonne. |
| Town Square | `square_local_resident` | Local | A local observing Caden’s paths and people from the central square. |
| Town Square | `square_passing_visitor` | Visitor | A visitor passing through an unexpectedly active town square. |
| Residential Quarter | `residential_home_resident` | Resident | A resident near a home in Caden’s quieter district. |
| Residential Quarter | `residential_path_resident` | Resident | A resident using the quieter neighborhood paths. |
| Commons | `commons_local` | Local | A local enjoying the Commons as a quieter part of town. |

---

# 4. Zone Content Briefs

## Wayfarer’s Approach

**Identity:** Arrival, pause, preparation, and onward movement.

**Dialogue focus:** Travel fatigue, checking packs, finding rest, asking directions, watching traffic, and anticipation of Terrebonne.

**Environmental-storytelling guardrails:**

- Keep luggage, carts, benches, and roadside props in functional clusters rather than isolated scatter.
- Show temporary occupancy without assigning ownership to any pack, cart, room, or traveler.
- Let the road remain the dominant visual and conversational reference.
- Use Festival references as reasons for increased traffic, not as explanations of ceremonies or traditions.
- Avoid naming the inn, its staff, travel companies, routes beyond Terrebonne, or transport institutions.

## Marketplace

**Identity:** Compact, social, practical, and busier than usual.

**Dialogue focus:** Crowded lanes, browsing, supplies moving quickly, travelers preparing, and locals navigating visitor traffic.

**Environmental-storytelling guardrails:**

- Use ordinary goods without locking a canonical economy or merchandise taxonomy.
- Keep lanes and interaction spaces clear even when dialogue describes bustle.
- Avoid pricing, currency, shortages, guilds, merchant associations, and named shops.
- Vary Festival references so the entire market does not speak with one voice.
- Let some shoppers be ordinary locals rather than Festival travelers.

## Town Square

**Identity:** The connective social center where Caden’s paths and people cross.

**Dialogue focus:** Orientation, meeting, observing travelers, crossing between districts, and the contrast between a small town and the imagined capital.

**Environmental-storytelling guardrails:**

- Keep the square open and readable; ambient text should not assign a purpose to the reserved community space.
- Use benches, paths, lanterns, and passing NPCs as anchors for social observation.
- Treat the northeastern Terrebonne closure as a canon-risk item until its in-world status is approved.
- Do not establish a government building, monument, shrine, fountain, or official town institution through ambient text.
- Avoid lines that imply everyone in the square is Festival-bound.

## Residential Quarter

**Identity:** Quieter domestic edges, smaller paths, and relief from public bustle.

**Dialogue focus:** Hearing the town from a distance, keeping to quieter paths, tolerating visitors, and valuing ordinary home life.

**Environmental-storytelling guardrails:**

- Use porches, gates, flowers, yards, and thresholds without naming owners or families.
- Do not imply detailed household composition, wealth, professions, or ancestry.
- Keep Festival references indirect and less frequent than in Wayfarer’s Approach or the Marketplace.
- Avoid treating every fence as a legal or social boundary unless that convention is approved.
- Do not turn domestic props into quest hooks without a later content decision.

## Commons

**Identity:** Maintained open space that lets Caden feel quieter without leaving town.

**Dialogue focus:** Rest, distance from busy roads, hearing Caden from afar, and enjoying open space.

**Environmental-storytelling guardrails:**

- Favor simple observation over claims about official public use or town tradition.
- Keep the Quiet Green visually open; do not assign it a ceremony, sport, shrine, stage, or festival function.
- Use trees, flowers, rocks, and benches as calm environmental anchors.
- Use little or no Festival-specific exposition.
- Avoid defining who maintains the Commons or which institution controls it.

---

# 5. Ambient Dialogue Variant Library

> Each `draft.*` identifier is a review handle only. Do not migrate it into the content registry without a separate ID/localization decision.

## Wayfarer’s Approach — `wayfarers_resting_traveler` (Traveler)

**Current role function:** Resting in Caden before continuing toward the Festival.

### Variant 1 — `draft.caden.wayfarers_resting_traveler.01`

- **[C0]** “I meant to stop only for a moment.”
- **[C0]** “Caden makes it easy to linger.”

### Variant 2 — `draft.caden.wayfarers_resting_traveler.02`

- **[C0]** “The road has been busy since I arrived.”
- **[C1]** “A quiet seat is worth finding while one is open.”

### Variant 3 — `draft.caden.wayfarers_resting_traveler.03`

- **[C0]** “I am resting my feet before I think about Terrebonne.”
- **[C0]** “There is no sense arriving at the capital already worn out.”

### Variant 4 — `draft.caden.wayfarers_resting_traveler.04`

- **[C0]** “You can tell who has been traveling by the way they look at a bench.”
- **[C0]** “I probably had the same expression.”

### Variant 5 — `draft.caden.wayfarers_resting_traveler.05`

- **[C0]** “The town is livelier than I expected.”
- **[C0]** “Most of us seem to be headed the same direction.”

### Variant 6 — `draft.caden.wayfarers_resting_traveler.06`

- **[C0]** “I found a place to rest, which is enough for now.”
- **[C0]** “The Festival can wait until my legs forgive me.”


## Wayfarer’s Approach — `wayfarers_continuing_traveler` (Traveler)

**Current role function:** Preparing to continue toward Terrebonne.

### Variant 1 — `draft.caden.wayfarers_continuing_traveler.01`

- **[C0]** “I have checked my pack twice already.”
- **[C0]** “I will probably check it once more before I leave.”

### Variant 2 — `draft.caden.wayfarers_continuing_traveler.02`

- **[C0]** “Terrebonne is close enough to feel near and far at once.”
- **[C0]** “I would rather leave Caden prepared than hurry.”

### Variant 3 — `draft.caden.wayfarers_continuing_traveler.03`

- **[C1]** “The road is crowded, but no one seems eager to turn back.”
- **[C1]** “The Festival has everyone looking ahead.”

### Variant 4 — `draft.caden.wayfarers_continuing_traveler.04`

- **[C0]** “I keep finding one more thing I forgot.”
- **[C1]** “That is what a last stop is for.”

### Variant 5 — `draft.caden.wayfarers_continuing_traveler.05`

- **[C0]** “I am waiting for the traffic to thin.”
- **[C0]** “It has not listened to me yet.”

### Variant 6 — `draft.caden.wayfarers_continuing_traveler.06`

- **[C0]** “Caden is a good place to gather yourself.”
- **[C0]** “After this, it is on to the capital.”


## Wayfarer’s Approach — `wayfarers_roadside_local` (Local)

**Current role function:** A local accustomed to travelers passing through Caden.

### Variant 1 — `draft.caden.wayfarers_roadside_local.01`

- **[C0]** “New faces are easy to spot here.”
- **[C0]** “Most are looking toward the road before they have even finished resting.”

### Variant 2 — `draft.caden.wayfarers_roadside_local.02`

- **[C0]** “Caden knows how to make room for people passing through.”
- **[C1]** “Some stay an hour, and some stay the night.”

### Variant 3 — `draft.caden.wayfarers_roadside_local.03`

- **[C0]** “The road brings noise, conversation, and tired boots.”
- **[C1]** “This end of town would feel strange without them.”

### Variant 4 — `draft.caden.wayfarers_roadside_local.04`

- **[C0]** “You are not the only one finding your way around.”
- **[C1]** “It feels as though half the town is giving directions today.”

### Variant 5 — `draft.caden.wayfarers_roadside_local.05`

- **[C0]** “The closer the Festival gets, the busier this end of town feels.”
- **[C0]** “At least the road keeps everyone moving.”

### Variant 6 — `draft.caden.wayfarers_roadside_local.06`

- **[C0]** “Follow the road and Caden will explain itself.”
- **[C0]** “The square is where most of the paths come together.”


## Marketplace — `market_stall_attendant` (Merchant)

**Current role function:** Attending a busy market stall while supplies move quickly.

### Variant 1 — `draft.caden.market_stall_attendant.01`

- **[C1]** “People have been choosing the practical things first.”
- **[C1]** “No one wants to reach Terrebonne missing something obvious.”

### Variant 2 — `draft.caden.market_stall_attendant.02`

- **[C0]** “Take your time looking.”
- **[C0]** “The lane will still be busy when you are done.”

### Variant 3 — `draft.caden.market_stall_attendant.03`

- **[C0]** “A crowded market is better than an empty one.”
- **[C0]** “It simply leaves less room for elbows.”

### Variant 4 — `draft.caden.market_stall_attendant.04`

- **[C1]** “Travelers ask for supplies, and locals ask where the supplies went.”
- **[C0]** “That is a busy day in Caden.”

### Variant 5 — `draft.caden.market_stall_attendant.05`

- **[C0]** “The Festival brings plenty of footsteps through Caden.”
- **[C1]** “A few of them usually stop at the tables.”

### Variant 6 — `draft.caden.market_stall_attendant.06`

- **[C0]** “Nothing here is grand enough for the capital.”
- **[C0]** “That does not mean it is not useful.”


## Marketplace — `market_shopper` (Shopper)

**Current role function:** A shopper navigating a busier-than-usual market.

### Variant 1 — `draft.caden.market_shopper.01`

- **[C0]** “I came for one thing and found several reasons to keep looking.”
- **[C0]** “That is how the market gets you.”

### Variant 2 — `draft.caden.market_shopper.02`

- **[C0]** “The lanes feel narrower when everyone stops at once.”
- **[C0]** “I keep choosing the same crowded corner.”

### Variant 3 — `draft.caden.market_shopper.03`

- **[C0]** “I should have finished my errands earlier.”
- **[C1]** “Today, everyone had the same idea.”

### Variant 4 — `draft.caden.market_shopper.04`

- **[C0]** “The market is busy, but at least it is easy to see what is happening.”
- **[C0]** “You only have to watch where you step.”

### Variant 5 — `draft.caden.market_shopper.05`

- **[C0]** “I am not bound for the Festival.”
- **[C1]** “I am only trying to finish my usual shopping.”

### Variant 6 — `draft.caden.market_shopper.06`

- **[C0]** “Visitors look at the stalls.”
- **[C1]** “Locals look for the shortest way around them.”


## Marketplace — `market_supply_traveler` (Traveler)

**Current role function:** Gathering supplies before continuing toward Terrebonne.

### Variant 1 — `draft.caden.market_supply_traveler.01`

- **[C0]** “I would rather carry one useful thing too many than one too few.”
- **[C0]** “My shoulders may disagree later.”

### Variant 2 — `draft.caden.market_supply_traveler.02`

- **[C1]** “Caden is the last place I want to discover I forgot something.”
- **[C0]** “Better to notice now than on the road.”

### Variant 3 — `draft.caden.market_supply_traveler.03`

- **[C0]** “The capital is close, but close is not the same as ready.”
- **[C0]** “I am checking everything before I leave.”

### Variant 4 — `draft.caden.market_supply_traveler.04`

- **[C0]** “Every pack feels lighter before you start adding supplies.”
- **[C0]** “Mine has stopped feeling light.”

### Variant 5 — `draft.caden.market_supply_traveler.05`

- **[C0]** “The Festival may be the reason for the crowds.”
- **[C0]** “It is also the reason I am checking every strap.”

### Variant 6 — `draft.caden.market_supply_traveler.06`

- **[C0]** “I have room for necessities and very little else.”
- **[C0]** “That is probably for the best.”


## Town Square — `square_local_resident` (Local)

**Current role function:** A local observing Caden’s paths and people from the central square.

### Variant 1 — `draft.caden.square_local_resident.01`

- **[C0]** “Stand here long enough and you will see most of Caden pass by.”
- **[C0]** “The square has a way of collecting every path.”

### Variant 2 — `draft.caden.square_local_resident.02`

- **[C0]** “The roads meet here, but no one stays still for long.”
- **[C0]** “Not with this many travelers in town.”

### Variant 3 — `draft.caden.square_local_resident.03`

- **[C1]** “The square is busier whenever the market is busy.”
- **[C0]** “Today, that is not saying much.”

### Variant 4 — `draft.caden.square_local_resident.04`

- **[C0]** “You look like you are still learning the paths.”
- **[C0]** “The square is a good place to start.”

### Variant 5 — `draft.caden.square_local_resident.05`

- **[C0]** “Travelers bring energy with them.”
- **[C0]** “They also bring questions.”

### Variant 6 — `draft.caden.square_local_resident.06`

- **[C0]** “Caden feels small until everyone decides to cross the square together.”
- **[C0]** “Then it feels smaller still.”


## Town Square — `square_passing_visitor` (Visitor)

**Current role function:** A visitor passing through an unexpectedly active town square.

### Variant 1 — `draft.caden.square_passing_visitor.01`

- **[C0]** “I thought I was taking a shortcut.”
- **[C0]** “I have passed the same corner twice.”

### Variant 2 — `draft.caden.square_passing_visitor.02`

- **[C0]** “Everyone seems to know where they are going except me.”
- **[C0]** “That is reassuring, in a strange way.”

### Variant 3 — `draft.caden.square_passing_visitor.03`

- **[C0]** “I stopped to look around and nearly forgot I was on my way somewhere.”
- **[C0]** “Caden is good at slowing a person down.”

### Variant 4 — `draft.caden.square_passing_visitor.04`

- **[C0]** “Caden is smaller than Terrebonne must be.”
- **[C0]** “It still has more paths than I expected.”

### Variant 5 — `draft.caden.square_passing_visitor.05`

- **[C0]** “The Festival has filled the road with unfamiliar faces.”
- **[C0]** “I suppose mine is one of them.”

### Variant 6 — `draft.caden.square_passing_visitor.06`

- **[C1]** “This square makes a good meeting place.”
- **[C1]** “Now I only need the people I am meeting.”


## Residential Quarter — `residential_home_resident` (Resident)

**Current role function:** A resident near a home in Caden’s quieter district.

### Variant 1 — `draft.caden.residential_home_resident.01`

- **[C0]** “The market can keep its noise.”
- **[C0]** “I prefer hearing it from here.”

### Variant 2 — `draft.caden.residential_home_resident.02`

- **[C1]** “Visitors usually pass through this part more quietly.”
- **[C1]** “Perhaps the smaller paths encourage it.”

### Variant 3 — `draft.caden.residential_home_resident.03`

- **[C0]** “The roads are busy, but the homes still feel like home.”
- **[C0]** “That is enough for me.”

### Variant 4 — `draft.caden.residential_home_resident.04`

- **[C0]** “It is easy to forget how many people are in town.”
- **[C0]** “Then you walk toward the square.”

### Variant 5 — `draft.caden.residential_home_resident.05`

- **[C0]** “I do not mind the Festival crowds.”
- **[C1]** “I only mind when they forget where the public path ends.”

### Variant 6 — `draft.caden.residential_home_resident.06`

- **[C0]** “This end of Caden is not much for spectacle.”
- **[C0]** “That is why I like it.”


## Residential Quarter — `residential_path_resident` (Resident)

**Current role function:** A resident using the quieter neighborhood paths.

### Variant 1 — `draft.caden.residential_path_resident.01`

- **[C0]** “These paths are quieter than the main road.”
- **[C1]** “That is usually the point.”

### Variant 2 — `draft.caden.residential_path_resident.02`

- **[C0]** “You can hear the market without having to stand in it.”
- **[C0]** “That is close enough for me.”

### Variant 3 — `draft.caden.residential_path_resident.03`

- **[C1]** “Visitors tend to slow down here.”
- **[C0]** “The paths do not reward rushing.”

### Variant 4 — `draft.caden.residential_path_resident.04`

- **[C1]** “I take the longer way when the square is crowded.”
- **[C0]** “It is still not a very long way.”

### Variant 5 — `draft.caden.residential_path_resident.05`

- **[C0]** “Caden has busy corners and quiet ones.”
- **[C0]** “This is one of the quiet ones.”

### Variant 6 — `draft.caden.residential_path_resident.06`

- **[C0]** “The Festival feels close even here.”
- **[C0]** “More footsteps carry farther than people expect.”


## Commons — `commons_local` (Local)

**Current role function:** A local enjoying the Commons as a quieter part of town.

### Variant 1 — `draft.caden.commons_local.01`

- **[C0]** “The commons gives the town room to breathe.”
- **[C0]** “Not every corner needs to be busy.”

### Variant 2 — `draft.caden.commons_local.02`

- **[C0]** “It is quiet here without being far from anything.”
- **[C0]** “That is the best sort of quiet.”

### Variant 3 — `draft.caden.commons_local.03`

- **[C1]** “Some people come here to rest before facing the roads again.”
- **[C0]** “I cannot blame them.”

### Variant 4 — `draft.caden.commons_local.04`

- **[C0]** “You can still hear Caden from here.”
- **[C0]** “It simply sounds less hurried.”

### Variant 5 — `draft.caden.commons_local.05`

- **[C0]** “The Festival has made the town louder.”
- **[C0]** “The commons has not taken it personally.”

### Variant 6 — `draft.caden.commons_local.06`

- **[C0]** “There is no trick to this place.”
- **[C0]** “It is simply a little space and a little quiet.”


---

# 6. Optional Inspectable and Environmental Text Concepts

> These concepts are not authorization to add interaction nodes. They are possible text for already approved visible objects or future inspectable hooks.

| # | Zone | Draft ID | Object | Candidate text | Risk | Audit note |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | Wayfarer’s Approach | `draft.inspect.wayfarers.inn_porch` | Inn porch | “The porch has been kept clear despite the steady traffic. The entrance remains easy to reach.” | C1 | Implies active maintenance during the visitor influx. |
| 2 | Wayfarer’s Approach | `draft.inspect.wayfarers.luggage_stack` | Luggage stack | “Packs and rolled blankets sit in a careful pile, ready to be shouldered again.” | C0 | No additional factual implication identified. |
| 3 | Wayfarer’s Approach | `draft.inspect.wayfarers.parked_cart` | Parked cart | “The cart has been drawn aside, leaving the main road open.” | C0 | No additional factual implication identified. |
| 4 | Wayfarer’s Approach | `draft.inspect.wayfarers.worn_road_edge` | Worn road edge | “The packed earth is worn smooth where travelers leave the road for Caden.” | C0 | No additional factual implication identified. |
| 5 | Marketplace | `draft.inspect.market.stall_canopy` | Stall canopy | “The cloth is tied high enough to keep the lane open beneath it.” | C0 | No additional factual implication identified. |
| 6 | Marketplace | `draft.inspect.market.empty_crates` | Empty crates | “Empty crates wait beneath the counter, stacked where they will not narrow the lane.” | C0 | No additional factual implication identified. |
| 7 | Marketplace | `draft.inspect.market.baskets` | Nested baskets | “The baskets are nested by size, ready to be filled or carried away.” | C1 | Suggests a likely use but does not establish specific merchandise. |
| 8 | Marketplace | `draft.inspect.market.supply_bundle` | Bound supply bundle | “The straps are pulled tight. This bundle looks prepared for the road rather than display.” | C1 | Assigns a travel purpose to a generic prop. |
| 9 | Town Square | `draft.inspect.square.paving` | Plaza paving | “The paving is worn most where Caden’s paths meet.” | C0 | No additional factual implication identified. |
| 10 | Town Square | `draft.inspect.square.bench` | Square bench | “A pause here offers a view of every road into the square.” | C0 | No additional factual implication identified. |
| 11 | Town Square | `draft.inspect.square.festival_cloth` | Blue-and-cream cloth | “Blue-and-cream cloth has been tied neatly to the fence. It looks temporary.” | C1 | Treats the approved visual decoration as an in-world temporary Festival detail. |
| 12 | Town Square | `draft.inspect.square.terrebonne_road` | Road toward Terrebonne | “The road turns toward Terrebonne, but the way ahead is closed.” | C2 | The in-world reason, duration, and even permanence of the closure remain unresolved; current blockage may still be development-only. |
| 13 | Residential Quarter | `draft.inspect.residential.flower_box` | Window flower box | “The flowers have been kept low enough not to crowd the window.” | C1 | Implies deliberate household maintenance. |
| 14 | Residential Quarter | `draft.inspect.residential.yard_gate` | Small yard gate | “The gate marks the edge of a small yard; the public path continues beyond it.” | C1 | Defines public/private spatial use that has not been formally approved. |
| 15 | Residential Quarter | `draft.inspect.residential.doorstep` | Worn doorstep | “The stone at the threshold is smoother than the path around it.” | C0 | No additional factual implication identified. |
| 16 | Residential Quarter | `draft.inspect.residential.garden_patch` | Garden patch | “The planting is neat and modest, more cared for than ornamental.” | C1 | Characterizes the intent of the planting. |
| 17 | Commons | `draft.inspect.commons.shade_tree` | Shade tree | “The broad branches cast more shade than the small trunk suggests.” | C0 | No additional factual implication identified. |
| 18 | Commons | `draft.inspect.commons.wildflowers` | Wildflower patch | “The flowers grow in a loose patch rather than a planted row.” | C0 | No additional factual implication identified. |
| 19 | Commons | `draft.inspect.commons.bench` | Commons bench | “From here, the sounds of Caden seem close without feeling crowded.” | C0 | No additional factual implication identified. |
| 20 | Commons | `draft.inspect.commons.rock_cluster` | Rock cluster | “The stones sit where the grass begins to thicken toward the edge of the commons.” | C0 | No additional factual implication identified. |

---

# 7. Canon-Risk Audit — Elevated Lines

The following lines contain a `C1` or `C2` implication and require explicit review before production use. All other lines are tagged `C0` in their source sections.

| Source | Variant | Line | Candidate text | Risk | Why it needs review |
| --- | ---: | ---: | --- | --- | --- |
| `wayfarers_resting_traveler` | 2 | 2 | “A quiet seat is worth finding while one is open.” | C1 | Implies competition for public seating during the current influx. |
| `wayfarers_continuing_traveler` | 3 | 1 | “The road is crowded, but no one seems eager to turn back.” | C1 | Generalizes the intentions of the current travelers. |
| `wayfarers_continuing_traveler` | 3 | 2 | “The Festival has everyone looking ahead.” | C1 | Uses broad “everyone” language about Festival motivation. |
| `wayfarers_continuing_traveler` | 4 | 2 | “That is what a last stop is for.” | C1 | Frames Caden as the final practical stop before Terrebonne. |
| `wayfarers_roadside_local` | 2 | 2 | “Some stay an hour, and some stay the night.” | C1 | Implies a recurring pattern of short and overnight stays. |
| `wayfarers_roadside_local` | 3 | 2 | “This end of town would feel strange without them.” | C1 | Suggests traveler traffic is a defining long-term feature of the district. |
| `wayfarers_roadside_local` | 4 | 2 | “It feels as though half the town is giving directions today.” | C1 | Hyperbolically implies widespread local behavior. |
| `market_stall_attendant` | 1 | 1 | “People have been choosing the practical things first.” | C1 | Implies a specific purchasing trend. |
| `market_stall_attendant` | 1 | 2 | “No one wants to reach Terrebonne missing something obvious.” | C1 | Generalizes traveler purchasing motives. |
| `market_stall_attendant` | 4 | 1 | “Travelers ask for supplies, and locals ask where the supplies went.” | C1 | Implies current demand is affecting local availability. |
| `market_stall_attendant` | 5 | 2 | “A few of them usually stop at the tables.” | C1 | Implies a recurring relationship between Festival traffic and stall custom. |
| `market_shopper` | 3 | 2 | “Today, everyone had the same idea.” | C1 | Hyperbolically implies shared shopping behavior. |
| `market_shopper` | 5 | 2 | “I am only trying to finish my usual shopping.” | C1 | Implies this role has a stable personal shopping routine. |
| `market_shopper` | 6 | 2 | “Locals look for the shortest way around them.” | C1 | Generalizes a local behavioral pattern. |
| `market_supply_traveler` | 2 | 1 | “Caden is the last place I want to discover I forgot something.” | C1 | Frames Caden as the last practical preparation stop. |
| `square_local_resident` | 3 | 1 | “The square is busier whenever the market is busy.” | C1 | Implies a recurring relationship between district activity levels. |
| `square_passing_visitor` | 6 | 1 | “This square makes a good meeting place.” | C1 | Suggests an established social use for the square. |
| `square_passing_visitor` | 6 | 2 | “Now I only need the people I am meeting.” | C1 | Gives the generic visitor a temporary personal circumstance. |
| `residential_home_resident` | 2 | 1 | “Visitors usually pass through this part more quietly.” | C1 | Implies a recurring visitor behavior in the residential district. |
| `residential_home_resident` | 2 | 2 | “Perhaps the smaller paths encourage it.” | C1 | Suggests the paths influence behavior. |
| `residential_home_resident` | 5 | 2 | “I only mind when they forget where the public path ends.” | C1 | Implies a local norm about public and private path boundaries. |
| `residential_path_resident` | 1 | 2 | “That is usually the point.” | C1 | Implies an intentional or customary function for the paths. |
| `residential_path_resident` | 3 | 1 | “Visitors tend to slow down here.” | C1 | Generalizes visitor behavior. |
| `residential_path_resident` | 4 | 1 | “I take the longer way when the square is crowded.” | C1 | Gives the generic role a habitual route choice. |
| `commons_local` | 3 | 1 | “Some people come here to rest before facing the roads again.” | C1 | Suggests a recurring public use of the Commons. |
| `draft.inspect.wayfarers.inn_porch` | inspect | 1 | “The porch has been kept clear despite the steady traffic. The entrance remains easy to reach.” | C1 | Implies active maintenance during the visitor influx. |
| `draft.inspect.market.baskets` | inspect | 1 | “The baskets are nested by size, ready to be filled or carried away.” | C1 | Suggests a likely use but does not establish specific merchandise. |
| `draft.inspect.market.supply_bundle` | inspect | 1 | “The straps are pulled tight. This bundle looks prepared for the road rather than display.” | C1 | Assigns a travel purpose to a generic prop. |
| `draft.inspect.square.festival_cloth` | inspect | 1 | “Blue-and-cream cloth has been tied neatly to the fence. It looks temporary.” | C1 | Treats the approved visual decoration as an in-world temporary Festival detail. |
| `draft.inspect.square.terrebonne_road` | inspect | 1 | “The road turns toward Terrebonne, but the way ahead is closed.” | C2 | The in-world reason, duration, and even permanence of the closure remain unresolved; current blockage may still be development-only. |
| `draft.inspect.residential.flower_box` | inspect | 1 | “The flowers have been kept low enough not to crowd the window.” | C1 | Implies deliberate household maintenance. |
| `draft.inspect.residential.yard_gate` | inspect | 1 | “The gate marks the edge of a small yard; the public path continues beyond it.” | C1 | Defines public/private spatial use that has not been formally approved. |
| `draft.inspect.residential.garden_patch` | inspect | 1 | “The planting is neat and modest, more cared for than ornamental.” | C1 | Characterizes the intent of the planting. |

## High-risk exclusions deliberately not drafted

The following content was excluded rather than written and then flagged:

- any warning, rumor, omen, or hint of the demonic invasion;
- any explanation for the Terrebonne road closure;
- any claim about Festival ceremonies, dates, sacred objects, official colors, or symbols;
- any named inn, shop, official, family, district institution, or civic authority;
- any specific currency, prices, resource shortages, or permanent market inventory;
- any claim about ancestry demographics or social relations;
- any line that establishes a class, quest reward, combat role, or expedition system.

---

# 8. Terminology and Capitalization Glossary

| Term | Usage rule | Status |
| --- | --- | --- |
| **Caden** | Capitalized. Canonical spelling. Never use “Kaiden.” | Established |
| **Terrebonne** | Capitalized. The nearby capital city; not currently playable. | Established |
| **Festival of the Six** | Full title capitalized. “the Festival” may be used after the full context is clear. | Established, details restricted |
| **Halcyon Age** | Capitalized historical era. Current game era. | Established |
| **Age of Reckoning** | Capitalized historical era; it has already ended. | Established |
| **Reckoning** | Capitalized when referring to the historical conflict/era. Avoid casual ambient exposition unless approved. | Established, avoid overuse |
| **Wayfarer’s Approach** | Use curly apostrophe in prose. Confirm whether this is an in-world district name or only a development/display label. | Label status TBD |
| **Marketplace** | Capitalized when used as the zone/display name; lowercase for a generic marketplace. | Display status partly established |
| **Town Square** | Capitalized when used as the zone/display name; lowercase for a generic square. | Display status partly established |
| **Residential Quarter** | Current prose label. Production scene is `Residential`; final in-world display name remains open. | Display name TBD |
| **Commons** | Capitalized when used as the zone/display name; lowercase when used generically. | Display status partly established |
| **the capital** | Lowercase descriptive shorthand for Terrebonne after the city is established in context. | Established usage |
| **out-of-towner** | Hyphenated. Describes the opening player premise; avoid turning it into a permanent identity. | Established |
| **Edenite** | Capitalized world material. Do not imply mechanics, ownership, ritual meaning, or common speech patterns in this pack. | Established term, ambient use restricted |
| **DRAFT / NON-CANON** | Required label for all material in this document until creator approval and content-contract review. | Workflow rule |

---

# 9. Lore and Content Questions Requiring Creator Approval

| ID | Question |
| --- | --- |
| `ZONE-001` | Are Wayfarer’s Approach, Town Square, Marketplace, Residential Quarter, and Commons actual in-world local names, player-facing map labels, or development labels only? |
| `INN-001` | Does the unnamed inn receive a canonical name, and may ambient dialogue identify it as an inn before that name is approved? |
| `FEST-001` | How often does the Festival of the Six occur, and how close is it when the opening begins? |
| `FEST-002` | Do Caden residents normally say “Festival of the Six,” shorten it to “the Festival,” or use another approved local shorthand? |
| `FEST-003` | Which Festival preparations are visible or commonly discussed in Caden without revealing unapproved ceremonies or traditions? |
| `FEST-004` | Are blue-and-cream ribbons canonical Festival decoration, or only an approved provisional visual treatment? |
| `TRAVEL-001` | How long does travel from Caden to Terrebonne normally take, and is Caden truly the last stopping point before the capital? |
| `TRAVEL-002` | What forms of transport and road traffic are ordinary between Caden and Terrebonne? |
| `TRAVEL-003` | Are rooms genuinely scarce during the Festival build-up, or is the current line about filling rooms only development flavor? |
| `ROAD-001` | Is the northeastern Terrebonne road canonically closed in the opening, or is that barrier only a current-build boundary? |
| `ROAD-002` | If the road is canonically closed, what non-spoiler explanation may ordinary NPCs give before the invasion? |
| `MARKET-001` | What broad categories of goods are canonical in Caden’s Marketplace? |
| `MARKET-002` | What currency or exchange language should dialogue use once commerce is implemented? |
| `MARKET-003` | Are the market stalls permanent, seasonal, or expanded temporarily for Festival traffic? |
| `CADEN-001` | What civic authority, if any, governs Caden, and should ordinary dialogue mention it? |
| `CADEN-002` | What relationship does Caden have to Terrebonne’s jurisdiction, services, and defenses? |
| `CADEN-003` | What local foods, drinks, lodging customs, greetings, and idioms are approved for ordinary flavor? |
| `CADEN-004` | Which ancestries are common among Caden residents and Festival travelers, and how visible should that diversity be in dialogue? |
| `COMMONS-001` | Is the Commons officially maintained public land, an informal green, or something else? |
| `RES-001` | Are yards and paths governed by recognizable public/private customs that residents may reference? |
| `EDENITE-001` | How ordinary are Edenite fixtures in daily Halcyon-Age life, and would locals comment on them at all? |
| `INVASION-001` | Which pre-invasion ambient lines remain valid after the first breach, and which must be replaced immediately? |
| `INVASION-002` | What warning signs, if any, may appear before the demonic invasion without spoiling the intended reveal? |
| `CONTENT-001` | Will ambient dialogue rotate randomly, advance by campaign state, respond to zone activity, or remain fixed in the first playable build? |
| `CONTENT-002` | What localization constraints—maximum line length, reading level, text box capacity, and punctuation style—should become production rules? |

---

# 10. Editorial Review Checklist

## Voice review

- [ ] Lines sound conversational rather than expository.
- [ ] No NPC speaks with an unexplained dialect or archaic affectation.
- [ ] No role sounds like a named permanent character unless intentionally promoted later.
- [ ] Festival references are distributed rather than repeated by everyone.
- [ ] The player is not assigned ancestry, gender, class, wealth, or personality.

## Canon review

- [ ] Every `C1` line is explicitly approved, revised, or rejected.
- [ ] Every `C2` line remains blocked until its lore gate is resolved.
- [ ] No line invents Festival rites, iconography, history, or schedule.
- [ ] No line invents Caden government, institutions, families, businesses, or religion.
- [ ] No pre-invasion line foreshadows the demonic breach without deliberate approval.
- [ ] Zone labels are confirmed as in-world or development-facing before NPCs use them aloud.

## Implementation-readiness review

- [ ] Dialogue rotation behavior has been approved.
- [ ] Production stable IDs and localization keys have been approved.
- [ ] Maximum line length and wrapping limits have been tested at 640×360.
- [ ] Existing live dialogue is either retained, replaced, or merged through an explicit content migration.
- [ ] Draft text is converted through a separate Codex task; no manual ad hoc `.tres` edits.
- [ ] Campaign-state eligibility is defined before pre-invasion lines are used after the breach.
- [ ] Content-registry validation exists before IDs are treated as released.

---

# 11. Approval Worksheet

Use one status per item:

- `APPROVE`
- `APPROVE WITH EDIT`
- `HOLD`
- `REJECT`
- `PROMOTE TO NAMED CHARACTER REVIEW`

## Dialogue roles

| Role ID | Variants reviewed | Decision | Notes |
| --- | ---: | --- | --- |
| `wayfarers_resting_traveler` | 0/6 |  |  |
| `wayfarers_continuing_traveler` | 0/6 |  |  |
| `wayfarers_roadside_local` | 0/6 |  |  |
| `market_stall_attendant` | 0/6 |  |  |
| `market_shopper` | 0/6 |  |  |
| `market_supply_traveler` | 0/6 |  |  |
| `square_local_resident` | 0/6 |  |  |
| `square_passing_visitor` | 0/6 |  |  |
| `residential_home_resident` | 0/6 |  |  |
| `residential_path_resident` | 0/6 |  |  |
| `commons_local` | 0/6 |  |  |

## Inspectables

| Range | Items reviewed | Decision | Notes |
| --- | ---: | --- | --- |
| Wayfarer’s Approach 1–4 | 0/4 |  |  |
| Marketplace 5–8 | 0/4 |  |  |
| Town Square 9–12 | 0/4 |  |  |
| Residential Quarter 13–16 | 0/4 |  |  |
| Commons 17–20 | 0/4 |  |  |

---

# 12. Future Conversion Gate

Do not convert this pack into `.tres` resources until all of the following are true:

1. creator review has selected the approved lines;
2. production dialogue rotation/state behavior is defined;
3. content IDs and localization-key format are approved;
4. the pre-invasion campaign state is represented cleanly;
5. line-length and UI wrapping validation is complete;
6. a Codex prompt is written against the current GitHub `main`;
7. the conversion task includes content validation, regression tests, a rollback plan, and no unrelated gameplay changes.

Suggested future task title:

`CONTENT-CADEN-001 — Convert approved pre-invasion ambient dialogue into versioned content definitions`

That task is intentionally **not authorized by this draft**.
