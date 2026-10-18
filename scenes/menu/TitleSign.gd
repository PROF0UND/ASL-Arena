extends Control
## The title logo: a two-plank wooden sign hanging on ropes, with the game name painted in gold.
## Drawn at the world's pixel scale (320x180, shown at 2x) so it matches the art.

const WOOD_DARK := Color("4a2c17")
const WOOD := Color("8a5530")
const WOOD_LIGHT := Color("a8713c")
const WOOD_HI := Color("c98f52")
const ROPE := Color("d9c08a")
const GOLD := Color("ffd35c")
const GOLD_SHADOW := Color("b86e1c")
const CREAM := Color("fdf2d0")

const SIGN := Rect2(64, 14, 192, 46)
const TITLE := "ASL ARENA"
const TAGLINE := "Sign. Cast. Duel."

var _font: Font
var _t := 0.0


func _ready() -> void:
	size = Vector2(320, 180)
	scale = Vector2(2, 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# The sign bobs one pixel, like it's swaying on its ropes.
	var bob := Vector2(0, 1 if fmod(_t, 2.4) > 1.2 else 0)
	var sign := Rect2(SIGN.position + bob, SIGN.size)

	for x in [sign.position.x + 22, sign.end.x - 22]:
		draw_line(Vector2(x, 0), Vector2(x, sign.position.y + 3), ROPE, 2.0)

	draw_rect(Rect2(sign.position + Vector2(2, 3), sign.size), Color(0, 0, 0, 0.35))  # drop shadow
	var half := sign.size.y / 2.0
	for i in 2:
		var plank := Rect2(sign.position.x, sign.position.y + i * half, sign.size.x, half)
		draw_rect(plank, WOOD_DARK)
		var inner := plank.grow(-2)
		draw_rect(inner, WOOD)
		draw_line(inner.position, Vector2(inner.end.x, inner.position.y), WOOD_HI, 1.0)
		for gy in [inner.position.y + 6, inner.position.y + 13]:  # wood grain
			draw_line(Vector2(inner.position.x + 8 + i * 30, gy), Vector2(inner.end.x - 40 + i * 20, gy), WOOD_LIGHT, 1.0)
		for nx in [inner.position.x + 4, inner.end.x - 5]:  # nails
			draw_rect(Rect2(nx, inner.position.y + half / 2.0 - 3, 2, 2), WOOD_DARK)

	var title_size := 24
	var w := _font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var baseline := sign.get_center().y + (_font.get_ascent(title_size) - _font.get_descent(title_size)) / 2.0
	var pos := Vector2(round(sign.get_center().x - w / 2.0), round(baseline))
	draw_string_outline(_font, pos + Vector2(0, 2), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 4, WOOD_DARK)
	draw_string(_font, pos + Vector2(0, 2), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, GOLD_SHADOW)
	draw_string_outline(_font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 4, WOOD_DARK)
	draw_string(_font, pos, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, GOLD)

	# Ribbon with the tagline under the sign.
	var tag_w := _font.get_string_size(TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 14
	var ribbon := Rect2(round(sign.get_center().x - tag_w / 2.0), sign.end.y + 3, tag_w, 10)
	draw_rect(ribbon, WOOD_DARK)
	draw_rect(ribbon.grow(-1), Color("7a1f1f"))
	draw_string(_font, Vector2(ribbon.position.x + 7, ribbon.end.y - 3), TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, CREAM)
