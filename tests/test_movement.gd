extends RefCounted
var runner
func test_control_config_is_instant() -> void:
	var cfg := HoleMoveConfig.new()
	var m := HoleMovement.new(cfg)
	var v := m.calculate_velocity(Vector3.ZERO, Vector3(1, 0, 0), 1.0, 6.09, 1.0 / 60.0)
	runner.approx(v.length(), 6.09, 0.001, "full stick reaches top speed in one tick")
	v = m.calculate_velocity(v, Vector3(1, 0, 0), 0.5, 6.09, 1.0 / 60.0)
	runner.approx(v.length(), 3.045, 0.001, "half stick = half speed")
	v = m.calculate_velocity(v, Vector3.ZERO, 0.0, 6.09, 1.0 / 60.0)
	runner.approx(v.length(), 0.0, 0.001, "release stops instantly")
func test_speed_is_table_times_multiplier() -> void:
	var cfg := HoleMoveConfig.new()
	runner.approx(cfg.top_speed(10.0, false), 10.0, 0.001, "player speed = table speed")
	runner.approx(cfg.top_speed(10.0, true), 10.0, 0.001, "bot speed = table speed x BotsSpeedMultiplier (1.0)")
	cfg.bots_speed_multiplier = 0.9
	runner.approx(cfg.top_speed(10.0, true), 9.0, 0.001, "bot multiplier applies")
func test_quick_turn_and_states() -> void:
	var cfg := HoleMoveConfig.new()
	var m := HoleMovement.new(cfg)
	m.calculate_velocity(Vector3.ZERO, Vector3(1, 0, 0), 1.0, 10.0, 0.016)
	runner.check(m.speed_state == HoleMovement.SpeedState.RUNNING, "mag 1 = running")
	m.calculate_velocity(Vector3.ZERO, Vector3(1, 0, 0), 0.3, 10.0, 0.016)
	runner.check(m.speed_state == HoleMovement.SpeedState.WALKING, "mag 0.3 = walking")
	m.calculate_velocity(Vector3.ZERO, Vector3(-1, 0, 0), 1.0, 10.0, 0.016)
	runner.check(m.quick_turn_count == 1, "reversal counts as quick turn")
	m.calculate_velocity(Vector3.ZERO, Vector3(1, 0, 0), 1.0, 10.0, 0.016)
	runner.check(m.quick_turn_count == 1, "second reversal within cooldown ignored")
func test_camera_curves() -> void:
	var c := CameraCurves.new()
	runner.approx(c.distance_for(1.0), 10.0, 0.01, "cam dist size1")
	runner.approx(c.distance_for(14.0), 50.0, 0.01, "cam dist size14")
	runner.approx(c.angle_for(1.0), 40.91, 0.01, "pitch size1")
	runner.approx(c.fov_for(4.0), 70.0, 0.01, "fov size4")
	runner.approx(c.fov_for(100.0), 50.0, 0.01, "fov large")
