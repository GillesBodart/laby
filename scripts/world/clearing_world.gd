class_name ClearingWorld
extends Node2D
## Renders a ClearingLayout: fills the tile layers and spawns props.

const PROP_SCENES := {
	"tree": preload("res://scenes/world/props/tree.tscn"),
	"rock": preload("res://scenes/world/props/rock.tscn"),
	"campfire": preload("res://scenes/world/props/campfire.tscn"),
}

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var entities: Node2D = $Entities
@onready var gates: ClearingGates = $Gates

var layout: ClearingLayout
var depleted_cells: Array[Vector2i] = []


func _ready() -> void:
	add_to_group("persist")


func build(new_layout: ClearingLayout) -> void:
	layout = new_layout
	depleted_cells.clear()
	var tile_set := TileSetFactory.clearing_tileset()
	ground.tile_set = tile_set
	walls.tile_set = tile_set
	ground.clear()
	walls.clear()
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_coords(layout.get_ground(cell)))
			if layout.is_wall(cell):
				walls.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_coords(layout.get_wall(cell)))
	for prop in layout.props:
		var node: Node2D = PROP_SCENES[prop.type].instantiate()
		node.position = cell_to_feet(prop.cell)
		if node is Gatherable:
			node.cell = prop.cell
			node.depleted.connect(_on_depleted)
		entities.add_child(node)
	gates.setup(walls, layout.gates)


func _on_depleted(g: Gatherable) -> void:
	depleted_cells.append(g.cell)


func get_save_key() -> String:
	return "clearing"


func get_save_data() -> Dictionary:
	return {"depleted": depleted_cells.map(func(c: Vector2i) -> Array: return [c.x, c.y])}


func load_save_data(data: Dictionary) -> void:
	var gone := {}
	for c in data.get("depleted", []):
		gone[Vector2i(int(c[0]), int(c[1]))] = true
	for node in get_tree().get_nodes_in_group("gatherable"):
		if node is Gatherable and gone.has(node.cell):
			node.free()
	depleted_cells.clear()
	for c in gone:
		depleted_cells.append(c)


func pixel_size() -> Vector2i:
	return layout.size * TileCatalog.TILE_SIZE


## World position of the bottom-center "feet" point of a cell (y-sort anchor).
static func cell_to_feet(cell: Vector2i) -> Vector2:
	var t := TileCatalog.TILE_SIZE
	return Vector2(cell.x * t + t / 2.0, cell.y * t + t - 2.0)


static func cell_center(cell: Vector2i) -> Vector2:
	var t := TileCatalog.TILE_SIZE
	return Vector2(cell.x * t + t / 2.0, cell.y * t + t / 2.0)
