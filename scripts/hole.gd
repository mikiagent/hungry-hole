class_name Hole
extends CharacterBody3D
## The player's or a bot's hole. Size/level/xp/points per 03-systems/*.md.
signal level_changed(level: int)
signal size_changed(size: float)
signal died(killer)

@export var balance: BalanceTable
@export var move_config: HoleMoveConfig
@export var player_id: int = 0
@export var is_bot: bool = false
@export var display_name: String = "You"
@export var color: Color = Color("3EA8FB")

var level := 1
var xp := 0
var points := 0
var size := 2.0
var speed_multiplier := 1.0
var is_dead := false
var rank := 1
var mass_collected := 0.0
var kills := 0
var desired_dir := Vector3.ZERO
var input_mag := 0.0
var movement: HoleMovement
var _target_size := 2.0
var _size_tween: Tween
var _mouth_tilt := 0.0

@onready var eat_trigger: Area3D = $EatTrigger
@onready var eat_shape: CollisionShape3D = $EatTrigger/Shape
@onready var collect_trigger: Area3D = $CollectTrigger
@onready var collect_shape: CollisionShape3D = $CollectTrigger/Shape
@onready var visuals: Node3D = $Visuals
@onready var ring: MeshInstance3D = $Visuals/Ring
@onready var crown: MeshInstance3D = $Visuals/Crown
@onready var name_label: Label3D = $NameLabel
@onready var tube: MeshInstance3D = $Visuals/Tube
var _tube_mat: ShaderMaterial
var _ring_mat: ShaderMaterial

const SIZE_TWEEN_DURATION := 0.35
const SWALLOW_TIME := 0.35
## HoleUnblockerSettings V239
const UNBLOCK_INTERVAL := 0.25
const UNBLOCK_PRIMARY_DELAY := 1.0
const UNBLOCK_PRIMARY_FORCE := 5.0
const UNBLOCK_EXTRA_FORCE_PER_S := 5.0
const UNBLOCK_MAX_BOUNCE := 20.0
const UNBLOCK_SPIT_DELAY := 3.0
const UNBLOCK_SPIT_FORCE := 50.0
const UNBLOCK_SPIT_MASS_FACTOR := 0.35
var _unblock_accum := 0.0
var _scan_query := PhysicsShapeQueryParameters3D.new()
## Physical mouth: a ring of box colliders around the opening, on this hole's own layer (original: c_MAX_HOLE_LAYER_COUNT per-hole layers).
const RIM_SEGMENTS := 32
const PLUG_DEPTH := 0.8               # how far a too-big object can sink while tipping over the edge
const RIM_LAYER_BASE := 10            # physics layers 11..18 are hole rims
const PLUG_LAYER_BASE := 18           # physics layers 19..26: a floor inside each hole that only too-big objects hit
var plug_layer_bit := 0
var _plug: CollisionShape3D
var rim_body: AnimatableBody3D
var rim_layer_bit := 0
var _rim_shapes: Array[CollisionShape3D] = []
var _scan_shape := CylinderShape3D.new()
const COLLECT_TRIGGER_Y := -1.5

func _ready() -> void:
	if balance == null:
		balance = BalanceTable.new()
	if move_config == null:
		move_config = HoleMoveConfig.new()
	movement = HoleMovement.new(move_config)
	collision_layer = 1 << 3
	collision_mask = 1 << 2  # walls only: holes must pass over each other so a bigger one can swallow a smaller one
	eat_trigger.collision_layer = 0
	eat_trigger.collision_mask = 1 << 1  # objects
	collect_trigger.collision_layer = 0
	collect_trigger.collision_mask = 1 << 1
	_build_rim()
	eat_trigger.body_entered.connect(_on_eat_trigger_entered)
	eat_trigger.body_exited.connect(_on_eat_trigger_exited)
	collect_trigger.monitoring = false  # capture is depth-based in FallingObject now
	_apply_color()
	name_label.text = display_name
	name_label.font = preload("res://assets/fonts/fredoka_bold.tres")
	set_level(1, true)

