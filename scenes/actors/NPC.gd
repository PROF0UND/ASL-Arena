extends Node2D
## A walkway NPC who shows a line of ASL advice when the local player walks close.

const TALK_RADIUS := 48.0

## Leave empty to pick a line from Config.NPC_ADVICE based on where the NPC stands.
@export_multiline var advice := ""

@onready var _bubble: Label = $Bubble


func _ready() -> void:
	if advice == "":
		var index := absi(int(global_position.x) * 31 + int(global_position.y)) % Config.NPC_ADVICE.size()
		advice = Config.NPC_ADVICE[index]
	_bubble.text = advice


func _process(_delta: float) -> void:
	var me := get_tree().get_first_node_in_group("local_player") as Node2D
	_bubble.visible = me != null and me.global_position.distance_to(global_position) < TALK_RADIUS
