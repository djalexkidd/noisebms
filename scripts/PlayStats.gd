class_name PlayStats

# Statistics of the player for the STATS menu, like the console versions of IIDX:
# every play (solo, versus, DP, ARCADE, netplay, not the autoplay, TRAINING or the editor test) adds its time,
# notes, judgements and options to the group of its style and difficulty (SP_N... DP_A) in user://stats.cfg.
# The lamps and DJ LEVELs come from the best scores (Scores, user://scores.cfg).

const PATH = "user://stats.cfg"
# Groups of the tabs: N (Beginner, Normal), H (Hyper), A (Another, Leggendaria)
const CLASSES = ["N", "H", "A"]
const COUNTERS = ["plays", "time", "notes", "level_sum", "PGreat", "Great", "Good", "Bad", "Poor", "fast", "slow", "random", "mirror", "hard", "easy"]
const JUDGES = ["PGreat", "Great", "Good", "Bad", "Poor"]
# A free difficulty name (Quaver) goes by its level: up to 3 is N, up to 6 is H, then A
const LEVEL_CLASSES = [3, 6]

static var config: ConfigFile

static func load_config() -> ConfigFile:
	if config == null:
		config = ConfigFile.new()
		config.load(PATH)
	return config

# Class of a difficulty (N, H or A), empty when its name is free and its level unknown
static func difficulty_class(difficulty_name: String, level: int) -> String:
	match difficulty_name.to_lower():
		"beginner", "normal": return "N"
		"hyper": return "H"
		"another", "leggendaria": return "A"
	if level <= 0:
		return ""
	if level <= LEVEL_CLASSES[0]:
		return "N"
	return "H" if level <= LEVEL_CLASSES[1] else "A"

static func group(double: bool, difficulty_name: String, level: int) -> String:
	var difficulty = difficulty_class(difficulty_name, level)
	return ("DP" if double else "SP") + ("_" + difficulty if difficulty != "" else "")

# Called by the playfield at the end of a play, before its results screen
static func add_play(player: int, double: bool, time: float, note_count: int, counts: Dictionary, fast: int, slow: int) -> void:
	var level: int = Global.song_info.get("level", 0)
	var key = group(double, Loader.chart_difficulty, level)
	var stats: Dictionary = load_config().get_value("plays", key, {})
	var add = func(counter: String, value) -> void: stats[counter] = stats.get(counter, 0) + value
	add.call("plays", 1)
	add.call("time", maxf(time, 0.0))
	add.call("notes", note_count)
	add.call("level_sum", level)
	for judge in JUDGES:
		add.call(judge, counts.get(judge, 0))
	add.call("fast", fast)
	add.call("slow", slow)
	add.call("random", int(Global.get_player_var(player, "random")))
	add.call("mirror", int(Global.get_player_var(player, "mirror")))
	var gauge_level = Global.get_player_var(player, "gauge_level")
	add.call("hard", int(gauge_level == 2))
	add.call("easy", int(gauge_level == 1))
	config.set_value("plays", key, stats)
	config.save(PATH)

# A new ARCADE game, counted at its 1st stage
static func add_arcade_game() -> void:
	load_config().set_value("global", "arcade_games", get_arcade_games() + 1)
	config.save(PATH)

static func get_arcade_games() -> int:
	return load_config().get_value("global", "arcade_games", 0)

# The groups of a tab: "" (TOTAL), "SP", "DP", "SP_N"...
static func matches(key: String, tab: String) -> bool:
	return tab == "" or key == tab or key.begins_with(tab + "_")

# Sum of the counters of the plays of a tab
static func totals(tab: String) -> Dictionary:
	var result = {}
	for counter in COUNTERS:
		result[counter] = 0
	var plays = load_config()
	if plays.has_section("plays"):
		for key in plays.get_section_keys("plays"):
			if matches(key, tab):
				var stats: Dictionary = plays.get_value("plays", key)
				for counter in COUNTERS:
					result[counter] += stats.get(counter, 0)
	return result

# Best scores of the charts of a tab: their count, the count of each lamp and of each DJ LEVEL (F to AAA)
static func best_scores(tab: String) -> Dictionary:
	var lamps = []
	lamps.resize(Scores.LAMPS.size())
	lamps.fill(0)
	var ranks = {}
	for rank_name in ["AAA", "AA", "A", "B", "C", "D", "E", "F"]:
		ranks[rank_name] = 0
	var charts = 0
	var scores = Scores.load_config()
	for path in scores.get_sections():
		for difficulty_key in scores.get_section_keys(path):
			var best = scores.get_value(path, difficulty_key)
			if not best is Dictionary:
				continue
			var double = difficulty_key.begins_with("DP_")
			var key = group(double, difficulty_key.trim_prefix("DP_") if double else difficulty_key, best.get("level", 0))
			if not matches(key, tab):
				continue
			charts += 1
			lamps[clampi(best.get("lamp", 0), 0, lamps.size() - 1)] += 1
			ranks[Scores.rank(best.get("rate", 0.0))] += 1
	return {"charts": charts, "lamps": lamps, "ranks": ranks}