func _build_rim() -> void:
	rim_layer_bit = 1 << (RIM_LAYER_BASE + (player_id % 8))
	rim_body = AnimatableBody3D.new()
	rim_body.name = "Rim"
	rim_body.sync_to_physics = true
	rim_body.collision_layer = rim_layer_bit
	rim_body.collision_mask = 0
	var pm := PhysicsMaterial.new(); pm.friction = 0.45; pm.bounce = 0.0   # GameBalanceSettings.m_innerHolePhysicsMaterial
	rim_body.physics_material_override = pm
	add_child(rim_body)
	# plug: a disc inside the hole on its own layer; objects too big to be eaten tip onto it instead of falling through
	plug_layer_bit = 1 << (PLUG_LAYER_BASE + (player_id % 8))
	var plug_body := AnimatableBody3D.new(); plug_body.name = "Plug"; plug_body.sync_to_physics = true
	plug_body.collision_layer = plug_layer_bit; plug_body.collision_mask = 0
	plug_body.physics_material_override = pm
	_plug = CollisionShape3D.new(); _plug.shape = CylinderShape3D.new(); plug_body.add_child(_plug)
	add_child(plug_body)
	for i in RIM_SEGMENTS:
		var cs := CollisionShape3D.new(); cs.shape = BoxShape3D.new()
		rim_body.add_child(cs); _rim_shapes.append(cs)
	_size_rim(radius())

## Annulus from the hole edge outward; top surface at ground level, so it reads to physics like the ground with a round cut.
func _size_rim(r: float) -> void:
	if _rim_shapes.is_empty(): return
	if _plug:
		(_plug.shape as CylinderShape3D).radius = r * 1.02
		(_plug.shape as CylinderShape3D).height = 1.0
		_plug.position = Vector3(0, -PLUG_DEPTH - 0.5, 0)
	var width := maxf(4.0, r * 1.5)
	var mid := r + width * 0.5
	var seg_len := TAU * mid / RIM_SEGMENTS * 1.08
	var inner_len := TAU * r / RIM_SEGMENTS
	for i in RIM_SEGMENTS:
		var a := TAU * i / RIM_SEGMENTS
		var cs := _rim_shapes[i]
		(cs.shape as BoxShape3D).size = Vector3(maxf(seg_len, inner_len), 1.0, width)
		cs.transform = Transform3D(Basis(Vector3.UP, -a), Vector3(sin(a) * mid, -0.5, cos(a) * mid))

func radius() -> float:
	return size * 0.5

func set_level(new_level: int, instant := false) -> void:
	new_level = maxi(new_level, 1)   # no upper cap: past max level the hole keeps growing slowly
	var changed := new_level != level
	level = new_level
	_target_size = balance.size_for_level(level)
	if instant:
		_apply_size(_target_size)
	else:
		if _size_tween: _size_tween.kill()
		_size_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_size_tween.tween_method(_apply_size, size, _target_size, SIZE_TWEEN_DURATION)
	if changed:
		level_changed.emit(level)
		Events.hole_level_up.emit(self, level)

func _apply_size(s: float) -> void:
	size = s
	var r := radius()
	_size_rim(r)
	visuals.scale = Vector3(r, 1.0, r)
	var cyl := eat_shape.shape as CylinderShape3D
	cyl.radius = r * 0.92
	cyl.height = 3.0
	eat_trigger.position.y = 0.5
	var ccyl := collect_shape.shape as CylinderShape3D
	ccyl.radius = r * 1.5
	ccyl.height = 2.0
	collect_trigger.position.y = COLLECT_TRIGGER_Y - 1.0
	if _tube_mat: _tube_mat.set_shader_parameter("fade_depth", 1.5 + r * 1.4)
	size_changed.emit(size)

