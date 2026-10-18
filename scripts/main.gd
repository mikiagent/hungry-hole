extends Node3D
## Boots a Classic (Timer) match: city, holes, camera, HUD. States: PREGAME → PLAYING → ENDED.
enum State { PREGAME, PLAYING, ENDED }
var state := State.PREGAME
var city: CityGenerator
var match_node: Match
var rig: CameraRig
var hud: HUD
var controller: PlayerController
var _screenshot_path := ""
var _screenshot_timer := 0.0
var _auto_quit := 0.0
var _autoplay := false
var _overlap_test := false
var _kill_test := false
var _diag := false
var _edge_test := false
var _topple_test := false
var _topple_base: FallingObject
var _topple_max := 0.0
var _topple_t := 0.0
var _edge_boxes: Array = []
var _edge_t := 0.0
var _diag_stuck := {}
var _diag_accum := 0.0
var _diag_reported := 0
var _kill_victim: Hole
var _kill_t := 0.0
var _screenshot_at := 2.5
var _fps_samples: Array[float] = []

func _ready() -> void:
	randomize()
	_parse_args()
	_build_world()
	city = CityGenerator.new(); city.tiers = ObjectPhysicsTiers.new(); add_child(city); city.build()
	match_node = Match.new(); match_node.params = GameModeParams.new(); match_node.balance = BalanceTable.new(); add_child(match_node)
	match_node.setup(city, city.bounds)
	Movable.current_match = match_node
	match_node.spawn_holes(city.spawn_groups)
	rig = CameraRig.new(); var cam := Camera3D.new(); cam.name = "Camera3D"; rig.add_child(cam); add_child(rig)
	rig.target = match_node.player; rig.snap()
	controller = PlayerController.new(); controller.hole = match_node.player; controller.camera_yaw = rig.yaw_deg; add_child(controller)
	hud = HUD.new(); add_child(hud); hud.setup(match_node, cam)
	controller.joystick_changed.connect(hud.on_joystick)
	controller.enabled = false
	hud.show_center(tr("TXT_TAP_TO_START"))
	Events.match_ended.connect(func(_r, _rank): state = State.ENDED)
	print("[main] city objects=%d points=%d holes=%d yaw=%.0f" % [city.object_count, city.total_points, match_node.holes.size(), rig.yaw_deg])
	if _autoplay:
		var bc := BotController.new(); add_child(bc); bc.setup(match_node.player, match_node, BotProfile.hard())
		match_node.bots.append(bc)
		controller.queue_free(); controller = null
	if _overlap_test:
		# player at level 8 with a level-3 bot half inside it, both frozen in place
		var p := match_node.player; p.set_level(8, true)
		var b: Hole = match_node.holes[1]; b.set_level(3, true)
		b.global_position = p.global_position + Vector3(p.radius() * 0.8, 0, 0)
		for bc in match_node.bots: bc.set_physics_process(false)
		match_node.set_process(false)
		rig.snap()
	if _topple_test:
		# a level-12 hole (5.2 m) drives past a 4-storey stack (4x4 m footprint needs a 5.8 m hole), 1.6 m off-centre
		var p := match_node.player; p.set_level(12, true)
		for bc in match_node.bots: bc.set_physics_process(false)
		for h in match_node.holes: if h != p: h.global_position += Vector3(500, 0, 500)
		if controller: controller.queue_free(); controller = null
		var site := p.global_position + Vector3(16, 0, 0)
		for c in city.get_children():
			if c is FallingObject and c.global_position.distance_to(site) < 16.0: c.free()
		city._building_stack(site + Vector3(0, 0, 1.6), 4, "b_coral")
		for c in city.get_children():
			if c is FallingObject and c.global_position.distance_to(site + Vector3(0, 1.5, 1.6)) < 0.5: _topple_base = c
		rig.snap()
	if _edge_test:
		# parked size-10 hole (radius 5); crates at increasing distance from its centre along +X
		var p := match_node.player; p.set_level(5, true)
		for bc in match_node.bots: bc.set_physics_process(false)
		for h in match_node.holes: if h != p: h.global_position += Vector3(500, 0, 500)
		if controller: controller.queue_free(); controller = null
		for c in city.get_children():
			if c is FallingObject and c.global_position.distance_to(p.global_position) < 14.0: c.free()
		var ang := 0.0
		for d in [2.0, 3.5, 4.5, 5.2, 5.8, 6.5, 7.5, 9.0]:
			var dir := Vector3(cos(ang), 0, sin(ang)); ang += TAU / 8.0
			var fo := city._prop_box("edgecrate", p.global_position + dir * d, Vector3(2.0, 1.2, 2.0), "wood", 1, 1)
			fo.set_meta("edge_d", d)
			_edge_boxes.append(fo)
		rig.snap()
	if _kill_test:
		# a level-6 player drives straight at a parked level-2 bot; physics, triggers and kill rule all live
		var p := match_node.player; p.set_level(6, true)
		_kill_victim = match_node.holes[1]; _kill_victim.set_level(2, true)
		_kill_victim.global_position = p.global_position + Vector3(14, 0, 0)
		for bc in match_node.bots: bc.set_physics_process(false)
		if controller: controller.queue_free(); controller = null
		rig.snap()
	if _auto_quit > 0.0 or _screenshot_path != "":
		_start()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="): _screenshot_path = a.substr(13)
		if a.begins_with("--quit-after="): _auto_quit = float(a.substr(13))
		if a == "--autoplay": _autoplay = true
		if a == "--overlap-test": _overlap_test = true
		if a == "--kill-test": _kill_test = true
		if a == "--diag-eat": _diag = true
		if a == "--edge-test": _edge_test = true
		if a == "--topple-test": _topple_test = true
		if a.begins_with("--screenshot-at="): _screenshot_at = float(a.substr(16))

