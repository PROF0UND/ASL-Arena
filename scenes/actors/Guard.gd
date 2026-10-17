extends Node2D
## Walks to a late player, then sticks beside them while they're escorted to the arena.
## Runs the same way on every peer from the synced player position, so no guard state is networked.

signal reached_target

var _target: Node2D
var _offset := Vector2.ZERO
var _arrived := false


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
	global_position = global_position.move_toward(goal, Config.GUARD_SPEED * delta)
	if global_position.distance_to(goal) < 2.0:
		_arrived = true
		reached_target.emit()
