extends World
## A labyrinth sector (see Sectors): the Stone maze north of the Clearing and
## the deeper biomes beyond it. The sector id is GameState.area. The south
## vestibule leads back, the guardian's arena and its sealed gate lie north.

const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const DUSK_WARNING := "The light fades... at nightfall the walls shift and the Clearing gates close."


func sector() -> String:
	return GameState.area if Sectors.is_sector(GameState.area) else "labyrinth"


func make_layout() -> ClearingLayout:
	GameState.reached[sector()] = true
	return LabyrinthGenerator.generate(GameState.world_seed, sector(), current_shift())


## The maze shifts at every nightfall: the shift index is the night index.
static func current_shift() -> int:
	return maxi(TimeSystem.clock.night_index(), 0)


func setup_area() -> void:
	var tint: Color = Sectors.info(sector()).tint
	clearing.ground.self_modulate = tint
	clearing.walls.self_modulate = tint
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
	_sync_fog()
	EventBus.night_started.connect(_on_night_started)
	EventBus.phase_changed.connect(_on_phase_changed)


## Walls seen before the last shift(s) may have moved: flag them on the map.
func _sync_fog() -> void:
	var now := current_shift()
	if fog == null or fog.shift == now:
		return
	for region in LabyrinthGenerator.shift_regions(GameState.world_seed, sector(), fog.shift) + LabyrinthGenerator.shift_regions(GameState.world_seed, sector(), now):
		fog.mark_uncertain(LabyrinthGenerator.region_tiles(region).grow(1))
	fog.shift = now


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
	return "You enter %s." % Sectors.display_name(target)
