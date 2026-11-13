class_name UiPalette
extends RefCounted
## The one set of UI colours shared by the HUD, panels and menus. Colours that
## carry meaning on their own (good / bad / warn...) are not here: they come
## from Accessibility.color() so the colour-blind palette can swap them.

const INK := Color8(27, 20, 16)
## The four main colours of the game's UI; every frame colour derives from them.
const AMBER := Color("#ffb852")
const MUSTARD := Color("#d1bd19")
const LEAF := Color("#328e13")
const FOREST := Color("#00592e")
## Mustard rim of the frames (lit top-left, shaded bottom-right).
const BRASS := MUSTARD
const BRASS_DARK := Color(0.45, 0.4, 0.04)
## Forest-green felt of the panel frames, and its leaf-green stitching.
const FELT_DARK := FOREST
const FELT := Color(0.078, 0.43, 0.137)
const STITCH := LEAF
## Dark forest backing of the HUD boxes and notices (stays readable over the world).
const HUD_BG := Color(0.0, 0.2, 0.1, 0.88)
## Cream / tan plates (titles, buttons, slots, cards).
const CREAM := Color8(236, 222, 186)
const TAN := Color(0.97, 0.79, 0.53)
const SLOT_FILL := Color8(176, 136, 92)
const BROWN := Color8(96, 72, 48)
const GOLD := AMBER
## Parchment pages (journal, map).
const PAGE := Color8(236, 222, 186)
const PAGE_DARK := Color8(214, 196, 152)
## Text on cream (dark, mid, faded) and on felt / dark backgrounds (light, dim).
const TEXT_DARK := Color8(58, 42, 30)
const TEXT_MID := Color8(110, 84, 60)
const FADED := Color8(150, 126, 98)
const TEXT_LIGHT := Color8(238, 226, 196)
const TEXT_DIM := Color8(186, 176, 152)
## Screen dimmer behind an open panel.
const SHADE := Color(0.03, 0.05, 0.08, 0.72)
