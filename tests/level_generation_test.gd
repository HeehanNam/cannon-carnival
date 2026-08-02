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
	game.load_level(9)
	await process_frame
	var glass_block: RigidBody3D
	for candidate in get_nodes_in_group("blocks"):
		if str(candidate.get_meta("block_type", "")) == "glass":
			glass_block = candidate as RigidBody3D
			break
	if glass_block == null:
		push_error("Laboratory level generated no glass block")
		quit(1)
		return
	var test_projectile := RigidBody3D.new()
	test_projectile.linear_velocity = Vector3(0, 0, -15)
	root.add_child(test_projectile)
	var blocks_before_break: int = game.blocks_left
	game.on_projectile_hit(glass_block, test_projectile)
	if game.blocks_left != blocks_before_break - 1:
		push_error("Glass block did not break and update remaining count")
		quit(1)
		return
	print("50 levels generated successfully")
	quit()
