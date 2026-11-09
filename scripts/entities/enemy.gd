class_name Enemy
extends CharacterBody2D
## A creature of the forest or the labyrinth. Stats and behaviour come from
## EnemyCatalog. A small state machine drives every attack style:
## melee bites, charges, pounces, area slams, ranged volleys, hit-and-run,
## ambushes, suicide blasts, summoners and blinking phantoms. Shield bearers
## block blows from the front; flank them or strike after they attack.

enum S { WANDER, CHASE, WINDUP, ACTION, RECOVER, FLEE, HIDDEN, FUSE }

const KNOCKBACK := 140.0
const KNOCK_DECAY := 700.0
const SLEEP_DIST := 720.0
const WANDER_RADIUS := 72.0
const LEASH := 1.8
const GUARD_TURN := 3.2
const GUARD_DOT := 0.35
const REVEAL_DIST := 52.0
const LIGHT_WARD := 110.0
const ELITE_SHARD_CHANCE := 0.35
const EFFECT_TIME := 4.0
const WINDUP := {"melee": 0.28, "ambush": 0.12, "blink": 0.22, "hit_run": 0.08, "charge": 0.55,
	"pounce": 0.35, "slam": 0.7, "ranged": 0.4, "summon": 0.6}

var type_id := "grub"
var hp := 1
var max_hp := 1
var _def: Dictionary
var _state := S.WANDER
var _timer := 0.0
var _cooldown := 0.0
var _summon_cd := 0.0
var _knock := Vector2.ZERO
var _flash := 0.0
var _dead := false
var _home := Vector2.ZERO
var _wander_to := Vector2.ZERO
var _target: Player
var _provoked := false
var _dash := Vector2.ZERO
var _dash_hit := false
var _action := ""
var _guard := Vector2.DOWN
var _bar := 0.0
var _sprite_y := -14.0
var _flee_from := Vector2.ZERO
var _summons: Array = []
var _regen_acc := 0.0
var _volley_cd := 3.0
## Night raider (see Settlement.raid_size): marches on the camp, hits players
## it meets and wrecks structures in its way.
var raider := false
var camp := Vector2.ZERO
var _siege: Structure = null

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision


func setup(id: String) -> void:
	type_id = id
	_def = EnemyCatalog.def(id)
	hp = _def.hp
	max_hp = _def.hp


func _ready() -> void:
	if _def.is_empty():
		setup(type_id)
	add_to_group("enemies")
	if Taming.tier(type_id) >= 0:
		add_to_group("interactable")
	sprite.texture = load(EnemyCatalog.sprite_path(type_id))
	# Feet on the node origin whatever the creature's size; shadow follows its width.
	var tex_size := sprite.texture.get_size()
	_sprite_y = 2.0 - tex_size.y / 2.0
	sprite.position.y = _sprite_y
	var shadow := get_node_or_null("Shadow") as Sprite2D
	if shadow:
		shadow.scale = Vector2.ONE * clampf(tex_size.x / 26.0, 0.5, 1.8)
	var shape := CircleShape2D.new()
	shape.radius = _def.radius
	collision.shape = shape
	if _def.phasing:
		collision_mask = 0
	_home = global_position
	_wander_to = _home
	if _def.attack == "ambush":
		_state = S.HIDDEN
	_timer = randf_range(0.0, 2.0)


func hit_radius() -> float:
	return _def.radius


func is_hidden() -> bool:
	return _state == S.HIDDEN