func _build_world() -> void:
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 35, 0); sun.light_energy = 1.1; sun.shadow_enabled = true; sun.light_color = Color("FFF4E0")
	sun.directional_shadow_max_distance = 220.0; add_child(sun)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_SKY; var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("4FC3F7"); sm.sky_horizon_color = Color("CDEFFF"); sm.ground_bottom_color = Color("8BD450"); sm.ground_horizon_color = Color("CDEFFF"); sky.sky_material = sm; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; e.ambient_light_energy = 0.9
	e.fog_enabled = true; e.fog_mode = Environment.FOG_MODE_DEPTH; e.fog_light_color = Color("CDEFFF"); e.fog_depth_begin = 300.0; e.fog_depth_end = 1200.0; e.fog_density = 0.6; e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; add_child(env)

func _start() -> void:
	if state != State.PREGAME: return
	state = State.PLAYING
	hud.show_center("")
	if controller: controller.enabled = true
	match_node.start()

func _unhandled_input(event: InputEvent) -> void:
	if state == State.PREGAME and (event.is_action_pressed("start") or event is InputEventScreenTouch):
		_start()
	elif state == State.ENDED and (event.is_action_pressed("start") or (event is InputEventScreenTouch and event.pressed)):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause") and state == State.PLAYING:
		hud.set_paused(not get_tree().paused)

