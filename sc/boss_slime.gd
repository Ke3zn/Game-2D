extends CharacterBody2D
class_name BossSlime

signal health_changed(current: float, max_val: float)
signal died()

@export var boss_name: String = "👑 SLIME KING"
@export var max_health: float = 100.0
@export var health: float = 100.0
@export var damage: float = 20.0
@export var speed: float = 22.0
@export var detection_radius: float = 180.0
@export var slam_cooldown: float = 4.0

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false

var _attack_timer: float = 0.0
var _slam_timer: float = 2.0
var _is_slamming: bool = false
var _minion_spawned: bool = false
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var crown: Sprite2D = $Crown
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	spawn_position = global_position
	health = max_health

	# Muat mahkota secara dinamis
	if crown and FileAccess.file_exists("res://asset/char/tools/crown.png"):
		var img = Image.load_from_file("res://asset/char/tools/crown.png")
		if img:
			crown.texture = ImageTexture.create_from_image(img)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _attack_timer > 0.0:
		_attack_timer = max(0.0, _attack_timer - delta)

	if _slam_timer > 0.0 and not _is_slamming:
		_slam_timer = max(0.0, _slam_timer - delta)

	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, delta * 200.0)
		move_and_slide()
		return

	if _is_slamming:
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var hud = _get_hud()

	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			# Beritahu HUD untuk memunculkan Boss Health Bar
			if hud and hud.has_method("show_boss_bar"):
				hud.show_boss_bar(boss_name, health, max_health)

			# Cek jika siap Ground Slam (Lompatan Guncangan Tanah)
			if dist <= 120.0 and _slam_timer <= 0.0:
				_perform_ground_slam(player)
				return

			# Kejar player
			var dir = (player.global_position - global_position).normalized()
			var current_speed = speed * 1.25 if health <= max_health * 0.5 else speed
			velocity = dir * current_speed

			if sprite:
				sprite.flip_h = dir.x < 0
			if crown:
				crown.position.x = -1.0 if dir.x < 0 else 1.0

			# Cek jika menyentuh player untuk serangan normal
			if dist <= 24.0 and _attack_timer <= 0.0:
				_attack_player(player)
		else:
			# Di luar jangkauan, sembunyikan Boss Bar dan kembali perlahan
			if hud and hud.has_method("hide_boss_bar"):
				hud.hide_boss_bar()

			var dist_spawn = global_position.distance_to(spawn_position)
			if dist_spawn > 15.0:
				var dir_spawn = (spawn_position - global_position).normalized()
				velocity = dir_spawn * (speed * 0.6)
				if sprite:
					sprite.flip_h = dir_spawn.x < 0
			else:
				velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	# Animasi squash/hop bos besar
	if velocity != Vector2.ZERO and sprite:
		var hop = sin(Time.get_ticks_msec() * 0.012)
		sprite.scale = Vector2(2.4 + hop * 0.25, 2.4 - hop * 0.25)
		if crown:
			crown.position.y = -22.0 + hop * 2.0
	elif sprite:
		sprite.scale = Vector2(2.4, 2.4)
		if crown:
			crown.position.y = -22.0

	move_and_slide()

func _attack_player(p: Node2D) -> void:
	_attack_timer = 1.5
	if p.has_method("take_damage"):
		p.take_damage(damage)
	# Efek serang dorongan
	var lunge_dir = (p.global_position - global_position).normalized()
	global_position += lunge_dir * 8.0

func _perform_ground_slam(p: Node2D) -> void:
	_is_slamming = true
	_slam_timer = slam_cooldown
	velocity = Vector2.ZERO

	# Fase 1: Bersiap & Lompat Tinggi ke Udara
	var start_pos = global_position
	var target_pos = p.global_position

	var tween = create_tween()
	# Squash sebelum lompat
	tween.tween_property(sprite, "scale", Vector2(3.0, 1.4), 0.25)
	# Melompat naik
	tween.tween_property(self, "position:y", start_pos.y - 35.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:x", (start_pos.x + target_pos.x) * 0.5, 0.4)
	# Hentak keras ke bawah (Slam)
	tween.tween_property(self, "position:y", target_pos.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position:x", target_pos.x, 0.2)
	tween.tween_callback(func():
		_on_slam_impact()
	)

func _on_slam_impact() -> void:
	# Efek squash benturan tanah
	if sprite:
		sprite.scale = Vector2(3.2, 1.6)
		var t = create_tween()
		t.tween_property(sprite, "scale", Vector2(2.4, 2.4), 0.3)

	# Guncangan layar (Screen Shake)
	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(8.0, 0.35)

	# Cek area damage di sekitar pendaratan
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= 50.0:
			if player.has_method("take_damage"):
				player.take_damage(15.0)

	_is_slamming = false

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)

	var hud = _get_hud()
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(health, max_health)

	# Knockback ringan untuk bos (lebih kokoh dari musuh biasa)
	_hurt_timer = 0.15
	_knockback_velocity = knockback_dir.normalized() * 35.0

	# Efek kedip merah
	if sprite:
		sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE if health > max_health * 0.5 else Color(1.0, 0.7, 0.7), 0.2)

	# Panggil minion saat darah di bawah 50%
	if health <= max_health * 0.5 and not _minion_spawned:
		_summon_minion()

	if health <= 0.0:
		_die()

func _summon_minion() -> void:
	_minion_spawned = true
	var slime_scene = load("res://asset/enemy_slime.tscn")
	if slime_scene and get_parent():
		var minion = slime_scene.instantiate()
		minion.global_position = global_position + Vector2(25, 0)
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

	# Drop Hadiah Legendaris (2 Ramuan Merah + 1 Tumpukan Koin)
	_spawn_drop_item("potion_red", Vector2(-20, 0))
	_spawn_drop_item("potion_red", Vector2(20, 0))
	_spawn_drop_item("coin", Vector2(0, 15))

	# Efek animasi kekalahan dramatis (berkedip cepat lalu meletus squash)
	var tween = create_tween()
	if sprite:
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.2), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color(1, 0.2, 0.2, 0.5), 0.1)
		tween.tween_property(sprite, "scale", Vector2(3.5, 0.2), 0.35)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	if crown:
		tween.parallel().tween_property(crown, "position:y", -45.0, 0.2)
		tween.parallel().tween_property(crown, "modulate:a", 0.0, 0.35)
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
