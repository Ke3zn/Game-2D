extends Sprite2D

@export var fade_alpha: float = 0.35
@export var fade_duration: float = 0.25

var _overlapping_count: int = 0
var _tween: Tween

func _ready() -> void:
	if z_index <= 2:
		z_index = 3
	
	var area = get_node_or_null("Area2D")
	if not area:
		area = Area2D.new()
		area.name = "Area2D"
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		add_child(area)
		
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		if texture:
			shape.size = texture.get_size()
		else:
			shape.size = Vector2(100, 100)
		col.shape = shape
		area.add_child(col)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	
	for body in area.get_overlapping_bodies():
		if body.name == "Player" or body is CharacterBody2D:
			_overlapping_count += 1
	if _overlapping_count > 0:
		modulate.a = fade_alpha

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		_overlapping_count += 1
		_fade_to(fade_alpha)

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body is CharacterBody2D:
		_overlapping_count = max(0, _overlapping_count - 1)
		if _overlapping_count == 0:
			_fade_to(1.0)

func _fade_to(target_alpha: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", target_alpha, fade_duration)
