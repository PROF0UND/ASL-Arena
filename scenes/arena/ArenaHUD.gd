extends CanvasLayer
## On-screen info: HP bars, status banner, camera panel, hint card, learned signs, game over.

const FLASH_TIME := 1.5
const LEARNED_HINT_TIME := 4.0

var _flash_text := ""
var _flash_timer := 0.0
var _hint_timer := 0.0  # > 0 means the hint card hides itself when this runs out

@onready var _world = get_parent()
@onready var _combat = get_parent().get_node("Combat")
@onready var _hp_bars: Control = $HPBars
@onready var _p1_bar: ProgressBar = $HPBars/P1Bar
@onready var _p2_bar: ProgressBar = $HPBars/P2Bar
@onready var _p2_label: Label = $HPBars/P2Label
@onready var _banner: Label = $Banner
@onready var _camera_panel: Panel = $CameraPanel
@onready var _hand_view = $CameraPanel/Hand
@onready var _tracker_status: Label = $CameraPanel/TrackerStatus
@onready var _hint_card: Panel = $HintCard
@onready var _hint_letter: Label = $HintCard/HintLetter
@onready var _hint_text: Label = $HintCard/HintText
@onready var _signs: Label = $Signs
@onready var _game_over: Panel = $GameOver
@onready var _result: Label = $GameOver/Result
@onready var _back_button: Button = $GameOver/BackButton


func _ready() -> void:
	_p1_bar.max_value = Config.MAX_HP
	_p2_bar.max_value = Config.MAX_HP
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.match_over.connect(_on_match_over)
	GameState.phase_changed.connect(func(phase: int):
		if phase == GameState.Phase.FIGHT:
			flash("FIGHT!"))
	GameState.escort_started.connect(func(slot: int):
		if slot == Net.local_slot():
			flash("The guards are here for you!"))
	SignInput.hand_updated.connect(_hand_view.set_landmarks)
	_combat.prompt_changed.connect(func(_l: String): _hide_hint())
	_combat.hint_requested.connect(_show_hint)
	_combat.prompt_timed_out.connect(func(l: String): flash("Too slow! %s is recharging" % l))
	_combat.fired.connect(func(_l: String, tier: String): flash("%s fireball!" % tier.capitalize()))
	_back_button.pressed.connect(Net.leave_to_menu)
	_hint_card.visible = false
	_game_over.visible = false


func _process(delta: float) -> void:
	var in_fight := GameState.phase >= GameState.Phase.FIGHT
	_hp_bars.visible = in_fight
	_camera_panel.visible = in_fight or _world.dojo_ui.visible
	_tracker_status.text = "tracker connected" if SignInput.tracker_connected else "no tracker: use keyboard"
	if not SignInput.tracker_connected:
		_hand_view.set_landmarks([], false)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		_banner.text = _flash_text
	else:
		_banner.text = _status_text()

	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hide_hint()

	_signs.text = _signs_text()


func flash(text: String) -> void:
	_flash_text = text
	_flash_timer = FLASH_TIME


func show_learned(letter: String) -> void:
	flash("New sign learned: %s!" % letter)
	_show_hint(letter)
	_hint_timer = LEARNED_HINT_TIME


func show_game_over(text: String) -> void:
	_result.text = text
	_game_over.visible = true
	_back_button.grab_focus()


func _show_hint(letter: String) -> void:
	_hint_letter.text = letter
	_hint_text.text = Config.SIGN_HINTS.get(letter, "")
	_hint_card.visible = true
	_hint_timer = 0.0


func _hide_hint() -> void:
	_hint_card.visible = false
	_hint_timer = 0.0


func _on_hp_changed(slot: int, hp: int) -> void:
	var bar := _p1_bar if slot == 1 else _p2_bar
	bar.value = hp


func _on_match_over(winner_slot: int) -> void:
	if GameState.mode == "quick":
		show_game_over("Dummy defeated!")
	elif winner_slot == Net.local_slot():
		show_game_over("You win!")
	else:
		show_game_over("You lose...")


func _status_text() -> String:
	var my_slot := Net.local_slot()
	var phase := GameState.phase
	if GameState.mode == "quick":
		_p2_label.text = "DUMMY"
	if phase == GameState.Phase.HOME:
		if multiplayer.is_server() and GameState.mode == "online" and _world.players.size() < 2:
			return "Waiting for Player 2 to join. Host IP: %s" % _local_ip()
		return "Learn signs in the dojo, then follow the stone path to the arena."
	if phase == GameState.Phase.WAITING:
		var secs := ceili(GameState.countdown)
		if GameState.countdown <= 0.0:
			return "The guards are escorting P%d to the arena..." % GameState.late_slot
		if GameState.late_slot == my_slot:
			return "Your opponent is in the arena! Guards come for you in %ds" % secs
		return "Waiting for P%d. Guards fetch them in %ds" % [GameState.late_slot, secs]
	if phase == GameState.Phase.FIGHT and _combat.current_letter == "":
		if _combat.available_letters(my_slot).is_empty():
			return "All your signs are recharging..."
		if not _combat.opponent_in_range():
			return "Get closer to your opponent to sign!"
	return ""


func _signs_text() -> String:
	var parts := []
	for letter in GameState.learned[Net.local_slot()]:
		if _combat.cooldowns.has(letter):
			parts.append("%s(%d)" % [letter, ceili(_combat.cooldowns[letter])])
		else:
			parts.append(letter)
	return "Signs: " + (" ".join(parts) if not parts.is_empty() else "none yet")


## Best guess at the LAN address to tell the other player (skips loopback and Docker bridges).
func _local_ip() -> String:
	var fallback := "127.0.0.1"
	for address in IP.get_local_addresses():
		if address.count(".") != 3 or address.begins_with("127.") or address.begins_with("172.17."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10."):
			return address
		fallback = address
	return fallback
