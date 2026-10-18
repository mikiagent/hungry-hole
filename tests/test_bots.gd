extends RefCounted
var runner
func test_profiles_match_dump() -> void:
	var h := BotProfile.hard()
	runner.approx(h.select_closest_chance, 0.7, 0.001, "hard closest 0.7")
	runner.approx(h.select_random_chance, 0.3, 0.001, "hard random 0.3")
	runner.approx(h.target_change_cooldown, 5.0, 0.001, "hard cooldown 5")
	runner.approx(h.escape_player_if_closer_than, 1.0, 0.001, "hard escape 1")
	var n := BotProfile.normal()
	runner.check(n.max_size == -1, "normal uncapped")
	runner.approx(n.escape_player_if_closer_than, 3.0, 0.001, "normal escape 3")
	var br := BotProfile.battle_royale()
	runner.approx(br.aggression_ramp_seconds, 90.0, 0.001, "BR aggression ramp 90 s")
	runner.check(br.max_player_hunters == 2, "max 2 hunters")
func test_waypoint_clamped_to_bounds() -> void:
	var b := Rect2(-100, -100, 200, 200)
	for i in 50:
		var p := BotController.random_waypoint(Vector3(95, 0, 95), b)
		runner.check(p.x <= 97.0 and p.z <= 97.0 and p.x >= -97.0 and p.z >= -97.0, "waypoint inside walls")
func test_game_mode_defaults() -> void:
	var g := GameModeParams.new()
	runner.check(g.player_count == 7, "7 players")
	runner.approx(g.duration_seconds, 120.0, 0.001, "2 minutes")
	runner.approx(g.kill_cooldown, 5.0, 0.001, "kill cooldown 5 s")
