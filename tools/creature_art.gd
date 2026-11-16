extends RefCounted
## Procedural creature pose sheets (layout: CreatureSheet).
##
## Every creature is a small 3D puppet of ellipsoids, tapered limbs and flat
## panels. It is posed per frame, projected in the game's top-down 3/4 view
## with a depth buffer, lit from the upper left with 5-tone hue-shifted ramps,
## then inked like the rest of the art. A family shares one rig and one shape
## language; species only change proportions, palette and gear, so the whole
## bestiary reads as one heroic-fantasy world.

const Catalog := preload("res://scripts/data/enemy_catalog.gd")
const Sheet := preload("res://scripts/world/visuals/creature_sheet.gd")
const Specs := preload("res://tools/creature_specs.gd")
const OUTLINE := Color8(24, 22, 32)
const CA := 0.5
const SA := 0.866
## Bodies seen from the front or back are drawn this much wider (stylised
## chunkiness so they read as well as in profile).
const WIDEN := 1.55
## Facings (rows): local (forward, right, up) -> world (east, south, up).
const FACING := [
	Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)),
	Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)),
	Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)),
]

var _light := Vector3(-0.5, -0.7, 0.55).normalized()
var _img: Image
var _zb := PackedFloat32Array()
var _gb := PackedInt32Array()
var _n := 0
var _s := 1.0
var _org := Vector3.ZERO
var _m := Basis()
var _row := 0
var _parts: Array = []
var _g := 0
var _mats := {}


# ---------------------------------------------------------------- sheets

