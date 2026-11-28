extends CanvasLayer

signal dialogue_finished

@export var slot_normal_style: StyleBoxFlat
@export var slot_active_style: StyleBoxFlat
@export var btn_normal_style: StyleBoxFlat
@export var btn_pressed_style: StyleBoxFlat
@export var action_normal_style: StyleBoxFlat
@export var action_pressed_style: StyleBoxFlat

@onready var blood_bar: TextureProgressBar = %BloodBar
@onready var energy_bar: TextureProgressBar = %EnergyBar
@onready var blood_val_label: Label = %BloodValLabel
@onready var energy_val_label: Label = %EnergyValLabel
@onready var coin_bar_panel: PanelContainer = %CoinBarPanel
@onready var coin_val_label: Label = %CoinValLabel

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
@onready var prologue_backdrop: ColorRect = %PrologueBackdrop
@onready var prologue_panel: Control = %ProloguePanel
@onready var prologue_text_label: Label = %PrologueText
@onready var prologue_page_label: Label = %ProloguePageLabel
@onready var prologue_next_btn: Button = %PrologueNextBtn
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
var _default_dialogue_speaker: String = ""
var _is_prologue_dialogue: bool = false
var _dialogue_typing_tween: Tween = null
var _is_typing_dialogue: bool = false
var _sfx_talk: AudioStreamPlayer = null
const SFX_TALK_PATH := "res://asset/music/sfx/talkingsynth.mp3"
var inventory_items: Dictionary = {}

var slots: Array[PanelContainer] = []
var item_icons: Array[TextureRect] = []
var _hotbar_count_labels: Array[Label] = []

var blood_tween: Tween
var energy_tween: Tween
var current_active_slot: int = 0
var hotbar_equips: Array[String] = ["hand", "", ""]
var _selected_inv_slot: int = -1
var _equip_btn_row: HBoxContainer = null
var _drink_btn: Button = null
var coin_count: int = 0
var _obj_arrow_layer: Control = null
var _cliff_gate_body: StaticBody2D = null
var _cliff_gate_shape: CollisionShape2D = null
var _cliff_gate_sensor: Area2D = null
var _cliff_gate_warn_cd_msec: int = 0
var _player_at_cliff_gate: bool = false

func _ready() -> void:
	add_to_group("hud")
	slots = [slot_0, slot_1, slot_2]
	item_icons = [item_icon_0, item_icon_1, item_icon_2]
	_setup_hotbar_count_badges()

	# Pulihkan status quest, tas, hotbar, koin & APAR lintas scene (mis. saat keluar/masuk rumah/toko)
	if get_tree().has_meta("saved_coins"):
		coin_count = int(get_tree().get_meta("saved_coins", 0))
	if get_tree().has_meta("saved_inventory_items"):
		var saved = get_tree().get_meta("saved_inventory_items")
		if saved is Dictionary:
			inventory_items = saved.duplicate(true)
			for k in inventory_items.keys().duplicate():
				var it = inventory_items[k]
				if it is Dictionary and it.get("id") == "coin":
					if not get_tree().has_meta("saved_coins"):
						coin_count += int(it.get("count", 1))
					inventory_items.erase(k)
			get_tree().set_meta("saved_inventory_items", inventory_items.duplicate(true))
	get_tree().set_meta("saved_coins", coin_count)
	if get_tree().has_meta("hotbar_equips"):
		var eq = get_tree().get_meta("hotbar_equips")
		if eq is Array and eq.size() >= 3:
			hotbar_equips = ["hand", str(eq[1]), str(eq[2])]
	else:
		get_tree().set_meta("hotbar_equips", hotbar_equips.duplicate())
	if get_tree().has_meta("quest_status"):
		quest_status = str(get_tree().get_meta("quest_status"))
	if get_tree().has_meta("quest_current_count"):
		quest_current_count = int(get_tree().get_meta("quest_current_count"))
	if get_tree().has_meta("quest_target_count"):
		quest_target_count = int(get_tree().get_meta("quest_target_count"))
	var has_apar: bool = get_tree().get_meta("has_apar", false)
	var has_pentungan: bool = get_tree().get_meta("has_pentungan", false)

	# Slot 1 (index 0) selalu Tangan Kosong; Pentungan (Slot 2) & APAR (Slot 3) didapat setelah bicara dengan Kakek
	if has_pentungan:
		_register_pentungan_item()
	if has_apar:
		_register_apar_item()

	# Muat ikon tas ransel secara dinamis jika file ada
	if FileAccess.file_exists("res://asset/tools/tas.png"):
		var img_tas = Image.load_from_file("res://asset/tools/tas.png")
		if img_tas and tas_icon:
			tas_icon.texture = ImageTexture.create_from_image(img_tas)

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

	# Setup Analog Virtual Joystick, Panduan Kontrol, Panah Objektif & Suara Dialog
	_setup_joystick()
	_setup_controls_guide()
	_setup_objective_arrow()
	_setup_talk_sfx()

	# Hubungkan tombol next dialog & prolog
	if dialogue_next_btn:
		dialogue_next_btn.pressed.connect(advance_dialogue)
	if prologue_next_btn:
		prologue_next_btn.pressed.connect(advance_dialogue)

	# Hubungkan tombol Game Over
	if respawn_btn:
		respawn_btn.pressed.connect(_on_respawn_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)

	# Update visual awal
	_refresh_hotbar_icons()
	set_active_slot(current_active_slot)
	_update_quest_ui()
	_update_coin_ui()

	# Cari player di dalam scene secara otomatis
	var player = get_tree().get_first_node_in_group("player")
	if player:
		connect_player(player)
	else:
		get_tree().node_added.connect(_on_node_added)

	call_deferred("_setup_cliff_boss_gate")
	call_deferred("_maybe_start_opening_prologue")

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
		var was_same := (current_active_slot == slot_index)
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("set_active_slot"):
			player.set_active_slot(slot_index)
		else:
			set_active_slot(slot_index)
		if slot_index >= 0 and slot_index < hotbar_equips.size() and hotbar_equips[slot_index] == "potion_red":
			if was_same:
				if not consume_potion_from_hotbar():
					if player and "current_blood" in player and "max_blood" in player and player.current_blood >= player.max_blood:
						_show_quest_notif("Darah sudah penuh!", Color(0.85, 0.55, 0.15, 1.0))
			else:
				_show_quest_notif("Tekan [ E ] atau klik lagi untuk minum ramuan", Color(0.85, 0.32, 0.32, 1.0))

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

