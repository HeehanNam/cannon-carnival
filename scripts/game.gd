extends Node3D

enum GameState { READY, AIMING, PROJECTILE_ACTIVE, CHECKING, CLEAR, FAIL, PAUSED }

const MOVE_LIMITS := [7, 6, 5]
const STAGE_NAMES := ["첫 번째 탑", "쌍둥이 성", "회전 요새"]
const BLOCK_RED := Color("e62f43")
const BLOCK_DARK := Color("a8142b")
const CREAM := Color("fff0c2")
const BLOCK_SCRIPT := preload("res://scripts/physics_block.gd")

var state := GameState.READY
var level := 0
var moves := 7
var score := 0
var targets_left := 0
var projectile: RigidBody3D
var projectile_timer := 0.0
var cannon_yaw := 0.0
var cannon_pitch := deg_to_rad(14.0)
var stage_root: Node3D
var cannon_pivot: Node3D
var barrel_pivot: Node3D
var camera: Camera3D
var platform: AnimatableBody3D
var platform_angle := 0.0
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

func _ready() -> void:
	build_environment()
	build_ui()
	load_level(0)

func build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("37aef6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dff6ff")
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.position = Vector3(0, 7.2, 15.5)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	camera.fov = 47
	add_child(camera)

	# Sunny park ground.
	var ground := StaticBody3D.new()
	ground.position = Vector3(0, -1.0, 0)
	ground.add_child(mesh_box(Vector3(36, 0.5, 36), Color("62ba24")))
	ground.add_child(shape_box(Vector3(36, 0.5, 36)))
	add_child(ground)
	for i in range(18):
		var tree := Node3D.new()
		var angle := TAU * float(i) / 18.0
		tree.position = Vector3(cos(angle) * 10.5, 0, -2.5 + sin(angle) * 5.5)
		tree.add_child(mesh_cylinder(0.18, 1.0, Color("9b6028")))
		var crown := mesh_sphere(0.75, Color.from_hsv(0.28 + (i % 3) * .02, .72, .65 + (i % 2) * .12))
		crown.position.y = 1.0
		tree.add_child(crown)
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

	hint_label = make_label("쓰러뜨릴 블록을 선택하세요", 19, Color.WHITE)
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
	level = posmod(index, MOVE_LIMITS.size())
	for child in stage_root.get_children(): child.queue_free()
	moves = MOVE_LIMITS[level]
	score = 0
	targets_left = 0
	state = GameState.READY
	projectile = null
	overlay.visible = false
	cannon_yaw = 0.0
	cannon_pitch = deg_to_rad(14)
	update_cannon()

	platform = AnimatableBody3D.new()
	platform.position = Vector3(0, 0, -1.0)
	platform.add_child(mesh_box(Vector3(7.3, 0.55, 5.1), Color("623bc1")))
	platform.add_child(shape_box(Vector3(7.3, 0.55, 5.1)))
	stage_root.add_child(platform)
	var trim := mesh_box(Vector3(7.45, .17, 5.25), Color("ffca22"))
	trim.position.y = .35
	platform.add_child(trim)

	if level == 0: build_tower(Vector3.ZERO, 3, 3)
	elif level == 1:
		build_tower(Vector3(-1.7, 0, 0), 2, 3)
		build_tower(Vector3(1.7, 0, 0), 2, 3)
		add_block(Vector3(0, 3.75, 0), Vector3(3.6, .55, .75), true, false)
	else:
		build_fortress()
	update_hud()
	hint_label.text = STAGE_NAMES[level] + " · 타워를 터치하세요"

func build_tower(offset: Vector3, columns: int, rows: int) -> void:
	for y in range(rows):
		for x in range(columns):
			var px := (x - (columns - 1) * .5) * 1.18
			var target := y == rows - 1 or (y == 1 and x == columns / 2)
			add_block(offset + Vector3(px, .65 + y * 1.12, 0), Vector3(.82, 1.0, .82), target, (x + y) % 4 == 0)

func build_fortress() -> void:
	for x in [-2.25, -1.12, 0.0, 1.12, 2.25]: add_block(Vector3(x, .65, 0), Vector3(.82, 1.0, .82), x == 0, false)
	for x in [-2.0, 0.0, 2.0]: add_block(Vector3(x, 1.8, 0), Vector3(.9, 1.0, .9), true, x != 0)
	add_block(Vector3(-1.0, 2.85, 0), Vector3(2.7, .45, .75), false, false)
	add_block(Vector3(1.0, 2.85, 0), Vector3(2.7, .45, .75), false, false)
	add_block(Vector3(0, 3.7, 0), Vector3(.9, 1.0, .9), true, false)

