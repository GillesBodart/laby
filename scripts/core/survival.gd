class_name Survival
extends RefCounted
## Pure-data survival model: health, hunger, thirst, body temperature,
## stamina and XP/levels.
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
const MAX_THIRST := 100.0
## Thirst lasts about a day in mild sectors; heat doubles it.
const THIRST_DRAIN := 0.13
const DEHYDRATE_DAMAGE := 1.5
const REGEN_MIN_THIRST := 30.0
## Body temperature -100 (freezing) .. +100 (burning). Each point of unprotected climate stress
## pushes it 55 further from 0; past +-TEMP_HARM it hurts.
const TEMP_PER_STRESS := 55.0
const TEMP_RATE := 9.0
const TEMP_HARM := 99.0
const TEMP_DAMAGE := 2.5

## Skills live in SkillGraph (radial passive tree); `skills` holds node ranks.
## Respec at a Skill Altar costs RESPEC_ITEM (a Bound resource).
const RESPEC_ITEM := "memory_shard"

var health := MAX_HEALTH

var hunger := MAX_HUNGER
var stamina := MAX_STAMINA
var xp := 0
var level := 1
var skill_points := 0
## skill node id -> rank (see SkillGraph).
var skills := {}
## Cached SkillGraph.totals(skills).
var _bonus := {}
## Extra max health from worn gear (set by the Player, not saved here).
var bonus_health := 0.0
var thirst := MAX_THIRST
## Thirst only drains once enabled (the players have reached the desert).
var thirst_enabled := false
var temperature := 0.0
## Seconds left of the Warming Tonic / Cooling Draught buffs.
var warmth := 0.0
var chill := 0.0

var _exhausted := false
var _regen_wait := 0.0


static func xp_for_level(lvl: int) -> int:
	return 20 + 10 * lvl


func rank(id: String) -> int:
	return int(skills.get(id, 0))


## Total skill-graph bonus for a stat ("hp", "dmg", "speed", ...).
func bonus(stat: String) -> int:
	return int(_bonus.get(stat, 0))


func _pct(stat: String) -> float:
	return clampf(1.0 - bonus(stat) / 100.0, 0.1, 2.0)


func max_health() -> float:
	return maxf(MAX_HEALTH + bonus("hp") + bonus_health, 10.0)


## Strength characteristic: grows with levels and skills; every 10 points
## insure one backpack slot (kept on death).
func strength() -> int:
	return 10 + (level - 1) + bonus("strength")


func insured_slots() -> int:
	return mini(strength() / 10, 10)


func damage_bonus() -> int:
	return bonus("dmg")


func speed_multiplier() -> float:
	return maxf(1.0 + bonus("speed") / 100.0, 0.3)


## Multiplier on running and dodge-roll stamina costs.
func stamina_cost_mult() -> float:
	return _pct("run_cost")


## Whether a node can take a rank now: points, max rank, reachability from
## allocated nodes and its world gate (`reached` = GameState.reached).
func can_learn(id: String, reached: Dictionary = {}) -> bool:
	return SkillGraph.has(id) and skill_points >= SkillGraph.cost(id) \
			and rank(id) < SkillGraph.max_rank(id) and SkillGraph.reachable(id, skills) \
			and SkillGraph.gate_open(id, reached)


## Spends skill points on one rank; returns false if not allowed.
func learn(id: String, reached: Dictionary = {}) -> bool:
	if not can_learn(id, reached):
		return false
	var before := max_health()
	skill_points -= SkillGraph.cost(id)
	skills[id] = rank(id) + 1
	_bonus = SkillGraph.totals(skills)
	health = clampf(health + maxf(max_health() - before, 0.0), 0.0, max_health())
	changed.emit()
	return true


