class_name Player
extends CharacterBody2D
## Survivor controlled by a PlayerInput intent (keyboard locally,
## network later). Movement uses a small state machine.

enum State { IDLE, MOVE }

const WALK_SPEED := 144.0
const RUN_SPEED := 230.0
const ACCELERATION := 1800.0
const FRICTION := 2400.0
const SHEET := preload("res://assets/sprites/player.png")
const FRAME_SIZE := Vector2i(32, 32)
const ANIMATIONS := {
	"idle_down": {"row": 0, "frames": [0], "fps": 1.0},
	"walk_down": {"row": 0, "frames": [1, 0, 2, 0], "fps": 8.0},
	"idle_up": {"row": 1, "frames": [0], "fps": 1.0},
	"walk_up": {"row": 1, "frames": [1, 0, 2, 0], "fps": 8.0},
	"idle_side": {"row": 2, "frames": [0], "fps": 1.0},
	"walk_side": {"row": 2, "frames": [1, 0, 2, 0], "fps": 8.0},
}

const REACH := 36.0
const STATION_RANGE := 112.0
const GATHER_COOLDOWN := 0.4
const ATTACK_COOLDOWN := 0.45
const ATTACK_RANGE := 36.0
const HURT_INVULNERABILITY := 0.6
const BASE_DAMAGE := 8

@export var peer_id: int = GameState.OFFLINE_PEER_ID

var state: State = State.IDLE
var facing := Vector2.DOWN
var inventory := Inventory.new()
var equipment := Equipment.new()
var survival := Survival.new()
var _gather_timer := 0.0
var _attack_timer := 0.0
var _hurt_timer := 0.0
var _slash_time := 0.0
var _swing: Tween
var _tool_pivot: Node2D
var _tool_arm: Node2D
var _tool_sprite: Sprite2D

@onready var input: PlayerInput = $PlayerInput
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var light: PointLight2D = $Light


func _ready() -> void:
	add_to_group("players")
	add_to_group("persist")
	input.peer_id = peer_id
	sprite.sprite_frames = SpriteFramesBuilder.build(SHEET, FRAME_SIZE, ANIMATIONS)
	sprite.play("idle_down")
	if GameState.inventories.has(peer_id):
		inventory.load_data(GameState.inventories[peer_id])
	inventory.changed.connect(func() -> void: GameState.inventories[peer_id] = inventory.to_data())
	if GameState.equipments.has(peer_id):
		equipment.load_data(GameState.equipments[peer_id])
	equipment.changed.connect(_on_equipment_changed)
	_on_equipment_changed()
	if GameState.survivals.has(peer_id):
		survival.load_data(GameState.survivals[peer_id])
	survival.died.connect(_on_died)
	GameState.register_player(self)
	_build_tool_sprite()
	if input.is_local():
		add_child(Builder.new())


func _exit_tree() -> void:
	GameState.survivals[peer_id] = survival.to_data()
	GameState.equipments[peer_id] = equipment.to_data()
	if GameState.players.get(peer_id) == self:
		GameState.unregister_player(peer_id)


func _physics_process(delta: float) -> void:
	var move := input.move_vector
	match state:
		State.IDLE:
			if move != Vector2.ZERO:
				state = State.MOVE
		State.MOVE:
			if move == Vector2.ZERO:
				state = State.IDLE

	if state == State.MOVE:
		var speed := RUN_SPEED if input.run and survival.can_run() else WALK_SPEED
		velocity = velocity.move_toward(move * speed * survival.speed_multiplier(), ACCELERATION * delta)
		facing = _cardinal(move)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	survival.tick(delta, state == State.MOVE, input.run)
	_update_visuals()
	_gather_timer = maxf(_gather_timer - delta, 0.0)
	if input.interact and _gather_timer == 0.0:
		_try_gather()
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if _slash_time > 0.0:
		_slash_time = maxf(_slash_time - delta, 0.0)
		queue_redraw()
	if input.attack and _attack_timer == 0.0 and not survival.is_dead():
		_attack()


func _unhandled_input(event: InputEvent) -> void:
	if input.is_local() and event.is_action_pressed("eat"):
		eat_best_food()