func flash_energy_bar() -> void:
	if not energy_bar:
		return
	var t = energy_bar.create_tween()
	t.tween_property(energy_bar, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.08)
	t.tween_property(energy_bar, "modulate", Color.WHITE, 0.14)

func _process(delta: float) -> void:
	# Jika tidak sedang di-drag manual, sinkronkan posisi knob joystick dengan tombol keyboard (WASD / Panah)
	if not _is_dragging_joystick and joystick_knob:
		var k_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var target_pos = _joystick_center - _knob_half_size + (k_vector * 32.0)
		joystick_knob.position = joystick_knob.position.lerp(target_pos, min(1.0, 18.0 * delta))
	if _obj_arrow_layer:
		_obj_arrow_layer.queue_redraw()
	if quest_status == "IN_PROGRESS":
		_check_fire_area_trigger()
	elif quest_status == "FIND_ARSONIST":
		_check_arsonist_encounter_trigger()
	elif quest_status == "QUEST2_GO_FOREST":
		_check_forest_arrival_trigger()
	elif quest_status == "QUEST2_EXPLORE_FOREST":
		_check_forest_monster_sight_trigger()
	if _player_at_cliff_gate and _is_cliff_boss_gate_locked():
		var now_msec := Time.get_ticks_msec()
		if now_msec - _cliff_gate_warn_cd_msec >= 2200:
			_cliff_gate_warn_cd_msec = now_msec
			_show_quest_notif("Padamkan api yang di bawah dulu!", Color(0.92, 0.36, 0.14, 1.0))

func _setup_objective_arrow() -> void:
	var ctrl := get_node_or_null("Control")
	if not ctrl or _obj_arrow_layer:
		return
	_obj_arrow_layer = Control.new()
	_obj_arrow_layer.name = "ObjectiveArrowLayer"
	_obj_arrow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_obj_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.add_child(_obj_arrow_layer)
	ctrl.move_child(_obj_arrow_layer, 0)
	_obj_arrow_layer.draw.connect(_on_draw_objective_arrow)

func _get_kakek_node() -> Node2D:
	var kakek := get_tree().get_first_node_in_group("npc") as Node2D
	if kakek and is_instance_valid(kakek):
		return kakek
	var cur := get_tree().current_scene
	if cur:
		return cur.get_node_or_null("NPC_Kakek") as Node2D
	return null

func _get_boss_location_node() -> Node2D:
	var cur := get_tree().current_scene
	if cur:
		var bn := cur.get_node_or_null("BossNormal") as Node2D
		if bn and is_instance_valid(bn) and not ("is_dead" in bn and bn.is_dead):
			return bn
	for b in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(b) and b is Node2D and not ("is_dead" in b and b.is_dead):
			return b as Node2D
	return null

func _get_nearest_burning_tree() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var best: Node2D = null
	var best_d := INF
	for t in get_tree().get_nodes_in_group("burning_tree"):
		if not is_instance_valid(t) or not (t is Node2D):
			continue
		if t.has_method("is_extinguished") and t.is_extinguished():
			continue
		var d := player.global_position.distance_to((t as Node2D).global_position) if player else 0.0
		if d < best_d:
			best_d = d
			best = t as Node2D
	return best

func _maybe_start_opening_prologue() -> void:
	if not is_inside_tree():
		return
	var cur := get_tree().current_scene
	if not cur or not cur.has_node("NPC_Kakek"):
		return
	if quest_status != "NOT_STARTED":
		return
	if get_tree().get_meta("prologue_shown", false):
		return
	get_tree().set_meta("prologue_shown", true)
	get_tree().remove_meta("prologue_pending")
	get_tree().set_meta("prologue_active", true)
	if prologue_backdrop:
		prologue_backdrop.visible = true
		prologue_backdrop.modulate = Color(1, 1, 1, 1)
		prologue_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree() or quest_status != "NOT_STARTED":
		_end_prologue_backdrop(false)
		return
	if is_dialogue_open():
		_end_prologue_backdrop(false)
		return
	dialogue_finished.connect(func():
		_end_prologue_backdrop(true)
	, CONNECT_ONE_SHOT)
	start_dialogue("Prolog", [
		"Di suatu pagi yang cerah, Rojali sedang berkeliling di desanya yang bernama Desa Rimba. Ia senang berjalan santai sambil menikmati pepohonan rindang yang membuat suasana terasa tenang dan nyaman.",
		"Saat sedang berjalan santai, tiba-tiba terlihat kepulan asap tebal muncul dari arah hutan! Rojali sontak terkejut melihat asap pekat tersebut.",
		"Kebetulan ia bertemu dengan seorang Kakek warga desa yang juga tampak terkejut. Tanpa berpikir panjang, Rojali pun segera menghampiri Kakek tersebut untuk bertanya."
	])

func _end_prologue_backdrop(fade: bool = true) -> void:
	get_tree().set_meta("prologue_active", false)
	if not prologue_backdrop or not prologue_backdrop.visible:
		return
	prologue_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fade and is_inside_tree():
		var t := prologue_backdrop.create_tween()
		t.tween_property(prologue_backdrop, "modulate:a", 0.0, 0.5)
		t.tween_callback(func():
			if prologue_backdrop:
				prologue_backdrop.visible = false
		)
	else:
		prologue_backdrop.visible = false

func _is_cliff_boss_gate_locked() -> bool:
	return quest_status in ["NOT_STARTED", "IN_PROGRESS", "TRIGGERING_FIRE_DIALOGUE", "EXTINGUISH_TREES"]

func _setup_cliff_boss_gate() -> void:
	if not is_inside_tree():
		return
	var cur := get_tree().current_scene
	if not cur or not cur.has_node("Lampu Jalan DLL"):
		return
	if _cliff_gate_body and is_instance_valid(_cliff_gate_body):
		_update_cliff_boss_gate()
		return
	_cliff_gate_body = StaticBody2D.new()
	_cliff_gate_body.name = "BossCliffGate"
	_cliff_gate_body.position = Vector2(432.0, 295.0)
	_cliff_gate_shape = CollisionShape2D.new()
	var gate_rect := RectangleShape2D.new()
	gate_rect.size = Vector2(42.0, 18.0)
	_cliff_gate_shape.shape = gate_rect
	_cliff_gate_body.add_child(_cliff_gate_shape)
	cur.add_child(_cliff_gate_body)

	_cliff_gate_sensor = Area2D.new()
	_cliff_gate_sensor.name = "BossCliffGateSensor"
	_cliff_gate_sensor.position = Vector2(432.0, 310.0)
	_cliff_gate_sensor.collision_layer = 0
	_cliff_gate_sensor.collision_mask = 1
	_cliff_gate_sensor.monitorable = false
	var sensor_shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = Vector2(46.0, 32.0)
	sensor_shape.shape = sensor_rect
	_cliff_gate_sensor.add_child(sensor_shape)
	_cliff_gate_sensor.body_entered.connect(_on_cliff_gate_sensor_entered)
	_cliff_gate_sensor.body_exited.connect(_on_cliff_gate_sensor_exited)
	cur.add_child(_cliff_gate_sensor)
	_update_cliff_boss_gate()

