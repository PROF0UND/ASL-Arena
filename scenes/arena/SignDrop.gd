extends Node2D
## An arena pickup that teaches one letter. The host spawns and removes it (World.gd).

var id := 0
var letter := ""
var pending := false  # pickup requested, waiting for the host

var _t := 0.0

@onready var _label: Label = $Letter


func setup(p_id: int, p_letter: String) -> void:
	id = p_id
	letter = p_letter


func _ready() -> void:
	_label.text = letter


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 10.0 + glow * 3.0, Color(0.5, 0.9, 1.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0, Color(0.3, 0.7, 1.0))
