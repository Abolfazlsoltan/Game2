extends Node2D
## Small Warriors: touch-friendly lane strategy game.

const SAVE_PATH := "user://small_warriors.cfg"
const W := 1280.0
const H := 720.0
const GROUND_Y := 548.0
const COSTS := {"SWORD": 35, "ARCHER": 55, "GUARD": 75}
const UNIT_COLORS := {"SWORD": Color("#4f9dff"), "ARCHER": Color("#62d6b0"), "GUARD": Color("#b69cff")}
const GOLD := Color("#ffc96a")
const TEXT := Color("#f3f6fb")
const MUTED := Color("#9baac0")
const BLUE := Color("#4f9dff")
const RED := Color("#ff667b")
const GREEN := Color("#69d9ad")
const PANEL := Color("#111f32")

var rng := RandomNumberGenerator.new()
var screen := "menu"
var paused := false
var gold := 120
var best_wave := 1
var wave := 1
var enemy_target := 4
var enemy_spawned := 0
var spawn_timer := 0.0
var base_hp := 100.0
var enemy_base_hp := 100.0
var upgrade_level := 0
var kills := 0
var elapsed := 0.0
var notice := "Build your army. Protect your keep."
var notice_time := 3.0
var units: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []

func _ready() -> void:
    rng.randomize()
    _load_save()
    get_viewport().size_changed.connect(queue_redraw)
    queue_redraw()

func _process(delta: float) -> void:
    if screen == "battle" and not paused:
        elapsed += delta
        spawn_timer += delta
        notice_time = maxf(0.0, notice_time - delta)
        if enemy_spawned < enemy_target and spawn_timer >= maxf(0.85, 2.0 - float(wave) * 0.035):
            spawn_timer = 0.0
            _spawn_enemy()
        _simulate(delta)
        _simulate_effects(delta)
        # Autosave periodically so earned gold is not lost if Android closes the app.
        if int(elapsed / 10.0) != int(maxf(0.0, elapsed - delta) / 10.0):
            _save_game()
        if base_hp <= 0.0:
            screen = "game_over"
            best_wave = maxi(best_wave, wave)
            _save_game()
        elif enemy_base_hp <= 0.0:
            enemy_base_hp = 100.0
            gold += 60
            _notify("Enemy keep destroyed! Bonus +60 gold.")
            _save_game()
        _check_wave()
    elif screen == "battle":
        _simulate_effects(delta)
    queue_redraw()

func _stats(kind: String, friendly: bool) -> Dictionary:
    var bonus := float(upgrade_level) * 0.12 if friendly else 0.0
    match kind:
        "ARCHER":
            return {"hp": 46.0 + bonus * 10.0, "speed": 34.0, "damage": 10.0 + bonus * 10.0, "range": 165.0, "cooldown": 1.15}
        "GUARD":
            return {"hp": 118.0 + bonus * 20.0, "speed": 23.0, "damage": 15.0 + bonus * 10.0, "range": 44.0, "cooldown": 1.05}
        _:
            return {"hp": 72.0 + bonus * 15.0, "speed": 39.0, "damage": 13.0 + bonus * 10.0, "range": 44.0, "cooldown": 0.86}

func _spawn_enemy() -> void:
    enemy_spawned += 1
    var roll := rng.randf()
    var kind := "SWORD"
    if wave >= 2 and roll > 0.62:
        kind = "ARCHER"
    if wave >= 4 and roll > 0.84:
        kind = "GUARD"
    var s := _stats(kind, false)
    units.append({
        "side": 1, "kind": kind, "x": 1030.0 + rng.randf_range(-12.0, 12.0),
        "hp": float(s["hp"]), "max_hp": float(s["hp"]), "speed": float(s["speed"]),
        "damage": float(s["damage"]) + float(wave - 1) * 0.4, "range": float(s["range"]),
        "cooldown": float(s["cooldown"]), "attack_cd": rng.randf_range(0.0, 0.7),
        "phase": rng.randf_range(0.0, TAU)
    })

