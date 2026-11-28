extends Node2D

@onready var player: Node2D = $Player
@onready var bed_prompt: Label = $BedArea/BedPrompt
@onready var door_prompt: Label = $DoorArea/DoorPrompt
@onready var fade_rect: ColorRect = $FadeCanvas/FadeRect
@onready var sleep_notify: Control = $FadeCanvas/SleepNotify

const QUIET_BGM_PATH := "res://asset/music/background music/baim_quite_place_backsound.wav"

var _can_sleep: bool = false
var _can_exit: bool = false
var _is_busy: bool = false
var _bgm_player: AudioStreamPlayer

func _ready() -> void:
	_setup_textures()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -19.0
	if ResourceLoader.exists(QUIET_BGM_PATH):
		_bgm_player.stream = load(QUIET_BGM_PATH)
	add_child(_bgm_player)
	_bgm_player.finished.connect(func():
		if _bgm_player.stream and is_inside_tree():
			_bgm_player.play()
	)
	if _bgm_player.stream:
		_bgm_player.play()
	if bed_prompt:
		bed_prompt.visible = false
	if door_prompt:
		door_prompt.visible = false
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
	if sleep_notify:
		sleep_notify.visible = false

func _load_texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _setup_textures() -> void:
	var t_floor = _load_texture("res://asset/interior/floor_wood.png")
	var t_wall = _load_texture("res://asset/interior/wall_wood.png")
	var t_bed = _load_texture("res://asset/interior/bed.png")
	var t_rug = _load_texture("res://asset/interior/rug.png")
	var t_table = _load_texture("res://asset/interior/table.png")
	var t_doormat = _load_texture("res://asset/interior/door_mat.png")

	if t_floor and has_node("Floor"):
		$Floor.texture = t_floor
	if t_wall:
		if has_node("WallTop"): $WallTop.texture = t_wall
		if has_node("WallLeft"): $WallLeft.texture = t_wall
		if has_node("WallRight"): $WallRight.texture = t_wall
		if has_node("WallBottomLeft"): $WallBottomLeft.texture = t_wall
		if has_node("WallBottomRight"): $WallBottomRight.texture = t_wall
	if t_rug and has_node("Rug"):
		$Rug.texture = t_rug
	if t_doormat and has_node("DoorMat"):
		$DoorMat.texture = t_doormat
	if t_table and has_node("Table/Sprite2D"):
		$Table/Sprite2D.texture = t_table
	if t_bed and has_node("Bed/Sprite2D"):
		$Bed/Sprite2D.texture = t_bed

func _unhandled_input(event: InputEvent) -> void:
	if _is_busy:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if _can_sleep:
			sleep()
		elif _can_exit:
			exit_to_village()

func _on_bed_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_sleep = true
		if bed_prompt:
			bed_prompt.visible = true

func _on_bed_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_sleep = false
		if bed_prompt:
			bed_prompt.visible = false

func _on_door_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_exit = true
		if door_prompt:
			door_prompt.visible = true

func _on_door_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_exit = false
		if door_prompt:
			door_prompt.visible = false

func sleep() -> void:
	if _is_busy:
		return
	_is_busy = true
	if bed_prompt:
		bed_prompt.visible = false

	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
		tween.tween_callback(func():
			if player and player.has_method("heal"):
				player.heal(100.0)
			if player and player.has_method("restore_energy"):
				player.restore_energy(100.0)
			if sleep_notify:
				sleep_notify.visible = true
				sleep_notify.modulate.a = 0.0
				var notify_tween = create_tween()
				notify_tween.tween_property(sleep_notify, "modulate:a", 1.0, 0.25)
				notify_tween.tween_interval(1.0)
				notify_tween.tween_property(sleep_notify, "modulate:a", 0.0, 0.25)
				notify_tween.tween_callback(func(): sleep_notify.visible = false)
		)
		tween.tween_interval(1.2)
		tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
		tween.tween_callback(func(): _is_busy = false)

func exit_to_village() -> void:
	if _is_busy:
		return
	_is_busy = true
	if door_prompt:
		door_prompt.visible = false
	get_tree().set_meta("spawn_outside_house", true)

	var tree := get_tree()
	var target_path := "res://asset/game.tscn"

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
	title_lbl.text = "Keluar Rumah..."
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
	sub_lbl.text = "Memuat peta... 0%"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_res:
		sub_lbl.add_theme_font_override("font", font_res)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70, 0.9))
	vbox.add_child(sub_lbl)

	# Fade in layar loading (cepat)
	var fade_in := canvas.create_tween()
	fade_in.set_parallel(true)
	fade_in.tween_property(bg, "color:a", 1.0, 0.16)
	fade_in.tween_property(center, "modulate:a", 1.0, 0.16)
	await fade_in.finished

	ResourceLoader.load_threaded_request(target_path)
	var progress_arr: Array = []
	var visual_pct: float = 0.0
	var elapsed: float = 0.0
	var packed_scene: PackedScene = null

	while true:
		await tree.process_frame
		elapsed += get_process_delta_time()
		var status := ResourceLoader.load_threaded_get_status(target_path, progress_arr)
		var real_pct: float = (float(progress_arr[0]) * 100.0) if progress_arr.size() > 0 else 0.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			real_pct = 100.0
		visual_pct = move_toward(visual_pct, real_pct, get_process_delta_time() * 550.0)
		bar.value = visual_pct
		sub_lbl.text = "Memuat peta... %d%%" % int(round(visual_pct))

		if status == ResourceLoader.THREAD_LOAD_LOADED and visual_pct >= 99.5 and elapsed >= 0.15:
			packed_scene = ResourceLoader.load_threaded_get(target_path) as PackedScene
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			break

	# Pasang tween fade-out pada canvas (bukan await di InteriorHouse yang akan terhapus)
	var fade_out := canvas.create_tween()
	fade_out.tween_interval(0.05)
	fade_out.tween_property(center, "modulate:a", 0.0, 0.16)
	fade_out.parallel().tween_property(bg, "color:a", 0.0, 0.25)
	fade_out.tween_callback(canvas.queue_free)

	if packed_scene:
		tree.change_scene_to_packed(packed_scene)
	else:
		tree.change_scene_to_file(target_path)
