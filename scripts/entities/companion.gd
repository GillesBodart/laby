class_name Companion
extends CharacterBody2D
## A tamed creature fighting beside its survivor. Its persistent record
## lives in GameState.companions (type, hp, level, mode, downed) and is
## mutated in place, so travel and saves keep it. Modes: "follow" trails the
## owner and engages creatures hunting them; "stay" guards its spot.
## A downed companion limps back to the Clearing and recovers there.

const FOLLOW_DIST := 30.0
const TELEPORT_DIST := 420.0
const GUARD_RADIUS := 140.0
const HIT_COOLDOWN := 1.0
const REGEN := 1.0
const XP_PER_LEVEL := 3

var entry: Dictionary
var owner_player: Player
var _def: Dictionary
var _hit_cd := 0.0
var _foe: Enemy
var _post := Vector2.ZERO
var _regen_acc := 0.0
var _sprite: Sprite2D
var _flash := 0.0


static func spawn(parent: Node, record: Dictionary, owner_node: Player, at: Vector2) -> Companion:
	var c := Companion.new()
	c.entry = record
	c.owner_player = owner_node
	c.position = at
	parent.add_child(c)
	return c


func _ready() -> void:
	add_to_group("companions")
	_def = EnemyCatalog.def(type_id())
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shadow := Sprite2D.new()
	shadow.texture = load("res://assets/sprites/effects/shadow.png")
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	_sprite = Sprite2D.new()
	_sprite.texture = load(EnemyCatalog.sprite_path(type_id()))
	var tex_size := _sprite.texture.get_size()
	_sprite.position.y = 2.0 - tex_size.y / 2.0
	shadow.scale = Vector2.ONE * clampf(tex_size.x / 26.0, 0.5, 1.8)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = minf(float(_def.radius), 7.0)
	shape.position = Vector2(0, -6)
	add_child(shape)
	_post = global_position


func type_id() -> String:
	return entry.type


func level() -> int:
	return int(entry.get("level", 1))


func max_hp() -> int:
	return int(entry.max_hp)


func hp() -> int:
	return int(entry.hp)


func is_staying() -> bool:
	return entry.get("mode", "follow") == "stay"


func damage() -> int:
	return int(Taming.companion_damage(type_id()) * (1.0 + 0.15 * (level() - 1)))


func speed() -> float:
	return maxf(float(_def.speed) * 1.6, 150.0)


func set_mode(mode: String) -> void:
	entry.mode = mode
	_post = global_position


func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	var anchor := _post if is_staying() else owner_player.global_position
	if not is_staying() and global_position.distance_to(anchor) > TELEPORT_DIST:
		global_position = anchor + Vector2(-16, 8)
	if _foe == null or not is_instance_valid(_foe) or _foe._dead or _foe.global_position.distance_to(anchor) > GUARD_RADIUS * 1.5:
		_foe = _find_foe(anchor)
	var desired := Vector2.ZERO
	if _foe:
		var to := _foe.global_position - global_position
		var reach := _foe.hit_radius() + 14.0
		if to.length() > reach:
			desired = to.normalized() * speed()
		elif _hit_cd == 0.0:
			_strike(_foe)
	else:
		var slot := maxi(owner_player.companions().find(self), 0)
		var target := anchor + (Vector2(-14 + 28 * (slot % 2), 10 + 12 * (slot / 2)) if not is_staying() else Vector2.ZERO)
		var to := target - global_position
		if to.length() > (FOLLOW_DIST if not is_staying() else 4.0):
			desired = to.normalized() * minf(speed(), to.length() * 5.0)
		_regen_acc += REGEN * delta
		if _regen_acc >= 1.0 and hp() < max_hp():
			entry.hp = mini(hp() + 1, max_hp())
			_regen_acc = 0.0
	velocity = desired
	move_and_slide()
	if absf(velocity.x) > 4.0 and int(_def.face) != 0:
		_sprite.flip_h = (velocity.x > 0.0) == (int(_def.face) < 0)
	_sprite.modulate = Color(1.6, 0.6, 0.6) if _flash > 0.0 else Color.WHITE
	queue_redraw()


## Nearest creature hunting the owner (or menacing the guarded spot).
func _find_foe(anchor: Vector2) -> Enemy:
	var best: Enemy = null
	var best_d := GUARD_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en == null or en._dead or en.is_hidden() or en._def.temper == "passive":
			continue
		if en._target == null and not en._provoked:
			continue
		var d := en.global_position.distance_to(anchor)
		if d < best_d:
			best_d = d
			best = en
	return best


func _strike(foe: Enemy) -> void:
	_hit_cd = HIT_COOLDOWN
	var tw := create_tween()
	var lunge := (foe.global_position - global_position).normalized() * 5.0
	tw.tween_property(_sprite, "offset", lunge, 0.08)
	tw.tween_property(_sprite, "offset", Vector2.ZERO, 0.12)
	var killed := foe.hp <= damage()
	foe.take_damage(damage(), self)
	if killed:
		_gain_xp(1)
	# The foe bites back while they trade blows.
	elif int(foe._def.damage) > 0 and randf() < 0.45:
		take_damage(int(foe._def.damage))


func _gain_xp(n: int) -> void:
	entry.xp = int(entry.get("xp", 0)) + n
	if int(entry.xp) >= XP_PER_LEVEL * level():
		entry.xp = 0
		entry.level = level() + 1
		entry.max_hp = int(entry.max_hp * 1.12) + 1
		entry.hp = entry.max_hp
		EventBus.notify.emit("%s grows stronger (level %d)." % [display_name(), level()])


func display_name() -> String:
	return String(entry.get("name", _def.name))


func take_damage(amount: int, _source: Node2D = null) -> void:
	entry.hp = hp() - maxi(amount, 1)
	_flash = 0.15
	if hp() <= 0:
		entry.hp = 0
		if GameState.companion_permadeath:
			GameState.companions.erase(entry)
			EventBus.notify.emit("%s has fallen. The Maze keeps it." % display_name())
			Sound.play("death", global_position)
			HitChips.burst(get_parent(), global_position + Vector2(0, -8), [Color8(200, 200, 200), Color8(140, 140, 150)], 10)
			queue_free()
			return
		entry.downed = true
		if GameState.area == "clearing":
			EventBus.notify.emit("%s is downed and rests by the campfire." % display_name())
		else:
			EventBus.notify.emit("%s is downed and limps back to the Clearing." % display_name())
		HitChips.burst(get_parent(), global_position + Vector2(0, -8), [Color8(200, 200, 200), Color8(140, 140, 150)], 7)
		EventBus.companion_downed.emit(entry)
		queue_free()


func _draw() -> void:
	# Green collar pip marks a friend; a small bar shows wounds.
	var top := _sprite.position.y - _sprite.texture.get_size().y / 2.0 - 3.0
	draw_rect(Rect2(-2, top - 1, 4, 3), Color8(30, 40, 20))
	draw_rect(Rect2(-1, top, 2, 1), Color8(120, 220, 90) if not is_staying() else Color8(240, 200, 80))
	if hp() < max_hp():
		var w := 14.0
		draw_rect(Rect2(-w / 2.0, top - 5, w, 2), Color8(30, 20, 20))
		draw_rect(Rect2(-w / 2.0, top - 5, w * hp() / max_hp(), 2), Color8(120, 220, 90))
