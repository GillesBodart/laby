class_name TileSetFactory
extends RefCounted
## Builds the TileSet for the Clearing atlas from TileCatalog definitions,
## so collision and atlas layout live in one data table. Sectors pass their
## own atlas texture (same layout, see Sectors art); one TileSet per texture.

const SOURCE_ID := 0
const WORLD_PHYSICS_LAYER := 1 # bit for "world" (layer 1)

static var _cache := {}


static func clearing_tileset(texture_path: String = TileCatalog.TEXTURE_PATH) -> TileSet:
	if _cache.has(texture_path):
		return _cache[texture_path]
	var size := TileCatalog.TILE_SIZE
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(size, size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, WORLD_PHYSICS_LAYER)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(texture_path)
	source.texture_region_size = Vector2i(size, size)
	tile_set.add_source(source, SOURCE_ID)

	var h := size / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for id in TileCatalog.DEFS:
		for coords in TileCatalog.all_atlas_coords(id):
			source.create_tile(coords)
			if TileCatalog.is_solid(id):
				var data := source.get_tile_data(coords, 0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, square)
	_cache[texture_path] = tile_set
	return tile_set
