class_name World
extends Node2D
## Main gameplay scene: builds an area from the world seed, spawns the local
## player, wires the camera and handles portal travel between areas.

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

@onready var clearing: ClearingWorld = $Clearing
@onready var camera: GameCamera = $Camera

const REVEAL_RADIUS := 5
## Real seconds a companion downed in the Clearing rests before rejoining.
const COMPANION_REST_SECONDS := 30.0

var layout: ClearingLayout
var fog: FogMap
var _last_cell := {}


func _ready() -> void:
	layout = make_layout()
	clearing.build(layout)
	camera.set_bounds(clearing.pixel_size())
	if layout.fogged:
		fog = GameState.fog_for(GameState.area, layout.size)

	var arrival := layout.spawn_cell
	if GameState.arriving:
		arrival = layout.arrivals.get(GameState.came_from, layout.return_cell)
	GameState.arriving = false
	var player := spawn_player(GameState.local_peer_id(), ClearingWorld.cell_center(arrival))
	setup_area()
	var save := GameState.take_pending_save()
	if save.is_empty():
		greet()
	else:
		SaveSystem.apply_to_tree(save)
	spawn_companions()
	spawn_survivors()
	EventBus.settlement_changed.connect(spawn_survivors)
	EventBus.night_started.connect(start_raid)
	EventBus.day_started.connect(end_raid)
	EventBus.companion_downed.connect(_on_companion_downed)
	EventBus.slept.connect(_on_slept)
	camera.follow(player)


## Override in other areas.
func make_layout() -> ClearingLayout:
	return ClearingGenerator.generate(GameState.world_seed)


## Override in other areas: extra nodes once the map and the player exist.
func setup_area() -> void:
	pass


func greet() -> void:
	if GameState.inventories.is_empty():
		EventBus.notify.emit("You wake up in the Clearing. The walls are... enormous.")


func _physics_process(_delta: float) -> void:
	_update_fog()
	for portal in layout.all_portals():
		if portal.target == GameState.area:
			continue
		for player in GameState.players.values():
			var cell := clearing.walls.local_to_map(clearing.walls.to_local(player.global_position))
			if portal.rect.has_point(cell):
				enter_portal(portal.target)
				return


func enter_portal(target: String) -> void:
	EventBus.notify.emit(portal_message(target))
	GameState.travel(target)


func _update_fog() -> void:
	if fog == null:
		return
	for id in GameState.players:
		var cell := clearing.walls.local_to_map(clearing.walls.to_local(GameState.players[id].global_position))
		if _last_cell.get(id) != cell:
			_last_cell[id] = cell
			fog.reveal(cell, REVEAL_RADIUS)


func portal_message(_target: String) -> String:
	return "You step into the Labyrinth..."


## Brings each survivor's companions along. Downed ones rest in the Clearing
## and are back on their feet once their owner returns there (or, when they
## fell in the Clearing itself, after COMPANION_REST_SECONDS by the campfire).
func spawn_companions() -> void:
	for c in GameState.companions:
		var owner_node: Player = GameState.players.get(int(c.owner))
		if owner_node == null:
			continue
		if c.downed and GameState.area == "clearing":
			_heal_companion(c)
		if c.downed:
			continue
		if c.get("mode", "follow") == "stay" and GameState.area != "clearing":
			c.mode = "follow"
		Companion.spawn(clearing.entities, c, owner_node, owner_node.global_position + Vector2(-16, 10))


func _heal_companion(c: Dictionary) -> void:
	c.downed = false
	c.hp = c.max_hp


## Waking up: the screen fades in from black.
func _on_slept() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	var black := ColorRect.new()
	black.color = Color(0.03, 0.03, 0.06)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	add_child(layer)
	var tween := layer.create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(black, "modulate:a", 0.0, 1.4)
	tween.tween_callback(layer.queue_free)


