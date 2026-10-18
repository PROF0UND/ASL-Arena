extends Node2D
## A player, or the Quick Duel dummy: the wizard sprite with its feet at the node origin.
## The controlling peer moves it and streams its position; the other peer interpolates.

const BODY_CENTER := Vector2(0, -14)
const PROGRESS_RING_CENTER := Vector2(0, -46)
const HUE_SWAP := preload("res://assets/shaders/hue_swap.gdshader")
const P2_HUE_SHIFT := 0.37  # blue robe -> red robe
const RUN_SPEED_THRESHOLD := 5.0  # px/s; slower than this counts as standing

var slot := 1
var peer_id := 1
var is_dummy := false
var input_locked := false
var hold_progress := 0.0:
	set(value):
		if value != hold_progress:
			hold_progress = value
			queue_redraw()

var _escort_path: Array[Vector2] = []
var _remote_target := Vector2.ZERO
var _send_timer := 0.0
var _reported_in_arena := false
var _last_position := Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _name_label: Label = $Name
@onready var _prompt: Label = $Prompt
@onready var _camera: Camera2D = $Camera2D


## Call before adding to the tree. Names match on every peer so RPCs line up.
func setup(p_slot: int, p_peer: int, dummy := false) -> void:
	slot = p_slot
	peer_id = p_peer
	is_dummy = dummy
	name = "Dummy" if dummy else "Player%d" % p_peer
	set_multiplayer_authority(p_peer)


func _ready() -> void:
	_remote_target = position
	_last_position = position
	_name_label.text = "DUMMY" if is_dummy else "P%d" % slot
	if slot == 2:
		var mat := ShaderMaterial.new()
		mat.shader = HUE_SWAP
		mat.set_shader_parameter("hue_shift", P2_HUE_SHIFT)
		_sprite.material = mat
	add_to_group("players")
	if is_local():
		add_to_group("local_player")
		_camera.enabled = true
		_camera.make_current()
		var limits: Rect2 = _world().map_bounds()
		_camera.limit_left = int(limits.position.x)
		_camera.limit_top = int(limits.position.y)
		_camera.limit_right = int(limits.end.x)
		_camera.limit_bottom = int(limits.end.y)


func is_local() -> bool:
	return not is_dummy and peer_id == multiplayer.get_unique_id()


func center() -> Vector2:
	return global_position + BODY_CENTER


func _physics_process(delta: float) -> void:
	if not is_local():
		if not is_dummy:
			position = position.lerp(_remote_target, 1.0 - exp(-15.0 * delta))
		_update_animation(delta)
		return

	if not _escort_path.is_empty():
		_follow_escort(delta)
	elif not input_locked and GameState.phase != GameState.Phase.OVER:
		var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		_move(dir * Config.PLAYER_SPEED * delta)

	_update_animation(delta)
	_check_arena()
	_frame_fight()
	_send_timer -= delta
	# Wait until both players exist, or the other peer gets RPCs for a node it hasn't spawned yet.
	if _send_timer <= 0.0 and _world().players.size() == 2:
		_send_timer = 1.0 / Config.POSITION_SEND_RATE
		_sync_position.rpc(position)


## Axis-separated so the player slides along zone edges instead of sticking.
func _move(step: Vector2) -> void:
	var world = _world()
	var candidate := global_position + Vector2(step.x, 0)
	if world.is_walkable(candidate):
		global_position = candidate
	candidate = global_position + Vector2(0, step.y)
	if world.is_walkable(candidate):
		global_position = candidate


func _check_arena() -> void:
	var world = _world()
	if _reported_in_arena or world.players.size() < 2:
		return
	if world.arena.is_inside(global_position):
		_reported_in_arena = true
		GameState.report_in_arena(slot)


## During a fight, aim the camera halfway to the opponent so both fighters stay on screen.
func _frame_fight() -> void:
	var foe = _world().opponent_of(slot)
	if GameState.phase >= GameState.Phase.FIGHT and foe:
		# Nudged up a little so the letter over the top player's head isn't cut off.
		_camera.position = (foe.global_position - global_position) / 2.0 + Vector2(0, -16)
	else:
		_camera.position = Vector2.ZERO


# --- Escort (guards walking a late player to the arena) ---

func start_escort(path: Array[Vector2]) -> void:
	_escort_path = path.duplicate()
	input_locked = true


func _follow_escort(delta: float) -> void:
	var target := _escort_path[0]
	global_position = global_position.move_toward(target, Config.ESCORT_SPEED * delta)
	if global_position.distance_to(target) < 1.0:
		_escort_path.remove_at(0)
		if _escort_path.is_empty():
			input_locked = false


# --- Visuals ---

## Animation follows actual movement, so it works the same for local and remote players.
## Runs on physics frames because that's when positions change.
func _update_animation(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	if delta <= 0.0:
		return
	if moved.length() / delta > RUN_SPEED_THRESHOLD:
		_sprite.play(&"run")
		if absf(moved.x) > 0.01:
			_sprite.flip_h = moved.x < 0.0  # only turn on horizontal movement, Among Us style
	else:
		_sprite.play(&"idle")


## Letter over the player's head. Sent by the owner so the opponent sees it too.
@rpc("authority", "call_local", "reliable")
func show_prompt(letter: String) -> void:
	_prompt.text = letter
	_prompt.visible = letter != ""
	hold_progress = 0.0


func flash() -> void:
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25).from(Color(4, 4, 4))


func _draw() -> void:
	if hold_progress > 0.0 and _prompt.visible:
		draw_arc(PROGRESS_RING_CENTER, 8.0, -PI / 2, -PI / 2 + TAU * hold_progress, 32, Color.WHITE, 1.0)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_position(p: Vector2) -> void:
	_remote_target = p


func _world() -> Node:
	return get_tree().get_first_node_in_group("world")
