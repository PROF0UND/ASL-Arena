@tool
extends "res://scenes/zones/MapZone.gd"
## The arena screen: a painted MapZone plus where fighters start and where sign drops appear.
## Like other screens, the node position is the image's top-left corner and walk_rect is the fighting area.


func _ready() -> void:
	super()
	add_to_group("arena")


func center() -> Vector2:
	return global_position + walk_rect.get_center()


## Counts as "in the arena" for the guard countdown.
func is_inside(p: Vector2) -> bool:
	return contains_point(p)


## Where each player stands when the fight starts: P1 on the north side, P2 on the south.
func start_point(slot: int) -> Vector2:
	return center() + Vector2(0, -1 if slot == 1 else 1) * walk_rect.size.y * 0.25


## A random spot well inside the fighting area.
func random_drop_point() -> Vector2:
	var area := walk_rect.grow(-24)
	return global_position + area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
