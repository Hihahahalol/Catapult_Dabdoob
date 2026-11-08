extends Node

signal migrate_userdir_done

enum PatchState { UNPATCHED, PATCHED, UNKNOWN }

# these must be updated if upstream updates Cataclysm.sh
const _ORIG_SCRIPT_HASHES = {
	"bn": "98284e6cd7e52e0e1a6380370580808ccb9dac1ee248b5494fe01625f11b51eb",
	"cata": "fa851b9b3bf24ba30af927b84dba0af3a5f107c8cfdc894e8e865be3c9a37a72",
	"tlg": "0f2f49fe70fac1634dfb59284130c18f4ccc8de287fbe865d034d790ec60444c",
}

# these must be updated if scripts in macos_entry_scripts are modified
const _PATCHED_SCRIPT_HASHES = {
	"bn": "4ab8e05c1bbe85d5ec7deea1fc6d52ef52dd5bed20f1167be1370e1bd9347726",
	"cata": "23b84ceae85aca568b42eaf75c1cb2ef88a1248a9bc842da6fafba2147cff174",
	"tlg": "4b2eb49dad2a36aa015f4d80e916e32195fd84e4cbbd1c0d64651de736350d89",
}

const _SCRIPT_FILENAME = "Cataclysm.sh"
const _TEMP_FILENAME = "Cataclysm.sh.temp"
const _BACKUP_FILENAME = "Cataclysm.sh.orig"

func _get_orig_userdir():
	var game_dir = ""
	match Settings.read("game"):
		"bn":
			game_dir = "Cataclysm-BN"
		"dda":
			game_dir = "Cataclysm"
		"tlg":
			game_dir = "Cataclysm-TLG"
		_:
			return "" # can't support migration for the other forks because their game_dir is also Cataclysm (no one plays them anyways)

	var orig_userdir = ""
	var home_dir = OS.get_environment("HOME")
	if home_dir != "":
		orig_userdir = home_dir.plus_file("Library").plus_file("Application Support")
	else:
		orig_userdir = OS.get_user_data_dir().get_base_dir().get_base_dir().get_base_dir().get_base_dir().plus_file("Application Support")
	orig_userdir = orig_userdir.plus_file(game_dir)

	return orig_userdir

func _get_patch_state(script_path: String, script_type: String):
	var f = File.new()
	var h = f.get_sha256(script_path)
	if h == _ORIG_SCRIPT_HASHES[script_type]:
		return PatchState.UNPATCHED
	if h == _PATCHED_SCRIPT_HASHES[script_type]:
		return PatchState.PATCHED
	return PatchState.UNKNOWN

func _get_script_type(game: String):
	match game:
		"bn":
			return "bn"
		"dda", "eod", "tish":
			return "cata"
		"tlg":
			return "tlg"
		_:
			return ""

func _perm_and_sign(script_path: String, app_bundle_path: String, game: String):
	var result = OS.execute("chmod", ["+x", script_path])
	if result != 0:
		Status.post("Failed to set permissions for Cataclysm.sh script: " + str(result), Enums.MSG_WARN)

	# only cdda and tlg signs their released app bundle
	if game != "dda" and game != "tlg": return
	
	result = OS.execute("/usr/bin/codesign", ["--force", "--sign", "-", app_bundle_path], true)
	if result != 0:
		Status.post("Failed to sign Cataclysm.app: " + str(result), Enums.MSG_WARN)

func patch(app_bundle_path: String):
	if OS.get_name() != "OSX": return

	var d = Directory.new()
	var f = File.new()
	var game = Settings.read("game")
	var script_path = app_bundle_path.plus_file("Contents").plus_file("MacOS").plus_file(_SCRIPT_FILENAME)
	var script_type = _get_script_type(game)
	if script_type == "": return
	if not d.file_exists(script_path):
		Status.post("MacOS app bundle entry script (Cataclysm.sh) not found.", Enums.MSG_ERROR)
		return
	
	match _get_patch_state(script_path, script_type):
		PatchState.PATCHED:
			return
		PatchState.UNKNOWN:
			Status.post("MacOS Cataclysm.sh script has been updated in upstream or modified. Skipping patching.", Enums.MSG_WARN)
			return

	Status.post(tr("msg_macos_patch_start"), Enums.MSG_INFO)
	# backup orig to game dir
	var error = d.copy(script_path, Paths.game_dir.plus_file(_BACKUP_FILENAME))
	if error != OK:
		Status.post("Failed to back up MacOS Cataclysm.sh script: " + str(error), Enums.MSG_ERROR)
		return
	
	# load patch
	var patch = MacosEntry.SCRIPTS[script_type]
	if patch.sha256_text() != _PATCHED_SCRIPT_HASHES[script_type]:
		Status.post("MacOS Cataclysm.sh patch file corrupted.", Enums.MSG_ERROR)
		return

	var temp_path = Paths.game_dir.plus_file(_TEMP_FILENAME)
	error = f.open(temp_path, File.WRITE)
	if error == OK:
		f.store_string(patch)
		f.close()
	else:
		Status.post("Failed to open MacOS Cataclysm.sh temp script: " + str(error), Enums.MSG_ERROR)
		return
	
	error = d.rename(temp_path, script_path)
	if error != OK:
		Status.post("Failed to write MacOS Cataclysm.sh script: " + str(error), Enums.MSG_ERROR)
		return
	
	_perm_and_sign(script_path, app_bundle_path, game)
	Status.post(tr("msg_macos_patch_success"), Enums.MSG_INFO)

