extends SceneTree
## Pixel art for the late-game systems (death remains, survival props, sectors,
## settlement, glyphs...). Same conventions as generate_placeholder_art.gd:
## cel-shaded tones dark -> light, 1px dark outline, 32px icons + 16px copies.
## Some sprites are Dungeon Crawl Stone Soup tiles (CC0) vendored in
## tools/third_party/dcss/extra (see CREDITS.md).
##
##   godot --headless --path . --script res://tools/generate_roadmap_art.gd
##   godot --headless --path . --editor --quit

const OUTLINE := Color8(24, 22, 32)
const DCSS_EXTRA := "res://tools/third_party/dcss/extra"
const LEATHER := [Color8(66, 40, 26), Color8(98, 62, 38), Color8(132, 88, 54), Color8(170, 120, 74), Color8(204, 160, 104)]
const BONE := [Color8(150, 140, 116), Color8(196, 186, 160), Color8(226, 218, 196), Color8(246, 242, 226)]
const STONE := [Color8(44, 51, 52), Color8(70, 80, 78), Color8(98, 110, 104), Color8(132, 144, 134), Color8(170, 182, 168)]
const WOOD := [Color8(56, 38, 30), Color8(80, 54, 38), Color8(120, 82, 50), Color8(160, 114, 68), Color8(194, 150, 92)]
const WATER := [Color8(30, 60, 110), Color8(44, 96, 150), Color8(70, 140, 190), Color8(130, 196, 230), Color8(214, 240, 250)]
const FIRE := [Color8(140, 40, 36), Color8(210, 76, 44), Color8(246, 168, 60), Color8(255, 240, 160)]
const GLOW := [Color8(40, 110, 110), Color8(70, 170, 160), Color8(120, 230, 210), Color8(210, 255, 244)]


func _init() -> void:
	for dir in ["res://assets/sprites/structures", "res://assets/ui/items", "res://assets/sprites/props", "res://assets/sprites/npcs", "res://assets/sprites/enemies"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_remains(), "res://assets/sprites/remains.png")
	_sector_art()
	print("Roadmap art generated.")
	quit()


# ---------------------------------------------------------------- sectors

## New resource nodes: existing sprites recoloured [source, hue (-1 keeps), sat mul, sat add, value mul].
const NODE_RECOLORS := {
	"thornbush": ["blueberry", 0.27, 0.8, 0.1, 0.8], "giant_fern": ["grass", 0.33, 1.0, 0.1, 0.9],
	"hive_comb": ["beehive", 0.13, 0.9, 0.1, 1.15], "spore_pod": ["mushroom", 0.08, 0.8, 0.1, 1.0],
	"root_knot": ["resin_stump", 0.2, 0.9, 0.15, 0.9], "moonflower": ["flower", 0.6, 0.6, 0.0, 1.25],
	"sandstone": ["rubble", 0.09, 1.0, 0.4, 1.2], "dry_bush": ["grass", 0.1, 0.5, 0.05, 1.0],
	"salt_flat": ["sand", -1.0, 0.0, 0.0, 1.3], "amber_deposit": ["ore_gold", 0.07, 1.1, 0.1, 1.0],
	"date_palm": ["apple_tree", 0.16, 0.8, 0.0, 1.0], "fossil": ["bone_pile", 0.1, 1.0, 0.25, 0.85],
	"sunstone": ["ore_crystal", 0.13, 1.1, 0.2, 1.1],
	"frost_lichen": ["cave_moss", 0.5, 0.4, 0.0, 1.3], "snow_drift": ["sand", 0.58, 0.15, 0.0, 1.4],
	"ore_mithril": ["ore_silver", 0.52, 1.0, 0.3, 1.05], "blue_crystal": ["ore_crystal", 0.6, 1.0, 0.1, 1.0],
	"frozen_tree": ["apple_tree", 0.56, 0.3, 0.05, 1.3], "snowberry": ["blueberry", 0.58, 0.3, 0.0, 1.35],
	"basalt": ["rubble", 0.75, 0.3, 0.0, 0.55], "magma_vent": ["obsidian", 0.05, 1.0, 0.6, 1.4],
	"ash_pile": ["sand", -1.0, 0.0, 0.0, 0.7], "ore_ember": ["ore_copper", 0.01, 1.2, 0.2, 1.0],
	"fire_lily": ["flower", 0.03, 1.2, 0.2, 1.0], "charred_stump": ["resin_stump", 0.05, 0.2, 0.0, 0.45],
	"soul_crystal": ["ore_crystal", 0.46, 1.0, 0.1, 1.0], "blood_moss": ["cave_moss", 0.98, 1.0, 0.4, 0.9],
	"ore_hellsteel": ["ore_iron", 0.0, 1.0, 0.45, 0.75], "brimstone": ["sulfur", 0.12, 1.2, 0.2, 1.1],
	"hellfire_bloom": ["shadow_orchid", 0.02, 1.0, 0.5, 1.2],
}

