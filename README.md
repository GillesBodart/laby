# LABY

2D top-down pixel-art survival / building RPG set in a shifting labyrinth (Godot 4.7, GDScript).
Design: [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md) · Art & tone rules: [`.github/instructions/design.instructions.md`](.github/instructions/design.instructions.md)

## Status

| Milestone | State |
|-----------|-------|
| M0 Project setup (structure, 960x540 viewport, 32px tiles, autoloads, input map, placeholder art) | ✅ |
| M1 Player + world (seeded Clearing, walk/run + collisions, camera, day/night clock & lighting, gates closing at night) | ✅ |
| M2 Gather + inventory + craft (E to chop/mine, I backpack + recipe book, campfire/workbench stations, saved) | ✅ |
| Clearing v2 | ✅ 100x70 glade, 10 tree + 10 rock variants, single north gate leading to the Labyrinth (separate scene, loads after the gate corridor; walk back into the vestibule to return) |
| M3 Building (grid walls/floors/doors/workbench/chest in the Clearing, saved) + Stash chest | ✅ (death rules deferred until health exists) |
| M4 Survival + XP (health/hunger/stamina bars, berry bushes, R to eat, starvation + respawn, XP & levels from gathering -> skill points, saved) | ✅ (farming plots deferred) |
| M5 Maze v1 (labyrinth sector from seed, **M** fog-of-war map saved with the game, gates close at night) | ✅ |
| M6 Combat + enemies (**Space** attack, tools hit harder; moss grubs, stalkers, stone wardens guard the labyrinth by depth, drops + XP) | ✅ |
| M5b Skills (**K** screen: Vigor, Might, Fleet foot, Endurance, 3 ranks each, spend level-up points, saved) | ✅ |
| M7 Minecraft-style content: 11 raw resources (grass, clay, coal, copper/iron ore, crystal in the labyrinth by depth), smelting at a furnace, 3 tool/armor tiers (ore needs a good enough pickaxe), 33 recipes, farm plots (E plants a berry, ripe in 4 min) | ✅ |
| M8 Gear & stations: equipment doll (weapon, head, body, feet, ring, amulet; click to equip), chop/mine swing animation, 7 crafting stations each with its own recipe book (E on campfire, workbench, furnace, anvil, cooking pot, tanning rack, stonecutter), mushrooms + meat and 8 foods, 54 recipes | ✅ |
| M9 Esc menu: pause, save / load in 3 slots (slot 1 = F5/F9 quick save), rebind every shortcut (swap on conflict, reset to defaults; stored in `user://settings.cfg`), quit | ✅ |
| M10 Biomes: 48 creatures (23 forest, 25 labyrinth) with distinct attacks (melee, charge, ranged projectiles, shields, poison/slow, packs), 40 gatherable resources (20 per biome), ~200 items and 161 recipes incl. loom + alchemy table, bows & arrows, shields (offhand slot, block), potions (**H** drink); item art partly from Dungeon Crawl Stone Soup (CC0, see [CREDITS](CREDITS.md)) | ✅ |
| M10b Categorised items: tools, weapons, ammo, armor, accessories, medicine, food, stations, building, materials, creature parts, resources. Recipe books grouped by category with filter chips; backpack **SORT** button merges stacks and orders by category | ✅ |
| M10c Ground polish: smooth seamless 256px grass textures, organic dirt paths with soft noisy borders (procedural soil, no tile grid), ponds (solid water, mud banks, lily pads) with reeds growing only on their banks, flat clay/sand patches drawn under walkers, creatures scaled to believable sizes (hare 14px to treant 48px), fixed downward tool swing | ✅ |
| M10d Discovery + crops: recipes appear once you have found any of their ingredients ("N undiscovered" counter, saved per player), E on an empty farm plot opens a seed picker with 13 crops (berries, blueberries, wheat, carrot, potato, herb, cotton, flower, reed, mushroom, glowcap, apple tree, shadow orchid), each with its own growth time, yield and art; tighter interaction reach; fixed the shadow drifting after a swing | ✅ |
| M11 Death rules: dying drops your non-insured backpack into a remains pile at the spot (saved; walk back and press **E** to recover it). Strength (10 + level + Brawn) insures 1 slot per 10 points (green padlocked slots, kept by SORT); bound items (keys, relics) are never lost | ✅ |
| M12 Sectors: six labyrinth sectors north of the Clearing (Stone Labyrinth, Overgrowth, Sunken Dunes, Rime Halls, Cinder Forge, the Pit), each with 20+ creatures, 20+ resources, its own palette and a guardian boss in an arena; the boss drops a Key that unseals the north gate (the Pit gate needs all six, beyond it: the way out). Sector gear tiers (mithril, ember, hellsteel), staffs, ~285 items and ~210 recipes; waystones in every vestibule (and craftable) travel to any reached area | ✅ |
| M13 Thirst & temperature: thirst wakes once you reach the desert (WT bar; drink at ponds/wells with **E**, fill waterskins); climates (desert/forge hot, ice cold) push body temperature (TP gauge) and hurt at the extreme unless you wear warm/cool gear, stand by a fire/torch or drink tonics | ✅ |
| M14 Light & dodge: hold a Torch in the offhand for a wide warm light; night hunters will not approach a torch-bearer or anyone near a campfire / standing torch (unless provoked). **C** dodge-rolls (stamina, brief invulnerability) | ✅ |
| M15 Skill graph: radial passive tree (**K**) with a hub ring and six clusters (Warrior, Ranger, Survivor, Scholar, Beastmaster, Builder), multi-rank nodes, notables, hybrid bridges and sector-gated keystones with trade-offs; pan with drag, zoom with the wheel. Build a Skill Altar (stonecutter) to respec for a Memory Shard (elite/boss drop) | ✅ |
| M16 Taming: feed a weakened creature (gentle ones need no beating) its favourite food with **E** to tame it. Tougher species need Beastmaster nodes (tier and party cap); guardians never yield. Companions follow, fight whatever hunts you, level up, guard a spot (**V** follow/stay), travel and save with you; a downed companion recovers in the Clearing | ✅ |
| M17 Shifting maze, glyphs & journal: at every nightfall a few regions of each sector re-carve themselves (always staying connected); fixed landmarks (statues, an old engine) never move. Moved passages show hatched on the map until seen again. Map markers (**M**, 1-4 kind, left click mark, right click erase). Four glyph stones per sector (the deeper ones need the Scholar's glyph insight) reveal tonight's moving passages, the route to the arena, the guardian's den and the sector's story. **J** opens the journal (creatures, resources, glyphs, places) | ✅ |
| M18 Settlement & survivors: the Clearing grows from a Camp into Shelters, a Village, a Fortified Base and a Community as you build beds (new: Straw Bed), stations, farm plots, a well, walls, doors and torches (and slay a guardian). Every dawn the survivors eat from the Stash, work their role (gatherer, farmer, builder, cook, guard, cartographer, healer) and put the fruit in the Stash; fed and housed camps attract up to eight quirky newcomers. **E** on a survivor opens the settlement panel (checklist, needs, click to change a role) | ✅ |
| M19 Night raids: from the second night, every other night raiders come out of the maze, more for bigger camps and fewer the better it is defended (guards, walls, torches). They batter structures (HP bars; stone outlasts wood, Builder skills toughen them), guards fight them, survivors chase them off at dawn. Builders mend damage at dawn and **F** in build mode repairs with one of the structure's main material. Away from home, a raid is resolved off-screen | ✅ |
| M20 Sound: every effect and ambience is synthesised at runtime (no audio files) — swings, hits, shield blocks, chopping, mining, crafting, building, doors, eating, level-ups, the raid horn, the maze grinding as it shifts. Ambience follows place and time (meadow birds by day, crickets at night, the maze's hum, clanks and distant growls). Esc → Sound sets master / effects / ambience volume (saved in `user://settings.cfg`) | ✅ |
| M21 Gamepad: plays fully on a controller — left stick moves, right stick aims shots, A attack, B dodge, X gather / use, Y backpack, LB eat, RB drink, LT run, RT place / repair, D-pad skills / journal / next building / build mode, L3 companions, R3 remove, Back map, Start pause. In panels and menus the pad drives the cursor (A click, X right-click, B back) and prompts show pad buttons | ✅ |

## Run

```powershell
$godot = "C:\Tool\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --path .                                              # play
& $godot --headless --path . res://tests/test_runner.tscn      # tests (exit code = failures)
& $godot --headless --path . --script res://tools/generate_placeholder_art.gd  # regenerate placeholder PNGs
```

Controls: **WASD / arrows** move (physical keys, so ZQSD on AZERTY) · **Shift** run · **E** (hold) chop trees / mine rocks; tap **E** on a crafting station to open its recipe book, on an empty farm plot to pick a seed (click or 1-9), on a ripe one to harvest · **Space** attack (bows shoot toward the mouse cursor once it has moved, otherwise straight ahead) · **R** eat berries · **M** map · **K** skills · **V** companions follow/stay · **J** journal · **I** backpack & hand crafting (Tab switches tab; click backpack gear to equip, click the doll to take off, click a recipe to craft, wheel scrolls, category chips filter the book, SORT tidies the backpack) · **H** drink / use a potion · **B** build mode (**Q** next item, **F** place / toggle door / repair, **X** remove + refund) · **E** / **G** on a chest opens the Stash window (click a stack to move it across, right-click moves one, 1 stores materials, 2 takes all) · **F5/F9** quick save/load · **F3** fast time (x30) · **Esc** closes the open panel, otherwise opens the pause menu (save, load, controls rebinding, sound volumes, quit). Keys listed are defaults. A gamepad works too (see M21).

Debug args (after `--`): `--seed=123`, `--time=21:30`, `--at=36,14` (tile cell), `--area=desert` (clearing or any sector), `--give [--panel] [--sort] [--station=anvil]`, `--tame=tusk_boar,hare`, `--spawn=dusk_jackal,thicket_archer`, `--swing=down,iron_pickaxe[,0.14]` (repeat a swing, or freeze it that many seconds in), `--farm=wheat,apple [--panel]` (a seed-picker plot plus ripe plots of those crops), `--equip=torch,iron_sword` (give and equip), `--die` (die with a full pack and stand at the remains), `--explore` (reveal the sector, read its glyphs, add sample markers, journal entries and a wall shift), `--map`, `--journal`, `--screenshot=out.png --screenshot-frames=60`.

## Architecture

```
autoload/   EventBus (signals) · GameState (seed, players by peer id) · TimeSystem · SaveSystem · KeyBindings (rebindable shortcuts) · DebugTools
scripts/core      DayClock (pure time logic) · SpriteFramesBuilder
scripts/world     TileCatalog (tile ids/atlas/collision) · TileSetFactory · ClearingGenerator -> ClearingLayout (pure data)
                  ClearingWorld (renders layout) · ClearingGates · LightingCurve · GameCamera · world.gd
scripts/entities  Player (state machine) · PlayerInput (intent) · campfire
scenes/           world, player, props, ui
tests/            unit + integration suites (TestCase base, test_runner.tscn)
tools/            placeholder art generator
```

Key decisions:
- **Logic vs rendering:** generators/clocks are pure `RefCounted` classes producing data; nodes only render it. This keeps them testable and deterministic from the seed (needed for maze shifting and co-op).
- **Multiplayer-ready:** players are registered by peer id, input is an intent component (`PlayerInput`), and only the authority advances time.
- **Data-driven tiles:** `TileCatalog` is the single table for atlas coordinates and collision; the art generator, TileSet and generator all use it. Replace `assets/` PNGs keeping the same grid to swap art.
- **Saves:** nodes in the `persist` group implement `get_save_key/get_save_data/load_save_data`; world is rebuilt from the seed, then node data applied.
- **Day:** a day starts at dawn (05:00); gates close at night (20:00) and reopen at dawn, never closing on a player.
