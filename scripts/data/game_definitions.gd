extends RefCounted
## Single source of truth for unit and campaign configuration.
## Keep this file data-focused; gameplay behavior belongs in systems.

const STATS := {
	"MINER": {"cost": 100, "pop": 1, "time": 3.0, "hp": 110.0, "speed": 84.0, "dmg": 8.0, "range": 34.0, "cd": 0.85, "melee": true, "scale": 0.92, "name": "Miner"},
	"SWORD": {"cost": 125, "pop": 1, "time": 3.6, "hp": 175.0, "speed": 102.0, "dmg": 18.0, "range": 42.0, "cd": 0.68, "melee": true, "scale": 1.0, "name": "Sword"},
	"ARCHER": {"cost": 230, "pop": 1, "time": 5.0, "hp": 90.0, "speed": 88.0, "dmg": 14.0, "range": 228.0, "cd": 1.02, "melee": false, "scale": 1.0, "name": "Archer"},
	"SPEAR": {"cost": 360, "pop": 2, "time": 6.4, "hp": 390.0, "speed": 66.0, "dmg": 22.0, "range": 50.0, "cd": 0.95, "melee": true, "scale": 1.06, "name": "Spear"},
	"MAGE": {"cost": 450, "pop": 3, "time": 7.4, "hp": 130.0, "speed": 74.0, "dmg": 18.0, "range": 198.0, "cd": 1.28, "melee": false, "scale": 1.0, "name": "Mage"},
	"GIANT": {"cost": 860, "pop": 4, "time": 11.0, "hp": 880.0, "speed": 46.0, "dmg": 46.0, "range": 62.0, "cd": 1.38, "melee": true, "scale": 1.62, "name": "Giant"},
}

const KIND_ORDER := ["MINER", "SWORD", "ARCHER", "SPEAR", "MAGE", "GIANT"]

const STAGES := [
	{"name": "Dust Road", "blurb": "Train miners. Hold, then break their statue.", "sky": 0, "cap": 14, "miners": 2, "atk": 3, "p_hp": 1500.0, "e_hp": 820.0, "p_gold": 460, "e_gold": 280, "unlock": ["MINER", "SWORD"], "mix": [["SWORD", 1.0]]},
	{"name": "Bow Hollow", "blurb": "Archers join the legion. Close the distance.", "sky": 1, "cap": 16, "miners": 3, "atk": 4, "p_hp": 1600.0, "e_hp": 1000.0, "p_gold": 500, "e_gold": 360, "unlock": ["MINER", "SWORD", "ARCHER"], "mix": [["SWORD", 0.45], ["ARCHER", 0.55]]},
	{"name": "Shield Line", "blurb": "Spears hold the road. Archers punish them.", "sky": 2, "cap": 18, "miners": 3, "atk": 4, "p_hp": 1700.0, "e_hp": 1250.0, "p_gold": 540, "e_gold": 440, "unlock": ["MINER", "SWORD", "ARCHER", "SPEAR"], "mix": [["SWORD", 0.25], ["ARCHER", 0.3], ["SPEAR", 0.45]]},
	{"name": "Ash Coven", "blurb": "Mages burn clumps of soldiers. Spread out.", "sky": 3, "cap": 20, "miners": 3, "atk": 4, "p_hp": 1800.0, "e_hp": 1450.0, "p_gold": 580, "e_gold": 520, "unlock": ["MINER", "SWORD", "ARCHER", "SPEAR", "MAGE"], "mix": [["ARCHER", 0.25], ["SPEAR", 0.35], ["MAGE", 0.4]]},
	{"name": "Stone March", "blurb": "Giants crack statues. Do not let them arrive alone.", "sky": 4, "cap": 22, "miners": 4, "atk": 5, "p_hp": 2000.0, "e_hp": 1750.0, "p_gold": 680, "e_gold": 640, "unlock": ["MINER", "SWORD", "ARCHER", "SPEAR", "MAGE", "GIANT"], "mix": [["SPEAR", 0.3], ["ARCHER", 0.25], ["GIANT", 0.45]]},
	{"name": "Twin Banner", "blurb": "A full host on both sides of the vein.", "sky": 1, "cap": 24, "miners": 4, "atk": 5, "p_hp": 2100.0, "e_hp": 2000.0, "p_gold": 640, "e_gold": 760, "unlock": ["MINER", "SWORD", "ARCHER", "SPEAR", "MAGE", "GIANT"], "mix": [["SWORD", 0.2], ["ARCHER", 0.2], ["SPEAR", 0.25], ["MAGE", 0.15], ["GIANT", 0.2]]},
	{"name": "Night Host", "blurb": "They march early. Answer with a wall.", "sky": 5, "cap": 24, "miners": 4, "atk": 4, "p_hp": 2200.0, "e_hp": 2300.0, "p_gold": 700, "e_gold": 900, "unlock": ["MINER", "SWORD", "ARCHER", "SPEAR", "MAGE", "GIANT"], "mix": [["SPEAR", 0.3], ["MAGE", 0.25], ["GIANT", 0.3], ["ARCHER", 0.15]]},
	{"name": "Crown of Sticks", "blurb": "Last statue on the road. End it.", "sky": 5, "cap": 26, "miners": 5, "atk": 4, "p_hp": 2400.0, "e_hp": 2700.0, "p_gold": 760, "e_gold": 1100, "unlock": ["MINER", "SWORD", "ARCHER", "SPEAR", "MAGE", "GIANT"], "mix": [["SWORD", 0.15], ["ARCHER", 0.2], ["SPEAR", 0.2], ["MAGE", 0.15], ["GIANT", 0.3]]},
]

