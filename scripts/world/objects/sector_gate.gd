class_name SectorGate
extends StaticBody2D
## Sealed stone door blocking a sector's north exit until the players hold
## the needed Keys (see Sectors, GameState.keys). E on it tries to open it.

const TEXTURE_PATH := "res://assets/sprites/environment/landmarks/sector_gate.png"

var keys: Array = []


static func create(rect: Rect2i, needed: Array) -> SectorGate:
	var g := SectorGate.new()
	g.keys = needed
	var t := TileCatalog.TILE_SIZE
	g.position = Vector2((rect.position.x + rect.size.x / 2.0) * t, (rect.position.y + 1) * t)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect.size.x * t, t)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -t / 2.0)
	g.add_child(col)
	return g


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("sector_gate")
	var sprite := Sprite2D.new()
	sprite.texture = load(TEXTURE_PATH)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	add_child(sprite)


func is_open() -> bool:
	return GameState.has_keys(keys)


func interact_hint() -> String:
	return "Open the sealed gate" if is_open() else "Sealed gate (%s)" % _needed_text()


func interact(_player: Node) -> void:
	if is_open():
		_open()
	else:
		EventBus.notify.emit("Sealed. It needs %s." % _needed_text())


## Opens on its own as soon as the Key is earned (the guardian falls nearby).
func _physics_process(_delta: float) -> void:
	if is_open():
		_open()


func _open() -> void:
	set_physics_process(false)
	HitChips.burst(get_parent(), global_position + Vector2(0, -10), [Color8(170, 182, 168), Color8(98, 110, 104)], 14)
	queue_free()


func _needed_text() -> String:
	var missing := keys.filter(func(k): return not GameState.keys.has(k))
	if missing.size() == 1:
		return ItemCatalog.item_name(missing[0])
	return "%d more Keys" % missing.size()
