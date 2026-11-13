class_name GateLatch
extends Node2D
## Invisible handle on a Clearing gate: E on a shut gate knocks for the
## guard (see ClearingGates.knock).

var gates: ClearingGates


func _ready() -> void:
	add_to_group("interactable")


func can_interact(_p: Node) -> bool:
	return gates != null and not gates.is_open


func interact_hint() -> String:
	var guard := Settlement.guard(GameState.survivors)
	return "Knock: %s opens the gate" % Settlement.name_of(guard) if not guard.is_empty() else "Gate shut until dawn"


func interact(_p: Node) -> void:
	gates.knock()
