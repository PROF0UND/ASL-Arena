extends Node
## Match state shared by both peers. The host decides; everyone receives the result by RPC.
## Any peer can *request* a change (learn a letter, report reaching the arena) through the public helpers.

enum Phase { HOME, WAITING, FIGHT, OVER }

signal phase_changed(phase: int)
signal hp_changed(slot: int, hp: int)
signal learned_changed(slot: int, letters: Array)
signal countdown_started(late_slot: int, seconds: float)
signal escort_started(slot: int)
signal match_over(winner_slot: int)

var mode := "online"  # "online" or "quick"
var phase: int = Phase.HOME
var hp := {1: Config.MAX_HP, 2: Config.MAX_HP}
var learned := {1: [], 2: []}
var late_slot := 0      # who the guards are coming for
var countdown := 0.0    # seconds until the guards go; ticks on every peer

var _in_arena := {1: false, 2: false}  # host only
var _escort_sent := false               # host only


func reset(p_mode: String) -> void:
	mode = p_mode
	phase = Phase.HOME
	hp = {1: Config.MAX_HP, 2: Config.MAX_HP}
	learned = {1: [], 2: []}
	late_slot = 0
	countdown = 0.0
	_in_arena = {1: false, 2: false}
	_escort_sent = false


func _process(delta: float) -> void:
	if phase != Phase.WAITING or countdown <= 0.0:
		return
	countdown = maxf(countdown - delta, 0.0)
	if countdown == 0.0 and multiplayer.is_server() and not _escort_sent:
		_escort_sent = true
		_start_escort.rpc(late_slot)


# --- Requests (safe to call from any peer) ---

func learn_letter(slot: int, letter: String) -> void:
	if multiplayer.is_server():
		_add_learned(slot, letter)
	else:
		_add_learned.rpc_id(1, slot, letter)


func report_in_arena(slot: int) -> void:
	if multiplayer.is_server():
		_arrived(slot)
	else:
		_arrived.rpc_id(1, slot)


# --- Host only ---

func start_fight() -> void:
	_in_arena = {1: true, 2: true}
	_set_phase.rpc(Phase.FIGHT)
	print("[GameState] Fight!")


func damage(slot: int, amount: int) -> void:
	if not multiplayer.is_server() or phase != Phase.FIGHT:
		return
	var new_hp := maxi(hp[slot] - amount, 0)
	_set_hp.rpc(slot, new_hp)
	if new_hp == 0:
		_end_match.rpc(3 - slot)


func send_full_state_to(peer_id: int) -> void:
	for slot in [1, 2]:
		_sync_learned.rpc_id(peer_id, slot, learned[slot])
		_set_hp.rpc_id(peer_id, slot, hp[slot])
	_set_phase.rpc_id(peer_id, phase)


# --- RPCs ---

@rpc("any_peer", "reliable")
func _add_learned(slot: int, letter: String) -> void:
	if not multiplayer.is_server() or letter in learned[slot]:
		return
	var letters: Array = learned[slot].duplicate()
	letters.append(letter)
	_sync_learned.rpc(slot, letters)


@rpc("any_peer", "reliable")
func _arrived(slot: int) -> void:
	if not multiplayer.is_server() or _in_arena[slot] or phase >= Phase.FIGHT:
		return
	_in_arena[slot] = true
	if _in_arena[1] and _in_arena[2]:
		start_fight()
	elif phase == Phase.HOME:
		_start_countdown.rpc(3 - slot, Config.GUARD_WAIT_TIME)


@rpc("authority", "call_local", "reliable")
func _sync_learned(slot: int, letters: Array) -> void:
	learned[slot] = letters
	learned_changed.emit(slot, letters)


@rpc("authority", "call_local", "reliable")
func _start_countdown(p_late_slot: int, seconds: float) -> void:
	late_slot = p_late_slot
	countdown = seconds
	phase = Phase.WAITING
	phase_changed.emit(phase)
	countdown_started.emit(late_slot, seconds)


@rpc("authority", "call_local", "reliable")
func _start_escort(slot: int) -> void:
	escort_started.emit(slot)


@rpc("authority", "call_local", "reliable")
func _set_phase(new_phase: int) -> void:
	phase = new_phase
	phase_changed.emit(phase)


@rpc("authority", "call_local", "reliable")
func _set_hp(slot: int, value: int) -> void:
	hp[slot] = value
	hp_changed.emit(slot, value)


@rpc("authority", "call_local", "reliable")
func _end_match(winner_slot: int) -> void:
	phase = Phase.OVER
	phase_changed.emit(phase)
	match_over.emit(winner_slot)
	print("[GameState] P%d wins" % winner_slot)
