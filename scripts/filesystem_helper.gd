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
	# Extracts .zip, .tar.gz, or .dmg archives using 7-Zip on Windows, Linux, and macOS
	# Falls back to system utilities on Linux/macOS if 7-Zip is not available.
	# On macOS, uses hdiutil for .dmg file extraction.
	
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
	
	# On Linux/macOS, prefer system utilities for better compatibility
	if (_platform == "X11" or _platform == "OSX") and (path.to_lower().ends_with(".tar.gz")):
		Status.post("[debug] Using system tar for .tar.gz extraction")
		command = command_linux_gz
	elif (_platform == "X11" or _platform == "OSX") and (path.to_lower().ends_with(".zip")):
		Status.post("[debug] Using system unzip for .zip extraction")
		command = command_linux_zip
	elif (_platform == "OSX") and (path.to_lower().ends_with(".dmg")):
		Status.post("[debug] Using hdiutil for .dmg extraction on macOS")
		# Create a temporary script for DMG extraction with better error handling
		var script_content = """#!/bin/bash
echo "=== DMG Extraction Debug ==="
echo "DMG file: %s"
echo "Destination: %s"
echo "Current user: $(whoami)"
echo "Current directory: $(pwd)"

# Test if hdiutil is available (try common locations)
HDIUTIL_PATH=""
for path in /usr/bin/hdiutil /bin/hdiutil /usr/local/bin/hdiutil; do
    if [ -x "$path" ]; then
        HDIUTIL_PATH="$path"
        break
    fi
done

if [ -z "$HDIUTIL_PATH" ]; then
    echo "ERROR: hdiutil command not found in common locations"
    echo "Searched: /usr/bin/hdiutil /bin/hdiutil /usr/local/bin/hdiutil"
    exit 1
fi

echo "Found hdiutil at: $HDIUTIL_PATH"

# Test if DMG file exists and is readable
if [ ! -f "%s" ]; then
    echo "ERROR: DMG file does not exist: %s"
    exit 1
fi

if [ ! -r "%s" ]; then
    echo "ERROR: DMG file is not readable: %s"
    exit 1
fi

echo "Attempting to mount DMG file..."
MOUNT_OUTPUT=$("$HDIUTIL_PATH" attach '%s' -nobrowse -quiet 2>&1)
MOUNT_RESULT=$?
echo "hdiutil attach exit code: $MOUNT_RESULT"
echo "hdiutil attach output: $MOUNT_OUTPUT"

if [ $MOUNT_RESULT -ne 0 ]; then
    echo "ERROR: Failed to mount DMG file"
    echo "Mount output: $MOUNT_OUTPUT"
    exit 2
fi

MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | tail -1 | cut -f3)
echo "Extracted mount point: '$MOUNT_POINT'"

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    echo "ERROR: Invalid mount point: '$MOUNT_POINT'"
    exit 3
fi

echo "Mount successful. Listing contents of mount point:"
ls -la "$MOUNT_POINT" || echo "Failed to list mount point contents"

echo "Creating destination directory if needed..."
mkdir -p "%s"

echo "Copying files from '$MOUNT_POINT' to '%s'..."
echo "Source contents:"
ls -la "$MOUNT_POINT" 2>&1 || echo "Failed to list source"
echo "Destination before copy:"
ls -la "%s" 2>&1 || echo "Destination doesn't exist yet"

# Use more robust copy with better error handling
echo "Executing: cp -R \"$MOUNT_POINT\"/. \"%s/\""
cp -R "$MOUNT_POINT"/. "%s/" 2>&1
COPY_RESULT=$?
echo "Copy exit code: $COPY_RESULT"

echo "Destination after copy:"
ls -la "%s" 2>&1 || echo "Failed to list destination"

if [ $COPY_RESULT -ne 0 ]; then
    echo "ERROR: Failed to copy files"
    "$HDIUTIL_PATH" detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 4
fi

echo "Unmounting DMG..."
"$HDIUTIL_PATH" detach "$MOUNT_POINT" -quiet 2>&1
DETACH_RESULT=$?
echo "Detach exit code: $DETACH_RESULT"

if [ $DETACH_RESULT -ne 0 ]; then
    echo "WARNING: Failed to cleanly unmount DMG, but extraction completed"
fi

echo "DMG extraction completed successfully"
exit 0
""" % [path, dest_dir, path, path, path, path, path, dest_dir, dest_dir, dest_dir]
		
		var script_path = OS.get_user_data_dir().plus_file("dmg_extract.sh")
		var script_file = File.new()
		script_file.open(script_path, File.WRITE)
		script_file.store_string(script_content)
		script_file.close()
		
		# Make script executable
		OS.execute("chmod", ["+x", script_path], true)
		
		command = {
			"name": "/bin/bash",
			"args": [script_path]
		}
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
			emit_signal("extract_done")
			return
		Status.post("[debug] Extracting: " + path + " to: " + dest_dir)
		command = command_sevenzip_windows
	else:
		Status.post(tr("msg_extract_unsupported") % path.get_file(), Enums.MSG_ERROR)
		emit_signal("extract_done")
		return
		
	if not d.dir_exists(dest_dir):
		var make_dir_error = d.make_dir_recursive(dest_dir)
		if make_dir_error != OK:
			Status.post("[error] Failed to create extraction directory: " + dest_dir + " (error: " + str(make_dir_error) + ")", Enums.MSG_ERROR)
			last_extract_result = make_dir_error
			emit_signal("extract_done")
			return
		
	Status.post(tr("msg_extracting_file") % path.get_file())
	Status.post("[debug] Extract command: " + str(command), Enums.MSG_DEBUG)
		
	var oew = OSExecWrapper.new()
	oew.execute(command["name"], command["args"], true)  # Enable output capture
	yield(oew, "process_exited")
	last_extract_result = oew.exit_code
	
	# Clean up temporary DMG script if it was created
	if (_platform == "OSX") and (path.to_lower().ends_with(".dmg")):
		var script_path = OS.get_user_data_dir().plus_file("dmg_extract.sh")
		var cleanup_dir = Directory.new()
		if cleanup_dir.file_exists(script_path):
			cleanup_dir.remove(script_path)
	
	if oew.exit_code:
		Status.post(tr("msg_extract_error") % oew.exit_code, Enums.MSG_ERROR)
		Status.post(tr("msg_extract_failed_cmd") % str(command), Enums.MSG_DEBUG)
		if oew.output.size() > 0:
			for i in range(oew.output.size()):
				Status.post("[DMG/7-Zip output] " + str(oew.output[i]), Enums.MSG_ERROR)
		else:
			Status.post("[DMG/7-Zip] No output captured", Enums.MSG_ERROR)
		
		# For DMG files, try a simpler fallback approach
		if (_platform == "OSX") and (path.to_lower().ends_with(".dmg")):
			Status.post("[debug] Trying fallback DMG extraction method...")
			yield(_try_dmg_fallback(path, dest_dir), "extract_done")
			return
	emit_signal("extract_done")


