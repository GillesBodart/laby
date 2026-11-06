# LABY — Game Specification (v0.1, draft)

Companion to `.github/instructions/design.instructions.md` (art/tone rules). This document defines WHAT the game is and what to build, in order.
Items marked **[DECIDE]** are open questions; a default is proposed.

## 1. Core Concept

A 2D top-down pixel-art survival/building RPG. The player is dropped into a walled glade (the **Clearing**) surrounded by a **shifting labyrinth**. The goal is to **find the exit**. The fun is the first half of the Maze Runner story: build a community, learn, explore, map, and escape. There is NO "outside the maze" phase.

### 1.1 Design pillars (from design doc) + the missing one
1. EXPLORE  2. SURVIVE  3. BUILD
4. **KNOW (new)**: progress comes from *knowledge*, not only gear. Maps, notes, decoded clues and learned skills are the real progression currency.

### 1.2 The core loop
Day: leave Clearing -> explore/map maze sections -> gather -> return before nightfall.
Night: maze doors close/shift, threats rise -> craft, build, farm, analyse discoveries.
Each trip out should answer: "what did I learn that makes the next trip go further?"

## 2. Win Condition and Structure

- **Goal:** locate and open the Exit, which requires N **Keys of Knowledge** (e.g. 4-5), each hidden in a labyrinth **Sector** with a distinct biome, hazard and puzzle.
- **Campaign length target:** 8-12 hours, one continuous save (not a pure roguelike reset).
- **Death (decided):** lose carried items, respawn in the Clearing; a recoverable "Remains" drops at the death spot. Optional permadeath hard mode (chosen at New Game; separate toggles for player and companions).
- **Safe resources (decided):** the player can *bank* resources so they survive death:
  - **Stash chest** in the Clearing: stored items are never lost. Death only affects the backpack.
  - **Insured slots (decided):** derived from the Strength characteristic: every 10 Strength secures 1 backpack slot (kept on death). The player chooses which slots are insured.
  - **Bound resources** (skill-improvement materials, "Relics") are always kept on death but can only be spent at the proper station (Skill Altar, Workshop, Forge), not traded.
  - Skill upgrades, construction tiers and equipment recipes draw from the Stash + Bound pouch, so banking is a core loop.
- **Replayability (decided):** every New Game generates a new maze (new seed). Biome order is fixed (see 3.1); layouts, landmarks, keys and clues differ.
- **Ending:** escape ends the game; optional epilogue screen only. No outside-world gameplay.

## 3. The Labyrinth (heart of the game)

- Grid of **Sectors** (A-E) around the Clearing, each a wall-tile maze generated from a seed.
- **Shifting:** at each night start, a subset of corridors reconfigure ("the walls move"). Explored Sectors stay *known* but paths change, so the map is a record of the past and landmarks matter.
- **Landmarks** (fixed, never shift): statues, machinery, marked doors. They let the player re-orient and annotate the map.
- **Mapping:** auto-reveals tiles seen; manual markers (danger, resource, door, note). Cells affected by a shift are shown as "uncertain".
- **Distance gating:** deeper = farther from Clearing = more danger + better resources + clues. Torches/rope/chalk extend safe range.
- **Return pressure:** night door-closing is the main tension: get back or be caught inside.
- **Generation constraints:** every Sector fully connected at generation; key room guaranteed reachable; resource/enemy tables per biome; no unfair dead-ends at the entrance.

### 3.1 Biome progression (decided)
The further from the Clearing, the more the biome changes. Each is a Sector ring/zone with its own palette, resources, enemies, hazard, boss and Key:

| Order | Biome | Hazard / theme | Notes |
|-------|-------|----------------|-------|
| 1 | Stone | Narrow overgrown walls, traps | Vertical slice biome |
| 2 | Forest | Dense vegetation, low visibility, predators | Herbs, mushrooms, hunting |
| 3 | Desert | Heat/thirst, sandstorms, buried ruins | Water becomes critical |
| 4 | Ice | Cold (introduces Temperature), slippery floors | Temperature moves from post-MVP to M-Ice |
| 5 | Volcano | Lava, fire damage, collapsing paths | Rare minerals, forge tier |
| 6 | Hell | Corrupted maze, strongest enemies | Final Key(s) |
| End | Exit | Open with all Keys | Game ends |