# ------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if _dead:
		return
	var near := _nearest_player(SLEEP_DIST)
	if near == null and not raider:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_summon_cd = maxf(_summon_cd - delta, 0.0)
	_timer -= delta
	_bar = maxf(_bar - delta, 0.0)
	if _def.regen > 0.0 and hp < max_hp:
		_regen_acc += _def.regen * delta
		if _regen_acc >= 1.0:
			hp = mini(hp + int(_regen_acc), max_hp)
			_regen_acc = fmod(_regen_acc, 1.0)
	var desired := Vector2.ZERO
	if not _def.volley.is_empty() and _target and is_instance_valid(_target) and _state != S.WANDER:
		_volley_cd -= delta
		if _volley_cd <= 0.0:
			_volley_cd = _def.volley.get("every", 5.0)
			_fire_volley()
	match _state:
		S.WANDER:
			desired = _raid() if raider else _wander()
		S.HIDDEN:
			if global_position.distance_to(near.global_position) < REVEAL_DIST:
				_reveal(near)
		S.CHASE:
			desired = _chase()
		S.WINDUP:
			if _timer <= 0.0:
				_perform()
		S.ACTION:
			desired = _dash
			_check_dash_hit()
			if _timer <= 0.0 or (get_slide_collision_count() > 0 and _timer < 0.25):
				_enter(S.RECOVER, 0.9 if _action == "charge" else 0.5)
		S.RECOVER:
			if _timer <= 0.0:
				_enter(S.CHASE, 0.0)
		S.FLEE:
			desired = (global_position - _flee_from).normalized() * _def.speed * 1.15
			if _timer <= 0.0:
				_enter(S.CHASE if _hostile() else S.WANDER, 0.0)
		S.FUSE:
			if _timer <= 0.0:
				_explode()
				return
	_update_guard(delta)
	_update_look(desired)
	velocity = desired + _knock
	_knock = _knock.move_toward(Vector2.ZERO, KNOCK_DECAY * delta)
	move_and_slide()
	queue_redraw()


func _enter(s: S, t: float) -> void:
	_state = s
	_timer = t


func _night() -> bool:
	var p := TimeSystem.phase()
	return p == DayClock.Phase.NIGHT or p == DayClock.Phase.DUSK


func _hostile() -> bool:
	return _def.temper != "passive" and (_provoked or EnemyCatalog.is_hostile(type_id, _night()))


## Night hunters shy from light: a held torch, or a campfire / standing torch
## near their prey. Provoking them breaks the spell.
func _warded(p: Node2D) -> bool:
	if _def.temper != "nocturnal" or _provoked:
		return false
	if p.has_method("holds_light") and p.holds_light():
		return true
	for group in ["campfire", "standing_torch"]:
		for n in get_tree().get_nodes_in_group(group):
			if n.global_position.distance_to(p.global_position) < LIGHT_WARD:
				return true
	return false


func _wander() -> Vector2:
	if _def.temper == "passive":
		var p := _nearest_player(56.0)
		if p and p.velocity.length() > 20.0:
			_flee_from = p.global_position
			_enter(S.FLEE, 1.2)
			return Vector2.ZERO
	elif _hostile():
		var t := _nearest_player(_def.aggro)
		if t and not _warded(t):
			_target = t
			_enter(S.CHASE, 0.0)
			return Vector2.ZERO
	if _timer <= 0.0:
		_timer = randf_range(1.5, 4.0)
		_wander_to = _home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * WANDER_RADIUS
	var to := _wander_to - global_position
	if to.length() < 4.0:
		return Vector2.ZERO
	return to.normalized() * _def.speed * 0.4


