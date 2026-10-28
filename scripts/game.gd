extends Node2D
## Small Warriors — side-view stick army. Mine the center vein, train a legion, break the statue.

const SAVE_PATH := "user://small_warriors.cfg"
const W := 1280.0
const H := 720.0
const LANE_TOP := 430.0
const LANE_BOT := 578.0
const HOME_X := 168.0
const AWAY_X := 1112.0
const MINE_X := 640.0
const MINE_Y := 512.0
const BAG_MAX := 90.0

const GOLD := Color("#e2b34a")
const BONE := Color("#f3efe6")
const MUTED := Color("#9aa4b2")
const BLUE := Color("#3d8bfd")
const RED := Color("#d64545")
const GREEN := Color("#7dcea0")
const INK := Color(0.05, 0.07, 0.1, 0.94)

const GameDefinitions = preload("res://scripts/data/game_definitions.gd")
const SaveService = preload("res://scripts/systems/save_service.gd")
const STATS = GameDefinitions.STATS
const KIND_ORDER = GameDefinitions.KIND_ORDER
const STAGES = GameDefinitions.STAGES

var rng := RandomNumberGenerator.new()
var screen := "menu"
var paused := false
var sfx_on := true
var unlocked := 1
var stars: Array = [0, 0, 0, 0, 0, 0, 0, 0]
var wins := 0
var stage_i := 0
var gold := 0
var enemy_gold := 0
var player_hp := 1.0
var player_max := 1.0
var enemy_hp := 1.0
var enemy_max := 1.0
var p_order := "defend"
var e_order := "defend"
var units: Array = []
var projectiles: Array = []
var particles: Array = []
var floaters: Array = []
var player_queue: Array = []
var enemy_queue: Array = []
var player_train_t := 0.0
var enemy_train_t := 0.0
var next_id := 1
var selected_id := -1
var joy := Vector2.ZERO
var key_move := Vector2.ZERO
var held := {}
var action_held := false
var pointers := {}
var ai_timer := 0.0
var tick := 0.0
var battle_time := 0.0
var intro_t := 0.0
var hint_t := 0.0
var toast := ""
var toast_t := 0.0
var shake := 0.0
var ending := ""
var ending_t := 0.0
var result_stars := 0
var miner_warned := false
var sfx_players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var sfx_streams := {}

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--validate-data"):
		var data_errors: PackedStringArray = GameDefinitions.validation_errors()
		if data_errors.is_empty():
			print("DATA_VALIDATION_OK: unit and campaign definitions are consistent.")
			get_tree().quit(0)
		else:
			for issue in data_errors:
				push_error("DATA_VALIDATION_FAIL: " + issue)
			get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--validate-save"):
		get_tree().quit(0 if _validate_save_service() else 1)
		return
	rng.randomize()
	_load_save()
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -6.0
		add_child(player)
		sfx_players.append(player)
	music = AudioStreamPlayer.new()
	music.volume_db = -16.0
	add_child(music)
	sfx_streams = {
		"ui": _tone(720.0, 0.05, 0.22, 0.0),
		"coin": _tone(940.0, 0.09, 0.2, 0.0),
		"hit": _tone(160.0, 0.06, 0.28, 0.0),
		"shoot": _tone(540.0, 0.05, 0.16, 0.0),
		"die": _tone(96.0, 0.16, 0.26, 0.0),
		"win": _arpeggio([523.0, 659.0, 784.0], 0.14),
		"lose": _tone(82.0, 0.32, 0.28, 0.0),
		"train": _tone(410.0, 0.07, 0.18, 0.0),
	}
	music.stream = _drone()
	if sfx_on:
		music.play()
	if OS.get_cmdline_user_args().has("--smoke"):
		_begin(0)
		intro_t = 0.0
		p_order = "attack"
		e_order = "attack"
		for _i in 5:
			_spawn(0, "SWORD")
			_spawn(1, "SWORD")
		_spawn(0, "ARCHER")
		_spawn(1, "ARCHER")
		_spawn(0, "GIANT")
		var start_p := player_hp
		var start_e := enemy_hp
		var start_gold := gold
		for _n in 500:
			_step(0.05)
		var lead_x := 0.0
		for u in units:
			if int(u["side"]) == 0 and str(u["kind"]) != "MINER":
				lead_x = maxf(lead_x, float(u["x"]))
		print("SMOKE end=", ending, " dp=", int(start_p - player_hp), " de=", int(start_e - enemy_hp), " lead=", int(lead_x), " goldd=", gold - start_gold, " units=", units.size())
		var smoke_ok := lead_x >= 450.0 or ending != ""
		if not smoke_ok:
			push_error("SMOKE_FAIL: friendly combat units did not advance far enough.")
			for u in units:
				print(" U ", u["side"], " ", u["kind"], " x=", int(u["x"]), " hp=", int(u["hp"]))
			get_tree().quit(1)
		else:
			print("SMOKE_OK: battle simulation advanced; ending=", ending, " player_hp=", int(player_hp), " enemy_hp=", int(enemy_hp), " units=", units.size())
			get_tree().quit(0)
		return

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	tick += dt
	toast_t = maxf(0.0, toast_t - dt)
	shake = maxf(0.0, shake - dt * 16.0)
	if screen == "battle":
		if intro_t > 0.0 and not paused:
			intro_t = maxf(0.0, intro_t - dt)
		elif ending != "":
			ending_t -= dt
			if ending_t <= 0.0:
				_finish()
		elif not paused:
			_step(dt)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if screen == "battle" and ending == "":
			paused = true
		_save_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func _back() -> void:
	if screen == "battle":
		if ending != "":
			screen = "map"
		else:
			paused = not paused
	elif screen == "help" or screen == "map" or screen == "result":
		screen = "menu" if screen != "result" else "map"
		if screen == "menu":
			pass
		_save_game()
	else:
		_save_game()
		get_tree().quit()

func _load_save() -> void:
	var progress: Dictionary = SaveService.load_progress(SAVE_PATH, STAGES.size())
	unlocked = int(progress.get("unlocked", 1))
	wins = int(progress.get("wins", 0))
	sfx_on = bool(progress.get("sfx_on", true))
	stars = progress.get("stars", [0, 0, 0, 0, 0, 0, 0, 0])

func _save_game() -> void:
	var progress := {
		"unlocked": unlocked,
		"wins": wins,
		"sfx_on": sfx_on,
		"stars": stars,
	}
	var save_error: Error = SaveService.save_progress(progress, SAVE_PATH, STAGES.size())
	if save_error != OK:
		push_warning("Unable to save campaign progress. Error code: " + str(save_error))

func _validate_save_service() -> bool:
	var test_path := "user://small_warriors_save_validation.cfg"
	var sample := {
		"unlocked": mini(2, STAGES.size()),
		"wins": 7,
		"sfx_on": false,
		"stars": [3, 2, 1, 0, 3, 2, 1, 0],
	}
	var write_error: Error = SaveService.save_progress(sample, test_path, STAGES.size())
	if write_error != OK:
		push_error("SAVE_VALIDATION_FAIL: unable to write test save, error=" + str(write_error))
		return false
	var loaded: Dictionary = SaveService.load_progress(test_path, STAGES.size())
	var expected_stars: Array = []
	for i in STAGES.size():
		expected_stars.append(int(sample["stars"][i]) if i < sample["stars"].size() else 0)
	var valid: bool = (
		int(loaded.get("unlocked", 0)) == int(sample["unlocked"])
		and int(loaded.get("wins", -1)) == int(sample["wins"])
		and bool(loaded.get("sfx_on", true)) == bool(sample["sfx_on"])
		and loaded.get("stars", []) == expected_stars
	)
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	if remove_error != OK:
		push_warning("Could not remove temporary save validation file: " + str(remove_error))
	if valid:
		print("SAVE_VALIDATION_OK: campaign progress round-trip passed.")
	else:
		push_error("SAVE_VALIDATION_FAIL: round-trip values did not match.")
	return valid

func _stage() -> Dictionary:
	return STAGES[stage_i]

func _begin(index: int) -> void:
	stage_i = clampi(index, 0, STAGES.size() - 1)
	var stg := _stage()
	screen = "battle"
	paused = false
	ending = ""
	ending_t = 0.0
	intro_t = 1.65
	gold = int(stg["p_gold"])
	enemy_gold = int(stg["e_gold"])
	player_hp = float(stg["p_hp"])
	player_max = player_hp
	enemy_hp = float(stg["e_hp"])
	enemy_max = enemy_hp
	p_order = "defend"
	e_order = "defend"
	units.clear()
	projectiles.clear()
	particles.clear()
	floaters.clear()
	player_queue.clear()
	enemy_queue.clear()
	player_train_t = 0.0
	enemy_train_t = 0.0
	selected_id = _spawn(0, "MINER")
	_spawn(1, "MINER")
	if stage_i >= 1:
		_spawn(0, "SWORD")
	if stage_i >= 3:
		_spawn(0, "ARCHER")
	if stage_i >= 2:
		_spawn(1, "SWORD")
	if stage_i >= 4:
		_spawn(1, "ARCHER")
	if stage_i >= 6:
		_spawn(1, "SPEAR")
	if stage_i >= 7:
		_spawn(1, "GIANT")
	ai_timer = 0.4
	battle_time = 0.0
	hint_t = 8.0
	miner_warned = false
	joy = Vector2.ZERO
	action_held = false
	_toast(_stage_name_fa(stage_i))

func _finish() -> void:
	var won := ending == "win"
	result_stars = 0
	if won:
		var ratio := player_hp / maxf(1.0, player_max)
		result_stars = 1
		if ratio >= 0.42:
			result_stars = 2
		if ratio >= 0.7:
			result_stars = 3
		if int(stars[stage_i]) < result_stars:
			stars[stage_i] = result_stars
		if stage_i + 1 >= unlocked and unlocked < 8:
			unlocked = stage_i + 2
		wins += 1
	screen = "result"
	ending = "" if won else "lose"
	_save_game()

