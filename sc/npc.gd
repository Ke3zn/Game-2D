extends CharacterBody2D
class_name NPC

@export var npc_name: String = "Kakek Warga Desa"

var _player_in_range: bool = false
var _player_ref: Node2D = null
var _quest_marker: Label = null

@onready var prompt: Label = $PromptLabel
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("npc")
	if prompt:
		prompt.visible = false

	_quest_marker = Label.new()
	_quest_marker.text = "!"
	_quest_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_marker.position = Vector2(-12, -32)
	_quest_marker.size = Vector2(24, 18)
	_quest_marker.z_index = 5
	_quest_marker.add_theme_font_size_override("font_size", 14)
	_quest_marker.add_theme_color_override("font_color", Color(1.0, 0.88, 0.18, 1.0))
	_quest_marker.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 1.0))
	_quest_marker.add_theme_constant_override("outline_size", 4)
	add_child(_quest_marker)

	# Efek pernapasan idle halus mempertahankan skala asli sprite
	if sprite:
		var base_scale = sprite.scale
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "scale", Vector2(base_scale.x, base_scale.y * 0.96), 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "scale", base_scale, 1.0).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	if _player_ref:
		# Urutan render Y-depth: saat player berdiri di bawah Kakek, player tampil di depan
		z_index = 1 if _player_ref.global_position.y > global_position.y else 2
	if _quest_marker:
		var q_status := str(get_tree().get_meta("quest_status", "NOT_STARTED"))
		var show_marker := q_status in ["NOT_STARTED", "READY_TO_TURN_IN", "COMPLETED", "QUEST2_READY"]
		_quest_marker.visible = show_marker
		if show_marker:
			var is_turn_in := q_status == "READY_TO_TURN_IN" or q_status == "QUEST2_READY"
			_quest_marker.text = "?" if is_turn_in else "!"
			var col := Color(0.35, 1.0, 0.5, 1.0) if is_turn_in else Color(1.0, 0.88, 0.18, 1.0)
			_quest_marker.add_theme_color_override("font_color", col)
			_quest_marker.position.y = -32.0 + sin(Time.get_ticks_msec() * 0.007) * 2.5

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
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
	if (hud.has_method("is_dialogue_open") and hud.is_dialogue_open()) or ("dialogue_modal" in hud and hud.dialogue_modal and hud.dialogue_modal.visible):
		return

	var q_status = hud.get("quest_status") if "quest_status" in hud else "NOT_STARTED"
	var has_apar = get_tree().get_meta("has_apar", false)
	var has_pentungan = get_tree().get_meta("has_pentungan", false)
	var lines: Array[String] = []

	if q_status == "NOT_STARTED" or not has_apar or not has_pentungan:
		lines = [
			"Rojali: \"Kakek!\"Sambil menunjuk ke langit di atas hutan. \"Kakek lihat itu? Asap apa itu? Tebal sekali!\"",
			"Kakek: \"Astaga, Nak Rojali, Kakek juga baru saja melihatnya,\"Padahal saat Kakek pergi untuk shalat subuh pagi tadi, langit masih bersih sekali. Asap sepekat itu tidak mungkin berasal dari perapian biasa.\"",
			"Rojali: \"Apa mungkin hutan kita terbakar, Kek? Padahal semalam tidak ada petir, dan baru masuk musim kemarau juga kan, Kek? Masa sudah terbakar saja?\"",
			"Kakek: \"Musim kemarau memang baru mulai, tapi api tidak akan muncul tiba-tiba tanpa pemicu. Kakek takut ada orang yang sengaja membakar lahan, atau ada orang yang membuang puntung rokok sembarangan.\"",
			"Kakek: \"Coba kamu cek ke sana, Rojali, sekalian bawa alat pemadam kebakaran ini untuk memadamkan apinya, serta bawa pentungan ini untuk berjaga-jaga. Kakek takut apinya cepat menyebar ke pemukiman desa.\"",
			"Rojali: \"Baik, Kek, Rojali akan cek penyebab kebakaran ini apa.\""
		]
		var on_finish := func() -> void:
			if hud.has_method("unlock_pentungan"):
				hud.unlock_pentungan()
			if hud.has_method("unlock_apar"):
				hud.unlock_apar()
			if q_status == "NOT_STARTED" and hud.has_method("start_quest"):
				hud.start_quest(2)
		if hud.has_signal("dialogue_finished"):
			hud.dialogue_finished.connect(on_finish, CONNECT_ONE_SHOT)
		hud.start_dialogue(npc_name, lines)
	elif q_status == "IN_PROGRESS":
		lines = [
			"Cepat cek lokasi asap tebal di seberang jembatan, Nak Rojali! Pakai APAR [3] untuk memadamkan api dan pentungan [2] untuk berjaga."
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "EXTINGUISH_TREES":
		lines = [
			"Cepat padamkan api di pohon-pohon itu dengan APAR sebelum menyebar ke pemukiman desa, Nak Rojali!"
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "FIND_ARSONIST" or q_status == "DEFEAT_ARSONIST":
		lines = [
			"Kakek: Syukurlah apinya sudah padam! Sekarang cari dan hentikan pelaku pembakaran hutan itu, tetap waspada ya Rojali!"
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "EXTINGUISH_REMAINING":
		lines = [
			"Kakek: Bagus sekali, Rojali! Segera padamkan sisa api yang masih menyala di hutan sebelum menyebar lagi!"
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "READY_TO_TURN_IN":
		lines = [
			"Rojali: Kek, saya sudah berhasil mengecek apa penyebab kebakaran hutan tersebut. Ternyata disebabkan oleh oknum yang ingin membangun lahan di desa kita, Kek, tetapi tenang saja Kek, Rojali telah mengalahkannya. Untung Kakek kasih Rojali alat APAR dan pemukul ini, Kek.",
			"Kakek: Wah, Kakek harus mengasih tahu warga desa untuk berjaga-jaga biar kasus ini tidak kejadian lagi. Syukurlah kamu tidak apa-apa, Rojali. Sekali lagi terima kasih ya, Rojali, berkat kamu desa ini menjadi aman kembali.",
			"Kakek: Ini Kakek ada sedikit upah buat kamu karena sudah menyelamatkan desa.",
			"Rojali: Wah, terima kasih banyak, Kek, pakai dikasih duit segala, Rojali jadi tidak enak kan, Kek, hehe... (sambil tangannya mengambil duit dari si Kakek)"
		]
		var on_turn_in := func() -> void:
			if hud.has_method("complete_quest"):
				hud.complete_quest()
		if hud.has_signal("dialogue_finished"):
			hud.dialogue_finished.connect(on_turn_in, CONNECT_ONE_SHOT)
		hud.start_dialogue(npc_name, lines)
	elif q_status == "COMPLETED":
		lines = [
			"Kakek: Rojali, Kakek minta tolong ke kamu untuk membasmi sebuah monster yang ada di Forest kita, karena para warga desa mulai cemas dengan munculnya monster itu. Sehingga beberapa hari ini mereka sudah tidak melakukan kerja menebang pohon. Coba kamu cek ke sana.",
			"Rojali: Baik, Kek, Rojali akan ke sana untuk mengeceknya, tapi Rojali akan dapat... ehemm (sambil memegang kantong celana)",
			"Kakek: Ohh tentu dong, bisa aja kamu! Urusan itu gampang, Kakek sudah menyiapkan uangnya. Sudah, segera pergi sana ke Forest untuk mengeceknya!",
			"Rojali: Wahh, baik Kek, segera meluncur ke lokasinya!"
		]
		var on_q2_start := func() -> void:
			if hud.has_method("start_quest_2"):
				hud.start_quest_2()
		if hud.has_signal("dialogue_finished"):
			hud.dialogue_finished.connect(on_q2_start, CONNECT_ONE_SHOT)
		hud.start_dialogue(npc_name, lines)
	elif q_status in ["QUEST2_GO_FOREST", "QUEST2_EXPLORE_FOREST", "QUEST2_SLIME"]:
		lines = [
			"Kakek: Hati-hati di Forest ya, Rojali! Cek dan basmi monster yang mengganggu di sana agar warga bisa bekerja lagi!"
		]
		hud.start_dialogue(npc_name, lines)
	elif q_status == "QUEST2_READY":
		lines = [
			"Rojali: Kakek, Rojali telah mengalahkan monsternya! Ternyata monsternya itu adalah slime besar, Kek, pantas saja warga tidak berani ke Forest.",
			"Kakek: Oala, seperti itu ya Rojali. Terima kasih telah membantu ya Rojali, ini dia upah yang telah Kakek janjikan tadi.",
			"Rojali: Sama-sama, Kek! Kalau butuh apa-apa panggil saja Rojali, Rojali akan membantunya asal ada... hehehe, tau lah ya Kek maksud Rojali apa.",
			"Kakek: Iya, Kakek akan bilang kalau Kakek butuh bantuan lagi. Yee lain kali kalau mau menolong harus ikhlas Rojali, jangan minta upah melulu!",
			"Rojali: Hehehe iya Kek, Rojali juga bercanda kali soal upah!"
		]
		var on_q2_done := func() -> void:
			if hud.has_method("complete_quest_2"):
				hud.complete_quest_2()
		if hud.has_signal("dialogue_finished"):
			hud.dialogue_finished.connect(on_q2_done, CONNECT_ONE_SHOT)
		hud.start_dialogue(npc_name, lines)
	elif q_status == "QUEST2_COMPLETED":
		lines = [
			"Kakek: Terima kasih banyak, Rojali! Desa dan hutan kita sekarang benar-benar aman berkat kamu!"
		]
		hud.start_dialogue(npc_name, lines)
