extends Control
## A cream box with a hand-drawn outline that "boils": the edges wobble to a new random shape a few times a
## second, like hand-animated line boil. Children sit on top as usual.

@export var fill := Color("fbefd0")
@export var border := Color("4a2c17")
@export var border_width := 3.0
@export var boil_fps := 8.0
@export var wobble := 1.5    # how far the edges wander, in pixels
@export var segment := 14.0  # distance between wobble points along the edge

var _t := 0.0


func _process(delta: float) -> void:
	var step_before := int(_t * boil_fps)
	_t += delta
	if int(_t * boil_fps) != step_before:
		queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_t * boil_fps) * 7919 + 1  # same shape for the whole frame of the boil
	var outline := _wobbly_outline(rng)
	var shadow := PackedVector2Array()
	for p in outline:
		shadow.append(p + Vector2(0, 4))
	draw_colored_polygon(shadow, Color(0.12, 0.07, 0.03, 0.45))
	draw_colored_polygon(outline, fill)
	var closed := outline.duplicate()
	closed.append(outline[0])
	draw_polyline(closed, border, border_width)
	# A thin second line just inside, like a quick pencil re-trace.
	var inner := _wobbly_outline(rng, 5.0)
	inner.append(inner[0])
	draw_polyline(inner, Color(border, 0.35), 1.0)


func _wobbly_outline(rng: RandomNumberGenerator, inset := 0.0) -> PackedVector2Array:
	var r := Rect2(Vector2.ZERO, size).grow(-inset)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var points := PackedVector2Array()
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var steps := maxi(1, int(a.distance_to(b) / segment))
		for i in steps:
			var p := a.lerp(b, float(i) / steps)
			points.append((p + Vector2(rng.randf_range(-wobble, wobble), rng.randf_range(-wobble, wobble))).round())
	return points
