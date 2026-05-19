extends Node
## Cross-platform image picker.
##
## Android flow:
##   pick_image() → check media permission → request if missing →
##   wait for user response → open FileDialog in DCIM/Pictures
##
## Desktop flow:
##   pick_image() → FileDialog

signal image_ready(image: Image)
signal cancelled()

# Android permission names
const PERM_MEDIA   = "android.permission.READ_MEDIA_IMAGES"   # API 33+
const PERM_STORAGE = "android.permission.READ_EXTERNAL_STORAGE"  # API ≤ 32

var _file_dialog: FileDialog = null
var _android_plugin = null   # native GodotImagePicker singleton, if present

func _ready() -> void:
	if OS.get_name() == "Android":
		_init_android()
	else:
		_init_file_dialog()

# ── Init ───────────────────────────────────────────────────────────────────────

func _init_android() -> void:
	if Engine.has_singleton("GodotImagePicker"):
		_android_plugin = Engine.get_singleton("GodotImagePicker")
		_android_plugin.connect("image_picked", _on_android_image_picked)
		_android_plugin.connect("cancelled",    _on_android_cancelled)
	else:
		# FileDialog fallback — set up now, open only when pick_image() is called
		_init_file_dialog()

func _init_file_dialog() -> void:
	_file_dialog = FileDialog.new()
	_file_dialog.access    = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters   = PackedStringArray(["*.png,*.jpg,*.jpeg,*.bmp,*.webp ; Images"])
	_file_dialog.size      = Vector2i(960, 800)
	_file_dialog.file_selected.connect(_on_file_selected)
	_file_dialog.canceled.connect(_on_file_cancelled)
	# Must be in the scene tree before popup() works
	get_tree().root.call_deferred("add_child", _file_dialog)

# ── Public API ─────────────────────────────────────────────────────────────────

func pick_image() -> void:
	if _android_plugin:
		_android_plugin.pick_image()
	elif OS.get_name() == "Android":
		await _pick_android_with_permission()
	else:
		_open_file_dialog()

# ── Android permission flow ────────────────────────────────────────────────────

func _pick_android_with_permission() -> void:
	if _has_media_permission():
		_open_file_dialog()
		return

	# Ask the OS — this shows the system permission dialog.
	# OS.request_permissions() is asynchronous; we poll for up to ~3 s.
	OS.request_permissions()

	# Poll every 500 ms (max 6 attempts = 3 s) until the user responds.
	for _i in range(6):
		await get_tree().create_timer(0.5).timeout
		if _has_media_permission():
			_open_file_dialog()
			return

	# User denied or took too long — surface a clear message.
	push_warning("ImagePicker: media permission denied or not yet granted")
	emit_signal("cancelled")

func _has_media_permission() -> bool:
	var granted: PackedStringArray = OS.get_granted_permissions()
	return PERM_MEDIA in granted or PERM_STORAGE in granted

# ── Open FileDialog at gallery directory ───────────────────────────────────────

func _open_file_dialog() -> void:
	if _file_dialog == null:
		_init_file_dialog()
		# Let the deferred add_child complete before popup
		await get_tree().process_frame
		await get_tree().process_frame

	# Navigate to the best available photo directory
	var candidates: Array[String] = [
		OS.get_system_dir(OS.SYSTEM_DIR_DCIM),
		OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
		"/storage/emulated/0/DCIM/Camera",
		"/storage/emulated/0/DCIM",
		"/storage/emulated/0/Pictures",
		"/sdcard/DCIM/Camera",
		"/sdcard/DCIM",
		"/sdcard/Pictures",
	]
	for d in candidates:
		if d != "" and DirAccess.dir_exists_absolute(d):
			_file_dialog.current_dir = d
			break

	_file_dialog.popup_centered_ratio(0.95)

# ── Callbacks ──────────────────────────────────────────────────────────────────

func _on_android_image_picked(path: String) -> void:
	_load_and_emit(path)

func _on_android_cancelled() -> void:
	emit_signal("cancelled")

func _on_file_selected(path: String) -> void:
	_load_and_emit(path)

func _on_file_cancelled() -> void:
	emit_signal("cancelled")

# ── Image loading & preparation ────────────────────────────────────────────────

func _load_and_emit(path: String) -> void:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		push_error("ImagePicker: failed to load '%s' (err %d)" % [path, err])
		emit_signal("cancelled")
		return
	img = _prepare_image(img)
	GameManager.set_image(img)
	GameManager.selected_image_path = path
	emit_signal("image_ready", img)

# Square-crop from centre + cap resolution for low-end device performance.
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
