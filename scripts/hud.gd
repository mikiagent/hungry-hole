class_name HUD
extends CanvasLayer
## Timer, ranking, size/XP, +N popups, kill streak, joystick, pre-game and game-over panels.
var match_ref: Match
var player: Hole
var _timer_label: Label
var _rank_box: VBoxContainer
var _size_label: Label
var _xp_bar: ProgressBar
var _kill_label: Label
var _center_label: Label
var _gameover: Panel
var _joystick: Control
var _joy_active := false; var _joy_origin := Vector2.ZERO; var _joy_cur := Vector2.ZERO
var _camera: Camera3D
var _killer_name := ""
var _lives_label: Label
var _goal_label: Label
var _respawn_label: Label
var _respawn_at := 0.0
var _winner: Hole
var _tip_label: Label
var _pause_panel: PanelContainer
var _confetti: CPUParticles2D
const KILL_KEYS := ["TXT_KILL_0", "TXT_KILL_1", "TXT_KILL_2", "TXT_KILL_3", "TXT_KILL_4", "TXT_KILL_5", "TXT_KILL_6", "TXT_KILL_7", "TXT_KILL_8", "TXT_KILL_9"]
const TIP_KEYS := ["TXT_TIP_0", "TXT_TIP_1", "TXT_TIP_2", "TXT_TIP_3", "TXT_TIP_4", "TXT_TIP_5", "TXT_TIP_6"]
const RANK_COLORS := ["FFD93D", "D9D2C5", "C98A4B", "FFF8E7", "FFF8E7", "FFF8E7", "FFF8E7"]

func setup(m: Match, cam: Camera3D) -> void:
	match_ref = m; player = m.player; _camera = cam
	_build()
	Events.match_time_changed.connect(_on_time)
	Events.ranking_changed.connect(_on_ranking)
	Events.object_captured.connect(_on_captured)
	Events.kill_streak.connect(_on_kill_streak)
	Events.match_ended.connect(_on_match_ended)
	Events.player_eaten.connect(func(k):
		_killer_name = k.display_name if k else ""
		if player.lives > 0: _respawn_at = Time.get_ticks_msec() / 1000.0 + match_ref.params.respawn_cooldown)
	Events.lives_changed.connect(func(_h, _l): _refresh_lives())
	player.level_changed.connect(_on_level)
	_on_level(player.level)

func _style_label(l: Label, size: int, color := Color.WHITE) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("2C2F48"))
	l.add_theme_constant_override("outline_size", int(size * 0.18))

func _panel_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.set_corner_radius_all(28); s.content_margin_left = 24; s.content_margin_right = 24; s.content_margin_top = 16; s.content_margin_bottom = 16
	return s

