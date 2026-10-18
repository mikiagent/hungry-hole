extends RefCounted
## Integration tests that need the scene tree: kills, cooldown streaks, ranking.
var runner

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

func _make_match() -> Match:
	var m := Match.new()
	m.params = GameModeParams.new(); m.balance = BalanceTable.new()
	_tree().root.add_child(m)
	var map := Node3D.new(); _tree().root.add_child(map)
	m.setup(map, Rect2(-100, -100, 200, 200))
	return m

func _add_hole(m: Match, id: int, lvl: int, pos: Vector3, bot := true) -> Hole:
	var h := m.hole_scene.instantiate() as Hole
	h.player_id = id; h.is_bot = bot; h.balance = m.balance
	m.map.add_child(h); h.global_position = pos
	h.set_level(lvl, true)
	m.holes.append(h)
	return h

func test_bigger_hole_kills_smaller() -> void:
	var m := _make_match(); m.playing = true
	var big := _add_hole(m, 0, 5, Vector3.ZERO, false); m.player = big
	var small := _add_hole(m, 1, 2, Vector3(big.radius() * 0.3, 0, 0))
	m._check_hole_kills()
	runner.check(small.is_dead, "level-2 hole inside a level-5 hole dies")
	runner.check(not big.is_dead, "killer survives")
	runner.check(big.kills == 1, "kill counted")
	runner.check(big.points > 0, "killer gains points")
	m.map.queue_free(); m.queue_free()

func test_equal_level_no_kill() -> void:
	var m := _make_match(); m.playing = true
	var a := _add_hole(m, 0, 3, Vector3.ZERO, false); m.player = a
	var b := _add_hole(m, 1, 3, Vector3(0.5, 0, 0))
	m._check_hole_kills()
	runner.check(not a.is_dead and not b.is_dead, "same level holes cannot eat each other")
	m.map.queue_free(); m.queue_free()

func test_far_hole_not_killed() -> void:
	var m := _make_match(); m.playing = true
	var big := _add_hole(m, 0, 5, Vector3.ZERO, false); m.player = big
	var small := _add_hole(m, 1, 1, Vector3(30, 0, 0))
	m._check_hole_kills()
	runner.check(not small.is_dead, "small hole outside radius survives")
	m.map.queue_free(); m.queue_free()

func test_ranking_orders_by_points() -> void:
	var m := _make_match()
	var a := _add_hole(m, 0, 1, Vector3.ZERO, false); m.player = a
	var b := _add_hole(m, 1, 1, Vector3(50, 0, 0))
	var c := _add_hole(m, 2, 1, Vector3(-50, 0, 0))
	a.points = 5; b.points = 20; c.points = 10
	m._update_ranking()
	runner.check(b.rank == 1 and c.rank == 2 and a.rank == 3, "rank by points desc")
	m.map.queue_free(); m.queue_free()
