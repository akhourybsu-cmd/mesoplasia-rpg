# Mesoplasia RPG — Caden Starting-Town Vertical Slice v1

## Purpose

This document is the implementation brief for the first playable slice of the Mesoplasia RPG. It is intentionally narrow. The goal is to begin building a stable, testable game in Godot without requiring the full Mesoplasia canon or the capital city of Terrebonne to be implemented.

Codex must read and obey the repository `AGENTS.md` and `docs/TECHNICAL_STANDARDS.md` before acting on this document.

---

## 1. Current Game Context

### Historical Era
- The game takes place during the **Halcyon Age**.
- The **Age of Reckoning has already ended**.
- The Reckoning is historical background, not the active crisis of this opening slice.

### Opening Location
- The player begins in **Caden**, a small town just outside the capital city of **Terrebonne**.
- Caden is the only playable settlement required for the current development scope.
- **Terrebonne is not playable yet.**
- The player should not enter or travel to Terrebonne during this vertical slice.

### Player Premise
- The player character is an **out-of-towner**.
- The player has stopped in Caden before attending the **Festival of the Six** in Terrebonne.
- For the present build, the festival is background motivation and ambient world context only.
- Do not build the festival, the capital, festival events, major ceremonies, or related large-scale systems yet.

### Spelling Consistency
- The starting town is canonically spelled **Caden**.
- Use **Caden** consistently in all game files, documentation, dialogue, map labels, and future implementation.
- If any repository content uses another spelling, flag it for correction rather than propagating it.

---

## 2. Caden — Town Identity

Caden should feel like the prototypical welcoming starting town in a classic top-down adventure RPG.

### Core Character
- Cozy
- Warm
- Safe
- Modest
- Easy to navigate
- Lived-in rather than grand
- Active because travelers pass through on their way to Terrebonne

### Architecture
- Cabin-like, homey buildings
- No structure should be greater than two stories
- Wood, stone, porches, chimneys, simple signage, fences, greenery, and similar rustic details are appropriate
- Avoid monumental, aristocratic, or highly urban architecture
- Caden should clearly contrast with the scale the player imagines Terrebonne to have

### Marketplace
- Caden has a cute, compact central marketplace
- The marketplace should function as the town's visual and social heart
- It can include simple stalls, signs, travelers, locals, and merchants
- Festival-bound traffic can make the marketplace feel a little busier than normal

### Function
Caden is a resting place for people preparing to enter Terrebonne. It is not merely an isolated farming village.

Travelers may reasonably:
- rest
- eat
- shop
- gather supplies
- ask for directions
- wait for companions
- arrange transport
- hear rumors or conversation about the capital and festival

Do not invent major political institutions, noble families, industries, religious structures, or historical events for Caden unless explicitly approved.

---

## 3. Festival of the Six — Current Scope

For this vertical slice, the Festival of the Six should exist primarily as **subtext**.

NPCs may naturally reference:
- traveling to the festival
- crowds heading toward Terrebonne
- excitement about the event
- rooms or supplies being in higher demand
- meeting family or friends in the capital
- preparing for the trip

The festival should help explain why an out-of-town player is in Caden and why the town has extra visitors.

### Do Not Yet Implement
- Terrebonne festival maps
- festival ceremonies
- festival minigames
- festival quest chains
- major festival lore exposition
- the Pearl or other large festival events
- relic displays
- city-wide crowd systems
- capital-city travel

Festival references should be light, natural, and optional rather than an exposition dump.

---

## 4. Technical Baseline

Follow the existing repository standards.

Current baseline:
- Godot 4.7
- 2D
- GDScript
- Compatibility renderer
- Internal viewport: 640×360
- Initial desktop window: 1280×720
- Stretch mode: `viewport`
- Stretch aspect: `keep`
- Stretch scale mode: `integer`
- Nearest-neighbor texture filtering
- Initial world tile standard: 32×32
- Four-direction movement initially
- Named Input Map actions
- WASD and arrow-key movement
- No unapproved autoloads
- No external dependencies without approval

The repository `AGENTS.md` remains authoritative for coding and architecture rules.

---

## 5. First Vertical-Slice Goal

The immediate goal is not to make a full RPG chapter.

The goal is to create a small, clean, expandable slice where the player can:

1. Spawn in Caden.
2. Move around the town.
3. Collide correctly with the environment.
4. Have a camera that follows the player appropriately.
5. Approach and interact with NPCs or simple world objects.
6. Read short dialogue.
7. Experience Caden as a coherent starting location.
8. Hear occasional references to the Festival of the Six and Terrebonne.
9. Remain entirely within Caden for the current build.

All visuals may initially use placeholders or simple development art.

---

## 6. Recommended Implementation Order

### Milestone A — Player Foundation
Create a reusable player scene.

