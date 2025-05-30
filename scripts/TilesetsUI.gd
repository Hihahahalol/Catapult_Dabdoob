extends VBoxContainer


onready var _tileset = $"/root/Catapult/Tileset"
onready var _installed_list = $HBox/Installed/InstalledList
onready var _available_list = $HBox/Downloadable/AvailableList
onready var _btn_delete = $HBox/Installed/BtnDelete
onready var _btn_install = $HBox/Downloadable/BtnInstall
onready var _dlg_confirm_del = $ConfirmDelete
onready var _dlg_manual_dl = $ConfirmManualDownload
onready var _dlg_file = $InstallFromFileDialog
onready var _cbox_stock = $HBox/Installed/ShowStock
onready var _preview_image = $PreviewArea/PreviewImage
onready var _no_preview_label = $PreviewArea/NoPreviewLabel

var _installed_tilesets = []


func refresh_installed() -> void:
	
	_installed_tilesets = _tileset.get_installed(Settings.read("show_stock_tilesets"))
		
	_installed_list.clear()
	for tileset in _installed_tilesets:
		_installed_list.add_item(tileset["name"])
		print("Debug: Installed tileset: ", tileset["name"])
		var desc = ""
		if tileset["description"] == "":
			desc = tr("str_no_tileset_desc")
		else:
			desc = _break_up_string(tileset["description"], 60)
		_installed_list.set_item_tooltip(_installed_list.get_item_count() - 1, desc)
	
	# Hide preview when refreshing since selection is cleared
	_hide_preview()


func _break_up_string(text: String, approx_width_chars: int) -> String:
	
	var result = text
	
	for pos in range(approx_width_chars, len(result), approx_width_chars):
			
		while true:
			if result[pos] == " ":
				result.erase(pos, 1)
				result = result.insert(pos, "\n")
				break
			else:
				pos -= 1
	
	return result


func _populate_available() -> void:
	
	_available_list.clear()
	for tileset in _tileset.TILESETS:
		_available_list.add_item(tileset["name"])
		print("Debug: Available tileset: ", tileset["name"])
		
		
func _is_tileset_installed(name: String) -> bool:
	
	for tileset in _installed_tilesets:
		if tileset["name"] == name:
			return true
			
	return false


func _on_Tabs_tab_changed(tab: int) -> void:
	
	if tab != 2:
		return
		
	_cbox_stock.pressed = Settings.read("show_stock_tilesets")
	
	_btn_delete.disabled = true
	_btn_install.disabled = true
	_btn_install.text = tr("btn_install_tilesets")
	
	_populate_available()
	refresh_installed()
	
	# Hide preview when tab is first opened
	_hide_preview()


func _on_ShowStock_toggled(button_pressed: bool) -> void:
	
	Settings.store("show_stock_tilesets", button_pressed)
	refresh_installed()


func _on_InstalledList_item_selected(index: int) -> void:
	
	if _installed_list.disabled:
		return  # https://github.com/godotengine/godot/issues/37277
	
	if len(_installed_tilesets) > 0:
		_btn_delete.disabled = _installed_tilesets[index]["is_stock"]
		# Show preview for selected installed tileset
		_show_tileset_preview(_installed_tilesets[index]["name"])
	else:
		_btn_delete.disabled = true
		_hide_preview()


func _on_BtnDelete_pressed() -> void:
	
	var name = _installed_tilesets[_installed_list.get_selected_items()[0]]["name"]
	_dlg_confirm_del.dialog_text = tr("dlg_tileset_deletion_text") % name
	_dlg_confirm_del.get_cancel().text = tr("btn_cancel")
	_dlg_confirm_del.rect_size = Vector2(200, 100)
	_dlg_confirm_del.popup_centered()


func _on_ConfirmDelete_confirmed() -> void:
	
	_tileset.delete_tileset(_installed_tilesets[_installed_list.get_selected_items()[0]]["name"])
	yield(_tileset, "tileset_deletion_finished")
	refresh_installed()
	
	if len(_installed_list.get_selected_items()) == 0:
		_btn_delete.disabled = true
		_hide_preview()


func _on_AvailableList_item_selected(index: int) -> void:
	
	if _installed_list.disabled:
		return  # https://github.com/godotengine/godot/issues/37277
	
	_btn_install.disabled = false
	var tileset_name = _tileset.TILESETS[index]["name"]
	if _is_tileset_installed(tileset_name):
		_btn_install.text = tr("btn_reinstall_tileset")
	else:
		_btn_install.text = tr("btn_install_tilesets")
	
	# Show preview for selected available tileset
	_show_tileset_preview(tileset_name)


func _on_BtnInstall_pressed() -> void:
	
	var tileset_index = _available_list.get_selected_items()[0]
	var tileset = _tileset.TILESETS[tileset_index]
	
	if ("manual_download" in tileset) and (tileset["manual_download"] == true):
		_dlg_manual_dl.rect_size = Vector2(300, 150)
		_dlg_manual_dl.get_cancel().text = tr("btn_cancel")
		_dlg_manual_dl.popup_centered()
	else:
		if _is_tileset_installed(tileset["name"]):
			_tileset.install_tileset(tileset_index, null, true)
		else:
			_tileset.install_tileset(tileset_index)
		yield(_tileset, "tileset_installation_finished")
		refresh_installed()