func _update_cliff_boss_gate() -> void:
	var locked := _is_cliff_boss_gate_locked()
	if _cliff_gate_shape and is_instance_valid(_cliff_gate_shape):
		_cliff_gate_shape.set_deferred("disabled", not locked)
	if _cliff_gate_sensor and is_instance_valid(_cliff_gate_sensor):
		_cliff_gate_sensor.set_deferred("monitoring", locked)
	if not locked:
		_player_at_cliff_gate = false

func _on_cliff_gate_sensor_entered(body: Node) -> void:
	if body.is_in_group("player") and _is_cliff_boss_gate_locked():
		_player_at_cliff_gate = true
		var now_msec := Time.get_ticks_msec()
		if now_msec - _cliff_gate_warn_cd_msec >= 1200:
			_cliff_gate_warn_cd_msec = now_msec
			_show_quest_notif("Padamkan api yang di bawah dulu!", Color(0.92, 0.36, 0.14, 1.0))

func _on_cliff_gate_sensor_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_at_cliff_gate = false

func _check_fire_area_trigger() -> void:
	if is_dialogue_open():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	var near_tree := _get_nearest_burning_tree()
	if near_tree and player.global_position.y <= 478.0 and player.global_position.distance_to(near_tree.global_position) <= 105.0:
		quest_status = "TRIGGERING_FIRE_DIALOGUE"
		var on_done := func() -> void:
			quest_status = "EXTINGUISH_TREES"
			get_tree().set_meta("quest_status", quest_status)
			_update_quest_ui()
		dialogue_finished.connect(on_done, CONNECT_ONE_SHOT)
		start_dialogue("Rojali", ["\"Ya ampun, kenapa bisa pohon ini kebakaran?!\""])

const EXTINGUISH_TREE_GOAL: int = 10

func _get_zone_fire_progress(boss_zone: bool) -> Vector2i:
	var trees := get_tree().get_nodes_in_group("burning_tree")
	var zone_total := 0
	var zone_done := 0
	for t in trees:
		if not is_instance_valid(t) or not (t is Node2D):
			continue
		var in_boss_zone := (t as Node2D).global_position.y < 320.0
		if in_boss_zone != boss_zone:
			continue
		zone_total += 1
		if t.has_method("is_extinguished") and t.is_extinguished():
			zone_done += 1
	return Vector2i(zone_done, zone_total)

func _get_extinguish_progress() -> Vector2i:
	var lp := _get_zone_fire_progress(false)
	if lp.y > 0:
		return Vector2i(mini(lp.x, EXTINGUISH_TREE_GOAL), mini(EXTINGUISH_TREE_GOAL, lp.y))
	return Vector2i(0, EXTINGUISH_TREE_GOAL)

func _get_remaining_fire_progress() -> Vector2i:
	var bp := _get_zone_fire_progress(true)
	if bp.y > 0:
		return bp
	return Vector2i(0, 8)

func on_burning_tree_extinguished(tree_y: float = 999.0) -> void:
	_update_quest_ui()
	if tree_y < 320.0:
		var bp := _get_zone_fire_progress(true)
		if quest_status == "EXTINGUISH_REMAINING" and (bp.y <= 0 or bp.x >= bp.y or _get_nearest_burning_tree() == null):
			quest_status = "READY_TO_TURN_IN"
			get_tree().set_meta("quest_status", quest_status)
			_update_quest_ui()
	else:
		var prog := _get_extinguish_progress()
		if quest_status == "EXTINGUISH_TREES" and prog.y > 0 and prog.x >= prog.y:
			quest_status = "TRIGGERING_ARSONIST_DIALOGUE"
			var on_done := func() -> void:
				quest_status = "FIND_ARSONIST"
				get_tree().set_meta("quest_status", quest_status)
				_update_quest_ui()
			dialogue_finished.connect(on_done, CONNECT_ONE_SHOT)
			start_dialogue("Rojali", ["\"Siapa yang melakukan pembakaran ini?!\""])

func _is_target_visible_and_close(player: Node2D, target: Node2D, max_dist: float) -> bool:
	var diff := target.global_position - player.global_position
	return diff.length() <= max_dist and absf(diff.x) <= 95.0 and absf(diff.y) <= 60.0

func _check_arsonist_encounter_trigger() -> void:
	if is_dialogue_open():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var boss := _get_boss_location_node()
	if not player or not is_instance_valid(player) or not boss or not is_instance_valid(boss):
		return
	if _is_target_visible_and_close(player, boss, 85.0):
		quest_status = "TRIGGERING_BOSS_INTRO"
		var on_done := func() -> void:
			quest_status = "DEFEAT_ARSONIST"
			get_tree().set_meta("quest_status", quest_status)
			_update_quest_ui()
		dialogue_finished.connect(on_done, CONNECT_ONE_SHOT)
		start_dialogue("Rojali", [
			"Rojali: Jadi kamu yang melakukan pembakaran ini?",
			"Pelaku Pembakar: Iya, memang kenapa? Hutan ini sengaja saya bakar agar saya bisa membangun lahan yang ingin saya bangun.",
			"Rojali: Sialan kau!"
		])

func on_arsonist_defeated() -> void:
	if quest_status == "DEFEAT_ARSONIST" or quest_status == "FIND_ARSONIST":
		var trees := get_tree().get_nodes_in_group("burning_tree")
		var total_t := trees.size()
		var done_t := 0
		for t in trees:
			if is_instance_valid(t) and t.has_method("is_extinguished") and t.is_extinguished():
				done_t += 1
		var remaining := maxi(0, total_t - done_t)
		if remaining > 0:
			get_tree().set_meta("remaining_fire_base", done_t)
			get_tree().set_meta("remaining_fire_target", mini(8, remaining))
			quest_status = "EXTINGUISH_REMAINING"
		else:
			quest_status = "READY_TO_TURN_IN"
		get_tree().set_meta("quest_status", quest_status)
		_update_quest_ui()

