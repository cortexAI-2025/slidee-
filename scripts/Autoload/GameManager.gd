extends Node
## Global state shared across all scenes.
## Autoloaded as "GameManager".

# Selected image from gallery/camera
var selected_image: Image = null
var selected_texture: ImageTexture = null
var selected_image_path: String = ""

# Current game configuration
var grid_size: int = 3

# Runtime game state (set by Game scene)
var current_moves: int = 0
var current_time: float = 0.0

# Tracks completed games for interstitial ad frequency
var games_completed: int = 0

# Persistent flags (also stored in SaveManager)
var is_premium: bool = false
var dark_mode: bool = false

# Emitted by Game scene; listened to by Victory scene
signal game_won(moves: int, time: float, grid_size: int)

func _ready() -> void:
	is_premium = SaveManager.data.get("is_premium", false)
	dark_mode = SaveManager.data.get("dark_mode", false)
	games_completed = SaveManager.data.get("games_completed", 0)

func set_image(img: Image) -> void:
	selected_image = img
	selected_texture = ImageTexture.create_from_image(img)

func should_show_ad() -> bool:
	if is_premium:
		return false
	# Show ad every 3 completed games
	return games_completed > 0 and games_completed % 3 == 0

func on_game_completed(moves: int, time: float) -> void:
	games_completed += 1
	SaveManager.data["games_completed"] = games_completed
	SaveManager.save()
	emit_signal("game_won", moves, time, grid_size)
