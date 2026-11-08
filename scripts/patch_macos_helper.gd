extends Node

# these must be updated if upstream updates Cataclysm.sh
const _ORIG_SCRIPT_HASHES = {
	"bn": "98284e6cd7e52e0e1a6380370580808ccb9dac1ee248b5494fe01625f11b51eb",
	"cata": "fa851b9b3bf24ba30af927b84dba0af3a5f107c8cfdc894e8e865be3c9a37a72",
	"tlg": "0f2f49fe70fac1634dfb59284130c18f4ccc8de287fbe865d034d790ec60444c",
}

# these must be updated if scripts in scripts/macos_entry_scripts are modified
const _PATCHED_SCRIPT_HASHES = {
	"bn": "4ab8e05c1bbe85d5ec7deea1fc6d52ef52dd5bed20f1167be1370e1bd9347726",
	"cata": "23b84ceae85aca568b42eaf75c1cb2ef88a1248a9bc842da6fafba2147cff174",
	"tlg": "4b2eb49dad2a36aa015f4d80e916e32195fd84e4cbbd1c0d64651de736350d89",
}

const _SCRIPT_FILENAME = "Cataclysm.sh"
const _TEMP_FILENAME = "Cataclysm.sh.temp"
const _BACKUP_FILENAME = "Cataclysm.sh.orig"

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
	
	var h = f.get_sha256(script_path)
	if h == _PATCHED_SCRIPT_HASHES[script_type]:
		return
	if h != _ORIG_SCRIPT_HASHES[script_type]:
		Status.post("MacOS Cataclysm.sh script has been updated in upstream or modified. Skipping patching.", Enums.MSG_WARN)
		return

	# backup orig to game dir
	var error = d.copy(script_path, Paths.game_dir.plus_file(_BACKUP_FILENAME))
	if error != OK:
		Status.post("Failed to back up MacOS Cataclysm.sh script: " + str(error), Enums.MSG_ERROR)
		return
	
	# load patch from resources
	var patch_path = "res://scripts/macos_entry_scripts".plus_file(script_type)
	if f.get_sha256(patch_path) != _PATCHED_SCRIPT_HASHES[script_type]:
		Status.post("MacOS Cataclysm.sh patch file corrupted. Please redownload launcher to enable MacOS patching.", Enums.MSG_ERROR)
		return
	error = f.open(patch_path, File.READ)
	if error != OK:
		Status.post("Failed to open Cataclysm.sh patch file: " + str(error), Enums.MSG_ERROR)
		return
	var patch = f.get_as_text()
	f.close()

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

	var h = f.get_sha256(script_path)
	if h == _ORIG_SCRIPT_HASHES[script_type]:
		return
	if h != _PATCHED_SCRIPT_HASHES[script_type]:
		Status.post("[debug] MacOS Cataclysm.sh script has been updated in upstream or modified. Skipping restore.", Enums.MSG_DEBUG)
		return

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
