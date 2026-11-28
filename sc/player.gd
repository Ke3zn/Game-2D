extends CharacterBody2D

signal blood_changed(current: float, max_val: float)
signal energy_changed(current: float, max_val: float)
signal active_slot_changed(slot_index: int)
signal died()

@export_group("Inventory")
@export var active_slot: int = 1 # 0: Pemadam Api, 1: Pentungan, 2: Slot Kosong

@export_group("Movement")
@export var speed: float = 30.0
@export var sprint_speed: float = 55.0

@export_group("Stats")
@export var max_blood: float = 100.0
@export var current_blood: float = 100.0
@export var max_energy: float = 100.0
@export var current_energy: float = 100.0
@export var energy_recovery_rate: float = 22.0 # Pemulihan energi per detik saat istirahat
@export var energy_recovery_delay: float = 0.4 # Jeda (detik) sebelum energi mulai pulih setelah dipakai
@export var attack_energy_cost: float = 8.0    # Pengurangan energi setiap serangan
@export var sprint_energy_cost: float = 25.0   # Pengurangan energi per detik saat sprint

var direction := Vector2.ZERO
var last_direction := "front"
var is_attacking := false
var is_spraying_apar := false
var is_hurt := false
var is_dead := false
var has_apar := false
var _energy_recovery_timer: float = 0.0
var _invuln_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _attack_failsafe_timer: float = 0.0
var _attack_seq: int = 0
const SFX_BAT_PATH := "res://asset/music/sfx/bathitball.mp3"
const SFX_APAR_PATH := "res://asset/music/sfx/spray-first-aid.mp3"
const SFX_WALK_PATH := "res://asset/music/sfx/baim_walk.mp3"
const SFX_RUN_PATH := "res://asset/music/sfx/baim_run.mp3"

var _apar_foam_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _attack_lunge_velocity: Vector2 = Vector2.ZERO
var _hit_dealt_this_swing: bool = false
var _sfx_pentungan: AudioStreamPlayer = null
var _sfx_apar: AudioStreamPlayer = null
var _sfx_walk: AudioStreamPlayer = null
var _sfx_run: AudioStreamPlayer = null
var _is_walking_sfx: bool = false
var _is_running_sfx: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	has_apar = get_tree().get_meta("has_apar", false)
	var bonus_hp: float = float(get_tree().get_meta("bonus_max_blood", 0.0))
	if bonus_hp > 0.0:
		max_blood += bonus_hp
		current_blood = minf(max_blood, current_blood + bonus_hp)
	_setup_audio()
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_play_state_anim("idle")
	# Pancarkan status awal
	blood_changed.emit(current_blood, max_blood)
	energy_changed.emit(current_energy, max_energy)
	active_slot_changed.emit(active_slot)
	if get_tree().get_meta("spawn_outside_house", false):
		call_deferred("_apply_house_exit_spawn", "spawn_outside_house", "Door_VillageHouse")
	elif get_tree().get_meta("spawn_outside_store", false):
		call_deferred("_apply_house_exit_spawn", "spawn_outside_store", "Door_WeaponStore")

