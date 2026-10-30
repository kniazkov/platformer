extends Node2D

const SAVE = "user://progress.json"
const BACKUP = "user://progress.backup.json"
const W = 1280.0
const H = 720.0
const HERO_X = 300.0
const HERO_Y = 390.0

var run: Dictionary = {}
var stats: Dictionary = {"starts": 0, "wins": 0, "deaths": 0, "gold": 0, "record": 0, "failed": []}
var mode = "menu"
var panel: Control
var hud: Label
var sound: GameSound
var held: Dictionary = {}
var jump_requested = false
var jump_latched = false
var crouch_suppressed = false
var save_clock = 0.0
var camera = Vector2.ZERO
var textures: Dictionary = {}
var outcome = ""

func _ready() -> void:
	get_tree().auto_accept_quit = false
	for role in ["hero", "boss", "chaser"]:
		var path = "res://assets/%s.png" % role
		if ResourceLoader.exists(path):
			textures[role] = load(path)
	sound = GameSound.new()
	add_child(sound)
	var layer = CanvasLayer.new()
	add_child(layer)
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)
	load_progress()
	menu()

func is_boss() -> bool:
	return int(run.get("level", 1)) % 5 == 0

func new_run() -> void:
	stats.starts += 1
	run = {"level": 1, "lives": 3, "total_gold": 0, "deaths": 0, "seed": randi()}
	start_level()

func start_level() -> void:
	var keep = {"level": run.level, "lives": run.lives, "total_gold": run.total_gold,
		"deaths": run.deaths, "seed": run.seed}
	run = keep
	run.merge({"x": 0.0, "y": 0.0, "vy": 0.0, "grounded": true,
		"energy": 100.0, "gold": 0, "time": 0.0, "ramp": 0.0,
		"objects": [], "section": 0, "boss_x": 220.0, "boss_hp": Balance.BOSS_HEALTH,
		"boss_cd": 2.0, "boss_invuln": 0.0, "attack": 0, "shots": [],
		"chaser": false, "chaser_x": -240.0, "state": "playing"})
	var length = Balance.BASE_SPEED * Balance.tier(run.level) * Balance.LEVEL_SECONDS
	run["length"] = length
	var sections = int(ceil(length / (1024.0 * Balance.tier(run.level))))
	# Три слитка на секцию, небольшой запас сверх необходимого.
	run["required"] = sections * 3 - 3
	resume()

func resume() -> void:
	clear_input()
	# После возобновления под балкой нельзя автоматически встать и погибнуть.
	run["resume_crouch"] = bool(run.get("saved_crouch", false))
	mode = "playing"
	run.state = "playing"
	clear_panel()
	hud = Label.new()
	hud.position = Vector2(26, 22)
	hud.add_theme_font_size_override("font_size", 22)
	panel.add_child(hud)
	var pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.position = Vector2(1180, 20)
	pause_button.size = Vector2(72, 52)
	pause_button.pressed.connect(pause_game)
	panel.add_child(pause_button)
	sound.playing = true
	save_progress()

func clear_input() -> void:
	held.clear()
	jump_requested = false
	jump_latched = false
	crouch_suppressed = false

func clear_panel() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()

func box(title: String, subtitle: String = "") -> VBoxContainer:
	clear_panel()
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.065, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var column = VBoxContainer.new()
	column.custom_minimum_size.x = 570
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var label = Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	column.add_child(label)
	if not subtitle.is_empty():
		var detail = Label.new()
		detail.text = subtitle
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_theme_font_size_override("font_size", 20)
		column.add_child(detail)
	return column

