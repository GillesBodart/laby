class_name Remains
extends Node2D
## A dropped backpack left where a survivor fell (see the death rules).
## E takes everything back; the pile vanishes once empty.

const TEXTURE_PATH := "res://assets/sprites/environment/remains.png"

## The GameState.remains entry this pile shows (shared by reference).
var entry: Dictionary


static func create(remains_entry: Dictionary) -> Remains:
	var r := Remains.new()
	r.entry = remains_entry
	r.position = Vector2(remains_entry.pos[0], remains_entry.pos[1])
	return r


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("remains")
	var sprite := Sprite2D.new()
	sprite.texture = load(TEXTURE_PATH)
	sprite.offset = Vector2(0, -8)
	add_child(sprite)


func interact_hint() -> String:
	return "Pick up dropped items" if entry.get("dropped", false) else "Recover your remains"


## Moves every stack that fits into the player's backpack.
func interact(player: Node) -> void:
	var inv: Inventory = player.inventory
	var left := []
	var taken := 0
	for s in entry.items:
		var rest := inv.add(String(s.id), int(s.count))
		taken += int(s.count) - rest
		if rest > 0:
			left.append({"id": s.id, "count": rest})
	entry.items = left
	if left.is_empty():
		GameState.remains.erase(entry)
		EventBus.notify.emit("Picked up the items." if entry.get("dropped", false) else "Recovered your belongings.")
		queue_free()
	elif taken > 0:
		EventBus.notify.emit("Backpack full: some items are still on the pile.")
	else:
		EventBus.notify.emit("Backpack full!")
