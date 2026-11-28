extends Node2D

@onready var player: Node2D = $Player
@onready var shop_prompt: Label = $ShopArea/ShopPrompt
@onready var door_prompt: Label = $DoorArea/DoorPrompt
@onready var fade_rect: ColorRect = $FadeCanvas/FadeRect
@onready var store_modal: Control = $FadeCanvas/StoreModal
@onready var coins_label: Label = $FadeCanvas/StoreModal/Panel/Margin/VBox/Header/HeaderInfo/CoinsLabel
@onready var greeting_label: Label = $FadeCanvas/StoreModal/Panel/Margin/VBox/Header/HeaderInfo/GreetingLabel
@onready var items_list: VBoxContainer = $FadeCanvas/StoreModal/Panel/Margin/VBox/ItemsScroll/ItemsList
@onready var close_btn: Button = $FadeCanvas/StoreModal/Panel/Margin/VBox/Footer/CloseBtn

var _can_shop: bool = false
const STORE_LOCKED: bool = true
var _can_exit: bool = false
var _is_busy: bool = false
var _anim_time: float = 0.0
var _keeper_base_scale := Vector2(0.85, 0.85)
var _keeper_hop_offset: float = 0.0

@onready var keeper_node: Node2D = $StoreKeeper
@onready var keeper_sprite: Sprite2D = $StoreKeeper/Sprite2D
@onready var keeper_bubble: Label = $StoreKeeper/GreetingBubble

const SHOP_ITEMS := [
	{
		"id": "bat_upgrade",
		"name": "Pentungan Kayu",
		"desc": "Pentungan berlapis besi. +10 Damage pukulan.",
		"price": 50,
		"icon": "res://asset/ui/icon_bat_upgrade.png",
		"unique": true,
		"meta_dmg": 10.0
	},
	{
		"id": "forest_axe",
		"name": "Kapak Penjaga",
		"desc": "Kapak tajam berkekuatan tinggi. +20 Damage & +8 Jangkauan.",
		"price": 120,
		"icon": "res://asset/ui/icon_axe.png",
		"unique": true,
		"meta_dmg": 20.0,
		"meta_range": 8.0
	},
	{
		"id": "light_armor",
		"name": "Pelindung Baja Ringan",
		"desc": "Mengurangi 25% damage musuh & menambah +25 Max Darah.",
		"price": 80,
		"icon": "res://asset/ui/icon_shield.png",
		"unique": true,
		"meta_dr": 0.25,
		"meta_hp": 25.0
	},
	{
		"id": "potion_red",
		"name": "Ramuan Pemulih",
		"desc": "Disimpan di Tas. Memulihkan +40 Darah saat diminum.",
		"price": 30,
		"icon": "res://asset/tools/potion_red.png",
		"unique": false
	}
]

func _ready() -> void:
	_setup_textures()
	if shop_prompt:
		shop_prompt.visible = false
	if door_prompt:
		door_prompt.visible = false
	if store_modal:
		store_modal.visible = false
	if close_btn:
		close_btn.pressed.connect(_close_store)
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.35)