## Refunds every allocated rank.
func respec() -> int:
	var refund := 0
	for id in skills:
		if SkillGraph.has(id):
			refund += SkillGraph.cost(id) * int(skills[id])
	skills = {}
	_bonus = {}
	skill_points += refund
	health = minf(health, max_health())
	changed.emit()
	return refund


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
	hunger = maxf(hunger - (HUNGER_DRAIN + (RUN_HUNGER_DRAIN if run_active else 0.0)) * _pct("hunger") * delta, 0.0)
	if run_active:
		stamina = maxf(stamina - RUN_COST * stamina_cost_mult() * delta, 0.0)
		_regen_wait = REGEN_DELAY
		if stamina == 0.0:
			_exhausted = true
	else:
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		if _regen_wait == 0.0:
			stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
			if _exhausted and stamina >= RECOVER_THRESHOLD:
				_exhausted = false
	if thirst_enabled:
		var hot := 2.0 if temperature > 40.0 else 1.0
		thirst = maxf(thirst - THIRST_DRAIN * hot * _pct("thirst") * delta, 0.0)
	if temperature < -40.0:
		hunger = maxf(hunger - HUNGER_DRAIN * 0.5 * delta, 0.0)
	warmth = maxf(warmth - delta, 0.0)
	chill = maxf(chill - delta, 0.0)
	if is_starving():
		damage(STARVE_DAMAGE * delta)
	elif is_dehydrated():
		damage(DEHYDRATE_DAMAGE * delta)
	elif absf(temperature) >= TEMP_HARM:
		damage(TEMP_DAMAGE * delta)
	elif hunger >= REGEN_MIN_HUNGER and (not thirst_enabled or thirst >= REGEN_MIN_THIRST) and health < max_health():
		health = minf(health + REGEN_RATE * (1.0 + bonus("regen") / 100.0) * delta, max_health())
	changed.emit()


func is_dehydrated() -> bool:
	return thirst_enabled and thirst <= 0.0


## Climate stress left after protection: climate -2..+2 against the worn
## warm/cool points (buffs count as 2). Positive = heat, negative = cold.
func climate_stress(climate: int, warm: int, cool: int) -> int:
	if climate > 0:
		return maxi(climate - cool - (2 if chill > 0.0 else 0), 0)
	if climate < 0:
		return -maxi(-climate - warm - (2 if warmth > 0.0 else 0), 0)
	return 0


## Moves the body temperature toward what the climate dictates.
func tick_climate(delta: float, climate: int, warm: int, cool: int) -> void:
	var target := clampf(climate_stress(climate, warm, cool) * TEMP_PER_STRESS, -100.0, 100.0)
	temperature = move_toward(temperature, target, TEMP_RATE * delta)


func drink(amount: float) -> void:
	thirst = minf(thirst + amount, MAX_THIRST)
	changed.emit()


func eat(amount: float) -> void:
	hunger = minf(hunger + amount, MAX_HUNGER)
	changed.emit()


func heal(amount: float) -> void:
	health = minf(health + amount, max_health())
	changed.emit()


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, MAX_STAMINA)
	_exhausted = false
	changed.emit()


func damage(amount: float) -> void:
	if is_dead():
		return
	health = maxf(health - amount, 0.0)
	if is_dead():
		died.emit()


## Full reset of the needs after respawning (XP and levels are kept).
func revive() -> void:
	health = max_health()
	hunger = 60.0
	thirst = 60.0
	temperature = 0.0
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
		"xp": xp, "level": level, "skill_points": skill_points, "skills": skills.duplicate(),
		"thirst": thirst, "temperature": temperature, "warmth": warmth, "chill": chill,
	}


func load_data(data: Dictionary) -> void:
	hunger = clampf(float(data.get("hunger", MAX_HUNGER)), 0.0, MAX_HUNGER)
	stamina = clampf(float(data.get("stamina", MAX_STAMINA)), 0.0, MAX_STAMINA)
	thirst = clampf(float(data.get("thirst", MAX_THIRST)), 0.0, MAX_THIRST)
	temperature = clampf(float(data.get("temperature", 0.0)), -100.0, 100.0)
	warmth = maxf(float(data.get("warmth", 0.0)), 0.0)
	chill = maxf(float(data.get("chill", 0.0)), 0.0)
	xp = int(data.get("xp", 0))
	level = maxi(int(data.get("level", 1)), 1)
	skill_points = int(data.get("skill_points", 0))
	skills = {}
	for k in data.get("skills", {}):
		if SkillGraph.has(k):
			skills[k] = clampi(int(data.skills[k]), 0, SkillGraph.max_rank(k))
	_bonus = SkillGraph.totals(skills)
	health = clampf(float(data.get("health", MAX_HEALTH)), 0.0, max_health())
	_exhausted = false
	_regen_wait = 0.0
	changed.emit()
