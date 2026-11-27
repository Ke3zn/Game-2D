# Contoh pengaturan animasi boss untuk Godot 4 (AnimatedSprite2D)
# Taruh script ini di node boss. Ganti path sesuai folder project kamu.
extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
const MOLOTOV_SCENE := preload("res://scenes/molotov.tscn")  # buat scene molotov sendiri
const RELEASE_FRAME := 7  # frame saat botol lepas dari tangan

func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_throw_timing()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)

func _setup_throw_timing() -> void:
	var sf := sprite.sprite_frames
	sf.set_animation_speed("throw_molotov", 10.0)
	sf.set_animation_loop("throw_molotov", false)
	# durasi relatif tiap frame: ancang-ancang pelan, lempar cepat, tahan sebentar di akhir
	var durations := [1.2, 1.1, 1.1, 0.9, 0.9, 2.6, 0.6, 0.7, 1.1, 1.3, 1.6]
	for i in durations.size():
		var tex := sf.get_frame_texture("throw_molotov", i)
		sf.set_frame("throw_molotov", i, tex, durations[i])
	sf.set_animation_speed("idle_front", 6.0)
	sf.set_animation_speed("run_right", 12.0)

func throw_molotov() -> void:
	sprite.play("throw_molotov")

func _on_frame_changed() -> void:
	if sprite.animation == "throw_molotov" and sprite.frame == RELEASE_FRAME:
		var m := MOLOTOV_SCENE.instantiate()
		m.global_position = global_position + Vector2(40 * (-1 if sprite.flip_h else 1), -50)
		get_parent().add_child(m)

func _on_animation_finished() -> void:
	if sprite.animation == "throw_molotov":
		sprite.play("idle_front")
