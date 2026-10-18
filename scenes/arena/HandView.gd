extends Control
## Draws the tracker's 21 hand landmarks (MediaPipe order, x/y in 0..1) as a skeleton.

const CONNECTIONS := [
	[0, 1], [1, 2], [2, 3], [3, 4],          # thumb
	[0, 5], [5, 6], [6, 7], [7, 8],          # index
	[5, 9], [9, 10], [10, 11], [11, 12],     # middle
	[9, 13], [13, 14], [14, 15], [15, 16],   # ring
	[13, 17], [0, 17], [17, 18], [18, 19], [19, 20],  # pinky + palm
]
const BONE := Color(0.6, 0.9, 1.0)
const JOINT := Color(1.0, 1.0, 1.0)

var _points: Array[Vector2] = []


func set_landmarks(landmarks: Array, hand_present: bool) -> void:
	_points.clear()
	if hand_present:
		for p in landmarks:
			if p is Array and p.size() >= 2:
				_points.append(Vector2(float(p[0]) * size.x, float(p[1]) * size.y))
	queue_redraw()


func _draw() -> void:
	if _points.size() < 21:
		return
	for c in CONNECTIONS:
		draw_line(_points[c[0]], _points[c[1]], BONE, 1.0)
	for p in _points:
		draw_circle(p, 1.5, JOINT)
