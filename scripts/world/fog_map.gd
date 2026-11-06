class_name FogMap
extends RefCounted
## Pure-data fog of war: which cells of an area the player has explored.

var size: Vector2i
var _cells: PackedByteArray


func _init(map_size: Vector2i = Vector2i.ZERO) -> void:
	size = map_size
	_cells = PackedByteArray()
	_cells.resize(size.x * size.y)


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
			if _cells[i] == 0:
				_cells[i] = 1
				added += 1
	return added


func explored_count() -> int:
	var n := 0
	for v in _cells:
		n += v
	return n


func explored_fraction() -> float:
	return float(explored_count()) / maxf(size.x * size.y, 1.0)


func to_data() -> Dictionary:
	return {"w": size.x, "h": size.y, "bits": Marshalls.raw_to_base64(_cells)}


static func from_data(data: Dictionary) -> FogMap:
	var fog := FogMap.new(Vector2i(int(data.get("w", 0)), int(data.get("h", 0))))
	var bytes := Marshalls.base64_to_raw(String(data.get("bits", "")))
	if bytes.size() == fog._cells.size():
		fog._cells = bytes
	return fog
