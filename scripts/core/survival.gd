class_name Survival
extends RefCounted
## Pure-data survival model: health, hunger, stamina and XP/levels.
## No nodes; the Player ticks it and the HUD reads it.

signal changed
signal leveled_up(level: int)
signal died

const MAX_HEALTH := 100.0
const MAX_HUNGER := 100.0
const MAX_STAMINA := 100.0
## Hunger lasts about a day and a half of real play (12 min/day).
const HUNGER_DRAIN := 0.09
const RUN_HUNGER_DRAIN := 0.05
const STARVE_DAMAGE := 1.5
const REGEN_RATE := 1.0
const REGEN_MIN_HUNGER := 50.0
const RUN_COST := 24.0
const STAMINA_REGEN := 16.0
const REGEN_DELAY := 0.8
## Once exhausted, running needs this much stamina back.
const RECOVER_THRESHOLD := 25.0

var health := MAX_HEALTH
var hunger := MAX_HUNGER
var stamina := MAX_STAMINA
var xp := 0
var level := 1
var skill_points := 0

var _exhausted := false
var _regen_wait := 0.0


static func xp_for_level(lvl: int) -> int:
	return 20 + 10 * lvl


func can_run() -> bool:
	return stamina > 0.0 and not _exhausted


func is_dead() -> bool:
	return health <= 0.0


func is_starving() -> bool:
	return hunger <= 0.0


## Advances the needs by delta seconds.
func tick(delta: float, moving: bool, running: bool) -> void:
	if is_dead():
		return
	var run_active := running and moving and can_run()
	hunger = maxf(hunger - (HUNGER_DRAIN + (RUN_HUNGER_DRAIN if run_active else 0.0)) * delta, 0.0)
	if run_active:
		stamina = maxf(stamina - RUN_COST * delta, 0.0)
		_regen_wait = REGEN_DELAY
		if stamina == 0.0:
			_exhausted = true
	else:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		if _regen_wait == 0.0:
			stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
			if _exhausted and stamina >= RECOVER_THRESHOLD:
				_exhausted = false
	if is_starving():
		damage(STARVE_DAMAGE * delta)
	elif hunger >= REGEN_MIN_HUNGER and health < MAX_HEALTH:
		health = minf(health + REGEN_RATE * delta, MAX_HEALTH)
	changed.emit()


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, MAX_HUNGER)
	changed.emit()


func damage(amount: float) -> void:
	if is_dead():
		return
	health = maxf(health - amount, 0.0)
	if is_dead():
		died.emit()


## Full reset of the needs after respawning (XP and levels are kept).
func revive() -> void:
	health = MAX_HEALTH
	hunger = 60.0
	stamina = MAX_STAMINA
	_exhausted = false
	_regen_wait = 0.0
	changed.emit()


## Adds XP, returns the number of levels gained (each grants a skill point).
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_for_level(level):
		xp -= xp_for_level(level)
		level += 1
		skill_points += 1
		gained += 1
		leveled_up.emit(level)
	changed.emit()
	return gained


func to_data() -> Dictionary:
	return {
		"health": health, "hunger": hunger, "stamina": stamina,
		"xp": xp, "level": level, "skill_points": skill_points,
	}


func load_data(data: Dictionary) -> void:
	health = clampf(float(data.get("health", MAX_HEALTH)), 0.0, MAX_HEALTH)
	hunger = clampf(float(data.get("hunger", MAX_HUNGER)), 0.0, MAX_HUNGER)
	stamina = clampf(float(data.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	xp = int(data.get("xp", 0))
	level = maxi(int(data.get("level", 1)), 1)
	skill_points = int(data.get("skill_points", 0))
	_exhausted = false
	_regen_wait = 0.0
	changed.emit()