func _try_dmg_fallback(path: String, dest_dir: String) -> void:
	# Simple fallback DMG extraction using step-by-step commands
	Status.post("[debug] Attempting step-by-step DMG fallback extraction...")
	Status.post("[debug] DMG file: " + path)
	Status.post("[debug] Destination: " + dest_dir)
	
	# Step 1: Mount the DMG
	Status.post("[debug] Step 1: Mounting DMG...")
	var mount_command = {
		"name": "/usr/bin/hdiutil",
		"args": ["attach", path, "-nobrowse", "-quiet"]
	}
	
	var oew_mount = OSExecWrapper.new()
	oew_mount.execute(mount_command["name"], mount_command["args"], true)
	yield(oew_mount, "process_exited")
	
	Status.post("[debug] Mount exit code: " + str(oew_mount.exit_code))
	if oew_mount.output.size() > 0:
		for i in range(oew_mount.output.size()):
			Status.post("[DMG Mount] " + str(oew_mount.output[i]), Enums.MSG_DEBUG)
	
	if oew_mount.exit_code != 0:
		Status.post("[error] Failed to mount DMG", Enums.MSG_ERROR)
		last_extract_result = oew_mount.exit_code
		emit_signal("extract_done")
		return
	
	# Step 2: Find the mount point from the output
	var mount_point = ""
	Status.post("[debug] hdiutil output lines: " + str(oew_mount.output.size()))
	
	if oew_mount.output.size() > 0:
		for i in range(oew_mount.output.size()):
			var line = oew_mount.output[i]
			Status.post("[debug] Output line " + str(i) + ": " + line)
			
			# Try different parsing methods
			if "/Volumes/" in line:
				# Look for /Volumes/ path in the line
				var volumes_start = line.find("/Volumes/")
				if volumes_start != -1:
					var path_part = line.substr(volumes_start)
					# Extract just the path (stop at whitespace or tab)
					var space_pos = path_part.find(" ")
					var tab_pos = path_part.find("\t")
					var end_pos = -1
					
					if space_pos != -1 and tab_pos != -1:
						end_pos = min(space_pos, tab_pos)
					elif space_pos != -1:
						end_pos = space_pos
					elif tab_pos != -1:
						end_pos = tab_pos
					
					if end_pos != -1:
						mount_point = path_part.substr(0, end_pos)
					else:
						mount_point = path_part.strip_edges()
					break
	
	Status.post("[debug] Detected mount point: '" + mount_point + "'")
	
	if mount_point == "":
		Status.post("[error] Could not determine mount point from hdiutil output", Enums.MSG_ERROR)
		Status.post("[debug] Trying alternative: look for any /Volumes/ directory...")
		
		# Fallback: try to find the volume by listing /Volumes/
		var volumes_command = {
			"name": "/bin/ls",
			"args": ["/Volumes/"]
		}
		
		var oew_volumes = OSExecWrapper.new()
		oew_volumes.execute(volumes_command["name"], volumes_command["args"], true)
		yield(oew_volumes, "process_exited")
		
		if oew_volumes.exit_code == 0 and oew_volumes.output.size() > 0:
			Status.post("[debug] Available volumes:")
			for i in range(oew_volumes.output.size()):
				var volume_name = oew_volumes.output[i].strip_edges()
				Status.post("[debug] Volume: " + volume_name)
				# Look for a volume that might be our DMG (contains common game-related keywords)
				if "cdda" in volume_name.to_lower() or "cataclysm" in volume_name.to_lower() or "ctlg" in volume_name.to_lower():
					mount_point = "/Volumes/" + volume_name
					Status.post("[debug] Using detected game volume: " + mount_point)
					break
		
		if mount_point == "":
			Status.post("[error] Could not determine mount point even with fallback", Enums.MSG_ERROR)
			last_extract_result = 1
			emit_signal("extract_done")
			return
	
	# Step 3: Create destination directory
	var dir = Directory.new()
	if not dir.dir_exists(dest_dir):
		Status.post("[debug] Creating destination directory: " + dest_dir)
		var make_dir_error = dir.make_dir_recursive(dest_dir)
		if make_dir_error != OK:
			Status.post("[error] Failed to create destination directory: " + dest_dir + " (error: " + str(make_dir_error) + ")", Enums.MSG_ERROR)
			last_extract_result = make_dir_error
			emit_signal("extract_done")
			return
	
	# Step 4: Examine volume contents first
	Status.post("[debug] Step 2: Examining volume contents...")
	var ls_command = {
		"name": "/bin/ls",
		"args": ["-la", mount_point]
	}
	
	var oew_ls = OSExecWrapper.new()
	oew_ls.execute(ls_command["name"], ls_command["args"], true)
	yield(oew_ls, "process_exited")
	
	Status.post("[debug] Volume contents (ls exit code: " + str(oew_ls.exit_code) + "):")
	if oew_ls.output.size() > 0:
		for line in oew_ls.output:
			Status.post("[debug] " + line)
	if oew_ls.error_output.size() > 0:
		for line in oew_ls.error_output:
			Status.post("[debug] ls error: " + line)
	
	# Step 5: Copy files using system cp command
	Status.post("[debug] Step 3: Copying files from " + mount_point + " to " + dest_dir)
	var copy_command = {
		"name": "/bin/cp",
		"args": ["-R", mount_point + "/.", dest_dir + "/"]
	}
	
	var oew_copy = OSExecWrapper.new()
	oew_copy.execute(copy_command["name"], copy_command["args"], true)
	yield(oew_copy, "process_exited")
	
	Status.post("[debug] Copy exit code: " + str(oew_copy.exit_code))
	if oew_copy.output.size() > 0:
		for line in oew_copy.output:
			Status.post("[debug] Copy output: " + line)
	if oew_copy.error_output.size() > 0:
		for line in oew_copy.error_output:
			Status.post("[debug] Copy error: " + line)
	
	# Step 6: Unmount the DMG (always try, even if copy failed)
	Status.post("[debug] Step 4: Unmounting DMG...")
	var unmount_command = {
		"name": "/usr/bin/hdiutil",
		"args": ["detach", mount_point, "-quiet"]
	}
	
	var oew_unmount = OSExecWrapper.new()
	oew_unmount.execute(unmount_command["name"], unmount_command["args"], true)
	yield(oew_unmount, "process_exited")
	
	Status.post("[debug] Unmount exit code: " + str(oew_unmount.exit_code))
	
	# Final result
	last_extract_result = oew_copy.exit_code
	if oew_copy.exit_code == 0:
		Status.post("[debug] DMG fallback extraction succeeded!")
	else:
		Status.post("[error] DMG fallback extraction failed with copy exit code: " + str(oew_copy.exit_code), Enums.MSG_ERROR)
	
	emit_signal("extract_done")


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
	