class_name GameModeParams
extends Resource
## GameModeParameters "Timer" (Classic) defaults.
@export var mode_id: String = "Timer"
@export var title: String = "Classic"
@export var description: String = "Get the best score in 2 minutes"
@export var player_count: int = 7
@export var duration_seconds: float = 120.0
@export var bots_respawn: bool = true
@export var kill_cooldown: float = 5.0          # GAME_KILL_COOLDOWN
@export var ranking_interval: float = 0.25
@export var bot_respawn_min_distance: float = 50.0  # MinBotRespawnDistanceFromPlayer
@export var warning_seconds: int = 10
@export var accent_color: Color = Color("FF9A01")
@export var bot_profile_names: Array[String] = ["Easy", "Normal", "Normal", "Normal", "Hard", "Hard"]