func _process(delta: float) -> void:
	_anim_time += delta
	if keeper_sprite:
		# Animasi bernapas & gerak halus agar NPC terlihat hidup
		var breath := sin(_anim_time * 3.0)
		var sway := sin(_anim_time * 1.6)
		keeper_sprite.scale = Vector2(
			_keeper_base_scale.x - breath * 0.018,
			_keeper_base_scale.y + breath * 0.028
		)
		keeper_sprite.position.y = breath * 0.7 + _keeper_hop_offset
		keeper_sprite.rotation = sway * 0.025
		if player and is_instance_valid(player) and keeper_node:
			# Sprite asli menghadap kiri; balik ke kanan jika player di kanan
			keeper_sprite.flip_h = player.global_position.x > keeper_node.global_position.x
	if keeper_bubble and keeper_bubble.visible:
		keeper_bubble.position.y = -34.0 + sin(_anim_time * 4.0) * 1.2

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _setup_textures() -> void:
	var t_floor := _load_texture("res://asset/interior/floor_wood.png")
	var t_wall := _load_texture("res://asset/interior/wall_wood.png")
	var t_carpet := _load_texture("res://asset/ui/store_carpet.png")
	var t_counter := _load_texture("res://asset/ui/store_counter.png")
	var t_rack := _load_texture("res://asset/ui/store_weapon_rack.png")
	var t_shelf := _load_texture("res://asset/ui/store_potion_shelf.png")
	var t_table := _load_texture("res://asset/interior/table.png")
	var t_doormat := _load_texture("res://asset/interior/door_mat.png")
	var t_keeper := _load_texture("res://asset/ui/npc_shopkeeper.png")
	var t_portrait := _load_texture("res://asset/craftpix-net-934138-free-medieval-npc-avatars-pixel-pack-for-dialogue/NPC_3/Smile.png")
	var t_axe := _load_texture("res://asset/ui/icon_axe.png")
	var t_shield := _load_texture("res://asset/ui/icon_shield.png")

	if t_floor and has_node("Floor"): $Floor.texture = t_floor
	if t_wall:
		if has_node("WallTop"): $WallTop.texture = t_wall
		if has_node("WallLeft"): $WallLeft.texture = t_wall
		if has_node("WallRight"): $WallRight.texture = t_wall
		if has_node("WallBottomLeft"): $WallBottomLeft.texture = t_wall
		if has_node("WallBottomRight"): $WallBottomRight.texture = t_wall
	if t_carpet and has_node("Rug"): $Rug.texture = t_carpet
	if t_doormat and has_node("DoorMat"): $DoorMat.texture = t_doormat
	if t_counter and has_node("CounterCollision/Sprite2D"):
		$CounterCollision/Sprite2D.texture = t_counter
	if t_rack:
		if has_node("WeaponRackLeft"): $WeaponRackLeft.texture = t_rack
		if has_node("WeaponRackRight"): $WeaponRackRight.texture = t_rack
	if t_shelf and has_node("PotionShelf"):
		$PotionShelf.texture = t_shelf
	if t_table:
		if has_node("SideTableLeft/Sprite2D"): $SideTableLeft/Sprite2D.texture = t_table
		if has_node("SideTableRight/Sprite2D"): $SideTableRight/Sprite2D.texture = t_table
	if t_axe and has_node("SideTableLeft/DisplayAxe"):
		$SideTableLeft/DisplayAxe.texture = t_axe
	if t_shield and has_node("SideTableRight/DisplayShield"):
		$SideTableRight/DisplayShield.texture = t_shield
	if t_keeper and has_node("StoreKeeper/Sprite2D"):
		$StoreKeeper/Sprite2D.texture = t_keeper
	if t_portrait and has_node("FadeCanvas/StoreModal/Panel/Margin/VBox/Header/PortraitFrame/Portrait"):
		$FadeCanvas/StoreModal/Panel/Margin/VBox/Header/PortraitFrame/Portrait.texture = t_portrait

func _unhandled_input(event: InputEvent) -> void:
	if _is_busy:
		return
	if store_modal and store_modal.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_store()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if _can_shop:
			_open_store()
			get_viewport().set_input_as_handled()
		elif _can_exit:
			exit_to_village()
			get_viewport().set_input_as_handled()

func _on_shop_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_shop = true
		if shop_prompt:
			shop_prompt.visible = true
		_play_keeper_greet("Selamat datang!")

func _on_shop_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_shop = false
		if shop_prompt:
			shop_prompt.visible = false
		if keeper_bubble:
			keeper_bubble.visible = false

