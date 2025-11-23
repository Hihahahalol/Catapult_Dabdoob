extends Node


signal tileset_installation_started
signal tileset_installation_finished
signal tileset_deletion_started
signal tileset_deletion_finished


const TILESETS = [
]


func parse_tileset_dir(tileset_dir: String) -> Array:
	
	if not DirAccess.dir_exists_absolute(tileset_dir):
		Status.post(tr("msg_no_tileset_dir") % tileset_dir, Enums.MSG_ERROR)
		return []
	
	var result = []
	
	for subdir in FS.list_dir(tileset_dir):
		var info = tileset_dir.path_join(subdir).path_join("tile_config.json")
		if FileAccess.file_exists(info):
			var f = FileAccess.open(info, FileAccess.READ)
			var json_text = f.get_as_text()
			var test_json_conv = JSON.new()
			var parse_error = test_json_conv.parse(json_text)
			var name = ""
			var desc = ""
			if parse_error == OK and test_json_conv.data is Dictionary:
				var data = test_json_conv.data
				if "tile_info" in data and data["tile_info"] is Array and data["tile_info"].size() > 0:
					var tile_info = data["tile_info"][0]
					if "pixelscale" in tile_info:
						name = subdir + " (" + str(tile_info["pixelscale"]) + "x)"
					else:
						name = subdir
					if "name" in tile_info:
						desc = tile_info["name"]
			if name == "":
				name = subdir
			var item = {}
			item["name"] = name
			item["description"] = desc
			item["location"] = tileset_dir.path_join(subdir)
			result.append(item)
			f.close()
		
	return result


func get_installed(include_stock = false) -> Array:
	
	var tilesets = []
	
	if DirAccess.dir_exists_absolute(Paths.tileset_user):
		tilesets.append_array(parse_tileset_dir(Paths.tileset_user))
		for tileset in tilesets:
			tileset["is_stock"] = false
	
	if include_stock:
		var stock = parse_tileset_dir(Paths.tileset_stock)
		for tileset in stock:
			tileset["is_stock"] = true
		tilesets.append_array(stock)
		
	return tilesets


func delete_tileset(name: String) -> void:
	
	for tileset in get_installed():
		if tileset["name"] == name:
			emit_signal("tileset_deletion_started")
			Status.post(tr("msg_deleting_tileset") % tileset["location"])
			FS.rm_dir(tileset["location"])
			await FS.rm_dir_done
			emit_signal("tileset_deletion_finished")
			return
			
	Status.post(tr("msg_tileset_not_found") % name, Enums.MSG_ERROR)


func install_tileset(tileset_index: int, from_file = null, reinstall = false, keep_archive = false) -> void:
	
	var tileset = TILESETS[tileset_index]
	var game = Settings.read("game")
	var tileset_dir = Paths.tileset_user
	var tmp_dir = Paths.tmp_dir.path_join(tileset["name"])
	var archive = ""
	
	emit_signal("tileset_installation_started")
	
	if reinstall:
		Status.post(tr("msg_reinstalling_tileset") % tileset["name"])
	else:
		Status.post(tr("msg_installing_tileset") % tileset["name"])
	
	if from_file:
		archive = from_file
	else:
		archive = Paths.cache_dir.path_join(tileset["filename"])
		if Settings.read("ignore_cache") or not FileAccess.file_exists(archive):
			Downloader.download_file(tileset["url"], Paths.cache_dir, tileset["filename"])
			await Downloader.download_finished
		if not FileAccess.file_exists(archive):
			Status.post(tr("msg_tileset_download_failed"), Enums.MSG_ERROR)
			emit_signal("tileset_installation_finished")
			return
		
	if reinstall:
		FS.rm_dir(tileset_dir.path_join(tileset["name"]))
		await FS.rm_dir_done
		
	FS.extract(archive, tmp_dir)
	await FS.extract_done
	if not keep_archive and not Settings.read("keep_cache"):
		DirAccess.remove_absolute(archive)
	
	if FS.last_extract_result == 0:
		# Check if the expected directory exists after extraction
		var source_path = tmp_dir.path_join(tileset["internal_path"])
		if DirAccess.dir_exists_absolute(source_path):
			FS.move_dir(source_path, tileset_dir.path_join(tileset["name"]))
			await FS.move_dir_done
			
			# On macOS, ensure proper permissions for the installed tileset
			if OS.get_name() == "OSX":
				var installed_tileset_path = tileset_dir.path_join(tileset["name"])
				var chmod_output: Array = []
				var chmod_result = OS.execute("chmod", ["-R", "755", installed_tileset_path], chmod_output, true)
				if chmod_result != 0:
					Status.post("Warning: Could not set tileset directory permissions", Enums.MSG_WARN)
			
			Status.post(tr("msg_tileset_installed"))
		else:
			Status.post(tr("msg_tileset_extraction_failed") % tileset["internal_path"], Enums.MSG_ERROR)
			Status.post(tr("msg_tileset_extraction_debug") % [tmp_dir, FS.list_dir(tmp_dir)], Enums.MSG_DEBUG)
	else:
		Status.post(tr("msg_tileset_extraction_error") % FS.last_extract_result, Enums.MSG_ERROR)
	
	# Clean up temporary directory
	FS.rm_dir(tmp_dir)
	await FS.rm_dir_done
	
	emit_signal("tileset_installation_finished") 