func _on_companion_downed(record: Dictionary) -> void:
	if GameState.area != "clearing":
		return
	# Pauses with the game; the connection dies with this scene.
	get_tree().create_timer(COMPANION_REST_SECONDS, false).timeout.connect(_revive_companion.bind(record))


## A companion that rested by the campfire gets up and rejoins its owner.
func _revive_companion(record: Dictionary) -> void:
	if not record.downed or not GameState.companions.has(record) or GameState.area != "clearing":
		return
	var owner_node: Player = GameState.players.get(int(record.owner))
	if owner_node == null:
		return
	_heal_companion(record)
	Companion.spawn(clearing.entities, record, owner_node, ClearingWorld.cell_center(layout.campfire_cell + Vector2i(1, 1)))
	EventBus.notify.emit("%s is back on its feet." % record.name)


## The settlement's people live around the campfire, a little away from where
## the player wakes up. Respawned whenever the settlement changes.
func spawn_survivors() -> void:
	if GameState.area != "clearing" or not layout.buildable:
		return
	for s in get_tree().get_nodes_in_group("survivors"):
		s.remove_from_group("survivors")
		s.remove_from_group("interactable")
		s.queue_free()
	var home := ClearingWorld.cell_center(layout.campfire_cell + Vector2i(-4, -1))
	for i in GameState.survivors.size():
		var offset := Vector2((i % 4) * 22 - 33, (i >> 2) * 20)
		clearing.entities.add_child(Survivor.create(i, home + offset))


## Attack styles that make sense for a creature storming a camp.
const RAID_ATTACKS := ["melee", "charge", "pounce", "slam", "hit_run", "ranged", "blink"]


## Nightfall in the Clearing: raiders come out of the maze (Settlement.raid_size).
func start_raid(night: int) -> int:
	if GameState.area != "clearing" or not layout.buildable:
		return 0
	var tier := Settlement.tier(GameState.structures, GameState.bosses_defeated.size())
	var n := Settlement.raid_size(tier, night, Settlement.defence(GameState.survivors, GameState.structures))
	if n == 0:
		return 0
	var camp := ClearingWorld.cell_center(layout.campfire_cell)
	for spot in _raid_spawns(n):
		var id := EnemyCatalog.pick("labyrinth", Settlement.raid_depth(tier), randf(),
			func(d): return d.temper != "passive" and d.attack in RAID_ATTACKS)
		if id == "":
			continue
		var e: Enemy = ClearingWorld.ENEMY_SCENE.instantiate()
		e.setup(id)
		e.position = spot
		e.make_raider(camp)
		clearing.entities.add_child(e)
	Sound.play("horn", Vector2.INF, 0.0)
	EventBus.notify.emit("Night %d: %d raiders pour out of the maze toward the camp!" % [night, n])
	return n


## Free cells at the edge of the Clearing, far from the fire.
func _raid_spawns(n: int) -> Array:
	var r := layout.clearing_rect
	var out := []
	for i in 400:
		if out.size() >= n:
			break
		var side := randi() % 4
		var c := Vector2i(randi_range(r.position.x + 1, r.end.x - 2), r.position.y + 1 if side == 0 else r.end.y - 2)
		if side >= 2:
			c = Vector2i(r.position.x + 1 if side == 2 else r.end.x - 2, randi_range(r.position.y + 1, r.end.y - 2))
		if layout.is_walkable(c) and not GameState.structures.has(c) and c.distance_to(layout.campfire_cell) > 8.0:
			out.append(ClearingWorld.cell_center(c))
	return out


## Dawn: surviving raiders slink back into the maze.
func end_raid(_day := 0) -> void:
	var left := get_tree().get_nodes_in_group("raiders")
	for e in left:
		e.queue_free()
	if not left.is_empty():
		EventBus.notify.emit("At first light the raiders slink back into the maze.")

func spawn_player(peer_id: int, at: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.peer_id = peer_id
	player.name = "Player_%d" % peer_id
	player.position = at
	clearing.entities.add_child(player)
	return player
