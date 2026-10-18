extends Node
## Background music (loops through every screen, never restarts between scenes) and one-shot sound effects.
## Looping is set in music/game_background_music.mp3.import (Import dock: Loop).

const MUSIC := preload("res://music/game_background_music.mp3")
const SFX := {
	"fireball_small": preload("res://music/small_fireball.mp3"),
	"fireball_heavy": preload("res://music/Heavy_fireball.mp3"),
	"honk": preload("res://music/honk-sound.mp3"),
}
## Sounds with long tails get faded out after this many seconds.
const SFX_MAX_LENGTH := {"fireball_small": 1.0}
const MUSIC_VOLUME_DB := -10.0
const SFX_VOLUME_DB := -4.0
const VOICES := 8  # sound effects that can overlap

var _music := AudioStreamPlayer.new()
var _voices: Array[AudioStreamPlayer] = []
var _fades: Array = []  # one fade-out tween (or null) per voice
var _next_voice := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.stream = MUSIC
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
		_fades.append(null)


## Play a sound effect from SFX. `volume_db` is added to the default effect volume.
func play_sfx(sound: String, volume_db := 0.0) -> void:
	var i := _next_voice
	_next_voice = (_next_voice + 1) % VOICES
	var voice := _voices[i]
	if _fades[i]:
		_fades[i].kill()
		_fades[i] = null
	voice.stream = SFX[sound]
	voice.volume_db = SFX_VOLUME_DB + volume_db
	voice.play()
	if SFX_MAX_LENGTH.has(sound):
		var fade := create_tween()
		fade.tween_interval(maxf(SFX_MAX_LENGTH[sound] - 0.25, 0.0))
		fade.tween_property(voice, "volume_db", -40.0, 0.25)
		fade.tween_callback(voice.stop)
		_fades[i] = fade
