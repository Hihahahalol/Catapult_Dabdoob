extends Node


signal copy_dir_done
signal rm_dir_done
signal move_dir_done
signal extract_done
signal zip_done


var _platform: String = ""

var last_extract_result: int = 0 setget , _get_last_extract_result
# Stores the exit code of the last extract operation (0 if successful).
var last_zip_result: int = 0 setget , _get_last_zip_result
# Stores the exit code of the last zip operation (0 if successful).


func _enter_tree() -> void:
	
	_platform = OS.get_name()
	# Normalize platform names for consistent usage
	if _platform == "OSX":
		_platform = "OSX"  # Keep OSX for consistency with Godot's naming


func _get_last_extract_result() -> int:
	
	return last_extract_result


func _get_last_zip_result() -> int:
	return last_zip_result
	

func list_dir(path: String, recursive := false) -> Array:
	# Lists the files and subdirectories within a directory.
	
	var d = Directory.new()
	d.open(path)
	
	var error = d.list_dir_begin(true)
	if error:
		Status.post(tr("msg_list_dir_failed") % [path, error], Enums.MSG_ERROR)
		return []
	
	var result = []
	
	while true:
		var name = d.get_next()
		if name:
			result.append(name)
			if recursive and d.current_is_dir():
				var subdir = list_dir(path.plus_file(name), true)
				for child in subdir:
					result.append(name.plus_file(child))
		else:
			break
	
	return result


func _copy_dir_internal(data: Array) -> void:
	
	var abs_path: String = data[0]
	var dest_dir: String = data[1]
	
	var dir = abs_path.get_file()
	var d = Directory.new()
	
	var error = d.make_dir_recursive(dest_dir.plus_file(dir))
	if error:
		Status.post(tr("msg_cannot_create_target_dir") % [dest_dir.plus_file(dir), error], Enums.MSG_ERROR)
		return
	
	for item in list_dir(abs_path):
		var path = abs_path.plus_file(item)
		if d.file_exists(path):
			error = d.copy(path, dest_dir.plus_file(dir).plus_file(item))
			if error:
				Status.post(tr("msg_copy_file_failed") % [item, error], Enums.MSG_ERROR)
				Status.post(tr("msg_copy_file_failed_details") % [path, dest_dir.plus_file(dir).plus_file(item)])
		elif d.dir_exists(path):
			_copy_dir_internal([path, dest_dir.plus_file(dir)])


func copy_dir(abs_path: String, dest_dir: String) -> void:
	# Recursively copies a directory *into* a new location.
	
	var tfe = ThreadedFuncExecutor.new()
	tfe.execute(self, "_copy_dir_internal", [abs_path, dest_dir])
	yield(tfe, "func_returned")
	tfe.collect()
	emit_signal("copy_dir_done")


func _rm_dir_internal(data: Array) -> void:
	
	var abs_path = data[0]
	var d = Directory.new()
	var error
	
	for item in list_dir(abs_path):
		var path = abs_path.plus_file(item)
		if d.file_exists(path):
			error = d.remove(path)
			if error:
				Status.post(tr("msg_remove_file_failed") % [item, error], Enums.MSG_ERROR)
				Status.post(tr("msg_remove_file_failed_details") % path, Enums.MSG_DEBUG)
		elif d.dir_exists(path):
			_rm_dir_internal([path])
	
	error = d.remove(abs_path)
	if error:
		Status.post(tr("msg_rm_dir_failed") % [abs_path, error], Enums.MSG_ERROR)


func rm_dir(abs_path: String) -> void:
	# Recursively removes a directory.
	
	var tfe = ThreadedFuncExecutor.new()
	tfe.execute(self, "_rm_dir_internal", [abs_path])
	yield(tfe, "func_returned")
	tfe.collect()
	emit_signal("rm_dir_done")


