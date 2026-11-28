extends CharacterBody2D
class_name BossNormal

signal health_changed(current: float, max_val: float)
signal died()

@export var boss_name: String = "🔥 BOSS PEMBAKAR"
@export var evil_boss_name: String = "EVIL BOSS PEMBAKAR"
@export var max_health: float = 250.0
@export var health: float = 250.0
@export var stick_damage: float = 5.0
@export var molotov_damage: float = 6.0
@export var fireball_damage: float = 8.0
@export var speed: float = 30.0 # Disamakan dengan kecepatan jalan player
@export var evil_speed: float = 40.0
@export var detection_radius: float = 195.0
@export var stick_cooldown: float = 1.35
@export var molotov_cooldown: float = 3.2
@export var fireball_cooldown: float = 1.85

const MOLOTOV_TEX := preload("res://asset/tools/molotov_projectile.png")
const EVIL_FIREBALL_PATH := "res://asset/char-fix/evil/processed/evil_fireball.png"
const SFX_BAT_PATH := "res://asset/music/sfx/bathitball.mp3"
const SFX_TRANSFORM_PATH := "res://asset/music/sfx/baim_tranformation.mp3"
const EFFECT_FIRE_1_PATH := "res://asset/char-fix/evil/processed/effect_fire_spark_1.png"
const EFFECT_FIRE_2_PATH := "res://asset/char-fix/evil/processed/effect_fire_spark_2.png"
const EFFECT_LIGHT_1_PATH := "res://asset/char-fix/evil/processed/effect_light_spark_1.png"
const EFFECT_LIGHT_2_PATH := "res://asset/char-fix/evil/processed/effect_light_spark_2.png"
const EFFECT_WHITE_1_PATH := "res://asset/char-fix/evil/processed/effect_white_spark_1.png"
const BASE_SPRITE_SCALE := Vector2(0.34, 0.34)
const ACTION_SPRITE_SCALE := Vector2(0.303, 0.303) # Normalisasi sprite attack/throw (130px) agar sama dengan idle/walk/run (116px)
const ACTION_SPRITE_Y_OFFSET := 2.37
const EVOLVE_SPRITE_SCALE := Vector2(0.1818, 0.1818)
const EVIL_SPRITE_SCALE := Vector2(0.130, 0.130)
const THROW_RELEASE_FRAME := 8
const EVIL_THROW_RELEASE_FRAME := 4
const STICK_HIT_FRAME := 5

const MELEE_SWITCH_RANGE := 52.0
const MOLOTOV_SWITCH_RANGE := 60.0
const STICK_ATTACK_RANGE := 24.0

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false

var _base_max_health: float = 250.0
var _is_evolving: bool = false
var _is_evil: bool = false
var _evil_throw_count: int = 0
var _fire_aura_timer: float = 0.0

var _stick_timer: float = 0.0
var _molotov_timer: float = 1.2
var _is_throwing: bool = false
var _is_stick_attacking: bool = false
var _molotov_launched: bool = false
var _stick_hit_dealt: bool = false
var _throw_target_pos: Vector2 = Vector2.ZERO
var _pending_telegraph: Node2D = null
var _pending_telegraphs: Array[Node2D] = []
var _pending_fireball_targets: Array[Vector2] = []
var _wave1_spawned: bool = false
var _wave2_spawned: bool = false
var _was_player_in_range: bool = false
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _last_dir: String = "front"
var _weapon_suffix: String = "" # "" = molotov, "_stick" = stick, "_evil" = evil phase
var _sfx_stick: AudioStreamPlayer = null
var _sfx_transform: AudioStreamPlayer = null
var _fireball_frames: SpriteFrames = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	add_to_group("boss_normal")
	spawn_position = global_position
	_base_max_health = max_health
	health = max_health
	_create_shadow()
	_build_fireball_frames()
	_sfx_stick = AudioStreamPlayer.new()
	_sfx_stick.volume_db = -3.0
	_sfx_stick.pitch_scale = 0.9
	if ResourceLoader.exists(SFX_BAT_PATH):
		_sfx_stick.stream = load(SFX_BAT_PATH)
	add_child(_sfx_stick)
	_sfx_transform = AudioStreamPlayer.new()
	_sfx_transform.volume_db = -10.0
	if ResourceLoader.exists(SFX_TRANSFORM_PATH):
		_sfx_transform.stream = load(SFX_TRANSFORM_PATH)
	add_child(_sfx_transform)
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.play("idle_front")
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.frame_changed.connect(_on_frame_changed)

