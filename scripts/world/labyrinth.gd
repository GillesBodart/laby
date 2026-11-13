extends World
## A labyrinth sector (see Sectors): the Stone maze north of the Clearing and
## the deeper biomes beyond it. The sector id is GameState.area. The south
## vestibule leads back, the guardian's arena and its sealed gate lie north.

const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const DUSK_WARNING := "The light fades... at nightfall the walls shift and the Clearing gates close."
const FAR_WARNING := "You are a long way in, and the day is running out. Head back now to beat the gates."
## The arena glows in the sector's accent colour (about this radius in px).
const ARENA_LIGHT_RADIUS := 320.0

var _home_check := 0.0
var _home_warned_day := -1


func sector() -> String:
	return GameState.area if Sectors.is_sector(GameState.area) else "labyrinth"


func make_layout() -> ClearingLayout:
	GameState.reached[sector()] = true
	return LabyrinthGenerator.generate(GameState.world_seed, sector(), current_shift())


## The maze shifts at every nightfall: the shift index is the night index.
static func current_shift() -> int:
	return maxi(TimeSystem.clock.night_index(), 0)


func setup_area() -> void:
	# Each sector paints its own atlas (same layout); the tint is only a mood.
	var info := Sectors.info(sector())
	var tile_set := TileSetFactory.clearing_tileset(info.art.tiles)
	clearing.ground.tile_set = tile_set
	clearing.walls.tile_set = tile_set
	clearing.ground.self_modulate = info.tint
	clearing.walls.self_modulate = info.tint
	if not layout.sector_gate.is_empty() and not GameState.has_keys(layout.sector_gate.keys):
		clearing.entities.add_child(SectorGate.create(layout.sector_gate.rect, layout.sector_gate.keys))
	if not layout.boss.is_empty() and not GameState.bosses_defeated.has(layout.boss.type):
		var boss: Enemy = ENEMY_SCENE.instantiate()
		boss.setup(layout.boss.type)
		boss.position = ClearingWorld.cell_center(layout.boss.cell) + Vector2(0, 12)
		clearing.entities.add_child(boss)
	# A waystone stands in every sector's vestibule: the way home.
	var stone_cell := layout.return_cell + Vector2i(-1, 0)
	if not layout.is_wall(stone_cell):
		var stone := Structure.create("waystone", stone_cell)
		stone.fixed = true
		clearing.entities.add_child(stone)
	for m in layout.landmarks:
		clearing.entities.add_child(Landmark.create("landmark", m.type, m.cell))
	for g in layout.glyphs:
		clearing.entities.add_child(Landmark.create("glyph", g.glyph, g.cell))
	for c in layout.chests:
		clearing.entities.add_child(TreasureChest.create(c.id, sector(), c.cell))
	_light_arena(info)
	_shape_curtains()
	for h in layout.hazards:
		var vent := MagmaVent.create(h.rect)
		clearing.add_child(vent)
		clearing.move_child(vent, clearing.entities.get_index())
	_sync_fog()
	EventBus.night_started.connect(_on_night_started)
	EventBus.phase_changed.connect(_on_phase_changed)


## Walls seen before the last shift(s) may have moved: flag them on the map.
func _sync_fog() -> void:
	var now := current_shift()
	if fog == null or fog.shift == now:
		return
	for region in LabyrinthGenerator.shift_regions(GameState.world_seed, sector(), fog.shift) + LabyrinthGenerator.shift_regions(GameState.world_seed, sector(), now):
		fog.mark_uncertain(LabyrinthGenerator.region_tiles(region).grow(LabyrinthGenerator.PITCH - LabyrinthGenerator.OPEN + 1))
	fog.shift = now


func _light_arena(info: Dictionary) -> void:
	if layout.arena_rect.size == Vector2i.ZERO:
		return
	var light := PointLight2D.new()
	light.texture = preload("res://resources/lights/light_banded.tres")
	light.color = info.art.glow[3]
	light.energy = 0.9
	light.texture_scale = ARENA_LIGHT_RADIUS / (light.texture.get_width() / 2.0)
	light.position = ClearingWorld.cell_center(layout.arena_rect.get_center())
	clearing.entities.add_child(light)


## Thorn curtains span their whole passage (3 tiles), not one tile.
func _shape_curtains() -> void:
	var curtains := {}
	for p in layout.props:
		if p.type in [LabyrinthGenerator.CURTAIN, LabyrinthGenerator.CURTAIN_V]:
			curtains[p.cell] = p.type == LabyrinthGenerator.CURTAIN_V
	for g in get_tree().get_nodes_in_group("gatherable"):
		if not curtains.has(g.cell):
			continue
		var vertical: bool = curtains[g.cell]
		var col := g.get_node("Collision") as CollisionShape2D
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12, 96) if vertical else Vector2(96, 12)
		col.shape = shape
		col.position = Vector2(0, -12) if vertical else Vector2(0, -10)
		var sprite := g.get_node("Sprite") as Sprite2D
		var size := sprite.texture.get_size()
		sprite.offset = Vector2(-size.x / 2.0, 36.0 - size.y) if vertical else Vector2(-size.x / 2.0, 2.0 - size.y)
		g.get_node("Shadow").visible = false


