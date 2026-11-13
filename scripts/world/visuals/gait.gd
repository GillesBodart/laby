class_name Gait
extends Node2D
## Procedural body motion layered over a character's or creature's sprite:
## a hop per step, a side-to-side sway and a squash on each footfall, all
## pivoting on the feet (the host's origin), plus slow breathing at rest.
## The sprites are reparented under this node, so their own position, scale
## and offset tweens (lunges, dodges, swings) keep working unchanged.

## Lift at the top of each step, in pixels.
@export var hop := 2.0
## Lean to either side, in degrees, alternating each step.
@export var sway_deg := 4.0
## Squash on footfalls / stretch mid-step (fraction of the height).
@export var squash := 0.07
## Distance travelled per step, in pixels (sets the cadence).
@export var stride := 9.0
@export var min_cadence := 1.8
@export var max_cadence := 6.0
## Breathing amplitude at rest (fraction of the height).
@export var breathe := 0.018
## Hovering creatures drift up and down instead of stepping.
@export var floating := false

## Steps taken (the fractional part is the progress through the current one).
var steps := 0.0
var _move := 0.0
var _time := 0.0


## Wraps `parts` (sprites drawn by `host`) in a new Gait at the host's origin.
static func attach(host: Node2D, parts: Array) -> Gait:
	var g := Gait.new()
	g.name = "Gait"
	g._time = randf() * 10.0
	var at := host.get_child_count()
	for p: Node in parts:
		at = mini(at, p.get_index())
	host.add_child(g)
	host.move_child(g, at)
	for p: Node in parts:
		p.reparent(g, false)
	return g


## Scales the motion to a creature's art: big bodies step slower and lighter
## on the sway, phasing ones hover.
func fit(art_size: Vector2, hovers := false) -> void:
	hop = clampf(art_size.y * 0.07, 1.5, 3.5)
	stride = clampf(art_size.x * 0.4, 7.0, 22.0)
	sway_deg = clampf(130.0 / maxf(art_size.y, 1.0), 1.5, 5.0)
	floating = hovers


## Advances by `delta` for a body moving at `speed` px/s. Pass `phase` (in
## steps, contact at whole numbers) to follow a sprite's own walk cycle.
func advance(delta: float, speed: float, phase := -1.0) -> void:
	_time += delta
	var moving := speed > 4.0
	_move = move_toward(_move, 1.0 if moving else 0.0, delta * 6.0)
	if floating:
		position = Vector2(0.0, -1.5 - 1.5 * sin(_time * 2.2))
		rotation = deg_to_rad(2.5) * sin(_time * 1.3) * (0.4 + 0.6 * _move)
		scale = Vector2.ONE
		return
	if phase >= 0.0:
		steps = phase
	elif moving:
		steps += delta * clampf(speed / stride, min_cadence, max_cadence)
	var k := sin(fposmod(steps, 1.0) * PI)
	position = Vector2(0.0, -hop * k * _move)
	rotation = deg_to_rad(sway_deg) * sin(steps * PI) * _move
	var sy := 1.0 + squash * _move * (1.5 * k - 1.0) + breathe * (1.0 - _move) * sin(_time * 2.6)
	scale = Vector2(1.0 - (sy - 1.0) * 0.6, sy)
