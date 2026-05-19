extends Control
## Main game scene.
## Manages the puzzle board, HUD (timer + moves), and overlay controls.

const SCENE_HOME       = "res://scenes/Home.tscn"
const SCENE_DIFFICULTY = "res://scenes/Difficulty.tscn"
const SCENE_VICTORY    = "res://scenes/Victory.tscn"
const TILE_SCENE       = preload("res://scenes/Tile.tscn")

const COL_BG      = Color(0.051, 0.067, 0.09, 1)
const COL_PRIMARY = Color(0.306, 0.8,   0.769, 1)
const COL_SURFACE = Color(0.11,  0.137, 0.2,   1)
const COL_TEXT    = Color(1, 1, 1, 1)
const COL_MUTED   = Color(0.6, 0.6, 0.65, 1)
const COL_CORAL   = Color(1.0, 0.42, 0.42, 1)

const BOARD_MARGIN = 40   # px between board edges and screen
const TILE_GAP     = 6    # px between tiles

# ── State ──────────────────────────────────────────────────────────────────────
var _board: PuzzleBoard = null
var _tiles: Array = []          # Tile node references indexed by board_index
var _tile_size: int = 0         # Rendered size of one tile in px
var _board_offset: Vector2      # Top-left corner of the puzzle grid

var _timer_active: bool = false
var _elapsed: float = 0.0
var _moves: int = 0

var _preview_visible: bool = false
var _preview_node: TextureRect = null
var _input_locked: bool = false  # Lock during animations

# HUD references
var _timer_label: Label = null
var _moves_label: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_start_puzzle()

# ── UI ─────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Top HUD bar ───────────────────────────────────────────────────────────
	var top_bar = HBoxContainer.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(1080, 130)
	top_bar.add_theme_constant_override("separation", 0)
	add_child(top_bar)

	# Back button
	var back_btn = _flat_btn("←", 64, COL_MUTED)
	back_btn.custom_minimum_size = Vector2(110, 130)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file(SCENE_DIFFICULTY))
	top_bar.add_child(back_btn)

	# Spacer
	var sp1 = Control.new(); sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(sp1)

	# Timer
	var timer_box = VBoxContainer.new()
	timer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_timer_label = Label.new()
	_timer_label.text = "0:00"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 48)
	_timer_label.add_theme_color_override("font_color", COL_TEXT)
	var timer_sub = Label.new()
	timer_sub.text = "TIME"
	timer_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_sub.add_theme_font_size_override("font_size", 26)
	timer_sub.add_theme_color_override("font_color", COL_MUTED)
	timer_box.add_child(_timer_label)
	timer_box.add_child(timer_sub)
	top_bar.add_child(timer_box)

	var sp2 = Control.new(); sp2.custom_minimum_size = Vector2(60, 0)
	top_bar.add_child(sp2)

	# Move counter
	var moves_box = VBoxContainer.new()
	moves_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_moves_label = Label.new()
	_moves_label.text = "0"
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves_label.add_theme_font_size_override("font_size", 48)
	_moves_label.add_theme_color_override("font_color", COL_TEXT)
	var moves_sub = Label.new()
	moves_sub.text = "MOVES"
	moves_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	moves_sub.add_theme_font_size_override("font_size", 26)
	moves_sub.add_theme_color_override("font_color", COL_MUTED)
	moves_box.add_child(_moves_label)
	moves_box.add_child(moves_sub)
	top_bar.add_child(moves_box)

	var sp3 = Control.new(); sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(sp3)

	# ── Bottom action bar ─────────────────────────────────────────────────────
	var bot_bar = HBoxContainer.new()
	bot_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top    = -160
	bot_bar.offset_bottom = 0
	bot_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_bar.add_theme_constant_override("separation", 60)
	add_child(bot_bar)

	# Restart
	var restart_btn = _icon_btn("↺", "Restart", COL_SURFACE, COL_PRIMARY)
	restart_btn.pressed.connect(_on_restart)
	bot_bar.add_child(restart_btn)

	# Preview (hold)
	var preview_btn = Button.new()
	preview_btn.text = "👁"
	preview_btn.custom_minimum_size = Vector2(200, 120)
	var pstyle = _surface_style()
	preview_btn.add_theme_stylebox_override("normal", pstyle)
	preview_btn.add_theme_stylebox_override("hover", pstyle)
	preview_btn.add_theme_stylebox_override("pressed", pstyle)
	preview_btn.add_theme_font_size_override("font_size", 52)
	preview_btn.button_down.connect(_show_preview)
	preview_btn.button_up.connect(_hide_preview)
	bot_bar.add_child(preview_btn)

	# ── Preview overlay ────────────────────────────────────────────────────────
	_preview_node = TextureRect.new()
	_preview_node.texture = GameManager.selected_texture
	_preview_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_node.modulate = Color(1, 1, 1, 0.92)
	_preview_node.visible = false
	_preview_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_node)

func _flat_btn(text: String, font_size: int, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", color)
	return btn

func _icon_btn(icon: String, _label: String, bg: Color, fg: Color) -> Button:
	var btn = Button.new()
	btn.text = icon
	btn.custom_minimum_size = Vector2(200, 120)
	var style = _surface_style()
	style.bg_color = bg
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate(); hover.bg_color = bg.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 52)
	btn.add_theme_color_override("font_color", fg)
	return btn