func button(column: VBoxContainer, title: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = title
	item.custom_minimum_size.y = 54
	item.add_theme_font_size_override("font_size", 24)
	item.pressed.connect(action)
	column.add_child(item)
	return item

func menu() -> void:
	mode = "menu"
	clear_input()
	sound.playing = false
	var column = box("ГОЛДА", "Вниз по лестнице • прототип")
	var can_continue = not run.is_empty() and run.get("state", "") != "finished"
	button(column, "Продолжить", continue_run).disabled = not can_continue
	button(column, "Новая игра", confirm_new)
	button(column, "Рекорд", show_record)
	button(column, "Статистика", show_stats)
	button(column, "Выход", exit_game)
	save_progress()

func confirm_new() -> void:
	if run.is_empty() or run.get("state", "") == "finished":
		new_run()
		return
	var column = box("Начать заново?", "Текущее прохождение будет заменено. Рекорд останется.")
	button(column, "Новая игра", new_run)
	button(column, "Назад", menu)

func continue_run() -> void:
	match run.get("state", "playing"):
		"dead": show_death()
		"won": show_win()
		_: resume()

func pause_game() -> void:
	if mode != "playing":
		return
	run["saved_crouch"] = crouching()
	mode = "paused"
	clear_input()
	sound.playing = false
	var column = box("Пауза", "Время остановлено")
	button(column, "Продолжить", resume)
	button(column, "Главное меню", menu)
	save_progress()

func show_record() -> void:
	var column = box("Рекорд", "%d слитков голды\nЗа полностью пройденную игру" % stats.record)
	button(column, "Назад", menu)

func show_stats() -> void:
	var column = box("Статистика", "Новых игр: %d • Побед: %d\nСмертей: %d • Голды за всё время: %d" % [stats.starts, stats.wins, stats.deaths, stats.gold])
	button(column, "Неудачные попытки", show_failed)
	button(column, "Назад", menu)

func show_failed() -> void:
	var column = box("Неудачные попытки")
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 340)
	column.add_child(scroll)
	var rows = VBoxContainer.new()
	scroll.add_child(rows)
	if stats.failed.is_empty():
		var empty = Label.new()
		empty.text = "Пока нет неудачных попыток"
		rows.add_child(empty)
	for i in range(stats.failed.size() - 1, -1, -1):
		var attempt = stats.failed[i]
		var row = Label.new()
		row.text = "Уровень %d • Голда: %d • %s" % [attempt.level, attempt.gold, attempt.reason]
		row.add_theme_font_size_override("font_size", 20)
		rows.add_child(row)
	button(column, "Назад", show_stats)

func lose(reason: String) -> void:
	if mode != "playing":
		return
	run.lives -= 1
	run.deaths += 1
	stats.deaths += 1
	stats.failed.append({"level": run.level, "gold": run.gold, "reason": reason})
	run["reason"] = reason
	run.state = "dead"
	sound.effect("death")
	show_death()
	save_progress()

func show_death() -> void:
	mode = "dead"
	clear_input()
	sound.playing = false
	var detail = "%s\nОсталось попыток: %d" % [run.get("reason", "Неудача"), run.lives]
	if run.lives <= 0:
		detail += "\nСледующая попытка начнётся с первого уровня."
	var column = box("Попытка проиграна", detail)
	button(column, "Повторить", retry)
	button(column, "Главное меню", menu)

func retry() -> void:
	if run.lives <= 0:
		new_run()
	else:
		start_level()

func win() -> void:
	if mode != "playing":
		return
	run.total_gold += run.gold
	run.state = "won"
	if run.level == 15:
		stats.wins += 1
		stats.record = maxi(stats.record, run.total_gold)
		run.state = "finished"
	sound.effect("win")
	show_win()
	save_progress()

func show_win() -> void:
	mode = "won"
	clear_input()
	sound.playing = false
	var final_level = run.level == 15
	var column = box("Игра пройдена!" if final_level else "Уровень пройден!",
		"Голда: %d • Смертей за прохождение: %d" % [run.total_gold, run.deaths])
	button(column, "Новая игра" if final_level else "Дальше", new_run if final_level else next_level)
	button(column, "Главное меню", menu)

func next_level() -> void:
	run.level += 1
	run.seed = randi()
	start_level()

func exit_game() -> void:
	save_progress()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(sound):
			pause_game()
			save_progress()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		exit_game()

func save_progress() -> void:
	if mode == "playing" and not run.is_empty():
		run["saved_crouch"] = crouching()
	if run.is_empty() and stats.starts == 0:
		return
	var payload = {"version": 1, "run": run, "stats": stats}
	var file = FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить прогресс")
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(SAVE, BACKUP)
	DirAccess.rename_absolute(SAVE + ".tmp", SAVE)

func load_progress() -> void:
	for path in [SAVE, BACKUP]:
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.get("version") == 1 and data.get("stats") is Dictionary and data.get("run") is Dictionary:
			stats.merge(data.stats, true)
			run = data.run
			return

func touch_action(position_value: Vector2) -> String:
	if position_value.y < 540:
		return ""
	if position_value.x < 220:
		return "crouch"
	if position_value.x > 1050:
		return "jump"
	if position_value.x > 820:
		return "boost"
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if mode == "playing": pause_game()
		elif mode == "paused": resume()
		return
	if mode != "playing":
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		if event.pressed and not jump_latched:
			jump_requested = true
		jump_latched = event.pressed
	if event is InputEventScreenTouch:
		if event.pressed:
			held[event.index] = touch_action(event.position)
			if held[event.index] == "jump": jump_requested = true
		else:
			held.erase(event.index)
	if event is InputEventScreenDrag and held.has(event.index):
		# Выход пальца за кнопку отпускает действие, но не запускает новый прыжок.
		if touch_action(event.position) != held[event.index]: held.erase(event.index)