func _recruit(kind: String) -> void:
    var cost: int = COSTS[kind]
    if gold < cost:
        _notify("Not enough gold. Defeat enemies to earn more.")
        return
    gold -= cost
    var s := _stats(kind, true)
    units.append({
        "side": 0, "kind": kind, "x": 226.0 + rng.randf_range(-8.0, 8.0),
        "hp": float(s["hp"]), "max_hp": float(s["hp"]), "speed": float(s["speed"]),
        "damage": float(s["damage"]), "range": float(s["range"]),
        "cooldown": float(s["cooldown"]), "attack_cd": rng.randf_range(0.0, 0.35),
        "phase": rng.randf_range(0.0, TAU)
    })
    _burst(Vector2(240, GROUND_Y - 34), UNIT_COLORS[kind], 8)
    _notify(kind.capitalize() + " deployed.")

func _simulate(delta: float) -> void:
    for i in range(units.size()):
        var u: Dictionary = units[i]
        u["attack_cd"] = maxf(0.0, float(u["attack_cd"]) - delta)
        var side := int(u["side"])
        var x := float(u["x"])
        var target_i := _find_target(u)
        if target_i >= 0:
            var target: Dictionary = units[target_i]
            var distance := absf(float(target["x"]) - x)
            if distance <= float(u["range"]):
                if float(u["attack_cd"]) <= 0.0:
                    target["hp"] = float(target["hp"]) - float(u["damage"])
                    u["attack_cd"] = float(u["cooldown"])
                    units[target_i] = target
                    _burst(Vector2(float(target["x"]), GROUND_Y - 38), GOLD if side == 0 else RED, 2)
            else:
                u["x"] = x + float(u["speed"]) * delta * (1.0 if side == 0 else -1.0)
        else:
            var base_x := 1120.0 if side == 0 else 160.0
            if absf(base_x - x) <= float(u["range"]) + 32.0:
                if float(u["attack_cd"]) <= 0.0:
                    if side == 0:
                        enemy_base_hp = maxf(0.0, enemy_base_hp - float(u["damage"]))
                    else:
                        base_hp = maxf(0.0, base_hp - float(u["damage"]))
                    u["attack_cd"] = float(u["cooldown"])
                    _add_floater(Vector2(base_x, GROUND_Y - 75), "-" + str(int(u["damage"])), GOLD if side == 0 else RED)
            else:
                u["x"] = x + float(u["speed"]) * delta * (1.0 if side == 0 else -1.0)
        u["x"] = clampf(float(u["x"]), 195.0, 1085.0)
        units[i] = u
    # Remove dead units after iteration so target indices stay valid during combat.
    for i in range(units.size() - 1, -1, -1):
        if float(units[i]["hp"]) <= 0.0:
            var dead: Dictionary = units[i]
            var pos := Vector2(float(dead["x"]), GROUND_Y - 35)
            _burst(pos, RED if int(dead["side"]) == 1 else BLUE, 9)
            _add_floater(pos + Vector2(-5, -25), "DOWN", GOLD)
            if int(dead["side"]) == 1:
                gold += 9
                kills += 1
            units.remove_at(i)

func _find_target(unit: Dictionary) -> int:
    var best := -1
    var best_distance := INF
    for i in range(units.size()):
        if int(units[i]["side"]) == int(unit["side"]):
            continue
        var d := absf(float(units[i]["x"]) - float(unit["x"]))
        if d < best_distance and d <= 250.0:
            best_distance = d
            best = i
    return best

func _check_wave() -> void:
    if enemy_spawned < enemy_target:
        return
    for u in units:
        if int(u["side"]) == 1:
            return
    wave += 1
    best_wave = maxi(best_wave, wave)
    var reward := 25 + wave * 3
    gold += reward
    enemy_target = mini(4 + wave * 2, 24)
    enemy_spawned = 0
    spawn_timer = 0.0
    _notify("Wave cleared! +" + str(reward) + " gold.")
    _save_game()

