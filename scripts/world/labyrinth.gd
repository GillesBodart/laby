extends World
## A labyrinth sector (see Sectors): the Stone maze north of the Clearing and
## the deeper biomes beyond it. The sector id is GameState.area. The south
## vestibule leads back, the guardian's arena and its sealed gate lie north.

const ENEMY_SCENE := preload("res://scenes/world/props/enemy.tscn")


func sector() -> String:
	return GameState.area if Sectors.is_sector(GameState.area) else "labyrinth"


func make_layout() -> ClearingLayout:
	GameState.reached[sector()] = true
	return LabyrinthGenerator.generate(GameState.world_seed, sector())


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


func greet() -> void:
	EventBus.notify.emit(Sectors.info(sector()).greet)


func enter_portal(target: String) -> void:
	if target == "escape":
		if not GameState.escaped:
			GameState.escaped = true
			EventBus.notify.emit("Light. Wind. You have walked out of the Maze. (You may keep exploring.)")
		GameState.travel("clearing")
		return
	super.enter_portal(target)


func portal_message(target: String) -> String:
	if target == "clearing":
		if TimeSystem.phase() == DayClock.Phase.NIGHT:
			return "Back at the Clearing... but the gates are shut for the night."
		return "You return to the Clearing."
	return "You enter %s." % Sectors.display_name(target)