func action(name_value: String) -> bool:
	if held.values().has(name_value): return true
	if name_value == "crouch": return Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	if name_value == "boost": return Input.is_physical_key_pressed(KEY_SHIFT)
	return false

func _physics_process(delta: float) -> void:
	if mode == "playing":
		# Малые подшаги защищают от пролёта сквозь ловушки на больших скоростях.
		var steps = maxi(1, int(ceil(speed() * delta / 12.0)))
		for i in range(steps):
			if mode != "playing": break
			step(delta / steps)
		save_clock += delta
		if save_clock >= 1.0:
			save_clock = 0
			save_progress()
		if is_instance_valid(hud):
			hud.text = "УРОВЕНЬ %d / 15    ПОПЫТКИ %d    ГОЛДА %d%s\nЭНЕРГИЯ %d%%    %s" % [run.level, run.lives, run.gold, "" if is_boss() else " / %d" % run.required, int(run.energy), "БОСС: %d / 3" % run.boss_hp if is_boss() else "ПРОЙДЕНО %d%%" % clampi(int(100.0 * run.x / run.length), 0, 100)]
	queue_redraw()

func speed() -> float:
	return Balance.BASE_SPEED * Balance.tier(run.level) * (1.0 + run.ramp)

func ensure_sections() -> void:
	var length = 1024.0 * Balance.tier(run.level)
	while run.section * length < run.x + 1700:
		if not is_boss() and run.section * length >= run.length: break
		var data = LevelGenerator.section(int(run.seed), int(run.section), Balance.tier(run.level), is_boss())
		run.objects.append_array(data.objects)
		run.section += 1
	# Размер активного мира ограничен, даже если бой длится долго.
	run.objects = run.objects.filter(func(item): return item.x > run.x - 800)

func in_gap(x: float) -> bool:
	for item in run.objects:
		if item.kind == "gap" and x > item.x and x < item.x + item.width:
			return true
	return false

func hero_rect() -> Rect2:
	var height = 34.0 if crouching() else 68.0
	return Rect2(run.x - 17, run.y - height, 34, height)

func crouching() -> bool:
	return (action("crouch") or bool(run.get("resume_crouch", false))) and not crouch_suppressed

func step(dt: float) -> void:
	ensure_sections()
	run.time += dt
	if is_boss() and run.gold >= 30: run.ramp += Balance.BOSS_RAMP * dt
	var base = speed()
	if run.get("resume_crouch", false):
		var under_beam = false
		for obstacle in run.objects:
			if obstacle.kind == "beam" and run.x + 25 > obstacle.x and run.x - 25 < obstacle.x + obstacle.width:
				under_beam = true
		if not under_beam: run.resume_crouch = false
	var boosted = action("boost") and run.energy > 0
	var vx = base * (Balance.BOOST if boosted else 1.0) * (Balance.CROUCH if crouching() else 1.0)
	if boosted: run.energy = maxf(0, run.energy - Balance.STAMINA_DRAIN * dt)
	if not action("crouch"): crouch_suppressed = false
	if jump_requested:
		if run.grounded:
			run.vy = Balance.JUMP
			run.grounded = false
			crouch_suppressed = true
			sound.effect("jump")
		jump_requested = false
	var previous_y = float(run.y)
	run.x += vx * dt
	var floor_height = Balance.floor_y(run.x)
	if run.grounded and not in_gap(run.x):
		run.y = floor_height
	else:
		run.grounded = false
		run.vy += Balance.GRAVITY * dt
		run.y += run.vy * dt
		if not in_gap(run.x) and run.vy >= 0 and previous_y <= floor_height + 20 and run.y >= floor_height:
			run.y = floor_height
			run.vy = 0
			run.grounded = true
	if run.y > floor_height + 230:
		lose("Падение в яму")
		return
	var body = hero_rect()
	for item in run.objects:
		if item.used: continue
		var y = Balance.floor_y(item.x)
		if item.kind in ["gold", "energy"]:
			var size_value = Vector2(30, 20) if item.kind == "gold" else Vector2(22, 36)
			if body.intersects(Rect2(Vector2(item.x - size_value.x / 2, y - size_value.y - 5), size_value)):
				item.used = true
				if item.kind == "gold":
					run.gold += 1
					stats.gold += 1
				else: run.energy = 100.0
				sound.effect(item.kind)
		elif item.kind == "spikes":
			if body.intersects(Rect2(item.x, y - 20, item.width, 20)):
				lose("Шипы")
				return
		elif item.kind == "beam":
			if body.intersects(Rect2(item.x, y - 112, item.width, 60)):
				lose("Низкая балка")
				return
		elif item.kind == "chase" and run.x >= item.x:
			item.used = true
			if not run.chaser:
				run.chaser = true
				run.chaser_x = run.x - 280
	if run.chaser:
		run.chaser_x += base * 1.28 * dt
		if run.x - run.chaser_x > 520: run.chaser = false
		elif run.x - run.chaser_x < 30:
			lose("Преследователь догнал")
			return
	if is_boss():
		update_boss(dt, base, previous_y, boosted)
	elif run.x >= run.length:
		if run.gold >= run.required: win()
		else: lose("Недостаточно голды")