func _move_dir_internal(data: Array) -> void:
	
	var abs_path: String = data[0]
	var abs_dest: String = data[1]
	
	var d = Directory.new()
	var error = d.make_dir_recursive(abs_dest)
	if error:
		Status.post(tr("msg_create_dir_failed") % [abs_dest, error], Enums.MSG_ERROR)
		return
	
	for item in list_dir(abs_path):
		var path = abs_path.plus_file(item)
		var dest = abs_dest.plus_file(item)
		if d.file_exists(path):
			error = d.rename(path, abs_dest.plus_file(item))
			if error:
				Status.post(tr("msg_move_file_failed") % [item, error], Enums.MSG_ERROR)
				Status.post(tr("msg_move_file_failed_details") % [path, dest])
		elif d.dir_exists(path):
			_move_dir_internal([path, abs_dest.plus_file(item)])
	
	error = d.remove(abs_path)
	if error:
		Status.post(tr("msg_move_rmdir_failed") % [abs_path, error], Enums.MSG_ERROR)


func move_dir(abs_path: String, abs_dest: String) -> void:
	# Moves the specified directory (this is move with rename, so the last
	# part of dest is the new name for the directory).
	
	var tfe = ThreadedFuncExecutor.new()
	tfe.execute(self, "_move_dir_internal", [abs_path, abs_dest])
	yield(tfe, "func_returned")
	tfe.collect()
	emit_signal("move_dir_done")


func extract(path: String, dest_dir: String) -> void:
	# Extracts a .zip, .tar.gz, or .dmg archive using 7-Zip on Windows, Linux, and macOS
	# Falls back to system utilities on Linux/macOS if 7-Zip is not available.
	
	var sevenzip_exe
	if OS.get_name() == "Windows":
		sevenzip_exe = Paths.utils_dir.plus_file("7za.exe")
	elif OS.get_name() == "OSX":
		sevenzip_exe = Paths.utils_dir.plus_file("7za")
	else:  # Linux (X11)
		sevenzip_exe = Paths.utils_dir.plus_file("7za")
	
	var command_linux_zip = {
		"name": "unzip",
		"args": ["-o", "%s" % path, "-d", "%s" % dest_dir]
	}
	var command_linux_gz = {
		"name": "tar",
		"args": ["-xzf", path, "-C", dest_dir,
				"--exclude=*doc/CONTRIBUTING.md", "--exclude=*doc/JSON_LOADING_ORDER.md"]
				# Godot can't operate on symlinks just yet, so we have to avoid them.
	}
	var command_sevenzip_windows = {
		"name": "cmd",
		"args": ["/C", "\"%s\" x \"%s\" -o\"%s\" -y" % [sevenzip_exe.replace("/", "\\"), path.replace("/", "\\"), dest_dir.replace("/", "\\")]]
	}
	var command_sevenzip_unix = {
		"name": "/bin/bash",
		"args": ["-c", "'%s' x '%s' -o'%s' -y" % [sevenzip_exe, path, dest_dir]]
	}
	var command
	
	var d = Directory.new()
	
	# Handle DMG files on macOS
	if OS.get_name() == "OSX" and path.to_lower().ends_with(".dmg"):
		_extract_dmg(path, dest_dir)
		return
	
	# On Linux/macOS, prefer system utilities for better compatibility
	if (_platform == "X11" or _platform == "OSX") and (path.to_lower().ends_with(".tar.gz")):
		Status.post("[debug] Using system tar for .tar.gz extraction")
		command = command_linux_gz
	elif (_platform == "X11" or _platform == "OSX") and (path.to_lower().ends_with(".zip")):
		Status.post("[debug] Using system unzip for .zip extraction")
		command = command_linux_zip
	# Try to use 7-Zip on all platforms as fallback
	elif d.file_exists(sevenzip_exe) and (path.to_lower().ends_with(".zip") or path.to_lower().ends_with(".tar.gz")):
		Status.post("[debug] Extracting: " + path + " to: " + dest_dir)
		if OS.get_name() == "Windows":
			command = command_sevenzip_windows
		else:  # Linux (X11) or macOS (OSX)
			command = command_sevenzip_unix
	elif (_platform == "Windows") and (path.to_lower().ends_with(".zip")):
		# On Windows, 7-Zip should always be available
		if not d.file_exists(sevenzip_exe):
			Status.post("[error] 7za.exe not found at: " + sevenzip_exe, Enums.MSG_ERROR)
			last_extract_result = 1
			emit_signal("extract_done")
			return
		Status.post("[debug] Extracting: " + path + " to: " + dest_dir)
		command = command_sevenzip_windows
	else:
		Status.post(tr("msg_extract_unsupported") % path.get_file(), Enums.MSG_ERROR)
		last_extract_result = 1
		emit_signal("extract_done")
		return
		
	if not d.dir_exists(dest_dir):
		var make_dir_result = d.make_dir_recursive(dest_dir)
		if make_dir_result != OK:
			Status.post(tr("msg_extract_create_dir_failed") % [dest_dir, make_dir_result], Enums.MSG_ERROR)
			last_extract_result = make_dir_result
			emit_signal("extract_done")
			return
		
	Status.post(tr("msg_extracting_file") % path.get_file())
	Status.post("[debug] Extract command: " + str(command), Enums.MSG_DEBUG)
	
	# Check if extraction tool is available
	if not _check_extraction_tool_available(command["name"]):
		last_extract_result = 127  # Command not found
		emit_signal("extract_done")
		return
		
	var oew = OSExecWrapper.new()
	oew.execute(command["name"], command["args"], false)
	yield(oew, "process_exited")
	last_extract_result = oew.exit_code
	if oew.exit_code:
		Status.post(tr("msg_extract_error") % oew.exit_code, Enums.MSG_ERROR)
		Status.post(tr("msg_extract_failed_cmd") % str(command), Enums.MSG_DEBUG)
		if oew.output.size() > 0:
			for i in range(oew.output.size()):
				Status.post("[Extract output] " + str(oew.output[i]), Enums.MSG_ERROR)
		else:
			Status.post("[Extract] No output captured", Enums.MSG_ERROR)
	emit_signal("extract_done")