func _upgrade() -> void:
    if gold < 90:
        _notify("Upgrade costs 90 gold.")
        return
    gold -= 90
    upgrade_level += 1
    # Upgrade already-deployed friendly troops as well as future recruits.
    for i in range(units.size()):
        var troop: Dictionary = units[i]
        if int(troop["side"]) == 0:
            var hp_bonus := maxf(8.0, float(troop["max_hp"]) * 0.12)
            troop["max_hp"] = float(troop["max_hp"]) + hp_bonus
            troop["hp"] = minf(float(troop["max_hp"]), float(troop["hp"]) + hp_bonus)
            troop["damage"] = float(troop["damage"]) + 2.0
            units[i] = troop
    _notify("Army upgraded: troops reinforced.")
    _burst(Vector2(640, 400), GOLD, 18)
    _save_game()

func _start_game() -> void:
    screen = "battle"
    paused = false
    gold = maxi(gold, 60)
    wave = 1
    enemy_target = 4
    enemy_spawned = 0
    spawn_timer = 0.0
    base_hp = 100.0
    enemy_base_hp = 100.0
    elapsed = 0.0
    kills = 0
    units.clear()
    particles.clear()
    floaters.clear()
    _recruit("SWORD")
    _recruit("SWORD")
    _notify("Recruit units and defend your keep.")

func _notify(message: String) -> void:
    notice = message
    notice_time = 2.8

func _burst(pos: Vector2, color: Color, count: int) -> void:
    for j in range(count):
        var a := rng.randf_range(0.0, TAU)
        var speed := rng.randf_range(22.0, 100.0)
        particles.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * speed, "color": color, "life": rng.randf_range(0.2, 0.5), "max_life": 0.5})

func _add_floater(pos: Vector2, label: String, color: Color) -> void:
    floaters.append({"pos": pos, "label": label, "color": color, "life": 0.9})

