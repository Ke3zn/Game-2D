extends CharacterBody2D
class_name NPC

@export var npc_name: String = "Kakek Warga Desa"
@export var dialogue_lines: Array[String] = [
	"Halo anak muda! Selamat datang di desa kami.",
	"Kakek sudah terlalu tua untuk memadamkan api di sekitar desa... Maukah kamu menolong Kakek?",
	"Gunakan APAR pemberian Kakek dengan tombol [1] dan pentunganmu dengan tombol [2]. Semoga berhasil!"
]

var _player_in_range: bool = false

@onready var prompt: Label = $PromptLabel
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("npc")
	if prompt:
		prompt.visible = false

	# Efek pernapasan idle halus mempertahankan skala asli sprite
	if sprite:
		var base_scale = sprite.scale
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "scale", Vector2(base_scale.x, base_scale.y * 0.96), 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "scale", base_scale, 1.0).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range:
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE):
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
	if "dialogue_modal" in hud and hud.dialogue_modal and hud.dialogue_modal.visible:
		return

	var q_status = hud.get("quest_status") if "quest_status" in hud else "NOT_STARTED"
	var has_apar = get_tree().get_meta("has_apar", false)
	var lines: Array[String] = []

	if q_status == "NOT_STARTED" or not has_apar:
		lines = [
			"Halo anak muda! Syukurlah ada yang datang ke desa kami.",
			"Kakek ingin meminta tolong... Ada api yang harus segera dipadamkan, tapi Kakek sudah terlalu tua dan lemah untuk melakukannya sendiri.",
			"Maukah kamu membantu Kakek memadamkan api itu dan menjaga desa dari para Slime liar di hutan seberang jembatan?",
			"Kakek akan kasih Alat Pemadam Api (APAR) ini untukmu! Selesai bicara ini, kamu bisa pakai APAR dengan [1] dan pentungan dengan [2]."
		]
		var on_finish := func() -> void:
			if hud.has_method("unlock_apar"):
				hud.unlock_apar()
			if q_status == "NOT_STARTED" and hud.has_method("start_quest"):
				hud.start_quest(2)
		if hud.has_signal("dialogue_finished"):
			hud.dialogue_finished.connect(on_finish, CONNECT_ONE_SHOT)
		hud.start_dialogue(npc_name, lines)
	elif q_status == "IN_PROGRESS":
		var current_kills = hud.get("quest_current_count") if "quest_current_count" in hud else 0
		lines = [
			"APAR sudah Kakek berikan padamu ya, nak. Tekan [1] untuk memegangnya dan [2] untuk memakai pentungan.",
			"Untuk para Slime liar di hutan seberang jembatan, kamu baru membasmi %d dari 2 Slime. Tetap berhati-hatilah!" % current_kills
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "READY_TO_TURN_IN":
		lines = [
			"Luar biasa sekali anak muda! Hutan seberang jembatan kini kembali damai.",
			"Warga desa dan Kakek sangat berterima kasih atas keberanian dan bantuanmu.",
			"Sesuai janji, terimalah 100 Koin Emas ini sebagai hadiah dari kami warga desa!"
		]
		var on_turn_in := func() -> void:
			if hud.has_method("complete_quest"):
				hud.complete_quest()
		if hud.has_signal("dialogue_finished"):
			hud.dialogue_finished.connect(on_turn_in, CONNECT_ONE_SHOT)
		hud.start_dialogue(npc_name, lines)
	elif q_status == "COMPLETED":
		lines = [
			"Terima kasih banyak atas bantuanmu menjaga desa dan menolong Kakek yang tua ini, anak muda!",
			"Simpan baik-baik APAR itu ya. Jika lelah, masuklah ke rumah untuk beristirahat memulihkan darah dan energimu."
		]
		hud.start_dialogue(npc_name, lines)
	else:
		hud.start_dialogue(npc_name, dialogue_lines)
