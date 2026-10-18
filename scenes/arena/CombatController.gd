extends Node
## The local player's sign loop during a fight: when the opponent is close, show a random learned
## letter that isn't on cooldown, wait for the sign, show the hint card after a while, then time out.

signal prompt_changed(letter: String)
signal hint_requested(letter: String)
signal prompt_timed_out(letter: String)
signal fired(letter: String, tier: String)

var current_letter := ""
var cooldowns := {}  # letter -> seconds left

var _prompt_time := 0.0
var _gap := 0.0
var _hint_shown := false

@onready var _world = get_parent()


func _ready() -> void:
	SignInput.letter_confirmed.connect(_on_letter_confirmed)
	SignInput.letter_progress.connect(_on_letter_progress)


func _process(delta: float) -> void:
	for letter in cooldowns.keys():
		cooldowns[letter] -= delta
		if cooldowns[letter] <= 0.0:
			cooldowns.erase(letter)

	var me = _world.local_player()
	if me == null or GameState.phase != GameState.Phase.FIGHT:
		if current_letter != "":
			_clear_prompt(me)
		return

	if current_letter == "":
		_gap -= delta
		if _gap <= 0.0 and opponent_in_range():
			_pick_letter(me)
		return

	_prompt_time += delta
	if not _hint_shown and _prompt_time >= Config.HINT_DELAY:
		_hint_shown = true
		hint_requested.emit(current_letter)
	if _prompt_time >= Config.PROMPT_TIMEOUT:
		var letter := current_letter
		cooldowns[letter] = Config.LETTER_COOLDOWN
		_clear_prompt(me)
		prompt_timed_out.emit(letter)


func available_letters(slot: int) -> Array:
	return GameState.learned[slot].filter(func(l): return not cooldowns.has(l))


func opponent_in_range() -> bool:
	var me = _world.local_player()
	var foe = _world.opponent_of(me.slot) if me else null
	return foe != null and me.global_position.distance_to(foe.global_position) <= Config.PROMPT_RANGE


func _pick_letter(me) -> void:
	var options := available_letters(me.slot)
	if options.is_empty():
		return
	current_letter = options.pick_random()
	_prompt_time = 0.0
	_hint_shown = false
	me.show_prompt.rpc(current_letter)
	prompt_changed.emit(current_letter)


func _clear_prompt(me) -> void:
	current_letter = ""
	_gap = Config.PROMPT_GAP
	_hint_shown = false
	if me:
		me.show_prompt.rpc("")
	prompt_changed.emit("")


func _on_letter_confirmed(letter: String, quality: float) -> void:
	if current_letter == "" or letter != current_letter:
		return
	var me = _world.local_player()
	cooldowns[letter] = Config.LETTER_COOLDOWN
	fired.emit(letter, Config.tier_for(quality))
	_clear_prompt(me)
	me.cast.rpc()
	# Release the fireball on the arm-out frame of the cast animation.
	await get_tree().create_timer(Config.CAST_RELEASE_TIME).timeout
	if is_instance_valid(me):
		_world.request_fireball(me.slot, quality)


func _on_letter_progress(letter: String, progress: float) -> void:
	var me = _world.local_player()
	if me:
		me.hold_progress = progress if current_letter != "" and letter == current_letter else 0.0
