extends CanvasLayer

signal dialogue_finished

@export var slot_normal_style: StyleBoxFlat
@export var slot_active_style: StyleBoxFlat
@export var btn_normal_style: StyleBoxFlat
@export var btn_pressed_style: StyleBoxFlat
@export var action_normal_style: StyleBoxFlat
@export var action_pressed_style: StyleBoxFlat

@onready var blood_bar: ProgressBar = %BloodBar
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var blood_val_label: Label = %BloodValLabel
@onready var energy_val_label: Label = %EnergyValLabel

@onready var slot_0: PanelContainer = %Slot0
@onready var slot_1: PanelContainer = %Slot1
@onready var slot_2: PanelContainer = %Slot2

@onready var item_icon_0: TextureRect = %ItemIcon0
@onready var item_icon_1: TextureRect = %ItemIcon1
@onready var item_icon_2: TextureRect = %ItemIcon2
@onready var tas_icon: TextureRect = %TasIcon
@onready var tas_button: Button = %TasButton

@onready var joystick_base: Panel = %JoystickBase
@onready var joystick_knob: Panel = %JoystickKnob
@onready var controls_guide: PanelContainer = %ControlsGuide
@onready var guide_toggle_btn: Button = %GuideToggleBtn
@onready var guide_content: VBoxContainer = %GuideContent

var _is_dragging_joystick: bool = false
var _joystick_center: Vector2 = Vector2(68.0, 68.0)
var _knob_half_size: Vector2 = Vector2(30.0, 30.0)
var _max_joystick_radius: float = 46.0
var _active_joystick_dir: Vector2 = Vector2.ZERO

@onready var inventory_modal: Control = %InventoryModal
@onready var inv_close_btn: Button = %InvCloseBtn
@onready var dimmer: ColorRect = %Dimmer
@onready var inv_grid: GridContainer = %InvGrid
@onready var inv_detail_icon: TextureRect = %InvDetailIcon
@onready var inv_detail_title: Label = %InvDetailTitle
@onready var inv_detail_desc: Label = %InvDetailDesc

@onready var dialogue_modal: Control = %DialogueModal
@onready var speaker_label: Label = %SpeakerLabel
@onready var dialogue_text: Label = %DialogueText
@onready var dialogue_next_btn: Button = %DialogueNextBtn

@onready var quest_tracker: Control = %QuestTracker
@onready var quest_title_label: Label = %QuestTitleLabel
@onready var quest_progress_label: Label = %QuestProgressLabel
@onready var quest_reward_label: Label = %QuestRewardLabel

@onready var boss_bar_container: Control = %BossBarContainer
@onready var boss_name_label: Label = %BossNameLabel
@onready var boss_hp_val_label: Label = %BossHpValLabel
@onready var boss_progress_bar: TextureProgressBar = %BossProgressBar
@onready var victory_banner: Control = %VictoryBanner

@onready var game_over_modal: Control = %GameOverModal
@onready var respawn_btn: Button = %RespawnBtn
@onready var restart_btn: Button = %RestartBtn

var quest_status: String = "NOT_STARTED"
var quest_current_count: int = 0
var quest_target_count: int = 2

var current_dialogue_lines: Array[String] = []
var current_dialogue_idx: int = 0
var inventory_items: Dictionary = {
	1: {"id": "pentungan", "name": "Pentungan Kayu", "desc": "Senjata pemukul dasar untuk perlindungan diri. Mengkonsumsi 20 energi saat diayunkan. (Terpasang di Slot 2 Hotbar)", "icon": null}
}

var slots: Array[PanelContainer] = []
var item_icons: Array[TextureRect] = []

var blood_tween: Tween
var energy_tween: Tween
var current_active_slot: int = 1

