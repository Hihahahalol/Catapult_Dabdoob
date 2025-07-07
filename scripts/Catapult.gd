extends Node


onready var _debug_ui = $Main/Tabs/Debug
onready var _log = $Main/Log
onready var _game_info = $Main/GameInfo
onready var _game_desc = $Main/GameInfo/Description
onready var _mod_info = $Main/Tabs/Mods/ModInfo
onready var _tabs = $Main/Tabs
onready var _mods = $Mods  
onready var _releases = $Releases
onready var _installer = $ReleaseInstaller
onready var _btn_install = $Main/Tabs/Game/BtnInstall
onready var _btn_refresh = $Main/Tabs/Game/Builds/BtnRefresh
onready var _changelog = $Main/Tabs/Game/ChangelogDialog
onready var _lbl_changelog = $Main/Tabs/Game/Channel/HBox/ChangelogLink
onready var _btn_game_dir = $Main/Tabs/Game/ActiveInstall/Build/GameDir
onready var _btn_user_dir = $Main/Tabs/Game/ActiveInstall/Build/UserDir
onready var _btn_play = $Main/Tabs/Game/ActiveInstall/Launch/BtnPlay
onready var _btn_resume = $Main/Tabs/Game/ActiveInstall/Launch/BtnResume
# Button removed - update check now happens automatically
onready var _btn_update = $Main/Tabs/Game/ActiveInstall/Update/BtnUpdate
onready var _lst_builds = $Main/Tabs/Game/Builds/BuildsList
onready var _lst_games = $Main/GameChoice/GamesList
onready var _rbtn_stable = $Main/Tabs/Game/Channel/Group/RBtnStable
onready var _rbtn_exper = $Main/Tabs/Game/Channel/Group/RBtnExperimental
onready var _lbl_build = $Main/Tabs/Game/ActiveInstall/Build/Name
onready var _cb_update = $Main/Tabs/Game/UpdateCurrent
onready var _lst_installs = $Main/Tabs/Game/GameInstalls/HBox/InstallsList
onready var _btn_make_active = $Main/Tabs/Game/GameInstalls/HBox/VBox/btnMakeActive
onready var _btn_delete = $Main/Tabs/Game/GameInstalls/HBox/VBox/btnDelete
onready var _panel_installs = $Main/Tabs/Game/GameInstalls
onready var _version_check_request = HTTPRequest.new()
onready var _cb_backup_before_launch = $Main/Tabs/Backups/BackupBeforeLaunch
onready var _backups = $Backups

var _disable_savestate := {}
var _installs := {}

# For UI scaling on the fly
var _base_min_sizes := {}
var _base_icon_sizes := {}

var _easter_egg_counter := 0

# Game process monitoring
var _game_process: OSExecWrapper = null
var _launcher_should_close_after_game := false

const VERSION_CHECK_URL = "https://api.github.com/repos/Hihahahalol/Catapult_Dabdoob/releases/latest"
var _latest_version = ""
var _is_update_available = false
var _release_page_url = ""
var _download_urls = []


func _get_github_auth_headers() -> PoolStringArray:
	# Check for Auth_Token.txt file in the same directory as the executable
	var token_file_path = OS.get_executable_path().get_base_dir().plus_file("Auth_Token.txt")
	var file = File.new()
	
	if file.open(token_file_path, File.READ) != OK:
		# File doesn't exist, return empty headers for unauthenticated requests
		return PoolStringArray()
	
	var token = file.get_as_text().strip_edges()
	file.close()
	
	# Basic validation - GitHub tokens should be at least 20 characters
	# and contain only alphanumeric characters, underscores, and possibly other characters
	if token.length() < 20:
		# Token too short, use unauthenticated requests
		Status.post("Auth_Token.txt found but token appears too short, using unauthenticated requests")
		return PoolStringArray()
	
	# GitHub tokens typically contain only alphanumeric characters, underscores, and sometimes dashes
	# We'll do a simple validation to check for obvious invalid tokens
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_-]+$")
	if not regex.search(token):
		# Invalid characters in token, use unauthenticated requests
		Status.post("Auth_Token.txt found but token contains invalid characters, using unauthenticated requests")
		return PoolStringArray()
	
	# Return headers with authentication
	Status.post("Using GitHub authentication token for API requests")
	return PoolStringArray(["Authorization: token " + token])


func _ready() -> void:
	
	# Add the HTTPRequest node for version checking
	add_child(_version_check_request)
	_version_check_request.connect("request_completed", self, "_on_version_check_completed")
	
	# Apply UI theme
	var theme_file = Settings.read("launcher_theme")
	load_ui_theme(theme_file)
	
	_save_control_min_sizes()
	_scale_control_min_sizes(Geom.scale)
	Geom.connect("scale_changed", self, "_on_ui_scale_changed")
	
	assign_localized_text()
	
	_btn_resume.grab_focus()
	
	var welcome_msg = tr("str_welcome")
	if Settings.read("print_tips_of_the_day"):
		welcome_msg += tr("str_tip_of_the_day") + TOTD.get_tip() + "\n"
	Status.post(welcome_msg)
	
	_unpack_utils()
	_setup_ui()
	
	# Connect the BtnUpdate button signal
	_btn_update.connect("pressed", self, "_on_BtnUpdate_pressed")
	
	# Automatically check for updates on startup
	_on_BtnCheck_pressed()


func _save_control_min_sizes() -> void:
	
	for node in Helpers.get_all_nodes_within(self):
		if ("rect_min_size" in node) and (node.rect_min_size != Vector2.ZERO):
			_base_min_sizes[node] = node.rect_min_size


func _scale_control_min_sizes(factor: float) -> void:
	
	for node in _base_min_sizes:
		node.rect_min_size = _base_min_sizes[node] * factor


func _save_icon_sizes() -> void:
	
	var resources = load("res://")