Each biome requires gear/knowledge from the previous one (e.g. water skin for Desert, warm clothing for Ice, fire resistance for Volcano), so BUILD/CRAFT gates EXPLORE.

## 4. Character Progression: Skill Graph

Replaces the old use-based skill list. The player levels up (XP from exploring, gathering, crafting, building, combat, discoveries), earns **Skill Points**, and spends them in a **radial skill graph** (reference: Path of Exile / Last Epoch style passive trees).

### 4.1 Graph structure
- **Central hub:** the starting node ring (basic survivor: +Strength, +Stamina, +Gathering). Everyone starts here.
- **Specialization clusters (multiple "heads")** radiate outward; each cluster is a themed branch with its own sub-tree, e.g.:
  - **Beastmaster** (taming, see 4.3), **Ranger** (bows, tracking, navigation), **Builder/Engineer** (construction tiers, traps, automation), **Survivor** (needs, food, resistances), **Warrior/Guardian** (melee, defence), **Scholar/Glyphwalker** (Lore, glyph decoding, map/shift prediction), **Healer/Alchemist** (herbs, potions), **Scout/Assassin** (stealth, speed).
  - Final cluster list is tunable; the data model must allow adding clusters without code changes.
- **Nodes:** small (stat bonus), notable (stronger effect), keystone (build-defining, with a trade-off). Each node has `cost`, `max_ranks` (shown like 0/3), and `requires` (one or more prerequisite nodes, any-of or all-of).
- **Connections:** nodes are linked by edges; a node can be taken only if an adjacent/prerequisite node is allocated (reachability rule). Branches meet at **bridge nodes** so hybrid builds (e.g. Beastmaster + Survivor) are possible.
- **Gating by world progress:** outer rings/keystones need a biome milestone or Relic (Bound resource), tying exploration to character growth.
- **Respec:** possible at a Skill Altar in the Clearing for a cost (Bound resource), so builds are experimental but not free.
- **Strength etc.:** characteristics (Strength, Agility, Intellect, Vitality) are granted by nodes and level-ups; Strength drives insured slots (every 10 = 1 slot).
- **Co-op:** each player has their own graph and points.

### 4.2 Graph UI and tech
- Pannable/zoomable graph screen (pixel-art nodes, lit when allocated, dim when unreachable, glow on available), cluster labels, tooltips with ranks and requirements, point counter, search/highlight by cluster.
- Data-driven: `SkillNode` Resource (id, name, icon, cluster, position, cost, max_ranks, requires, effects[], unlock_condition) and `SkillGraph` Resource; effects are modifiers applied via a stats component. Graph is built/validated by an editor tool/script (no cycles that break reachability, all nodes reachable from the hub).
- Allocated nodes saved per player.

### 4.3 Creature taming (Beastmaster specialization)
- Maze creatures can be **tamed**; taming is gated and scaled by the Beastmaster cluster (cluster nodes unlock taming tiers, number of companions, abilities, commands). Non-Beastmasters can tame only the weakest tier (decided).
- **How to tame (default):** weaken or feed the creature its favourite food/resource found in its biome, then a short taming interaction (patience/timing). Rare and elite creatures need higher tiers and special items.
- **Companions:** follow the player, have stats, level and traits; commands (follow, stay, attack, gather, guard Clearing). Can be housed in the Clearing (pens/stables) and assigned jobs (hauling, guarding, farming, scouting), and become part of base building.
- **Per-biome fauna:** each biome has tameable species (comic and original designs) that grant distinct utilities: carry capacity, tracking, digging, light, combat, scouting shifted paths.
- **Costs and limits:** companions need food, can be downed (default: a downed companion recovers at the Clearing; **companion permadeath is a player-selectable hardcore option** at New Game, alongside player permadeath, decided), count toward a party cap defined by the cluster.
- **Co-op:** each player owns their tamed creatures; max total companions is capped for performance.
- Data-driven `CreatureSpecies` Resource (taming rules, favourite items, stats, abilities, tier).

### 4.4 Knowledge (discovery-based, separate from skill points)
- **Recipes** unlock by discovering materials + examining ruins, not just by level.
- **Journal** auto-logs discoveries (creatures, plants, glyphs, shift patterns).
- **Glyphs:** the maze uses a glyph language; decoding glyphs reveals shift timing hints, safe routes and key locations. Core "aha" mechanic.

## 5. The Clearing (Settlement)

