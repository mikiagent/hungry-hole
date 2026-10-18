class_name FallingObject
extends RigidBody3D
## Eatable object: frozen until an eligible hole's trigger touches it, then falls through the hole floor and is captured below.
enum ObjectType { INANIMATE, PEOPLE, VEHICLE, BUILDING, ANIMAL }
@export var size_required: int = 1
@export var points: int = 1
@export var object_type: ObjectType = ObjectType.INANIMATE
@export var only_for_player: bool = false
@export var height: float = 1.0
@export var tiers: ObjectPhysicsTiers

var captured_by = null
var stack_above: FallingObject = null  # FallingObjectsStack: segment resting on this one
var falling_for = null
var is_falling := false
var is_fleeing := false
var fall_started_at := 0.0
var spit_count := 0
var no_eat_until := 0.0
var footprint_half := 0.5   # half the largest horizontal extent, set by the generator
var tipping_for = null   # hole whose opening undercuts us while we are too big to be eaten
var _flash_tween: Tween
var _settle_t := 0.0
static var _phys_mat: PhysicsMaterial
var _original_colors := {}

func _ready() -> void:
	if tiers == null:
		tiers = ObjectPhysicsTiers.new()
	mass = tiers.mass_for(size_required)
	linear_damp = tiers.linear_damp_for(size_required)
	angular_damp = tiers.angular_damp_for(size_required)
	collision_layer = 1 << 1
	collision_mask = 1 << 0 | 1 << 1 | 1 << 2  # ground, objects, walls
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	set_physics_process(false)   # idle objects cost nothing per tick; enabled while falling or tipping
	can_sleep = true
	continuous_cd = false
	if _phys_mat == null:
		_phys_mat = PhysicsMaterial.new(); _phys_mat.bounce = 0.0; _phys_mat.friction = 0.9; _phys_mat.absorbent = true
	physics_material_override = _phys_mat

## Captured once the whole object is this far below the ground (deeper than the original's 1-5 u so the fall reads clearly).
const CAPTURE_EXTRA_DEPTH := 4.0

func _physics_process(_delta: float) -> void:
	# safety net: anything not being eaten that sank into the ground is lifted just enough to sit on it
	if captured_by == null and not is_falling and not freeze and tipping_for == null and lowest_point() < -0.3:
		_restore_ground()
	if tipping_for != null and (not is_instance_valid(tipping_for) or tipping_for.is_dead):
		_restore_ground()
	elif tipping_for != null:
		_undercut_torque()
	elif captured_by == null and not is_falling and not freeze:
		_settle(_delta)
	if is_falling and captured_by == null and falling_for != null and is_instance_valid(falling_for):
		if global_position.y < -(height * 0.5 + CAPTURE_EXTRA_DEPTH + falling_for.radius() * 0.25):
			capture(falling_for)

## Too big for this hole: become a real rigid body standing on the real ground. The part of its footprint over
## the opening has lost its foundation, modelled as a torque toward the clipped corner. It pivots on its
## hole-side edge and falls over onto the ground; it never sinks into the opening (it does not fit).
## The torque beats the righting moment (weight x half-width) plus a share that grows with the undercut.
const UNDERCUT_MIN := 0.12
const UNDERCUT_STRENGTH := 0.9
func _undercut_torque() -> void:
	var h = tipping_for
	var to: Vector3 = h.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.01: return
	var undercut := clampf((h.radius() - (d - footprint_half)) / (2.0 * footprint_half), 0.0, 1.0)
	if undercut <= 0.0 and lowest_point() > -0.05:
		_restore_ground()   # nothing over the opening any more: the rim and the ground are the same height, swap seamlessly
		return
	# stop pushing once the centre of mass is past the pivot edge: gravity finishes the fall, so it lands without slamming
	var past_pivot := atan2(footprint_half / 0.9, maxf(height, 1.0) * 0.5) + 0.15
	if undercut < UNDERCUT_MIN or tilt() > minf(past_pivot, TOPPLED_TILT): return
	# tip toward the footprint corner that is over the opening (the clipped corner), not toward the hole's centre
	var b := global_transform.basis
	var ex := Vector3(b.x.x, 0, b.x.z).normalized() * footprint_half
	var ez := Vector3(b.z.x, 0, b.z.z).normalized() * footprint_half
	var best := Vector3.ZERO; var best_d := INF
	for c in [ex + ez, ex - ez, -ex + ez, -ex - ez]:
		var cd: float = (global_position + c - h.global_position).length()
		if cd < best_d: best_d = cd; best = c
	var dir: Vector3 = best.normalized() if best_d < h.radius() else to / d
	var axis := Vector3.UP.cross(dir)
	var g := 80.0
	apply_torque(axis * mass * g * (footprint_half * 1.15 + undercut * maxf(height, 1.0) * 0.5 * UNDERCUT_STRENGTH))
	sleeping = false

const TOPPLED_TILT := 1.15   # ~65°: past this it is falling over by itself, stop pushing

## Angle between the object's up axis and world up.
func tilt() -> float:
	return global_transform.basis.y.normalized().angle_to(Vector3.UP)

