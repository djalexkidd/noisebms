class_name MenuTurntable
extends RefCounted

# Steps of both turntables in a menu, like main_menu.gd: the analog motion,
# or a digital turntable held with a key repeat like the song wheel. poll() once per frame.

const ANALOG_STEP = 0.08
const REPEAT_DELAY = 0.3
const REPEAT_RATE = 0.09

var analog_previous = [0.0, 0.0]
var analog_remainder = [0.0, 0.0]
var repeat_direction = 0
var repeat_time = 0.0

func _init() -> void:
	for player in [1, 2]:
		analog_previous[player - 1] = analog_value(player)

func analog_value(player: int) -> float:
	return Input.get_action_strength("p%d_analog_turntable_fwd" % player) - Input.get_action_strength("p%d_analog_turntable_rew" % player)

func poll(delta: float) -> int:
	var steps = 0
	var direction = 0
	for player in [1, 2]:
		var value = analog_value(player)
		analog_remainder[player - 1] += wrapf(value - analog_previous[player - 1], -1.0, 1.0)
		analog_previous[player - 1] = value
		var player_steps = int(analog_remainder[player - 1] / ANALOG_STEP)
		analog_remainder[player - 1] -= player_steps * ANALOG_STEP
		steps += player_steps
		direction += int(Input.is_action_pressed("p%d_digital_turntable_fwd" % player))
		direction -= int(Input.is_action_pressed("p%d_digital_turntable_rew" % player))
	direction = signi(direction)
	if direction == 0:
		repeat_direction = 0
	elif direction != repeat_direction:
		repeat_direction = direction
		repeat_time = REPEAT_DELAY
		steps += direction
	else:
		repeat_time -= delta
		if repeat_time <= 0.0:
			repeat_time += REPEAT_RATE
			steps += direction
	return steps

# A white key (1, 3, 5, 7) or a black key (2, 4, 6) of either player just pressed
static func white_pressed() -> bool:
	return keys_pressed([1, 3, 5, 7])

static func black_pressed() -> bool:
	return keys_pressed([2, 4, 6])

static func keys_pressed(keys: Array) -> bool:
	for player in [1, 2]:
		for key in keys:
			if Input.is_action_just_pressed("p%d_key%d" % [player, key]):
				return true
	return false

# A key bound to a player action, already read with Input in _process
static func is_player_input(event: InputEvent) -> bool:
	for action in InputMap.get_actions():
		if (action.begins_with("p1_") or action.begins_with("p2_")) and event.is_action(action):
			return true
	return false