static func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if STATS.size() != KIND_ORDER.size():
		errors.append("STATS and KIND_ORDER must contain the same number of unit definitions.")

	var seen := {}
	for kind in KIND_ORDER:
		if seen.has(kind):
			errors.append("Duplicate unit kind in KIND_ORDER: " + str(kind))
		seen[kind] = true
		if not STATS.has(kind):
			errors.append("KIND_ORDER references missing unit: " + str(kind))
			continue
		var stat: Dictionary = STATS[kind]
		for field in ["cost", "pop", "time", "hp", "speed", "dmg", "range", "cd", "melee", "scale", "name"]:
			if not stat.has(field):
				errors.append("Unit " + str(kind) + " is missing field: " + field)
		if float(stat.get("cost", -1)) < 0.0:
			errors.append("Unit cost cannot be negative: " + str(kind))
		if int(stat.get("pop", 0)) <= 0:
			errors.append("Unit population must be positive: " + str(kind))
		for field in ["time", "hp", "speed", "cd", "scale"]:
			if float(stat.get(field, 0.0)) <= 0.0:
				errors.append("Unit " + str(kind) + " must have positive " + field + ".")
		if float(stat.get("dmg", -1.0)) < 0.0 or float(stat.get("range", -1.0)) < 0.0:
			errors.append("Unit damage and range cannot be negative: " + str(kind))

	if STAGES.is_empty():
		errors.append("Campaign must define at least one stage.")
	for index in STAGES.size():
		var stage: Dictionary = STAGES[index]
		for field in ["name", "blurb", "sky", "cap", "miners", "atk", "p_hp", "e_hp", "p_gold", "e_gold", "unlock", "mix"]:
			if not stage.has(field):
				errors.append("Stage " + str(index + 1) + " is missing field: " + field)
		if int(stage.get("cap", 0)) <= 0:
			errors.append("Stage " + str(index + 1) + " population cap must be positive.")
		if float(stage.get("p_hp", 0.0)) <= 0.0 or float(stage.get("e_hp", 0.0)) <= 0.0:
			errors.append("Stage " + str(index + 1) + " monument health must be positive.")
		if int(stage.get("p_gold", -1)) < 0 or int(stage.get("e_gold", -1)) < 0:
			errors.append("Stage " + str(index + 1) + " starting gold cannot be negative.")
		for kind in stage.get("unlock", []):
			if not STATS.has(str(kind)):
				errors.append("Stage " + str(index + 1) + " unlocks unknown unit: " + str(kind))
		var mix: Array = stage.get("mix", [])
		if mix.is_empty():
			errors.append("Stage " + str(index + 1) + " needs at least one enemy mix entry.")
		var total_weight := 0.0
		for entry in mix:
			if not entry is Array or entry.size() != 2:
				errors.append("Stage " + str(index + 1) + " has a malformed enemy mix entry.")
				continue
			if not STATS.has(str(entry[0])):
				errors.append("Stage " + str(index + 1) + " enemy mix uses unknown unit: " + str(entry[0]))
			if float(entry[1]) <= 0.0:
				errors.append("Stage " + str(index + 1) + " enemy mix weights must be positive.")
			total_weight += maxf(0.0, float(entry[1]))
		if absf(total_weight - 1.0) > 0.02:
			errors.append("Stage " + str(index + 1) + " enemy mix weights must sum to 1.0.")

	return errors
