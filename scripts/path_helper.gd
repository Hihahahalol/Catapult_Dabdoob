extends Node
# This is a cetralized place for all path resolution logic.


signal status_message

var own_dir: String setget , _get_own_dir
var installs_summary: Dictionary setget , _get_installs_summary
var cache_dir: String setget , _get_cache_dir
var game_dir: String setget , _get_game_dir
var next_install_dir: String setget , _get_next_install_dir
var userdata: String setget , _get_userdata_dir
var config: String setget , _get_config_dir
var savegames: String setget , _get_savegame_dir
var mods_stock: String setget , _get_mods_dir_default
var mods_user: String setget , _get_mods_dir_user
var sound_stock: String setget , _get_sound_dir_default
var sound_user: String setget , _get_sound_dir_user
var gfx_default: String setget , _get_gfx_dir_default
var gfx_user: String setget , _get_gfx_dir_user
var tileset_stock: String setget , _get_tileset_dir_default
var tileset_user: String setget , _get_tileset_dir_user
var font_user: String setget , _get_font_dir_user
var templates: String setget , _get_templates_dir
var memorial: String setget , _get_memorial_dir
var graveyard: String setget , _get_graveyard_dir
var mod_repo: String setget , _get_modrepo_dir
var tmp_dir: String setget , _get_tmp_dir
var utils_dir: String setget , _get_utils_dir
var save_backups: String setget , _get_save_backups_dir

var _last_active_install_name := ""
var _last_active_install_dir := ""


func _get_own_dir() -> String:
	
	# On macOS, use the standard Application Support directory
	if OS.get_name() == "OSX":
		var home_dir = OS.get_environment("HOME")
		if home_dir != "":
			return home_dir.plus_file("Library").plus_file("Application Support").plus_file("Dabdoob")
		else:
			# Fallback if HOME environment variable is not available
			return OS.get_user_data_dir().get_base_dir().get_base_dir().get_base_dir().get_base_dir().plus_file("Application Support").plus_file("Dabdoob")
	else:
		# On Windows and Linux, keep the current behavior (portable)
		return OS.get_executable_path().get_base_dir()


func _get_installs_summary() -> Dictionary:
	
	var result = {}
	var d = Directory.new()
	
	for game in ["dda", "tlg", "bn", "eod", "tish"]:
		var installs = {}
		var base_dir = Paths.own_dir.plus_file(game)
		for subdir in FS.list_dir(base_dir):
			var info_file = base_dir.plus_file(subdir).plus_file(Helpers.INFO_FILENAME)
			if d.file_exists(info_file):
				var info = Helpers.load_json_file(info_file)
				installs[info["name"]] = base_dir.plus_file(subdir)
		if not installs.empty():
			result[game] = installs
	
	# Ensure that some installation of the game is set as active
	var game = Settings.read("game")
	var active_name = Settings.read("active_install_" + game)
	if game in result:
		if (active_name == "") or (not active_name in result[game]):
			Settings.store("active_install_" + game, result[game].keys()[0])
	
	return result


func _get_cache_dir() -> String:
	
	return _get_own_dir().plus_file("cache")


func _get_game_dir() -> String:

	var active_name = Settings.read("active_install_" + Settings.read("game"))
	
	if active_name == "":
		return _get_next_install_dir()
	elif active_name == _last_active_install_name:
		return _last_active_install_dir
	else:
		return _find_active_game_dir()


func _find_active_game_dir() -> String:
	
	var d = Directory.new()
	var base_dir = _get_own_dir().plus_file(Settings.read("game"))
	for subdir in FS.list_dir(base_dir):
		var curr_dir = base_dir.plus_file(subdir)
		var info_file = curr_dir.plus_file("catapult_install_info.json")
		if d.file_exists(info_file):
			var info = Helpers.load_json_file(info_file)
			if ("name" in info) and (info["name"] == Settings.read("active_install_" + Settings.read("game"))):
				_last_active_install_dir = curr_dir
				return curr_dir
	
	return ""


func _get_next_install_dir() -> String:
	# Finds a suitable directory name for a new game installation in the
	# multi-install system. The names follow the pattern "game0, game1, ..."
	
	var base_dir := _get_own_dir().plus_file(Settings.read("game"))
	var dir_number := 0
	var d := Directory.new()
	while d.dir_exists(base_dir.plus_file("game" + str(dir_number))):
		dir_number += 1
	return base_dir.plus_file("game" + str(dir_number))


