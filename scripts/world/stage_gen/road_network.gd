extends RefCounted

const DIR_N := 1
const DIR_E := 2
const DIR_S := 4
const DIR_W := 8


static func h_key(i: int, j: int) -> String:
	return "h_%d_%d" % [i, j]


static func v_key(i: int, j: int) -> String:
	return "v_%d_%d" % [i, j]


static func node_key(i: int, j: int) -> String:
	return "%d_%d" % [i, j]


static func generate(rng: RandomNumberGenerator, n: int, loop_prob: float = 0.22) -> Dictionary:
	var edges := {}
	var visited := {}
	for i in n + 1:
		for j in n + 1:
			visited[node_key(i, j)] = false
	var stack := [[0, 0]]
	visited[node_key(0, 0)] = true
	while not stack.is_empty():
		var cur: Array = stack.back()
		var ci: int = cur[0]
		var cj: int = cur[1]
		var neighbors := []
		if ci > 0 and not visited[node_key(ci - 1, cj)]:
			neighbors.append([ci - 1, cj, h_key(ci - 1, cj)])
		if ci < n and not visited[node_key(ci + 1, cj)]:
			neighbors.append([ci + 1, cj, h_key(ci, cj)])
		if cj > 0 and not visited[node_key(ci, cj - 1)]:
			neighbors.append([ci, cj - 1, v_key(ci, cj - 1)])
		if cj < n and not visited[node_key(ci, cj + 1)]:
			neighbors.append([ci, cj + 1, v_key(ci, cj)])
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var nb: Array = neighbors[rng.randi_range(0, neighbors.size() - 1)]
		edges[nb[2]] = true
		visited[node_key(nb[0], nb[1])] = true
		stack.append([nb[0], nb[1]])
	for i in n:
		for j in n + 1:
			var k := h_key(i, j)
			if not edges.has(k) and rng.randf() < loop_prob:
				edges[k] = true
	for i in n + 1:
		for j in n:
			var k := v_key(i, j)
			if not edges.has(k) and rng.randf() < loop_prob:
				edges[k] = true
	var masks := {}
	for i in n + 1:
		for j in n + 1:
			masks[node_key(i, j)] = _mask(edges, i, j, n)
	return {"n": n, "edges": edges, "masks": masks}


static func _mask(edges: Dictionary, i: int, j: int, n: int) -> int:
	var m := 0
	if j > 0 and edges.has(v_key(i, j - 1)):
		m |= DIR_N
	if i < n and edges.has(h_key(i, j)):
		m |= DIR_E
	if j < n and edges.has(v_key(i, j)):
		m |= DIR_S
	if i > 0 and edges.has(h_key(i - 1, j)):
		m |= DIR_W
	return m


static func block_has_edge(net: Dictionary, bx: int, bz: int, side: int) -> bool:
	match side:
		0:
			return net["edges"].has(h_key(bx, bz))
		1:
			return net["edges"].has(v_key(bx + 1, bz))
		2:
			return net["edges"].has(h_key(bx, bz + 1))
		3:
			return net["edges"].has(v_key(bx, bz))
	return false