func update_boss(dt: float, base: float, previous_y: float, boosted: bool) -> void:
	# Босс держит дистанцию на обычном шаге; ускорение позволяет догнать его.
	run.boss_x += base * dt
	if run.boss_x - run.x > 260: run.boss_x = run.x + 260
	run.boss_invuln = maxf(0, run.boss_invuln - dt)
	var top = Balance.floor_y(run.boss_x) - 78
	var boss_body = Rect2(run.boss_x - 30, top, 60, 78)
	if run.boss_invuln <= 0 and hero_rect().intersects(boss_body):
		if boosted and run.vy > 0 and previous_y <= top + 22:
			run.boss_hp -= 1
			run.vy = Balance.JUMP * 0.85
			run.grounded = false
			run.y = top - 2
			run.boss_x = run.x + 250
			run.boss_invuln = 0.9
			sound.effect("hit")
			if run.boss_hp <= 0:
				win()
				return
		else:
			lose("Столкновение с боссом")
			return
	run.boss_cd -= dt
	if run.boss_cd <= 0:
		var high = int(run.attack) % 2 == 1
		run.shots.append({"x": run.boss_x - 40, "high": high})
		run.attack += 1
		run.boss_cd = 2.4 / (1.0 + run.ramp)
		sound.effect("shot")
	for shot in run.shots:
		shot.x -= base * 0.75 * dt
		var y = Balance.floor_y(shot.x) - (57 if shot.high else 12)
		if hero_rect().intersects(Rect2(shot.x - 13, y - 10, 26, 20)):
			lose("Высокий снаряд" if shot.high else "Снаряд по земле")
			return
	run.shots = run.shots.filter(func(shot): return shot.x > run.x - 500)

func screen(world: Vector2) -> Vector2:
	return world - camera

func actor(role: String, position_value: Vector2, tint: Color, small: bool = false) -> void:
	var height = 34.0 if small else (78.0 if role == "boss" else 68.0)
	var width = 54.0 if role == "boss" else 34.0
	var p = screen(position_value)
	if textures.has(role):
		draw_texture_rect(textures[role], Rect2(p - Vector2(width / 2, height), Vector2(width, height)), false)
		return
	# Временный человечек; PNG с тем же именем заменяет его без изменения кода.
	draw_circle(p - Vector2(0, height - 12), 13, Color("f5c89d"))
	draw_style_box(actor_style(tint), Rect2(p - Vector2(width / 2, height - 27), Vector2(width, maxf(12, height - 40))))
	var stride = sin(float(run.get("time", 0)) * 13) * 8
	draw_line(p - Vector2(7, 13), p + Vector2(-8 + stride, 0), Color("91a5c4"), 7, true)
	draw_line(p - Vector2(-7, 13), p + Vector2(8 - stride, 0), Color("91a5c4"), 7, true)
	draw_circle(p + Vector2(5, -height + 10), 2, Color("172134"))

var styles: Dictionary = {}
func actor_style(tint: Color) -> StyleBoxFlat:
	if not styles.has(tint):
		var style = StyleBoxFlat.new()
		style.bg_color = tint
		style.set_corner_radius_all(7)
		styles[tint] = style
	return styles[tint]