func _check_forest_arrival_trigger() -> void:
	if is_dialogue_open():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	# Area Forest berada di timur laut (kanan atas)
	if player.global_position.x >= 870.0 and player.global_position.y <= 360.0:
		quest_status = "TRIGGERING_Q2_ARRIVAL"
		var on_done := func() -> void:
			quest_status = "QUEST2_EXPLORE_FOREST"
			get_tree().set_meta("quest_status", quest_status)
			_update_quest_ui()
		dialogue_finished.connect(on_done, CONNECT_ONE_SHOT)
		start_dialogue("Rojali", ["Rojali: \"Monster apa yang muncul di daerah ini?\""])

func _check_forest_monster_sight_trigger() -> void:
	if is_dialogue_open():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var monster := _get_nearest_forest_slime(true)
	if not player or not is_instance_valid(player) or not monster or not is_instance_valid(monster):
		return
	if _is_target_visible_and_close(player, monster, 80.0):
		quest_status = "TRIGGERING_Q2_SIGHT"
		var on_done := func() -> void:
			_begin_quest2_slime_hunt()
		dialogue_finished.connect(on_done, CONNECT_ONE_SHOT)
		start_dialogue("Rojali", ["Rojali: \"Wah ternyata slime monsternya, aku harus segera membasminya!\""])

func _begin_quest2_slime_hunt() -> void:
	quest_status = "QUEST2_SLIME"
	var alive_slimes := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not ("is_dead" in e and e.is_dead):
			if not e.is_in_group("boss_normal"):
				alive_slimes += 1
	quest_target_count = maxi(1, alive_slimes)
	quest_current_count = 0
	get_tree().set_meta("quest_status", quest_status)
	get_tree().set_meta("quest_current_count", quest_current_count)
	get_tree().set_meta("quest_target_count", quest_target_count)
	_update_quest_ui()

func _get_nearest_forest_slime(include_boss_slime: bool = true) -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var best: Node2D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.is_in_group("boss_normal"):
			continue
		if not include_boss_slime and e.is_in_group("boss"):
			continue
		if "is_dead" in e and e.is_dead:
			continue
		var d := player.global_position.distance_to((e as Node2D).global_position) if player else 0.0
		if d < best_d:
			best_d = d
			best = e as Node2D
	return best

func _on_draw_objective_arrow() -> void:
	if not _obj_arrow_layer:
		return
	if not (quest_status in ["NOT_STARTED", "IN_PROGRESS", "EXTINGUISH_TREES", "FIND_ARSONIST", "DEFEAT_ARSONIST", "EXTINGUISH_REMAINING", "READY_TO_TURN_IN", "COMPLETED", "QUEST2_GO_FOREST", "QUEST2_EXPLORE_FOREST", "QUEST2_SLIME", "QUEST2_READY"]):
		return
	if is_dialogue_open():
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var target: Node2D = null
	var target_pos := Vector2.ZERO
	var has_target := false
	if quest_status == "IN_PROGRESS" or quest_status == "FIND_ARSONIST" or quest_status == "DEFEAT_ARSONIST":
		target = _get_boss_location_node()
	elif quest_status == "EXTINGUISH_TREES" or quest_status == "EXTINGUISH_REMAINING":
		target = _get_nearest_burning_tree()
	elif quest_status == "QUEST2_GO_FOREST":
		var cur := get_tree().current_scene
		if cur and cur.has_node("Tanah"):
			target_pos = Vector2(960.0, 260.0)
			has_target = true
	elif quest_status == "QUEST2_EXPLORE_FOREST" or quest_status == "QUEST2_SLIME":
		target = _get_nearest_forest_slime(true)
	else:
		target = _get_kakek_node()
	if target and is_instance_valid(target):
		target_pos = target.global_position
		has_target = true
	if not player or not is_instance_valid(player) or not has_target:
		return
	var diff := target_pos - player.global_position
	if diff.length() <= 45.0:
		return
	var xform := get_viewport().get_canvas_transform()
	var p_screen: Vector2 = xform * player.global_position
	var t_screen: Vector2 = xform * target_pos
	var dir := (t_screen - p_screen).normalized()
	if dir == Vector2.ZERO:
		return

	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	var arrow_pos := p_screen + dir * (48.0 * pulse)
	var vp_size := get_viewport().get_visible_rect().size
	arrow_pos.x = clampf(arrow_pos.x, 32.0, vp_size.x - 32.0)
	arrow_pos.y = clampf(arrow_pos.y, 32.0, vp_size.y - 32.0)

	var perp := Vector2(-dir.y, dir.x)
	var tip := arrow_pos + dir * 10.0
	var left := arrow_pos - dir * 6.0 + perp * 7.0
	var right := arrow_pos - dir * 6.0 - perp * 7.0
	var col := Color(1.0, 0.86, 0.2, 0.95)
	if quest_status == "IN_PROGRESS":
		col = Color(1.0, 0.52, 0.16, 0.95)
	elif quest_status == "READY_TO_TURN_IN" or quest_status == "QUEST2_READY":
		col = Color(0.35, 0.95, 0.5, 0.95)
	_obj_arrow_layer.draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, left + perp * 2.0 - dir * 2.0, right - perp * 2.0 - dir * 2.0]), Color(0.1, 0.06, 0.02, 0.9))
	_obj_arrow_layer.draw_colored_polygon(PackedVector2Array([tip, left, right]), col)

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
		var sep := guide_content.get_parent().get_node_or_null("HSeparator") as Control
		if sep:
			sep.visible = guide_content.visible
		var cg := get_node_or_null("%ControlsGuide") as Control
		if cg:
			cg.size.y = 0

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
	var joy_offset = touch_pos - _joystick_center
	var dist = joy_offset.length()
	if dist > _max_joystick_radius:
		joy_offset = joy_offset.normalized() * _max_joystick_radius
		dist = _max_joystick_radius

	if joystick_knob:
		joystick_knob.position = (_joystick_center + joy_offset) - _knob_half_size

	var deadzone = 8.0
	if dist > deadzone:
		_active_joystick_dir = joy_offset.normalized()
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
		if is_dialogue_open():
			if event.keycode == KEY_E or event.keycode == KEY_SPACE:
				advance_dialogue()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_ESCAPE:
				close_dialogue()
				get_viewport().set_input_as_handled()
				return

		# Kontrol tas inventory
		if event.keycode == KEY_B:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and inventory_modal and inventory_modal.visible:
			close_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and not event.echo and (not inventory_modal or not inventory_modal.visible):
			if current_active_slot >= 0 and current_active_slot < hotbar_equips.size() and hotbar_equips[current_active_slot] == "potion_red":
				if not _has_nearby_world_interactable():
					if not consume_potion_from_hotbar():
						var p = get_tree().get_first_node_in_group("player")
						if p and "current_blood" in p and "max_blood" in p and p.current_blood >= p.max_blood:
							_show_quest_notif("Darah sudah penuh!", Color(0.85, 0.55, 0.15, 1.0))
					get_viewport().set_input_as_handled()

