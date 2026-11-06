class_name TileCatalog
extends RefCounted
## Single source of truth for tiles of the Clearing/Stone tileset:
## atlas coordinates and collision. Used by the art generator, the
## TileSet factory and the world generator.

const TEXTURE_PATH := "res://assets/tilesets/clearing_tiles.png"
const TILE_SIZE := 16
const ATLAS_COLUMNS := 8
const ATLAS_ROWS := 2

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
}

const DEFS := {
	Id.GRASS: {"atlas": Vector2i(0, 0), "solid": false},
	Id.GRASS_ALT: {"atlas": Vector2i(1, 0), "solid": false},
	Id.GRASS_FLOWERS: {"atlas": Vector2i(2, 0), "solid": false},
	Id.DIRT: {"atlas": Vector2i(3, 0), "solid": false},
	Id.MAZE_FLOOR: {"atlas": Vector2i(4, 0), "solid": false},
	Id.MAZE_FLOOR_MOSS: {"atlas": Vector2i(5, 0), "solid": false},
	Id.VOID: {"atlas": Vector2i(6, 0), "solid": true},
	Id.GATE_FLOOR: {"atlas": Vector2i(7, 0), "solid": false},
	Id.WALL_TOP: {"atlas": Vector2i(0, 1), "solid": true},
	Id.WALL_TOP_MOSS: {"atlas": Vector2i(1, 1), "solid": true},
	Id.WALL_FACE_HIGH: {"atlas": Vector2i(2, 1), "solid": true},
	Id.WALL_FACE_HIGH_VINES: {"atlas": Vector2i(3, 1), "solid": true},
	Id.WALL_FACE_LOW: {"atlas": Vector2i(4, 1), "solid": true},
	Id.WALL_FACE_LOW_VINES: {"atlas": Vector2i(5, 1), "solid": true},
	Id.GATE_CLOSED: {"atlas": Vector2i(6, 1), "solid": true},
}


static func atlas_coords(id: int) -> Vector2i:
	return DEFS[id]["atlas"]


static func is_solid(id: int) -> bool:
	return DEFS[id]["solid"]
