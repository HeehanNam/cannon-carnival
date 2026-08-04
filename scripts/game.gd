extends Node3D

enum GameState { READY, AIMING, PROJECTILE_ACTIVE, CHECKING, CLEAR, FAIL, PAUSED }

const LEVEL_COUNT := 50
const TEMPLATE_NAMES := ["중앙 타워", "쌍둥이 성", "회전 요새", "계단 피라미드", "블록 장벽", "공중 다리", "아치 관문", "나선 탑", "도미노 정원", "연금술 연구소"]
const BLOCK_RED := Color("e62f43")
const BLOCK_DARK := Color("a8142b")
const CREAM := Color("fff0c2")
const BLOCK_SCRIPT := preload("res://scripts/physics_block.gd")
const PARK_BACKGROUND := preload("res://assets/backgrounds/toy_kingdom_park.png")
const THEME_NAMES := ["햇살 공원", "산호 해변", "캔디 정원", "눈꽃 마을", "별빛 공원"]
const SKY_COLORS := [Color("37aef6"), Color("48cfe8"), Color("a978ed"), Color("9bd8f5"), Color("172654")]
const GROUND_COLORS := [Color("62ba24"), Color("f2cf72"), Color("f093c3"), Color("dbeff5"), Color("35406f")]
const FOLIAGE_COLORS := [Color("64d83d"), Color("26c5a4"), Color("ff75bd"), Color("b7e7ef"), Color("7656c7")]

var state := GameState.READY
var state_before_pause := GameState.READY
var level := 0
var moves := 7
var score := 0
var targets_left := 0
var blocks_left := 0
var projectile: RigidBody3D
var projectile_timer := 0.0
var cannon_yaw := 0.0
var cannon_pitch := deg_to_rad(14.0)
var stage_root: Node3D
var cannon_pivot: Node3D
var barrel_pivot: Node3D
var camera: Camera3D
var background_sprite: Sprite3D
var environment_data: Environment
var ground_visual: MeshInstance3D
var tree_crowns: Array[MeshInstance3D] = []
var platform: AnimatableBody3D
var platform_angle := 0.0
var platform_rotation_speed := 0.0
var platform_half_extents := Vector2(3.65, 2.55)
var impact_started := false
var clear_pending := false
var moves_label: Label
var target_label: Label
var level_label: Label
var hint_label: Label
var overlay: Control
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var flash: ColorRect
var shake_amount := 0.0
var shake_phase := 0.0

func _ready() -> void:
	build_environment()
	build_ui()
	load_level(0)

func build_environment() -> void:
	var world := WorldEnvironment.new()
	environment_data = Environment.new()
	environment_data.background_mode = Environment.BG_COLOR
	environment_data.background_color = SKY_COLORS[0]
	environment_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_data.ambient_light_color = Color("dff6ff")
	environment_data.ambient_light_energy = 0.85
	environment_data.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment_data
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.position = Vector3(0, 6.25, 15.5)
	camera.rotation_degrees = Vector3(-11, 0, 0)
	camera.fov = 47
	add_child(camera)
	background_sprite = Sprite3D.new()
	background_sprite.texture = PARK_BACKGROUND
	background_sprite.position = Vector3(0, 5.5, -11.0)
	background_sprite.pixel_size = .014
	background_sprite.shaded = false
	add_child(background_sprite)

	# Sunny park ground.
	var ground := StaticBody3D.new()
	ground.position = Vector3(0, -1.0, 0)
	ground_visual = mesh_box(Vector3(36, 0.5, 36), GROUND_COLORS[0])
	ground.add_child(ground_visual)
	ground.add_child(shape_box(Vector3(36, 0.5, 36)))
	add_child(ground)
	# Keep the entire firing lane clear. Decorations live behind the target only.
	for i in range(18):
		var tree := Node3D.new()
		var row := i / 9
		var column := i % 9
		tree.position = Vector3(-10.0 + column * 2.5, 0, -5.5 - row * 2.2)
		tree.add_child(mesh_cylinder(0.18, 1.0, Color("9b6028")))
		var crown := mesh_sphere(0.75, Color.from_hsv(0.28 + (i % 3) * .02, .72, .65 + (i % 2) * .12))
		crown.position.y = 1.0
		tree.add_child(crown)
		tree_crowns.append(crown)
		add_child(tree)

	stage_root = Node3D.new()
	stage_root.name = "Stage"
	add_child(stage_root)
	build_cannon()

func build_cannon() -> void:
	cannon_pivot = Node3D.new()
	cannon_pivot.position = Vector3(0, 0.0, 9.0)
	add_child(cannon_pivot)
	var base := mesh_cylinder(1.5, 0.55, Color("f6a800"))
	base.position.y = -0.3
	cannon_pivot.add_child(base)
	var ring := mesh_cylinder(1.22, 0.68, Color("135cde"))
	ring.position.y = 0.05
	cannon_pivot.add_child(ring)
	barrel_pivot = Node3D.new()
	barrel_pivot.position.y = 0.45
	cannon_pivot.add_child(barrel_pivot)
	var barrel := mesh_cylinder(0.48, 3.0, Color("df243d"))
	barrel.rotation_degrees.x = 90
	barrel.position = Vector3(0, 0.25, -1.1)
	barrel_pivot.add_child(barrel)
	var muzzle := mesh_cylinder(0.62, 0.42, Color("ffbf16"))
	muzzle.rotation_degrees.x = 90
	muzzle.position = Vector3(0, 0.25, -2.62)
	barrel_pivot.add_child(muzzle)