func _spawn(side: int, kind: String) -> int:
	var st: Dictionary = STATS[kind]
	var id := next_id
	next_id += 1
	var y := (LANE_TOP + LANE_BOT) * 0.5 + rng.randf_range(-34.0, 34.0)
	units.append({
		"id": id, "side": side, "kind": kind,
		"x": (HOME_X + 28.0) if side == 0 else (AWAY_X - 28.0), "y": y,
		"hp": float(st["hp"]), "max_hp": float(st["hp"]), "bag": 0.0,
		"cd": rng.randf() * 0.25, "ability": 0.0, "block": 0.0, "stun": 0.0,
		"anim": rng.randf() * TAU, "flash": 0.0, "dead": 0.0,
		"facing": 1.0 if side == 0 else -1.0,
		"slot": rng.randf_range(-30.0, 30.0),
		"moving": false,
		"leap": 0.0, "leap_x": 0.0, "leap_y": 0.0,
	})
	return id

func _unlocked(kind: String) -> bool:
	return kind in _stage()["unlock"]

func _enqueue(side: int, kind: String) -> bool:
	if not STATS.has(kind):
		return false
	var st: Dictionary = STATS[kind]
	if side == 0 and not _unlocked(kind):
		_toast(str(st["name"]) + " unlocks later")
		return false
	var purse := gold if side == 0 else enemy_gold
	if purse < int(st["cost"]):
		if side == 0:
			_toast("Not enough gold")
			_sfx("ui")
		return false
	if _pop(side) + int(st["pop"]) > int(_stage()["cap"]):
		if side == 0:
			_toast("Population is full")
		return false
	var q: Array = player_queue if side == 0 else enemy_queue
	if q.size() >= 5:
		if side == 0:
			_toast("Queue is full")
		return false
	if side == 0:
		gold -= int(st["cost"])
		if player_queue.is_empty():
			player_train_t = float(st["time"])
		player_queue.append(kind)
		_sfx("train")
	else:
		enemy_gold -= int(st["cost"])
		if enemy_queue.is_empty():
			enemy_train_t = float(st["time"])
		enemy_queue.append(kind)
	return true

func _pop(side: int) -> int:
	var n := 0
	for u in units:
		if int(u["side"]) == side and float(u["dead"]) <= 0.0:
			n += int(STATS[str(u["kind"])]["pop"])
	var q: Array = player_queue if side == 0 else enemy_queue
	for kind in q:
		n += int(STATS[str(kind)]["pop"])
	return n

func _count_kind(side: int, kind: String) -> int:
	var n := 0
	for u in units:
		if int(u["side"]) == side and str(u["kind"]) == kind and float(u["dead"]) <= 0.0:
			n += 1
	return n

func _military(side: int) -> int:
	var n := 0
	for u in units:
		if int(u["side"]) == side and str(u["kind"]) != "MINER" and float(u["dead"]) <= 0.0:
			n += 1
	return n

func _step(dt: float) -> void:
	battle_time += dt
	hint_t = maxf(0.0, hint_t - dt)
	_tick_queues(dt)
	ai_timer += dt
	if ai_timer >= 0.9:
		ai_timer = 0.0
		_enemy_think()
	for i in range(units.size()):
		_command(i, dt)
	_separate()
	for i in range(units.size()):
		_clamp_unit(units[i])
	_projectiles(dt)
	_effects(dt)
	_decay(dt)
	_miner_warning()
	if ending == "":
		if player_hp <= 0.0:
			player_hp = 0.0
			ending = "lose"
			ending_t = 0.85
			shake = 8.0
			_sfx("lose")
		elif enemy_hp <= 0.0:
			enemy_hp = 0.0
			ending = "win"
			ending_t = 0.95
			shake = 7.0
			_sfx("win")

func _tick_queues(dt: float) -> void:
	if not player_queue.is_empty():
		player_train_t -= dt
		if player_train_t <= 0.0:
			var kind := str(player_queue.pop_front())
			var id := _spawn(0, kind)
			if selected_id < 0:
				selected_id = id
			_burst(Vector2(HOME_X + 20.0, 500.0), BLUE, 8)
			if player_queue.is_empty():
				player_train_t = 0.0
			else:
				player_train_t = float(STATS[str(player_queue[0])]["time"])
	if not enemy_queue.is_empty():
		enemy_train_t -= dt
		if enemy_train_t <= 0.0:
			var kind2 := str(enemy_queue.pop_front())
			_spawn(1, kind2)
			if enemy_queue.is_empty():
				enemy_train_t = 0.0
			else:
				enemy_train_t = float(STATS[str(enemy_queue[0])]["time"])

func _command(i: int, dt: float) -> void:
	var u: Dictionary = units[i]
	u["ability"] = maxf(0.0, float(u["ability"]) - dt)
	u["block"] = maxf(0.0, float(u["block"]) - dt)
	u["stun"] = maxf(0.0, float(u["stun"]) - dt)
	u["flash"] = maxf(0.0, float(u["flash"]) - dt)
	u["cd"] = maxf(0.0, float(u["cd"]) - dt)
	u["moving"] = false
	if float(u["dead"]) > 0.0:
		units[i] = u
		return
	if float(u["stun"]) > 0.0:
		units[i] = u
		return
	if float(u["leap"]) > 0.0:
		u["x"] = float(u["x"]) + float(u["leap_x"]) * dt
		u["y"] = float(u["y"]) + float(u["leap_y"]) * dt
		u["leap"] = float(u["leap"]) - dt
		u["anim"] = float(u["anim"]) + dt * 18.0
		if float(u["leap"]) <= 0.0:
			u["leap"] = 0.0
			_leap_land(u)
		units[i] = u
		return
	var stick := _stick()
	var manual := int(u["side"]) == 0 and int(u["id"]) == selected_id and (stick.length() > 0.16 or (action_held and str(u["kind"]) == "MINER"))
	if manual:
		_manual(u, dt, stick)
	elif str(u["kind"]) == "MINER":
		_miner_ai(u, dt)
	else:
		_combat_ai(u, dt)
	if str(u["kind"]) == "MINER":
		_try_deposit(u)
	units[i] = u

func _stick() -> Vector2:
	if key_move.length() > 0.05:
		return key_move
	return joy

func _manual(u: Dictionary, dt: float, stick: Vector2) -> void:
	var v := stick
	if v.length() > 1.0:
		v = v.normalized()
	var speed := float(STATS[str(u["kind"])]["speed"])
	if v.length() > 0.12:
		var step_distance := speed * minf(1.0, v.length()) * dt
		u["x"] = float(u["x"]) + v.x * speed * dt
		u["y"] = float(u["y"]) + v.y * speed * 0.88 * dt
		u["moving"] = true
		if absf(v.x) > 0.2:
			u["facing"] = 1.0 if v.x > 0.0 else -1.0
		u["anim"] = float(u["anim"]) + step_distance * 0.105
	if str(u["kind"]) == "MINER" and action_held:
		_dig(u, dt, true)
		_try_attack(u)
	else:
		if not _try_attack(u):
			_maybe_statue(u)

func _miner_ai(u: Dictionary, dt: float) -> void:
	var side := int(u["side"])
	var order := p_order if side == 0 else e_order
	var home := HOME_X if side == 0 else AWAY_X
	var speed := float(STATS["MINER"]["speed"])
	var going_home := order == "garrison" or float(u["bag"]) >= BAG_MAX
	if going_home:
		_walk(u, Vector2(home + (30.0 if side == 0 else -30.0), float(u["y"])), speed, dt)
	else:
		var mine := Vector2(MINE_X + (-26.0 if side == 0 else 26.0), clampf(MINE_Y + float(u["slot"]) * 0.35, LANE_TOP + 8.0, LANE_BOT - 4.0))
		if Vector2(float(u["x"]), float(u["y"])).distance_to(mine) > 28.0:
			_walk(u, mine, speed, dt)
		else:
			_dig(u, dt, false)
	_try_attack(u)

func _dig(u: Dictionary, dt: float, boosted: bool) -> void:
	if Vector2(float(u["x"]), float(u["y"])).distance_to(Vector2(MINE_X, MINE_Y)) > 58.0:
		return
	if float(u["bag"]) >= BAG_MAX:
		return
	var rate := 36.0 if boosted else 18.0
	u["bag"] = minf(BAG_MAX, float(u["bag"]) + rate * dt)
	u["anim"] = float(u["anim"]) + dt * 16.0
	if rng.randf() < dt * 8.0:
		_burst(Vector2(MINE_X, MINE_Y - 10.0), GOLD, 1)

func _try_deposit(u: Dictionary) -> void:
	if float(u["bag"]) <= 1.0:
		return
	var side := int(u["side"])
	var home := HOME_X if side == 0 else AWAY_X
	if absf(float(u["x"]) - home) > 78.0:
		return
	var gained := int(u["bag"])
	u["bag"] = 0.0
	if side == 0:
		gold += gained
	else:
		enemy_gold += gained
	_floater(Vector2(float(u["x"]), float(u["y"]) - 58.0), "+" + str(gained), GOLD)
	_sfx("coin")

func _combat_ai(u: Dictionary, dt: float) -> void:
	var side := int(u["side"])
	var kind := str(u["kind"])
	var st: Dictionary = STATS[kind]
	var order := p_order if side == 0 else e_order
	var speed := float(st["speed"])
	var melee := bool(st["melee"])
	var reach := float(st["range"])
	var aggro := 150.0
	if order == "attack":
		aggro = 280.0
	elif order == "garrison":
		aggro = 110.0
	if not melee:
		aggro = maxf(aggro, reach)
	var foe := _nearest_foe(u, aggro)
	var pos := Vector2(float(u["x"]), float(u["y"]))
	if foe >= 0 and order != "defend":
		var f: Dictionary = units[foe]
		var fp := Vector2(float(f["x"]), float(f["y"]))
		var dist := pos.distance_to(fp)
		if dist <= reach:
			u["facing"] = 1.0 if fp.x >= pos.x else -1.0
			_try_attack(u)
			return
		if not melee and dist < reach * 0.42:
			var away := pos + (pos - fp).normalized() * 36.0
			_walk(u, away, speed, dt)
			return
		_walk(u, fp, speed, dt)
		return
	if order == "defend":
		if foe >= 0:
			var f2: Dictionary = units[foe]
			var fp2 := Vector2(float(f2["x"]), float(f2["y"]))
			if pos.distance_to(fp2) <= reach:
				u["facing"] = 1.0 if fp2.x >= pos.x else -1.0
				_try_attack(u)
				return
		var line := 310.0 if side == 0 else 970.0
		_walk(u, Vector2(line, (LANE_TOP + LANE_BOT) * 0.5 + float(u["slot"])), speed, dt)
		return
	if order == "garrison":
		var gx := 214.0 if side == 0 else 1066.0
		_walk(u, Vector2(gx, (LANE_TOP + LANE_BOT) * 0.5 + float(u["slot"])), speed, dt)
		if foe >= 0:
			_try_attack(u)
		return
	var statue_x := AWAY_X if side == 0 else HOME_X
	var dest := Vector2(statue_x + (-48.0 if side == 0 else 48.0), (LANE_TOP + LANE_BOT) * 0.5 + float(u["slot"]))
	if absf(float(u["x"]) - statue_x) <= reach + 34.0:
		u["facing"] = 1.0 if side == 0 else -1.0
		if not _try_attack(u):
			_maybe_statue(u)
		return
	_walk(u, dest, speed, dt)

