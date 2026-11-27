extends Area2D
class_name DoorHouse

@export var target_scene: String = "res://asset/interior_house.tscn"
@export var prompt_text: String = "[E/F] Masuk Rumah"
@export var spawn_meta_key: String = ""
@export var loading_title: String = ""

var _player_in_range: bool = false
var _is_transitioning: bool = false

@onready var prompt: Label = $PromptLabel

func _ready() -> void:
	add_to_group("door")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.text = prompt_text
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _is_transitioning:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE):
			enter_door()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if prompt:
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if prompt:
			prompt.visible = false

func enter_door() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if prompt:
		prompt.visible = false

	var tree := get_tree()
	tree.set_meta("minimap_interior_pos", global_position)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	tree.root.add_child(canvas)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.05, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.modulate.a = 0.0
	canvas.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(340, 0)
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var font_res: FontFile = load("res://asset/ui/PixelifySans.ttf")

	var title_lbl := Label.new()
	if loading_title != "":
		title_lbl.text = loading_title
	elif target_scene.contains("store"):
		title_lbl.text = "Memasuki Toko..."
	else:
		title_lbl.text = "Memasuki Rumah..."
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_res:
		title_lbl.add_theme_font_override("font", font_res)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.97, 0.94, 0.84, 1.0))
	vbox.add_child(title_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(340, 18)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.14, 0.12, 0.10, 1.0)
	sb_bg.border_width_left = 2
	sb_bg.border_width_top = 2
	sb_bg.border_width_right = 2
	sb_bg.border_width_bottom = 2
	sb_bg.border_color = Color(0.84, 0.75, 0.56, 0.9)
	sb_bg.corner_radius_top_left = 4
	sb_bg.corner_radius_top_right = 4
	sb_bg.corner_radius_bottom_right = 4
	sb_bg.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("background", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.45, 0.76, 0.34, 1.0)
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_right = 2
	sb_fill.corner_radius_bottom_left = 2
	bar.add_theme_stylebox_override("fill", sb_fill)
	vbox.add_child(bar)

	var sub_lbl := Label.new()
	sub_lbl.text = "Memuat ruangan... 0%"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_res:
		sub_lbl.add_theme_font_override("font", font_res)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70, 0.9))
	vbox.add_child(sub_lbl)

	var fade_in := canvas.create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(bg, "color:a", 1.0, 0.16)
	fade_in.tween_property(center, "modulate:a", 1.0, 0.16)
	await fade_in.finished

	ResourceLoader.load_threaded_request(target_scene)
	var progress_arr: Array = []
	var visual_pct: float = 0.0
	var elapsed: float = 0.0
	var packed_scene: PackedScene = null

	while true:
		await tree.process_frame
		elapsed += get_process_delta_time()
		var status := ResourceLoader.load_threaded_get_status(target_scene, progress_arr)
		var real_pct: float = (float(progress_arr[0]) * 100.0) if progress_arr.size() > 0 else 0.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			real_pct = 100.0
		visual_pct = move_toward(visual_pct, real_pct, get_process_delta_time() * 550.0)
		bar.value = visual_pct
		sub_lbl.text = "Memuat ruangan... %d%%" % int(round(visual_pct))

		if status == ResourceLoader.THREAD_LOAD_LOADED and visual_pct >= 99.5 and elapsed >= 0.15:
			packed_scene = ResourceLoader.load_threaded_get(target_scene) as PackedScene
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			break

	var fade_out := canvas.create_tween()
	fade_out.tween_interval(0.05)
	fade_out.tween_property(center, "modulate:a", 0.0, 0.16)
	fade_out.parallel().tween_property(bg, "color:a", 0.0, 0.25)
	fade_out.tween_callback(canvas.queue_free)

	if packed_scene:
		if spawn_meta_key != "":
			tree.set_meta(spawn_meta_key, true)
		tree.change_scene_to_packed(packed_scene)
	else:
		if spawn_meta_key != "":
			tree.set_meta(spawn_meta_key, true)
		tree.change_scene_to_file(target_scene)
