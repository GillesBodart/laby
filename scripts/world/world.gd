class_name World
extends Node2D
## Main gameplay scene: builds an area from the world seed, spawns the local
## player, wires the camera and handles portal travel between areas.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var clearing: ClearingWorld = $Clearing
@onready var camera: GameCamera = $Camera

const REVEAL_RADIUS := 5

var layout: ClearingLayout
var fog: FogMap
var _last_cell := {}


func _ready() -> void:
	layout = make_layout()
	clearing.build(layout)
	camera.set_bounds(clearing.pixel_size())
	if layout.fogged:
		fog = GameState.fog_for(GameState.area, layout.size)

	var arrival := layout.return_cell if GameState.arriving else layout.spawn_cell
	GameState.arriving = false
	var player := spawn_player(GameState.local_peer_id(), ClearingWorld.cell_center(arrival))
	var save := GameState.take_pending_save()
	if save.is_empty():
		greet()
	else:
		SaveSystem.apply_to_tree(save)
	camera.follow(player)


## Override in other areas.
func make_layout() -> ClearingLayout:
	return ClearingGenerator.generate(GameState.world_seed)


func greet() -> void:
	if GameState.inventories.is_empty():
		EventBus.notify.emit("You wake up in the Clearing. The walls are... enormous.")


func _physics_process(_delta: float) -> void:
	_update_fog()
	if layout.portal_target == "" or GameState.area == layout.portal_target:
		return
	for player in GameState.players.values():
		var cell := clearing.walls.local_to_map(clearing.walls.to_local(player.global_position))
		if layout.portal_rect.has_point(cell):
			EventBus.notify.emit(portal_message())
			GameState.travel(layout.portal_target)
			return


func _update_fog() -> void:
	if fog == null:
		return
	for id in GameState.players:
		var cell := clearing.walls.local_to_map(clearing.walls.to_local(GameState.players[id].global_position))
		if _last_cell.get(id) != cell:
			_last_cell[id] = cell
			fog.reveal(cell, REVEAL_RADIUS)


func portal_message() -> String:
	return "You step into the Labyrinth..."


func spawn_player(peer_id: int, at: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.peer_id = peer_id
	player.name = "Player_%d" % peer_id
	player.position = at
	clearing.entities.add_child(player)
	return player
