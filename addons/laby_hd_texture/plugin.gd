@tool
extends EditorPlugin

const MANIFEST := "res://tools/smooth_art/manifest.json"

var _importer: EditorImportPlugin


func _enter_tree() -> void:
	_importer = preload("res://addons/laby_hd_texture/hd_texture_importer.gd").new()
	add_import_plugin(_importer)
	_reclaim_early_imports()


## Scripts preloading art are parsed before plugins load, so the editor may
## import those PNGs with the stock texture importer and rewrite their
## .import files. Point every HD file listed by tools/smooth_art back at this
## importer.
func _reclaim_early_imports() -> void:
	var manifest_text := FileAccess.get_file_as_string(MANIFEST)
	var manifest: Variant = JSON.parse_string(manifest_text) if manifest_text != "" else null
	if not manifest is Dictionary:
		return
	var stale := PackedStringArray()
	for rel: String in manifest:
		var path := "res://" + rel
		var cfg := ConfigFile.new()
		if cfg.load(path + ".import") != OK:
			continue
		if cfg.get_value("remap", "importer", "") == "laby.hd_texture":
			continue
		var fresh := ConfigFile.new()
		fresh.set_value("remap", "importer", "laby.hd_texture")
		fresh.set_value("remap", "type", "Texture2D")
		var uid: String = cfg.get_value("remap", "uid", "")
		if uid != "":
			fresh.set_value("remap", "uid", uid)
		fresh.save(path + ".import")
		stale.append(path)
	if not stale.is_empty():
		_reimport_after_scan(stale)


func _reimport_after_scan(paths: PackedStringArray) -> void:
	var fs := EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await get_tree().process_frame
	print("laby_hd_texture: reimporting %d early import(s)." % paths.size())
	fs.reimport_files(paths)
