class_name BotController
extends Node
## Port of BotHoleController + BotTargetFinder (strategies), with BR aggression ramp optional.
@export var profile: BotProfile
var hole: Hole
var match_ref
var target: Node3D = null
var target_is_hole := false
var _target_timer := 0.0
var _change_cooldown := 0.0
var _wait_timer := 0.0
var _decision_accum := 0.0
var _waypoint := Vector3.ZERO
var _has_waypoint := false
var _elapsed := 0.0
const DECISION_INTERVAL := 0.1   # BotServiceConfig.m_decisionIntervalMs
const TARGET_REACHED := 0.1       # BotHoleController.TargetReachedDistance
const WAYPOINT_MIN := 10.0
const WAYPOINT_MAX := 200.0

func setup(h: Hole, m, p: BotProfile) -> void:
	hole = h; match_ref = m; profile = p if p else BotProfile.normal()
	if profile.starting_size > 1:
		hole.set_level(profile.starting_size, true)

func _physics_process(delta: float) -> void:
	if hole == null or hole.is_dead or match_ref == null or not match_ref.playing:
		if hole: hole.input_mag = 0.0
		return
	_elapsed += delta
	_decision_accum += delta
	_change_cooldown = maxf(_change_cooldown - delta, 0.0)
	_target_timer -= delta
	if _decision_accum >= DECISION_INTERVAL:
		_decision_accum = 0.0
		_decide()
	_steer(delta)

func aggressivity() -> float:
	if profile.aggression_ramp_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed / profile.aggression_ramp_seconds, 0.0, 1.0)

func _decide() -> void:
	# 1. danger: bigger holes nearby → escape
	var danger := _closest_dangerous_hole()
	if danger != null:
		var away: Vector3 = (hole.global_position - danger.global_position)
		away.y = 0.0
		_waypoint = hole.global_position + away.normalized() * profile.escape_distance
		_has_waypoint = true
		target = null
		return
	# 2. keep a valid target while timers allow
	if target != null and (not is_instance_valid(target) or target.is_queued_for_deletion()):
		target = null
	if target != null and _target_timer > 0.0:
		if target is FallingObject and ((target as FallingObject).captured_by != null or (target as FallingObject).size_required > hole.level):
			target = null
		elif target is Hole and ((target as Hole).is_dead or (target as Hole).level >= hole.level):
			target = null
		else:
			return
	if _change_cooldown > 0.0 and target != null and is_instance_valid(target):
		return
	# 3. aggression: chase a vulnerable (smaller) hole: always if it's close, otherwise with a probability that ramps up
	var victim := _closest_vulnerable_hole()
	var close_prey: bool = victim != null and profile.hunt_radius > 0.0 and hole.global_position.distance_to(victim.global_position) < profile.hunt_radius + hole.radius()
	if victim != null and (close_prey or (aggressivity() > 0.0 and randf() < aggressivity())):
		if true:
			target = victim; target_is_hole = true
			_target_timer = randf_range(profile.hole_chase_duration.x, profile.hole_chase_duration.y)
			_change_cooldown = profile.target_change_cooldown
			return
	# 4. objects by strategy
	var obj := _pick_object()
	if obj != null:
		target = obj; target_is_hole = false; _has_waypoint = false
		_target_timer = randf_range(profile.sudden_target_change_interval.x, profile.sudden_target_change_interval.y)
		_change_cooldown = profile.target_change_cooldown
	else:
		target = null
		_waypoint = BotController.random_waypoint(hole.global_position, match_ref.map_bounds)
		_has_waypoint = true

static func random_waypoint(from: Vector3, bounds: Rect2) -> Vector3:
	var ang := randf() * TAU
	var dist := randf_range(WAYPOINT_MIN, WAYPOINT_MAX)
	var p := from + Vector3(cos(ang), 0, sin(ang)) * dist
	p.x = clampf(p.x, bounds.position.x + 3.0, bounds.end.x - 3.0)
	p.z = clampf(p.z, bounds.position.y + 3.0, bounds.end.y - 3.0)
	return p

func _roll_strategy() -> int:
	var r := randf() * (profile.select_closest_chance + profile.select_furthest_chance + profile.select_random_chance)
	if r < profile.select_closest_chance: return 0
	if r < profile.select_closest_chance + profile.select_furthest_chance: return 1
	return 2

func _pick_object() -> FallingObject:
	var strat := _roll_strategy()
	var best: FallingObject = null
	var best_d := INF if strat == 0 else -INF
	var candidates: Array = []
	var maxd2 := profile.max_target_distance * profile.max_target_distance
	for o in match_ref.eatables_snapshot():
		if not is_instance_valid(o) or o.is_queued_for_deletion() or o.captured_by != null or o.size_required > hole.level or o.only_for_player or o.is_falling:
			continue
		var d2: float = hole.global_position.distance_squared_to(o.global_position)
		if d2 > maxd2: continue
		if strat == 2:
			candidates.append(o)
		elif strat == 0:
			var score := d2 if profile.value_seeking <= 0.0 else -float(o.points) * profile.value_seeking / (sqrt(d2) + 6.0)
			if score < best_d: best_d = score; best = o
		elif strat == 1 and d2 > best_d:
			best_d = d2; best = o
	if strat == 2 and not candidates.is_empty():
		return candidates[randi() % candidates.size()]
	return best

func _closest_dangerous_hole() -> Hole:
	var best: Hole = null; var bd := INF
	for h in match_ref.holes:
		if h == hole or h.is_dead or h.level < hole.level: continue
		var lim := profile.escape_bot_if_closer_than if h.is_bot else profile.escape_player_if_closer_than
		if lim <= 0.0: continue
		var d: float = hole.global_position.distance_to(h.global_position) - h.radius()
		if d < lim and d < bd:
			bd = d; best = h
	return best

func _closest_vulnerable_hole() -> Hole:
	var best: Hole = null; var bd := INF
	var hunters := 0
	for b in match_ref.bots:
		if b != self and is_instance_valid(b.target) and b.target is Hole and not (b.target as Hole).is_bot: hunters += 1
	for h in match_ref.holes:
		if h == hole or h.is_dead or h.level >= hole.level: continue
		if not h.is_bot and hunters >= profile.max_player_hunters: continue
		var d: float = hole.global_position.distance_to(h.global_position)
		if d < bd: bd = d; best = h
	return best

func _steer(_delta: float) -> void:
	var goal: Vector3
	if target != null and is_instance_valid(target):
		goal = target.global_position
	elif _has_waypoint:
		goal = _waypoint
	else:
		hole.input_mag = 0.0
		return
	var to: Vector3 = goal - hole.global_position
	to.y = 0.0
	if to.length() <= TARGET_REACHED + hole.radius() * 0.3:
		hole.input_mag = 0.0
		if _has_waypoint: _has_waypoint = false
		_target_timer = minf(_target_timer, profile.delay_after_reaching_target)
		return
	hole.desired_dir = to.normalized()
	var k := 0.0 if profile.aggression_ramp_seconds <= 0 else aggressivity()
	hole.speed_multiplier = lerpf(profile.initial_speed_multiplier, profile.final_speed_multiplier, k)
	hole.input_mag = 1.0