func assign_localized_text() -> void:
	
	var version = Settings.read("version")
	OS.set_window_title(tr("window_title"))	
	
	_tabs.set_tab_title(0, tr("tab_game"))
	_tabs.set_tab_title(1, tr("tab_mods"))
	_tabs.set_tab_title(2, tr("tab_tilesets"))
	_tabs.set_tab_title(3, tr("tab_soundpacks"))
	_tabs.set_tab_title(4, tr("tab_fonts"))
	_tabs.set_tab_title(5, tr("tab_backups"))
	_tabs.set_tab_title(6, tr("tab_settings"))
	_tabs.set_tab_title(7, tr("tab_about"))
	
	_lbl_changelog.bbcode_text = tr("lbl_changelog")
	
	var game = Settings.read("game")
	if game == "dda":
		_game_desc.bbcode_text = tr("desc_dda")
	elif game == "bn":
		_game_desc.bbcode_text = tr("desc_bn")
	elif game == "eod":
		_game_desc.bbcode_text = tr("desc_eod")
	elif game == "tish":
		_game_desc.bbcode_text = tr("desc_tish")
	elif game == "tlg":
		_game_desc.bbcode_text = tr("desc_tlg")


func load_ui_theme(theme_file: String) -> void:
	
	# Since we've got multiple themes that have some shared elements (like fonts),
	# we have to make sure old theme's *scaled* sizes don't become new theme's
	# *base* sizes. To avoid that, we have to reset the scale of the old theme
	# before replacing it, and we have to do that before we even attempt to load
	# the new theme.
	
	self.theme.apply_scale(1.0)
	var new_theme := load("res://themes".plus_file(theme_file)) as ScalableTheme
	
	if new_theme:
		new_theme.apply_scale(Geom.scale)
		self.theme = new_theme
	else:
		self.theme.apply_scale(Geom.scale)
		Status.post(tr("msg_theme_load_error") % theme_file, Enums.MSG_ERROR)


func _unpack_utils() -> void:
	
	var d = Directory.new()
	var sevenzip_exe
	
	# Platform-specific binary names
	if OS.get_name() == "Windows":
		sevenzip_exe = Paths.utils_dir.plus_file("7za.exe")
	else:  # Linux (X11) or macOS (OSX)
		sevenzip_exe = Paths.utils_dir.plus_file("7za")
	
	if not d.file_exists(sevenzip_exe):
		if not d.dir_exists(Paths.utils_dir):
			d.make_dir(Paths.utils_dir)
		
		var source_found = false
		var source_path = ""
		var binary_name = "7za.exe" if OS.get_name() == "Windows" else "7za"
		
		# Try multiple locations for the 7-Zip binary
		var possible_locations = [
			"res://utils/" + binary_name,  # Godot resource path
			OS.get_executable_path().get_base_dir().plus_file("utils").plus_file(binary_name),  # Next to executable
			OS.get_executable_path().get_base_dir().plus_file(binary_name),  # Same directory as executable
			"./utils/" + binary_name,  # Relative path
			"utils/" + binary_name     # Current directory utils
		]
		
		for location in possible_locations:
			if location.begins_with("res://"):
				# For resource paths, we need to use File.open to check existence
				var file = File.new()
				if file.open(location, File.READ) == OK:
					file.close()
					source_path = location
					source_found = true
					break
			else:
				# For regular file paths, use Directory.file_exists
				if d.file_exists(location):
					source_path = location
					source_found = true
					break
		
		if source_found:
			var copy_error = OK
			if source_path.begins_with("res://"):
				# Copy from resource
				var source_file = File.new()
				var dest_file = File.new()
				
				if source_file.open(source_path, File.READ) == OK:
					if dest_file.open(sevenzip_exe, File.WRITE) == OK:
						dest_file.store_buffer(source_file.get_buffer(source_file.get_len()))
						dest_file.close()
					else:
						copy_error = ERR_CANT_CREATE
				else:
					copy_error = ERR_FILE_NOT_FOUND
				source_file.close()
			else:
				# Copy from regular file path
				copy_error = d.copy(source_path, sevenzip_exe)
			
			if copy_error != OK:
				Status.post("[error] Failed to copy 7-Zip binary: " + str(copy_error), Enums.MSG_ERROR)
				return
			
			# Make executable on Linux and macOS
			if OS.get_name() == "X11" or OS.get_name() == "OSX":
				OS.execute("chmod", ["+x", sevenzip_exe], true)
		else:
			Status.post("[error] 7-Zip binary not found in any of the following locations:", Enums.MSG_ERROR)
			for location in possible_locations:
				Status.post("  - " + location, Enums.MSG_ERROR)
			Status.post("[error] Please ensure 7-Zip binary is included in the project or placed next to the executable.", Enums.MSG_ERROR)
			return


func _smart_disable_controls(group_name: String) -> void:
	
	var nodes = get_tree().get_nodes_in_group(group_name)
	var state = {}
	
	for n in nodes:
		if "disabled" in n:
			state[n] = n.disabled
			n.disabled = true
			
	_disable_savestate[group_name] = state


func _smart_reenable_controls(group_name: String) -> void:
	
	if not group_name in _disable_savestate:
		return
	
	var state = _disable_savestate[group_name]
	for node in state:
		node.disabled = state[node]
		
	_disable_savestate.erase(group_name)


func _on_ui_scale_changed(new_scale: float) -> void:
	
	_scale_control_min_sizes(new_scale)


func _on_Tabs_tab_changed(tab: int) -> void:
	
	_refresh_currently_installed()


func _on_GamesList_item_selected(index: int) -> void:
	
	match index:
		0:
			Settings.store("game", "dda")
			_game_desc.bbcode_text = tr("desc_dda")
		1:
			Settings.store("game", "tlg")
			_game_desc.bbcode_text = tr("desc_tlg")
		2:
			Settings.store("game", "bn")
			_game_desc.bbcode_text = tr("desc_bn")
		3:
			Settings.store("game", "eod")
			_game_desc.bbcode_text = tr("desc_eod")
		4:
			Settings.store("game", "tish")
			_game_desc.bbcode_text = tr("desc_tish")
	
	_tabs.current_tab = 0
	apply_game_choice()
	_refresh_currently_installed()
	
	_mods.refresh_installed()
	_mods.refresh_available()


