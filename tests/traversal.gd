extends SceneTree
func _initialize() -> void:
	call_deferred("verify")
func verify() -> void:
	var original: Dictionary = {}
	for path in ["user://progress.json", "user://progress.backup.json"]:
		if FileAccess.file_exists(path): original[path] = FileAccess.get_file_as_bytes(path)
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	var failures = 0
	for level in [1, 6, 11]:
		for seed_value in range(10):
			game.run = {"level": level, "lives": 3, "total_gold": 0, "deaths": 0, "seed": seed_value}
			game.start_level()
			game.held[0] = "boost"
			for tick in range(10000):
				if game.mode != "playing": break
				game.ensure_sections()
				game.held.erase(1)
				for item in game.run.objects:
					var distance = item.x - game.run.x
					if item.kind in ["gap", "spikes"] and distance > 0 and distance < 58 * Balance.tier(level) and game.run.grounded:
						game.jump_requested = true
					if item.kind == "beam" and distance < 65 * Balance.tier(level) and distance > -item.width - 35:
						game.held[1] = "crouch"
				game.step(1.0 / 120.0)
			if game.run.state != "won":
				push_error("Карта не пройдена: уровень %d seed %d x %.1f голда %d причина %s" % [level, seed_value, game.run.x, game.run.gold, game.run.get("reason", "таймаут")])
				failures += 1
	game.queue_free()
	await process_frame
	for path in ["user://progress.json", "user://progress.backup.json"]:
		if original.has(path):
			var file = FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(original[path])
			file.close()
		elif FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	await process_frame
	print("Пройдено карт: %d/30" % (30 - failures))
	quit(1 if failures else 0)
