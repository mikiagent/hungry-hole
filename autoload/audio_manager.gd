extends Node
## Sound library by tag. Generates simple placeholder tones until final SFX land in assets/final/sfx.
var _players: Array[AudioStreamPlayer] = []
var _streams := {}
const POOL := 12

signal sound_changed(on: bool)
var _session_mute := false   # --mute: silence this run without touching the saved setting

func _ready() -> void:
	_session_mute = OS.get_cmdline_user_args().has("--mute") or OS.get_cmdline_args().has("--mute")
	_apply_mute()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_streams = {
		"eat": _tone(880.0, 0.08, 0.25),
		"fall": _tone(300.0, 0.25, 0.15, true),
		"grow": _tone(523.0, 0.35, 0.3, false, 1046.0),
		"kill": _tone(200.0, 0.5, 0.35, true),
		"tick": _tone(1200.0, 0.05, 0.2),
		"win": _tone(660.0, 0.8, 0.3, false, 990.0),
		"lose": _tone(330.0, 0.9, 0.3, true),
	}
	for tag in _streams.keys():
		var final_path := "res://assets/final/sfx/%s.ogg" % tag
		if ResourceLoader.exists(final_path):
			_streams[tag] = load(final_path)

## Sound on/off is the saved "sound" setting; it mutes the whole Master bus (effects and any future music).
## A first launch (nothing saved) uses the project setting game/audio/sound_on_by_default: off while testing, on for releases.
func is_sound_on() -> bool:
	return bool(SaveData.get_setting("sound", ProjectSettings.get_setting("game/audio/sound_on_by_default", true)))

## Master volume, 0..1, saved as the "volume" setting.
const DEFAULT_VOLUME := 0.4
func get_volume() -> float:
	return clampf(float(SaveData.get_setting("volume", DEFAULT_VOLUME)), 0.0, 1.0)

func set_volume(v: float) -> void:
	SaveData.set_setting("volume", clampf(v, 0.0, 1.0))
	_apply_mute()

func set_sound(on: bool) -> void:
	SaveData.set_setting("sound", on)
	_apply_mute()
	sound_changed.emit(on)

func _apply_mute() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, _session_mute or not is_sound_on() or get_volume() <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(get_volume(), 0.001)))

func play(tag: String, pitch_jitter: float = 0.1) -> void:
	if _session_mute or not is_sound_on():
		return
	if not _streams.has(tag):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[tag]
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return

func _tone(freq: float, length: float, volume: float, falling := false, freq2 := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var k := t / length
		var f := freq
		if falling:
			f = lerpf(freq, freq * 0.5, k)
		elif freq2 > 0.0:
			f = freq if k < 0.5 else freq2
		var env := (1.0 - k) * volume
		var s := sin(TAU * f * t) * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