func _on_RBtnStable_toggled(button_pressed: bool) -> void:
	if (Settings.read("game") == "eod") or (Settings.read("game") == "tish"):
		Settings.store("channel", "experimental")


	if button_pressed:
		Settings.store("channel", "stable")
	else:
		Settings.store("channel", "experimental")
		
	apply_game_choice()


func _on_Releases_started_fetching_releases() -> void:
	
	_smart_disable_controls("disable_while_fetching_releases")


func _on_Releases_done_fetching_releases() -> void:
	
	_smart_reenable_controls("disable_while_fetching_releases")
	reload_builds_list()
	_refresh_currently_installed()


func _on_ReleaseInstaller_operation_started() -> void:
	
	_smart_disable_controls("disable_during_release_operations")


func _on_ReleaseInstaller_operation_finished() -> void:
	
	_smart_reenable_controls("disable_during_release_operations")
	_refresh_currently_installed()


func _on_mod_operation_started() -> void:
	
	_smart_disable_controls("disable_during_mod_operations")


func _on_mod_operation_finished() -> void:
	
	_smart_reenable_controls("disable_during_mod_operations")


func _on_soundpack_operation_started() -> void:
	
	_smart_disable_controls("disable_during_soundpack_operations")


func _on_soundpack_operation_finished() -> void:
	
	_smart_reenable_controls("disable_during_soundpack_operations")


func _on_tileset_operation_started() -> void:
	
	_smart_disable_controls("disable_during_tileset_operations")


func _on_tileset_operation_finished() -> void:
	
	_smart_reenable_controls("disable_during_tileset_operations")


func _on_backup_operation_started() -> void:
	
	_smart_disable_controls("disable_during_backup_operations")


func _on_backup_operation_finished() -> void:
	
	_smart_reenable_controls("disable_during_backup_operations")


func _on_Description_meta_clicked(meta) -> void:
	
	OS.shell_open(meta)


func _on_ChangelogLink_meta_clicked(meta) -> void:
	
	_changelog.open()


func _on_Log_meta_clicked(meta) -> void:
	
	OS.shell_open(meta)


func _on_AboutLink_meta_clicked(meta) -> void:
	
	OS.shell_open(meta)


func _on_BtnRefresh_pressed() -> void:
	
	_releases.fetch(_get_release_key())


func _on_BuildsList_item_selected(index: int) -> void:
	
	var info = Paths.installs_summary
	var game = Settings.read("game")
	
	if (not Settings.read("update_to_same_build_allowed")) \
			and (game in info) \
			and (_releases.releases[_get_release_key()][index]["name"] in info[game]):
		_btn_install.disabled = true
		_cb_update.disabled = true
	else:
		_btn_install.disabled = false
		_cb_update.disabled = false


func _on_BtnInstall_pressed() -> void:
	
	var index = _lst_builds.selected
	var release = _releases.releases[_get_release_key()][index]
	var update_path := ""
	if Settings.read("update_current_when_installing"):
		var game = Settings.read("game")
		var active_name = Settings.read("active_install_" + game)
		if (game in _installs) and (active_name in _installs[game]):
			update_path = _installs[game][active_name]
	_installer.install_release(release, Settings.read("game"), update_path)


func _on_cbUpdateCurrent_toggled(button_pressed: bool) -> void:
	
	Settings.store("update_current_when_installing", button_pressed)


func _get_release_key() -> String:
	# Compiles a string looking like "dda-stable" or "bn-experimental"
	# from settings.
	
	var game = Settings.read("game")
	var key = game + "-" + Settings.read("channel")
	
	return key


func _open_directory(path: String) -> void:
	# Cross-platform directory opening that handles paths with spaces properly
	
	if OS.get_name() == "OSX":
		# On macOS, use the 'open' command which handles spaces properly
		OS.execute("open", [path], false)
	else:
		# On Windows and Linux, use the standard shell_open
		OS.shell_open(path)


func _on_GameDir_pressed() -> void:
	
	var gamedir = Paths.game_dir
	if Directory.new().dir_exists(gamedir):
		_open_directory(gamedir)


func _on_UserDir_pressed() -> void:
	
	var userdir = Paths.userdata
	if Directory.new().dir_exists(userdir):
		_open_directory(userdir)


func _setup_ui() -> void:

	_game_info.visible = Settings.read("show_game_desc")
	if not Settings.read("debug_mode"):
		_tabs.remove_child(_debug_ui)
	
	_cb_update.pressed = Settings.read("update_current_when_installing")
	
	apply_game_choice()
	
	_lst_games.connect("item_selected", self, "_on_GamesList_item_selected")
	_rbtn_stable.connect("toggled", self, "_on_RBtnStable_toggled")
	# Had to leave these signals unconnected in the editor and only connect
	# them now from code to avoid cyclic calls of apply_game_choice.
	
	_refresh_currently_installed()


func reload_builds_list() -> void:
	
	_lst_builds.clear()
	for rec in _releases.releases[_get_release_key()]:
			_lst_builds.add_item(rec["name"])
	_refresh_currently_installed()


func apply_game_choice() -> void:
	
	# TODO: Turn this mess into a more elegant mess.

	var game = Settings.read("game")
	var channel = Settings.read("channel")
	
	if (game == "dda") or (game == "bn"):
		_rbtn_exper.disabled = false
		_rbtn_stable.disabled = false
		if channel == "stable":
			_rbtn_stable.pressed = true
			_btn_refresh.disabled = true
		else:
			_btn_refresh.disabled = false
	elif game in ["eod", "tish", "tlg"]:
		# These Forks do not have a stable channel
		_rbtn_exper.pressed = true
		_rbtn_exper.disabled = true
		_rbtn_stable.disabled = true
		_btn_refresh.disabled = false

	match game:
		"dda":
			_lst_games.select(0)
			_game_desc.bbcode_text = tr("desc_dda")
				
		"tlg":
			_lst_games.select(1)
			_game_desc.bbcode_text = tr("desc_tlg")

		"bn":
			_lst_games.select(2)
			_game_desc.bbcode_text = tr("desc_bn")

		"eod":
			_lst_games.select(3)
			_game_desc.bbcode_text = tr("desc_eod")

		"tish":
			_lst_games.select(4)
			_game_desc.bbcode_text = tr("desc_tish")
	
	if len(_releases.releases[_get_release_key()]) == 0:
		_releases.fetch(_get_release_key())
	else:
		reload_builds_list()