func _surface_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = COL_SURFACE
	for prop in ["corner_radius_top_left","corner_radius_top_right",
				 "corner_radius_bottom_left","corner_radius_bottom_right"]:
		s.set(prop, 18)
	return s

# ── Puzzle setup ───────────────────────────────────────────────────────────────

func _start_puzzle() -> void:
	_elapsed = 0.0
	_moves   = 0
	_update_hud()
	_input_locked = false

	# Remove old tiles
	for t in _tiles:
		if is_instance_valid(t):
			t.queue_free()
	_tiles.clear()

	# Create board logic
	_board = PuzzleBoard.new()
	_board.tile_moved.connect(_on_tile_moved)
	_board.puzzle_solved.connect(_on_puzzle_solved)
	add_child(_board)
	_board.setup(GameManager.grid_size)

	# Calculate tile pixel size to fit the screen
	var available_w = 1080 - BOARD_MARGIN * 2
	var available_h = 1920 - 300 - 200  # top HUD + bottom bar
	var max_side = min(available_w, available_h)
	var n = GameManager.grid_size
	_tile_size = (max_side - TILE_GAP * (n - 1)) / n
	var board_px = _tile_size * n + TILE_GAP * (n - 1)
	_board_offset = Vector2(
		(1080 - board_px) / 2.0,
		150.0 + (available_h - board_px) / 2.0
	)

	# Slice the image once into an atlas-friendly size
	var img = GameManager.selected_image
	var tile_px = img.get_width() / n   # image is already square

	# Create tile nodes
	for board_idx in range(_board.total_tiles):
		var tile_num = _board.tiles[board_idx]
		if tile_num == 0:
			_tiles.append(null)  # empty slot — no node
			continue

		var solved_pos = _board.solved_position(tile_num)
		var tile_node = TILE_SCENE.instantiate() as Panel
		tile_node.init(GameManager.selected_texture,
					   tile_num,
					   solved_pos.x, solved_pos.y,
					   n, tile_px)
		tile_node.board_index = board_idx
		tile_node.size = Vector2(_tile_size, _tile_size)
		tile_node.position = _board_position(board_idx)
		tile_node.tapped.connect(_on_tile_tapped)
		add_child(tile_node)
		_tiles.append(tile_node)

	# Move _preview_node on top
	move_child(_preview_node, get_child_count() - 1)

	_timer_active = true

func _board_position(board_idx: int) -> Vector2:
	var col = board_idx % GameManager.grid_size
	var row = board_idx / GameManager.grid_size
	return _board_offset + Vector2(col * (_tile_size + TILE_GAP),
								   row * (_tile_size + TILE_GAP))

# ── Process (timer) ────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _timer_active:
		_elapsed += delta
		_update_hud()

func _update_hud() -> void:
	var m = int(_elapsed) / 60
	var s = int(_elapsed) % 60
	_timer_label.text = "%d:%02d" % [m, s]
	_moves_label.text = str(_moves)

# ── Input / move handling ──────────────────────────────────────────────────────

func _on_tile_tapped(board_idx: int) -> void:
	if _input_locked:
		return
	var tile = _tiles[board_idx]
	if tile == null:
		return
	if not _board.can_move(board_idx):
		tile.flash_invalid()
		return

	_input_locked = true
	_board.try_move(board_idx)  # will emit tile_moved

func _on_tile_moved(from_idx: int, _to_idx: int) -> void:
	# from_idx: the tile that moved; it swapped with what was the empty slot.
	# After the board swap, the empty is now at from_idx.
	var empty_new = from_idx
	var tile_new  = _to_idx   # where the tile physically went

	var moving_tile: Panel = null
	# Find the tile that moved (it was at from_idx before the board updated)
	for t in _tiles:
		if t == null: continue
		if t.board_index == empty_new:
			# This was the tile that slid — it still has old board_index
			moving_tile = t
			break

	if moving_tile == null:
		_input_locked = false
		return

	# Update board_index
	moving_tile.board_index = tile_new

	# Swap the _tiles array entries
	var empty_prev_node = _tiles[tile_new]     # null (the empty slot visual)
	_tiles[tile_new]   = moving_tile
	_tiles[empty_new]  = empty_prev_node

	# Animate slide
	var target_pos = _board_position(tile_new)
	moving_tile.slide_to(target_pos, func():
		_input_locked = false
	)

	_moves += 1
	GameManager.current_moves = _moves

# ── Preview ────────────────────────────────────────────────────────────────────

func _show_preview() -> void:
	_preview_node.visible = true

func _hide_preview() -> void:
	_preview_node.visible = false

# ── Restart ────────────────────────────────────────────────────────────────────

func _on_restart() -> void:
	_timer_active = false
	# Remove the old PuzzleBoard before rebuilding
	if is_instance_valid(_board):
		_board.queue_free()
		_board = null
	_start_puzzle()

# ── Win ────────────────────────────────────────────────────────────────────────

func _on_puzzle_solved() -> void:
	_timer_active = false
	GameManager.current_time = _elapsed

	# Brief delay before victory screen
	await get_tree().create_timer(0.6).timeout
	GameManager.on_game_completed(_moves, _elapsed)
	get_tree().change_scene_to_file(SCENE_VICTORY)
