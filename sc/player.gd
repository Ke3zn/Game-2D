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
@export var energy_recovery_rate: float = 15.0 # Pemulihan energi per detik saat istirahat
@export var energy_recovery_delay: float = 0.6 # Jeda (detik) sebelum energi mulai pulih setelah dipakai
@export var attack_energy_cost: float = 20.0   # Pengurangan energi setiap serangan
@export var sprint_energy_cost: float = 25.0   # Pengurangan energi per detik saat sprint

var direction := Vector2.ZERO
var last_direction := "front"
var is_attacking := false
var is_hurt := false
var is_dead := false
var _energy_recovery_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pentungan: Sprite2D = $Pentungan
@onready var apar_sprite: Sprite2D = get_node_or_null("Apar")

func _ready() -> void:
	add_to_group("player")
	if sprite:
		sprite.play("idle_front")
	# Pancarkan status awal
	blood_changed.emit(current_blood, max_blood)
	energy_changed.emit(current_energy, max_energy)
	active_slot_changed.emit(active_slot)
	_update_weapon_transform()

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

	if is_attacking or is_hurt:
		move_and_slide()
		return

	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var is_sprinting := false
	if direction != Vector2.ZERO:
		is_sprinting = Input.is_key_pressed(KEY_SHIFT) and current_energy > 0.0
		if is_sprinting:
			velocity = direction.normalized() * sprint_speed
			if sprite:
				sprite.speed_scale = 1.3
			current_energy = max(0.0, current_energy - sprint_energy_cost * delta)
			_energy_recovery_timer = energy_recovery_delay
			energy_changed.emit(current_energy, max_energy)
		else:
			velocity = direction.normalized() * speed
			if sprite:
				sprite.speed_scale = 0.9

		var prev_dir = last_direction
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
		if sprite:
			sprite.play("run_" + last_direction)
		if prev_dir != last_direction and not is_attacking:
			_update_weapon_transform()
	else:
		velocity = Vector2.ZERO
		if sprite:
			sprite.speed_scale = 1.0
			sprite.play("idle_" + last_direction)

	# Pemulihan energi jika tidak sedang sprint dan jeda delay sudah selesai
	if not is_sprinting:
		if _energy_recovery_timer > 0.0:
			_energy_recovery_timer = max(0.0, _energy_recovery_timer - delta)
		elif current_energy < max_energy:
			current_energy = min(max_energy, current_energy + energy_recovery_rate * delta)
			energy_changed.emit(current_energy, max_energy)

	if Input.is_action_just_pressed("attack"):
		if active_slot == 1:
			# Hanya bisa attack jika sedang memegang pentungan (Slot 1)
			if current_energy >= attack_energy_cost:
				current_energy -= attack_energy_cost
				_energy_recovery_timer = energy_recovery_delay
				energy_changed.emit(current_energy, max_energy)
				_start_attack_pentungan()
			return
		elif active_slot == 0:
			# APAR (Slot 0): alat spray api (menyusul), mainkan animasi spray
			_start_spray_apar()
			return
		else:
			# Slot kosong / selain pentungan: tidak bisa menyerang, tidak mengurangi energi
			pass
		return

	move_and_slide()

func _start_attack_pentungan() -> void:
	is_attacking = true
	velocity = Vector2.ZERO
	if sprite:
		sprite.speed_scale = 1.0
		var anim_name = "attack_pentungan_" + last_direction
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
		else:
			sprite.play("idle_" + last_direction)
	_update_weapon_transform()

	# Cek musuh di area jangkauan serangan pentungan
	var attack_damage = 25.0
	var attack_dir = Vector2.ZERO
	match last_direction:
		"front": attack_dir = Vector2.DOWN
		"back": attack_dir = Vector2.UP
		"left": attack_dir = Vector2.LEFT
		"right": attack_dir = Vector2.RIGHT

	var attack_center = global_position + attack_dir * 12.0
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			if e.global_position.distance_to(attack_center) <= 22.0:
				var kb = (e.global_position - global_position).normalized()
				if kb == Vector2.ZERO:
					kb = attack_dir
				if e.has_method("take_damage"):
					e.take_damage(attack_damage, kb)

func _start_spray_apar() -> void:
	is_attacking = true
	velocity = Vector2.ZERO
	if sprite:
		sprite.speed_scale = 1.0
		var anim_name = "spray_apar_" + last_direction
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
		else:
			sprite.play("idle_" + last_direction)
	_update_weapon_transform()

