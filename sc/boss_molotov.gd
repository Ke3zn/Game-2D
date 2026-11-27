extends CharacterBody2D
class_name BossMolotov

signal health_changed(current: float, max_val: float)
signal died()

@export var boss_name: String = "🔥 BOSS PEMBAKAR"
@export var max_health: float = 120.0
@export var health: float = 120.0
@export var damage: float = 18.0
@export var speed: float = 28.0
@export var detection_radius: float = 175.0
@export var throw_cooldown: float = 3.2

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false

const THROW_RELEASE_FRAME := 7
const MELEE_HIT_FRAME := 4
const MOLOTOV_TEX := preload("res://asset/char/boss-normal-lengkap/molotov_projectile.png")

var _attack_timer: float = 0.0
var _throw_timer: float = 1.5
var _is_throwing: bool = false
var _is_melee: bool = false
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _pending_target_pos: Vector2 = Vector2.ZERO
var _pending_telegraph: Node2D = null
var _molotov_launched: bool = false
var _melee_hit_dealt: bool = false
var _facing: String = "right"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	spawn_position = global_position
	health = max_health
	_create_shadow()
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.flip_h = false
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_sprite_animation_finished)
		sprite.play("idle_front")

func _create_shadow() -> void:
	var shadow = Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	var pts = PackedVector2Array()
	for i in range(16):
		var a = (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 4.0))
	shadow.polygon = pts
	shadow.position = Vector2(0, 15)
	add_child(shadow)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _attack_timer > 0.0:
		_attack_timer = max(0.0, _attack_timer - delta)
	if _throw_timer > 0.0 and not _is_throwing:
		_throw_timer = max(0.0, _throw_timer - delta)

	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 220.0)
		move_and_slide()
		return

	if _is_throwing or _is_melee:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 300.0)
		move_and_slide()
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var hud = _get_hud()

	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			if hud and hud.has_method("show_boss_bar"):
				hud.show_boss_bar(boss_name, health, max_health)

			var dir = (player.global_position - global_position).normalized()
			_facing = "right" if player.global_position.x >= global_position.x else "left"

			# Lempar Molotov jika jarak menengah-jauh dan cooldown siap
			if dist <= 145.0 and dist >= 34.0 and _throw_timer <= 0.0:
				_perform_molotov_throw(player)
				return

			# Serangan pukulan tongkat jarak dekat
			if dist <= 26.0 and _attack_timer <= 0.0:
				_perform_melee_tongkat(player)
				return

			var enraged = health <= max_health * 0.5
			var move_speed = speed * (1.25 if enraged else 1.0)
			velocity = dir * move_speed
			var run_anim = "run_" + _facing
			if sprite and sprite.animation != run_anim:
				sprite.play(run_anim)
		else:
			if hud and hud.has_method("hide_boss_bar"):
				hud.hide_boss_bar()

			var dist_spawn = global_position.distance_to(spawn_position)
			if dist_spawn > 15.0:
				var dir_spawn = (spawn_position - global_position).normalized()
				velocity = dir_spawn * (speed * 0.7)
				_facing = "right" if dir_spawn.x >= 0.0 else "left"
				var run_anim = "run_" + _facing
				if sprite and sprite.animation != run_anim:
					sprite.play(run_anim)
			else:
				velocity = Vector2.ZERO
				if sprite and sprite.animation != "idle_front":
					sprite.play("idle_front")
	else:
		velocity = Vector2.ZERO
		if sprite and sprite.animation != "idle_front":
			sprite.play("idle_front")

	move_and_slide()

func _perform_melee_tongkat(p: Node2D) -> void:
	_is_melee = true
	_melee_hit_dealt = false
	_attack_timer = 1.3
	_facing = "right" if p.global_position.x >= global_position.x else "left"
	var dir = (p.global_position - global_position).normalized()
	velocity = dir * 35.0
	if sprite:
		sprite.flip_h = false
		sprite.play("melee_tongkat_" + _facing)

func _perform_molotov_throw(p: Node2D) -> void:
	_is_throwing = true
	_molotov_launched = false
	_throw_timer = throw_cooldown * (0.78 if health <= max_health * 0.5 else 1.0)
	velocity = Vector2.ZERO

	_pending_target_pos = p.global_position
	_facing = "right" if _pending_target_pos.x >= global_position.x else "left"
	_pending_telegraph = _spawn_telegraph_ring(_pending_target_pos, 32.0)

	if sprite:
		sprite.flip_h = false
		sprite.play("throw_molotov_" + _facing)

func _on_sprite_frame_changed() -> void:
	if not sprite:
		return
	if _is_melee and not _melee_hit_dealt and sprite.animation.begins_with("melee_tongkat_") and sprite.frame == MELEE_HIT_FRAME:
		_melee_hit_dealt = true
		if not is_dead and player and is_instance_valid(player) and global_position.distance_to(player.global_position) <= 34.0:
			var kb = (player.global_position - global_position).normalized() * 90.0
			if player.has_method("take_damage"):
				player.take_damage(damage * 0.85, kb)
	elif _is_throwing and not _molotov_launched and sprite.animation.begins_with("throw_molotov_") and sprite.frame == THROW_RELEASE_FRAME:
		_molotov_launched = true
		if is_dead:
			if is_instance_valid(_pending_telegraph):
				_pending_telegraph.queue_free()
			return
		var hand_offset = Vector2(14.0 * (1.0 if _facing == "right" else -1.0), -14.0)
		_launch_molotov_projectile(global_position + hand_offset, _pending_target_pos, _pending_telegraph)
		_pending_telegraph = null