func _play_keeper_greet(msg: String) -> void:
	if keeper_bubble:
		keeper_bubble.text = msg
		keeper_bubble.visible = true
	var tw := create_tween()
	tw.tween_method(func(v: float): _keeper_hop_offset = v, 0.0, -4.5, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _keeper_hop_offset = v, -4.5, 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

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

func _get_hud() -> Node:
	return get_tree().get_first_node_in_group("hud")

func _open_store() -> void:
	if not store_modal:
		return
	_refresh_store_ui()
	store_modal.visible = true

func _close_store() -> void:
	if store_modal:
		store_modal.visible = false

func _refresh_store_ui() -> void:
	var hud := _get_hud()
	var coins: int = hud.get_coin_count() if hud and hud.has_method("get_coin_count") else 0
	if coins_label:
		coins_label.text = "Koin Anda: %d" % coins

	if not items_list:
		return
	for ch in items_list.get_children():
		ch.queue_free()

	if STORE_LOCKED and greeting_label:
		greeting_label.text = "Masih dalam tahap pengembangan 😁😊"
		greeting_label.add_theme_color_override("font_color", Color(0.72, 0.22, 0.16, 1.0))

	var font_res: FontFile = load("res://asset/ui/PixelifySans.ttf")

	for item in SHOP_ITEMS:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.95, 0.90, 0.78, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 3
		sb.border_color = Color(0.32, 0.22, 0.12, 1.0)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_right = 4
		sb.corner_radius_bottom_left = 4
		row.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		margin.add_child(hbox)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(36, 36)
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = _load_texture(item["icon"])
		hbox.add_child(icon_rect)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = item["name"]
		if font_res: name_lbl.add_theme_font_override("font", font_res)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.22, 0.14, 0.06, 1.0))
		info.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = item["desc"]
		if font_res: desc_lbl.add_theme_font_override("font", font_res)
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.42, 0.30, 0.16, 1.0))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc_lbl)

		var is_owned: bool = item["unique"] and get_tree().get_meta("owned_" + item["id"], false)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, 36)
		btn.focus_mode = Control.FOCUS_NONE
		if font_res: btn.add_theme_font_override("font", font_res)
		btn.add_theme_font_size_override("font_size", 13)
		if STORE_LOCKED:
			row.modulate = Color(0.88, 0.85, 0.80, 0.92)
			btn.text = "Terkunci"
			btn.disabled = true
		elif is_owned:
			btn.text = "Dimiliki ✓"
			btn.disabled = true
		else:
			btn.text = "Beli (%d)" % item["price"]
			btn.disabled = coins < item["price"]
			btn.pressed.connect(_buy_item.bind(item))
		hbox.add_child(btn)

		items_list.add_child(row)

func _buy_item(item: Dictionary) -> void:
	if STORE_LOCKED:
		return
	var hud := _get_hud()
	if not hud or not hud.has_method("spend_coins"):
		return
	var price: int = item["price"]
	if not hud.spend_coins(price):
		if greeting_label:
			greeting_label.text = "Maaf, koin kamu belum cukup untuk membeli %s!" % item["name"]
		return

	if item["unique"]:
		get_tree().set_meta("owned_" + item["id"], true)
	if item.has("meta_dmg"):
		var cur_dmg: float = float(get_tree().get_meta("bonus_attack_damage", 0.0))
		get_tree().set_meta("bonus_attack_damage", maxf(cur_dmg, float(item["meta_dmg"])))
	if item.has("meta_range"):
		var cur_rng: float = float(get_tree().get_meta("bonus_attack_range", 0.0))
		get_tree().set_meta("bonus_attack_range", maxf(cur_rng, float(item["meta_range"])))
	if item.has("meta_dr"):
		get_tree().set_meta("damage_reduction", float(item["meta_dr"]))
	if item.has("meta_hp"):
		var prev_hp: float = float(get_tree().get_meta("bonus_max_blood", 0.0))
		var new_hp: float = float(item["meta_hp"])
		get_tree().set_meta("bonus_max_blood", new_hp)
		if player and new_hp > prev_hp:
			player.max_blood += (new_hp - prev_hp)
			player.heal(new_hp - prev_hp)

	if hud.has_method("add_item_to_inventory"):
		hud.add_item_to_inventory(item["id"], item["name"], item["desc"], item["icon"], 1)

	if greeting_label:
		greeting_label.text = "Terima kasih! %s sudah siap digunakan!" % item["name"]
	_play_keeper_greet("Terima kasih!")
	_refresh_store_ui()

func exit_to_village() -> void:
	if _is_busy:
		return
	_is_busy = true
	if door_prompt:
		door_prompt.visible = false
	get_tree().set_meta("spawn_outside_store", true)

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
	title_lbl.text = "Keluar Toko..."
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_res: title_lbl.add_theme_font_override("font", font_res)
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
	if font_res: sub_lbl.add_theme_font_override("font", font_res)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.70, 0.9))
	vbox.add_child(sub_lbl)

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

	var fade_out := canvas.create_tween()
	fade_out.tween_interval(0.05)
	fade_out.tween_property(center, "modulate:a", 0.0, 0.16)
	fade_out.parallel().tween_property(bg, "color:a", 0.0, 0.25)
	fade_out.tween_callback(canvas.queue_free)

	if packed_scene:
		tree.change_scene_to_packed(packed_scene)
	else:
		tree.change_scene_to_file(target_path)
