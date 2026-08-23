extends SceneTree


func _roll(seed_v: int, axis: String, i: int, j: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d|%d" % [seed_v, axis, i, j])
	return rng.randf()


func _side_rate(seed_v: int, x0: int) -> Array:
	var ok := 0
	var n := 0
	for bx in range(x0, x0 + 6):
		for bz in range(x0, x0 + 6):
			for side in 4:
				n += 1
				match side:
					0:
						if _roll(seed_v, "h", bx, bz) < 0.72: ok += 1
					1:
						if _roll(seed_v, "v", bx + 1, bz) < 0.72: ok += 1
					2:
						if _roll(seed_v, "h", bx, bz + 1) < 0.72: ok += 1
					3:
						if _roll(seed_v, "v", bx, bz) < 0.72: ok += 1
	return [ok, n]


func _init() -> void:
	seed(20260823)
	var bad_seeds := []
	for trial in 300:
		var sv := randi()
		var near: Array = _side_rate(sv, -2)
		var far: Array = _side_rate(sv, 17)
		var near_pct := float(near[0]) / float(near[1])
		var far_pct := float(far[0]) / float(far[1])
		if far_pct < 0.3 and near_pct > 0.45:
			bad_seeds.append([sv, near_pct, far_pct])
	print("BAD_SEED_COUNT=", bad_seeds.size(), "/300")
	for b in bad_seeds.slice(0, 6):
		print("  seed=", b[0], " near=", snappedf(b[1], 0.01), " far=", snappedf(b[2], 0.01))
	quit()