func _ready() -> void:
	add_to_group("hud")
	slots = [slot_0, slot_1, slot_2]
	item_icons = [item_icon_0, item_icon_1, item_icon_2]

	# Pulihkan status quest & APAR lintas scene (mis. saat keluar/masuk rumah)
	if get_tree().has_meta("quest_status"):
		quest_status = str(get_tree().get_meta("quest_status"))
	if get_tree().has_meta("quest_current_count"):
		quest_current_count = int(get_tree().get_meta("quest_current_count"))
	var has_apar: bool = get_tree().get_meta("has_apar", false)

	# APAR hanya muncul di Slot 1 setelah player selesai berbicara dengan Kakek
	if has_apar:
		_register_apar_item()
	elif item_icon_0:
		item_icon_0.texture = null

	# Muat ikon tas ransel secara dinamis jika file ada
	if FileAccess.file_exists("res://asset/char/tools/tas.png"):
		var img_tas = Image.load_from_file("res://asset/char/tools/tas.png")
		if img_tas and tas_icon:
			tas_icon.texture = ImageTexture.create_from_image(img_tas)

	if item_icon_1 and item_icon_1.texture and inventory_items.has(1):
		inventory_items[1]["icon"] = item_icon_1.texture

	# Hubungkan event klik mouse pada setiap slot hotbar
	for i in range(slots.size()):
		var s = slots[i]
		if s:
			s.gui_input.connect(_on_slot_gui_input.bind(i))

	# Hubungkan tombol Tas (posisi kanan bawah, mengganti tombol pedang)
	if tas_button:
		tas_button.pressed.connect(toggle_inventory)

	# Hubungkan tombol tutup inventory dan klik latar luar
	if inv_close_btn:
		inv_close_btn.pressed.connect(close_inventory)
	if dimmer:
		dimmer.gui_input.connect(_on_dimmer_gui_input)

	# Inisialisasi slot grid tas
	_setup_inventory_grid()

	# Setup Analog Virtual Joystick & Panduan Kontrol
	_setup_joystick()
	_setup_controls_guide()

	# Hubungkan tombol next dialog
	if dialogue_next_btn:
		dialogue_next_btn.pressed.connect(advance_dialogue)

	# Hubungkan tombol Game Over
	if respawn_btn:
		respawn_btn.pressed.connect(_on_respawn_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)

	# Update visual awal
	set_active_slot(current_active_slot)
	_update_quest_ui()

	# Cari player di dalam scene secara otomatis
	var player = get_tree().get_first_node_in_group("player")
	if player:
		connect_player(player)
	else:
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		connect_player(node)

func connect_player(player: Node) -> void:
	if player.has_signal("blood_changed") and not player.blood_changed.is_connected(_on_blood_changed):
		player.blood_changed.connect(_on_blood_changed)
	if player.has_signal("energy_changed") and not player.energy_changed.is_connected(_on_energy_changed):
		player.energy_changed.connect(_on_energy_changed)
	if player.has_signal("active_slot_changed") and not player.active_slot_changed.is_connected(_on_active_slot_changed):
		player.active_slot_changed.connect(_on_active_slot_changed)
	if player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	if not player.is_node_ready():
		await player.ready

	if "current_blood" in player and "max_blood" in player:
		set_blood(player.current_blood, player.max_blood, false)
	if "current_energy" in player and "max_energy" in player:
		set_energy(player.current_energy, player.max_energy, false)
	if "active_slot" in player:
		set_active_slot(player.active_slot)

func _on_blood_changed(current: float, max_val: float) -> void:
	set_blood(current, max_val, true)

func _on_energy_changed(current: float, max_val: float) -> void:
	set_energy(current, max_val, true)

func _on_active_slot_changed(slot_idx: int) -> void:
	set_active_slot(slot_idx)

func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_active_slot"):
			player.set_active_slot(slot_index)
		else:
			set_active_slot(slot_index)

func set_active_slot(index: int) -> void:
	current_active_slot = clampi(index, 0, 2)
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot:
			continue
		if i == current_active_slot:
			if slot_active_style:
				slot.add_theme_stylebox_override("panel", slot_active_style)
		else:
			if slot_normal_style:
				slot.add_theme_stylebox_override("panel", slot_normal_style)

func set_slot_icon(index: int, texture: Texture2D) -> void:
	if index >= 0 and index < item_icons.size() and item_icons[index]:
		item_icons[index].texture = texture

func set_blood(current: float, max_val: float, animate: bool = true) -> void:
	if not blood_bar:
		return
	blood_bar.max_value = max_val
	if blood_val_label:
		blood_val_label.text = "%d / %d" % [ceil(current), ceil(max_val)]

	if animate:
		if blood_tween and blood_tween.is_valid():
			blood_tween.kill()
		blood_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		blood_tween.tween_property(blood_bar, "value", current, 0.25)
	else:
		blood_bar.value = current

