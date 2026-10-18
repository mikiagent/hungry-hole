class_name BotProfile
extends Resource
## Mirrors Voodoo.Holeio.Game.Bots.Data.BotConfig (defaults = "Normal").
@export var profile_name: String = "Normal"
@export var starting_size: int = 1
@export var max_size: int = -1
@export var max_target_distance: float = 250.0
@export var select_closest_chance: float = 0.5
@export var select_furthest_chance: float = 0.5
@export var select_random_chance: float = 0.0
@export var target_bots_probability: float = 0.0
@export var target_player_probability: float = 0.0
@export var target_falling_object_probability: float = 1.0
@export var sudden_target_change_interval: Vector2 = Vector2(5, 10)
@export var target_change_cooldown: float = 10.0
@export var moving_target_max_pursuit: float = 10.0
@export var static_target_max_wait: float = 2.0
@export var delay_after_reaching_target: float = 1.0
@export var initial_speed_multiplier: float = 1.0
@export var final_speed_multiplier: float = 1.0
@export var target_player_if_closer_than: float = -1.0
@export var escape_player_if_closer_than: float = 3.0
@export var escape_bot_if_closer_than: float = -1.0
@export var escape_distance: float = 10.0
@export var can_respawn: bool = true
## Battle-Royale style aggression (BotBattleRoyale consts). 0 = off.
@export var aggression_ramp_seconds: float = 0.0  # 90 in BR
@export var hole_chase_duration: Vector2 = Vector2(3, 8)
@export var player_chase_duration: Vector2 = Vector2(5, 30)
@export var max_player_hunters: int = 2

## Prefer valuable objects: score = points / (distance + value_distance_bias). 0 = pure nearest.
@export var value_seeking: float = 0.0
@export var hunt_radius: float = 0.0      # chase a smaller hole inside this radius regardless of the ramp

static func easy() -> BotProfile:
	var p := BotProfile.new(); p.profile_name = "Easy"; p.max_size = 10; return p
## Classic-mode profiles are tuned up from the dumped BotConfig values (user asked for more threatening bots):
## Normal and Hard ramp aggression like BotBattleRoyale and seek valuable objects.
static func normal() -> BotProfile:
	var p := BotProfile.new()
	p.aggression_ramp_seconds = 60.0; p.value_seeking = 1.0; p.hunt_radius = 18.0
	p.final_speed_multiplier = 1.05; p.max_player_hunters = 2
	return p
static func hard() -> BotProfile:
	var p := BotProfile.new(); p.profile_name = "Hard"; p.max_size = -1
	p.select_closest_chance = 0.7; p.select_furthest_chance = 0.0; p.select_random_chance = 0.3
	p.target_change_cooldown = 5.0; p.escape_player_if_closer_than = 1.0; p.escape_bot_if_closer_than = 1.0
	p.aggression_ramp_seconds = 30.0; p.value_seeking = 1.5; p.hunt_radius = 30.0
	p.initial_speed_multiplier = 1.0; p.final_speed_multiplier = 1.12; p.max_player_hunters = 3
	return p
static func battle_royale() -> BotProfile:
	var p := hard(); p.profile_name = "BattleRoyale"; p.max_size = 16; p.aggression_ramp_seconds = 90.0; p.max_player_hunters = 2
	p.target_player_if_closer_than = 20.0; p.can_respawn = false
	return p