func _walk(u: Dictionary, dest: Vector2, speed: float, dt: float) -> void:
	var pos := Vector2(float(u["x"]), float(u["y"]))
	var delta := dest - pos
	var dist := delta.length()
	if dist < 3.0:
		return
	var step := minf(speed * dt, dist)
	var dirv := delta / dist
	u["x"] = float(u["x"]) + dirv.x * step
	u["y"] = float(u["y"]) + dirv.y * step
	u["moving"] = true
	if absf(dirv.x) > 0.12:
		u["facing"] = 1.0 if dirv.x > 0.0 else -1.0
	u["anim"] = float(u["anim"]) + step * 0.105

func _try_attack(u: Dictionary) -> bool:
	if float(u["cd"]) > 0.0:
		return false
	var st: Dictionary = STATS[str(u["kind"])]
	var foe := _nearest_foe(u, float(st["range"]) + 6.0)
	if foe < 0:
		return false
	var f: Dictionary = units[foe]
	u["cd"] = float(st["cd"])
	u["facing"] = 1.0 if float(f["x"]) >= float(u["x"]) else -1.0
	var dmg := _dmg(u)
	if bool(st["melee"]):
		_hurt(f, dmg, float(u["x"]))
		_burst(Vector2(float(f["x"]), float(f["y"]) - 30.0), BONE, 3)
		_sfx("hit")
	else:
		_shoot(u, float(f["x"]), float(f["y"]) - 28.0, dmg, false)
	units[foe] = f
	return true

func _maybe_statue(u: Dictionary) -> void:
	if float(u["cd"]) > 0.0 or str(u["kind"]) == "MINER":
		return
	var side := int(u["side"])
	var statue_x := AWAY_X if side == 0 else HOME_X
	var reach := float(STATS[str(u["kind"])]["range"]) + 28.0
	if absf(float(u["x"]) - statue_x) > reach or absf(float(u["y"]) - 510.0) > 120.0:
		return
	var order := p_order if side == 0 else e_order
	var controlled := side == 0 and int(u["id"]) == selected_id
	if order != "attack" and not controlled:
		return
	u["cd"] = float(STATS[str(u["kind"])]["cd"])
	u["facing"] = 1.0 if side == 0 else -1.0
	var dmg := _dmg(u)
	if str(u["kind"]) == "GIANT":
		dmg *= 1.75
	if bool(STATS[str(u["kind"])]["melee"]):
		_damage_statue(side, dmg)
		_sfx("hit")
	else:
		_shoot(u, statue_x, 470.0, dmg, true)

func _dmg(u: Dictionary) -> float:
	var amount := float(STATS[str(u["kind"])]["dmg"])
	if int(u["side"]) == 0 and int(u["id"]) == selected_id:
		amount *= 1.28
	return amount

func _shoot(u: Dictionary, tx: float, ty: float, dmg: float, at_statue: bool) -> void:
	var origin := Vector2(float(u["x"]) + float(u["facing"]) * 14.0, float(u["y"]) - 36.0)
	var aim := Vector2(tx, ty)
	var vel := (aim - origin)
	if vel.length() < 1.0:
		vel = Vector2(float(u["facing"]), 0.0)
	vel = vel.normalized() * (340.0 if str(u["kind"]) == "ARCHER" else 250.0)
	projectiles.append({
		"side": int(u["side"]), "x": origin.x, "y": origin.y,
		"vx": vel.x, "vy": vel.y, "dmg": dmg,
		"kind": str(u["kind"]), "life": 1.7, "statue": at_statue,
	})
	_sfx("shoot")

func _leap_land(u: Dictionary) -> void:
	var hit := false
	for other in units:
		if int(other["side"]) == int(u["side"]) or float(other["dead"]) > 0.0:
			continue
		if Vector2(float(other["x"]), float(other["y"])).distance_to(Vector2(float(u["x"]), float(u["y"]))) <= 52.0:
			_hurt(other, 30.0, float(u["x"]))
			hit = true
	_burst(Vector2(float(u["x"]), float(u["y"]) - 10.0), GOLD, 10)
	if hit:
		_sfx("hit")
	shake = maxf(shake, 3.0)

func _hurt(u: Dictionary, amount: float, from_x: float) -> void:
	if float(u["dead"]) > 0.0 or float(u["hp"]) <= 0.0:
		return
	if str(u["kind"]) == "SPEAR" and float(u["block"]) > 0.0:
		var facing_hit := (from_x - float(u["x"])) * float(u["facing"])
		if facing_hit >= -4.0:
			amount *= 0.18
			_floater(Vector2(float(u["x"]), float(u["y"]) - 64.0), "BLOCK", Color("#d5e6f7"))
	u["hp"] = float(u["hp"]) - amount
	u["flash"] = 0.1
	_floater(Vector2(float(u["x"]) + rng.randf_range(-8.0, 8.0), float(u["y"]) - 52.0), str(int(amount)), RED if int(u["side"]) == 0 else GOLD)
	if float(u["hp"]) <= 0.0:
		u["hp"] = 0.0
		u["dead"] = 0.55
		u["bag"] = 0.0
		if int(u["id"]) == selected_id:
			selected_id = -1
		_burst(Vector2(float(u["x"]), float(u["y"]) - 24.0), RED if int(u["side"]) == 1 else BLUE, 8)
		_sfx("die")

func _damage_statue(attacker_side: int, amount: float) -> void:
	if attacker_side == 0:
		enemy_hp = maxf(0.0, enemy_hp - amount)
		_floater(Vector2(AWAY_X, 390.0), "-" + str(int(amount)), GOLD)
	else:
		player_hp = maxf(0.0, player_hp - amount)
		_floater(Vector2(HOME_X, 390.0), "-" + str(int(amount)), RED)
	shake = maxf(shake, 2.4)

func _enemy_think() -> void:
	var stg := _stage()
	var miners := _count_kind(1, "MINER")
	var queued_miners := 0
	for kind in enemy_queue:
		if str(kind) == "MINER":
			queued_miners += 1
	if miners + queued_miners < int(stg["miners"]):
		_enqueue(1, "MINER")
	elif _military(1) < int(stg["atk"]) + 3:
		_enqueue(1, _roll(stg["mix"]))
	var eh := enemy_hp / maxf(1.0, enemy_max)
	if eh < 0.3 or _military(1) >= int(stg["atk"]):
		e_order = "attack"
	else:
		e_order = "defend"

func _roll(mix: Array) -> String:
	var total := 0.0
	for pair in mix:
		total += float(pair[1])
	var r := rng.randf() * total
	for pair in mix:
		r -= float(pair[1])
		if r <= 0.0:
			return str(pair[0])
	return str(mix[0][0])

func _use_ability() -> void:
	var index := _index_of(selected_id)
	if index < 0:
		_toast("Tap one of your soldiers")
		return
	var u: Dictionary = units[index]
	if float(u["dead"]) > 0.0:
		return
	if float(u["ability"]) > 0.0:
		_toast("Not ready")
		return
	var kind := str(u["kind"])
	match kind:
		"SWORD":
			var foe := _nearest_foe(u, 230.0)
			var dest := Vector2(float(u["x"]) + float(u["facing"]) * 150.0, float(u["y"]))
			if foe >= 0:
				dest = Vector2(float(units[foe]["x"]), float(units[foe]["y"]))
			var delta := dest - Vector2(float(u["x"]), float(u["y"]))
			if delta.length() > 180.0:
				delta = delta.normalized() * 180.0
			if delta.length() < 24.0:
				delta = Vector2(float(u["facing"]) * 120.0, 0.0)
			u["leap"] = 0.2
			u["leap_x"] = delta.x / 0.2
			u["leap_y"] = delta.y / 0.2
			u["ability"] = 5.2
			_sfx("shoot")
		"ARCHER":
			var foe_a := _nearest_foe(u, 360.0)
			var tx := float(u["x"]) + float(u["facing"]) * 200.0
			var ty := float(u["y"]) - 20.0
			if foe_a >= 0:
				tx = float(units[foe_a]["x"])
				ty = float(units[foe_a]["y"]) - 28.0
			u["ability"] = 2.4
			_shoot(u, tx, ty, _dmg(u) * 1.85, false)
		"SPEAR":
			u["block"] = 1.65
			u["ability"] = 6.4
			_sfx("ui")
		"MAGE":
			u["ability"] = 4.6
			var cx := float(u["x"]) + float(u["facing"]) * 120.0
			var cy := float(u["y"])
			var foe_m := _nearest_foe(u, 280.0)
			if foe_m >= 0:
				cx = float(units[foe_m]["x"])
				cy = float(units[foe_m]["y"])
			for other in units:
				if int(other["side"]) == int(u["side"]) or float(other["dead"]) > 0.0:
					continue
				if Vector2(float(other["x"]), float(other["y"])).distance_to(Vector2(cx, cy)) <= 62.0:
					_hurt(other, _dmg(u) * 1.4, float(u["x"]))
			_burst(Vector2(cx, cy - 16.0), Color("#7eb6ff"), 14)
			_sfx("shoot")
		"GIANT":
			u["ability"] = 6.2
			shake = 9.0
			for other2 in units:
				if int(other2["side"]) == int(u["side"]) or float(other2["dead"]) > 0.0:
					continue
				if Vector2(float(other2["x"]), float(other2["y"])).distance_to(Vector2(float(u["x"]), float(u["y"]))) <= 108.0:
					_hurt(other2, _dmg(u) * 0.85, float(u["x"]))
					other2["stun"] = 0.55
			_sfx("hit")
		_:
			u["ability"] = 0.25
			_try_attack(u)
	units[index] = u