func _build_fireball_frames() -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists(EVIL_FIREBALL_PATH):
		tex = load(EVIL_FIREBALL_PATH) as Texture2D
	if not tex and FileAccess.file_exists(EVIL_FIREBALL_PATH):
		var img := Image.load_from_file(EVIL_FIREBALL_PATH)
		if img:
			tex = ImageTexture.create_from_image(img)
	if not tex:
		return
	var sf := SpriteFrames.new()
	sf.add_animation("spin")
	sf.set_animation_loop("spin", true)
	sf.set_animation_speed("spin", 16.0)
	for i in range(8):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 288, 0, 288, 288)
		sf.add_frame("spin", at)
	_fireball_frames = sf

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

	if _is_evolving:
		velocity = Vector2.ZERO
		_process_evil_aura(delta, 0.08)
		return

	if _is_evil:
		_process_evil_aura(delta, 0.16)

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

	if player and is_instance_valid(player):
		z_index = 1 if player.global_position.y > global_position.y else 2

	var hud = _get_hud()
	var active_detect := maxf(detection_radius, 225.0) if _is_evil else detection_radius

	if player and is_instance_valid(player) and not player.get("is_dead"):
		var dist = global_position.distance_to(player.global_position)
		if dist <= active_detect:
			_was_player_in_range = true
			if hud and hud.has_method("show_boss_bar"):
				hud.show_boss_bar(_get_display_name(), health, max_health)

			var dir = (player.global_position - global_position).normalized()
			_last_dir = _vec_to_dir(dir)

			if _is_evil:
				_weapon_suffix = "_evil"
				if dist <= 205.0 and _molotov_timer <= 0.0:
					_start_throw_fireball(player)
					return
				if dist > 56.0:
					velocity = dir * evil_speed
					_play_anim("run_evil_" + _last_dir)
				elif dist < 28.0:
					velocity = -dir * (evil_speed * 0.55)
					_play_anim("idle_evil_" + _last_dir)
				else:
					var side := 1.0 if (_evil_throw_count % 2 == 0) else -1.0
					var strafe := Vector2(-dir.y, dir.x) * (evil_speed * 0.45 * side)
					velocity = strafe
					_play_anim("walk_evil_" + _last_dir)
			else:
				# Fase Normal: ganti senjata otomatis berdasarkan jarak player (stick saat dekat, molotov saat jauh)
				if dist <= MELEE_SWITCH_RANGE:
					_weapon_suffix = "_stick"
				elif dist >= MOLOTOV_SWITCH_RANGE:
					_weapon_suffix = ""

				if _weapon_suffix == "_stick":
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
					if dist >= MOLOTOV_SWITCH_RANGE and dist <= 180.0 and _molotov_timer <= 0.0:
						_start_throw_molotov(player)
						return
					velocity = dir * speed
					_play_anim("run_" + _last_dir)
		else:
			if _was_player_in_range:
				_was_player_in_range = false
				if hud and hud.has_method("hide_boss_bar"):
					hud.hide_boss_bar()

			_weapon_suffix = "_evil" if _is_evil else ""
			var dist_spawn = global_position.distance_to(spawn_position)
			if dist_spawn > 15.0:
				var dir_spawn = (spawn_position - global_position).normalized()
				_last_dir = _vec_to_dir(dir_spawn)
				var ret_speed := evil_speed * 0.75 if _is_evil else speed * 0.7
				velocity = dir_spawn * ret_speed
				_play_anim(("walk_evil_" if _is_evil else "walk_") + _last_dir)
			else:
				velocity = Vector2.ZERO
				_play_anim("idle_evil_front" if _is_evil else "idle_front")
	else:
		_weapon_suffix = "_evil" if _is_evil else ""
		velocity = Vector2.ZERO
		_play_anim("idle_evil_front" if _is_evil else "idle_front")

	move_and_slide()

