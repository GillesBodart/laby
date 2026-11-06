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
| M10 | Next: taming |

## Run

```powershell
$godot = "C:\Tool\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --path .                                              # play
& $godot --headless --path . res://tests/test_runner.tscn      # tests (exit code = failures)
& $godot --headless --path . --script res://tools/generate_placeholder_art.gd  # regenerate placeholder PNGs
```

Controls: **WASD / arrows** move (physical keys, so ZQSD on AZERTY) · **Shift** run · **E** (hold) chop trees / mine rocks; tap **E** on a crafting station to open its recipe book · **Space** attack · **R** eat berries · **M** map · **K** skills · **I** backpack & hand crafting (Tab switches tab; click backpack gear to equip, click the doll to take off, click a recipe to craft, wheel scrolls) · **B** build mode (**Q** next item, **F** place / toggle door, **X** remove + refund) · **G** Stash (next to a chest: 1 deposit, 2 withdraw) · **F5/F9** quick save/load · **F3** fast time (x30) · **Esc** closes the open panel, otherwise opens the pause menu (save, load, controls rebinding, quit). Keys listed are defaults.

Debug args (after `--`): `--seed=123`, `--time=21:30`, `--at=36,14` (tile cell), `--area=labyrinth`, `--screenshot=out.png --screenshot-frames=60`.

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