func _nearest_foe(u: Dictionary, radius: float) -> int:
	var best := -1
	var best_d := radius
	var pos := Vector2(float(u["x"]), float(u["y"]))
	for i in range(units.size()):
		var other: Dictionary = units[i]
		if int(other["side"]) == int(u["side"]) or float(other["dead"]) > 0.0 or float(other["hp"]) <= 0.0:
			continue
		var d := pos.distance_to(Vector2(float(other["x"]), float(other["y"])))
		if d < best_d:
			best_d = d
			best = i
	return best

func _index_of(id: int) -> int:
	for i in range(units.size()):
		if int(units[i]["id"]) == id and float(units[i]["dead"]) <= 0.0:
			return i
	return -1

func _separate() -> void:
	for i in range(units.size()):
		for j in range(i + 1, units.size()):
			var a: Dictionary = units[i]
			var b: Dictionary = units[j]
			if float(a["dead"]) > 0.0 or float(b["dead"]) > 0.0:
				continue
			var ra := 30.0 if str(a["kind"]) == "GIANT" else 16.0
			var rb := 30.0 if str(b["kind"]) == "GIANT" else 16.0
			var delta := Vector2(float(a["x"]) - float(b["x"]), float(a["y"]) - float(b["y"]))
			var dist := delta.length()
			var need := ra + rb
			if dist < need and dist > 0.05:
				var push := delta / dist * (need - dist) * 0.5
				a["x"] = float(a["x"]) + push.x * 0.55
				a["y"] = float(a["y"]) + push.y
				b["x"] = float(b["x"]) - push.x * 0.55
				b["y"] = float(b["y"]) - push.y
				units[i] = a
				units[j] = b

func _clamp_unit(u: Dictionary) -> void:
	u["x"] = clampf(float(u["x"]), 116.0, 1164.0)
	u["y"] = clampf(float(u["y"]), LANE_TOP, LANE_BOT)

func _projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["life"] = float(p["life"]) - dt
		var dead_shot := float(p["life"]) <= 0.0
		if not dead_shot:
			for u in units:
				if int(u["side"]) == int(p["side"]) or float(u["dead"]) > 0.0:
					continue
				if Vector2(float(p["x"]), float(p["y"])).distance_to(Vector2(float(u["x"]), float(u["y"]) - 28.0)) <= (22.0 if str(u["kind"]) == "GIANT" else 15.0):
					if str(p["kind"]) == "MAGE":
						_mage_splash(p)
					else:
						_hurt(u, float(p["dmg"]), float(p["x"]) - float(p["vx"]))
					dead_shot = true
					break
		if not dead_shot:
			var statue_x := AWAY_X if int(p["side"]) == 0 else HOME_X
			if absf(float(p["x"]) - statue_x) < 36.0 and float(p["y"]) > 400.0 and float(p["y"]) < 560.0:
				var dmg := float(p["dmg"])
				if str(p["kind"]) == "GIANT":
					dmg *= 1.75
				_damage_statue(int(p["side"]), dmg)
				if str(p["kind"]) == "MAGE":
					_mage_splash(p)
				dead_shot = true
		if dead_shot or float(p["x"]) < 40.0 or float(p["x"]) > 1240.0:
			projectiles.remove_at(i)
		else:
			projectiles[i] = p

func _mage_splash(p: Dictionary) -> void:
	for other in units:
		if int(other["side"]) == int(p["side"]) or float(other["dead"]) > 0.0:
			continue
		if Vector2(float(other["x"]), float(other["y"])).distance_to(Vector2(float(p["x"]), float(p["y"]) + 20.0)) <= 58.0:
			_hurt(other, float(p["dmg"]), float(p["x"]))
	_burst(Vector2(float(p["x"]), float(p["y"])), Color("#8eb6ff"), 8)

