class_name TileSetFactory
extends RefCounted
## Builds the TileSet for the Clearing atlas from TileCatalog definitions,
## so collision and atlas layout live in one data table.

const SOURCE_ID := 0
const WORLD_PHYSICS_LAYER := 1 # bit for "world" (layer 1)

static var _cache: TileSet


static func clearing_tileset() -> TileSet:
	if _cache:
		return _cache
	var size := TileCatalog.TILE_SIZE
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, WORLD_PHYSICS_LAYER)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(TileCatalog.TEXTURE_PATH)
	source.texture_region_size = Vector2i(size, size)
	tile_set.add_source(source, SOURCE_ID)

	var h := size / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for id in TileCatalog.DEFS:
		var coords := TileCatalog.atlas_coords(id)
		source.create_tile(coords)
		if TileCatalog.is_solid(id):
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	_cache = tile_set
	return tile_set
