extends Control

@export var map_radius: float = 62.0
@export var border_color: Color = Color(0.12, 0.12, 0.12, 1.0)
@export var border_width: float = 4.0

# Skema warna sesuai mockup desain
@export var water_color: Color = Color(0.38, 0.68, 0.88, 1.0)
@export var island_color: Color = Color(0.96, 0.83, 0.63, 1.0)
@export var boss_color: Color = Color(0.70, 0.24, 0.24, 1.0)
@export var forest_color: Color = Color(0.40, 0.74, 0.44, 1.0)
@export var river_color: Color = Color(0.32, 0.62, 0.82, 1.0)
@export var lake_color: Color = Color(0.24, 0.52, 0.76, 1.0)
@export var player_color: Color = Color(1.0, 0.95, 0.2, 1.0)

# Batas area dunia (world coordinate bounds)
@export var world_min: Vector2 = Vector2(-50, -200)
@export var world_max: Vector2 = Vector2(1950, 950)

var player: Node2D = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_find_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _process(_delta: float) -> void:
	if not player or not is_instance_valid(player):
		_find_player()
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	var r = min(center.x, center.y) - border_width * 0.5
	if r <= 0:
		return

	# 1. Lingkaran Dasar Air Laut
	draw_circle(center, r, water_color)

	# 2. Daratan Utama Pulau (Island)
	var island_poly = PackedVector2Array([
		center + Vector2(-r * 0.85, r * 0.2),
		center + Vector2(-r * 0.80, -r * 0.2),
		center + Vector2(-r * 0.55, -r * 0.65),
		center + Vector2(0.0, -r * 0.78),
		center + Vector2(r * 0.60, -r * 0.65),
		center + Vector2(r * 0.85, -r * 0.2),
		center + Vector2(r * 0.72, r * 0.45),
		center + Vector2(r * 0.35, r * 0.82),
		center + Vector2(-r * 0.35, r * 0.85),
		center + Vector2(-r * 0.70, r * 0.60)
	])
	draw_colored_polygon(island_poly, island_color)

	# 3. Wilayah Boss (Kiri Atas - Merah/Cokelat)
	var boss_poly = PackedVector2Array([
		center + Vector2(-r * 0.80, -r * 0.2),
		center + Vector2(-r * 0.55, -r * 0.65),
		center + Vector2(-r * 0.12, -r * 0.42),
		center + Vector2(-r * 0.40, -r * 0.12)
	])
	draw_colored_polygon(boss_poly, boss_color)

	# 4. Wilayah Forest (Kanan Atas - Hijau)
	var forest_poly = PackedVector2Array([
		center + Vector2(0.0, -r * 0.78),
		center + Vector2(r * 0.60, -r * 0.65),
		center + Vector2(r * 0.85, -r * 0.2),
		center + Vector2(r * 0.38, -r * 0.10),
		center + Vector2(r * 0.05, -r * 0.36)
	])
	draw_colored_polygon(forest_poly, forest_color)

	# 5. Sungai dan Danau
	var river_line = PackedVector2Array([
		center + Vector2(-r * 0.10, -r * 0.78),
		center + Vector2(0.0, -r * 0.42),
		center + Vector2(r * 0.18, -r * 0.20),
		center + Vector2(r * 0.50, -r * 0.15)
	])
	draw_polyline(river_line, river_color, 3.0, true)
	draw_circle(center + Vector2(-r * 0.04, 0.0), 4.5, lake_color)

	# 6. Titik Bangunan Desa
	var house_color = Color(0.55, 0.35, 0.25, 0.85)
	var house_offsets = [
		Vector2(-r * 0.30, r * 0.18),
		Vector2(-r * 0.42, r * 0.38),
		Vector2(-r * 0.15, r * 0.48),
		Vector2(r * 0.12, r * 0.32),
		Vector2(r * 0.28, r * 0.12)
	]
	for h_pos in house_offsets:
		draw_rect(Rect2(center + h_pos - Vector2(2, 2), Vector2(4, 4)), house_color)

	# 7. Teks Label "Boss" dan "Forest"
	var font = ThemeDB.fallback_font
	var font_size = 9
	if font:
		draw_string(font, center + Vector2(-r * 0.60, -r * 0.32), "Boss", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
		draw_string(font, center + Vector2(r * 0.22, -r * 0.40), "Forest", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	# 8. Posisi Player Realtime
	if player and is_instance_valid(player):
		var p_pos = player.global_position
		var nx = clampf((p_pos.x - world_min.x) / (world_max.x - world_min.x), 0.0, 1.0)
		var ny = clampf((p_pos.y - world_min.y) / (world_max.y - world_min.y), 0.0, 1.0)
		var map_pos = center + Vector2((nx - 0.5) * 2.0 * (r * 0.72), (ny - 0.5) * 2.0 * (r * 0.72))
		
		# Efek kedip/pulse
		var pulse = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(map_pos, 5.0 * pulse, Color(0, 0, 0, 0.8))
		draw_circle(map_pos, 4.0 * pulse, Color.WHITE)
		draw_circle(map_pos, 3.0 * pulse, player_color)

	# 9. Ring Border Luar
	draw_arc(center, r, 0, TAU, 64, border_color, border_width, true)
