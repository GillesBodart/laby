class_name Glyphs
extends RefCounted
## The maze speaks in glyphs (pure data). Every sector holds four glyph
## stones (see LabyrinthGenerator.glyph_spots); deeper meanings need Lore,
## the Scholar's "glyph insight". Each decoded stone gives a concrete hint
## (applied by the labyrinth scene) and a fragment of the maze's story.
## Landmarks are the fixed statues and machines used to find your way.

## What each stone of a sector reveals, by index.
const HINTS := ["shift", "route", "key", "lore"]
## Lore (glyph insight) needed to read each stone.
const REQUIRED_LORE := [0, 0, 1, 2]

const HINT_TEXT := {
	"shift": "The walls move when the sun dies. These marks name the passages that will turn tonight (see the map).",
	"route": "A line of arrows: the old builders' way to the heart of this place. The route appears on your map.",
	"key": "A keyhole and a beast's eye. The guardian's den and its key are marked on your map.",
	"lore": "A list of names carved and crossed out. The great markers of this sector are shown on your map.",
}

## The story, one fragment per sector (the fourth stone).
const STORY := {
	"labyrinth": "\"Subjects adapt. Walls adjust. Observe, record, repeat.\" Someone built this on purpose.",
	"overgrowth": "\"The gardens were meant to feed the watchers. Now the gardens feed on the walls.\"",
	"desert": "\"Heat test 41: subjects ration water when they are made to choose.\" The sand hides the rest.",
	"ice": "\"Cold sleep failed. Those who woke kept walking north.\" Frost fills the last line.",
	"volcano": "\"The engines must never stop. The engines are the walls.\" The glyph is warm to the touch.",
	"hell": "\"Final phase: a door that opens only for those who stayed together.\"",
}

const LANDMARKS := {
	"statue_angel": {"name": "Winged Watcher", "text": "A stone figure with folded wings. Its eyes are worn smooth by countless glances."},
	"statue_dragon": {"name": "Coiled Drake", "text": "A drake curled around a pillar. Someone scratched tally marks on its tail."},
	"statue_guardian": {"name": "Stone Sentinel", "text": "A helmeted guard with a broken spear. It faces the way out, or so the tallies claim."},
	"statue_hero": {"name": "Nameless Hero", "text": "A survivor in stone, arm raised. The plaque is blank, as if waiting for a name."},
	"statue_sword": {"name": "Planted Blade", "text": "A huge sword driven into the floor. Moss grows only on its southern side."},
	"statue_twins": {"name": "The Twins", "text": "Two figures back to back, one smiling, one not. They never seem to move. Never."},
	"column": {"name": "Marked Pillar", "text": "A lone pillar covered in chalk arrows from many hands. Most of them point at each other."},
	"old_engine": {"name": "Old Engine", "text": "Cogs as tall as you, cold and rusted. Sometimes, at night, it ticks."},
}


static func index_of(glyph_id: String) -> int:
	return int(glyph_id.get_slice("_", glyph_id.get_slice_count("_") - 1))


static func sector_of(glyph_id: String) -> String:
	return glyph_id.substr(0, glyph_id.rfind("_"))


static func hint(glyph_id: String) -> String:
	return HINTS[index_of(glyph_id) % HINTS.size()]


static func required_lore(glyph_id: String) -> int:
	return REQUIRED_LORE[index_of(glyph_id) % REQUIRED_LORE.size()]


## Text shown once read (and kept in the journal).
static func text(glyph_id: String) -> String:
	var h := hint(glyph_id)
	if h == "lore":
		return "%s %s" % [STORY.get(sector_of(glyph_id), ""), HINT_TEXT.lore]
	return HINT_TEXT[h]


static func landmark_name(type: String) -> String:
	return LANDMARKS.get(type, {}).get("name", type.capitalize())


static func landmark_text(type: String) -> String:
	return LANDMARKS.get(type, {}).get("text", "")