func _get_display_name() -> String:
	return evil_boss_name if _is_evil else boss_name

func _vec_to_dir(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "front" if v.y >= 0.0 else "back"

func _play_anim(anim_name: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	if anim_name == "evolve_to_evil":
		sprite.scale = EVOLVE_SPRITE_SCALE
		sprite.position.y = 0.0
	elif anim_name.contains("_evil_"):
		sprite.scale = EVIL_SPRITE_SCALE
		sprite.position.y = 0.0
	else:
		var is_action := anim_name.begins_with("attack_stick_") or anim_name.begins_with("throw_")
		sprite.scale = ACTION_SPRITE_SCALE if is_action else BASE_SPRITE_SCALE
		sprite.position.y = ACTION_SPRITE_Y_OFFSET if is_action else 0.0
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
	if _sfx_stick and _sfx_stick.stream:
		_sfx_stick.play()

func _start_throw_molotov(p: Node2D) -> void:
	_is_throwing = true
	_molotov_launched = false
	_molotov_timer = molotov_cooldown
	_throw_target_pos = p.global_position
	velocity = Vector2.ZERO

	var dir = (p.global_position - global_position).normalized()
	_last_dir = _vec_to_dir(dir)
	_play_anim("throw_" + _last_dir)

	var parent = get_parent()
	if parent:
		var marker := _create_telegraph_marker(_throw_target_pos, Color(1.0, 0.3, 0.08, 0.35), 20.0, 14.0)
		parent.add_child(marker)
		_pending_telegraph = marker

func _start_throw_fireball(p: Node2D) -> void:
	_is_throwing = true
	_molotov_launched = false
	_molotov_timer = fireball_cooldown
	_evil_throw_count += 1
	velocity = Vector2.ZERO

	var diff: Vector2 = p.global_position - global_position
	var dir: Vector2 = diff.normalized() if diff.length() > 0.1 else Vector2.DOWN
	_last_dir = _vec_to_dir(dir)
	var anim_dir := _last_dir
	if anim_dir == "back":
		anim_dir = "right" if dir.x >= 0.0 else "left"
	_play_anim("throw_evil_" + anim_dir)

	_clear_pending_telegraphs()
	_pending_fireball_targets.clear()

	var base_dist := maxf(diff.length(), 32.0)
	var use_triple := (_evil_throw_count % 3 == 0) or (health <= max_health * 0.5)
	var angles: Array[float] = [0.0]
	if use_triple:
		angles = [0.0, -0.32, 0.32]

	var parent = get_parent()
	for ang in angles:
		var target_pos: Vector2 = global_position + dir.rotated(ang) * base_dist
		_pending_fireball_targets.append(target_pos)
		if parent:
			var marker := _create_telegraph_marker(target_pos, Color(1.0, 0.22, 0.04, 0.42), 21.0, 15.0)
			parent.add_child(marker)
			_pending_telegraphs.append(marker)

func _create_telegraph_marker(pos: Vector2, col: Color, rx: float, ry: float) -> Polygon2D:
	var marker := Polygon2D.new()
	marker.z_index = 1
	marker.global_position = pos
	marker.color = col
	var pts := PackedVector2Array()
	for i in range(16):
		var a := (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	marker.polygon = pts
	return marker

func _clear_pending_telegraphs() -> void:
	if _pending_telegraph and is_instance_valid(_pending_telegraph):
		_pending_telegraph.queue_free()
	_pending_telegraph = null
	for m in _pending_telegraphs:
		if m and is_instance_valid(m):
			m.queue_free()
	_pending_telegraphs.clear()

func _on_frame_changed() -> void:
	if not sprite:
		return
	if _is_throwing and not _molotov_launched:
		if sprite.animation.begins_with("throw_evil_"):
			if sprite.frame >= EVIL_THROW_RELEASE_FRAME:
				_molotov_launched = true
				_launch_evil_fireballs()
		elif sprite.animation.begins_with("throw_"):
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
	if _is_evolving and sprite.animation == "evolve_to_evil":
		_finish_evolution()
	elif sprite.animation.begins_with("throw_evil_"):
		if not _molotov_launched:
			_molotov_launched = true
			_launch_evil_fireballs()
		_is_throwing = false
		_play_anim("idle_evil_" + _last_dir)
	elif sprite.animation.begins_with("throw_"):
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

func _launch_evil_fireballs() -> void:
	var targets := _pending_fireball_targets.duplicate()
	var telegraphs := _pending_telegraphs.duplicate()
	_pending_fireball_targets.clear()
	_pending_telegraphs.clear()
	for i in range(targets.size()):
		var tel: Node2D = null
		if i < telegraphs.size():
			tel = telegraphs[i]
		_spawn_fireball_projectile(targets[i], tel)

func _spawn_fireball_projectile(target_pos: Vector2, telegraph: Node2D) -> void:
	var parent = get_parent()
	if not parent:
		if telegraph and is_instance_valid(telegraph):
			telegraph.queue_free()
		return

	var container := Node2D.new()
	container.z_index = 4

	var anim_fb := AnimatedSprite2D.new()
	anim_fb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_fb.sprite_frames = _fireball_frames
	anim_fb.scale = Vector2(0.085, 0.085)
	anim_fb.play("spin")
	container.add_child(anim_fb)

	var hand_offset := Vector2(0, -8)
	if _last_dir == "left":
		hand_offset = Vector2(-10, -6)
	elif _last_dir == "right":
		hand_offset = Vector2(10, -6)
	var start_pos: Vector2 = global_position + hand_offset
	container.global_position = start_pos
	parent.add_child(container)

	var flight_time := 0.40
	var mid_pos: Vector2 = (start_pos + target_pos) * 0.5 + Vector2(0, -18)
	var tween = container.create_tween()
	tween.tween_property(container, "global_position", mid_pos, flight_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "global_position", target_pos, flight_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if telegraph and is_instance_valid(telegraph):
			telegraph.queue_free()
		_on_fireball_impact(container, target_pos)
	)

func _on_fireball_impact(proj: Node2D, impact_pos: Vector2) -> void:
	if not is_instance_valid(proj):
		return
	for ch in proj.get_children():
		ch.queue_free()
	proj.global_position = impact_pos

	var fire_outer = Polygon2D.new()
	fire_outer.color = Color(1.0, 0.28, 0.04, 0.80)
	var pts_o = PackedVector2Array()
	for i in range(14):
		var a = (float(i) / 14.0) * TAU
		pts_o.append(Vector2(cos(a) * 21.0, sin(a) * 14.0))
	fire_outer.polygon = pts_o
	proj.add_child(fire_outer)

	var fire_inner = Polygon2D.new()
	fire_inner.color = Color(1.0, 0.88, 0.25, 0.95)
	var pts_i = PackedVector2Array()
	for i in range(10):
		var a = (float(i) / 10.0) * TAU
		pts_i.append(Vector2(cos(a) * 11.0, sin(a) * 8.0))
	fire_inner.polygon = pts_i
	proj.add_child(fire_inner)

	if player and is_instance_valid(player) and not player.get("is_dead"):
		if player.global_position.distance_to(impact_pos) <= 25.0:
			if player.has_method("take_damage"):
				var kb = (player.global_position - impact_pos).normalized() * 75.0
				player.take_damage(fireball_damage, kb)

	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(4.5, 0.2)

	var ft = proj.create_tween()
	ft.tween_interval(1.4)
	ft.tween_property(proj, "modulate:a", 0.0, 0.45)
	ft.tween_callback(proj.queue_free)

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

func _start_evolution() -> void:
	if _is_evolving or _is_evil:
		return
	_is_evolving = true
	_is_throwing = false
	_is_stick_attacking = false
	_molotov_launched = false
	_stick_hit_dealt = false
	_hurt_timer = 0.0
	_knockback_velocity = Vector2.ZERO
	_weapon_suffix = "_evil"
	velocity = Vector2.ZERO
	_pending_fireball_targets.clear()
	_clear_pending_telegraphs()

	var target_max: float = ceilf(_base_max_health * 1.25)
	max_health = target_max

	if _sfx_transform and _sfx_transform.stream:
		_sfx_transform.play()

	_play_transformation_effects()

	if sprite:
		sprite.modulate = Color(1.0, 0.72, 0.55, 1.0)
		_play_anim("evolve_to_evil")
		var pulse := create_tween()
		pulse.tween_property(sprite, "modulate", Color(1.3, 0.55, 0.45, 1.0), 0.35)
		pulse.tween_property(sprite, "modulate", Color.WHITE, 0.65)

	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(5.5, 0.55)

	var heal_tween := create_tween()
	heal_tween.tween_method(func(val: float):
		health = val
		health_changed.emit(health, max_health)
		var h = _get_hud()
		if h and h.has_method("show_boss_bar"):
			h.show_boss_bar(evil_boss_name, health, max_health)
	, health, target_max, 0.95)

	# Failsafe jika sinyal animation_finished terlewat
	get_tree().create_timer(1.25).timeout.connect(func():
		if _is_evolving and not is_dead:
			_finish_evolution()
	)

func _load_tex_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		if t:
			return t
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img:
			return ImageTexture.create_from_image(img)
	return null

func _play_transformation_effects() -> void:
	var parent := get_parent()
	if not parent:
		return
	var fx_root := Node2D.new()
	fx_root.z_index = z_index + 2
	fx_root.global_position = global_position
	parent.add_child(fx_root)

	var make_fx := func(path: String, pos: Vector2, start_scale: Vector2, start_alpha: float) -> Sprite2D:
		var s := Sprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.texture = _load_tex_safe(path)
		s.position = pos
		s.scale = start_scale
		s.modulate = Color(1.0, 1.0, 1.0, start_alpha)
		fx_root.add_child(s)
		return s

	# 1. Light aura beams shooting upward around boss
	var light1: Sprite2D = make_fx.call(EFFECT_LIGHT_1_PATH, Vector2(0, -4), Vector2(0.13, 0.10), 0.0)
	var light2: Sprite2D = make_fx.call(EFFECT_LIGHT_2_PATH, Vector2(0, -6), Vector2(0.14, 0.11), 0.0)
	var tl1 := light1.create_tween()
	tl1.tween_property(light1, "modulate:a", 0.95, 0.15)
	tl1.parallel().tween_property(light1, "scale", Vector2(0.15, 0.16), 0.35)
	tl1.parallel().tween_property(light1, "position:y", -10.0, 0.95)
	tl1.tween_interval(0.35)
	tl1.tween_property(light1, "modulate:a", 0.0, 0.35)

	var tl2 := light2.create_tween()
	tl2.tween_interval(0.10)
	tl2.tween_property(light2, "modulate:a", 0.90, 0.18)
	tl2.parallel().tween_property(light2, "scale", Vector2(0.17, 0.18), 0.45)
	tl2.parallel().tween_property(light2, "position:y", -12.0, 0.95)
	tl2.tween_interval(0.25)
	tl2.tween_property(light2, "modulate:a", 0.0, 0.35)

	# 2. Fire smoke shockwave rings expanding simultaneously
	var fire1: Sprite2D = make_fx.call(EFFECT_FIRE_1_PATH, Vector2(0, 2), Vector2(0.08, 0.08), 0.95)
	var fire2: Sprite2D = make_fx.call(EFFECT_FIRE_2_PATH, Vector2(0, 2), Vector2(0.10, 0.10), 0.90)
	var tf1 := fire1.create_tween().set_parallel(true)
	tf1.tween_property(fire1, "scale", Vector2(0.20, 0.20), 0.60).set_ease(Tween.EASE_OUT)
	tf1.tween_property(fire1, "modulate:a", 0.0, 0.65)

	var tf2 := fire2.create_tween().set_parallel(true)
	tf2.tween_property(fire2, "scale", Vector2(0.24, 0.24), 0.95).set_ease(Tween.EASE_OUT)
	tf2.tween_property(fire2, "modulate:a", 0.0, 1.00)

	# 3. White sparkle burst spinning outward
	var white1: Sprite2D = make_fx.call(EFFECT_WHITE_1_PATH, Vector2(0, -2), Vector2(0.07, 0.07), 0.0)
	var tw1 := white1.create_tween()
	tw1.tween_property(white1, "modulate:a", 1.0, 0.12)
	tw1.parallel().tween_property(white1, "scale", Vector2(0.19, 0.19), 0.75).set_ease(Tween.EASE_OUT)
	tw1.parallel().tween_property(white1, "rotation_degrees", 36.0, 1.00)
	tw1.tween_interval(0.10)
	tw1.tween_property(white1, "modulate:a", 0.0, 0.35)

	var cleanup := fx_root.create_tween()
	cleanup.tween_interval(1.25)
	cleanup.tween_callback(fx_root.queue_free)

func _finish_evolution() -> void:
	if not _is_evolving:
		return
	_is_evolving = false
	_is_evil = true
	boss_name = evil_boss_name
	max_health = ceilf(_base_max_health * 1.25)
	health = max_health
	_molotov_timer = 0.45
	health_changed.emit(health, max_health)

	var hud = _get_hud()
	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar(evil_boss_name, health, max_health)

	if sprite:
		sprite.modulate = Color.WHITE
		_play_anim("idle_evil_" + _last_dir)

func _process_evil_aura(delta: float, interval: float) -> void:
	_fire_aura_timer -= delta
	if _fire_aura_timer > 0.0:
		return
	_fire_aura_timer = interval
	var parent = get_parent()
	if not parent:
		return
	var ember := Polygon2D.new()
	ember.z_index = z_index + 1
	ember.polygon = PackedVector2Array([Vector2(-1.6, -1.6), Vector2(1.6, -1.6), Vector2(1.6, 1.6), Vector2(-1.6, 1.6)])
	ember.color = Color(1.0, randf_range(0.25, 0.72), 0.08, 0.88)
	var offset := Vector2(randf_range(-12.0, 12.0), randf_range(-4.0, 14.0))
	ember.global_position = global_position + offset
	parent.add_child(ember)
	var t := ember.create_tween().set_parallel(true)
	t.tween_property(ember, "global_position:y", ember.global_position.y - randf_range(12.0, 22.0), 0.45)
	t.tween_property(ember, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(ember.queue_free)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead or _is_evolving:
		return

	health = max(0.0, health - amount)

	# Evolusi ke Evil Boss saat darah tersisa <= 25% dari darah awal
	if not _is_evil and health <= _base_max_health * 0.25:
		health = max(1.0, health)
		health_changed.emit(health, max_health)
		var h_evo = _get_hud()
		if h_evo and h_evo.has_method("update_boss_hp"):
			h_evo.update_boss_hp(health, max_health)
		_start_evolution()
		return

	health_changed.emit(health, max_health)

	var hud = _get_hud()
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(health, max_health)

	_hurt_timer = 0.14
	_knockback_velocity = knockback_dir.normalized() * 35.0

	if sprite:
		sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE if (_is_evil or health > max_health * 0.5) else Color(1.0, 0.8, 0.8), 0.2)

	# Panggil minion Slime hanya saat fase normal (<= 70% dan <= 35%)
	if not _is_evil:
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
	_clear_pending_telegraphs()
	if collision:
		collision.set_deferred("disabled", true)

	var hud = _get_hud()
	if hud and hud.has_method("on_boss_defeated"):
		hud.on_boss_defeated(_get_display_name())

	_spawn_drop_item("potion_red", Vector2(-20, 0))
	_spawn_drop_item("potion_red", Vector2(20, 0))
	_spawn_drop_item("coin", Vector2(0, 15))

	var tween = create_tween()
	if sprite:
		var squash := Vector2(sprite.scale.x * 1.25, sprite.scale.y * 0.22)
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.2), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0.5), 0.1)
		tween.tween_property(sprite, "scale", squash, 0.35)
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