func set_energy(current: float, max_val: float, animate: bool = true) -> void:
	if not energy_bar:
		return
	energy_bar.max_value = max_val
	if energy_val_label:
		energy_val_label.text = "%d / %d" % [ceil(current), ceil(max_val)]

	if animate:
		if energy_tween and energy_tween.is_valid():
			energy_tween.kill()
		energy_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		energy_tween.tween_property(energy_bar, "value", current, 0.15)
	else:
		energy_bar.value = current

func _process(delta: float) -> void:
	# Jika tidak sedang di-drag manual, sinkronkan posisi knob joystick dengan tombol keyboard (WASD / Panah)
	if not _is_dragging_joystick and joystick_knob:
		var k_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var target_pos = _joystick_center - _knob_half_size + (k_vector * 32.0)
		joystick_knob.position = joystick_knob.position.lerp(target_pos, min(1.0, 18.0 * delta))

func _setup_joystick() -> void:
	if joystick_base:
		joystick_base.gui_input.connect(_on_joystick_gui_input)

func _setup_controls_guide() -> void:
	if guide_toggle_btn:
		guide_toggle_btn.pressed.connect(_toggle_controls_guide)

func _toggle_controls_guide() -> void:
	if guide_content and guide_toggle_btn:
		guide_content.visible = not guide_content.visible
		guide_toggle_btn.text = "−" if guide_content.visible else "+"

