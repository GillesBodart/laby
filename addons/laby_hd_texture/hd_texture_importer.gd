@tool
extends EditorImportPlugin
## Imports a PNG drawn at HD_SCALE x the gameplay resolution (see
## tools/smooth_art) as an HdTexture: sprites, atlas regions, tile sets and
## UI rects keep their sizes in game units while the GPU samples the
## full-resolution image.

const HD_SCALE := 2
const HdTexture := preload("res://scripts/util/hd_texture.gd")


func _get_importer_name() -> String:
	return "laby.hd_texture"


func _get_visible_name() -> String:
	return "Laby HD Texture"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["png"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Texture2D"


func _get_priority() -> float:
	return 2.0


func _get_import_order() -> int:
	return 0


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [{"name": "hd_scale", "default_value": HD_SCALE}]


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _can_import_threaded() -> bool:
	return false


func _import(source_file: String, save_path: String, options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var img := Image.load_from_file(source_file)
	if img == null or img.is_empty():
		return ERR_FILE_CORRUPT
	var scale: int = maxi(int(options.get("hd_scale", HD_SCALE)), 1)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var full := PortableCompressedTexture2D.new()
	full.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	var tex := HdTexture.new()
	tex.source = full
	tex.hd_scale = scale
	return ResourceSaver.save(tex, "%s.%s" % [save_path, _get_save_extension()])
