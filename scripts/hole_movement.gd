class_name HoleMovement
extends RefCounted
## Port of HoleMoveImprovementsService.CalculateVelocity + state machine.
enum MoveState { STOPPED, MOVING, DECELERATING }
enum SpeedState { NONE, WALKING, RUNNING }

var config: HoleMoveConfig
var move_state := MoveState.STOPPED
var speed_state := SpeedState.NONE
var _last_desired := Vector3.ZERO
var _quick_turn_timer := 0.0
var quick_turn_count := 0

func _init(cfg: HoleMoveConfig) -> void:
	config = cfg

func ramp(mag: float) -> float:
	if config.joystick_ramp:
		return clampf(config.joystick_ramp.sample(clampf(mag, 0.0, 1.0)), 0.0, 1.0)
	return clampf(mag, 0.0, 1.0)

## Returns the new horizontal velocity.
func calculate_velocity(current: Vector3, desired_dir: Vector3, input_mag: float, top_speed: float, delta: float) -> Vector3:
	desired_dir.y = 0.0
	var mag := ramp(input_mag)
	_update_state(desired_dir, mag, delta)
	if mag <= 0.001 or desired_dir.length_squared() < 0.0001:
		var dec := config.deceleration * delta
		return current.move_toward(Vector3.ZERO, dec)
	var dir := desired_dir.normalized()
	var target := dir * top_speed * mag
	var acc := config.acceleration
	if config.turning_curve and current.length() > 0.01:
		var d := current.normalized().dot(dir)
		acc *= maxf(config.turning_curve.sample((d + 1.0) * 0.5), 0.01)
	return current.move_toward(target, acc * delta)

func _update_state(desired_dir: Vector3, mag: float, delta: float) -> void:
	_quick_turn_timer = maxf(_quick_turn_timer - delta, 0.0)
	if mag <= 0.001:
		move_state = MoveState.DECELERATING if move_state == MoveState.MOVING else MoveState.STOPPED
		speed_state = SpeedState.NONE
		return
	move_state = MoveState.MOVING
	speed_state = SpeedState.RUNNING if mag >= config.walking_running_threshold else SpeedState.WALKING
	var d := desired_dir.normalized()
	if _last_desired.length_squared() > 0.0 and _last_desired.dot(d) < config.quick_turn_dot and _quick_turn_timer <= 0.0:
		quick_turn_count += 1
		_quick_turn_timer = config.quick_turn_cooldown
	_last_desired = d