## New item icons: existing icons recoloured (same fields as NODE_RECOLORS).
const ICON_RECOLORS := {
	"thorn": ["fang", 0.28, 1.0, 0.5, 0.7], "living_root": ["vine", 0.2, 1.0, 0.1, 0.9],
	"moon_petal": ["petals", 0.58, 0.6, 0.0, 1.2], "royal_jelly": ["honey", 0.14, 0.5, 0.0, 1.2],
	"amber": ["resin", 0.08, 1.2, 0.1, 1.0], "sunstone": ["crystal", 0.13, 1.0, 0.2, 1.1],
	"fossil": ["bone", 0.1, 1.0, 0.25, 0.85], "salt": ["sand", -1.0, 0.0, 0.0, 1.3],
	"sandstone": ["stone", 0.09, 1.0, 0.4, 1.15], "cactus_pulp": ["herb", 0.32, 1.0, 0.0, 1.0],
	"dates": ["berry", 0.07, 0.8, 0.0, 0.7], "ice": ["glass", 0.55, 1.0, 0.1, 1.1],
	"frost_crystal": ["crystal", 0.58, 1.0, 0.0, 1.0], "mithril_ore": ["silver_ore", 0.52, 1.0, 0.3, 1.0],
	"snowberry": ["blueberry", 0.58, 0.3, 0.0, 1.3], "frost_pelt": ["fur", -1.0, 0.0, 0.0, 1.6],
	"basalt": ["stone", 0.75, 0.3, 0.0, 0.55], "magma_core": ["glow_gland", 0.05, 1.2, 0.3, 1.0],
	"ash": ["sand", -1.0, 0.0, 0.0, 0.7], "ember_ore": ["copper_ore", 0.01, 1.2, 0.2, 1.0],
	"fire_petal": ["petals", 0.04, 1.2, 0.2, 1.0], "fire_gland": ["glow_gland", 0.02, 1.2, 0.3, 1.0],
	"demon_horn": ["horn", 0.0, 1.0, 0.5, 0.6], "soul_shard": ["crystal", 0.45, 1.0, 0.0, 1.0],
	"cursed_bone": ["bone", 0.8, 1.0, 0.2, 0.9], "hellsteel_ore": ["iron_ore", 0.0, 1.0, 0.4, 0.7],
	"brimstone": ["sulfur", 0.12, 1.2, 0.2, 1.1], "blood_moss": ["moss", 0.98, 1.0, 0.4, 0.9],
	"mithril_ingot": ["iron_ingot", 0.52, 1.0, 0.3, 1.05], "ember_ingot": ["copper_ingot", 0.02, 1.2, 0.2, 1.0],
	"hellsteel_ingot": ["iron_ingot", 0.0, 1.0, 0.45, 0.6],
	"mithril_axe": ["iron_axe", 0.52, 1.0, 0.3, 1.05], "mithril_pickaxe": ["iron_pickaxe", 0.52, 1.0, 0.3, 1.05],
	"mithril_sword": ["iron_sword", 0.52, 1.0, 0.3, 1.05], "ember_blade": ["obsidian_blade", 0.03, 1.0, 0.6, 1.5],
	"hellsteel_pickaxe": ["obsidian_pickaxe", 0.0, 1.0, 0.5, 1.1], "hellsteel_greatsword": ["crystal_blade", 0.0, 1.0, 0.5, 0.7],
	"bone_crown": ["horned_helm", 0.8, 1.0, 0.2, 1.0], "druid_staff": ["arc_staff", 0.25, 1.0, 0.0, 0.9],
	"frost_staff": ["arc_staff", 0.55, 1.0, 0.0, 1.1], "fire_staff": ["arc_staff", 0.04, 1.0, 0.4, 1.0],
	"ember_bow": ["long_bow", 0.03, 1.0, 0.4, 1.1], "thorn_arrow": ["flint_arrow", 0.28, 1.0, 0.4, 1.0],
	"mithril_arrow": ["iron_arrow", 0.52, 1.0, 0.3, 1.05], "fire_arrow": ["blast_arrow", 0.06, 1.0, 0.2, 1.1],
	"parka": ["fur_coat", -1.0, 0.0, 0.0, 1.7], "snow_boots": ["fur_boots", -1.0, 0.0, 0.0, 1.7],
	"desert_wrap": ["leather_cap", 0.12, 0.5, 0.1, 1.4], "sun_robe": ["silk_robe", 0.12, 1.0, 0.4, 1.0],
	"fire_cloak": ["wool_tunic", -1.0, 0.0, 0.0, 0.7], "ember_helm": ["iron_helm", 0.03, 1.0, 0.5, 1.0],
	"mithril_helm": ["iron_helm", 0.52, 1.0, 0.3, 1.05], "mithril_armor": ["iron_armor", 0.52, 1.0, 0.3, 1.05],
	"mithril_boots": ["iron_boots", 0.52, 1.0, 0.3, 1.05], "mithril_shield": ["iron_shield", 0.52, 1.0, 0.3, 1.05],
	"basalt_shield": ["iron_shield", 0.75, 0.3, 0.0, 0.5], "hellsteel_helm": ["obsidian_helm", 0.0, 1.0, 0.5, 1.1],
	"hellsteel_plate": ["obsidian_plate", 0.0, 1.0, 0.5, 1.1], "hellsteel_boots": ["obsidian_boots", 0.0, 1.0, 0.5, 1.1],
	"amber_amulet": ["gold_amulet", 0.08, 1.2, 0.0, 1.0], "fossil_charm": ["bone_charm", 0.1, 1.0, 0.1, 0.9],
	"soul_amulet": ["crystal_amulet", 0.45, 1.0, 0.0, 1.0], "sunstone_ring": ["gold_ring", 0.13, 1.2, 0.1, 1.1],
	"frost_ring": ["silver_ring", 0.58, 1.0, 0.3, 1.0], "demon_ring": ["obsidian_ring", 0.0, 1.0, 0.5, 1.2],
	"jerky": ["cooked_meat", 0.03, 0.8, 0.0, 0.8], "cactus_salad": ["forest_salad", 0.3, 1.0, 0.0, 1.0],
	"date_cake": ["honey_cake", 0.07, 1.0, 0.1, 0.8], "snowberry_tart": ["blueberry_pie", 0.58, 0.4, 0.0, 1.2],
	"spiced_stew": ["meat_stew", 0.03, 1.2, 0.2, 1.0], "cooling_draught": ["healing_potion", 0.55, 1.0, 0.0, 1.0],
	"warming_tonic": ["stamina_tonic", 0.06, 1.0, 0.0, 1.0], "moon_elixir": ["greater_potion", 0.6, 0.6, 0.0, 1.2],
	"blood_salve": ["healing_salve", 0.98, 1.0, 0.3, 0.9],
}