func _get_userdata_dir() -> String:
	
	return _get_own_dir().plus_file(Settings.read("game")).plus_file("userdata")


func _get_config_dir() -> String:
	
	var game_dir = _get_game_dir()
	if game_dir == "" or not Directory.new().dir_exists(game_dir):
		return ""
	
	return _get_userdata_dir().plus_file("config")


func _get_savegame_dir() -> String:
	
	return _get_userdata_dir().plus_file("save")


func _get_mods_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_data_path = _get_app_bundle_data_path(game_dir)
		if app_bundle_data_path != "":
			return app_bundle_data_path.plus_file("mods")
	
	return game_dir.plus_file("data").plus_file("mods")


func _get_mods_dir_user() -> String:
	
	return _get_userdata_dir().plus_file("mods")


func _get_sound_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_data_path = _get_app_bundle_data_path(game_dir)
		if app_bundle_data_path != "":
			return app_bundle_data_path.plus_file("sound")
	
	return game_dir.plus_file("data").plus_file("sound")


func _get_sound_dir_user() -> String:
	
	return _get_userdata_dir().plus_file("sound")


func _get_gfx_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_gfx_path = _get_app_bundle_gfx_path(game_dir)
		if app_bundle_gfx_path != "":
			return app_bundle_gfx_path
	
	return game_dir.plus_file("gfx")


func _get_gfx_dir_user() -> String:
	
	return _get_userdata_dir().plus_file("gfx")


func _get_tileset_dir_default() -> String:
	
	var game_dir = _get_game_dir()
	
	# On macOS, check if the game is packaged as an .app bundle
	if OS.get_name() == "OSX":
		var app_bundle_gfx_path = _get_app_bundle_gfx_path(game_dir)
		if app_bundle_gfx_path != "":
			return app_bundle_gfx_path
	
	return game_dir.plus_file("gfx")


func _get_tileset_dir_user() -> String:
	
	return _get_userdata_dir().plus_file("gfx")


func _get_font_dir_user() -> String:
	
	return _get_userdata_dir().plus_file("font")


func _get_templates_dir() -> String:
	
	return _get_userdata_dir().plus_file("templates")


func _get_memorial_dir() -> String:
	
	return _get_userdata_dir().plus_file("memorial")


func _get_graveyard_dir() -> String:
	
	return _get_userdata_dir().plus_file("graveyard")


func _get_modrepo_dir() -> String:
	
	return _get_own_dir().plus_file(Settings.read("game")).plus_file("mod_repo")


func _get_tmp_dir() -> String:
	
	return _get_own_dir().plus_file(Settings.read("game")).plus_file("tmp")


func _get_utils_dir() -> String:
	
	return _get_own_dir().plus_file("utils")


func _get_save_backups_dir() -> String:
	
	return _get_own_dir().plus_file(Settings.read("game")).plus_file("save_backups")


func _get_app_bundle_gfx_path(game_dir: String) -> String:
	# Check if the game directory contains a .app bundle and return the gfx path inside it
	
	if game_dir == "":
		return ""
	
	var d = Directory.new()
	var dir_contents = FS.list_dir(game_dir)
	
	for item in dir_contents:
		if item.ends_with(".app"):
			var app_path = game_dir.plus_file(item)
			var resources_gfx_path = app_path.plus_file("Contents").plus_file("Resources").plus_file("gfx")
			
			# Check if the gfx directory exists inside Contents/Resources
			if d.dir_exists(resources_gfx_path):
				return resources_gfx_path
	
	return ""


func _get_app_bundle_data_path(game_dir: String) -> String:
	# Check if the game directory contains a .app bundle and return the data path inside it
	
	if game_dir == "":
		return ""
	
	var d = Directory.new()
	var dir_contents = FS.list_dir(game_dir)
	
	for item in dir_contents:
		if item.ends_with(".app"):
			var app_path = game_dir.plus_file(item)
			var resources_data_path = app_path.plus_file("Contents").plus_file("Resources").plus_file("data")
			
			# Check if the data directory exists inside Contents/Resources
			if d.dir_exists(resources_data_path):
				return resources_data_path
	
	return ""
