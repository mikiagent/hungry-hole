class_name BalanceTable
extends Resource
## Level → XP / Size / Speed. Defaults = Hole.io "Legacy" GameBalanceSettings (evidence/assets/scriptableobjects).
@export var xp_required: Array[int] = [0, 10, 20, 40, 50, 55, 60, 65, 70, 75, 80, 85, 90, 100, 110, 120, 150, 200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400, 420, 440]
## Diameters. Start at 1.2 m (SurgeRebalanced also starts at 1.2) and grow ×1.145 per level to ~60 m at level 30 (user: start smaller).
@export var size: Array[float] = [1.2, 1.37, 1.57, 1.8, 2.06, 2.36, 2.7, 3.1, 3.55, 4.06, 4.65, 5.32, 6.09, 6.98, 7.99, 9.15, 10.47, 11.99, 13.73, 15.72, 18.0, 20.61, 23.6, 27.02, 30.94, 35.43, 40.56, 46.44, 53.18, 60.89]
## Speed keeps the original speed-by-size relation (Legacy table: size 2 -> 6.09, size 40 -> 39.06): speed = 4.36 + 0.868 * size.
@export var speed: Array[float] = [5.4, 5.55, 5.72, 5.92, 6.15, 6.41, 6.7, 7.05, 7.44, 7.88, 8.4, 8.98, 9.65, 10.42, 11.3, 12.3, 13.45, 14.77, 16.28, 18.0, 19.98, 22.25, 24.84, 27.81, 31.22, 35.11, 39.57, 44.67, 50.52, 57.21]
## Timer mode uses the original "FastProgression" XP table (TimerXPTableData, 40 levels), first 30 levels.
## Levelling is slowed toward half speed from level 10 (x1 at L10 rising to x2 at L20+) so the smaller 1.2 m start is not starved
## (user asked for half-speed levelling, then for smaller starting holes).
@export var xp_table_fast: Array[int] = [0, 4, 12, 22, 31, 41, 52, 63, 75, 87, 110, 136, 165, 197, 232, 272, 314, 360, 408, 460, 492, 524, 556, 588, 620, 652, 684, 716, 748, 780]
@export var use_fast_table: bool = true
## Raised from the original 20 (user request): sizes and speeds continue the original +2 / +1.735 per level steps.
@export var max_level: int = 30
## Past max_level holes keep growing (user: a champion must be able to eat everything): each extra level costs
## OVERFLOW_XP and multiplies the diameter by OVERFLOW_GROWTH. Speed stays at the max-level value.
const OVERFLOW_XP := 40
const OVERFLOW_GROWTH := 1.03

## Smallest level whose opening a footprint of this horizontal diagonal can pass through.
func level_for_footprint(diagonal: float) -> int:
	for l in range(1, level_count() + 200):
		if size_for_level(l) >= diagonal * 1.02:
			return l
	return level_count() + 200

func level_count() -> int:
	return min(max_level, size.size())

func size_for_level(level: int) -> float:
	var n := level_count()
	if level > n:
		return size[n - 1] * pow(OVERFLOW_GROWTH, level - n)
	return size[clampi(level, 1, n) - 1]

func speed_for_level(level: int) -> float:
	return speed[clampi(level, 1, level_count()) - 1]

## XP required to *reach* `level` (cumulative). Level 1 = 0.
func xp_for_level(level: int) -> int:
	var t := xp_table_fast if use_fast_table else xp_required
	if level <= 1:
		return 0
	var n := mini(level_count(), t.size())
	if level > n:
		return t[n - 1] + (level - n) * OVERFLOW_XP
	return t[level - 1]

## Level reached for a cumulative XP value.
func level_for_xp(xp: int) -> int:
	var lvl := 1
	for l in range(2, level_count() + 1):
		var need := xp_for_level(l)
		if need >= 0 and xp >= need:
			lvl = l
	if lvl == level_count():
		lvl += maxi(0, (xp - xp_for_level(level_count())) / OVERFLOW_XP)
	return lvl

func level_progress(xp: int, level: int) -> float:
	var a := xp_for_level(level)
	var b := xp_for_level(level + 1)
	if b <= a:
		return 1.0
	return clampf(float(xp - a) / float(b - a), 0.0, 1.0)
