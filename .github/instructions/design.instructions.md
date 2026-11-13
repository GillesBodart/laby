# LABY — Design, Art Direction & Development Guidelines

What the game is and what is built: [`docs/GAME_SPEC.md`](../../docs/GAME_SPEC.md). Current state, commands and architecture: [`README.md`](../../README.md). This file holds the rules every change must respect.

## 1. Vision

A 2D top-down survival / building RPG. The player wakes in the **Clearing**, a walled meadow, surrounded by a **shifting labyrinth**. The goal is to escape. The game is the first half of a Maze Runner-style story: build a community, learn, explore, map and get out. There is no "outside the maze" phase.

Pillars. Every feature must serve at least one of them:

1. **EXPLORE**: an unknown maze, landmarks, glyphs, secrets.
2. **SURVIVE**: needs, combat, nightfall, death rules.
3. **BUILD**: a settlement that grows from a campfire into a community.
4. **KNOW**: progress comes from knowledge (map, journal, glyphs, discovered recipes, blueprints, skills), not only from gear.

Core loop: **EXPLORE → GATHER → CRAFT → BUILD → SURVIVE → EXPLORE FURTHER**. By day you leave the Clearing and come back before the gates close. By night you craft, build and sleep while the walls move. Every trip should answer the question: "what did I learn that lets the next trip go further?"

## 2. Inspirations

- **The Maze Runner (atmosphere only)**: a hostile enclosed world, huge overgrown walls, a safe meadow, rules the player discovers through experiment. Do not reproduce its characters, creatures, places, story or assets. The universe is original.
- **Dave the Diver (tone and loop)**: humour, charming exaggerated characters, and the rhythm of an expedition by day and base management by night. Humour lives in survivors, item and journal text and animations. It never shows in the maze's lighting or palette, which stay mysterious.
- **Minecraft-style crafting**: many resources, many recipes, stations with their own recipe books, material tiers.

## 3. Art direction: smooth HD, no pixel art

**Pixel art is out.** The look is smooth, detailed 2D illustration in a top-down 3/4 view, rendered with linear filtering.

- **Pipeline**: art is generated at logical size (`tools/generate_placeholder_art.gd`, `tools/generate_roadmap_art.gd`). It is then upscaled 2× with xBR (`tools/smooth_art`) and imported through the `laby_hd_texture` plugin as an `HdTexture`, which reports the logical size. Every new or edited PNG must go through `smooth_art` and be reimported (commands in the README). Never commit raw low-res art.
- **Logical units**: 32 px tiles, 960×540 viewport (window 1440×810, `canvas_items` stretch, fractional scale), camera zoom 0.75. Gameplay code, atlas regions and sheets stay in 1× coordinates.
- **Shared finish**: selective dark ink outline with a lit rim, contact shadows under props, Y-sorted tall objects. Characters are about 42 px chibis on 48×48 frames. Creatures are larger and readable.
- **Consistency**: one perspective (top-down 3/4; no isometric or mixed views), consistent proportions, no photorealism, no generic vector clip-art, no heavy gradients or 3D effects. A new asset must look like it belongs next to the existing ones.
- **Lighting is a core art tool**: warm campfires and torches in the Clearing, cold ambient light in the maze, dark nights (`PointLight2D` + day/night modulate).
- **Biome palettes** carry identity and danger:

  | Area | Palette |
  |------|---------|
  | Clearing | natural greens, earthy browns, warm yellows |
  | Stone Labyrinth | teal-grey stone, desaturated green, ivy |
  | Overgrowth | saturated greens, deep shadows |
  | Sunken Dunes | ochre, orange, sand |
  | Rime Halls | cyan, white, cold blue |
  | Cinder Forge | black, red, orange glow |
  | The Pit | purple, crimson, corruption |

- **Animation**: the hero and survivors have real walk cycles (contact and passing poses). Every character and creature rides the `Gait` rig (sway, footfall squash, breathing, hovering). Tool swings must lead with the working edge. Keep effects restrained: no heavy particles or cinematic transitions.

## 4. UI

- Smooth rounded UI with the **Nunito** font (`resources/ui/ui_font.tres` through `resources/ui/theme.tres`). 9-slice frames (`UiFrame`, `hud_frame.tres`). Consistent item icons (32 px, plus 16 px small icons).
- **UI palette**: four main colours, defined once in `UiPalette` (`scripts/ui/common/ui_palette.gd`): amber `#ffb852` (accents, titles), mustard `#d1bd19` (frame rims), leaf green `#328e13` (stitching, highlights), forest green `#00592e` (panel and HUD backgrounds). Derive other UI shades from them; never hard-code UI colours in panels.
- The HUD must never hide gameplay. Notices are small, stacked, bottom right.
- **Accessibility** (`Accessibility` autoload): every HUD element and floating number follows the text-size setting. Colours that carry meaning on their own come from `Accessibility` (colour-blind palette), never from hard-coded red/green.
- Everything is playable with keyboard + mouse and with a gamepad (panels included). Prompts show the active device's buttons. Keys are rebindable (`KeyBindings`).

## 5. Sound

All sound is synthesised at runtime (`Synth`, `Sound` autoload). There are no audio files. New effects and ambiences are added as synth recipes. The Clearing is calm (birds, crickets, fire); the maze sounds uneasy (hum, grinding walls, distant growls). Respect the master, effects and ambience volume settings.

## 6. Creatures

Original creatures that look organic or biomechanical: distinct silhouettes, readable threat level, behaviour that fits their biome. They should be threatening *and* a bit goofy. Each sector has its own fauna, a guardian boss and tameable species.

## 7. Development rules

1. **One working copy**: work in this repository on `main`. Do not create parallel copies, worktrees or long-lived side branches of the project.
2. Inspect the existing architecture first (README › Architecture) and reuse existing systems, catalogs and components.
3. **Logic vs rendering**: game rules live in pure `RefCounted` classes (`scripts/systems`, `scripts/generation`) that are deterministic from the seed; nodes only render and forward input.
4. **Data-driven**: items, recipes, creatures, structures, tiles, sectors and blueprints live in the static catalogs under `scripts/data`. Add content there, not in scene code. Do not hard-code visual constants in several places.
5. **Multiplayer-ready, not multiplayer yet**: players are keyed by peer id, input goes through the `PlayerInput` intent, and only the authority advances time. Never add singletons that assume a single player.
6. **Saves**: persistent nodes are in the `persist` group (`get_save_key` / `get_save_data` / `load_save_data`). The world is rebuilt from the seed, then node data is applied. New state must be saved and loaded.
7. **Tests**: add focused unit/integration cases to the existing suites under `tests/`. Run `godot --headless --path . res://tests/test_runner.tscn` (exit code = number of failures) and keep it green.
8. Update the README milestone table and controls when a feature ships.
9. Performance: 60 FPS on a modest PC. Avoid per-frame allocations, redundant redraws and heavy effects.
10. No new dependencies or tooling unless required. Third-party art must be CC0/OFL and listed in `CREDITS.md`.
11. When a request is ambiguous and could compromise the architecture or the art direction, ask.

## 8. Golden rule

The game must feel like a mysterious, charming survival adventure in a smooth, hand-crafted illustrated style: hostile maze, warm settlement, funny people. **Consistency, atmosphere, readability and player experience come before visual complexity.**
