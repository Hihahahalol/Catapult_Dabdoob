extends PanelContainer


export(Texture) var maximize_icon
export(Texture) var restore_icon

var dragging := false
var drag_start_position := Vector2.ZERO
var window_start_position := Vector2.ZERO
var is_maximized := false
var unmaximized_position := Vector2.ZERO
var unmaximized_size := Vector2.ZERO

onready var title_label = $MarginContainer/HBoxContainer/Title
onready var icon = $MarginContainer/HBoxContainer/Icon
onready var maximize_button = $MarginContainer/HBoxContainer/MaximizeButton
onready var close_button = $MarginContainer/HBoxContainer/CloseButton
onready var minimize_button = $MarginContainer/HBoxContainer/MinimizeButton


func _ready() -> void:
	# Load and set the window icon
	var app_icon = load("res://icons/appiconpng.png")
	if app_icon:
		icon.texture = app_icon
	
	# Set title from window
	title_label.text = OS.get_window_title()
	
	# Apply dark theme styling
	_apply_dark_theme()
	
	# Connect hover effects for close button
	close_button.connect("mouse_entered", self, "_on_close_button_mouse_entered")
	close_button.connect("mouse_exited", self, "_on_close_button_mouse_exited")
	
	# Connect hover effects for other buttons
	minimize_button.connect("mouse_entered", self, "_on_button_mouse_entered", [minimize_button])
	minimize_button.connect("mouse_exited", self, "_on_button_mouse_exited", [minimize_button])
	maximize_button.connect("mouse_entered", self, "_on_button_mouse_entered", [maximize_button])
	maximize_button.connect("mouse_exited", self, "_on_button_mouse_exited", [maximize_button])
	
	# Connect to scale changes
	Geom.connect("scale_changed", self, "_on_scale_changed")


func _apply_dark_theme() -> void:
	# Set dark background for title bar - use color that matches the launcher theme
	var style_box = StyleBoxFlat.new()
	
	# Get the theme from the parent panel to match its colors
	var parent_theme = get_parent().theme if get_parent() else null
	if parent_theme:
		# Try to get the panel background color from the theme
		var panel_style = parent_theme.get_stylebox("panel", "Panel")
		if panel_style and panel_style is StyleBoxFlat:
			# Use a slightly darker shade of the panel color for the title bar
			var base_color = panel_style.bg_color
			style_box.bg_color = base_color.darkened(0.1)
		else:
			# Fallback to dark gray
			style_box.bg_color = Color(0.2, 0.23, 0.25)
	else:
		style_box.bg_color = Color(0.2, 0.23, 0.25)
	
	style_box.border_color = Color(0.1, 0.1, 0.1)
	style_box.set_border_width_all(1)
	add_stylebox_override("panel", style_box)


func _on_scale_changed(_new_scale: float) -> void:
	# Title bar will automatically resize with the rest of the UI
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				# Start dragging - store where in the window the user clicked
				dragging = true
				drag_start_position = get_viewport().get_mouse_position()
			else:
				# Stop dragging
				dragging = false
		
		# Double-click to maximize/restore
		if event.button_index == BUTTON_LEFT and event.doubleclick:
			_toggle_maximize()
	
	elif event is InputEventMouseMotion:
		if dragging and not is_maximized:
			# Calculate screen mouse position and move window
			var mouse_screen_pos = get_viewport().get_mouse_position() + OS.window_position
			OS.window_position = mouse_screen_pos - drag_start_position


func _on_MinimizeButton_pressed() -> void:
	OS.window_minimized = true


func _on_MaximizeButton_pressed() -> void:
	_toggle_maximize()


func _toggle_maximize() -> void:
	if is_maximized:
		# Restore
		OS.window_maximized = false
		OS.window_position = unmaximized_position
		OS.window_size = unmaximized_size
		is_maximized = false
		maximize_button.texture_normal = maximize_icon
	else:
		# Maximize
		unmaximized_position = OS.window_position
		unmaximized_size = OS.window_size
		OS.window_maximized = true
		is_maximized = true
		maximize_button.texture_normal = restore_icon


func _on_CloseButton_pressed() -> void:
	get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)


func _on_close_button_mouse_entered() -> void:
	close_button.modulate = Color(1.2, 0.4, 0.4)  # Red tint on hover


func _on_close_button_mouse_exited() -> void:
	close_button.modulate = Color.white


func _on_button_mouse_entered(button: TextureButton) -> void:
	button.modulate = Color(1.3, 1.3, 1.3)  # Brighten on hover


func _on_button_mouse_exited(button: TextureButton) -> void:
	button.modulate = Color.white


func set_title(new_title: String) -> void:
	title_label.text = new_title

