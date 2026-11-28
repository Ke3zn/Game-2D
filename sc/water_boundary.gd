extends TileMapLayer

# Membentuk batas tabrakan otomatis di seluruh tepi perairan/lautan (`Air`)
# yang tidak tertutup daratan (`Tanah`, `Pasir Pantai`) maupun jembatan kayu.
func _ready() -> void:
	var parent_node := get_parent()
	if not parent_node:
		return

	var tanah := parent_node.get_node_or_null("Tanah") as TileMapLayer
	var pasir := parent_node.get_node_or_null("Pasir Pantai") as TileMapLayer
	var game_root := parent_node.get_parent()
	var bridge := game_root.get_node_or_null("TopDownSimpleSummerPropWoodenBridgeHorizontal") as Node2D if game_root else null

	# Area aman jalur jembatan kayu (x=[772..908], y=[302..348])
	var bridge_walk_rect := Rect2(772.0, 302.0, 136.0, 46.0)
	if bridge:
		bridge_walk_rect = Rect2(bridge.global_position - Vector2(68.0, 26.0), Vector2(136.0, 48.0))

	var cell_size := Vector2(tile_set.tile_size) if tile_set else Vector2(16.0, 16.0)
	var water_cells := {}

	for cell in get_used_cells():
		var wp := to_global(map_to_local(cell))
		if bridge_walk_rect.has_point(wp):
			continue
		if _is_land_at(wp, tanah, pasir):
			continue
		water_cells[cell] = true

	if water_cells.is_empty():
		return

	# Gabungkan seluruh tile perairan menjadi persegi panjang terkompresi agar ringan & rapat
	var visited := {}
	var sorted_cells: Array = water_cells.keys()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)

	var body := StaticBody2D.new()
	body.name = "WaterBoundaryBody"
	body.collision_layer = 1
	body.collision_mask = 0

	for start: Vector2i in sorted_cells:
		if visited.has(start):
			continue
		var w := 1
		while water_cells.has(start + Vector2i(w, 0)) and not visited.has(start + Vector2i(w, 0)):
			w += 1
		var h := 1
		while true:
			var next_row_ok := true
			for x in range(w):
				var c := start + Vector2i(x, h)
				if not water_cells.has(c) or visited.has(c):
					next_row_ok = false
					break
			if not next_row_ok:
				break
			h += 1
		for y in range(h):
			for x in range(w):
				visited[start + Vector2i(x, y)] = true

		var tl_local := map_to_local(start) - cell_size * 0.5
		var br_local := map_to_local(start + Vector2i(w - 1, h - 1)) + cell_size * 0.5
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = br_local - tl_local
		col.shape = rect
		col.position = (tl_local + br_local) * 0.5
		body.add_child(col)

	add_child(body)

func _is_land_at(world_pos: Vector2, tanah: TileMapLayer, pasir: TileMapLayer) -> bool:
	if tanah:
		var tc := tanah.local_to_map(tanah.to_local(world_pos))
		if tanah.get_cell_source_id(tc) != -1:
			return true
	if pasir:
		var pc := pasir.local_to_map(pasir.to_local(world_pos))
		if pasir.get_cell_source_id(pc) != -1:
			return true
	return false
