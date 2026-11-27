extends Area2D
class_name ItemPickup

@export var item_id: String = "potion_red"
@export var item_name: String = "Ramuan Pemulih Darah"
@export var item_desc: String = "Memulihkan 40 Darah saat diminum dari tas."
@export var item_icon_path: String = "res://asset/tools/potion_red.png"
@export var heal_amount: float = 40.0
@export var count: int = 1

var _start_y: float = 0.0
var _can_pickup: bool = false
var _is_picked_up: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Label = $PromptLabel

func _ready() -> void:
	add_to_group("item_pickup")
	_start_y = position.y
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_item(item_id)
	if prompt:
		prompt.visible = false

func set_item(id: String) -> void:
	item_id = id
	match id:
		"potion_red":
			item_name = "Ramuan Pemulih Darah"
			item_desc = "Memulihkan 40 Darah saat diminum dari tas."
			item_icon_path = "res://asset/tools/potion_red.png"
			heal_amount = 40.0
		"coin":
			item_name = "Koin Emas"
			item_desc = "Koin mata uang berharga yang dijatuhkan monster."
			item_icon_path = "res://asset/tools/coin.png"
			heal_amount = 0.0
		"wood":
			item_name = "Ranting Kayu"
			item_desc = "Kayu bahan kerajinan dari pepohonan hutan."
			item_icon_path = "res://asset/tools/wood.png"
			heal_amount = 0.0

	if FileAccess.file_exists(item_icon_path) and sprite:
		var img = Image.load_from_file(item_icon_path)
		if img:
			sprite.texture = ImageTexture.create_from_image(img)

func _process(_delta: float) -> void:
	if _is_picked_up:
		return
	# Efek melayang halus (bobbing)
	position.y = _start_y + sin(Time.get_ticks_msec() * 0.005) * 1.5

func _unhandled_input(event: InputEvent) -> void:
	if _can_pickup and not _is_picked_up:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE):
			collect()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_pickup = true
		if prompt:
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_pickup = false
		if prompt:
			prompt.visible = false

func collect() -> void:
	if _is_picked_up:
		return
	_is_picked_up = true
	if prompt:
		prompt.visible = false

	# Tambahkan ke inventory di HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var game = get_tree().current_scene
		if game:
			hud = game.get_node_or_null("HUD")
	if hud and hud.has_method("add_item_to_inventory"):
		hud.add_item_to_inventory(item_id, item_name, item_desc, item_icon_path, count)

	# Animasi ambil (naik ke atas & shrink)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 12.0, 0.25)
	tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
