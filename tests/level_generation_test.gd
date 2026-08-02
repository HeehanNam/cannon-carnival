extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene := load("res://scenes/game.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load game scene")
		quit(1)
		return
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	for level_index in range(50):
		game.load_level(level_index)
		var generated_blocks: int = game.blocks_left
		if generated_blocks <= 0:
			push_error("Level %d generated no blocks" % (level_index + 1))
			quit(1)
			return
	print("50 levels generated successfully")
	quit()
