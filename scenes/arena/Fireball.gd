extends Node2D
## Flies in a straight line. Every peer moves it locally; only the host checks hits (World.gd).

var id := 0
var owner_slot := 1
var tier := "medium"
var damage := 0
var radius := 6.0

var _dir := Vector2.RIGHT
var _speed := 200.0
var _color := Color.ORANGE
var _life := Config.FIREBALL_LIFETIME


func setup(p_id: int, p_owner_slot: int, dir: Vector2, p_tier: String) -> void:
	id = p_id
	owner_slot = p_owner_slot
	tier = p_tier
	_dir = dir
	var stats: Dictionary = Config.FIREBALL_TIERS[p_tier]
	damage = stats.damage
	radius = stats.radius
	_speed = stats.speed
	_color = stats.color


func _process(delta: float) -> void:
	position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, _color)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 1.0, 0.8))
