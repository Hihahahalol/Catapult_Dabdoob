extends Node


signal operation_started
signal operation_finished


func install_release(release_info: Dictionary, game: String, update_in: String = "") -> void:
	
	emit_signal("operation_started")
	
	if update_in:
		Status.post(tr("msg_updating_game") % release_info["name"])
	else:
		Status.post(tr("msg_installing_game") % release_info["name"])
	
	var archive: String = Paths.cache_dir.plus_file(release_info["filename"])
	
	if Settings.read("ignore_cache") or not Directory.new().file_exists(archive):
		Downloader.download_file(release_info["url"], Paths.cache_dir, release_info["filename"])
		yield(Downloader, "download_finished")
	
	if Directory.new().file_exists(archive):
		
		FS.extract(archive, Paths.tmp_dir)
		yield(FS, "extract_done")
		if not Settings.read("keep_cache"):
			Directory.new().remove(archive)
		
		if FS.last_extract_result == 0:
		
			var extracted_root
			match OS.get_name():
				"X11":
					extracted_root = _find_game_root_directory(Paths.tmp_dir)
				"Windows":
					extracted_root = Paths.tmp_dir
				"OSX":
					extracted_root = _find_game_root_directory(Paths.tmp_dir)
			
			if extracted_root == "":
				Status.post(tr("msg_install_no_game_dir_found"), Enums.MSG_ERROR)
				emit_signal("operation_finished")
				return
			
			Helpers.create_info_file(extracted_root, release_info["name"])
			
			var target_dir: String
			if update_in:
				target_dir = update_in
				FS.rm_dir(target_dir)
				yield(FS, "rm_dir_done")
			else:
				target_dir = Paths.next_install_dir
			
			FS.move_dir(extracted_root, target_dir)
			yield(FS, "move_dir_done")
			
			# Set executable permissions on macOS/Linux after installation
			if OS.get_name() == "OSX" or OS.get_name() == "X11":
				_set_executable_permissions(target_dir)
			
			if update_in:
				Settings.store("active_install_" + Settings.read("game"), release_info["name"])
				Status.post(tr("msg_game_updated"))
			else:
				Status.post(tr("msg_game_installed"))
		else:
			Status.post(tr("msg_install_extract_failed") % FS.last_extract_result, Enums.MSG_ERROR)
	else:
		Status.post(tr("msg_install_archive_not_found") % archive, Enums.MSG_ERROR)
	
	emit_signal("operation_finished")


func _find_game_root_directory(temp_dir: String) -> String:
	# Find the actual game directory, filtering out macOS metadata and other unwanted directories
	
	var dir_contents = FS.list_dir(temp_dir)
	var potential_dirs = []
	
	for item in dir_contents:
		var full_path = temp_dir.plus_file(item)
		var d = Directory.new()
		
		# Skip macOS metadata directories and common unwanted folders
		if item.begins_with("__MACOSX") or item.begins_with(".") or item == "desktop.ini":
			continue
			
		if d.dir_exists(full_path):
			potential_dirs.append(item)
	
	if potential_dirs.empty():
		Status.post(tr("msg_install_no_valid_dirs_found"), Enums.MSG_ERROR)
		return ""
	
	# If there's only one valid directory, use it
	if potential_dirs.size() == 1:
		return temp_dir.plus_file(potential_dirs[0])
	
	# If multiple directories, try to find the one that looks like a game directory
	for dir_name in potential_dirs:
		var full_path = temp_dir.plus_file(dir_name)
		if _looks_like_game_directory(full_path):
			return full_path
	
	# Fallback to the first directory if no obvious game directory found
	Status.post(tr("msg_install_using_first_dir") % potential_dirs[0], Enums.MSG_WARNING)
	return temp_dir.plus_file(potential_dirs[0])


func _looks_like_game_directory(dir_path: String) -> bool:
	# Check if directory contains typical game files/structure
	
	var d = Directory.new()
	var contents = FS.list_dir(dir_path)
	
	# Look for common game executable patterns
	var game_executables = [
		"cataclysm-tiles", "cataclysm-bn-tiles", "cataclysm-tlg-tiles",
		"cataclysm-tiles.exe", "cataclysm-bn-tiles.exe", "cataclysm-tlg-tiles.exe"
	]
	
	for exe in game_executables:
		if d.file_exists(dir_path.plus_file(exe)):
			return true
	
	# Look for typical game directories
	var game_dirs = ["data", "gfx", "lang", "lua", "tools"]
	var found_dirs = 0
	
	for game_dir in game_dirs:
		if d.dir_exists(dir_path.plus_file(game_dir)):
			found_dirs += 1
	
	# If we found at least 2 typical game directories, it's likely the game root
	return found_dirs >= 2


func _set_executable_permissions(install_dir: String) -> void:
	# Set executable permissions for game binaries on Unix-like systems
	
	if OS.get_name() != "OSX" and OS.get_name() != "X11":
		return
	
	var d = Directory.new()
	var game_executables = [
		"cataclysm-tiles", "cataclysm-bn-tiles", "cataclysm-tlg-tiles",
		"cataclysm-eod-tiles", "cataclysm-tish-tiles"
	]
	
	for exe_name in game_executables:
		var exe_path = install_dir.plus_file(exe_name)
		if d.file_exists(exe_path):
			var result = OS.execute("chmod", ["+x", exe_path], true)
			if result == 0:
				Status.post(tr("msg_install_set_executable") % exe_name, Enums.MSG_DEBUG)
			else:
				Status.post(tr("msg_install_chmod_failed") % [exe_name, result], Enums.MSG_WARNING)
	
	# Also check for .app bundles and set permissions on their executables
	if OS.get_name() == "OSX":
		_set_app_bundle_permissions(install_dir)


func _set_app_bundle_permissions(install_dir: String) -> void:
	# Handle .app bundle executable permissions on macOS
	
	var contents = FS.list_dir(install_dir)
	var d = Directory.new()
	
	for item in contents:
		if item.ends_with(".app"):
			var app_path = install_dir.plus_file(item)
			var exe_path = app_path.plus_file("Contents").plus_file("MacOS")
			
			if d.dir_exists(exe_path):
				var exe_contents = FS.list_dir(exe_path)
				for exe_file in exe_contents:
					var full_exe_path = exe_path.plus_file(exe_file)
					if d.file_exists(full_exe_path):
						var result = OS.execute("chmod", ["+x", full_exe_path], true)
						if result == 0:
							Status.post(tr("msg_install_set_app_executable") % [item, exe_file], Enums.MSG_DEBUG)
						else:
							Status.post(tr("msg_install_app_chmod_failed") % [item, exe_file, result], Enums.MSG_WARNING)


func remove_release_by_name(name: String) -> void:
	
	emit_signal("operation_started")
	
	var installs := Paths.installs_summary
	var game = Settings.read("game")
	
	if (game in installs) and (name in installs[game]):
		Status.post(tr("msg_deleting_game") % name)
		var location = installs[game][name]
		FS.rm_dir(location)
		yield(FS, "rm_dir_done")
		Status.post(tr("msg_game_deleted"))
	else:
		Status.post(tr("msg_delete_not_found") % name, Enums.MSG_ERROR)
	
	emit_signal("operation_finished")
