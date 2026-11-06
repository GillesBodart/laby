class_name LightingCurve
extends RefCounted
## Ambient light colour over the day. Shared by the CanvasModulate and by
## light sources that scale with darkness.

const KEYS := [
	[0, Color(0.16, 0.18, 0.32)],
	[270, Color(0.16, 0.18, 0.32)],
	[340, Color(0.62, 0.5, 0.58)],
	[420, Color(1, 1, 1)],
	[1050, Color(1, 1, 1)],
	[1140, Color(0.95, 0.68, 0.5)],
	[1230, Color(0.16, 0.18, 0.32)],
	[1440, Color(0.16, 0.18, 0.32)],
]


static func color_at(minute_of_day: float) -> Color:
	for i in range(1, KEYS.size()):
		if minute_of_day <= KEYS[i][0]:
			var a: Array = KEYS[i - 1]
			var b: Array = KEYS[i]
			var t := inverse_lerp(float(a[0]), float(b[0]), minute_of_day)
			return (a[1] as Color).lerp(b[1], t)
	return KEYS[-1][1]


## 0 = full daylight, 1 = darkest night.
static func darkness_at(minute_of_day: float) -> float:
	var c := color_at(minute_of_day)
	var night: Color = KEYS[0][1]
	var lum := (c.r + c.g + c.b) / 3.0
	var night_lum := (night.r + night.g + night.b) / 3.0
	return clampf(inverse_lerp(1.0, night_lum, lum), 0.0, 1.0)
