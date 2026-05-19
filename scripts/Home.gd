extends Control
## Home screen. Shown at app launch.
## Builds its UI programmatically for easy maintenance.

const SCENE_DIFFICULTY = "res://scenes/Difficulty.tscn"
const SCENE_GAME       = "res://scenes/Game.tscn"

const COL_BG      = Color(0.051, 0.067, 0.09, 1)
const COL_PRIMARY = Color(0.306, 0.8,   0.769, 1)   # #4ECDC4
const COL_CORAL   = Color(1.0,   0.42,  0.42,  1)   # #FF6B6B
const COL_SURFACE = Color(0.11,  0.137, 0.2,   1)   # #1C2333
const COL_TEXT    = Color(1, 1, 1, 1)
const COL_MUTED   = Color(0.6, 0.6, 0.65, 1)

var _picker: Node = null
var _status_label: Label = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	_picker = load("res://scripts/ImagePickerPlugin.gd").new()
	_picker.name = "ImagePicker"
	add_child(_picker)
	_picker.image_ready.connect(_on_image_ready)
	_picker.cancelled.connect(_on_picker_cancelled)

	# Request media permissions early so the system dialog appears at launch
	# rather than when the user taps the button.
	if OS.get_name() == "Android":
		OS.request_permissions()

# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Decorative tiles in the background (purely visual)
	_add_bg_tiles()

	# Main content — centred column
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left   = -300
	vbox.offset_right  =  300
	vbox.offset_top    = -500
	vbox.offset_bottom =  500
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 48)
	add_child(vbox)

	# App title
	var title = Label.new()
	title.text = "SLIDEE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Puzzle from your photos"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 36)
	subtitle.add_theme_color_override("font_color", COL_MUTED)
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(spacer)

	# SELECT IMAGE button
	var btn = _make_button("  Select Image  ", COL_PRIMARY, Color(0.05, 0.05, 0.05))
	btn.custom_minimum_size = Vector2(540, 120)
	btn.pressed.connect(_on_select_pressed)
	vbox.add_child(btn)

	# Best scores button (secondary)
	var scores_btn = _make_button("Best Scores", COL_SURFACE, COL_TEXT)
	scores_btn.custom_minimum_size = Vector2(360, 90)
	scores_btn.pressed.connect(_on_scores_pressed)
	vbox.add_child(scores_btn)

	# Status / loading label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 32)
	_status_label.add_theme_color_override("font_color", COL_MUTED)
	_status_label.visible = false
	vbox.add_child(_status_label)

	# Settings gear (top-right corner)
	var settings_btn = Button.new()
	settings_btn.text = "⚙"
	settings_btn.flat = true
	settings_btn.position = Vector2(900, 60)
	settings_btn.size = Vector2(120, 120)
	settings_btn.add_theme_font_size_override("font_size", 56)
	settings_btn.add_theme_color_override("font_color", COL_MUTED)
	settings_btn.pressed.connect(_on_settings_pressed)
	add_child(settings_btn)

	# Version watermark
	var ver = Label.new()
	ver.text = "v1.0"
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left  = -120
	ver.offset_top   = -60
	ver.offset_right = -20
	ver.offset_bottom = -20
	ver.add_theme_font_size_override("font_size", 28)
	ver.add_theme_color_override("font_color", COL_MUTED)
	add_child(ver)

func _add_bg_tiles() -> void:
	# Draw a faint 3×3 grid graphic in the background for branding
	var colours = [
		Color(0.306, 0.8, 0.769, 0.08),
		Color(1.0,   0.42, 0.42, 0.08),
	]
	var tile_sz = 340
	var gap = 8
	var cols_n = 3
	var rows_n = 3
	var total_w = cols_n * tile_sz + (cols_n - 1) * gap
	var total_h = rows_n * tile_sz + (rows_n - 1) * gap
	var start_x = (1080 - total_w) / 2
	var start_y = 300

	for r in range(rows_n):
		for c in range(cols_n):
			if r == 1 and c == 1:
				continue  # empty centre tile
			var rect = ColorRect.new()
			rect.color = colours[(r + c) % 2]
			rect.position = Vector2(start_x + c * (tile_sz + gap),
									start_y + r * (tile_sz + gap))
			rect.size = Vector2(tile_sz, tile_sz)
			var style = StyleBoxFlat.new()
			style.corner_radius_top_left     = 12
			style.corner_radius_top_right    = 12
			style.corner_radius_bottom_left  = 12
			style.corner_radius_bottom_right = 12
			rect.add_theme_stylebox_override("panel", style)
			add_child(rect)

func _make_button(label_text: String, bg: Color, fg: Color) -> Button:
	var btn = Button.new()
	btn.text = label_text
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	btn.add_theme_stylebox_override("normal", style)
	var hover_style = style.duplicate()
	hover_style.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style = style.duplicate()
	pressed_style.bg_color = bg.darkened(0.12)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_font_size_override("font_size", 48)
	return btn

# ── Event handlers ─────────────────────────────────────────────────────────────

func _on_select_pressed() -> void:
	if OS.get_name() == "Android":
		_set_status("Opening gallery…  (grant access if prompted)")
	else:
		_set_status("Opening gallery…")
	_picker.pick_image()

func _on_picker_cancelled() -> void:
	_set_status("")

func _on_image_ready(_img: Image) -> void:
	_set_status("")
	get_tree().change_scene_to_file(SCENE_DIFFICULTY)

func _on_scores_pressed() -> void:
	_show_best_scores_popup()

func _on_settings_pressed() -> void:
	_show_settings_popup()

# ── Popups ─────────────────────────────────────────────────────────────────────

func _set_status(msg: String) -> void:
	_status_label.text = msg
	_status_label.visible = msg.length() > 0

func _show_best_scores_popup() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Best Scores"

	var lines = []
	for size in [3, 4, 5]:
		var best = SaveManager.get_best(size)
		var moves_str = str(best["moves"]) if best["moves"] > 0 else "—"
		var time_str  = _fmt_time(best["time"]) if best["time"] > 0 else "—"
		lines.append("%dx%d — %s moves  %s" % [size, size, moves_str, time_str])

	dialog.dialog_text = "\n".join(lines)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _show_settings_popup() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Settings"

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)

	var premium_check = CheckButton.new()
	premium_check.text = "Premium (no ads)"
	premium_check.button_pressed = GameManager.is_premium
	premium_check.toggled.connect(func(on: bool):
		GameManager.is_premium = on
		SaveManager.data["is_premium"] = on
		SaveManager.save()
	)
	vbox.add_child(premium_check)

	var dark_check = CheckButton.new()
	dark_check.text = "Dark mode (enabled)"
	dark_check.button_pressed = true
	dark_check.disabled = true  # always dark in v1
	vbox.add_child(dark_check)

	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _fmt_time(secs: float) -> String:
	if secs < 0:
		return "—"
	var m = int(secs) / 60
	var s = int(secs) % 60
	return "%d:%02d" % [m, s]
