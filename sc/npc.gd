extends CharacterBody2D
class_name NPC

@export var npc_name: String = "Kakek Warga Desa"
@export var dialogue_lines: Array[String] = [
	"Halo anak muda! Selamat datang di desa kami.",
	"Di hutan seberang jembatan, makhluk Slime liar mulai berkeliaran dan mengganggu warga.",
	"Gunakan Pentungan kayumu untuk membela diri jika mereka mendekat!",
	"Jika kamu terluka, cari atau minum Ramuan Merah untuk memulihkan darahmu. Semoga berhasil!"
]

var _player_in_range: bool = false

@onready var prompt: Label = $PromptLabel
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("npc")
	if prompt:
		prompt.visible = false

	# Efek pernapasan idle halus
	if sprite:
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "scale", Vector2(0.1, 0.096), 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 1.0).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE):
			interact()

func _on_interact_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if prompt:
			prompt.visible = true

func _on_interact_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if prompt:
			prompt.visible = false

func interact() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var game = get_tree().current_scene
		if game:
			hud = game.get_node_or_null("HUD")
	if not hud or not hud.has_method("start_dialogue"):
		return

	var q_status = hud.get("quest_status") if "quest_status" in hud else "NOT_STARTED"
	var lines: Array[String] = []

	if q_status == "NOT_STARTED":
		lines = [
			"Halo anak muda! Selamat datang di desa kami.",
			"Di hutan seberang jembatan, makhluk Slime liar mulai berkeliaran dan mengancam warga desa.",
			"Maukah kamu membantu kami membasmi 2 Slime liar di sana?",
			"Gunakan pentunganmu. Jika kamu lelah atau terluka, beristirahatlah di rumah sebelah untuk memulihkan diri!",
			"Semoga berhasil! Warga desa sangat mengandalkanmu."
		]
		hud.start_dialogue(npc_name, lines)
		if hud.has_method("start_quest"):
			hud.start_quest(2)
	elif q_status == "IN_PROGRESS":
		var current_kills = hud.get("quest_current_count") if "quest_current_count" in hud else 0
		lines = [
			"Bagaimana perburuanmu di hutan seberang jembatan, anak muda?",
			"Kamu baru membasmi %d dari 2 Slime liar. Tetap waspada dan berhati-hatilah!" % current_kills
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "READY_TO_TURN_IN":
		lines = [
			"Luar biasa sekali anak muda! Hutan seberang jembatan kini kembali damai.",
			"Warga desa sangat berterima kasih atas keberanian dan bantuanmu.",
			"Sesuai janji, terimalah 100 Koin Emas ini sebagai hadiah dari kami warga desa!"
		]
		hud.start_dialogue(npc_name, lines)
		if hud.has_method("complete_quest"):
			hud.complete_quest()
	elif q_status == "COMPLETED":
		lines = [
			"Terima kasih banyak atas bantuanmu menjaga desa kami, pahlawan muda!",
			"Jika kamu lelah setelah berpetualang, masuklah ke rumah sebelah untuk tidur dan memulihkan seluruh darah dan energimu."
		]
		hud.start_dialogue(npc_name, lines)
	else:
		hud.start_dialogue(npc_name, dialogue_lines)
