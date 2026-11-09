class_name Landmark
extends StaticBody2D
## A fixed point of the shifting maze: a statue or old machine to find your
## way by (kind "landmark"), or a glyph stone to decode (kind "glyph").
## Both log to the journal (see Glyphs, GameState.journal).

const LANDMARK_XP := 10
const GLYPH_XP := 40

var kind := "landmark"
## Landmark type (statue_angel...) or glyph id (labyrinth_0...).
var id := ""
var cell: Vector2i
var _sprite := Sprite2D.new()


static func create(landmark_kind: String, landmark_id: String, at: Vector2i) -> Landmark:
	var l := Landmark.new()
	l.kind = landmark_kind
	l.id = landmark_id
	l.cell = at
	return l


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("landmarks")
	collision_mask = 0
	position = ClearingWorld.cell_center(cell) + Vector2(0, 12)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 10)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -5)
	add_child(col)
	add_child(_sprite)
	_refresh()


func _refresh() -> void:
	var path := "res://assets/sprites/props/landmark_%s.png" % id
	if kind == "glyph":
		path = "res://assets/sprites/props/glyph_stone%s.png" % ("_read" if is_read() else "")
	_sprite.texture = load(path)
	_sprite.offset = Vector2(0, -_sprite.texture.get_height() / 2.0)


func is_read() -> bool:
	return GameState.in_journal("glyphs", id)


func display_name() -> String:
	return Glyphs.landmark_name(id) if kind == "landmark" else "Glyph stone"


func can_interact(_player: Node) -> bool:
	return true


func interact_hint() -> String:
	if kind == "landmark":
		return "Examine the %s" % display_name()
	return "Read the glyphs" if not is_read() else "Glyph stone (read)"


func interact(player: Node) -> void:
	if kind == "landmark":
		if GameState.log_journal("places", id) and player.has_method("gain_xp"):
			player.gain_xp(LANDMARK_XP)
		EventBus.notify.emit("%s. %s" % [display_name(), Glyphs.landmark_text(id)])
		return
	if is_read():
		EventBus.notify.emit(Glyphs.text(id))
		return
	var lore := 0
	if "survival" in player and player.survival != null:
		lore = int(player.survival.bonus("lore"))
	var need := Glyphs.required_lore(id)
	if lore < need:
		EventBus.notify.emit("The carvings are too strange to read. (Needs glyph insight %d, the Scholar's path.)" % need)
		return
	GameState.log_journal("glyphs", id)
	if player.has_method("gain_xp"):
		player.gain_xp(GLYPH_XP)
	_refresh()
	HitChips.burst(get_parent(), global_position + Vector2(0, -14), [Color8(150, 240, 200), Color8(90, 180, 150)], 10)
	EventBus.notify.emit(Glyphs.text(id))