func _effects(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["life"] = float(p["life"]) - dt
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["vy"] = float(p["vy"]) + 40.0 * dt
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
		else:
			particles[i] = p
	for i in range(floaters.size() - 1, -1, -1):
		var f: Dictionary = floaters[i]
		f["life"] = float(f["life"]) - dt
		f["y"] = float(f["y"]) - 28.0 * dt
		if float(f["life"]) <= 0.0:
			floaters.remove_at(i)
		else:
			floaters[i] = f

func _decay(dt: float) -> void:
	for i in range(units.size() - 1, -1, -1):
		var u: Dictionary = units[i]
		if float(u["dead"]) > 0.0:
			u["dead"] = float(u["dead"]) - dt
			if float(u["dead"]) <= 0.0:
				if int(u["id"]) == selected_id:
					selected_id = -1
				units.remove_at(i)
			else:
				units[i] = u

func _miner_warning() -> void:
	var alive := _count_kind(0, "MINER")
	var queued := 0
	for kind in player_queue:
		if str(kind) == "MINER":
			queued += 1
	if alive + queued == 0 and not miner_warned:
		miner_warned = true
		_toast("Miners are down. Train another.")
	elif alive > 0:
		miner_warned = false

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for _j in count:
		if particles.size() > 90:
			return
		var a := rng.randf() * TAU
		var speed := rng.randf_range(20.0, 90.0)
		particles.append({"x": pos.x, "y": pos.y, "vx": cos(a) * speed, "vy": sin(a) * speed - 20.0, "life": rng.randf_range(0.25, 0.5), "max": 0.5, "color": color})

func _floater(pos: Vector2, label: String, color: Color) -> void:
	if floaters.size() > 18:
		floaters.pop_front()
	floaters.append({"x": pos.x, "y": pos.y, "life": 0.8, "label": label, "color": color})

func _toast(message: String) -> void:
	toast = message
	toast_t = 2.4

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down(event.index, event.position)
		else:
			_pointer_up(event.index)
	elif event is InputEventScreenDrag:
		_pointer_move(event.index, event.position)
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			held[event.keycode] = true
			_refresh_keys()
			_key_action(event.keycode)
		elif not event.pressed:
			held.erase(event.keycode)
			_refresh_keys()

func _refresh_keys() -> void:
	key_move = Vector2.ZERO
	if held.has(KEY_A) or held.has(KEY_LEFT):
		key_move.x -= 1.0
	if held.has(KEY_D) or held.has(KEY_RIGHT):
		key_move.x += 1.0
	if held.has(KEY_W) or held.has(KEY_UP):
		key_move.y -= 1.0
	if held.has(KEY_S) or held.has(KEY_DOWN):
		key_move.y += 1.0
	if key_move.length() > 1.0:
		key_move = key_move.normalized()

func _key_action(code: int) -> void:
	if code == KEY_ESCAPE:
		if screen == "battle" and ending == "":
			paused = not paused
		return
	if screen != "battle" or paused or ending != "":
		return
	if code == KEY_SPACE or code == KEY_J:
		_use_ability()
	elif code == KEY_1:
		_enqueue(0, "MINER")
	elif code == KEY_2:
		_enqueue(0, "SWORD")
	elif code == KEY_3:
		_enqueue(0, "ARCHER")
	elif code == KEY_4:
		_enqueue(0, "SPEAR")
	elif code == KEY_5:
		_enqueue(0, "MAGE")
	elif code == KEY_6:
		_enqueue(0, "GIANT")
	elif code == KEY_F:
		_set_order("attack")
	elif code == KEY_G:
		_set_order("defend")
	elif code == KEY_H:
		_set_order("garrison")

func _pointer_down(id: int, screen_pos: Vector2) -> void:
	if sfx_on and music != null and not music.playing:
		music.play()
	var p := _to_game(screen_pos)
	var rec := {"p": p, "o": p, "kind": "field", "btn": ""}
	if screen == "battle" and not paused and ending == "" and intro_t <= 0.0:
		if p.distance_to(Vector2(86, 664)) <= 70.0:
			rec["kind"] = "joy"
			_set_joy(p)
		elif p.distance_to(Vector2(1194, 664)) <= 64.0:
			rec["kind"] = "action"
			action_held = true
			_use_ability()
		else:
			var b := _hit_button(p)
			if b != "":
				rec["kind"] = "btn"
				rec["btn"] = b
	else:
		var b2 := _hit_button(p)
		if b2 != "":
			rec["kind"] = "btn"
			rec["btn"] = b2
	pointers[id] = rec

func _pointer_move(id: int, screen_pos: Vector2) -> void:
	if not pointers.has(id):
		return
	var rec: Dictionary = pointers[id]
	rec["p"] = _to_game(screen_pos)
	pointers[id] = rec
	if str(rec["kind"]) == "joy":
		_set_joy(rec["p"])

func _pointer_up(id: int) -> void:
	if not pointers.has(id):
		return
	var rec: Dictionary = pointers[id]
	pointers.erase(id)
	if str(rec["kind"]) == "joy":
		if not _pointer_kind("joy"):
			joy = Vector2.ZERO
	elif str(rec["kind"]) == "action":
		if not _pointer_kind("action"):
			action_held = false
	elif str(rec["kind"]) == "btn":
		if _hit_button(rec["p"]) == str(rec["btn"]):
			_click(str(rec["btn"]))
	elif str(rec["kind"]) == "field":
		if Vector2(rec["o"]).distance_to(Vector2(rec["p"])) < 22.0:
			_field_tap(rec["p"])

func _pointer_kind(kind: String) -> bool:
	for rec in pointers.values():
		if str(rec["kind"]) == kind:
			return true
	return false

func _set_joy(p: Vector2) -> void:
	var d := p - Vector2(86, 664)
	if d.length() > 48.0:
		d = d.normalized() * 48.0
	joy = d / 48.0

func _to_game(screen_pos: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var uniform := minf(viewport_size.x / W, viewport_size.y / H)
	if uniform <= 0.001:
		return screen_pos
	var offset := (viewport_size - Vector2(W, H) * uniform) * 0.5
	return (screen_pos - offset) / uniform

func _set_order(order: String) -> void:
	p_order = order
	_sfx("ui")
	if order == "attack":
		_toast("Army attacking")
	elif order == "defend":
		_toast("Army holding the line")
	else:
		_toast("Garrison — miners falling back")

func _click(id: String) -> void:
	_sfx("ui")
	if id == "campaign":
		screen = "map"
	elif id == "help":
		screen = "help"
	elif id == "sfx":
		sfx_on = not sfx_on
		if sfx_on:
			if music.stream != null and not music.playing:
				music.play()
		else:
			music.stop()
		_save_game()
	elif id == "back_menu":
		screen = "menu"
	elif id.begins_with("stage_"):
		var index := int(id.trim_prefix("stage_"))
		if index < unlocked:
			_begin(index)
		else:
			_toast("Win the previous battle first")
	elif id == "pause":
		paused = true
	elif id == "resume":
		paused = false
	elif id == "retry":
		_begin(stage_i)
	elif id == "to_map":
		paused = false
		screen = "map"
		_save_game()
	elif id == "order_attack":
		_set_order("attack")
	elif id == "order_defend":
		_set_order("defend")
	elif id == "order_garrison":
		_set_order("garrison")
	elif id.begins_with("train_"):
		_enqueue(0, id.trim_prefix("train_"))
	elif id == "next":
		if stage_i + 1 < unlocked:
			_begin(stage_i + 1)
		else:
			screen = "map"
	elif id == "result_retry":
		_begin(stage_i)
	elif id == "result_map":
		screen = "map"

func _field_tap(p: Vector2) -> void:
	if screen != "battle" or paused or ending != "" or intro_t > 0.0:
		return
	if p.y > 590.0:
		return
	var best := -1
	var best_d := 46.0
	for u in units:
		if int(u["side"]) != 0 or float(u["dead"]) > 0.0:
			continue
		var d := p.distance_to(Vector2(float(u["x"]), float(u["y"]) - 30.0))
		if d < best_d:
			best_d = d
			best = int(u["id"])
	if best >= 0:
		selected_id = best
		_sfx("ui")

func _hit_button(p: Vector2) -> String:
	if screen == "menu":
		if Rect2(78, 360, 280, 64).has_point(p):
			return "campaign"
		if Rect2(78, 440, 280, 54).has_point(p):
			return "help"
		if Rect2(78, 508, 280, 48).has_point(p):
			return "sfx"
	elif screen == "help":
		if Rect2(78, 640, 240, 52).has_point(p):
			return "back_menu"
	elif screen == "map":
		if Rect2(40, 28, 140, 44).has_point(p):
			return "back_menu"
		for i in 8:
			if _stage_rect(i).has_point(p):
				return "stage_" + str(i)
	elif screen == "result":
		if Rect2(430, 470, 420, 56).has_point(p):
			return "next" if ending == "" else "result_retry"
		if Rect2(430, 538, 200, 48).has_point(p):
			return "result_retry"
		if Rect2(650, 538, 200, 48).has_point(p):
			return "result_map"
	elif screen == "battle":
		if paused:
			if Rect2(470, 300, 340, 52).has_point(p):
				return "resume"
			if Rect2(470, 364, 340, 52).has_point(p):
				return "retry"
			if Rect2(470, 428, 340, 52).has_point(p):
				return "to_map"
			return ""
		if Rect2(24, 16, 86, 42).has_point(p):
			return "pause"
		if _order_rect(0).has_point(p):
			return "order_attack"
		if _order_rect(1).has_point(p):
			return "order_defend"
		if _order_rect(2).has_point(p):
			return "order_garrison"
		for i in KIND_ORDER.size():
			if _train_rect(i).has_point(p):
				return "train_" + str(KIND_ORDER[i])
	return ""

func _order_rect(i: int) -> Rect2:
	return Rect2(168.0 + float(i) * 158.0, 600.0, 150.0, 42.0)

func _train_rect(i: int) -> Rect2:
	return Rect2(168.0 + float(i) * 148.0, 650.0, 142.0, 58.0)

func _stage_rect(i: int) -> Rect2:
	var col := i % 4
	var row := int(i / 4.0)
	return Rect2(70.0 + float(col) * 300.0, 150.0 + float(row) * 230.0, 276.0, 200.0)

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var uniform := minf(viewport_size.x / W, viewport_size.y / H)
	var offset := (viewport_size - Vector2(W, H) * uniform) * 0.5
	var world_off := offset
	if shake > 0.0:
		world_off += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake * uniform
	draw_set_transform(world_off, 0.0, Vector2.ONE * uniform)
	if screen == "menu":
		_draw_menu()
	elif screen == "help":
		_draw_help()
	elif screen == "map":
		_draw_map()
	else:
		_draw_world()
		draw_set_transform(offset, 0.0, Vector2.ONE * uniform)
		_draw_battle_ui()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_world() -> void:
	_draw_sky()
	_draw_ground()
	_draw_mine()
	_draw_statue(HOME_X, player_hp / maxf(1.0, player_max), true)
	_draw_statue(AWAY_X, enemy_hp / maxf(1.0, enemy_max), false)
	for p in projectiles:
		_draw_shot(p)
	var ordered := units.duplicate()
	ordered.sort_custom(_y_less)
	for u in ordered:
		_draw_stick(u)
	for p in particles:
		var a := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var c: Color = p["color"]
		c.a = a
		draw_circle(Vector2(float(p["x"]), float(p["y"])), 2.2 + a * 2.0, c)
	for f in floaters:
		var c2: Color = f["color"]
		c2.a = clampf(float(f["life"]) / 0.8, 0.0, 1.0)
		_text(str(f["label"]), Vector2(float(f["x"]) - 10.0, float(f["y"])), 14, c2)

func _y_less(a, b) -> bool:
	return float(a["y"]) < float(b["y"])

func _sky_colors() -> Array:
	var skies := [
		[Color("#1c3358"), Color("#c4784a")],
		[Color("#24324a"), Color("#d7a15a")],
		[Color("#1a3044"), Color("#6f8f78")],
		[Color("#2a2438"), Color("#a85a48")],
		[Color("#3a3328"), Color("#c4a36a")],
		[Color("#121826"), Color("#3d4d66")],
	]
	var idx := 0
	if screen == "battle" or screen == "result":
		idx = int(_stage()["sky"])
	return skies[idx]

func _draw_sky() -> void:
	var cols: Array = _sky_colors()
	var top: Color = cols[0]
	var bot: Color = cols[1]
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(-30, t * 430.0 - 10.0, W + 60.0, 24.0), top.lerp(bot, t))
	var night := int(_stage()["sky"]) == 5
	var sun_col := Color("#fff0c7") if not night else Color("#b8c8f0")
	draw_circle(Vector2(1000, 118), 54, Color(sun_col.r, sun_col.g, sun_col.b, 0.10))
	draw_circle(Vector2(1000, 118), 39, Color(sun_col.r, sun_col.g, sun_col.b, 0.82))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, 382), Vector2(110, 328), Vector2(218, 354), Vector2(350, 292),
		Vector2(488, 370), Vector2(620, 334), Vector2(770, 382), Vector2(930, 315),
		Vector2(1080, 352), Vector2(1210, 302), Vector2(1320, 380), Vector2(1320, 440), Vector2(-40, 440)
	]), Color("#283747"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, 408), Vector2(170, 358), Vector2(330, 398), Vector2(490, 346),
		Vector2(650, 402), Vector2(830, 356), Vector2(1020, 404), Vector2(1180, 360),
		Vector2(1320, 410), Vector2(1320, 450), Vector2(-30, 450)
	]), Color("#34443f"))
	for ruin_x in [76.0, 414.0, 856.0, 1190.0]:
		draw_rect(Rect2(ruin_x, 365, 18, 48), Color("#27323a"))
		draw_rect(Rect2(ruin_x - 5, 358, 28, 8), Color("#3e4b50"))
		draw_line(Vector2(ruin_x + 9, 343), Vector2(ruin_x + 9, 368), Color("#7d6a52"), 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(ruin_x + 10, 344), Vector2(ruin_x + 28, 350), Vector2(ruin_x + 10, 357)
		]), BLUE if ruin_x < 640.0 else RED)

func _draw_ground() -> void:
	draw_rect(Rect2(-30, 400, W + 60, 340), Color("#202b2a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 428), Vector2(1300, 420), Vector2(1300, 720), Vector2(-20, 720)
	]), Color("#354238"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(70, 465), Vector2(1210, 450), Vector2(1250, 612), Vector2(35, 624)
	]), Color("#46513a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(112, 491), Vector2(1168, 483), Vector2(1185, 579), Vector2(94, 590)
	]), Color("#72583e"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(112, 491), Vector2(1168, 483), Vector2(1160, 496), Vector2(104, 505)
	]), Color("#9a7952"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(94, 590), Vector2(1185, 579), Vector2(1220, 620), Vector2(62, 635)
	]), Color("#26352e"))
	for i in 25:
		var x := 36.0 + float(i) * 51.0
		var y := 438.0 + sin(float(i) * 1.7) * 7.0
		draw_line(Vector2(x, y + 8.0), Vector2(x + 5.0, y - 1.0), Color("#74835a", 0.65), 2.0)
	for i in 18:
		var x := 122.0 + float(i) * 59.0
		var y := 522.0 + sin(float(i) * 2.3) * 22.0
		var stone := Color("#8a7357") if i % 2 == 0 else Color("#665943")
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 12, y), Vector2(x - 5, y - 4), Vector2(x + 11, y - 3),
			Vector2(x + 15, y + 2), Vector2(x + 1, y + 5), Vector2(x - 10, y + 4)
		]), stone)
	draw_line(Vector2(40, 635), Vector2(1240, 619), Color("#66735a", 0.7), 2.0)

