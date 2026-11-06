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

## Body sprite rest position (feet on the node origin).
const SPRITE_OFFSET := Vector2(0, -16)
## Gathering/interaction reach, measured from a point just in front of the body.
const REACH := 22.0
const PROBE := 12.0
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
var _interact_held := false
var _attack_timer := 0.0
var _hurt_timer := 0.0
var _slash_time := 0.0
var _swing: Tween
var _tool_pivot: Node2D
var _tool_arm: Node2D
var _tool_sprite: Sprite2D
## Status effects: name -> seconds left ("poison" drains health, "slow" hampers movement).
var effects := {}
var _poison_acc := 0.0

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
	inventory.load_known(GameState.knowns.get(peer_id, []))
	inventory.changed.connect(func() -> void: GameState.inventories[peer_id] = inventory.to_data())
	inventory.discovered.connect(_on_discovered)
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
		var slow := 0.55 if effects.has("slow") else 1.0
		velocity = velocity.move_toward(move * speed * survival.speed_multiplier() * slow, ACCELERATION * delta)
		facing = _cardinal(move)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	survival.tick(delta, state == State.MOVE, input.run)
	_tick_effects(delta)
	_update_visuals()
	_gather_timer = maxf(_gather_timer - delta, 0.0)
	var pressed := input.interact and not _interact_held
	_interact_held = input.interact
	if pressed and input.is_local() and _ui_open():
		EventBus.station_used.emit("")
	elif input.interact and _gather_timer == 0.0 and not (input.is_local() and _ui_open()):
		_try_gather(pressed)
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
	elif input.is_local() and event.is_action_pressed("drink"):
		drink_best_potion()


## Uses a consumable from the backpack (food, medicine, potion). Returns
## whether it was consumed.
func use_item(id: String) -> bool:
	if not ItemCatalog.is_consumable(id) or inventory.count(id) == 0:
		return false
	var it: Dictionary = ItemCatalog.ITEMS[id]
	var food: float = it.get("food", 0.0)
	var heal: float = it.get("heal", 0.0)
	var cures: bool = it.get("cure", false) and not effects.is_empty()
	var stamina: float = it.get("stamina", 0.0)
	var useful := cures or (heal > 0.0 and survival.health < survival.max_health()) \
		or (food > 0.0 and survival.hunger < Survival.MAX_HUNGER - 0.5) \
		or (stamina > 0.0 and survival.stamina < Survival.MAX_STAMINA)
	if not useful:
		EventBus.notify.emit("No need for %s now." % ItemCatalog.item_name(id))
		return false
	inventory.remove(id, 1)
	if food > 0.0:
		survival.eat(food)
	if heal > 0.0:
		survival.heal(heal)
	if stamina > 0.0:
		survival.restore_stamina(stamina)
	if it.get("cure", false):
		effects.clear()
	EventBus.notify.emit("Used %s." % ItemCatalog.item_name(id))
	return true


## Drinks the best healing item, or an antidote when poisoned.
func drink_best_potion() -> bool:
	var best := ""
	var best_score := 0.0
	for s in inventory.slots:
		if s.is_empty():
			continue
		var it: Dictionary = ItemCatalog.ITEMS[s.id]
		if it.get("food", 0.0) > 0.0 and not it.has("cure") and it.get("heal", 0.0) < 12.0:
			continue
		var score: float = it.get("heal", 0.0)
		if it.get("cure", false) and not effects.is_empty():
			score += 200.0
		if it.get("stamina", 0.0) > 0.0 and survival.stamina < 20.0:
			score += 30.0
		if score > best_score:
			best_score = score
			best = s.id
	if best == "":
		EventBus.notify.emit("No potion to drink.")
		return false
	return use_item(best)


func apply_effect(effect: String, seconds: float) -> void:
	if effect == "" or survival.is_dead():
		return
	if not effects.has(effect):
		EventBus.notify.emit("You are %s!" % ("poisoned" if effect == "poison" else "slowed"))
	effects[effect] = maxf(effects.get(effect, 0.0), seconds)


