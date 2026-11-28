extends CharacterBody2D
class_name EnemySlime

signal health_changed(current: float, max_val: float)
signal died()

@export var max_health: float = 30.0
@export var health: float = 30.0
@export var speed: float = 26.0
@export var damage: float = 12.0
@export var attack_cooldown: float = 1.0
@export var detection_radius: float = 90.0
@export var drop_item_id: String = "coin"
@export var coin_reward: int = 10

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	add_to_group("enemy")
	spawn_position = global_position
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.visible = false # Sembunyi sampai terkena pukulan pertama

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _attack_timer > 0.0:
		_attack_timer = max(0.0, _attack_timer - delta)

	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 300.0)
		move_and_slide()
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var cur = get_tree().current_scene
		if cur:
			hud = cur.get_node_or_null("HUD")
	if hud:
		if (hud.has_method("is_dialogue_open") and hud.is_dialogue_open()) or ("quest_status" in hud and hud.quest_status != "QUEST2_SLIME"):
			velocity = Vector2.ZERO
			move_and_slide()
			return

	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			# Kejar player sambil menjaga jarak agar tidak menempel
			var dir = (player.global_position - global_position).normalized()
			if dist < 13.0:
				velocity = -dir * (speed * 0.5)
			elif dist <= 16.0:
				velocity = Vector2.ZERO
			else:
				velocity = dir * speed
			if sprite:
				sprite.flip_h = dir.x < 0

			# Cek jika menyentuh player untuk menyerang
			if dist <= 17.0 and _attack_timer <= 0.0:
				_attack_player(player)
		else:
			# Kembali ke posisi awal perlahan jika player di luar jangkauan
			var dist_spawn = global_position.distance_to(spawn_position)
			if dist_spawn > 10.0:
				var dir_spawn = (spawn_position - global_position).normalized()
				velocity = dir_spawn * (speed * 0.5)
				if sprite:
					sprite.flip_h = dir_spawn.x < 0
			else:
				velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	# Efek animasi lompat/squash slime sederhana
	if velocity != Vector2.ZERO and sprite:
		var hop = sin(Time.get_ticks_msec() * 0.015)
		sprite.scale = Vector2(0.75 + hop * 0.1, 0.75 - hop * 0.1)
	elif sprite:
		sprite.scale = Vector2(0.75, 0.75)

	move_and_slide()

func _attack_player(p: Node2D) -> void:
	_attack_timer = attack_cooldown
	if p.has_method("take_damage"):
		p.take_damage(damage)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)

	if health_bar:
		health_bar.visible = true
		health_bar.value = health

	# Efek knockback & kedip merah
	_hurt_timer = 0.2
	_knockback_velocity = knockback_dir.normalized() * 100.0

	if sprite:
		sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	died.emit()
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)

	if health_bar:
		health_bar.visible = false

	# Jatuhkan item (Item Pickup) jika ada scene item
	_spawn_drop_item()

	# Beritahu sistem quest jika slime mati
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var game = get_tree().current_scene
		if game:
			hud = game.get_node_or_null("HUD")
	if hud and hud.has_method("add_quest_progress"):
		hud.add_quest_progress("slime", 1)

	# Animasi menghilang (squash & fade out)
	var tween = create_tween().set_parallel(true)
	if sprite:
		tween.tween_property(sprite, "scale", Vector2(1.2, 0.1), 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

func _spawn_drop_item() -> void:
	var item_scene = load("res://asset/item_pickup.tscn")
	if item_scene:
		var item = item_scene.instantiate()
		item.global_position = global_position
		if drop_item_id == "coin":
			item.count = coin_reward
		item.set_item(drop_item_id)
		get_parent().add_child(item)
