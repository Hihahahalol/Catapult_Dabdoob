extends Node

# This script makes it possible to set the correct size and position
# for the window before it is shown.

# Thanks to github.com/Lauson1ex for helping me figure this out.

signal scale_changed

var scale: float: set = _set_scale
var min_base_size := Vector2(
		ProjectSettings.get("display/window/size/viewport_width"),
		ProjectSettings.get("display/window/size/viewport_height"))
var base_size := min_base_size

var decor_offset := Vector2.ZERO


func _set_scale(new_scale: float) -> void:
	
	scale = new_scale + 0.0004
	_apply_scale()
	emit_signal("scale_changed", scale)


func _apply_scale() -> void:
	
	get_window().min_size = min_base_size * scale
	get_window().set_size(base_size * scale)


func calculate_scale_from_dpi() -> float:
	
	var ratio = DisplayServer.screen_get_dpi() / 96.0
	return snapped(ratio, 0.125)


func save_window_state() -> void:
	
	var state := {
		"size_x": base_size.x,
		"size_y": base_size.y,
		"position_x": get_window().position.x,
		"position_y": get_window().position.y,
		"decor_offset_x": decor_offset.x,
		"decor_offset_y": decor_offset.y,
		}
	Settings.store("window_state", state)


func recover_window_state() -> void:
	
	var state: Dictionary = Settings.read("window_state")
	
	if state.is_empty():
		# Center the window manually in Godot 4
		var screen_size = DisplayServer.screen_get_size()
		var window_size = get_window().size
		get_window().position = Vector2i((screen_size.x - window_size.x) / 2, (screen_size.y - window_size.y) / 2)
		# Yield at least once to make this consistently a coroutine
		await get_tree().process_frame
		return
	
	base_size =  Vector2(state["size_x"] as float, state["size_y"] as float)
	var pos := Vector2(state["position_x"] as float, state["position_y"] as float)
	decor_offset = Vector2(state["decor_offset_x"] as float, state["decor_offset_y"] as float)
	pos += decor_offset
	get_window().position = Vector2i(pos)
	
	# In some environments (e.g. KDE) switching a window from borderless to
	# normal results in it shifting down by the height of the window title.
	# The code below works around this by detecting when decorations actually
	# get added to the window (there is a measurable delay before that happens)
	# and storing the resulting offset for compensation on the next launch.
	
	# Add timeout to prevent infinite loop (max 50 frames = ~0.8 seconds at 60fps)
	var frame_count = 0
	var max_frames = 50
	while Vector2i(get_window().size) == Vector2i(get_window().get_size_with_decorations()) and frame_count < max_frames:
		await get_tree().process_frame
		frame_count += 1
	
	# Only update decor_offset if we actually detected a change
	if frame_count < max_frames:
		decor_offset = pos - Vector2(get_window().position)
	else:
		# Timeout reached - window decorations didn't change, keep existing offset
		push_warning("Window decoration detection timed out after " + str(max_frames) + " frames")


func _on_SceneTree_idle():
	
	await get_tree().process_frame
	
	# Disable per-pixel transparency IMMEDIATELY to fix Linux input issues
	# Must be done before any deferred calls and BEFORE window state recovery
	get_window().transparent = false
	ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed", false)
	
	# On Linux, we need to wait for the window system to process the transparency change
	# before we can reliably receive input events
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for Linux window managers
	
	# Keep window borderless to use custom title bar
	# In Godot 4, window icon is set via project settings, not at runtime
	# DisplayServer.window_set_icon() would be used if needed
	
	# Recover window state after transparency is disabled
	# In Godot 4, await handles coroutines automatically
	await recover_window_state()
	_apply_scale()
	
	# Ensure the window has focus after all setup is complete
	# This is critical on Linux with borderless windows
	await get_tree().process_frame
	get_window().mode = Window.MODE_MINIMIZED if (false  ) else Window.MODE_WINDOWED# Ensure not minimized
	# Note: There's no direct "focus window" in Godot, but ensuring it's not minimized helps


func _ready():
	
	if Settings.read("ui_scale_override_enabled"):
		_set_scale(Settings.read("ui_scale_override") as float)
	else:
		_set_scale(calculate_scale_from_dpi())

	_on_SceneTree_idle()


func _on_window_resized() -> void:
	
	base_size = get_window().size / scale


func _exit_tree() -> void:
	
	save_window_state()
