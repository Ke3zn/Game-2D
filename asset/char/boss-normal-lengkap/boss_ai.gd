# Godot 4: AI boss sederhana.
# Jauh dari player  -> lempar molotov
# Dekat dengan player -> pukul pakai tongkat
# Di antaranya      -> jalan mendekat
extends CharacterBody2D

const FOLDER := "res://asset/char/boss-normal/fixed/"
const SPEED := 70.0
const JARAK_PUKUL := 48.0     # pixel, sesuaikan dengan ukuran game
const JARAK_LEMPAR := 160.0
const JEDA_SERANG := 1.2      # detik antar serangan
const MOLOTOV_SCENE := preload("res://scenes/molotov.tscn")

@export var player: Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var sedang_serang := false
var cooldown := 0.0
var info: Dictionary

func _ready() -> void:
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "boss_animasi_info.json"))
	_muat_animasi()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle_front")

func _muat_animasi() -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for nama in info.keys():
		var d: Dictionary = info[nama]
		var sheet: Texture2D = load(FOLDER + d["file"])
		sf.add_animation(nama)
		sf.set_animation_speed(nama, 10.0)
		sf.set_animation_loop(nama, d.get("loop", false))
		for i in int(d["frames"]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * d["frame_w"], 0, d["frame_w"], d["frame_h"])
			sf.add_frame(nama, at, float(d["durations_ms"][i]) / 100.0)
	sprite.sprite_frames = sf

func _arah() -> String:
	return "right" if player.global_position.x >= global_position.x else "left"

func _physics_process(delta: float) -> void:
	if player == null:
		return
	cooldown = max(0.0, cooldown - delta)
	if sedang_serang:
		velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)
		move_and_slide()
		return

	var jarak := global_position.distance_to(player.global_position)
	if cooldown == 0.0 and jarak <= JARAK_PUKUL:
		_serang("melee_tongkat_")
	elif cooldown == 0.0 and jarak >= JARAK_LEMPAR:
		_serang("throw_molotov_")
	elif jarak > JARAK_PUKUL:
		var dir := (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * SPEED, 500 * delta)
		_play("run_" + _arah())
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)
		_play("idle_front")
	move_and_slide()

func _play(nama: String) -> void:
	if sprite.animation != nama:
		sprite.play(nama)

func _serang(awalan: String) -> void:
	sedang_serang = true
	sprite.play(awalan + _arah())

func _on_frame_changed() -> void:
	var d: Dictionary = info.get(sprite.animation, {})
	if d.has("hit_frame") and sprite.frame == int(d["hit_frame"]):
		if global_position.distance_to(player.global_position) <= JARAK_PUKUL + 12:
			if player.has_method("kena_damage"):
				player.kena_damage(15)
	if d.has("release_frame") and sprite.frame == int(d["release_frame"]):
		var m := MOLOTOV_SCENE.instantiate()
		var arah := 1 if _arah() == "right" else -1
		m.global_position = global_position + Vector2(36 * arah, -40)
		if "target" in m:
			m.target = player.global_position
		get_parent().add_child(m)

func _on_animation_finished() -> void:
	if sedang_serang:
		sedang_serang = false
		cooldown = JEDA_SERANG
		sprite.play("idle_front")
