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
	for dir in ["res://assets/sprites/structures", "res://assets/ui/icons/items/small", "res://assets/sprites/environment/landmarks", "res://assets/sprites/characters/survivors", "res://assets/sprites/enemies"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_save(_remains(), "res://assets/sprites/environment/remains.png")
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
		_save(_recolor("res://assets/sprites/environment/gatherables/%s.png" % r[0], r[1], r[2], r[3], r[4]), "res://assets/sprites/environment/gatherables/%s.png" % id)
	for id in ICON_RECOLORS:
		var r: Array = ICON_RECOLORS[id]
		_icon(_recolor("res://assets/ui/icons/items/%s.png" % r[0], r[1], r[2], r[3], r[4]), id)
	# Hand-drawn nodes for shapes no existing sprite has.
	_save(_cactus(), "res://assets/sprites/environment/gatherables/cactus.png")
	_save(_ice_block(), "res://assets/sprites/environment/gatherables/ice_block.png")
	_save(_bone_spire(), "res://assets/sprites/environment/gatherables/bone_spire.png")
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
	_save(_sector_gate(), "res://assets/sprites/environment/landmarks/sector_gate.png")
	var altar := _fit32(_dcss("skill_altar", 30))
	_save(altar, "res://assets/sprites/structures/skill_altar.png")
	_icon(altar, "skill_altar")
	_icon(_memory_shard(), "memory_shard")
	for s in ["statue_angel", "statue_dragon", "statue_guardian", "statue_hero", "statue_sword", "statue_twins", "column"]:
		_save(_dcss(s, 36), "res://assets/sprites/environment/landmarks/landmark_%s.png" % s)
	_save(_old_engine(), "res://assets/sprites/environment/landmarks/landmark_old_engine.png")
	_save(_glyph_stone(false), "res://assets/sprites/environment/landmarks/glyph_stone.png")
	_save(_glyph_stone(true), "res://assets/sprites/environment/landmarks/glyph_stone_read.png")
	# Survivor sprites (npcs/) are drawn by generate_placeholder_art.gd in the player's style.
	var bed := _bed()
	_save(bed, "res://assets/sprites/structures/bed.png")
	_icon(bed, "bed")


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
	# Stone footing.
	_blob(img, 16, 28.5, 6.5, 2.6, STONE, 0.15, 5)
	_rect(img, 11, 27, 11, 1, STONE[4])
	# Pole: cylinder shading with a few grain marks.
	for y in range(11, 28):
		_px(img, 15, y, WOOD[3])
		_px(img, 16, y, WOOD[2])
		_px(img, 17, y, WOOD[1])
		if _hash(y, 0, 9) > 0.75:
			_px(img, 16, y, WOOD[1])
	_rect(img, 14, 18, 5, 2, LEATHER[1])
	_rect(img, 14, 18, 5, 1, LEATHER[3])
	# Iron cage holding the fire.
	_rect(img, 12, 10, 9, 2, Color8(70, 74, 84))
	_rect(img, 12, 10, 9, 1, Color8(150, 156, 168))
	for x in [12, 16, 20]:
		_line(img, Vector2(x, 10), Vector2(x, 6), Color8(90, 96, 108))
	# Flame: outer tongue, hot middle, bright core.
	var layers := [[FIRE[0], 9, 4.5], [FIRE[1], 8, 3.6], [FIRE[2], 6, 2.4], [FIRE[3], 3, 1.2]]
	for layer in layers:
		var hgt: int = layer[1]
		var wmax: float = layer[2]
		for y in hgt:
			var fr := float(y) / hgt
			var hw := wmax * pow(1.0 - fr, 0.7)
			var sway := sin(fr * 3.0) * 1.2 * fr
			for x in range(int(16.5 + sway - hw), int(16.5 + sway + hw) + 1):
				_px(img, x, 10 - y, layer[0])
	_outline(img)
	_px(img, 19, 0, FIRE[3])
	_px(img, 13, 1, FIRE[2])
	return img


## Tall carved monolith; the rune channels hold a faint teal glow.
func _waystone() -> Image:
	var img := _img(32, 32)
	# Rubble base with moss.
	_blob(img, 16, 28, 11, 3.2, STONE, 0.2, 31)
	for y in range(2, 28):
		var w := 6.0 - (y - 2) * 0.02 if y > 6 else 6.0 - (6 - y) * 0.9
		for x in range(int(16 - w), int(16 + w) + 1):
			var u := (x + 0.5 - (16 - w)) / (w * 2.0)
			var t := 3 if u < 0.2 else (2 if u < 0.62 else (1 if u < 0.9 else 0))
			if y < 5 and u > 0.15 and u < 0.85:
				t = 4
			# Chiselled block courses.
			if y == 12 or y == 20:
				t = 0
			elif y == 13 or y == 21:
				t = mini(t + 1, 4)
			elif _hash(x, y, 3) > 0.88:
				t = maxi(t - 1, 0)
			_px(img, x, y, STONE[t])
	for p in [Vector2i(10, 25), Vector2i(11, 26), Vector2i(12, 26), Vector2i(21, 26), Vector2i(20, 24), Vector2i(10, 23)]:
		_px(img, p.x, p.y, Color8(84, 120, 60))
		_px(img, p.x, p.y - 1, Color8(120, 160, 80))
	# Rune channels: dark groove with a glowing core.
	var rune := [[Vector2(13, 7), Vector2(16, 10)], [Vector2(19, 7), Vector2(16, 10)], [Vector2(16, 10), Vector2(16, 18)],
		[Vector2(13, 15), Vector2(19, 15)], [Vector2(14, 23), Vector2(18, 23)]]
	for seg in rune:
		_line(img, seg[0] + Vector2(1, 1), seg[1] + Vector2(1, 1), STONE[0])
	for seg in rune:
		_line(img, seg[0], seg[1], GLOW[2])
	for p in [Vector2i(16, 10), Vector2i(16, 15), Vector2i(13, 7), Vector2i(19, 7)]:
		_px(img, p.x, p.y, GLOW[3])
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



## Wooden bed in 3/4 view: headboard with posts, plump pillow, a folded
## tartan wool blanket over a straw mattress, and the footboard's front face.
func _bed() -> Image:
	var img := _img(32, 32)
	# Side rails and the frame behind the mattress.
	_box(img, 5, 6, 22, 23, WOOD, 61)
	# Mattress (straw ticking) with a soft lit edge.
	for y in range(8, 27):
		for x in range(7, 25):
			var col := Color8(220, 200, 150)
			if x == 7 or y == 8:
				col = Color8(240, 226, 186)
			elif x == 24:
				col = Color8(176, 150, 100)
			elif _hash(x, y, 62) > 0.86:
				col = Color8(198, 174, 120)
			_px(img, x, y, col)
	# Pillow: rounded, lit from the upper left, with a crease.
	for y in range(9, 15):
		for x in range(9, 23):
			var u := (x - 15.5) / 7.0
			var v := (y - 11.5) / 3.2
			if u * u * u * u + v * v * v * v > 1.0:
				continue
			var lit := -u * 0.5 - v * 0.8
			var col := Color8(232, 228, 216)
			if lit > 0.35:
				col = Color8(252, 250, 244)
			elif lit < -0.45:
				col = Color8(184, 180, 172)
			_px(img, x, y, col)
	_line(img, Vector2(12, 12), Vector2(19, 12), Color8(206, 202, 192))
	# Blanket: red tartan, folded back at the top, draping over the rails.
	var wool := [Color8(92, 36, 38), Color8(142, 54, 50), Color8(182, 78, 62), Color8(214, 112, 86), Color8(238, 154, 120)]
	for y in range(15, 29):
		for x in range(5, 27):
			var col: Color = wool[2]
			if (x - 5) % 6 == 2 or (y - 15) % 6 == 3:
				col = wool[1]
			if (x - 5) % 6 == 2 and (y - 15) % 6 == 3:
				col = wool[0]
			if (x - 5) % 6 == 5 or (y - 15) % 6 == 0:
				col = Color8(222, 196, 140)
			if x <= 6:
				col = col.darkened(0.12)
			elif x >= 25:
				col = col.darkened(0.3)
			_px(img, x, y, col)
	_rect(img, 5, 15, 22, 3, wool[3])
	_rect(img, 5, 15, 22, 1, wool[4])
	_rect(img, 5, 17, 22, 1, wool[0])
	for x in range(6, 26, 3):
		_px(img, x, 16, Color8(222, 196, 140))
	# Headboard with two round-topped posts.
	_box(img, 4, 1, 24, 6, WOOD, 63)
	_rect(img, 6, 3, 20, 1, WOOD[1])
	for px in [3, 26]:
		_box(img, px, 0, 3, 8, WOOD, 64)
		_px(img, px + 1, 0, WOOD[4])
	# Footboard front face.
	_box(img, 4, 28, 24, 3, WOOD, 65)
	_rect(img, 4, 28, 24, 1, WOOD[4])
	for px in [3, 26]:
		_box(img, px, 26, 3, 5, WOOD, 66)
	return _outline(img)


## Rusted machine half-swallowed by the maze: a big cog, pipes and a dead lamp.
func _old_engine() -> Image:
	var img := _img(34, 34)
	var rust := [Color8(70, 40, 30), Color8(116, 64, 40), Color8(160, 96, 56), Color8(196, 136, 80)]
	var iron := [Color8(40, 44, 50), Color8(66, 72, 80), Color8(98, 106, 114), Color8(140, 150, 156)]
	_box(img, 4, 14, 26, 18, iron, 41)
	_box(img, 7, 18, 8, 10, rust, 42)
	for a in 8:
		var ang := a * TAU / 8.0
		var p := Vector2(22, 13) + Vector2.from_angle(ang) * 9.0
		_rect(img, int(p.x) - 1, int(p.y) - 1, 3, 3, rust[1])
	_blob(img, 22, 13, 8, 8, rust, 0.15, 43)
	_blob(img, 22, 13, 3, 3, iron, 0.0, 44)
	_rect(img, 2, 8, 3, 22, iron[2])
	_rect(img, 2, 8, 9, 3, iron[2])
	_rect(img, 2, 8, 1, 22, iron[3])
	_blob(img, 26, 26, 2.5, 2.5, [Color8(60, 90, 70), Color8(90, 160, 120), Color8(170, 240, 200)], 0.0, 45)
	for i in 5:
		_px(img, 6 + i * 5, 31, Color8(60, 110, 50))
		_px(img, 7 + i * 5, 30, Color8(80, 140, 60))
	return _outline(img)


## Upright slab carved with a spiral glyph; read stones glow.
func _glyph_stone(read: bool) -> Image:
	var img := _img(26, 32)
	for y in range(2, 30):
		var w := 18 if y > 7 else 18 - (8 - y) * 2
		for x in range(13 - w / 2, 13 + w / 2):
			var col: Color = STONE[2]
			if x == 13 - w / 2 or y == 2:
				col = STONE[3]
			elif x == 13 + w / 2 - 1:
				col = STONE[0]
			elif _hash(x, y, 9) > 0.8:
				col = STONE[1]
			_px(img, x, y, col)
	_rect(img, 3, 28, 20, 3, STONE[1])
	var ink: Color = GLOW[3] if read else Color8(40, 46, 48)
	var ink2: Color = GLOW[2] if read else Color8(60, 68, 70)
	_line(img, Vector2(9, 9), Vector2(17, 9), ink)
	_line(img, Vector2(17, 9), Vector2(17, 17), ink)
	_line(img, Vector2(17, 17), Vector2(11, 17), ink)
	_line(img, Vector2(11, 17), Vector2(11, 13), ink2)
	_line(img, Vector2(11, 13), Vector2(14, 13), ink2)
	_line(img, Vector2(9, 21), Vector2(17, 21), ink2)
	_rect(img, 12, 24, 3, 2, ink)
	for y in range(6, 12):
		_px(img, 5, y, Color8(70, 120, 60))
	_px(img, 6, 11, Color8(90, 150, 70))
	return _outline(img)


# ---------------------------------------------------------------- helpers

func _save(img: Image, path: String) -> void:
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save %s (%d)" % [path, err])


func _icon(img: Image, id: String) -> void:
	_save(img, "res://assets/ui/icons/items/%s.png" % id)
	var small := img.duplicate() as Image
	small.resize(16, 16, Image.INTERPOLATE_LANCZOS)
	_save(small, "res://assets/ui/icons/items/small/%s.png" % id)


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


## Same finish as the placeholder generator's _ink: a lit top rim, a shaded
## bottom/right rim and a selective outline (deep shade of the neighbouring
## colour on top, pure ink below so sprites stay grounded).
func _outline(img: Image, color := OUTLINE) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5 or c == color:
				continue
			if not solid.call(x, y - 1):
				img.set_pixel(x, y, c.lightened(0.14))
			elif not solid.call(x, y + 1) or not solid.call(x + 1, y):
				img.set_pixel(x, y, c.darkened(0.16))
	src = img.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var sum := Vector3.ZERO
			var n := 0
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixel(q.x, q.y).a > 0.5:
					var nc := src.get_pixel(q.x, q.y)
					sum += Vector3(nc.r, nc.g, nc.b)
					n += 1
			if n == 0:
				continue
			var ink: Color = color
			if not solid.call(x, y - 1):
				ink = Color(sum.x / n, sum.y / n, sum.z / n).darkened(0.72).lerp(color, 0.35)
			img.set_pixel(x, y, ink)
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
