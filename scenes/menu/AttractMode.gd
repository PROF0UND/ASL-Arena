extends Node2D
## Title-screen background: the arena, with wizards in every robe color running around and dueling,
## and the crazy goose chasing whichever wizard it has its eye on.
## Purely decorative: nothing here touches GameState or the network.

const Robe := preload("res://scenes/actors/robe.gd")
const FRAMES := preload("res://assets/characters/wizard_frames.tres")
const GOOSE_FRAMES := preload("res://assets/characters/goose_frames.tres")
const FIREBALL_SCENE := preload("res://scenes/arena/Fireball.tscn")
const ARENA_TEXTURE := preload("res://assets/arena/arena.png")

const COLORS := [Robe.BLUE, Robe.RED, Robe.GREEN, Robe.PURPLE, Robe.ORANGE, Robe.TEAL]
const VIEW_OFFSET := Vector2(0, -30)     # show the middle 180 rows of the 240-tall arena
const FIELD := Rect2(36, 102, 248, 40)   # where wizards roam: feet low enough that hats clear the ribbon
const SPEED := 45.0
const BODY := Vector2(0, -14)
const TIERS := ["weak", "medium", "medium", "strong"]
const GOOSE_SPEED := 70.0                  # faster than the wizards, so it always catches someone
const GOOSE_TURN := 200.0
const GOOSE_FIELD := Rect2(12, 98, 296, 46)  # a bit looser than the wizards' area
const GOOSE_PAUSE := 0.6                   # flapping victory pause after each honk

var _wizards: Array = []    # each: {sprite, target, wait, casting}
var _fireballs: Array = []  # each: {node, shooter}
var _shake := 0.0
var _goose: AnimatedSprite2D
var _goose_target: Dictionary = {}
var _goose_velocity := Vector2.ZERO
var _goose_pause := 0.0

@onready var _actors: Node2D = $Actors


func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = ARENA_TEXTURE
	background.centered = false
	background.position = VIEW_OFFSET
	add_child(background)
	move_child(background, 0)
	for hue in COLORS:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = FRAMES
		sprite.offset = Vector2(0, -14)
		sprite.material = Robe.make(hue)
		sprite.position = _random_point()
		_actors.add_child(sprite)
		var wizard := {"sprite": sprite, "target": _random_point(), "wait": randf_range(0.0, 1.5), "casting": false}
		sprite.animation_finished.connect(func(): wizard.casting = false)
		_wizards.append(wizard)
	_goose = AnimatedSprite2D.new()
	_goose.sprite_frames = GOOSE_FRAMES
	_goose.offset = Vector2(0, -13)  # feet on the ground, so it y-sorts with the wizards
	_goose.position = Vector2(GOOSE_FIELD.end.x - 10, GOOSE_FIELD.get_center().y)
	_goose.play(&"default")
	_actors.add_child(_goose)
	_goose_target = _wizards.pick_random()


func _process(delta: float) -> void:
	for wizard in _wizards:
		_update_wizard(wizard, delta)
	_update_fireballs()
	_update_goose(delta)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 10.0, 0.0)
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	else:
		position = Vector2.ZERO


func _update_wizard(wizard: Dictionary, delta: float) -> void:
	var sprite: AnimatedSprite2D = wizard.sprite
	if wizard.casting:
		return
	if wizard.wait > 0.0:
		wizard.wait -= delta
		sprite.play(&"idle")
		return
	var to: Vector2 = wizard.target - sprite.position
	if to.length() < 2.0:
		wizard.target = _random_point()
		if randf() < 0.6:
			_cast(wizard)
		else:
			wizard.wait = randf_range(0.3, 1.2)
		return
	var step := to.normalized() * SPEED * delta
	sprite.position += step if step.length() < to.length() else to
	if absf(step.x) > 0.01:
		sprite.flip_h = step.x < 0.0
	sprite.play(&"run")


func _cast(wizard: Dictionary) -> void:
	var sprite: AnimatedSprite2D = wizard.sprite
	var foe: AnimatedSprite2D = _wizards.filter(func(w): return w.sprite != sprite).pick_random().sprite
	sprite.flip_h = foe.position.x < sprite.position.x
	wizard.casting = true
	sprite.play(&"cast")
	await get_tree().create_timer(Config.CAST_RELEASE_TIME).timeout
	if not is_inside_tree():
		return
	var from := sprite.position + BODY
	var fireball = FIREBALL_SCENE.instantiate()
	fireball.setup(0, 0, (foe.position + BODY - from).normalized(), TIERS.pick_random())
	fireball.position = from
	_actors.add_child(fireball)
	_fireballs.append({"node": fireball, "shooter": sprite})


func _update_fireballs() -> void:
	for shot in _fireballs.duplicate():
		var fireball = shot.node
		if not is_instance_valid(fireball):
			_fireballs.erase(shot)
			continue
		for wizard in _wizards:
			var sprite: AnimatedSprite2D = wizard.sprite
			if sprite == shot.shooter:
				continue
			if fireball.position.distance_to(sprite.position + BODY) < fireball.radius + 6.0:
				create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25).from(Color(4, 4, 4))
				_shake = maxf(_shake, Config.FIREBALL_TIERS[fireball.tier].shake * 0.6)
				fireball.queue_free()
				_fireballs.erase(shot)
				break


func _update_goose(delta: float) -> void:
	if _goose_pause > 0.0:
		_goose_pause -= delta
		if _goose_pause <= 0.0:
			_goose.play(&"default")
		return
	var target: AnimatedSprite2D = _goose_target.sprite
	var desired := (target.position - _goose.position).normalized() * GOOSE_SPEED
	_goose_velocity = _goose_velocity.move_toward(desired, GOOSE_TURN * delta)
	_goose.position = (_goose.position + _goose_velocity * delta).clamp(GOOSE_FIELD.position, GOOSE_FIELD.end)
	if absf(_goose_velocity.x) > 1.0:
		_goose.flip_h = _goose_velocity.x < 0.0  # the sprite faces right
	if _goose.position.distance_to(target.position) < 8.0:
		# HONK: the wizard flashes and stumbles, the goose flaps, then picks a new victim.
		create_tween().tween_property(target, "modulate", Color.WHITE, 0.25).from(Color(4, 4, 4))
		_goose_target.wait = maxf(_goose_target.wait, 0.5)
		_shake = maxf(_shake, 1.5)
		_goose_velocity = -_goose_velocity * 0.4
		_goose_pause = GOOSE_PAUSE
		_goose.stop()
		_goose.frame = 1  # the flapping, honking frame
		_goose_target = _wizards.filter(func(w): return w.sprite != target).pick_random()


func _random_point() -> Vector2:
	return FIELD.position + Vector2(randf() * FIELD.size.x, randf() * FIELD.size.y)
