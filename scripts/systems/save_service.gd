extends RefCounted
## Reads and writes campaign progression. Kept separate from battle and UI logic.

const DEFAULT_SAVE_PATH := "user://small_warriors.cfg"
const DEFAULT_STAGE_COUNT := 12

static func default_progress(stage_count: int = DEFAULT_STAGE_COUNT) -> Dictionary:
	var stars: Array[int] = []
	for _i in maxi(0, stage_count):
		stars.append(0)
	return {
		"unlocked": 1,
		"wins": 0,
		"sfx_on": true,
		"stars": stars,
		"best_wave": 0,
		"tournament_wins": 0,
	}

static func load_progress(path: String = DEFAULT_SAVE_PATH, stage_count: int = DEFAULT_STAGE_COUNT) -> Dictionary:
	var progress := default_progress(stage_count)
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return progress

	progress["unlocked"] = clampi(int(config.get_value("campaign", "unlocked", 1)), 1, maxi(1, stage_count))
	progress["wins"] = maxi(0, int(config.get_value("campaign", "wins", 0)))
	progress["sfx_on"] = bool(config.get_value("campaign", "sfx", true))
	progress["best_wave"] = maxi(0, int(config.get_value("records", "best_wave", 0)))
	progress["tournament_wins"] = maxi(0, int(config.get_value("records", "tournament_wins", 0)))

	var raw_stars := str(config.get_value("campaign", "stars", ""))
	var stored_stars := raw_stars.split(",")
	var normalized_stars: Array[int] = []
	for index in maxi(0, stage_count):
		var star_value := int(stored_stars[index]) if index < stored_stars.size() else 0
		normalized_stars.append(clampi(star_value, 0, 3))
	progress["stars"] = normalized_stars
	return progress

static func save_progress(progress: Dictionary, path: String = DEFAULT_SAVE_PATH, stage_count: int = DEFAULT_STAGE_COUNT) -> Error:
	var config := ConfigFile.new()
	config.set_value("campaign", "unlocked", clampi(int(progress.get("unlocked", 1)), 1, maxi(1, stage_count)))
	config.set_value("campaign", "wins", maxi(0, int(progress.get("wins", 0))))
	config.set_value("campaign", "sfx", bool(progress.get("sfx_on", true)))
	config.set_value("records", "best_wave", maxi(0, int(progress.get("best_wave", 0))))
	config.set_value("records", "tournament_wins", maxi(0, int(progress.get("tournament_wins", 0))))

	var source_stars: Array = progress.get("stars", [])
	var stored_stars: Array[String] = []
	for index in maxi(0, stage_count):
		var star_value := int(source_stars[index]) if index < source_stars.size() else 0
		stored_stars.append(str(clampi(star_value, 0, 3)))
	config.set_value("campaign", "stars", ",".join(stored_stars))
	return config.save(path)
