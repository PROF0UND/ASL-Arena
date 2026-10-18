@tool
extends Node2D
## The circular arena. The node position is its center.

const FLOOR := Color(0.36, 0.62, 0.36)
const RING := Color(0.92, 0.86, 0.60)
const ENTRY_MARGIN := 24.0  # how far past the edge counts as "in the arena"

@export var radius := 220.0:
	set(value):
		radius = value
		queue_redraw()


func _ready() -> void:
	add_to_group("zone")


func contains_point(p: Vector2) -> bool:
	return p.distance_to(global_position) <= radius


## The arena's screen. At least one screen wide so the camera never shows past it sideways.
func bounds() -> Rect2:
	var half := Vector2(maxf(radius + 10.0, 160.0), radius + 10.0)
	return Rect2(global_position - half, half * 2.0)


func is_inside(p: Vector2) -> bool:
	return p.distance_to(global_position) <= radius - ENTRY_MARGIN


## Where each player stands when the fight starts: P1 on the north side, P2 on the south.
func start_point(slot: int) -> Vector2:
	return global_position + Vector2(0, -1 if slot == 1 else 1) * radius * 0.35


func random_drop_point() -> Vector2:
	var r := sqrt(randf()) * radius * 0.6
	return global_position + Vector2.from_angle(randf() * TAU) * r


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, FLOOR)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, RING, 6.0)
	draw_string(ThemeDB.fallback_font, Vector2(-radius, -radius + 40), "ARENA",
			HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 16, RING)
