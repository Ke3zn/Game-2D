extends Area2D
class_name DoorHouse

@export var target_scene: String = "res://asset/interior_house.tscn"
@export var prompt_text: String = "[E/F] Masuk Rumah"

var _player_in_range: bool = false
var _is_transitioning: bool = false

@onready var prompt: Label = $PromptLabel

func _ready() -> void:
	add_to_group("door")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.text = prompt_text
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _is_transitioning:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE):
			enter_door()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if prompt:
			prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if prompt:
			prompt.visible = false

func enter_door() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if prompt:
		prompt.visible = false

	# Transisi fade hitam halus sebelum pindah scene
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	var tween = canvas.create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(target_scene)
		var tween_out = canvas.create_tween()
		tween_out.tween_property(overlay, "color:a", 0.0, 0.3)
		tween_out.tween_callback(canvas.queue_free)
	)
