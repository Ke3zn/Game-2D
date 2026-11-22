extends CharacterBody2D

const SPEED = 100.0

var direction := Vector2.ZERO
var last_direction := "front"
var is_attacking := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pentungan: Sprite2D = $Pentungan

func _ready() -> void:
	sprite.play("idle_front")
	pentungan.visible = false

func _physics_process(_delta: float) -> void:
	if is_attacking:
		move_and_slide()
		return

	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		velocity = direction.normalized() * SPEED
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				last_direction = "right"
			else:
				last_direction = "left"
		else:
			if direction.y > 0:
				last_direction = "front"
			else:
				last_direction = "back"
		sprite.play("run_" + last_direction)
	else:
		velocity = Vector2.ZERO
		sprite.play("idle_" + last_direction)

	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return

	move_and_slide()

func _start_attack() -> void:
	is_attacking = true
	velocity = Vector2.ZERO
	sprite.play("attack_" + last_direction)
	pentungan.visible = true
	match last_direction:
		"front":
			pentungan.position = Vector2(6, 7)
			pentungan.rotation_degrees = 35
			pentungan.flip_h = false
			pentungan.z_index = 1
		"back":
			pentungan.position = Vector2(-5, -4)
			pentungan.rotation_degrees = -135
			pentungan.flip_h = false
			pentungan.z_index = -1
		"left":
			pentungan.position = Vector2(-8, 5)
			pentungan.rotation_degrees = -45
			pentungan.flip_h = true
			pentungan.z_index = 1
		"right":
			pentungan.position = Vector2(8, 5)
			pentungan.rotation_degrees = 45
			pentungan.flip_h = false
			pentungan.z_index = 1

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		pentungan.visible = false
		pentungan.flip_h = false
		sprite.play("idle_" + last_direction)
