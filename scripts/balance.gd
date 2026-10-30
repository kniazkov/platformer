class_name Balance
extends RefCounted

# Начальные значения прототипа: менять здесь после игровых проверок.
const STEP_WIDTH = 64.0
const STEP_DROP = 12.0
const BASE_SPEED = 210.0
const TIER_SPEED = 1.18
const BOOST = 1.85
const CROUCH = 0.82
const GRAVITY = 1600.0
const JUMP = -620.0
const STAMINA_DRAIN = 16.0
const LEVEL_SECONDS = 60.0
const BOSS_HEALTH = 3
const BOSS_RAMP = 0.025
const TELEGRAPH = 0.28

static func tier(level: int) -> float:
	return pow(TIER_SPEED, int((level - 1) / 5.0))

static func floor_y(x: float) -> float:
	return floor(x / STEP_WIDTH) * STEP_DROP
