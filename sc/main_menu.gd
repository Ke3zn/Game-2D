extends Control

const GAME_SCENE_PATH := "res://asset/game.tscn"
const OPENING_BGM_PATH := "res://asset/music/background music/baim_opening_backsound.wav"

@onready var menu_buttons: Array[Button] = [
	%BtnStart,
	%BtnGuide,
	%BtnSettings,
	%BtnQuit
]
@onready var cursor_label: Label = %MenuCursor
@onready var title_banner: Control = %TitleBanner
@onready var guide_modal: Control = %GuideModal
@onready var settings_modal: Control = %SettingsModal
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_val_label: Label = %VolumeValLabel
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var fade_rect: ColorRect = %FadeRect
@onready var particles_layer: Control = %ParticlesLayer
@onready var hero_preview: TextureRect = %HeroPreview

var _selected_idx: int = 0
var _is_starting: bool = false
var _cursor_tween: Tween
var _bgm_player: AudioStreamPlayer

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -5.0
	if ResourceLoader.exists(OPENING_BGM_PATH):
		_bgm_player.stream = load(OPENING_BGM_PATH)
	add_child(_bgm_player)
	_bgm_player.finished.connect(func():
		if not _is_starting and _bgm_player.stream and is_inside_tree():
			_bgm_player.play()
	)
	if _bgm_player.stream:
		_bgm_player.play()
	# Fade in halus saat halaman depan muncul
	if fade_rect:
		fade_rect.visible = true
		fade_rect.color = Color(0, 0, 0, 1)
		var ft = create_tween()
		ft.tween_property(fade_rect, "color:a", 0.0, 0.45)
		ft.tween_callback(func(): fade_rect.visible = false)

	# Animasi melayang lembut pada banner judul
	if title_banner:
		var base_y = title_banner.position.y
		var bt = create_tween().set_loops()
		bt.tween_property(title_banner, "position:y", base_y - 5.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bt.tween_property(title_banner, "position:y", base_y + 3.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Animasi idle ringan pada preview karakter
	if hero_preview:
		var ht = create_tween().set_loops()
		ht.tween_property(hero_preview, "scale", Vector2(1.03, 0.97), 1.0).set_trans(Tween.TRANS_SINE)
		ht.tween_property(hero_preview, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

	# Hubungkan tombol menu
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		if not btn:
			continue
		btn.mouse_entered.connect(_on_btn_hovered.bind(i))
		btn.focus_entered.connect(_on_btn_hovered.bind(i))

	%BtnStart.pressed.connect(_on_start_pressed)
	%BtnGuide.pressed.connect(_on_guide_pressed)
	%BtnSettings.pressed.connect(_on_settings_pressed)
	%BtnQuit.pressed.connect(_on_quit_pressed)
	%BtnCloseGuide.pressed.connect(_close_modals)
	%BtnCloseSettings.pressed.connect(_close_modals)

	if volume_slider:
		var bus_idx = AudioServer.get_bus_index("Master")
		var db = AudioServer.get_bus_volume_db(bus_idx) if bus_idx >= 0 else 0.0
		var linear = clampf(db_to_linear(db) * 100.0, 0.0, 100.0)
		volume_slider.value = linear
		_update_volume_label(linear)
		volume_slider.value_changed.connect(_on_volume_changed)

	if fullscreen_check:
		var mode = DisplayServer.window_get_mode()
		fullscreen_check.button_pressed = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_spawn_fireflies()
	call_deferred("_update_cursor", 0, false)

func _unhandled_input(event: InputEvent) -> void:
	if _is_starting:
		return

	if (guide_modal and guide_modal.visible) or (settings_modal and settings_modal.visible):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_modals()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_update_cursor((_selected_idx + 1) % menu_buttons.size(), true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			_update_cursor((_selected_idx - 1 + menu_buttons.size()) % menu_buttons.size(), true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if _selected_idx >= 0 and _selected_idx < menu_buttons.size() and menu_buttons[_selected_idx]:
				menu_buttons[_selected_idx].pressed.emit()
				get_viewport().set_input_as_handled()

func _on_btn_hovered(idx: int) -> void:
	_update_cursor(idx, true)

func _update_cursor(idx: int, animate: bool = true) -> void:
	_selected_idx = clampi(idx, 0, menu_buttons.size() - 1)
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		if not btn:
			continue
		if i == _selected_idx:
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
		else:
			btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 0.85))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))

	if cursor_label and menu_buttons[_selected_idx]:
		var target_btn = menu_buttons[_selected_idx]
		var target_y = target_btn.global_position.y + (target_btn.size.y - cursor_label.size.y) * 0.5
		var target_x = target_btn.global_position.x - 42.0
		if animate:
			if _cursor_tween and _cursor_tween.is_valid():
				_cursor_tween.kill()
			_cursor_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			_cursor_tween.tween_property(cursor_label, "global_position", Vector2(target_x, target_y), 0.1)
		else:
			cursor_label.global_position = Vector2(target_x, target_y)

func _on_start_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	if _bgm_player and _bgm_player.playing:
		var bt = create_tween()
		bt.tween_property(_bgm_player, "volume_db", -50.0, 0.38)
	if fade_rect:
		fade_rect.visible = true
		var t = create_tween()
		t.tween_property(fade_rect, "color:a", 1.0, 0.4)
		t.tween_callback(func():
			get_tree().change_scene_to_file(GAME_SCENE_PATH)
		)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_guide_pressed() -> void:
	if guide_modal:
		guide_modal.visible = true
	if settings_modal:
		settings_modal.visible = false

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.visible = true
	if guide_modal:
		guide_modal.visible = false

func _close_modals() -> void:
	if guide_modal:
		guide_modal.visible = false
	if settings_modal:
		settings_modal.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(val: float) -> void:
	_update_volume_label(val)
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, val <= 0.5)
		if val > 0.5:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(val / 100.0))

func _update_volume_label(val: float) -> void:
	if volume_val_label:
		volume_val_label.text = "%d%%" % int(round(val))

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _spawn_fireflies() -> void:
	if not particles_layer:
		return
	for i in range(24):
		var dot = ColorRect.new()
		var sz = 6.0 if i % 3 == 0 else 4.0
		dot.size = Vector2(sz, sz)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.color = Color(1.0, 0.88, 0.45, 0.85) if i % 4 != 0 else Color(1.0, 0.55, 0.25, 0.8)
		var sx = randf_range(40.0, 1880.0)
		var sy = randf_range(480.0, 1020.0)
		dot.position = Vector2(sx, sy)
		particles_layer.add_child(dot)

		var dur = randf_range(2.2, 4.5)
		var drift_x = randf_range(-35.0, 35.0)
		var drift_y = randf_range(-70.0, -25.0)
		var t = dot.create_tween().set_loops()
		t.tween_property(dot, "position", Vector2(sx + drift_x, sy + drift_y), dur).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(dot, "modulate:a", 0.2, dur * 0.5)
		t.tween_property(dot, "position", Vector2(sx, sy), dur).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(dot, "modulate:a", 0.95, dur * 0.5)