func add_xp(amount: int) -> void:
	if is_dead: return
	xp += amount
	var new_level := balance.level_for_xp(xp)
	if new_level > level:
		set_level(new_level)
		AudioManager.play("grow")

func add_points(amount: int) -> void:
	points += amount

func top_speed() -> float:
	return move_config.top_speed(balance.speed_for_level(level), is_bot) * speed_multiplier

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var v := movement.calculate_velocity(Vector3(velocity.x, 0, velocity.z), desired_dir, input_mag, top_speed(), delta)
	velocity = Vector3(v.x, 0.0, v.z)
	move_and_slide()
	global_position.y = 0.0
	_scan_eatables()
	_unblock(delta)
	# tilt the ring a little toward travel for the "squish" feel
	var sp := velocity.length() / maxf(top_speed(), 0.01)
	_mouth_tilt = lerpf(_mouth_tilt, sp * 0.12, 8.0 * delta)
	# squash-and-stretch along travel instead of tilting (tilting pushed one side of the ring into the ground)
	var r := radius()
	if velocity.length() > 0.1:
		var fwd := velocity.normalized()
		var stretch := 1.0 + _mouth_tilt * 0.6
		visuals.rotation = Vector3(0, atan2(fwd.x, fwd.z), 0)
		visuals.scale = Vector3(r / sqrt(stretch), 1.0, r * stretch)
	else:
		visuals.scale = Vector3(r, 1.0, r)

## Direct query of the hole opening every tick. Area enter events alone missed sleeping frozen bodies and
## objects that were reset or spat out while still inside (see --diag-eat).
func _scan_eatables() -> void:
	_scan_shape.radius = radius() * 0.92
	_scan_shape.height = 3.0
	_scan_query.shape = _scan_shape
	_scan_query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.5, 0))
	_scan_query.collision_mask = 1 << 1
	_scan_query.collide_with_areas = false
	var now := Time.get_ticks_msec() / 1000.0
	for hit in get_world_3d().direct_space_state.intersect_shape(_scan_query, 96):
		var fo := hit.collider as FallingObject
		if fo == null or fo.is_falling or fo.captured_by != null or now < fo.no_eat_until: continue
		if can_eat(fo): fo.start_falling(self)
		elif fo.tipping_for != self: fo.start_tipping(self)

func _unblock(delta: float) -> void:
	_unblock_accum += delta
	if _unblock_accum < UNBLOCK_INTERVAL: return
	_unblock_accum = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	for body in eat_trigger.get_overlapping_bodies():
		if not is_instance_valid(body) or not body is FallingObject: continue
		var fo := body as FallingObject
		if not fo.is_falling or fo.captured_by != null or fo.falling_for != self: continue
		if fo.global_position.y < -0.8: continue  # already going down
		var stuck := now - fo.fall_started_at
		if stuck > UNBLOCK_SPIT_DELAY:
			var out := fo.global_position - global_position; out.y = 0.0
			var f := UNBLOCK_SPIT_FORCE + fo.mass * UNBLOCK_SPIT_MASS_FACTOR
			fo.collision_mask = 1 << 0 | 1 << 1 | 1 << 2
			fo.is_falling = false; fo.falling_for = null; fo.spit_count += 1
			fo.no_eat_until = now + 1.5
			fo.set_physics_process(false)
			fo.apply_central_impulse((out.normalized() + Vector3.UP * 0.6).normalized() * f * fo.mass * 0.05)
		elif stuck > UNBLOCK_PRIMARY_DELAY:
			var force := minf(UNBLOCK_PRIMARY_FORCE + UNBLOCK_EXTRA_FORCE_PER_S * (stuck - UNBLOCK_PRIMARY_DELAY), UNBLOCK_MAX_BOUNCE)
			var inward := global_position - fo.global_position; inward.y = 0.0
			fo.apply_central_impulse((inward.normalized() * 0.5 + Vector3.DOWN).normalized() * force * fo.mass * 0.05)

