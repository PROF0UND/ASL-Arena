extends Node2D
## Owns the map and everyone in it. Spawns players, starts escorts, and on the host
## runs arena authority: fireball spawns, hits, and sign drops.
## The map is separate screens (zones under Zones in World.tscn) spaced apart in one scene;
## Portals move the local player between them with a fade.

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const GUARD_SCENE := preload("res://scenes/actors/Guard.tscn")
const FIREBALL_SCENE := preload("res://scenes/arena/Fireball.tscn")
const DROP_SCENE := preload("res://scenes/arena/SignDrop.tscn")
const GUARD_OFFSETS := [Vector2(-20, 0), Vector2(20, 0)]
const FADE_TIME := 0.2

var players := {}    # slot -> Player
var fireballs := {}  # id -> Fireball
var drops := {}      # id -> SignDrop

var _next_id := 0
var _drop_timer := Config.DROP_INTERVAL
var _was_at_door := false
var _was_in_portal := false
var _traveling := false
var _fade: ColorRect

@onready var arena = $Zones/Arena
@onready var hud = $HUD
@onready var dojo_ui = $DojoUI
@onready var combat = $Combat
@onready var _players_root: Node2D = $Players
@onready var _guards_root: Node2D = $Guards
@onready var _fireballs_root: Node2D = $Fireballs
@onready var _drops_root: Node2D = $Drops


func _ready() -> void:
	add_to_group("world")
	_build_fade()
	Net.opponent_left.connect(_on_opponent_left)
	GameState.escort_started.connect(_on_escort_started)
	if GameState.mode == "quick":
		_setup_quick_duel()
	elif multiplayer.is_server():
		_spawn_player(1, 1, get_home(1).spawn_point())
	else:
		_client_ready.rpc_id(1)


func _process(delta: float) -> void:
	var me = local_player()
	if me:
		_check_portals(me)
		_check_dojo_door(me)
		_check_drop_pickup(me)
	if multiplayer.is_server():
		_host_process(delta)


# --- Lookups ---

func local_player():
	return players.get(Net.local_slot())


func opponent_of(slot: int):
	return players.get(3 - slot)


func get_home(slot: int):
	for home in get_tree().get_nodes_in_group("home"):
		if home.home_slot == slot:
			return home
	return null


## The screen containing `p` (the camera stays inside it), or null.
func zone_at(p: Vector2):
	for zone in get_tree().get_nodes_in_group("zone"):
		if zone.bounds().has_point(p):
			return zone
	return null


func is_walkable(p: Vector2) -> bool:
	if GameState.phase >= GameState.Phase.FIGHT:
		return arena.contains_point(p)  # nobody leaves once the fight starts
	for zone in get_tree().get_nodes_in_group("zone"):
		if zone.contains_point(p):
			return true
	return false


# --- Spawning ---

func _setup_quick_duel() -> void:
	_spawn_player(1, 1, arena.start_point(1))
	var dummy = PLAYER_SCENE.instantiate()
	dummy.setup(2, 1, true)
	dummy.position = arena.start_point(2)
	_players_root.add_child(dummy)
	players[2] = dummy
	for letter in Config.QUICK_DUEL_LETTERS:
		GameState.learn_letter(1, letter)
	GameState.start_fight()


@rpc("any_peer", "reliable")
func _client_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_spawn_player.rpc_id(id, 1, 1, players[1].global_position)
	_spawn_player.rpc(id, 2, get_home(2).spawn_point())
	GameState.send_full_state_to(id)


@rpc("authority", "call_local", "reliable")
func _spawn_player(peer: int, slot: int, pos: Vector2) -> void:
	if players.has(slot):
		return
	var p = PLAYER_SCENE.instantiate()
	p.setup(slot, peer)
	p.position = pos
	_players_root.add_child(p)
	players[slot] = p
	print("[World] Spawned P%d (peer %d)" % [slot, peer])


# --- Moving between screens ---

func _check_portals(me) -> void:
	if _traveling or GameState.phase >= GameState.Phase.FIGHT:
		return
	var portal = null
	for p in get_tree().get_nodes_in_group("portal"):
		if p.rect().has_point(me.global_position):
			portal = p
			break
	if portal and not _was_in_portal:
		travel(me, portal.target_position())
	_was_in_portal = portal != null


## Fade to black, move the local player, fade back in.
func travel(me, destination: Vector2) -> void:
	_traveling = true
	me.input_locked = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	tween.tween_callback(func(): me.teleport(destination))
	tween.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	tween.tween_callback(func():
		me.input_locked = false
		_traveling = false)


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.size = Vector2(640, 360)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


# --- Dojo ---

func _check_dojo_door(me) -> void:
	if GameState.phase >= GameState.Phase.FIGHT:
		return
	var at_door: bool = get_home(me.slot).door_global().has_point(me.global_position)
	if at_door and not _was_at_door and not dojo_ui.visible:
		dojo_ui.open()
	_was_at_door = at_door


