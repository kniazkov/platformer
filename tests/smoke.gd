extends SceneTree

var failures = 0
func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	# Не изменяем существующий пользовательский прогресс при локальном запуске тестов.
	var original: Dictionary = {}
	for path in ["user://progress.json", "user://progress.backup.json"]:
		if FileAccess.file_exists(path): original[path] = FileAccess.get_file_as_bytes(path)
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.new_run()
	check(game.run.lives == 3, "Новая игра должна давать три попытки")
	var seed_value = game.run.seed
	game.run.gold = 4
	game.lose("Тест")
	check(game.run.lives == 2 and game.stats.failed[-1].gold == 4, "Смерть расходует общую попытку и попадает в статистику")
	game.retry()
	check(game.run.seed == seed_value and game.run.gold == 0, "Повторяется та же карта, голда сбрасывается")
	game.run.gold = 5
	game.win()
	game.next_level()
	check(game.run.level == 2 and game.run.lives == 2 and game.run.total_gold == 5, "Переход не восстанавливает попытки")
	game.lose("Тест")
	game.retry()
	game.lose("Тест")
	game.retry()
	check(game.run.level == 1 and game.run.lives == 3 and game.run.total_gold == 0, "Третья смерть сбрасывает прохождение")
	game.run.level = 5
	game.start_level()
	game.run.gold = 30
	game.step(0.01)
	check(game.run.ramp > 0, "После 30 слитков начинается разгон")
	game.run.boss_hp = 1
	game.run.boss_x = 200
	game.run.x = 190
	game.run.y = Balance.floor_y(200) - 77
	game.run.vy = 100
	game.run.grounded = false
	game.held[0] = "boost"
	game.update_boss(0.001, game.speed(), game.run.y - 1, true)
	check(game.run.boss_hp == 0 and game.run.state == "won", "Попадание сверху с ускорением побеждает босса")
	game.next_level()
	check(game.run.ramp == 0 and game.run.energy == 100, "Разгон не переносится на следующий уровень")
	game.run.x = 123.5
	game.run.shots = [{"x": 333.0, "high": true}]
	game.save_progress()
	game.run = {}
	game.load_progress()
	check(game.run.x == 123.5 and game.run.shots.size() == 1, "Сохраняется точное состояние мира")
	game.run.level = 15
	game.run.total_gold = 100
	game.resume()
	game.win()
	check(game.stats.wins == 1 and game.stats.record >= 100, "Финал обновляет рекорд")
	# Проверяем детерминизм и изоляцию препятствий на всех трёх скоростях.
	for level in [1, 6, 11]:
		for index in range(100):
			var a = LevelGenerator.section(12345, index, Balance.tier(level), false)
			var b = LevelGenerator.section(12345, index, Balance.tier(level), false)
			check(a == b, "Генерация обязана быть воспроизводимой")
			var hazards = a.objects.filter(func(o): return o.kind in ["gap", "spikes", "beam"])
			check(hazards.size() == 1, "На секцию допускается только одно препятствие")
	game.queue_free()
	await process_frame
	for path in ["user://progress.json", "user://progress.backup.json"]:
		if original.has(path):
			var file = FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(original[path])
			file.close()
		elif FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("Проверки завершены. Ошибок: %d" % failures)
	quit(1 if failures else 0)