func _sector_art() -> void:
	for id in NODE_RECOLORS:
		var r: Array = NODE_RECOLORS[id]
		_save(_recolor("res://assets/sprites/resources/%s.png" % r[0], r[1], r[2], r[3], r[4]), "res://assets/sprites/resources/%s.png" % id)
	for id in ICON_RECOLORS:
		var r: Array = ICON_RECOLORS[id]
		_icon(_recolor("res://assets/ui/items/%s.png" % r[0], r[1], r[2], r[3], r[4]), id)
	# Hand-drawn nodes for shapes no existing sprite has.
	_save(_cactus(), "res://assets/sprites/resources/cactus.png")
	_save(_ice_block(), "res://assets/sprites/resources/ice_block.png")
	_save(_bone_spire(), "res://assets/sprites/resources/bone_spire.png")
	for k in ["key_stone", "key_overgrowth", "key_desert", "key_ice", "key_volcano", "key_hell"]:
		_icon(_fit32(_dcss(k, 28)), k)
	var well := _fit32(_dcss("well", 30))
	_save(well, "res://assets/sprites/structures/well.png")
	_icon(well, "well")
	var torch := _standing_torch()
	_save(torch, "res://assets/sprites/structures/standing_torch.png")
	_icon(torch, "standing_torch")
	var stone := _waystone()
	_save(stone, "res://assets/sprites/structures/waystone.png")
	_icon(stone, "waystone")
	_icon(_waterskin(false), "waterskin")
	_icon(_waterskin(true), "waterskin_full")
	_save(_sector_gate(), "res://assets/sprites/props/sector_gate.png")
	var altar := _fit32(_dcss("skill_altar", 30))
	_save(altar, "res://assets/sprites/structures/skill_altar.png")
	_icon(altar, "skill_altar")
	_icon(_memory_shard(), "memory_shard")


