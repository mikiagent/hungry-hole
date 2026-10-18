extends Node
## PlayerPrefs replacement: best score, name, settings.
const PATH := "user://save.cfg"
var cfg := ConfigFile.new()

func _ready() -> void:
	cfg.load(PATH)

func get_best_score(mode: String) -> int:
	return int(cfg.get_value("scores", mode, 0))

func set_best_score(mode: String, score: int) -> void:
	if score > get_best_score(mode):
		cfg.set_value("scores", mode, score)
		cfg.save(PATH)

func get_player_name() -> String:
	return str(cfg.get_value("profile", "name", "You"))

func get_setting(key: String, default_value) :
	return cfg.get_value("settings", key, default_value)

func set_setting(key: String, value) -> void:
	cfg.set_value("settings", key, value)
	cfg.save(PATH)
