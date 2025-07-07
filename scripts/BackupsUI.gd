extends VBoxContainer


onready var _backups = $"/root/Catapult/Backups"
onready var _edit_name = $Current/HBox/EditName
onready var _btn_create = $Current/HBox/BtnCreate
onready var _list_backups = $Available/HBox/BackupsList
onready var _btn_refresh = $Available/Buttons/BtnRefresh
onready var _btn_restore = $Available/Buttons/BtnRestore
onready var _btn_delete = $Available/Buttons/BtnDelete
onready var _lbl_info = $Available/HBox/BackupInfo
# Reference to automatic backup control
onready var _cb_backup_before_launch = $BackupBeforeLaunch
onready var _cb_backup_after_closing = $BackupAfterClosing
onready var _sb_max_auto_backups = $MaxAutoBackups/sbMaxAutoBackups


func _ready() -> void:
	# Initialize automatic backup controls from settings
	_cb_backup_before_launch.pressed = Settings.read("backup_before_launch")
	_cb_backup_after_closing.pressed = Settings.read("backup_after_closing")
	_sb_max_auto_backups.value = Settings.read("max_auto_backups")
	
	# Connect signals for automatic backup controls
	_cb_backup_before_launch.connect("toggled", self, "_on_BackupBeforeLaunch_toggled")
	_cb_backup_after_closing.connect("toggled", self, "_on_BackupAfterClosing_toggled")
	_sb_max_auto_backups.connect("value_changed", self, "_on_MaxAutoBackups_value_changed")
	
	# Connect keyboard input for delete key
	_list_backups.connect("gui_input", self, "_on_BackupsList_input")


func _refresh_available() -> void:
	
	_list_backups.clear()
	_btn_restore.disabled = true
	_btn_delete.disabled = true
	_lbl_info.bbcode_text = tr("lbl_backup_info_placeholder")
	_backups.refresh_available()

	for item in _backups.available:
		_list_backups.add_item(item["name"])


func _populate_default_new_name() -> void:
	
	var datetime = OS.get_datetime()
	_edit_name.text = "Manual_%02d-%02d-%02d_%02d-%02d" % [
		datetime["year"] % 100,
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
	]


func _on_Tabs_tab_changed(tab: int) -> void:
	
	if tab != 5:
		return
	
	_refresh_available()
	_populate_default_new_name()


## Update the default backup filename when the app gains focus.
func _notification(what: int) -> void:

	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		_populate_default_new_name()


func _on_BtnCreate_pressed():

	var target_file = _edit_name.text
	if target_file.is_valid_filename():
		_backups.backup_current(target_file)
		yield(_backups, "backup_creation_finished")
		_refresh_available()


func _on_EditName_text_entered(new_text):
	
	_on_BtnCreate_pressed()


func _on_BtnRefresh_pressed():

	_refresh_available()


func _on_BtnRestore_pressed():

	if not _list_backups.is_anything_selected():
		return
	
	var selected_items = _list_backups.get_selected_items()
	if selected_items.size() > 1:
		# Cannot restore multiple backups at once
		return
	
	var idx = selected_items[0]
	_backups.restore(idx)


func _on_BtnDelete_pressed():
	
	if not _list_backups.is_anything_selected():
		return
	
	var selected_items = _list_backups.get_selected_items()
	var backup_names = []
	
	for idx in selected_items:
		backup_names.append(_list_backups.get_item_text(idx))
	
	if backup_names.size() == 1:
		# Single deletion
		_backups.delete(backup_names[0])
		yield(_backups, "backup_deletion_finished")
	elif backup_names.size() > 1:
		# Batch deletion
		_backups.delete_multiple(backup_names)
		yield(_backups, "backup_batch_deletion_finished")
	
	_refresh_available()


func _on_EditName_text_changed(new_text: String):
	
	# This disallows Windows' invalid characters as well as text that is empty or has leading or
	# trailing whitespace. These rules are used regardless of the active OS.
	_btn_create.disabled = not new_text.is_valid_filename()
	
	# Keep normal color if text is empty to avoid red placeholder text.
	if (new_text == "") or (new_text.is_valid_filename()):
		_edit_name.add_color_override("font_color", get_color("font_color", "LineEdit"))
	else:
		_edit_name.add_color_override("font_color", Color.red)


func _on_BackupsList_item_selected(index):
	
	var selected_items = _list_backups.get_selected_items()
	
	# Enable/disable buttons based on selection
	_btn_delete.disabled = selected_items.empty()
	_btn_restore.disabled = selected_items.empty() or selected_items.size() > 1
	
	# Update info display
	if selected_items.size() == 1:
		_lbl_info.bbcode_text = _make_backup_info_string(selected_items[0])
	elif selected_items.size() > 1:
		_lbl_info.bbcode_text = _make_multi_selection_info_string(selected_items)
	else:
		_lbl_info.bbcode_text = tr("lbl_backup_info_placeholder")


func _on_BackupsList_multi_selected(index: int, selected: bool) -> void:
	# Handle multi-selection events (called when items are selected/deselected with Ctrl/Shift)
	_on_BackupsList_item_selected(index)


func _make_backup_info_string(index: int) -> String:
	
	var text := ""
	var info: Dictionary = _backups.available[index]
	
	var worlds_str := ""
	for world in info["worlds"]:
		worlds_str += world + ", "
	worlds_str = worlds_str.substr(0, len(worlds_str) - 2)
	
	text += "[u]%s[/u]\n[color=#3b93f7][url=%s]%s[/url][/color]\n\n" % [tr("backup_info_location"), info["path"], info["path"]]
	text += "[u]%s[/u]\n%s" % [tr("backup_info_worlds"), worlds_str]
	
	return text


func _on_BackupInfo_meta_clicked(meta) -> void:
	
	_open_directory(meta)


func _open_directory(path: String) -> void:
	# Cross-platform directory opening that handles paths with spaces properly
	
	if OS.get_name() == "OSX":
		# On macOS, use the 'open' command which handles spaces properly
		OS.execute("open", [path], false)
	else:
		# On Windows and Linux, use the standard shell_open
		OS.shell_open(path)


# Handlers for automatic backup controls
func _on_BackupBeforeLaunch_toggled(button_pressed: bool) -> void:
	Settings.store("backup_before_launch", button_pressed)


func _on_BackupAfterClosing_toggled(button_pressed: bool) -> void:
	Settings.store("backup_after_closing", button_pressed)


func _on_MaxAutoBackups_value_changed(value: int) -> void:
	Settings.store("max_auto_backups", value)


func _on_BackupsList_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_DELETE:
			_on_BtnDelete_pressed()


func _make_multi_selection_info_string(selected_indices: Array) -> String:
	var text := ""
	text += "[u]%s[/u]\n" % tr("backup_info_multiple_selected")
	text += tr("backup_info_selected_count") % selected_indices.size()
	text += "\n\n"
	
	# List selected backup names
	for i in range(min(selected_indices.size(), 10)):  # Limit to first 10 for display
		var index = selected_indices[i]
		text += "• %s\n" % _list_backups.get_item_text(index)
	
	if selected_indices.size() > 10:
		text += "• ... %s %s\n" % [tr("and"), selected_indices.size() - 10, tr("more")]
	
	return text
