class_name Inventory
extends RefCounted
## Fixed-slot stackable inventory (pure data, per player).

signal changed
## First time an item id ever enters this inventory.
signal discovered(id: String)

const DEFAULT_SLOTS := 30

## Each: {} or {"id": String, "count": int}; a used tool or weapon (stack of
## one) also carries "wear": uses spent (see ItemCatalog.durability_of).
var slots: Array = []
## Every item id ever held (id -> true): recipes unlock from these.
var known: Dictionary = {}


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
		discover(id)
		changed.emit()
	return left


## Puts one used tool or weapon in a free slot, keeping its wear; returns 1
## when there was no room (0 = stored).
func add_worn(id: String, wear: int) -> int:
	if wear <= 0:
		return add(id, 1)
	for i in slots.size():
		if slots[i].is_empty():
			slots[i] = {"id": id, "count": 1, "wear": wear}
			discover(id)
			changed.emit()
			return 0
	return 1


## Index of a slot holding the item (the last one, like remove), or -1.
func find_last(id: String) -> int:
	for i in range(slots.size() - 1, -1, -1):
		if not slots[i].is_empty() and slots[i].id == id:
			return i
	return -1


## Spends `uses` of the durability of the item in slot `index`. Returns true
## when it broke (the slot is then emptied).
func wear_slot(index: int, uses := 1) -> bool:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return false
	var s: Dictionary = slots[index]
	var dur := ItemCatalog.durability_of(s.id)
	if dur <= 0:
		return false
	s["wear"] = int(s.get("wear", 0)) + uses
	if int(s.wear) >= dur:
		slots[index] = {}
	changed.emit()
	return slots[index].is_empty()


## Marks an item as seen; returns true the first time.
func discover(id: String) -> bool:
	if known.has(id) or not ItemCatalog.ITEMS.has(id):
		return false
	known[id] = true
	discovered.emit(id)
	return true


func knows(id: String) -> bool:
	return known.has(id)


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


## Takes up to `amount` items out of slot `index`; returns how many were taken.
func take(index: int, amount: int) -> int:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return 0
	var n := mini(amount, int(slots[index].count))
	slots[index].count -= n
	if slots[index].count == 0:
		slots[index] = {}
	changed.emit()
	return n


## Manual reorder: drops slot `from` onto slot `to`. Same items merge into `to`
## (the overflow stays in `from`); anything else swaps places.
func move_slot(from: int, to: int) -> void:
	if from == to or from < 0 or to < 0 or from >= slots.size() or to >= slots.size() or slots[from].is_empty():
		return
	var a: Dictionary = slots[from]
	var b: Dictionary = slots[to]
	if not b.is_empty() and b.id == a.id:
		var n := mini(ItemCatalog.stack_size(a.id) - int(b.count), int(a.count))
		if n > 0:
			b.count += n
			a.count -= n
			if a.count == 0:
				slots[from] = {}
			changed.emit()
			return
	slots[from] = b
	slots[to] = a
	changed.emit()


## Removes up to `amount` items from slot `index` to throw away; returns the
## removed stack ({} when nothing). Bound items cannot be discarded.
func discard(index: int, amount: int) -> Dictionary:
	if index < 0 or index >= slots.size() or slots[index].is_empty() or ItemCatalog.is_bound(slots[index].id):
		return {}
	var id: String = slots[index].id
	var n := take(index, amount)
	return {"id": id, "count": n} if n > 0 else {}


## Moves up to `amount` items of slot `index` into `target`; returns how many moved.
func move_to(target: RefCounted, index: int, amount: int) -> int:
	if index < 0 or index >= slots.size() or slots[index].is_empty():
		return 0
	var id: String = slots[index].id
	var n := mini(amount, int(slots[index].count))
	var moved: int
	if int(slots[index].get("wear", 0)) > 0:
		moved = 1 - target.add_worn(id, int(slots[index].wear))
	else:
		moved = n - target.add(id, n)
	return take(index, moved)


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


## Merges partial stacks and orders slots by category (ItemCatalog.sorts_before).
## The first `keep_first` slots (insured ones) are left untouched.
func sort(keep_first := 0) -> void:
	var totals := {}
	# Used gear keeps its own slot (and wear); everything else merges.
	var worn := []
	for i in range(keep_first, slots.size()):
		var s: Dictionary = slots[i]
		if s.is_empty():
			continue
		if int(s.get("wear", 0)) > 0:
			worn.append(s)
		else:
			totals[s.id] = totals.get(s.id, 0) + int(s.count)
	var ids: Array = totals.keys()
	ids.sort_custom(ItemCatalog.sorts_before)
	var packed := []
	for id in ids:
		var left: int = totals[id]
		var cap := ItemCatalog.stack_size(id)
		while left > 0:
			var n := mini(cap, left)
			packed.append({"id": id, "count": n})
			left -= n
	# Used copies go right after the fresh ones of the same item.
	for s in worn:
		var at := packed.size()
		for k in packed.size():
			if ItemCatalog.sorts_before(s.id, packed[k].id):
				at = k
				break
		packed.insert(at, s)
	for i in range(keep_first, slots.size()):
		var k := i - keep_first
		slots[i] = packed[k] if k < packed.size() else {}
	changed.emit()


## Death rule: empties every slot except the first `keep_first` (insured) ones
## and Bound items, returning the lost stacks.
func strip_for_death(keep_first: int) -> Array:
	var lost := []
	for i in range(keep_first, slots.size()):
		var s: Dictionary = slots[i]
		if s.is_empty() or ItemCatalog.is_bound(s.id):
			continue
		lost.append(s.duplicate())
		slots[i] = {}
	if not lost.is_empty():
		changed.emit()
	return lost


func to_data() -> Array:
	return slots.duplicate(true)


func load_data(data: Array) -> void:
	for i in slots.size():
		slots[i] = {}
		if i < data.size() and not (data[i] as Dictionary).is_empty():
			var d: Dictionary = data[i]
			if ItemCatalog.ITEMS.has(d.id):
				slots[i] = {"id": String(d.id), "count": int(d.count)}
				if int(d.get("wear", 0)) > 0:
					slots[i]["wear"] = int(d.wear)
				known[String(d.id)] = true
	changed.emit()


func known_to_data() -> Array:
	return known.keys()


## Restores discoveries (older saves have none: what is carried counts).
func load_known(ids: Array) -> void:
	for id in ids:
		if ItemCatalog.ITEMS.has(id):
			known[String(id)] = true
