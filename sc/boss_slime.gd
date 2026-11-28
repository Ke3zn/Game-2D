extends CharacterBody2D
class_name BossSlime

signal health_changed(current: float, max_val: float)
signal died()

@export var boss_name: String = "👑 SLIME KING"
@export var max_health: float = 180.0
@export var health: float = 180.0
@export var damage: float = 10.0
@export var slam_damage: float = 8.0
@export var speed: float = 22.0
@export var detection_radius: float = 180.0
@export var slam_cooldown: float = 4.0

var player: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_dead: bool = false

var _attack_timer: float = 0.0
var _slam_timer: float = 2.0
var _is_slamming: bool = false
var _is_lunging: bool = false
var _minion_spawned: bool = false
var _was_player_in_range: bool = false
var _hurt_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _shadow: Polygon2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var crown: Sprite2D = $Crown
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	spawn_position = global_position
	health = max_health
	_create_shadow()

	# Muat mahkota secara dinamis
	if crown and FileAccess.file_exists("res://asset/tools/crown.png"):
		var img = Image.load_from_file("res://asset/tools/crown.png")
		if img:
			crown.texture = ImageTexture.create_from_image(img)

func _create_shadow() -> void:
	_shadow = Polygon2D.new()
	_shadow.name = "GroundShadow"
	_shadow.z_index = -1
	_shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	var pts = PackedVector2Array()
	for i in range(18):
		var a = (float(i) / 18.0) * TAU
		pts.append(Vector2(cos(a) * 18.0, sin(a) * 7.0))
	_shadow.polygon = pts
	_shadow.position = Vector2(0, 14)
	add_child(_shadow)

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

	if _is_slamming or _is_lunging:
		return

	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var hud = _get_hud()
	if hud:
		if (hud.has_method("is_dialogue_open") and hud.is_dialogue_open()) or ("quest_status" in hud and hud.quest_status != "QUEST2_SLIME"):
			velocity = Vector2.ZERO
			if _was_player_in_range:
				_was_player_in_range = false
				if hud.has_method("hide_boss_bar"):
					hud.hide_boss_bar()
			move_and_slide()
			return

	if player and is_instance_valid(player):
		z_index = 1 if player.global_position.y > global_position.y else 2
		var dist = global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			_was_player_in_range = true
			# Beritahu HUD untuk memunculkan Boss Health Bar
			if hud and hud.has_method("show_boss_bar"):
				hud.show_boss_bar(boss_name, health, max_health)

			# Cek jika siap Ground Slam (Lompatan Guncangan Tanah)
			if dist <= 120.0 and _slam_timer <= 0.0:
				_perform_ground_slam(player)
				return

			# Kejar player sambil menjaga jarak agar tidak menempel
			var dir = (player.global_position - global_position).normalized()
			var current_speed = speed * 1.25 if health <= max_health * 0.5 else speed
			if dist < 20.0:
				velocity = -dir * (current_speed * 0.45)
			elif dist <= 26.0:
				velocity = Vector2.ZERO
			else:
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
			if _was_player_in_range:
				_was_player_in_range = false
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
	_is_lunging = true
	_attack_timer = 1.5
	velocity = Vector2.ZERO
	var lunge_dir = (p.global_position - global_position).normalized()
	var start_pos = global_position
	var tilt_deg = 14.0 if lunge_dir.x >= 0 else -14.0

	var tween = create_tween()
	# Fase 1: Tarik ke belakang & squash (antisipasi)
	if sprite:
		tween.tween_property(sprite, "scale", Vector2(2.85, 1.85), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "rotation_degrees", -tilt_deg * 0.5, 0.1)
	if crown:
		tween.parallel().tween_property(crown, "position:y", -18.0, 0.1)

	# Fase 2: Terjang cepat ke depan & stretch
	tween.tween_property(self, "global_position", start_pos + lunge_dir * 14.0, 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if sprite:
		tween.parallel().tween_property(sprite, "scale", Vector2(2.0, 2.85), 0.12)
		tween.parallel().tween_property(sprite, "rotation_degrees", tilt_deg, 0.12)
	if crown:
		tween.parallel().tween_property(crown, "position:y", -26.0, 0.12)

	# Fase 3: Cek benturan & damage tepat saat menerjang
	tween.tween_callback(func():
		if not is_dead and is_instance_valid(p) and global_position.distance_to(p.global_position) <= 30.0:
			if p.has_method("take_damage"):
				p.take_damage(damage, lunge_dir * 85.0)
	)

	# Fase 4: Pantul kembali ke pose normal dengan elastis
	if sprite:
		tween.tween_property(sprite, "scale", Vector2(2.4, 2.4), 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "rotation_degrees", 0.0, 0.2)
	if crown:
		tween.parallel().tween_property(crown, "position:y", -22.0, 0.2)
	tween.tween_callback(func(): _is_lunging = false)

func _perform_ground_slam(p: Node2D) -> void:
	_is_slamming = true
	_slam_timer = slam_cooldown
	velocity = Vector2.ZERO

	var start_pos = global_position
	var target_pos = p.global_position
	var telegraph = _spawn_slam_telegraph(target_pos, 50.0)

	var tween = create_tween()
	# Fase 1: Antisipasi - Squash dalam & bergetar sebelum melompat
	if sprite:
		tween.tween_property(sprite, "scale", Vector2(3.15, 1.45), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.55, 0.4, 1.0), 0.24)
	if crown:
		tween.parallel().tween_property(crown, "position:y", -14.0, 0.24)

	# Fase 2: Meluncur tinggi ke udara (stretch vertikal + bayangan tetap di bawah)
	tween.tween_property(self, "position:y", start_pos.y - 46.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:x", (start_pos.x + target_pos.x) * 0.5, 0.36)
	if sprite:
		tween.parallel().tween_property(sprite, "scale", Vector2(1.75, 3.1), 0.36)
	if crown:
		tween.parallel().tween_property(crown, "position:y", -29.0, 0.36)
	if _shadow:
		tween.parallel().tween_property(_shadow, "scale", Vector2(0.55, 0.55), 0.36)
		tween.parallel().tween_property(_shadow, "position:y", 60.0, 0.36)

	# Fase 3: Jeda singkat di puncak lompatan (hang time)
	tween.tween_interval(0.08)

	# Fase 4: Hantam keras ke tanah target (Slam!)
	tween.tween_property(self, "position:y", target_pos.y, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position:x", target_pos.x, 0.16)
	if sprite:
		tween.parallel().tween_property(sprite, "scale", Vector2(1.9, 2.9), 0.16)
	if _shadow:
		tween.parallel().tween_property(_shadow, "scale", Vector2(1.15, 1.15), 0.16)
		tween.parallel().tween_property(_shadow, "position:y", 14.0, 0.16)

	tween.tween_callback(func():
		if is_instance_valid(telegraph):
			telegraph.queue_free()
		_on_slam_impact()
	)

func _spawn_slam_telegraph(pos: Vector2, radius: float) -> Node2D:
	var parent_node = get_parent()
	if not parent_node:
		return null
	var ring = Polygon2D.new()
	ring.z_index = 1
	ring.global_position = pos
	ring.color = Color(0.95, 0.2, 0.2, 0.28)
	var pts = PackedVector2Array()
	for i in range(28):
		var a = (float(i) / 28.0) * TAU
		pts.append(Vector2(cos(a) * radius, sin(a) * radius * 0.72))
	ring.polygon = pts
	parent_node.add_child(ring)

	var t = ring.create_tween().set_loops()
	t.tween_property(ring, "scale", Vector2(1.08, 1.08), 0.16)
	t.tween_property(ring, "scale", Vector2(0.9, 0.9), 0.16)
	return ring

func _on_slam_impact() -> void:
	# Efek squash benturan tanah + pemulihan elastis
	if sprite:
		sprite.scale = Vector2(3.5, 1.35)
		var base_tint = Color.WHITE if health > max_health * 0.5 else Color(1.0, 0.7, 0.7)
		var t = create_tween()
		t.tween_property(sprite, "scale", Vector2(2.4, 2.4), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(sprite, "modulate", base_tint, 0.25)
	if crown:
		crown.position.y = -13.0
		var ct = create_tween()
		ct.tween_property(crown, "position:y", -22.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if _shadow:
		_shadow.scale = Vector2(1.0, 1.0)
		_shadow.position.y = 14.0

	# Gelombang kejut (Shockwave Ring) & percikan lendir slime
	_spawn_shockwave_and_splashes()

	# Guncangan layar (Screen Shake)
	var hud = _get_hud()
	if hud and hud.has_method("trigger_screen_shake"):
		hud.trigger_screen_shake(8.0, 0.35)

	# Cek area damage di sekitar pendaratan
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= 50.0:
			if player.has_method("take_damage"):
				var kb = (player.global_position - global_position).normalized() * 110.0
				player.take_damage(slam_damage, kb)

	_is_slamming = false

func _spawn_shockwave_and_splashes() -> void:
	var parent_node = get_parent()
	if not parent_node:
		return

	var wave = Line2D.new()
	wave.z_index = 1
	wave.global_position = global_position + Vector2(0, 8)
	wave.width = 4.0
	wave.default_color = Color(1.0, 0.35, 0.35, 0.85)
	var pts = PackedVector2Array()
	for i in range(29):
		var a = (float(i) / 28.0) * TAU
		pts.append(Vector2(cos(a) * 18.0, sin(a) * 13.0))
	wave.points = pts
	parent_node.add_child(wave)

	var wt = wave.create_tween().set_parallel(true)
	wt.tween_property(wave, "scale", Vector2(2.8, 2.8), 0.32).set_ease(Tween.EASE_OUT)
	wt.tween_property(wave, "modulate:a", 0.0, 0.32)
	wt.chain().tween_callback(wave.queue_free)

	for i in range(12):
		var drop = Polygon2D.new()
		drop.z_index = 3
		drop.global_position = global_position + Vector2(0, 6)
		drop.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		drop.color = Color(0.95, 0.25, 0.3, 0.9)
		parent_node.add_child(drop)
		var angle = (float(i) / 12.0) * TAU + randf_range(-0.2, 0.2)
		var d = randf_range(22.0, 48.0)
		var dt = drop.create_tween().set_parallel(true)
		dt.tween_property(drop, "global_position", global_position + Vector2(cos(angle) * d, sin(angle) * d * 0.75 - 4.0), 0.35).set_ease(Tween.EASE_OUT)
		dt.tween_property(drop, "modulate:a", 0.0, 0.35)
		dt.chain().tween_callback(drop.queue_free)

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
	if hud and hud.has_method("add_quest_progress"):
		hud.add_quest_progress("slime", 1)

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