func unpatch(app_bundle_path: String):
	if OS.get_name() != "OSX": return

	var d = Directory.new()
	var f = File.new()
	var game = Settings.read("game")
	var script_path = app_bundle_path.plus_file("Contents").plus_file("MacOS").plus_file(_SCRIPT_FILENAME)
	var script_type = _get_script_type(game)
	if script_type == "": return
	if not d.file_exists(script_path):
		Status.post("MacOS app bundle entry script (Cataclysm.sh) not found.", Enums.MSG_ERROR)
		return

	match _get_patch_state(script_path, script_type):
		PatchState.UNPATCHED:
			return
		PatchState.UNKNOWN:
			Status.post("[debug] MacOS Cataclysm.sh script has been updated in upstream or modified. Skipping restore.", Enums.MSG_DEBUG)
			return

	Status.post(tr("msg_macos_unpatch_start"), Enums.MSG_INFO)
	var backup_path = Paths.game_dir.plus_file(_BACKUP_FILENAME)
	if not d.file_exists(backup_path):
		Status.post("Backed up original version of Cataclysm.sh not found. Skipping restore.", Enums.MSG_WARN)
		return
	if f.get_sha256(backup_path) != _ORIG_SCRIPT_HASHES[script_type]:
		Status.post("Backed up original version of Cataclysm.sh has been modified. Skipping restore.", Enums.MSG_WARN)
		return

	var error = d.copy(backup_path, script_path)
	if error != OK:
		Status.post("Restoring original MacOS Cataclysm.sh script failed: " + str(error), Enums.MSG_ERROR)
		return

	_perm_and_sign(script_path, app_bundle_path, game)
	Status.post(tr("msg_macos_unpatch_success"), Enums.MSG_INFO)

func has_migrated_userdir():
	if OS.get_name() != "OSX": return true
	var d = Directory.new()

	# existence of save dir in launcher's userdir is a good enough indicator
	if d.dir_exists(Paths.savegames): return true

	var orig_userdir = _get_orig_userdir()
	# game is not bn, dda, or tlg 
	if orig_userdir == "": return true
	return !d.dir_exists(orig_userdir) or FS.list_dir(orig_userdir).size() == 0

func migrate_userdir():
	var d = Directory.new()
	var orig_userdir = _get_orig_userdir()

	Status.post(tr("msg_migrate_macos_userdir_start"), Enums.MSG_INFO)
	
	# copy to a temp directory first to ensure atomicity
	var temp_path = Paths.userdata + "_temp"
	if d.dir_exists(temp_path):
		FS.rm_dir(temp_path)
		yield(FS, "rm_dir_done")
	d.make_dir_recursive(temp_path)
	for item in FS.list_dir(orig_userdir):
		var item_path = orig_userdir.plus_file(item)
		if d.file_exists(item_path):
			d.copy(item_path, temp_path.plus_file(item))
		else:
			FS.copy_dir(item_path, temp_path)
			yield(FS, "copy_dir_done")

	if FS.list_dir(temp_path).size() != FS.list_dir(orig_userdir).size():
		Status.post("Failed to copy %s to %s, please copy manually for the launcher-managed features to work" % [orig_userdir, Paths.userdata], Enums.MSG_ERROR)
		FS.rm_dir(temp_path)
		yield(FS, "rm_dir_done")
		emit_signal("migrate_userdir_done")
		return

	# back up old launcher userdata dir
	var backup_userdir = ""
	if d.dir_exists(Paths.userdata):
		var datetime = OS.get_datetime()
		var backup_name = "userdata_backup_%02d-%02d-%02d_%02d-%02d" % [
			datetime["year"] % 100,
			datetime["month"],
			datetime["day"],
			datetime["hour"],
			datetime["minute"],
		]
		var backups_dir = Paths.own_dir.plus_file(Settings.read("game")).plus_file("userdata_backups")
		d.make_dir_recursive(backups_dir)
		backup_userdir = backups_dir.plus_file(backup_name)
		while d.dir_exists(backup_userdir):
			backup_userdir += "_1"
		# we back up and at the same time delete the initial userdata
		FS.move_dir(Paths.userdata, backup_userdir)
		yield(FS, "move_dir_done")

	FS.move_dir(temp_path, Paths.userdata)
	yield(FS, "move_dir_done")

	if d.dir_exists(Paths.userdata):
		Status.post(tr("msg_migrate_macos_userdir_success") % Paths.userdata, Enums.MSG_INFO)
	else:
		Status.post("Failed to copy %s to %s, please copy manually for the launcher-managed features to work" % [orig_userdir, Paths.userdata], Enums.MSG_ERROR)
		if backup_userdir != "":
			FS.move_dir(backup_userdir, Paths.userdata)
			yield(FS, "move_dir_done")

	emit_signal("migrate_userdir_done")