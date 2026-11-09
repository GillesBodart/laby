class_name ItemCatalog
extends RefCounted
## Single table of items and crafting recipes (data only, no nodes).
##
## Item fields: name, stack, color (fallback icon), desc, and optionally
##   tool   - "axe" | "pickaxe" (gathering kind), with tier 1 stone .. 3 iron
##   slot   - equipment slot (see Equipment.SLOTS); weapons and tools default to "weapon"
##   dmg    - bonus attack damage while equipped
##   armor  - damage absorbed per hit while equipped
##   hp     - bonus max health while equipped
##   food   - hunger restored when eaten
##   heal   - health restored when eaten or drunk (H drinks the best potion)
##   cure   - removes poison and slowness when consumed
##   stamina - stamina restored when consumed
##   ranged - projectile fired by a weapon ("arrow" uses arrows from the backpack, "bolt" is free)
##   arrow  - bonus damage of an arrow (ammunition, not equippable)
##   block  - % chance for a shield (offhand) to stop a hit completely
##   bound  - never lost on death (Keys, Relics)

const ITEMS := {
	# --- raw resources
	"wood": {"name": "Wood", "stack": 40, "color": Color8(140, 100, 64), "desc": "Rough logs from the Clearing's trees."},
	"stone": {"name": "Stone", "stack": 40, "color": Color8(150, 154, 148), "desc": "Grey stone. Good for tools and walls."},
	"fiber": {"name": "Fiber", "stack": 40, "color": Color8(150, 176, 84), "desc": "Tough plant fibers from tall grass."},
	"clay": {"name": "Clay", "stack": 40, "color": Color8(176, 112, 80), "desc": "Wet red clay. Fire it into bricks."},
	"coal": {"name": "Coal", "stack": 40, "color": Color8(40, 40, 46), "desc": "Black fuel for the furnace."},
	"copper_ore": {"name": "Copper Ore", "stack": 40, "color": Color8(196, 120, 72), "desc": "Green-streaked ore. Smelt it."},
	"iron_ore": {"name": "Iron Ore", "stack": 40, "color": Color8(168, 140, 130), "desc": "Heavy ore. Needs a copper pickaxe."},
	"crystal": {"name": "Crystal", "stack": 20, "color": Color8(120, 220, 240), "desc": "A humming crystal from deep in the maze."},
	"hide": {"name": "Hide", "stack": 40, "color": Color8(150, 104, 70), "desc": "Tough skin of maze creatures."},
	"bone": {"name": "Bone", "stack": 40, "color": Color8(232, 224, 200), "desc": "Pale bones from stalkers."},
	"berry": {"name": "Berries", "stack": 40, "color": Color8(200, 52, 84), "food": 14.0, "desc": "Sweet wild berries. R eats them (+14 food)."},
	# --- forest resources
	"flint": {"name": "Flint", "stack": 40, "color": Color8(70, 72, 84), "desc": "Glassy black stone that splits into sharp edges."},
	"reed": {"name": "Reed", "stack": 40, "color": Color8(170, 160, 96), "desc": "Hollow stalks. Hats, sandals and arrow shafts."},
	"herb": {"name": "Healing Herb", "stack": 40, "color": Color8(96, 170, 96), "heal": 4.0, "desc": "Bitter leaves that close wounds. Base of salves and potions."},
	"wheat": {"name": "Wild Wheat", "stack": 40, "color": Color8(222, 186, 92), "desc": "Golden grain. Mill it into flour at a stonecutter."},
	"cotton": {"name": "Cotton", "stack": 40, "color": Color8(240, 238, 228), "desc": "Soft bolls. Weave into cloth at a loom."},
	"resin": {"name": "Resin", "stack": 40, "color": Color8(222, 150, 50), "desc": "Sticky amber sap from old stumps."},
	"honey": {"name": "Honey", "stack": 20, "color": Color8(240, 176, 48), "food": 10.0, "heal": 5.0, "desc": "Wild honeycomb (+10 food, +5 health)."},
	"apple": {"name": "Wild Apple", "stack": 40, "color": Color8(206, 52, 46), "food": 12.0, "desc": "Crisp and sour (+12 food)."},
	"carrot": {"name": "Carrot", "stack": 40, "color": Color8(240, 132, 40), "food": 10.0, "desc": "Sweet root (+10 food)."},
	"blueberry": {"name": "Blueberries", "stack": 40, "color": Color8(70, 92, 196), "food": 9.0, "desc": "Tiny and tart (+9 food)."},
	"petals": {"name": "Petals", "stack": 40, "color": Color8(226, 110, 170), "desc": "Bright wildflower petals. Crush into dye."},
	"sand": {"name": "Sand", "stack": 40, "color": Color8(226, 206, 150), "desc": "Fine pale sand. Melts into glass."},
	"egg": {"name": "Wild Egg", "stack": 20, "color": Color8(240, 230, 206), "food": 6.0, "desc": "From a ground nest. Better cooked (+6 food)."},
	"potato": {"name": "Potato", "stack": 40, "color": Color8(180, 140, 86), "food": 8.0, "desc": "Starchy tuber. Bake it (+8 food)."},
	# --- labyrinth resources
	"tin_ore": {"name": "Tin Ore", "stack": 40, "color": Color8(176, 182, 170), "desc": "Pale ore. Alloy with copper into bronze."},
	"silver_ore": {"name": "Silver Ore", "stack": 40, "color": Color8(210, 216, 226), "desc": "Gleaming veins from deeper corridors."},
	"gold_ore": {"name": "Gold Ore", "stack": 40, "color": Color8(236, 196, 70), "desc": "Heavy and warm. Jewellery metal."},
	"quartz": {"name": "Quartz", "stack": 40, "color": Color8(236, 226, 240), "desc": "Milky crystal. Lenses and jewels."},
	"obsidian": {"name": "Obsidian", "stack": 40, "color": Color8(54, 36, 74), "desc": "Volcanic glass, sharper than steel. Needs an iron pickaxe."},
	"sulfur": {"name": "Sulfur", "stack": 40, "color": Color8(230, 216, 70), "desc": "Yellow crust that stinks of eggs."},
	"saltpeter": {"name": "Saltpeter", "stack": 40, "color": Color8(236, 236, 226), "desc": "White salt scraped from damp walls."},
	"glowcap": {"name": "Glowcap", "stack": 40, "color": Color8(90, 220, 210), "food": 3.0, "heal": 6.0, "desc": "Luminous fungus. Potent in potions."},
	"moss": {"name": "Cave Moss", "stack": 40, "color": Color8(84, 130, 64), "desc": "Damp and spongy. Soaks up blood."},
	"vine": {"name": "Vine", "stack": 40, "color": Color8(60, 120, 56), "desc": "Strong creeper. Twists into rope."},
	"scrap": {"name": "Scrap Metal", "stack": 40, "color": Color8(132, 108, 92), "desc": "Rusted plates from forgotten machines."},
	"cog": {"name": "Ancient Cog", "stack": 20, "color": Color8(196, 150, 72), "desc": "A precise brass gear. Who made it?"},
	"shadow_petal": {"name": "Shadow Petal", "stack": 20, "color": Color8(110, 60, 160), "desc": "Petal of an orchid that only grows in darkness."},
	"silk": {"name": "Silk", "stack": 40, "color": Color8(236, 236, 246), "desc": "Strong spider thread."},
	# --- creature parts
	"wool": {"name": "Wool", "stack": 40, "color": Color8(236, 230, 214), "desc": "Thick fleece. Felt it at a loom."},
	"wing_dust": {"name": "Wing Dust", "stack": 40, "color": Color8(214, 190, 240), "desc": "Shimmering scales of insect wings."},
	"slime": {"name": "Slime", "stack": 40, "color": Color8(120, 200, 90), "desc": "Gooey and sticky. Makes glue."},
	"tusk": {"name": "Tusk", "stack": 20, "color": Color8(240, 232, 206), "desc": "Curved boar tusk."},
	"fur": {"name": "Fur", "stack": 40, "color": Color8(118, 84, 56), "desc": "Warm pelt."},
	"shell": {"name": "Shell", "stack": 20, "color": Color8(90, 128, 70), "desc": "Hard carapace. A natural shield."},
	"fang": {"name": "Fang", "stack": 40, "color": Color8(246, 240, 226), "desc": "Sharp predator tooth."},
	"venom_sac": {"name": "Venom Sac", "stack": 20, "color": Color8(130, 200, 60), "desc": "Handle with care. Antidotes and poisons."},
	"chitin": {"name": "Chitin", "stack": 40, "color": Color8(110, 70, 50), "desc": "Light, hard insect plate."},
	"feather": {"name": "Feather", "stack": 40, "color": Color8(70, 70, 86), "desc": "Fletching for arrows."},
	"spores": {"name": "Spores", "stack": 40, "color": Color8(200, 170, 110), "desc": "Puffcap dust. Calms poison."},
	"ectoplasm": {"name": "Ectoplasm", "stack": 20, "color": Color8(150, 236, 220), "desc": "Cold residue of a phantom."},
	"spark_core": {"name": "Spark Core", "stack": 20, "color": Color8(160, 200, 255), "desc": "Crackling heart of a machine spirit."},
	"horn": {"name": "Great Horn", "stack": 10, "color": Color8(220, 206, 170), "desc": "Trophy of a labyrinth brute."},
	"glow_gland": {"name": "Glow Gland", "stack": 20, "color": Color8(200, 250, 110), "desc": "Still glowing faintly."},
	"scale": {"name": "Scale", "stack": 40, "color": Color8(80, 150, 90), "desc": "Overlapping reptile scales."},	# --- materials
	"plank": {"name": "Plank", "stack": 40, "color": Color8(190, 146, 92), "desc": "Cut planks. Used for all building."},
	"stick": {"name": "Stick", "stack": 40, "color": Color8(120, 84, 52), "desc": "Sturdy sticks for handles."},
	"rope": {"name": "Rope", "stack": 40, "color": Color8(196, 170, 108), "desc": "Twisted fiber cord."},
	"brick": {"name": "Brick", "stack": 40, "color": Color8(184, 82, 60), "desc": "Fired clay brick. Cook at a furnace."},
	"copper_ingot": {"name": "Copper Ingot", "stack": 40, "color": Color8(214, 132, 80), "desc": "Smelted copper."},
	"iron_ingot": {"name": "Iron Ingot", "stack": 40, "color": Color8(190, 194, 202), "desc": "Smelted iron."},
	"leather": {"name": "Leather", "stack": 40, "color": Color8(132, 84, 52), "desc": "Cured hide for armor."},
	"torch": {"name": "Torch", "stack": 20, "color": Color8(245, 154, 58), "desc": "Lights the way in the dark."},
	"flour": {"name": "Flour", "stack": 40, "color": Color8(240, 232, 214), "desc": "Milled wheat. Bread and pies."},
	"glass": {"name": "Glass", "stack": 40, "color": Color8(180, 220, 230), "desc": "Molten sand, cooled clear."},
	"glass_vial": {"name": "Glass Vial", "stack": 20, "color": Color8(200, 232, 240), "desc": "Empty flask for potions."},
	"cloth": {"name": "Cloth", "stack": 40, "color": Color8(226, 214, 186), "desc": "Woven cotton."},
	"silk_cloth": {"name": "Silk Cloth", "stack": 40, "color": Color8(236, 236, 250), "desc": "Light and nearly untearable."},
	"felt": {"name": "Felt", "stack": 40, "color": Color8(196, 170, 140), "desc": "Pressed wool."},
	"bronze_ingot": {"name": "Bronze Ingot", "stack": 40, "color": Color8(200, 150, 70), "desc": "Copper and tin alloy."},
	"silver_ingot": {"name": "Silver Ingot", "stack": 40, "color": Color8(220, 226, 236), "desc": "Pure silver."},
	"gold_ingot": {"name": "Gold Ingot", "stack": 40, "color": Color8(240, 200, 70), "desc": "Pure gold."},
	"gunpowder": {"name": "Gunpowder", "stack": 40, "color": Color8(60, 60, 66), "desc": "Sulfur, saltpeter and coal. Explosive."},
	"glue": {"name": "Glue", "stack": 40, "color": Color8(232, 210, 140), "desc": "Resin and slime. Holds bows together."},
	"dye": {"name": "Dye", "stack": 40, "color": Color8(200, 60, 140), "desc": "Vivid colour for fine cloth."},
	"bowstring": {"name": "Bowstring", "stack": 20, "color": Color8(236, 226, 196), "desc": "Waxed cord for bows."},	# --- tools and weapons (tier decides which ores can be mined)
	"stone_axe": {"name": "Stone Axe", "stack": 1, "color": Color8(170, 172, 164), "tool": "axe", "tier": 1, "dmg": 6, "desc": "Chops trees faster. +6 damage."},
	"stone_pickaxe": {"name": "Stone Pickaxe", "stack": 1, "color": Color8(140, 146, 152), "tool": "pickaxe", "tier": 1, "dmg": 4, "desc": "Mines rocks, coal and copper. +4 damage."},
	"stone_sword": {"name": "Stone Sword", "stack": 1, "color": Color8(160, 166, 160), "dmg": 8, "desc": "A crude blade. +8 damage."},
	"bone_sword": {"name": "Bone Sword", "stack": 1, "color": Color8(232, 224, 200), "dmg": 7, "desc": "Light and sharp. +7 damage."},
	"copper_axe": {"name": "Copper Axe", "stack": 1, "color": Color8(214, 132, 80), "tool": "axe", "tier": 2, "dmg": 8, "desc": "Chops quickly. +8 damage."},
	"copper_pickaxe": {"name": "Copper Pickaxe", "stack": 1, "color": Color8(214, 132, 80), "tool": "pickaxe", "tier": 2, "dmg": 6, "desc": "Mines iron ore. +6 damage."},
	"copper_sword": {"name": "Copper Sword", "stack": 1, "color": Color8(214, 132, 80), "dmg": 11, "desc": "+11 damage."},
	"iron_axe": {"name": "Iron Axe", "stack": 1, "color": Color8(190, 194, 202), "tool": "axe", "tier": 3, "dmg": 11, "desc": "Fells trees in a blink. +11 damage."},
	"iron_pickaxe": {"name": "Iron Pickaxe", "stack": 1, "color": Color8(190, 194, 202), "tool": "pickaxe", "tier": 3, "dmg": 9, "desc": "Mines crystals. +9 damage."},
	"iron_sword": {"name": "Iron Sword", "stack": 1, "color": Color8(190, 194, 202), "dmg": 15, "desc": "+15 damage."},
	"crystal_blade": {"name": "Crystal Blade", "stack": 1, "color": Color8(120, 220, 240), "dmg": 22, "desc": "Hums with power. +22 damage."},
	"flint_knife": {"name": "Flint Knife", "stack": 1, "color": Color8(70, 72, 84), "dmg": 5, "desc": "A sharp first blade. +5 damage."},
	"wooden_club": {"name": "Wooden Club", "stack": 1, "color": Color8(120, 82, 50), "dmg": 6, "desc": "Heavy knotted wood. +6 damage."},
	"flint_spear": {"name": "Flint Spear", "stack": 1, "color": Color8(70, 72, 84), "dmg": 9, "desc": "Long reach, sharp tip. +9 damage."},
	"tusk_dagger": {"name": "Tusk Dagger", "stack": 1, "color": Color8(240, 232, 206), "dmg": 10, "desc": "Curved and vicious. +10 damage."},
	"bronze_axe": {"name": "Bronze Axe", "stack": 1, "color": Color8(200, 150, 70), "tool": "axe", "tier": 2, "dmg": 9, "desc": "Tough bronze head. +9 damage."},
	"bronze_pickaxe": {"name": "Bronze Pickaxe", "stack": 1, "color": Color8(200, 150, 70), "tool": "pickaxe", "tier": 2, "dmg": 7, "desc": "Mines iron and silver. +7 damage."},
	"bronze_sword": {"name": "Bronze Sword", "stack": 1, "color": Color8(200, 150, 70), "dmg": 13, "desc": "+13 damage."},
	"bronze_spear": {"name": "Bronze Spear", "stack": 1, "color": Color8(200, 150, 70), "dmg": 14, "desc": "+14 damage."},
	"iron_spear": {"name": "Iron Spear", "stack": 1, "color": Color8(190, 194, 202), "dmg": 17, "desc": "+17 damage."},
	"war_hammer": {"name": "War Hammer", "stack": 1, "color": Color8(150, 156, 164), "dmg": 19, "desc": "Crushes shells and stone. +19 damage."},
	"venom_dagger": {"name": "Venom Dagger", "stack": 1, "color": Color8(130, 200, 60), "dmg": 16, "desc": "Dripping blade. +16 damage."},
	"silver_sword": {"name": "Silver Sword", "stack": 1, "color": Color8(220, 226, 236), "dmg": 18, "desc": "Bright and balanced. +18 damage."},
	"obsidian_axe": {"name": "Obsidian Axe", "stack": 1, "color": Color8(54, 36, 74), "tool": "axe", "tier": 4, "dmg": 13, "desc": "Cleaves anything. +13 damage."},
	"obsidian_pickaxe": {"name": "Obsidian Pickaxe", "stack": 1, "color": Color8(54, 36, 74), "tool": "pickaxe", "tier": 4, "dmg": 11, "desc": "The fastest pick. +11 damage."},
	"obsidian_blade": {"name": "Obsidian Blade", "stack": 1, "color": Color8(54, 36, 74), "dmg": 20, "desc": "Black glass edge. +20 damage."},
	"horn_halberd": {"name": "Horn Halberd", "stack": 1, "color": Color8(220, 206, 170), "dmg": 26, "desc": "A brute's horn on an iron haft. +26 damage."},
	"short_bow": {"name": "Short Bow", "stack": 1, "color": Color8(160, 114, 68), "dmg": 5, "ranged": "arrow", "desc": "Shoots arrows (Space). +5 damage."},
	"long_bow": {"name": "Long Bow", "stack": 1, "color": Color8(120, 82, 50), "dmg": 9, "ranged": "arrow", "desc": "Shoots arrows far. +9 damage."},
	"bone_bow": {"name": "Bone Bow", "stack": 1, "color": Color8(232, 224, 200), "dmg": 13, "ranged": "arrow", "desc": "Recurved bone and silk. +13 damage."},
	"crossbow": {"name": "Crossbow", "stack": 1, "color": Color8(110, 116, 128), "dmg": 17, "ranged": "arrow", "desc": "Cog-wound bolts. +17 damage."},
	"arc_staff": {"name": "Arc Staff", "stack": 1, "color": Color8(160, 200, 255), "dmg": 14, "ranged": "bolt", "desc": "Spits lightning, no ammo needed. +14 damage."},
	"flint_arrow": {"name": "Flint Arrow", "stack": 40, "color": Color8(70, 72, 84), "arrow": 4, "desc": "Ammunition for bows. +4 damage."},
	"iron_arrow": {"name": "Iron Arrow", "stack": 40, "color": Color8(190, 194, 202), "arrow": 8, "desc": "Ammunition for bows. +8 damage."},
	"blast_arrow": {"name": "Blast Arrow", "stack": 20, "color": Color8(210, 76, 44), "arrow": 16, "desc": "Packed with gunpowder. +16 damage."},	# --- armor (the best piece in the backpack is worn)
	"leather_armor": {"name": "Leather Armor", "stack": 1, "color": Color8(132, 84, 52), "slot": "body", "armor": 2, "desc": "Body armor. Absorbs 2 damage per hit."},
	"copper_armor": {"name": "Copper Armor", "stack": 1, "color": Color8(214, 132, 80), "slot": "body", "armor": 4, "desc": "Body armor. Absorbs 4 damage per hit."},
	"iron_armor": {"name": "Iron Armor", "stack": 1, "color": Color8(190, 194, 202), "slot": "body", "armor": 7, "desc": "Body armor. Absorbs 7 damage per hit."},
	"leather_cap": {"name": "Leather Cap", "stack": 1, "color": Color8(132, 84, 52), "slot": "head", "armor": 1, "desc": "Head. Absorbs 1 damage."},
	"copper_helm": {"name": "Copper Helm", "stack": 1, "color": Color8(214, 132, 80), "slot": "head", "armor": 2, "desc": "Head. Absorbs 2 damage."},
	"iron_helm": {"name": "Iron Helm", "stack": 1, "color": Color8(190, 194, 202), "slot": "head", "armor": 3, "desc": "Head. Absorbs 3 damage."},
	"leather_boots": {"name": "Leather Boots", "stack": 1, "color": Color8(132, 84, 52), "slot": "feet", "armor": 1, "desc": "Feet. Absorbs 1 damage."},
	"copper_boots": {"name": "Copper Boots", "stack": 1, "color": Color8(214, 132, 80), "slot": "feet", "armor": 1, "hp": 10, "desc": "Feet. Absorbs 1 damage, +10 max health."},
	"iron_boots": {"name": "Iron Boots", "stack": 1, "color": Color8(190, 194, 202), "slot": "feet", "armor": 2, "hp": 10, "desc": "Feet. Absorbs 2 damage, +10 max health."},
	"copper_ring": {"name": "Copper Ring", "stack": 1, "color": Color8(214, 132, 80), "slot": "ring", "dmg": 2, "desc": "Ring. +2 damage."},
	"crystal_ring": {"name": "Crystal Ring", "stack": 1, "color": Color8(120, 220, 240), "slot": "ring", "dmg": 5, "desc": "Ring. +5 damage."},
	"bone_charm": {"name": "Bone Charm", "stack": 1, "color": Color8(232, 224, 200), "slot": "amulet", "hp": 20, "desc": "Amulet. +20 max health."},
	"crystal_amulet": {"name": "Crystal Amulet", "stack": 1, "color": Color8(120, 220, 240), "slot": "amulet", "hp": 40, "armor": 1, "desc": "Amulet. +40 max health, absorbs 1."},
	"wool_tunic": {"name": "Wool Tunic", "stack": 1, "color": Color8(196, 170, 140), "slot": "body", "armor": 1, "hp": 10, "desc": "Body. Absorbs 1, +10 max health."},
	"fur_coat": {"name": "Fur Coat", "stack": 1, "color": Color8(118, 84, 56), "slot": "body", "armor": 3, "hp": 15, "warm": 1, "desc": "Body. Absorbs 3, +15 max health. Warm 1."},
	"scale_vest": {"name": "Scale Vest", "stack": 1, "color": Color8(80, 150, 90), "slot": "body", "armor": 4, "desc": "Body. Absorbs 4 damage."},
	"bronze_armor": {"name": "Bronze Armor", "stack": 1, "color": Color8(200, 150, 70), "slot": "body", "armor": 5, "desc": "Body. Absorbs 5 damage."},
	"chitin_armor": {"name": "Chitin Armor", "stack": 1, "color": Color8(110, 70, 50), "slot": "body", "armor": 6, "hp": 10, "desc": "Body. Absorbs 6, +10 max health."},
	"silk_robe": {"name": "Silk Robe", "stack": 1, "color": Color8(200, 60, 140), "slot": "body", "armor": 2, "hp": 35, "desc": "Body. Absorbs 2, +35 max health."},
	"obsidian_plate": {"name": "Obsidian Plate", "stack": 1, "color": Color8(54, 36, 74), "slot": "body", "armor": 9, "desc": "Body. Absorbs 9 damage."},
	"straw_hat": {"name": "Straw Hat", "stack": 1, "color": Color8(222, 186, 92), "slot": "head", "hp": 5, "cool": 1, "desc": "Head. +5 max health. Cool 1: keeps the sun off."},
	"fur_hood": {"name": "Fur Hood", "stack": 1, "color": Color8(118, 84, 56), "slot": "head", "armor": 1, "hp": 8, "warm": 1, "desc": "Head. Absorbs 1, +8 max health. Warm 1."},
	"bronze_helm": {"name": "Bronze Helm", "stack": 1, "color": Color8(200, 150, 70), "slot": "head", "armor": 2, "hp": 5, "desc": "Head. Absorbs 2, +5 max health."},
	"chitin_helm": {"name": "Chitin Helm", "stack": 1, "color": Color8(110, 70, 50), "slot": "head", "armor": 3, "desc": "Head. Absorbs 3 damage."},
	"horned_helm": {"name": "Horned Helm", "stack": 1, "color": Color8(220, 206, 170), "slot": "head", "armor": 4, "dmg": 2, "desc": "Head. Absorbs 4, +2 damage."},
	"obsidian_helm": {"name": "Obsidian Helm", "stack": 1, "color": Color8(54, 36, 74), "slot": "head", "armor": 4, "hp": 5, "desc": "Head. Absorbs 4, +5 max health."},
	"reed_sandals": {"name": "Reed Sandals", "stack": 1, "color": Color8(170, 160, 96), "slot": "feet", "hp": 5, "desc": "Feet. +5 max health."},
	"fur_boots": {"name": "Fur Boots", "stack": 1, "color": Color8(118, 84, 56), "slot": "feet", "armor": 1, "hp": 12, "warm": 1, "desc": "Feet. Absorbs 1, +12 max health. Warm 1."},
	"bronze_boots": {"name": "Bronze Boots", "stack": 1, "color": Color8(200, 150, 70), "slot": "feet", "armor": 2, "hp": 5, "desc": "Feet. Absorbs 2, +5 max health."},
	"obsidian_boots": {"name": "Obsidian Boots", "stack": 1, "color": Color8(54, 36, 74), "slot": "feet", "armor": 3, "hp": 15, "desc": "Feet. Absorbs 3, +15 max health."},
	"wooden_shield": {"name": "Wooden Shield", "stack": 1, "color": Color8(160, 114, 68), "slot": "offhand", "armor": 1, "block": 10, "desc": "Offhand. Absorbs 1, 10% chance to block a hit."},
	"shell_shield": {"name": "Shell Shield", "stack": 1, "color": Color8(90, 128, 70), "slot": "offhand", "armor": 2, "block": 15, "desc": "Offhand. Absorbs 2, 15% block."},
	"bronze_shield": {"name": "Bronze Shield", "stack": 1, "color": Color8(200, 150, 70), "slot": "offhand", "armor": 2, "block": 20, "desc": "Offhand. Absorbs 2, 20% block."},
	"iron_shield": {"name": "Iron Shield", "stack": 1, "color": Color8(190, 194, 202), "slot": "offhand", "armor": 3, "block": 25, "desc": "Offhand. Absorbs 3, 25% block."},
	"obsidian_shield": {"name": "Obsidian Shield", "stack": 1, "color": Color8(54, 36, 74), "slot": "offhand", "armor": 4, "block": 30, "desc": "Offhand. Absorbs 4, 30% block."},
	"silver_ring": {"name": "Silver Ring", "stack": 1, "color": Color8(220, 226, 236), "slot": "ring", "dmg": 3, "desc": "Ring. +3 damage."},
	"gold_ring": {"name": "Gold Ring", "stack": 1, "color": Color8(240, 200, 70), "slot": "ring", "dmg": 2, "hp": 15, "desc": "Ring. +2 damage, +15 max health."},
	"quartz_ring": {"name": "Quartz Ring", "stack": 1, "color": Color8(236, 226, 240), "slot": "ring", "dmg": 3, "armor": 1, "desc": "Ring. +3 damage, absorbs 1."},
	"obsidian_ring": {"name": "Obsidian Ring", "stack": 1, "color": Color8(54, 36, 74), "slot": "ring", "dmg": 7, "desc": "Ring. +7 damage."},
	"feather_charm": {"name": "Feather Charm", "stack": 1, "color": Color8(70, 70, 86), "slot": "amulet", "hp": 10, "desc": "Amulet. +10 max health."},
	"fang_necklace": {"name": "Fang Necklace", "stack": 1, "color": Color8(246, 240, 226), "slot": "amulet", "dmg": 3, "hp": 5, "desc": "Amulet. +3 damage, +5 max health."},
	"glow_amulet": {"name": "Glow Amulet", "stack": 1, "color": Color8(200, 250, 110), "slot": "amulet", "hp": 25, "desc": "Amulet. +25 max health."},
	"gold_amulet": {"name": "Gold Amulet", "stack": 1, "color": Color8(240, 200, 70), "slot": "amulet", "hp": 30, "armor": 1, "desc": "Amulet. +30 max health, absorbs 1."},
	"shadow_amulet": {"name": "Shadow Amulet", "stack": 1, "color": Color8(110, 60, 160), "slot": "amulet", "hp": 50, "dmg": 3, "desc": "Amulet. +50 max health, +3 damage."},	# --- food
	"mushroom": {"name": "Mushroom", "stack": 40, "color": Color8(172, 88, 52), "food": 5.0, "desc": "Earthy cap from the forest floor. Better cooked (+5 food)."},
	"raw_meat": {"name": "Raw Meat", "stack": 40, "color": Color8(200, 70, 72), "food": 6.0, "desc": "From maze creatures. Cook it! (+6 food)"},
	"cooked_meat": {"name": "Cooked Meat", "stack": 20, "color": Color8(160, 94, 50), "food": 35.0, "desc": "Roasted over the fire (+35 food)."},
	"roasted_mushroom": {"name": "Mushroom Skewer", "stack": 20, "color": Color8(124, 58, 38), "food": 18.0, "desc": "Smoky and filling (+18 food)."},
	"berry_jam": {"name": "Berry Jam", "stack": 20, "color": Color8(150, 30, 70), "food": 45.0, "desc": "Thick and sweet (+45 food)."},
	"mushroom_soup": {"name": "Mushroom Soup", "stack": 10, "color": Color8(226, 196, 150), "food": 50.0, "desc": "Warm and creamy (+50 food)."},
	"forest_salad": {"name": "Forest Salad", "stack": 10, "color": Color8(100, 162, 68), "food": 40.0, "desc": "Leaves, berries and caps (+40 food)."},
	"meat_stew": {"name": "Meat Stew", "stack": 10, "color": Color8(170, 100, 56), "food": 85.0, "desc": "A survivor's feast (+85 food)."},
	"baked_potato": {"name": "Baked Potato", "stack": 20, "color": Color8(196, 150, 86), "food": 22.0, "desc": "Fluffy inside (+22 food)."},
	"roasted_carrot": {"name": "Roasted Carrot", "stack": 20, "color": Color8(214, 110, 40), "food": 18.0, "desc": "Caramelised (+18 food)."},
	"fried_egg": {"name": "Fried Egg", "stack": 20, "color": Color8(250, 220, 90), "food": 18.0, "desc": "Sunny side up (+18 food)."},
	"flatbread": {"name": "Flatbread", "stack": 20, "color": Color8(214, 176, 112), "food": 28.0, "desc": "Baked on hot stones (+28 food)."},
	"candied_apple": {"name": "Candied Apple", "stack": 20, "color": Color8(220, 70, 50), "food": 30.0, "desc": "Apple dipped in honey (+30 food)."},
	"fruit_salad": {"name": "Fruit Salad", "stack": 10, "color": Color8(200, 90, 120), "food": 34.0, "desc": "Apple, berries, blueberries (+34 food)."},
	"omelette": {"name": "Omelette", "stack": 10, "color": Color8(240, 200, 80), "food": 40.0, "desc": "Eggs and mushrooms (+40 food)."},
	"porridge": {"name": "Honey Porridge", "stack": 10, "color": Color8(226, 200, 150), "food": 38.0, "desc": "Wheat boiled sweet (+38 food)."},
	"carrot_soup": {"name": "Carrot Soup", "stack": 10, "color": Color8(240, 140, 50), "food": 50.0, "desc": "Bright and warming (+50 food)."},
	"apple_pie": {"name": "Apple Pie", "stack": 10, "color": Color8(214, 160, 90), "food": 62.0, "desc": "A taste of home (+62 food)."},
	"blueberry_pie": {"name": "Blueberry Pie", "stack": 10, "color": Color8(90, 90, 170), "food": 62.0, "desc": "Purple-stained crust (+62 food)."},
	"honey_cake": {"name": "Honey Cake", "stack": 10, "color": Color8(236, 180, 80), "food": 66.0, "heal": 10.0, "desc": "Sweet layers (+66 food, +10 health)."},
	"vegetable_stew": {"name": "Vegetable Stew", "stack": 10, "color": Color8(170, 120, 60), "food": 72.0, "desc": "Everything from the garden (+72 food)."},
	"glowcap_broth": {"name": "Glowcap Broth", "stack": 10, "color": Color8(90, 200, 190), "food": 45.0, "heal": 20.0, "desc": "Faintly luminous (+45 food, +20 health)."},
	"hunter_feast": {"name": "Hunter's Feast", "stack": 5, "color": Color8(160, 94, 50), "food": 100.0, "heal": 30.0, "desc": "Full belly, mended wounds (+100 food, +30 health)."},
	# --- medicine and potions (H drinks the best one)
	"moss_poultice": {"name": "Moss Poultice", "stack": 20, "color": Color8(84, 130, 64), "heal": 12.0, "desc": "Pressed moss (+12 health)."},
	"bandage": {"name": "Bandage", "stack": 20, "color": Color8(236, 226, 206), "heal": 18.0, "desc": "Clean cloth and herbs (+18 health)."},
	"healing_salve": {"name": "Healing Salve", "stack": 20, "color": Color8(150, 190, 90), "heal": 25.0, "desc": "Herb and resin balm (+25 health)."},
	"healing_potion": {"name": "Healing Potion", "stack": 10, "color": Color8(210, 56, 70), "heal": 50.0, "desc": "Red and sweet (+50 health)."},
	"greater_potion": {"name": "Greater Potion", "stack": 10, "color": Color8(200, 60, 200), "heal": 100.0, "cure": true, "desc": "Glows violet (+100 health, cures poison)."},
	"antidote": {"name": "Antidote", "stack": 10, "color": Color8(80, 200, 110), "cure": true, "heal": 5.0, "desc": "Cures poison and slowness."},
	# --- sector resources (Overgrowth, Dunes, Rime Halls, Cinder Forge, Pit)
	"thorn": {"name": "Thorn", "stack": 40, "color": Color8(90, 150, 60), "desc": "Wicked briar spike. Arrowheads and traps."},
	"living_root": {"name": "Living Root", "stack": 20, "color": Color8(120, 150, 70), "desc": "Still twitches. Druids carve staves from it."},
	"moon_petal": {"name": "Moon Petal", "stack": 20, "color": Color8(190, 220, 250), "desc": "Glows under the stars. Potent elixirs."},
	"royal_jelly": {"name": "Royal Jelly", "stack": 10, "color": Color8(250, 236, 170), "food": 20.0, "heal": 20.0, "desc": "Hive queen's food (+20 food, +20 health)."},
	"amber": {"name": "Amber", "stack": 20, "color": Color8(230, 150, 40), "desc": "Fossil resin with a tiny insect inside."},
	"sunstone": {"name": "Sunstone", "stack": 10, "color": Color8(250, 210, 80), "desc": "Warm to the touch, even at night."},
	"fossil": {"name": "Fossil", "stack": 20, "color": Color8(210, 196, 160), "desc": "Bones of something that walked here before the walls."},
	"salt": {"name": "Salt", "stack": 40, "color": Color8(240, 240, 236), "desc": "Cures meat. Jerky keeps forever."},
	"sandstone": {"name": "Sandstone", "stack": 40, "color": Color8(214, 176, 120), "desc": "Soft golden stone. Easy to carve."},
	"cactus_pulp": {"name": "Cactus Pulp", "stack": 40, "color": Color8(110, 170, 90), "food": 3.0, "water": 20.0, "desc": "Wet and bitter (+20 water, +3 food)."},
	"dates": {"name": "Dates", "stack": 40, "color": Color8(150, 90, 50), "food": 14.0, "water": 4.0, "desc": "Sticky palm fruit (+14 food)."},
	"ice": {"name": "Ice", "stack": 40, "color": Color8(190, 230, 250), "water": 12.0, "desc": "Chew it for water (+12) or brew cooling draughts."},
	"frost_crystal": {"name": "Frost Crystal", "stack": 20, "color": Color8(140, 200, 250), "desc": "Never melts. Frost staves and rings."},
	"mithril_ore": {"name": "Mithril Ore", "stack": 40, "color": Color8(170, 220, 230), "desc": "Feather-light silver-blue ore. Needs an obsidian pickaxe."},
	"snowberry": {"name": "Snowberries", "stack": 40, "color": Color8(230, 240, 250), "food": 9.0, "water": 3.0, "desc": "Frozen berries (+9 food)."},
	"frost_pelt": {"name": "Frost Pelt", "stack": 20, "color": Color8(220, 230, 240), "desc": "Thick white fur. Parkas and snow boots."},
	"basalt": {"name": "Basalt", "stack": 40, "color": Color8(70, 66, 70), "desc": "Dense volcanic rock."},
	"magma_core": {"name": "Magma Core", "stack": 20, "color": Color8(250, 120, 40), "desc": "A still-molten heart. Fire weapons."},
	"ash": {"name": "Ash", "stack": 40, "color": Color8(150, 146, 146), "desc": "Fine grey ash. Fireproofs cloth."},
	"ember_ore": {"name": "Ember Ore", "stack": 40, "color": Color8(210, 80, 50), "desc": "Glowing red ore. Needs an obsidian pickaxe."},
	"fire_petal": {"name": "Fire Petal", "stack": 20, "color": Color8(250, 110, 50), "desc": "Hot as a coal. Warming tonics and spice."},
	"fire_gland": {"name": "Fire Gland", "stack": 20, "color": Color8(240, 90, 40), "desc": "From fire-breathing beasts."},
	"demon_horn": {"name": "Demon Horn", "stack": 10, "color": Color8(150, 40, 40), "desc": "Black-red horn of a Pit dweller."},
	"soul_shard": {"name": "Soul Shard", "stack": 20, "color": Color8(150, 236, 220), "desc": "Whispers when held."},
	"cursed_bone": {"name": "Cursed Bone", "stack": 40, "color": Color8(190, 170, 200), "desc": "Bone stained violet. Cold."},
	"hellsteel_ore": {"name": "Hellsteel Ore", "stack": 40, "color": Color8(130, 50, 50), "desc": "The hardest metal. Needs a mithril pickaxe."},
	"brimstone": {"name": "Brimstone", "stack": 40, "color": Color8(240, 190, 60), "desc": "Burning sulfur. Hellsteel flux."},
	"blood_moss": {"name": "Blood Moss", "stack": 40, "color": Color8(170, 40, 50), "heal": 6.0, "desc": "Red moss that stops bleeding (+6 health)."},
	# --- guardian keys (bound: never lost on death)
	"key_stone": {"name": "Stone Key", "stack": 1, "color": Color8(170, 182, 168), "bound": true, "desc": "Taken from the Stone Colossus. Opens the Overgrowth."},
	"key_overgrowth": {"name": "Briar Key", "stack": 1, "color": Color8(90, 150, 60), "bound": true, "desc": "Taken from the Briar Hydra. Opens the Sunken Dunes."},
	"key_desert": {"name": "Sun Key", "stack": 1, "color": Color8(250, 210, 80), "bound": true, "desc": "Taken from the Sun Wyrm. Opens the Rime Halls."},
	"key_ice": {"name": "Rime Key", "stack": 1, "color": Color8(140, 200, 250), "bound": true, "desc": "Taken from the Hoarfrost Dragon. Opens the Cinder Forge."},
	"key_volcano": {"name": "Forge Key", "stack": 1, "color": Color8(250, 120, 40), "bound": true, "desc": "Taken from the Forgeheart Giant. Opens the Pit."},
	"key_hell": {"name": "Pit Key", "stack": 1, "color": Color8(150, 40, 40), "bound": true, "desc": "Taken from the Pit Lord. With all six Keys, the last gate opens."},
	# --- sector materials
	"mithril_ingot": {"name": "Mithril Ingot", "stack": 40, "color": Color8(170, 220, 230), "desc": "Light as cloth, hard as iron."},
	"ember_ingot": {"name": "Ember Ingot", "stack": 40, "color": Color8(230, 100, 50), "desc": "Forever warm metal."},
	"hellsteel_ingot": {"name": "Hellsteel Ingot", "stack": 40, "color": Color8(130, 50, 50), "desc": "Forged in the Pit's fire."},
	"waterskin": {"name": "Waterskin", "stack": 5, "color": Color8(132, 88, 54), "desc": "Empty. Fill it at a pond or a well (E)."},
	"waterskin_full": {"name": "Full Waterskin", "stack": 5, "color": Color8(70, 140, 190), "water": 50.0, "desc": "H drinks it (+50 water)."},
	# --- sector gear (warm / cool: protection against cold / heat)
	"mithril_axe": {"name": "Mithril Axe", "stack": 1, "color": Color8(170, 220, 230), "tool": "axe", "tier": 5, "dmg": 16, "desc": "+16 damage."},
	"mithril_pickaxe": {"name": "Mithril Pickaxe", "stack": 1, "color": Color8(170, 220, 230), "tool": "pickaxe", "tier": 5, "dmg": 14, "desc": "Mines hellsteel. +14 damage."},
	"mithril_sword": {"name": "Mithril Sword", "stack": 1, "color": Color8(170, 220, 230), "dmg": 30, "desc": "Sings through the air. +30 damage."},
	"ember_blade": {"name": "Ember Blade", "stack": 1, "color": Color8(230, 100, 50), "dmg": 36, "desc": "Leaves burning trails. +36 damage."},
	"hellsteel_pickaxe": {"name": "Hellsteel Pickaxe", "stack": 1, "color": Color8(130, 50, 50), "tool": "pickaxe", "tier": 6, "dmg": 18, "desc": "Breaks anything. +18 damage."},
	"hellsteel_greatsword": {"name": "Hellsteel Greatsword", "stack": 1, "color": Color8(130, 50, 50), "dmg": 46, "desc": "A slab of black-red steel. +46 damage."},
	"bone_crown": {"name": "Bone Crown", "stack": 1, "color": Color8(190, 170, 200), "slot": "head", "armor": 5, "dmg": 5, "desc": "Head. Absorbs 5, +5 damage."},
	"druid_staff": {"name": "Druid Staff", "stack": 1, "color": Color8(120, 150, 70), "dmg": 22, "ranged": "thorn", "desc": "Fires thorns, no ammo needed. +22 damage."},
	"frost_staff": {"name": "Frost Staff", "stack": 1, "color": Color8(140, 200, 250), "dmg": 30, "ranged": "frost", "desc": "Fires frost shards. +30 damage."},
	"fire_staff": {"name": "Fire Staff", "stack": 1, "color": Color8(250, 120, 40), "dmg": 38, "ranged": "fire", "desc": "Hurls fireballs. +38 damage."},
	"ember_bow": {"name": "Ember Bow", "stack": 1, "color": Color8(230, 100, 50), "dmg": 24, "ranged": "arrow", "desc": "Shoots arrows. +24 damage."},
	"thorn_arrow": {"name": "Thorn Arrow", "stack": 40, "color": Color8(90, 150, 60), "arrow": 6, "desc": "Ammunition for bows. +6 damage."},
	"mithril_arrow": {"name": "Mithril Arrow", "stack": 40, "color": Color8(170, 220, 230), "arrow": 12, "desc": "Ammunition for bows. +12 damage."},
	"fire_arrow": {"name": "Fire Arrow", "stack": 20, "color": Color8(250, 120, 40), "arrow": 20, "desc": "Ammunition for bows. +20 damage."},
	"parka": {"name": "Frost Parka", "stack": 1, "color": Color8(220, 230, 240), "slot": "body", "armor": 3, "hp": 20, "warm": 2, "desc": "Body. Absorbs 3, +20 max health. Warm 2."},
	"snow_boots": {"name": "Snow Boots", "stack": 1, "color": Color8(220, 230, 240), "slot": "feet", "armor": 2, "hp": 10, "warm": 1, "desc": "Feet. Absorbs 2, +10 max health. Warm 1."},
	"desert_wrap": {"name": "Desert Wrap", "stack": 1, "color": Color8(226, 206, 150), "slot": "head", "hp": 8, "cool": 1, "desc": "Head. +8 max health. Cool 1."},
	"sun_robe": {"name": "Sun Robe", "stack": 1, "color": Color8(250, 220, 140), "slot": "body", "armor": 2, "hp": 25, "cool": 1, "desc": "Body. Absorbs 2, +25 max health. Cool 1."},
	"fire_cloak": {"name": "Ashen Cloak", "stack": 1, "color": Color8(150, 146, 146), "slot": "body", "armor": 5, "hp": 15, "cool": 2, "desc": "Body. Absorbs 5, +15 max health. Cool 2."},
	"ember_helm": {"name": "Ember Helm", "stack": 1, "color": Color8(230, 100, 50), "slot": "head", "armor": 5, "hp": 5, "cool": 1, "desc": "Head. Absorbs 5, +5 max health. Cool 1."},
	"mithril_helm": {"name": "Mithril Helm", "stack": 1, "color": Color8(170, 220, 230), "slot": "head", "armor": 5, "hp": 10, "desc": "Head. Absorbs 5, +10 max health."},
	"mithril_armor": {"name": "Mithril Mail", "stack": 1, "color": Color8(170, 220, 230), "slot": "body", "armor": 11, "hp": 10, "desc": "Body. Absorbs 11, +10 max health."},
	"mithril_boots": {"name": "Mithril Boots", "stack": 1, "color": Color8(170, 220, 230), "slot": "feet", "armor": 4, "hp": 15, "desc": "Feet. Absorbs 4, +15 max health."},
	"mithril_shield": {"name": "Mithril Shield", "stack": 1, "color": Color8(170, 220, 230), "slot": "offhand", "armor": 5, "block": 35, "desc": "Offhand. Absorbs 5, 35% block."},
	"basalt_shield": {"name": "Basalt Shield", "stack": 1, "color": Color8(70, 66, 70), "slot": "offhand", "armor": 6, "block": 30, "desc": "Offhand. Absorbs 6, 30% block."},
	"hellsteel_helm": {"name": "Hellsteel Helm", "stack": 1, "color": Color8(130, 50, 50), "slot": "head", "armor": 7, "hp": 10, "desc": "Head. Absorbs 7, +10 max health."},
	"hellsteel_plate": {"name": "Hellsteel Plate", "stack": 1, "color": Color8(130, 50, 50), "slot": "body", "armor": 14, "hp": 20, "cool": 1, "desc": "Body. Absorbs 14, +20 max health. Cool 1."},
	"hellsteel_boots": {"name": "Hellsteel Boots", "stack": 1, "color": Color8(130, 50, 50), "slot": "feet", "armor": 6, "hp": 20, "desc": "Feet. Absorbs 6, +20 max health."},
	"amber_amulet": {"name": "Amber Amulet", "stack": 1, "color": Color8(230, 150, 40), "slot": "amulet", "hp": 40, "armor": 1, "desc": "Amulet. +40 max health, absorbs 1."},
	"fossil_charm": {"name": "Fossil Charm", "stack": 1, "color": Color8(210, 196, 160), "slot": "amulet", "hp": 20, "armor": 2, "desc": "Amulet. +20 max health, absorbs 2."},
	"soul_amulet": {"name": "Soul Amulet", "stack": 1, "color": Color8(150, 236, 220), "slot": "amulet", "hp": 70, "dmg": 5, "desc": "Amulet. +70 max health, +5 damage."},
	"sunstone_ring": {"name": "Sunstone Ring", "stack": 1, "color": Color8(250, 210, 80), "slot": "ring", "dmg": 6, "hp": 10, "warm": 1, "desc": "Ring. +6 damage, +10 max health. Warm 1."},
	"frost_ring": {"name": "Frost Ring", "stack": 1, "color": Color8(140, 200, 250), "slot": "ring", "dmg": 6, "cool": 1, "desc": "Ring. +6 damage. Cool 1."},
	"demon_ring": {"name": "Demon Ring", "stack": 1, "color": Color8(150, 40, 40), "slot": "ring", "dmg": 11, "desc": "Ring. +11 damage."},
	# --- sector food and medicine
	"jerky": {"name": "Jerky", "stack": 40, "color": Color8(130, 70, 50), "food": 28.0, "desc": "Salted dried meat (+28 food)."},
	"cactus_salad": {"name": "Cactus Salad", "stack": 10, "color": Color8(110, 170, 90), "food": 24.0, "water": 25.0, "desc": "Crunchy and wet (+24 food, +25 water)."},
	"date_cake": {"name": "Date Cake", "stack": 10, "color": Color8(150, 90, 50), "food": 55.0, "desc": "Dense and sweet (+55 food)."},
	"snowberry_tart": {"name": "Snowberry Tart", "stack": 10, "color": Color8(200, 220, 240), "food": 52.0, "desc": "Tart and icy (+52 food)."},
	"spiced_stew": {"name": "Spiced Stew", "stack": 10, "color": Color8(200, 80, 40), "food": 90.0, "heal": 20.0, "warmth": 240.0, "desc": "Burns going down (+90 food, +20 health, warm for 4 min)."},
	"cooling_draught": {"name": "Cooling Draught", "stack": 10, "color": Color8(140, 210, 250), "water": 20.0, "chill": 300.0, "desc": "Cool 2 for 5 minutes, +20 water."},
	"warming_tonic": {"name": "Warming Tonic", "stack": 10, "color": Color8(250, 140, 60), "warmth": 300.0, "desc": "Warm 2 for 5 minutes."},
	"moon_elixir": {"name": "Moon Elixir", "stack": 10, "color": Color8(190, 220, 250), "heal": 130.0, "cure": true, "desc": "+130 health, cures poison."},
	"blood_salve": {"name": "Blood Salve", "stack": 20, "color": Color8(170, 40, 50), "heal": 40.0, "desc": "+40 health."},
	"stamina_tonic": {"name": "Stamina Tonic", "stack": 10, "color": Color8(240, 200, 60), "stamina": 100.0, "food": 5.0, "desc": "Restores all stamina."},	# --- buildings
	"workbench": {"name": "Workbench", "stack": 5, "color": Color8(166, 120, 72), "desc": "Place with B, E to use. Woodwork and new stations."},
	"furnace": {"name": "Furnace", "stack": 5, "color": Color8(120, 120, 124), "desc": "Place with B, E to use. Smelts ore, fires clay."},
	"anvil": {"name": "Anvil", "stack": 5, "color": Color8(96, 100, 108), "desc": "Place with B, E to use. Forges metal tools, weapons, armor, jewels."},
	"cooking_pot": {"name": "Cooking Pot", "stack": 5, "color": Color8(66, 70, 80), "desc": "Place with B, E to use. Soups, stews and meals."},
	"tanning_rack": {"name": "Tanning Rack", "stack": 5, "color": Color8(168, 118, 78), "desc": "Place with B, E to use. Leather and leather gear."},
	"stonecutter": {"name": "Stonecutter", "stack": 5, "color": Color8(128, 132, 130), "desc": "Place with B, E to use. Stone and brick blocks."},
	"loom": {"name": "Loom", "stack": 5, "color": Color8(176, 130, 82), "desc": "Place with B, E to use. Cloth, felt, silk and garments."},
	"alchemy_table": {"name": "Alchemy Table", "stack": 5, "color": Color8(120, 90, 140), "desc": "Place with B, E to use. Potions, gunpowder, glue and dye."},	"chest": {"name": "Chest", "stack": 5, "color": Color8(150, 104, 60), "desc": "Place with B, E (or G) to open. The Stash is shared and kept on death."},
	"wooden_wall": {"name": "Wooden Wall", "stack": 40, "color": Color8(150, 106, 64), "desc": "Place with B. Blocks the way."},
	"wooden_floor": {"name": "Wooden Floor", "stack": 40, "color": Color8(190, 146, 92), "desc": "Place with B. Walkable."},
	"wooden_door": {"name": "Wooden Door", "stack": 10, "color": Color8(130, 92, 58), "desc": "Place with B. F opens/closes."},
	"stone_wall": {"name": "Stone Wall", "stack": 40, "color": Color8(130, 138, 132), "desc": "Place with B. Sturdy defense."},
	"stone_floor": {"name": "Stone Floor", "stack": 40, "color": Color8(150, 154, 148), "desc": "Place with B. Walkable."},
	"brick_wall": {"name": "Brick Wall", "stack": 40, "color": Color8(184, 82, 60), "desc": "Place with B. Warm red masonry."},
	"farm_plot": {"name": "Farm Plot", "stack": 10, "color": Color8(110, 78, 50), "desc": "Place with B. E on it picks a seed to sow: berries, wheat, carrots, herbs, mushrooms..."},
	"well": {"name": "Well", "stack": 5, "color": Color8(120, 126, 130), "desc": "Place with B. E drinks or fills a waterskin, anywhere."},
	"standing_torch": {"name": "Standing Torch", "stack": 20, "color": Color8(245, 154, 58), "desc": "Place with B. Lights the night and scares off some creatures."},
	"waystone": {"name": "Waystone", "stack": 2, "color": Color8(150, 200, 220), "desc": "Place with B. E travels to any sector already reached."},
}