func can_eat(obj) -> bool:
	if obj.size_required > level: return false
	return not (obj.only_for_player and is_bot)

func _on_eat_trigger_entered(body: Node3D) -> void:
	if is_dead or not is_instance_valid(body) or not body is FallingObject:
		return
	var fo := body as FallingObject
	if can_eat(fo):
		fo.start_falling(self)
	elif not is_bot:
		fo.flash_uneatable()

func _on_eat_trigger_exited(body: Node3D) -> void:
	if is_instance_valid(body) and body is FallingObject:
		(body as FallingObject).left_hole(self)

func _on_collect_trigger_entered(body: Node3D) -> void:
	if is_dead or not body is FallingObject:
		return
	var fo := body as FallingObject
	if fo.captured_by != null:
		return
	fo.capture(self)

func die(killer) -> void:
	if is_dead: return
	is_dead = true
	velocity = Vector3.ZERO
	input_mag = 0.0
	eat_trigger.set_deferred("monitoring", false)
	set_crown(false)
	# swallow: shrink and slide into the killer's center, then vanish
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(visuals, "scale", Vector3(0.01, 1.0, 0.01), SWALLOW_TIME)
	if killer != null and is_instance_valid(killer):
		tw.tween_property(self, "global_position", Vector3(killer.global_position.x, 0, killer.global_position.z), SWALLOW_TIME)
	tw.tween_property(name_label, "modulate:a", 0.0, SWALLOW_TIME * 0.6)
	tw.chain().tween_callback(func(): visible = false)
	died.emit(killer)

func respawn(at: Vector3) -> void:
	is_dead = false
	xp = 0
	global_position = Vector3(at.x, 0.0, at.z)
	set_level(1, true)
	visible = true
	name_label.modulate.a = 1.0
	eat_trigger.monitoring = true

## Put the name on the hole's far rim as seen from the camera: horizontally centered, just above the ring on screen.
func _place_label() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null: return
	var away := global_position - cam.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001: return
	var r := radius()
	name_label.global_position = global_position + away.normalized() * (r + 0.4) + Vector3.UP * (0.8 + r * 0.15)
	name_label.pixel_size = 0.012 + r * 0.004

## Called every frame with all holes: hide our rim and inner wall wherever a larger hole overlaps us.
func update_occluders(all_holes: Array) -> void:
	var arr := PackedVector4Array()
	for h in all_holes:
		if arr.size() >= 8: break
		if h == self or h.is_dead: continue
		if h.size > size or (is_equal_approx(h.size, size) and h.player_id < player_id):
			if h.global_position.distance_to(global_position) < h.radius() + radius():
				arr.append(Vector4(h.global_position.x, h.global_position.z, h.radius(), 1.0))
	while arr.size() < 8: arr.append(Vector4.ZERO)
	if _ring_mat: _ring_mat.set_shader_parameter("occluders", arr)
	if _tube_mat: _tube_mat.set_shader_parameter("occluders", arr)
	# larger holes also sort later so their transparent label/crown draw on top
	ring.sorting_offset = size
	tube.sorting_offset = size

func set_crown(on: bool) -> void:
	crown.visible = on

func _process(delta: float) -> void:
	_place_label()
	if crown.visible:
		crown.rotate_y(delta * 1.5)

func _apply_color() -> void:
	_tube_mat = ShaderMaterial.new()
	_tube_mat.shader = preload("res://shaders/hole_tube.gdshader")
	_tube_mat.set_shader_parameter("rim_color", color.darkened(0.55))
	tube.material_override = _tube_mat
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = preload("res://shaders/hole_ring.gdshader")
	_ring_mat.set_shader_parameter("color", color)
	ring.material_override = _ring_mat
	name_label.modulate = color
	name_label.outline_modulate = Color("2C2F48")
