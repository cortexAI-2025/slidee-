extends Control
## Camera capture screen.
## Shows a live viewfinder via CameraServer/CameraFeed, captures on tap.

const SCENE_HOME       = "res://scenes/Home.tscn"
const SCENE_DIFFICULTY = "res://scenes/Difficulty.tscn"

const COL_BG      = Color(0, 0, 0, 1)
const COL_PRIMARY = Color(0.306, 0.8, 0.769, 1)
const COL_MUTED   = Color(0.6, 0.6, 0.65, 1)

# Camera
var _feed: CameraFeed        = null
var _cam_texture: CameraTexture = null

# Scene nodes
var _preview: TextureRect    = null
var _sub_vp: SubViewport     = null
var _no_cam_label: Label     = null
var _capture_btn: Button     = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_init_camera()

# ── UI ─────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Black background
	var bg = ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# SubViewport renders the CameraFeed — used for reliable frame capture
	_sub_vp = SubViewport.new()
	_sub_vp.size = Vector2i(1080, 1920)
	_sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_vp.handle_input_locally = false
	add_child(_sub_vp)

	# TextureRect inside SubViewport shows the live camera texture
	_preview = TextureRect.new()
	_preview.size = Vector2i(1080, 1920)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sub_vp.add_child(_preview)

	# Mirror of the SubViewport shown to the user
	var vp_display = TextureRect.new()
	vp_display.texture = _sub_vp.get_texture()
	vp_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp_display.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vp_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(vp_display)

	# "No camera" message (hidden until needed)
	_no_cam_label = Label.new()
	_no_cam_label.text = "Camera not available\non this device"
	_no_cam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_cam_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_no_cam_label.add_theme_font_size_override("font_size", 48)
	_no_cam_label.add_theme_color_override("font_color", COL_MUTED)
	_no_cam_label.visible = false
	add_child(_no_cam_label)

	# ── Overlay UI ─────────────────────────────────────────────────────────────
	var ui = CanvasLayer.new()
	add_child(ui)

	# Back button (top-left)
	var back = Button.new()
	back.text = "←"
	back.flat = true
	back.position = Vector2(40, 80)
	back.size = Vector2(120, 120)
	back.add_theme_font_size_override("font_size", 72)
	back.add_theme_color_override("font_color", Color.WHITE)
	back.pressed.connect(_on_back)
	ui.add_child(back)

	# Shutter button (centred at the bottom)
	_capture_btn = Button.new()
	_capture_btn.text = ""
	_capture_btn.custom_minimum_size = Vector2(180, 180)
	_capture_btn.position = Vector2((1080 - 180) / 2, 1920 - 280)

	var outer = StyleBoxFlat.new()
	outer.bg_color = Color.WHITE
	for p in ["corner_radius_top_left","corner_radius_top_right",
			  "corner_radius_bottom_left","corner_radius_bottom_right"]:
		outer.set(p, 90)
	outer.border_width_top    = 8
	outer.border_width_bottom = 8
	outer.border_width_left   = 8
	outer.border_width_right  = 8
	outer.border_color = COL_PRIMARY
	_capture_btn.add_theme_stylebox_override("normal", outer)

	var pressed_style = outer.duplicate()
	pressed_style.bg_color = COL_PRIMARY
	_capture_btn.add_theme_stylebox_override("pressed", pressed_style)

	_capture_btn.pressed.connect(_on_capture)
	ui.add_child(_capture_btn)

	# Hint label above shutter
	var hint = Label.new()
	hint.text = "Tap to capture"
	hint.position = Vector2(0, 1920 - 320)
	hint.size = Vector2(1080, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 34)
	hint.add_theme_color_override("font_color", COL_MUTED)
	ui.add_child(hint)

# ── Camera init ────────────────────────────────────────────────────────────────

func _init_camera() -> void:
	# Listen for feeds added after this node is ready (Android may delay discovery)
	CameraServer.camera_feed_added.connect(_on_feed_added)

	var count = CameraServer.get_feed_count()
	if count > 0:
		# Prefer back camera; fall back to first available
		var chosen: CameraFeed = null
		for i in range(count):
			var f: CameraFeed = CameraServer.get_feed(i)
			if f.feed_position == CameraFeed.FEED_BACK:
				chosen = f
				break
		if chosen == null:
			chosen = CameraServer.get_feed(0)
		_activate_feed(chosen)
	else:
		# No camera detected yet — wait for feed_added signal
		_no_cam_label.visible = true

func _on_feed_added(id: int) -> void:
	if _feed != null:
		return  # already have one
	_no_cam_label.visible = false
	_activate_feed(CameraServer.get_feed(id))

func _activate_feed(feed: CameraFeed) -> void:
	_feed = feed
	_feed.active = true

	_cam_texture = CameraTexture.new()
	_cam_texture.camera_feed_id = _feed.get_id()
	_cam_texture.which_feed = CameraTexture.FEED_RGBA
	_preview.texture = _cam_texture

# ── Capture ────────────────────────────────────────────────────────────────────

func _on_capture() -> void:
	if _feed == null:
		return

	# Flash effect
	_capture_btn.disabled = true
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)

	# Wait one rendered frame so the SubViewport has the latest camera frame
	await RenderingServer.frame_post_draw

	var img: Image = _sub_vp.get_texture().get_image()

	# Remove flash overlay
	flash.queue_free()

	if img == null or img.is_empty():
		push_error("Camera: failed to read frame from SubViewport")
		_capture_btn.disabled = false
		return

	_feed.active = false
	GameManager.set_image(_prepare_image(img))
	get_tree().change_scene_to_file(SCENE_DIFFICULTY)

func _on_back() -> void:
	if _feed:
		_feed.active = false
	get_tree().change_scene_to_file(SCENE_HOME)

# ── Image prep (same as ImagePickerPlugin) ─────────────────────────────────────

func _prepare_image(img: Image) -> Image:
	const MAX_SIZE = 1024
	var w := img.get_width()
	var h := img.get_height()
	var side := min(w, h)
	img = img.get_region(Rect2i((w - side) / 2, (h - side) / 2, side, side))
	if side > MAX_SIZE:
		img.resize(MAX_SIZE, MAX_SIZE, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	return img