func _process(delta: float) -> void:
	_home_check += delta
	if _home_check < 1.0:
		return
	_home_check = 0.0
	_check_way_home()


## Besides the dusk warning, warn once a day when the way home (path through
## the maze) takes longer than what is left of the daylight, with a margin.
func _check_way_home() -> void:
	var day := TimeSystem.clock.day()
	var minute := TimeSystem.minute_of_day()
	if _home_warned_day == day or minute < DayClock.DAWN_START or minute >= DayClock.DUSK_START:
		return
	var player: Node2D = GameState.players.get(GameState.local_peer_id())
	if player == null:
		return
	var tile := clearing.walls.local_to_map(clearing.walls.to_local(player.global_position))
	var cells := LabyrinthGenerator.cells_home(layout, sector(), tile)
	var left := (DayClock.NIGHT_START - minute) * TimeSystem.real_seconds_per_day / DayClock.MINUTES_PER_DAY / maxf(TimeSystem.time_scale, 0.001)
	if LabyrinthGenerator.dusk_warning_due(left, cells):
		_home_warned_day = day
		EventBus.notify.emit(FAR_WARNING)


func _on_phase_changed(phase: int) -> void:
	if phase == DayClock.Phase.DUSK:
		EventBus.notify.emit(DUSK_WARNING)


func _on_night_started(_night: int) -> void:
	apply_shift(current_shift())


## Moves the walls live: the regions of the old and the new shift are copied
## from a freshly generated layout; walkers caught inside are pushed out.
func apply_shift(shift: int) -> void:
	Sound.play("shift", Vector2.INF, 0.0)
	var fresh := LabyrinthGenerator.generate(GameState.world_seed, sector(), shift)
	var rects: Array = []
	for r in layout.shift_tiles + fresh.shift_tiles:
		rects.append(r.grow(1).grow_individual(0, 0, 0, 1).intersection(Rect2i(Vector2i.ZERO, layout.size)))
	var changed := 0
	for r in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if layout.get_wall(c) != fresh.get_wall(c):
					changed += 1
				layout.set_wall(c, fresh.get_wall(c))
				layout.set_ground(c, fresh.get_ground(c))
				clearing.ground.set_cell(c, TileSetFactory.SOURCE_ID, TileCatalog.atlas_for(fresh.get_ground(c), c))
				if fresh.is_wall(c):
					clearing.walls.set_cell(c, TileSetFactory.SOURCE_ID, TileCatalog.atlas_for(fresh.get_wall(c), c))
				else:
					clearing.walls.erase_cell(c)
	layout.shift_tiles = fresh.shift_tiles
	clearing.refresh_wall_edges()
	# Curtains and vents whose passage closed are swallowed by the walls.
	for g in get_tree().get_nodes_in_group("gatherable"):
		if layout.is_wall(g.cell):
			g.queue_free()
	for v in get_tree().get_nodes_in_group("hazards"):
		if layout.is_wall(v.rect.position):
			v.queue_free()
	if fog != null:
		for r in rects:
			fog.mark_uncertain(r)
		fog.shift = shift
	for group in ["players", "enemies", "companions"]:
		for n in get_tree().get_nodes_in_group(group):
			_unbury(n)
	if changed > 0:
		EventBus.notify.emit("A deep grinding echoes through the maze... the walls are moving.")


func _unbury(n: Node) -> void:
	if not n is Node2D:
		return
	var c := clearing.walls.local_to_map(clearing.walls.to_local(n.global_position))
	if layout.is_wall(c):
		n.global_position = ClearingWorld.cell_to_feet(clearing.nearest_open_cell(c))


func greet() -> void:
	EventBus.notify.emit(Sectors.info(sector()).greet)


func enter_portal(target: String) -> void:
	if target == "escape":
		if not GameState.escaped:
			GameState.escaped = true
			GameState.epilogue_pending = true
		GameState.travel("clearing")
		return
	super.enter_portal(target)


func portal_message(target: String) -> String:
	if target == "clearing":
		if TimeSystem.phase() == DayClock.Phase.NIGHT:
			return "Back at the Clearing... but the gates are shut for the night."
		return "You return to the Clearing."
	return "You enter the %s." % Sectors.display_name(target)
