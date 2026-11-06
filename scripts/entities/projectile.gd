class_name Projectile
extends Node2D
## A thrown or shot missile (arrows, spit, bolts...). Flies straight, stops
## at walls and hits the first body of the opposing team it reaches.
## team "enemy" hurts players, team "player" hurts creatures.

const HIT_RADIUS := 9.0
const COLORS := {
	"arrow": [Color8(120, 84, 52), Color8(200, 200, 210), Color8(236, 236, 236)],
	"bone": [Color8(236, 228, 204), Color8(170, 160, 140), Color8(250, 246, 236)],
	"spit": [Color8(120, 200, 70), Color8(70, 140, 40), Color8(200, 250, 140)],
	"web": [Color8(236, 236, 246), Color8(170, 170, 190), Color8(255, 255, 255)],
	"bolt": [Color8(150, 200, 255), Color8(70, 110, 230), Color8(240, 250, 255)],
	"orb": [Color8(200, 110, 240), Color8(110, 50, 160), Color8(250, 210, 255)],
	"thorn": [Color8(90, 150, 60), Color8(50, 90, 36), Color8(170, 220, 120)],
	"javelin": [Color8(150, 110, 70), Color8(190, 194, 202), Color8(236, 236, 240)],
}

var kind := "arrow"
var team := "enemy"
var damage := 5
var effect := ""
var velocity := Vector2.ZERO
var life := 1.6
var shooter: Node2D
var _t := 0.0


static func fire(parent: Node, from: Vector2, dir: Vector2, p_kind: String, p_speed: float,
		p_damage: int, p_team: String, p_shooter: Node2D, p_effect := "") -> Projectile:
	var p := Projectile.new()
	p.kind = p_kind
	p.team = p_team
	p.damage = p_damage
	p.effect = p_effect
	p.velocity = dir.normalized() * p_speed
	p.shooter = p_shooter
	p.life = clampf(260.0 / maxf(p_speed, 1.0), 0.8, 2.4)
	p.global_position = from
	p.z_index = 2
	parent.add_child(p)
	p.global_position = from
	return p


func _physics_process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var step := velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		HitChips.burst(get_parent(), hit.position, COLORS.get(kind, COLORS.arrow), 4)
		queue_free()
		return
	global_position += step
	if team == "enemy":
		for p in GameState.players.values():
			if is_instance_valid(p) and not p.survival.is_dead() and global_position.distance_to(p.global_position + Vector2(0, -8)) < HIT_RADIUS:
				p.take_damage(damage, self)
				if effect != "":
					p.apply_effect(effect, 4.0)
				_impact()
				return
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			var r: float = e.hit_radius() if e.has_method("hit_radius") else 8.0
			if global_position.distance_to(e.global_position + Vector2(0, -8)) < r + 4.0:
				e.take_damage(damage, shooter if is_instance_valid(shooter) else null, global_position - velocity.normalized() * 20.0)
				_impact()
				return
	queue_redraw()


func _impact() -> void:
	HitChips.burst(get_parent(), global_position, COLORS.get(kind, COLORS.arrow), 5)
	queue_free()


func _draw() -> void:
	var c: Array = COLORS.get(kind, COLORS.arrow)
	var a := velocity.angle()
	draw_set_transform(Vector2.ZERO, a, Vector2.ONE)
	match kind:
		"arrow", "javelin":
			var n := 7.0 if kind == "arrow" else 10.0
			draw_rect(Rect2(-n, -0.5, n * 2.0 - 3.0, 1.0), c[0])
			draw_rect(Rect2(n - 3.0, -1.5, 3.0, 3.0), c[1])
			draw_rect(Rect2(n - 1.0, -0.5, 1.0, 1.0), c[2])
			if kind == "arrow":
				draw_rect(Rect2(-n, -2.0, 3.0, 1.0), c[2])
				draw_rect(Rect2(-n, 1.0, 3.0, 1.0), c[2])
		"bone":
			draw_set_transform(Vector2.ZERO, _t * 14.0, Vector2.ONE)
			draw_rect(Rect2(-4, -1, 8, 2), c[0])
			draw_rect(Rect2(-5, -2, 2, 4), c[2])
			draw_rect(Rect2(3, -2, 2, 4), c[2])
		"spit":
			draw_circle(Vector2.ZERO, 3.5, c[1])
			draw_circle(Vector2(-0.5, -0.5), 2.5, c[0])
			draw_rect(Rect2(-1, -2, 1, 1), c[2])
			draw_circle(Vector2(-6, 0), 1.5, Color(c[0], 0.6))
		"web":
			draw_set_transform(Vector2.ZERO, _t * 6.0, Vector2.ONE)
			for i in 4:
				var d := Vector2.RIGHT.rotated(i * PI / 4.0) * 5.0
				draw_line(-d, d, c[0], 1.0)
			draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 8, c[1], 1.0)
		"bolt":
			var flick := 1.0 if int(_t * 30.0) % 2 == 0 else -1.0
			draw_polyline(PackedVector2Array([Vector2(-7, 0), Vector2(-3, -2 * flick), Vector2(1, 2 * flick), Vector2(6, 0)]), c[1], 2.0)
			draw_polyline(PackedVector2Array([Vector2(-7, 0), Vector2(-3, -2 * flick), Vector2(1, 2 * flick), Vector2(6, 0)]), c[2], 1.0)
		"orb":
			draw_circle(Vector2.ZERO, 4.5, Color(c[1], 0.7))
			draw_circle(Vector2.ZERO, 3.0, c[0])
			draw_rect(Rect2(-1, -2, 2, 2), c[2])
		"thorn":
			draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(-4, -2.5), Vector2(-2, 0), Vector2(-4, 2.5)]), c[0])
			draw_line(Vector2(-2, 0), Vector2(5, 0), c[2], 1.0)
		_:
			draw_circle(Vector2.ZERO, 3.0, c[0])