func build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var top := ColorRect.new()
	top.color = Color(0.02, 0.14, 0.35, 0.36)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = 92
	ui.add_child(top)

	moves_label = make_label("발사 7", 29, Color.WHITE)
	moves_label.position = Vector2(22, 19)
	moves_label.add_theme_stylebox_override("normal", panel_style(Color("7048b8"), 16, 4, Color("ffcf52")))
	moves_label.custom_minimum_size = Vector2(132, 60)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.add_child(moves_label)

	level_label = make_label("LEVEL 1", 22, Color.WHITE)
	level_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	level_label.position = Vector2(-75, 19)
	level_label.size = Vector2(150, 50)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(level_label)

	target_label = make_label("타깃 0", 20, Color.WHITE)
	target_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	target_label.position = Vector2(-155, 24)
	target_label.size = Vector2(135, 45)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(target_label)

	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.add_theme_font_size_override("font_size", 24)
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-61, 18)
	pause.size = Vector2(48, 48)
	pause.pressed.connect(toggle_pause)
	ui.add_child(pause)

	hint_label = make_label("화면을 터치해 발사하세요", 19, Color.WHITE)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-185, -174)
	hint_label.size = Vector2(370, 42)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_stylebox_override("normal", panel_style(Color(0.03, .06, .18, .62), 20))
	ui.add_child(hint_label)

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(flash)

	overlay = ColorRect.new()
	overlay.color = Color(0.02, .06, .16, .82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	ui.add_child(overlay)
	overlay_title = make_label("STAGE CLEAR!", 44, Color("ffdc42"))
	overlay_title.set_anchors_preset(Control.PRESET_CENTER)
	overlay_title.position = Vector2(-230, -170)
	overlay_title.size = Vector2(460, 70)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_title)
	overlay_body = make_label("★★★", 34, Color.WHITE)
	overlay_body.set_anchors_preset(Control.PRESET_CENTER)
	overlay_body.position = Vector2(-220, -85)
	overlay_body.size = Vector2(440, 150)
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_body)
	overlay_button = Button.new()
	overlay_button.text = "다음 스테이지"
	overlay_button.set_anchors_preset(Control.PRESET_CENTER)
	overlay_button.position = Vector2(-110, 100)
	overlay_button.size = Vector2(220, 70)
	overlay_button.add_theme_font_size_override("font_size", 23)
	overlay_button.pressed.connect(on_overlay_button)
	overlay.add_child(overlay_button)

func load_level(index: int) -> void:
	level = posmod(index, LEVEL_COUNT)
	apply_level_theme(level)
	for child in stage_root.get_children():
		stage_root.remove_child(child)
		child.queue_free()
	moves = move_limit_for_level(level)
	score = 0
	targets_left = 0
	blocks_left = 0
	state = GameState.READY
	projectile = null
	impact_started = false
	clear_pending = false
	platform_angle = 0.0
	platform_rotation_speed = rotation_speed_for_level(level)
	overlay.visible = false
	cannon_yaw = 0.0
	cannon_pitch = deg_to_rad(14)
	update_cannon()

	platform = AnimatableBody3D.new()
	platform.position = Vector3(0, 0, -1.0)
	var platform_physics := PhysicsMaterial.new()
	platform_physics.friction = 1.0
	platform_physics.rough = true
	platform.physics_material_override = platform_physics
	var tier: int = int(level / 10)
	var platform_size := Vector3(8.6, 0.55, 6.2)
	platform_half_extents = Vector2(platform_size.x * .5, platform_size.z * .5)
	var platform_visual := mesh_box(platform_size, Color("623bc1"))
	var platform_collision := shape_box(platform_size)
	platform.add_child(platform_visual)
	platform.add_child(platform_collision)
	stage_root.add_child(platform)
	var trim := mesh_box(platform_size + Vector3(.15, -.38, .15), Color("ffca22"))
	trim.position.y = .35
	platform.add_child(trim)
	var pedestal := mesh_cylinder(.34, 1.25, Color("f5a919"))
	pedestal.position.y = -.85
	platform.add_child(pedestal)

	generate_level_structure(level)
	fit_platform_to_structure(tier, platform_visual, platform_collision, trim)
	update_hud()
	hint_label.text = THEME_NAMES[int(level / 10)] + " · " + TEMPLATE_NAMES[level % TEMPLATE_NAMES.size()]

