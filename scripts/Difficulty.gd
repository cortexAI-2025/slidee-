extends Control
## Difficulty selection screen.
## Shows a thumbnail of the chosen image plus three grid-size buttons.

const SCENE_HOME = "res://scenes/Home.tscn"
const SCENE_GAME = "res://scenes/Game.tscn"

const COL_BG      = Color(0.051, 0.067, 0.09, 1)
const COL_PRIMARY = Color(0.306, 0.8,   0.769, 1)
const COL_SURFACE = Color(0.11,  0.137, 0.2,   1)
const COL_TEXT    = Color(1, 1, 1, 1)
const COL_MUTED   = Color(0.6, 0.6, 0.65, 1)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Root column
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 60
	vbox.offset_right  = -60
	vbox.offset_top    = 80
	vbox.offset_bottom = -80
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 60)
	add_child(vbox)

	# ── Image preview ─────────────────────────────────────────────────────────
	var preview = TextureRect.new()
	preview.texture = GameManager.selected_texture
	preview.custom_minimum_size = Vector2(700, 700)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Rounded frame around preview
	var frame = Panel.new()
	frame.custom_minimum_size = Vector2(720, 720)
	var style = StyleBoxFlat.new()
	style.bg_color = COL_SURFACE
	style.corner_radius_top_left     = 24
	style.corner_radius_top_right    = 24
	style.corner_radius_bottom_left  = 24
	style.corner_radius_bottom_right = 24
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 10
	style.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", style)
	frame.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center_frame = CenterContainer.new()
	center_frame.add_child(frame)
	vbox.add_child(center_frame)

	# ── Label ─────────────────────────────────────────────────────────────────
	var lbl = Label.new()
	lbl.text = "Choose difficulty"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", COL_TEXT)
	vbox.add_child(lbl)

	# ── Difficulty buttons ────────────────────────────────────────────────────
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 32)
	vbox.add_child(hbox)

	for grid in [3, 4, 5]:
		var label = "%d×%d" % [grid, grid]
		var desc  = ["Easy", "Medium", "Hard"][grid - 3]
		var btn   = _make_difficulty_button(label, desc, grid)
		hbox.add_child(btn)

	# ── Back button ───────────────────────────────────────────────────────────
	var back = Button.new()
	back.text = "← Back"
	back.flat = true
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", COL_MUTED)
	back.pressed.connect(func(): get_tree().change_scene_to_file(SCENE_HOME))

	var center_back = CenterContainer.new()
	center_back.add_child(back)
	vbox.add_child(center_back)

func _make_difficulty_button(label_text: String, sub: String, grid_size: int) -> Control:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(210, 190)

	var style = StyleBoxFlat.new()
	style.bg_color = COL_SURFACE
	style.corner_radius_top_left     = 20
	style.corner_radius_top_right    = 20
	style.corner_radius_bottom_left  = 20
	style.corner_radius_bottom_right = 20
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = COL_PRIMARY.darkened(0.3)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_s = style.duplicate()
	pressed_s.bg_color = COL_PRIMARY
	btn.add_theme_stylebox_override("pressed", pressed_s)

	# Use a VBoxContainer inside the button for two lines of text
	var inner = VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top_lbl = Label.new()
	top_lbl.text = label_text
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_lbl.add_theme_font_size_override("font_size", 52)
	top_lbl.add_theme_color_override("font_color", COL_PRIMARY)
	top_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(top_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = sub
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 30)
	sub_lbl.add_theme_color_override("font_color", COL_MUTED)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sub_lbl)

	btn.add_child(inner)
	btn.pressed.connect(func(): _start_game(grid_size))
	return btn

func _start_game(size: int) -> void:
	GameManager.grid_size = size
	get_tree().change_scene_to_file(SCENE_GAME)