func add_block(pos: Vector3, size: Vector3, is_target: bool, heavy: bool) -> void:
	var body := RigidBody3D.new()
	body.set_script(BLOCK_SCRIPT)
	body.position = pos + Vector3(0, 0, -1.0)
	body.mass = 2.6 if heavy else 1.0
	body.set_meta("target", is_target)
	body.set_meta("counted", false)
	body.set_meta("value", 200 if is_target else 100)
	body.add_to_group("blocks")
	var color := Color("702f9e") if heavy else BLOCK_RED
	body.add_child(mesh_cylinder(size.x * .5, size.y, color))
	body.add_child(shape_cylinder(size.x * .5, size.y))
	var stripe := mesh_cylinder(size.x * .515, size.y * .13, CREAM)
	stripe.position.y = size.y * .17
	body.add_child(stripe)
	var stripe2 := mesh_cylinder(size.x * .515, size.y * .10, CREAM)
	stripe2.position.y = -size.y * .28
	body.add_child(stripe2)
	if is_target:
		var crown := mesh_sphere(size.x * .2, Color("ffd62f"))
		crown.scale.y = .45
		crown.position = Vector3(0, size.y * .54, 0)
		body.add_child(crown)
		targets_left += 1
	stage_root.add_child(body)

func fire_at(target: Vector3) -> void:
	if state not in [GameState.READY, GameState.AIMING] or moves <= 0: return
	var origin := cannon_pivot.position + Vector3.UP * .7
	var launch_velocity := ballistic_velocity(origin, target, 19.0)
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
	projectile.position = origin + launch_velocity.normalized() * 2.8
	projectile.add_child(mesh_sphere(.42, Color("192237")))
	projectile.add_child(shape_sphere(.42))
	projectile.linear_velocity = launch_velocity
	projectile.contact_monitor = true
	projectile.max_contacts_reported = 8
	projectile.body_entered.connect(on_projectile_hit)
	add_child(projectile)
	shake_amount = .18
	flash.color.a = .4
	update_hud()
	hint_label.text = "선택한 지점으로 발사했습니다"

func on_projectile_hit(body: Node) -> void:
	shake_amount = max(shake_amount, .24)
	flash.color.a = .22
	if body.has_method("activate_physics"):
		var impulse := projectile.linear_velocity.normalized() * 10.5 if is_instance_valid(projectile) else Vector3.ZERO
		body.activate_physics(impulse)

func _physics_process(delta: float) -> void:
	if state == GameState.PAUSED: return
	if level == 2 and platform and is_instance_valid(platform):
		platform_angle += delta * .26
		platform.rotation.y = platform_angle
	check_dropped_blocks()
	if projectile and is_instance_valid(projectile):
		projectile_timer += delta
		if state == GameState.PROJECTILE_ACTIVE and (projectile_timer > 5.5 or projectile.position.y < -3.0 or projectile.linear_velocity.length() < .18 and projectile_timer > 2.0):
			state = GameState.CHECKING
			get_tree().create_timer(1.0).timeout.connect(finish_check)
	if flash.color.a > 0: flash.color.a = move_toward(flash.color.a, 0.0, delta * 1.8)
	if shake_amount > 0:
		camera.h_offset = randf_range(-shake_amount, shake_amount)
		camera.v_offset = randf_range(-shake_amount, shake_amount)
		shake_amount = move_toward(shake_amount, 0.0, delta * .8)
	else:
		camera.h_offset = 0; camera.v_offset = 0

func check_dropped_blocks() -> void:
	for body in get_tree().get_nodes_in_group("blocks"):
		if not is_instance_valid(body) or body.get_meta("counted", false): continue
		if body.position.y < -0.65 or abs(body.position.x) > 4.2 or body.position.z > 2.2 or body.position.z < -4.2:
			body.set_meta("counted", true)
			score += int(body.get_meta("value", 100))
			if body.get_meta("target", false): targets_left -= 1
			update_hud()
			if targets_left <= 0: clear_stage()

func finish_check() -> void:
	if state in [GameState.CLEAR, GameState.FAIL]: return
	if targets_left <= 0: clear_stage()
	elif moves <= 0: fail_stage()
	else:
		state = GameState.READY
		hint_label.text = "남은 타깃 블록을 선택하세요"

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
	overlay_body.text = "타깃 %d개가 남았어요\n조금 아래를 노려보세요" % targets_left
	overlay_button.text = "다시 도전"
	overlay.visible = true

func on_overlay_button() -> void:
	load_level(level + 1 if state == GameState.CLEAR else level)

func toggle_pause() -> void:
	if state == GameState.PAUSED:
		get_tree().paused = false
		state = GameState.READY
		overlay.visible = false
	else:
		get_tree().paused = true
		state = GameState.PAUSED
		overlay_title.text = "일시정지"
		overlay_body.text = "잠깐 쉬어가도 좋아요"
		overlay_button.text = "계속하기"
		overlay.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if state not in [GameState.READY, GameState.AIMING]: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select_tower_point(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		select_tower_point(event.position)

func select_tower_point(screen_position: Vector2) -> void:
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider is Node and (collider as Node).is_in_group("blocks"):
		fire_at(hit["position"])
	else:
		hint_label.text = "타워 블록을 정확히 선택하세요"

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
	target_label.text = "타깃 %d" % max(targets_left, 0)
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

func mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new()
	mesh.size = size; mesh.material = material(color); node.mesh = mesh; return node

func mesh_cylinder(radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	mesh.radial_segments = 20; mesh.material = material(color); node.mesh = mesh; return node

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