func apply_level_theme(level_index: int) -> void:
	var theme_index: int = clampi(int(level_index / 10), 0, SKY_COLORS.size() - 1)
	if environment_data:
		environment_data.background_color = SKY_COLORS[theme_index]
		environment_data.ambient_light_color = SKY_COLORS[theme_index].lightened(.58)
	if background_sprite:
		var background_tints: Array[Color] = [Color.WHITE, Color("e8fff8"), Color("ffe8fa"), Color("eef8ff"), Color("b8c7ff")]
		background_sprite.modulate = background_tints[theme_index]
	if ground_visual and ground_visual.mesh:
		ground_visual.mesh.material = material(GROUND_COLORS[theme_index])
	for i in range(tree_crowns.size()):
		var crown := tree_crowns[i]
		if crown and crown.mesh:
			var variation: float = float(i % 3) * .055 - .055
			var foliage: Color = FOLIAGE_COLORS[theme_index]
			foliage = foliage.lightened(variation) if variation >= 0.0 else foliage.darkened(-variation)
			crown.mesh.material = material(foliage)

func fit_platform_to_structure(tier: int, visual: MeshInstance3D, collision: CollisionShape3D, trim: MeshInstance3D) -> void:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for node in get_tree().get_nodes_in_group("blocks"):
		var block := node as Node3D
		if block == null or not block.is_inside_tree(): continue
		# Use the immutable level-layout coordinate. Transform caches for physics
		# bodies can lag by a frame while a level is being assembled headlessly.
		var local_position: Vector3 = block.get_meta("layout_position", block.position + Vector3(0, 0, 1.0))
		var footprint: Vector2 = block.get_meta("footprint", Vector2(.82, .82))
		min_x = minf(min_x, local_position.x - footprint.x * .5)
		max_x = maxf(max_x, local_position.x + footprint.x * .5)
		min_z = minf(min_z, local_position.z - footprint.y * .5)
		max_z = maxf(max_z, local_position.z + footprint.y * .5)
	if min_x == INF:
		return
	var margins: Array[float] = [1.0, .85, .7, .55, .4]
	var margin: float = margins[clampi(tier, 0, margins.size() - 1)]
	var center_x: float = (min_x + max_x) * .5
	var center_z: float = (min_z + max_z) * .5
	var fitted_size := Vector3(maxf(2.8, max_x - min_x + margin * 2.0), .55, maxf(2.6, max_z - min_z + margin * 2.0))
	platform.position = Vector3(center_x, 0, -1.0 + center_z)
	platform.force_update_transform()
	platform_half_extents = Vector2(fitted_size.x * .5, fitted_size.z * .5)
	var box_mesh := visual.mesh as BoxMesh
	var box_shape := collision.shape as BoxShape3D
	var trim_mesh := trim.mesh as BoxMesh
	if box_mesh: box_mesh.size = fitted_size
	if box_shape: box_shape.size = fitted_size
	if trim_mesh: trim_mesh.size = Vector3(fitted_size.x + .15, .17, fitted_size.z + .15)

func move_limit_for_level(level_index: int) -> int:
	var tier: int = int(level_index / 10)
	var template_bonus: int = 1 if level_index % 10 in [1, 2, 5, 6, 9] else 0
	return max(5, 10 + template_bonus - tier)

func rotation_speed_for_level(level_index: int) -> float:
	if level_index < 5:
		return 0.0
	if level_index % 4 not in [2, 3] and level_index < 30:
		return 0.0
	return 0.12 + float(int(level_index / 10)) * 0.035

func generate_level_structure(level_index: int) -> void:
	var tier: int = int(level_index / 10)
	var template: int = level_index % 10
	match template:
		0:
			build_tower(Vector3.ZERO, 3 + tier % 2, 3 + min(tier, 2))
		1:
			var rows: int = 3 + mini(int(tier / 2), 2)
			build_tower(Vector3(-1.75, 0, 0), 2, rows)
			build_tower(Vector3(1.75, 0, 0), 2, rows)
			add_block(Vector3(0, float(rows) + .55, 0), Vector3(3.7, .55, .75), true, tier >= 3)
		2:
			build_fortress(tier)
		3:
			build_pyramid(3 + min(tier, 2), tier)
		4:
			build_wall(4 + tier % 2, 3 + min(int(tier / 2), 1), tier)
		5:
			build_bridge(tier)
		6:
			build_arch(tier)
		7:
			build_spiral(tier)
		8:
			build_domino_garden(tier)
		9:
			build_laboratory(tier)
	if tier >= 2:
		build_depth_defenses(tier, level_index)

func build_depth_defenses(tier: int, level_index: int) -> void:
	# Later stages gain grounded layers along the depth axis. Spacing keeps each
	# layer physically separate while requiring shots through or around the front.
	var rear_z := -1.38
	var rear_columns := [-2.45, 0.0, 2.45]
	var rear_height: int = 1 if tier == 2 else 2
	for column_index in range(rear_columns.size()):
		for y in range(rear_height):
			var rear_type := "ice" if (column_index + y + level_index) % 3 == 0 else "wood"
			if tier >= 4 and column_index == 1 and y == 0:
				rear_type = "explosive"
			add_block(Vector3(rear_columns[column_index], .775 + y, rear_z), Vector3(.78, 1.0, .72), y == rear_height - 1, false, rear_type)
	if tier < 3:
		return
	var front_z := 1.38
	var front_columns := [-1.85, 0.0, 1.85]
	var front_height: int = 1 if tier == 3 else 2
	for column_index in range(front_columns.size()):
		for y in range(front_height):
			var front_type := "glass" if (column_index + y) % 2 == 0 else "stone"
			add_block(Vector3(front_columns[column_index], .775 + y, front_z), Vector3(.76, 1.0, .72), y == front_height - 1, front_type == "stone", front_type)
	if tier >= 4:
		# A low middle-depth brace makes the final ten stages genuinely three-layered.
		for x in [-2.75, 2.75]:
			add_block(Vector3(x, .725, 0), Vector3(.68, .9, .68), false, false, "ice")