func _on_BtnPlay_pressed() -> void:
	_start_game()


func _on_BtnResume_pressed() -> void:
	var lastworld: String = Paths.config.plus_file("lastworld.json")
	var info = Helpers.load_json_file(lastworld)
	if info:
		_start_game(info["world_name"])


func _start_game(world := "") -> void:
	# Create automatic backup if enabled
	if Settings.read("backup_before_launch"):
		var datetime = OS.get_datetime()
		var backup_name = "Auto_%02d-%02d-%02d_%02d-%02d" % [
			datetime["year"] % 100,
			datetime["month"],
			datetime["day"],
			datetime["hour"],
			datetime["minute"],
		]
		# Create the backup
		Status.post(tr("Creating automatic backup before game launch..."))
		_backups.backup_current(backup_name)
		# Wait for backup to complete before launching game
		yield(_backups, "backup_creation_finished")
		Status.post(tr("Automatic backup created: %s") % backup_name)
		
		# Clean up old automatic backups if we exceed the maximum count
		_cleanup_automatic_backups()
	
	# Store whether launcher should close after game
	_launcher_should_close_after_game = not Settings.read("keep_open_after_starting_game")
	
	# Create game process wrapper for monitoring
	_game_process = OSExecWrapper.new()
	_game_process.connect("process_exited", self, "_on_game_process_exited")
	
	var command_path: String
	var command_args: PoolStringArray
	
	match OS.get_name():
		"X11":
			command_path = Paths.game_dir.plus_file("cataclysm-launcher")
			command_args = ["--userdir", _escape_path(Paths.userdata)]
			if world != "":
				command_args.append_array(["--world", _escape_path(world)])
		
		"Windows":
			var world_str := ""
			if world != "":
				world_str = "--world \"%s\"" % world

			var exe_file = "cataclysm-tiles.exe"
			if Settings.read("game") == "bn" and Directory.new().file_exists(Paths.game_dir.plus_file("cataclysm-bn-tiles.exe")):
				exe_file = "cataclysm-bn-tiles.exe"
			if Settings.read("game") == "tlg" and Directory.new().file_exists(Paths.game_dir.plus_file("cataclysm-tlg-tiles.exe")):
				exe_file = "cataclysm-tlg-tiles.exe"

			# For Windows, we need to use cmd to change directory and launch the executable
			# This ensures the game runs from its installation directory
			command_path = "cmd"
			var game_exe_path = Paths.game_dir.plus_file(exe_file)
			var cmd_string = "cd /d \"%s\" && \"%s\" --userdir \"%s/\"" % [Paths.game_dir, game_exe_path, Paths.userdata]
			if world != "":
				cmd_string += " --world \"%s\"" % world
			command_args = ["/C", cmd_string]
		"OSX":
			# macOS - Check for cataclysm-launcher first, like Linux
			var launcher_path = Paths.game_dir.plus_file("cataclysm-launcher")
			var d = Directory.new()
			
			if d.file_exists(launcher_path):
				# Use cataclysm-launcher if available (like Linux)
				command_path = launcher_path
				command_args = ["--userdir", _escape_path(Paths.userdata)]
				if world != "":
					command_args.append_array(["--world", _escape_path(world)])
				
				# Verify executable permissions
				if not _verify_executable_permissions(command_path):
					Status.post(tr("msg_fixing_executable_permissions") % command_path.get_file())
					var chmod_result = OS.execute("chmod", ["+x", command_path], true)
					if chmod_result != 0:
						Status.post(tr("msg_chmod_failed") % [command_path.get_file(), chmod_result], Enums.MSG_ERROR)
						return
				
				# Use direct execution with working directory change
				_launch_game_with_working_dir(command_path, command_args, Paths.game_dir, world)
				return
			else:
				# No cataclysm-launcher, find game executable
				var exe_info = _find_macos_executable(Paths.game_dir)
				if exe_info.empty():
					Status.post(tr("msg_no_executable_found_macos"), Enums.MSG_ERROR)
					return
				
				if exe_info["type"] == "app_bundle":
					# Use macOS 'open' command for proper app bundle launching
					_launch_app_bundle(exe_info, world)
					return
				else:
					# Direct executable - use with working directory change
					command_path = exe_info["path"]
					command_args = ["--userdir", _escape_path(Paths.userdata)]
					if world != "":
						command_args.append_array(["--world", _escape_path(world)])
					
					# Verify executable permissions
					if not _verify_executable_permissions(command_path):
						Status.post(tr("msg_fixing_executable_permissions") % command_path.get_file())
						var chmod_result = OS.execute("chmod", ["+x", command_path], true)
						if chmod_result != 0:
							Status.post(tr("msg_chmod_failed") % [command_path.get_file(), chmod_result], Enums.MSG_ERROR)
							return
					
					# Use direct execution with working directory change
					_launch_game_with_working_dir(command_path, command_args, Paths.game_dir, world)
					return
		_:
			Status.post(tr("Unsupported operating system for game launching"), Enums.MSG_ERROR)
			return
	
	# Show appropriate status message
	var game_name = command_path
	if OS.get_name() == "Windows":
		# For Windows, extract the actual game executable name from the command
		var exe_file = "cataclysm-tiles.exe"
		if Settings.read("game") == "bn" and Directory.new().file_exists(Paths.game_dir.plus_file("cataclysm-bn-tiles.exe")):
			exe_file = "cataclysm-bn-tiles.exe"
		if Settings.read("game") == "tlg" and Directory.new().file_exists(Paths.game_dir.plus_file("cataclysm-tlg-tiles.exe")):
			exe_file = "cataclysm-tlg-tiles.exe"
		game_name = exe_file
	
	Status.post(tr("Starting game: %s") % game_name)
	
	# Launch game with process monitoring
	_game_process.execute(command_path, command_args, false)
	
	# Inform user about monitoring
	if Settings.read("backup_after_closing"):
		Status.post(tr("Game launched. Monitoring process for automatic backup when game closes..."))