## Pale violet crystal splinter with a bright core (Bound respec resource).
func _memory_shard() -> Image:
	var img := _img(32, 32)
	var tones := [Color8(70, 44, 110), Color8(118, 82, 170), Color8(172, 140, 226), Color8(226, 212, 255)]
	for y in range(5, 28):
		var t := float(y - 5) / 22.0
		var half := int(round(6.0 * (1.0 - absf(t - 0.4) / 0.6)))
		for x in range(16 - half, 17 + half):
			var side := float(x - 16) / maxf(half, 1)
			var tone := 2 if side < -0.2 else (1 if side > 0.35 else 3)
			if y > 22:
				tone = maxi(tone - 1, 0)
			_px(img, x - int(t * 3.0), y, tones[tone])
	_rect(img, 14, 11, 2, 5, Color.WHITE)
	_px(img, 22, 8, tones[3])
	_px(img, 8, 20, tones[2])
	return _outline(img)


## Loads a PNG and moves its colours: hue set (or kept when < 0), saturation
## scaled and offset, value scaled. Near-black outline pixels are kept.
func _recolor(path: String, hue: float, sat_mul: float, sat_add: float, val_mul: float) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0 or c.v < 0.16:
				continue
			var h := c.h if hue < 0.0 else hue
			var s := clampf(c.s * sat_mul + (sat_add if c.s > 0.05 or sat_mul == 0.0 else sat_add * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color.from_hsv(h, s, clampf(c.v * val_mul, 0.0, 1.0), c.a))
	return img


## Centres an image on a transparent 32x32 canvas (bottom-aligned).
func _fit32(src: Image) -> Image:
	var img := _img(32, 32)
	var w := mini(src.get_width(), 32)
	var h := mini(src.get_height(), 32)
	img.blit_rect(src, Rect2i(0, 0, w, h), Vector2i((32 - w) / 2, 32 - h))
	return img


func _cactus() -> Image:
	var img := _img(32, 32)
	var g := [Color8(30, 70, 40), Color8(50, 110, 56), Color8(80, 150, 72), Color8(130, 190, 100)]
	_rect(img, 13, 6, 6, 24, g[1])
	_rect(img, 14, 6, 3, 24, g[2])
	_rect(img, 14, 7, 1, 22, g[3])
	_rect(img, 7, 12, 4, 10, g[1]); _rect(img, 8, 12, 2, 10, g[2]); _rect(img, 7, 20, 6, 3, g[1])
	_rect(img, 21, 9, 4, 10, g[1]); _rect(img, 22, 9, 2, 10, g[2]); _rect(img, 19, 17, 6, 3, g[1])
	for p in [Vector2i(12, 10), Vector2i(19, 14), Vector2i(12, 20), Vector2i(19, 24), Vector2i(6, 15), Vector2i(25, 12)]:
		_px(img, p.x, p.y, BONE[3])
	_blob(img, 16, 5, 2.5, 2, [Color8(200, 60, 100), Color8(240, 110, 150), Color8(255, 190, 210)], 0.1, 4)
	_rect(img, 12, 29, 8, 2, Color8(60, 46, 30))
	return _outline(img)


func _ice_block() -> Image:
	var img := _img(32, 32)
	var ice := [Color8(60, 110, 160), Color8(110, 170, 220), Color8(170, 220, 245), Color8(230, 248, 255)]
	_box(img, 6, 12, 20, 18, ice, 9)
	_box(img, 10, 6, 13, 10, ice, 11)
	_line(img, Vector2(9, 15), Vector2(14, 26), ice[3])
	_line(img, Vector2(13, 9), Vector2(16, 14), ice[3])
	_line(img, Vector2(22, 16), Vector2(19, 27), ice[0])
	return _outline(img)


func _bone_spire() -> Image:
	var img := _img(32, 32)
	var b := [Color8(110, 90, 120), Color8(160, 140, 170), Color8(200, 186, 206), Color8(236, 228, 240)]
	for i in 26:
		var w := int(2 + i / 4.0)
		_rect(img, 16 - w / 2, 4 + i, w, 1, b[1])
		_px(img, 16 - w / 2, 4 + i, b[3])
		_px(img, 16 + (w - 1) / 2, 4 + i, b[0])
	_line(img, Vector2(9, 30), Vector2(5, 16), b[2], 2)
	_line(img, Vector2(23, 30), Vector2(27, 19), b[2], 2)
	_blob(img, 16, 18, 2, 1.5, [Color8(110, 30, 40), Color8(200, 40, 60), Color8(250, 120, 120)], 0.0, 1)
	return _outline(img)


func _standing_torch() -> Image:
	var img := _img(32, 32)
	_rect(img, 15, 12, 3, 17, WOOD[2])
	_rect(img, 15, 12, 1, 17, WOOD[3])
	_rect(img, 12, 28, 9, 3, STONE[2])
	_rect(img, 12, 28, 9, 1, STONE[4])
	_rect(img, 13, 11, 7, 3, LEATHER[1])
	_blob(img, 16.5, 7, 4, 5, FIRE, 0.25, 7)
	_blob(img, 16.5, 8.5, 2, 2.5, [FIRE[2], FIRE[3]], 0.1, 8)
	return _outline(img)


func _waystone() -> Image:
	var img := _img(32, 32)
	for y in range(3, 29):
		var w := 12 if y > 6 else 12 - (7 - y) * 2
		for x in range(16 - w / 2, 16 + w / 2):
			var col: Color = STONE[2]
			if x == 16 - w / 2 or y == 3:
				col = STONE[4]
			elif x == 16 + w / 2 - 1:
				col = STONE[0]
			elif _hash(x, y, 3) > 0.82:
				col = STONE[1]
			_px(img, x, y, col)
	_rect(img, 7, 27, 18, 4, STONE[1])
	_rect(img, 7, 27, 18, 1, STONE[3])
	for p in [Vector2(13, 10), Vector2(19, 10), Vector2(16, 13), Vector2(13, 19), Vector2(19, 19), Vector2(16, 22)]:
		_rect(img, int(p.x), int(p.y), 1, 1, GLOW[3])
	_line(img, Vector2(13, 10), Vector2(16, 13), GLOW[2])
	_line(img, Vector2(19, 10), Vector2(16, 13), GLOW[2])
	_line(img, Vector2(16, 13), Vector2(16, 22), GLOW[2])
	_line(img, Vector2(13, 19), Vector2(19, 19), GLOW[1])
	return _outline(img)


func _waterskin(full: bool) -> Image:
	var img := _img(32, 32)
	var tones: Array = [WATER[0], LEATHER[1], LEATHER[2], LEATHER[3]] if full else LEATHER
	_blob(img, 16, 19, 9 if full else 7, 8 if full else 7, tones, 0.12, 2)
	_rect(img, 14, 6, 4, 6, LEATHER[2])
	_rect(img, 14, 6, 1, 6, LEATHER[3])
	_rect(img, 13, 4, 6, 2, WOOD[1])
	_line(img, Vector2(9, 14), Vector2(15, 9), LEATHER[0])
	if full:
		_blob(img, 23, 9, 2, 2.5, WATER, 0.0, 3)
	return _outline(img)


## Sealed stone door spanning a 3-tile passage, with a glowing key glyph.
func _sector_gate() -> Image:
	var img := _img(96, 48)
	_box(img, 0, 6, 12, 42, STONE, 21)
	_box(img, 84, 6, 12, 42, STONE, 22)
	_box(img, 0, 0, 96, 8, STONE, 23)
	for i in 3:
		_box(img, 12 + i * 24, 8, 24, 40, [Color8(40, 44, 48), Color8(62, 68, 70), Color8(86, 94, 92), Color8(112, 122, 116)], 30 + i)
	for x in [24, 48, 72]:
		_rect(img, x - 1, 8, 2, 40, STONE[0])
	_rect(img, 12, 18, 72, 2, Color8(60, 50, 40))
	_rect(img, 12, 36, 72, 2, Color8(60, 50, 40))
	_blob(img, 48, 27, 7, 7, STONE, 0.1, 5)
	_line(img, Vector2(48, 22), Vector2(48, 32), GLOW[3], 2)
	_line(img, Vector2(44, 25), Vector2(52, 25), GLOW[2])
	_rect(img, 46, 30, 5, 2, GLOW[2])
	return _outline(img)


# ---------------------------------------------------------------- helpers

func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


func _icon(img: Image, id: String) -> void:
	_save(img, "res://assets/ui/items/%s.png" % id)
	var small := img.duplicate() as Image
	small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
	_save(small, "res://assets/ui/items/%s_s.png" % id)


func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _hash(x: int, y: int, s: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + s * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, col)


## Cel-shaded ellipse lit from the upper left; tones dark -> light.
func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, tones: Array, jitter := 0.1, seed := 0) -> void:
	var light := Vector3(-0.5, -0.7, 0.55).normalized()
	for y in range(int(floor(cy - ry)) - 1, int(ceil(cy + ry)) + 2):
		for x in range(int(floor(cx - rx)) - 1, int(ceil(cx + rx)) + 2):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			var d := nx * nx + ny * ny
			if d > 1.0:
				continue
			var lit := Vector3(nx, ny, sqrt(maxf(0.0, 1.0 - d))).dot(light) + (_hash(x, y, seed) - 0.5) * jitter
			_px(img, x, y, tones[int(clampf((lit + 0.45) / 1.35, 0.0, 0.999) * tones.size())])


