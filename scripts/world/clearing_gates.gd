class_name ClearingGates
extends Node
## Opens the Clearing gates at dawn and closes them at nightfall.
## A gate cell is only shut once no player stands on it. At night a survivor
## on guard duty opens a shut gate for GUARD_OPEN_SECONDS when someone knocks
## (E on the gate, from either side).

const WARNING_TEXT := "The walls groan... the gates close at nightfall."
const GUARD_OPEN_SECONDS := 6.0
const NO_CELLS := {}

var _walls: TileMapLayer
var _cells: Array[Vector2i] = []
var _pending_close: Array[Vector2i] = []
var _closed_cells := {}
var _latches: Array[Node2D] = []
var _guard_timer := 0.0
var is_open := true


func setup(walls: TileMapLayer, gates: Array[Dictionary]) -> void:
	_walls = walls
	_cells.clear()
	for latch in _latches:
		latch.queue_free()
	_latches.clear()
	for gate in gates:
		_cells.append_array(gate.cells)
		# A latch on each side of the door so it can be reached from both.
		for side in [Vector2i.UP, Vector2i.DOWN]:
			var latch := GateLatch.new()
			latch.gates = self
			latch.position = walls.map_to_local(gate.cells[gate.cells.size() / 2] + side) + Vector2(0, 8)
			walls.add_child(latch)
			_latches.append(latch)
	_closed_cells = {}
	for cell in _cells:
		_closed_cells[cell] = true
	if not EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.connect(_on_phase_changed)
	_apply_phase(TimeSystem.phase(), false)


## Gate cells walkers must avoid right now (empty while the gates are open).
func closed_cells() -> Dictionary:
	return NO_CELLS if is_open else _closed_cells


## Someone knocks on a shut gate: the guard opens it for a few seconds.
## Returns true if the gate opened.
func knock() -> bool:
	if is_open:
		return false
	var guard := Settlement.guard(GameState.survivors)
	if guard.is_empty():
		EventBus.notify.emit("The gate is shut until dawn. Nobody keeps watch to open it.")
		return false
	set_open(true)
	_guard_timer = GUARD_OPEN_SECONDS
	Sound.play("door", Vector2.INF, 0.0)
	EventBus.notify.emit("%s heaves the gate open. Quick, it shuts again in a moment!" % Settlement.name_of(guard))
	return true


func _on_phase_changed(phase: int) -> void:
	_apply_phase(phase, true)


func _apply_phase(phase: int, announce: bool) -> void:
	_guard_timer = 0.0
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


func _physics_process(delta: float) -> void:
	if _guard_timer > 0.0:
		_guard_timer -= delta
		if _guard_timer <= 0.0 and TimeSystem.phase() == DayClock.Phase.NIGHT:
			set_open(false)
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
