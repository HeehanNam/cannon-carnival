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
	if game.shake_amount > .12:
		push_error("Impact camera shake exceeds the comfort limit")
		quit(1)
		return
	var theme_colors := {}
	for themed_level in [0, 10, 20, 30, 40]:
		game.load_level(themed_level)
		theme_colors[game.environment_data.background_color.to_html()] = true
	if theme_colors.size() != 5:
		push_error("The five level themes do not use distinct sky colors")
		quit(1)
		return
	game.load_level(7)
	await physics_frame
	for candidate in get_nodes_in_group("blocks"):
		var spiral_block := candidate as RigidBody3D
		if spiral_block == null: continue
		var support_query := PhysicsRayQueryParameters3D.create(spiral_block.global_position, spiral_block.global_position + Vector3.DOWN * 1.25)
		support_query.exclude = [spiral_block.get_rid()]
		var support_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(support_query)
		if support_hit.is_empty():
			push_error("Spiral level contains an unsupported floating block")
			quit(1)
			return
	game.state = game.GameState.CHECKING
	game.moves = 2
	game.fire_at(Vector3(0, 1, -1))
	if game.moves != 1 or game.state != game.GameState.PROJECTILE_ACTIVE:
		push_error("A shot could not be fired while result checking was active")
		quit(1)
		return
	game.load_level(0)
	await process_frame
	game.state = game.GameState.CHECKING
	game.moves = 2
	game.blocks_left = 0
	game.confirm_platform_empty()
	if game.state != game.GameState.READY or game.blocks_left <= 0:
		push_error("Result checking did not recover from a stale block count")
		quit(1)
		return
	print("50 levels generated successfully")
	quit()
