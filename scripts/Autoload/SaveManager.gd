extends Node
## Handles local persistence using a JSON file in user://.
## Autoloaded as "SaveManager".

const SAVE_PATH = "user://save_data.json"

# Default structure — expanded on first load
var data: Dictionary = {
	"best_scores": {
		"3": {"moves": -1, "time": -1.0},
		"4": {"moves": -1, "time": -1.0},
		"5": {"moves": -1, "time": -1.0}
	},
	"games_completed": 0,
	"is_premium": false,
	"dark_mode": false
}

func _ready() -> void:
	_load_data()

func save() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		# Merge so new keys from defaults are kept
		for key in data:
			if parsed.has(key):
				data[key] = parsed[key]

# Returns true if the score is a new best; saves if so.
func try_save_best(grid_size: int, moves: int, time: float) -> bool:
	var key = str(grid_size)
	if not data["best_scores"].has(key):
		data["best_scores"][key] = {"moves": -1, "time": -1.0}

	var best = data["best_scores"][key]
	var is_new_best = false

	# Better = fewer moves; time is tiebreaker
	if best["moves"] == -1:
		is_new_best = true
	elif moves < best["moves"]:
		is_new_best = true
	elif moves == best["moves"] and time < best["time"]:
		is_new_best = true

	if is_new_best:
		data["best_scores"][key] = {"moves": moves, "time": time}
		save()

	return is_new_best

func get_best(grid_size: int) -> Dictionary:
	var key = str(grid_size)
	return data["best_scores"].get(key, {"moves": -1, "time": -1.0})
