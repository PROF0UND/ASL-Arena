@tool
extends Node2D
## The stone walkway between a home and the arena. The node position is the top-left corner.
## NPCs are child instances in Walkway.tscn; move them around in the editor.

const STONE := Color(0.60, 0.60, 0.55)
const SEAM := Color(0.48, 0.48, 0.44)

@export var size := Vector2(80, 340):
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:
	add_to_group("zone")


func contains_point(p: Vector2) -> bool:
	return Rect2(global_position, size).has_point(p)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), STONE)
	var y := 20.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), SEAM, 1.0)
		y += 20.0
