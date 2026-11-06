class_name Gatherable
extends StaticBody2D
## Harvestable prop (tree, rock). Each hit deals damage; the matching tool
## doubles it. When depleted it yields items and is removed from the world.

signal depleted(gatherable: Gatherable)

@export var item_id := "wood"
@export var yield_amount := 3
@export var max_hits := 4
@export var tool_kind := "axe"

var cell := Vector2i.ZERO
var _hits_left := 0


func _ready() -> void:
	add_to_group("gatherable")
	_hits_left = max_hits


func hit(player: Player) -> void:
	var dmg := 2 if player.inventory.has_tool(tool_kind) else 1
	_hits_left -= dmg
	_shake()
	if _hits_left > 0:
		return
	var left := player.inventory.add(item_id, yield_amount)
	EventBus.notify.emit("+%d %s" % [yield_amount - left, ItemCatalog.item_name(item_id)])
	if left > 0:
		EventBus.notify.emit("Backpack full!")
	depleted.emit(self)
	queue_free()


func _shake() -> void:
	var sprite := get_node_or_null("Sprite") as Node2D
	if sprite == null:
		return
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", 1.0, 0.04)
	tw.tween_property(sprite, "position:x", -1.0, 0.04)
	tw.tween_property(sprite, "position:x", 0.0, 0.04)