func _on_ConfirmManualDownload_confirmed() -> void:
	
	var tileset = _tileset.TILESETS[_available_list.get_selected_items()[0]]
	
	OS.shell_open(tileset["url"])
	_dlg_file.current_dir = Paths.own_dir
	_dlg_file.popup_centered_ratio(0.9)
	


func _on_InstallFromFileDialog_file_selected(path: String) -> void:
	
	var index = _available_list.get_selected_items()[0]
	var name = _tileset.TILESETS[index]["name"]
	
	if _is_tileset_installed(name):
		_tileset.install_tileset(index, path, true, true)
	else:
		_tileset.install_tileset(index, path, false, true)
	
	yield(_tileset, "tileset_installation_finished")
	refresh_installed()


# Map tileset names to preview image filenames
func _get_preview_filename_for_tileset(tileset_name: String) -> String:
	# Create a mapping of tileset names to preview image files
	var name_mappings = {
		"Altica": "Altica",
		"ASCIITileset2": "ASCIITileset2", 
		"BrownLikeBears": "BrownLikeBears",
		"ChestHole": "ChestHole",
		"ChibiUltica": "ChibiUltica",
		"Cuteclysm": "Cuteclysm",
		"HitButtonISO": "HitButtonISO",
		"Hoder Tileset": "Hoder Tileset",
		"HollowMoon": "HollowMoon",
		"MShockXotto+": "MShockXotto+",
		"NeoDaysTileset": "NeoDaysTileset", 
		"RetroDaysTileset": "RetroDaysTileset",
		"UltimateCataclysm": "UltimateCataclysm",
		"UndeadPeople": "UndeadPeople"
	}
	
	# Try exact match first
	if tileset_name in name_mappings:
		return name_mappings[tileset_name]
	
	# Try to find partial matches by checking if any key contains the tileset name or vice versa
	for key in name_mappings.keys():
		if key.to_lower().find(tileset_name.to_lower()) != -1 or tileset_name.to_lower().find(key.to_lower()) != -1:
			return name_mappings[key]
	
	# If no match found, try removing common suffixes like "(16x)", "(32x)", etc.
	var clean_name = tileset_name.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\s*\\([0-9]+x\\)\\s*$")  # Remove "(16x)" style suffixes
	clean_name = regex.sub(clean_name, "", true)
	
	if clean_name in name_mappings:
		return name_mappings[clean_name]
	
	# Try partial match with cleaned name
	for key in name_mappings.keys():
		if key.to_lower().find(clean_name.to_lower()) != -1 or clean_name.to_lower().find(key.to_lower()) != -1:
			return name_mappings[key]
	
	# Last resort: try using the tileset name directly as filename
	print("Debug: No mapping found, trying direct filename: ", tileset_name)
	return tileset_name


func _show_tileset_preview(tileset_name: String) -> void:
	var preview_filename = _get_preview_filename_for_tileset(tileset_name)
	
	print("Debug: Trying to show preview for tileset: ", tileset_name)
	print("Debug: Mapped to filename: ", preview_filename)
	
	if preview_filename != "":
		var preview_path = "res://images/tileset_previews/" + preview_filename + ".png"
		print("Debug: Full path: ", preview_path)
		
		# Try to load the texture directly first
		var texture = load(preview_path)
		print("Debug: Load result: ", texture)
		
		if texture != null:
			_preview_image.texture = texture
			_preview_image.visible = true
			_no_preview_label.visible = false
			print("Debug: Successfully loaded preview for: ", tileset_name)
			return
		else:
			print("Debug: Failed to load, trying alternative approaches...")
			
			# Check if the file exists in the filesystem
			var file = File.new()
			var file_exists = file.file_exists(preview_path)
			print("Debug: File exists check: ", file_exists)
			
			# Try a few common variations of the filename
			var variations = [
				preview_filename.to_lower(),
				preview_filename.replace(" ", ""),
				preview_filename.replace(" ", "_"),
				preview_filename.replace(" ", "-")
			]
			
			for variation in variations:
				var alt_path = "res://images/tileset_previews/" + variation + ".png"
				print("Debug: Trying variation: ", alt_path)
				var alt_texture = load(alt_path)
				if alt_texture != null:
					_preview_image.texture = alt_texture
					_preview_image.visible = true
					_no_preview_label.visible = false
					print("Debug: Successfully loaded alternative for: ", tileset_name)
					return
			
			print("Warning: Could not load texture for: " + preview_path)
	else:
		print("Debug: No preview filename mapping found for: ", tileset_name)
	
	# No preview available
	_preview_image.visible = false
	_preview_image.texture = null
	_no_preview_label.visible = true


func _hide_preview() -> void:
	_preview_image.visible = false
	_preview_image.texture = null
	_no_preview_label.visible = true 