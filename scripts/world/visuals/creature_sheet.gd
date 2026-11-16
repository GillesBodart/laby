class_name CreatureSheet
extends RefCounted
## Layout and animation rules of creature pose sheets (drawn by
## tools/creature_art.gd, played by Enemy and Companion).
##
## A sheet holds 9 columns x 3 rows of square cells:
##   columns  0 idle, 1-4 walk (contact, passing, contact, passing),
##            5 windup, 6 strike, 7 recover, 8 hurt (ambushers: buried)
##   rows     0 facing down, 1 facing up, 2 side (facing right; flip for left)
## The creature stands on a ground line ground_for(cell) px above the cell's
## bottom.
## An instance tracks which row a creature shows, with hysteresis so it does
## not flicker between rows when walking diagonally.

const COLS := 9
const ROWS := 3
const IDLE := 0
const WALK := 1
const WINDUP := 5
const STRIKE := 6
const RECOVER := 7
const HURT := 8
const DOWN := 0
const UP := 1
const SIDE := 2
const RIGS := ["quadruped", "crawler", "flyer", "serpent", "biped", "spirit", "fungus"]
## Distance covered per step (half a walk cycle) as a fraction of the size.
const STRIDE := {"quadruped": 0.32, "crawler": 0.2, "flyer": 0.3, "serpent": 0.34, "biped": 0.26,
	"spirit": 0.3, "fungus": 0.4}
## Body height (ground to top of head) as a fraction of the size, for bars
## and floating numbers.
const HEIGHT := {"quadruped": 0.8, "crawler": 0.55, "flyer": 1.05, "serpent": 0.65, "biped": 1.0,
	"spirit": 1.1, "fungus": 0.95}
## Wing beats / robe ripples of airborne rigs, frames per second.
const FLAP_FPS := 11.0
## A diagonal heading must lean this much towards the other axis to turn.
const TURN_RATIO := 1.3

var row := SIDE
var flip := false
## Minimum time between two row changes (big creatures turn slower).
var hold_time := 0.18
var _hold := 0.0


## Square cell side for a creature `size` px long (with room for its swing).
static func cell_for(size: int) -> int:
	var c := ceili(size * 1.4)
	return c + c % 2 + 4


## Height of the ground line above the bottom of a `cell` px cell: the body
## of a creature facing the camera reaches below its feet point.
static func ground_for(cell: int) -> int:
	return int(cell * 0.2) + 2


static func frame_size(tex: Texture2D) -> Vector2i:
	return Vector2i(tex.get_width() / COLS, tex.get_height() / ROWS)


static func airborne(rig: String) -> bool:
	return rig == "flyer" or rig == "spirit"


static func stride_for(rig: String, size: int) -> float:
	return maxf(float(STRIDE.get(rig, 0.3)) * size, 4.0)


static func height_for(rig: String, size: int) -> float:
	return float(HEIGHT.get(rig, 0.9)) * size


## Column for a pose: "idle", "walk", "windup", "strike", "recover", "hurt",
## "hidden". `steps` is Gait.steps; airborne rigs flap on `time` instead.
static func column(pose: String, steps: float, time: float, is_airborne := false) -> int:
	match pose:
		"windup":
			return WINDUP
		"strike":
			return STRIKE
		"recover":
			return RECOVER
		"hurt", "hidden":
			return HURT
		"walk":
			if is_airborne:
				return WALK + int(fposmod(time * FLAP_FPS, 4.0))
			return WALK + int(fposmod(steps * 2.0 + 0.5, 4.0))
	if is_airborne:
		return WALK + int(fposmod(time * FLAP_FPS * 0.6, 4.0))
	return IDLE


static func frame(r: int, col: int) -> int:
	return r * COLS + col


## Turns towards `dir` (no-op when zero). `force` skips the hold and the
## hysteresis: used to lock the aim when an attack winds up.
func face(dir: Vector2, delta: float, force := false) -> void:
	_hold = maxf(_hold - delta, 0.0)
	if dir.length_squared() < 0.0001:
		return
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var want := SIDE if ax >= ay else (DOWN if dir.y > 0.0 else UP)
	if want != row and not force:
		var leaning := ay > ax * TURN_RATIO if row == SIDE else (ax > ay * TURN_RATIO if want == SIDE else true)
		if _hold > 0.0 or not leaning:
			want = row
	if want != row:
		row = want
		_hold = hold_time
	if row == SIDE and ax > 0.05:
		flip = dir.x < 0.0


## Sets up `sprite` for a sheet of creature `id`: frames, feet on the origin.
## Returns the cell size.
static func setup_sprite(sprite: Sprite2D, id: String) -> int:
	sprite.texture = load(EnemyCatalog.sprite_path(id))
	sprite.hframes = COLS
	sprite.vframes = ROWS
	var cell := frame_size(sprite.texture).y
	sprite.position.y = ground_for(cell) - cell / 2.0
	return cell
