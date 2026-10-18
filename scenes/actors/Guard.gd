extends Node2D
## A dark-robed arena guard. Walks to a late player, then stands beside them until the screen fades
## to the arena. Runs the same way on every peer from the synced player position, so nothing is networked.

const Robe := preload("res://scenes/actors/robe.gd")

signal reached_target

var _target: Node2D
var _offset := Vector2.ZERO
var _arrived := false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_sprite.material = Robe.make(Robe.BLUE, 0.15, 0.55)  # charcoal robes
	_sprite.play(&"run")


func escort(target: Node2D, offset: Vector2) -> void:
	_target = target
	_offset = offset


func _process(delta: float) -> void:
	if not is_instance_valid(_target) or GameState.phase >= GameState.Phase.FIGHT:
		queue_free()
		return
	var goal := _target.global_position + _offset
	if _arrived:
		global_position = goal
		return
	var step := global_position.move_toward(goal, Config.GUARD_SPEED * delta) - global_position
	if absf(step.x) > 0.01:
		_sprite.flip_h = step.x < 0.0
	global_position += step
	if global_position.distance_to(goal) < 2.0:
		_arrived = true
		_sprite.play(&"idle")
		_sprite.flip_h = _target.global_position.x < global_position.x  # face the player
		reached_target.emit()
