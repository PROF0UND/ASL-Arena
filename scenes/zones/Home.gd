@tool
extends Node2D
## A player's starting zone: the painted background plus the rectangles that make it playable.
## The node position is the top-left corner of the background image. All rects are in image pixels.
## Turn on `show_debug` (always on in the editor) to see the rects drawn over the art while tuning.

const DEBUG_WALK := Color(0.2, 1.0, 0.2, 0.9)
const DEBUG_BLOCK := Color(1.0, 0.2, 0.2, 0.9)
const DEBUG_DOOR := Color(1.0, 0.9, 0.2, 0.9)

@export var slot := 1
## The painted start area: a horizontal strip of animation frames (the bushes sway between them).
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_background.texture = value
## Seconds per background frame (the bushes sway between frames).
@export var frame_time := 0.5
## Where the player can stand: the painted part of the image.
@export var walk_rect := Rect2(35, 20, 250, 200):
	set(value):
		walk_rect = value
		queue_redraw()
## Things the player can't walk through: house, tree, bushes.
@export var blockers: Array[Rect2] = [
	Rect2(188, 57, 96, 84),   # house
	Rect2(150, 28, 76, 70),   # tree
	Rect2(167, 112, 22, 22),  # bush beside the house
	Rect2(35, 20, 46, 28),    # bush, top left
	Rect2(40, 157, 60, 40),   # bushes, bottom left
	Rect2(100, 172, 44, 22),  # bush, bottom middle
	Rect2(184, 196, 16, 24),  # gate pillar, left
	Rect2(246, 196, 18, 24),  # gate pillar, right
]:
	set(value):
		blockers = value
		queue_redraw()
## Standing here opens the dojo (just below the house door).
@export var door_rect := Rect2(224, 140, 20, 8):
	set(value):
		door_rect = value
		queue_redraw()
## Where this zone connects to its walkway; escorted players leave through here.
@export var exit_point := Vector2(223, 214):
	set(value):
		exit_point = value
		queue_redraw()
@export var spawn_offset := Vector2(80, 90)
@export var show_debug := false

var _anim_time := 0.0

@onready var _background: Sprite2D = $Background


func _ready() -> void:
	add_to_group("zone")
	add_to_group("home")
	if background:
		_background.texture = background


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_time += delta
	_background.frame = int(_anim_time / frame_time) % _background.hframes


## The whole background image (one frame), for camera limits.
func bounds() -> Rect2:
	var tex_size := _background.texture.get_size() if _background.texture else Vector2.ZERO
	return Rect2(global_position, Vector2(tex_size.x / _background.hframes, tex_size.y))


func door_global() -> Rect2:
	return Rect2(global_position + door_rect.position, door_rect.size)


func exit_global() -> Vector2:
	return global_position + exit_point


func spawn_point() -> Vector2:
	return global_position + spawn_offset


func contains_point(p: Vector2) -> bool:
	var local := p - global_position
	if not walk_rect.has_point(local):
		return false
	for r in blockers:
		if r.has_point(local):
			return false
	return true


func _draw() -> void:
	if not (Engine.is_editor_hint() or show_debug):
		return
	draw_rect(walk_rect, DEBUG_WALK, false, 1.0)
	for r in blockers:
		draw_rect(r, DEBUG_BLOCK, false, 1.0)
	draw_rect(door_rect, DEBUG_DOOR, false, 1.0)
	draw_circle(exit_point, 3.0, DEBUG_DOOR)
	draw_circle(spawn_offset, 3.0, DEBUG_WALK)
