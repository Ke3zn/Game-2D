extends CharacterBody2D
class_name BossNormal

signal health_changed(current: float, max_val: float)
signal died()

@export var boss_name: String = "🔥 BOSS PEMBAKAR"
@export var max_health: float = 150.0
@export var health: float = 150.0
@export var damage: float = 18.0
@export var molotov_damage: float = 15.0
@export var speed: float = 26.0
@export var detection_radius: float = 200.0
@export var molotov_cooldown: float = 3.8

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false

var _attack_timer: float = 0.0
var _molotov_timer: float = 1.5
var _is_throwing: bool = false
var _molotov_launched: bool = false
var _throw_target_pos: Vector2 = Vector2.ZERO
var _wave1_spawned: bool = false
var _wave2_spawned: bool = false
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	spawn_position = global_position
	health = max_health
	if sprite:
		sprite.play("idle_front")
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.frame_changed.connect(_on_frame_changed)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _attack_timer > 0.0:
		_attack_timer = max(0.0, _attack_timer - delta)

	if _molotov_timer > 0.0 and not _is_throwing:
		_molotov_timer = max(0.0, _molotov_timer - delta)

	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 220.0)
		move_and_slide()
		return

	if _is_throwing:
		velocity = Vector2.ZERO
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var hud = _get_hud()

	if player and is_instance_valid(player) and not player.get("is_dead"):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			if hud and hud.has_method("show_boss_bar"):
				hud.show_boss_bar(boss_name, health, max_health)

			# Lempar Molotov saat jarak menengah
			if dist >= 38.0 and dist <= 165.0 and _molotov_timer <= 0.0:
				_start_throw_molotov(player)
				return

			# Kejar player
			var dir = (player.global_position - global_position).normalized()
			var current_speed = speed * 1.25 if health <= max_health * 0.5 else speed
			velocity = dir * current_speed
			_update_move_anim(dir)

			# Serangan jarak dekat
			if dist <= 22.0 and _attack_timer <= 0.0:
				_attack_player(player)
		else:
			if hud and hud.has_method("hide_boss_bar"):
				hud.hide_boss_bar()

			var dist_spawn = global_position.distance_to(spawn_position)
			if dist_spawn > 15.0:
				var dir_spawn = (spawn_position - global_position).normalized()
				velocity = dir_spawn * (speed * 0.6)
				_update_move_anim(dir_spawn)
			else:
				velocity = Vector2.ZERO
				if sprite:
					sprite.flip_h = false
					if sprite.animation != "idle_front":
						sprite.play("idle_front")
	else:
		velocity = Vector2.ZERO
		if sprite:
			sprite.flip_h = false
			if sprite.animation != "idle_front":
				sprite.play("idle_front")

	move_and_slide()

func _update_move_anim(dir: Vector2) -> void:
	if not sprite:
		return
	sprite.flip_h = false
	var target_anim := "idle_front"
	if dir.x < -0.15:
		target_anim = "walk_left"
	elif dir.x > 0.15:
		target_anim = "walk_right"
	elif abs(dir.y) > 0.1:
		target_anim = "walk_right" if dir.y < 0 else "idle_front"
	if sprite.animation != target_anim or not sprite.is_playing():
		sprite.play(target_anim)

func _attack_player(p: Node2D) -> void:
	_attack_timer = 1.4
	if p.has_method("take_damage"):
		p.take_damage(damage)
	var lunge_dir = (p.global_position - global_position).normalized()
	global_position += lunge_dir * 6.0

func _start_throw_molotov(p: Node2D) -> void:
	_is_throwing = true
	_molotov_launched = false
	_molotov_timer = molotov_cooldown
	_throw_target_pos = p.global_position
	velocity = Vector2.ZERO
	if sprite:
		sprite.flip_h = p.global_position.x < global_position.x
		sprite.play("throw_molotov")

func _on_frame_changed() -> void:
	if _is_throwing and not _molotov_launched and sprite and sprite.animation == "throw_molotov":
		# Lepas molotov tepat saat animasi mengayun lemparan ke depan (frame 9)
		if sprite.frame >= 9:
			_molotov_launched = true
			_spawn_molotov_projectile(_throw_target_pos)

func _on_animation_finished() -> void:
	if sprite and sprite.animation == "throw_molotov":
		if not _molotov_launched:
			_molotov_launched = true
			_spawn_molotov_projectile(_throw_target_pos)
		_is_throwing = false
		sprite.flip_h = false
		sprite.play("idle_front")