func _simulate_effects(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var p: Dictionary = particles[i]
        p["life"] = float(p["life"]) - delta
        p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
        p["vel"] = Vector2(p["vel"]) * 0.91
        if float(p["life"]) <= 0.0:
            particles.remove_at(i)
        else:
            particles[i] = p
    for i in range(floaters.size() - 1, -1, -1):
        var f: Dictionary = floaters[i]
        f["life"] = float(f["life"]) - delta
        f["pos"] = Vector2(f["pos"]) + Vector2(0, -25.0 * delta)
        if float(f["life"]) <= 0.0:
            floaters.remove_at(i)
        else:
            floaters[i] = f

func _draw() -> void:
    # Keep the 16:9 game canvas proportional on phones and tablets.
    var viewport_size := get_viewport_rect().size
    var uniform_scale := minf(viewport_size.x / W, viewport_size.y / H)
    var offset := (viewport_size - Vector2(W, H) * uniform_scale) * 0.5
    draw_set_transform(offset, 0.0, Vector2.ONE * uniform_scale)
    _draw_background()
    match screen:
        "menu": _draw_menu()
        "battle": _draw_battle()
        "game_over": _draw_game_over()
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_background() -> void:
    draw_rect(Rect2(0, 0, W, H), Color("#091322"))
    draw_circle(Vector2(1080, 95), 185, Color(0.15, 0.33, 0.55, 0.10))
    draw_circle(Vector2(150, 610), 230, Color(0.08, 0.42, 0.42, 0.08))
    for i in range(9):
        var y := float(i) * 92.0
        draw_line(Vector2(0, y), Vector2(W, y), Color(0.16, 0.25, 0.38, 0.12), 1.0)
    draw_rect(Rect2(0, GROUND_Y, W, H - GROUND_Y), Color("#13283a"))
    draw_rect(Rect2(0, GROUND_Y, W, 3), Color("#41617a"))
    for i in range(32):
        var x := float(i) * 43.0
        draw_line(Vector2(x, GROUND_Y + 12), Vector2(x + 18, H), Color(0.24, 0.38, 0.49, 0.18), 1.0)

func _draw_menu() -> void:
    _text("SMALL WARRIORS", Vector2(78, 108), 24, GOLD)
    _text("TACTICS. TIMING. TRIUMPH.", Vector2(80, 139), 13, MUTED)
    _text("Build your army.", Vector2(78, 245), 43, TEXT)
    _text("Defend your keep. Survive every wave.", Vector2(82, 284), 17, MUTED)
    _draw_keep(Vector2(1000, 420), true)
    _draw_keep(Vector2(1130, 430), false)
    _draw_unit_art(Vector2(835, 486), "SWORD", 0, 1.15)
    _draw_unit_art(Vector2(890, 486), "ARCHER", 0, 1.15)
    _draw_unit_art(Vector2(1030, 486), "GUARD", 1, 1.15)
    _button(Rect2(80, 360, 250, 66), "START BATTLE", GOLD, PANEL)
    _text("BEST WAVE  " + str(best_wave), Vector2(82, 465), 14, MUTED)
    _text("Offline • Progress saved locally", Vector2(82, 505), 13, MUTED)
    _text("Tap START to deploy. Recruit, upgrade, and outlast each wave.", Vector2(82, 540), 12, Color("#71869c"))
    _text("BUILD 0.1.0", Vector2(80, 665), 12, Color("#60758b"))

func _draw_battle() -> void:
    _text("SMALL WARRIORS", Vector2(36, 42), 17, GOLD)
    _text("WAVE " + str(wave), Vector2(36, 76), 25, TEXT)
    _text("KILLS  " + str(kills), Vector2(36, 104), 13, MUTED)
    var friendly_count := 0
    for troop in units:
        if int(troop["side"]) == 0:
            friendly_count += 1
    _text("TROOPS  " + str(friendly_count), Vector2(300, 42), 13, MUTED)
    _text("ENEMIES LEFT  " + str(maxi(0, enemy_target - enemy_spawned)), Vector2(300, 66), 12, MUTED)
    _pill(Rect2(930, 25, 300, 54), "✦  " + str(gold) + " GOLD", GOLD)
    _bar(Rect2(36, 125, 230, 12), base_hp / 100.0, BLUE)
    _text("YOUR KEEP", Vector2(36, 151), 11, MUTED)
    _bar(Rect2(1010, 125, 220, 12), enemy_base_hp / 100.0, RED)
    _text("ENEMY KEEP", Vector2(1090, 151), 11, MUTED)
    _draw_keep(Vector2(150, 470), true)
    _draw_keep(Vector2(1130, 470), false)
    for u in units:
        _draw_unit(u)
    for p in particles:
        var alpha := clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
        var c: Color = p["color"]
        c.a = alpha
        draw_circle(Vector2(p["pos"]), 2.0 + 3.0 * alpha, c)
    for f in floaters:
        var c: Color = f["color"]
        c.a = clampf(float(f["life"]) / 0.9, 0.0, 1.0)
        _text(str(f["label"]), Vector2(f["pos"]), 13, c)
    if notice_time > 0.0:
        _pill(Rect2(390, 92, 500, 38), notice, Color("#1b3045"))
    _button(Rect2(30, 590, 190, 82), "SWORDSMAN  ·  35", BLUE, PANEL)
    _button(Rect2(235, 590, 190, 82), "ARCHER  ·  55", GREEN, PANEL)
    _button(Rect2(440, 590, 190, 82), "GUARD  ·  75", Color("#b69cff"), PANEL)
    _button(Rect2(1000, 590, 230, 82), "UPGRADE  ·  90", GOLD, PANEL)
    _text("Recruit units to push forward", Vector2(675, 620), 14, MUTED)
    _button(Rect2(1080, 92, 150, 34), "PAUSE  II", Color("#344b64"), PANEL)
    if paused:
        draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.04, 0.08, 0.84))
        draw_rect(Rect2(390, 205, 500, 320), Color("#0d1a2b"))
        draw_rect(Rect2(390, 205, 500, 320), Color("#41617a"), false, 2.0)
        _text("BATTLE PAUSED", Vector2(510, 255), 28, TEXT)
        _text("Your progress is saved automatically.", Vector2(458, 286), 15, MUTED)
        _button(Rect2(470, 315, 340, 52), "RESUME BATTLE", GOLD, PANEL)
        _button(Rect2(470, 381, 340, 52), "RESTART BATTLE", BLUE, PANEL)
        _button(Rect2(470, 447, 340, 52), "MAIN MENU", Color("#344b64"), PANEL)

