class_name Movable
extends Node
## Traffic and pedestrians: moves a frozen FallingObject along a lane; people flee nearby holes (FleeingConfig).
enum Kind { CAR, PERSON }
var kind := Kind.CAR
var dir := Vector3.FORWARD
var speed := 8.0
var bounds := Rect2()
var match_ref
static var current_match = null
var _flee_timer := 0.0
var _wander_timer := 0.0
const FLEE_TRIGGER_DIST := 6.0      # FleeingConfig: trigger when a hole is near (sizes 1.1–1.7× in the original)
const FLEE_SPEEDS := [6.0, 5.0, 4.5, 4.0]
const WALK_SPEED := 1.2
const RETURN_TIME := 2.0

func _physics_process(delta: float) -> void:
	var fo := get_parent() as FallingObject
	if fo == null or fo.is_falling or fo.captured_by != null or not fo.freeze:
		return
	if match_ref == null: match_ref = Movable.current_match
	if match_ref == null or not match_ref.playing:
		return
	var v := speed
	if kind == Kind.PERSON:
		_flee_timer = maxf(_flee_timer - delta, 0.0)
		_wander_timer -= delta
		if _flee_timer <= 0.0:
			var threat := _nearest_hole(fo.global_position)
			if threat != null and fo.global_position.distance_to(threat.global_position) < FLEE_TRIGGER_DIST + threat.radius():
				var away := fo.global_position - threat.global_position; away.y = 0.0
				dir = away.normalized(); speed = FLEE_SPEEDS[randi() % FLEE_SPEEDS.size()]; _flee_timer = RETURN_TIME
				fo.is_fleeing = true
			elif _wander_timer <= 0.0:
				_wander_timer = randf_range(2.0, 5.0)
				dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(); speed = WALK_SPEED if randf() < 0.7 else 0.0
				fo.is_fleeing = false
		v = speed
	bounds = match_ref.map_bounds
	var p := fo.global_position + dir * v * delta
	# keep inside walls; cars wrap to the other side of their lane, people bounce
	if p.x < bounds.position.x + 2 or p.x > bounds.end.x - 2 or p.z < bounds.position.y + 2 or p.z > bounds.end.y - 2:
		if kind == Kind.CAR:
			if absf(dir.x) > 0.5: p.x = bounds.end.x - 3 if dir.x < 0 else bounds.position.x + 3
			else: p.z = bounds.end.y - 3 if dir.z < 0 else bounds.position.y + 3
		else:
			dir = -dir; p = fo.global_position
	fo.global_position = p
	if v > 0.01:
		fo.rotation.y = atan2(dir.x, dir.z) + (fo.get_meta("yaw_offset", 0.0))

func _nearest_hole(pos: Vector3) -> Hole:
	var best: Hole = null; var bd := INF
	for h in match_ref.holes:
		if h.is_dead: continue
		var d := pos.distance_to(h.global_position)
		if d < bd: bd = d; best = h
	return best
