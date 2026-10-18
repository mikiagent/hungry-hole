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

## Captured once the whole object is this far below the ground (deeper than the original's 1-5 u so the fall reads clearly).
const CAPTURE_EXTRA_DEPTH := 4.0

func _physics_process(_delta: float) -> void:
	# safety net: anything not being eaten that ends up well below ground goes back on top
	if captured_by == null and not is_falling and not freeze and global_position.y < -3.0:
		_restore_ground()
		global_position.y = height * 0.5 + 0.5
	if tipping_for != null and (not is_instance_valid(tipping_for) or tipping_for.is_dead):
		_restore_ground()
	elif tipping_for != null:
		_undercut_torque()
	if is_falling and captured_by == null and falling_for != null and is_instance_valid(falling_for):
		if global_position.y < -(height * 0.5 + CAPTURE_EXTRA_DEPTH + falling_for.radius() * 0.25):
			capture(falling_for)

## Too big for this hole: become a real rigid body that loses ground support over the opening.
## It tips and can topple over the edge, but the hole's plug stops it from sinking through.
## The part of the footprint over the opening has lost its foundation: tip toward the hole in proportion
## to how much of the footprint is unsupported, so a clipped building leans and can fall over.
const UNDERCUT_MIN := 0.12
const UNDERCUT_STRENGTH := 0.9
func _undercut_torque() -> void:
	var h = tipping_for
	var to: Vector3 = h.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.01: return
	var undercut := clampf((h.radius() - (d - footprint_half)) / (2.0 * footprint_half), 0.0, 1.0)
	if undercut < UNDERCUT_MIN: return
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
	# gravity (80) acting on the unsupported share of the mass, lever arm ~ half the height
	apply_torque(axis * mass * 80.0 * undercut * maxf(height, 1.0) * 0.5 * UNDERCUT_STRENGTH)
	sleeping = false

## Give a tipped object its ground back; if it sank into the opening, lift it to ground level first.
func _restore_ground() -> void:
	tipping_for = null
	set_physics_process(false)
	if global_position.y < height * 0.5 - 0.2:
		global_position.y = height * 0.5 + 0.05
		linear_velocity.y = maxf(linear_velocity.y, 0.0)
	collision_mask = 1 << 0 | 1 << 1 | 1 << 2

func start_tipping(hole) -> void:
	if captured_by != null or is_falling: return
	tipping_for = hole
	set_physics_process(true)
	freeze = false
	sleeping = false
	collision_mask = 1 << 1 | 1 << 2 | hole.rim_layer_bit | hole.plug_layer_bit
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