func _on_game_process_exited() -> void:
	# Game has closed, handle post-game actions
	Status.post(tr("Game process has exited (exit code: %s)") % _game_process.exit_code)
	
	# Create automatic backup if enabled
	if Settings.read("backup_after_closing"):
		var datetime = OS.get_datetime()
		var backup_name = "AutoExit_%02d-%02d-%02d_%02d-%02d" % [
			datetime["year"] % 100,
			datetime["month"],
			datetime["day"],
			datetime["hour"],
			datetime["minute"],
		]
		Status.post(tr("Creating automatic backup after game closed..."))
		_backups.backup_current(backup_name)
		yield(_backups, "backup_creation_finished")
		Status.post(tr("Automatic backup created: %s") % backup_name)
		
		# Clean up old automatic backups if we exceed the maximum count
		_cleanup_automatic_backups()
	
	# Clean up the process wrapper
	if _game_process:
		_game_process = null
	
	# Close launcher if that was the original setting
	if _launcher_should_close_after_game:
		Status.post(tr("Closing launcher..."))
		yield(get_tree().create_timer(1.0), "timeout")  # Give user time to see the message
		get_tree().quit()


func _on_InstallsList_item_selected(index: int) -> void:
	
	var name = _lst_installs.get_item_text(index)
	_btn_delete.disabled = false
	_btn_make_active.disabled = (name == Settings.read("active_install_" + Settings.read("game")))


func _on_InstallsList_item_activated(index: int) -> void:
	
	var name = _lst_installs.get_item_text(index)
	var path = _installs[Settings.read("game")][name]
	if Directory.new().dir_exists(path):
		_open_directory(path)


func _on_btnMakeActive_pressed() -> void:
	
	var name = _lst_installs.get_item_text(_lst_installs.get_selected_items()[0])
	Status.post(tr("msg_set_active") % name)
	Settings.store("active_install_" + Settings.read("game"), name)
	_refresh_currently_installed()


func _on_btnDelete_pressed() -> void:
	
	var name = _lst_installs.get_item_text(_lst_installs.get_selected_items()[0])
	_installer.remove_release_by_name(name)


func _refresh_currently_installed() -> void:
	
	var releases = _releases.releases[_get_release_key()]

	_lst_installs.clear()
	var game = Settings.read("game")
	_installs = Paths.installs_summary
	var active_name = Settings.read("active_install_" + game)
	if game in _installs:
		for name in _installs[game]:
			_lst_installs.add_item(name)
			var curr_idx = _lst_installs.get_item_count() - 1
			_lst_installs.set_item_tooltip(curr_idx, tr("tooltip_installs_item") % _installs[game][name])
#			if name == active_name:
#				_lst_installs.set_item_custom_fg_color(curr_idx, Color(0, 0.8, 0))
	
	_lst_builds.select(-1)
	_btn_make_active.disabled = true
	_btn_delete.disabled = true
	
	if game in _installs:
		_lbl_build.text = active_name
		_btn_play.disabled = false
		_btn_resume.disabled = not (Directory.new().file_exists(Paths.config.plus_file("lastworld.json")))
		_btn_game_dir.visible = true
		_btn_user_dir.visible = true
		if (_lst_builds.selected != -1) and (_lst_builds.selected < len(releases)):
				if not Settings.read("update_to_same_build_allowed"):
					_btn_install.disabled = (releases[_lst_builds.selected]["name"] in _installs[game])
					_cb_update.disabled = _btn_install.disabled
		else:
			_btn_install.disabled = true

	else:
		_lbl_build.text = tr("lbl_none")
		_btn_install.disabled = false
		_cb_update.disabled = true
		_btn_play.disabled = true
		_btn_resume.disabled = true
		_btn_game_dir.visible = false
		_btn_user_dir.visible = false
	
	if (game in _installs and _installs[game].size() > 1) or \
			(Settings.read("always_show_installs") == true):
		_panel_installs.visible = true
	else:
		_panel_installs.visible = false

	for i in [1, 2, 3, 4, 5]:
		_tabs.set_tab_disabled(i, not game in _installs)


func _on_InfoIcon_gui_input(event: InputEvent) -> void:
	
	if (event is InputEventMouseButton) and (event.button_index == BUTTON_LEFT) and (event.is_pressed()):
		_easter_egg_counter += 1
		if _easter_egg_counter == 3:
			Status.post("[color=red]%s[/color]" % tr("msg_easter_egg_warning"))
		if _easter_egg_counter == 10:
			_activate_easter_egg()


func _activate_easter_egg() -> void:
	
	for node in Helpers.get_all_nodes_within(self):
		if node is Control:
			node.rect_pivot_offset = node.rect_size / 2.0
			node.rect_rotation = randf() * 2.0 - 1.0

	Status.rainbow_text = true
	
	for i in range(20):
		Status.post(tr("msg_easter_egg_activated"))
		yield(get_tree().create_timer(0.1), "timeout")


func _on_BtnCheck_pressed() -> void:
	var current_version = Settings.get_hardcoded_version()
	Status.post(tr("Checking for Dabdoob updates... Current version: v%s") % current_version)
	
	# Disable the update button while checking
	_btn_update.disabled = true
	
	# Get authentication headers if token is available
	var headers = _get_github_auth_headers()
	
	# Make the HTTP request to GitHub with authentication if available
	var error = _version_check_request.request(VERSION_CHECK_URL, headers)
	if error != OK:
		Status.post(tr("Error making HTTP request"), Enums.MSG_ERROR)
		_btn_update.disabled = false  # Re-enable button on error

