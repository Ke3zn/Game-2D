extends Control

@export var map_radius: float = 62.0
@export var border_color: Color = Color(0.12, 0.09, 0.06, 1.0)
@export var border_width: float = 4.0

# Skema warna Minimap Penjaga Hutan
@export var water_deep_color: Color = Color(0.19, 0.46, 0.68, 1.0)
@export var water_shallow_color: Color = Color(0.33, 0.65, 0.84, 1.0)
@export var sand_color: Color = Color(0.92, 0.81, 0.58, 1.0)
@export var island_color: Color = Color(0.58, 0.76, 0.38, 1.0)
@export var forest_color: Color = Color(0.24, 0.54, 0.28, 1.0)
@export var forest_canopy_color: Color = Color(0.33, 0.67, 0.33, 0.95)
@export var lake_color: Color = Color(0.22, 0.50, 0.74, 1.0)
@export var player_color: Color = Color(1.0, 0.92, 0.22, 1.0)

# Pusat & skala dunia 1:1 agar posisi player akurat terhadap seluruh map
var _world_center: Vector2 = Vector2(950.0, 530.0)
var _world_half_span: float = 1020.0

var player: Node2D = null
var _ui_font: Font = null
var _map_tex: ImageTexture = null
var _houses: Array[Vector2] = []
var _fountains: Array[Vector2] = []
var _bridges: Array[Vector2] = []
var _baked: bool = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://asset/ui/PixelifySans.ttf"):
		_ui_font = load("res://asset/ui/PixelifySans.ttf")
	_find_player()
	call_deferred("_bake_real_map")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		_find_player()
	queue_redraw()

func _world_to_norm(wpos: Vector2) -> Vector2:
	# Mengembalikan koordinat ternormalisasi di sekitar pusat (-1..1) dengan rasio aspek 1:1
	return (wpos - _world_center) / _world_half_span

func _world_to_minimap(wpos: Vector2, center: Vector2, r: float) -> Vector2:
	var n := _world_to_norm(wpos) * (r * 0.92)
	if n.length() > r * 0.88:
		n = n.normalized() * (r * 0.88)
	return center + n

func _bake_real_map() -> void:
	var root_scene := get_tree().current_scene
	if not root_scene:
		var hud := get_parent()
		while hud and not (hud is Node2D):
			hud = hud.get_parent()
		root_scene = hud
	if not root_scene:
		return

	var tanah := root_scene.get_node_or_null("Tanah") as TileMapLayer
	var pasir := root_scene.get_node_or_null("Pasir Pantai") as TileMapLayer
	var rumput := root_scene.get_node_or_null("Rumput + Grass") as TileMapLayer
	var lampu := root_scene.get_node_or_null("Lampu Jalan DLL") as TileMapLayer

	# Hitung pusat dunia otomatis dari tilemap yang ada
	var min_b := Vector2(INF, INF)
	var max_b := Vector2(-INF, -INF)
	var layers: Array[TileMapLayer] = [tanah, pasir]
	for tml in layers:
		if tml and tml.tile_set:
			var rect: Rect2i = tml.get_used_rect()
			if rect.size != Vector2i.ZERO:
				var ts := Vector2(tml.tile_set.tile_size)
				var p0: Vector2 = tml.to_global(Vector2(rect.position) * ts)
				var p1: Vector2 = tml.to_global(Vector2(rect.end) * ts)
				min_b.x = minf(min_b.x, p0.x)
				min_b.y = minf(min_b.y, p0.y)
				max_b.x = maxf(max_b.x, p1.x)
				max_b.y = maxf(max_b.y, p1.y)

	if min_b.x < INF:
		_world_center = (min_b + max_b) * 0.5
		var span := max_b - min_b
		_world_half_span = maxf(span.x, span.y) * 0.54

	_houses.clear()
	_fountains.clear()
	_bridges.clear()
	var tree_positions: Array[Vector2] = []

	for ch in root_scene.get_children():
		if not (ch is Node2D):
			continue
		var n2 := ch as Node2D
		if ch.name.begins_with("HousesAndWarehouses"):
			_houses.append(n2.global_position)
		elif ch.name.begins_with("AirMancur"):
			_fountains.append(n2.global_position)
		elif ch.name.contains("Bridge"):
			_bridges.append(n2.global_position)
		elif ch.name.begins_with("FirTree") or ch.name.begins_with("MiddleLaneTree") or ch.name.begins_with("JungleTree") or ch.name.begins_with("Birch") or ch.name.begins_with("Poon") or ch.name.begins_with("TileFade_"):
			tree_positions.append(n2.global_position)

	# Render tekstur peta asli 128x128
	var sz := 128
	var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	var half_px := float(sz) * 0.5

	for y in range(sz):
		for x in range(sz):
			var d := Vector2(x + 0.5 - half_px, y + 0.5 - half_px).length() / half_px
			if d <= 1.0:
				img.set_pixel(x, y, water_shallow_color if d <= 0.90 else water_deep_color)

	# Helper untuk menggambar kotak kecil di image pada posisi dunia
	var paint_world_rect := func(wpos: Vector2, half_w: float, col: Color):
		var norm := _world_to_norm(wpos) * 0.92
		if norm.length() > 0.90:
			return
		var px := int(round(half_px + norm.x * half_px))
		var py := int(round(half_px + norm.y * half_px))
		var r_px := maxi(0, int(ceil((half_w / _world_half_span) * half_px * 0.92)))
		for dy in range(-r_px, r_px + 1):
			for dx in range(-r_px, r_px + 1):
				var ix := px + dx
				var iy := py + dy
				if ix >= 0 and ix < sz and iy >= 0 and iy < sz:
					if Vector2(ix + 0.5 - half_px, iy + 0.5 - half_px).length() / half_px <= 0.96:
						img.set_pixel(ix, iy, col)

	if pasir and pasir.tile_set:
		for c in pasir.get_used_cells():
			paint_world_rect.call(pasir.to_global(pasir.map_to_local(c)), 12.0, sand_color)

	if tanah and tanah.tile_set:
		for c in tanah.get_used_cells():
			paint_world_rect.call(tanah.to_global(tanah.map_to_local(c)), 11.0, island_color)

	if rumput and rumput.tile_set:
		for c in rumput.get_used_cells():
			paint_world_rect.call(rumput.to_global(rumput.map_to_local(c)), 10.0, forest_color)

	if lampu and lampu.tile_set:
		for c in lampu.get_used_cells():
			paint_world_rect.call(lampu.to_global(lampu.map_to_local(c)), 9.0, Color(0.42, 0.34, 0.28, 1.0))

	for tp in tree_positions:
		paint_world_rect.call(tp, 16.0, forest_canopy_color)

	_map_tex = ImageTexture.create_from_image(img)
	_baked = true

