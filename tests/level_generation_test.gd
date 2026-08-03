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
	for fitted_level in [0, 20, 40]:
		game.load_level(fitted_level)
		if not platform_fits_blocks(game, int(fitted_level / 10)):
			push_error("Level %d platform does not fit its actual block footprint" % (fitted_level + 1))
			quit(1)
			return
	game.load_level(0)
	var exact_target := Vector3(0, 1.25, -1.0)
	game.fire_at(exact_target)
	var fired_projectile: RigidBody3D = game.projectile
	var horizontal_delta := Vector2(exact_target.x - fired_projectile.position.x, exact_target.z - fired_projectile.position.z)
	var horizontal_velocity := Vector2(fired_projectile.linear_velocity.x, fired_projectile.linear_velocity.z)
	var flight_time: float = horizontal_delta.length() / horizontal_velocity.length()
	var predicted_height: float = fired_projectile.position.y + fired_projectile.linear_velocity.y * flight_time - .5 * 12.0 * flight_time * flight_time
	if abs(predicted_height - exact_target.y) > .035:
		push_error("Ballistic trajectory does not intersect the exact touched height")
		quit(1)
		return
	game.load_level(0)
	game.state = game.GameState.READY
	var resume_timer := game.get_tree().create_timer(.01, true, false, true)
	resume_timer.timeout.connect(game.on_overlay_button)
	game.toggle_pause()
	await resume_timer.timeout
	if game.get_tree().paused or game.state != game.GameState.READY:
		push_error("Continue button did not resume the paused game")
		quit(1)
		return
	game.load_level(40)
	await process_frame
	var depth_bands := {}
	for candidate in get_nodes_in_group("blocks"):
		var layered_block := candidate as Node3D
		if layered_block == null: continue
		var local_block_position: Vector3 = game.platform.to_local(layered_block.global_position)
		depth_bands[roundi(local_block_position.z * 10.0)] = true
	if depth_bands.size() < 3:
		push_error("Late-game level does not contain at least three depth layers")
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

func platform_fits_blocks(game, tier: int) -> bool:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for candidate in get_nodes_in_group("blocks"):
		var block := candidate as Node3D
		if block == null or not block.is_inside_tree(): continue
		var local_position: Vector3 = game.platform.to_local(block.global_position)
		var footprint: Vector2 = block.get_meta("footprint", Vector2(.82, .82))
		min_x = minf(min_x, local_position.x - footprint.x * .5)
		max_x = maxf(max_x, local_position.x + footprint.x * .5)
		min_z = minf(min_z, local_position.z - footprint.y * .5)
		max_z = maxf(max_z, local_position.z + footprint.y * .5)
	var margins: Array[float] = [1.0, .85, .7, .55, .4]
	var expected_margin: float = margins[clampi(tier, 0, 4)]
	var horizontal_fit: bool = abs((min_x + game.platform_half_extents.x) - expected_margin) < .03 and abs((game.platform_half_extents.x - max_x) - expected_margin) < .03
	var depth_fit: bool = abs((min_z + game.platform_half_extents.y) - expected_margin) < .03 and abs((game.platform_half_extents.y - max_z) - expected_margin) < .03
	return horizontal_fit and depth_fit
