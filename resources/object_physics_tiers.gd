class_name ObjectPhysicsTiers
extends Resource
## Rigidbody params per size_required (GameBalanceSettings.m_fallingObjectsPhysicConfig).
@export var mass: Array[float] = [3, 6, 15, 20, 30, 40, 60, 90, 120, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250]
@export var linear_damp: Array[float] = [2.0, 2.0, 0.05, 0.05, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
@export var angular_damp: Array[float] = [0.05, 0.05, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]

func mass_for(size_required: int) -> float:
	return mass[clampi(size_required, 1, mass.size()) - 1]
func linear_damp_for(size_required: int) -> float:
	return linear_damp[clampi(size_required, 1, linear_damp.size()) - 1]
func angular_damp_for(size_required: int) -> float:
	return angular_damp[clampi(size_required, 1, angular_damp.size()) - 1]
