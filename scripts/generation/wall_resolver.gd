class_name WallResolver
extends RefCounted
## Picks the wall tile (top / face / vines) of every solid cell so walls look
## right from the top-down camera. Shared by all generators.
## `vines` / `top_alt` are the decoration shares (see Sectors art); one draw is
## made per cell whatever they are, so they never change the rng sequence.

const Id := TileCatalog.Id


static func resolve(layout: ClearingLayout, solid: Dictionary, rng: RandomNumberGenerator, vines := 0.25, top_alt := 0.2) -> void:
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			if not solid.has(cell):
				continue
			var id: int
			if not _is_solid(layout, solid, cell + Vector2i.DOWN):
				id = Id.WALL_FACE_LOW_VINES if rng.randf() < vines else Id.WALL_FACE_LOW
			elif not _is_solid(layout, solid, cell + Vector2i(0, 2)):
				id = Id.WALL_FACE_HIGH_VINES if rng.randf() < vines else Id.WALL_FACE_HIGH
			else:
				id = Id.WALL_TOP_MOSS if rng.randf() < top_alt else Id.WALL_TOP
			layout.set_wall(cell, id)


static func _is_solid(layout: ClearingLayout, solid: Dictionary, cell: Vector2i) -> bool:
	return not layout.in_bounds(cell) or solid.has(cell)