- Starts as a campfire, a few shelters and a small group of survivors.
- **Tiers:** Camp -> Shelters -> Village (workshops, farms, walls) -> Fortified Base -> Self-sufficient Community.
- **Survivors (NPCs):** small cast (5-8) assignable to roles (farmer, builder, cook, guard, cartographer). They give the "community" feel of the film. Keep simple: role = passive production + occasional requests.
- **Settlement needs:** food, water, shelter, defence. Each tier unlocks buildings and raises the night threat the Clearing must withstand.
- Grid-based building, 16x16 tiles, placement preview, deconstruct/refund, structure HP.

## 6. Survival Systems (MVP set)

Health, Hunger, Stamina from the start. **Thirst is introduced in the Desert biome; Temperature in the Ice biome** (not before), so early game stays readable and each new need is a lesson. Characteristics (e.g. Strength) drive derived stats such as insured slots. Tools/weapons have durability. Tuning rule: needs limit trip length, never nag constantly; a well-prepared trip must be comfortable.

## 7. Combat and Enemies

- Simple real-time top-down combat: attack, dodge-roll, stamina cost.
- Roles: wildlife (passive), territorial, night predators, Sector guardians, one boss per Key.
- Original creature designs (biomechanical-organic); no Maze Runner IP.
- Avoidance/stealth is valid; combat is not the main pillar.

## 8. Technical Spec (Godot 4)

