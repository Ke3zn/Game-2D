extends StaticBody2D
class_name BurningTree

enum Stage { STAGE_1_BURNING, STAGE_2_DYING, STAGE_3_EMBERS, STAGE_4_OUT, STAGE_4_FINAL }

@export var extinguish_duration: float = 2.1

var current_stage: Stage = Stage.STAGE_1_BURNING
var fire_level: float = 1.0 # 1.0 = api penuh, 0.0 = padam total
var _steam_cooldown: float = 0.0
var _player_ref: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("burning_tree")
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.animation_finished.connect(_on_animation_finished)
		var ext_list = get_tree().get_meta("extinguished_trees", [])
		if ext_list is Array and name in ext_list:
			fire_level = 0.0
			current_stage = Stage.STAGE_4_FINAL
			sprite.play("stage_4_final")
			return
		sprite.play("stage_1_burning")

func is_extinguished() -> bool:
	return current_stage == Stage.STAGE_4_OUT or current_stage == Stage.STAGE_4_FINAL

func _process(delta: float) -> void:
	if _steam_cooldown > 0.0:
		_steam_cooldown = maxf(0.0, _steam_cooldown - delta)

	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	if _player_ref:
		z_index = 1 if (_player_ref.global_position.y + 15.0) > global_position.y else 3

func apply_apar_spray(spray_delta: float) -> void:
	if current_stage == Stage.STAGE_4_OUT or current_stage == Stage.STAGE_4_FINAL or spray_delta <= 0.0:
		return

	var reduction: float = spray_delta / maxf(0.1, extinguish_duration)
	fire_level = maxf(0.0, fire_level - reduction)

	var next_stage: Stage = current_stage
	if fire_level <= 0.0:
		next_stage = Stage.STAGE_4_OUT
	elif fire_level <= 0.33:
		next_stage = Stage.STAGE_3_EMBERS
	elif fire_level <= 0.66:
		next_stage = Stage.STAGE_2_DYING
	else:
		next_stage = Stage.STAGE_1_BURNING

	if next_stage != current_stage:
		current_stage = next_stage
		_play_stage_anim(current_stage)
		_spawn_steam_puff(4 if current_stage != Stage.STAGE_4_OUT else 7)
		if current_stage == Stage.STAGE_4_OUT:
			var ext_list: Array = get_tree().get_meta("extinguished_trees", []).duplicate()
			if not (name in ext_list):
				ext_list.append(name)
				get_tree().set_meta("extinguished_trees", ext_list)
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("on_burning_tree_extinguished"):
				hud.on_burning_tree_extinguished()

	if sprite and current_stage != Stage.STAGE_4_OUT:
		sprite.modulate = Color(0.9, 0.96, 1.0, 1.0)
		var flash_t: Tween = create_tween()
		flash_t.tween_property(sprite, "modulate", Color.WHITE, 0.14)

	if _steam_cooldown <= 0.0:
		_steam_cooldown = 0.24
		_spawn_steam_puff(2)

func _play_stage_anim(stage: Stage) -> void:
	if not sprite:
		return
	match stage:
		Stage.STAGE_1_BURNING:
			sprite.play("stage_1_burning")
		Stage.STAGE_2_DYING:
			sprite.play("stage_2_dying")
		Stage.STAGE_3_EMBERS:
			sprite.play("stage_3_embers")
		Stage.STAGE_4_OUT:
			sprite.modulate = Color.WHITE
			sprite.play("stage_4_out")
		Stage.STAGE_4_FINAL:
			sprite.modulate = Color.WHITE
			sprite.play("stage_4_final")

func _on_animation_finished() -> void:
	if current_stage == Stage.STAGE_4_OUT:
		current_stage = Stage.STAGE_4_FINAL
		_play_stage_anim(Stage.STAGE_4_FINAL)

func _spawn_steam_puff(count: int = 3) -> void:
	var parent_node: Node = get_parent()
	if not parent_node:
		return
	for i in range(count):
		var puff: Polygon2D = Polygon2D.new()
		puff.z_index = 4
		puff.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-26.0, -8.0))
		puff.polygon = PackedVector2Array([
			Vector2(-2.2, -2.2), Vector2(2.2, -2.2),
			Vector2(2.2, 2.2), Vector2(-2.2, 2.2)
		])
		puff.color = Color(0.95, 0.98, 1.0, 0.78)
		parent_node.add_child(puff)

		var target: Vector2 = puff.global_position + Vector2(randf_range(-7.0, 7.0), randf_range(-16.0, -8.0))
		var t: Tween = puff.create_tween().set_parallel(true)
		t.tween_property(puff, "global_position", target, 0.42).set_ease(Tween.EASE_OUT)
		t.tween_property(puff, "scale", Vector2(2.0, 2.0), 0.42)
		t.tween_property(puff, "modulate:a", 0.0, 0.44)
		t.chain().tween_callback(puff.queue_free)
