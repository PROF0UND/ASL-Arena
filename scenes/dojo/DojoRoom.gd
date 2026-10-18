extends Control
## Draws the dojo interior at the world's pixel scale (320x180, shown at 2x): wooden beams, shoji screens,
## a tatami floor, the lesson board with the current hand sign, and a Stardew-style toolbar of signs.
## DojoUI.gd sets the state below; this script only draws it.

const SIZE := Vector2(320, 180)

const WOOD_DARK := Color("4a2c17")
const WOOD := Color("7a4a26")
const WOOD_LIGHT := Color("a8713c")
const WOOD_HI := Color("c98f52")
const PAPER := Color("f3e8cc")
const PAPER_SHADE := Color("e6d6b0")
const GRID := Color("b38b5a")
const TATAMI := Color("c9b46e")
const TATAMI_LINE := Color(0.55, 0.47, 0.25, 0.35)
const TATAMI_BORDER := Color("3d3020")
const BOARD := Color("fbf8ee")
const SHADOW := Color(0, 0, 0, 0.2)
const GOLD := Color("f2c14e")
const INK := Color("4a2c17")
const SLOT_FILL := Color("f6dfa7")
const SLOT_EDGE := Color("9e6b34")
const BAR_FILL := Color("e8b86d")

const BOARD_RECT := Rect2(104, 40, 112, 76)
const PLAQUE_RECT := Rect2(144, 30, 32, 16)
const SLOT := 16
const SLOT_GAP := 2

# --- State (set by DojoUI) ---
var letters: Array = []        # every letter the dojo teaches, in order
var learned: Array = []        # letters this player knows
var lesson := ""               # letter on the board ("" = all learned)
var sign_texture: Texture2D    # hand-sign picture for `lesson`, or null to show the letter
var progress := 0.0            # hold progress 0..1
var celebrate := 0.0           # 0..1 while a "learned it!" burst plays
var board_alpha := 1.0         # fades the next sign in
var title_alpha := 0.0         # "The Dojo" title card
var keyboard_hint := false     # show the Space + key reminder when no tracker is connected
var practice := false          # the board is replaying an already-learned sign
var hover_slot := -1           # toolbar slot under the mouse, or -1

var _font: Font