func set_active_slot(index: int) -> void:
	if active_slot == index:
		return
	active_slot = clampi(index, 0, 2)
	active_slot_changed.emit(active_slot)
	_update_weapon_transform()

func _update_weapon_transform() -> void:
	if not pentungan:
		pentungan = get_node_or_null("Pentungan")
	if not apar_sprite:
		apar_sprite = get_node_or_null("Apar")

	# Sembunyikan overlay senjata saat attack/hurt karena sprite sheet sudah ada senjatanya
	if is_attacking or is_hurt:
		if pentungan:
			pentungan.visible = false
		if apar_sprite:
			apar_sprite.visible = false
		return

	# Slot 1: Pentungan
	if active_slot == 1:
		if apar_sprite:
			apar_sprite.visible = false
		if pentungan:
			pentungan.visible = true
			match last_direction:
				"front":
					pentungan.position = Vector2(2.5, 1.5)
					pentungan.rotation_degrees = 15
					pentungan.flip_h = false
					pentungan.z_index = 1
				"back":
					pentungan.position = Vector2(-2.2, 1.0)
					pentungan.rotation_degrees = -30
					pentungan.flip_h = false
					pentungan.z_index = -1
				"left":
					pentungan.position = Vector2(-2.0, 1.5)
					pentungan.rotation_degrees = -15
					pentungan.flip_h = true
					pentungan.z_index = 1
				"right":
					pentungan.position = Vector2(2.0, 1.5)
					pentungan.rotation_degrees = 15
					pentungan.flip_h = false
					pentungan.z_index = 1
	# Slot 0: APAR (Pemadam Api)
	elif active_slot == 0:
		if pentungan:
			pentungan.visible = false
		if apar_sprite:
			apar_sprite.visible = true
			match last_direction:
				"front":
					apar_sprite.position = Vector2(3.0, 3.0)
					apar_sprite.rotation_degrees = 0
					apar_sprite.flip_h = false
					apar_sprite.z_index = 1
				"back":
					apar_sprite.position = Vector2(-2.5, 2.0)
					apar_sprite.rotation_degrees = 0
					apar_sprite.flip_h = false
					apar_sprite.z_index = -1
				"left":
					apar_sprite.position = Vector2(-3.0, 3.0)
					apar_sprite.rotation_degrees = 0
					apar_sprite.flip_h = true
					apar_sprite.z_index = 1
				"right":
					apar_sprite.position = Vector2(3.0, 3.0)
					apar_sprite.rotation_degrees = 0
					apar_sprite.flip_h = false
					apar_sprite.z_index = 1
	# Slot 2 / Kosong
	else:
		if pentungan:
			pentungan.visible = false
		if apar_sprite:
			apar_sprite.visible = false

func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		sprite.play("idle_" + last_direction)
		_update_weapon_transform()
	elif is_hurt:
		is_hurt = false
		sprite.play("idle_" + last_direction)
		_update_weapon_transform()

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_blood = max(0.0, current_blood - amount)
	blood_changed.emit(current_blood, max_blood)
	
	# Mainkan animasi hurt HANYA saat terkena damage musuh (darah berkurang)
	if current_blood > 0.0 and amount > 0.0:
		is_hurt = true
		is_attacking = false
		if sprite:
			sprite.speed_scale = 1.0
			var anim_hurt = "hurt_" + last_direction
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_hurt):
				sprite.play(anim_hurt)
			elif sprite.sprite_frames and sprite.sprite_frames.has_animation("attack_" + last_direction):
				sprite.play("attack_" + last_direction)
		_update_weapon_transform()
		# Flash merah sebentar
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4, 1.0), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
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
	is_dead = true
	velocity = Vector2.ZERO
	died.emit()
	if pentungan:
		pentungan.visible = false
	if sprite:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(sprite, "rotation_degrees", 90.0, 0.35)
		tween.tween_property(sprite, "modulate", Color(0.85, 0.2, 0.2, 0.8), 0.35)
		tween.tween_property(sprite, "position:y", sprite.position.y + 6.0, 0.35)

func respawn(respawn_pos: Vector2 = Vector2.ZERO) -> void:
	is_dead = false
	is_attacking = false
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
		sprite.play("idle_" + last_direction)
	_update_weapon_transform()
