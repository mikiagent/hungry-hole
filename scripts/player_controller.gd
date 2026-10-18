class_name PlayerController
extends Node
## Touch/mouse drag virtual joystick + keyboard/gamepad → hole.desired_dir / input_mag.
var hole: Hole
var camera_yaw := 45.0
var _dragging := false
var _origin := Vector2.ZERO
var joystick_radius_px := 160.0  # JoystickConfig.movementRange-like
var enabled := true
signal joystick_changed(active: bool, origin: Vector2, current: Vector2)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed:
			_dragging = true; _origin = pos
			joystick_changed.emit(true, _origin, pos)
		else:
			_dragging = false
			joystick_changed.emit(false, _origin, pos)
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var pos: Vector2 = event.position
		var v := (pos - _origin)
		var mag := clampf(v.length() / joystick_radius_px, 0.0, 1.0)
		if v.length() > 0.001:
			_apply(Vector2(v.x, v.y).normalized(), mag)
		joystick_changed.emit(true, _origin, pos)

func _process(_delta: float) -> void:
	if hole == null or not enabled: return
	var kv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if kv.length() > 0.01:
		_apply(kv.normalized(), clampf(kv.length(), 0.0, 1.0))
	elif not _dragging:
		hole.input_mag = 0.0

func _apply(screen_dir: Vector2, mag: float) -> void:
	# screen up = away from camera; rotate by camera yaw so controls match the view
	var d := Vector3(screen_dir.x, 0.0, screen_dir.y).rotated(Vector3.UP, deg_to_rad(camera_yaw))
	hole.desired_dir = d.normalized()
	hole.input_mag = mag