## Eats the most nourishing food in the backpack. Returns whether anything was eaten.
func eat_best_food() -> bool:
	var best := ""
	for s in inventory.slots:
		if not s.is_empty() and ItemCatalog.food_of(s.id) > (ItemCatalog.food_of(best) if best != "" else 0.0):
			best = s.id
	if best == "":
		EventBus.notify.emit("Nothing to eat.")
		return false
	if survival.hunger >= Survival.MAX_HUNGER - 0.5:
		EventBus.notify.emit("Not hungry.")
		return false
	inventory.remove(best, 1)
	survival.eat(ItemCatalog.food_of(best))
	EventBus.notify.emit("Ate %s." % ItemCatalog.item_name(best))
	return true


func gain_xp(amount: int) -> void:
	var before := survival.level
	if survival.add_xp(amount) > 0:
		EventBus.notify.emit("Level %d! +%d skill point" % [survival.level, survival.level - before])


func _on_died() -> void:
	EventBus.notify.emit("You collapsed... and wake up at the camp.")
	survival.revive()
	velocity = Vector2.ZERO
	var world := get_tree().get_first_node_in_group("clearing_world") as ClearingWorld
	if GameState.area != "clearing" or world == null:
		GameState.arriving = false
		GameState.survivals[peer_id] = survival.to_data()
		GameState.travel("clearing")
	else:
		global_position = ClearingWorld.cell_center(world.layout.spawn_cell)


## Damage dealt per hit: the equipped weapon (tools count) plus rings and skills.
func weapon_damage() -> int:
	return BASE_DAMAGE + equipment.stat("dmg") + survival.damage_bonus()


## Damage absorbed per hit by worn gear.
func armor() -> int:
	return equipment.stat("armor")


## Best tool tier of a kind: carried in the backpack or held as the weapon.
func tool_tier(kind: String) -> int:
	return maxi(inventory.tool_tier(kind), equipment.tool_tier(kind))


## Best tool of a kind to show in hand ("" = bare hands).
func best_tool(kind: String) -> String:
	var best := ""
	var held := equipment.get_item("weapon")
	if held != "" and ItemCatalog.tool_of(held) == kind:
		best = held
	for s in inventory.slots:
		if not s.is_empty() and ItemCatalog.tool_of(s.id) == kind and (best == "" or ItemCatalog.tier_of(s.id) > ItemCatalog.tier_of(best)):
			best = s.id
	return best


func _on_equipment_changed() -> void:
	GameState.equipments[peer_id] = equipment.to_data()
	survival.bonus_health = float(equipment.stat("hp"))
	survival.health = minf(survival.health, survival.max_health())


func _attack() -> void:
	_attack_timer = ATTACK_COOLDOWN
	_slash_time = 0.12
	swing(equipment.get_item("weapon"))
	var center := global_position + Vector2(0, -8)
	for node in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = node.global_position + Vector2(0, -6) - center
		if offset.length() <= ATTACK_RANGE and (offset.length() < 12.0 or offset.normalized().dot(facing) > 0.25):
			node.take_damage(weapon_damage(), self)


func take_damage(amount: int, source: Node2D = null) -> void:
	if _hurt_timer > 0.0 or survival.is_dead():
		return
	_hurt_timer = HURT_INVULNERABILITY
	survival.damage(maxi(amount - armor(), 1))
	if source:
		velocity = (global_position - source.global_position).normalized() * 160.0
	var tw := create_tween()
	sprite.modulate = Color(1.6, 0.5, 0.5)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)


func _draw() -> void:
	if _slash_time <= 0.0:
		return
	var a := facing.angle()
	draw_arc(Vector2(0, -8), 24.0, a - 0.9, a + 0.9, 10, Color(1, 1, 1, 0.9), 3.0)
	draw_arc(Vector2(0, -8), 20.0, a - 0.7, a + 0.7, 8, Color(0.8, 0.9, 1, 0.6), 2.0)


func _try_gather() -> void:
	var target := find_gatherable()
	if target:
		_gather_timer = GATHER_COOLDOWN
		swing(best_tool(target.tool_kind), func() -> void:
			if is_instance_valid(target):
				target.hit(self))
		return
	var plot := _find_farm_plot()
	if plot:
		_gather_timer = 0.6
		plot.farm_interact(self)


func _find_farm_plot() -> Structure:
	var probe := global_position + Vector2(0, -8) + facing * 16.0
	var best: Structure = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("farm_plot"):
		var d := probe.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Nearest harvestable prop within reach in front of the player.
func find_gatherable() -> Gatherable:
	var probe := global_position + Vector2(0, -8) + facing * 16.0
	var best: Gatherable = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("gatherable"):
		var d := probe.distance_to(node.global_position + Vector2(0, -6))
		if d < best_d:
			best_d = d
			best = node
	return best


