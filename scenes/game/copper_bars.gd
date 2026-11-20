extends Node2D

# Copper bars between the two playfields while a module plays (VIDEO SETTINGS, Global.copper_bars),
# one fixed bar per channel (red, green, blue, yellow), stretched by the sound level of the channel
# (ModPlayer.channelLevel()), in dB and smoothed like the visualizer of the music select.

# Area between the playfields, above their plates (like TRAINING_RECT of main.gd)
const AREA : Rect2 = Rect2(410, 16, 460, 470)
const BAR_COLORS : Array[Color] = [Color(1.0, 0.1, 0.0), Color(0.0, 0.8, 0.0), Color(0.0, 0.2, 0.95), Color(0.95, 0.85, 0.0)]
# Size and spacing of a bar for 4 channels, smaller to fit more channels (.xm)
const BAR_HEIGHT : float = 30.0
const BAR_PITCH : float = 56.0
# Length of a bar at full volume, and of its chrome ends
const BAR_MAX_WIDTH : float = 440.0
const CAP_WIDTH : float = 40.0
const CAP_COLOR : Color = Color(0.95, 0.95, 0.95)
# Levels from MIN_DB (only the chrome ends) to 0 dB (full bar)
const MIN_DB : float = -40.0
# The bars follow the sound smoothly, up and down (higher = faster)
const RISE_SPEED : float = 18.0
const FALL_SPEED : float = 8.0

# ModPlayer of the song
var player : ModPlayer
var levels : PackedFloat32Array = []
var shade : GradientTexture2D

func _ready() -> void:
	# Vertical light of a tube: lit from above, dark at the bottom
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 0.85, 1.0])
	gradient.colors = PackedColorArray([Color(0.55, 0.55, 0.55), Color.WHITE, Color(0.8, 0.8, 0.8), Color(0.35, 0.35, 0.35), Color(0.1, 0.1, 0.1)])
	shade = GradientTexture2D.new()
	shade.gradient = gradient
	shade.width = 1
	shade.height = 64
	shade.fill_from = Vector2(0, 0)
	shade.fill_to = Vector2(0, 1)

func _process(delta : float) -> void:
	if player == null:
		return
	var channels : int = player.voices.size()
	levels.resize(channels)
	for c in channels:
		var db : float = linear_to_db(maxf(player.channelLevel(c), 0.00001))
		var target : float = clampf((db - MIN_DB) / -MIN_DB, 0.0, 1.0)
		var speed : float = RISE_SPEED if target > levels[c] else FALL_SPEED
		levels[c] = lerpf(levels[c], target, 1.0 - exp(-speed * delta))
	queue_redraw()

func _draw() -> void:
	var channels : int = levels.size()
	if channels == 0:
		return
	var pitch : float = minf(BAR_PITCH, AREA.size.y / channels)
	var height : float = BAR_HEIGHT * pitch / BAR_PITCH
	var top : float = AREA.get_center().y - pitch * channels / 2.0
	var center : float = AREA.get_center().x
	for c in channels:
		var width : float = 2 * CAP_WIDTH + levels[c] * (BAR_MAX_WIDTH - 2 * CAP_WIDTH)
		var y : float = top + c * pitch + (pitch - height) / 2.0
		var left : float = center - width / 2.0
		draw_texture_rect(shade, Rect2(left + CAP_WIDTH, y, width - 2 * CAP_WIDTH, height), false, BAR_COLORS[c % BAR_COLORS.size()])
		draw_texture_rect(shade, Rect2(left, y, CAP_WIDTH, height), false, CAP_COLOR)
		draw_texture_rect(shade, Rect2(left + width - CAP_WIDTH, y, CAP_WIDTH, height), false, CAP_COLOR)
