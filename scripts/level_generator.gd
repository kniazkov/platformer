class_name LevelGenerator
extends RefCounted

# Независимые безопасные секции: препятствия не накладываются друг на друга.
# Одинаковый seed и номер секции всегда дают ту же карту, включая бесконечный бой.
static func section(seed_value: int, index: int, tier: float, boss: bool) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value + index * 104729
	var length = 1024.0 * tier
	var start = index * length
	var kind = rng.randi_range(0, 2)
	var obstacle_x = start + 512.0 * tier
	var objects: Array = []
	# Голда лежит на безопасных подходах; прыжки остаются добровольным риском.
	for offset in [160.0, 280.0, 820.0]:
		objects.append({"kind": "gold", "x": start + offset * tier, "used": false})
	objects.append({"kind": "energy", "x": start + 380.0 * tier, "used": false})
	objects.append({"kind": ["gap", "spikes", "beam"][kind], "x": obstacle_x,
		"width": (128.0 if kind == 0 else 64.0) * tier, "used": false})
	if index > 0 and index % (5 if boss else 3) == 1:
		objects.append({"kind": "chase", "x": start + 60.0 * tier, "used": false})
	return {"objects": objects, "length": length}
