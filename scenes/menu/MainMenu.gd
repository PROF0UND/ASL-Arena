extends Control
## Title screen. Also reads launch flags for quick testing (pass them after `--`):
##   --quick-duel   --host   --join=<ip>   --tracker-port=<port> (read by SignInput)

const WORLD_SCENE := "res://scenes/world/World.tscn"

static var _launch_flags_used := false

@onready var _quick_button: Button = $Buttons/QuickDuel
@onready var _host_button: Button = $Buttons/Host
@onready var _address: LineEdit = $Buttons/Address
@onready var _join_button: Button = $Buttons/Join
@onready var _status: Label = $Buttons/Status


func _ready() -> void:
	_quick_button.pressed.connect(_on_quick_duel)
	_host_button.pressed.connect(_on_host)
	_join_button.pressed.connect(_on_join)
	Net.connected.connect(_on_connected)
	Net.connect_failed.connect(_on_connect_failed)
	_quick_button.grab_focus()
	if not _launch_flags_used:
		_launch_flags_used = true
		_apply_launch_flags.call_deferred()


func _apply_launch_flags() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick-duel":
			_on_quick_duel()
		elif arg == "--host":
			_on_host()
		elif arg.begins_with("--join="):
			_address.text = arg.get_slice("=", 1)
			_on_join()


func _on_quick_duel() -> void:
	Net.go_offline()
	GameState.reset("quick")
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_host() -> void:
	var err := Net.host()
	if err != OK:
		_status.text = "Could not host: %s" % error_string(err)
		return
	GameState.reset("online")
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_join() -> void:
	var address := _address.text.strip_edges()
	var err := Net.join(address if address != "" else "127.0.0.1")
	if err != OK:
		_status.text = "Could not join: %s" % error_string(err)
		return
	_status.text = "Connecting..."
	_set_buttons_disabled(true)


func _on_connected() -> void:
	GameState.reset("online")
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_connect_failed(reason: String) -> void:
	_status.text = reason
	_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	for button in [_quick_button, _host_button, _join_button]:
		button.disabled = disabled