# --- Guards ---

func _on_escort_started(slot: int) -> void:
	var target = players.get(slot)
	if target == null:
		return
	if target.is_local():
		dojo_ui.close()
	# Guards walk in from the edge of the late player's screen that faces the arena.
	var spawn_at: Vector2 = target.global_position
	var zone = zone_at(target.global_position)
	if zone:
		var b: Rect2 = zone.bounds()
		var arena_is_below: bool = b.get_center().y < arena.center().y
		spawn_at.y = b.end.y - 4.0 if arena_is_below else b.position.y + 4.0
	for offset in GUARD_OFFSETS:
		var guard = GUARD_SCENE.instantiate()
		_guards_root.add_child(guard)
		guard.global_position = spawn_at + offset
		guard.escort(target, offset)
		if target.is_local() and offset == GUARD_OFFSETS[0]:
			guard.reached_target.connect(func(): travel(target, arena.start_point(slot)))


# --- Fireballs (host decides, everyone simulates) ---

func request_fireball(slot: int, quality: float) -> void:
	if multiplayer.is_server():
		_fire(slot, quality)
	else:
		_fire.rpc_id(1, slot, quality)


@rpc("any_peer", "reliable")
func _fire(slot: int, quality: float) -> void:
	if not multiplayer.is_server() or GameState.phase != GameState.Phase.FIGHT:
		return
	var shooter = players.get(slot)
	var target = opponent_of(slot)
	if shooter == null or target == null:
		return
	var from: Vector2 = shooter.center()
	var dir: Vector2 = (target.center() - from).normalized()
	_next_id += 1
	_spawn_fireball.rpc(_next_id, slot, from, dir, Config.tier_for(quality))


@rpc("authority", "call_local", "reliable")
func _spawn_fireball(id: int, slot: int, from: Vector2, dir: Vector2, tier: String) -> void:
	var fb = FIREBALL_SCENE.instantiate()
	fb.setup(id, slot, dir, tier)
	fb.position = from
	_fireballs_root.add_child(fb)
	fireballs[id] = fb
	fb.tree_exiting.connect(func(): fireballs.erase(id))


@rpc("authority", "call_local", "reliable")
func _fireball_hit(id: int, target_slot: int) -> void:
	var fb = fireballs.get(id)
	if fb:
		fireballs.erase(id)
		fb.queue_free()
	var target = players.get(target_slot)
	if target:
		target.flash()


func _host_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.FIGHT:
		return
	for id in fireballs.keys():
		var fb = fireballs[id]
		var target = opponent_of(fb.owner_slot)
		if target and fb.global_position.distance_to(target.center()) < fb.radius + 10.0:
			_fireball_hit.rpc(id, target.slot)
			GameState.damage(target.slot, fb.damage)
	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = Config.DROP_INTERVAL
		_try_spawn_drop()


# --- Sign drops (teach a letter mid-fight) ---

func _try_spawn_drop() -> void:
	if not drops.is_empty():
		return
	var candidates := []
	for letter in Config.STARTER_LETTERS:
		if not (letter in GameState.learned[1] and letter in GameState.learned[2]):
			candidates.append(letter)
	if candidates.is_empty():
		return
	_next_id += 1
	_spawn_drop.rpc(_next_id, arena.random_drop_point(), candidates.pick_random())


@rpc("authority", "call_local", "reliable")
func _spawn_drop(id: int, pos: Vector2, letter: String) -> void:
	var drop = DROP_SCENE.instantiate()
	drop.setup(id, letter)
	drop.position = pos
	_drops_root.add_child(drop)
	drops[id] = drop


func _check_drop_pickup(me) -> void:
	if GameState.phase != GameState.Phase.FIGHT:
		return
	for id in drops:
		var drop = drops[id]
		if drop.pending or drop.letter in GameState.learned[me.slot]:
			continue
		if drop.global_position.distance_to(me.global_position) < Config.DROP_PICKUP_RADIUS:
			drop.pending = true
			if multiplayer.is_server():
				_pickup(id, me.slot)
			else:
				_pickup.rpc_id(1, id, me.slot)


@rpc("any_peer", "reliable")
func _pickup(id: int, slot: int) -> void:
	if not multiplayer.is_server() or not drops.has(id):
		return
	var letter: String = drops[id].letter
	if letter in GameState.learned[slot]:
		return
	GameState.learn_letter(slot, letter)
	_drop_taken.rpc(id, slot, letter)


@rpc("authority", "call_local", "reliable")
func _drop_taken(id: int, slot: int, letter: String) -> void:
	if drops.has(id):
		drops[id].queue_free()
		drops.erase(id)
	var picker = players.get(slot)
	if picker and picker.is_local():
		hud.show_learned(letter)


func _on_opponent_left() -> void:
	if GameState.mode == "online":
		hud.show_game_over("Opponent disconnected")
