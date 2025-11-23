extends Node
# This is a cetralized place for all path resolution logic.


signal status_message

var own_dir: String: get = _get_own_dir
var installs_summary: Dictionary: get = _get_installs_summary
var cache_dir: String: get = _get_cache_dir
var game_dir: String: get = _get_game_dir
var next_install_dir: String: get = _get_next_install_dir
var userdata: String: get = _get_userdata_dir
var config: String: get = _get_config_dir
var savegames: String: get = _get_savegame_dir
var mods_stock: String: get = _get_mods_dir_default
var mods_user: String: get = _get_mods_dir_user
var sound_stock: String: get = _get_sound_dir_default
var sound_user: String: get = _get_sound_dir_user
var gfx_default: String: get = _get_gfx_dir_default
var gfx_user: String: get = _get_gfx_dir_user
var tileset_stock: String: get = _get_tileset_dir_default
var tileset_user: String: get = _get_tileset_dir_user
var font_user: String: get = _get_font_dir_user
var templates: String: get = _get_templates_dir
var memorial: String: get = _get_memorial_dir
var graveyard: String: get = _get_graveyard_dir
var mod_repo: String: get = _get_modrepo_dir
var tmp_dir: String: get = _get_tmp_dir
var utils_dir: String: get = _get_utils_dir
var save_backups: String: get = _get_save_backups_dir

var _last_active_install_name := ""
var _last_active_install_dir := ""


func _get_own_dir() -> String:
	
	# On macOS, use the standard Application Support directory
	if OS.get_name() == "OSX":
		var home_dir = OS.get_environment("HOME")
		var dabdoob_dir = ""
		if home_dir != "":
			dabdoob_dir = home_dir.path_join("Library").path_join("Application Support").path_join("Dabdoob")
		else:
			# Fallback if HOME environment variable is not available
			dabdoob_dir = OS.get_user_data_dir().get_base_dir().get_base_dir().get_base_dir().get_base_dir().path_join("Application Support").path_join("Dabdoob")
		
		# Ensure the directory exists with proper permissions
		if not DirAccess.dir_exists_absolute(dabdoob_dir):
			var err = DirAccess.make_dir_recursive_absolute(dabdoob_dir)
			if err == OK:
				# Set proper permissions for the newly created directory
				var chmod_output: Array = []
				var chmod_result = OS.execute("chmod", ["755", dabdoob_dir], chmod_output, true)
				if chmod_result != 0:
					print("Warning: Could not set permissions for Dabdoob directory")
			else:
				print("Error creating Dabdoob directory: ", err)
		
		return dabdoob_dir
	else:
		# On Windows and Linux, keep the current behavior (portable)
		var exe_path = OS.get_executable_path()
		if exe_path.is_empty():
			# Fallback if executable path is not available (can happen in some Linux environments)
			push_error("Unable to determine executable path, using current directory as fallback")
			return "."
		var base_dir = exe_path.get_base_dir()
		if base_dir.is_empty():
			push_error("Unable to determine base directory from executable path, using current directory as fallback")
			return "."
		return base_dir


func _get_installs_summary() -> Dictionary:
	
	var result = {}
	
	# Add error handling for directory operations
	var own_directory = Paths.own_dir
	if own_directory.is_empty():
		push_error("Own directory is empty, cannot get installs summary")
		return {}
	
	for game in ["dda", "tlg", "bn", "eod", "tish"]:
		var installs = {}
		var base_dir = own_directory.path_join(game)
		
		# Skip if base directory doesn't exist yet (first run)
		if not DirAccess.dir_exists_absolute(base_dir):
			continue
			
		var subdirs = FS.list_dir(base_dir)
		for subdir in subdirs:
			var info_file = base_dir.path_join(subdir).path_join(Helpers.INFO_FILENAME)
			if FileAccess.file_exists(info_file):
				var info = Helpers.load_json_file(info_file)
				if info and "name" in info:
					installs[info["name"]] = base_dir.path_join(subdir)
		if not installs.is_empty():
			result[game] = installs
	
	# Ensure that some installation of the game is set as active
	var game = Settings.read("game")
	if game:
		var active_name = Settings.read("active_install_" + game)
		if game in result:
			if (active_name == "") or (not active_name in result[game]):
				Settings.store("active_install_" + game, result[game].keys()[0])
	
	return result


func _get_cache_dir() -> String:
	
	return _get_own_dir().path_join("cache")


func _get_game_dir() -> String:

	var active_name = Settings.read("active_install_" + Settings.read("game"))
	
	if active_name == "":
		return _get_next_install_dir()
	elif active_name == _last_active_install_name:
		return _last_active_install_dir
	else:
		return _find_active_game_dir()


