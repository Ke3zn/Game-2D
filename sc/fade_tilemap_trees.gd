extends TileMapLayer

@export var fade_alpha: float = 0.35
@export var fade_duration: float = 0.25

func _is_tree_tile(sid: int, ac: Vector2i) -> bool:
	if sid != 2:
		return false
	if ac.y >= 23 and ac.y <= 26 and ac.x >= 15 and ac.x <= 21:
		return true
	if ac.y >= 27 and ac.y <= 30 and ac.x >= 15 and ac.x <= 29:
		return true
	return false

func _ready() -> void:
	if not tile_set:
		return
	var tree_cells := {}
	for cell in get_used_cells():
		var sid := get_cell_source_id(cell)
		var ac := get_cell_atlas_coords(cell)
		if _is_tree_tile(sid, ac):
			tree_cells[cell] = Vector3i(sid, ac.x, ac.y)

	if tree_cells.is_empty():
		return

	var src := tile_set.get_source(2) as TileSetAtlasSource
	if not src or not src.texture:
		return
	var tex: Texture2D = src.texture
	var tile_sz: Vector2i = tile_set.tile_size

	var visited := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var parent_node := get_parent()

	for start_cell in tree_cells.keys():
		if visited.has(start_cell):
			continue
		var cluster: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_cell]
		visited[start_cell] = true
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			cluster.append(c)
			for d in dirs:
				var nc: Vector2i = c + d
				if tree_cells.has(nc) and not visited.has(nc):
					visited[nc] = true
					queue.append(nc)

		var min_pos := Vector2(INF, INF)
		var max_pos := Vector2(-INF, -INF)
		for c in cluster:
			var wpos := to_global(map_to_local(c))
			min_pos.x = minf(min_pos.x, wpos.x - tile_sz.x * 0.5)
			min_pos.y = minf(min_pos.y, wpos.y - tile_sz.y * 0.5)
			max_pos.x = maxf(max_pos.x, wpos.x + tile_sz.x * 0.5)
			max_pos.y = maxf(max_pos.y, wpos.y + tile_sz.y * 0.5)

		var center := (min_pos + max_pos) * 0.5
		var box_size := max_pos - min_pos

		var obj_node := Node2D.new()
		obj_node.name = "TileFade_%s_%d_%d" % [name, start_cell.x, start_cell.y]
		obj_node.global_position = center
		obj_node.z_index = 3

		for c in cluster:
			var info: Vector3i = tree_cells[c]
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.region_enabled = true
			sp.region_rect = Rect2(info.y * tile_sz.x, info.z * tile_sz.y, tile_sz.x, tile_sz.y)
			sp.position = to_global(map_to_local(c)) - center
			obj_node.add_child(sp)
			erase_cell(c)

		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = box_size
		col.shape = rect
		area.add_child(col)
		obj_node.add_child(area)

		var state := {"count": 0, "tween": null}
		area.body_entered.connect(func(body: Node2D):
			if body.name == "Player" or body is CharacterBody2D:
				state["count"] += 1
				if state["tween"] and is_instance_valid(state["tween"]):
					state["tween"].kill()
				var tw := obj_node.create_tween()
				tw.tween_property(obj_node, "modulate:a", fade_alpha, fade_duration)
				state["tween"] = tw
		)
		area.body_exited.connect(func(body: Node2D):
			if body.name == "Player" or body is CharacterBody2D:
				state["count"] = max(0, state["count"] - 1)
				if state["count"] == 0:
					if state["tween"] and is_instance_valid(state["tween"]):
						state["tween"].kill()
					var tw := obj_node.create_tween()
					tw.tween_property(obj_node, "modulate:a", 1.0, fade_duration)
					state["tween"] = tw
		)

		if parent_node:
			parent_node.call_deferred("add_child", obj_node)
		else:
			call_deferred("add_child", obj_node)
