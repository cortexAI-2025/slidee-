class_name PuzzleBoard
extends Node
## Core puzzle logic: tile state, shuffling, move validation, win detection.
## Instantiated and owned by Game.gd.

# ── Signals ────────────────────────────────────────────────────────────────────
signal tile_moved(from_index: int, to_index: int)
signal puzzle_solved()

# ── State ──────────────────────────────────────────────────────────────────────
var grid_size: int = 3
var total_tiles: int = 9   # grid_size²

# tiles[i] holds the logical tile number at board position i.
# Value 0 = the empty slot.
# Solved state: [1, 2, 3, …, n²-1, 0]
var tiles: Array[int] = []

# Position of the empty slot in the tiles array
var empty_index: int = 0

# ── Initialise ─────────────────────────────────────────────────────────────────

func setup(size: int) -> void:
	grid_size = size
	total_tiles = size * size
	_reset_solved()
	_shuffle()

func _reset_solved() -> void:
	tiles.clear()
	for i in range(total_tiles - 1):
		tiles.append(i + 1)  # 1 … n²-1
	tiles.append(0)           # empty last
	empty_index = total_tiles - 1

# ── Shuffle ────────────────────────────────────────────────────────────────────
# Shuffle by making random valid moves from the solved state.
# This guarantees the puzzle is always solvable.

func _shuffle() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	# More moves for larger grids; minimum 200 to avoid trivial states
	var move_count = max(200, grid_size * grid_size * 40)
	var last_moved = -1  # prevent immediately undoing the last move

	for _i in range(move_count):
		var neighbors = _get_neighbors(empty_index)
		# Filter out the previous empty position to avoid ping-pong
		if neighbors.size() > 1:
			neighbors = neighbors.filter(func(n): return n != last_moved)
		var pick = neighbors[rng.randi() % neighbors.size()]
		last_moved = empty_index
		_do_swap(pick)

# ── Move API ───────────────────────────────────────────────────────────────────

# Returns true if the tile at board_index can move (adjacent to empty).
func can_move(board_index: int) -> bool:
	return board_index in _get_neighbors(empty_index)

# Attempts to move the tile at board_index into the empty slot.
# Returns true on success.
func try_move(board_index: int) -> bool:
	if not can_move(board_index):
		return false
	var from = board_index
	_do_swap(board_index)
	emit_signal("tile_moved", from, empty_index)  # new empty_index = old from
	if _is_solved():
		emit_signal("puzzle_solved")
	return true

func _do_swap(neighbor_index: int) -> void:
	tiles[empty_index] = tiles[neighbor_index]
	tiles[neighbor_index] = 0
	empty_index = neighbor_index

# ── Neighbours ─────────────────────────────────────────────────────────────────

func _get_neighbors(pos: int) -> Array[int]:
	var result: Array[int] = []
	var row = pos / grid_size
	var col = pos % grid_size
	if row > 0:              result.append(pos - grid_size)
	if row < grid_size - 1: result.append(pos + grid_size)
	if col > 0:              result.append(pos - 1)
	if col < grid_size - 1: result.append(pos + 1)
	return result

# Returns the direction the empty tile would move if the given tile is tapped.
# Used for animation direction. Returns Vector2.ZERO if invalid.
func get_move_direction(board_index: int) -> Vector2:
	var delta = empty_index - board_index
	if delta == -grid_size: return Vector2.UP
	if delta == grid_size:  return Vector2.DOWN
	if delta == -1:         return Vector2.LEFT
	if delta == 1:          return Vector2.RIGHT
	return Vector2.ZERO

# ── Win detection ──────────────────────────────────────────────────────────────

func _is_solved() -> bool:
	for i in range(total_tiles - 1):
		if tiles[i] != i + 1:
			return false
	return tiles[total_tiles - 1] == 0

# ── Helpers ────────────────────────────────────────────────────────────────────

# Returns the grid row/col of a board index as a Vector2i.
func index_to_grid(idx: int) -> Vector2i:
	return Vector2i(idx % grid_size, idx / grid_size)

# Returns the correct (solved) grid position of tile_number.
func solved_position(tile_number: int) -> Vector2i:
	if tile_number == 0:
		return Vector2i(grid_size - 1, grid_size - 1)
	var idx = tile_number - 1
	return Vector2i(idx % grid_size, idx / grid_size)