## Bevelled box: light top/left edge, dark bottom/right edge.
func _box(img: Image, x: int, y: int, w: int, h: int, tones: Array, seed := 0) -> void:
	var n: int = tones.size()
	for yy in h:
		for xx in w:
			var col: Color = tones[n / 2]
			if _hash(x + xx, y + yy, seed) > 0.8:
				col = tones[n / 2 - 1]
			if yy == 0 or xx == 0:
				col = tones[n - 1]
			elif yy == h - 1 or xx == w - 1:
				col = tones[0]
			elif yy == h - 2:
				col = tones[1]
			_px(img, x + xx, y + yy, col)


func _line(img: Image, a: Vector2, b: Vector2, col: Color, width := 1) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in steps + 1:
		var p := a.lerp(b, float(i) / maxf(steps, 1))
		_rect(img, int(round(p.x)) - width / 2, int(round(p.y)) - width / 2, width, width, col)


func _outline(img: Image, color := OUTLINE) -> Image:
	var src := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, color)
					break
	return img


## A vendored DCSS tile, outlined and optionally scaled to `size` px.
func _dcss(rel: String, size := 32) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [DCSS_EXTRA, rel]))
	if img == null:
		push_error("Missing DCSS tile " + rel)
		return _img(32, 32)
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x > 0:
		img = img.get_region(used)
	var scale := float(size) / maxf(img.get_width(), img.get_height())
	if absf(scale - 1.0) > 0.01:
		img.resize(maxi(int(round(img.get_width() * scale)), 1), maxi(int(round(img.get_height() * scale)), 1), Image.INTERPOLATE_NEAREST)
	var out := _img(img.get_width() + 2, img.get_height() + 2)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(1, 1))
	return _outline(out)


# ---------------------------------------------------------------- sprites

## Torn backpack spilling its contents, with a bleached bone.
func _remains() -> Image:
	var img := _img(26, 20)
	_blob(img, 13, 12, 9, 6.5, LEATHER, 0.15, 3)
	_rect(img, 8, 7, 10, 2, LEATHER[1])
	_rect(img, 9, 6, 8, 1, LEATHER[3])
	_line(img, Vector2(6, 11), Vector2(20, 11), LEATHER[0])
	_blob(img, 21, 15, 2.5, 2, [Color8(150, 40, 50), Color8(210, 70, 80), Color8(250, 150, 160)], 0.1, 5)
	_blob(img, 5, 15, 2.2, 1.8, [Color8(90, 100, 110), Color8(150, 156, 164), Color8(200, 204, 210)], 0.1, 6)
	_line(img, Vector2(3, 18), Vector2(12, 16), BONE[2], 2)
	_px(img, 2, 17, BONE[3]); _px(img, 2, 19, BONE[1]); _px(img, 13, 15, BONE[3]); _px(img, 13, 17, BONE[1])
	return _outline(img)