func build_tower(offset: Vector3, columns: int, rows: int) -> void:
	for y in range(rows):
		for x in range(columns):
			var px := (x - (columns - 1) * .5) * 1.18
			var target := y == rows - 1 or (y == 1 and x == columns / 2)
			add_block(offset + Vector3(px, .775 + y * 1.0, 0), Vector3(.82, 1.0, .82), target, (x + y) % 4 == 0)

func build_fortress(tier: int) -> void:
	for x in [-2.25, -1.12, 0.0, 1.12, 2.25]: add_block(Vector3(x, .775, 0), Vector3(.82, 1.0, .82), x == 0, false)
	for x in [-2.0, 0.0, 2.0]: add_block(Vector3(x, 1.775, 0), Vector3(.9, 1.0, .9), true, x != 0)
	add_block(Vector3(-1.0, 2.5, 0), Vector3(2.7, .45, .75), false, false)
	add_block(Vector3(1.0, 2.5, 0), Vector3(2.7, .45, .75), false, false)
	add_block(Vector3(0, 3.225, 0), Vector3(.9, 1.0, .9), true, false)
	if tier >= 2:
		add_block(Vector3(-2.65, 1.775, 0), Vector3(.82, 1.0, .82), false, tier >= 4)
		add_block(Vector3(2.65, 1.775, 0), Vector3(.82, 1.0, .82), false, tier >= 4)

func build_pyramid(rows: int, tier: int) -> void:
	var base_count: int = rows + 1
	for y in range(rows):
		var count: int = base_count - y
		for x in range(count):
			var px: float = (x - (count - 1) * .5) * 1.08
			var is_top: bool = y == rows - 1
			add_block(Vector3(px, .775 + y, 0), Vector3(.82, 1.0, .82), is_top, tier >= 3 and (x + y) % 5 == 0)

func build_wall(columns: int, rows: int, tier: int) -> void:
	for y in range(rows):
		for x in range(columns):
			var px: float = (x - (columns - 1) * .5) * 1.08
			var offset_x: float = .27 if y % 2 == 1 else 0.0
			add_block(Vector3(px + offset_x, .775 + y, 0), Vector3(.82, 1.0, .82), y == rows - 1, tier >= 2 and (x + y) % 4 == 0)

func build_bridge(tier: int) -> void:
	var pillar_rows: int = 2 + mini(tier, 2)
	for side in [-1.0, 1.0]:
		for y in range(pillar_rows):
			add_block(Vector3(side * 2.25, .775 + y, 0), Vector3(.88, 1.0, .88), y == pillar_rows - 1, tier >= 3 and y == 0, "stone" if y == 0 else "")
	var bridge_y: float = float(pillar_rows) + .55
	add_block(Vector3(0, bridge_y, 0), Vector3(4.25, .55, .8), true, false, "wood")
	for x in [-1.35, 0.0, 1.35]:
		add_block(Vector3(x, bridge_y + .8, 0), Vector3(.68, .9, .68), x == 0, false, "glass" if x != 0 else "ice")

func build_arch(tier: int) -> void:
	var height: int = 3 + mini(int(tier / 2), 1)
	for side in [-1.0, 1.0]:
		for y in range(height):
			add_block(Vector3(side * 1.65, .775 + y, 0), Vector3(.85, 1.0, .85), y == height - 1, tier >= 3 and y == 0, "stone" if y == 0 else "")
	add_block(Vector3(0, float(height) + .55, 0), Vector3(3.8, .55, .8), true, false, "wood")
	add_block(Vector3(0, float(height) + 1.25, 0), Vector3(.72, .82, .72), true, false, "glass")
	if tier >= 2:
		add_block(Vector3(-2.7, .775, 0), Vector3(.75, 1.0, .75), false, false, "ice")
		add_block(Vector3(2.7, .775, 0), Vector3(.75, 1.0, .75), false, false, "ice")

func build_spiral(tier: int) -> void:
	# Every step is a grounded vertical column. The curved height profile keeps
	# the spiral silhouette without relying on unsupported floating blocks.
	var columns: int = 7 + tier
	for column in range(columns):
		var progress: float = float(column) / maxf(1.0, float(columns - 1))
		var angle: float = lerp(-1.25, 1.25, progress)
		var radius: float = 2.15
		var column_height: int = 1 + column % (3 + mini(tier, 2))
		for y in range(column_height):
			var block_type := "ice" if tier >= 1 and (column + y) % 6 == 2 else ""
			add_block(Vector3(sin(angle) * radius, .635 + y * .72, cos(angle) * radius - 1.15), Vector3(.7, .72, .7), y == column_height - 1, tier >= 4 and y == 0, block_type)

