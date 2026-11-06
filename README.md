# LABY

2D top-down pixel-art survival / building RPG set in a shifting labyrinth (Godot 4.7, GDScript).
Design: [`docs/GAME_SPEC.md`](docs/GAME_SPEC.md) · Art & tone rules: [`.github/instructions/design.instructions.md`](.github/instructions/design.instructions.md)

## Status

| Milestone | State |
|-----------|-------|
| M0 Project setup (structure, 960x540 viewport, 32px tiles, autoloads, input map, placeholder art) | ✅ |
| M1 Player + world (seeded Clearing, walk/run + collisions, camera, day/night clock & lighting, gates closing at night) | ✅ |
| M2 Gather + inventory + craft (E to chop/mine, I backpack + 10 recipes, campfire/workbench stations, saved) | ✅ |
| Clearing v2 | ✅ 100x70 glade, 10 tree + 10 rock variants, single north gate leading to the Labyrinth (separate scene, loads after the gate corridor; walk back into the vestibule to return) |
| M3 Building (grid walls/floors/doors/workbench/chest in the Clearing, saved) + Stash chest | ✅ (death rules deferred until health exists) |
| M4 Survival + XP (health/hunger/stamina bars, berry bushes, R to eat, starvation + respawn, XP & levels from gathering -> skill points, saved) | ✅ (farming plots deferred) |
| M5 Maze v1 (labyrinth sector from seed, **M** fog-of-war map saved with the game, gates close at night) | ✅ |
| M6 Combat + enemies (**Space** attack, tools hit harder; moss grubs, stalkers, stone wardens guard the labyrinth by depth, drops + XP) | ✅ |
| M5b Skills (**K** screen: Vigor, Might, Fleet foot, Endurance, 3 ranks each, spend level-up points, saved) | ✅ |
| M6b+ | Next: farming, taming |

## Run

```powershell
$godot = "C:\Tool\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --path .                                              # play
& $godot --headless --path . res://tests/test_runner.tscn      # tests (exit code = failures)
& $godot --headless --path . --script res://tools/generate_placeholder_art.gd  # regenerate placeholder PNGs
```

Controls: **WASD / arrows** move (physical keys, so ZQSD on AZERTY) · **Shift** run · **E** (hold) chop trees / mine rocks · **Space** attack · **R** eat berries · **M** map · **K** skills · **I** backpack & crafting (Tab switches tab; 1-0 or click to craft) · **B** build mode (**Q** next item, **F** place / toggle door, **X** remove + refund) · **G** Stash (next to a chest: 1 deposit, 2 withdraw) · **F5/F9** quick save/load · **F3** fast time (x30).

Debug args (after `--`): `--seed=123`, `--time=21:30`, `--at=36,14` (tile cell), `--area=labyrinth`, `--screenshot=out.png --screenshot-frames=60`.

## Architecture

```
autoload/   EventBus (signals) · GameState (seed, players by peer id) · TimeSystem · SaveSystem · DebugTools
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
