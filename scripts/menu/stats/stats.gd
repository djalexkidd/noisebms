extends "res://scripts/menu/stats/stats_page.gd"

# STATS screen like the console versions of IIDX: one tab per group of charts (TOTAL, SINGLE, SP N/H/A, DOUBLE, DP N/H/A).
# Left: the player (songs played, play time, notes, ARCADE) and the options used; right: the clear rates,
# the charts by DJ LEVEL and the share of each judgement with its pie. Data from PlayStats and Scores.
# Turntable, arrows, wheel or a click: tab; black key: back to the STATS menu.

# Name, PlayStats group, color, explanation
const TABS = [
	["TOTAL", "", Color.WHITE, "OVERALL RECORD OF THE PLAYER."],
	["SINGLE", "SP", Color.WHITE, "RECORD OF THE SINGLE PLAY."],
	["SP N", "SP_N", Color(0.3, 0.6, 1), "SINGLE PLAY, NORMAL CHARTS (BEGINNER, NORMAL OR LEVEL 1~3)."],
	["SP H", "SP_H", Color(1, 0.75, 0.1), "SINGLE PLAY, HYPER CHARTS (HYPER OR LEVEL 4~6)."],
	["SP A", "SP_A", Color(1, 0.2, 0.15), "SINGLE PLAY, ANOTHER CHARTS (ANOTHER, LEGGENDARIA OR LEVEL 7~8)."],
	["DOUBLE", "DP", Color.WHITE, "RECORD OF THE DOUBLE PLAY."],
	["DP N", "DP_N", Color(0.3, 0.6, 1), "DOUBLE PLAY, NORMAL CHARTS (BEGINNER, NORMAL OR LEVEL 1~3)."],
	["DP H", "DP_H", Color(1, 0.75, 0.1), "DOUBLE PLAY, HYPER CHARTS (HYPER OR LEVEL 4~6)."],
	["DP A", "DP_A", Color(1, 0.2, 0.15), "DOUBLE PLAY, ANOTHER CHARTS (ANOTHER, LEGGENDARIA OR LEVEL 7~8)."],
]
const DJ_LEVELS = ["AAA", "AA", "A", "B", "C", "D", "E", "F"]
const DJ_LEVEL_COLORS = [Color(0.15, 0.45, 0.8), Color(0.1, 0.6, 0.5), Color(0.35, 0.65, 0.15), Color(0.65, 0.6, 0.1),
	Color(0.7, 0.45, 0.1), Color(0.65, 0.3, 0.1), Color(0.75, 0.15, 0.5), Color(0.45, 0.15, 0.75)]
# Judgements of PlayStats.JUDGES
const JUDGE_NAMES = ["P-GREAT", "GREAT", "GOOD", "BAD", "POOR"]
const JUDGE_COLORS = [Color(0.2, 0.8, 0.85), Color(0.15, 0.7, 0.35), Color(0.8, 0.8, 0.2), Color(0.85, 0.5, 0.2), Color(0.85, 0.2, 0.15)]

const TAB_TOP = 124.0
const TAB_HEIGHT = 36.0
const MARGIN = 40.0
const CONTENT_TOP = 172.0
const ROW_HEIGHT = 26.0
const ROW_STEP = 29.0
const COLUMN_GAP = 40.0
const VALUE_X = 340.0
const BAR_WIDTH = 230.0
const PIE_RADIUS = 92.0
# Bars and pie growing after a tab change
const GROW_TIME = 0.45

# Last tab, kept across scene changes
static var last_tab = 0
var tab = last_tab
var totals := {}
var best := {}
var arcade_best := {}
var grow := 0.0
var grow_tween: Tween

func _ready() -> void:
	super._ready()
	for double in [false, true]:
		var entries = Arcade.load_ranking(double)
		arcade_best[double] = entries[0].get("ex_score", 0) if not entries.is_empty() else -1
	load_tab()

