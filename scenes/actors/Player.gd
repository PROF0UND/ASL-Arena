extends Node2D
## A player, or the Quick Duel dummy: the wizard sprite with its feet at the node origin.
## The controlling peer moves it and streams its position; the other peer interpolates.

const BODY_CENTER := Vector2(0, -14)
const PROGRESS_RING_CENTER := Vector2(0, -46)
const Robe := preload("res://scenes/actors/robe.gd")
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

var _remote_target := Vector2.ZERO
var _send_timer := 0.0
var _reported_in_arena := false
var _last_position := Vector2.ZERO
var _casting := false  # the cast animation plays out before run/idle take over again

@onready var _sprite: AnimatedSprite2D = $Sprite
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
	if slot == 2:
		_sprite.material = Robe.for_slot(slot)  # P2 wears red
	_sprite.animation_finished.connect(func(): _casting = false)
	add_to_group("players")
	if is_local():
		add_to_group("local_player")
		_camera.enabled = true
		_camera.make_current()
		_update_camera_limits()


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

	# Holding Space is the keyboard signing stance (Space + letter), so feet stay planted.
	if not input_locked and GameState.phase != GameState.Phase.OVER and not SignInput.keyboard_signing():
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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


# --- Changing screens ---

## Jump straight to `pos` (used by portals and the guard escort). The other peer snaps too
## instead of sliding across the gap between screens.
func teleport(pos: Vector2) -> void:
	_snap_to(pos)
	_update_camera_limits()
	if _world().players.size() == 2:
		_teleported.rpc(pos)


@rpc("authority", "call_remote", "reliable")
func _teleported(pos: Vector2) -> void:
	_snap_to(pos)


func _snap_to(pos: Vector2) -> void:
	global_position = pos
	_remote_target = pos
	_last_position = pos


## Keep the camera inside whichever screen the player is on.
func _update_camera_limits() -> void:
	var zone = _world().zone_at(global_position)
	if zone == null:
		return
	var b: Rect2 = zone.bounds()
	_camera.limit_left = int(b.position.x)
	_camera.limit_top = int(b.position.y)
	_camera.limit_right = int(b.end.x)
	_camera.limit_bottom = int(b.end.y)
	_camera.reset_smoothing()


# --- Visuals ---

## Animation follows actual movement, so it works the same for local and remote players.
## Runs on physics frames because that's when positions change.
func _update_animation(delta: float) -> void:
	var moved := global_position - _last_position
	_last_position = global_position
	if delta <= 0.0 or _casting:
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


## Play the casting animation facing the opponent. Sent by the owner so both screens see it.
@rpc("authority", "call_local", "reliable")
func cast() -> void:
	var foe = _world().opponent_of(slot)
	if foe and absf(foe.global_position.x - global_position.x) > 1.0:
		_sprite.flip_h = foe.global_position.x < global_position.x
	_casting = true
	_sprite.play(&"cast")


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
