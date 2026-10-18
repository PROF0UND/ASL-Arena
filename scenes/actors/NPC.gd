extends Node2D
## A bridge NPC: a wizard in their own robe color who turns to the local player and shares ASL advice.

const Robe := preload("res://scenes/actors/robe.gd")
const TALK_RADIUS := 32.0

## Leave empty to pick a line from Config.NPC_ADVICE based on where the NPC stands.
@export_multiline var advice := ""
## Robe hue shift (see robe.gd). Negative picks a color from Robe.NPC_COLORS based on where the NPC stands.
@export var robe_hue := -1.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _bubble: Label = $Bubble


func _ready() -> void:
	var seed_index := absi(int(global_position.x) * 31 + int(global_position.y))
	if advice == "":
		advice = Config.NPC_ADVICE[seed_index % Config.NPC_ADVICE.size()]
	_bubble.text = advice
	var hue: float = robe_hue if robe_hue >= 0.0 else Robe.NPC_COLORS[seed_index % Robe.NPC_COLORS.size()]
	_sprite.material = Robe.make(hue)
	_sprite.play(&"idle")
	_sprite.frame = seed_index % 2  # so neighbors don't breathe in sync


func _process(_delta: float) -> void:
	var me := get_tree().get_first_node_in_group("local_player") as Node2D
	var near := me != null and me.global_position.distance_to(global_position) < TALK_RADIUS
	_bubble.visible = near
	if near and absf(me.global_position.x - global_position.x) > 1.0:
		_sprite.flip_h = me.global_position.x < global_position.x
