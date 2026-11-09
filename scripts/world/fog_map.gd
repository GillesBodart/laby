class_name FogMap
extends RefCounted
## Pure-data fog of war: which cells of an area the player has explored.

var size: Vector2i
var _cells: PackedByteArray
## Explored cells whose walls may have moved since (the maze shifted).
var _unsure: PackedByteArray
## Last maze shift (night index) this map was brought up to date with.
var shift := 0


func _init(map_size: Vector2i = Vector2i.ZERO) -> void:
	size = map_size
	_cells = PackedByteArray()
	_cells.resize(size.x * size.y)
	_unsure = PackedByteArray()
	_unsure.resize(size.x * size.y)


func is_explored(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y \
			and _cells[cell.y * size.x + cell.x] == 1


## Marks every cell within radius of center as explored; returns how many are new.
func reveal(center: Vector2i, radius: int) -> int:
	var added := 0
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var c := Vector2i(x, y)
			if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
				continue
			if Vector2(c - center).length() > radius + 0.5:
				continue
			var i := c.y * size.x + c.x
			_unsure[i] = 0
			if _cells[i] == 0:
				_cells[i] = 1
				added += 1
	return added


func is_uncertain(cell: Vector2i) -> bool:
	return is_explored(cell) and _unsure[cell.y * size.x + cell.x] == 1


## Flags the explored cells of rect as outdated (walls moved there).
func mark_uncertain(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if is_explored(Vector2i(x, y)):
				_unsure[y * size.x + x] = 1


func uncertain_count() -> int:
	var n := 0
	for v in _unsure:
		n += v
	return n


func explored_count() -> int:
	var n := 0
	for v in _cells:
		n += v
	return n


func explored_fraction() -> float:
	return float(explored_count()) / maxf(size.x * size.y, 1.0)


func to_data() -> Dictionary:
	return {"w": size.x, "h": size.y, "bits": Marshalls.raw_to_base64(_cells),
		"unsure": Marshalls.raw_to_base64(_unsure), "shift": shift}


static func from_data(data: Dictionary) -> FogMap:
	var fog := FogMap.new(Vector2i(int(data.get("w", 0)), int(data.get("h", 0))))
	var bytes := Marshalls.base64_to_raw(String(data.get("bits", "")))
	if bytes.size() == fog._cells.size():
		fog._cells = bytes
	var unsure := Marshalls.base64_to_raw(String(data.get("unsure", "")))
	if unsure.size() == fog._unsure.size():
		fog._unsure = unsure
	fog.shift = int(data.get("shift", 0))
	return fog