func _on_version_check_completed(result, response_code, headers, body):
	
	if result != HTTPRequest.RESULT_SUCCESS:
		Status.post(tr("Failed to connect to update server"), Enums.MSG_ERROR)
		_btn_update.disabled = false  # Re-enable button on error
		return
		
	if response_code != 200:
		Status.post(tr("Error response from update server: %d") % response_code, Enums.MSG_ERROR)
		_btn_update.disabled = false  # Re-enable button on error
		return
	
	# Parse the JSON response
	var json = JSON.parse(body.get_string_from_utf8())
	if json.error != OK:
		Status.post(tr("Error parsing response from server"), Enums.MSG_ERROR)
		_btn_update.disabled = false  # Re-enable button on error
		return
	
	var response = json.result
	if typeof(response) != TYPE_DICTIONARY:
		Status.post(tr("Invalid response format from server"), Enums.MSG_ERROR)
		_btn_update.disabled = false  # Re-enable button on error
		return
	
	if "name" in response:
		_latest_version = response["name"]
		var current_version = Settings.get_hardcoded_version()
		
		Status.post(tr("Dabdoob's latest version available: v%s") % _latest_version)
		
		# Store the browser download URL from the API response
		if "html_url" in response:
			_release_page_url = response["html_url"]
		else:
			_release_page_url = "https://github.com/Hihahahalol/Catapult_Dabdoob/releases/latest"
		
		# Find downloadable assets in the response
		_download_urls = []
		if "assets" in response and response["assets"] is Array and response["assets"].size() > 0:
			for asset in response["assets"]:
				if "browser_download_url" in asset:
					_download_urls.append({
						"name": asset.get("name", "unknown"),
						"size": asset.get("size", 0),
						"url": asset["browser_download_url"]
					})
		
		# Simple version comparison
		if _is_newer_version(_latest_version, current_version):
			Status.post(tr("A new version is available! You can update to v%s") % _latest_version, Enums.MSG_SUCCESS)
			_btn_update.disabled = false
			_is_update_available = true
		else:
			Status.post(tr("You have Dabdoob's latest version!"), Enums.MSG_SUCCESS)
			_btn_update.disabled = true
			_is_update_available = false
	else:
		Status.post(tr("Could not determine Dabdoob's latest version"), Enums.MSG_ERROR)
		_btn_update.disabled = false  # Re-enable button on error

func _is_newer_version(latest: String, current: String) -> bool:
	# Split version strings and convert to integers
	var latest_parts = latest.split(".")
	var current_parts = current.split(".")
	
	# Compare major version first
	if latest_parts.size() > 0 and current_parts.size() > 0:
		var latest_major = int(latest_parts[0])
		var current_major = int(current_parts[0])
		
		if latest_major > current_major:
			return true
		elif latest_major < current_major:
			return false
	
	# If major versions are equal, compare minor version
	# Get minor versions (default to 0 if not present)
	var latest_minor = 0
	var current_minor = 0
	
	if latest_parts.size() > 1:
		latest_minor = int(latest_parts[1])
	
	if current_parts.size() > 1:
		current_minor = int(current_parts[1])
	
	if latest_minor > current_minor:
		return true
	
	return false

func _on_BtnUpdate_pressed() -> void:
	if _is_update_available:
		Status.post(tr("Starting update to version v%s...") % _latest_version)
		_perform_update()
	else:
		Status.post(tr("No update available"))

func _perform_update() -> void:
	# Check if we have download URLs available
	if _download_urls.empty():
		Status.post(tr("No download URLs found. Opening release page in browser..."))
		OS.shell_open(_release_page_url)
		return
	
	# Disable update button during update
	_btn_update.disabled = true
	
	# Create a temporary directory for the download
	var temp_dir = OS.get_user_data_dir().plus_file("update_temp")
	var dir = Directory.new()
	if dir.dir_exists(temp_dir):
		_remove_directory_recursive(temp_dir)
	dir.make_dir(temp_dir)
	
	# Show update progress to user
	Status.post(tr("Downloading update from GitHub..."))
	
	# Find the appropriate asset for the current OS
	var download_url = ""
	var asset_name = ""
	var os_name = OS.get_name()
	
	# Log all available assets for debugging
	Status.post(tr("Available assets:"))
	for asset in _download_urls:
		Status.post("- " + asset["name"])
	
	for asset in _download_urls:
		var name = asset["name"].to_lower()
		
		# Check for Windows assets
		if os_name == "Windows" and (name.find("win") >= 0 or name.find("windows") >= 0 or name.ends_with(".exe")):
			download_url = asset["url"]
			asset_name = asset["name"]
			Status.post(tr("Selected Windows asset: %s") % asset_name)
			break
		
		# Check for Linux assets
		elif os_name == "X11" and (name.find("linux") >= 0 or name.find("x86_64") >= 0 or name.ends_with(".x86_64")):
			download_url = asset["url"]
			asset_name = asset["name"]
			Status.post(tr("Selected Linux asset: %s") % asset_name)
			break
		
		# Check for macOS assets
		elif os_name == "OSX" and (name.find("mac") >= 0 or name.find("osx") >= 0 or name.find("darwin") >= 0 or name.ends_with(".dmg")):
			download_url = asset["url"]
			asset_name = asset["name"]
			Status.post(tr("Selected macOS asset: %s") % asset_name)
			break
	
	# If no matching asset was found, use the first one as a fallback
	if download_url.empty():
		Status.post(tr("No OS-specific asset found for %s, using first available") % os_name)
		download_url = _download_urls[0]["url"]
		asset_name = _download_urls[0]["name"]
		
	Status.post(tr("Downloading %s...") % asset_name)
	
	# Set up the downloader
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self, "_on_update_download_completed", [temp_dir, asset_name])
	
	# Get authentication headers for the download
	var headers = _get_github_auth_headers()
	
	# Start the download with authentication if available
	var error = http_request.request(download_url, headers)
	if error != OK:
		Status.post(tr("Error starting download: %s") % error, Enums.MSG_ERROR)
		_cleanup_update(http_request, temp_dir)

