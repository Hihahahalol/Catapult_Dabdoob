extends Node


signal tileset_installation_started
signal tileset_installation_finished
signal tileset_deletion_started
signal tileset_deletion_finished


const TILESETS = [
	{
		"name": "Currently there are no supported tilesets",
		"url": "https://github.com/I-am-Erk/CDDA-Tilesets/releases/latest/download/MSXotto.zip",
		"filename": "Currently there are no supported tilesets.zip",
		"internal_path": "Currently there are no supported tilesets",
	},
]


func parse_tileset_dir(tileset_dir: String) -> Array:
	
	if not Directory.new().dir_exists(tileset_dir):
		Status.post(tr("msg_no_tileset_dir") % tileset_dir, Enums.MSG_ERROR)
		return []
	
	var result = []
	
	for subdir in FS.list_dir(tileset_dir):
		var f = File.new()
		var info = tileset_dir.plus_file(subdir).plus_file("tile_config.json")
		if f.file_exists(info):
			f.open(info, File.READ)
			var json_text = f.get_as_text()
			var json = JSON.parse(json_text)
			var name = ""
			var desc = ""
			if json.error == OK and json.result is Dictionary:
				var data = json.result
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
			item["location"] = tileset_dir.plus_file(subdir)
			result.append(item)
			f.close()
		
	return result


func get_installed(include_stock = false) -> Array:
	
	var tilesets = []
	
	if Directory.new().dir_exists(Paths.tileset_user):
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
			yield(FS, "rm_dir_done")
			emit_signal("tileset_deletion_finished")
			return
			
	Status.post(tr("msg_tileset_not_found") % name, Enums.MSG_ERROR)


func install_tileset(tileset_index: int, from_file = null, reinstall = false, keep_archive = false) -> void:
	
	var tileset = TILESETS[tileset_index]
	var game = Settings.read("game")
	var tileset_dir = Paths.tileset_user
	var tmp_dir = Paths.tmp_dir.plus_file(tileset["name"])
	var archive = ""
	
	emit_signal("tileset_installation_started")
	
	if reinstall:
		Status.post(tr("msg_reinstalling_tileset") % tileset["name"])
	else:
		Status.post(tr("msg_installing_tileset") % tileset["name"])
	
	if from_file:
		archive = from_file
	else:
		archive = Paths.cache_dir.plus_file(tileset["filename"])
		if Settings.read("ignore_cache") or not Directory.new().file_exists(archive):
			Downloader.download_file(tileset["url"], Paths.cache_dir, tileset["filename"])
			yield(Downloader, "download_finished")
		if not Directory.new().file_exists(archive):
			Status.post(tr("msg_tileset_download_failed"), Enums.MSG_ERROR)
			emit_signal("tileset_installation_finished")
			return
		
	if reinstall:
		FS.rm_dir(tileset_dir.plus_file(tileset["name"]))
		yield(FS, "rm_dir_done")
		
	FS.extract(archive, tmp_dir)
	yield(FS, "extract_done")
	if not keep_archive and not Settings.read("keep_cache"):
		Directory.new().remove(archive)
	
	if FS.last_extract_result == 0:
		# Check if the expected directory exists after extraction
		var source_path = tmp_dir.plus_file(tileset["internal_path"])
		if Directory.new().dir_exists(source_path):
			FS.move_dir(source_path, tileset_dir.plus_file(tileset["name"]))
			yield(FS, "move_dir_done")
			
			# On macOS, ensure proper permissions for the installed tileset
			if OS.get_name() == "OSX":
				var installed_tileset_path = tileset_dir.plus_file(tileset["name"])
				var chmod_result = OS.execute("chmod", ["-R", "755", installed_tileset_path], true)
				if chmod_result != 0:
					Status.post("Warning: Could not set tileset directory permissions", Enums.MSG_WARNING)
			
			Status.post(tr("msg_tileset_installed"))
		else:
			Status.post(tr("msg_tileset_extraction_failed") % tileset["internal_path"], Enums.MSG_ERROR)
			Status.post(tr("msg_tileset_extraction_debug") % [tmp_dir, FS.list_dir(tmp_dir)], Enums.MSG_DEBUG)
	else:
		Status.post(tr("msg_tileset_extraction_error") % FS.last_extract_result, Enums.MSG_ERROR)
	
	# Clean up temporary directory
	FS.rm_dir(tmp_dir)
	yield(FS, "rm_dir_done")
	
	emit_signal("tileset_installation_finished") 