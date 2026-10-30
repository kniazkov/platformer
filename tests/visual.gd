extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280, 720)
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.new_run()
	game.run.x = 100
	game.run.y = Balance.floor_y(100)
	game.ensure_sections()
	game._physics_process(0.0)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/platformer-game.png")
	game.menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/platformer-menu.png")
	game.queue_free()
	await process_frame
	quit()