func _build() -> void:
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	# timer
	var tp := PanelContainer.new(); tp.add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.18, 0.28, 0.75)))
	tp.anchor_left = 0.5; tp.anchor_right = 0.5; tp.offset_left = -110; tp.offset_right = 110; tp.offset_top = 70; tp.custom_minimum_size = Vector2(220, 90); root.add_child(tp)
	_timer_label = Label.new(); _timer_label.text = "2:00"; _timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(_timer_label, 56); tp.add_child(_timer_label)
	# ranking
	var rp := PanelContainer.new(); rp.add_theme_stylebox_override("panel", _panel_style(Color(0.17, 0.18, 0.28, 0.6)))
	rp.anchor_left = 1.0; rp.anchor_right = 1.0; rp.offset_left = -380; rp.offset_right = -30; rp.offset_top = 190; rp.custom_minimum_size = Vector2(350, 0); root.add_child(rp)
	_rank_box = VBoxContainer.new(); rp.add_child(_rank_box)
	# size + xp
	var sp := VBoxContainer.new(); sp.position = Vector2(40, 70); root.add_child(sp)
	_size_label = Label.new(); _style_label(_size_label, 44, Color("FFD93D")); sp.add_child(_size_label)
	_xp_bar = ProgressBar.new(); _xp_bar.custom_minimum_size = Vector2(260, 26); _xp_bar.show_percentage = false; _xp_bar.max_value = 1.0
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.17, 0.18, 0.28, 0.7); bg.set_corner_radius_all(13)
	var fg := StyleBoxFlat.new(); fg.bg_color = Color("6BCB77"); fg.set_corner_radius_all(13)
	_xp_bar.add_theme_stylebox_override("background", bg); _xp_bar.add_theme_stylebox_override("fill", fg); sp.add_child(_xp_bar)
	_lives_label = Label.new(); _style_label(_lives_label, 40, Color("FF5252")); sp.add_child(_lives_label)
	_goal_label = Label.new(); _style_label(_goal_label, 28, Color("FFF8E7")); sp.add_child(_goal_label)
	_respawn_label = Label.new(); _respawn_label.set_anchors_preset(Control.PRESET_CENTER); _respawn_label.position = Vector2(0, 760); _respawn_label.size = Vector2(1080, 140)
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(_respawn_label, 80, Color("FFD93D")); _respawn_label.visible = false; root.add_child(_respawn_label)
	# kill text
	_kill_label = Label.new(); _kill_label.set_anchors_preset(Control.PRESET_CENTER_TOP); _kill_label.position = Vector2(0, 420); _kill_label.size = Vector2(1080, 120)
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(_kill_label, 96, Color("FF5252")); _kill_label.modulate.a = 0.0; root.add_child(_kill_label)
	# center text (tap to start / game over title)
	_center_label = Label.new(); _center_label.set_anchors_preset(Control.PRESET_CENTER); _center_label.position = Vector2(0, 820); _center_label.size = Vector2(1080, 200)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(_center_label, 88); root.add_child(_center_label)
	# joystick overlay
	_joystick = Control.new(); _joystick.set_anchors_preset(Control.PRESET_FULL_RECT); _joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE; _joystick.draw.connect(_draw_joystick); root.add_child(_joystick)
	# loading tip under "Tap to start"
	_tip_label = Label.new(); _tip_label.set_anchors_preset(Control.PRESET_CENTER); _tip_label.position = Vector2(60, 1010); _tip_label.size = Vector2(960, 80)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD; _style_label(_tip_label, 38, Color("FFF8E7")); root.add_child(_tip_label)
	_tip_label.text = tr(TIP_KEYS.pick_random())
	# confetti (victory)
	_confetti = CPUParticles2D.new(); _confetti.position = Vector2(540, -20); _confetti.amount = 160; _confetti.lifetime = 3.0; _confetti.one_shot = true; _confetti.emitting = false
	_confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE; _confetti.emission_rect_extents = Vector2(540, 10); _confetti.gravity = Vector2(0, 600)
	_confetti.initial_velocity_min = 50; _confetti.initial_velocity_max = 250; _confetti.angular_velocity_min = -360; _confetti.angular_velocity_max = 360
	_confetti.scale_amount_min = 8; _confetti.scale_amount_max = 16
	var grad := Gradient.new(); grad.colors = PackedColorArray([Color("FF6B6B"), Color("FFD93D"), Color("6BCB77"), Color("4D96FF"), Color("B06BFF")]); grad.offsets = PackedFloat32Array([0, 0.25, 0.5, 0.75, 1])
	_confetti.color_initial_ramp = grad; root.add_child(_confetti)
	# pause panel
	_pause_panel = PanelContainer.new(); _pause_panel.add_theme_stylebox_override("panel", _panel_style(Color("FFF8E7"))); _pause_panel.position = Vector2(240, 700); _pause_panel.custom_minimum_size = Vector2(600, 420); _pause_panel.visible = false
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS; root.add_child(_pause_panel)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 24); _pause_panel.add_child(pv)
	var pt := Label.new(); pt.text = tr("TXT_PAUSED"); pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(pt, 72, Color("FF9A01")); pv.add_child(pt)
	var snd := CheckButton.new(); snd.text = tr("TXT_SOUND"); snd.button_pressed = SaveData.get_setting("sound", true); snd.add_theme_font_size_override("font_size", 44); snd.add_theme_color_override("font_color", Color("2C2F48"))
	snd.toggled.connect(func(on): if on != AudioManager.is_sound_on(): AudioManager.set_sound(on)); pv.add_child(snd)
	AudioManager.sound_changed.connect(func(on): snd.set_pressed_no_signal(on))
	# always-visible sound toggle under the leaderboard
	var sb := Button.new(); sb.focus_mode = Control.FOCUS_NONE; sb.position = Vector2(820, 540); sb.custom_minimum_size = Vector2(230, 84)
	sb.add_theme_font_size_override("font_size", 38); sb.add_theme_color_override("font_color", Color.WHITE); sb.add_theme_color_override("font_hover_color", Color.WHITE)
	var sbs := _panel_style(Color(0.17, 0.18, 0.28, 0.75)); sb.add_theme_stylebox_override("normal", sbs); sb.add_theme_stylebox_override("hover", sbs); sb.add_theme_stylebox_override("pressed", sbs)
	var label_for := func(on: bool) -> String: return tr("TXT_SOUND_ON") if on else tr("TXT_SOUND_OFF")
	sb.text = label_for.call(AudioManager.is_sound_on())
	sb.pressed.connect(func(): AudioManager.set_sound(not AudioManager.is_sound_on()))
	AudioManager.sound_changed.connect(func(on): sb.text = label_for.call(on))
	root.add_child(sb)
	var rb := Button.new(); rb.text = tr("TXT_RESUME"); rb.add_theme_font_size_override("font_size", 48); rb.custom_minimum_size = Vector2(0, 110)
	var rbs := _panel_style(Color("6BCB77")); rb.add_theme_stylebox_override("normal", rbs); rb.add_theme_stylebox_override("hover", rbs); rb.add_theme_stylebox_override("pressed", _panel_style(Color("4DA85A")))
	rb.pressed.connect(func(): set_paused(false)); pv.add_child(rb)
	# game over panel
	_gameover = Panel.new(); _gameover.add_theme_stylebox_override("panel", _panel_style(Color("FFF8E7"))); _gameover.position = Vector2(90, 520); _gameover.size = Vector2(900, 980); _gameover.visible = false; root.add_child(_gameover)