func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging_joystick = true
				_update_joystick(event.position)
			else:
				_release_joystick()
	elif event is InputEventMouseMotion and _is_dragging_joystick:
		_update_joystick(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_dragging_joystick = true
			_update_joystick(event.position)
		else:
			_release_joystick()
	elif event is InputEventScreenDrag and _is_dragging_joystick:
		_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var offset = touch_pos - _joystick_center
	var dist = offset.length()
	if dist > _max_joystick_radius:
		offset = offset.normalized() * _max_joystick_radius
		dist = _max_joystick_radius

	if joystick_knob:
		joystick_knob.position = (_joystick_center + offset) - _knob_half_size

	var deadzone = 8.0
	if dist > deadzone:
		_active_joystick_dir = offset.normalized()
		_set_action_state("move_right", _active_joystick_dir.x > 0.35)
		_set_action_state("move_left", _active_joystick_dir.x < -0.35)
		_set_action_state("move_down", _active_joystick_dir.y > 0.35)
		_set_action_state("move_up", _active_joystick_dir.y < -0.35)
	else:
		_active_joystick_dir = Vector2.ZERO
		_release_movement_actions()

func _set_action_state(action: StringName, is_active: bool) -> void:
	if is_active:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	else:
		if Input.is_action_pressed(action):
			Input.action_release(action)

func _release_movement_actions() -> void:
	if Input.is_action_pressed("move_left"):
		Input.action_release("move_left")
	if Input.is_action_pressed("move_right"):
		Input.action_release("move_right")
	if Input.is_action_pressed("move_up"):
		Input.action_release("move_up")
	if Input.is_action_pressed("move_down"):
		Input.action_release("move_down")

func _release_joystick() -> void:
	_is_dragging_joystick = false
	_active_joystick_dir = Vector2.ZERO
	_release_movement_actions()
	if joystick_knob:
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(joystick_knob, "position", _joystick_center - _knob_half_size, 0.15)

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close_inventory()

func toggle_inventory() -> void:
	if inventory_modal:
		if inventory_modal.visible:
			close_inventory()
		else:
			open_inventory()

func open_inventory() -> void:
	if inventory_modal:
		inventory_modal.visible = true
		_select_inv_item(current_active_slot)

func close_inventory() -> void:
	if inventory_modal:
		inventory_modal.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Lepas joystick jika klik mouse / touch terlepas di luar area base
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_dragging_joystick:
			_release_joystick()
	elif event is InputEventScreenTouch and not event.pressed:
		if _is_dragging_joystick:
			_release_joystick()

	if event is InputEventKey and event.pressed:
		# Jika dialog sedang aktif, utamakan kontrol dialog
		if dialogue_modal and dialogue_modal.visible:
			if event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE:
				advance_dialogue()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_ESCAPE:
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

		# Kontrol tas inventory
		if event.keycode == KEY_B or event.keycode == KEY_I or event.keycode == KEY_TAB:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and inventory_modal and inventory_modal.visible:
			close_inventory()
			get_viewport().set_input_as_handled()

func start_dialogue(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	current_dialogue_lines = lines
	current_dialogue_idx = 0
	if speaker_label:
		speaker_label.text = speaker
	if dialogue_text:
		dialogue_text.text = current_dialogue_lines[0]
	if dialogue_next_btn:
		dialogue_next_btn.text = "Selesai [ E ] ✓" if current_dialogue_lines.size() == 1 else "Lanjut [ E ] ▶"
	if dialogue_modal:
		dialogue_modal.visible = true

func advance_dialogue() -> void:
	current_dialogue_idx += 1
	if current_dialogue_idx < current_dialogue_lines.size():
		if dialogue_text:
			dialogue_text.text = current_dialogue_lines[current_dialogue_idx]
		if dialogue_next_btn:
			dialogue_next_btn.text = "Selesai [ E ] ✓" if current_dialogue_idx == current_dialogue_lines.size() - 1 else "Lanjut [ E ] ▶"
	else:
		close_dialogue()
		dialogue_finished.emit()

func close_dialogue() -> void:
	if dialogue_modal:
		dialogue_modal.visible = false
	current_dialogue_lines.clear()
	current_dialogue_idx = 0

func _register_apar_item() -> void:
	var tex: Texture2D = null
	if FileAccess.file_exists("res://asset/char/tools/pemadam.png"):
		var img = Image.load_from_file("res://asset/char/tools/pemadam.png")
		if img:
			tex = ImageTexture.create_from_image(img)
	if item_icon_0:
		item_icon_0.texture = tex
	inventory_items[0] = {
		"id": "pemadam",
		"name": "Alat Pemadam Api (APAR)",
		"desc": "Pemberian Kakek untuk memadamkan api di sekitar desa dan hutan. (Terpasang di Slot 1 Hotbar)",
		"icon": tex
	}
	_update_inv_slot_display(0)

func unlock_apar() -> void:
	get_tree().set_meta("has_apar", true)
	_register_apar_item()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("grant_apar"):
		player.grant_apar()

func start_quest(target_count: int = 2) -> void:
	quest_status = "IN_PROGRESS"
	quest_target_count = target_count
	quest_current_count = 0
	get_tree().set_meta("quest_status", quest_status)
	get_tree().set_meta("quest_current_count", quest_current_count)
	_update_quest_ui()

func add_quest_progress(target_type: String, amount: int = 1) -> void:
	if quest_status != "IN_PROGRESS":
		return
	if target_type == "slime":
		quest_current_count = min(quest_target_count, quest_current_count + amount)
		if quest_current_count >= quest_target_count:
			quest_status = "READY_TO_TURN_IN"
		get_tree().set_meta("quest_status", quest_status)
		get_tree().set_meta("quest_current_count", quest_current_count)
		_update_quest_ui()

func complete_quest() -> void:
	if quest_status != "READY_TO_TURN_IN":
		return
	quest_status = "COMPLETED"
	get_tree().set_meta("quest_status", quest_status)
	add_item_to_inventory("coin", "Koin Emas", "Koin mata uang berharga hadiah dari Kakek desa.", "res://asset/char/tools/coin.png", 100)
	_update_quest_ui()

func _update_quest_ui() -> void:
	if not quest_tracker:
		return
	if quest_status == "NOT_STARTED":
		quest_tracker.visible = false
		return

	quest_tracker.visible = true
	if quest_status == "IN_PROGRESS":
		if quest_title_label: quest_title_label.text = "📜 Misi Kakek: Padamkan Api & Basmi Slime"
		if quest_progress_label:
			quest_progress_label.text = "• APAR [1] Diterima | Kalahkan Slime: %d / %d" % [quest_current_count, quest_target_count]
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15, 1.0))
		if quest_reward_label: quest_reward_label.text = "Hadiah: 100 Koin Emas 🪙"
	elif quest_status == "READY_TO_TURN_IN":
		if quest_title_label: quest_title_label.text = "📜 Misi Selesai! (Lapor ke Kakek)"
		if quest_progress_label:
			quest_progress_label.text = "• Slime Terbasmi: %d / %d ✓" % [quest_current_count, quest_target_count]
			quest_progress_label.add_theme_color_override("font_color", Color(0.15, 0.55, 0.2, 1.0))
		if quest_reward_label: quest_reward_label.text = "Bicaralah pada Kakek untuk hadiah!"
	elif quest_status == "COMPLETED":
		if quest_title_label: quest_title_label.text = "✓ Misi Desa Selesai"
		if quest_progress_label:
			quest_progress_label.text = "Desa telah aman dari ancaman Slime!"
			quest_progress_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.25, 1.0))
		if quest_reward_label: quest_reward_label.text = "Hadiah 100 Koin Emas telah diterima!"

