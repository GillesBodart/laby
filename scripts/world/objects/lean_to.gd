class_name LeanTo
extends Node2D
## A rough shelter of poles and hides in the ring outside the Clearing gate.
## Shut out at night, a survivor can huddle here until the gates open at
## dawn: time skips to DAWN_START and it costs food and water, no rest.

const TEXTURE_PATH := "res://assets/sprites/environment/landmarks/lean_to.png"


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("lean_to")
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://assets/sprites/effects/shadow.png")
	shadow.scale = Vector2(1.8, 1.2)
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(TEXTURE_PATH)
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0 + 2.0)
	add_child(sprite)


func interact_hint() -> String:
	return "Huddle in the lean-to until dawn"


func interact(p: Node) -> void:
	rest(p)


## Why `p` cannot wait for dawn here ("" if they can).
static func blocker(p: Player) -> String:
	if TimeSystem.phase() != DayClock.Phase.NIGHT:
		return "Not now: the lean-to is for nights shut out of the Clearing"
	if p.hostiles_near():
		return "Something prowls nearby: you dare not shut your eyes"
	return ""


## Waits for dawn: returns true if the night was skipped.
static func rest(p: Player) -> bool:
	var why := blocker(p)
	if why != "":
		EventBus.notify.emit(why)
		return false
	p.pass_night(DayClock.DAWN_START)
	p.survival.rough_night()
	EventBus.notify.emit("A long, cold night under the hides. The gates grind open at dawn.")
	return true
