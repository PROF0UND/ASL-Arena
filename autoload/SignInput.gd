extends Node
## Turns "which hand shape is being held" into game events.
## Two sources, keyboard first:
##   - Keyboard: hold a letter key to hold that sign. Shift + letter = a sloppy sign (low confidence).
##   - The Python tracker, as JSON over UDP on 127.0.0.1:4242 (see README for the packet format).
## Hold-to-confirm lives here so the dojo and the arena behave the same way.

signal letter_progress(letter: String, progress: float)  # 0..1 while a sign is held; "" when nothing is
signal letter_confirmed(letter: String, quality: float)  # quality = average confidence over the hold
signal hand_updated(landmarks: Array, hand_present: bool)

var tracker_connected := false  # true while tracker packets keep arriving
var current_letter := ""
var current_confidence := 0.0

var _udp := PacketPeerUDP.new()
var _last_packet_time := -1000.0
var _tracker_letter := ""
var _tracker_conf := 0.0

var _hold_letter := ""
var _hold_time := 0.0
var _hold_conf_sum := 0.0
var _hold_samples := 0
var _hold_fired := false


func _ready() -> void:
	var port := _port_from_args()
	var err := _udp.bind(port, "127.0.0.1")
	if err != OK:
		push_warning("SignInput: could not listen on UDP %d (%s). Keyboard input still works." % [port, error_string(err)])
	else:
		print("[SignInput] Listening for the tracker on 127.0.0.1:%d" % port)


func _process(delta: float) -> void:
	_read_tracker()
	tracker_connected = _now() - _last_packet_time < Config.TRACKER_STALE_TIME

	var letter := ""
	var conf := 0.0
	var key_letter := _held_key_letter()
	if key_letter != "":
		letter = key_letter
		var sloppy := Input.is_physical_key_pressed(KEY_SHIFT)
		conf = Config.KEYBOARD_SLOPPY_CONFIDENCE if sloppy else Config.KEYBOARD_CONFIDENCE
	elif tracker_connected and _tracker_letter != "" and _tracker_conf >= Config.MIN_CONFIDENCE:
		letter = _tracker_letter
		conf = _tracker_conf

	current_letter = letter
	current_confidence = conf
	_update_hold(letter, conf, delta)


func _update_hold(letter: String, conf: float, delta: float) -> void:
	if letter != _hold_letter:
		_hold_letter = letter
		_hold_time = 0.0
		_hold_conf_sum = 0.0
		_hold_samples = 0
		_hold_fired = false
	if letter == "":
		letter_progress.emit("", 0.0)
		return
	if _hold_fired:
		# Already counted; the hand has to change before this letter counts again.
		letter_progress.emit(letter, 0.0)
		return
	_hold_time += delta
	_hold_conf_sum += conf
	_hold_samples += 1
	letter_progress.emit(letter, minf(_hold_time / Config.HOLD_TIME, 1.0))
	if _hold_time >= Config.HOLD_TIME:
		_hold_fired = true
		letter_confirmed.emit(letter, _hold_conf_sum / _hold_samples)


func _read_tracker() -> void:
	if not _udp.is_bound():
		return
	var latest := PackedByteArray()
	while _udp.get_available_packet_count() > 0:
		latest = _udp.get_packet()  # only the newest packet matters
	if latest.is_empty():
		return
	var data = JSON.parse_string(latest.get_string_from_utf8())
	if not data is Dictionary:
		return
	_last_packet_time = _now()
	var hand_present := bool(data.get("hand_present", false))
	var letter = data.get("letter")
	_tracker_letter = String(letter).to_upper() if hand_present and letter is String else ""
	_tracker_conf = float(data.get("confidence", 0.0)) if _tracker_letter != "" else 0.0
	var landmarks = data.get("landmarks", [])
	hand_updated.emit(landmarks if landmarks is Array else [], hand_present)


func _held_key_letter() -> String:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return ""
	for i in 26:
		if Input.is_physical_key_pressed((KEY_A + i) as Key):
			return char(65 + i)
	return ""


func _port_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tracker-port="):
			return int(arg.get_slice("=", 1))
	return Config.TRACKER_PORT


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