func build_domino_garden(tier: int) -> void:
	var count: int = 11 + tier * 2
	for i in range(count):
		var progress: float = float(i) / maxf(1.0, float(count - 1))
		var x: float = lerp(-2.8, 2.8, progress)
		var z: float = sin(progress * TAU * 1.5) * 1.15
		var kind := "explosive" if tier >= 2 and i == int(count / 2) else ("ice" if i % 5 == 0 else "wood")
		add_block(Vector3(x, .875, z), Vector3(.42, 1.2, .72), i % 4 == 0, false, kind)

func build_laboratory(tier: int) -> void:
	for x in [-2.2, 0.0, 2.2]:
		add_block(Vector3(x, .725, 0), Vector3(.7, .9, .7), true, false, "glass")
		add_block(Vector3(x, 1.65, 0), Vector3(.82, .9, .82), false, false, "ice")
	add_block(Vector3(0, 2.4, 0), Vector3(5.3, .5, .75), true, tier >= 4, "stone" if tier >= 3 else "wood")
	for x in [-1.5, 0.0, 1.5]:
		var kind := "explosive" if tier >= 2 and x == 0.0 else "glass"
		add_block(Vector3(x, 3.05, 0), Vector3(.68, .8, .68), true, false, kind)

func add_block(pos: Vector3, size: Vector3, is_target: bool, heavy: bool, requested_type := "") -> void:
	var body := RigidBody3D.new()
	body.set_script(BLOCK_SCRIPT)
	body.position = pos + Vector3(0, 0, -1.0)
	var block_type: String = requested_type if requested_type != "" else choose_block_type(pos, heavy)
	body.mass = block_mass(block_type)
	var block_physics := PhysicsMaterial.new()
	block_physics.friction = 1.0
	block_physics.rough = true
	body.physics_material_override = block_physics
	body.set_meta("target", is_target)
	body.set_meta("counted", false)
	body.set_meta("value", 200 if is_target else 100)
	body.set_meta("block_type", block_type)
	body.set_meta("durability", 2 if block_type == "ice" else 1)
	body.set_meta("footprint", Vector2(size.x, size.z))
	body.set_meta("layout_position", pos)
	body.add_to_group("blocks")
	blocks_left += 1
	build_block_visual(body, size, block_type)
	if is_target:
		var crown := mesh_sphere(size.x * .2, Color("ffd62f"))
		crown.scale.y = .45
		crown.position = Vector3(0, size.y * .54, 0)
		body.add_child(crown)
		targets_left += 1
	stage_root.add_child(body)

func choose_block_type(pos: Vector3, heavy: bool) -> String:
	if heavy: return "stone"
	var key: int = abs(int(pos.x * 31.0) + int(pos.y * 17.0) + level * 13)
	if level >= 24 and key % 19 == 0: return "explosive"
	if level >= 12 and key % 11 == 0: return "ice"
	if level >= 7 and key % 13 == 0: return "glass"
	if level >= 4 and key % 5 == 0: return "wood"
	return "barrel"

func block_mass(block_type: String) -> float:
	match block_type:
		"glass": return .55
		"ice": return .8
		"wood": return .9
		"stone": return 3.2
		"explosive": return 1.1
		_: return 1.0

func build_block_visual(body: RigidBody3D, size: Vector3, block_type: String) -> void:
	var accent: Color = level_block_color(0.0)
	var secondary: Color = level_block_color(.09)
	match block_type:
		"glass":
			body.add_child(mesh_transparent_cylinder(size.x * .43, size.y * .72, Color(0.55, .95, 1.0, .42)))
			body.add_child(shape_cylinder(size.x * .43, size.y))
			var liquid := mesh_transparent_cylinder(size.x * .32, size.y * .36, Color(.72, .22, 1.0, .82))
			liquid.position.y = -size.y * .15
			body.add_child(liquid)
			var neck := mesh_transparent_cylinder(size.x * .19, size.y * .28, Color(.72, 1.0, 1.0, .5))
			neck.position.y = size.y * .47
			body.add_child(neck)
		"ice":
			body.add_child(mesh_transparent_box(size, Color(.38, .88, 1.0, .72)))
			body.add_child(shape_box(size))
			var core := mesh_box(size * .62, Color("dffaff"))
			body.add_child(core)
		"wood":
			body.add_child(mesh_box(size, Color("b96b32").lerp(accent, .18)))
			body.add_child(shape_box(size))
			var band := mesh_box(Vector3(size.x * 1.02, size.y * .13, size.z * 1.02), Color("f2b85b"))
			body.add_child(band)
		"stone":
			body.add_child(mesh_box(size, Color("68748c").lerp(secondary, .22)))
			body.add_child(shape_box(size))
			var inset := mesh_box(size * .72, Color("8995aa"))
			inset.position.z = size.z * .15
			body.add_child(inset)
		"explosive":
			body.add_child(mesh_cylinder(size.x * .5, size.y, Color("29283e").lerp(accent, .2)))
			body.add_child(shape_cylinder(size.x * .5, size.y))
			var warning := mesh_cylinder(size.x * .515, size.y * .22, Color("ffd322"))
			body.add_child(warning)
		_:
			body.add_child(mesh_cylinder(size.x * .5, size.y, accent))
			body.add_child(shape_cylinder(size.x * .5, size.y))
			var stripe := mesh_cylinder(size.x * .515, size.y * .13, CREAM)
			stripe.position.y = size.y * .17
			body.add_child(stripe)
			var stripe2 := mesh_cylinder(size.x * .515, size.y * .10, CREAM)
			stripe2.position.y = -size.y * .28
			body.add_child(stripe2)

