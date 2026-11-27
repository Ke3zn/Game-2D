# Godot 4: memasang animasi attack yang sudah diperbaiki ke AnimatedSprite2D,
# lengkap dengan durasi tiap frame dari animasi_info.json.
# Taruh script ini di node player, lalu sesuaikan FOLDER.
extends CharacterBody2D

const FOLDER := "res://asset/char/main-char/attack-fixed/"
const BASE_FPS := 10.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# frame saat pukulan/pentungan mengenai lawan (aktifkan hitbox di frame ini)
const HIT_FRAME := {
	"attack-front": 3, "attack-right": 3, "attack-left": 3, "attack-back": 3,
	"pentungan-attack-front": 2, "pentungan-attack-right": 2,
	"pentungan-attack-left": 2, "pentungan-attack-back": 3,
}

func _ready() -> void:
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_attacks()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)

func _load_attacks() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "animasi_info.json"))
	var sf := sprite.sprite_frames
	for anim_name in info.keys():
		var d: Dictionary = info[anim_name]
		var sheet: Texture2D = load(FOLDER + d["file"])
		if sf.has_animation(anim_name):
			sf.remove_animation(anim_name)
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, BASE_FPS)
		sf.set_animation_loop(anim_name, false)
		var w: int = d["frame_w"]
		var h: int = d["frame_h"]
		for i in int(d["frames"]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * w, 0, w, h)
			# durasi relatif: 100 ms = 1.0 pada 10 fps
			sf.add_frame(anim_name, at, float(d["durations_ms"][i]) / 100.0)

func attack(dir: String, pakai_pentungan := false) -> void:
	var anim := ("pentungan-attack-" if pakai_pentungan else "attack-") + dir
	sprite.play(anim)

func _on_frame_changed() -> void:
	if HIT_FRAME.get(sprite.animation, -1) == sprite.frame:
		_hit_enemies()

func _hit_enemies() -> void:
	# aktifkan hitbox / beri damage di sini, lalu beri hit-stop singkat:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05, true, false, true).timeout
	Engine.time_scale = 1.0

func _on_animation_finished() -> void:
	if sprite.animation.begins_with("attack-") or sprite.animation.begins_with("pentungan-attack-"):
		var dir := sprite.animation.get_slice("-", sprite.animation.get_slice_count("-") - 1)
		sprite.play("idle-" + dir)
