extends CanvasLayer
## The dojo lesson screen. Only the local player sees it; their body stays parked at the door.
## The sensei teaches the starter letters in order: hold the shown sign to learn it.

@onready var _world = get_parent()
@onready var _speech: Label = $Panel/Speech
@onready var _letter: Label = $Panel/Letter
@onready var _hold_bar: ProgressBar = $Panel/HoldBar
@onready var _learned: Label = $Panel/Learned
@onready var _leave_button: Button = $Panel/LeaveButton


func _ready() -> void:
	visible = false
	SignInput.letter_confirmed.connect(_on_letter_confirmed)
	SignInput.letter_progress.connect(_on_letter_progress)
	GameState.learned_changed.connect(func(_slot: int, _letters: Array): _refresh())
	_leave_button.pressed.connect(close)


func open() -> void:
	visible = true
	_set_player_locked(true)
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	_set_player_locked(false)


func current_lesson() -> String:
	for letter in Config.STARTER_LETTERS:
		if not letter in GameState.learned[Net.local_slot()]:
			return letter
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_letter_confirmed(letter: String, _quality: float) -> void:
	if visible and letter == current_lesson():
		GameState.learn_letter(Net.local_slot(), letter)


func _on_letter_progress(letter: String, progress: float) -> void:
	if visible:
		_hold_bar.value = progress if letter == current_lesson() else 0.0


func _refresh() -> void:
	if not is_node_ready():
		return
	var lesson := current_lesson()
	if lesson == "":
		_letter.text = ":)"
		_speech.text = "You have learned every sign I know. Go to the arena and show them!"
	else:
		_letter.text = lesson
		_speech.text = "This is the letter %s. %s Hold it steady!" % [lesson, Config.SIGN_HINTS[lesson]]
	var learned: Array = GameState.learned[Net.local_slot()]
	_learned.text = "Signs learned: " + (" ".join(learned) if not learned.is_empty() else "none yet")


func _set_player_locked(locked: bool) -> void:
	var me = _world.local_player()
	if me:
		me.input_locked = locked
