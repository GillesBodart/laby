class_name Farming
extends RefCounted
## Pure crop-growth rules for farm plots (no nodes). Time is the DayClock's
## total_minutes; `planted` is the minute a crop was sown, or NOT_PLANTED.

const NOT_PLANTED := -1.0
## Default growth time: a third of an in-game day (4 real minutes at the default day length).
const GROW_MINUTES := 480.0
const EMPTY := 0
const GROWING := 1
const RIPE := 2
## Crop sown in plots saved before crops could be chosen.
const DEFAULT_CROP := "berry"

## Plantable crops, in picker order. Sowing uses one `seed` item; harvest gives
## min..max of `yield`. `shape` picks the plant art (bush, root, stalk, flower,
## cap, tree); its fruit takes the yield item's colour.
const CROPS := {
	"berry": {"seed": "berry", "yield": "berry", "min": 3, "max": 5, "minutes": 480.0, "xp": 3, "shape": "bush"},
	"blueberry": {"seed": "blueberry", "yield": "blueberry", "min": 3, "max": 5, "minutes": 480.0, "xp": 3, "shape": "bush"},
	"wheat": {"seed": "wheat", "yield": "wheat", "min": 3, "max": 6, "minutes": 360.0, "xp": 3, "shape": "stalk"},
	"carrot": {"seed": "carrot", "yield": "carrot", "min": 2, "max": 4, "minutes": 420.0, "xp": 3, "shape": "root"},
	"potato": {"seed": "potato", "yield": "potato", "min": 3, "max": 5, "minutes": 600.0, "xp": 4, "shape": "root"},
	"herb": {"seed": "herb", "yield": "herb", "min": 2, "max": 4, "minutes": 300.0, "xp": 3, "shape": "flower"},
	"cotton": {"seed": "cotton", "yield": "cotton", "min": 2, "max": 4, "minutes": 540.0, "xp": 4, "shape": "flower"},
	"flower": {"seed": "petals", "yield": "petals", "min": 2, "max": 4, "minutes": 300.0, "xp": 2, "shape": "flower"},
	"reed": {"seed": "reed", "yield": "reed", "min": 3, "max": 5, "minutes": 360.0, "xp": 2, "shape": "stalk"},
	"mushroom": {"seed": "mushroom", "yield": "mushroom", "min": 2, "max": 4, "minutes": 420.0, "xp": 3, "shape": "cap"},
	"glowcap": {"seed": "glowcap", "yield": "glowcap", "min": 1, "max": 3, "minutes": 720.0, "xp": 6, "shape": "cap"},
	"apple": {"seed": "apple", "yield": "apple", "min": 3, "max": 6, "minutes": 1440.0, "xp": 8, "shape": "tree"},
	"shadow_orchid": {"seed": "shadow_petal", "yield": "shadow_petal", "min": 1, "max": 2, "minutes": 1440.0, "xp": 10, "shape": "flower"},
}


static func crop_ids() -> Array:
	return CROPS.keys()


static func grow_minutes(crop: String) -> float:
	return CROPS.get(crop, CROPS[DEFAULT_CROP]).minutes


static func stage(planted: float, now: float, minutes := GROW_MINUTES) -> int:
	if planted < 0.0:
		return EMPTY
	return RIPE if now - planted >= minutes else GROWING


static func minutes_left(planted: float, now: float, minutes := GROW_MINUTES) -> float:
	return maxf(minutes - (now - planted), 0.0)


## Crops the inventory can sow right now.
static func plantable(inv: RefCounted) -> Array:
	var out := []
	for id in CROPS:
		if inv.count(CROPS[id].seed) > 0:
			out.append(id)
	return out
