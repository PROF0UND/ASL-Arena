@tool
extends Node2D
## Walking into this rectangle sends the local player to `target` (usually a Marker2D on another
## screen), with a fade. The node position is the rectangle's top-left corner.

@export var size := Vector2(32, 8):
	set(value):
		size = value
		queue_redraw()
@export var target: NodePath


func _ready() -> void:
	add_to_group("portal")


func rect() -> Rect2:
	return Rect2(global_position, size)


func target_position() -> Vector2:
	var node := get_node_or_null(target) as Node2D
	return node.global_position if node else global_position


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.6, 1.0, 0.9), false, 1.0)