func _on_sprite_animation_finished() -> void:
	if not sprite:
		return
	if sprite.animation.begins_with("throw_molotov_"):
		_is_throwing = false
		if not is_dead:
			sprite.play("idle_front")
	elif sprite.animation.begins_with("melee_tongkat_"):
		_is_melee = false
		if not is_dead:
			sprite.play("idle_front")

func _spawn_telegraph_ring(pos: Vector2, radius: float) -> Node2D:
	var parent_node = get_parent()
	if not parent_node:
		return null
	var ring = Polygon2D.new()
	ring.z_index = 1
	ring.global_position = pos
	ring.color = Color(1.0, 0.3, 0.1, 0.28)
	var pts = PackedVector2Array()
	for i in range(24):
		var a = (float(i) / 24.0) * TAU
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.75))
	ring.polygon = pts
	parent_node.add_child(ring)

	var t = ring.create_tween().set_loops()
	t.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.18)
	t.tween_property(ring, "scale", Vector2(0.92, 0.92), 0.18)
	return ring

func _launch_molotov_projectile(start_pos: Vector2, target_pos: Vector2, telegraph: Node2D) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return

	var bottle = Sprite2D.new()
	bottle.z_index = 4
	bottle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bottle.texture = MOLOTOV_TEX
	bottle.scale = Vector2(0.38, 0.38)
	bottle.global_position = start_pos

	parent_node.add_child(bottle)

	var flight_time = 0.45
	var t = bottle.create_tween()
	t.tween_method(func(progress: float):
		if not is_instance_valid(bottle):
			return
		var arc_y = sin(progress * PI) * 28.0
		bottle.global_position = start_pos.lerp(target_pos, progress) - Vector2(0, arc_y)
		bottle.rotation = progress * TAU * 2.0
	, 0.0, 1.0, flight_time)
	t.tween_callback(func():
		if is_instance_valid(telegraph):
			telegraph.queue_free()
		if is_instance_valid(bottle):
			bottle.queue_free()
		_explode_molotov(target_pos)
	)

func _explode_molotov(impact_pos: Vector2) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return

	# Efek ledakan api & partikel bara
	var blast = Polygon2D.new()
	blast.z_index = 3
	blast.global_position = impact_pos
	blast.color = Color(1.0, 0.45, 0.1, 0.75)
	var pts = PackedVector2Array()
	for i in range(20):
		var a = (float(i) / 20.0) * TAU
		pts.append(Vector2(cos(a) * 30.0, sin(a) * 22.0))
	blast.polygon = pts
	parent_node.add_child(blast)

	var bt = blast.create_tween().set_parallel(true)
	bt.tween_property(blast, "scale", Vector2(1.3, 1.3), 0.3)
	bt.tween_property(blast, "modulate:a", 0.0, 0.35)
	bt.chain().tween_callback(blast.queue_free)

	for i in range(10):
		var ember = Polygon2D.new()
		ember.z_index = 4
		ember.global_position = impact_pos
		ember.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		ember.color = Color(1.0, 0.75, 0.15, 1.0) if i % 2 == 0 else Color(1.0, 0.3, 0.05, 1.0)
		parent_node.add_child(ember)
		var angle = (float(i) / 10.0) * TAU + randf_range(-0.2, 0.2)
		var dist_out = randf_range(14.0, 32.0)
		var et = ember.create_tween().set_parallel(true)
		et.tween_property(ember, "global_position", impact_pos + Vector2(cos(angle) * dist_out, sin(angle) * dist_out - 6.0), 0.35).set_ease(Tween.EASE_OUT)
		et.tween_property(ember, "modulate:a", 0.0, 0.35)
		et.chain().tween_callback(ember.queue_free)

	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(6.0, 0.25)

	if player and is_instance_valid(player):
		if impact_pos.distance_to(player.global_position) <= 34.0:
			if player.has_method("take_damage"):
				var kb = (player.global_position - impact_pos).normalized() * 100.0
				player.take_damage(damage, kb)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)

	var hud = _get_hud()
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(health, max_health)

	_hurt_timer = 0.14
	_knockback_velocity = knockback_dir.normalized() * 38.0

	if sprite:
		sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE if health > max_health * 0.5 else Color(1.0, 0.75, 0.75), 0.2)

	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	died.emit()
	set_physics_process(false)
	if collision:
		collision.set_deferred("disabled", true)

	var hud = _get_hud()
	if hud and hud.has_method("on_boss_defeated"):
		hud.on_boss_defeated(boss_name)

	_spawn_drop_item("potion_red", Vector2(-18, 0))
	_spawn_drop_item("potion_red", Vector2(18, 0))
	_spawn_drop_item("coin", Vector2(0, 14))

	var tween = create_tween()
	if sprite:
		tween.tween_property(sprite, "modulate", Color(1, 0.25, 0.25, 0.7), 0.15)
		tween.tween_property(sprite, "rotation_degrees", 90.0, 0.25)
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