## Lowest world-space point of the collision box (works for any orientation, standing or lying).
func lowest_point() -> float:
	var low := INF
	for c in get_children():
		var cs := c as CollisionShape3D
		if cs == null or not cs.shape is BoxShape3D: continue
		var e: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		var xf := cs.global_transform
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					low = minf(low, (xf * Vector3(e.x * sx, e.y * sy, e.z * sz)).y)
	return low if low < INF else global_position.y - height * 0.5

## Give a tipped object its ground back. If part of it sank into the opening, lift it only by that depth
## (never teleport to standing height: a toppled building lying on its side would be launched into the air).
func _restore_ground() -> void:
	tipping_for = null
	var low := lowest_point()
	if low < -0.02:
		global_position.y -= low - 0.02
		linear_velocity = Vector3(linear_velocity.x, 0.0, linear_velocity.z) * 0.5
		angular_velocity *= 0.5
	collision_mask = 1 << 0 | 1 << 1 | 1 << 2
	_settle_t = 0.0
	set_physics_process(not freeze)   # keep watching until it comes to rest, then freeze in place

## Become dynamic and report contacts, so a falling building knocks frozen neighbours loose (dominoes)
## instead of grinding against them as if they were immovable walls.
func _wake() -> void:
	set_physics_process(true)
	freeze = false
	sleeping = false
	_settle_t = 0.0
	contact_monitor = true
	max_contacts_reported = 4
	if not body_entered.is_connected(_on_body_hit):
		body_entered.connect(_on_body_hit)

func _on_body_hit(body: Node) -> void:
	var o := body as FallingObject
	if o == null or not o.freeze or o.captured_by != null or o.is_falling: return
	if linear_velocity.length() + angular_velocity.length() * height * 0.5 < 1.5: return   # only a real hit knocks things loose
	o._wake()

## Freeze an object once it has been at rest for a moment: no jitter, no per-tick cost.
func _settle(delta: float) -> void:
	if linear_velocity.length() < 0.3 and angular_velocity.length() < 0.3:
		_settle_t += delta
		if _settle_t > 0.8:
			freeze = true; continuous_cd = false; contact_monitor = false
			set_physics_process(false)
	else:
		_settle_t = 0.0

func start_tipping(hole) -> void:
	if captured_by != null or is_falling: return
	if tilt() > TOPPLED_TILT and lowest_point() > -0.05:
		return   # already lying on the ground beside the hole; leave it be
	tipping_for = hole
	_wake()
	continuous_cd = true
	angular_damp = 0.5
	# real ground, not the hole's moving rim: a moving collider under a resting building shoves it sideways
	collision_mask = 1 << 0 | 1 << 1 | 1 << 2
	# whatever is stacked on us has to come loose too, or it would hold us up in mid-air
	var s := stack_above
	while s != null and is_instance_valid(s) and s.freeze:
		s.freeze = false; s.sleeping = false
		s = s.stack_above

func start_falling(hole) -> void:
	if captured_by != null:
		return
	falling_for = hole
	tipping_for = null
	if is_falling:
		return
	is_falling = true
	set_physics_process(true)
	fall_started_at = Time.get_ticks_msec() / 1000.0
	freeze = false
	# the "layer trick": stop colliding with the flat ground and collide with this hole's rim instead,
	# so the object tips over the mouth edge (centre of mass over the opening) or rests on the lip (mostly outside)
	collision_mask = 1 << 1 | 1 << 2 | hole.rim_layer_bit
	sleeping = false
	# a light nudge toward the centre so things already over the edge commit to the fall
	var to_center: Vector3 = (hole.global_position - global_position)
	to_center.y = 0.0
	if to_center.length() > 0.01:
		apply_central_impulse(to_center.normalized() * mass * 0.6)
	AudioManager.play("fall", 0.2)
	if stack_above != null and is_instance_valid(stack_above) and stack_above.captured_by == null and hole.level >= stack_above.size_required:
		stack_above.call_deferred("start_falling", hole)

func left_hole(hole) -> void:
	if tipping_for == hole:
		_restore_ground()
	if falling_for == hole and global_position.y > -0.2 and captured_by == null:
		# still above ground: we slid out, go back to resting on the ground
		falling_for = null
		is_falling = false
		collision_mask = 1 << 0 | 1 << 1 | 1 << 2
		set_physics_process(false)
		if global_position.y > 0.3:
			pass  # keep falling onto ground normally

func capture(hole) -> void:
	if captured_by != null:
		return
	captured_by = hole
	hole.add_points(points)
	hole.add_xp(points)
	hole.mass_collected += mass
	Events.object_captured.emit(hole, self, points, points)
	AudioManager.play("eat")
	# return to pool: disable
	freeze = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitorable", false)
	call_deferred("queue_free")

func flash_uneatable() -> void:
	if _flash_tween and _flash_tween.is_running():
		return
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for mi in meshes:
		var m := (mi as MeshInstance3D).get_active_material(0)
		if m is StandardMaterial3D:
			var mm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			(mi as MeshInstance3D).material_override = mm
			_flash_tween = create_tween()
			_flash_tween.tween_property(mm, "emission_energy_multiplier", 0.8, 0.08).from(0.0)
			_flash_tween.tween_property(mm, "emission_energy_multiplier", 0.0, 0.25)
			mm.emission_enabled = true
			mm.emission = Color.WHITE
