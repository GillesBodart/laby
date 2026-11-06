class_name SpriteFramesBuilder
extends RefCounted
## Builds SpriteFrames from a grid sprite sheet and an animation table:
## { "anim_name": {"row": int, "frames": [col, ...], "fps": float, "loop": bool} }


static func build(texture: Texture2D, frame_size: Vector2i, anims: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name in anims:
		var def: Dictionary = anims[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, def.get("fps", 8.0))
		frames.set_animation_loop(anim_name, def.get("loop", true))
		for col in def.frames:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(col * frame_size.x, def.row * frame_size.y), frame_size)
			frames.add_frame(anim_name, atlas)
	return frames