func show_boss_bar(title: String, current_hp: float, max_hp: float) -> void:
	if not boss_bar_container:
		return
	boss_bar_container.visible = true
	if boss_name_label:
		boss_name_label.text = title
	update_boss_hp(current_hp, max_hp)

func update_boss_hp(current_hp: float, max_hp: float) -> void:
	if boss_progress_bar:
		boss_progress_bar.max_value = max_hp
		boss_progress_bar.value = current_hp
	if boss_hp_val_label:
		boss_hp_val_label.text = "%d / %d" % [ceil(current_hp), ceil(max_hp)]

func hide_boss_bar() -> void:
	if boss_bar_container:
		boss_bar_container.visible = false

func on_boss_defeated(title: String) -> void:
	hide_boss_bar()
	trigger_screen_shake(12.0, 0.5)
	if victory_banner:
		victory_banner.visible = true
		victory_banner.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(victory_banner, "modulate:a", 1.0, 0.3)
		tween.tween_interval(3.0)
		tween.tween_property(victory_banner, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): victory_banner.visible = false)

func trigger_screen_shake(intensity: float = 8.0, duration: float = 0.35) -> void:
	var ctrl = get_node_or_null("Control")
	if not ctrl:
		return
	var tween = create_tween()
	var step_time = 0.05
	var count = int(duration / step_time)
	for i in range(count):
		var rand_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(ctrl, "position", rand_offset, step_time)
	tween.tween_property(ctrl, "position", Vector2.ZERO, step_time)

func _on_player_died() -> void:
	show_game_over()

func show_game_over() -> void:
	if game_over_modal:
		game_over_modal.visible = true
		game_over_modal.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(game_over_modal, "modulate:a", 1.0, 0.4)

func hide_game_over() -> void:
	if game_over_modal:
		game_over_modal.visible = false

func _on_respawn_pressed() -> void:
	hide_game_over()
	# Pindah dan bangkit di kasur rumah desa
	get_tree().change_scene_to_file("res://asset/interior_house.tscn")

func _on_restart_pressed() -> void:
	hide_game_over()
	for k in ["has_apar", "quest_status", "quest_current_count"]:
		if get_tree().has_meta(k):
			get_tree().remove_meta(k)
	get_tree().reload_current_scene()

func _setup_inventory_grid() -> void:
	if not inv_grid:
		return
	for child in inv_grid.get_children():
		child.queue_free()

	for i in range(15):
		var slot_panel = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(72, 72)
		if slot_normal_style:
			slot_panel.add_theme_stylebox_override("panel", slot_normal_style)

		var margin = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		slot_panel.add_child(margin)

		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		margin.add_child(icon)

		var num_label = Label.new()
		num_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		num_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		num_label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.15, 0.75))
		num_label.add_theme_font_size_override("font_size", 12)
		num_label.text = " %d" % (i + 1)
		slot_panel.add_child(num_label)

		slot_panel.gui_input.connect(_on_inv_slot_gui_input.bind(i))
		inv_grid.add_child(slot_panel)

	# Muat tampilan awal untuk setiap slot yang sudah terisi item
	for slot_idx in range(15):
		_update_inv_slot_display(slot_idx)

func _update_inv_slot_display(slot_idx: int) -> void:
	if not inv_grid or slot_idx < 0 or slot_idx >= inv_grid.get_child_count():
		return
	var slot_panel = inv_grid.get_child(slot_idx)
	var margin = slot_panel.get_node_or_null("MarginContainer")
	var icon = margin.get_child(0) as TextureRect if margin and margin.get_child_count() > 0 else null
	var count_label = slot_panel.get_node_or_null("CountLabel") as Label

	if inventory_items.has(slot_idx):
		var it = inventory_items[slot_idx]
		var tex: Texture2D = it.get("icon")
		if not tex and slot_idx == 0 and item_icon_0:
			tex = item_icon_0.texture
		elif not tex and slot_idx == 1 and item_icon_1:
			tex = item_icon_1.texture
		if icon:
			icon.texture = tex

		var cnt = it.get("count", 1)
		if cnt > 1:
			if not count_label:
				count_label = Label.new()
				count_label.name = "CountLabel"
				count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
				count_label.size_flags_vertical = Control.SIZE_SHRINK_END
				count_label.add_theme_color_override("font_color", Color(0.2, 0.12, 0.05, 1.0))
				count_label.add_theme_font_size_override("font_size", 13)
				slot_panel.add_child(count_label)
			count_label.text = "x%d " % cnt
			count_label.visible = true
		elif count_label:
			count_label.visible = false
	else:
		if icon:
			icon.texture = null
		if count_label:
			count_label.visible = false