func level_block_color(hue_offset: float) -> Color:
	var theme_index: int = clampi(int(level / 10), 0, 4)
	var base_hues: Array[float] = [.97, .05, .88, .53, .66]
	var hue: float = fmod(base_hues[theme_index] + hue_offset + float(level % 10) * .018, 1.0)
	return Color.from_hsv(hue, .72 if theme_index != 3 else .48, .94)

func fire_at(target: Vector3) -> void:
	if state not in [GameState.READY, GameState.AIMING, GameState.PROJECTILE_ACTIVE, GameState.CHECKING] or moves <= 0: return
	var cannon_origin := cannon_pivot.position + Vector3.UP * .7
	var origin := cannon_origin
	var launch_velocity := ballistic_velocity(origin, target, 19.0)
	for iteration in range(2):
		origin = cannon_origin + launch_velocity.normalized() * 2.8
		launch_velocity = ballistic_velocity(origin, target, 19.0)
	if launch_velocity.length_squared() < 0.1: return
	cannon_yaw = atan2(-launch_velocity.x, -launch_velocity.z)
	cannon_pitch = asin(clamp(launch_velocity.normalized().y, -1.0, 1.0))
	update_cannon()
	state = GameState.PROJECTILE_ACTIVE
	moves -= 1
	projectile_timer = 0.0
	projectile = RigidBody3D.new()
	projectile.mass = 2.2
	projectile.continuous_cd = true
	projectile.position = origin
	projectile.add_child(mesh_sphere(.42, Color("192237")))
	projectile.add_child(shape_sphere(.42))
	projectile.linear_velocity = launch_velocity
	projectile.contact_monitor = true
	projectile.max_contacts_reported = 8
	projectile.body_entered.connect(on_projectile_hit.bind(projectile))
	add_child(projectile)
	shake_amount = max(shake_amount, .025)
	flash.color.a = .10
	update_hud()
	hint_label.text = "선택한 지점으로 발사했습니다"

func on_projectile_hit(body: Node, source_projectile: RigidBody3D) -> void:
	shake_amount = max(shake_amount, .055)
	flash.color.a = .14
	if body is Node3D:
		spawn_shards((body as Node3D).global_position, level_block_color(.08), 5)
	if not impact_started:
		impact_started = true
		# Once the first real collision happens, gravity applies to the full tower.
		# Only the directly hit block receives the projectile impulse.
		for block in get_tree().get_nodes_in_group("blocks"):
			if is_instance_valid(block) and block.has_method("activate_physics"):
				block.activate_physics()
	if body.has_method("activate_physics"):
		var impulse := source_projectile.linear_velocity.normalized() * 12.5 if is_instance_valid(source_projectile) else Vector3.ZERO
		body.activate_physics(impulse)
	if not body.is_in_group("blocks"):
		return
	var block_type: String = str(body.get_meta("block_type", "barrel"))
	if block_type == "glass":
		destroy_special_block(body, Color(.55, .95, 1.0, .78), 16)
	elif block_type == "ice":
		var durability: int = int(body.get_meta("durability", 2)) - 1
		body.set_meta("durability", durability)
		spawn_shards(body.global_position, Color(.45, .9, 1.0, .8), 7)
		if durability <= 0:
			destroy_special_block(body, Color(.72, .96, 1.0, .9), 15)
	elif block_type == "explosive":
		explode_block(body)

func destroy_special_block(body: Node, shard_color: Color, shard_count: int) -> void:
	if not is_instance_valid(body): return
	var body_3d := body as Node3D
	if body_3d == null: return
	spawn_shards(body_3d.global_position, shard_color, shard_count)
	if not body.get_meta("counted", false):
		body.set_meta("counted", true)
		blocks_left = maxi(0, blocks_left - 1)
		score += int(body.get_meta("value", 100))
		update_hud()
	body.queue_free()

func explode_block(body: Node) -> void:
	var source := body as Node3D
	if source == null: return
	var blast_origin: Vector3 = source.global_position
	destroy_special_block(body, Color("ffcf32"), 20)
	shake_amount = .11
	flash.color.a = .26
	for candidate in get_tree().get_nodes_in_group("blocks"):
		var nearby := candidate as RigidBody3D
		if nearby == null or nearby == body: continue
		var offset: Vector3 = nearby.global_position - blast_origin
		var distance: float = offset.length()
		if distance < 3.2 and nearby.has_method("activate_physics"):
			var strength: float = lerp(13.0, 3.0, distance / 3.2)
			nearby.activate_physics(offset.normalized() * strength + Vector3.UP * 2.5)

