class_name CameraRig
extends Node3D
## Follows a hole; distance/pitch/FOV from CameraCurves by hole size; yaw 45° (+ random quarter turn).
@export var curves: CameraCurves
var target: Hole
var yaw_deg := 45.0
var _dist := 10.0
var _pitch := 41.0
var _fov := 60.0
@onready var cam: Camera3D = $Camera3D

func _ready() -> void:
	if curves == null: curves = CameraCurves.new()
	yaw_deg = curves.map_rotation_deg + [0.0, 90.0, 180.0, 270.0].pick_random()

func snap() -> void:
	if target == null: return
	_dist = curves.distance_for(target.size); _pitch = curves.angle_for(target.size); _fov = curves.fov_for(target.size)
	global_position = target.global_position
	_apply()

func _process(delta: float) -> void:
	if target == null: return
	var k := 1.0 - exp(-delta / maxf(curves.smooth_time, 0.01))
	_dist = lerpf(_dist, curves.distance_for(target.size), k)
	_pitch = lerpf(_pitch, curves.angle_for(target.size), k)
	_fov = lerpf(_fov, curves.fov_for(target.size), k)
	# physics interpolation is on: read the smoothed transform, not the raw 60 Hz physics position (that caused the jumping)
	var tp := target.get_global_transform_interpolated().origin
	global_position = global_position.lerp(tp, 1.0 - exp(-delta / 0.08))
	_apply()

func _apply() -> void:
	rotation_degrees = Vector3(0, yaw_deg, 0)
	cam.position = Vector3(0, sin(deg_to_rad(_pitch)) * _dist, cos(deg_to_rad(_pitch)) * _dist)
	cam.look_at(global_position + Vector3(0, 0.5, 0), Vector3.UP)
	cam.fov = _fov
