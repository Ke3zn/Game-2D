extends CharacterBody2D
class_name BossNormal

signal health_changed(current: float, max_val: float)
signal died()

@export var boss_name: String = "🔥 BOSS PEMBAKAR"
@export var max_health: float = 140.0
@export var health: float = 140.0
@export var stick_damage: float = 8.0
@export var molotov_damage: float = 10.0
@export var speed: float = 30.0 # Disamakan dengan kecepatan jalan player
@export var detection_radius: float = 195.0
@export var stick_cooldown: float = 1.35
@export var molotov_cooldown: float = 3.2

const MOLOTOV_TEX := preload("res://asset/tools/molotov_projectile.png")
const THROW_RELEASE_FRAME := 8
const STICK_HIT_FRAME := 5

const MELEE_SWITCH_RANGE := 52.0
const MOLOTOV_SWITCH_RANGE := 60.0
const STICK_ATTACK_RANGE := 24.0

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false

var _stick_timer: float = 0.0
var _molotov_timer: float = 1.2
var _is_throwing: bool = false
var _is_stick_attacking: bool = false
var _molotov_launched: bool = false
var _stick_hit_dealt: bool = false
var _throw_target_pos: Vector2 = Vector2.ZERO
var _pending_telegraph: Node2D = null
var _wave1_spawned: bool = false
var _wave2_spawned: bool = false
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_dir: String = "front"
var _weapon_suffix: String = "" # "" = molotov, "_stick" = stick

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
		sprite.play("idle_front")
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.frame_changed.connect(_on_frame_changed)

func _create_shadow() -> void:
	var shadow = Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.z_index = -1
	shadow.color = Color(0.0, 0.0, 0.0, 0.32)
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

	if _stick_timer > 0.0 and not _is_stick_attacking:
		_stick_timer = max(0.0, _stick_timer - delta)

	if _molotov_timer > 0.0 and not _is_throwing:
		_molotov_timer = max(0.0, _molotov_timer - delta)

	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 220.0)
		move_and_slide()
		return

	if _is_throwing or _is_stick_attacking:
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

			var dir = (player.global_position - global_position).normalized()
			_last_dir = _vec_to_dir(dir)

			# Ganti senjata otomatis berdasarkan jarak player (stick saat dekat, molotov saat jauh)
			if dist <= MELEE_SWITCH_RANGE:
				_weapon_suffix = "_stick"
			elif dist >= MOLOTOV_SWITCH_RANGE:
				_weapon_suffix = ""

			if _weapon_suffix == "_stick":
				# Dekat: serang dengan pukulan stick
				if dist <= STICK_ATTACK_RANGE and _stick_timer <= 0.0:
					_start_stick_attack(player)
					return
				if dist > 18.0:
					velocity = dir * speed
					_play_anim("run_stick_" + _last_dir)
				else:
					velocity = Vector2.ZERO
					_play_anim("idle_stick_" + _last_dir)
			else:
				# Jauh: serang lempar molotov
				if dist >= MOLOTOV_SWITCH_RANGE and dist <= 180.0 and _molotov_timer <= 0.0:
					_start_throw_molotov(player)
					return
				velocity = dir * speed
				_play_anim("run_" + _last_dir)
		else:
			if hud and hud.has_method("hide_boss_bar"):
				hud.hide_boss_bar()

			_weapon_suffix = ""
			var dist_spawn = global_position.distance_to(spawn_position)
			if dist_spawn > 15.0:
				var dir_spawn = (spawn_position - global_position).normalized()
				_last_dir = _vec_to_dir(dir_spawn)
				velocity = dir_spawn * (speed * 0.7)
				_play_anim("walk_" + _last_dir)
			else:
				velocity = Vector2.ZERO
				_play_anim("idle_front")
	else:
		_weapon_suffix = ""
		velocity = Vector2.ZERO
		_play_anim("idle_front")

	move_and_slide()