func _extract_dmg(dmg_path: String, dest_dir: String) -> void:
	# Extract DMG files on macOS using hdiutil
	
	if OS.get_name() != "OSX":
		Status.post(tr("msg_dmg_only_macos"), Enums.MSG_ERROR)
		last_extract_result = 1
		emit_signal("extract_done")
		return
	
	var d = Directory.new()
	if not d.dir_exists(dest_dir):
		var make_dir_result = d.make_dir_recursive(dest_dir)
		if make_dir_result != OK:
			Status.post(tr("msg_extract_create_dir_failed") % [dest_dir, make_dir_result], Enums.MSG_ERROR)
			last_extract_result = make_dir_result
			emit_signal("extract_done")
			return
	
	Status.post(tr("msg_mounting_dmg") % dmg_path.get_file())
	
	# Mount the DMG
	var mount_command = {
		"name": "hdiutil",
		"args": ["attach", "-readonly", "-nobrowse", "-plist", dmg_path]
	}
	
	var oew = OSExecWrapper.new()
	oew.execute(mount_command["name"], mount_command["args"], true)
	yield(oew, "process_exited")
	
	if oew.exit_code != 0:
		Status.post(tr("msg_dmg_mount_failed") % oew.exit_code, Enums.MSG_ERROR)
		last_extract_result = oew.exit_code
		emit_signal("extract_done")
		return
	
	# Parse the mount point from plist output
	var mount_point = _parse_dmg_mount_point(oew.output)
	if mount_point == "":
		Status.post(tr("msg_dmg_mount_point_failed"), Enums.MSG_ERROR)
		last_extract_result = 1
		emit_signal("extract_done")
		return
	
	Status.post(tr("msg_copying_dmg_contents") % mount_point)
	
	# Copy contents from mounted DMG
	copy_dir(mount_point, dest_dir)
	yield(self, "copy_dir_done")
	
	# Unmount the DMG
	Status.post(tr("msg_unmounting_dmg"))
	var unmount_command = {
		"name": "hdiutil",
		"args": ["detach", mount_point]
	}
	
	var unmount_oew = OSExecWrapper.new()
	unmount_oew.execute(unmount_command["name"], unmount_command["args"], false)
	yield(unmount_oew, "process_exited")
	
	if unmount_oew.exit_code != 0:
		Status.post(tr("msg_dmg_unmount_warning") % unmount_oew.exit_code, Enums.MSG_WARNING)
	
	last_extract_result = 0
	emit_signal("extract_done")