func show_center(text: String) -> void:
	_center_label.text = text
	_center_label.visible = text != ""
	if _tip_label: _tip_label.visible = text != ""

func toast(text: String) -> void:
	var l := Label.new(); l.text = text; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, 330); l.size = Vector2(1080, 100); _style_label(l, 60, Color("6BCB77"))
	add_child(l)
	var tw := l.create_tween(); tw.tween_property(l, "modulate:a", 1.0, 0.2).from(0.0); tw.tween_interval(2.0); tw.tween_property(l, "modulate:a", 0.0, 0.5); tw.tween_callback(l.queue_free)

func set_paused(on: bool) -> void:
	get_tree().paused = on
	_pause_panel.visible = on

func _tombstone() -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, 220)
	c.draw.connect(func():
		var cx := 450.0
		c.draw_rect(Rect2(cx - 230, 170, 460, 40), Color("8BD450"))
		c.draw_circle(Vector2(cx, 80), 90, Color("B0BEC5"))
		c.draw_rect(Rect2(cx - 90, 80, 180, 100), Color("B0BEC5"))
		c.draw_rect(Rect2(cx - 70, 70, 140, 50), Color("90A4AE"))
		c.draw_string(preload("res://assets/fonts/fredoka_bold.tres"), Vector2(cx - 60, 108), "RIP", HORIZONTAL_ALIGNMENT_CENTER, 120, 36, Color("FFF8E7")))
	return c

func _on_time(t: float) -> void:
	var s := maxi(int(ceil(t)), 0)
	_timer_label.text = "%d:%02d" % [s / 60, s % 60]
	_timer_label.add_theme_color_override("font_color", Color("FF5252") if s <= match_ref.params.warning_seconds else Color.WHITE)

func _on_level(level: int) -> void:
	_size_label.text = tr("TXT_GAME_LEVEL") % level

func _refresh_lives() -> void:
	if _lives_label: _lives_label.text = "♥".repeat(maxi(player.lives, 0)) + "♡".repeat(maxi(match_ref.params.lives - player.lives, 0))

func _process(_d: float) -> void:
	if player: _xp_bar.value = player.balance.level_progress(player.xp, player.level)
	if _lives_label and _lives_label.text == "": _refresh_lives()
	if _goal_label: _goal_label.text = "%.0f / %d m" % [player.size, int(match_ref.params.win_diameter)]
	var left := _respawn_at - Time.get_ticks_msec() / 1000.0
	_respawn_label.visible = player.is_dead and player.lives > 0 and left > 0.0
	if _respawn_label.visible: _respawn_label.text = tr("TXT_RESPAWN_IN") % int(ceil(left))
	_joystick.queue_redraw()

func _on_ranking(holes: Array) -> void:
	for c in _rank_box.get_children(): c.queue_free()
	for i in mini(holes.size(), 7):
		var h: Hole = holes[i]
		var row: HBoxContainer = HBoxContainer.new()
		var pos := Label.new(); pos.text = "%d." % (i + 1); pos.custom_minimum_size.x = 60; _style_label(pos, 30, Color(RANK_COLORS[i])); row.add_child(pos)
		var nm := Label.new(); nm.text = h.display_name + (" (dead)" if h.is_dead else ""); nm.custom_minimum_size.x = 170; nm.clip_text = true; _style_label(nm, 30, h.color if h == player else Color.WHITE); row.add_child(nm)
		var sc := Label.new(); sc.text = str(h.points); sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _style_label(sc, 30); row.add_child(sc)
		_rank_box.add_child(row)