func add_item_to_inventory(item_id: String, item_name: String, item_desc: String, icon_path: String, count: int = 1) -> bool:
	var tex: Texture2D = null
	if FileAccess.file_exists(icon_path):
		var img = Image.load_from_file(icon_path)
		if img:
			tex = ImageTexture.create_from_image(img)

	# Cek apakah item bertipe sama sudah ada di inventory untuk stack
	for slot_idx in inventory_items.keys():
		var item = inventory_items[slot_idx]
		if item.get("id") == item_id:
			item["count"] = item.get("count", 1) + count
			if tex and not item.get("icon"):
				item["icon"] = tex
			_update_inv_slot_display(slot_idx)
			return true

	# Cari slot kosong pertama dari slot 0 sampai 14
	for slot_idx in range(15):
		if not inventory_items.has(slot_idx):
			inventory_items[slot_idx] = {
				"id": item_id,
				"name": item_name,
				"desc": item_desc,
				"icon": tex,
				"icon_path": icon_path,
				"count": count
			}
			# Jika masuk ke slot 2 (Hotbar Slot 3), tampilkan juga ikonnya di Hotbar
			if slot_idx == 2 and item_icon_2 and tex:
				item_icon_2.texture = tex
			_update_inv_slot_display(slot_idx)
			return true

	return false

func _on_inv_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_inv_item(slot_idx)

func _select_inv_item(slot_idx: int) -> void:
	if not inventory_items.has(slot_idx):
		if inv_detail_title: inv_detail_title.text = "Slot Kosong (%d)" % (slot_idx + 1)
		if inv_detail_desc: inv_detail_desc.text = "Ruang penyimpanan tas belum terisi. Item yang Anda temukan saat menjelajah akan disimpan di sini."
		if inv_detail_icon: inv_detail_icon.texture = null
		return

	var it = inventory_items[slot_idx]
	if inv_detail_title: inv_detail_title.text = it.get("name", "")
	if inv_detail_icon:
		var tex: Texture2D = it.get("icon")
		if not tex and slot_idx == 0 and item_icon_0:
			tex = item_icon_0.texture
		elif not tex and slot_idx == 1 and item_icon_1:
			tex = item_icon_1.texture
		inv_detail_icon.texture = tex

	if it.get("id") == "pemadam":
		if inv_detail_desc: inv_detail_desc.text = it.get("desc", "")
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_active_slot"):
			player.set_active_slot(0)
	elif it.get("id") == "pentungan":
		if inv_detail_desc: inv_detail_desc.text = it.get("desc", "")
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_active_slot"):
			player.set_active_slot(1)
	elif it.get("id") == "potion_red":
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("heal") and player.current_blood < player.max_blood:
			player.heal(40.0)
			it["count"] = it.get("count", 1) - 1
			if inv_detail_desc:
				inv_detail_desc.text = "Darah berhasil dipulihkan +40! Sisa ramuan di tas: %d botol." % it["count"]
			if it["count"] <= 0:
				inventory_items.erase(slot_idx)
				if slot_idx == 2 and item_icon_2:
					item_icon_2.texture = null
			_update_inv_slot_display(slot_idx)
		else:
			if inv_detail_desc:
				if player and player.current_blood >= player.max_blood:
					inv_detail_desc.text = it.get("desc", "") + "\n(Darah Anda sudah penuh 100/100!)"
				else:
					inv_detail_desc.text = it.get("desc", "") + "\n(Klik item ini untuk meminum dan memulihkan 40 Darah)"
	else:
		if inv_detail_desc:
			inv_detail_desc.text = it.get("desc", "") + " (Jumlah: %d)" % it.get("count", 1)
