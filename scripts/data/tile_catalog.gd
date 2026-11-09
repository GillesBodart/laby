class_name TileCatalog
extends RefCounted
## Single source of truth for tiles of the Clearing/Stone tileset:
## atlas coordinates and collision. Used by the art generator, the
## TileSet factory and the world generator.

const TEXTURE_PATH := "res://assets/tilesets/clearing_tiles.png"
const TILE_SIZE := 32
const ATLAS_COLUMNS := 8
## Grass and wall tops are painted as large seamless 8x8-tile textures (one per id)
## so they do not repeat every tile; cells pick their piece by position.
const MACRO := 8
const ATLAS_ROWS := 2 + 5 * MACRO

enum Id {
	GRASS,
	GRASS_ALT,
	GRASS_FLOWERS,
	DIRT,
	MAZE_FLOOR,
	MAZE_FLOOR_MOSS,
	VOID,
	GATE_FLOOR,
	WALL_TOP,
	WALL_TOP_MOSS,
	WALL_FACE_HIGH,
	WALL_FACE_HIGH_VINES,
	WALL_FACE_LOW,
	WALL_FACE_LOW_VINES,
	GATE_CLOSED,
	## Pond water: blocks movement; drawn by the pond overlay over grass.
	WATER,
}

const DEFS := {
	Id.GRASS: {"atlas": Vector2i(0, 0), "solid": false, "macro": Vector2i(0, 2)},
	Id.GRASS_ALT: {"atlas": Vector2i(1, 0), "solid": false, "macro": Vector2i(0, 2 + MACRO)},
	Id.GRASS_FLOWERS: {"atlas": Vector2i(2, 0), "solid": false, "macro": Vector2i(0, 2 + 2 * MACRO)},
	Id.DIRT: {"atlas": Vector2i(3, 0), "solid": false},
	Id.MAZE_FLOOR: {"atlas": Vector2i(4, 0), "solid": false},
	Id.MAZE_FLOOR_MOSS: {"atlas": Vector2i(5, 0), "solid": false},
	Id.VOID: {"atlas": Vector2i(6, 0), "solid": true},
	Id.GATE_FLOOR: {"atlas": Vector2i(7, 0), "solid": false},
	Id.WALL_TOP: {"atlas": Vector2i(0, 1), "solid": true, "macro": Vector2i(0, 2 + 3 * MACRO)},
	Id.WALL_TOP_MOSS: {"atlas": Vector2i(1, 1), "solid": true, "macro": Vector2i(0, 2 + 4 * MACRO)},
	Id.WALL_FACE_HIGH: {"atlas": Vector2i(2, 1), "solid": true},
	Id.WALL_FACE_HIGH_VINES: {"atlas": Vector2i(3, 1), "solid": true},
	Id.WALL_FACE_LOW: {"atlas": Vector2i(4, 1), "solid": true},
	Id.WALL_FACE_LOW_VINES: {"atlas": Vector2i(5, 1), "solid": true},
	Id.GATE_CLOSED: {"atlas": Vector2i(6, 1), "solid": true},
	Id.WATER: {"atlas": Vector2i(7, 1), "solid": true},
}


static func atlas_coords(id: int) -> Vector2i:
	return DEFS[id]["atlas"]


static func is_solid(id: int) -> bool:
	return DEFS[id]["solid"]


## Atlas tile drawn for an id at a cell (grass and wall tops pick their piece of the macro texture).
static func atlas_for(id: int, cell: Vector2i) -> Vector2i:
	var def: Dictionary = DEFS[id]
	if def.has("macro"):
		return def.macro + Vector2i(posmod(cell.x, MACRO), posmod(cell.y, MACRO))
	return def.atlas


## Every atlas tile used by an id (one, or MACRO x MACRO for grass).
static func all_atlas_coords(id: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [DEFS[id].atlas]
	if DEFS[id].has("macro"):
		for y in MACRO:
			for x in MACRO:
				out.append(DEFS[id].macro + Vector2i(x, y))
	return out