func _on_update_download_completed(result, response_code, headers, body, temp_dir, asset_name):
	var http_request = get_node_or_null("HTTPRequest")
	if http_request:
		remove_child(http_request)
		http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		Status.post(tr("Download failed with error code: %s") % result, Enums.MSG_ERROR)
		_cleanup_update(null, temp_dir)
		return
		
	if response_code != 200:
		Status.post(tr("Server returned error code: %s") % response_code, Enums.MSG_ERROR)
		_cleanup_update(null, temp_dir)
		return
	
	# Save the downloaded file
	var downloaded_file = temp_dir.plus_file(asset_name)
	var file = File.new()
	var error = file.open(downloaded_file, File.WRITE)
	if error != OK:
		Status.post(tr("Failed to create temporary file: %s") % error, Enums.MSG_ERROR)
		_cleanup_update(null, temp_dir)
		return
		
	file.store_buffer(body)
	file.close()
	
	Status.post(tr("Download complete. Preparing update..."))
	
	# Create a PowerShell script to handle the update
	_create_powershell_updater(downloaded_file)

func _create_powershell_updater(downloaded_file):
	var current_exe = OS.get_executable_path()
	
	# Create a much simpler PowerShell script for updating just the executable
	var ps_script = """
# Dabdoob Update Script - Single Executable Updater
$ErrorActionPreference = "Stop"

# Log function
function Log-Message {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath "$env:USERPROFILE\\AppData\\Roaming\\Godot\\app_userdata\\Dabdoob\\update_log.txt" -Append
}

# Clear previous log and start a new one
if (Test-Path "$env:USERPROFILE\\AppData\\Roaming\\Godot\\app_userdata\\Dabdoob\\update_log.txt") {
    Remove-Item -Path "$env:USERPROFILE\\AppData\\Roaming\\Godot\\app_userdata\\Dabdoob\\update_log.txt" -Force
}

Log-Message "Starting update process"
Log-Message "Downloaded file: %s"
Log-Message "Target executable: %s"

try {
    # Wait for main process to exit
    Log-Message "Waiting for application to close..."
    Start-Sleep -Seconds 5
    
    $processName = [System.IO.Path]::GetFileNameWithoutExtension("%s")
    Log-Message "Process name: $processName"
    
    # Check if process is still running
    $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
    
    if ($running) {
        Log-Message "Process still running, waiting another 5 seconds..."
        Start-Sleep -Seconds 5
        
        # Try to forcefully terminate if still running
        $running = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($running) {
            Log-Message "Terminating process..."
            Stop-Process -Name $processName -Force
            Start-Sleep -Seconds 2
        }
    }
    
    # Check if source and target files exist
    if (-not (Test-Path "%s")) {
        throw "Source file not found: %s"
    }
    
    Log-Message "Source file exists and has size: $((Get-Item -Path "%s").Length) bytes"
    
    if (Test-Path "%s") {
        Log-Message "Target file exists and has size: $((Get-Item -Path "%s").Length) bytes"
    } else {
        Log-Message "Target file does not exist yet"
    }
    
    # Copy the executable
    Log-Message "Copying executable file..."
    Copy-Item -Path "%s" -Destination "%s" -Force
    
    # Verify the copy worked
    if (Test-Path "%s") {
        Log-Message "Verified: Target file now exists with size: $((Get-Item -Path "%s").Length) bytes"
    } else {
        throw "Failed to create target file"
    }
    
    # Start the updated application
    Log-Message "Update complete, starting application..."
    Start-Process -FilePath "%s"
    
    # Clean up
    Log-Message "Cleaning up..."
    Start-Sleep -Seconds 2
    Remove-Item -Path "%s" -Force -ErrorAction SilentlyContinue
    
    Log-Message "Update completed successfully"
} catch {
    Log-Message "Error during update: $_"
    Log-Message "Stack trace: $($_.ScriptStackTrace)"
}
""" % [
	downloaded_file.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	current_exe.get_file(),
	downloaded_file.replace("/", "\\"),
	downloaded_file.replace("/", "\\"),
	downloaded_file.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	downloaded_file.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	current_exe.replace("/", "\\"),
	downloaded_file.replace("/", "\\")
]
	
	var ps_path = OS.get_user_data_dir().plus_file("update.ps1")
	var file = File.new()
	file.open(ps_path, File.WRITE)
	file.store_string(ps_script)
	file.close()
	
	# Create a simple batch file to launch PowerShell with elevated privileges
	var bat_script = """
@echo off
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s"
""" % ps_path.replace("/", "\\")
	
	var bat_path = OS.get_user_data_dir().plus_file("update_launcher.bat")
	file = File.new()
	file.open(bat_path, File.WRITE)
	file.store_string(bat_script)
	file.close()
	
	# Log
	Status.post(tr("Update ready! Dabdoob will restart to complete the update."))
	Status.post(tr("Update logs will be saved to: %s") % OS.get_user_data_dir().plus_file("update_log.txt"))
	
	# Execute the batch file and exit
	if OS.get_name() == "Windows":
		# Run the PowerShell script without showing a window
		OS.execute("cmd.exe", ["/c", "start", "/b", bat_path], false)
		yield(get_tree().create_timer(2.0), "timeout")
		get_tree().quit()
	else:
		Status.post(tr("Automatic updates are only supported on Windows. Please update manually."))
		OS.shell_open(_release_page_url)
		_cleanup_update(null, OS.get_user_data_dir().plus_file("update_temp"))

func _cleanup_update(http_request, temp_dir):
	if http_request:
		remove_child(http_request)
		http_request.queue_free()
	
	# Re-enable update button
	_btn_update.disabled = false
	
	# Clean up temporary directory
	if temp_dir:
		_remove_directory_recursive(temp_dir)
		
func _remove_directory_recursive(path):
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true)
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_remove_directory_recursive(path.plus_file(file_name))
			else:
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		dir.change_dir("..")
		dir.remove(path)