func _draw_mine() -> void:
	var bob := sin(tick * 3.0) * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(MINE_X - 54, MINE_Y + 8), Vector2(MINE_X - 20, MINE_Y - 46 + bob), Vector2(MINE_X + 8, MINE_Y - 8),
		Vector2(MINE_X + 36, MINE_Y - 52), Vector2(MINE_X + 62, MINE_Y + 10)
	]), Color("#5c5348"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(MINE_X - 10, MINE_Y - 8), Vector2(MINE_X + 4, MINE_Y - 28), Vector2(MINE_X + 18, MINE_Y - 6)
	]), GOLD)
	draw_circle(Vector2(MINE_X - 16, MINE_Y - 18 + bob), 4.0, Color("#ffe29a"))
	_text("GOLD", Vector2(MINE_X - 22, MINE_Y - 58), 12, GOLD)

func _draw_statue(x: float, ratio: float, friendly: bool) -> void:
	var team := BLUE if friendly else RED
	var stone := Color("#59616b") if friendly else Color("#63504f")
	var shade := stone.darkened(0.28)
	var light := stone.lightened(0.18)
	# Perspective base and layered stone keep.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 70, 548), Vector2(x - 52, 530), Vector2(x + 57, 530),
		Vector2(x + 76, 548), Vector2(x + 64, 564), Vector2(x - 61, 564)
	]), Color("#171f24", 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 54, 388), Vector2(x + 42, 388), Vector2(x + 58, 410),
		Vector2(x + 58, 522), Vector2(x - 54, 522)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 42, 388), Vector2(x + 59, 408), Vector2(x + 59, 522), Vector2(x + 42, 522)
	]), shade)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 64, 383), Vector2(x - 43, 366), Vector2(x + 48, 366),
		Vector2(x + 62, 383), Vector2(x + 47, 397), Vector2(x - 52, 397)
	]), light)
	draw_rect(Rect2(x - 58, 402, 103, 18), shade)
	for row in 4:
		for col in 3:
			var bx := x - 42.0 + float(col) * 30.0 + (8.0 if row % 2 == 1 else 0.0)
			var by := 427.0 + float(row) * 25.0
			draw_rect(Rect2(bx, by, 24, 18), Color("#f0d7a4", 0.07), false, 1.0)
	for seam_y in [424.0, 450.0, 477.0, 503.0]:
		draw_line(Vector2(x - 49, seam_y), Vector2(x + 39, seam_y), Color("#c2b59d", 0.36), 1.5)
	# Tall central tower, crenellations and deep-set gate.
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 33, 388), Vector2(x - 28, 341), Vector2(x - 15, 329),
		Vector2(x + 24, 329), Vector2(x + 37, 341), Vector2(x + 42, 388)
	]), stone.lightened(0.06))
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 24, 329), Vector2(x + 42, 341), Vector2(x + 42, 388), Vector2(x + 24, 388)
	]), shade)
	draw_rect(Rect2(x - 34, 348, 78, 9), shade)
	for crenel in 5:
		var cx := x - 31.0 + float(crenel) * 17.0
		draw_rect(Rect2(cx, 334, 11, 15), light if crenel % 2 == 0 else stone)
	draw_rect(Rect2(x - 13, 361, 23, 27), Color("#222a31"))
	draw_arc(Vector2(x - 1.5, 362), 11.5, PI, TAU, 16, Color("#b9a98a"), 2.0, true)
	draw_rect(Rect2(x - 8, 369, 13, 19), Color("#111a20"))
	draw_line(Vector2(x - 2, 369), Vector2(x - 2, 387), Color("#8f7651"), 1.0)
	# Original team pennant and bright core.
	draw_line(Vector2(x + 4, 296), Vector2(x + 4, 337), Color("#a88a5d"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 5, 298), Vector2(x + 31, 306), Vector2(x + 5, 319)
	]), team)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, 310), Vector2(x + 10, 322), Vector2(x, 334), Vector2(x - 10, 322)
	]), team.lerp(GOLD, 0.38))
	draw_line(Vector2(x - 48, 543), Vector2(x + 48, 543), Color("#d7bd8b", 0.45), 2.0)
	draw_rect(Rect2(x - 44, 574, 88, 8), Color(0, 0, 0, 0.62))
	draw_rect(Rect2(x - 42, 576, 84.0 * clampf(ratio, 0.0, 1.0), 4), team)

func _draw_shot(p: Dictionary) -> void:
	var a := Vector2(float(p["x"]), float(p["y"]))
	var b := a - Vector2(float(p["vx"]), float(p["vy"])).normalized() * 12.0
	var col := GOLD if str(p["kind"]) == "ARCHER" else Color("#9ec2ff")
	if str(p["kind"]) == "MAGE":
		draw_circle(a, 5.0, col)
	else:
		draw_line(b, a, col, 2.0, true)

