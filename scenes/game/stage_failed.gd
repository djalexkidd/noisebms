class_name StageFailed
extends Control

# STAGE FAILED like on IIDX: two metal doors slam shut from the top and the bottom,
# STAGE FAILED lights up in the middle, then the screen fades to black and `closed` is emitted.

signal closed

const LAYER : int = 20
const SCREEN : Vector2 = Vector2(1280, 720)
const CLOSE_TIME : float = 0.35
const SHAKE_TIME : float = 0.15
const SHAKE_AMPLITUDE : float = 6.0
# The text flickers on after the doors meet
const TEXT_FLICKER_TIME : float = 0.25
# Time the closed doors stay before the fade
const HOLD_TIME : float = 1.0
const FADE_TIME : float = 0.6
const FONT : Font = preload("res://assets/font/ABSTRACT.TTF")
const TEXT : String = "STAGE FAILED"
const TEXT_SIZE : int = 18
# The wide letters are narrowed to fit the capsule
const TEXT_WIDTH : float = 330.0
const TEXT_COLOR : Color = Color(1.0, 0.1, 0.05)
const DOOR_COLOR : Color = Color(0.53, 0.53, 0.53)
const OUTER_COLOR : Color = Color(0.40, 0.40, 0.40)
const INNER_COLOR : Color = Color(0.26, 0.26, 0.26)
const FRAME_LINE_COLOR : Color = Color(0.33, 0.33, 0.33)
const EDGE_COLOR : Color = Color(0.02, 0.02, 0.02)
const RED_EDGE_COLOR : Color = Color(0.85, 0.05, 0.05)

# The top door when closed (the bottom one is the same turned by 180°), it goes down to the middle of the screen.
# Thin frame along the screen border
const FRAME_LINE : PackedVector2Array = [Vector2(0, 234), Vector2(40, 234), Vector2(40, 28), Vector2(56, 12),
	Vector2(1224, 12), Vector2(1240, 28), Vector2(1240, 234), Vector2(1280, 234)]
# Upper edge of the big grey shape
const OUTER_EDGE : PackedVector2Array = [Vector2(0, 268), Vector2(40, 268), Vector2(82, 236), Vector2(82, 186),
	Vector2(100, 168), Vector2(200, 168), Vector2(232, 196), Vector2(392, 196), Vector2(430, 242), Vector2(850, 242),
	Vector2(888, 196), Vector2(1048, 196), Vector2(1080, 168), Vector2(1180, 168), Vector2(1198, 186), Vector2(1198, 236),
	Vector2(1240, 268), Vector2(1280, 268)]
# Part of that edge lit in red
const RED_EDGE : PackedVector2Array = [Vector2(570, 242), Vector2(850, 242), Vector2(888, 196), Vector2(1048, 196)]
# Upper edge of the dark inner shape
const INNER_EDGE : PackedVector2Array = [Vector2(0, 328), Vector2(178, 328), Vector2(206, 300), Vector2(206, 282),
	Vector2(220, 268), Vector2(350, 268), Vector2(385, 298), Vector2(470, 298), Vector2(484, 288), Vector2(796, 288),
	Vector2(810, 298), Vector2(895, 298), Vector2(930, 268), Vector2(1060, 268), Vector2(1074, 282), Vector2(1074, 300),
	Vector2(1102, 328), Vector2(1280, 328)]
# Slots in the inner shape
const SLOTS : Array = [[Vector2(405, 296), Vector2(455, 296)], [Vector2(825, 296), Vector2(875, 296)]]
# Black band across the middle and its half of the capsule holding the text
const BAND_TOP : float = 350.0
const CAPSULE : PackedVector2Array = [Vector2(392, 360), Vector2(402, 351), Vector2(440, 351), Vector2(452, 341),
	Vector2(828, 341), Vector2(840, 351), Vector2(878, 351), Vector2(888, 360)]
# Arrow pointing to the text
const ARROW : PackedVector2Array = [Vector2(632, 268), Vector2(648, 268), Vector2(640, 278)]

var elapsed : float = 0.0
var done : bool = false

# Show the doors over everything of the scene, await `closed` before leaving
static func show_on(parent : Node) -> StageFailed:
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = LAYER
	parent.add_child(layer)
	var screen : StageFailed = StageFailed.new()
	layer.add_child(screen)
	return screen

func _ready() -> void:
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta : float) -> void:
	elapsed += delta
	queue_redraw()
	if not done and elapsed >= CLOSE_TIME + HOLD_TIME + FADE_TIME:
		done = true
		closed.emit()

func _draw() -> void:
	# The doors slam faster and faster, then shake for a moment
	var t : float = minf(elapsed / CLOSE_TIME, 1.0)
	var offset : float = -SCREEN.y / 2.0 * (1.0 - t * t)
	var since : float = elapsed - CLOSE_TIME
	var shake : float = 0.0
	if since > 0.0 and since < SHAKE_TIME:
		shake = SHAKE_AMPLITUDE * (1.0 - since / SHAKE_TIME) * sin(since * 90.0)
	draw_set_transform(Vector2(0, offset + shake))
	drawDoor()
	draw_set_transform(Vector2(SCREEN.x, SCREEN.y - offset + shake), PI)
	drawDoor()
	if since > 0.0:
		# Flickers on, then stays
		var on : bool = since > TEXT_FLICKER_TIME or int(since * 30.0) % 2 == 0
		if on:
			var width : float = FONT.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
			var narrow : float = minf(1.0, TEXT_WIDTH / width)
			draw_set_transform(Vector2(SCREEN.x / 2.0, SCREEN.y / 2.0 + shake), 0.0, Vector2(narrow, 1.0))
			var at := Vector2(-width / 2.0, TEXT_SIZE * 0.45)
			draw_string_outline(FONT, at, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, 6, Color(TEXT_COLOR, 0.35))
			draw_string(FONT, at, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, TEXT_COLOR)
	draw_set_transform(Vector2.ZERO)
	# Fade to black
	var fade : float = (since - HOLD_TIME) / FADE_TIME
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0, 0, 0, minf(fade, 1.0)))

# The top door, closed (y from 0 to the middle of the screen)
func drawDoor() -> void:
	var middle : float = SCREEN.y / 2.0
	draw_rect(Rect2(0, -SCREEN.y, SCREEN.x, middle + SCREEN.y), DOOR_COLOR)
	draw_polyline(FRAME_LINE, FRAME_LINE_COLOR, 2.0)
	draw_colored_polygon(closeShape(OUTER_EDGE, middle), OUTER_COLOR)
	draw_colored_polygon(closeShape(INNER_EDGE, middle), INNER_COLOR)
	draw_polyline(INNER_EDGE, EDGE_COLOR, 2.0)
	draw_polyline(OUTER_EDGE, EDGE_COLOR, 4.0)
	draw_polyline(RED_EDGE, RED_EDGE_COLOR, 3.0)
	for slot in SLOTS:
		draw_line(slot[0], slot[1], Color(0.18, 0.18, 0.18), 4.0)
	draw_colored_polygon(ARROW, Color(0.35, 0.35, 0.35))
	draw_rect(Rect2(0, BAND_TOP, SCREEN.x, middle - BAND_TOP), EDGE_COLOR)
	draw_colored_polygon(CAPSULE, EDGE_COLOR)

# A shape from its upper edge down to the middle of the screen
func closeShape(edge : PackedVector2Array, bottom : float) -> PackedVector2Array:
	var shape : PackedVector2Array = edge.duplicate()
	shape.append(Vector2(SCREEN.x, bottom))
	shape.append(Vector2(0, bottom))
	return shape