func _draw_game_over() -> void:
    _text("KEEP FALLEN", Vector2(80, 170), 18, RED)
    _text("Your army fought bravely.", Vector2(80, 235), 39, TEXT)
    _text("Wave " + str(wave) + "  •  Enemies defeated " + str(kills), Vector2(82, 278), 17, MUTED)
    _draw_keep(Vector2(990, 440), false)
    _button(Rect2(80, 350, 250, 66), "TRY AGAIN", GOLD, PANEL)
    _button(Rect2(80, 435, 250, 58), "MAIN MENU", Color("#344b64"), PANEL)
    _text("BEST WAVE  " + str(best_wave), Vector2(82, 530), 15, GOLD)

func _draw_keep(center: Vector2, friendly: bool) -> void:
    var col := BLUE if friendly else RED
    draw_rect(Rect2(center.x - 43, center.y - 88, 86, 112), Color("#1c3047"))
    draw_rect(Rect2(center.x - 52, center.y - 108, 28, 38), col.darkened(0.25))
    draw_rect(Rect2(center.x + 24, center.y - 108, 28, 38), col.darkened(0.25))
    draw_rect(Rect2(center.x - 12, center.y - 55, 24, 79), Color("#0b1726"))
    draw_rect(Rect2(center.x - 43, center.y - 88, 86, 8), col)
    for j in range(3):
        draw_rect(Rect2(center.x - 31 + j * 25, center.y - 76, 8, 15), col.lightened(0.2))
    draw_rect(Rect2(center.x - 60, center.y + 24, 120, 8), Color("#050c15"))

func _draw_unit(u: Dictionary) -> void:
    var pos := Vector2(float(u["x"]), GROUND_Y - 35 + sin(float(u["phase"]) + elapsed * 7.0) * 2.0)
    _draw_unit_art(pos, str(u["kind"]), int(u["side"]), 1.0)
    var ratio := clampf(float(u["hp"]) / float(u["max_hp"]), 0.0, 1.0)
    draw_rect(Rect2(pos.x - 19, pos.y - 61, 38, 4), Color("#050a11"))
    draw_rect(Rect2(pos.x - 19, pos.y - 61, 38 * ratio, 4), GREEN if int(u["side"]) == 0 else RED)

func _draw_unit_art(pos: Vector2, kind: String, side: int, scale: float) -> void:
    var col: Color = UNIT_COLORS[kind] if side == 0 else RED
    var dir := 1.0 if side == 0 else -1.0
    var shadow := PackedVector2Array()
    for j in range(18):
        var a := TAU * float(j) / 18.0
        shadow.append(pos + Vector2(cos(a) * 18.0, 5.0 + sin(a) * 5.0) * scale)
    draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
    draw_line(pos + Vector2(-5, -13) * scale, pos + Vector2(-8, 0) * scale, col.darkened(0.2), 6 * scale, true)
    draw_line(pos + Vector2(5, -13) * scale, pos + Vector2(9, 0) * scale, col.darkened(0.2), 6 * scale, true)
    draw_line(pos + Vector2(0, -34) * scale, pos + Vector2(0, -13) * scale, col, 8 * scale, true)
    draw_circle(pos + Vector2(0, -43) * scale, 8 * scale, Color("#e8edf5"))
    draw_arc(pos + Vector2(0, -43) * scale, 8.5 * scale, PI, TAU, 16, col, 3 * scale, true)
    draw_line(pos + Vector2(1, -30) * scale, pos + Vector2(11 * dir, -19) * scale, col, 5 * scale, true)
    if kind == "ARCHER":
        draw_arc(pos + Vector2(14 * dir, -26) * scale, 10 * scale, -PI/2, PI/2, 12, GOLD, 2 * scale, true)
        draw_line(pos + Vector2(14 * dir, -36) * scale, pos + Vector2(14 * dir, -16) * scale, Color("#d9e5f2"), 1.2 * scale)
    elif kind == "GUARD":
        draw_rect(Rect2(pos.x + (8 * dir if dir > 0 else -20) * scale, pos.y - 37 * scale, 12 * scale, 20 * scale), GOLD)
        draw_line(pos + Vector2(0, -29) * scale, pos + Vector2(20 * dir, -32) * scale, col, 6 * scale, true)
    else:
        draw_line(pos + Vector2(3 * dir, -31) * scale, pos + Vector2(22 * dir, -45) * scale, Color("#dce7f5"), 3 * scale, true)
        draw_line(pos + Vector2(19 * dir, -47) * scale, pos + Vector2(25 * dir, -41) * scale, GOLD, 2 * scale, true)