func make(id: String) -> Image:
	var spec: Dictionary = Specs.get_spec(id)
	var cell := Sheet.cell_for(Catalog.size_of(id))
	# small bodies are scaled up to fill their cell; the fit pass below shrinks
	var size: float = Catalog.size_of(id) * float(spec.get("scale", 1.0))
	var sheet := Image.create(cell * Sheet.COLS, cell * Sheet.ROWS, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	# dry run on a padded canvas: shrink the whole creature (never single
	# frames) if a raised weapon or a lunge would leave the cell, and centre
	# each row on its widest extent so long bodies do not hang off one side
	var pad := cell
	var ox := cell / 2.0
	var oy := float(cell - Sheet.ground_for(cell))
	var fit := 1.0
	var dxs := []
	for row in Sheet.ROWS:
		var l := 1.0
		var rr := 1.0
		var u := 1.0
		var dn := 1.0
		for col in Sheet.COLS:
			var r := _frame(spec, size, cell, row, col, pad).get_used_rect()
			if r.size.x == 0:
				continue
			l = maxf(l, ox + pad - r.position.x)
			rr = maxf(rr, r.end.x - (ox + pad))
			u = maxf(u, oy + pad - r.position.y)
			dn = maxf(dn, r.end.y - (oy + pad))
		var dx := (l - rr) * 0.5
		dxs.append(dx)
		var half := (l + rr) * 0.5
		fit = minf(fit, minf((ox - 1.0) / half, minf((oy - 1.0) / u, (cell - oy - 1.0) / dn)))
	fit = maxf(fit, 0.72 * Catalog.size_of(id) / size)
	for row in Sheet.ROWS:
		for col in Sheet.COLS:
			var f := _frame(spec, size * fit, cell, row, col, 0, dxs[row] * fit)
			sheet.blit_rect(f, Rect2i(0, 0, cell, cell), Vector2i(col * cell, row * cell))
	return sheet


func _frame(spec: Dictionary, size: float, cell: int, row: int, col: int, pad := 0, dx := 0.0) -> Image:
	var n := cell + pad * 2
	_n = n
	_s = size
	_row = row
	_org = Vector3(cell / 2.0 + pad + dx, cell - Sheet.ground_for(cell) + pad, 0.0)
	var view := Basis(Vector3(1, 0, 0), Vector3(0, CA, SA), Vector3(0, -SA, CA))
	_m = view * FACING[row]
	_img = Image.create(n, n, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_zb.resize(n * n)
	_zb.fill(-1e9)
	_gb.resize(n * n)
	_gb.fill(-1)
	_parts.clear()
	_g = 0
	var pose := _pose(col)
	match String(spec.rig):
		"quadruped":
			_quadruped(spec, pose)
		"biped":
			_biped(spec, pose)
		"crawler":
			_crawler(spec, pose)
		"flyer":
			_flyer(spec, pose)
		"serpent":
			_serpent(spec, pose)
		"spirit":
			_spirit(spec, pose)
		"fungus":
			_fungus(spec, pose)
	for p in _parts:
		match int(p.k):
			0:
				_r_ell(p)
			1:
				_r_cap(p)
			2:
				_r_tri(p)
	_contours()
	_ink(_img)
	return _img


## Pose of a sheet column: st = idle / walk / windup / strike / recover /
## hurt, ph = walk phase (0, .25, .5, .75 for the four walk columns).
static func _pose(col: int) -> Dictionary:
	var d := {"st": "idle", "ph": 0.0, "k": 0}
	if col >= Sheet.WALK and col < Sheet.WINDUP:
		d.st = "walk"
		d.ph = (col - Sheet.WALK) * 0.25
	elif col == Sheet.WINDUP:
		d.st = "windup"
		d.k = 1
	elif col == Sheet.STRIKE:
		d.st = "strike"
		d.k = 2
	elif col == Sheet.RECOVER:
		d.st = "recover"
		d.k = 3
	elif col == Sheet.HURT:
		d.st = "hurt"
		d.k = 4
	return d


# ---------------------------------------------------------------- palette

## 5 tones dark -> light: shadows drift cool and violet, lights drift warm.
static func ramp(c: Color) -> Array:
	return [_shift(c, 0.42, 0.7, 0.16, 0.1), _shift(c, 0.68, 0.7, 0.08, 0.05), c,
		_shift(c, 1.16, 0.12, 0.07, -0.07), _shift(c, 1.34, 0.12, 0.12, -0.16)]


static func _shift(c: Color, vmul: float, hue: float, amt: float, sat: float) -> Color:
	var h := c.h
	var s := c.s
	if s < 0.08 and vmul < 1.0:
		h = hue
		s = 0.1
	h = fposmod(h + wrapf(hue - h, -0.5, 0.5) * amt, 1.0)
	var v := c.v * vmul if vmul <= 1.0 else c.v + (1.0 - c.v) * (vmul - 1.0) * 1.6
	return Color.from_hsv(h, clampf(s + sat, 0.0, 1.0), clampf(v, 0.0, 1.0), c.a)


## Material: a ramp, optionally glowing (unaffected by shadow) or patterned.
## pat: "band" (stripes across the long axis), "spots", "mottle", "cracks"
## (glowing veins), "wrap" (bandages); c2 is the pattern colour.
func mat(c: Color, glow := false, pat := "", c2 := Color.BLACK, freq := 4.0) -> Dictionary:
	var key := "%s|%s|%s|%s|%s" % [c.to_html(), glow, pat, c2.to_html(), freq]
	if not _mats.has(key):
		_mats[key] = {"t": ramp(c), "glow": glow, "pat": pat, "t2": ramp(c2), "f": freq}
	return _mats[key]


# ---------------------------------------------------------------- puppet

static func rot(pitch: float, yaw := 0.0, roll := 0.0) -> Basis:
	## pitch > 0 lifts the front, yaw > 0 turns towards the right side.
	return Basis(Vector3(0, 0, 1), yaw) * Basis(Vector3(0, 1, 0), -pitch) * Basis(Vector3(1, 0, 0), roll)


func ell(c: Vector3, r: Vector3, m: Dictionary, b := Basis()) -> void:
	_g += 1
	_parts.append({"k": 0, "c": c, "a": b * Basis.from_scale(r), "m": m, "g": _g})


func ball(c: Vector3, r: float, m: Dictionary) -> void:
	ell(c, Vector3(r, r, r), m)


func cap(a: Vector3, b: Vector3, ra: float, rb: float, m: Dictionary) -> void:
	_g += 1
	_parts.append({"k": 1, "a": a, "b": b, "ra": ra, "rb": rb, "m": m, "g": _g})


## Chain of capsules through `pts` with radii `rs` (same group: no seams).
func chain(pts: Array, rs: Array, m: Dictionary) -> void:
	_g += 1
	for i in pts.size() - 1:
		_parts.append({"k": 1, "a": pts[i], "b": pts[i + 1], "ra": rs[i], "rb": rs[i + 1], "m": m, "g": _g})


func tri(a: Vector3, b: Vector3, c: Vector3, m: Dictionary) -> void:
	_g += 1
	_parts.append({"k": 2, "p": [a, b, c], "m": m, "g": _g})


## Flat panel (fan from the first point).
func panel(pts: Array, m: Dictionary) -> void:
	_g += 1
	for i in range(1, pts.size() - 1):
		_parts.append({"k": 2, "p": [pts[0], pts[i], pts[i + 1]], "m": m, "g": _g})


## Two-bone limb from `a` towards `t`; the joint bends towards `pole`.
## Returns the end point (t, or as far as the limb reaches).
func limb(a: Vector3, t: Vector3, l1: float, l2: float, pole: Vector3, r1: float, r2: float, r3: float, m: Dictionary) -> Vector3:
	var d := t - a
	var dl := d.length()
	var dir := d / dl if dl > 0.0001 else Vector3(0, 0, -1)
	var dist := clampf(dl, absf(l1 - l2) + 0.0001, (l1 + l2) * 0.999)
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.0001:
		perp = Vector3(0, 0, 1)
	var j := a + dir * x + perp.normalized() * h
	var e := a + dir * dist
	_g += 1
	_parts.append({"k": 1, "a": a, "b": j, "ra": r1, "rb": r2, "m": m, "g": _g})
	_parts.append({"k": 1, "a": j, "b": e, "ra": r2, "rb": r3, "m": m, "g": _g})
	return e


## Eye: dark (or glowing) ball with a glint.
func eye(c: Vector3, r: float, col: Color, glow := false, b := Basis()) -> void:
	if glow:
		ball(c, r, mat(col, true))
		return
	ball(c, r, mat(col))
	ball(c + b * Vector3(r * 0.55, 0, r * 0.45), r * 0.42, mat(Color(1, 0.98, 0.9), true))


# ---------------------------------------------------------------- raster

func _view(p: Vector3) -> Vector3:
	return _m * p * _s + _org


func _r_ell(p: Dictionary) -> void:
	var c := _view(p.c)
	var a: Basis = _m * (p.a as Basis)
	var b := Basis(a.x * _s, a.y * _s, a.z * _s)
	if absf(b.determinant()) < 0.0001:
		return
	var bi := b.inverse()
	var bt := bi.transposed()
	var ex := Vector3(b.x.x, b.y.x, b.z.x).length()
	var ey := Vector3(b.x.y, b.y.y, b.z.y).length()
	var w: Vector3 = bi.z
	var aa := w.dot(w)
	var m: Dictionary = p.m
	for y in range(maxi(floori(c.y - ey), 0), mini(ceili(c.y + ey) + 1, _n)):
		for x in range(maxi(floori(c.x - ex), 0), mini(ceili(c.x + ex) + 1, _n)):
			var u0: Vector3 = bi.x * (x + 0.5 - c.x) + bi.y * (y + 0.5 - c.y)
			var bb := 2.0 * u0.dot(w)
			var disc := bb * bb - 4.0 * aa * (u0.dot(u0) - 1.0)
			if disc < 0.0:
				continue
			var z := (-bb + sqrt(disc)) / (2.0 * aa)
			var i := y * _n + x
			if c.z + z <= _zb[i]:
				continue
			var u := u0 + w * z
			_put(x, y, i, c.z + z, (bt * u).normalized(), m, p.g, u)


func _r_cap(p: Dictionary) -> void:
	var a := _view(p.a)
	var b := _view(p.b)
	var ra: float = p.ra * _s
	var rb: float = p.rb * _s
	var steps := maxi(1, ceili(a.distance_to(b) / maxf(0.5, minf(ra, rb) * 0.45)))
	for k in steps + 1:
		var t := float(k) / steps
		_r_ball(a.lerp(b, t), lerpf(ra, rb, t), p.m, p.g)


func _r_ball(c: Vector3, r: float, m: Dictionary, g: int) -> void:
	r = maxf(r, 0.6)
	var r2 := r * r + 0.15
	for y in range(maxi(floori(c.y - r), 0), mini(ceili(c.y + r) + 1, _n)):
		for x in range(maxi(floori(c.x - r), 0), mini(ceili(c.x + r) + 1, _n)):
			var qx := x + 0.5 - c.x
			var qy := y + 0.5 - c.y
			var d2 := qx * qx + qy * qy
			if d2 > r2:
				continue
			var nz := sqrt(maxf(r * r - d2, 0.0))
			var i := y * _n + x
			if c.z + nz <= _zb[i]:
				continue
			_put(x, y, i, c.z + nz, Vector3(qx, qy, nz) / r, m, g, Vector3(qx, qy, nz) / r)


func _r_tri(p: Dictionary) -> void:
	var v0 := _view(p.p[0])
	var v1 := _view(p.p[1])
	var v2 := _view(p.p[2])
	var n := (v1 - v0).cross(v2 - v0)
	var area := (v1.x - v0.x) * (v2.y - v0.y) - (v1.y - v0.y) * (v2.x - v0.x)
	if absf(area) < 0.01:
		return
	n = n.normalized()
	if n.z < 0.0:
		n = -n
	for y in range(maxi(floori(minf(v0.y, minf(v1.y, v2.y))), 0), mini(ceili(maxf(v0.y, maxf(v1.y, v2.y))) + 1, _n)):
		for x in range(maxi(floori(minf(v0.x, minf(v1.x, v2.x))), 0), mini(ceili(maxf(v0.x, maxf(v1.x, v2.x))) + 1, _n)):
			var px := x + 0.5
			var py := y + 0.5
			var w0 := ((v1.x - px) * (v2.y - py) - (v1.y - py) * (v2.x - px)) / area
			var w1 := ((v2.x - px) * (v0.y - py) - (v2.y - py) * (v0.x - px)) / area
			var w2 := 1.0 - w0 - w1
			if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
				continue
			var z := v0.z * w0 + v1.z * w1 + v2.z * w2
			var i := y * _n + x
			if z <= _zb[i]:
				continue
			_put(x, y, i, z, n, p.m, p.g, Vector3(w0, w1, w2))


func _put(x: int, y: int, i: int, z: float, n: Vector3, m: Dictionary, g: int, u: Vector3) -> void:
	var lit := n.dot(_light)
	var t := clampf((lit + 0.42) / 1.3, 0.0, 0.999)
	var tones: Array = m.t
	var k := int(t * 5.0)
	if m.glow:
		k = 2 + int(t * 2.999)
	match String(m.pat):
		"band":
			if fposmod(u.x * m.f + 0.25, 1.0) < 0.45:
				tones = m.t2
		"spots":
			var q: Vector3 = (u * m.f).round()
			if _hash3(q) > 0.62 and (u * float(m.f) - q).length() < 0.42:
				tones = m.t2
		"mottle":
			var hv := _hash3((u * float(m.f)).floor())
			k = clampi(k + (1 if hv > 0.78 else (-1 if hv < 0.2 else 0)), 0, 4)
		"cracks":
			var hv2 := _vnoise(u * float(m.f))
			if absf(hv2 - 0.5) < 0.045:
				tones = m.t2
				k = 3
		"wrap":
			if fposmod(u.z * m.f + u.x * 0.6, 1.0) < 0.2:
				k = maxi(k - 1, 0)
	_img.set_pixel(x, y, tones[k])
	_zb[i] = z
	_gb[i] = g


static func _hash3(q: Vector3) -> float:
	var h: int = int(q.x) * 374761393 + int(q.y) * 668265263 + int(q.z) * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func _vnoise(p: Vector3) -> float:
	var f := p.floor()
	var t := p - f
	t = t * t * (Vector3(3, 3, 3) - 2.0 * t)
	var a := lerpf(_hash3(f), _hash3(f + Vector3(1, 0, 0)), t.x)
	var b := lerpf(_hash3(f + Vector3(0, 1, 0)), _hash3(f + Vector3(1, 1, 0)), t.x)
	var c := lerpf(_hash3(f + Vector3(0, 0, 1)), _hash3(f + Vector3(1, 0, 1)), t.x)
	var d := lerpf(_hash3(f + Vector3(0, 1, 1)), _hash3(f + Vector3(1, 1, 1)), t.x)
	return lerpf(lerpf(a, b, t.y), lerpf(c, d, t.y), t.z)


## Inner contour: a pixel bordering a part clearly in front of it darkens.
func _contours() -> void:
	var src := _img.duplicate() as Image
	var thr := maxf(1.2, _s * 0.035)
	for y in _n:
		for x in _n:
			var i := y * _n + x
			if _gb[i] < 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx: int = x + d.x
				var qy: int = y + d.y
				if qx < 0 or qy < 0 or qx >= _n or qy >= _n:
					continue
				var j := qy * _n + qx
				if _gb[j] >= 0 and _gb[j] != _gb[i] and _zb[j] > _zb[i] + thr:
					_img.set_pixel(x, y, src.get_pixel(x, y).darkened(0.5).lerp(OUTLINE, 0.3))
					break


## Same finish as the rest of the sprites (generate_placeholder_art._ink).
static func _ink(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5:
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
			var avg := Color(sum.x / n, sum.y / n, sum.z / n)
			var ink: Color = OUTLINE
			if not solid.call(x, y - 1):
				ink = avg.darkened(0.72).lerp(OUTLINE, 0.35)
			img.set_pixel(x, y, ink)

# ---------------------------------------------------------------- quadruped

## Pose knobs of a four-legged body per attack style (windup, strike,
## recover): shift/air/crouch move the body, bp pitches it (around the hips),
## hp pitches the head, neck scales the neck, jaw opens the mouth, ff/fu and
## bf/bu move / lift the front and back feet, rear raises the front legs.
const QPOSE := {
	"bite": [{"shift": -0.04, "crouch": 0.015, "hp": -0.3, "neck": 0.8, "jaw": 0.12, "ff": 0.03, "bf": 0.02},
		{"shift": 0.08, "hp": 0.12, "neck": 1.3, "jaw": 0.7, "ff": 0.09, "bf": -0.07},
		{"shift": 0.03, "neck": 1.05, "jaw": 0.2, "ff": 0.04, "bf": -0.02}],
	"charge": [{"shift": -0.04, "crouch": 0.03, "hp": -0.5, "bp": -0.06, "ff": -0.04, "fu": 0.05, "bf": 0.03},
		{"shift": 0.1, "air": 0.035, "bp": -0.08, "hp": -0.4, "ff": 0.13, "fu": 0.03, "bf": -0.13, "bu": 0.03},
		{"shift": 0.05, "hp": -0.15, "ff": -0.03, "bf": 0.05}],
	"pounce": [{"crouch": 0.075, "shift": -0.04, "bp": 0.1, "hp": -0.12, "ff": 0.04, "bf": 0.05},
		{"air": 0.13, "shift": 0.1, "bp": -0.12, "hp": 0.08, "jaw": 0.7, "ff": 0.15, "fu": 0.07, "bf": -0.15, "bu": 0.08},
		{"crouch": 0.035, "shift": 0.08, "bp": -0.08, "jaw": 0.2, "ff": 0.06, "bf": 0.02}],
	"slam": [{"bp": 0.85, "hp": -0.55, "jaw": 0.55, "rear": 1.0, "bf": 0.03},
		{"bp": -0.14, "shift": 0.08, "crouch": 0.035, "hp": -0.15, "jaw": 0.6, "ff": 0.13, "bf": -0.03},
		{"bp": -0.04, "shift": 0.05, "jaw": 0.2, "ff": 0.06}],
	"howl": [{"bp": 0.22, "crouch": 0.03, "hp": 0.3, "jaw": 0.12, "bf": 0.05},
		{"bp": 0.3, "crouch": 0.035, "hp": 0.95, "jaw": 0.5, "neck": 1.15, "bf": 0.06},
		{"bp": 0.1, "hp": 0.35, "jaw": 0.15, "bf": 0.03}],
	"breath": [{"shift": -0.03, "bp": 0.12, "hp": 0.55, "neck": 0.8, "jaw": 0.25, "bf": 0.03},
		{"shift": 0.05, "bp": -0.04, "hp": -0.12, "neck": 1.25, "jaw": 0.85, "ff": 0.05, "bf": -0.03},
		{"shift": 0.02, "hp": 0.05, "neck": 1.05, "jaw": 0.3}],
	"butt": [{"shift": -0.03, "crouch": 0.02, "hp": -0.4, "ff": -0.02, "bf": 0.02},
		{"shift": 0.08, "hp": -0.32, "ff": 0.07, "bf": -0.07},
		{"shift": 0.03, "hp": -0.1, "ff": 0.02}],
}
const QHURT := {"shift": -0.05, "bp": 0.12, "hp": 0.35, "yaw": 0.45, "jaw": 0.3, "crouch": 0.01, "ff": 0.04, "bf": -0.02, "squint": 1.0}
## Leg phase offsets per gait: [front-left, front-right, back-left, back-right].
const GAITS := {"trot": [0.0, 0.5, 0.5, 0.0], "walk": [0.25, 0.75, 0.0, 0.5], "bound": [0.0, 0.08, 0.5, 0.58]}


static func _knobs(table: Dictionary, hurt: Dictionary, style: String, pose: Dictionary, base: Dictionary) -> Dictionary:
	var q := base.duplicate()
	if pose.k >= 1 and pose.k <= 3:
		q.merge(table.get(style, table.values()[0])[pose.k - 1], true)
	elif pose.k == 4:
		q.merge(hurt, true)
	return q


func _quadruped(p: Dictionary, pose: Dictionary) -> void:
	var q := _knobs(QPOSE, QHURT, p.atk, pose, {"shift": 0.0, "air": 0.0, "crouch": 0.0, "bp": 0.0, "hp": 0.0,
		"yaw": 0.0, "jaw": 0.0, "neck": 1.0, "ff": 0.0, "fu": 0.0, "bf": 0.0, "bu": 0.0, "rear": 0.0, "squint": 0.0})
	var bl: float = p.bl
	var bw: float = p.bw
	var bh: float = p.bh
	var leg: float = p.leg
	var lw: float = p.lw
	var walk: bool = pose.st == "walk"
	var ph: float = pose.ph
	var bob := 0.0
	if walk:
		if p.gait == "bound":
			bob = 0.05 * maxf(sin(TAU * ph), 0.0)
			q.bp += 0.14 * sin(TAU * ph + 0.6)
		else:
			bob = 0.012 * absf(sin(TAU * ph * 2.0))
	var root := Vector3(-bl * 0.6 + q.shift, 0, leg - q.crouch + bob + q.air)
	var bb := rot(q.bp)
	var fur := mat(p.fur, false, p.pat, p.fur2, p.pf)
	var under := mat(p.belly)
	var paw := mat(p.paw)
	# body: haunch, barrel, chest, lighter belly underneath
	ell(root + bb * Vector3(bl * 0.1, 0, bh * 0.55), Vector3(bl * 0.55, bw, bh), fur, bb)
	ell(root + bb * Vector3(bl * 0.62, 0, bh * 0.6), Vector3(bl * 0.9, bw * 0.95, bh * 0.95), fur, bb)
	ell(root + bb * Vector3(bl * 1.12, 0, bh * 0.68), Vector3(bl * 0.58, bw * 1.04, bh * 1.12), fur, bb)
	ell(root + bb * Vector3(bl * 0.7, 0, bh * 0.2), Vector3(bl * 0.82, bw * 0.78, bh * 0.66), under, bb)
	# legs
	var reach := leg + bh * 0.25 - lw * 0.6
	var l1 := reach * 0.54
	var offs: Array = GAITS.get(p.gait, GAITS.trot)
	var amp: float = p.get("stride", 0.09)
	for sd in [-1.0, 1.0]:
		for front in [true, false]:
			var j := root + bb * (Vector3(bl * 1.3, sd * bw * 0.6, bh * 0.25) if front else Vector3(bl * 0.05, sd * bw * 0.62, bh * 0.3))
			var t := Vector3(j.x + (q.ff if front else q.bf) + sd * 0.008, sd * bw * 0.72, lw * 0.6 + (q.fu if front else q.bu) + q.air * 0.7)
			if front and sd < 0.0 and q.fu > 0.0 and pose.k == 1:
				t.z = lw * 0.6
			if walk:
				var lp: float = ph + offs[(0 if front else 2) + (0 if sd < 0.0 else 1)]
				t.x += cos(TAU * lp) * amp
				t.z += maxf(-sin(TAU * lp), 0.0) * leg * 0.3
			if front and q.rear > 0.0:
				t = j + bb * Vector3(leg * 0.5, sd * 0.02, -leg * 0.45)
			var pole := Vector3(1, 0, -0.2) if front else Vector3(-1, 0, 0)
			if not front:
				ell(j + bb * Vector3(0, sd * bw * 0.05, -bh * 0.05), Vector3(bl * 0.32, bw * 0.38, bh * 0.72), fur, bb)
			var e := limb(j, t, l1, l1, pole, lw * 1.2, lw * 0.82, lw * 0.75, fur)
			ell(e + Vector3(lw * 0.35, 0, -lw * 0.15), Vector3(lw * 1.05, lw * 0.8, lw * 0.6), paw)
	# neck and head
	if p.wings:
		var flap := 0.25 + 0.3 * sin(TAU * ph) if walk else (0.9 if pose.k == 1 else (-0.1 if pose.k == 2 else 0.3))
		for sd in [-1.0, 1.0]:
			_wing(root + bb * Vector3(bl * 1.15, sd * bw * 0.6, bh * 1.3), bb, sd, p.wing_span, flap, mat(p.wing_col, false, "band", Color(p.wing_col).darkened(0.15), 5.0), mat(p.wing_bone))
	var neck_base := root + bb * Vector3(bl * 1.45, 0, bh * 0.95)
	var heads: int = p.get("heads", 1)
	for i in heads:
		var off := i - (heads - 1) * 0.5
		var nyaw = off * 0.55 + (q.yaw if i == 0 else 0.0)
		var nb := bb * rot(q.hp * 0.5 + absf(off) * -0.1, nyaw)
		var nk: float = p.neck * q.neck * (1.0 - absf(off) * 0.12)
		var nbase := neck_base + bb * Vector3(0, off * bw * 0.5, 0)
		var hc := nbase + nb * Vector3(cos(p.neck_up) * nk, 0, sin(p.neck_up) * nk)
		var hb := bb * rot(q.hp, nyaw)
		if p.head == "reptile" and nk > p.hs * 1.2:
			var mid := nbase + nb * Vector3(cos(p.neck_up) * nk * 0.35, 0, sin(p.neck_up) * nk * 0.65)
			chain([nbase, mid, hc], [bw * 0.62, p.hs * 0.62, p.hs * 0.5], fur)
		else:
			cap(nbase, hc, bw * 0.78, p.hs * 0.7, fur)
		if p.mane:
			ell(nbase + nb * Vector3(nk * 0.25, 0, nk * 0.3), Vector3(bh * 0.85, bw * 1.2, bh * 1.05), mat(p.mane_col, p.mane_glow, "mottle", Color.BLACK, 9.0), nb * rot(0.5))
		_beast_head(hc, hb, p, q.jaw, q.squint, fur)
		if p.breath != Color.TRANSPARENT and (pose.k == 1 or pose.k == 2):
			var mouth := hc + hb * Vector3(p.hs * 0.8 + p.sn * 1.1, 0, -p.hs * 0.3)
			if pose.k == 1:
				ball(mouth, p.sr * 0.6, mat(p.breath, true))
			else:
				for j in 4:
					ball(mouth + hb * Vector3(p.hs * (0.3 + j * 0.65), 0, -p.hs * j * 0.15), p.hs * (0.3 + j * 0.2), mat(Color(p.breath).lightened(0.4 - j * 0.12), true))
	# tail
	var tb := root + bb * Vector3(-bl * 0.42, 0, bh * 0.95)
	var sway := sin(TAU * ph) * 0.15 if walk else (0.4 if pose.k == 2 else 0.0)
	_tail(tb, bb, p, sway, fur)
	_quad_extras(p, root, bb, bl, bw, bh)


func _beast_head(h: Vector3, hb: Basis, p: Dictionary, jaw: float, squint: float, fur: Dictionary) -> void:
	var hs: float = p.hs
	var sn: float = p.sn
	var sr: float = p.sr
	var muzzle := mat(p.muzzle)
	var dark := mat(p.nose)
	var reptile: bool = p.head == "reptile"
	ell(h, Vector3(hs, hs * 0.82, hs * (0.62 if reptile else 0.85)), fur, hb)
	ell(h + hb * Vector3(hs * 0.68 + sn * 0.45, 0, -hs * 0.22), Vector3(sn * 0.62 + hs * 0.12, sr, sr * (0.6 if reptile else 0.85)), muzzle if not reptile else fur, hb * rot(-0.08))
	var tip := h + hb * Vector3(hs * 0.7 + sn * 1.02, 0, -hs * 0.14)
	if reptile:
		for sd in [-1.0, 1.0]:
			ball(tip + hb * Vector3(-sr * 0.1, sd * sr * 0.35, sr * 0.2), sr * 0.12, dark)
			ell(h + hb * Vector3(hs * 0.45, sd * hs * 0.42, hs * 0.38), Vector3(hs * 0.32, hs * 0.16, hs * 0.11), fur, hb * rot(0.15))
	elif p.head == "boar":
		ell(tip, Vector3(sr * 0.32, sr * 0.78, sr * 0.68), mat(p.snout_col), hb)
		ball(tip + hb * Vector3(sr * 0.28, -sr * 0.3, 0), sr * 0.16, dark)
		ball(tip + hb * Vector3(sr * 0.28, sr * 0.3, 0), sr * 0.16, dark)
	else:
		ball(tip, sr * 0.42, dark)
	var hinge := h + hb * Vector3(hs * 0.25, 0, -hs * 0.5)
	var jb := hb * rot(-jaw)
	ell(hinge + jb * Vector3(hs * 0.35 + sn * 0.4, 0, -sr * 0.12), Vector3(hs * 0.3 + sn * 0.42, sr * 0.8, sr * 0.42), muzzle, jb)
	if jaw > 0.05:
		ell(hinge + hb * rot(-jaw * 0.5) * Vector3(hs * 0.4 + sn * 0.35, 0, 0), Vector3(hs * 0.3 + sn * 0.36, sr * 0.68, sr * 0.48), mat(Color8(120, 34, 44)), hb * rot(-jaw * 0.5))
		var tooth := mat(Color8(240, 232, 214))
		for sd in [-1.0, 1.0]:
			var f := h + hb * Vector3(hs * 0.7 + sn * 0.85, sd * sr * 0.5, -hs * 0.3)
			cap(f, f + hb * Vector3(0, 0, -sr * 0.65), sr * 0.17, 0.0, tooth)
			var lf := hinge + jb * Vector3(hs * 0.3 + sn * 0.75, sd * sr * 0.45, sr * 0.1)
			cap(lf, lf + jb * Vector3(0, 0, sr * 0.5), sr * 0.14, 0.0, tooth)
	for sd in [-1.0, 1.0]:
		var e := h + hb * Vector3(hs * 0.62, sd * hs * 0.48, hs * 0.22)
		if squint > 0.0:
			ell(e, Vector3(hs * 0.1, hs * 0.16, hs * 0.04), dark, hb)
		else:
			eye(e, hs * float(p.eye_r), p.eye, p.eye_glow, hb)
	var ear := mat(p.ear_col)
	var er: float = p.ear
	for sd in [-1.0, 1.0]:
		var base := h + hb * Vector3(-hs * 0.1, sd * hs * 0.5, hs * 0.55)
		match String(p.ears):
			"point":
				cap(base, base + hb * Vector3(-hs * 0.15, sd * hs * 0.25, hs * 0.95 * er), hs * 0.3 * er, 0.0, ear)
			"round":
				ell(base + hb * Vector3(0, sd * hs * 0.05, hs * 0.1), Vector3(hs * 0.16, hs * 0.26, hs * 0.26) * er, ear, hb)
			"long":
				ell(base + hb * Vector3(-hs * 0.45, sd * hs * 0.05, hs * 1.0 * er), Vector3(hs * 0.3, hs * 0.18, hs * 0.95 * er), ear, hb * rot(-0.35))
			"floppy":
				ell(base + hb * Vector3(hs * 0.2, sd * hs * 0.38, -hs * 0.05), Vector3(hs * 0.42 * er, hs * 0.12, hs * 0.28 * er), ear, hb * rot(-0.5, sd * 0.4))
	var horn := mat(p.horn_col)
	for sd in [-1.0, 1.0]:
		match String(p.horns):
			"tusks":
				var tk := h + hb * Vector3(hs * 0.6 + sn * 0.75, sd * sr * 0.85, -hs * 0.35)
				chain([tk, tk + hb * Vector3(sn * 0.1, sd * sr * 0.3, hs * 0.25), tk + hb * Vector3(-sn * 0.05, sd * sr * 0.45, hs * 0.55)], [sr * 0.22, sr * 0.16, 0.0], horn)
			"curl":
				var cb := h + hb * Vector3(-hs * 0.05, sd * hs * 0.55, hs * 0.5)
				var pts := []
				var rs := []
				for i in 7:
					var a := i * 0.95
					var rr := hs * (0.62 - i * 0.06)
					pts.append(cb + hb * Vector3(-sin(a) * rr, sd * (hs * 0.18 + i * hs * 0.045), cos(a) * rr - hs * 0.45))
					rs.append(hs * (0.26 - i * 0.03))
				chain(pts, rs, mat(p.horn_col, false, "band", Color(p.horn_col).darkened(0.25), 6.0))
			"yak":
				var yb := h + hb * Vector3(-hs * 0.05, sd * hs * 0.7, hs * 0.45)
				chain([yb, yb + hb * Vector3(0, sd * hs * 0.75, hs * 0.05), yb + hb * Vector3(hs * 0.2, sd * hs * 1.1, hs * 0.55), yb + hb * Vector3(hs * 0.35, sd * hs * 1.0, hs * 0.85)], [hs * 0.24, hs * 0.2, hs * 0.13, 0.0], horn)
			"mammoth":
				var mb := h + hb * Vector3(hs * 0.55, sd * hs * 0.45, -hs * 0.45)
				chain([mb, mb + hb * Vector3(hs * 0.5, sd * hs * 0.25, -hs * 0.55), mb + hb * Vector3(hs * 1.25, sd * hs * 0.45, -hs * 0.4), mb + hb * Vector3(hs * 1.55, sd * hs * 0.2, hs * 0.15)], [hs * 0.22, hs * 0.2, hs * 0.14, 0.0], horn)
			"antler":
				var ab := h + hb * Vector3(-hs * 0.1, sd * hs * 0.4, hs * 0.75)
				var a1 := ab + hb * Vector3(-hs * 0.2, sd * hs * 0.5, hs * 0.7)
				chain([ab, a1, a1 + hb * Vector3(-hs * 0.3, sd * hs * 0.3, hs * 0.5)], [hs * 0.12, hs * 0.09, 0.0], horn)
				cap(a1, a1 + hb * Vector3(hs * 0.35, sd * hs * 0.1, hs * 0.4), hs * 0.08, 0.0, horn)
			"bull":
				var bb0 := h + hb * Vector3(0, sd * hs * 0.65, hs * 0.5)
				chain([bb0, bb0 + hb * Vector3(-hs * 0.05, sd * hs * 0.7, hs * 0.1), bb0 + hb * Vector3(hs * 0.3, sd * hs * 1.05, hs * 0.5), bb0 + hb * Vector3(hs * 0.7, sd * hs * 0.95, hs * 0.75)], [hs * 0.24, hs * 0.2, hs * 0.13, 0.0], horn)
			"swept":
				var sw0 := h + hb * Vector3(-hs * 0.1, sd * hs * 0.45, hs * 0.55)
				chain([sw0, sw0 + hb * Vector3(-hs * 0.6, sd * hs * 0.2, hs * 0.35), sw0 + hb * Vector3(-hs * 1.3, sd * hs * 0.3, hs * 0.45)], [hs * 0.2, hs * 0.13, 0.0], horn)
			"nubs":
				var nb0 := h + hb * Vector3(-hs * 0.1, sd * hs * 0.4, hs * 0.7)
				cap(nb0, nb0 + hb * Vector3(-hs * 0.4, sd * hs * 0.15, hs * 0.4), hs * 0.16, 0.0, horn)
	if p.get("ring", false):
		cap(tip + hb * Vector3(-sr * 0.1, -sr * 0.4, -sr * 0.3), tip + hb * Vector3(0, 0, -sr * 0.75), sr * 0.1, sr * 0.1, mat(Color8(224, 180, 80)))
		cap(tip + hb * Vector3(0, 0, -sr * 0.75), tip + hb * Vector3(-sr * 0.1, sr * 0.4, -sr * 0.3), sr * 0.1, sr * 0.1, mat(Color8(224, 180, 80)))


func _tail(tb: Vector3, bb: Basis, p: Dictionary, sway: float, fur: Dictionary) -> void:
	var tl: float = p.tl
	var hs: float = p.hs
	var tail_m := mat(p.tail_col, p.tail_glow) if p.tail_col != Color.TRANSPARENT else fur
	match String(p.tail):
		"bushy":
			var a := tb + bb * Vector3(-tl * 0.35, sway * tl * 0.4, tl * 0.15)
			var b := a + bb * Vector3(-tl * 0.4, sway * tl * 0.6, -tl * 0.2)
			var c := b + bb * Vector3(-tl * 0.3, sway * tl * 0.5, -tl * 0.25)
			chain([tb, a, b, c], [hs * 0.3, hs * 0.48, hs * 0.42, hs * 0.08], tail_m)
		"thin":
			var a2 := tb + bb * Vector3(-tl * 0.35, sway * tl * 0.5, -tl * 0.05)
			var b2 := a2 + bb * Vector3(-tl * 0.35, sway * tl * 0.7, -tl * 0.2)
			var c2 := b2 + bb * Vector3(-tl * 0.3, sway * tl * 0.9, -tl * 0.15)
			chain([tb, a2, b2, c2], [hs * 0.16, hs * 0.12, hs * 0.08, hs * 0.03], tail_m)
		"tuft":
			var a3 := tb + bb * Vector3(-tl * 0.3, sway * tl * 0.4, -tl * 0.25)
			var b3 := a3 + bb * Vector3(-tl * 0.15, sway * tl * 0.4, -tl * 0.4)
			chain([tb, a3, b3], [hs * 0.12, hs * 0.08, hs * 0.06], tail_m)
			ell(b3 + bb * Vector3(0, 0, -tl * 0.12), Vector3(hs * 0.18, hs * 0.18, hs * 0.3), mat(p.mane_col))
		"stub":
			ball(tb + bb * Vector3(-hs * 0.15, 0, -hs * 0.05), hs * 0.32, tail_m)
		"puff":
			ball(tb + bb * Vector3(-hs * 0.12, 0, hs * 0.05), hs * 0.42, tail_m)
		"reptile":
			var pts := [tb]
			var rs := [hs * 0.55]
			for i in 5:
				var s := (i + 1) / 5.0
				pts.append(tb + bb * Vector3(-tl * s, sin(s * 2.5 + 0.5) * sway * tl * 0.8 + sin(s * 3.0) * tl * 0.12, -tl * 0.25 * s + 0.0))
				rs.append(hs * 0.55 * (1.0 - s * 0.85))
			chain(pts, rs, tail_m)
			if p.tail_col != Color.TRANSPARENT:
				var e: Vector3 = pts[5]
				ell(e, Vector3(hs * 0.3, hs * 0.08, hs * 0.22), tail_m, bb)


## Pelt and gear of four-legged beasts (wool, hump, shag, moss, thorns, ice
## spikes, flames).
func _quad_extras(p: Dictionary, root: Vector3, bb: Basis, bl: float, bw: float, bh: float) -> void:
	var c := root + bb * Vector3(bl * 0.62, 0, bh * 0.62)
	if p.wool:
		var wm := mat(p.wool_col, false, "mottle", Color.BLACK, 7.0)
		for i in 14:
			var a := i * 2.39996
			var zz := 1.0 - (i + 0.5) / 14.0 * 1.3
			var rr := sqrt(maxf(1.0 - zz * zz, 0.0))
			var d := Vector3(cos(a) * rr * 1.25, sin(a) * rr, zz)
			ball(c + bb * Vector3(d.x * bl * 0.85, d.y * bw * 0.85, d.z * bh * 0.8), bh * 0.5, wm)
	if p.hump:
		ell(root + bb * Vector3(bl * 0.95, 0, bh * 1.35), Vector3(bl * 0.38, bw * 0.62, bh * 0.55), mat(p.fur2), bb)
	if p.shag:
		ell(root + bb * Vector3(bl * 0.6, 0, bh * 0.15), Vector3(bl * 1.08, bw * 1.12, bh * 0.92), mat(p.shag_col, false, "mottle", Color.BLACK, 10.0), bb)
	var back := func(i: int, n: int) -> Vector3:
		var t := (i + 0.5) / n
		return root + bb * Vector3(bl * (1.3 - t * 1.6), (fposmod(i * 0.618, 1.0) - 0.5) * bw * 0.9, bh * (1.45 - absf(t - 0.5) * 0.5))
	if p.moss:
		var mm := mat(p.moss_col, false, "mottle", Color.BLACK, 8.0)
		for i in 7:
			ell(back.call(i, 7), Vector3(bl * 0.22, bw * 0.4, bh * 0.25), mm, bb)
		var cap_m := mat(Color8(214, 120, 70), false, "spots", Color8(240, 226, 200), 5.0)
		for i in [1, 4]:
			var mp: Vector3 = back.call(i, 7) + Vector3(0, 0, bh * 0.3)
			cap(mp - Vector3(0, 0, bh * 0.2), mp, bh * 0.07, bh * 0.07, mat(Color8(230, 220, 196)))
			ell(mp + Vector3(0, 0, bh * 0.06), Vector3(bh * 0.2, bh * 0.2, bh * 0.1), cap_m)
	if p.thorns:
		var tm := mat(Color8(92, 60, 40))
		var lm := mat(Color8(84, 140, 62))
		for i in 8:
			var bp: Vector3 = back.call(i, 8)
			cap(bp, bp + bb * Vector3(-bh * 0.35, (fposmod(i * 0.37, 1.0) - 0.5) * bh * 0.6, bh * 0.45), bh * 0.08, 0.0, tm)
			if i % 3 == 1:
				ell(bp + Vector3(0, 0, bh * 0.12), Vector3(bh * 0.24, bh * 0.14, bh * 0.07), lm, rot(0.3, i * 1.3))
	if p.spikes:
		var im := mat(Color8(176, 226, 246))
		for i in 6:
			var sp: Vector3 = back.call(i, 6)
			cap(sp, sp + bb * Vector3(-bh * 0.25, (fposmod(i * 0.53, 1.0) - 0.5) * bh * 0.5, bh * 0.6), bh * 0.13, 0.0, im)
	if p.flames:
		var fm := mat(Color8(255, 132, 40), true)
		var fm2 := mat(Color8(255, 214, 96), true)
		for i in 7:
			var fp: Vector3 = back.call(i, 7)
			cap(fp, fp + bb * Vector3(-bh * 0.55, 0, bh * 0.55), bh * 0.17, 0.0, fm)
			cap(fp + Vector3(0, 0, bh * 0.05), fp + bb * Vector3(-bh * 0.32, 0, bh * 0.38), bh * 0.08, 0.0, fm2)


# ---------------------------------------------------------------- biped

## Pose knobs of two-legged folk per attack style (windup, strike, recover).
## rh / lh: hand targets from the shoulders in arm lengths (torso frame),
## wd: weapon direction (torso frame), lean (forward), twist (towards the
## weapon side), crouch / shift / air, rf / lf: foot steps, glow: staff orb,
## held: false once a thrown weapon has left the hand.
const BPOSE := {
	"swing": [{"rh": Vector3(-0.15, 0.15, 0.75), "wd": Vector3(-0.45, 0.1, 0.9), "lh": Vector3(0.4, -0.1, -0.5), "lean": -0.1, "twist": -0.3, "lf": 0.06},
		{"rh": Vector3(0.9, -0.05, -0.15), "wd": Vector3(0.85, -0.15, -0.5), "lh": Vector3(-0.2, -0.2, -0.75), "lean": 0.3, "twist": 0.3, "shift": 0.05, "rf": 0.1, "lf": -0.06},
		{"rh": Vector3(0.5, -0.25, -0.6), "wd": Vector3(0.3, -0.6, -0.75), "lh": Vector3(0.0, -0.2, -0.85), "lean": 0.15, "twist": 0.12, "shift": 0.03, "rf": 0.05}],
	"slam": [{"rh": Vector3(-0.1, -0.08, 0.95), "lh": Vector3(-0.1, 0.08, 0.95), "wd": Vector3(-0.65, 0, 0.75), "lean": -0.18, "two": true},
		{"rh": Vector3(0.85, -0.12, -0.45), "lh": Vector3(0.85, 0.12, -0.45), "wd": Vector3(0.75, 0, -0.65), "lean": 0.45, "crouch": 0.06, "shift": 0.06, "rf": 0.08, "two": true},
		{"rh": Vector3(0.55, -0.12, -0.65), "lh": Vector3(0.55, 0.12, -0.65), "wd": Vector3(0.4, 0, -0.9), "lean": 0.25, "crouch": 0.03, "shift": 0.03, "two": true}],
	"bow": [{"lh": Vector3(0.98, 0.0, 0.12), "rh": Vector3(0.12, -0.12, 0.25), "lean": -0.04, "twist": -0.55, "draw": 1.0},
		{"lh": Vector3(0.98, 0.0, 0.12), "rh": Vector3(-0.25, 0.25, 0.3), "lean": 0.04, "twist": -0.5, "draw": 0.0, "lf": 0.04},
		{"lh": Vector3(0.6, 0.0, -0.3), "rh": Vector3(0.1, 0.1, -0.6), "twist": -0.2}],
	"throw": [{"rh": Vector3(-0.55, 0.2, 0.55), "wd": Vector3(1, 0, 0.25), "lh": Vector3(0.75, -0.1, 0.15), "lean": -0.12, "twist": -0.45, "lf": 0.06},
		{"rh": Vector3(0.95, 0.0, 0.2), "lh": Vector3(-0.3, -0.2, -0.6), "lean": 0.28, "twist": 0.35, "shift": 0.04, "rf": 0.1, "held": false},
		{"rh": Vector3(0.55, -0.1, -0.55), "lh": Vector3(0.0, -0.2, -0.85), "lean": 0.12, "twist": 0.1, "held": false}],
	"sling": [{"rh": Vector3(0.05, 0.05, 0.95), "lh": Vector3(0.6, -0.1, 0.0), "lean": -0.08, "twist": -0.3, "whirl": 1.0},
		{"rh": Vector3(0.95, 0.0, 0.25), "lh": Vector3(-0.2, -0.2, -0.7), "lean": 0.25, "twist": 0.3, "rf": 0.08, "held": false},
		{"rh": Vector3(0.6, -0.1, -0.5), "lh": Vector3(0.0, -0.2, -0.85), "lean": 0.1, "held": false}],
	"cast": [{"rh": Vector3(0.1, 0.1, 0.75), "wd": Vector3(0.1, 0, 1), "lh": Vector3(0.25, -0.2, 0.65), "lean": -0.12, "glow": 1.6},
		{"rh": Vector3(0.9, 0.05, 0.2), "wd": Vector3(0.75, 0, 0.65), "lh": Vector3(0.9, -0.1, 0.05), "lean": 0.22, "shift": 0.04, "rf": 0.07, "glow": 2.2},
		{"rh": Vector3(0.45, 0.1, -0.35), "wd": Vector3(0.25, 0, 1), "lh": Vector3(0.2, -0.2, -0.6), "lean": 0.08, "glow": 1.2}],
	"claw": [{"rh": Vector3(-0.35, 0.25, 0.35), "lh": Vector3(-0.35, -0.25, 0.35), "lean": 0.3, "crouch": 0.07, "jaw": 0.3},
		{"rh": Vector3(1.0, -0.05, 0.15), "lh": Vector3(0.95, 0.05, 0.3), "lean": 0.45, "air": 0.06, "shift": 0.1, "rf": 0.12, "lf": -0.14, "jaw": 0.7},
		{"rh": Vector3(0.6, 0.1, -0.45), "lh": Vector3(0.55, -0.1, -0.35), "lean": 0.25, "crouch": 0.03, "shift": 0.06, "rf": 0.05, "jaw": 0.25}],
	"charge": [{"rh": Vector3(-0.35, 0.2, -0.6), "lh": Vector3(-0.35, -0.2, -0.6), "lean": 0.45, "crouch": 0.06, "hp": -0.35, "rf": -0.08, "lf": 0.04, "wd": Vector3(-0.6, 0, -0.6)},
		{"rh": Vector3(-0.45, 0.2, -0.4), "lh": Vector3(-0.45, -0.2, -0.4), "lean": 0.62, "shift": 0.12, "air": 0.02, "hp": -0.45, "rf": 0.13, "lf": -0.14, "wd": Vector3(-0.7, 0, -0.4)},
		{"rh": Vector3(0.1, 0.15, -0.8), "lh": Vector3(0.1, -0.15, -0.8), "lean": 0.25, "shift": 0.05, "hp": -0.15, "rf": 0.04}],
}
const BHURT := {"rh": Vector3(-0.05, 0.45, -0.45), "lh": Vector3(-0.05, -0.45, -0.45), "lean": -0.22, "shift": -0.04, "hp": 0.3, "twist": 0.2, "squint": 1.0, "jaw": 0.4, "rf": -0.03}


func _biped(p: Dictionary, pose: Dictionary) -> void:
	var q := _knobs(BPOSE, BHURT, p.atk, pose, {"lean": 0.0, "twist": 0.0, "crouch": 0.0, "shift": 0.0, "air": 0.0,
		"hp": 0.0, "jaw": 0.0, "rf": 0.0, "lf": 0.0, "glow": 1.0, "held": true, "draw": 0.0, "whirl": 0.0, "squint": 0.0, "two": false})
	var leg: float = p.leg
	var th: float = p.th
	_s *= clampf(0.86 / (leg + th * 2.05 + float(p.hr) * 1.8), 1.0, 1.35)
	var tw: float = p.tw
	var td: float = p.td
	var hr: float = p.hr
	var arm: float = p.arm
	var aw: float = p.aw
	var lw: float = p.lw
	var walk: bool = pose.st == "walk"
	var ph: float = pose.ph
	var bob := 0.0
	var swing := 0.0
	if walk:
		bob = 0.022 * absf(sin(TAU * ph))
		swing = cos(TAU * ph)
	var skin := mat(p.skin, false, p.skin_pat, p.skin2, p.spf)
	var cloth := mat(p.cloth, false, p.cloth_pat, p.cloth2, 6.0) if p.cloth != Color.TRANSPARENT else skin
	var pelvis := Vector3(q.shift, 0, leg - q.crouch + bob + q.air)
	var tb := rot(-(p.hunch + q.lean), q.twist + (swing * 0.08 if walk else 0.0))
	# legs and feet (hidden under a robe, which sways instead)
	var stride: float = p.get("stride", 0.1)
	var boot := mat(p.boot)
	for sd in [-1.0, 1.0]:
		var hip := pelvis + Vector3(0, sd * tw * 0.5, -th * 0.12)
		var t := Vector3(hip.x + (q.rf if sd > 0.0 else q.lf), sd * tw * 0.62, lw * 0.6 + q.air * 0.6)
		if walk:
			var lp := ph + (0.0 if sd < 0.0 else 0.5)
			t.x += cos(TAU * lp) * stride
			t.z += maxf(-sin(TAU * lp), 0.0) * leg * 0.28
		var reach: float = hip.z + float(q.crouch) - lw * 0.6
		var e := limb(hip, t, reach * 0.53, reach * 0.53, Vector3(1, 0, 0.1), lw * 1.25, lw * 0.95, lw * 0.85, mat(p.legs) if p.legs != Color.TRANSPARENT else skin)
		ell(e + Vector3(lw * 0.6, 0, -lw * 0.15), Vector3(lw * 1.5, lw * 0.95, lw * 0.75), boot)
	if p.robe:
		var hem := 0.03 * swing if walk else 0.0
		cap(pelvis + Vector3(0, 0, th * 0.4), Vector3(pelvis.x * 0.6 - 0.02 + hem, 0, lw * 1.2), tw * 0.95, tw * 1.35, cloth)
	# torso
	ell(pelvis + tb * Vector3(0, 0, th * 0.15), Vector3(td * 0.95, tw * 0.9, th * 0.55), mat(p.belt) if p.belt != Color.TRANSPARENT else cloth, tb)
	var chest := pelvis + tb * Vector3(0, 0, th * 1.15)
	ell(chest, Vector3(td, tw, th), cloth if p.shirt else skin, tb)
	if p.belly:
		ell(pelvis + tb * Vector3(td * 0.35, 0, th * 0.7), Vector3(td * 0.9, tw * 0.85, th * 0.75), skin, tb)
	if p.belt != Color.TRANSPARENT:
		ell(pelvis + tb * Vector3(0, 0, th * 0.35), Vector3(td * 1.02, tw * 0.94, th * 0.14), mat(p.belt), tb)
	if p.ribs:
		ell(chest + tb * Vector3(td * 0.2, 0, 0), Vector3(td * 0.85, tw * 0.85, th * 0.85), mat(p.skin, false, "band", Color(p.skin).darkened(0.55), 9.0), tb * rot(PI / 2))
	var top := pelvis + tb * Vector3(0, 0, th * 2.05)
	if p.tail:
		var tbase := pelvis + tb * Vector3(-td * 0.8, 0, th * 0.1)
		var ts := sin(TAU * ph) * 0.06 if walk else 0.0
		chain([tbase, tbase + Vector3(-0.1, ts, -0.08), tbase + Vector3(-0.2, ts * 2.0, -0.05), tbase + Vector3(-0.27, ts * 2.5, 0.03)],
			[aw * 0.8, aw * 0.6, aw * 0.45, aw * 0.2], mat(p.tail_col) if p.tail_col != Color.TRANSPARENT else skin)
		if p.tail_tip:
			cap(tbase + Vector3(-0.27, ts * 2.5, 0.03), tbase + Vector3(-0.33, ts * 2.5, 0.08), aw * 0.6, 0.0, skin)
	if p.wings:
		var flap := 0.2 * sin(TAU * ph) if walk else (0.6 if pose.k == 1 else 0.0)
		for sd in [-1.0, 1.0]:
			_wing(chest + tb * Vector3(-td * 0.7, sd * tw * 0.5, th * 0.5), tb, sd, p.wing_span, 0.35 + flap, mat(p.wing_col), mat(p.wing_bone))
	if p.cape != Color.TRANSPARENT:
		var cm := mat(p.cape)
		var sw := 0.04 * swing if walk else (0.05 if pose.k == 2 else 0.0)
		panel([top + tb * Vector3(-td * 0.9, -tw * 0.9, -th * 0.1), top + tb * Vector3(-td * 0.9, tw * 0.9, -th * 0.1),
			Vector3(pelvis.x - td * 1.6 - sw, tw * 1.3, lw * 0.8), Vector3(pelvis.x - td * 1.6 - sw, -tw * 1.3, lw * 0.8)], cm)
	# arms (right = +r holds the weapon) with weapon and shield
	var rest_r := Vector3(0.08 - swing * 0.25 if walk else 0.08, 0.12, -0.9)
	var rest_l := Vector3(0.08 + swing * 0.25 if walk else 0.08, -0.12, -0.9)
	var hold: Dictionary = WEAPON_REST.get(p.weapon, {})
	if pose.k == 0:
		rest_r = hold.get("rh", rest_r)
		rest_l = hold.get("lh", rest_l)
	var rh: Vector3 = q.get("rh", rest_r)
	var lh: Vector3 = q.get("lh", rest_l)
	var wd: Vector3 = q.get("wd", hold.get("wd", Vector3(0.75, 0, 0.6)))
	if p.weapon == "bow" and pose.k == 0:
		rh = rest_r
	var hands := []
	for sd in [1.0, -1.0]:
		var sh := pelvis + tb * Vector3(0, sd * tw * 1.02, th * 1.8)
		var tgt := sh + tb * ((rh if sd > 0.0 else lh) * arm)
		var e := limb(sh, tgt, arm * 0.5, arm * 0.5, tb * Vector3(-1, sd * 0.6, -0.3), aw * 1.3, aw, aw * 0.9, mat(p.sleeve) if p.sleeve != Color.TRANSPARENT else skin)
		ball(e, aw * 1.35, mat(p.hand) if p.hand != Color.TRANSPARENT else skin)
		if p.claws:
			for c in 3:
				cap(e, e + tb * Vector3(aw * 1.6, (c - 1) * aw * 0.7, -aw * 0.8), aw * 0.35, 0.0, mat(Color8(232, 224, 206)))
		if p.pads != Color.TRANSPARENT:
			ell(sh + tb * Vector3(0, sd * aw * 0.4, aw * 0.6), Vector3(aw * 2.0, aw * 2.0, aw * 1.4), mat(p.pads), tb)
		hands.append(e)
	var w_dir := (tb * wd).normalized()
	if p.weapon == "bow":
		_bow(hands[1], hands[0], tb, q.draw, p, pose.k)
	elif p.weapon != "" and q.held:
		_weapon(p.weapon, hands[0], w_dir, p, q.glow, q.whirl)
	elif p.weapon == "sling":
		_weapon("sling", hands[0], w_dir, p, 1.0, 0.0)
	if p.weapon2 != "":
		_weapon(p.weapon2, hands[1], w_dir, p, q.glow, 0.0)
	if p.shield != "":
		var sm := mat(p.shield_col, false, "band", Color(p.shield_col).darkened(0.2), 5.0)
		var sb := tb * rot(0.1, -0.45)
		ell(hands[1] + sb * Vector3(0.03, -0.02, 0.02), Vector3(0.022, 0.13, 0.15) * float(p.shield_r), sm, sb)
		ball(hands[1] + sb * Vector3(0.05, -0.02, 0.02), 0.035 * float(p.shield_r), mat(p.metal))
	# neck and head
	var hb := tb * rot(p.hunch * 0.8 + q.lean * 0.6 + q.hp)
	var hc := top + hb * Vector3(hr * 0.15, 0, hr * 0.82)
	cap(top - tb * Vector3(0, 0, th * 0.2), hc, tw * 0.4, hr * 0.5, skin)
	_biped_head(hc, hb, p, q.jaw, q.squint, skin)


## Default grip per weapon (hands from the shoulders, weapon direction).
const WEAPON_REST := {
	"club": {"rh": Vector3(0.25, 0.15, -0.8), "wd": Vector3(0.7, 0.1, 0.7)},
	"sword": {"rh": Vector3(0.25, 0.15, -0.8), "wd": Vector3(0.8, 0.1, 0.6)},
	"axe": {"rh": Vector3(0.25, 0.15, -0.8), "wd": Vector3(0.6, 0.0, 0.8)},
	"cleaver": {"rh": Vector3(0.2, 0.2, -0.8), "wd": Vector3(0.5, 0.1, 0.85)},
	"hammer": {"rh": Vector3(0.3, 0.15, -0.75), "wd": Vector3(0.45, 0.1, 0.9)},
	"javelin": {"rh": Vector3(0.15, 0.15, -0.75), "wd": Vector3(0.12, 0, 1)},
	"staff": {"rh": Vector3(0.4, 0.15, -0.45), "wd": Vector3(0.12, 0, 1)},
	"crystal_staff": {"rh": Vector3(0.4, 0.15, -0.45), "wd": Vector3(0.12, 0, 1)},
	"bow": {"lh": Vector3(0.25, -0.15, -0.75)},
	"sling": {"rh": Vector3(0.2, 0.15, -0.8), "wd": Vector3(0, 0, -1)},
	"fireball": {"rh": Vector3(0.45, 0.2, -0.35), "wd": Vector3(0.6, 0, 0.8)},
	"scythe": {"rh": Vector3(0.35, 0.15, -0.5), "wd": Vector3(0.15, 0, 1)},
}


func _weapon(kind: String, h: Vector3, d: Vector3, p: Dictionary, glow: float, whirl: float) -> void:
	var s: float = p.wsize
	var wood := mat(p.wood)
	var metal := mat(p.metal)
	var side := d.cross(Vector3(0, 1, 0))
	if side.length() < 0.05:
		side = Vector3(1, 0, 0)
	side = side.normalized()
	var g := d.cross(side).normalized()
	match kind:
		"club":
			cap(h - d * 0.04 * s, h + d * 0.36 * s, 0.022 * s, 0.058 * s, wood)
			for i in 3:
				var at := h + d * (0.22 + i * 0.05) * s
				cap(at + side * 0.04 * s * (1 if i % 2 == 0 else -1), at + side * 0.075 * s * (1 if i % 2 == 0 else -1) + g * 0.02 * s, 0.014 * s, 0.0, metal)
		"sword":
			cap(h - d * 0.05 * s, h + d * 0.03 * s, 0.015 * s, 0.015 * s, mat(p.wood))
			cap(h + d * 0.035 * s - side * 0.055 * s, h + d * 0.035 * s + side * 0.055 * s, 0.014 * s, 0.014 * s, metal)
			panel([h + d * 0.04 * s - side * 0.024 * s, h + d * 0.04 * s + side * 0.024 * s, h + d * 0.36 * s + side * 0.016 * s,
				h + d * 0.42 * s, h + d * 0.36 * s - side * 0.016 * s], metal)
		"axe":
			cap(h - d * 0.12 * s, h + d * 0.5 * s, 0.02 * s, 0.018 * s, wood)
			var top := h + d * 0.44 * s
			panel([top - d * 0.06 * s, top + d * 0.08 * s, top + d * 0.12 * s - side * 0.16 * s, top - d * 0.12 * s - side * 0.16 * s], metal)
		"cleaver":
			cap(h - d * 0.06 * s, h + d * 0.1 * s, 0.022 * s, 0.022 * s, wood)
			panel([h + d * 0.08 * s - side * 0.03 * s, h + d * 0.56 * s - side * 0.03 * s, h + d * 0.6 * s + side * 0.2 * s, h + d * 0.1 * s + side * 0.17 * s], metal)
			ball(h + d * 0.18 * s + side * 0.12 * s, 0.025 * s, mat(Color8(30, 26, 34)))
		"hammer":
			cap(h - d * 0.14 * s, h + d * 0.55 * s, 0.022 * s, 0.022 * s, wood)
			ell(h + d * 0.56 * s, Vector3(0.075, 0.08, 0.13) * s, mat(p.metal, false, "mottle", Color.BLACK, 3.0), Basis(d, g, side))
		"javelin":
			cap(h - d * 0.35 * s, h + d * 0.5 * s, 0.012 * s, 0.012 * s, wood)
			cap(h + d * 0.48 * s, h + d * 0.62 * s, 0.026 * s, 0.0, metal)
			cap(h - d * 0.36 * s + side * 0.02 * s, h - d * 0.3 * s, 0.014 * s, 0.0, mat(Color8(196, 60, 46)))
		"staff", "crystal_staff":
			cap(h - d * 0.45 * s, h + d * 0.38 * s, 0.016 * s, 0.02 * s, wood)
			var tip := h + d * 0.46 * s
			if kind == "staff":
				for i in 3:
					var a := i * TAU / 3.0
					cap(h + d * 0.37 * s, tip + (side * cos(a) + g * sin(a)) * 0.05 * s + d * 0.03 * s, 0.01 * s, 0.004 * s, wood)
				ball(tip, 0.045 * s * minf(glow, 1.6), mat(p.orb, true))
				if glow > 2.0:
					ball(tip + d * 0.02 * s, 0.075 * s, mat(Color(p.orb).lightened(0.5), true))
			else:
				cap(h + d * 0.36 * s, tip + d * 0.12 * s, 0.045 * s * minf(glow, 1.5), 0.0, mat(p.orb, true))
				cap(h + d * 0.38 * s + side * 0.03 * s, tip + side * 0.05 * s + d * 0.04 * s, 0.022 * s, 0.0, mat(p.orb, true))
				if glow > 2.0:
					ball(tip + d * 0.08 * s, 0.07 * s, mat(Color(p.orb).lightened(0.5), true))
		"fireball":
			ball(h + d * 0.05 * s, 0.045 * s * clampf(glow, 1.0, 1.35), mat(p.orb, true))
			ball(h + d * 0.06 * s + Vector3(0, 0, 0.02 * s), 0.024 * s * clampf(glow, 1.0, 1.35), mat(Color(p.orb).lightened(0.5), true))
		"scythe":
			cap(h - d * 0.3 * s, h + d * 0.55 * s, 0.016 * s, 0.016 * s, wood)
			var st := h + d * 0.53 * s
			chain([st, st + side * 0.12 * s + d * 0.02 * s, st + side * 0.26 * s - d * 0.06 * s, st + side * 0.34 * s - d * 0.16 * s],
				[0.03 * s, 0.026 * s, 0.016 * s, 0.0], metal)
		"sling":
			var pouch := h + Vector3(-0.1, 0, 0.12) * s if whirl > 0.0 else h + Vector3(0.03, 0, -0.16) * s
			cap(h, pouch, 0.006 * s, 0.006 * s, mat(Color8(120, 90, 60)))
			ball(pouch, 0.03 * s, mat(Color8(110, 80, 56)))
			if whirl > 0.0:
				ball(pouch + Vector3(0, 0, 0.015 * s), 0.022 * s, mat(Color8(150, 146, 140)))


## Bow held in the left hand, string drawn towards the right hand.
func _bow(lh: Vector3, rh: Vector3, tb: Basis, draw: float, p: Dictionary, k: int) -> void:
	var s: float = p.wsize
	var wood := mat(p.wood)
	var b := tb if k > 0 and k < 4 else tb * rot(0.0, 0.0)
	var pts := []
	var rs := []
	for i in 7:
		var a := lerpf(-1.0, 1.0, i / 6.0)
		pts.append(lh + b * Vector3(-(1.0 - cos(a)) * 0.26 * s, 0, sin(a) * 0.3 * s))
		rs.append(0.016 * s * (1.0 - absf(a) * 0.45))
	chain(pts, rs, wood)
	var string_m := mat(Color8(230, 222, 200))
	var mid: Vector3 = rh if draw > 0.5 else (pts[0] + pts[6]) * 0.5
	cap(pts[0], mid, 0.005 * s, 0.005 * s, string_m)
	cap(mid, pts[6], 0.005 * s, 0.005 * s, string_m)
	if draw > 0.5:
		var fwd := (lh - rh).normalized()
		cap(rh, lh + fwd * 0.06 * s, 0.008 * s, 0.008 * s, mat(Color8(150, 110, 70)))
		cap(lh + fwd * 0.05 * s, lh + fwd * 0.1 * s, 0.018 * s, 0.0, mat(p.metal))


## Bat-like membrane wing from `base`: three finger bones and panels between.
func _wing(base: Vector3, b: Basis, sd: float, span: float, lift: float, skin_m: Dictionary, bone_m: Dictionary) -> void:
	var elbow := base + b * Vector3(-span * 0.2, sd * span * 0.45, span * (0.25 + lift * 0.4))
	var tips := [
		elbow + b * Vector3(span * 0.15, sd * span * 0.45, span * (0.35 + lift * 0.3)),
		elbow + b * Vector3(-span * 0.15, sd * span * 0.6, span * (0.05 + lift * 0.2)),
		elbow + b * Vector3(-span * 0.45, sd * span * 0.4, -span * (0.2 - lift * 0.15)),
	]
	cap(base, elbow, span * 0.045, span * 0.035, bone_m)
	var root := base + b * Vector3(-span * 0.25, 0, -span * 0.15)
	for i in tips.size():
		cap(elbow, tips[i], span * 0.025, span * 0.01, bone_m)
	panel([base, elbow, tips[0]], skin_m)
	panel([elbow, tips[0], tips[1]], skin_m)
	panel([elbow, tips[1], tips[2]], skin_m)
	panel([base, elbow, tips[2], root], skin_m)


## Heads of the folk. Shared language: big head, readable eyes, one strong
## feature per kind (goblin ears, gnome beard and hat, orc tusks, troll nose,
## ogre brow, giant beard, skull sockets, demon horns).
func _biped_head(h: Vector3, hb: Basis, p: Dictionary, jaw: float, squint: float, skin: Dictionary) -> void:
	var hr: float = p.hr
	var kind := String(p.head)
	if p.has("beast"):
		var bp: Dictionary = Specs.RIG.quadruped.duplicate()
		bp.merge(p.beast, true)
		_beast_head(h, hb, bp, jaw, squint, skin)
		return
	var dark := mat(Color8(30, 22, 30))
	var tooth := mat(Color8(240, 230, 206))
	var hair := mat(p.hair, p.hair_glow, "mottle", Color.BLACK, 5.0)
	match kind:
		"skull", "pharaoh":
			ell(h, Vector3(hr * 0.95, hr * 0.85, hr * 0.92), skin, hb)
			var jb := hb * rot(-jaw * 0.8)
			ell(h + hb * Vector3(hr * 0.35, 0, -hr * 0.6) + jb * Vector3(hr * 0.25, 0, -hr * 0.1), Vector3(hr * 0.42, hr * 0.55, hr * 0.28), skin, jb)
			for sd in [-1.0, 1.0]:
				ell(h + hb * Vector3(hr * 0.68, sd * hr * 0.36, hr * 0.02), Vector3(hr * 0.2, hr * 0.24, hr * 0.24), dark, hb)
				if squint == 0.0:
					ball(h + hb * Vector3(hr * 0.8, sd * hr * 0.36, hr * 0.02), hr * 0.11, mat(p.eye, true))
			ell(h + hb * Vector3(hr * 0.85, 0, -hr * 0.28), Vector3(hr * 0.1, hr * 0.12, hr * 0.12), dark, hb)
			for i in 4:
				ball(h + hb * Vector3(hr * 0.78, (i - 1.5) * hr * 0.14, -hr * 0.52), hr * 0.07, tooth)
			if kind == "pharaoh":
				var gold := mat(Color8(226, 180, 70), false, "band", Color8(54, 84, 150), 7.0)
				ell(h + hb * Vector3(-hr * 0.15, 0, hr * 0.15), Vector3(hr * 0.95, hr * 1.05, hr * 0.95), gold, hb * rot(PI / 2))
				for sd in [-1.0, 1.0]:
					ell(h + hb * Vector3(-hr * 0.05, sd * hr * 0.85, -hr * 0.65), Vector3(hr * 0.3, hr * 0.15, hr * 0.6), gold, hb)
				cap(h + hb * Vector3(hr * 0.75, 0, hr * 0.6), h + hb * Vector3(hr * 0.95, 0, hr * 0.85), hr * 0.12, hr * 0.06, mat(Color8(240, 200, 80)))
		"mummy":
			ell(h, Vector3(hr * 0.95, hr * 0.88, hr * 0.95), mat(p.skin, false, "wrap", Color.BLACK, 7.0), hb)
			if squint == 0.0:
				ball(h + hb * Vector3(hr * 0.86, hr * 0.32, hr * 0.05), hr * 0.13, mat(p.eye, true))
			ell(h + hb * Vector3(hr * 0.8, -hr * 0.3, hr * 0.05), Vector3(hr * 0.15, hr * 0.2, hr * 0.06), dark, hb)
			if jaw > 0.1:
				ell(h + hb * Vector3(hr * 0.8, 0, -hr * 0.45), Vector3(hr * 0.12, hr * 0.25, hr * 0.1 + jaw * hr * 0.12), dark, hb)
		"stone":
			ell(h, Vector3(hr * 0.95, hr * 1.05, hr * 0.85), skin, hb * rot(0.1))
			ell(h + hb * Vector3(hr * 0.3, 0, hr * 0.35), Vector3(hr * 0.7, hr * 0.95, hr * 0.4), skin, hb)
			for sd in [-1.0, 1.0]:
				ell(h + hb * Vector3(hr * 0.86, sd * hr * 0.38, 0), Vector3(hr * 0.08, hr * 0.2, hr * 0.08), mat(p.eye, true), hb)
			ell(h + hb * Vector3(-hr * 0.1, 0, hr * 0.6), Vector3(hr * 0.6, hr * 0.7, hr * 0.25), mat(p.hair, false, "mottle", Color.BLACK, 6.0), hb)
		_:
			var wide := 1.12 if kind in ["ogre", "troll", "orc", "giant"] else 1.0
			ell(h, Vector3(hr * 0.95, hr * 0.9 * wide, hr * 0.92), skin, hb)
			if kind in ["orc", "troll", "ogre"]:
				var jb2 := hb * rot(-jaw * 0.6)
				ell(h + hb * Vector3(hr * 0.3, 0, -hr * 0.5) + jb2 * Vector3(hr * 0.2, 0, -hr * 0.05), Vector3(hr * 0.58, hr * 0.78 * wide, hr * 0.42), skin, jb2)
				if jaw > 0.1:
					ell(h + hb * Vector3(hr * 0.72, 0, -hr * 0.42), Vector3(hr * 0.12, hr * 0.4, hr * 0.1 + jaw * hr * 0.15), mat(Color8(110, 30, 40)), hb)
				for sd in [-1.0, 1.0]:
					var tk := h + hb * Vector3(hr * 0.72, sd * hr * 0.38, -hr * 0.55) + jb2 * Vector3(0, 0, 0)
					cap(tk, tk + hb * Vector3(hr * 0.05, sd * hr * 0.04, hr * (0.42 if kind != "ogre" else 0.25)), hr * 0.1, 0.0, tooth)
			elif kind != "gnome" and kind != "giant":
				var mouth_w := hr * (0.4 if kind in ["goblin", "imp", "demon"] else 0.3)
				ell(h + hb * Vector3(hr * 0.82, 0, -hr * 0.42), Vector3(hr * 0.1, mouth_w, hr * 0.05 + jaw * hr * 0.18), mat(Color8(90, 26, 40)), hb)
				for sd in [-1.0, 1.0]:
					cap(h + hb * Vector3(hr * 0.86, sd * mouth_w * 0.6, -hr * 0.4), h + hb * Vector3(hr * 0.9, sd * mouth_w * 0.6, -hr * 0.52), hr * 0.07, 0.0, tooth)
			for sd in [-1.0, 1.0]:
				var ep := h + hb * Vector3(hr * 0.78, sd * hr * 0.36, hr * 0.06)
				if squint > 0.0:
					ell(ep, Vector3(hr * 0.06, hr * 0.17, hr * 0.04), dark, hb)
				elif p.eye_glow:
					ell(ep, Vector3(hr * 0.12, hr * 0.17, hr * 0.12), mat(p.eye, true), hb)
				else:
					ball(ep, hr * 0.2, mat(Color8(246, 238, 214)))
					ball(ep + hb * Vector3(hr * 0.12, -sd * hr * 0.02, 0), hr * 0.11, mat(p.eye))
				if kind == "ogre" or kind == "troll" or kind == "giant":
					ell(h + hb * Vector3(hr * 0.72, sd * hr * 0.32, hr * 0.28), Vector3(hr * 0.22, hr * 0.3, hr * 0.12), skin, hb * rot(-0.25 * sd, 0, 0.0))
			match kind:
				"goblin", "imp", "demon":
					cap(h + hb * Vector3(hr * 0.85, 0, -hr * 0.05), h + hb * Vector3(hr * (1.3 if kind == "goblin" else 1.1), 0, -hr * 0.25), hr * 0.16, hr * 0.06, skin)
					for sd in [-1.0, 1.0]:
						var eb := h + hb * Vector3(-hr * 0.05, sd * hr * 0.8, hr * 0.15)
						cap(eb, eb + hb * Vector3(-hr * 0.35, sd * hr * (1.05 if kind == "goblin" else 0.55), hr * 0.3), hr * 0.24, 0.0, skin)
				"orc", "troll":
					var nose_l := 0.75 if kind == "troll" else 0.3
					cap(h + hb * Vector3(hr * 0.85, 0, hr * 0.0), h + hb * Vector3(hr * (0.85 + nose_l), 0, -hr * nose_l * 0.4), hr * 0.17, hr * 0.12, skin)
					for sd in [-1.0, 1.0]:
						var ob := h + hb * Vector3(-hr * 0.05, sd * hr * 0.85, hr * 0.1)
						cap(ob, ob + hb * Vector3(-hr * 0.3, sd * hr * 0.45, hr * 0.25), hr * 0.18, 0.0, skin)
				"ogre":
					ell(h + hb * Vector3(hr * 0.9, 0, -hr * 0.12), Vector3(hr * 0.18, hr * 0.2, hr * 0.16), skin, hb)
					for sd in [-1.0, 1.0]:
						ball(h + hb * Vector3(-hr * 0.05, sd * hr * 0.98, 0), hr * 0.2, skin)
				"gnome", "giant":
					ball(h + hb * Vector3(hr * 0.92, 0, -hr * 0.12), hr * (0.24 if kind == "gnome" else 0.18), mat(Color(p.skin).lerp(Color8(220, 110, 100), 0.35)))
					var beard := mat(p.hair, p.hair_glow, "mottle", Color.BLACK, 6.0)
					var bj := hb * rot(-jaw * 0.4)
					ell(h + hb * Vector3(hr * 0.55, 0, -hr * 0.55) + bj * Vector3(0, 0, -hr * 0.2), Vector3(hr * 0.5, hr * 0.72, hr * 0.8), beard, bj * rot(-0.35))
					cap(h + hb * Vector3(hr * 0.6, 0, -hr * 0.9), h + hb * Vector3(hr * 0.75, 0, -hr * 1.5), hr * 0.35, hr * 0.05, beard)
			if p.horns != "":
				var hm := mat(p.horn_col, false, "band", Color(p.horn_col).darkened(0.3), 6.0)
				for sd in [-1.0, 1.0]:
					var hbse := h + hb * Vector3(hr * 0.1, sd * hr * 0.55, hr * 0.62)
					match String(p.horns):
						"small":
							cap(hbse, hbse + hb * Vector3(-hr * 0.15, sd * hr * 0.1, hr * 0.45), hr * 0.14, 0.0, hm)
						"ram":
							chain([hbse, hbse + hb * Vector3(-hr * 0.35, sd * hr * 0.35, hr * 0.35), hbse + hb * Vector3(-hr * 0.55, sd * hr * 0.6, -hr * 0.1), hbse + hb * Vector3(-hr * 0.15, sd * hr * 0.75, -hr * 0.45)], [hr * 0.2, hr * 0.17, hr * 0.12, hr * 0.03], hm)
						"great":
							chain([hbse, hbse + hb * Vector3(-hr * 0.1, sd * hr * 0.55, hr * 0.35), hbse + hb * Vector3(-hr * 0.35, sd * hr * 0.75, hr * 0.95), hbse + hb * Vector3(-hr * 0.7, sd * hr * 0.6, hr * 1.4)], [hr * 0.24, hr * 0.2, hr * 0.13, 0.0], hm)
						"crown":
							for i in 3:
								var cb := h + hb * Vector3(hr * (0.2 - i * 0.35), sd * hr * (0.55 + i * 0.1), hr * 0.6)
								cap(cb, cb + hb * Vector3(-hr * 0.2, sd * hr * 0.15, hr * (0.7 - i * 0.12)), hr * 0.13, 0.0, hm)
	# headgear
	match String(p.hat):
		"hood":
			var hm2 := mat(p.hat_col, false, "mottle", Color.BLACK, 4.0)
			ell(h + hb * Vector3(-hr * 0.24, 0, hr * 0.16), Vector3(hr * 0.95, hr * 1.04, hr * 1.0), hm2, hb)
			cap(h + hb * Vector3(-hr * 0.6, 0, hr * 0.5), h + hb * Vector3(-hr * 1.2, 0, hr * 0.1), hr * 0.35, 0.0, hm2)
		"cowl":
			var cm := mat(p.hat_col)
			ell(h + hb * Vector3(-hr * 0.1, 0, hr * 0.12), Vector3(hr * 1.05, hr * 1.06, hr * 1.06), cm, hb)
			cap(h + hb * Vector3(-hr * 0.2, 0, hr * 0.7), h + hb * Vector3(-hr * 0.6, 0, hr * 1.5), hr * 0.5, 0.0, cm)
		"gnome":
			var gm := mat(p.hat_col)
			ell(h + hb * Vector3(-hr * 0.05, 0, hr * 0.45), Vector3(hr * 0.98, hr * 0.98, hr * 0.32), gm, hb)
			chain([h + hb * Vector3(-hr * 0.05, 0, hr * 0.5), h + hb * Vector3(-hr * 0.2, 0, hr * 1.4), h + hb * Vector3(-hr * 0.65, 0, hr * 2.0)], [hr * 0.8, hr * 0.45, 0.0], gm)
		"cap":
			ell(h + hb * Vector3(-hr * 0.05, 0, hr * 0.38), Vector3(hr * 0.98, hr * 0.96, hr * 0.62), mat(p.hat_col, false, "band", Color(p.hat_col).darkened(0.25), 4.0), hb * rot(PI / 2))
		"helm", "horned_helm":
			var mm := mat(p.metal, false, "mottle", Color.BLACK, 3.0)
			ell(h + hb * Vector3(-hr * 0.02, 0, hr * 0.12), Vector3(hr * 1.02, hr * 0.98, hr * 1.0), mm, hb)
			ell(h + hb * Vector3(hr * 0.86, 0, hr * 0.06), Vector3(hr * 0.12, hr * 0.48, hr * 0.06), dark, hb)
			if squint == 0.0:
				for sd in [-1.0, 1.0]:
					ball(h + hb * Vector3(hr * 0.94, sd * hr * 0.22, hr * 0.06), hr * 0.08, mat(p.eye, true))
			cap(h + hb * Vector3(hr * 0.8, 0, hr * 0.5), h + hb * Vector3(hr * 0.98, 0, -hr * 0.4), hr * 0.08, hr * 0.06, mm)
			if p.hat == "horned_helm":
				var hh := mat(p.horn_col)
				for sd in [-1.0, 1.0]:
					var hp0 := h + hb * Vector3(0, sd * hr * 0.85, hr * 0.45)
					chain([hp0, hp0 + hb * Vector3(hr * 0.1, sd * hr * 0.5, hr * 0.35), hp0 + hb * Vector3(hr * 0.25, sd * hr * 0.55, hr * 0.9)], [hr * 0.18, hr * 0.12, 0.0], hh)
		"crown":
			var crm := mat(Color8(232, 186, 70))
			ell(h + hb * Vector3(0, 0, hr * 0.62), Vector3(hr * 0.7, hr * 0.7, hr * 0.16), crm, hb)
			for i in 5:
				var a := i * TAU / 5.0
				var cb2 := h + hb * Vector3(cos(a) * hr * 0.62, sin(a) * hr * 0.62, hr * 0.7)
				cap(cb2, cb2 + Vector3(0, 0, hr * 0.32), hr * 0.08, 0.0, crm)
	if p.hair_style == "topknot":
		var tk2 := h + hb * Vector3(-hr * 0.35, 0, hr * 0.8)
		ball(tk2, hr * 0.25, hair)
		chain([tk2, tk2 + hb * Vector3(-hr * 0.45, 0, -hr * 0.1), tk2 + hb * Vector3(-hr * 0.6, 0, -hr * 0.6)], [hr * 0.16, hr * 0.13, hr * 0.06], hair)
	elif p.hair_style == "shag":
		ell(h + hb * Vector3(-hr * 0.2, 0, hr * 0.35), Vector3(hr * 0.9, hr * 1.0, hr * 0.75), hair, hb)
		for i in 3:
			cap(h + hb * Vector3(-hr * 0.3 - i * hr * 0.2, (i - 1) * hr * 0.4, hr * 0.7), h + hb * Vector3(-hr * 0.85 - i * hr * 0.1, (i - 1) * hr * 0.6, hr * 0.2), hr * 0.25, 0.0, hair)
	elif p.hair_style == "flame":
		for i in 5:
			var fb := h + hb * Vector3(-hr * 0.1 - (i % 3) * hr * 0.25, (i - 2) * hr * 0.3, hr * 0.65)
			cap(fb, fb + hb * Vector3(-hr * 0.35, (i - 2) * hr * 0.1, hr * 0.7), hr * 0.24, 0.0, hair)


# ---------------------------------------------------------------- crawler

## Many-legged vermin: spiders, scorpions, crabs, grubs. Knobs: shift / air /
## crouch move the body, bp pitches it, fl raises the front legs, jaw opens
## fangs or pincers, tc cocks the tail (+1 back, -1 struck forward), cr
## raises the claws.
const CPOSE := {
	"pounce": [{"crouch": 0.04, "shift": -0.05, "bp": 0.25, "fl": 0.12, "jaw": 0.3},
		{"air": 0.12, "shift": 0.15, "bp": -0.12, "fl": 0.16, "jaw": 1.0},
		{"crouch": 0.02, "shift": 0.08, "jaw": 0.2}],
	"charge": [{"shift": -0.04, "crouch": 0.02, "tc": 1.0, "jaw": 1.0, "cr": 0.5},
		{"shift": 0.12, "tc": -1.0, "jaw": 0.0, "cr": -0.15, "bp": -0.06},
		{"shift": 0.06, "tc": 0.3, "jaw": 0.4}],
	"ranged": [{"cr": 1.0, "jaw": 1.0, "bp": 0.18, "shift": -0.03},
		{"cr": -0.4, "jaw": 0.0, "shift": 0.07, "bp": -0.1, "crouch": 0.02},
		{"cr": 0.1, "jaw": 0.3, "shift": 0.03}],
	"summon": [{"bp": 0.35, "fl": 0.12, "jaw": 0.5, "crouch": 0.02},
		{"bp": -0.15, "shift": 0.06, "fl": 0.05, "jaw": 1.0, "crouch": 0.04},
		{"bp": 0.05, "jaw": 0.3}],
	"bite": [{"bp": 0.6, "shift": -0.06, "jaw": 0.3},
		{"bp": -0.15, "shift": 0.14, "jaw": 1.0},
		{"shift": 0.05, "jaw": 0.2}],
}
const CHURT := {"shift": -0.05, "bp": 0.3, "jaw": 0.5, "squint": 1.0, "fl": 0.05, "tc": 0.5, "cr": 0.6}


func _crawler(p: Dictionary, pose: Dictionary) -> void:
	var q := _knobs(CPOSE, CHURT, p.atk, pose, {"shift": 0.0, "air": 0.0, "crouch": 0.0, "bp": 0.0, "fl": 0.0,
		"jaw": 0.0, "tc": 0.0, "cr": 0.0, "squint": 0.0})
	var walk: bool = pose.st == "walk"
	var ph: float = pose.ph
	var bob := 0.008 * absf(sin(TAU * ph * 2.0)) if walk else 0.0
	var hgt: float = p.hgt
	var root := Vector3(q.shift, 0, hgt - q.crouch + q.air + bob)
	var bb := rot(q.bp)
	var shell := mat(p.col, false, p.pat, p.col2, p.pf)
	var dark := mat(p.col2)
	var leg_m := mat(p.leg_col, false, "band", Color(p.leg_col).darkened(0.35), 7.0)
	var th: float = p.th
	var body := String(p.body)
	if body == "grub":
		_grub(p, q, walk, ph, shell, dark)
		return
	# legs: alternating tetrapod gait, knees high
	var pairs: int = 4 if body == "spider" else 3
	var R: float = p.leg
	var stride: float = p.stride
	for sd in [-1.0, 1.0]:
		for i in pairs:
			var a := lerpf(0.8, -0.8, i / float(pairs - 1))
			var hx := th * (0.45 - i * 0.3) if body == "spider" else th * (0.2 - i * 0.45)
			var hip := root + bb * Vector3(hx, sd * th * 0.55, -th * 0.05)
			var foot := Vector3(hx * 0.4 + sin(a) * R * 0.7, sd * (cos(a) * R * 0.8 + th * 0.4), p.lw * 0.5)
			if walk:
				var lp := ph + (0.5 if (i + (0 if sd < 0.0 else 1)) % 2 == 1 else 0.0)
				foot.x += cos(TAU * lp) * stride
				foot.z += maxf(-sin(TAU * lp), 0.0) * hgt * 0.7
			if i == 0 and q.fl > 0.0:
				foot = hip + bb * Vector3(R * 0.45, sd * R * 0.3, q.fl + R * 0.15)
			var dist := hip.distance_to(foot)
			var ln := maxf(R * 0.62, dist * 0.56)
			limb(hip, foot, ln, ln, Vector3(sin(a) * 0.3, sd * 0.5, 1.0), p.lw * 1.3, p.lw, p.lw * 0.55, leg_m)
	match body:
		"spider":
			var ab: float = p.ab
			ell(root + bb * Vector3(-th - ab * 0.8, 0, ab * 0.35), Vector3(ab * 1.1, ab * 0.95, ab * 0.85), mat(p.col, false, p.abd_pat, p.col2, p.pf), bb * rot(0.25))
			if p.brood:
				for k in 6:
					var a2 := k * 2.4
					ball(root + bb * Vector3(-th - ab * 0.8 + cos(a2) * ab * 0.5, sin(a2) * ab * 0.55, ab * 1.15), ab * 0.17, mat(Color(p.col).lightened(0.25)))
			ell(root, Vector3(th * 1.1, th, th * 0.7), shell, bb)
			var hc := root + bb * Vector3(th * 0.95, 0, th * 0.15)
			ell(hc, Vector3(th * 0.55, th * 0.7, th * 0.55), shell, bb)
			if q.squint == 0.0:
				for sd in [-1.0, 1.0]:
					eye(hc + bb * Vector3(th * 0.45, sd * th * 0.22, th * 0.22), th * 0.17, p.eye, p.eye_glow, bb)
					eye(hc + bb * Vector3(th * 0.32, sd * th * 0.45, th * 0.38), th * 0.1, p.eye, p.eye_glow, bb)
			var fang := mat(p.fang)
			for sd in [-1.0, 1.0]:
				var fb := hc + bb * Vector3(th * 0.45, sd * th * 0.2, -th * 0.2)
				cap(fb, fb + bb * Vector3(th * (0.15 + q.jaw * 0.2), sd * th * q.jaw * 0.25, -th * 0.45), th * 0.14, 0.0, fang)
		"scorpion":
			for k in 4:
				ell(root + bb * Vector3(-k * th * 0.85, 0, k * th * 0.06), Vector3(th * 0.75, th * (1.0 - k * 0.12), th * 0.5), shell, bb)
			var hc2 := root + bb * Vector3(th * 0.75, 0, 0)
			ell(hc2, Vector3(th * 0.5, th * 0.75, th * 0.4), shell, bb)
			if q.squint == 0.0:
				for sd in [-1.0, 1.0]:
					eye(hc2 + bb * Vector3(th * 0.2, sd * th * 0.2, th * 0.35), th * 0.11, p.eye, p.eye_glow, bb)
			_claws(p, q, root + bb * Vector3(th * 0.8, 0, 0), bb, shell, dark)
			# tail arcs over the back, segment by segment
			var tl: float = p.tl
			var step = 0.5 + (-q.tc) * 0.13 + (0.03 * sin(TAU * ph) if walk else 0.0)
			var seg := tl / 6.0 * (1.0 + maxf(-q.tc, 0.0) * 0.25)
			var pt := root + bb * Vector3(-th * 3.0, 0, th * 0.2)
			var ang := PI - 0.35 - maxf(q.tc, 0.0) * 0.15
			var pts := [pt]
			var rs := [th * 0.45]
			for k in 5:
				pt = pt + bb * Vector3(cos(ang) * seg, 0, sin(ang) * seg)
				pts.append(pt)
				rs.append(th * (0.42 - k * 0.04))
				ang -= step
			chain(pts, rs, shell)
			ell(pt + bb * Vector3(cos(ang) * seg * 0.4, 0, sin(ang) * seg * 0.4), Vector3(th * 0.38, th * 0.3, th * 0.3), mat(p.sting_col, p.sting_glow), bb * rot(ang))
			var sb := pt + bb * Vector3(cos(ang) * seg * 0.7, 0, sin(ang) * seg * 0.7)
			cap(sb, sb + bb * Vector3(cos(ang - 1.0) * seg * 0.7, 0, sin(ang - 1.0) * seg * 0.7), th * 0.14, 0.0, dark)
		"crab":
			var cw: float = p.cw
			ell(root + bb * Vector3(0, 0, th * 0.2), Vector3(cw * 0.75, cw, th * 1.0), shell, bb)
			ell(root + bb * Vector3(0, 0, th * 0.75), Vector3(cw * 0.5, cw * 0.65, th * 0.35), shell, bb)
			for sd in [-1.0, 1.0]:
				var stalk := root + bb * Vector3(cw * 0.55, sd * cw * 0.25, th * 0.6)
				var top := stalk + bb * Vector3(th * 0.1, sd * th * 0.1, th * (0.2 if q.squint > 0.0 else 0.75))
				cap(stalk, top, th * 0.12, th * 0.1, dark)
				eye(top, th * 0.2, p.eye, p.eye_glow, bb)
			_claws(p, q, root + bb * Vector3(cw * 0.55, 0, th * 0.1), bb, shell, dark)


func _claws(p: Dictionary, q: Dictionary, front: Vector3, bb: Basis, shell: Dictionary, dark: Dictionary) -> void:
	var cl: float = p.cl
	var w: float = p.get("cw", p.th)
	for sd in [-1.0, 1.0]:
		var sh := front + bb * Vector3(0, sd * w * 0.55, 0)
		var hand := sh + bb * Vector3(cl * (1.6 - absf(q.cr) * 0.3) + maxf(-q.cr, 0.0) * cl * 0.6, sd * w * 0.45, cl * 0.4 + q.cr * cl * 1.6)
		var e := limb(sh, hand, cl * 1.1, cl * 1.1, Vector3(-0.3, sd, 0.4), cl * 0.32, cl * 0.28, cl * 0.3, shell)
		var cb := bb * rot(q.cr * 0.6, sd * 0.25)
		ell(e + cb * Vector3(cl * 0.35, 0, 0), Vector3(cl * 0.6, cl * 0.42, cl * 0.36), shell, cb)
		var jw: float = q.jaw
		cap(e + cb * Vector3(cl * 0.7, 0, cl * 0.1), e + cb * Vector3(cl * 1.45, -sd * cl * 0.05, cl * (0.12 + jw * 0.4)), cl * 0.24, cl * 0.03, shell)
		cap(e + cb * Vector3(cl * 0.7, 0, -cl * 0.1), e + cb * Vector3(cl * 1.3, -sd * cl * 0.05, -cl * (0.1 + jw * 0.25)), cl * 0.18, cl * 0.03, dark)


## Moss grub: a chain of soft segments with a peristaltic wave.
func _grub(p: Dictionary, q: Dictionary, walk: bool, ph: float, shell: Dictionary, dark: Dictionary) -> void:
	var r: float = p.th
	var n := 6
	var pts := []
	for i in n:
		var s := float(i)
		var wave := maxf(sin(TAU * ph - s * 1.1), 0.0) if walk else 0.0
		var lift := maxf(q.bp, 0.0) * maxf(3.0 - s, 0.0) * r * 0.55
		pts.append(Vector3(q.shift + r * 1.5 - s * r * (1.25 - wave * 0.2), 0, r * (1.0 - s * 0.07) + wave * r * 0.35 + lift))
	for i in range(n - 1, -1, -1):
		var rr := r * (1.05 - absf(i - 1.5) * 0.09)
		ell(pts[i], Vector3(rr * 0.85, rr, rr * 0.92), shell)
		if i > 0:
			for sd in [-1.0, 1.0]:
				ball(Vector3(pts[i].x, sd * rr * 0.6, r * 0.18), r * 0.2, dark)
	var hd: Vector3 = pts[0] + Vector3(r * 0.6, 0, 0)
	ell(hd, Vector3(r * 0.7, r * 0.8, r * 0.75), mat(p.head_col))
	for sd in [-1.0, 1.0]:
		if q.squint == 0.0:
			eye(hd + Vector3(r * 0.5, sd * r * 0.35, r * 0.25), r * 0.17, p.eye, p.eye_glow)
		var mb := hd + Vector3(r * 0.55, sd * r * 0.25, -r * 0.3)
		cap(mb, mb + Vector3(r * 0.35, sd * r * (0.05 + q.jaw * 0.3), -r * 0.05), r * 0.13, 0.0, mat(p.fang))
	for sd in [-1.0, 1.0]:
		cap(hd + Vector3(0, sd * r * 0.3, r * 0.6), hd + Vector3(r * 0.3, sd * r * 0.55, r * 1.1), r * 0.07, r * 0.04, dark)

# ---------------------------------------------------------------- flyer

## Winged pests hover; the walk columns are a wing-beat cycle. Knobs: rise
## (altitude), bp (pitch: dive < 0), wing (forced wing angle, 1 up / -1
## down), shift, jaw, sting (abdomen curls forward), roll.
const FPOSE := {
	"hit_run": [{"rise": 0.08, "bp": 0.3, "wing": 1.0, "shift": -0.05, "jaw": 0.3},
		{"rise": -0.1, "bp": -0.5, "wing": -0.7, "shift": 0.13, "jaw": 1.0, "sting": 1.0},
		{"bp": -0.1, "wing": 0.3, "shift": 0.05, "jaw": 0.2}],
	"summon": [{"rise": 0.05, "bp": 0.25, "wing": 1.0, "jaw": 0.5, "sting": 0.4},
		{"rise": -0.02, "bp": -0.2, "wing": -0.5, "jaw": 1.0, "sting": 1.0, "shift": 0.05},
		{"wing": 0.3, "jaw": 0.3}],
	"slam": [{"rise": 0.1, "wing": 1.0, "bp": 0.25},
		{"rise": -0.08, "wing": -0.9, "bp": -0.35, "shift": 0.12},
		{"wing": 0.2, "shift": 0.05}],
}
const FHURT := {"rise": -0.03, "bp": 0.45, "shift": -0.05, "wing": 0.7, "roll": 0.35, "squint": 1.0, "jaw": 0.4}


func _flyer(p: Dictionary, pose: Dictionary) -> void:
	var walk: bool = pose.st == "walk"
	var flap := cos(TAU * pose.ph) if walk else 0.35
	var q := _knobs(FPOSE, FHURT, p.atk, pose, {"rise": 0.0, "bp": 0.0, "wing": flap, "shift": 0.0, "jaw": 0.0,
		"sting": 0.0, "roll": 0.0, "squint": 0.0})
	var r: float = p.br
	var root := Vector3(q.shift, 0, p.alt + q.rise - flap * 0.02)
	var bb := rot(q.bp, 0.0, q.roll)
	var fur := mat(p.col, false, p.pat, p.col2, p.pf)
	var dark := mat(p.col2)
	var ws: float = p.wing_span
	match String(p.body):
		"bat":
			ell(root, Vector3(r * 1.1, r * 0.9, r * 0.95), fur, bb)
			ell(root + bb * Vector3(r * 0.3, 0, -r * 0.15), Vector3(r * 0.8, r * 0.7, r * 0.75), mat(p.belly), bb)
			for sd in [-1.0, 1.0]:
				_wing(root + bb * Vector3(r * 0.2, sd * r * 0.6, r * 0.3), bb, sd, ws, q.wing * 0.9, mat(p.wing_col, p.wing_glow, "band", Color(p.wing_col).darkened(0.2), 4.0), mat(p.wing_bone))
				cap(root + bb * Vector3(-r * 0.5, sd * r * 0.35, -r * 0.6), root + bb * Vector3(-r * 0.6, sd * r * 0.4, -r * 1.2), r * 0.12, r * 0.08, dark)
			var hc := root + bb * Vector3(r * 1.05, 0, r * 0.45)
			ell(hc, Vector3(r * 0.62, r * 0.66, r * 0.6), fur, bb)
			for sd in [-1.0, 1.0]:
				cap(hc + bb * Vector3(-r * 0.1, sd * r * 0.38, r * 0.35), hc + bb * Vector3(-r * 0.25, sd * r * 0.7, r * 1.15), r * 0.3, 0.0, mat(p.ear_col))
				if q.squint == 0.0:
					eye(hc + bb * Vector3(r * 0.5, sd * r * 0.3, r * 0.12), r * 0.15, p.eye, p.eye_glow, bb)
				cap(hc + bb * Vector3(r * 0.55, sd * r * 0.14, -r * 0.3), hc + bb * Vector3(r * 0.6, sd * r * 0.14, -r * (0.55 + q.jaw * 0.15)), r * 0.08, 0.0, mat(Color8(240, 232, 214)))
			ell(hc + bb * Vector3(r * 0.58, 0, -r * 0.1), Vector3(r * 0.2, r * 0.22, r * 0.17), mat(p.belly), bb)
			if p.flames:
				for k in 3:
					cap(root + bb * Vector3(-r * 0.5 - k * r * 0.2, (k - 1) * r * 0.4, r * 0.3), root + bb * Vector3(-r * 1.4, (k - 1) * r * 0.6, r * 0.9), r * 0.3, 0.0, mat(Color8(255, 140, 40), true))
		"bee":
			var ab := root + bb * Vector3(-r * 1.2, 0, -r * 0.1)
			var abb := bb * rot(-0.3 - q.sting * 1.0)
			var al: float = p.abd
			ell(ab + abb * Vector3(-r * al * 0.5, 0, 0), Vector3(r * al, r * 0.95, r * 0.9), mat(p.col, false, "band", p.col2, p.pf), abb)
			cap(ab + abb * Vector3(-r * al * 1.4, 0, 0), ab + abb * Vector3(-r * al * 1.4 - r * 0.6, 0, -r * 0.1), r * 0.14, 0.0, dark)
			ell(root, Vector3(r * 0.72, r * 0.68, r * 0.7), mat(p.thorax, false, "mottle", Color.BLACK, 9.0), bb)
			var wm := mat(p.wing_col)
			for sd in [-1.0, 1.0]:
				for k in 2:
					var wa: float = q.wing * 0.9 + 0.15 - k * 0.3
					var wb := bb * rot(0.0, -0.35 - k * 0.45) * Basis(Vector3(1, 0, 0), sd * wa)
					ell(root + bb * Vector3(-r * 0.2 - k * r * 0.3, 0, r * 0.45) + wb * Vector3(0, sd * ws * 0.5, 0), Vector3(ws * 0.2, ws * 0.5, 0.004), wm, wb)
				for k in 3:
					var lb := root + bb * Vector3(r * (0.3 - k * 0.3), sd * r * 0.45, -r * 0.4)
					cap(lb, lb + bb * Vector3(-r * 0.3, sd * r * 0.3, -r * 0.6), r * 0.1, r * 0.06, dark)
			var hc2 := root + bb * Vector3(r * 0.85, 0, r * 0.05)
			ell(hc2, Vector3(r * 0.55, r * 0.62, r * 0.55), mat(p.head_col), bb)
			for sd in [-1.0, 1.0]:
				if q.squint == 0.0:
					ell(hc2 + bb * Vector3(r * 0.25, sd * r * 0.4, r * 0.1), Vector3(r * 0.25, r * 0.2, r * 0.32), mat(p.eye), bb)
				chain([hc2 + bb * Vector3(r * 0.2, sd * r * 0.2, r * 0.45), hc2 + bb * Vector3(r * 0.5, sd * r * 0.35, r * 0.95), hc2 + bb * Vector3(r * 0.85, sd * r * 0.45, r * 1.0)], [r * 0.06, r * 0.05, r * 0.08], dark)
				cap(hc2 + bb * Vector3(r * 0.4, sd * r * 0.15, -r * 0.35), hc2 + bb * Vector3(r * 0.6, sd * r * (0.05 + q.jaw * 0.12), -r * 0.5), r * 0.08, 0.0, dark)
			if p.crown:
				var cm := mat(Color8(240, 196, 70))
				for k in 4:
					var a := k * TAU / 4.0 + 0.4
					cap(hc2 + bb * Vector3(cos(a) * r * 0.3, sin(a) * r * 0.3, r * 0.5), hc2 + bb * Vector3(cos(a) * r * 0.35, sin(a) * r * 0.35, r * 0.85), r * 0.09, 0.0, cm)
		"moth":
			chain([root + bb * Vector3(r * 0.6, 0, r * 0.1), root, root + bb * Vector3(-r * 1.0, 0, -r * 0.1), root + bb * Vector3(-r * 1.6, 0, -r * 0.15)], [r * 0.6, r * 0.62, r * 0.5, r * 0.15], fur)
			var wm2 := mat(p.wing_col, p.wing_glow, "spots", p.col2, 5.0)
			for sd in [-1.0, 1.0]:
				for k in 2:
					var wa2: float = q.wing * 0.8 + 0.1
					var wb2 := bb * rot(0.0, (0.25 if k == 0 else -0.55)) * Basis(Vector3(1, 0, 0), sd * wa2)
					var sz := 1.0 if k == 0 else 0.7
					ell(root + bb * Vector3(-r * 0.1 - k * r * 0.4, 0, r * 0.3) + wb2 * Vector3(0, sd * ws * 0.48 * sz, 0), Vector3(ws * 0.32 * sz, ws * 0.5 * sz, 0.005), wm2, wb2)
			var hc3 := root + bb * Vector3(r * 0.95, 0, r * 0.15)
			ell(hc3, Vector3(r * 0.42, r * 0.5, r * 0.45), fur, bb)
			for sd in [-1.0, 1.0]:
				if q.squint == 0.0:
					eye(hc3 + bb * Vector3(r * 0.25, sd * r * 0.3, r * 0.1), r * 0.2, p.eye, p.eye_glow, bb)
				var an := hc3 + bb * Vector3(r * 0.2, sd * r * 0.15, r * 0.35)
				cap(an, an + bb * Vector3(r * 0.5, sd * r * 0.5, r * 0.8), r * 0.1, r * 0.03, mat(p.wing_bone))

# ---------------------------------------------------------------- serpent

## Legless wyrmkin: snakes slither in S-curves, worms rise from a sand mound.
## Knobs: rise (head height), reach (head forward), jaw, coil (snake pulls
## its neck back into an S), emerge (worm body out of the ground, 0..1).
const SPOSE := {
	"snake": [{"rise": 0.12, "reach": -0.08, "jaw": 0.4, "coil": 1.0},
		{"rise": 0.05, "reach": 0.18, "jaw": 1.0},
		{"rise": 0.06, "reach": 0.06, "jaw": 0.2}],
	"worm": [{"rise": 0.12, "reach": -0.1, "jaw": 0.4, "emerge": 1.1},
		{"rise": -0.05, "reach": 0.16, "jaw": 1.0, "emerge": 1.05},
		{"rise": 0.0, "reach": 0.05, "jaw": 0.3}],
}
const SHURT := {"rise": 0.02, "reach": -0.06, "jaw": 0.5, "squint": 1.0, "coil": 0.5}


func _serpent(p: Dictionary, pose: Dictionary) -> void:
	var body := String(p.body)
	var q := _knobs(SPOSE, SHURT, body, pose, {"rise": 0.0, "reach": 0.0, "jaw": 0.0, "coil": 0.0, "emerge": 1.0, "squint": 0.0})
	var walk: bool = pose.st == "walk"
	var ph: float = pose.ph
	var r: float = p.r
	var hs: float = p.hs
	var skin := mat(p.col, false, p.pat, p.col2, p.pf)
	var belly := mat(p.belly)
	if pose.k == 4 and p.buried:
		_burrow(p, r, hs, skin)
		return
	if body == "snake":
		var L: float = p.length
		var n := 11
		var pts := []
		var rs := []
		var head_x: float = L * 0.4 + q.reach
		for i in n:
			var s := i / float(n - 1)
			var wave := sin(s * TAU * 1.1 - TAU * ph) if walk else sin(s * TAU * 1.1 + 0.6)
			var x := head_x - s * L * (0.9 if q.coil > 0.0 else 1.0)
			var y := wave * L * 0.11 * minf(s * 2.5, 1.0)
			var z := r
			if s < 0.3:
				var u := 1.0 - s / 0.3
				z += (p.rest_rise + q.rise) * u * u
				if q.coil > 0.0:
					x -= q.coil * sin(u * PI) * L * 0.12
					y += q.coil * sin(u * PI) * L * 0.06
			pts.append(Vector3(x, y, z))
			rs.append(r * (1.0 - maxf(s - 0.3, 0.0) * 1.15) * (0.85 if s < 0.08 else 1.0))
		for i in range(n - 1, 0, -1):
			cap(pts[i], pts[i - 1], rs[i], rs[i - 1], skin)
			if i % 2 == 0 and i > 3:
				ell(pts[i] - Vector3(0, 0, rs[i] * 0.45), Vector3(rs[i] * 0.9, rs[i] * 0.8, rs[i] * 0.5), belly)
		var hd = (pts[0] - pts[2]).normalized()
		var hb := Basis(Vector3(0, 0, 1), atan2(hd.y, hd.x)) * rot(-0.25 + q.jaw * 0.25)
		_snake_head(pts[0] + hb * Vector3(hs * 0.5, 0, 0), hb, p, q.jaw, q.squint, skin, walk and fmod(ph, 0.5) < 0.25)
	else:
		# worm: segments from the mound up to a round, toothed maw
		var H: float = p.height * q.emerge
		var sway := sin(TAU * ph) * 0.05 if walk else 0.0
		var base := Vector3(-r * 0.5, 0, 0)
		var head := Vector3(r * 0.6 + q.reach, sway, H + q.rise)
		var n2 := 7
		var pts2 := []
		for i in n2:
			var s := i / float(n2 - 1)
			var arc := sin(s * PI * 0.5)
			pts2.append(Vector3(lerpf(base.x - r * 0.6, head.x, s * s), head.y * s, lerpf(0.0, head.z, arc)))
		ell(Vector3(base.x - r * 0.3, 0, 0), Vector3(r * 2.2, r * 1.8, r * 0.45), mat(p.sand, false, "mottle", Color.BLACK, 6.0))
		for i in range(n2 - 1):
			var rr := r * (1.0 - i * 0.03)
			ball((pts2[i] + pts2[i + 1]) * 0.5, rr, skin)
		if p.fins:
			for i in range(1, n2 - 1):
				var fp: Vector3 = pts2[i]
				cap(fp + Vector3(-r * 0.5, 0, r * 0.4), fp + Vector3(-r * 1.4, 0, r * 0.9), r * 0.3, 0.0, mat(p.fin_col, true))
		var hb2 := rot(-0.35 + q.jaw * 0.2 + (0.4 if pose.k == 1 else 0.0))
		_maw(head, hb2, p, q.jaw, q.squint, skin)
		if p.breath != Color.TRANSPARENT and pose.k == 2:
			for j in 4:
				ball(head + hb2 * Vector3(r * (1.0 + j * 0.9), 0, 0), r * (0.45 + j * 0.25), mat(Color(p.breath).lightened(0.4 - j * 0.12), true))


func _snake_head(h: Vector3, hb: Basis, p: Dictionary, jaw: float, squint: float, skin: Dictionary, tongue: bool) -> void:
	var hs: float = p.hs
	ell(h, Vector3(hs * 1.1, hs * 0.8, hs * 0.5), skin, hb)
	var jb := hb * rot(-jaw * 0.8)
	ell(h + hb * Vector3(-hs * 0.3, 0, -hs * 0.2) + jb * Vector3(hs * 0.65, 0, -hs * 0.05), Vector3(hs * 0.9, hs * 0.62, hs * 0.22), mat(p.belly), jb)
	if jaw > 0.3:
		ell(h + hb * Vector3(hs * 0.25, 0, -hs * 0.25), Vector3(hs * 0.65, hs * 0.5, hs * 0.2), mat(Color8(150, 50, 70)), hb * rot(-jaw * 0.4))
		for sd in [-1.0, 1.0]:
			var f := h + hb * Vector3(hs * 0.7, sd * hs * 0.32, -hs * 0.25)
			cap(f, f + hb * Vector3(0, 0, -hs * 0.5), hs * 0.1, 0.0, mat(Color8(240, 232, 214)))
	elif tongue:
		var t0 := h + hb * Vector3(hs * 1.05, 0, -hs * 0.15)
		cap(t0, t0 + hb * Vector3(hs * 0.5, 0, -hs * 0.05), hs * 0.06, hs * 0.04, mat(Color8(200, 50, 70)))
	for sd in [-1.0, 1.0]:
		var e := h + hb * Vector3(hs * 0.35, sd * hs * 0.55, hs * 0.25)
		if squint > 0.0:
			ell(e, Vector3(hs * 0.12, hs * 0.08, hs * 0.04), mat(p.col2), hb)
		else:
			eye(e, hs * 0.24, p.eye, p.eye_glow, hb)
		ell(h + hb * Vector3(hs * 0.3, sd * hs * 0.5, hs * 0.38), Vector3(hs * 0.3, hs * 0.14, hs * 0.08), skin, hb)
	if p.horns != "":
		for sd in [-1.0, 1.0]:
			var hb0 := h + hb * Vector3(-hs * 0.4, sd * hs * 0.45, hs * 0.3)
			cap(hb0, hb0 + hb * Vector3(-hs * 0.7, sd * hs * 0.3, hs * 0.4), hs * 0.16, 0.0, mat(p.horn_col))


## Round lamprey maw: lip ring, teeth pointing inwards, glowing eyes around.
func _maw(h: Vector3, hb: Basis, p: Dictionary, jaw: float, squint: float, skin: Dictionary) -> void:
	var r: float = p.r * 1.15
	var open := 0.45 + jaw * 0.5
	ell(h, Vector3(r * 0.8, r, r), skin, hb)
	ell(h + hb * Vector3(r * 0.62, 0, 0), Vector3(r * 0.2, r * open, r * open), mat(Color8(70, 24, 34)), hb)
	var tooth := mat(Color8(244, 236, 214))
	for k in 8:
		var a := k * TAU / 8.0
		var o := hb * Vector3(r * 0.7, cos(a) * r * (open + 0.12), sin(a) * r * (open + 0.12))
		cap(h + o, h + o * Vector3(1, 0.55, 0.55) + hb * Vector3(r * 0.25, 0, 0), r * 0.1, 0.0, tooth)
	for k in 4:
		var a2 := k * TAU / 4.0 + PI / 4.0
		var flap := hb * Vector3(r * 0.5, cos(a2) * r * 0.95, sin(a2) * r * 0.95)
		cap(h + flap, h + flap * 1.3 + hb * Vector3(r * (0.5 - jaw * 0.3), cos(a2) * r * jaw * 0.6, sin(a2) * r * jaw * 0.6), r * 0.3, r * 0.08, skin)
	if squint == 0.0:
		for sd in [-1.0, 1.0]:
			eye(h + hb * Vector3(r * 0.3, sd * r * 0.85, r * 0.45), r * 0.14, p.eye, p.eye_glow, hb)


## Hidden ambusher: a snake coiled under leaves or a worm's sand mound.
func _burrow(p: Dictionary, r: float, hs: float, skin: Dictionary) -> void:
	if p.body == "snake":
		for k in 3:
			var rr := r * (2.6 - k * 0.8)
			ell(Vector3(0, 0, r * (0.8 + k * 1.3)), Vector3(rr * 1.4, rr * 1.4, r), skin)
		_snake_head(Vector3(r * 1.2, 0, r * 4.5), rot(-0.2), p, 0.0, 0.0, skin, false)
	else:
		var sm := mat(p.sand, false, "mottle", Color.BLACK, 6.0)
		ell(Vector3(0, 0, 0), Vector3(r * 2.6, r * 2.2, r * 0.9), sm)
		for k in 5:
			var a := k * 1.3
			ball(Vector3(cos(a) * r * 1.8, sin(a) * r * 1.6, r * 0.2), r * 0.35, sm)

# ---------------------------------------------------------------- spirit

## Things that float: storm wisps, hooded wraiths and reapers, fire
## elementals, burning skulls. Knobs: swell (size pulse), rise, shift, lean,
## arms (1 raised / -1 slashed forward), flash (explosion), jaw.
const PPOSE := {
	"explode": [{"swell": 1.25, "rise": -0.02, "jaw": 0.5}, {"swell": 1.5, "flash": 1.0, "jaw": 1.0}, {"swell": 0.75, "rise": 0.03}],
	"blink": [{"arms": 1.0, "rise": 0.05, "lean": -0.2}, {"arms": -1.0, "shift": 0.14, "lean": 0.45, "rise": -0.02, "jaw": 1.0},
		{"arms": -0.3, "shift": 0.06, "lean": 0.15}],
	"hit_run": [{"arms": 1.0, "lean": -0.2, "shift": -0.04, "swell": 1.1}, {"arms": -1.0, "shift": 0.15, "lean": 0.5, "swell": 1.15},
		{"arms": -0.3, "shift": 0.06, "lean": 0.2}],
}
const PHURT := {"lean": -0.3, "shift": -0.05, "swell": 0.9, "squint": 1.0, "arms": 0.4, "jaw": 0.5}


func _spirit(p: Dictionary, pose: Dictionary) -> void:
	var q := _knobs(PPOSE, PHURT, p.atk, pose, {"swell": 1.0, "rise": 0.0, "shift": 0.0, "lean": 0.0, "arms": 0.0,
		"flash": 0.0, "jaw": 0.0, "squint": 0.0})
	var walk: bool = pose.st == "walk"
	var ph: float = pose.ph
	var bob := sin(TAU * ph) * 0.02 if walk else 0.0
	var root := Vector3(q.shift, 0, p.alt + q.rise + bob)
	var r: float = p.r * q.swell
	match String(p.body):
		"wisp":
			var core := mat(p.col, true)
			ball(root, r, mat(p.col2, true))
			ball(root + Vector3(r * 0.15, 0, r * 0.2), r * 0.62, core)
			for k in 6:
				var a = k * TAU / 6.0 + TAU * ph * 0.5 + (q.flash * 0.3)
				var o = Vector3(cos(a), sin(a), sin(a * 2.0) * 0.4) * r * (1.2 + q.flash * 0.3)
				var m2 = o * 0.6 + Vector3(0, 0, r * 0.3 * (1 if k % 2 == 0 else -1))
				chain([root + o * 0.7, root + m2 + o * 0.35, root + o * 1.15], [r * 0.12, r * 0.09, 0.0], core)
			if q.squint == 0.0:
				for sd in [-1.0, 1.0]:
					ell(root + Vector3(r * 0.85, sd * r * 0.28, r * 0.15), Vector3(r * 0.1, r * 0.1, r * 0.2), mat(Color8(30, 40, 80)))
		"wraith":
			var lean := rot(q.lean)
			var cloak := mat(p.col, false, "mottle", p.col2, 5.0)
			var sh := root + lean * Vector3(0, 0, r * 1.6)
			var sway := sin(TAU * ph) * r * 0.25 if walk else 0.0
			chain([sh, root + lean * Vector3(-r * 0.4, sway * 0.5, r * 0.4), root + Vector3(-r * 1.5, sway, -r * 0.7), root + Vector3(-r * 2.4, sway * 1.5, -r * 0.9)],
				[r * 0.95, r * 0.9, r * 0.45, 0.0], cloak)
			for k in 3:
				var tb := root + Vector3(-r * 0.5 - k * r * 0.3, (k - 1) * r * 0.6, -r * 0.2)
				cap(tb, tb + Vector3(-r * 0.6, (k - 1) * r * 0.3 + sway, -r * 0.8), r * 0.3, 0.0, cloak)
			var bone := mat(p.bone)
			var hands := []
			for sd in [1.0, -1.0]:
				var s0 := sh + lean * Vector3(r * 0.2, sd * r * 0.8, 0)
				var tgt := s0 + lean * (Vector3(r * 1.0, sd * r * 0.5, r * 1.2) if q.arms > 0.5 else (Vector3(r * 1.9, sd * r * 0.2, -r * 0.2) if q.arms < -0.5 else Vector3(r * 1.0, sd * r * 0.4, -r * 0.7)))
				var e := limb(s0, tgt, r * 0.9, r * 0.9, Vector3(-1, sd, -0.5), r * 0.32, r * 0.22, r * 0.12, cloak)
				for c in 3:
					cap(e, e + lean * Vector3(r * 0.45, (c - 1) * r * 0.2, -r * 0.2), r * 0.07, 0.0, bone)
				hands.append(e)
			if p.weapon != "":
				var wp: Dictionary = Specs.RIG.biped.duplicate()
				wp.merge({"wsize": p.wsize, "wood": p.wood, "metal": p.metal}, true)
				var wd := Vector3(0.2, 0, 1) if q.arms > -0.5 else Vector3(0.9, 0, -0.45)
				_weapon(p.weapon, hands[0], (lean * wd).normalized(), wp, 1.0, 0.0)
			var hc := sh + lean * Vector3(r * 0.35, 0, r * 0.75)
			ell(hc, Vector3(r * 0.85, r * 0.8, r * 0.85), cloak, lean)
			cap(hc + lean * Vector3(-r * 0.5, 0, r * 0.5), hc + lean * Vector3(-r * 1.0, 0, r * 0.3), r * 0.4, 0.0, cloak)
			ell(hc + lean * Vector3(r * 0.55, 0, -r * 0.05), Vector3(r * 0.35, r * 0.55, r * 0.6), mat(Color8(16, 12, 22)), lean)
			if q.squint == 0.0:
				for sd in [-1.0, 1.0]:
					ball(hc + lean * Vector3(r * 0.8, sd * r * 0.2, r * 0.05), r * 0.11, mat(p.eye, true))
		"flame":
			var lean2 := rot(q.lean)
			var outer := mat(p.col, true)
			var inner := mat(p.col2, true)
			var fl := sin(TAU * ph) * r * 0.15 if walk else 0.0
			cap(root + Vector3(-r * 0.3, 0, -r * 1.2), root + lean2 * Vector3(0, 0, r * 0.4), r * 0.15, r * 0.85, outer)
			ell(root + lean2 * Vector3(0, 0, r * 0.9), Vector3(r * 0.9, r * 1.0, r * 1.0), outer, lean2)
			ell(root + lean2 * Vector3(r * 0.3, 0, r * 0.8), Vector3(r * 0.55, r * 0.6, r * 0.7), inner, lean2)
			for k in 5:
				var tb2 := root + lean2 * Vector3(-r * 0.2 - (k % 2) * r * 0.3, (k - 2) * r * 0.35, r * 1.6)
				cap(tb2, tb2 + lean2 * Vector3(-r * 0.5, (k - 2) * r * 0.1 + fl, r * (0.9 + (k % 3) * 0.3)), r * 0.32, 0.0, outer if k % 2 == 0 else inner)
			for sd in [1.0, -1.0]:
				var s1 := root + lean2 * Vector3(0, sd * r * 0.9, r * 1.1)
				var tg := s1 + lean2 * (Vector3(-r * 0.2, sd * r * 0.5, r * 1.0) if q.arms > 0.5 else (Vector3(r * 1.8, sd * r * 0.2, 0) if q.arms < -0.5 and sd > 0.0 else Vector3(r * 0.6, sd * r * 0.5, -r * 0.6)))
				var e2 := limb(s1, tg, r * 0.75, r * 0.75, Vector3(-1, sd, -0.3), r * 0.35, r * 0.28, r * 0.25, outer)
				ball(e2, r * 0.35, inner)
			if q.squint == 0.0:
				for sd in [-1.0, 1.0]:
					ell(root + lean2 * Vector3(r * 0.85, sd * r * 0.32, r * 1.05), Vector3(r * 0.1, r * 0.13, r * 0.22), mat(Color8(60, 20, 20)), lean2)
			ell(root + lean2 * Vector3(r * 0.85, 0, r * 0.6), Vector3(r * 0.08, r * 0.3, r * (0.06 + q.jaw * 0.12)), mat(Color8(60, 20, 20)), lean2)
		"skull":
			var hp: Dictionary = Specs.RIG.biped.duplicate()
			hp.merge({"head": "skull", "hr": r, "skin": p.bone, "eye": p.eye, "eye_glow": true}, true)
			var fm := mat(p.col, true)
			var fm2 := mat(p.col2, true)
			for k in 5:
				var a := (k - 2) * 0.45
				var tb3 := root + Vector3(-r * 0.4, sin(a) * r * 0.6, r * 0.4 + cos(a) * r * 0.2)
				var tip := tb3 + Vector3(-r * (1.4 + (k % 2) * 0.5 + q.flash * 0.4), sin(a) * r * 0.5 + (sin(TAU * ph + k) * r * 0.2 if walk else 0.0), r * 0.6)
				cap(tb3, tip, r * 0.45, 0.0, fm if k % 2 == 0 else fm2)
			_biped_head(root, rot(-0.1 + q.lean), hp, q.jaw, q.squint, mat(p.bone))
			if q.flash > 0.0:
				ball(root + Vector3(r * 0.2, 0, 0), r * 0.9, fm2)

# ---------------------------------------------------------------- fungus

## Capfolk: a stem with a face under a domed cap; walkers waddle on stubby
## feet. Knobs: swell, squash (cap pressed down), hop, roll, spores (cloud
## burst), shift, arms.
const GPOSE := {
	"explode": [{"swell": 1.2, "squash": 0.3, "roll": 0.0}, {"swell": 1.4, "spores": 1.0, "hop": 0.04}, {"swell": 0.85, "squash": 0.4}],
	"ranged": [{"squash": 0.45, "swell": 1.05}, {"hop": 0.03, "spores": 0.7, "swell": 1.1, "shift": 0.02}, {"squash": 0.15}],
}
const GHURT := {"roll": -0.3, "squash": 0.2, "squint": 1.0, "shift": -0.04}


func _fungus(p: Dictionary, pose: Dictionary) -> void:
	var q := _knobs(GPOSE, GHURT, p.atk, pose, {"swell": 1.0, "squash": 0.0, "hop": 0.0, "roll": 0.0, "spores": 0.0, "shift": 0.0, "squint": 0.0})
	var walk: bool = pose.st == "walk" and p.walker
	var ph: float = pose.ph
	var hop := absf(sin(TAU * ph)) * 0.04 if walk else 0.0
	var sway := sin(TAU * ph) * 0.18 if walk else (sin(TAU * ph) * 0.06 if pose.st == "walk" else 0.0)
	var sw: float = q.swell
	var sr: float = p.stem_r * sw
	var sh: float = p.stem_h * (1.0 - q.squash * 0.35)
	var base := Vector3(q.shift, 0, p.lift + hop + q.hop)
	var b := rot(q.roll * 0.5, 0.0, sway)
	var stem := mat(p.stem)
	if p.walker:
		for sd in [-1.0, 1.0]:
			var lp := sin(TAU * ph + (0.0 if sd > 0.0 else PI)) if walk else 0.0
			var f := Vector3(base.x + lp * 0.05, sd * sr * 0.6, sr * 0.3 + maxf(lp, 0.0) * 0.03)
			cap(base + b * Vector3(0, sd * sr * 0.5, sr * 0.3), f, sr * 0.38, sr * 0.34, stem)
			ell(f + Vector3(sr * 0.25, 0, -sr * 0.1), Vector3(sr * 0.55, sr * 0.38, sr * 0.28), mat(p.foot))
	var top := base + b * Vector3(0, 0, sh)
	cap(base + b * Vector3(0, 0, sr * 0.4), top, sr, sr * 0.82, stem)
	ell(base + b * Vector3(0, 0, sr * 0.6), Vector3(sr * 1.15, sr * 1.15, sr * 0.75), stem, b)
	if p.stick:
		var hand := base + b * Vector3(sr * 0.7, sr * 1.1, sh * 0.55)
		cap(base + b * Vector3(0, sr * 0.8, sh * 0.6), hand, sr * 0.16, sr * 0.14, stem)
		cap(hand + Vector3(0, 0, sh * 0.3), Vector3(hand.x + 0.02, hand.y, 0.0), sr * 0.12, sr * 0.1, mat(Color8(110, 80, 54)))
	# face on the stem
	var fc := base + b * Vector3(sr * 0.85, 0, sh * 0.55)
	for sd in [-1.0, 1.0]:
		var e := fc + b * Vector3(0, sd * sr * 0.38, sr * 0.15)
		if q.squint > 0.0:
			ell(e, Vector3(sr * 0.05, sr * 0.17, sr * 0.04), mat(Color8(30, 22, 30)), b)
		else:
			eye(e, sr * float(p.eye_r), p.eye, p.eye_glow, b)
	ell(fc + b * Vector3(sr * 0.05, 0, -sr * 0.3), Vector3(sr * 0.08, sr * 0.22, sr * (0.05 + q.spores * 0.15 + q.squash * 0.08)), mat(Color8(70, 30, 40)), b)
	# cap
	var cr: float = p.cap_r * sw * (1.0 + q.squash * 0.18)
	var ch: float = p.cap_h * sw * (1.0 - q.squash * 0.4)
	var ct := top + b * Vector3(0, 0, ch * 0.15)
	ell(ct - b * Vector3(0, 0, ch * 0.15), Vector3(cr * 0.92, cr * 0.92, ch * 0.3), mat(p.gills, false, "band", Color(p.gills).darkened(0.2), 14.0), b)
	ell(ct + b * Vector3(0, 0, ch * 0.25), Vector3(cr, cr, ch), mat(p.cap, p.cap_glow, "spots", p.dots, p.pf), b)
	if q.spores > 0.0:
		var sm := mat(p.spore)
		for k in 9:
			var a := k * 2.39996
			var d = Vector3(cos(a) * 0.8 + 0.6, sin(a), 0.4 + fposmod(k * 0.37, 1.0) * 0.6) * cr * (0.85 + q.spores * 0.35)
			ball(ct + d, cr * (0.18 + fposmod(k * 0.53, 1.0) * 0.16) * q.spores, sm)
