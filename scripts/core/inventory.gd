class_name Inventory
extends RefCounted
## Fixed-slot stackable inventory (pure data, per player).

signal changed

const DEFAULT_SLOTS := 20

var slots: Array = [] # each: {} or {"id": String, "count": int}


func _init(slot_count: int = DEFAULT_SLOTS) -> void:
	for i in slot_count:
		slots.append({})


func count(id: String) -> int:
	var total := 0
	for s in slots:
		if not s.is_empty() and s.id == id:
			total += s.count
	return total


func has_all(items: Dictionary) -> bool:
	for id in items:
		if count(id) < items[id]:
			return false
	return true


## Adds items; returns the amount that did not fit.
func add(id: String, amount: int) -> int:
	var left := amount
	var cap := ItemCatalog.stack_size(id)
	for s in slots:
		if left == 0:
			break
		if not s.is_empty() and s.id == id and s.count < cap:
			var n := mini(cap - s.count, left)
			s.count += n
			left -= n
	for i in slots.size():
		if left == 0:
			break
		if slots[i].is_empty():
			var n := mini(cap, left)
			slots[i] = {"id": id, "count": n}
			left -= n
	if left != amount:
		changed.emit()
	return left


## Removes items if all are available; returns success.
func remove(id: String, amount: int) -> bool:
	if count(id) < amount:
		return false
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		var s: Dictionary = slots[i]
		if s.is_empty() or s.id != id:
			continue
		var n := mini(s.count, left)
		s.count -= n
		left -= n
		if s.count == 0:
			slots[i] = {}
		if left == 0:
			break
	changed.emit()
	return true


func has_tool(kind: String) -> bool:
	for s in slots:
		if not s.is_empty() and ItemCatalog.tool_of(s.id) == kind:
			return true
	return false


## Highest tier among carried tools of the kind (0 = none; hands only).
func tool_tier(kind: String) -> int:
	var best := 0
	for s in slots:
		if not s.is_empty() and ItemCatalog.tool_of(s.id) == kind:
			best = maxi(best, ItemCatalog.tier_of(s.id))
	return best


## Best attack bonus among carried items.
func best_damage() -> int:
	var best := 0
	for s in slots:
		if not s.is_empty():
			best = maxi(best, ItemCatalog.damage_of(s.id))
	return best


## Best armor value among carried items.
func best_armor() -> int:
	var best := 0
	for s in slots:
		if not s.is_empty():
			best = maxi(best, ItemCatalog.armor_of(s.id))
	return best


func to_data() -> Array:
	return slots.duplicate(true)


func load_data(data: Array) -> void:
	for i in slots.size():
		slots[i] = {}
		if i < data.size() and not (data[i] as Dictionary).is_empty():
			var d: Dictionary = data[i]
			if ItemCatalog.ITEMS.has(d.id):
				slots[i] = {"id": String(d.id), "count": int(d.count)}
	changed.emit()
