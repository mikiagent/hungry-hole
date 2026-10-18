class_name HoleMoveConfig
extends Resource
## HoleMoveLocalConfig "Control" (default): instant acceleration, linear joystick ramp.
@export var acceleration: float = 99999.0
@export var deceleration: float = 99999.0
@export var joystick_ramp: Curve
@export var turning_curve: Curve
@export var walking_running_threshold: float = 0.5
@export var quick_turn_dot: float = -0.7
@export var quick_turn_cooldown: float = 0.5
@export var player_base_speed: float = 12.5   # HolePhysicsSettings.m_playerHoleBaseSpeed
@export var bot_base_speed: float = 10.0      # HolePhysicsSettings.m_botHoleBaseSpeed
## Confirmed by decompiling HoleMoveImprovementsService.CalculateVelocity (0x03AE646C):
## velocity = TopSpeed(level) × inputMagnitude × speedMultiplier. The 12.5/10 base speeds are not used there.
## Bots get HoleMoveRemoteConfig.BotsSpeedMultiplier, a remote value with no local default; 1.0 here.
@export var bots_speed_multiplier: float = 1.0

func top_speed(table_speed: float, is_bot: bool) -> float:
	return table_speed * (bots_speed_multiplier if is_bot else 1.0)
