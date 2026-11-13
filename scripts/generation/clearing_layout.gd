class_name ClearingLayout
extends RefCounted
## Pure data result of ClearingGenerator: tile ids per cell, gates, props.
## Rendering (ClearingWorld) and tests consume this; it holds no nodes.

const NO_TILE := -1

var size: Vector2i
var clearing_rect: Rect2i
var ground: PackedInt32Array
var walls: PackedInt32Array
## Array of {"side": String, "cells": Array[Vector2i]} - the door line of each gate.
var gates: Array[Dictionary] = []
## Array of {"type": String, "cell": Vector2i}.
var props: Array[Dictionary] = []
## Array of {"type": String (EnemyCatalog id), "cell": Vector2i}.
var enemy_spawns: Array[Dictionary] = []
## Array of {"blobs": [{c, r}] (cells, see Pond), "seed": int}; their cells are WATER.
var ponds: Array[Dictionary] = []
var spawn_cell: Vector2i
var campfire_cell: Vector2i
## Area transition: entering portal_rect (cells) travels to portal_target;
## arriving from the other area places the player on return_cell.
var portal_rect: Rect2i
var portal_target := ""
var return_cell: Vector2i
## Several exits (sectors): [{"rect": Rect2i, "target": String}]; when empty
## the single portal_rect/portal_target pair is used.
var portals: Array = []
## Arrival cell by the area the players come from (falls back to return_cell).
var arrivals: Dictionary = {}
## Sealed gate before the north exit: {"rect": Rect2i, "keys": Array[String]}.
var sector_gate: Dictionary = {}
## Guardian of a sector: {"type": String, "cell": Vector2i}, in arena_rect.
var boss: Dictionary = {}
var arena_rect: Rect2i
## Whether the player may build here (only the Clearing).
var buildable := false
## Fixed landmarks of a sector (never shift): [{"type": String, "cell": Vector2i}].
var landmarks: Array = []
## Glyph stones: [{"glyph": String, "cell": Vector2i}].
var glyphs: Array = []
## Treasure chests: [{"id": String, "cell": Vector2i}] (see Blueprints).
var chests: Array = []
## Rare deposits at the back of dead ends (prop cells, see the "hoard" glyph).
var caches: Array = []
## Floor hazards: [{"type": String, "rect": Rect2i}] (see MagmaVent).
var hazards: Array = []
## Tile rects of the maze regions that moved at the current shift.
var shift_tiles: Array = []
## Whether unexplored cells are hidden on the map (the Labyrinth).
var fogged := false


func _init(map_size: Vector2i) -> void:
	size = map_size
	ground = PackedInt32Array()
	ground.resize(size.x * size.y)
	walls = PackedInt32Array()
	walls.resize(size.x * size.y)
	walls.fill(NO_TILE)


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func get_ground(cell: Vector2i) -> int:
	return ground[index(cell)]


func set_ground(cell: Vector2i, id: int) -> void:
	ground[index(cell)] = id


func get_wall(cell: Vector2i) -> int:
	return walls[index(cell)] if in_bounds(cell) else TileCatalog.Id.WALL_TOP


func set_wall(cell: Vector2i, id: int) -> void:
	walls[index(cell)] = id


func is_wall(cell: Vector2i) -> bool:
	return get_wall(cell) != NO_TILE


func all_portals() -> Array:
	if not portals.is_empty():
		return portals
	if portal_target == "":
		return []
	return [{"rect": portal_rect, "target": portal_target}]


func gate_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for gate in gates:
		cells.append_array(gate.cells)
	return cells


func prop_cells() -> Dictionary:
	var cells := {}
	for prop in props:
		cells[prop.cell] = prop.type
	return cells


## Walkable with gates open and props treated as obstacles.
func is_walkable(cell: Vector2i, blocked: Dictionary = {}) -> bool:
	return in_bounds(cell) and not is_wall(cell) and not blocked.has(cell) \
		and get_ground(cell) != TileCatalog.Id.WATER