func _chase() -> Vector2:
	if _target == null or not is_instance_valid(_target) or _target.survival.is_dead() \
			or global_position.distance_to(_target.global_position) > _def.aggro * LEASH or not _hostile() \
			or _warded(_target):
		_target = _nearest_player(_def.aggro) if _hostile() else null
		if _target and _warded(_target):
			_target = null
		if _target == null:
			if not raider:
				_home = global_position
			_enter(S.WANDER, 0.5)
			return Vector2.ZERO
	var to := _target.global_position - global_position
	var dist := to.length()
	var dir := to.normalized()
	var speed: float = _def.speed
	match _def.attack:
		"charge", "pounce":
			var reach := 150.0 if _def.attack == "charge" else 96.0
			if _cooldown == 0.0 and dist < reach and dist > _def.range:
				_dash = dir
				_windup(_def.attack)
				return Vector2.ZERO
			if dist <= _def.range:
				if _cooldown == 0.0:
					_windup("melee")
				return Vector2.ZERO
		"slam":
			if dist <= _def.range:
				if _cooldown == 0.0:
					_windup("slam")
				return Vector2.ZERO
		"ranged", "summon":
			if _def.attack == "summon" and _summon_cd == 0.0 and _alive_summons() < _def.summon_max and dist < _def.range:
				_windup("summon")
				return Vector2.ZERO
			if _cooldown == 0.0 and dist <= _def.range:
				_windup("ranged")
				return Vector2.ZERO
			if dist < _def.keep * 0.7:
				return -dir * speed
			if dist < _def.keep * 1.15:
				return dir.orthogonal() * speed * 0.35 * (1.0 if int(Time.get_ticks_msec() / 1500) % 2 == 0 else -1.0)
		"explode":
			if dist <= _def.range + 6.0:
				_enter(S.FUSE, 0.8)
				return Vector2.ZERO
		"blink":
			if _cooldown == 0.0 and dist > 44.0 and dist < _def.aggro:
				_windup("blink")
				return Vector2.ZERO
			if dist <= _def.range:
				if _cooldown == 0.0:
					_windup("melee")
				return Vector2.ZERO
		_:
			if dist <= _def.range:
				if _cooldown == 0.0:
					_windup("hit_run" if _def.attack == "hit_run" else "melee")
				return Vector2.ZERO
	return dir * speed


func _windup(action: String) -> void:
	_action = action
	_enter(S.WINDUP, WINDUP.get(action, 0.3))


func _perform() -> void:
	var t := _target
	if t == null or not is_instance_valid(t):
		_enter(S.CHASE, 0.0)
		return
	_cooldown = _def.cooldown
	match _action:
		"charge", "pounce":
			var mult := 3.4 if _action == "charge" else 4.2
			_dash = _dash * maxf(_def.speed, 40.0) * mult
			_dash_hit = false
			_enter(S.ACTION, 0.55 if _action == "charge" else 0.32)
			return
		"slam":
			HitChips.burst(get_parent(), global_position, [Color8(150, 120, 90), Color8(110, 90, 70), Color8(200, 180, 150)], 12)
			for p in GameState.players.values():
				if global_position.distance_to(p.global_position) <= _def.blast:
					_hit(p, _def.damage)
			_enter(S.RECOVER, 0.8)
			return
		"ranged":
			_shoot(t)
			_enter(S.RECOVER, 0.3)
			return
		"summon":
			_summon_cd = _def.cooldown * 3.0
			for i in 1 + int(randf() < 0.5):
				_summon()
			if not _def.projectile.is_empty():
				_cooldown = 0.0
			_enter(S.RECOVER, 0.5)
			return
		"blink":
			_blink(t)
			_cooldown = 0.0
			_windup("melee")
			_timer = 0.35
			return
	if global_position.distance_to(t.global_position) <= _def.range + 10.0:
		_hit(t, _def.damage)
	if _action == "hit_run":
		_flee_from = t.global_position
		_enter(S.FLEE, 0.9)
	else:
		_enter(S.RECOVER, 0.35)


func _hit(p: Player, amount: int) -> void:
	p.take_damage(amount, self)
	if _def.effect != "":
		p.apply_effect(_def.effect, EFFECT_TIME)


func _check_dash_hit() -> void:
	if _dash_hit:
		return
	for p in GameState.players.values():
		if global_position.distance_to(p.global_position) <= _def.radius + 12.0:
			_dash_hit = true
			_hit(p, _def.damage)
			return


