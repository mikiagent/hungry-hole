class_name CameraCurves
extends Resource
## Legacy CameraSettingsData sampled by hole size (same unit as BalanceTable.size).
@export var distance_keys: PackedVector2Array = [Vector2(1, 10), Vector2(1.2, 10), Vector2(2, 19.85), Vector2(4, 19.85), Vector2(14, 50), Vector2(36, 156.2), Vector2(40, 156.2), Vector2(150.8, 436.6), Vector2(210.2, 511.9), Vector2(240, 495)]
@export var angle_keys: PackedVector2Array = [Vector2(1, 40.91), Vector2(2, 40.91), Vector2(4, 49.09), Vector2(14, 53.13), Vector2(36, 50.19), Vector2(40, 50.19), Vector2(240, 50)]
@export var fov_keys: PackedVector2Array = [Vector2(1, 60), Vector2(2, 60), Vector2(4, 70), Vector2(36, 50), Vector2(240, 50)]
@export var smooth_time: float = 0.25
@export var map_rotation_deg: float = 45.0

static func sample(keys: PackedVector2Array, x: float) -> float:
	if keys.is_empty():
		return 0.0
	if x <= keys[0].x:
		return keys[0].y
	for i in range(1, keys.size()):
		if x <= keys[i].x:
			var a := keys[i - 1]
			var b := keys[i]
			var t := (x - a.x) / maxf(b.x - a.x, 0.0001)
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, t))
	return keys[keys.size() - 1].y

func distance_for(size: float) -> float: return sample(distance_keys, size)
func angle_for(size: float) -> float: return sample(angle_keys, size)
func fov_for(size: float) -> float: return sample(fov_keys, size)
