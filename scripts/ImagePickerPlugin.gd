extends Node
## Cross-platform image picker.
## On Android it delegates to a native plugin (or simulates for testing).
## On desktop it uses Godot's FileDialog.

signal image_ready(image: Image)   # Emitted with loaded Image on success
signal cancelled()                  # Emitted when user cancels

var _file_dialog: FileDialog = null
var _android_plugin = null  # Native plugin handle, if available

func _ready() -> void:
	if OS.get_name() == "Android":
		_init_android()
	else:
		_init_file_dialog()

# ── Android ───────────────────────────────────────────────────────────────────

func _init_android() -> void:
	# Try to grab the native plugin registered via Godot's Android plugin system.
	# The plugin must expose: pick_image() and signals image_picked(path), cancelled.
	if Engine.has_singleton("GodotImagePicker"):
		_android_plugin = Engine.get_singleton("GodotImagePicker")
		_android_plugin.connect("image_picked", _on_android_image_picked)
		_android_plugin.connect("cancelled", _on_android_cancelled)
	else:
		push_warning("ImagePicker: native Android plugin not found — falling back to FileDialog")
		_init_file_dialog()

func _on_android_image_picked(path: String) -> void:
	_load_and_emit(path)

func _on_android_cancelled() -> void:
	emit_signal("cancelled")

# ── Desktop / fallback ────────────────────────────────────────────────────────

func _init_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray([
		"*.png,*.jpg,*.jpeg,*.bmp,*.webp ; Images"
	])
	_file_dialog.size = Vector2i(900, 700)
	_file_dialog.file_selected.connect(_on_desktop_file_selected)
	_file_dialog.canceled.connect(_on_desktop_cancelled)
	# Dialog must live in the scene tree to display
	get_tree().root.add_child(_file_dialog)

func _on_desktop_file_selected(path: String) -> void:
	_load_and_emit(path)

func _on_desktop_cancelled() -> void:
	emit_signal("cancelled")

# ── Public API ─────────────────────────────────────────────────────────────────

func pick_image() -> void:
	if _android_plugin:
		_android_plugin.pick_image()
	elif _file_dialog:
		_file_dialog.popup_centered()
	else:
		push_error("ImagePicker: no backend available")

# ── Helpers ────────────────────────────────────────────────────────────────────

func _load_and_emit(path: String) -> void:
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		push_error("ImagePicker: failed to load image at '%s'" % path)
		emit_signal("cancelled")
		return
	# Normalise to a square crop and a capped resolution for performance
	img = _prepare_image(img)
	GameManager.set_image(img)
	GameManager.selected_image_path = path
	emit_signal("image_ready", img)

func _prepare_image(img: Image) -> Image:
	const MAX_SIZE = 1024  # keep memory reasonable on low-end devices

	# Square-crop from centre
	var w = img.get_width()
	var h = img.get_height()
	var side = min(w, h)
	var x_offset = (w - side) / 2
	var y_offset = (h - side) / 2
	img = img.get_region(Rect2i(x_offset, y_offset, side, side))

	# Downscale if needed
	if side > MAX_SIZE:
		img.resize(MAX_SIZE, MAX_SIZE, Image.INTERPOLATE_LANCZOS)

	# Ensure RGBA8 format
	img.convert(Image.FORMAT_RGBA8)
	return img