func spawn_shards(origin: Vector3, shard_color: Color, amount: int) -> void:
	for i in range(amount):
		var shard := RigidBody3D.new()
		shard.mass = .04
		shard.collision_layer = 0
		shard.collision_mask = 0
		shard.position = origin + Vector3(randf_range(-.18, .18), randf_range(-.2, .2), randf_range(-.18, .18))
		var shard_size := Vector3(randf_range(.06, .16), randf_range(.05, .19), randf_range(.04, .12))
		shard.add_child(mesh_transparent_box(shard_size, shard_color))
		add_child(shard)
		shard.linear_velocity = Vector3(randf_range(-4.5, 4.5), randf_range(2.0, 7.0), randf_range(-4.0, 4.0))
		shard.angular_velocity = Vector3(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		get_tree().create_timer(1.4).timeout.connect(shard.queue_free)

func _physics_process(delta: float) -> void:
	if state == GameState.PAUSED: return
	if platform_rotation_speed > 0.0 and platform and is_instance_valid(platform):
		var angle_delta := delta * platform_rotation_speed
		platform_angle += angle_delta
		platform.rotation.y = platform_angle
		# Frozen rigid bodies do not inherit an AnimatableBody transform, so carry
		# them explicitly until the first impact enables normal dynamics.
		if not impact_started:
			var rotation_center := platform.global_position
			for block in get_tree().get_nodes_in_group("blocks"):
				if not is_instance_valid(block): continue
				var block_body: RigidBody3D = block as RigidBody3D
				if block_body == null: continue
				var relative: Vector3 = block_body.global_position - rotation_center
				relative = relative.rotated(Vector3.UP, angle_delta)
				block_body.global_position = rotation_center + relative
				block_body.rotate_y(angle_delta)
	check_dropped_blocks()
	if projectile and is_instance_valid(projectile):
		projectile_timer += delta
		if state == GameState.PROJECTILE_ACTIVE and (projectile_timer > 5.5 or projectile.position.y < -3.0 or projectile.linear_velocity.length() < .18 and projectile_timer > 2.0):
			state = GameState.CHECKING
			get_tree().create_timer(1.0).timeout.connect(finish_check)
	if flash.color.a > 0: flash.color.a = move_toward(flash.color.a, 0.0, delta * 3.6)
	if shake_amount > 0:
		shake_phase += delta * 32.0
		camera.h_offset = sin(shake_phase) * shake_amount
		camera.v_offset = sin(shake_phase * 1.65) * shake_amount * .32
		shake_amount = move_toward(shake_amount, 0.0, delta * 1.9)
	else:
		camera.h_offset = 0; camera.v_offset = 0

func check_dropped_blocks() -> void:
	for body in get_tree().get_nodes_in_group("blocks"):
		if not is_instance_valid(body) or body.get_meta("counted", false): continue
		if not is_block_on_platform(body):
			body.set_meta("counted", true)
			score += int(body.get_meta("value", 100))
			blocks_left -= 1
			if body.get_meta("target", false): targets_left -= 1
			update_hud()
			get_tree().create_timer(1.2).timeout.connect(body.queue_free)
	var actual_remaining: int = count_blocks_on_platform()
	blocks_left = actual_remaining
	update_hud()
	if actual_remaining <= 0 and not clear_pending and state not in [GameState.CLEAR, GameState.FAIL]:
		clear_pending = true
		get_tree().create_timer(0.8).timeout.connect(confirm_platform_empty)

func is_block_on_platform(body: Node3D) -> bool:
	if not platform or not is_instance_valid(platform):
		return false
	var local_position: Vector3 = platform.to_local(body.global_position)
	return abs(local_position.x) <= platform_half_extents.x + .2 and abs(local_position.z) <= platform_half_extents.y + .2 and local_position.y >= -0.55

func count_blocks_on_platform() -> int:
	var result := 0
	for node in get_tree().get_nodes_in_group("blocks"):
		var block := node as Node3D
		if block != null and is_instance_valid(block) and is_block_on_platform(block):
			result += 1
	return result

func confirm_platform_empty() -> void:
	clear_pending = false
	if state in [GameState.CLEAR, GameState.FAIL]: return
	var actual_blocks_on_platform: int = count_blocks_on_platform()
	blocks_left = actual_blocks_on_platform
	update_hud()
	if actual_blocks_on_platform == 0:
		clear_stage()
	elif moves > 0:
		state = GameState.READY
		hint_label.text = "남은 블록을 향해 다시 발사하세요"
	else:
		fail_stage()

func finish_check() -> void:
	if state in [GameState.CLEAR, GameState.FAIL]: return
	if state == GameState.PROJECTILE_ACTIVE: return
	blocks_left = count_blocks_on_platform()
	update_hud()
	if blocks_left <= 0:
		if not clear_pending:
			clear_pending = true
			get_tree().create_timer(0.5).timeout.connect(confirm_platform_empty)
	elif moves <= 0: fail_stage()
	else:
		state = GameState.READY
		hint_label.text = "화면을 터치해 다시 발사하세요"

func clear_stage() -> void:
	if state == GameState.CLEAR: return
	state = GameState.CLEAR
	score += moves * 500
	var stars := 3 if moves >= 3 else (2 if moves >= 1 else 1)
	overlay_title.text = "STAGE CLEAR!"
	overlay_body.text = "★".repeat(stars) + "☆".repeat(3 - stars) + "\n점수 %d\n남은 발사 +%d" % [score, moves]
	overlay_button.text = "다음 스테이지"
	overlay.visible = true

func fail_stage() -> void:
	state = GameState.FAIL
	overlay_title.text = "한 번 더!"
	overlay_body.text = "블록 %d개가 판 위에 남았어요\n조금 아래를 노려보세요" % blocks_left
	overlay_button.text = "다시 도전"
	overlay.visible = true

func on_overlay_button() -> void:
	if state == GameState.PAUSED:
		toggle_pause()
		return
	load_level(level + 1 if state == GameState.CLEAR else level)

func toggle_pause() -> void:
	if state == GameState.PAUSED:
		get_tree().paused = false
		state = state_before_pause
		overlay.visible = false
	else:
		state_before_pause = state
		get_tree().paused = true
		state = GameState.PAUSED
		overlay_title.text = "일시정지"
		overlay_body.text = "잠깐 쉬어가도 좋아요"
		overlay_button.text = "계속하기"
		overlay.visible = true

func _input(event: InputEvent) -> void:
	if state not in [GameState.READY, GameState.AIMING, GameState.PROJECTILE_ACTIVE, GameState.CHECKING]: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_tower_point(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		select_tower_point(event.position)

func select_tower_point(screen_position: Vector2) -> void:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var ray_end := ray_origin + ray_direction * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		fire_at(hit["position"])
		return
	# Sky taps still produce a shot: project the tap onto the tower's depth plane.
	var target := ray_origin + ray_direction * 18.0
	if abs(ray_direction.z) > 0.001:
		var distance_to_tower_plane := (-1.0 - ray_origin.z) / ray_direction.z
		if distance_to_tower_plane > 0.0:
			target = ray_origin + ray_direction * distance_to_tower_plane
	fire_at(target)

func update_cannon() -> void:
	if not cannon_pivot: return
	cannon_pivot.rotation.y = cannon_yaw
	barrel_pivot.rotation.x = -cannon_pitch

func shot_direction() -> Vector3:
	return Vector3(-sin(cannon_yaw) * cos(cannon_pitch), sin(cannon_pitch), -cos(cannon_yaw) * cos(cannon_pitch)).normalized()

func ballistic_velocity(origin: Vector3, target: Vector3, speed: float) -> Vector3:
	var offset := target - origin
	var flat := Vector3(offset.x, 0, offset.z)
	var distance := flat.length()
	if distance < 0.01:
		return Vector3.ZERO
	var gravity := 12.0
	var speed_sq := speed * speed
	var discriminant := speed_sq * speed_sq - gravity * (gravity * distance * distance + 2.0 * offset.y * speed_sq)
	if discriminant < 0.0:
		return offset.normalized() * speed
	var tangent := (speed_sq - sqrt(discriminant)) / (gravity * distance)
	var horizontal_speed := speed / sqrt(1.0 + tangent * tangent)
	return flat.normalized() * horizontal_speed + Vector3.UP * horizontal_speed * tangent

func update_hud() -> void:
	if not moves_label: return
	moves_label.text = "발사 %d" % moves
	target_label.text = "블록 %d" % max(blocks_left, 0)
	level_label.text = "LEVEL %d" % (level + 1)

func make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func panel_style(color: Color, radius: int, border := 0, border_color := Color.WHITE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius; style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius; style.corner_radius_bottom_right = radius
	style.border_width_left = border; style.border_width_right = border
	style.border_width_top = border; style.border_width_bottom = border
	style.border_color = border_color
	return style

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .72
	return mat

func transparent_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = .18
	mat.metallic = .08
	return mat

func mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new()
	mesh.size = size; mesh.material = material(color); node.mesh = mesh; return node

func mesh_transparent_box(size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new()
	mesh.size = size; mesh.material = transparent_material(color); node.mesh = mesh; return node

func mesh_cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = 20; mesh.material = material(color); node.mesh = mesh; return node

func mesh_transparent_cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = 20; mesh.material = transparent_material(color); node.mesh = mesh; return node

func mesh_sphere(radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := SphereMesh.new()
	mesh.radius = radius; mesh.height = radius * 2.0; mesh.material = material(color); node.mesh = mesh; return node

func shape_box(size: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size = size; node.shape = shape; return node

func shape_cylinder(radius: float, height: float) -> CollisionShape3D:
	var node := CollisionShape3D.new(); var shape := CylinderShape3D.new()
	shape.radius = radius; shape.height = height; node.shape = shape; return node

func shape_sphere(radius: float) -> CollisionShape3D:
	var node := CollisionShape3D.new(); var shape := SphereShape3D.new()
	shape.radius = radius; node.shape = shape; return node