## station: "" = craftable anywhere, otherwise a node group that must be near.
const RECIPES := [
	# --- by hand (I)
	{"id": "plank", "out": 2, "in": {"wood": 1}, "station": ""},
	{"id": "stick", "out": 3, "in": {"wood": 1}, "station": ""},
	{"id": "rope", "out": 1, "in": {"fiber": 3}, "station": ""},
	{"id": "torch", "out": 2, "in": {"stick": 1, "fiber": 2}, "station": ""},
	{"id": "stone_axe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_pickaxe", "out": 1, "in": {"stick": 2, "stone": 3}, "station": ""},
	{"id": "stone_sword", "out": 1, "in": {"stick": 1, "stone": 2}, "station": ""},
	{"id": "bone_sword", "out": 1, "in": {"bone": 3, "rope": 1}, "station": ""},
	{"id": "bone_charm", "out": 1, "in": {"bone": 3, "rope": 1}, "station": ""},
	{"id": "farm_plot", "out": 1, "in": {"plank": 2, "stick": 1}, "station": ""},
	{"id": "forest_salad", "out": 1, "in": {"fiber": 2, "berry": 3, "mushroom": 1}, "station": ""},
	# --- campfire
	{"id": "workbench", "out": 1, "in": {"plank": 8, "stone": 4}, "station": "campfire"},
	{"id": "cooked_meat", "out": 1, "in": {"raw_meat": 1}, "station": "campfire"},
	{"id": "roasted_mushroom", "out": 1, "in": {"mushroom": 2, "stick": 1}, "station": "campfire"},
	# --- workbench: woodwork and new stations
	{"id": "chest", "out": 1, "in": {"plank": 6, "stick": 2}, "station": "workbench"},
	{"id": "wooden_wall", "out": 2, "in": {"plank": 3, "stick": 1}, "station": "workbench"},
	{"id": "wooden_floor", "out": 4, "in": {"plank": 2}, "station": "workbench"},
	{"id": "wooden_door", "out": 1, "in": {"plank": 4, "stick": 2}, "station": "workbench"},
	{"id": "furnace", "out": 1, "in": {"stone": 10, "clay": 4}, "station": "workbench"},
	{"id": "tanning_rack", "out": 1, "in": {"stick": 6, "rope": 3}, "station": "workbench"},
	{"id": "stonecutter", "out": 1, "in": {"stone": 8, "plank": 4}, "station": "workbench"},
	{"id": "anvil", "out": 1, "in": {"copper_ingot": 6, "wood": 2}, "station": "workbench"},
	# --- furnace: smelting and firing
	{"id": "copper_ingot", "out": 2, "in": {"copper_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "iron_ingot", "out": 1, "in": {"iron_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "brick", "out": 2, "in": {"clay": 2, "coal": 1}, "station": "furnace"},
	{"id": "cooking_pot", "out": 1, "in": {"clay": 6, "rope": 1}, "station": "furnace"},
	# --- stonecutter: masonry
	{"id": "stone_wall", "out": 2, "in": {"stone": 4}, "station": "stonecutter"},
	{"id": "stone_floor", "out": 4, "in": {"stone": 2}, "station": "stonecutter"},
	{"id": "brick_wall", "out": 2, "in": {"brick": 4}, "station": "stonecutter"},
	# --- tanning rack: leather goods
	{"id": "leather", "out": 1, "in": {"hide": 2}, "station": "tanning_rack"},
	{"id": "leather_armor", "out": 1, "in": {"leather": 5, "rope": 2}, "station": "tanning_rack"},
	{"id": "leather_cap", "out": 1, "in": {"leather": 3}, "station": "tanning_rack"},
	{"id": "leather_boots", "out": 1, "in": {"leather": 2, "rope": 1}, "station": "tanning_rack"},
	# --- anvil: metal tools, weapons, armor and jewellery
	{"id": "copper_axe", "out": 1, "in": {"stick": 2, "copper_ingot": 3}, "station": "anvil"},
	{"id": "copper_pickaxe", "out": 1, "in": {"stick": 2, "copper_ingot": 3}, "station": "anvil"},
	{"id": "copper_sword", "out": 1, "in": {"stick": 1, "copper_ingot": 2}, "station": "anvil"},
	{"id": "copper_helm", "out": 1, "in": {"copper_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "copper_armor", "out": 1, "in": {"copper_ingot": 8, "leather": 2}, "station": "anvil"},
	{"id": "copper_boots", "out": 1, "in": {"copper_ingot": 3, "leather": 1}, "station": "anvil"},
	{"id": "copper_ring", "out": 1, "in": {"copper_ingot": 2}, "station": "anvil"},
	{"id": "iron_axe", "out": 1, "in": {"stick": 2, "iron_ingot": 3}, "station": "anvil"},
	{"id": "iron_pickaxe", "out": 1, "in": {"stick": 2, "iron_ingot": 3}, "station": "anvil"},
	{"id": "iron_sword", "out": 1, "in": {"stick": 1, "iron_ingot": 2}, "station": "anvil"},
	{"id": "iron_helm", "out": 1, "in": {"iron_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "iron_armor", "out": 1, "in": {"iron_ingot": 8, "leather": 3}, "station": "anvil"},
	{"id": "iron_boots", "out": 1, "in": {"iron_ingot": 3, "leather": 1}, "station": "anvil"},
	{"id": "crystal_blade", "out": 1, "in": {"stick": 1, "crystal": 3, "iron_ingot": 2}, "station": "anvil"},
	{"id": "crystal_ring", "out": 1, "in": {"crystal": 2, "iron_ingot": 1}, "station": "anvil"},
	{"id": "crystal_amulet", "out": 1, "in": {"crystal": 3, "copper_ingot": 2, "rope": 1}, "station": "anvil"},
	# --- cooking pot: meals
	{"id": "berry_jam", "out": 1, "in": {"berry": 4}, "station": "cooking_pot"},
	{"id": "mushroom_soup", "out": 1, "in": {"mushroom": 3, "berry": 1}, "station": "cooking_pot"},
	{"id": "meat_stew", "out": 1, "in": {"cooked_meat": 1, "mushroom": 2, "berry": 2}, "station": "cooking_pot"},
	# ================================================= biome expansion
	# --- by hand
	{"id": "flint_knife", "out": 1, "in": {"flint": 2, "stick": 1}, "station": ""},
	{"id": "flint_spear", "out": 1, "in": {"flint": 2, "stick": 3, "rope": 1}, "station": ""},
	{"id": "wooden_club", "out": 1, "in": {"wood": 3}, "station": ""},
	{"id": "rope", "out": 2, "in": {"vine": 2}, "station": ""},
	{"id": "rope", "out": 1, "in": {"reed": 3}, "station": ""},
	{"id": "straw_hat", "out": 1, "in": {"reed": 4, "fiber": 2}, "station": ""},
	{"id": "reed_sandals", "out": 1, "in": {"reed": 3, "fiber": 2}, "station": ""},
	{"id": "flint_arrow", "out": 4, "in": {"flint": 1, "stick": 2, "feather": 1}, "station": ""},
	{"id": "moss_poultice", "out": 1, "in": {"moss": 2, "herb": 1}, "station": ""},
	{"id": "feather_charm", "out": 1, "in": {"feather": 4, "rope": 1, "petals": 2}, "station": ""},
	{"id": "fang_necklace", "out": 1, "in": {"fang": 4, "rope": 1}, "station": ""},
	{"id": "fruit_salad", "out": 1, "in": {"apple": 1, "berry": 2, "blueberry": 2}, "station": ""},
	{"id": "torch", "out": 3, "in": {"stick": 1, "resin": 1}, "station": ""},
	# --- campfire
	{"id": "baked_potato", "out": 1, "in": {"potato": 1}, "station": "campfire"},
	{"id": "roasted_carrot", "out": 1, "in": {"carrot": 1}, "station": "campfire"},
	{"id": "fried_egg", "out": 1, "in": {"egg": 1}, "station": "campfire"},
	{"id": "flatbread", "out": 1, "in": {"flour": 2}, "station": "campfire"},
	{"id": "candied_apple", "out": 1, "in": {"apple": 1, "honey": 1, "stick": 1}, "station": "campfire"},
	# --- workbench
	{"id": "loom", "out": 1, "in": {"plank": 8, "stick": 4, "rope": 4}, "station": "workbench"},
	{"id": "alchemy_table", "out": 1, "in": {"plank": 6, "glass": 3, "stone": 4}, "station": "workbench"},
	{"id": "short_bow", "out": 1, "in": {"stick": 3, "rope": 2}, "station": "workbench"},
	{"id": "long_bow", "out": 1, "in": {"wood": 3, "bowstring": 1, "glue": 1}, "station": "workbench"},
	{"id": "bone_bow", "out": 1, "in": {"bone": 6, "bowstring": 1, "glue": 2}, "station": "workbench"},
	{"id": "crossbow", "out": 1, "in": {"plank": 4, "cog": 3, "iron_ingot": 2, "bowstring": 1}, "station": "workbench"},
	{"id": "wooden_shield", "out": 1, "in": {"plank": 5, "rope": 1}, "station": "workbench"},
	{"id": "shell_shield", "out": 1, "in": {"shell": 3, "plank": 2, "glue": 1}, "station": "workbench"},
	{"id": "war_hammer", "out": 1, "in": {"iron_ingot": 4, "wood": 2, "leather": 1}, "station": "anvil"},
	{"id": "bone_charm", "out": 1, "in": {"bone": 2, "silk": 2}, "station": "workbench"},
	# --- furnace
	{"id": "glass", "out": 2, "in": {"sand": 3, "coal": 1}, "station": "furnace"},
	{"id": "glass", "out": 1, "in": {"quartz": 1, "coal": 1}, "station": "furnace"},
	{"id": "glass_vial", "out": 3, "in": {"glass": 2}, "station": "furnace"},
	{"id": "bronze_ingot", "out": 3, "in": {"copper_ore": 2, "tin_ore": 1, "coal": 1}, "station": "furnace"},
	{"id": "silver_ingot", "out": 1, "in": {"silver_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "gold_ingot", "out": 1, "in": {"gold_ore": 2, "coal": 1}, "station": "furnace"},
	{"id": "iron_ingot", "out": 1, "in": {"scrap": 3, "coal": 1}, "station": "furnace"},
	{"id": "copper_ingot", "out": 1, "in": {"cog": 1}, "station": "furnace"},
	{"id": "coal", "out": 2, "in": {"wood": 3}, "station": "furnace"},
	# --- stonecutter (also mills grain)
	{"id": "flour", "out": 1, "in": {"wheat": 3}, "station": "stonecutter"},
	{"id": "stone_floor", "out": 4, "in": {"flint": 3}, "station": "stonecutter"},
	{"id": "sand", "out": 2, "in": {"stone": 1}, "station": "stonecutter"},
	{"id": "quartz_ring", "out": 1, "in": {"quartz": 3, "silver_ingot": 1}, "station": "stonecutter"},
	{"id": "obsidian_ring", "out": 1, "in": {"obsidian": 3, "gold_ingot": 1}, "station": "stonecutter"},
	# --- tanning rack
	{"id": "leather", "out": 1, "in": {"fur": 2}, "station": "tanning_rack"},
	{"id": "fur_coat", "out": 1, "in": {"fur": 6, "leather": 2, "rope": 1}, "station": "tanning_rack"},
	{"id": "fur_hood", "out": 1, "in": {"fur": 3, "leather": 1}, "station": "tanning_rack"},
	{"id": "fur_boots", "out": 1, "in": {"fur": 3, "leather": 1}, "station": "tanning_rack"},
	{"id": "scale_vest", "out": 1, "in": {"scale": 10, "leather": 3}, "station": "tanning_rack"},
	{"id": "chitin_armor", "out": 1, "in": {"chitin": 10, "leather": 2, "glue": 2}, "station": "tanning_rack"},
	{"id": "chitin_helm", "out": 1, "in": {"chitin": 5, "leather": 1, "glue": 1}, "station": "tanning_rack"},
	{"id": "bowstring", "out": 2, "in": {"leather": 1, "resin": 1}, "station": "tanning_rack"},
	# --- loom
	{"id": "cloth", "out": 1, "in": {"cotton": 3}, "station": "loom"},
	{"id": "cloth", "out": 1, "in": {"fiber": 6}, "station": "loom"},
	{"id": "felt", "out": 1, "in": {"wool": 3}, "station": "loom"},
	{"id": "silk_cloth", "out": 1, "in": {"silk": 4}, "station": "loom"},
	{"id": "rope", "out": 3, "in": {"cotton": 2, "fiber": 2}, "station": "loom"},
	{"id": "bowstring", "out": 2, "in": {"silk": 3}, "station": "loom"},
	{"id": "bandage", "out": 2, "in": {"cloth": 1, "herb": 1}, "station": "loom"},
	{"id": "wool_tunic", "out": 1, "in": {"felt": 4, "cloth": 1}, "station": "loom"},
	{"id": "silk_robe", "out": 1, "in": {"silk_cloth": 5, "dye": 2, "wing_dust": 2}, "station": "loom"},
	# --- alchemy table
	{"id": "healing_salve", "out": 1, "in": {"herb": 3, "resin": 1}, "station": "alchemy_table"},
	{"id": "healing_potion", "out": 1, "in": {"glass_vial": 1, "herb": 2, "honey": 1}, "station": "alchemy_table"},
	{"id": "healing_potion", "out": 1, "in": {"glass_vial": 1, "glowcap": 2}, "station": "alchemy_table"},
	{"id": "greater_potion", "out": 1, "in": {"glass_vial": 1, "healing_potion": 1, "ectoplasm": 1, "glow_gland": 1}, "station": "alchemy_table"},
	{"id": "antidote", "out": 1, "in": {"glass_vial": 1, "venom_sac": 1, "spores": 2}, "station": "alchemy_table"},
	{"id": "stamina_tonic", "out": 1, "in": {"glass_vial": 1, "honey": 1, "wing_dust": 2}, "station": "alchemy_table"},
	{"id": "gunpowder", "out": 2, "in": {"sulfur": 1, "saltpeter": 2, "coal": 1}, "station": "alchemy_table"},
	{"id": "glue", "out": 2, "in": {"slime": 1, "resin": 1}, "station": "alchemy_table"},
	{"id": "dye", "out": 2, "in": {"petals": 3}, "station": "alchemy_table"},
	{"id": "dye", "out": 2, "in": {"shadow_petal": 1, "blueberry": 2}, "station": "alchemy_table"},
	{"id": "blast_arrow", "out": 3, "in": {"iron_arrow": 3, "gunpowder": 1}, "station": "alchemy_table"},
	{"id": "glow_amulet", "out": 1, "in": {"glow_gland": 3, "silver_ingot": 1, "silk": 1}, "station": "alchemy_table"},
	{"id": "shadow_amulet", "out": 1, "in": {"shadow_petal": 4, "ectoplasm": 2, "gold_ingot": 2}, "station": "alchemy_table"},
	{"id": "arc_staff", "out": 1, "in": {"spark_core": 2, "crystal": 2, "silver_ingot": 2, "wood": 2}, "station": "alchemy_table"},
	# --- anvil
	{"id": "tusk_dagger", "out": 1, "in": {"tusk": 2, "leather": 1}, "station": "anvil"},
	{"id": "venom_dagger", "out": 1, "in": {"iron_ingot": 2, "venom_sac": 2, "fang": 2}, "station": "anvil"},
	{"id": "bronze_axe", "out": 1, "in": {"stick": 2, "bronze_ingot": 3}, "station": "anvil"},
	{"id": "bronze_pickaxe", "out": 1, "in": {"stick": 2, "bronze_ingot": 3}, "station": "anvil"},
	{"id": "bronze_sword", "out": 1, "in": {"stick": 1, "bronze_ingot": 3}, "station": "anvil"},
	{"id": "bronze_spear", "out": 1, "in": {"stick": 3, "bronze_ingot": 2}, "station": "anvil"},
	{"id": "bronze_helm", "out": 1, "in": {"bronze_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "bronze_armor", "out": 1, "in": {"bronze_ingot": 8, "leather": 2}, "station": "anvil"},
	{"id": "bronze_boots", "out": 1, "in": {"bronze_ingot": 3, "leather": 1}, "station": "anvil"},
	{"id": "bronze_shield", "out": 1, "in": {"bronze_ingot": 5, "plank": 2}, "station": "anvil"},
	{"id": "iron_spear", "out": 1, "in": {"stick": 3, "iron_ingot": 2}, "station": "anvil"},
	{"id": "iron_shield", "out": 1, "in": {"iron_ingot": 5, "plank": 2, "leather": 1}, "station": "anvil"},
	{"id": "iron_arrow", "out": 6, "in": {"iron_ingot": 1, "stick": 3, "feather": 2}, "station": "anvil"},
	{"id": "silver_sword", "out": 1, "in": {"silver_ingot": 3, "iron_ingot": 1, "leather": 1}, "station": "anvil"},
	{"id": "silver_ring", "out": 1, "in": {"silver_ingot": 2}, "station": "anvil"},
	{"id": "gold_ring", "out": 1, "in": {"gold_ingot": 2, "crystal": 1}, "station": "anvil"},
	{"id": "gold_amulet", "out": 1, "in": {"gold_ingot": 3, "quartz": 2, "silk": 1}, "station": "anvil"},
	{"id": "horned_helm", "out": 1, "in": {"iron_ingot": 3, "tusk": 2, "leather": 1}, "station": "anvil"},
	{"id": "horn_halberd", "out": 1, "in": {"horn": 1, "iron_ingot": 4, "wood": 2}, "station": "anvil"},
	{"id": "obsidian_axe", "out": 1, "in": {"obsidian": 4, "iron_ingot": 2, "stick": 2}, "station": "anvil"},
	{"id": "obsidian_pickaxe", "out": 1, "in": {"obsidian": 4, "iron_ingot": 2, "stick": 2}, "station": "anvil"},
	{"id": "obsidian_blade", "out": 1, "in": {"obsidian": 5, "iron_ingot": 2, "leather": 1}, "station": "anvil"},
	{"id": "obsidian_helm", "out": 1, "in": {"obsidian": 5, "iron_ingot": 2, "leather": 1}, "station": "anvil"},
	{"id": "obsidian_plate", "out": 1, "in": {"obsidian": 10, "iron_ingot": 4, "leather": 3}, "station": "anvil"},
	{"id": "obsidian_boots", "out": 1, "in": {"obsidian": 4, "iron_ingot": 2, "fur": 2}, "station": "anvil"},
	{"id": "obsidian_shield", "out": 1, "in": {"obsidian": 6, "iron_ingot": 3, "shell": 1}, "station": "anvil"},
	# --- cooking pot
	{"id": "omelette", "out": 1, "in": {"egg": 2, "mushroom": 1, "herb": 1}, "station": "cooking_pot"},
	{"id": "porridge", "out": 1, "in": {"wheat": 3, "honey": 1}, "station": "cooking_pot"},
	{"id": "carrot_soup", "out": 1, "in": {"carrot": 3, "potato": 1, "herb": 1}, "station": "cooking_pot"},
	{"id": "apple_pie", "out": 1, "in": {"flour": 2, "apple": 3, "egg": 1}, "station": "cooking_pot"},
	{"id": "blueberry_pie", "out": 1, "in": {"flour": 2, "blueberry": 4, "egg": 1}, "station": "cooking_pot"},
	{"id": "honey_cake", "out": 1, "in": {"flour": 2, "honey": 2, "egg": 2}, "station": "cooking_pot"},
	{"id": "vegetable_stew", "out": 1, "in": {"potato": 2, "carrot": 2, "mushroom": 1, "herb": 1}, "station": "cooking_pot"},
	{"id": "glowcap_broth", "out": 1, "in": {"glowcap": 3, "moss": 1, "cooked_meat": 1}, "station": "cooking_pot"},
	{"id": "hunter_feast", "out": 1, "in": {"cooked_meat": 3, "baked_potato": 2, "flatbread": 1, "berry_jam": 1}, "station": "cooking_pot"},
	{"id": "berry_jam", "out": 1, "in": {"blueberry": 4, "honey": 1}, "station": "cooking_pot"},
	# --- sectors: water, climate gear and new metals
	{"id": "thorn_arrow", "out": 6, "in": {"thorn": 3, "stick": 2}, "station": ""},
	{"id": "jerky", "out": 2, "in": {"raw_meat": 2, "salt": 1}, "station": "campfire"},
	{"id": "waterskin", "out": 1, "in": {"leather": 2, "rope": 1}, "station": "workbench"},
	{"id": "standing_torch", "out": 1, "in": {"stick": 2, "torch": 1, "stone": 2}, "station": "workbench"},
	{"id": "well", "out": 1, "in": {"stone": 14, "plank": 4, "rope": 2}, "station": "stonecutter"},
	{"id": "waystone", "out": 1, "in": {"sandstone": 8, "crystal": 2, "gold_ingot": 1}, "station": "stonecutter"},
	{"id": "druid_staff", "out": 1, "in": {"living_root": 3, "moon_petal": 1, "plank": 2}, "station": "workbench"},
	{"id": "mithril_ingot", "out": 1, "in": {"mithril_ore": 2, "coal": 2}, "station": "furnace"},
	{"id": "ember_ingot", "out": 1, "in": {"ember_ore": 2, "coal": 2}, "station": "furnace"},
	{"id": "hellsteel_ingot", "out": 1, "in": {"hellsteel_ore": 2, "brimstone": 1, "coal": 2}, "station": "furnace"},
	{"id": "mithril_axe", "out": 1, "in": {"mithril_ingot": 3, "stick": 2}, "station": "anvil"},
	{"id": "mithril_pickaxe", "out": 1, "in": {"mithril_ingot": 3, "stick": 2}, "station": "anvil"},
	{"id": "mithril_sword", "out": 1, "in": {"mithril_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "mithril_helm", "out": 1, "in": {"mithril_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "mithril_armor", "out": 1, "in": {"mithril_ingot": 8, "leather": 2}, "station": "anvil"},
	{"id": "mithril_boots", "out": 1, "in": {"mithril_ingot": 3, "frost_pelt": 1}, "station": "anvil"},
	{"id": "mithril_shield", "out": 1, "in": {"mithril_ingot": 5, "plank": 2}, "station": "anvil"},
	{"id": "mithril_arrow", "out": 6, "in": {"mithril_ingot": 1, "stick": 3, "feather": 2}, "station": "anvil"},
	{"id": "ember_blade", "out": 1, "in": {"ember_ingot": 5, "magma_core": 1, "leather": 1}, "station": "anvil"},
	{"id": "ember_helm", "out": 1, "in": {"ember_ingot": 4, "ash": 2}, "station": "anvil"},
	{"id": "ember_bow", "out": 1, "in": {"ember_ingot": 2, "living_root": 2, "bowstring": 1}, "station": "workbench"},
	{"id": "fire_arrow", "out": 6, "in": {"ember_ingot": 1, "stick": 3, "fire_gland": 1}, "station": "anvil"},
	{"id": "basalt_shield", "out": 1, "in": {"basalt": 8, "ember_ingot": 1}, "station": "anvil"},
	{"id": "hellsteel_pickaxe", "out": 1, "in": {"hellsteel_ingot": 3, "stick": 2}, "station": "anvil"},
	{"id": "hellsteel_greatsword", "out": 1, "in": {"hellsteel_ingot": 6, "demon_horn": 1, "leather": 2}, "station": "anvil"},
	{"id": "hellsteel_helm", "out": 1, "in": {"hellsteel_ingot": 4, "leather": 1}, "station": "anvil"},
	{"id": "hellsteel_plate", "out": 1, "in": {"hellsteel_ingot": 9, "leather": 3, "ash": 3}, "station": "anvil"},
	{"id": "hellsteel_boots", "out": 1, "in": {"hellsteel_ingot": 3, "leather": 1}, "station": "anvil"},
	{"id": "bone_crown", "out": 1, "in": {"cursed_bone": 6, "demon_horn": 1}, "station": "anvil"},
	{"id": "amber_amulet", "out": 1, "in": {"amber": 3, "gold_ingot": 2}, "station": "anvil"},
	{"id": "sunstone_ring", "out": 1, "in": {"sunstone": 2, "gold_ingot": 1}, "station": "anvil"},
	{"id": "frost_ring", "out": 1, "in": {"frost_crystal": 3, "silver_ingot": 2}, "station": "anvil"},
	{"id": "demon_ring", "out": 1, "in": {"demon_horn": 2, "hellsteel_ingot": 1}, "station": "anvil"},
	{"id": "fossil_charm", "out": 1, "in": {"fossil": 2, "rope": 1}, "station": "workbench"},
	{"id": "parka", "out": 1, "in": {"frost_pelt": 4, "leather": 2}, "station": "tanning_rack"},
	{"id": "snow_boots", "out": 1, "in": {"frost_pelt": 2, "leather": 1}, "station": "tanning_rack"},
	{"id": "desert_wrap", "out": 1, "in": {"cloth": 3, "rope": 1}, "station": "loom"},
	{"id": "sun_robe", "out": 1, "in": {"cloth": 5, "silk": 2}, "station": "loom"},
	{"id": "fire_cloak", "out": 1, "in": {"silk_cloth": 3, "ash": 4, "fire_gland": 2}, "station": "loom"},
	{"id": "frost_staff", "out": 1, "in": {"frost_crystal": 4, "mithril_ingot": 1, "stick": 2}, "station": "alchemy_table"},
	{"id": "fire_staff", "out": 1, "in": {"magma_core": 2, "ember_ingot": 2, "stick": 2}, "station": "alchemy_table"},
	{"id": "soul_amulet", "out": 1, "in": {"soul_shard": 4, "gold_ingot": 2, "demon_horn": 1}, "station": "alchemy_table"},
	{"id": "cooling_draught", "out": 1, "in": {"glass_vial": 1, "ice": 2, "herb": 1}, "station": "alchemy_table"},
	{"id": "warming_tonic", "out": 1, "in": {"glass_vial": 1, "fire_petal": 1, "herb": 1}, "station": "alchemy_table"},
	{"id": "moon_elixir", "out": 1, "in": {"glass_vial": 1, "moon_petal": 2, "royal_jelly": 1}, "station": "alchemy_table"},
	{"id": "blood_salve", "out": 2, "in": {"blood_moss": 3, "resin": 1}, "station": "alchemy_table"},
	{"id": "cactus_salad", "out": 1, "in": {"cactus_pulp": 2, "herb": 1, "salt": 1}, "station": "cooking_pot"},
	{"id": "date_cake", "out": 1, "in": {"flour": 2, "dates": 4, "egg": 1}, "station": "cooking_pot"},
	{"id": "snowberry_tart", "out": 1, "in": {"flour": 2, "snowberry": 4, "honey": 1}, "station": "cooking_pot"},
	{"id": "spiced_stew", "out": 1, "in": {"cooked_meat": 2, "fire_petal": 1, "potato": 2, "salt": 1}, "station": "cooking_pot"},
]

## Crafting stations (node groups) with display names; "" means by hand.
const STATIONS := {
	"": "Handcraft", "campfire": "Campfire", "workbench": "Workbench", "furnace": "Furnace",
	"anvil": "Anvil", "cooking_pot": "Cooking Pot", "tanning_rack": "Tanning Rack", "stonecutter": "Stonecutter",
	"loom": "Loom", "alchemy_table": "Alchemy Table",
}


## Display categories, in the order used by recipe books and backpack sorting.
const CATEGORIES := ["tool", "weapon", "ammo", "armor", "accessory", "medicine", "food",
	"station", "building", "material", "creature", "resource"]
const CATEGORY_NAMES := {
	"tool": "Tool", "weapon": "Weapon", "ammo": "Ammunition", "armor": "Armor",
	"accessory": "Accessory", "medicine": "Medicine", "food": "Food", "station": "Station",
	"building": "Building", "material": "Material", "creature": "Creature part", "resource": "Resource",
}
const _ARMOR_ORDER := ["head", "body", "feet", "offhand"]
const _BASIC_RESOURCES := ["wood", "stone", "berry"]

static var _category_cache := {}
static var _recipes_cache := {}


## Category of an item, derived from its fields (see CATEGORIES).
static func category_of(id: String) -> String:
	if _category_cache.has(id):
		return _category_cache[id]
	var it: Dictionary = ITEMS[id]
	var slot := slot_of(id)
	var cat := "resource"
	if it.has("tool"):
		cat = "tool"
	elif slot == "weapon":
		cat = "weapon"
	elif it.get("arrow", 0) > 0:
		cat = "ammo"
	elif slot in _ARMOR_ORDER:
		cat = "armor"
	elif slot in ["ring", "amulet"]:
		cat = "accessory"
	elif it.get("food", 0.0) > 0.0:
		cat = "food"
	elif is_consumable(id):
		cat = "medicine"
	elif STATIONS.has(id) or id == "campfire" or id == "chest":
		cat = "station"
	elif BuildCatalog.is_placeable(id):
		cat = "building"
	elif id in _BASIC_RESOURCES or _is_node_yield(id):
		cat = "resource"
	elif _is_creature_drop(id):
		cat = "creature"
	elif RECIPES.any(func(r): return r.id == id):
		cat = "material"
	_category_cache[id] = cat
	return cat


static func category_name(id: String) -> String:
	return CATEGORY_NAMES[category_of(id)]


static func _is_node_yield(id: String) -> bool:
	for t in ResourceCatalog.NODES:
		if ResourceCatalog.NODES[t].item == id:
			return true
	return false


static func _is_creature_drop(id: String) -> bool:
	for c in EnemyCatalog.TYPES:
		for d in EnemyCatalog.def(c).drops:
			if d.id == id:
				return true
	return false


## Rough strength used to order items inside a category (weakest first).
static func power_of(id: String) -> float:
	var it: Dictionary = ITEMS[id]
	return it.get("tier", 0) * 10.0 + it.get("dmg", 0) + it.get("armor", 0) * 2.0 + it.get("hp", 0) / 5.0 \
		+ it.get("block", 0) / 5.0 + it.get("arrow", 0) + it.get("heal", 0.0) / 5.0 + it.get("food", 0.0) / 5.0 \
		+ it.get("stamina", 0.0) / 10.0


## True when item a sorts before item b: category, sub-kind, strength, name.
static func sorts_before(a: String, b: String) -> bool:
	if a == b:
		return false
	var ca := CATEGORIES.find(category_of(a))
	var cb := CATEGORIES.find(category_of(b))
	if ca != cb:
		return ca < cb
	var sa := _sub_order(a)
	var sb := _sub_order(b)
	if sa != sb:
		return sa < sb
	var pa := power_of(a)
	var pb := power_of(b)
	if not is_equal_approx(pa, pb):
		return pa < pb
	return item_name(a) < item_name(b)


static func _sub_order(id: String) -> int:
	match category_of(id):
		"tool":
			return ["axe", "pickaxe"].find(tool_of(id))
		"weapon":
			return 1 if ranged_of(id) != "" else 0
		"armor":
			return _ARMOR_ORDER.find(slot_of(id))
		"accessory":
			return 0 if slot_of(id) == "ring" else 1
	return 0


## Indices into RECIPES made at a given station ("" = by hand), sorted by category.
static func recipes_at(station: String) -> Array:
	if _recipes_cache.has(station):
		return _recipes_cache[station]
	var out := []
	for i in RECIPES.size():
		if RECIPES[i].station == station:
			out.append(i)
	out.sort_custom(func(x: int, y: int) -> bool:
		var a: String = RECIPES[x].id
		var b: String = RECIPES[y].id
		return sorts_before(a, b) or (a == b and x < y))
	_recipes_cache[station] = out
	return out


## A recipe shows up in its book once any of its ingredients has been discovered.
static func recipe_known(index: int, known: Dictionary) -> bool:
	for id in RECIPES[index]["in"]:
		if known.has(id):
			return true
	return false


## Recipes that the discovery of `id` reveals (none of their other ingredients known yet).
static func recipes_revealed_by(id: String, known: Dictionary) -> Array:
	var out := []
	for i in RECIPES.size():
		if not RECIPES[i]["in"].has(id):
			continue
		var before := false
		for other in RECIPES[i]["in"]:
			if other != id and known.has(other):
				before = true
		if not before:
			out.append(i)
	return out


static func description(id: String) -> String:
	return ITEMS[id].get("desc", "")


static func item_name(id: String) -> String:
	return ITEMS[id].name


static func stack_size(id: String) -> int:
	return ITEMS[id].stack


static func tool_of(id: String) -> String:
	return ITEMS[id].get("tool", "")


static func tier_of(id: String) -> int:
	return ITEMS[id].get("tier", 0)


static func damage_of(id: String) -> int:
	return ITEMS[id].get("dmg", 0)


static func armor_of(id: String) -> int:
	return ITEMS[id].get("armor", 0)


## Hunger restored when eaten (0 = not food).
static func food_of(id: String) -> float:
	return ITEMS[id].get("food", 0.0)


static func hp_of(id: String) -> int:
	return ITEMS[id].get("hp", 0)


## Health restored when consumed (0 = none).
static func heal_of(id: String) -> float:
	return ITEMS[id].get("heal", 0.0)


## True for items that are used up on click (food, medicine, potions).
static func is_consumable(id: String) -> bool:
	var it: Dictionary = ITEMS.get(id, {})
	return it.get("food", 0.0) > 0.0 or it.get("heal", 0.0) > 0.0 or it.get("cure", false) \
		or it.get("stamina", 0.0) > 0.0 or it.get("water", 0.0) > 0.0 or it.get("warmth", 0.0) > 0.0 \
		or it.get("chill", 0.0) > 0.0


## Thirst restored when consumed (0 = none).
static func water_of(id: String) -> float:
	return ITEMS.get(id, {}).get("water", 0.0)


## Cold protection of a worn piece.
static func warm_of(id: String) -> int:
	return ITEMS.get(id, {}).get("warm", 0)


## Heat protection of a worn piece.
static func cool_of(id: String) -> int:
	return ITEMS.get(id, {}).get("cool", 0)


## Projectile kind a weapon fires ("" = melee).
static func ranged_of(id: String) -> String:
	return ITEMS.get(id, {}).get("ranged", "")


## Bonus damage of an arrow (0 = not ammunition).
static func arrow_of(id: String) -> int:
	return ITEMS.get(id, {}).get("arrow", 0)


## Bound items (Keys, Relics) are never lost on death.
static func is_bound(id: String) -> bool:
	return ITEMS.get(id, {}).get("bound", false)


## Equipment slot the item goes into ("" = not equippable).
static func slot_of(id: String) -> String:
	if not ITEMS.has(id):
		return ""
	var item: Dictionary = ITEMS[id]
	if item.has("slot"):
		return item.slot
	return "weapon" if item.get("dmg", 0) > 0 else ""
