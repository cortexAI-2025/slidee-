extends Panel
## A single puzzle tile. Holds an AtlasTexture sub-region of the source image.
## Handles its own tap detection and slide animation.

signal tapped(board_index: int)

# ── Config ─────────────────────────────────────────────────────────────────────
const ANIM_DURATION = 0.12  # seconds for slide animation
const SHADOW_COLOR  = Color(0, 0, 0, 0.35)

# ── State ──────────────────────────────────────────────────────────────────────
var board_index: int = 0      # current position in the grid (0-based)
var tile_number: int = 0      # logical tile id (0 = empty — should not be visible)

var _tile_rect: TextureRect
var _tween: Tween = null

# ── Setup ──────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.14, 0.20)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = SHADOW_COLOR
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)

	_tile_rect = TextureRect.new()
	_tile_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_tile_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tile_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_tile_rect)

	gui_input.connect(_on_gui_input)

func init(image_texture: ImageTexture, tile_num: int, col: int, row: int,
		grid_size: int, tile_px: int) -> void:
	tile_number = tile_num

	# Slice the source texture into an AtlasTexture region
	var atlas = AtlasTexture.new()
	atlas.atlas = image_texture
	atlas.region = Rect2(col * tile_px, row * tile_px, tile_px, tile_px)
	_tile_rect.texture = atlas

# ── Interaction ────────────────────────────────────────────────────────────────

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		emit_signal("tapped", board_index)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tapped", board_index)

# ── Animation ──────────────────────────────────────────────────────────────────

func slide_to(target_pos: Vector2, on_done: Callable = Callable()) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_pos, ANIM_DURATION)
	if on_done.is_valid():
		_tween.tween_callback(on_done)

func flash_invalid() -> void:
	# Brief shake to signal an invalid tap
	if _tween:
		_tween.kill()
	var origin = position
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", origin + Vector2(8, 0), 0.04)
	_tween.tween_property(self, "position", origin - Vector2(8, 0), 0.04)
	_tween.tween_property(self, "position", origin, 0.04)
