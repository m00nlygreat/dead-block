extends RefCounted

const PATTERNS := [
	{
		"id": "residential_quad",
		"weight": 4.0,
		"house_slots": [[0, 0.25], [0, 0.75], [1, 0.25], [1, 0.75], [2, 0.25], [2, 0.75], [3, 0.25], [3, 0.75]],
		"tree_range": Vector2i(0, 3),
		"car_sides": [0, 1, 2, 3],
		"car_count": Vector2i(2, 4),
	},
	{
		"id": "row_houses",
		"weight": 3.0,
		"house_slots": [[0, 0.3], [0, 0.7], [2, 0.3], [2, 0.7]],
		"tree_range": Vector2i(2, 6),
		"car_sides": [1, 3],
		"car_count": Vector2i(2, 3),
	},
	{
		"id": "courtyard",
		"weight": 2.0,
		"house_slots": [[0, 0.3], [0, 0.7], [1, 0.5], [3, 0.5]],
		"tree_range": Vector2i(2, 4),
		"car_sides": [2],
		"car_count": Vector2i(1, 2),
	},
	{
		"id": "park",
		"weight": 1.5,
		"house_slots": [],
		"tree_range": Vector2i(6, 12),
		"car_sides": [],
		"car_count": Vector2i(0, 0),
	},
	{
		"id": "parking_lot",
		"weight": 1.5,
		"house_slots": [],
		"tree_range": Vector2i(0, 1),
		"car_sides": [1, 3],
		"car_count": Vector2i(4, 6),
	},
]


static func pick(rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for p in PATTERNS:
		total += p["weight"]
	var roll := rng.randf() * total
	for p in PATTERNS:
		roll -= p["weight"]
		if roll <= 0.0:
			return p
	return PATTERNS[0]
