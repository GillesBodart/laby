class_name Roof
extends Node2D
## Roof over one closed room (Rooms.find): drawn over the room and its walls,
## lifted a little so the front wall still shows below the eave. It y-sorts
## with the south wall, and fades out while the local player is under it or
## building, so the inside stays visible.

const SHEET := preload("res://assets/sprites/structures/roof.png")
const LIFT := 22
const FADE_SPEED := 5.0
const VARIANTS := 3
const BOARD := [Color8(80, 54, 38), Color8(120, 82, 50), Color8(160, 114, 68)]
enum Tile { BACK, RIDGE, FRONT, EAVE }

## Cells the roof covers (room + enclosing walls) and the room's own cells.
var cells := {}
var room_cells := {}
var _top := 0
var _ridge := 0


static func create(room: Array, structures: Dictionary) -> Roof:
	var r := Roof.new()
	r.add_to_group("roofs")
	for c in room:
		r.room_cells[c] = true
		r.cells[c] = true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if Rooms.encloses(String(structures.get(n, {}).get("type", ""))):
					r.cells[n] = true
	var top: int = r.cells.keys().map(func(c): return c.y).min()
	var bottom: int = r.cells.keys().map(func(c): return c.y).max()
	r._top = top
	var rows := bottom - top + 1
	r._ridge = top + (maxi(1, rows / 3) if rows >= 3 else 0)
	var t := TileCatalog.TILE_SIZE
	r.position = Vector2(0, bottom * t + t / 2 + 1)
	return r


func covers(cell: Vector2i) -> bool:
	return cells.has(cell)


func _tile(c: Vector2i) -> int:
	if not cells.has(c + Vector2i.DOWN):
		return Tile.EAVE
	if c.y < _ridge:
		return Tile.BACK
	return Tile.RIDGE if c.y == _ridge else Tile.FRONT


func _draw() -> void:
	var t := TileCatalog.TILE_SIZE
	var ink := Color8(24, 22, 32)
	for c in cells:
		var o := Vector2(c.x * t, c.y * t - LIFT - position.y)
		draw_texture_rect_region(SHEET, Rect2(o, Vector2(t, t)), Rect2(_tile(c) * t, posmod(c.x * 7 + c.y * 13, VARIANTS) * t, t, t))
		if not cells.has(c + Vector2i.UP):
			draw_rect(Rect2(o, Vector2(t, 1)), ink)
			draw_rect(Rect2(o + Vector2(0, 1), Vector2(t, 1)), Color(1, 0.86, 0.66, 0.35))
		# Barge boards along the gable ends: lit on the left, shaded on the right.
		if not cells.has(c + Vector2i.LEFT):
			draw_rect(Rect2(o, Vector2(4, t)), BOARD[1])
			draw_rect(Rect2(o + Vector2(1, 0), Vector2(1, t)), BOARD[2])
			draw_rect(Rect2(o, Vector2(1, t)), ink)
			draw_rect(Rect2(o + Vector2(4, 0), Vector2(1, t)), Color(0, 0, 0, 0.3))
		if not cells.has(c + Vector2i.RIGHT):
			draw_rect(Rect2(o + Vector2(t - 4, 0), Vector2(4, t)), BOARD[0])
			draw_rect(Rect2(o + Vector2(t - 4, 0), Vector2(1, t)), BOARD[1])
			draw_rect(Rect2(o + Vector2(t - 1, 0), Vector2(1, t)), ink)
		if not cells.has(c + Vector2i.DOWN):
			# The eave's shadow on the wall face below it.
			draw_rect(Rect2(o + Vector2(0, t), Vector2(t, 3)), Color(0.02, 0.02, 0.06, 0.32))
			draw_rect(Rect2(o + Vector2(0, t + 3), Vector2(t, 2)), Color(0.02, 0.02, 0.06, 0.14))


func _process(delta: float) -> void:
	var target := 0.0 if _hidden() else 1.0
	modulate.a = move_toward(modulate.a, target, delta * FADE_SPEED)


## True while the local player stands under the roof or is building.
func _hidden() -> bool:
	var p: Player = GameState.players.get(GameState.local_peer_id())
	if p == null or not is_instance_valid(p):
		return false
	for child in p.get_children():
		if child is Builder and child.active:
			return true
	var local: Vector2 = (get_parent() as Node2D).to_local(p.global_position)
	var cell := Vector2i((local / TileCatalog.TILE_SIZE).floor())
	return cells.has(cell)