func _tick_effects(delta: float) -> void:
	for k in effects.keys():
		effects[k] -= delta
		if effects[k] <= 0.0:
			effects.erase(k)
	if effects.has("poison"):
		_poison_acc += delta
		if _poison_acc >= 1.0:
			_poison_acc -= 1.0
			survival.damage(2.0)
	var tint := Color.WHITE
	if effects.has("poison"):
		tint = Color(0.75, 1.15, 0.7)
	elif effects.has("slow"):
		tint = Color(0.75, 0.85, 1.2)
	if _hurt_timer <= 0.0:
		sprite.modulate = tint


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
	var lost := inventory.strip_for_death(survival.insured_slots())
	if lost.is_empty():
		EventBus.notify.emit("You collapsed... and wake up at the camp.")
	else:
		var entry := GameState.add_remains(GameState.area, global_position, lost)
		var here := get_tree().get_first_node_in_group("clearing_world") as ClearingWorld
		if here != null and GameState.area == "clearing":
			here.spawn_remains(entry)
		EventBus.notify.emit("You collapsed... your pack lies where you fell.")
	survival.revive()
	effects.clear()
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
	var weapon := equipment.get_item("weapon")
	var ranged := ItemCatalog.ranged_of(weapon)
	if ranged != "" and _fire(ranged):
		return
	_slash_time = 0.12
	swing(weapon)
	var center := global_position + Vector2(0, -8)
	for node in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = node.global_position + Vector2(0, -6) - center
		if offset.length() <= ATTACK_RANGE and (offset.length() < 12.0 or offset.normalized().dot(facing) > 0.25):
			node.take_damage(weapon_damage(), self)


## Shoots the ranged weapon toward the mouse (or the facing direction). Bows use the best
## arrow in the backpack; returns false (melee bash instead) when out of arrows.
func _fire(kind: String) -> bool:
	var dmg := weapon_damage()
	if kind == "arrow":
		var best := ""
		for s in inventory.slots:
			if not s.is_empty() and ItemCatalog.arrow_of(s.id) > (ItemCatalog.arrow_of(best) if best != "" else 0):
				best = s.id
		if best == "":
			EventBus.notify.emit("Out of arrows!")
			return false
		inventory.remove(best, 1)
		dmg += ItemCatalog.arrow_of(best)
	_attack_timer = ATTACK_COOLDOWN * 1.4
	var dir := input.aim_dir if input.aim_dir != Vector2.ZERO else facing
	facing = _cardinal(dir)
	var from := global_position + Vector2(0, -10) + dir * 6.0
	Projectile.fire(get_parent(), from, dir, kind, 260.0 if kind == "arrow" else 220.0, dmg, "player", self)
	return true


## % chance that the worn shield stops a hit completely.
func block_chance() -> int:
	return equipment.stat("block")


func take_damage(amount: int, source: Node2D = null) -> void:
	if _hurt_timer > 0.0 or survival.is_dead():
		return
	_hurt_timer = HURT_INVULNERABILITY
	if block_chance() > 0 and randi() % 100 < block_chance():
		HitChips.burst(get_parent(), global_position + Vector2(0, -10), [Color8(220, 224, 232), Color8(160, 114, 68)], 5)
		EventBus.notify.emit("Blocked!")
		return
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


func _try_gather(pressed := false) -> void:
	var thing := find_interactable() if pressed else null
	if thing:
		_gather_timer = 0.3
		thing.interact(self)
		return
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
		return
	var station := find_station()
	if station != "" and pressed and input.is_local():
		EventBus.station_used.emit(station)
	elif pressed and input.is_local() and _chest_in_reach():
		EventBus.chest_used.emit()


func _ui_open() -> bool:
	for p in get_tree().get_nodes_in_group("ui_panels"):
		if p.visible:
			return true
	return false