func _parse_dmg_mount_point(plist_output: Array) -> String:
	# Parse the mount point from hdiutil plist output
	
	if plist_output.empty():
		return ""
	
	var plist_text = ""
	for line in plist_output:
		plist_text += str(line) + "\n"
	
	# Look for mount-point in the plist output
	var lines = plist_text.split("\n")
	var found_mount_point = false
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if line == "<key>mount-point</key>":
			found_mount_point = true
		elif found_mount_point and line.begins_with("<string>"):
			# Extract mount point from <string>/Volumes/something</string>
			var start_pos = line.find("<string>") + 8
			var end_pos = line.find("</string>")
			if end_pos > start_pos:
				return line.substr(start_pos, end_pos - start_pos)
	
	return ""


func _check_extraction_tool_available(tool_name: String) -> bool:
	# Check if the extraction tool is available on the system
	
	var check_command = ""
	var check_args = []
	
	match OS.get_name():
		"Windows":
			if tool_name == "cmd":
				return true  # cmd is always available on Windows
			else:
				check_command = "where"
				check_args = [tool_name]
		"OSX", "X11":
			check_command = "which"
			check_args = [tool_name]
	
	if check_command == "":
		return true  # Assume available if we can't check
	
	var result = OS.execute(check_command, check_args, true)
	if result != 0:
		Status.post(tr("msg_extract_tool_not_found") % tool_name, Enums.MSG_ERROR)
		return false
	
	return true


func zip(parent: String, dir_to_zip: String, dest_zip: String) -> void:
	# Creates a .zip using 7-Zip on Windows, Linux, and macOS for better performance.
	# Falls back to system zip on Linux/macOS if 7-Zip is not available.
	# parent: directory that zip command is run from  (Path.savegames)
	# dir_to_zip: relative folder to zip up  (world_name)
	# dest_zip: zip name   (world_name.zip)
	# 
	# runs a command like:
	# cd <userdata/save> && 7za a MyWorld.zip MyWorld
	
	var sevenzip_exe
	if OS.get_name() == "Windows":
		sevenzip_exe = Paths.utils_dir.plus_file("7za.exe")
	elif OS.get_name() == "OSX":
		sevenzip_exe = Paths.utils_dir.plus_file("7za")
	else:  # Linux (X11)
		sevenzip_exe = Paths.utils_dir.plus_file("7za")
	
	var command_unix_zip = {
		"name": "/bin/bash",
		"args": ["-c", "cd '%s' && zip -r '%s' '%s'" % [parent, dest_zip, dir_to_zip]]
	}
	var command_sevenzip_windows = {
		"name": "cmd",
		"args": ["/C", "cd /d \"%s\" && \"%s\" a \"%s\" \"%s\" -mx5" % [parent, sevenzip_exe, dest_zip, dir_to_zip]]
	}
	var command_sevenzip_unix = {
		"name": "/bin/bash",
		"args": ["-c", "cd '%s' && '%s' a '%s' '%s' -mx5" % [parent, sevenzip_exe, dest_zip, dir_to_zip]]
	}
	var command
	
	var d = Directory.new()
	
	if not dest_zip.to_lower().ends_with(".zip"):
		Status.post(tr("msg_extract_unsupported") % dest_zip.get_file(), Enums.MSG_ERROR)
		emit_signal("zip_done")
		return
	
	# Try to use 7-Zip first for better performance
	if d.file_exists(sevenzip_exe):
		if OS.get_name() == "Windows":
			command = command_sevenzip_windows
		else:  # Linux (X11) or macOS (OSX)
			command = command_sevenzip_unix
	# Fall back to system zip on Linux/macOS
	elif _platform == "X11" or _platform == "OSX":
		Status.post("[debug] Using system zip for compression")
		command = command_unix_zip
	else:
		Status.post(tr("msg_extract_unsupported") % dest_zip.get_file(), Enums.MSG_ERROR)
		emit_signal("zip_done")
		return
	
	Status.post(tr("msg_zipping_file") % dest_zip.get_file())
		
	var oew = OSExecWrapper.new()
	oew.execute(command["name"], command["args"], false)
	yield(oew, "process_exited")
	last_zip_result = oew.exit_code
	if oew.exit_code:
		Status.post(tr("msg_zip_error") % oew.exit_code, Enums.MSG_ERROR)
		Status.post(tr("msg_extract_failed_cmd") % str(command), Enums.MSG_DEBUG)
		if oew.output.size() > 0:
			Status.post(tr("msg_extract_fail_output") % oew.output[0], Enums.MSG_DEBUG)
	emit_signal("zip_done")
	