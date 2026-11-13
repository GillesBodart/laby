# LABY — Game Specification

What the game is, the rules it runs on, and what is left to build. Art, tone and code rules: [`.github/instructions/design.instructions.md`](../.github/instructions/design.instructions.md). Implemented milestones, controls and architecture: [`README.md`](../README.md).

## 1. Concept

A 2D top-down survival / building RPG in smooth HD art. The player is dropped into a walled meadow (the **Clearing**) surrounded by a **shifting labyrinth** and has to **find the way out**. The fun is the first half of a Maze Runner-style story: build a community, learn, explore, map and escape. There is no gameplay outside the maze. Escaping ends the run with an epilogue.

Pillars: EXPLORE · SURVIVE · BUILD · **KNOW** (maps, journal, glyphs, recipes, blueprints and skills are the real progression currency).

Loop: by day, leave the Clearing, map, gather and come back before the gates close at 20:00. By night, the walls shift and threats rise: craft, build, farm, sleep, defend against raids.

## 2. Structure and win condition

- **Six sectors** north of the Clearing, in a fixed order. Each has its own palette, 20+ creatures, 20+ resources, a hazard and a guardian boss in an arena:

  | # | Sector (id) | Theme / hazard |
  |---|-------------|----------------|
  | 1 | Stone Labyrinth (`labyrinth`) | overgrown walls, first glyphs |
  | 2 | Overgrowth (`overgrowth`) | dense vegetation, predators, poison |
  | 3 | Sunken Dunes (`desert`) | heat, **thirst** starts here |
  | 4 | Rime Halls (`ice`) | cold, **temperature** matters |
  | 5 | Cinder Forge (`volcano`) | heat, rare metals |
  | 6 | The Pit (`hell`) | the strongest enemies |

- Each guardian drops a **Key** that unseals the sector's north gate. The Pit's gate needs all six Keys; beyond it lies the way out.
- **Each New Game makes a new maze** (new seed). The sector order is fixed; layouts, landmarks, glyphs, chests and caches change.
- **Campaign**: one continuous save (3 slots plus a quick save), targeting 8-12 hours.
- **Waystones** in every vestibule (also craftable) travel to any area already reached.

## 3. The labyrinth

