extends RefCounted
var runner
func test_size_and_speed_tables() -> void:
	var b := BalanceTable.new()
	runner.approx(b.size_for_level(1), 1.6, 0.001, "size L1 1.6 m")
	runner.check(b.size_for_level(20) > 17.0 and b.size_for_level(20) < 19.0, "size L20 ~17.5")
	for l in range(2, 31): runner.check(b.size_for_level(l) > b.size_for_level(l - 1), "sizes increase")
	for l in range(1, 31): runner.approx(b.speed_for_level(l), 4.36 + 0.868 * b.size_for_level(l), 0.02, "speed follows original size relation")
	runner.check(b.size_for_level(30) > 59.0 and b.size_for_level(30) < 63.0, "size L30 ~61")
	runner.approx(b.size_for_level(31), b.size_for_level(30) * 1.03, 0.01, "overflow growth 3% per level")
	runner.check(b.size_for_level(60) > b.size_for_level(40), "keeps growing")
	runner.approx(b.speed_for_level(60), b.speed_for_level(30), 0.001, "speed capped at L30 value")
	runner.check(b.level_for_footprint(1.0) == 1, "0.7x0.7 prop fits a level-1 hole")
	runner.check(b.level_for_footprint(5.66) == b.level_for_footprint(5.66), "deterministic")
	runner.check(b.size_for_level(b.level_for_footprint(5.66)) >= 5.66, "4x4 block fits its required level")
	runner.check(b.size_for_level(b.level_for_footprint(5.66) - 1) < 5.66 * 1.02, "and not the level below")
func test_fast_xp_table_levels() -> void:
	var b := BalanceTable.new()
	runner.check(b.level_for_xp(0) == 1, "0 xp = L1")
	runner.check(b.level_for_xp(3) == 1, "3 xp = L1")
	runner.check(b.level_for_xp(4) == 2, "4 xp = L2 (original value below L10)")
	runner.check(b.level_for_xp(87) == 10, "87 xp = L10 (original)")
	# past L10 each level's table increment is multiplied by LATE_XP_GROWTH^(L-10)
	var l11 := 87 + roundi(23 * BalanceTable.LATE_XP_GROWTH)
	runner.check(b.xp_for_level(11) == l11, "L11 increment scaled once")
	var l30 := b.xp_for_level(30)
	runner.check(l30 > 3800 and l30 < 5000, "L30 needs ~4,000-5,000 xp (got %d)" % l30)
	var prev := 0
	var rising := true
	for l in range(2, 45):
		var inc := b.xp_for_level(l) - b.xp_for_level(l - 1)
		if l > 11 and inc < prev: rising = false
		prev = inc
	runner.check(rising, "level costs never drop, including into overflow")
	runner.check(b.level_for_xp(l30 + 549) == 30, "first overflow level costs 550")
	runner.check(b.level_for_xp(l30 + 550) == 31, "first overflow level reached at +550")
	runner.check(b.level_for_xp(l30 + 550 + 590) == 32, "second overflow level costs 590")
	runner.check(b.level_for_xp(20000) < 60, "20k xp stays a sane size")
	runner.approx(b.level_progress(8, 2), 0.5, 0.001, "progress halfway L2→L3")
func test_legacy_xp_table() -> void:
	var b := BalanceTable.new(); b.use_fast_table = false
	runner.check(b.level_for_xp(10) == 2, "legacy 10 xp = L2")
	runner.check(b.level_for_xp(39) == 3, "legacy 39 xp = L3")
	runner.check(b.level_for_xp(75) == 10, "legacy 75 xp = L10 (unchanged below L10)")
	runner.check(b.xp_for_level(11) == 75 + roundi(5 * BalanceTable.LATE_XP_GROWTH), "legacy late growth applies too")
func test_physics_tiers() -> void:
	var t := ObjectPhysicsTiers.new()
	runner.approx(t.mass_for(1), 3.0, 0.001, "mass s1")
	runner.approx(t.mass_for(5), 30.0, 0.001, "mass s5")
	runner.approx(t.mass_for(10), 150.0, 0.001, "mass s10")
	runner.approx(t.linear_damp_for(2), 2.0, 0.001, "drag s2")
	runner.approx(t.linear_damp_for(7), 0.0, 0.001, "drag s7")
	runner.approx(t.angular_damp_for(12), 4.0, 0.001, "angular s12")
