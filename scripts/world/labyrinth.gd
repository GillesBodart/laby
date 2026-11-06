extends World
## First labyrinth sector (Stone biome), reached through the Clearing's north
## gate. Walking back into the vestibule returns to the Clearing.


func make_layout() -> ClearingLayout:
	return LabyrinthGenerator.generate(GameState.world_seed)


func greet() -> void:
	EventBus.notify.emit("The Labyrinth. Stone walls swallow the light...")


func portal_message() -> String:
	if TimeSystem.phase() == DayClock.Phase.NIGHT:
		return "Back at the Clearing... but the gates are shut for the night."
	return "You return to the Clearing."