func _on_captured(hole, fo, points: int, _xp: int) -> void:
	if hole != player or points <= 0: return
	var l := Label3D.new()
	l.text = "+%d" % points; l.font_size = 40; l.outline_size = 10; l.modulate = Color("FFD93D"); l.outline_modulate = Color("2C2F48")
	l.font = preload("res://assets/fonts/fredoka_bold.tres")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.pixel_size = 0.012 + player.radius() * 0.003
	hole.get_parent().add_child(l)
	l.global_position = Vector3(fo.global_position.x, 1.0, fo.global_position.z)
	var tw := l.create_tween(); tw.tween_property(l, "position:y", 2.5 + player.radius() * 0.3, 0.7); tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2); tw.tween_callback(l.queue_free)

func _on_kill_streak(_k, streak: int) -> void:
	_kill_label.text = tr(KILL_KEYS[clampi(streak - 1, 0, KILL_KEYS.size() - 1)])
	_kill_label.modulate.a = 1.0; _kill_label.scale = Vector2(1.3, 1.3); _kill_label.pivot_offset = _kill_label.size / 2
	var tw := create_tween(); tw.tween_property(_kill_label, "scale", Vector2.ONE, 0.15); tw.tween_property(_kill_label, "modulate:a", 0.0, 0.6).set_delay(0.8)

func _draw_joystick() -> void:
	if not _joy_active: return
	_joystick.draw_circle(_joy_origin, 120, Color(1, 1, 1, 0.25)); _joystick.draw_arc(_joy_origin, 120, 0, TAU, 48, Color(1, 1, 1, 0.6), 6)
	var v := (_joy_cur - _joy_origin); if v.length() > 120: v = v.normalized() * 120
	_joystick.draw_circle(_joy_origin + v, 48, Color(1, 1, 1, 0.8))

func on_joystick(active: bool, origin: Vector2, cur: Vector2) -> void:
	_joy_active = active; _joy_origin = origin; _joy_cur = cur

func _on_match_ended(result: int, ranking: Array) -> void:
	var title: String = tr({Match.Result.SUCCESS: "TXT_GAME_OVER_VICTORY", Match.Result.TIMEOUT: "TXT_GAME_OVER_TIME_OUT", Match.Result.EATEN: "TXT_GAME_OVER_EATEN", Match.Result.RIVAL_WON: "TXT_GAME_OVER_RIVAL"}.get(result, "TXT_GAME_OVER_TIME_OUT"))
	for c in _gameover.get_children(): c.queue_free()
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_FULL_RECT); v.add_theme_constant_override("separation", 14); _gameover.add_child(v)
	var t := Label.new(); t.text = title; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(t, 96, Color("FF9A01") if result != Match.Result.EATEN else Color("FF5252")); v.add_child(t)
	if result == Match.Result.EATEN:
		var stone := _tombstone(); v.add_child(stone)
		var e := Label.new(); e.text = tr("TXT_GAME_EATEN_BY") % (_killer_name if _killer_name != "" else "?"); e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(e, 34, Color("2C2F48")); v.add_child(e)
	if result == Match.Result.SUCCESS and _confetti:
		_confetti.restart(); _confetti.emitting = true
	var r := Label.new(); r.text = tr("TXT_GAME_RANKING"); r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(r, 48, Color("2C2F48")); v.add_child(r)
	for i in mini(ranking.size(), 7):
		var h: Hole = ranking[i]
		var row := HBoxContainer.new(); v.add_child(row)
		var pos := Label.new(); pos.text = "%d." % (i + 1); pos.custom_minimum_size.x = 80; _style_label(pos, 40, Color(RANK_COLORS[i])); row.add_child(pos)
		var nm := Label.new(); nm.text = h.display_name; nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _style_label(nm, 40, h.color if h == player else Color("2C3E50")); row.add_child(nm)
		var sc := Label.new(); sc.text = "%d pts" % h.points; _style_label(sc, 40, Color("2C3E50")); row.add_child(sc)
	var best := Label.new(); best.text = tr("TXT_BEST") % SaveData.get_best_score(match_ref.params.mode_id); best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(best, 32, Color("2C3E50")); v.add_child(best)
	var hint := Label.new(); hint.text = tr("TXT_TAP_CONTINUE"); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _style_label(hint, 36, Color("FF9A01")); v.add_child(hint)
	_gameover.visible = true
