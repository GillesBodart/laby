@tool
class_name HdTexture
extends Texture2D
## A texture drawn at `hd_scale` x its logical size. Sizes, sprite offsets,
## atlas regions and tile regions stay in logical (gameplay) pixels; drawing
## maps them onto the high-resolution `source`, so the art renders smooth
## without any gameplay code knowing about the resolution.

@export var source: Texture2D
@export var hd_scale := 2


func _get_width() -> int:
	return source.get_width() / hd_scale if source else 1


func _get_height() -> int:
	return source.get_height() / hd_scale if source else 1


func _get_rid() -> RID:
	return source.get_rid() if source else RID()


func _has_alpha() -> bool:
	return source.has_alpha() if source else false


func _is_pixel_opaque(x: int, y: int) -> bool:
	if source == null:
		return false
	var img := source.get_image()
	var p := Vector2i(x * hd_scale, y * hd_scale)
	return img != null and Rect2i(Vector2i.ZERO, img.get_size()).has_point(p) and img.get_pixelv(p).a > 0.5


## The art at its logical size, for code that rebuilds textures from pixels.
func _get_image() -> Image:
	if source == null:
		return null
	var img := source.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.resize(_get_width(), _get_height(), Image.INTERPOLATE_LANCZOS)
	return img


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	source.draw_rect(to_canvas_item, Rect2(pos, get_size()), false, modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if tile:
		source.draw_rect_region(to_canvas_item, rect, Rect2(Vector2.ZERO, rect.size * hd_scale), modulate, transpose)
	else:
		source.draw_rect(to_canvas_item, rect, false, modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	var r := Rect2(src_rect.position * hd_scale, src_rect.size * hd_scale)
	source.draw_rect_region(to_canvas_item, rect, r, modulate, transpose, clip_uv)