func _process(delta: float) -> void:
	queue_redraw()
	var steps = turntable.poll(delta)
	if leaving:
		return
	if steps != 0:
		select_tab(tab + steps)
	if MenuTurntable.black_pressed():
		back()

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: select_tab(tab - 1)
			MOUSE_BUTTON_WHEEL_DOWN: select_tab(tab + 1)
			MOUSE_BUTTON_LEFT: click(event.position)
		return
	if not (event is InputEventKey and event.pressed) or MenuTurntable.is_player_input(event):
		return
	match event.keycode:
		KEY_LEFT, KEY_UP: select_tab(tab - 1)
		KEY_RIGHT, KEY_DOWN: select_tab(tab + 1)
		KEY_ESCAPE, KEY_BACKSPACE: back()

func click(at: Vector2) -> void:
	if header_tag_rect(2).has_point(at):
		back()
	for i in TABS.size():
		if tab_rect(i).has_point(at):
			select_tab(i)

func select_tab(new_tab: int) -> void:
	new_tab = posmod(new_tab, TABS.size())
	if new_tab == tab:
		return
	tab = new_tab
	last_tab = tab
	scroll_sound.play()
	load_tab()

func load_tab() -> void:
	totals = PlayStats.totals(TABS[tab][1])
	best = PlayStats.best_scores(TABS[tab][1])
	if grow_tween:
		grow_tween.kill()
	grow = 0.0
	grow_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	grow_tween.tween_property(self, "grow", 1.0, GROW_TIME)

func back() -> void:
	leave_to(STATS_MENU_SCENE, cancel_sound)

# Layout

func tab_rect(i: int) -> Rect2:
	var width = (size.x - MARGIN * 2) / TABS.size()
	return Rect2(MARGIN + i * width, TAB_TOP, width - 4, TAB_HEIGHT)

func left_column() -> Rect2:
	return Rect2(MARGIN, CONTENT_TOP, (size.x - MARGIN * 2 - COLUMN_GAP) / 2, body_bottom() - 16 - CONTENT_TOP)

func right_column() -> Rect2:
	var left = left_column()
	return Rect2(left.end.x + COLUMN_GAP, CONTENT_TOP, left.size.x, left.size.y)

# Values

static func count_text(value: int, digits := 6) -> String:
	return "%0*d" % [digits, value]

static func time_text(seconds: float) -> String:
	var total = int(seconds)
	return "%04d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60]

static func percent_text(rate: float) -> String:
	return "%03d%%" % roundi(rate)

func rate_of(counter: String) -> float:
	return totals[counter] * 100.0 / totals["plays"] if totals["plays"] > 0 else 0.0

func plays_average(counter: String) -> float:
	return totals[counter] / float(totals["plays"]) if totals["plays"] > 0 else 0.0

# Best total of the ARCADE rankings of the styles of the tab
func arcade_text() -> String:
	var group: String = TABS[tab][1]
	var parts = []
	for double in [false, true]:
		if group != "" and group.begins_with("DP") != double:
			continue
		var ex = arcade_best[double]
		parts.append(("DP " if double else "SP ") + (count_text(ex, 5) if ex >= 0 else "-----"))
	return "  ".join(parts)

# Share of the charts of the tab with at least this lamp
func lamp_rate(lowest: int) -> float:
	if best["charts"] == 0:
		return 0.0
	var count = 0
	for lamp in range(lowest, best["lamps"].size()):
		count += best["lamps"][lamp]
	return count * 100.0 / best["charts"]

# Drawing

func _draw() -> void:
	draw_body()
	draw_tabs()
	draw_player()
	draw_clears()
	draw_dj_levels()
	draw_judges()
	draw_header("stats", "PLAYER DATA", TABS[tab][0])
	draw_footer(TABS[tab][3])

func draw_tabs() -> void:
	# The same size for every tab, the one of the widest
	var font_size = 24
	for i in TABS.size():
		font_size = mini(font_size, fit_size(TABS[i][0], 24, tab_rect(i).size.x - 12))
	for i in TABS.size():
		var rect = tab_rect(i)
		var selected = i == tab
		draw_rect(rect, ROW_LIGHT if selected else ROW)
		draw_rect(rect, TAG_BORDER, false, 1.0)
		var text: String = TABS[i][0]
		draw_text(Vector2(rect.get_center().x, rect.get_center().y + 9), text, font_size, TABS[i][2], HORIZONTAL_ALIGNMENT_CENTER, 4)
		if selected:
			draw_rect(rect.grow(2), YELLOW, false, 4.0)