func _has_nearby_world_interactable() -> bool:
	for n in get_tree().get_nodes_in_group("npc"):
		if is_instance_valid(n) and bool(n.get("_player_in_range")):
			return true
	for it in get_tree().get_nodes_in_group("item_pickup"):
		if is_instance_valid(it) and bool(it.get("_can_pickup")) and not bool(it.get("_is_picked_up")):
			return true
	for d in get_tree().get_nodes_in_group("door"):
		if is_instance_valid(d) and bool(d.get("_player_in_range")):
			return true
	return false

func _setup_talk_sfx() -> void:
	if _sfx_talk:
		return
	_sfx_talk = AudioStreamPlayer.new()
	_sfx_talk.volume_db = -8.0
	if ResourceLoader.exists(SFX_TALK_PATH):
		_sfx_talk.stream = load(SFX_TALK_PATH)
	elif FileAccess.file_exists(SFX_TALK_PATH):
		_sfx_talk.stream = AudioStreamMP3.load_from_file(SFX_TALK_PATH)
	_sfx_talk.finished.connect(func():
		if _is_typing_dialogue and is_dialogue_open() and _sfx_talk.stream and is_inside_tree():
			_sfx_talk.play()
	)
	add_child(_sfx_talk)

func _start_talk_sfx(speaker_name: String) -> void:
	if not _sfx_talk or not _sfx_talk.stream:
		return
	_sfx_talk.volume_db = -14.0 if speaker_name == "Prolog" else -8.0
	if speaker_name == "Rojali":
		_sfx_talk.pitch_scale = 1.06
	elif speaker_name == "Pelaku Pembakar":
		_sfx_talk.pitch_scale = 0.86
	else:
		_sfx_talk.pitch_scale = 0.94
	if not _sfx_talk.playing:
		_sfx_talk.play()

func _stop_talk_sfx() -> void:
	if _sfx_talk and _sfx_talk.playing:
		_sfx_talk.stop()

func is_dialogue_open() -> bool:
	return (dialogue_modal != null and dialogue_modal.visible) or (prologue_panel != null and prologue_panel.visible)

func _get_active_dialogue_label() -> Label:
	if _is_prologue_dialogue and prologue_text_label:
		return prologue_text_label
	return dialogue_text

func _get_active_next_btn() -> Button:
	if _is_prologue_dialogue and prologue_next_btn:
		return prologue_next_btn
	return dialogue_next_btn

func _update_dialogue_next_button_text() -> void:
	var btn := _get_active_next_btn()
	if not btn:
		return
	var is_last := current_dialogue_idx >= current_dialogue_lines.size() - 1
	if _is_prologue_dialogue:
		btn.text = "Mulai [ E ] ✓" if is_last else "Lanjut [ E ] ▶"
	else:
		btn.text = "Selesai [ E ] ✓" if is_last else "Lanjut [ E ] ▶"

func _finish_dialogue_typing() -> void:
	if _dialogue_typing_tween and _dialogue_typing_tween.is_valid():
		_dialogue_typing_tween.kill()
	_dialogue_typing_tween = null
	_is_typing_dialogue = false
	_stop_talk_sfx()
	if dialogue_text:
		dialogue_text.visible_characters = -1
	if prologue_text_label:
		prologue_text_label.visible_characters = -1

func _apply_dialogue_line(raw_line: String) -> void:
	var shown_speaker := _default_dialogue_speaker
	var shown_text := raw_line
	if raw_line.begins_with("Rojali:"):
		shown_speaker = "Rojali"
		shown_text = raw_line.substr(7).strip_edges()
	elif raw_line.begins_with("Kakek:"):
		shown_speaker = "Kakek Warga Desa"
		shown_text = raw_line.substr(6).strip_edges()
	elif raw_line.begins_with("Pelaku Pembakar:"):
		shown_speaker = "Pelaku Pembakar"
		shown_text = raw_line.substr(16).strip_edges()
	if not _is_prologue_dialogue and speaker_label:
		speaker_label.text = shown_speaker
	if _is_prologue_dialogue and prologue_page_label:
		prologue_page_label.text = "Halaman %d / %d" % [current_dialogue_idx + 1, maxi(1, current_dialogue_lines.size())]
	var target_label := _get_active_dialogue_label()
	if target_label:
		if _dialogue_typing_tween and _dialogue_typing_tween.is_valid():
			_dialogue_typing_tween.kill()
		target_label.text = shown_text
		var total_chars := shown_text.length()
		if total_chars > 0:
			target_label.visible_characters = 0
			_is_typing_dialogue = true
			_start_talk_sfx(shown_speaker)
			var duration := clampf(float(total_chars) * 0.025, 0.35, 2.8)
			_dialogue_typing_tween = create_tween()
			_dialogue_typing_tween.tween_property(target_label, "visible_characters", total_chars, duration)
			_dialogue_typing_tween.tween_callback(func():
				_is_typing_dialogue = false
				_stop_talk_sfx()
				if target_label:
					target_label.visible_characters = -1
			)
		else:
			target_label.visible_characters = -1
			_is_typing_dialogue = false
			_stop_talk_sfx()