func _find_active_game_dir() -> String:
	
	var base_dir = _get_own_dir().path_join(Settings.read("game"))
	for subdir in FS.list_dir(base_dir):
		var curr_dir = base_dir.path_join(subdir)
		var info_file = curr_dir.path_join("catapult_install_info.json")
		if FileAccess.file_exists(info_file):
			var info = Helpers.load_json_file(info_file)
			if ("name" in info) and (info["name"] == Settings.read("active_install_" + Settings.read("game"))):
				_last_active_install_dir = curr_dir
				return curr_dir
	
	return ""


func _get_next_install_dir() -> String:
	# Finds a suitable directory name for a new game installation in the
	# multi-install system. The names follow the pattern "game0, game1, ..."
	
	var base_dir := _get_own_dir().path_join(Settings.read("game"))
	var dir_number := 0
	while DirAccess.dir_exists_absolute(base_dir.path_join("game" + str(dir_number))):
		dir_number += 1
	return base_dir.path_join("game" + str(dir_number))


func _get_userdata_dir() -> String:
	
	return _get_own_dir().path_join(Settings.read("game")).path_join("userdata")


func _get_config_dir() -> String:
	
	var game_dir = _get_game_dir()
	if game_dir == "" or not DirAccess.dir_exists_absolute(game_dir):
		return ""
	
	return _get_userdata_dir().path_join("config")


func _get_savegame_dir() -> String:
	
	return _get_userdata_dir().path_join("save")


func _get_mods_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_data_path = _get_app_bundle_data_path(game_dir)
		if app_bundle_data_path != "":
			return app_bundle_data_path.path_join("mods")
	
	return game_dir.path_join("data").path_join("mods")


func _get_mods_dir_user() -> String:
	
	return _get_userdata_dir().path_join("mods")


func _get_sound_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_data_path = _get_app_bundle_data_path(game_dir)
		if app_bundle_data_path != "":
			return app_bundle_data_path.path_join("sound")
	
	return game_dir.path_join("data").path_join("sound")


func _get_sound_dir_user() -> String:
	
	return _get_userdata_dir().path_join("sound")


func _get_gfx_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_gfx_path = _get_app_bundle_gfx_path(game_dir)
		if app_bundle_gfx_path != "":
			return app_bundle_gfx_path
	
	return game_dir.path_join("gfx")


func _get_gfx_dir_user() -> String:
	
	return _get_userdata_dir().path_join("gfx")


func _get_tileset_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_gfx_path = _get_app_bundle_gfx_path(game_dir)
		if app_bundle_gfx_path != "":
			return app_bundle_gfx_path
	
	return game_dir.path_join("gfx")


func _get_tileset_dir_user() -> String:
	
	return _get_userdata_dir().path_join("gfx")


func _get_font_dir_user() -> String:
	
	return _get_userdata_dir().path_join("font")


func _get_templates_dir() -> String:
	
	return _get_userdata_dir().path_join("templates")


func _get_memorial_dir() -> String:
	
	return _get_userdata_dir().path_join("memorial")


func _get_graveyard_dir() -> String:
	
	return _get_userdata_dir().path_join("graveyard")


func _get_modrepo_dir() -> String:
	
	return _get_own_dir().path_join(Settings.read("game")).path_join("mod_repo")


func _get_tmp_dir() -> String:
	
	return _get_own_dir().path_join(Settings.read("game")).path_join("tmp")


func _get_utils_dir() -> String:
	
	return _get_own_dir().path_join("utils")


func _get_save_backups_dir() -> String:
	
	return _get_own_dir().path_join(Settings.read("game")).path_join("save_backups")


func _get_app_bundle_gfx_path(game_dir: String) -> String:
	# Check if the game directory contains a .app bundle and return the gfx path inside it
	
	if game_dir == "":
		return ""
	
	var dir_contents = FS.list_dir(game_dir)
	
	for item in dir_contents:
		if item.ends_with(".app"):
			var app_path = game_dir.path_join(item)
			var resources_gfx_path = app_path.path_join("Contents").path_join("Resources").path_join("gfx")
			
			# Check if the gfx directory exists inside Contents/Resources
			if DirAccess.dir_exists_absolute(resources_gfx_path):
				return resources_gfx_path
	
	return ""


func _get_app_bundle_data_path(game_dir: String) -> String:
	# Check if the game directory contains a .app bundle and return the data path inside it
	
	if game_dir == "":
		return ""
	
	var dir_contents = FS.list_dir(game_dir)
	
	for item in dir_contents:
		if item.ends_with(".app"):
			var app_path = game_dir.path_join(item)
			var resources_data_path = app_path.path_join("Contents").path_join("Resources").path_join("data")
			
			# Check if the data directory exists inside Contents/Resources
			if DirAccess.dir_exists_absolute(resources_data_path):
				return resources_data_path
	
	return ""