func _cleanup_automatic_backups() -> void:
	var max_backups = Settings.read("max_auto_backups")
	_backups.refresh_available()
	var auto_backups = []
	
	# Filter to only automatic backups and sort by name (which includes timestamp)
	for backup in _backups.available:
		if backup["name"].begins_with("Auto_") or backup["name"].begins_with("AutoExit_"):
			auto_backups.append(backup)
	
	# Sort by name to get chronological order (oldest first)
	auto_backups.sort_custom(self, "_compare_backup_names")
	
	# Remove excess automatic backups
	if auto_backups.size() > max_backups:
		var backups_to_remove = auto_backups.size() - max_backups
		for i in range(backups_to_remove):
			var backup_name = auto_backups[i]["name"]
			Status.post(tr("Removing old automatic backup: %s") % backup_name)
			_backups.delete(backup_name)
			yield(_backups, "backup_deletion_finished")


func _compare_backup_names(a, b) -> bool:
	return a["name"] < b["name"]

func _find_macos_executable(game_dir: String) -> Dictionary:
	# Find the correct executable on macOS, handling both direct executables and .app bundles
	
	var d = Directory.new()
	var game = Settings.read("game")
	
	# List of possible executable names based on game type
	var exe_names = []
	match game:
		"bn":
			exe_names = ["cataclysm-bn-tiles", "cataclysm-tiles"]
		"tlg":
			exe_names = ["cataclysm-tlg-tiles", "cataclysm-tiles"]
		"eod":
			exe_names = ["cataclysm-eod-tiles", "cataclysm-tiles"]
		"tish":
			exe_names = ["cataclysm-tish-tiles", "cataclysm-tiles"]
		_:
			exe_names = ["cataclysm-tiles"]
	
	# First, check for direct executables
	for exe_name in exe_names:
		var exe_path = game_dir.plus_file(exe_name)
		if d.file_exists(exe_path):
			return {"path": exe_path, "type": "direct", "name": exe_name}
	
	# If no direct executable found, look for .app bundles
	var dir_contents = FS.list_dir(game_dir)
	for item in dir_contents:
		if item.ends_with(".app"):
			var app_path = game_dir.plus_file(item)
			var exe_info = _find_app_bundle_executable(app_path, exe_names)
			if not exe_info.empty():
				exe_info["type"] = "app_bundle"
				exe_info["app_name"] = item
				return exe_info
	
	return {}


func _find_app_bundle_executable(app_path: String, preferred_names: Array) -> Dictionary:
	# Find the executable inside a .app bundle
	
	var d = Directory.new()
	var macos_path = app_path.plus_file("Contents").plus_file("MacOS")
	
	if not d.dir_exists(macos_path):
		return {}
	
	var macos_contents = FS.list_dir(macos_path)
	
	# First, try to find preferred executable names
	for preferred_name in preferred_names:
		for exe_file in macos_contents:
			if exe_file == preferred_name:
				var full_path = macos_path.plus_file(exe_file)
				if d.file_exists(full_path):
					return {"path": full_path, "name": exe_file}
	
	# If no preferred name found, use the first executable file
	for exe_file in macos_contents:
		var full_path = macos_path.plus_file(exe_file)
		if d.file_exists(full_path):
			return {"path": full_path, "name": exe_file}
	
	return {}


func _verify_executable_permissions(exe_path: String) -> bool:
	# Verify that a file has executable permissions on Unix-like systems
	
	if OS.get_name() != "OSX" and OS.get_name() != "X11":
		return true  # On Windows, we assume files are executable
	
	# Use 'test -x' to check if file is executable
	var result = OS.execute("test", ["-x", exe_path], true)
	return result == 0


func _launch_game_with_working_dir(command_path: String, command_args: PoolStringArray, working_dir: String, world: String) -> void:
	# Launch game with proper working directory and process monitoring
	
	# Show appropriate status message
	var game_name = command_path.get_file()
	Status.post(tr("Starting game: %s") % game_name)
	Status.post(tr("msg_setting_working_dir") % working_dir)
	
	# For Unix systems, we need to use a shell command to change directory and launch
	var shell_command = "cd '%s' && '%s'" % [_escape_path(working_dir), _escape_path(command_path)]
	for arg in command_args:
		shell_command += " '%s'" % _escape_path(arg)
	
	var final_command_path = "/bin/bash"
	var final_command_args = ["-c", shell_command]
	
	# Launch game with process monitoring using the existing system
	_game_process.execute(final_command_path, final_command_args, false)
	
	# Inform user about monitoring
	if Settings.read("backup_after_closing"):
		Status.post(tr("Game launched. Monitoring process for automatic backup when game closes..."))


func _launch_app_bundle(exe_info: Dictionary, world: String) -> void:
	# Launch macOS app bundle using 'open' command with proper monitoring
	
	var app_bundle_path = exe_info["path"].get_base_dir().get_base_dir().get_base_dir()  # Go up from Contents/MacOS to .app
	var app_name = exe_info.get("app_name", app_bundle_path.get_file())
	
	Status.post(tr("Starting macOS app bundle: %s") % app_name)
	
	# Build 'open' command with arguments
	var open_args = [app_bundle_path]
	
	# Add game arguments if needed
	var has_args = false
	if Paths.userdata != "":
		if not has_args:
			open_args.append("--args")
			has_args = true
		open_args.append("--userdir")
		open_args.append(Paths.userdata)
	
	if world != "":
		if not has_args:
			open_args.append("--args")
			has_args = true
		open_args.append("--world")
		open_args.append(world)
	
	# Launch using 'open' command with process monitoring
	_game_process.execute("open", open_args, false)
	
	# Inform user about monitoring
	if Settings.read("backup_after_closing"):
		Status.post(tr("Game launched. Monitoring process for automatic backup when game closes..."))


func _escape_path(path: String) -> String:
	# Properly escape paths for shells
	if OS.get_name() == "Windows":
		# Windows cmd.exe escaping
		return "\"%s\"" % path.replace("\"", "\\\"")
	else:
		# Unix shell escaping - escape single quotes for use within single quotes
		# Single quotes can't be escaped within single quotes, so we end the quote,
		# add an escaped single quote, then start a new quoted string
		return path.replace("'", "'\"'\"'")  # Replace ' with '"'"'


func _exit_tree() -> void:
	# Clean up game process monitoring if still active
	if _game_process:
		_game_process = null
	
	# Note: Backup creation is now handled in _on_game_process_exited()
	# when the game actually closes, not when the launcher closes