Requirements:
- Use a suitable Godot 2D character body.
- Use named Input Map actions already defined by the project.
- Implement four-direction movement.
- Keep movement code modular and small.
- Use placeholder visuals only.
- Add collision.
- Add a basic camera-follow setup.
- Do not add combat, inventory, stats, equipment, or animation systems yet.

### Milestone B — Caden Greybox
Create a separate Caden world scene using placeholder geometry or simple development tiles.

The initial greybox should establish:
- a central marketplace
- a main road
- a small inn/resting place
- several cabin-like buildings
- paths between buildings
- a visible or clearly indicated road toward Terrebonne
- boundaries preventing the player from leaving the current playable space

Do not spend time on final artwork.

### Milestone C — Interaction System
Create a small reusable interaction foundation.

It should eventually support:
- NPC conversation
- signs
- doors
- inspectable objects
- vendors

For the first pass, interaction with one test NPC or object is sufficient.

Do not build a giant generalized framework before it is needed.

### Milestone D — Dialogue Foundation
Create a reusable dialogue presentation system capable of:
- showing speaker name
- displaying dialogue text
- advancing through multiple lines
- closing cleanly
- temporarily preventing unwanted player movement during dialogue if appropriate

The architecture should be extendable later for choices and branching, but branching is not required for the first implementation.

Narrative content should be stored separately from general-purpose dialogue code where practical.

### Milestone E — First Caden Population
Once the systems above work, add a small set of placeholder NPC roles such as:
- innkeeper
- marketplace merchant
- local resident
- traveler heading to the festival
- traveler returning from or preparing for Terrebonne

These are roles, not permission to invent permanent names, biographies, factions, or canon.

### Milestone F — Simple Opening Loop
Create a very small opening objective that encourages the player to explore Caden.

Do not invent the main plot.

A temporary development objective may be used purely to test:
- navigation
- interaction
- dialogue
- objective completion

If an objective would establish story canon, stop and request approval first.

---

## 7. Current Non-Goals

Do not implement any of the following unless separately authorized:

- Terrebonne
- travel to the capital
- full Festival of the Six content
- combat
- enemies
- bosses
- leveling
- experience points
- inventory
- equipment
- crafting
- shops with full economic systems
- quest framework beyond what is needed for a tiny test loop
- save/load
- character creation
- playable races
- companions
- magic systems
- Edenite mechanics
- reputation
- factions
- procedural generation
- world map
- day/night cycle
- weather systems
- voice acting
- final art
- final music
- final sound design

These may come later. Their absence is intentional.

---

## 8. Canon and Narrative Guardrails

The first slice should require very little world canon.

Known facts may be used:
- Halcyon Age
- Age of Reckoning is over
- Terrebonne is the capital
- Caden is just outside Terrebonne
- Caden is a cozy resting town for travelers
- the player is an out-of-towner
- the player intends to attend the Festival of the Six
- the player remains in Caden for now

If development requires a fact not provided here or in another approved repository canon document:
1. Do not invent it.
2. Use a neutral placeholder if the fact is purely technical.
3. If it affects lore, story, naming, culture, history, geography, religion, politics, or character identity, flag the gap for clarification.

---

## 9. Development Principles for This Slice

- Build the smallest working feature first.
- Prefer reusable components, but do not over-engineer.
- Keep content separate from reusable systems where practical.
- Use placeholder assets freely.
- Test each milestone before expanding.
- Keep Caden small enough that the player can understand its layout quickly.
- Do not make the opening feel like an immediate world-ending crisis.
- The initial emotional tone should be welcoming, curious, and grounded.
- Festival references should make the world feel alive without pulling the player out of Caden.
- Every implementation step should preserve a path toward later expansion.

---

## 10. Definition of Success for Version 1

Version 1 of the starting-town slice is successful when:

- The project launches into Caden.
- The player appears reliably.
- Movement feels responsive.
- Collision works.
- The camera behaves correctly.
- The player cannot accidentally leave the intended map.
- The town layout is readable.
- At least one reusable interaction works.
- At least one NPC can deliver multi-line dialogue.
- At least one natural line of dialogue references travelers or the Festival of the Six.
- No unapproved world canon has been invented.
- No unnecessary large RPG systems have been introduced.
- The code remains clean enough to expand.

---

## 11. First Codex Implementation Task

After this document is added to the repository, the first implementation task should be **Milestone A — Player Foundation only**.

Codex should not proceed automatically into Milestones B–F.

After Milestone A:
- inspect the diff
- report all files created or modified
- report any project settings changed
- report how movement and collision were implemented
- state what could and could not be runtime-tested
- do not commit
- wait for review before continuing

---

## Status

**Approved direction:** Starting-town vertical slice in Caden during the Halcyon Age.

**Current development boundary:** Caden only.

**Terrebonne:** Background destination only.

**Festival of the Six:** Ambient subtext only.

**Main plot:** Not yet defined.

**Combat:** Not yet authorized.

**Full canon package:** Not required for this milestone.
