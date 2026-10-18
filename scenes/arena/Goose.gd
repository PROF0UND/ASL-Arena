extends Node2D
## Sometimes replaces a strong fireball: a goose that chases its target instead of flying straight.
## Same interface as Fireball.gd (id, owner_slot, tier, damage, radius) so World.gd treats them alike.
## Every peer steers it toward its own copy of the target; only the host checks hits.

var id := 0
var owner_slot := 1
var tier := "strong"
var damage := 0
var radius := 7.0

var _target: Node2D
var _velocity := Vector2.ZERO
var _life := Config.GOOSE_LIFETIME

@onready var _sprite: AnimatedSprite2D = $Sprite


func setup(p_id: int, p_owner_slot: int, dir: Vector2, p_tier: String, target: Node2D) -> void:
	id = p_id
	owner_slot = p_owner_slot
	tier = p_tier
	damage = Config.FIREBALL_TIERS[p_tier].damage
	_target = target
	_velocity = dir * Config.GOOSE_SPEED


func _process(delta: float) -> void:
	if is_instance_valid(_target):
		# Limited turning, so a sharp sidestep can still shake it off.
		var desired: Vector2 = (_target.center() - global_position).normalized() * Config.GOOSE_SPEED
		_velocity = _velocity.move_toward(desired, Config.GOOSE_TURN * delta)
	position += _velocity * delta
	if absf(_velocity.x) > 1.0:
		_sprite.flip_h = _velocity.x < 0.0  # the sprite faces right
	_life -= delta
	if _life <= 0.0:
		queue_free()