func _bar(rect: Rect2, ratio: float, color: Color) -> void:
    draw_rect(rect, Color("#050c15"))
    draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)

func _button(rect: Rect2, label: String, accent: Color, fill: Color) -> void:
    draw_rect(Rect2(rect.position + Vector2(0, 4), rect.size), Color(0, 0, 0, 0.25))
    draw_rect(rect, fill)
    draw_rect(rect, Color(accent, 0.8), false, 2.0)
    _text(label, rect.position + Vector2(14, rect.size.y / 2 + 5), 14, TEXT)

func _pill(rect: Rect2, label: String, accent: Color) -> void:
    draw_rect(rect, PANEL)
    draw_rect(rect, Color(accent, 0.7), false, 1.5)
    _text(label, rect.position + Vector2(15, rect.size.y / 2 + 5), 16, accent)

func _text(label: String, pos: Vector2, size: int, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _input(event: InputEvent) -> void:
    var point := Vector2.ZERO
    var pressed := false
    if event is InputEventScreenTouch and event.pressed:
        point = event.position
        pressed = true
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        point = event.position
        pressed = true
    elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and screen == "battle":
        paused = not paused
        queue_redraw()
        return
    if not pressed:
        return
    var viewport_size := get_viewport_rect().size
    var uniform_scale := minf(viewport_size.x / W, viewport_size.y / H)
    var offset := (viewport_size - Vector2(W, H) * uniform_scale) * 0.5
    point = (point - offset) / uniform_scale
    if point.x < 0.0 or point.y < 0.0 or point.x > W or point.y > H:
        return
    _tap(point)

func _tap(p: Vector2) -> void:
    if screen == "menu":
        if Rect2(80, 360, 250, 66).has_point(p):
            _start_game()
    elif screen == "battle":
        if Rect2(1080, 92, 150, 34).has_point(p):
            paused = not paused
            _notify("Battle paused." if paused else "Battle resumed.")
        elif paused:
            if Rect2(470, 315, 340, 52).has_point(p):
                paused = false
                _notify("Battle resumed.")
            elif Rect2(470, 381, 340, 52).has_point(p):
                _start_game()
                _notify("A new battle begins!")
            elif Rect2(470, 447, 340, 52).has_point(p):
                paused = false
                screen = "menu"
                _save_game()
        elif Rect2(30, 590, 190, 82).has_point(p):
            _recruit("SWORD")
        elif Rect2(235, 590, 190, 82).has_point(p):
            _recruit("ARCHER")
        elif Rect2(440, 590, 190, 82).has_point(p):
            _recruit("GUARD")
        elif Rect2(1000, 590, 230, 82).has_point(p):
            _upgrade()
    elif screen == "game_over":
        if Rect2(80, 350, 250, 66).has_point(p):
            _start_game()
        elif Rect2(80, 435, 250, 58).has_point(p):
            screen = "menu"
    queue_redraw()

func _save_game() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress", "gold", gold)
    cfg.set_value("progress", "best_wave", best_wave)
    cfg.set_value("progress", "upgrade_level", upgrade_level)
    cfg.set_value("progress", "kills", kills)
    cfg.save(SAVE_PATH)

func _load_save() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) == OK:
        gold = int(cfg.get_value("progress", "gold", gold))
        best_wave = int(cfg.get_value("progress", "best_wave", best_wave))
        upgrade_level = int(cfg.get_value("progress", "upgrade_level", upgrade_level))
        kills = int(cfg.get_value("progress", "kills", kills))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_game()