- **Engine:** Godot 4.x, **GDScript**, 2D, tile size **16x16**, base resolution **480x270** with integer scaling (pixel-perfect, nearest filtering).
- **Multiplayer (decided: LAN co-op, to be studied):** use Godot high-level multiplayer (ENet, host-authoritative, 2-4 players, host's world/save). Not an MVP feature, but from M0 the architecture must be multiplayer-ready: simulation separated from rendering/input, player actions as commands/RPCs, deterministic world generation from the shared seed, per-player inventory but shared Stash/base, no singletons that assume one player. Feasibility spike before M6. **Co-op rules (decided):** max 4 players; wave-style survival: a dead player spectates and waits until all remaining players die (run failed, respawn at the Clearing with death rules) or return to the Clearing alive (dead players then respawn there). Assumed: shared map knowledge, host-driven day/night, shared Stash.
- **Structure:**
  ```
  res://
    assets/{sprites,tilesets,audio,ui,fonts}
    data/            # Resources (.tres): items, recipes, enemies, sectors, glyphs
    scenes/{world,player,enemies,buildings,ui}
    scripts/{core,systems,entities,ui}
    autoload/        # GameState, EventBus, SaveSystem, TimeSystem
  ```
- **Patterns:** data-driven (Resource files for items/recipes/biomes), signal-based EventBus, state machines for player/enemies, components (Health, Inventory, Hurtbox) over inheritance.
- **World:** `TileMapLayer` chunked per Sector; maze via seeded algorithm (recursive backtracker + loop/room pass); shifting = deterministic regeneration of masked sub-regions from `seed + night_index`.
- **Save:** JSON/Resource with seed, night index, map knowledge, base tiles, inventory, NPC state, journal.
- **Performance:** 60 FPS on a modest PC; chunk load/unload; pathfinding via `AStarGrid2D`.
- **Tooling:** godot-devtool MCP for scene/script editing and runtime tests; GUT or scripted tests for generation + crafting data.
- **Input:** keyboard+mouse first, gamepad later.

## 9. Milestones

| # | Milestone | Done when |
|---|-----------|-----------|
| M0 | Project setup | Repo structure, pixel-perfect viewport, placeholder tileset, autoloads, input map |
| M1 | Player + world | Walk/collide in Clearing, camera, day/night clock |
| M2 | Gather + inventory + craft | Chop/mine, inventory UI, 10 recipes, workbench |
| M3 | Building + Stash | Grid placement of walls/floors/doors/campfire/storage, base save/load, Stash chest + death rules (insured/Bound items) |
| M4 | Survival + XP | Hunger/stamina, food, farming plot, XP and level-up granting Skill Points |
| M5 | Maze v1 | One Sector from seed, fog-of-war map, nightly door closing |
| M5b | Skill graph v1 | Data-driven graph, hub + 3 clusters (Survivor, Builder, Beastmaster), graph UI, allocation rules, save, stat effects |
| M6 | Combat + enemies | Dodge/attack, 3 enemy types, death/respawn |
| M6b | Taming v1 | 1 tameable species, taming interaction, follow/attack companion, Beastmaster nodes |
| M7 | Shifting + glyphs + journal | Night shift, landmarks, uncertain map, glyph decoding |
| M8 | NPCs + settlement tiers | Survivors with roles, tier progression |
| M9 | Full campaign | 4-5 Sectors, bosses, keys, Exit, ending |
| M10 | Polish | Audio, UI pass, balancing, final art |

**First vertical slice = M0-M5.** Prove "leave Clearing, map a bit, return at dusk" is fun before building more.

## 10. MVP Scope Cuts (be strict)
Out initially: temperature (until Ice), armor sets, multiple weapon classes, NPC schedules, gamepad, LAN multiplayer implementation (architecture must stay ready), localization, more than one boss.

## 11. Art Direction (from reference images)

Three references define the target look:
1. **Core Keeper-style base/farm scene:** warm, rich 16-bit pixel art, dense detail, wooden/stone crafting stations, torches with warm point lights, crops, glowing crystals, dark cave edges. Reference for the **Clearing / base building / UI readability**.
2. **Overgrown stone archway (moody illustration):** ruined arches, moss, hanging vines, cold teal-blue shadows with bright green foliage. Reference for **Labyrinth atmosphere and entrances**. Note: it is painterly, so we reproduce its palette, composition and lighting in tile-based pixel art, not its soft shading.
3. **SNES-style forest (Zelda/Secret of Mana feel):** saturated greens, outlined trees, dirt paths, small props, dark water/void border. Reference for **Forest biome and overworld tile readability**.

Rules derived from them:
- 16-bit-era detail, dark outlines on characters/props, limited per-biome palettes (16-24 colors) + shared UI palette.
- **Lighting is a core art tool:** dark ambient, warm torches/campfire lights in the Clearing, cold ambient in the maze (Godot `PointLight2D` + `CanvasModulate`, pixel-snapped).
- Vegetation overgrowing stone walls: wall tiles need moss/vine variants (autotile terrains + overlay decoration layer).
- Y-sorted tall objects (trees, walls, statues) for depth; shadows under every prop.
- Biome palettes: Stone (teal-grey/green), Forest (saturated greens), Desert (ochre/orange), Ice (cyan/white), Volcano (black/red/orange), Hell (purple/crimson).
- Placeholder art must match the above scale/palette; avoid mixing unrelated packs. Use CC0 packs only as stand-ins, then replace.

## 12. Tone and Inspiration: Dave the Diver

Take from *Dave the Diver*: **humor, charming character design, and the "expedition by day, base management by night" roguelite loop.**
- **Humor:** quirky survivors with comedic personalities, funny item/journal descriptions, absurd-but-lovable creatures, comic reactions (exaggerated death/pickup animations, silly NPC requests). The maze is menacing, but the people in it are funny; humor offsets the isolation.
- **Characters/creatures:** expressive, slightly exaggerated sprites with big readable silhouettes and personality; enemies should be threatening *and* a bit goofy.
- **Loop mapping:** Dive = Maze expedition (procedural, risk/reward, limited carry capacity, return with loot). Restaurant/base = Clearing (turn loot into food, upgrades, equipment, buildings; NPCs run stations). Unlock the next area by upgrading gear and finding story beats.
- **Mini-systems (later, low priority):** small side activities in the Clearing (cooking, farming, fishing in maze pools) that feed the main loop, plus short story/cutscene beats with comedic NPC dialogue.
- **Roguelite structure:** procedural maze per run, loot variance, permanent progression (skills, base, recipes, blueprints) that makes each expedition safer/longer.
- Guardrail: humor must not break the mysterious atmosphere; keep it in dialogue, character animation and item text, not in the maze's lighting/palette.

## 13. Open Decisions (remaining)
1. List of Bound resources (proposal: skill relics, blueprints, keys).
2. Which Strength sources exist (leveling, gear, food buffs) and starting value.
3. Mini-games are deprioritized (decided): focus on the skill graph first; Dave-style mini-systems come later.
4. Keys: 5 Keys (Stone-Hell) + Exit (decided).
5. Skill graph: final cluster list, points per level, node counts (default slice: hub + Survivor, Builder, Beastmaster). Values to be balanced through playtests and automated simulations (decided approach).
Decided: non-Beastmasters tame the weakest tier only; companion permadeath is a user-chosen hardcore option.