func _draw_stick(u: Dictionary) -> void:
	var kind := str(u["kind"])
	var st: Dictionary = STATS[kind]
	var sc := float(st["scale"])
	var x := float(u["x"])
	var y := float(u["y"])
	var facing := float(u["facing"])
	var walk := sin(float(u["anim"])) if bool(u.get("moving", false)) else 0.0
	var dead := float(u["dead"])
	var team := BLUE if int(u["side"]) == 0 else RED
	if dead > 0.0:
		y += (0.55 - dead) * 26.0
		walk = 0.0
	if int(u["id"]) == selected_id and int(u["side"]) == 0 and dead <= 0.0:
		var pulse := 0.65 + 0.35 * sin(tick * 6.0)
		draw_arc(Vector2(x, y + 2.0), 18.0 * sc, 0.0, TAU, 22, Color(GOLD.r, GOLD.g, GOLD.b, pulse), 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, y - 78.0 * sc), Vector2(x - 6, y - 68.0 * sc), Vector2(x + 6, y - 68.0 * sc)
		]), GOLD)
	var skin := BONE
	if float(u["flash"]) > 0.0:
		skin = Color("#ffb4b4")
	var idle_bob := sin(tick * 2.5 + float(u["id"])) * 0.7 if not bool(u.get("moving", false)) and dead <= 0.0 else 0.0
	var bob := absf(walk) * 1.5 * sc + idle_bob
	var hip := Vector2(x, y - 18.0 * sc + bob)
	var chest := Vector2(x - facing * (1.0 + walk * 2.0) * sc, y - 35.0 * sc + bob)
	var head := Vector2(chest.x + facing * 1.0 * sc, y - 49.0 * sc + bob)
	var lw := 3.8 * sc
	var foot_lift_a := maxf(0.0, cos(float(u["anim"]))) * 3.5 * sc if bool(u.get("moving", false)) else 0.0
	var foot_lift_b := maxf(0.0, -cos(float(u["anim"]))) * 3.5 * sc if bool(u.get("moving", false)) else 0.0
	var foot_a := Vector2(x - (7.0 + walk * 5.0) * sc, y - foot_lift_a)
	var foot_b := Vector2(x + (7.0 + walk * 5.0) * sc, y - foot_lift_b)
	var shadow := PackedVector2Array()
	for j in 16:
		var angle := TAU * float(j) / 16.0
		shadow.append(Vector2(x + cos(angle) * 12.0 * sc, y + 1.5 + sin(angle) * 3.0 * sc))
	draw_colored_polygon(shadow, Color(0.02, 0.03, 0.03, 0.32))
	var knee_a := Vector2((hip.x + foot_a.x) * 0.5 + walk * 2.0 * sc, y - 9.0 * sc - foot_lift_a * 0.4)
	var knee_b := Vector2((hip.x + foot_b.x) * 0.5 - walk * 2.0 * sc, y - 9.0 * sc - foot_lift_b * 0.4)
	draw_line(hip + Vector2(-3.0 * sc, 0), knee_b, team.darkened(0.28), 5.0 * sc, true)
	draw_line(knee_b, foot_b + Vector2(0, -1.5 * sc), skin.darkened(0.15), 3.8 * sc, true)
	draw_circle(knee_b, 2.0 * sc, skin.darkened(0.1))
	draw_line(hip + Vector2(3.0 * sc, 0), knee_a, team, 5.2 * sc, true)
	draw_line(knee_a, foot_a + Vector2(0, -1.5 * sc), skin, 4.0 * sc, true)
	draw_circle(knee_a, 2.2 * sc, skin)
	draw_colored_polygon(PackedVector2Array([foot_b + Vector2(-4.0 * sc, 0), foot_b + Vector2(3.0 * sc, -1.5 * sc), foot_b + Vector2(6.0 * sc, 0), foot_b + Vector2(3.0 * sc, 1.5 * sc), foot_b + Vector2(-4.0 * sc, 1.5 * sc)]), Color("#252b30"))
	draw_colored_polygon(PackedVector2Array([foot_a + Vector2(-4.0 * sc, 0), foot_a + Vector2(3.0 * sc, -1.5 * sc), foot_a + Vector2(6.0 * sc, 0), foot_a + Vector2(3.0 * sc, 1.5 * sc), foot_a + Vector2(-4.0 * sc, 1.5 * sc)]), Color("#3a4248"))
	draw_colored_polygon(PackedVector2Array([chest + Vector2(-7.0 * sc, -2.0 * sc), chest + Vector2(5.0 * sc, -3.0 * sc), hip + Vector2(7.0 * sc, 2.0 * sc), hip + Vector2(4.0 * sc, 6.0 * sc), hip + Vector2(-6.0 * sc, 5.0 * sc), chest + Vector2(-8.0 * sc, 4.0 * sc)]), team.darkened(0.32))
	draw_colored_polygon(PackedVector2Array([chest + Vector2(-5.0 * sc, -3.0 * sc), chest + Vector2(3.0 * sc, -4.0 * sc), hip + Vector2(4.0 * sc, 0), hip + Vector2(1.0 * sc, 4.0 * sc), hip + Vector2(-5.0 * sc, 3.0 * sc), chest + Vector2(-6.0 * sc, 3.0 * sc)]), team.lightened(0.08))
	draw_line(hip + Vector2(-5.0 * sc, 1.0 * sc), hip + Vector2(5.0 * sc, 1.0 * sc), GOLD, 1.8 * sc, true)
	var arm_f := Vector2(x + facing * (10.0 + walk * 2.5) * sc, y - 29.0 * sc + bob)
	var arm_b := Vector2(x - facing * 8.0 * sc - walk * 2.5 * sc, y - 28.0 * sc - walk * 1.5 * sc + bob)
	var elbow_f := arm_f + Vector2(facing * 2.0 * sc, 5.0 * sc)
	var elbow_b := arm_b + Vector2(-facing * 1.0 * sc, 5.0 * sc)
	draw_line(chest + Vector2(-facing * 5.0 * sc, 0), elbow_b, skin.darkened(0.1), lw, true)
	draw_line(elbow_b, arm_b + Vector2(0, 5.0 * sc), skin, lw - 0.4, true)
	draw_circle(elbow_b, 2.0 * sc, skin.darkened(0.1))
	draw_line(chest + Vector2(facing * 5.0 * sc, 0), elbow_f, skin, lw, true)
	draw_line(elbow_f, arm_f, skin, lw - 0.4, true)
	draw_circle(elbow_f, 2.0 * sc, skin)
	draw_colored_polygon(PackedVector2Array([chest + Vector2(-6.0 * sc, -2.0 * sc), chest + Vector2(-1.0 * sc, -4.0 * sc), chest + Vector2(2.0 * sc, 1.0 * sc), chest + Vector2(-5.0 * sc, 3.0 * sc)]), Color("#9ca8b4"))
	draw_colored_polygon(PackedVector2Array([chest + Vector2(2.0 * sc, -4.0 * sc), chest + Vector2(7.0 * sc, -2.0 * sc), chest + Vector2(8.0 * sc, 2.0 * sc), chest + Vector2(3.0 * sc, 3.0 * sc)]), Color("#c3cbd2"))
	draw_circle(head, 6.8 * sc, skin.darkened(0.16))
	draw_circle(head + Vector2(-facing * 1.0 * sc, -0.8 * sc), 5.7 * sc, skin)
	draw_circle(head + Vector2(facing * 2.2 * sc, -0.5 * sc), 1.0 * sc, Color("#1c1a17"))
	_draw_weapon(kind, arm_f, facing, sc, walk, float(u["block"]))
	if dead <= 0.0 and (float(u["hp"]) < float(u["max_hp"]) or int(u["id"]) == selected_id):
		var ratio := clampf(float(u["hp"]) / float(u["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(x - 16, y - 66.0 * sc, 32, 3.5), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(x - 16, y - 66.0 * sc, 32.0 * ratio, 3.5), GREEN if int(u["side"]) == 0 else RED)
	if kind == "MINER" and float(u["bag"]) > 2.0 and dead <= 0.0:
		_text(str(int(u["bag"])), Vector2(x - 8, y - 78.0 * sc), 11, GOLD)

func _draw_weapon(kind: String, hand: Vector2, facing: float, sc: float, _walk: float, block: float) -> void:
	var dir := facing
	if kind == "MINER":
		draw_line(hand, hand + Vector2(dir * 16.0 * sc, -14.0 * sc), Color("#8a6a45"), 3.0 * sc, true)
		draw_line(hand + Vector2(dir * 10.0 * sc, -8.0 * sc), hand + Vector2(dir * 22.0 * sc, -2.0 * sc), Color("#d9dde3"), 3.0 * sc, true)
	elif kind == "ARCHER":
		draw_arc(hand + Vector2(dir * 8.0 * sc, 0), 11.0 * sc, -1.2, 1.2, 10, Color("#e8d7b0"), 1.8 * sc, true)
		draw_line(hand + Vector2(dir * 8.0 * sc, -11.0 * sc), hand + Vector2(dir * 8.0 * sc, 11.0 * sc), Color("#f4efe4"), 1.0)
		draw_line(hand, hand + Vector2(dir * 20.0 * sc, -2.0 * sc), GOLD, 1.6, true)
	elif kind == "SPEAR":
		draw_line(hand, hand + Vector2(dir * 28.0 * sc, -6.0 * sc), Color("#d9dde3"), 2.4 * sc, true)
		draw_line(hand + Vector2(dir * 24.0 * sc, -8.0 * sc), hand + Vector2(dir * 34.0 * sc, -6.0 * sc), GOLD, 3.0 * sc, true)
		var shield := hand + Vector2(dir * (8.0 if block <= 0.0 else 16.0) * sc, 2.0)
		var sh := 16.0 * sc * (1.35 if block > 0.0 else 1.0)
		draw_rect(Rect2(shield.x - 6.0 * sc, shield.y - sh * 0.5, 12.0 * sc, sh), Color("#c4553d") if block > 0.0 else Color("#8d5a45"))
		draw_rect(Rect2(shield.x - 6.0 * sc, shield.y - sh * 0.5, 12.0 * sc, sh), GOLD, false, 1.2)
	elif kind == "MAGE":
		draw_line(hand, hand + Vector2(dir * 8.0 * sc, -20.0 * sc), Color("#6b4b86"), 3.0 * sc, true)
		draw_circle(hand + Vector2(dir * 8.0 * sc, -24.0 * sc), 5.0 * sc, Color("#9ec2ff"))
	elif kind == "GIANT":
		draw_line(hand, hand + Vector2(dir * 26.0 * sc, -8.0 * sc), Color("#6b5140"), 7.0 * sc, true)
		draw_circle(hand + Vector2(dir * 30.0 * sc, -8.0 * sc), 8.0 * sc, Color("#8d8378"))
	else:
		draw_line(hand, hand + Vector2(dir * 18.0 * sc, -16.0 * sc), Color("#e7edf4"), 2.6 * sc, true)
		draw_line(hand + Vector2(dir * 14.0 * sc, -12.0 * sc), hand + Vector2(dir * 22.0 * sc, -20.0 * sc), GOLD, 2.0 * sc, true)

func _stage_name_fa(index: int) -> String:
	var names := ["راه غبارآلود", "درهٔ کمان", "صف سپرها", "محفل خاکستر", "راه سنگی", "دو پرچم", "سپاه شب", "تاج چوبین"]
	return names[clampi(index, 0, names.size() - 1)]

func _stage_blurb_fa(index: int) -> String:
	var blurbs := [
		"معدن‌چی‌ها را آموزش بده و از قلعه محافظت کن.",
		"نیروهای تازه به گروهت می‌پیوندند.",
		"ترکیب نیروها و زمان‌بندی را مدیریت کن.",
		"در میدان مراقب جایگاه نیروها باش.",
		"نیروهای سنگین وارد میدان می‌شوند.",
		"دو گروه بزرگ برای پیروزی رقابت می‌کنند.",
		"نبردی در آسمان تاریک پیش روست.",
		"آخرین مرحلهٔ این مسیر را کامل کن."
	]
	return blurbs[clampi(index, 0, blurbs.size() - 1)]

func _unit_name_fa(kind: String) -> String:
	match kind:
		"MINER": return "معدن‌چی"
		"SWORD": return "شمشیرزن"
		"ARCHER": return "کماندار"
		"SPEAR": return "نیزه‌دار"
		"MAGE": return "جادوگر"
		"GIANT": return "غول"
		_: return kind

func _draw_battle_ui() -> void:
	_text("جنگاوران کوچک", Vector2(124, 36), 17, GOLD)
	_text(_stage_name_fa(stage_i), Vector2(124, 56), 13, MUTED)
	_pill(Rect2(430, 16, 200, 40), str(gold) + " طلا", GOLD)
	_pill(Rect2(646, 16, 150, 40), "جمعیت " + str(_pop(0)) + "/" + str(int(_stage()["cap"])), BONE)
	_button(Rect2(24, 16, 86, 42), "II", MUTED, true)
	_bar(Rect2(24, 78, 250, 10), player_hp / maxf(1.0, player_max), BLUE)
	_text("قلعهٔ شما  " + str(int(player_hp)), Vector2(24, 104), 12, MUTED)
	_bar(Rect2(1006, 78, 250, 10), enemy_hp / maxf(1.0, enemy_max), RED)
	_text("دشمن  " + str(int(enemy_hp)), Vector2(1006, 104), 12, MUTED)
	if not player_queue.is_empty():
		var st: Dictionary = STATS[str(player_queue[0])]
		var total := float(st["time"])
		var ratio := clampf(player_train_t / maxf(0.1, total), 0.0, 1.0)
		_text("آموزش " + _unit_name_fa(str(player_queue[0])) + "  " + String.num(maxf(0.0, player_train_t), 1) + " ثانیه", Vector2(820, 48), 13, BONE)
		_bar(Rect2(820, 54, 200, 6), 1.0 - ratio, GOLD)
	for i in 3:
		var names: Array = ["پیشروی", "دفاع", "بازگشت"]
		var ids: Array = ["attack", "defend", "garrison"]
		var on: bool = p_order == str(ids[i])
		_button(_order_rect(i), names[i], GOLD if on else Color("#8d97a5"), true)
	for i in KIND_ORDER.size():
		_draw_train(i)
	_draw_joy()
	_draw_action()
	if toast_t > 0.0:
		_pill(Rect2(390, 118, 500, 36), toast, Color("#d7e2ef"))
	if hint_t > 0.0 and stage_i == 0:
		_text("برای کنترل، یک نیرو را انتخاب کن. معدن‌چی‌ها طلا جمع می‌کنند.", Vector2(250, 168), 14, BONE)
	if intro_t > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.45))
		_text(_stage_name_fa(stage_i), Vector2(430, 300), 32, GOLD)
		_text(_stage_blurb_fa(stage_i), Vector2(360, 346), 18, BONE)
	if paused:
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.03, 0.05, 0.78))
		_text("بازی متوقف شد", Vector2(520, 250), 30, BONE)
		_button(Rect2(470, 300, 340, 52), "ادامهٔ بازی", GOLD, true)
		_button(Rect2(470, 364, 340, 52), "شروع دوباره", BLUE, true)
		_button(Rect2(470, 428, 340, 52), "نقشهٔ مراحل", MUTED, true)
	if screen == "result":
		_draw_result()

func _draw_train(i: int) -> void:
	var kind := str(KIND_ORDER[i])
	var st: Dictionary = STATS[kind]
	var rect := _train_rect(i)
	var on := _unlocked(kind)
	var afford := gold >= int(st["cost"]) and _pop(0) + int(st["pop"]) <= int(_stage()["cap"])
	var accent := GOLD if on and afford else Color("#5c6570")
	_button(rect, "", accent, on)
	_text(_unit_name_fa(kind), rect.position + Vector2(10, 24), 14, BONE if on else MUTED)
	_text(str(int(st["cost"])) + "g  ·  " + str(int(st["pop"])), rect.position + Vector2(10, 46), 12, GOLD if on and afford else Color("#a86868"))