func start_dialogue(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_default_dialogue_speaker = speaker
	_is_prologue_dialogue = (speaker == "Prolog")
	current_dialogue_lines = lines
	current_dialogue_idx = 0
	_apply_dialogue_line(current_dialogue_lines[0])
	_update_dialogue_next_button_text()
	if _is_prologue_dialogue and prologue_panel:
		if dialogue_modal:
			dialogue_modal.visible = false
		prologue_panel.visible = true
		prologue_panel.modulate = Color(1, 1, 1, 1)
	else:
		if prologue_panel:
			prologue_panel.visible = false
		if dialogue_modal:
			dialogue_modal.visible = true

func advance_dialogue() -> void:
	if _is_typing_dialogue:
		_finish_dialogue_typing()
		return
	current_dialogue_idx += 1
	if current_dialogue_idx < current_dialogue_lines.size():
		_apply_dialogue_line(current_dialogue_lines[current_dialogue_idx])
		_update_dialogue_next_button_text()
	else:
		close_dialogue()
		dialogue_finished.emit()

func close_dialogue() -> void:
	_finish_dialogue_typing()
	if dialogue_modal:
		dialogue_modal.visible = false
	if prologue_panel:
		prologue_panel.visible = false
	_is_prologue_dialogue = false
	current_dialogue_lines.clear()
	current_dialogue_idx = 0
	if get_tree().get_meta("prologue_active", false):
		_end_prologue_backdrop(true)

func _register_pentungan_item() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists("res://asset/tools/pentungan.png"):
		tex = load("res://asset/tools/pentungan.png")
	elif FileAccess.file_exists("res://asset/tools/pentungan.png"):
		var img = Image.load_from_file("res://asset/tools/pentungan.png")
		if img:
			tex = ImageTexture.create_from_image(img)
	inventory_items[1] = {
		"id": "pentungan",
		"name": "Pentungan Kayu",
		"desc": "Senjata pemukul dasar pemberian Kakek untuk berjaga-jaga. Mengkonsumsi 8 energi saat diayunkan.",
		"icon": tex
	}
	if hotbar_equips[1] != "pentungan" and hotbar_equips[2] != "pentungan":
		if hotbar_equips[1] == "":
			hotbar_equips[1] = "pentungan"
		elif hotbar_equips[2] == "":
			hotbar_equips[2] = "pentungan"
		else:
			hotbar_equips[1] = "pentungan"
		get_tree().set_meta("hotbar_equips", hotbar_equips.duplicate())
	get_tree().set_meta("saved_inventory_items", inventory_items.duplicate(true))
	_update_inv_slot_display(1)
	_refresh_hotbar_icons()

func _register_apar_item() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists("res://asset/tools/pemadam.png"):
		tex = load("res://asset/tools/pemadam.png")
	elif FileAccess.file_exists("res://asset/tools/pemadam.png"):
		var img = Image.load_from_file("res://asset/tools/pemadam.png")
		if img:
			tex = ImageTexture.create_from_image(img)
	inventory_items[0] = {
		"id": "pemadam",
		"name": "Alat Pemadam Api (APAR)",
		"desc": "Pemberian Kakek untuk memadamkan api di sekitar desa dan hutan.",
		"icon": tex
	}
	if hotbar_equips[1] != "pemadam" and hotbar_equips[2] != "pemadam":
		if hotbar_equips[2] == "":
			hotbar_equips[2] = "pemadam"
		elif hotbar_equips[1] == "":
			hotbar_equips[1] = "pemadam"
		else:
			hotbar_equips[2] = "pemadam"
		get_tree().set_meta("hotbar_equips", hotbar_equips.duplicate())
	_update_inv_slot_display(0)
	_refresh_hotbar_icons()

func _find_item_icon(item_id: String) -> Texture2D:
	if item_id == "hand":
		return load("res://asset/ui/icon_hand.png") if ResourceLoader.exists("res://asset/ui/icon_hand.png") else null
	if item_id == "":
		return null
	for k in inventory_items.keys():
		var it = inventory_items[k]
		if it.get("id") == item_id:
			var t: Texture2D = it.get("icon")
			if t:
				return t
	if item_id == "pentungan" and ResourceLoader.exists("res://asset/tools/pentungan.png"):
		return load("res://asset/tools/pentungan.png")
	if item_id == "pemadam" and ResourceLoader.exists("res://asset/tools/pemadam.png"):
		return load("res://asset/tools/pemadam.png")
	if item_id == "potion_red" and ResourceLoader.exists("res://asset/tools/potion_red.png"):
		return load("res://asset/tools/potion_red.png")
	return null

func _setup_hotbar_count_badges() -> void:
	_hotbar_count_labels.clear()
	for i in range(slots.size()):
		var s := slots[i]
		if not s:
			_hotbar_count_labels.append(null)
			continue
		var lbl := s.get_node_or_null("HotbarCountLabel") as Label
		if not lbl:
			lbl = Label.new()
			lbl.name = "HotbarCountLabel"
			lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
			lbl.size_flags_vertical = Control.SIZE_SHRINK_END
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.04, 1.0))
			lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.85, 0.95))
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.visible = false
			s.add_child(lbl)
		_hotbar_count_labels.append(lbl)

func _get_inventory_item_count(item_id: String) -> int:
	if item_id == "":
		return 0
	var total := 0
	for k in inventory_items.keys():
		var it = inventory_items[k]
		if it is Dictionary and str(it.get("id", "")) == item_id:
			total += int(it.get("count", 1))
	return total

func _refresh_hotbar_icons() -> void:
	hotbar_equips[0] = "hand"
	if item_icon_0:
		item_icon_0.texture = _find_item_icon("hand")
	if item_icon_1:
		item_icon_1.texture = _find_item_icon(hotbar_equips[1])
	if item_icon_2:
		item_icon_2.texture = _find_item_icon(hotbar_equips[2])
	for i in range(_hotbar_count_labels.size()):
		var lbl := _hotbar_count_labels[i]
		if not lbl:
			continue
		var eq_id: String = hotbar_equips[i] if i < hotbar_equips.size() else ""
		var cnt := _get_inventory_item_count(eq_id)
		if eq_id == "potion_red" and cnt > 0:
			lbl.text = "x%d " % cnt
			lbl.visible = true
		else:
			lbl.visible = false
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("refresh_held_tool_visual"):
		player.refresh_held_tool_visual()

func equip_item_to_hotbar(target_slot: int, item_id: String) -> void:
	if target_slot != 1 and target_slot != 2:
		return
	var other_slot := 2 if target_slot == 1 else 1
	if hotbar_equips[other_slot] == item_id:
		# Tukar posisi antara Slot 2 dan Slot 3
		var prev := hotbar_equips[target_slot]
		hotbar_equips[target_slot] = item_id
		hotbar_equips[other_slot] = prev
	else:
		hotbar_equips[target_slot] = item_id
	get_tree().set_meta("hotbar_equips", hotbar_equips.duplicate())
	_refresh_hotbar_icons()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_active_slot"):
		player.set_active_slot(target_slot)
	if player and player.has_method("refresh_held_tool_visual"):
		player.refresh_held_tool_visual()

func unlock_pentungan() -> void:
	get_tree().set_meta("has_pentungan", true)
	_register_pentungan_item()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("grant_pentungan"):
		player.grant_pentungan()

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

func start_quest_2() -> void:
	quest_status = "QUEST2_GO_FOREST"
	quest_current_count = 0
	get_tree().set_meta("quest_status", quest_status)
	get_tree().set_meta("quest_current_count", quest_current_count)
	_update_quest_ui()
	_show_quest_notif("📜 Quest 2 Baru: Pergi ke Forest!", Color(0.85, 0.55, 0.12, 1.0))