func _ready() -> void:
	size = SIZE
	scale = Vector2(2, 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_wall()
	_draw_floor()
	_draw_board()
	_draw_toolbar()
	_draw_title()


# --- Room ---

func _draw_wall() -> void:
	# Ceiling beam and the row of small transom windows above the screens.
	draw_rect(Rect2(0, 0, 320, 8), WOOD_DARK)
	draw_line(Vector2(0, 7), Vector2(320, 7), WOOD, 1.0)
	draw_rect(Rect2(0, 8, 320, 16), WOOD_DARK)
	for x in range(4, 320, 40):
		var pane := Rect2(x, 10, 34, 12)
		draw_rect(pane, PAPER_SHADE)
		for gx in range(int(pane.position.x) + 8, int(pane.end.x), 8):
			draw_line(Vector2(gx, pane.position.y), Vector2(gx, pane.end.y), GRID, 1.0)
		draw_line(Vector2(pane.position.x, pane.position.y + 6), Vector2(pane.end.x, pane.position.y + 6), GRID, 1.0)
	draw_rect(Rect2(0, 24, 320, 5), WOOD)
	draw_line(Vector2(0, 24), Vector2(320, 24), WOOD_HI, 1.0)

	# Back wall behind the board, and the shoji screens on either side.
	draw_rect(Rect2(80, 29, 160, 95), PAPER_SHADE)
	for panel in [Rect2(4, 29, 34, 95), Rect2(42, 29, 34, 95), Rect2(244, 29, 34, 95), Rect2(282, 29, 34, 95)]:
		_draw_shoji(panel)
	for post_x in [0, 38, 76, 240, 278, 316]:
		var w := 4 if post_x in [0, 76, 240, 316] else 4
		draw_rect(Rect2(post_x, 29, w, 95), WOOD_DARK)
		draw_line(Vector2(post_x + 1, 29), Vector2(post_x + 1, 124), WOOD, 1.0)
	draw_rect(Rect2(0, 124, 320, 3), WOOD_DARK)


func _draw_shoji(r: Rect2) -> void:
	draw_rect(r, WOOD_LIGHT)
	var paper := r.grow(-2)
	paper.size.y -= 12
	draw_rect(paper, PAPER)
	for gx in range(int(paper.position.x) + 8, int(paper.end.x), 8):
		draw_line(Vector2(gx, paper.position.y), Vector2(gx, paper.end.y), GRID, 1.0)
	for gy in range(int(paper.position.y) + 12, int(paper.end.y), 12):
		draw_line(Vector2(paper.position.x, gy), Vector2(paper.end.x, gy), GRID, 1.0)
	# Wooden kick panel at the bottom of each screen.
	draw_rect(Rect2(r.position.x + 2, paper.end.y, r.size.x - 4, 10), WOOD)
	draw_line(Vector2(r.position.x + 2, paper.end.y), Vector2(r.end.x - 2, paper.end.y), WOOD_HI, 1.0)


func _draw_floor() -> void:
	var top := 127.0
	draw_rect(Rect2(0, top, 320, SIZE.y - top), TATAMI)
	for y in range(int(top) + 2, int(SIZE.y), 3):
		draw_line(Vector2(0, y), Vector2(320, y), TATAMI_LINE, 1.0)
	# Mat seams converge toward a vanishing point above the board.
	var vanish := Vector2(160, 60)
	for bottom_x in [-60.0, 100.0, 220.0, 380.0]:
		var bottom := Vector2(bottom_x, SIZE.y)
		var t := (top - vanish.y) / (SIZE.y - vanish.y)
		draw_line(vanish.lerp(bottom, t), bottom, TATAMI_BORDER, 2.0)
	draw_line(Vector2(0, 150), Vector2(320, 150), TATAMI_BORDER, 2.0)


# --- Lesson board ---

func _draw_board() -> void:
	draw_rect(Rect2(BOARD_RECT.position + Vector2(3, 3), BOARD_RECT.size), SHADOW)
	draw_rect(BOARD_RECT, WOOD_DARK)
	var inner := BOARD_RECT.grow(-2)
	draw_rect(inner, BOARD)
	if celebrate > 0.0:
		draw_rect(inner.grow(-1), Color(GOLD, 0.9 * (1.0 - celebrate)), false, 2.0)

	# Hanging plaque with the letter.
	for x in [PLAQUE_RECT.position.x + 6, PLAQUE_RECT.end.x - 6]:
		draw_line(Vector2(x, 24), Vector2(x, PLAQUE_RECT.position.y), WOOD_DARK, 1.0)
	draw_rect(PLAQUE_RECT, WOOD_DARK)
	draw_rect(PLAQUE_RECT.grow(-1), GOLD if celebrate > 0.0 else WOOD)
	var plaque_text := lesson if lesson != "" else "*"
	_text_centered(plaque_text, PLAQUE_RECT, 10, INK if celebrate > 0.0 else GOLD)

	if lesson == "":
		_text_centered("All signs", Rect2(inner.position.x, inner.position.y + 14, inner.size.x, 14), 10, INK)
		_text_centered("learned!", Rect2(inner.position.x, inner.position.y + 28, inner.size.x, 14), 10, INK)
		_text_centered("Off to the arena", Rect2(inner.position.x, inner.position.y + 50, inner.size.x, 10), 6, WOOD)
		return

	if practice:
		var tag := Rect2(inner.position + Vector2(3, 3), Vector2(40, 11))
		draw_rect(tag, SLOT_EDGE)
		draw_rect(tag.grow(-1), SLOT_FILL)
		_text_centered("Practice", tag, 6, INK)

	var modulate_color := Color(1, 1, 1, board_alpha)
	if sign_texture:
		var tex_size := sign_texture.get_size()
		var pos := (inner.get_center() - tex_size / 2.0 - Vector2(0, 3)).round()
		draw_texture(sign_texture, pos, modulate_color)
	else:
		_text_centered(lesson, Rect2(inner.position.x, inner.position.y + 8, inner.size.x, 50), 32, Color(INK, board_alpha))

	# Hold bar along the bottom of the board.
	var bar := Rect2(inner.position.x + 14, inner.end.y - 7, inner.size.x - 28, 4)
	draw_rect(bar, WOOD_DARK)
	var fill := bar.grow(-1)
	fill.size.x *= clampf(progress, 0.0, 1.0)
	draw_rect(fill, GOLD)

	# Sparkles bursting out of the plaque when a sign is learned.
	if celebrate > 0.0:
		var c := PLAQUE_RECT.get_center()
		for i in 8:
			var dir := Vector2.from_angle(TAU * i / 8.0 + 0.3)
			var p := (c + dir * (6.0 + 30.0 * celebrate)).round()
			var a := 1.0 - celebrate
			var arm := 2.0 if i % 2 == 0 else 1.0
			draw_line(p - Vector2(arm, 0), p + Vector2(arm, 0), Color(GOLD, a), 1.0)
			draw_line(p - Vector2(0, arm), p + Vector2(0, arm), Color(GOLD, a), 1.0)


# --- Toolbar (one slot per sign) ---

## Toolbar slot index under a point in this control's coordinates, or -1.
func slot_at(point: Vector2) -> int:
	for i in letters.size():
		if _slot_rect(i).has_point(point):
			return i
	return -1


func _toolbar_frame() -> Rect2:
	var inner_w := letters.size() * SLOT + (letters.size() - 1) * SLOT_GAP
	return Rect2((SIZE.x - inner_w) / 2.0 - 4, 153, inner_w + 8, SLOT + 8)


func _slot_rect(i: int) -> Rect2:
	var frame := _toolbar_frame()
	return Rect2(frame.position.x + 4 + i * (SLOT + SLOT_GAP), frame.position.y + 4, SLOT, SLOT)


func _draw_toolbar() -> void:
	var frame := _toolbar_frame()
	draw_rect(Rect2(frame.position + Vector2(2, 2), frame.size), SHADOW)
	draw_rect(frame, WOOD_DARK)
	draw_rect(frame.grow(-1), BAR_FILL)
	draw_line(frame.position + Vector2(1, 1), Vector2(frame.end.x - 1, frame.position.y + 1), WOOD_HI, 1.0)
	for i in letters.size():
		var letter: String = letters[i]
		var r := _slot_rect(i)
		var known := letter in learned
		draw_rect(r, SLOT_EDGE)
		draw_rect(r.grow(-1), SLOT_FILL if known else Color(SLOT_FILL.darkened(0.35)))
		if letter == lesson:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)
			draw_rect(r.grow(1), Color(GOLD, pulse), false, 1.0)
		elif known and i == hover_slot:
			draw_rect(r.grow(1), Color.WHITE, false, 1.0)  # finished signs can be clicked to practice
		_text_centered(letter if known else "?", r, 8, INK if known else Color(INK, 0.45))

	# Controls on a small wooden notice to the right of the toolbar.
	var notice := Rect2(frame.end.x + 6, frame.position.y, 316 - frame.end.x - 6, frame.size.y)
	draw_rect(notice, WOOD_DARK)
	draw_rect(notice.grow(-1), BAR_FILL)
	if keyboard_hint:
		_text_centered("Space+key: sign", Rect2(notice.position, Vector2(notice.size.x, notice.size.y / 2 + 2)), 5, INK)
		_text_centered("Esc: leave", Rect2(notice.position + Vector2(0, notice.size.y / 2 - 2), Vector2(notice.size.x, notice.size.y / 2 + 2)), 5, INK)
	else:
		_text_centered("Esc: leave", notice, 5, INK)


func _draw_title() -> void:
	if title_alpha <= 0.0:
		return
	var r := Rect2(110, 130, 100, 18)
	draw_rect(r, Color(WOOD_DARK, title_alpha))
	draw_rect(r.grow(-1), Color(BAR_FILL, title_alpha))
	_text_centered("The Dojo", r, 10, Color(INK, title_alpha))


func _text_centered(text: String, r: Rect2, font_size: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := _font.get_ascent(font_size)
	var descent := _font.get_descent(font_size)
	var baseline := r.position.y + (r.size.y + ascent - descent) / 2.0
	draw_string(_font, Vector2(round(r.get_center().x - w / 2.0), round(baseline)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
