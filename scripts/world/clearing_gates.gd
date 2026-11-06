class_name ClearingGates
extends Node
## Opens the Clearing gates at dawn and closes them at nightfall.
## A gate cell is only shut once no player stands on it.

const WARNING_TEXT := "The walls groan... the gates close at nightfall."

var _walls: TileMapLayer
var _cells: Array[Vector2i] = []
var _pending_close: Array[Vector2i] = []
var is_open := true


func setup(walls: TileMapLayer, gates: Array[Dictionary]) -> void:
	_walls = walls
	_cells.clear()
	for gate in gates:
		_cells.append_array(gate.cells)
	if not EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.connect(_on_phase_changed)
	_apply_phase(TimeSystem.phase(), false)


func _on_phase_changed(phase: int) -> void:
	_apply_phase(phase, true)


func _apply_phase(phase: int, announce: bool) -> void:
	match phase:
		DayClock.Phase.NIGHT:
			set_open(false)
		DayClock.Phase.DUSK:
			set_open(true)
			if announce:
				EventBus.notify.emit(WARNING_TEXT)
		_:
			set_open(true)


func set_open(open: bool) -> void:
	if open == is_open and (open or _pending_close.is_empty()):
		return
	is_open = open
	_pending_close.clear()
	if open:
		for cell in _cells:
			_walls.erase_cell(cell)
	else:
		_pending_close = _cells.duplicate()
		_close_free_cells()
	EventBus.gates_changed.emit(open)


func _physics_process(_delta: float) -> void:
	if not _pending_close.is_empty():
		_close_free_cells()


func _close_free_cells() -> void:
	var occupied := {}
	for player in GameState.players.values():
		occupied[_walls.local_to_map(_walls.to_local(player.global_position))] = true
	var still_pending: Array[Vector2i] = []
	for cell in _pending_close:
		if occupied.has(cell):
			still_pending.append(cell)
		else:
			_walls.set_cell(cell, TileSetFactory.SOURCE_ID, TileCatalog.atlas_coords(TileCatalog.Id.GATE_CLOSED))
	_pending_close = still_pending
