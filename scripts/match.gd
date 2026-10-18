class_name Match
extends Node
## Timer-mode match: spawns holes, runs the clock, ranking, kills, end of game.
enum Result { UNDEFINED = -1, SUCCESS = 0, TIMEOUT = 1, EATEN = 2 }
@export var params: GameModeParams
@export var balance: BalanceTable
var holes: Array[Hole] = []
var bots: Array[BotController] = []
var player: Hole
var playing := false
var time_left := 0.0
var map
var map_bounds := Rect2(-100, -100, 200, 200)
var _rank_accum := 0.0
var _last_kill_time := -100.0
var _streak := 0
var _eatables: Array = []
var _eatables_dirty := true
var result := Result.UNDEFINED
var hole_scene: PackedScene = preload("res://scenes/hole.tscn")
const PLAYER_COLORS := ["3EA8FB", "33E930", "F08A0B", "DD222E", "F2448E", "704EFF", "FFCC00", "17EC99", "9B36E4", "4EFFED"]
const BOT_NAMES := ["Pepper", "Lara", "Rosix", "Merlino", "Danah", "Nepyx", "Soria", "Koshi", "Flagellum", "Urukagal"]

func setup(map_node, bounds: Rect2) -> void:
	if params == null: params = GameModeParams.new()
	if balance == null: balance = BalanceTable.new()
	map = map_node
	map_bounds = bounds
	time_left = params.duration_seconds

func spawn_holes(spawn_groups: Array) -> void:
	var groups := spawn_groups.duplicate()
	groups.shuffle()
	player = _make_hole(0, false, SaveData.get_player_name(), Color(PLAYER_COLORS[0]), groups[0])
	var profiles := {"Easy": BotProfile.easy(), "Normal": BotProfile.normal(), "Hard": BotProfile.hard(), "BattleRoyale": BotProfile.battle_royale()}
	for i in range(params.player_count - 1):
		var g: Array = groups[1 + (i % (groups.size() - 1))]  # never the player's group
		var h := _make_hole(i + 1, true, BOT_NAMES[i % BOT_NAMES.size()], Color(PLAYER_COLORS[(i + 1) % PLAYER_COLORS.size()]), g)
		var bc := BotController.new()
		var pname: String = params.bot_profile_names[i % params.bot_profile_names.size()]
		add_child(bc)
		bc.setup(h, self, profiles.get(pname, BotProfile.normal()))
		bots.append(bc)
		h.died.connect(_on_bot_died.bind(h))
	player.died.connect(_on_player_died)

func _make_hole(id: int, is_bot: bool, nm: String, col: Color, group: Array) -> Hole:
	var h := hole_scene.instantiate() as Hole
	h.player_id = id; h.is_bot = is_bot; h.display_name = nm; h.color = col; h.balance = balance
	map.add_child(h)
	var p: Vector3 = group[randi() % group.size()]
	h.global_position = Vector3(p.x, 0, p.z)
	holes.append(h)
	return h

func start() -> void:
	playing = true
	Events.match_started.emit()

func eatables_snapshot() -> Array:
	if _eatables_dirty or _eatables.size() == 0:
		_eatables = get_tree().get_nodes_in_group("eatable").filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion())
		_eatables_dirty = false
	return _eatables

func _process(delta: float) -> void:
	if not playing: return
	time_left -= delta
	Events.match_time_changed.emit(time_left)
	if int(time_left) != int(time_left + delta) and time_left <= params.warning_seconds and time_left > 0:
		AudioManager.play("tick", 0.0)
	_rank_accum += delta
	if _rank_accum >= params.ranking_interval:
		_rank_accum = 0.0
		_eatables_dirty = true
		_update_ranking()
	if time_left <= 0.0:
		end(Result.TIMEOUT)

func _physics_process(_delta: float) -> void:
	if playing: _check_hole_kills()

func _update_ranking() -> void:
	var alive := holes.duplicate()
	alive.sort_custom(func(a: Hole, b: Hole): return a.points > b.points if a.points != b.points else a.player_id < b.player_id)
	for i in alive.size():
		alive[i].rank = i + 1
		alive[i].set_crown(i == 0 and not alive[i].is_dead)
	Events.ranking_changed.emit(alive)

func _check_hole_kills() -> void:
	for a in holes:
		if a.is_dead: continue
		for b in holes:
			if a == b or b.is_dead or b.level >= a.level: continue
			var d := a.global_position.distance_to(b.global_position)
			# swallowed once more than half of the smaller hole is inside the bigger one
			if d + b.radius() * 0.5 < a.radius():
				process_kill(a, b)

func process_kill(killer: Hole, victim: Hole) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	victim.die(killer)
	var reward := maxi(victim.points / 4, victim.level * 2)  # BotSizeToPoints is remote-only; inferred reward
	killer.add_points(reward); killer.add_xp(victim.level * 3)
	killer.kills += 1
	if now - _last_kill_time <= params.kill_cooldown: _streak += 1
	else: _streak = 1
	_last_kill_time = now
	Events.hole_killed.emit(killer, victim)
	if not killer.is_bot:
		Events.kill_streak.emit(killer, _streak)
	AudioManager.play("kill")
	if victim.is_bot and params.bots_respawn:
		get_tree().create_timer(3.0).timeout.connect(func(): _respawn_bot(victim))

func _respawn_bot(h: Hole) -> void:
	if not playing or not is_instance_valid(h): return
	var best := Vector3.ZERO; var bd := -1.0
	for i in 20:
		var p := Vector3(randf_range(map_bounds.position.x + 5, map_bounds.end.x - 5), 0, randf_range(map_bounds.position.y + 5, map_bounds.end.y - 5))
		var d := p.distance_to(player.global_position)
		if d > bd: bd = d; best = p
		if d >= params.bot_respawn_min_distance: break
	h.respawn(best)

func _on_bot_died(_killer, _h) -> void:
	pass

func _on_player_died(killer) -> void:
	Events.player_eaten.emit(killer)
	end(Result.EATEN)

func end(r: int) -> void:
	if not playing: return
	playing = false
	result = r
	_update_ranking()
	var ranking := holes.duplicate()
	ranking.sort_custom(func(a: Hole, b: Hole): return a.points > b.points)
	SaveData.set_best_score(params.mode_id, player.points)
	if r == Result.TIMEOUT and ranking[0] == player: result = Result.SUCCESS
	AudioManager.play("win" if result == Result.SUCCESS else "lose", 0.0)
	Events.match_ended.emit(result, ranking)
