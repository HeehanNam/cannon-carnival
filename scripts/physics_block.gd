extends RigidBody3D

var activated := false

func _ready() -> void:
	# Towers remain perfectly still until a real impact reaches them.
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)

func activate_physics(impulse := Vector3.ZERO) -> void:
	if not activated:
		activated = true
		freeze = false
		sleeping = false
	if impulse.length_squared() > 0.001:
		apply_central_impulse(impulse)

func _on_body_entered(body: Node) -> void:
	if not activated or not body.has_method("activate_physics"):
		return
	# Pass only a portion of this block's momentum to touching frozen blocks.
	var transmitted := linear_velocity * mass * 0.32
	body.activate_physics(transmitted)

