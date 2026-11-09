class_name HitChips
extends Node2D
## Short burst of pixel chips (wood, stone, leaves) when a prop is struck.

const LIFETIME := 0.45
const GRAVITY := 260.0

var _chips: Array = [] # each: [position, velocity, color, size]
var _age := 0.0


static func burst(parent: Node, at: Vector2, colors: Array, count := 7) -> void:
	var fx := HitChips.new()
	fx.z_index = 5
	fx.position = at
	for i in count:
		var dir := Vector2.from_angle(randf_range(-PI * 0.95, -PI * 0.05))
		fx._chips.append([Vector2.ZERO, dir * randf_range(40.0, 95.0), colors[i % colors.size()], 1 + randi() % 2])
	parent.add_child(fx)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for c in _chips:
		c[1].y += GRAVITY * delta
		c[0] += c[1] * delta
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / LIFETIME
	for c in _chips:
		var col: Color = c[2]
		col.a = minf(fade * 1.6, 1.0)
		draw_rect(Rect2(c[0].round(), Vector2(c[3], c[3])), col)