func _draw_mini_house(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-3.5, -1.5), Vector2(7, 5)), Color(0.14, 0.10, 0.07, 0.9))
	draw_rect(Rect2(pos + Vector2(-2.5, -0.5), Vector2(5, 3.5)), Color(0.93, 0.86, 0.72, 1.0))
	var roof := PackedVector2Array([
		pos + Vector2(-4.0, -0.5),
		pos + Vector2(0.0, -4.0),
		pos + Vector2(4.0, -0.5)
	])
	draw_colored_polygon(roof, Color(0.74, 0.30, 0.20, 1.0))

func _draw_outlined_text(font: Font, pos: Vector2, text: String, size_px: int, col: Color) -> void:
	var shadow := Color(0.08, 0.06, 0.05, 0.95)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px, shadow)
	draw_string(font, pos + Vector2(-1, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px, shadow)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px, col)

func _draw() -> void:
	var center := size * 0.5
	var r := minf(center.x, center.y) - border_width * 0.5
	if r <= 0.0:
		return

	# 1. Gambar tekstur peta asli hasil bake (1:1)
	if _map_tex:
		draw_texture_rect(_map_tex, Rect2(center - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false)
	else:
		draw_circle(center, r, water_deep_color)

	# 2. Jembatan & Air Mancur Asli
	for br in _bridges:
		var b_pos := _world_to_minimap(br, center, r)
		draw_rect(Rect2(b_pos + Vector2(-4, -2), Vector2(8, 4)), Color(0.55, 0.36, 0.18, 1.0))

	for ft in _fountains:
		var f_pos := _world_to_minimap(ft, center, r)
		draw_circle(f_pos, 4.2, Color(0.90, 0.84, 0.72, 0.95))
		draw_circle(f_pos, 3.0, lake_color)

	# 3. Rumah-rumah Desa Asli
	for h_wpos in _houses:
		_draw_mini_house(_world_to_minimap(h_wpos, center, r))

	# 4. Penanda Boss aktif di map
	var bosses := get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if is_instance_valid(b) and b is Node2D:
			if "is_dead" in b and b.is_dead:
				continue
			var b_pos := _world_to_minimap((b as Node2D).global_position, center, r)
			draw_circle(b_pos, 3.8, Color(0.1, 0.05, 0.05, 0.95))
			draw_circle(b_pos, 2.6, Color(0.96, 0.26, 0.22, 1.0))

	# 5. Label Wilayah akurat sesuai posisi map
	var font := _ui_font if _ui_font else ThemeDB.fallback_font
	if font:
		_draw_outlined_text(font, _world_to_minimap(Vector2(370, 90), center, r), "Boss", 10, Color(1.0, 0.84, 0.78, 1.0))
		_draw_outlined_text(font, _world_to_minimap(Vector2(1287, 140), center, r), "Forest", 10, Color(0.95, 1.0, 0.90, 1.0))
		_draw_outlined_text(font, _world_to_minimap(Vector2(760, 860), center, r), "Desa", 10, Color(0.98, 0.94, 0.80, 1.0))

	# 6. Posisi Player Realtime
	if player and is_instance_valid(player):
		var map_pos := _world_to_minimap(player.global_position, center, r)
		var pulse := 0.88 + 0.14 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(map_pos, 5.2 * pulse, Color(0.08, 0.06, 0.04, 0.95))
		draw_circle(map_pos, 3.8 * pulse, Color.WHITE)
		draw_circle(map_pos, 2.6 * pulse, player_color)

	# 7. Bingkai Kompas Luar (Emas & Kayu Gelap)
	draw_arc(center, r - 1.5, 0.0, TAU, 64, Color(0.76, 0.56, 0.22, 1.0), 2.5, true)
	draw_arc(center, r, 0.0, TAU, 64, border_color, border_width, true)
	for a_idx in range(4):
		var ang := float(a_idx) * PI * 0.5
		var p_out := center + Vector2(cos(ang), sin(ang)) * (r - 1.0)
		var p_in := center + Vector2(cos(ang), sin(ang)) * (r - 5.5)
		draw_line(p_out, p_in, Color(0.96, 0.82, 0.42, 0.95), 2.0, true)
