class_name GameModeParams
extends Resource
## GameModeParameters "Timer" (Classic) defaults.
@export var mode_id: String = "Timer"
@export var title: String = "Classic"
@export var description: String = "Eat everything. First to 90 m wins."
@export var player_count: int = 7
@export var duration_seconds: float = 300.0   # 5 min: lives, zones and the 90 m goal need a longer match than the original 2 min
@export var bots_respawn: bool = true
@export var lives: int = 3                       # every hole, player and bots (user request)
@export var respawn_cooldown: float = 3.0
@export var spawn_protection: float = 4.0
@export var win_diameter: float = 90.0           # first hole this wide wins the match (user request)
@export var kill_cooldown: float = 5.0          # GAME_KILL_COOLDOWN
@export var ranking_interval: float = 0.25
@export var bot_respawn_min_distance: float = 50.0  # MinBotRespawnDistanceFromPlayer
@export var warning_seconds: int = 10
@export var accent_color: Color = Color("FF9A01")
@export var bot_profile_names: Array[String] = ["Easy", "Normal", "Normal", "Normal", "Hard", "Hard"]
