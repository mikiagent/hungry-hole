extends Node
## Global signal bus (replaces the original's C# events / UniTask signals).
signal object_captured(hole, falling_object, points: int, xp: int)
signal hole_level_up(hole, level: int)
signal hole_killed(killer, victim)
signal kill_streak(killer, streak: int)
signal ranking_changed(holes: Array)
signal match_started()
signal match_time_changed(time_left: float)
signal match_ended(result: int, ranking: Array)
signal player_eaten(killer)
signal lives_changed(hole, lives: int)