func _spawn_molotov_projectile(target_pos: Vector2) -> void:
	var parent = get_parent()
	if not parent:
		return

	# Node proyektil Molotov + efek api ledakan
	var proj = Node2D.new()
	proj.z_index = 4
	var start_pos = global_position + Vector2(-8 if (sprite and sprite.flip_h) else 8, -10)
	proj.global_position = start_pos

	var bottle = ColorRect.new()
	bottle.color = Color(1.0, 0.45, 0.1, 1.0)
	bottle.size = Vector2(5, 7)
	bottle.position = Vector2(-2.5, -3.5)
	proj.add_child(bottle)

	var flame = ColorRect.new()
	flame.color = Color(1.0, 0.9, 0.2, 1.0)
	flame.size = Vector2(3, 3)
	flame.position = Vector2(-1.5, -6.0)
	proj.add_child(flame)

	parent.add_child(proj)

	var flight_time := 0.45
	var mid_pos = (start_pos + target_pos) * 0.5 + Vector2(0, -24)
	var tween = proj.create_tween()
	tween.tween_property(proj, "global_position", mid_pos, flight_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(proj, "rotation_degrees", 180.0, flight_time * 0.5)
	tween.tween_property(proj, "global_position", target_pos, flight_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(proj, "rotation_degrees", 360.0, flight_time * 0.5)
	tween.tween_callback(func():
		_on_molotov_impact(proj, target_pos)
	)

func _on_molotov_impact(proj: Node2D, impact_pos: Vector2) -> void:
	if not is_instance_valid(proj):
		return
	for c in proj.get_children():
		c.queue_free()

	proj.rotation_degrees = 0.0
	proj.global_position = impact_pos

	# Visual area api di tanah
	var fire_outer = ColorRect.new()
	fire_outer.color = Color(1.0, 0.35, 0.05, 0.75)
	fire_outer.size = Vector2(28, 20)
	fire_outer.position = Vector2(-14, -10)
	proj.add_child(fire_outer)

	var fire_inner = ColorRect.new()
	fire_inner.color = Color(1.0, 0.8, 0.15, 0.9)
	fire_inner.size = Vector2(16, 12)
	fire_inner.position = Vector2(-8, -6)
	proj.add_child(fire_inner)

	# Beri damage ke player jika berada di radius ledakan molotov
	if player and is_instance_valid(player) and not player.get("is_dead"):
		if player.global_position.distance_to(impact_pos) <= 24.0:
			if player.has_method("take_damage"):
				player.take_damage(molotov_damage)

	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(4.0, 0.2)

	var ft = proj.create_tween()
	ft.tween_interval(1.2)
	ft.tween_property(proj, "modulate:a", 0.0, 0.4)
	ft.tween_callback(proj.queue_free)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)

	var hud = _get_hud()
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(health, max_health)

	_hurt_timer = 0.14
	_knockback_velocity = knockback_dir.normalized() * 35.0

	if sprite:
		sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE if health > max_health * 0.5 else Color(1.0, 0.8, 0.8), 0.2)

	# Panggil minion Slime saat darah <= 70% dan <= 35%
	if health <= max_health * 0.7 and not _wave1_spawned:
		_wave1_spawned = true
		_summon_slime_minions(2)
	if health <= max_health * 0.35 and not _wave2_spawned:
		_wave2_spawned = true
		_summon_slime_minions(2)

	if health <= 0.0:
		_die()

func _summon_slime_minions(count: int = 2) -> void:
	var slime_scene = load("res://asset/enemy_slime.tscn")
	if not slime_scene or not get_parent():
		return
	var offsets = [Vector2(-26, 10), Vector2(26, 10), Vector2(0, 26), Vector2(0, -24)]
	for i in range(count):
		var minion = slime_scene.instantiate()
		minion.global_position = global_position + offsets[i % offsets.size()]
		get_parent().add_child(minion)

func _die() -> void:
	is_dead = true
	died.emit()
	set_physics_process(false)
	if collision:
		collision.set_deferred("disabled", true)

	var hud = _get_hud()
	if hud and hud.has_method("on_boss_defeated"):
		hud.on_boss_defeated(boss_name)

	_spawn_drop_item("potion_red", Vector2(-20, 0))
	_spawn_drop_item("potion_red", Vector2(20, 0))
	_spawn_drop_item("coin", Vector2(0, 15))

	var tween = create_tween()
	if sprite:
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.2), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0.5), 0.1)
		tween.tween_property(sprite, "scale", Vector2(0.42, 0.08), 0.35)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)

func _spawn_drop_item(item_id: String, offset: Vector2 = Vector2.ZERO) -> void:
	var item_scene = load("res://asset/item_pickup.tscn")
	if item_scene and get_parent():
		var item = item_scene.instantiate()
		item.global_position = global_position + offset
		item.set_item(item_id)
		get_parent().add_child(item)

func _get_hud() -> Node:
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var game = get_tree().current_scene
		if game:
			hud = game.get_node_or_null("HUD")
	return hud
