extends CanvasLayer
## The dojo interior. Only the local player sees it; their body stays parked at the door outside.
## The board shows one hand sign at a time: hold it to learn it, then the next one appears.
## Click a finished sign in the toolbar to practice it again (clicking it a second time goes back).
## World.gd fades in and out of this screen (enter_dojo / leave_dojo).

const Robe := preload("res://scenes/actors/robe.gd")
const CELEBRATE_TIME := 0.9
const TITLE_TIME := 1.6

var _celebrating := false
var _practicing := false

@onready var _world = get_parent()
@onready var _room = $Room
@onready var _wizard: AnimatedSprite2D = $Room/Wizard


func _ready() -> void:
	visible = false
	SignInput.letter_confirmed.connect(_on_letter_confirmed)
	SignInput.letter_progress.connect(_on_letter_progress)
	_wizard.animation_finished.connect(func(): _wizard.play(&"idle"))


func open() -> void:
	visible = true
	_set_player_locked(true)
	_celebrating = false
	_practicing = false
	_room.practice = false
	_wizard.material = Robe.for_slot(Net.local_slot())
	_wizard.play(&"idle")
	_show_lesson(current_lesson())
	_room.title_alpha = 1.0
	var title := create_tween()
	title.tween_interval(TITLE_TIME)
	title.tween_property(_room, "title_alpha", 0.0, 0.4)


func close() -> void:
	if not visible:
		return
	visible = false
	SignInput.set_target("")
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_set_player_locked(false)


func current_lesson() -> String:
	for letter in Config.STARTER_LETTERS:
		if not letter in GameState.learned[Net.local_slot()]:
			return letter
	return ""


func _process(_delta: float) -> void:
	if not visible:
		return
	_room.letters = Config.STARTER_LETTERS
	_room.learned = GameState.learned[Net.local_slot()]
	_room.keyboard_hint = not SignInput.tracker_connected
	var hovered := _clickable_slot(_room.slot_at(_room.get_local_mouse_position()))
	_room.hover_slot = hovered
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hovered >= 0 else Input.CURSOR_ARROW)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_world.leave_dojo()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var slot := _clickable_slot(_room.slot_at(_room.make_canvas_position_local(event.position)))
		if slot >= 0:
			get_viewport().set_input_as_handled()
			_toggle_practice(Config.STARTER_LETTERS[slot])


## A slot can be clicked only if its sign has been learned and nothing is mid-celebration.
func _clickable_slot(slot: int) -> int:
	if slot < 0 or _celebrating:
		return -1
	return slot if Config.STARTER_LETTERS[slot] in GameState.learned[Net.local_slot()] else -1


func _toggle_practice(letter: String) -> void:
	if _practicing and letter == _room.lesson:
		_end_practice()  # clicked the sign being practiced: back to the lesson
		return
	_practicing = true
	_room.practice = true
	_show_lesson(letter)


func _end_practice() -> void:
	_practicing = false
	_room.practice = false
	_show_lesson(current_lesson())


func _on_letter_confirmed(letter: String, _quality: float) -> void:
	if not visible or _celebrating or letter != _room.lesson or letter == "":
		return
	if not _practicing:
		GameState.learn_letter(Net.local_slot(), letter)
	_celebrating = true
	_room.progress = 1.0
	_wizard.play(&"cast")
	var tween := create_tween()
	tween.tween_property(_room, "celebrate", 1.0, CELEBRATE_TIME).from(0.001)
	tween.tween_callback(func():
		_room.celebrate = 0.0
		_celebrating = false
		if _practicing:
			_end_practice()
		else:
			_show_lesson(current_lesson()))


func _on_letter_progress(letter: String, progress: float) -> void:
	if visible and not _celebrating:
		_room.progress = progress if letter == _room.lesson else 0.0


## Put a letter on the board and fade its hand sign in.
func _show_lesson(letter: String) -> void:
	_room.lesson = letter
	SignInput.set_target(letter)
	_room.sign_texture = Config.sign_texture(letter) if letter != "" else null
	_room.progress = 0.0
	_room.board_alpha = 0.0
	create_tween().tween_property(_room, "board_alpha", 1.0, 0.25)


func _set_player_locked(locked: bool) -> void:
	var me = _world.local_player()
	if me:
		me.input_locked = locked
