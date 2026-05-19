extends Control
## Victory / results screen.
## Reads final stats from GameManager, saves best score, offers to replay or go home.

const SCENE_HOME       = "res://scenes/Home.tscn"
const SCENE_DIFFICULTY = "res://scenes/Difficulty.tscn"
const SCENE_GAME       = "res://scenes/Game.tscn"

const COL_BG      = Color(0.051, 0.067, 0.09, 1)
const COL_PRIMARY = Color(0.306, 0.8,   0.769, 1)
const COL_CORAL   = Color(1.0,   0.42,  0.42,  1)
const COL_SURFACE = Color(0.11,  0.137, 0.2,   1)
const COL_TEXT    = Color(1, 1, 1, 1)
const COL_MUTED   = Color(0.6, 0.6, 0.65, 1)
const COL_GOLD    = Color(1.0, 0.84, 0.0, 1)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var moves    = GameManager.current_moves
	var time_sec = GameManager.current_time
	var grid     = GameManager.grid_size
	var is_best  = SaveManager.try_save_best(grid, moves, time_sec)

	_build_ui(moves, time_sec, grid, is_best)
	_animate_entrance()

func _build_ui(moves: int, time_sec: float, grid: int, is_best: bool) -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Confetti-like decorative circles (simple, lightweight)
	_add_decoration()

	# Main card
	var card = Panel.new()
	card.custom_minimum_size = Vector2(800, 900)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COL_SURFACE
	for prop in ["corner_radius_top_left","corner_radius_top_right",
				 "corner_radius_bottom_left","corner_radius_bottom_right"]:
		card_style.set(prop, 32)
	card_style.shadow_color = Color(0, 0, 0, 0.4)
	card_style.shadow_size = 16
	card.add_theme_stylebox_override("panel", card_style)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   = 40
	vbox.offset_right  = -40
	vbox.offset_top    = 40
	vbox.offset_bottom = -40
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 40)
	card.add_child(vbox)

	# Trophy
	var trophy = Label.new()
	trophy.text = "🏆"
	trophy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trophy.add_theme_font_size_override("font_size", 120)
	vbox.add_child(trophy)

	# Title
	var title = Label.new()
	title.text = "Puzzle Solved!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	vbox.add_child(title)

	# Best badge
	if is_best:
		var badge = Label.new()
		badge.text = "★  New Best Score!"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 40)
		badge.add_theme_color_override("font_color", COL_GOLD)
		vbox.add_child(badge)

	# Stats grid
	var stats = GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 60)
	stats.add_theme_constant_override("v_separation", 20)
	vbox.add_child(stats)

	_stat_row(stats, "Grid",  "%d×%d" % [grid, grid])
	_stat_row(stats, "Moves", str(moves))
	_stat_row(stats, "Time",  _fmt_time(time_sec))

	# Best score comparison
	var best = SaveManager.get_best(grid)
	if best["moves"] > 0:
		_stat_row(stats, "Best Moves", str(best["moves"]))
		_stat_row(stats, "Best Time",  _fmt_time(best["time"]))

	# Spacer
	var sp = Control.new(); sp.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(sp)

	# Action buttons
	var play_again = _make_btn("Play Again →", COL_PRIMARY, Color(0.05, 0.05, 0.05))
	play_again.pressed.connect(func(): get_tree().change_scene_to_file(SCENE_GAME))
	vbox.add_child(play_again)

	var change_img = _make_btn("Change Image", COL_SURFACE, COL_TEXT)
	change_img.pressed.connect(func(): get_tree().change_scene_to_file(SCENE_DIFFICULTY))
	vbox.add_child(change_img)

	var home_btn = _make_btn("Home", COL_SURFACE, COL_MUTED)
	home_btn.pressed.connect(func(): get_tree().change_scene_to_file(SCENE_HOME))
	vbox.add_child(home_btn)

func _stat_row(grid: GridContainer, key: String, val: String) -> void:
	var k = Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 36)
	k.add_theme_color_override("font_color", COL_MUTED)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(k)

	var v = Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 36)
	v.add_theme_color_override("font_color", COL_TEXT)
	grid.add_child(v)

func _make_btn(text: String, bg: Color, fg: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(560, 100)
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	for prop in ["corner_radius_top_left","corner_radius_top_right",
				 "corner_radius_bottom_left","corner_radius_bottom_right"]:
		s.set(prop, 16)
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate(); h.bg_color = bg.lightened(0.1)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_font_size_override("font_size", 42)
	return btn

func _add_decoration() -> void:
	# Simple coloured blobs for visual interest — no images required
	var colours = [COL_PRIMARY, COL_CORAL, COL_GOLD]
	var positions = [Vector2(100, 200), Vector2(950, 150), Vector2(80, 1700),
					 Vector2(980, 1750), Vector2(500, 100), Vector2(550, 1850)]
	var sizes = [120, 80, 100, 90, 60, 70]
	for i in range(positions.size()):
		var dot = ColorRect.new()
		dot.color = colours[i % colours.size()]
		dot.color.a = 0.12
		var sz = sizes[i]
		dot.size = Vector2(sz, sz)
		dot.position = positions[i] - Vector2(sz / 2, sz / 2)
		add_child(dot)

func _animate_entrance() -> void:
	# Slide card in from bottom
	modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.35)

func _fmt_time(secs: float) -> String:
	if secs < 0:
		return "—"
	var m = int(secs) / 60
	var s = int(secs) % 60
	return "%d:%02d" % [m, s]