func _vec_to_dir(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "front" if v.y >= 0.0 else "back"

func _play_anim(anim_name: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)

func _start_stick_attack(p: Node2D) -> void:
	_is_stick_attacking = true
	_stick_hit_dealt = false
	_stick_timer = stick_cooldown
	velocity = Vector2.ZERO

	var dir = (p.global_position - global_position).normalized()
	_last_dir = _vec_to_dir(dir)
	_play_anim("attack_stick_" + _last_dir)

func _start_throw_molotov(p: Node2D) -> void:
	_is_throwing = true
	_molotov_launched = false
	_molotov_timer = molotov_cooldown
	_throw_target_pos = p.global_position
	velocity = Vector2.ZERO

	var dir = (p.global_position - global_position).normalized()
	_last_dir = _vec_to_dir(dir)
	_play_anim("throw_" + _last_dir)

	# Lingkaran penanda target jatuh molotov agar player sempat menghindar
	var parent = get_parent()
	if parent:
		var marker = Polygon2D.new()
		marker.z_index = 1
		marker.global_position = _throw_target_pos
		marker.color = Color(1.0, 0.3, 0.08, 0.35)
		var pts = PackedVector2Array()
		for i in range(16):
			var a = (float(i) / 16.0) * TAU
			pts.append(Vector2(cos(a) * 20.0, sin(a) * 14.0))
		marker.polygon = pts
		parent.add_child(marker)
		_pending_telegraph = marker

func _on_frame_changed() -> void:
	if not sprite:
		return
	if _is_throwing and not _molotov_launched and sprite.animation.begins_with("throw_"):
		if sprite.frame >= THROW_RELEASE_FRAME:
			_molotov_launched = true
			_spawn_molotov_projectile(_throw_target_pos)
	elif _is_stick_attacking and not _stick_hit_dealt and sprite.animation.begins_with("attack_stick_"):
		if sprite.frame >= STICK_HIT_FRAME:
			_stick_hit_dealt = true
			_execute_stick_hit()

func _execute_stick_hit() -> void:
	if player and is_instance_valid(player) and not player.get("is_dead"):
		if global_position.distance_to(player.global_position) <= STICK_ATTACK_RANGE + 6.0:
			if player.has_method("take_damage"):
				var kb = (player.global_position - global_position).normalized() * 65.0
				player.take_damage(stick_damage, kb)

func _on_animation_finished() -> void:
	if not sprite:
		return
	if sprite.animation.begins_with("throw_"):
		if not _molotov_launched:
			_molotov_launched = true
			_spawn_molotov_projectile(_throw_target_pos)
		_is_throwing = false
		_play_anim("idle" + _weapon_suffix + "_" + _last_dir)
	elif sprite.animation.begins_with("attack_stick_"):
		if not _stick_hit_dealt:
			_stick_hit_dealt = true
			_execute_stick_hit()
		_is_stick_attacking = false
		_play_anim("idle" + _weapon_suffix + "_" + _last_dir)

func _spawn_molotov_projectile(target_pos: Vector2) -> void:
	var parent = get_parent()
	if not parent:
		return

	var proj = Sprite2D.new()
	proj.texture = MOLOTOV_TEX
	proj.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	proj.scale = Vector2(0.7, 0.7)
	proj.z_index = 4

	var hand_offset := Vector2(0, -8)
	if _last_dir == "left":
		hand_offset = Vector2(-8, -6)
	elif _last_dir == "right":
		hand_offset = Vector2(8, -6)
	var start_pos = global_position + hand_offset
	proj.global_position = start_pos
	parent.add_child(proj)

	var telegraph = _pending_telegraph
	_pending_telegraph = null

	var flight_time := 0.48
	var mid_pos = (start_pos + target_pos) * 0.5 + Vector2(0, -26)
	var tween = proj.create_tween()
	tween.tween_property(proj, "global_position", mid_pos, flight_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(proj, "rotation_degrees", 180.0, flight_time * 0.5)
	tween.tween_property(proj, "global_position", target_pos, flight_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(proj, "rotation_degrees", 360.0, flight_time * 0.5)
	tween.tween_callback(func():
		if telegraph and is_instance_valid(telegraph):
			telegraph.queue_free()
		_on_molotov_impact(proj, target_pos)
	)

func _on_molotov_impact(proj: Node2D, impact_pos: Vector2) -> void:
	if not is_instance_valid(proj):
		return
	proj.texture = null
	proj.rotation_degrees = 0.0
	proj.scale = Vector2.ONE
	proj.global_position = impact_pos

	var fire_outer = Polygon2D.new()
	fire_outer.color = Color(1.0, 0.35, 0.05, 0.72)
	var pts_o = PackedVector2Array()
	for i in range(12):
		var a = (float(i) / 12.0) * TAU
		pts_o.append(Vector2(cos(a) * 18.0, sin(a) * 12.0))
	fire_outer.polygon = pts_o
	proj.add_child(fire_outer)

	var fire_inner = Polygon2D.new()
	fire_inner.color = Color(1.0, 0.85, 0.2, 0.9)
	var pts_i = PackedVector2Array()
	for i in range(10):
		var a = (float(i) / 10.0) * TAU
		pts_i.append(Vector2(cos(a) * 10.0, sin(a) * 7.0))
	fire_inner.polygon = pts_i
	proj.add_child(fire_inner)

	if player and is_instance_valid(player) and not player.get("is_dead"):
		if player.global_position.distance_to(impact_pos) <= 24.0:
			if player.has_method("take_damage"):
				var kb = (player.global_position - impact_pos).normalized() * 65.0
				player.take_damage(molotov_damage, kb)

	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(4.0, 0.2)

	var ft = proj.create_tween()
	ft.tween_interval(1.3)
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
	if _pending_telegraph and is_instance_valid(_pending_telegraph):
		_pending_telegraph.queue_free()
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