# A line of the table: dark row, label, value on the right side
func draw_row(rect: Rect2, label: String, value: String, value_color := Color.WHITE) -> void:
	draw_rect(rect, ROW_LIGHT)
	var baseline = rect.get_center().y + 8
	draw_text(Vector2(rect.position.x + 18, baseline), label, fit_size(label, 18, VALUE_X - 40), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)
	draw_text(Vector2(rect.position.x + VALUE_X, baseline), value, fit_size(value, 20, rect.size.x - VALUE_X - 10), value_color, HORIZONTAL_ALIGNMENT_LEFT, 3)

func draw_player() -> void:
	var column = left_column()
	var dj_name = Global.p1_name if Global.p1_name != "" else "------"
	var rows = [
		["DJ NAME", dj_name, YELLOW],
		["SONGS PLAYED", count_text(totals["plays"]), Color.WHITE],
		["PLAY TIME", time_text(totals["time"]), Color.WHITE],
		["AVERAGE PLAY TIME", time_text(plays_average("time")), Color.WHITE],
		["NOTES PLAYED", count_text(totals["notes"], 8), Color.WHITE],
		["ARCADE GAMES", count_text(PlayStats.get_arcade_games(), 4), Color.WHITE],
		["ARCADE BEST", arcade_text(), PALE_BLUE],
	]
	var y = column.position.y
	for row in rows:
		draw_row(Rect2(column.position.x, y, column.size.x, ROW_HEIGHT), row[0], row[1], row[2])
		y += ROW_STEP

	# PLAY STATS. title with a line, then the rows indented
	y += 6
	draw_rect(Rect2(column.position.x, y, column.size.x, ROW_HEIGHT + 2), Color.BLACK)
	draw_text(Vector2(column.position.x + 18, y + ROW_HEIGHT - 4), "PLAY STATS.", 20, Color.WHITE)
	var line_x = column.position.x + 40 + TITLE_FONT.get_string_size("PLAY STATS.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_line(Vector2(line_x, y + ROW_HEIGHT / 2 + 1), Vector2(column.end.x - 40, y + ROW_HEIGHT / 2 + 1), Color.WHITE, 2.0)
	y += ROW_STEP + 4
	var stats = [
		["AVERAGE LEVEL", "%04.1f" % plays_average("level_sum")],
		["AVERAGE NOTES", count_text(roundi(plays_average("notes")), 4)],
		["RANDOM RATE", percent_text(rate_of("random"))],
		["MIRROR RATE", percent_text(rate_of("mirror"))],
		["HARD RATE", percent_text(rate_of("hard"))],
		["EASY RATE", percent_text(rate_of("easy"))],
	]
	for row in stats:
		draw_row(Rect2(column.position.x + 40, y, column.size.x - 80, ROW_HEIGHT), row[0], row[1])
		y += ROW_STEP

# FULL COMBO, HARD CLEAR and CLEAR rates of the charts played, with a bar
func draw_clears() -> void:
	var column = right_column()
	# FULL COMBO and PERFECT, HARD CLEAR and better, any clear
	var rates = [["FULL COMBO RATE", lamp_rate(5)], ["HARD CLEAR RATE", lamp_rate(4)], ["CLEAR RATE", lamp_rate(1)]]
	var y = column.position.y
	for rate in rates:
		var rect = Rect2(column.position.x, y, column.size.x, ROW_HEIGHT)
		draw_rect(rect, ROW_LIGHT)
		var baseline = rect.get_center().y + 8
		draw_text(Vector2(rect.position.x + 14, baseline), rate[0], fit_size(rate[0], 18, 186), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)
		var bar = Rect2(rect.position.x + 210, rect.position.y + 5, BAR_WIDTH, rect.size.y - 10)
		draw_rect(bar, Color.BLACK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * rate[1] / 100.0 * grow, bar.size.y)), Color(0.25, 0.6, 0.85))
		draw_rect(bar, Color.WHITE, false, 2.0)
		draw_text(Vector2(rect.end.x - 12, baseline), percent_text(rate[1]), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		y += ROW_STEP
	var charts_text = "%d CHART%s PLAYED" % [best["charts"], "" if best["charts"] == 1 else "S"]
	draw_text(Vector2(column.end.x - 12, y + 14), charts_text, 12, TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

# Charts by DJ LEVEL of their best score: one bar split by DJ LEVEL, the counts under it
func draw_dj_levels() -> void:
	var column = right_column()
	var top = column.position.y + ROW_STEP * 3 + 38
	draw_text(Vector2(column.position.x + 14, top), "CHARTS BY DJ LEVEL", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var bar = Rect2(column.position.x + 14, top + 14, column.size.x - 28, 20)
	draw_rect(bar, Color.BLACK)
	var x = bar.position.x
	for i in DJ_LEVELS.size():
		var count: int = best["ranks"][DJ_LEVELS[i]]
		if best["charts"] > 0 and count > 0:
			var width = bar.size.x * count / best["charts"] * grow
			draw_rect(Rect2(x, bar.position.y, width - 1, bar.size.y), DJ_LEVEL_COLORS[i])
			x += width
	draw_rect(bar, TAG_BORDER, false, 1.0)
	var cell = bar.size.x / DJ_LEVELS.size()
	for i in DJ_LEVELS.size():
		var left = bar.position.x + i * cell
		draw_rect(Rect2(left, bar.end.y + 8, 5, 40), DJ_LEVEL_COLORS[i])
		draw_text(Vector2(left + 10, bar.end.y + 22), DJ_LEVELS[i], 14, Color.WHITE)
		var count = count_text(best["ranks"][DJ_LEVELS[i]], 3)
		draw_text(Vector2(left + 10, bar.end.y + 46), count, fit_size(count, 18, cell - 16), Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)

# Share of each judgement of the notes played, FAST and SLOW, and the pie
func draw_judges() -> void:
	var column = right_column()
	var top = column.position.y + ROW_STEP * 3 + 160
	draw_text(Vector2(column.position.x + 14, top), "JUDGEMENT RATES", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 3)
	var total = 0
	for judge in PlayStats.JUDGES:
		total += totals[judge]
	var shares = []
	for i in PlayStats.JUDGES.size():
		shares.append(totals[PlayStats.JUDGES[i]] / float(total) if total > 0 else 0.0)
	var y = top + 30
	for i in JUDGE_NAMES.size():
		var name_color = Color(1, 0.45, 0.75) if i == 0 else Color.WHITE
		draw_text(Vector2(column.position.x + 160, y), JUDGE_NAMES[i], 16, name_color, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		draw_text(Vector2(column.position.x + 270, y), percent_text(shares[i] * 100.0), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		draw_rect(Rect2(column.position.x + 282, y - 15, 16, 16), JUDGE_COLORS[i])
		y += 25
	# FAST and SLOW of the GREAT, GOOD and BAD
	for line in [["FAST", totals["fast"]], ["SLOW", totals["slow"]]]:
		draw_text(Vector2(column.position.x + 110, y + 4), line[0], 14, PALE_BLUE, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		draw_text(Vector2(column.position.x + 270, y + 4), count_text(line[1], 7), 14, PALE_BLUE, HORIZONTAL_ALIGNMENT_RIGHT, 3)
		y += 20

	var center = Vector2(column.end.x - PIE_RADIUS - 30, top + 20 + PIE_RADIUS)
	if total == 0:
		draw_circle(center, PIE_RADIUS, ROW_LIGHT)
		draw_text(center + Vector2(0, 8), "NO DATA", 18, TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		# Clockwise from the top, the slices opening with the growth
		var angle = -PI / 2
		for i in shares.size():
			var sweep = shares[i] * TAU * grow
			if sweep <= 0.0:
				continue
			if sweep >= TAU - 0.001:
				draw_circle(center, PIE_RADIUS, JUDGE_COLORS[i])
				break
			var points = PackedVector2Array([center])
			var segments = maxi(2, ceili(sweep / 0.1))
			for step in segments + 1:
				points.append(center + Vector2.from_angle(angle + sweep * step / segments) * PIE_RADIUS)
			draw_colored_polygon(points, JUDGE_COLORS[i])
			angle += sweep
	draw_arc(center, PIE_RADIUS, 0, TAU, 64, Color.WHITE, 3.0, true)