func _draw_joy() -> void:
	var c := Vector2(86, 664)
	draw_circle(c, 52, Color(0, 0, 0, 0.35))
	draw_arc(c, 48, 0, TAU, 28, Color("#9aa4b2"), 2.0, true)
	draw_circle(c + joy * 28.0, 18, Color("#e7edf4"))

func _draw_action() -> void:
	var c := Vector2(1194, 664)
	var ready := true
	var frac := 0.0
	var index := _index_of(selected_id)
	if index >= 0:
		var u: Dictionary = units[index]
		var max_cd := _ability_max(str(u["kind"]))
		frac = clampf(float(u["ability"]) / max_cd, 0.0, 1.0) if max_cd > 0.0 else 0.0
		ready = float(u["ability"]) <= 0.0
	draw_circle(c, 40, Color(0.09, 0.07, 0.05, 0.92))
	draw_arc(c, 36, 0, TAU, 28, GOLD if ready else MUTED, 3.0, true)
	if frac > 0.0:
		draw_arc(c, 30, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - frac), 24, Color("#3d8bfd"), 4.0, true)
	_text("مهارت", c + Vector2(-22, 5), 14, BONE if ready else MUTED)

func _ability_max(kind: String) -> float:
	match kind:
		"SWORD":
			return 5.2
		"ARCHER":
			return 2.4
		"SPEAR":
			return 6.4
		"MAGE":
			return 4.6
		"GIANT":
			return 6.2
		_:
			return 0.25

func _draw_menu() -> void:
	_draw_sky()
	_draw_ground()
	_draw_statue(1040, 1.0, true)
	_draw_stick({"id": -10, "side": 0, "kind": "SWORD", "x": 860, "y": 540, "hp": 10, "max_hp": 10, "anim": tick * 7.0, "facing": 1.0, "dead": 0.0, "flash": 0.0, "block": 0.0, "bag": 0.0, "slot": 0.0})
	_draw_stick({"id": -11, "side": 0, "kind": "ARCHER", "x": 800, "y": 560, "hp": 10, "max_hp": 10, "anim": tick * 7.0 + 1.0, "facing": 1.0, "dead": 0.0, "flash": 0.0, "block": 0.0, "bag": 0.0, "slot": 0.0})
	_draw_stick({"id": -12, "side": 1, "kind": "SPEAR", "x": 960, "y": 548, "hp": 10, "max_hp": 10, "anim": tick * 6.0, "facing": -1.0, "dead": 0.0, "flash": 0.0, "block": 0.4, "bag": 0.0, "slot": 0.0})
	_text("جنگاوران کوچک", Vector2(78, 120), 18, GOLD)
	_text("لشکر کوچک", Vector2(76, 188), 50, BONE)
	_text("منابع جمع کن، نیروها را مدیریت کن و مراحل را پیش ببر.", Vector2(80, 230), 16, MUTED)
	_button(Rect2(78, 360, 280, 64), "مراحل داستانی", GOLD, true)
	_button(Rect2(78, 440, 280, 54), "راهنمای بازی", Color("#8d97a5"), true)
	_button(Rect2(78, 508, 280, 48), "صدا  " + ("روشن" if sfx_on else "خاموش"), Color("#8d97a5"), true)
	var total := 0
	for s in stars:
		total += int(s)
	_text("پیروزی‌ها  " + str(wins) + "    ستاره‌ها  " + str(total) + "/24", Vector2(80, 590), 14, MUTED)
	_text("VERSION 0.3.0", Vector2(80, 680), 12, Color("#66707c"))

func _draw_map() -> void:
	_draw_sky()
	draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.05, 0.08, 0.35))
	_button(Rect2(40, 28, 140, 44), "بازگشت", MUTED, true)
	_text("مراحل داستانی", Vector2(210, 58), 26, GOLD)
	_text("با پیروزی، مراحل و نیروهای تازه باز می‌شوند.", Vector2(420, 58), 16, MUTED)
	for i in 8:
		var rect := _stage_rect(i)
		var open := i < unlocked
		var stg: Dictionary = STAGES[i]
		draw_rect(rect, Color(0.07, 0.09, 0.12, 0.92))
		draw_rect(rect, GOLD if open else Color("#3c4450"), false, 2.0)
		_text(str(i + 1).pad_zeros(2), rect.position + Vector2(16, 36), 18, GOLD if open else MUTED)
		_text(_stage_name_fa(i), rect.position + Vector2(16, 78), 17, BONE if open else MUTED)
		_text(_stage_blurb_fa(i), rect.position + Vector2(16, 112), 12, MUTED)
		if open:
			for k in 3:
				_gem(rect.position + Vector2(28 + k * 26, 168), int(stars[i]) > k)
		else:
			_text("قفل است", rect.position + Vector2(16, 172), 14, Color("#6a7380"))

func _draw_help() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#121820"))
	_text("HOW TO COMMAND", Vector2(78, 78), 32, GOLD)
	var lines := [
		"Miners walk to the center vein, fill a sack, and carry gold home.",
		"Train troops along the bottom. Population is capped for the battle.",
		"ATTACK sends the army at their statue. Miners keep working.",
		"DEFEND holds your half of the field and fights anything that arrives.",
		"GARRISON pulls everyone back, miners included.",
		"Tap a soldier to take control. The left stick moves them. WASD works too.",
		"The right button is their skill. Controlled soldiers hit harder.",
		"Sword leaps. Archer fires a heavy shot. Spear raises a shield.",
		"Mage bursts a group. Giant slams the ground. Hold the button on a miner to dig faster.",
		"Keys: 1-6 train, F attack, G defend, H garrison, J or Space for the skill.",
		"If your statue falls, the battle is lost. Theirs falls, you win.",
	]
	for i in lines.size():
		_text(lines[i], Vector2(82, 130 + i * 42), 16, BONE)
	_button(Rect2(78, 640, 240, 52), "BACK", MUTED, true)

func _draw_result() -> void:
	var won := ending == ""
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.04, 0.06, 0.72))
	_text("پیروزی!" if won else "شکست", Vector2(500, 200), 36, GOLD if won else RED)
	_text(_stage_name_fa(stage_i), Vector2(540, 248), 18, MUTED)
	if won:
		for k in 3:
			_gem(Vector2(560 + k * 48, 300), result_stars > k)
		_text("مرحلهٔ بعدی باز شد.", Vector2(500, 380), 16, BONE)
	else:
		_text("نیروها و منابع را بهتر مدیریت کن و دوباره تلاش کن.", Vector2(420, 320), 16, BONE)
	_button(Rect2(430, 470, 420, 56), "مرحلهٔ بعد" if won and stage_i + 1 < 8 else ("نقشهٔ مراحل" if won else "تلاش دوباره"), GOLD, true)
	_button(Rect2(430, 538, 200, 48), "تکرار", BLUE, true)
	_button(Rect2(650, 538, 200, 48), "نقشه", MUTED, true)

func _gem(center: Vector2, filled: bool) -> void:
	var r := 8.0
	var pts := PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r * 0.55, -r * 0.15),
		center + Vector2(r * 0.35, r * 0.55),
		center + Vector2(0, r * 0.28),
		center + Vector2(-r * 0.35, r * 0.55),
		center + Vector2(-r * 0.55, -r * 0.15),
	])
	if filled:
		draw_colored_polygon(pts, GOLD)
	else:
		var line := pts.duplicate()
		line.append(pts[0])
		draw_polyline(line, Color("#66707c"), 1.6, true)

func _button(rect: Rect2, label: String, accent: Color, enabled: bool) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.28))
	draw_rect(rect, INK if enabled else Color(0.04, 0.05, 0.07, 0.9))
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.95 if enabled else 0.35), false, 2.0)
	if label != "":
		_text_in(rect, label, 15, BONE if enabled else MUTED)

func _pill(rect: Rect2, label: String, accent: Color) -> void:
	draw_rect(rect, INK)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.8), false, 1.5)
	_text_in(rect, label, 16, accent)

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.45))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)

func _text(label: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_in(rect: Rect2, label: String, size: int, color: Color) -> void:
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.5 + float(size) * 0.32)
	_text(label, pos, size, color)

func _tone(freq: float, dur: float, vol: float, _unused: float) -> AudioStreamWAV:
	return _mix([[freq, 1.0]], dur, vol, false)

func _arpeggio(notes: Array, each: float) -> AudioStreamWAV:
	var rate := 22050
	var dur := each * float(notes.size())
	var count := int(rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var idx := mini(int(t / each), notes.size() - 1)
		var local := t - float(idx) * each
		var env := pow(1.0 - local / each, 0.5)
		var sample := sin(TAU * float(notes[idx]) * t) * env * 0.22
		_write_sample(data, i, sample)
	return _wav(data, rate, false)

func _drone() -> AudioStreamWAV:
	return _mix([[110.0, 0.55], [164.81, 0.28], [220.0, 0.12]], 4.0, 0.18, true)

func _mix(partials: Array, dur: float, vol: float, looped: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0
		if not looped:
			env = pow(1.0 - t / dur, 0.55)
		else:
			var edge := minf(t, dur - t)
			env = clampf(edge / 0.08, 0.0, 1.0)
		var sample := 0.0
		for part in partials:
			sample += sin(TAU * float(part[0]) * t) * float(part[1])
		_write_sample(data, i, sample * env * vol)
	return _wav(data, rate, looped)

func _write_sample(data: PackedByteArray, i: int, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 32000.0)
	data[i * 2] = v & 255
	data[i * 2 + 1] = (v >> 8) & 255

func _wav(data: PackedByteArray, rate: int, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(data.size() / 2)
	return stream

func _sfx(name: String) -> void:
	if not sfx_on or not sfx_streams.has(name):
		return
	for player in sfx_players:
		if not player.playing:
			player.stream = sfx_streams[name]
			player.play()
			return
	sfx_players[0].stream = sfx_streams[name]
	sfx_players[0].play()