func _physics_process(delta: float) -> void:
	if _topple_test and state == State.PLAYING:
		_topple_t += delta
		var p := match_node.player
		p.desired_dir = Vector3(1, 0, 0); p.input_mag = 0.35 if _topple_t < 6.0 else 0.0
		for c in city.get_children():
			if c is FallingObject and c.name.begins_with("apt") and not c.freeze and is_instance_valid(c):
				var tilt := rad_to_deg(acos(clampf(c.global_transform.basis.y.dot(Vector3.UP), -1.0, 1.0)))
				_topple_max = maxf(_topple_max, tilt)
		if _topple_t > 7.0 and _topple_t < 100.0:
			_topple_t = 100.0
			var eaten := not is_instance_valid(_topple_base) or _topple_base.captured_by != null
			print("[topple-test] stack max tilt %.0f deg, eaten=%s, base y=%.2f" % [_topple_max, eaten, _topple_base.global_position.y if not eaten else -99.0])
	if _edge_test and state == State.PLAYING:
		_edge_t += delta
		if _edge_t > 4.0 and _edge_t < 100.0:
			_edge_t = 100.0
			for fo in _edge_boxes:
				var d: float = fo.get_meta("edge_d") if is_instance_valid(fo) else -1.0
				if not is_instance_valid(fo) or fo.captured_by != null:
					print("[edge-test] crate centre %.1f m from centre (radius 5): EATEN" % d)
				else:
					print("[edge-test] crate centre %.1f m (radius 5): stayed, y=%.2f falling=%s" % [d, fo.global_position.y, fo.is_falling])
	if _kill_test and state == State.PLAYING and _kill_victim:
		_kill_t += delta
		var p := match_node.player
		var to := _kill_victim.global_position - p.global_position; to.y = 0
		p.desired_dir = to.normalized() if to.length() > 0.05 else Vector3.ZERO
		p.input_mag = 1.0 if not _kill_victim.is_dead else 0.0
		if _kill_victim.is_dead and _kill_t < 100.0:
			print("[kill-test] PASS: level-6 player swallowed level-2 bot after %.2f s, player kills=%d points=%d" % [_kill_t, p.kills, p.points])
			_kill_t = 100.0
		elif _kill_t > 5.0 and _kill_t < 100.0:
			print("[kill-test] FAIL: bot still alive after 5 s, distance=%.2f" % to.length())
			_kill_t = 100.0

## --diag-eat: count objects an eligible hole is clearly over (center inside the opening) that stay unfallen for 0.5 s.
func _diag_tick(delta: float) -> void:
	_diag_accum += delta
	if _diag_accum < 0.1: return
	_diag_accum = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	for o in get_tree().get_nodes_in_group("eatable"):
		if not is_instance_valid(o) or o.is_queued_for_deletion() or o.captured_by != null or o.is_falling: 
			_diag_stuck.erase(o); continue
		var over := false
		for h in match_node.holes:
			if h.is_dead or o.size_required > h.level or (o.only_for_player and h.is_bot): continue
			var d := Vector2(o.global_position.x - h.global_position.x, o.global_position.z - h.global_position.z).length()
			if d < h.radius() * 0.7: over = true; break
		if not over: _diag_stuck.erase(o); continue
		if not _diag_stuck.has(o): _diag_stuck[o] = now
		elif now - _diag_stuck[o] > 0.5 and _diag_stuck[o] > 0.0:
			_diag_reported += 1
			if _diag_reported <= 12:
				print("[diag] STUCK %s size=%d y=%.2f freeze=%s mask=%d sleeping=%s" % [o.name, o.size_required, o.global_position.y, o.freeze, o.collision_mask, o.sleeping])
			_diag_stuck[o] = -1.0

func _process(delta: float) -> void:
	if _diag and state == State.PLAYING: _diag_tick(delta)
	city.update_hole_uniforms(match_node.holes)
	for h in match_node.holes: h.update_occluders(match_node.holes)
	if state == State.PLAYING and Engine.get_frames_drawn() > 30: _fps_samples.append(Engine.get_frames_per_second())
	if _screenshot_path != "":
		_screenshot_timer += delta
		if _screenshot_timer > _screenshot_at:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_screenshot_path)
			print("[main] screenshot saved ", _screenshot_path)
			_screenshot_path = ""
			if _auto_quit <= 0.0: get_tree().quit()
	if _auto_quit > 0.0:
		_auto_quit -= delta
		if _auto_quit <= 0.0:
			var bots_pts := []
			for h in match_node.holes: bots_pts.append("%s:%d/L%d k%d%s" % [h.display_name, h.points, h.level, h.kills, " DEAD" if h.is_dead else ""])
			if _fps_samples.size() > 0:
				var s := _fps_samples.duplicate(); s.sort()
				print("[main] fps median=%.0f min=%.0f samples=%d" % [s[s.size() / 2], s[0], s.size()])
			if _diag: print("[diag] stuck objects total: %d" % _diag_reported)
			print("[main] auto quit; player points=%d level=%d xp=%d | %s" % [match_node.player.points, match_node.player.level, match_node.player.xp, ", ".join(bots_pts)])
			get_tree().quit()