func add_quest_progress(target_type: String, amount: int = 1) -> void:
	if quest_status != "IN_PROGRESS" and quest_status != "QUEST2_SLIME":
		return
	if target_type == "slime":
		quest_current_count = min(quest_target_count, quest_current_count + amount)
		if quest_status == "QUEST2_SLIME" and quest_current_count >= quest_target_count:
			quest_status = "QUEST2_READY"
		get_tree().set_meta("quest_status", quest_status)
		get_tree().set_meta("quest_current_count", quest_current_count)
		_update_quest_ui()

func complete_quest() -> void:
	if quest_status != "READY_TO_TURN_IN":
		return
	quest_status = "COMPLETED"
	get_tree().set_meta("quest_status", quest_status)
	add_coins(10)
	_update_quest_ui()
	_show_quest_notif("✓ Misi Telah Selesai!", Color(0.2, 0.65, 0.3, 1.0))

func complete_quest_2() -> void:
	if quest_status != "QUEST2_READY":
		return
	quest_status = "QUEST2_COMPLETED"
	get_tree().set_meta("quest_status", quest_status)
	add_coins(25)
	_update_quest_ui()
	_show_quest_notif("✓ Quest 2 Telah Selesai!", Color(0.2, 0.65, 0.3, 1.0))

func _show_quest_notif(msg: String, border_col: Color = Color(0.2, 0.65, 0.3, 1.0)) -> void:
	var ctrl := get_node_or_null("Control")
	if not ctrl:
		return
	var prev := ctrl.get_node_or_null("QuestCompleteNotif")
	if prev:
		ctrl.remove_child(prev)
		prev.queue_free()
	var panel := PanelContainer.new()
	panel.name = "QuestCompleteNotif"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.92, 0.82, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_col
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 24
	style.content_margin_top = 12
	style.content_margin_right = 24
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.18, 0.12, 0.06, 1.0))
	panel.add_child(lbl)

	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 72.0
	panel.offset_left = -250.0
	panel.offset_right = 250.0
	panel.modulate.a = 0.0
	ctrl.add_child(panel)

	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.3)
	t.tween_interval(3.0)
	t.tween_property(panel, "modulate:a", 0.0, 0.45)
	t.tween_callback(panel.queue_free)

func _update_quest_ui() -> void:
	if not quest_tracker:
		return
	quest_tracker.visible = true
	if quest_reward_label:
		quest_reward_label.visible = false
	if quest_status == "NOT_STARTED":
		if quest_title_label: quest_title_label.text = "Temui Kakek"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "IN_PROGRESS":
		if quest_title_label: quest_title_label.text = "Misi Kakek: Lihat kelokasi tempat kebakaran tersebut"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "EXTINGUISH_TREES":
		if quest_title_label: quest_title_label.text = "Padamkan api dari pohon"
		if quest_progress_label:
			var prog := _get_extinguish_progress()
			quest_progress_label.visible = prog.y > 0
			quest_progress_label.text = "• Pohon padam: %d / %d" % [prog.x, prog.y]
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15, 1.0))
	elif quest_status == "FIND_ARSONIST":
		if quest_title_label: quest_title_label.text = "Cari orang yang melakukan pembakaran hutan ini"
		if quest_progress_label:
			var bp_find := _get_remaining_fire_progress()
			quest_progress_label.visible = bp_find.y > 0
			quest_progress_label.text = "• Pohon padam: %d / %d" % [bp_find.x, bp_find.y]
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15, 1.0))
	elif quest_status == "DEFEAT_ARSONIST":
		if quest_title_label: quest_title_label.text = "Kalahkan pelaku pembakar hutan"
		if quest_progress_label:
			var bp_boss := _get_remaining_fire_progress()
			quest_progress_label.visible = bp_boss.y > 0
			quest_progress_label.text = "• Pohon padam: %d / %d" % [bp_boss.x, bp_boss.y]
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15, 1.0))
	elif quest_status == "EXTINGUISH_REMAINING":
		if quest_title_label: quest_title_label.text = "Padamkan api yang masih menyala"
		if quest_progress_label:
			var rem := _get_remaining_fire_progress()
			quest_progress_label.visible = rem.y > 0
			quest_progress_label.text = "• Pohon padam: %d / %d" % [rem.x, rem.y]
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15, 1.0))
	elif quest_status == "READY_TO_TURN_IN":
		if quest_title_label: quest_title_label.text = "Misi Selesai! (Kembali ke Kakek)"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "COMPLETED":
		if quest_title_label: quest_title_label.text = "Temui Kakek (Quest 2)"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "QUEST2_GO_FOREST":
		if quest_title_label: quest_title_label.text = "Pergi ke Forest"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "QUEST2_EXPLORE_FOREST":
		if quest_title_label: quest_title_label.text = "Jelajahi Forest"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "QUEST2_SLIME":
		if quest_title_label: quest_title_label.text = "Bunuh slime-slime ini"
		if quest_progress_label:
			quest_progress_label.visible = true
			quest_progress_label.text = "• Slime terbasmi: %d / %d" % [quest_current_count, quest_target_count]
			quest_progress_label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15, 1.0))
	elif quest_status == "QUEST2_READY":
		if quest_title_label: quest_title_label.text = "Quest 2 Selesai! (Kembali ke Kakek)"
		if quest_progress_label: quest_progress_label.visible = false
	elif quest_status == "QUEST2_COMPLETED":
		if quest_title_label: quest_title_label.text = "✓ Semua Misi Selesai"
		if quest_progress_label:
			quest_progress_label.visible = true
			quest_progress_label.text = "Desa dan Forest telah aman!"
			quest_progress_label.add_theme_color_override("font_color", Color(0.2, 0.5, 0.25, 1.0))
	quest_tracker.size.y = 0
	_update_cliff_boss_gate()

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

func on_boss_defeated(_title: String) -> void:
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
	get_tree().set_meta("minimap_interior_pos", Vector2(760.0, 580.0))
	# Pindah dan bangkit di kasur rumah desa
	get_tree().change_scene_to_file("res://asset/interior_house.tscn")

