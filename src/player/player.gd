class_name BuilderPlayer
extends CharacterBody3D

signal flight_changed(enabled: bool)

const DOUBLE_TAP_WINDOW_MSEC := 300
const SPRINT_MULTIPLIER := 1.8
const FLIGHT_ACCELERATION := 160.0
const FLIGHT_BRAKING := 80.0 # At normal flight speed, coast for about 0.2 s.

var game_mode := GameModeState.new()
var camera: Camera3D
var head: Node3D
var active := false:
	set(value):
		if active != value:
			active = value
			reset_jump_taps()
			reset_sprint_taps()
			if not active:
				velocity = Vector3.ZERO
var flying := false
var sensitivity := 0.0022
var walk_speed := 10.0
var gravity := 22.0
var _last_jump_press_msec := -1
var _jump_released := true
var sprinting := false
var _last_forward_press_msec := -1
var _forward_released := true

func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.75
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	head = Node3D.new()
	head.position.y = 0.72
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75
	camera.near = 0.08
	camera.far = 400
	head.add_child(camera)
	camera.current = true
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

func _unhandled_input(event: InputEvent) -> void:
	handle_jump_input(event)
	handle_sprint_input(event)
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensitivity
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sensitivity, -1.5, 1.5)

func reset_sprint_taps() -> void:
	sprinting = false
	_last_forward_press_msec = -1
	_forward_released = true

func handle_sprint_input(event: InputEvent, now_msec: int = -1) -> void:
	if not active or event.is_echo(): return
	if event.is_action_pressed("back"):
		reset_sprint_taps()
		return
	if not event.is_action("forward"): return
	if event.is_action_released("forward"):
		_forward_released = true
		sprinting = false
		return
	if not event.is_action_pressed("forward") or not _forward_released: return
	_forward_released = false
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	var interval := now-_last_forward_press_msec
	if _last_forward_press_msec >= 0 and interval >= 0 and interval <= DOUBLE_TAP_WINDOW_MSEC:
		sprinting = true
		_last_forward_press_msec = -1
	else:
		_last_forward_press_msec = now

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_sprint_taps()
		reset_jump_taps()
		velocity = Vector3.ZERO

func reset_jump_taps() -> void:
	_last_jump_press_msec = -1
	_jump_released = true

func handle_jump_input(event: InputEvent, now_msec: int = -1) -> void:
	if not active or not game_mode.allows_flight() or not event.is_action("jump") or event.is_echo():
		return
	if event.is_action_released("jump"):
		_jump_released = true
		return
	if not event.is_action_pressed("jump") or not _jump_released:
		return
	_jump_released = false
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	var interval := now - _last_jump_press_msec
	if _last_jump_press_msec >= 0 and interval >= 0 and interval <= DOUBLE_TAP_WINDOW_MSEC:
		toggle_flight()
		# The second press finishes this pair; require a release before the next tap.
		_jump_released = false
	else:
		_last_jump_press_msec = now

func set_flying(enabled: bool) -> void:
	var permitted := enabled and game_mode.allows_flight()
	reset_jump_taps()
	reset_sprint_taps()
	velocity = Vector3.ZERO
	if flying != permitted:
		flying = permitted
		flight_changed.emit(flying)

func toggle_flight() -> void:
	if game_mode.allows_flight():
		set_flying(not flying)

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		return
	if flying and not game_mode.allows_flight():
		set_flying(false)
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := (global_basis * Vector3(input.x, 0, input.y)).normalized()
	if sprinting and (not Input.is_action_pressed("forward") or Input.is_action_pressed("back")):
		reset_sprint_taps()
	var fast := sprinting or (not flying and Input.is_action_pressed("sprint"))
	var speed := walk_speed * (SPRINT_MULTIPLIER if fast else 1.0)
	if flying:
		# Fly horizontally with WASD even when looking down at a building.
		direction.y = float(Input.is_action_pressed("jump")) - float(Input.is_action_pressed("descend"))
		var target_velocity := direction.limit_length() * speed * 1.6
		var acceleration := FLIGHT_BRAKING if direction.is_zero_approx() else FLIGHT_ACCELERATION
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, delta * 70)
		velocity.z = move_toward(velocity.z, direction.z * speed, delta * 70)
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = 8.0
		else:
			velocity.y = -0.1
		# A short upward probe makes the low temple steps comfortable to climb.
		if is_on_floor() and input.length() > 0.1 and test_move(global_transform, direction * speed * delta):
			var raised := global_transform
			raised.origin.y += 0.26
			if not test_move(raised, direction * 0.35) and not test_move(global_transform, Vector3.UP * 0.26):
				global_position.y += 0.26
	move_and_slide()
	position.x = clampf(position.x, -62, 62)
	position.z = clampf(position.z, -62, 62)
	if flying:
		position.y = clampf(position.y, 1.0, 38)
		# A sanctuary boundary stops momentum just like a physical wall.
		if absf(position.x) >= 62: velocity.x = 0
		if absf(position.z) >= 62: velocity.z = 0
		if position.y <= 1 or position.y >= 38: velocity.y = 0
	if position.y < -8:
		position = Vector3(8, 2, 20)
		velocity = Vector3.ZERO

func look_at_point(point: Vector3) -> void:
	var direction := point - (global_position + Vector3.UP * 0.72)
	rotation.y = atan2(-direction.x, -direction.z)
	head.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())

func serialize() -> Dictionary:
	return {"position": [position.x, position.y, position.z], "yaw": rotation.y, "pitch": head.rotation.x, "flying": flying}

func restore(data: Dictionary) -> void:
	if WorldStore.valid_vector(data.get("position")):
		var p: Array = data.position
		position = Vector3(clampf(p[0], -62, 62), clampf(p[1], 0.95, 38), clampf(p[2], -62, 62))
	for key in ["yaw", "pitch"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			data[key] = 0.0
	rotation.y = data.get("yaw", 0.0)
	head.rotation.x = clampf(data.get("pitch", 0.0), -1.5, 1.5)
	set_flying(data.get("flying", false) == true)
