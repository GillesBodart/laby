class_name Gatherable
extends StaticBody2D
## Harvestable prop (tree, rock). Each hit deals damage; the matching tool
## doubles it. When depleted it yields items and is removed from the world.

signal depleted(gatherable: Gatherable)

@export var item_id := "wood"
@export var yield_amount := 3
@export var max_hits := 4
@export var tool_kind := "axe"
@export var xp := 4
## Minimum tool tier needed (0 = bare hands work).
@export var min_tier := 0

var cell := Vector2i.ZERO
var _hits_left := 0


func _ready() -> void:
	add_to_group("gatherable")
	_hits_left = max_hits


func hit(player: Player) -> void:
	var tier := player.tool_tier(tool_kind)
	if tier < min_tier:
		EventBus.notify.emit("Needs a better %s" % tool_kind)
		_shake()
		return
	var dmg := 1 + tier
	_hits_left -= dmg
	_shake()
	if is_inside_tree():
		HitChips.burst(get_parent(), global_position + Vector2(0, -10), _chip_colors())
	if _hits_left > 0:
		return
	var amount := yield_amount
	if player.survival.bonus("gather") > 0 and randi() % 100 < player.survival.bonus("gather"):
		amount *= 2
	var left := player.inventory.add(item_id, amount)
	EventBus.notify.emit("+%d %s" % [amount - left, ItemCatalog.item_name(item_id)])
	if left > 0:
		EventBus.notify.emit("Backpack full!")
	player.gain_xp(xp)
	depleted.emit(self)
	queue_free()


## Chip colours: wood for axes, stone plus the ore tint for pickaxes, leaves otherwise.
func _chip_colors() -> Array:
	match tool_kind:
		"axe":
			return [Color8(160, 114, 68), Color8(194, 150, 92), Color8(100, 68, 44)]
		"pickaxe":
			return [Color8(128, 132, 130), Color8(168, 170, 164), ItemCatalog.ITEMS[item_id].color]
	return [Color8(84, 146, 60), Color8(98, 160, 68), Color8(44, 90, 42)]


func _shake() -> void:
	var sprite := get_node_or_null("Sprite") as Node2D
	if sprite == null:
		return
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", 1.0, 0.04)
	tw.tween_property(sprite, "position:x", -1.0, 0.04)
	tw.tween_property(sprite, "position:x", 0.0, 0.04)