func _shoot(t: Player) -> void:
	var pr: Dictionary = _def.projectile
	if pr.is_empty():
		return
	var from := global_position + Vector2(0, -10)
	var aim := (t.global_position + Vector2(0, -8) - from).normalized()
	var n: int = pr.get("count", 1)
	var spread: float = pr.get("spread", 0.0)
	for i in n:
		var a := 0.0 if n == 1 else lerpf(-spread, spread, i / float(n - 1))
		Projectile.fire(get_parent(), from, aim.rotated(a), pr.kind, pr.speed, _def.damage, "enemy", self, pr.get("effect", _def.effect))


## Boss ring attack: `count` projectiles fanned over +-spread around the target.
func _fire_volley() -> void:
	var v: Dictionary = _def.volley
	var from := global_position + Vector2(0, -12)
	var aim := (_target.global_position - from).normalized()
	var n: int = v.get("count", 8)
	var spread: float = v.get("spread", PI)
	for i in n:
		var a := lerpf(-spread, spread, i / float(n)) if spread >= PI - 0.01 else lerpf(-spread, spread, i / float(maxi(n - 1, 1)))
		Projectile.fire(get_parent(), from, aim.rotated(a), v.kind, v.speed, int(_def.damage * 0.6), "enemy", self, v.get("effect", ""))
	HitChips.burst(get_parent(), from, Projectile.COLORS.get(v.kind, Projectile.COLORS.arrow), 10)


func _alive_summons() -> int:
	_summons = _summons.filter(func(w): return w.get_ref() != null)
	return _summons.size()


func _summon() -> void:
	if _def.summon == "" or _alive_summons() >= _def.summon_max:
		return
	var e: Enemy = load("res://scenes/world/props/enemy.tscn").instantiate()
	e.setup(_def.summon)
	e.position = position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	e._provoked = true
	e._target = _target
	get_parent().add_child(e)
	e._enter(S.CHASE, 0.0)
	_summons.append(weakref(e))
	HitChips.burst(get_parent(), e.global_position, [Color8(120, 200, 90), Color8(80, 60, 40)], 6)


func _blink(t: Player) -> void:
	var space := get_world_2d().direct_space_state
	for off in [-t.facing * 30.0, t.facing.orthogonal() * 30.0, -t.facing.orthogonal() * 30.0]:
		var spot: Vector2 = t.global_position + off
		var q := PhysicsPointQueryParameters2D.new()
		q.position = spot + Vector2(0, -6)
		q.collision_mask = 1
		if space.intersect_point(q, 1).is_empty():
			HitChips.burst(get_parent(), global_position, [Color8(150, 236, 220), Color8(60, 80, 90)], 6)
			global_position = spot
			HitChips.burst(get_parent(), global_position, [Color8(150, 236, 220), Color8(60, 80, 90)], 6)
			return


func _explode() -> void:
	HitChips.burst(get_parent(), global_position, [Color8(250, 220, 120), Color8(220, 110, 50), Color8(120, 200, 90)], 16)
	for p in GameState.players.values():
		if global_position.distance_to(p.global_position) <= _def.blast:
			_hit(p, _def.damage)
	_dead = true
	queue_free()


func _reveal(p: Player) -> void:
	_target = p
	_provoked = true
	_cooldown = 0.0
	_enter(S.CHASE, 0.0)
	HitChips.burst(get_parent(), global_position, [Color8(90, 150, 60), Color8(140, 130, 110)], 6)


func _nearest_player(radius: float) -> Player:
	var best: Player = null
	var best_d := radius
	for p in GameState.players.values():
		if not is_instance_valid(p) or p.survival.is_dead():
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Turns this creature into a raider heading for `camp_pos`.
func make_raider(camp_pos: Vector2) -> void:
	raider = true
	camp = camp_pos
	_provoked = true
	add_to_group("raiders")


