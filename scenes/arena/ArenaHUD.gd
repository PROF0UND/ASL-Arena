extends CanvasLayer
## On-screen info: HP bars, status banner, camera panel, hint card, learned signs, game over.

const FLASH_TIME := 1.5
const GOOSE_FRAMES := preload("res://assets/characters/goose_frames.tres")
const GOOSE_SPACING := 50.0  # between geese around the end-screen box
const MESSAGE_BOTTOM := 332.0  # message box sits bottom-center, clear of NPC speech bubbles
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
@onready var _message_box: PanelContainer = $MessageBox
@onready var _message: Label = $MessageBox/Message
@onready var _camera_panel: Panel = $CameraPanel
@onready var _hand_view = $CameraPanel/Hand
@onready var _tracker_status: Label = $CameraPanel/TrackerStatus
@onready var _hint_card: Panel = $HintCard
@onready var _hint_letter: Label = $HintCard/HintLetter
@onready var _hint_sprite: TextureRect = $HintCard/HintSprite
@onready var _signs: Label = $Signs
@onready var _game_over: Control = $GameOver
@onready var _game_over_box: Control = $GameOver/Box
@onready var _result: Label = $GameOver/Box/Result
@onready var _subtitle: Label = $GameOver/Box/Subtitle
@onready var _back_button: Button = $GameOver/Box/BackButton


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
	_surround_with_geese(_game_over_box)
	_game_over.visible = false


func _process(delta: float) -> void:
	var in_fight := GameState.phase >= GameState.Phase.FIGHT
	_hp_bars.visible = in_fight
	_camera_panel.visible = GameState.phase == GameState.Phase.FIGHT or _world.dojo_ui.visible  # hidden on the end screen
	_tracker_status.text = "tracker connected" if SignInput.tracker_connected else "no tracker: Space + key"
	if not SignInput.tracker_connected:
		_hand_view.set_landmarks([], false)

	var text := _status_text()
	if _flash_timer > 0.0:
		_flash_timer -= delta
		text = _flash_text

	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_hide_hint()

	_signs.text = _signs_text()
	# The dojo has its own sign toolbar and title; only keep the banner for guard warnings.
	var in_dojo: bool = _world.dojo_ui.visible
	_signs.visible = not in_dojo
	if in_dojo and GameState.phase != GameState.Phase.WAITING:
		text = ""
	_set_message(text)


func flash(text: String) -> void:
	_flash_text = text
	_flash_timer = FLASH_TIME
	_message.text = ""  # force a re-layout and a pop even if the text repeats


## Show `text` in the bottom-center message box, sized to fit; "" hides it.
func _set_message(text: String) -> void:
	_message_box.visible = text != ""
	if text == "" or text == _message.text:
		return
	_message.text = text
	var box_size := _message_box.get_combined_minimum_size()
	_message_box.size = box_size
	_message_box.position = Vector2(round((640.0 - box_size.x) / 2.0), MESSAGE_BOTTOM - box_size.y)
	_message_box.pivot_offset = box_size / 2.0
	create_tween().tween_property(_message_box, "scale", Vector2.ONE, 0.12).from(Vector2(1.08, 1.08))


func show_learned(letter: String) -> void:
	flash("New sign learned: %s!" % letter)
	_show_hint(letter)
	_hint_timer = LEARNED_HINT_TIME


## Ring a box with flapping geese (top row perched on it, a row underneath, two on each side),
## alternating which way they face and each flapping on its own beat.
func _surround_with_geese(box: Control) -> void:
	var w := box.size.x
	var h := box.size.y
	var rows: Array = [[], [], [], []]  # top, bottom, left, right: each goose's feet
	var x := 0.0
	while x <= w + 0.5:
		rows[0].append(Vector2(x, 2))       # perched on the top edge
		rows[1].append(Vector2(x, h + 52))  # standing underneath
		x += GOOSE_SPACING
	for y in [h * 0.42, h * 0.8]:
		rows[2].append(Vector2(-30, y))
		rows[3].append(Vector2(w + 30, y))
	for row in rows:
		for i in row.size():
			var goose := AnimatedSprite2D.new()
			goose.sprite_frames = GOOSE_FRAMES
			goose.scale = Vector2(2, 2)
			goose.offset = Vector2(0, -13)  # feet at the spot
			goose.position = row[i]
			goose.flip_h = i % 2 == 1        # neighbors face opposite ways
			goose.speed_scale = randf_range(0.8, 1.3)
			box.add_child(goose)
			goose.play(&"default")
			goose.frame = randi() % 2


func show_game_over(title: String, subtitle := "") -> void:
	_result.text = title
	_subtitle.text = subtitle
	_game_over.visible = true
	_back_button.grab_focus()
	create_tween().tween_property(_game_over_box, "scale", Vector2.ONE, 0.25) \
			.from(Vector2(0.6, 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx("honk", -6.0)  # the goose on the corner approves


func _show_hint(letter: String) -> void:
	_hint_letter.text = letter
	_hint_sprite.texture = Config.sign_texture(letter)
	_hint_sprite.visible = _hint_sprite.texture != null
	_hint_card.visible = true
	_hint_timer = 0.0


func _hide_hint() -> void:
	_hint_card.visible = false
	_surround_with_geese(_game_over_box)
	_hint_timer = 0.0


func _on_hp_changed(slot: int, hp: int) -> void:
	var bar := _p1_bar if slot == 1 else _p2_bar
	bar.value = hp


func _on_match_over(winner_slot: int) -> void:
	if GameState.mode == "quick":
		show_game_over("VICTORY!", "The dummy never stood a chance.")
	elif winner_slot == Net.local_slot():
		show_game_over("VICTORY!", "Your signs were too strong!")
	else:
		show_game_over("DEFEAT...", "Practice your signs in the dojo and try again!")


func _status_text() -> String:
	var my_slot := Net.local_slot()
	var phase := GameState.phase
	if GameState.mode == "quick":
		_p2_label.text = "DUMMY"
	if phase == GameState.Phase.HOME:
		if multiplayer.is_server() and GameState.mode == "online" and _world.players.size() < 2:
			return "Waiting for Player 2 to join. Host IP: %s" % _local_ip()
		return "Learn signs in the dojo, then cross the bridge to the arena."
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