func _apply_house_exit_spawn(meta_key: String = "spawn_outside_house", door_name: String = "Door_VillageHouse") -> void:
	if not get_tree() or not get_tree().get_meta(meta_key, false):
		return
	var door := get_parent().get_node_or_null(door_name) as Node2D
	if not door:
		door = get_tree().get_first_node_in_group("door") as Node2D
	if door:
		get_tree().remove_meta(meta_key)
		global_position = door.global_position + Vector2(0, 26)
		var cam := get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_smoothing()
			cam.force_update_scroll()
		last_direction = "front"
		_play_state_anim("idle")

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			set_active_slot(0)
		elif event.keycode == KEY_2:
			set_active_slot(1)
		elif event.keycode == KEY_3:
			set_active_slot(2)
		elif event.keycode == KEY_B or event.keycode == KEY_I or event.keycode == KEY_TAB:
			var hud = get_tree().get_first_node_in_group("hud")
			if not hud:
				hud = get_parent().get_node_or_null("HUD")
			if hud and hud.has_method("toggle_inventory"):
				hud.toggle_inventory()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_active_slot((active_slot - 1 + 3) % 3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_active_slot((active_slot + 1) % 3)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _invuln_timer > 0.0:
		_invuln_timer = max(0.0, _invuln_timer - delta)

	if Input.is_action_just_pressed("attack") and _get_active_item_id() == "pentungan":
		_attack_buffer_timer = 0.18
	elif _attack_buffer_timer > 0.0:
		_attack_buffer_timer = max(0.0, _attack_buffer_timer - delta)

	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 280.0)
	_attack_lunge_velocity = _attack_lunge_velocity.move_toward(Vector2.ZERO, delta * 320.0)

	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if is_attacking:
		is_spraying_apar = false
		_stop_apar_sfx()
		_stop_move_sfx()
		_attack_failsafe_timer = max(0.0, _attack_failsafe_timer - delta)
		if _attack_failsafe_timer <= 0.0:
			is_attacking = false
			_attack_lunge_velocity = Vector2.ZERO
			_play_state_anim(_get_move_state())
		else:
			# Tetap izinkan sedikit kendali arah + momentum lunge agar serangan terasa luwes, bukan membeku
			velocity = direction * (speed * 0.35) + _attack_lunge_velocity + _knockback_velocity
			move_and_slide()
			return

	var wants_spray := _get_active_item_id() == "pemadam" and has_apar and Input.is_action_pressed("attack") and not _is_dialogue_open()
	is_spraying_apar = wants_spray

	var is_sprinting := false
	if direction != Vector2.ZERO:
		is_sprinting = not is_spraying_apar and Input.is_key_pressed(KEY_SHIFT) and current_energy > 0.0
		if is_sprinting:
			velocity = direction.normalized() * sprint_speed
			if sprite:
				sprite.speed_scale = 1.0
			current_energy = max(0.0, current_energy - sprint_energy_cost * delta)
			_energy_recovery_timer = energy_recovery_delay
			energy_changed.emit(current_energy, max_energy)
		else:
			var move_spd := speed * 0.85 if is_spraying_apar else speed
			velocity = direction.normalized() * move_spd
			if sprite:
				sprite.speed_scale = 0.95
		velocity += _knockback_velocity

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
		_play_state_anim("run" if is_sprinting else "walk")
	else:
		velocity = _knockback_velocity
		if sprite:
			sprite.speed_scale = 1.0
		_play_state_anim("idle")

	_update_move_sfx(direction != Vector2.ZERO, is_sprinting)

	# Pemulihan energi jika tidak sedang sprint dan jeda delay sudah selesai
	if not is_sprinting:
		if _energy_recovery_timer > 0.0:
			_energy_recovery_timer = max(0.0, _energy_recovery_timer - delta)
		elif current_energy < max_energy:
			current_energy = min(max_energy, current_energy + energy_recovery_rate * delta)
			energy_changed.emit(current_energy, max_energy)

	if is_spraying_apar:
		if _sfx_apar and _sfx_apar.stream and not _sfx_apar.playing:
			_sfx_apar.play()
		_process_continuous_apar_spray(delta)
	else:
		_apar_foam_timer = 0.0
		_stop_apar_sfx()

	if _attack_buffer_timer > 0.0:
		_attack_buffer_timer = 0.0
		if _get_active_item_id() == "pentungan":
			# Bisa attack jika slot aktif sedang memegang pentungan
			if current_energy >= attack_energy_cost:
				current_energy -= attack_energy_cost
				_energy_recovery_timer = energy_recovery_delay
				energy_changed.emit(current_energy, max_energy)
				_start_attack_pentungan()
			else:
				var hud = get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("flash_energy_bar"):
					hud.flash_energy_bar()
		move_and_slide()
		return

	move_and_slide()

func _get_active_item_id() -> String:
	if active_slot == 0:
		return "hand"
	var eq = get_tree().get_meta("hotbar_equips", ["hand", "pentungan", ""])
	if eq is Array and active_slot >= 0 and active_slot < eq.size():
		return str(eq[active_slot])
	return "pentungan" if active_slot == 1 else ""

func _get_tool_suffix() -> String:
	var item_id := _get_active_item_id()
	if item_id == "pentungan":
		return "_pentungan"
	elif item_id == "pemadam" and has_apar:
		return "_apar"
	return ""

