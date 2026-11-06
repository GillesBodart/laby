class_name Pond
extends RefCounted
## Pond shape and art. A pond is a union of ellipses ("blobs": [{c, r}] in cell
## units) merged as a metaball field: field >= 1 is water, slightly lower is the
## muddy bank where reeds grow. The generator uses field() for gameplay cells;
## paint() turns the same shape into a pixel-art overlay with a soft shoreline.

const WATER := 1.0
## Cells whose centre reaches this are solid water.
const SOLID := 0.9
## Bank cells (reeds) lie between SHORE and SOLID.
const SHORE := 0.55

const SHADOW := Color(0.16, 0.3, 0.12, 0.35)
const MUD_LIGHT := Color8(150, 132, 86)
const MUD := Color8(116, 96, 62)
const FOAM := Color8(206, 230, 214)
const SHALLOW := Color8(92, 168, 160)
const MID := Color8(62, 134, 142)
const DEEP := Color8(44, 102, 124)
const DEEPEST := Color8(36, 82, 108)
const GLINT := Color8(232, 246, 240)
const PAD := [Color8(40, 92, 46), Color8(70, 132, 58), Color8(112, 170, 74)]
const BLOOM := Color8(240, 200, 214)


static func field(blobs: Array, p: Vector2) -> float:
	var f := 0.0
	for b in blobs:
		var d: Vector2 = (p - b.c) / b.r
		f += 1.0 / maxf(d.length_squared(), 0.0001)
	return f


## Field below which nothing is painted (bank shadow edge, minus the wobble).
const EDGE := 0.5


## Bounding rectangle in cells (with room for the bank). Blobs add up, so a
## side is pushed out while the field along it is still above EDGE.
static func bounds(blobs: Array) -> Rect2:
	var r := Rect2(blobs[0].c, Vector2.ZERO)
	for b in blobs:
		r = r.expand(b.c - b.r * 1.6).expand(b.c + b.r * 1.6)
	var lo := r.position
	var hi := r.end
	for i in 40:
		var grown := false
		if _edge_max(blobs, Vector2(lo.x, lo.y), Vector2(lo.x, hi.y)) > EDGE:
			lo.x -= 0.5
			grown = true
		if _edge_max(blobs, Vector2(hi.x, lo.y), Vector2(hi.x, hi.y)) > EDGE:
			hi.x += 0.5
			grown = true
		if _edge_max(blobs, Vector2(lo.x, lo.y), Vector2(hi.x, lo.y)) > EDGE:
			lo.y -= 0.5
			grown = true
		if _edge_max(blobs, Vector2(lo.x, hi.y), Vector2(hi.x, hi.y)) > EDGE:
			hi.y += 0.5
			grown = true
		if not grown:
			break
	return Rect2(lo, hi - lo)


static func _edge_max(blobs: Array, a: Vector2, b: Vector2) -> float:
	var best := 0.0
	var steps := maxi(2, int(ceil(a.distance_to(b) * 4.0)))
	for k in steps + 1:
		best = maxf(best, field(blobs, a.lerp(b, float(k) / steps)))
	return best


static func _hash(x: int, y: int, s: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + s * 2147483647
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _noise(x: float, y: float, cs: float, s: int) -> float:
	var fx := x / cs
	var fy := y / cs
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	return lerpf(lerpf(_hash(x0, y0, s), _hash(x0 + 1, y0, s), tx),
		lerpf(_hash(x0, y0 + 1, s), _hash(x0 + 1, y0 + 1, s), tx), ty)


## Pixel-art overlay; its top-left corner sits at bounds().position * tile.
static func paint(blobs: Array, tile: int, seed_value: int) -> Image:
	var area := bounds(blobs)
	var origin := area.position * tile
	var w := int(ceil(area.size.x * tile))
	var h := int(ceil(area.size.y * tile))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fs := PackedFloat32Array()
	fs.resize(w * h)
	for y in h:
		for x in w:
			var p := (origin + Vector2(x + 0.5, y + 0.5)) / tile
			var wobble := (_noise(x, y, 7.0, seed_value) - 0.5) * 0.14 + (_noise(x, y, 3.0, seed_value + 1) - 0.5) * 0.05
			fs[y * w + x] = field(blobs, p) * (1.0 + wobble)
	for y in h:
		for x in w:
			var f := fs[y * w + x]
			var col := Color(0, 0, 0, 0)
			if f >= WATER:
				# Foam on the rim (any drier neighbour), then deeper bands inwards.
				var rim := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or fs[n.y * w + n.x] < WATER:
						rim = true
				if rim:
					col = FOAM
				elif f < 1.3:
					col = SHALLOW
				elif f < 1.9:
					col = MID
				elif f < 3.2:
					col = DEEP
				else:
					col = DEEPEST
				# Reflected sky: light falls on the north bank's water.
				if not rim and y > 0 and fs[(y - 1) * w + x] < WATER:
					col = SHALLOW.lightened(0.15)
			elif f >= 0.86:
				col = MUD
			elif f >= 0.74:
				col = MUD_LIGHT if _hash(x, y, seed_value + 2) > 0.25 else MUD
			elif f >= 0.64:
				col = SHADOW
			img.set_pixel(x, y, col)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Glints: short horizontal highlights on open water.
	for i in int(w * h / 900.0) + 2:
		var x := rng.randi_range(2, w - 6)
		var y := rng.randi_range(2, h - 3)
		if fs[y * w + x] > 1.5 and fs[y * w + x + 4] > 1.5:
			var n := rng.randi_range(2, 4)
			for k in n:
				img.set_pixel(x + k, y, GLINT if k > 0 and k < n - 1 else SHALLOW.lightened(0.3))
	# Lily pads (a notched disc), some flowering.
	for i in rng.randi_range(1, 4):
		var c := Vector2i(rng.randi_range(6, w - 7), rng.randi_range(6, h - 7))
		if fs[c.y * w + c.x] < 1.6:
			continue
		var r := rng.randf_range(2.4, 3.6)
		for y in range(-4, 5):
			for x in range(-4, 5):
				var v := Vector2(x, y * 1.25)
				if v.length() > r or (x > 0 and absi(y) <= absi(x) / 3):
					continue
				var tone := 1
				if v.length() > r - 1.0:
					tone = 0
				elif x + y < -1:
					tone = 2
				img.set_pixel(c.x + x, c.y + y, PAD[tone])
		if rng.randf() < 0.5:
			img.set_pixel(c.x - 1, c.y - 1, BLOOM)
			img.set_pixel(c.x - 2, c.y - 1, BLOOM.darkened(0.2))
			img.set_pixel(c.x - 1, c.y - 2, Color.WHITE)
	return img
