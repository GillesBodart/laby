class_name ClearingWorld
extends Node2D
## Renders a ClearingLayout: fills the tile layers and spawns props.

const PROP_SCENES := {
	"tree": preload("res://scenes/world/props/tree.tscn"),
	"rock": preload("res://scenes/world/props/rock.tscn"),
	"bush": preload("res://scenes/world/props/bush.tscn"),
	"campfire": preload("res://scenes/world/props/campfire.tscn"),
}

const RESOURCE_SCENE := preload("res://scenes/world/props/resource_node.tscn")
const ENEMY_SCENE := preload("res://scenes/world/props/enemy.tscn")
const VARIANT_COUNT := 10
## type -> Array[Texture2D], filled in _ready from assets/sprites/<type>s/.
var _prop_variants := {}

@onready var ground: TileMapLayer = $Ground
@onready var walls: TileMapLayer = $Walls
@onready var entities: Node2D = $Entities
@onready var gates: ClearingGates = $Gates

var layout: ClearingLayout
var _structure_nodes := {} # cell -> Structure
var _floors: Node2D


func _ready() -> void:
	add_to_group("persist")
	add_to_group("clearing_world")
	# Floors draw above the ground but below every entity.
	_floors = Node2D.new()
	_floors.name = "Floors"
	add_child(_floors)
	move_child(_floors, entities.get_index())
	for type in ["tree", "rock"]:
		var list: Array[Texture2D] = []
		for i in VARIANT_COUNT:
			list.append(load("res://assets/sprites/%ss/%s_%d.png" % [type, type, i]))
		_prop_variants[type] = list


func build(new_layout: ClearingLayout) -> void:
	layout = new_layout
	var tile_set := TileSetFactory.clearing_tileset()
	ground.tile_set = tile_set
	walls.tile_set = tile_set
	ground.clear()
	walls.clear()
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			var id := layout.get_ground(cell)
			if id == TileCatalog.Id.DIRT:
				# The dirt overlay paints soft borders over grass.
				ground.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_for(TileCatalog.Id.GRASS, cell))
				continue
			if id == TileCatalog.Id.WATER:
				# Grass underneath; the pond overlay paints the water, an invisible
				# solid tile on the wall layer stops walkers.
				ground.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_for(TileCatalog.Id.GRASS, cell))
				walls.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_coords(id))
				continue
			ground.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_for(id, cell))
			if layout.is_wall(cell):
				walls.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_coords(layout.get_wall(cell)))
	_build_dirt()
	_build_ponds()
	for prop in layout.props:
		# Only the Clearing remembers harvested props; the Labyrinth regrows them.
		if layout.buildable and GameState.depleted_cells.has(prop.cell):
			continue
		var node: Node2D = _make_prop(prop.type)
		node.position = cell_to_feet(prop.cell)
		_apply_variant(node, prop)
		if node is Gatherable:
			node.cell = prop.cell
			node.depleted.connect(_on_depleted)
		# Flat patches (clay, sand...) lie on the ground under every walker.
		(_floors if ResourceCatalog.is_flat(prop.type) else entities).add_child(node)
	for spawn in layout.enemy_spawns:
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		enemy.setup(spawn.type)
		enemy.position = cell_center(spawn.cell) + Vector2(0, 12)
		entities.add_child(enemy)
	gates.setup(walls, layout.gates)
	_spawn_structures()
	for entry in GameState.remains:
		if entry.area == GameState.area:
			spawn_remains(entry)


## Shows a GameState.remains entry; piles buried by moved walls are pushed
## to the nearest open cell.
func spawn_remains(entry: Dictionary) -> Remains:
	var cell := walls.local_to_map(Vector2(entry.pos[0], entry.pos[1]))
	if layout.is_wall(cell) or layout.get_ground(cell) == TileCatalog.Id.WATER:
		cell = nearest_open_cell(cell)
		var p := cell_to_feet(cell)
		entry.pos = [p.x, p.y]
	var r := Remains.create(entry)
	entities.add_child(r)
	return r


## Closest walkable cell to `from` (spiral search).
func nearest_open_cell(from: Vector2i) -> Vector2i:
	for radius in range(1, 40):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := from + Vector2i(dx, dy)
				if c.x < 0 or c.y < 0 or c.x >= layout.size.x or c.y >= layout.size.y:
					continue
				if not layout.is_wall(c) and layout.get_ground(c) != TileCatalog.Id.WATER and layout.get_ground(c) != TileCatalog.Id.VOID:
					return c
	return from


func _build_dirt() -> void:
	for node in get_tree().get_nodes_in_group("dirt_overlay"):
		node.free()
	for chunk in DirtOverlay.build(layout, TileCatalog.TILE_SIZE, GameState.world_seed):
		var sprite := Sprite2D.new()
		sprite.add_to_group("dirt_overlay")
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(chunk.image)
		sprite.position = chunk.pos
		_floors.add_child(sprite)
		_floors.move_child(sprite, 0)


func _build_ponds() -> void:
	for node in get_tree().get_nodes_in_group("ponds"):
		node.free()
	var tile := TileCatalog.TILE_SIZE
	for pond in layout.ponds:
		var sprite := Sprite2D.new()
		sprite.add_to_group("ponds")
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(Pond.paint(pond.blobs, tile, pond.seed))
		sprite.position = Pond.bounds(pond.blobs).position * tile
		_floors.add_child(sprite)
		_floors.move_child(sprite, 0)