## Crafting station group of the nearest station in reach ("" = none).
func find_station() -> String:
	var probe := global_position + Vector2(0, -6) + facing * PROBE
	var best := ""
	var best_d := REACH
	for group in ItemCatalog.STATIONS:
		if group == "":
			continue
		for node in get_tree().get_nodes_in_group(group):
			var d := _dist_to_tile(probe, node.global_position)
			if d < best_d:
				best_d = d
				best = group
	return best


## Nearest node of the "interactable" group in reach (remains, wells, NPCs...).
func find_interactable() -> Node2D:
	var probe := global_position + Vector2(0, -6) + facing * PROBE
	var best: Node2D = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("interactable"):
		if node.has_method("can_interact") and not node.can_interact(self):
			continue
		var d := _dist_to_tile(probe, node.global_position + Vector2(0, -8))
		if d < best_d:
			best_d = d
			best = node
	return best


func _chest_in_reach() -> bool:
	var probe := global_position + Vector2(0, -6) + facing * PROBE
	for node in get_tree().get_nodes_in_group("chest"):
		if _dist_to_tile(probe, node.global_position) < REACH:
			return true
	return false


func _find_farm_plot() -> Structure:
	var probe := global_position + Vector2(0, -6) + facing * PROBE
	var best: Structure = null
	var best_d := REACH
	for node in get_tree().get_nodes_in_group("farm_plot"):
		var d := _dist_to_tile(probe, node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Distance from a point to the tile-sized box of a structure centred on center.
static func _dist_to_tile(p: Vector2, center: Vector2) -> float:
	var half := TileCatalog.TILE_SIZE / 2.0
	var d := (p - center).abs() - Vector2(half, half)
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()


## Nearest harvestable prop within reach in front of the player.
func find_gatherable() -> Gatherable:
	var probe := global_position + Vector2(0, -6) + facing * PROBE
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
	for group in ItemCatalog.STATIONS:
		if group == "":
			continue
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


func _on_discovered(id: String) -> void:
	var revealed := ItemCatalog.recipes_revealed_by(id, inventory.known)
	GameState.knowns[peer_id] = inventory.known_to_data()
	if input.is_local() and not revealed.is_empty():
		EventBus.notify.emit("%s discovered: %d new recipe%s" % [ItemCatalog.item_name(id), revealed.size(), "" if revealed.size() == 1 else "s"])


func get_save_key() -> String:
	return "player_%d" % peer_id


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"facing": [facing.x, facing.y],
		"inventory": inventory.to_data(),
		"known": inventory.known_to_data(),
		"equipment": equipment.to_data(),
		"survival": survival.to_data(),
	}


func load_save_data(data: Dictionary) -> void:
	inventory.load_data(data.get("inventory", []))
	inventory.load_known(data.get("known", []))
	equipment.load_data(data.get("equipment", {}))
	for worn in equipment.to_data().values():
		if worn is String and worn != "":
			inventory.known[worn] = true
	GameState.knowns[peer_id] = inventory.known_to_data()
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
		# From beside the right shoulder, sweeping down across the front of the body.
		raise = -25.0
		strike = 140.0
		_tool_pivot.position = Vector2(6, -8)
	elif facing == Vector2.UP:
		raise = 110.0
		strike = -40.0
		_tool_pivot.position = Vector2(4, -14)
		_tool_pivot.z_index = -1
	_tool_arm.rotation_degrees = raise - 15.0
	_tool_pivot.visible = true
	sprite.position = SPRITE_OFFSET
	sprite.scale = Vector2.ONE
	_swing = create_tween()
	_swing.tween_property(_tool_arm, "rotation_degrees", raise, 0.07)
	_swing.tween_property(_tool_arm, "rotation_degrees", strike, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swing.parallel().tween_property(sprite, "position", SPRITE_OFFSET + facing * 2.0, 0.09)
	_swing.tween_callback(func() -> void:
		sprite.scale = Vector2(1.08, 0.92)
		if on_impact.is_valid():
			on_impact.call())
	_swing.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	_swing.parallel().tween_property(sprite, "position", SPRITE_OFFSET, 0.1)
	_swing.tween_callback(func() -> void: _tool_pivot.visible = false)
