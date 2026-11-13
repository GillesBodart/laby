extends Node
## Accessibility settings, kept in user://settings.cfg ([access] section):
## - text size: scales the always-on HUD (bars, clock, goal, prompts, notices,
##   item feed) and the floating damage numbers;
## - colour-blind palette: swaps the red/green pairs that carry meaning on
##   their own (map markers, companion pips, durability bars) for an
##   Okabe-Ito style orange / sky-blue / yellow set.

signal changed

const SCALES := [1.0, 1.25, 1.5]
const SCALE_NAMES := ["Normal", "Large", "Huge"]

## Meaningful colours: key -> [normal, colour-blind].
const PALETTE := {
	"danger": [Color8(230, 70, 60), Color8(230, 110, 20)],
	"resource": [Color8(110, 210, 90), Color8(86, 180, 233)],
	"good": [Color8(96, 200, 88), Color8(86, 180, 233)],
	"warn": [Color8(232, 196, 72), Color8(240, 228, 66)],
	"bad": [Color8(214, 72, 56), Color8(213, 94, 0)],
	"ally": [Color8(120, 220, 90), Color8(86, 180, 233)],
	"ally_stay": [Color8(240, 200, 80), Color8(240, 228, 66)],
}

var settings_path := "user://settings.cfg"
## Index into SCALES.
var text_size := 0
var colorblind := false


func _ready() -> void:
	load_settings()


func text_scale() -> float:
	return SCALES[text_size]


func text_size_name() -> String:
	return SCALE_NAMES[text_size]


func color(key: String) -> Color:
	return PALETTE[key][1 if colorblind else 0]


func set_text_size(i: int) -> void:
	text_size = posmod(i, SCALES.size())
	save_settings()
	changed.emit()


func set_colorblind(on: bool) -> void:
	colorblind = on
	save_settings()
	changed.emit()


## Scales what `ci` draws next by the text scale, keeping `anchor` in place
## (reset with ci.draw_set_transform_matrix(Transform2D.IDENTITY)).
func scale_about(ci: CanvasItem, anchor: Vector2) -> void:
	var s := text_scale()
	ci.draw_set_transform(anchor * (1.0 - s), 0.0, Vector2(s, s))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("access", "text_size", text_size)
	cfg.set_value("access", "colorblind", colorblind)
	cfg.save(settings_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		text_size = clampi(int(cfg.get_value("access", "text_size", 0)), 0, SCALES.size() - 1)
		colorblind = bool(cfg.get_value("access", "colorblind", false))
