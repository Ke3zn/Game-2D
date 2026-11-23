extends Node2D

@onready var player: Node2D = $Player
@onready var bed_prompt: Label = $BedArea/BedPrompt
@onready var door_prompt: Label = $DoorArea/DoorPrompt
@onready var fade_rect: ColorRect = $FadeCanvas/FadeRect
@onready var sleep_notify: Control = $FadeCanvas/SleepNotify

var _can_sleep: bool = false
var _can_exit: bool = false
var _is_busy: bool = false

func _ready() -> void:
	_setup_textures()
	if bed_prompt:
		bed_prompt.visible = false
	if door_prompt:
		door_prompt.visible = false
	if fade_rect:
		fade_rect.color = Color(0, 0, 0, 1)
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
	if sleep_notify:
		sleep_notify.visible = false

func _load_texture(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _setup_textures() -> void:
	var t_floor = _load_texture("res://asset/interior/floor_wood.png")
	var t_wall = _load_texture("res://asset/interior/wall_wood.png")
	var t_bed = _load_texture("res://asset/interior/bed.png")
	var t_rug = _load_texture("res://asset/interior/rug.png")
	var t_table = _load_texture("res://asset/interior/table.png")
	var t_doormat = _load_texture("res://asset/interior/door_mat.png")

	if t_floor and has_node("Floor"):
		$Floor.texture = t_floor
	if t_wall:
		if has_node("WallTop"): $WallTop.texture = t_wall
		if has_node("WallLeft"): $WallLeft.texture = t_wall
		if has_node("WallRight"): $WallRight.texture = t_wall
		if has_node("WallBottomLeft"): $WallBottomLeft.texture = t_wall
		if has_node("WallBottomRight"): $WallBottomRight.texture = t_wall
	if t_rug and has_node("Rug"):
		$Rug.texture = t_rug
	if t_doormat and has_node("DoorMat"):
		$DoorMat.texture = t_doormat
	if t_table and has_node("Table/Sprite2D"):
		$Table/Sprite2D.texture = t_table
	if t_bed and has_node("Bed/Sprite2D"):
		$Bed/Sprite2D.texture = t_bed

func _unhandled_input(event: InputEvent) -> void:
	if _is_busy:
		return
	if event is InputEventKey and event.pressed and (event.keycode == KEY_E or event.keycode == KEY_F or event.keycode == KEY_SPACE):
		if _can_sleep:
			sleep()
		elif _can_exit:
			exit_to_village()

func _on_bed_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_sleep = true
		if bed_prompt:
			bed_prompt.visible = true

func _on_bed_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_can_sleep = false
		if bed_prompt:
			bed_prompt.visible = false

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

func sleep() -> void:
	if _is_busy:
		return
	_is_busy = true
	if bed_prompt:
		bed_prompt.visible = false

	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
		tween.tween_callback(func():
			if player and player.has_method("heal"):
				player.heal(100.0)
			if player and player.has_method("restore_energy"):
				player.restore_energy(100.0)
			if sleep_notify:
				sleep_notify.visible = true
				sleep_notify.modulate.a = 0.0
				var notify_tween = create_tween()
				notify_tween.tween_property(sleep_notify, "modulate:a", 1.0, 0.25)
				notify_tween.tween_interval(1.0)
				notify_tween.tween_property(sleep_notify, "modulate:a", 0.0, 0.25)
				notify_tween.tween_callback(func(): sleep_notify.visible = false)
		)
		tween.tween_interval(1.2)
		tween.tween_property(fade_rect, "color:a", 0.0, 0.4)
		tween.tween_callback(func(): _is_busy = false)

func exit_to_village() -> void:
	if _is_busy:
		return
	_is_busy = true
	if door_prompt:
		door_prompt.visible = false

	if fade_rect:
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.35)
		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://asset/game.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://asset/game.tscn")