func _play_state_anim(base_state: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name = base_state + _get_tool_suffix() + "_" + last_direction
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
	else:
		var fallback = base_state + "_" + last_direction
		if sprite.sprite_frames.has_animation(fallback):
			if sprite.animation != fallback or not sprite.is_playing():
				sprite.play(fallback)

func _get_move_state() -> String:
	if direction == Vector2.ZERO:
		return "idle"
	if Input.is_key_pressed(KEY_SHIFT) and current_energy > 0.0:
		return "run"
	return "walk"

func grant_apar() -> void:
	has_apar = true
	get_tree().set_meta("has_apar", true)
	var target := 2
	var eq = get_tree().get_meta("hotbar_equips", ["hand", "pentungan", "pemadam"])
	if eq is Array and eq.size() >= 3:
		if str(eq[1]) == "pemadam":
			target = 1
		elif str(eq[2]) == "pemadam":
			target = 2
	set_active_slot(target)
	if not is_attacking and not is_hurt and not is_dead:
		_play_state_anim(_get_move_state())

func _get_facing_vector() -> Vector2:
	match last_direction:
		"front": return Vector2.DOWN
		"back": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN

func _start_attack_pentungan() -> void:
	is_attacking = true
	_hit_dealt_this_swing = false
	_attack_failsafe_timer = 0.75
	_attack_seq += 1
	var seq := _attack_seq
	var attack_dir = _get_facing_vector()
	_attack_lunge_velocity = attack_dir * 24.0
	velocity = _attack_lunge_velocity
	if _sfx_pentungan and _sfx_pentungan.stream:
		_sfx_pentungan.play()

	var anim_name = "attack_pentungan_" + last_direction
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.speed_scale = 1.0
		sprite.scale = Vector2(0.3, 0.3)
		sprite.play(anim_name)
		sprite.frame = 0

		# Eksekusi hit tepat saat ayunan pentungan mencapai frame impact (~frame 2 @ 10fps)
		get_tree().create_timer(0.20).timeout.connect(func():
			if not is_dead and is_attacking and _attack_seq == seq and not _hit_dealt_this_swing:
				_execute_pentungan_hit()
		)
	else:
		_execute_pentungan_hit()
		is_attacking = false

func _execute_pentungan_hit() -> void:
	_hit_dealt_this_swing = true
	var attack_dir = _get_facing_vector()
	var attack_damage = 25.0 + float(get_tree().get_meta("bonus_attack_damage", 0.0))
	var attack_range = 24.0 + float(get_tree().get_meta("bonus_attack_range", 0.0))
	var attack_center = global_position + attack_dir * 12.0
	var hit_any = false
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.get("is_dead"):
			if e.global_position.distance_to(attack_center) <= attack_range:
				var kb = (e.global_position - global_position).normalized()
				if kb == Vector2.ZERO:
					kb = attack_dir
				if e.has_method("take_damage"):
					e.take_damage(attack_damage, kb)
					hit_any = true
	if hit_any:
		Engine.time_scale = 0.08
		await get_tree().create_timer(0.04, true, false, true).timeout
		Engine.time_scale = 1.0

func _make_sfx_player(path: String, vol_db: float, loop_mp3: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = vol_db
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path)
		if loop_mp3 and s is AudioStreamMP3:
			s.loop = true
		p.stream = s
	add_child(p)
	return p

func _setup_audio() -> void:
	_sfx_pentungan = _make_sfx_player(SFX_BAT_PATH, -3.0, false)
	_sfx_apar = _make_sfx_player(SFX_APAR_PATH, -4.0, true)
	_sfx_apar.finished.connect(func():
		if is_spraying_apar and not is_dead and _sfx_apar.stream and is_inside_tree():
			_sfx_apar.play()
	)
	_sfx_walk = _make_sfx_player(SFX_WALK_PATH, -28.0, true)
	_sfx_walk.finished.connect(func():
		if _is_walking_sfx and not is_dead and _sfx_walk.stream and is_inside_tree():
			_sfx_walk.play()
	)
	_sfx_run = _make_sfx_player(SFX_RUN_PATH, -25.0, true)
	_sfx_run.finished.connect(func():
		if _is_running_sfx and not is_dead and _sfx_run.stream and is_inside_tree():
			_sfx_run.play()
	)

func _update_move_sfx(is_moving: bool, is_sprinting: bool) -> void:
	if not is_moving or is_dead or is_attacking:
		_stop_move_sfx()
		return
	if is_sprinting:
		_is_walking_sfx = false
		_is_running_sfx = true
		if _sfx_walk and _sfx_walk.playing:
			_sfx_walk.stop()
		if _sfx_run and _sfx_run.stream and not _sfx_run.playing:
			_sfx_run.play()
	else:
		_is_running_sfx = false
		_is_walking_sfx = true
		if _sfx_run and _sfx_run.playing:
			_sfx_run.stop()
		if _sfx_walk and _sfx_walk.stream and not _sfx_walk.playing:
			_sfx_walk.play()

func _stop_move_sfx() -> void:
	_is_walking_sfx = false
	_is_running_sfx = false
	if _sfx_walk and _sfx_walk.playing:
		_sfx_walk.stop()
	if _sfx_run and _sfx_run.playing:
		_sfx_run.stop()

func _stop_apar_sfx() -> void:
	if _sfx_apar and _sfx_apar.playing:
		_sfx_apar.stop()

func _is_dialogue_open() -> bool:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and "dialogue_modal" in hud and hud.dialogue_modal:
		return hud.dialogue_modal.visible
	return false

func _process_continuous_apar_spray(delta: float) -> void:
	var attack_dir := _get_facing_vector()
	_apar_foam_timer -= delta

	if _apar_foam_timer <= 0.0:
		_apar_foam_timer = 0.065
		_spawn_apar_foam(attack_dir, 5)
		var tree_spray_center := global_position + attack_dir * 22.0
		for tree in get_tree().get_nodes_in_group("burning_tree"):
			if is_instance_valid(tree) and tree.has_method("apply_apar_spray"):
				if tree.global_position.distance_to(tree_spray_center) <= 34.0 or global_position.distance_to(tree.global_position) <= 28.0:
					tree.apply_apar_spray(0.065)

func _spawn_apar_foam(attack_dir: Vector2, puff_count: int = 5) -> void:
	var parent_node = get_parent()
	if not parent_node:
		return
	var base_angle = attack_dir.angle()
	var origin = global_position + attack_dir * 9.0 + Vector2(0, 3)
	for i in range(puff_count):
		var puff = Polygon2D.new()
		puff.z_index = 4
		puff.global_position = origin
		puff.polygon = PackedVector2Array([Vector2(-2.2, -2.2), Vector2(2.2, -2.2), Vector2(2.2, 2.2), Vector2(-2.2, 2.2)])
		puff.color = Color(1.0, 1.0, 1.0, 0.92) if i % 2 == 0 else Color(0.90, 0.96, 1.0, 0.82)
		parent_node.add_child(puff)

		var a = base_angle + randf_range(-0.48, 0.48)
		var dist_out = randf_range(16.0, 38.0)
		var target_p = origin + Vector2(cos(a) * dist_out, sin(a) * dist_out)
		var t = puff.create_tween().set_parallel(true)
		t.tween_property(puff, "global_position", target_p, 0.32).set_ease(Tween.EASE_OUT)
		t.tween_property(puff, "scale", Vector2(2.1, 2.1), 0.32)
		t.tween_property(puff, "modulate:a", 0.0, 0.34)
		t.chain().tween_callback(puff.queue_free)

func set_active_slot(index: int) -> void:
	if active_slot == index:
		return
	active_slot = clampi(index, 0, 2)
	active_slot_changed.emit(active_slot)
	if not is_attacking and not is_hurt and not is_dead:
		_play_state_anim(_get_move_state())

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		_attack_lunge_velocity = Vector2.ZERO
		_play_state_anim(_get_move_state())
	elif is_hurt:
		is_hurt = false
		_play_state_anim(_get_move_state())

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_dead or _invuln_timer > 0.0:
		return
	var dmg_mult: float = clampf(1.0 - float(get_tree().get_meta("damage_reduction", 0.0)), 0.25, 1.0)
	var final_amount: float = amount * dmg_mult
	current_blood = max(0.0, current_blood - final_amount)
	blood_changed.emit(current_blood, max_blood)

	if current_blood > 0.0 and amount > 0.0:
		# Gunakan i-frame 0.5 detik + knockback ringan tanpa stun-lock 1 detik agar pertarungan tetap responsif
		_invuln_timer = 0.5
		if knockback != Vector2.ZERO:
			_knockback_velocity = knockback
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 0.7), 0.08)
			tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.55), 0.1)
			tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4, 0.8), 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)

	if current_blood <= 0.0:
		_die()