func text(position_value: Vector2, value: String, size_value: int, color_value: Color) -> void:
	draw_string(ThemeDB.fallback_font, position_value, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color_value)

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("101a2a"))
	# Стена здания: небольшое число примитивов, без света и тяжёлых эффектов.
	for i in range(7):
		var wx = float(i * 220) - fmod(float(run.get("x", 0)) * 0.15, 220.0)
		draw_rect(Rect2(wx, 100, 112, 220), Color("17253a"))
		draw_rect(Rect2(wx + 12, 112, 88, 190), Color("213c50"))
		draw_line(Vector2(wx + 56, 112), Vector2(wx + 56, 302), Color("17253a"), 8)
	if run.is_empty(): return
	camera = Vector2(run.x - HERO_X, Balance.floor_y(run.x) - HERO_Y)
	var first = int(floor((run.x - HERO_X - 80) / Balance.STEP_WIDTH))
	for i in range(first, first + 24):
		var x = i * Balance.STEP_WIDTH
		if in_gap(x + Balance.STEP_WIDTH / 2): continue
		var p = screen(Vector2(x, Balance.floor_y(x)))
		draw_rect(Rect2(p, Vector2(Balance.STEP_WIDTH + 1, H - p.y + 30)), Color("364459"))
		draw_rect(Rect2(p, Vector2(Balance.STEP_WIDTH, 7)), Color("8192a5"))
		draw_line(p + Vector2(0, 8), p + Vector2(0, 70), Color("26364a"), 2)
	for item in run.get("objects", []):
		if item.used or absf(item.x - run.x) > 1400: continue
		var p = screen(Vector2(item.x, Balance.floor_y(item.x)))
		match item.kind:
			"gold":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-15,-5), p + Vector2(-10,-25), p + Vector2(10,-25), p + Vector2(15,-5)]), Color("f6bd4b"))
				draw_line(p + Vector2(-8,-20), p + Vector2(8,-20), Color("ffec9e"), 3)
			"energy":
				draw_rect(Rect2(p + Vector2(-11,-41), Vector2(22,36)), Color("63e4b0"))
				text(p + Vector2(-5,-15), "ϟ", 22, Color("183b40"))
			"spikes":
				var count = maxi(1, int(item.width / 20))
				for j in range(count):
					var q = p + Vector2(j * item.width / count, 0)
					draw_colored_polygon(PackedVector2Array([q, q + Vector2(10,-20), q + Vector2(20,0)]), Color("ee7a81"))
			"beam":
				draw_rect(Rect2(p + Vector2(0,-112), Vector2(item.width,60)), Color("ce8b68"))
				draw_line(p + Vector2(0,-55), p + Vector2(item.width,-55), Color("f3ba88"), 5)
	actor("hero", Vector2(run.x, run.y), Color("64c5e8"), crouching() and mode == "playing")
	if run.get("chaser", false):
		actor("chaser", Vector2(run.chaser_x, Balance.floor_y(run.chaser_x)), Color("e57783"))
	if is_boss():
		actor("boss", Vector2(run.boss_x, Balance.floor_y(run.boss_x)), Color("b496f3"))
		if run.boss_cd < Balance.TELEGRAPH:
			var p = screen(Vector2(run.boss_x, Balance.floor_y(run.boss_x) - 102))
			text(p - Vector2(28,0), "↓" if int(run.attack) % 2 == 1 else "↑", 36, Color("ffda77"))
		for shot in run.shots:
			var p = screen(Vector2(shot.x, Balance.floor_y(shot.x) - (57 if shot.high else 12)))
			draw_circle(p, 12, Color("ff8e78") if shot.high else Color("ffce73"))
	else:
		var p = screen(Vector2(run.length, Balance.floor_y(run.length)))
		draw_rect(Rect2(p + Vector2(-15,-125), Vector2(80,125)), Color("62d6b1"))
		text(p + Vector2(-10,-140), "ВЫХОД", 22, Color("b7f4df"))
	if mode == "playing":
		draw_rect(Rect2(28, 94, 240, 9), Color("29394c"))
		draw_rect(Rect2(28, 94, 240 * run.energy / 100.0, 9), Color("63e4b0"))
		if run.ramp > 0: text(Vector2(460,130), "РАЗГОН! ×%.2f" % (1 + run.ramp), 26, Color("ffbc7c"))
		for control in [[Rect2(30,560,170,130), "ПРИСЕСТЬ"], [Rect2(850,560,170,130), "УСКОРИТЬ"], [Rect2(1080,560,170,130), "ПРЫЖОК"]]:
			draw_style_box(actor_style(Color(0.16,0.24,0.34,0.85)), control[0])
			text(control[0].position + Vector2(18,72), control[1], 20, Color("d9e7f2"))