func _raid() -> Vector2:
	var t := _nearest_player(_def.aggro)
	if t:
		_target = t
		_enter(S.CHASE, 0.0)
		return Vector2.ZERO
	if _siege == null or not is_instance_valid(_siege) or _siege.is_queued_for_deletion():
		_siege = _nearest_structure()
	var goal := _siege.global_position if _siege else camp
	var to := goal - global_position
	if _siege and to.length() < _def.radius + 24.0:
		if _cooldown == 0.0:
			_cooldown = _def.cooldown
			_siege.damage(int(_def.damage) + 2)
		return Vector2.ZERO
	if to.length() < 8.0:
		return Vector2.ZERO
	return to.normalized() * _def.speed * 0.8


func _nearest_structure() -> Structure:
	var best: Structure = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("structures"):
		if s is Structure and s.max_hp() > 0 and not s.is_queued_for_deletion():
			var d: float = global_position.distance_squared_to(s.global_position)
			if d < best_d:
				best_d = d
				best = s
	return best


# ------------------------------------------------------------- damage

## `from` is where the blow came from (defaults to the source's position).
func take_damage(amount: int, source: Node2D = null, from := Vector2.INF) -> void:
	if _dead:
		return
	if from == Vector2.INF and source:
		from = source.global_position
	var blocked := false
	if _guarding() and from != Vector2.INF and _guard.dot((from - global_position).normalized()) > GUARD_DOT:
		amount = int(ceil(amount * (1.0 - _def.shield)))
		blocked = true
	amount = maxi(amount - _def.armor, 1)
	hp -= amount
	_flash = 0.12
	_bar = 4.0
	if blocked:
		HitChips.burst(get_parent(), global_position + Vector2(0, -12), [Color8(220, 224, 232), Color8(150, 156, 170)], 5)
	Sound.play("block" if blocked else "hit", global_position)
	if from != Vector2.INF:
		_knock = (global_position - from).normalized() * KNOCKBACK * (0.3 if blocked else 1.0)
	var attacker := _attacker(source)
	if attacker:
		_target = attacker
	if _state == S.HIDDEN:
		_reveal(_target)
	if _def.temper == "passive":
		_flee_from = from if from != Vector2.INF else global_position
		_enter(S.FLEE, 2.5)
	elif _state == S.WANDER or (_state == S.FLEE and _hostile()):
		_provoked = true
		if _target:
			_enter(S.CHASE, 0.0)
	_provoked = _provoked or _def.temper != "passive"
	if hp <= 0:
		_die(attacker)


## The survivor credited for a hit: the player, or the owner of a companion.
func _attacker(source: Node2D) -> Player:
	if source is Player:
		return source
	if source is Companion:
		return source.owner_player
	return null


# ------------------------------------------------------------- taming

## Weakened (or gentle) creatures accept their favourite food from a survivor.
func can_interact(_p: Node) -> bool:
	return not _dead and Taming.receptive(type_id, hp, max_hp)


func interact_hint() -> String:
	return "Tame %s (%s)" % [_def.name, ItemCatalog.item_name(Taming.favourite(type_id))]


func interact(p: Player) -> void:
	tame(p)


## Feeds the creature; on success it becomes the survivor's companion.
func tame(p: Player) -> bool:
	var food := Taming.favourite(type_id)
	var why := Taming.refusal(type_id, hp, max_hp, p.survival, p.inventory.count(food) > 0, GameState.party_of(p.peer_id).size())
	if why != "":
		EventBus.notify.emit(why)
		return false
	p.inventory.remove(food, 1)
	_dead = true
	var record := GameState.add_companion(type_id, p.peer_id)
	record.hp = maxi(hp, int(record.max_hp / 2))
	HitChips.burst(get_parent(), global_position + Vector2(0, -10), [Color8(240, 120, 150), Color8(255, 220, 230)], 8)
	Companion.spawn(get_parent(), record, p, global_position)
	Sound.play("tame", global_position, 0.0)
	EventBus.notify.emit("The %s eats from your hand. It will follow you." % _def.name)
	p.gain_xp(int(_def.xp))
	GameState.log_journal("creatures", type_id, 0)
	queue_free()
	return true