func _make_prop(type: String) -> Node2D:
	if not ResourceCatalog.has(type):
		return PROP_SCENES[type].instantiate()
	var node: Gatherable = RESOURCE_SCENE.instantiate()
	ResourceCatalog.apply(node, type)
	node.get_node("Sprite").texture = load(ResourceCatalog.texture_path(type))
	if not ResourceCatalog.NODES[type].get("walkable", false):
		return node
	node.get_node("Collision").free()
	return node


func _apply_variant(node: Node2D, prop: Dictionary) -> void:
	var textures: Array = _prop_variants.get(prop.type, [])
	var sprite := node.get_node_or_null("Sprite") as Sprite2D
	if sprite and not textures.is_empty():
		sprite.texture = textures[int(prop.get("variant", 0)) % textures.size()]


func _on_depleted(g: Gatherable) -> void:
	if layout.buildable:
		GameState.depleted_cells[g.cell] = true


# ------------------------------------------------------------ structures

func _spawn_structures() -> void:
	for node in get_tree().get_nodes_in_group("structures"):
		node.free()
	_structure_nodes.clear()
	if not layout.buildable:
		return
	for cell in GameState.structures:
		var d: Dictionary = GameState.structures[cell]
		_add_structure_node(cell, d.type, d.open)


func _add_structure_node(cell: Vector2i, type: String, open: bool) -> void:
	var s := Structure.create(type, cell, open)
	var parent := _floors if BuildCatalog.TYPES[type].layer == "floor" else entities
	parent.add_child(s)
	_structure_nodes[cell] = s


func structure_at(cell: Vector2i) -> Structure:
	return _structure_nodes.get(cell)


## Why a structure cannot be placed at the cell ("" if it can).
func build_blocker(cell: Vector2i, type: String) -> String:
	if not layout.buildable or not layout.clearing_rect.has_point(cell):
		return "Can only build inside the Clearing"
	if GameState.structures.has(cell) or layout.is_wall(cell):
		return "Occupied"
	if layout.get_ground(cell) == TileCatalog.Id.WATER:
		return "Cannot build on water"
	if cell == layout.campfire_cell:
		return "Occupied"
	for prop in layout.props:
		if prop.cell == cell and not GameState.depleted_cells.has(cell):
			return "Blocked by %s" % prop.type
	if BuildCatalog.TYPES[type].solid:
		for player in GameState.players.values():
			if walls.local_to_map(walls.to_local(player.global_position)) == cell:
				return "Someone is standing there"
	return ""


func place_structure(cell: Vector2i, type: String) -> bool:
	if build_blocker(cell, type) != "":
		return false
	GameState.structures[cell] = {"type": type, "open": false, "planted": Farming.NOT_PLANTED}
	_add_structure_node(cell, type, false)
	return true


## Removes the structure and returns its type ("" if none).
func remove_structure(cell: Vector2i) -> String:
	if not GameState.structures.has(cell):
		return ""
	var type: String = GameState.structures[cell].type
	GameState.structures.erase(cell)
	if _structure_nodes.has(cell):
		_structure_nodes[cell].queue_free()
		_structure_nodes.erase(cell)
	return type


func toggle_structure(cell: Vector2i) -> void:
	var s := structure_at(cell)
	if s and BuildCatalog.TYPES[s.type].get("door", false):
		s.toggle()
		GameState.structures[cell].open = s.is_open


func get_save_key() -> String:
	return "clearing"


func get_save_data() -> Dictionary:
	var cells: Array = []
	for c in GameState.depleted_cells:
		cells.append([c.x, c.y])
	var built: Array = []
	for c in GameState.structures:
		var d: Dictionary = GameState.structures[c]
		built.append({"cell": [c.x, c.y], "type": d.type, "open": d.open, "planted": d.get("planted", Farming.NOT_PLANTED), "crop": d.get("crop", Farming.DEFAULT_CROP)})
	return {"depleted": cells, "structures": built}


func load_save_data(data: Dictionary) -> void:
	GameState.depleted_cells = {}
	for c in data.get("depleted", []):
		GameState.depleted_cells[Vector2i(int(c[0]), int(c[1]))] = true
	for node in get_tree().get_nodes_in_group("gatherable"):
		if layout.buildable and node is Gatherable and GameState.depleted_cells.has(node.cell):
			node.free()
	GameState.structures = {}
	for d in data.get("structures", []):
		if BuildCatalog.TYPES.has(d.type):
			GameState.structures[Vector2i(int(d.cell[0]), int(d.cell[1]))] = {"type": String(d.type), "open": bool(d.open), "planted": float(d.get("planted", Farming.NOT_PLANTED)), "crop": String(d.get("crop", Farming.DEFAULT_CROP))}
	_spawn_structures()


func pixel_size() -> Vector2i:
	return layout.size * TileCatalog.TILE_SIZE


## World position of the bottom-center "feet" point of a cell (y-sort anchor).
static func cell_to_feet(cell: Vector2i) -> Vector2:
	var t := TileCatalog.TILE_SIZE
	return Vector2(cell.x * t + t / 2.0, cell.y * t + t - 4.0)


static func cell_center(cell: Vector2i) -> Vector2:
	var t := TileCatalog.TILE_SIZE
	return Vector2(cell.x * t + t / 2.0, cell.y * t + t / 2.0)