## Crafting stations available near the player.
func nearby_stations() -> Array:
	var found: Array = []
	for group in ["campfire", "workbench", "furnace"]:
		for node in get_tree().get_nodes_in_group(group):
			if global_position.distance_to(node.global_position) <= STATION_RANGE:
				found.append(group)
				break
	return found

func _cardinal(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x > 0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0 else Vector2.UP


func _update_visuals() -> void:
	var dir_name := "down"
	if facing == Vector2.UP:
		dir_name = "up"
	elif facing.x != 0:
		dir_name = "side"
	sprite.flip_h = facing == Vector2.LEFT
	var anim := ("walk_" if state == State.MOVE else "idle_") + dir_name
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 1.5 if input.run and survival.can_run() else 1.0
	light.energy = 0.55 * LightingCurve.darkness_at(TimeSystem.minute_of_day())


func get_save_key() -> String:
	return "player_%d" % peer_id


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"facing": [facing.x, facing.y],
		"inventory": inventory.to_data(),
		"equipment": equipment.to_data(),
		"survival": survival.to_data(),
	}


func load_save_data(data: Dictionary) -> void:
	inventory.load_data(data.get("inventory", []))
	equipment.load_data(data.get("equipment", {}))
	survival.load_data(data.get("survival", {}))
	var p: Array = data.get("position", [global_position.x, global_position.y])
	global_position = Vector2(p[0], p[1])
	var f: Array = data.get("facing", [0, 1])
	facing = Vector2(f[0], f[1])
	velocity = Vector2.ZERO


# ------------------------------------------------------------- tool swing

## Pivot (mirrors for left) -> Arm (rotates) -> Sprite (grip at the origin).
func _build_tool_sprite() -> void:
	_tool_pivot = Node2D.new()
	_tool_pivot.name = "ToolPivot"
	add_child(_tool_pivot)
	_tool_arm = Node2D.new()
	_tool_pivot.add_child(_tool_arm)
	_tool_sprite = Sprite2D.new()
	_tool_sprite.centered = false
	# Item icons hold their grip near the bottom-left corner.
	_tool_sprite.offset = Vector2(-7, -25)
	_tool_sprite.scale = Vector2(0.62, 0.62)
	_tool_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tool_arm.add_child(_tool_sprite)
	_tool_pivot.visible = false


## Swings an item (axe, pickaxe, weapon; "" = empty hand) toward the facing
## direction; `on_impact` runs when the blow lands.
func swing(item_id: String, on_impact := Callable()) -> void:
	if _tool_pivot == null:
		if on_impact.is_valid():
			on_impact.call()
		return
	if _swing and _swing.is_valid():
		_swing.kill()
	var path := "res://assets/ui/items/%s.png" % item_id
	_tool_sprite.visible = item_id != "" and ResourceLoader.exists(path)
	if _tool_sprite.visible:
		_tool_sprite.texture = load(path)
	# Rotations relative to the icon pose (handle pointing up-right).
	var raise := -75.0
	var strike := 75.0
	_tool_pivot.scale = Vector2.ONE
	_tool_pivot.z_index = 1
	_tool_pivot.position = Vector2(4, -11)
	if facing == Vector2.LEFT:
		_tool_pivot.scale = Vector2(-1, 1)
		_tool_pivot.position = Vector2(-4, -11)
	elif facing == Vector2.DOWN:
		raise = -45.0
		strike = 130.0
		_tool_pivot.position = Vector2(5, -10)
	elif facing == Vector2.UP:
		raise = 110.0
		strike = -40.0
		_tool_pivot.position = Vector2(4, -14)
		_tool_pivot.z_index = -1
	_tool_arm.rotation_degrees = raise - 15.0
	_tool_pivot.visible = true
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	_swing = create_tween()
	_swing.tween_property(_tool_arm, "rotation_degrees", raise, 0.07)
	_swing.tween_property(_tool_arm, "rotation_degrees", strike, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing.parallel().tween_property(sprite, "position", facing * 2.0, 0.09)
	_swing.tween_callback(func() -> void:
		sprite.scale = Vector2(1.08, 0.92)
		if on_impact.is_valid():
			on_impact.call())
	_swing.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	_swing.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.1)
	_swing.tween_callback(func() -> void: _tool_pivot.visible = false)