func _guarding() -> bool:
	return _def.shield > 0.0 and _state != S.ACTION and _state != S.RECOVER


func _die(killer: Player) -> void:
	_dead = true
	HitChips.burst(get_parent(), global_position + Vector2(0, -8), [Color8(150, 40, 40), Color8(90, 30, 30), Color8(200, 200, 200)], 9)
	Sound.play("death", global_position)
	if killer:
		var got := PackedStringArray()
		for d in _def.drops:
			if randf() > d.chance:
				continue
			var n := randi_range(d.min, d.max)
			if n > 0:
				killer.inventory.add(d.id, n)
				got.append("+%d %s" % [n, ItemCatalog.item_name(d.id)])
		var shards := 2 if _def.boss else (1 if _def.elite and randf() < ELITE_SHARD_CHANCE else 0)
		if shards > 0:
			killer.inventory.add(Survival.RESPEC_ITEM, shards)
			got.append("+%d %s" % [shards, ItemCatalog.item_name(Survival.RESPEC_ITEM)])
		EventBus.notify.emit("%s defeated%s" % [_def.name, (": " + ", ".join(got)) if not got.is_empty() else ""])
		killer.gain_xp(_def.xp)
	GameState.log_journal("creatures", type_id)
	if _def.boss:
		GameState.defeat_boss(type_id)
	queue_free()


# ------------------------------------------------------------- visuals

func _update_guard(delta: float) -> void:
	if _target and is_instance_valid(_target) and _def.shield > 0.0:
		var want := (_target.global_position - global_position).normalized()
		var a := _guard.angle_to(want)
		_guard = _guard.rotated(clampf(a, -GUARD_TURN * delta, GUARD_TURN * delta))


func _update_look(desired: Vector2) -> void:
	var look_x := desired.x
	if _target and is_instance_valid(_target) and _state != S.FLEE and _state != S.WANDER:
		look_x = _target.global_position.x - global_position.x
	if _def.face != 0 and absf(look_x) > 0.5:
		sprite.flip_h = (look_x < 0.0) == (_def.face > 0)
	var mod := Color.WHITE
	if _flash > 0.0:
		_flash -= get_physics_process_delta_time()
		mod = Color(1.8, 1.8, 1.8)
	elif _state == S.WINDUP:
		mod = Color(1.5, 1.15, 0.7)
	elif _state == S.FUSE:
		mod = Color(2.0, 2.0, 1.4) if int(_timer * 12.0) % 2 == 0 else Color.WHITE
	elif _state == S.RECOVER and _action == "charge":
		mod = Color(0.8, 0.8, 0.9)
	if _state == S.HIDDEN:
		mod.a = 0.3
	elif _def.phasing:
		mod.a = 0.75
	sprite.modulate = mod
	var bob := 0.0
	if velocity.length() > 5.0 and _state != S.ACTION:
		bob = -absf(sin(Time.get_ticks_msec() * 0.012)) * 1.5
	sprite.position.y = _sprite_y + round(bob)


func _draw() -> void:
	if _guarding() and _target and _state != S.HIDDEN:
		var a := _guard.angle()
		draw_arc(Vector2(0, -8), _def.radius + 5.0, a - 0.7, a + 0.7, 6, Color(0.85, 0.88, 0.95, 0.55), 2.0)
	if (_bar > 0.0 or _def.elite or _def.boss) and _state != S.HIDDEN and hp < max_hp:
		var w := 20.0 if not (_def.elite or _def.boss) else (48.0 if _def.boss else 28.0)
		var r := Rect2(-w / 2.0, _sprite_y * 2.0 - 6.0, w, 3.0)
		draw_rect(r, Color8(27, 20, 16))
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2((w - 2.0) * clampf(float(hp) / max_hp, 0.0, 1.0), 1.0)),
			Color8(206, 62, 62) if not (_def.elite or _def.boss) else (Color8(190, 90, 230) if _def.boss else Color8(232, 170, 60)))