func heal(amount: float) -> void:
	current_blood = min(max_blood, current_blood + amount)
	blood_changed.emit(current_blood, max_blood)

func use_energy(amount: float) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		_energy_recovery_timer = energy_recovery_delay
		energy_changed.emit(current_energy, max_energy)
		return true
	return false

func restore_energy(amount: float) -> void:
	current_energy = min(max_energy, current_energy + amount)
	energy_changed.emit(current_energy, max_energy)

func _die() -> void:
	if is_dead:
		return
	Engine.time_scale = 1.0
	is_dead = true
	is_attacking = false
	is_spraying_apar = false
	_stop_apar_sfx()
	_stop_move_sfx()
	_attack_buffer_timer = 0.0
	velocity = Vector2.ZERO
	died.emit()
	if sprite:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(sprite, "rotation_degrees", 90.0, 0.35)
		tween.tween_property(sprite, "modulate", Color(0.85, 0.2, 0.2, 0.8), 0.35)
		tween.tween_property(sprite, "position:y", sprite.position.y + 6.0, 0.35)

func respawn(respawn_pos: Vector2 = Vector2.ZERO) -> void:
	Engine.time_scale = 1.0
	is_dead = false
	is_attacking = false
	is_spraying_apar = false
	_stop_apar_sfx()
	_stop_move_sfx()
	_attack_buffer_timer = 0.0
	_attack_failsafe_timer = 0.0
	is_hurt = false
	current_blood = max_blood
	current_energy = max_energy
	blood_changed.emit(current_blood, max_blood)
	energy_changed.emit(current_energy, max_energy)
	if respawn_pos != Vector2.ZERO:
		global_position = respawn_pos
	if sprite:
		sprite.rotation_degrees = 0.0
		sprite.modulate = Color.WHITE
		sprite.position = Vector2.ZERO
		_play_state_anim("idle")
