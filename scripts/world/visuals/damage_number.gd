class_name DamageNumber
extends Node2D
## A small number popping up from whoever got hit: white on creatures, red on
## the player, grey "0" when a block soaked it all. It hops, then fades.

const LIFETIME := 0.7
const RISE := 22.0
const FONT_SIZE := 30
const OUTLINE := Color8(14, 11, 14)

var _text := ""
var _color := Color.WHITE
var _age := 0.0
var _drift := 0.0
var _font: Font


static func pop(parent: Node, at: Vector2, amount: int, color: Color) -> void:
	if parent == null:
		return
	var fx := DamageNumber.new()
	fx._text = str(amount)
	fx._color = color
	fx._drift = randf_range(-8.0, 8.0)
	fx.z_index = 20
	fx.position = at
	parent.add_child(fx)


func _ready() -> void:
	_font = ThemeDB.get_project_theme().default_font


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	# A quick hop up, then a slow float.
	var y := -RISE * (1.0 - pow(1.0 - minf(t * 1.8, 1.0), 2.0)) - t * 6.0
	var pos := Vector2(roundf(_drift * t - _font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0), roundf(y))
	var col := _color
	col.a = clampf((1.0 - t) * 2.5, 0.0, 1.0)
	var ink := OUTLINE
	ink.a = col.a
	draw_string_outline(_font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, ink)
	draw_string(_font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)
