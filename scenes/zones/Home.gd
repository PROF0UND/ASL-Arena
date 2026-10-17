@tool
extends Node2D
## A player's starting zone with a dojo inside it. The node position is the top-left corner.
## Everything is rectangles so the map can be rearranged freely in World.tscn.

const FLOOR := Color(0.30, 0.58, 0.32)
const OUTLINE := Color(0.14, 0.30, 0.16)
const DOJO := Color(0.45, 0.32, 0.20)
const DOOR := Color(0.95, 0.85, 0.40)
const DOOR_SIZE := Vector2(32, 14)

@export var slot := 1:
	set(value):
		slot = value
		queue_redraw()
@export var size := Vector2(640, 360):
	set(value):
		size = value
		queue_redraw()
@export var dojo_rect := Rect2(60, 50, 160, 100):
	set(value):
		dojo_rect = value
		queue_redraw()
@export var spawn_offset := Vector2(480, 220)


func _ready() -> void:
	add_to_group("zone")
	add_to_group("home")


func area_rect() -> Rect2:
	return Rect2(global_position, size)


func dojo_global() -> Rect2:
	return Rect2(global_position + dojo_rect.position, dojo_rect.size)


func door_global() -> Rect2:
	return Rect2(global_position + _door_local().position, DOOR_SIZE)


func spawn_point() -> Vector2:
	return global_position + spawn_offset


func contains_point(p: Vector2) -> bool:
	return area_rect().has_point(p) and not dojo_global().has_point(p)


## The point on this zone's edge nearest to `target`, used to walk escorted players out.
func exit_toward(target: Vector2) -> Vector2:
	var r := area_rect().grow(-12)
	return Vector2(clampf(target.x, r.position.x, r.end.x), clampf(target.y, r.position.y, r.end.y))


func _door_local() -> Rect2:
	return Rect2(dojo_rect.position.x + dojo_rect.size.x / 2 - DOOR_SIZE.x / 2, dojo_rect.end.y, DOOR_SIZE.x, DOOR_SIZE.y)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), FLOOR)
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 2.0)
	draw_string(font, Vector2(8, 18), "PLAYER %d HOME" % slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, OUTLINE)
	draw_rect(dojo_rect, DOJO)
	draw_string(font, dojo_rect.position + Vector2(0, dojo_rect.size.y / 2 + 6), "DOJO",
			HORIZONTAL_ALIGNMENT_CENTER, dojo_rect.size.x, 16, Color.WHITE)
	draw_rect(_door_local(), DOOR)
