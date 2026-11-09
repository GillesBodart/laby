extends CanvasModulate
## Tints the world according to the time of day.


func _process(_delta: float) -> void:
	color = LightingCurve.color_at(TimeSystem.minute_of_day())