- Each sector is a seeded maze (recursive backtracker plus loops), fully connected. It has a vestibule at the south, the guardian's arena at the north, open chambers, extra loops near the entrance, and a reward in most dead ends: rare deposit caches, plus **treasure chests** that hold blueprints and valuables and are opened once.
- **Shifting**: at every nightfall a few regions re-carve themselves (seeded by `seed + night`). The maze always stays connected. Landmarks, glyph stones and treasure chests never move, and the shifting regions avoid them.
- **Map** (M): fog of war, saved. Moved passages show hatched until seen again. The player can place manual markers.
- **Glyph stones** (four per sector, laid out from the entrance towards the arena; only the story stone needs the Scholar's insight) reveal tonight's moving passages, the route to the arena, the guardian's den and the sector's story.
- **Distance gating**: depth is the walking distance from the entrance (1.0 at the guardian's door); each sector also hides two elite dens in its farthest dead ends. The deeper you go, the more danger and the better the loot. Dusk warnings and a countdown push the player to get back.

## 4. Character progression

- **XP** from gathering, harvesting, combat, landmarks, glyphs and treasure chests. Level-ups grant skill points.
- **Skill graph** (K): a radial passive tree. It has a hub ring and six clusters (Warrior, Ranger, Survivor, Scholar, Beastmaster, Builder) with multi-rank nodes, notables, hybrid bridges, and sector-gated keystones that carry trade-offs. **Respec** at a Skill Altar costs a Memory Shard (dropped by elites and bosses).
- **Strength** = 10 + (level − 1) + Brawn nodes. Every 10 points insure one backpack slot against death.
- **Knowledge**:
  - **Recipe discovery**: a recipe appears once you have found every special ingredient it needs. Staples (wood, sticks, planks, stone, fiber, rope, leather, coal, vials) reveal nothing on their own; a recipe made only of staples needs all of them.
  - **Blueprints**: rare recipes that no ingredient reveals. They are found in the sector's treasure chests and, once read, are known to the whole camp. Each guardian also guards its sector's weapon blueprint, taught when it falls.
  - **Journal** (J): creatures, resources, glyphs, places.
- **Taming** (Beastmaster): weaken a creature (gentle species need no fight), then feed it its favourite food. Beastmaster nodes raise the tame tier and the party cap; non-Beastmasters tame only the weakest tier, and guardians never yield. Companions follow or stay, fight, level up, travel and save with you. A downed companion recovers in the Clearing unless companion permadeath is on.

## 5. Survival, gear and death

- **Needs**: health, hunger and stamina from the start; thirst once the desert is reached; body temperature in hot and cold climates (countered by gear, fire and tonics). Tuning rule: needs limit trip length but never nag; a well-prepared trip must be comfortable.
- **Gear**: an equipment doll (weapon, offhand, head, body, feet, ring, amulet), material tiers up to the sector metals (Rimesilver, Ember, Deepsteel), bows and arrows, shields, staffs, potions. A held torch gives light and keeps night hunters away. **Tools and weapons wear out** and break.
- **Combat**: real-time attacks and a dodge-roll that costs stamina. Creatures have distinct attacks (melee, charge, ranged, shields, poison or slow, packs). Avoiding fights is a valid choice; combat is not the main pillar.
- **Death**: chosen at New Game.
  - *Recoverable* (default): the non-insured backpack drops as **remains** at the death spot; you respawn in the Clearing. The Stash and bound items (keys, relics) are never lost.
  - *Permanent*: the run and its saves end, and the run summary is shown.
  - Companion death is set the same way, separately (recover or permanent).

## 6. The Clearing (settlement)

- **Building** (B): grid placement on 32 px tiles of walls, floors, doors, stations, chests, beds, torches, farm plots and a well. Placement preview, removal with refund, structure HP and repair. Furniture stands on floors.
- **Rooms**: a space closed by walls and doors (up to 64 tiles) is a room. Its contents grant comfort buffs (Rested, Nourished, Handy, Organised, Cosy, Comfortable). Crafting inside a room that holds a chest also draws ingredients from the Stash. **Sleeping** in a bed inside a closed room at night skips to 07:00. Hostiles outside a sealed room do not prevent sleep.
- **Stations**, each with its own recipe book: campfire, workbench, furnace, anvil, cooking pot, tanning rack, stonecutter, loom, alchemy table. Farm plots grow 13 crops.
- **Settlement tiers**: Camp → Shelters → Village → Fortified Base → Community. Up to eight quirky survivors with roles (gatherer, farmer, builder, cook, guard, cartographer, healer). At each dawn they eat a ration each from the Stash (simplest food first; medicine and precious food are kept) and work. Cooks cook before breakfast; healers brew potions from herbs and glass vials.
- **Night raids**: once the camp is a Village, from the second night, raiders attack every other night. They mostly come through the north gate. They scale with the camp's size and are reduced by its defences.
- **Goal chain** in the HUD guides the early game: wood, tools, workbench, house, bed, maze, glyphs, survivors, guardians, escape.

## 7. Technical frame

Godot 4.7, GDScript, 2D. Logical 960×540 viewport with 32 px tiles and smooth HD textures (see the design instructions). There are no audio files; all sound is synthesised at runtime. Keyboard + mouse and gamepad are supported, and every key can be rebound. Accessibility offers text size and a colour-blind palette. The architecture and the commands to run, test and generate art are in the README.

## 8. Not built yet

- **LAN co-op** (ENet, host-authoritative, up to 4 players). Planned rules: wave-style, where a dead player spectates until everyone is dead (the run fails and all respawn at the Clearing) or the survivors return home; shared map knowledge, Stash and day/night. The architecture is ready for it (peer ids, input intents, authority-driven time); the networking is not implemented.
- **Side activities**, low priority: fishing in maze pools, cooking extras, short comedic story beats with survivors.
- **Balancing** through playtests and automated simulations (skill points per level, node values, need rates, raid strength).
- Localization.
