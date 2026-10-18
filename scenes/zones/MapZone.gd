@tool
extends Node2D
## One painted screen of the map (a home, a bridge, ...): an animated background plus the rectangles
## that make it playable. The node position is the image's top-left corner; all rects are in image pixels.
## Screens connect through Portal children. In the editor the rects are drawn over the art for tuning.

const DEBUG_WALK := Color(0.2, 1.0, 0.2, 0.9)
const DEBUG_BLOCK := Color(1.0, 0.2, 0.2, 0.9)
const DEBUG_DOOR := Color(1.0, 0.9, 0.2, 0.9)

## 1 or 2 if this is that player's home (it then has the dojo door); 0 for any other screen.
@export var home_slot := 0
## A horizontal strip of animation frames.
@export var background: Texture2D:
	set(value):
		background = value
		if is_node_ready():
			_background.texture = value
@export var frames := 2:
	set(value):
		frames = maxi(value, 1)
		if is_node_ready():
			_background.hframes = frames
## Seconds per background frame.
@export var frame_time := 0.5
## Where the player can stand.
@export var walk_rect := Rect2(0, 0, 320, 240):
	set(value):
		walk_rect = value
		queue_redraw()
## Things the player can't walk through.
@export var blockers: Array[Rect2] = []:
	set(value):
		blockers = value
		queue_redraw()
## Standing here opens the dojo. Leave empty on screens without one.
@export var door_rect := Rect2():
	set(value):
		door_rect = value
		queue_redraw()
@export var spawn_offset := Vector2(160, 120)
@export var show_debug := false

var _anim_time := 0.0

@onready var _background: Sprite2D = $Background


func _ready() -> void:
	add_to_group("zone")
	if home_slot > 0:
		add_to_group("home")
	_background.hframes = frames
	if background:
		_background.texture = background


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_anim_time += delta
	_background.frame = int(_anim_time / frame_time) % frames


## The whole screen (one background frame); the camera stays inside this.
func bounds() -> Rect2:
	var tex_size := background.get_size() if background else Vector2(320, 240)
	return Rect2(global_position, Vector2(tex_size.x / frames, tex_size.y))


func door_global() -> Rect2:
	return Rect2(global_position + door_rect.position, door_rect.size)


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
	if door_rect.has_area():
		draw_rect(door_rect, DEBUG_DOOR, false, 1.0)
	draw_circle(spawn_offset, 3.0, DEBUG_WALK)