func _on_restart_pressed() -> void:
	hide_game_over()
	# Pertahankan progres misi, item, koin, dan pohon padam saat mengulang scene setelah kalah
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
	if item_id == "coin":
		add_coins(count)
		return true

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
			get_tree().set_meta("saved_inventory_items", inventory_items.duplicate(true))
			_auto_assign_potion_hotbar(item_id)
			_refresh_hotbar_icons()
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
			_update_inv_slot_display(slot_idx)
			get_tree().set_meta("saved_inventory_items", inventory_items.duplicate(true))
			_auto_assign_potion_hotbar(item_id)
			_refresh_hotbar_icons()
			return true

	return false

func _auto_assign_potion_hotbar(item_id: String) -> void:
	if item_id != "potion_red":
		return
	if hotbar_equips[1] == "potion_red" or hotbar_equips[2] == "potion_red":
		return
	if hotbar_equips[2] != "":
		get_tree().set_meta("saved_slot2_before_potion", hotbar_equips[2])
	hotbar_equips[2] = "potion_red"
	get_tree().set_meta("hotbar_equips", hotbar_equips.duplicate())

func _update_coin_ui() -> void:
	if coin_val_label:
		coin_val_label.text = str(coin_count)

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coin_count += amount
	get_tree().set_meta("saved_coins", coin_count)
	_update_coin_ui()
	if coin_bar_panel:
		var t = coin_bar_panel.create_tween()
		t.tween_property(coin_bar_panel, "modulate", Color(1.25, 1.15, 0.75, 1.0), 0.1)
		t.tween_property(coin_bar_panel, "modulate", Color.WHITE, 0.18)

func get_coin_count() -> int:
	return coin_count

func spend_coins(amount: int) -> bool:
	if coin_count < amount:
		return false
	coin_count -= amount
	get_tree().set_meta("saved_coins", coin_count)
	_update_coin_ui()
	return true

func _on_inv_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_inv_item(slot_idx)

func _ensure_equip_buttons() -> void:
	if _equip_btn_row or not inv_detail_desc:
		return
	var parent_vbox := inv_detail_desc.get_parent()
	if not parent_vbox:
		return
	_drink_btn = Button.new()
	_drink_btn.text = "Minum (+40 Darah)"
	_drink_btn.focus_mode = Control.FOCUS_NONE
	_drink_btn.add_theme_font_size_override("font_size", 13)
	_drink_btn.visible = false
	_drink_btn.pressed.connect(func():
		drink_potion_from_inventory(_selected_inv_slot)
	)
	parent_vbox.add_child(_drink_btn)

	_equip_btn_row = HBoxContainer.new()
	_equip_btn_row.add_theme_constant_override("separation", 8)
	parent_vbox.add_child(_equip_btn_row)
	for s_idx in [1, 2]:
		var btn := Button.new()
		btn.text = "Pasang Slot %d" % (s_idx + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func():
			if inventory_items.has(_selected_inv_slot):
				equip_item_to_hotbar(s_idx, str(inventory_items[_selected_inv_slot].get("id", "")))
		)
		_equip_btn_row.add_child(btn)

func drink_potion_from_inventory(slot_idx: int) -> bool:
	if not inventory_items.has(slot_idx):
		return false
	var it = inventory_items[slot_idx]
	if str(it.get("id", "")) != "potion_red":
		return false
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_method("drink_potion"):
		return false
	if not player.drink_potion(40.0):
		if inv_detail_desc:
			inv_detail_desc.text = it.get("desc", "") + "\n(Darah Anda sudah penuh %d/%d!)" % [ceil(player.current_blood), ceil(player.max_blood)]
		return false

	it["count"] = int(it.get("count", 1)) - 1
	if it["count"] <= 0:
		inventory_items.erase(slot_idx)
		var restore_slot2 := str(get_tree().get_meta("saved_slot2_before_potion", ""))
		if restore_slot2 == "" and get_tree().get_meta("has_apar", false) and hotbar_equips[1] != "pemadam":
			restore_slot2 = "pemadam"
		for i in [1, 2]:
			if hotbar_equips[i] == "potion_red":
				hotbar_equips[i] = restore_slot2 if (i == 2 and restore_slot2 != "" and hotbar_equips[1] != restore_slot2) else ""
		get_tree().remove_meta("saved_slot2_before_potion")
		get_tree().set_meta("hotbar_equips", hotbar_equips.duplicate())
	_refresh_hotbar_icons()
	get_tree().set_meta("saved_inventory_items", inventory_items.duplicate(true))
	_update_inv_slot_display(slot_idx)
	if inventory_modal and inventory_modal.visible:
		close_inventory()
	return true

func consume_potion_from_hotbar() -> bool:
	for k in inventory_items.keys():
		var it = inventory_items[k]
		if it is Dictionary and str(it.get("id", "")) == "potion_red":
			return drink_potion_from_inventory(k)
	return false

func _select_inv_item(slot_idx: int) -> void:
	_selected_inv_slot = slot_idx
	_ensure_equip_buttons()
	if not inventory_items.has(slot_idx):
		if _equip_btn_row: _equip_btn_row.visible = false
		if _drink_btn: _drink_btn.visible = false
		if inv_detail_title: inv_detail_title.text = "Slot Kosong (%d)" % (slot_idx + 1)
		if inv_detail_desc: inv_detail_desc.text = "Ruang penyimpanan tas belum terisi."
		if inv_detail_icon: inv_detail_icon.texture = null
		return

	var it = inventory_items[slot_idx]
	var item_id: String = str(it.get("id", ""))
	if _equip_btn_row:
		_equip_btn_row.visible = (item_id != "coin")
	if _drink_btn:
		_drink_btn.visible = (item_id == "potion_red")
	if inv_detail_title: inv_detail_title.text = it.get("name", "")
	if inv_detail_icon:
		inv_detail_icon.texture = _find_item_icon(item_id)

	if item_id == "pemadam" or item_id == "pentungan":
		if inv_detail_desc: inv_detail_desc.text = it.get("desc", "") + "\n(Pilih 'Pasang Slot 2' atau 'Pasang Slot 3' untuk menukar slot)"
	elif item_id == "potion_red":
		var player = get_tree().get_first_node_in_group("player")
		if inv_detail_desc:
			if player and player.current_blood >= player.max_blood:
				inv_detail_desc.text = it.get("desc", "") + "\n(Darah penuh %d/%d. Bisa juga dipasang ke Hotbar Slot 2/3!)" % [ceil(player.current_blood), ceil(player.max_blood)]
			else:
				inv_detail_desc.text = it.get("desc", "") + "\n(Tekan 'Minum (+40 Darah)' atau pasang ke Hotbar lalu tekan Serang)"
	else:
		if inv_detail_desc:
			inv_detail_desc.text = it.get("desc", "") + " (Jumlah: %d)" % it.get("count", 1)
