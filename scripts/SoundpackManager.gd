extends Node


signal soundpack_installation_started
signal soundpack_installation_finished
signal soundpack_deletion_started
signal soundpack_deletion_finished


const SOUNDPACKS = [
	{
		"name": "CC-Sounds",
		"url": "https://github.com/Fris0uman/CDDA-Soundpacks/releases/latest/download/CC-Sounds.zip",
		"filename": "CC-Sounds.zip",
		"internal_path": "CC-Sounds",
	},
	{
		"name": "CC-Sounds-sfx-only",
		"url": "https://github.com/Fris0uman/CDDA-Soundpacks/releases/latest/download/CC-Sounds-sfx-only.zip",
		"filename": "CC-Sounds-sfx-only.zip",
		"internal_path": "CC-Sounds-sfx-only",
	},
	{
		"name": "CO.AG-music-only",
		"url": "https://github.com/Fris0uman/CDDA-Soundpacks/releases/latest/download/CO.AG-music-only.zip",
		"filename": "CO.AG-music-only.zip",
		"internal_path": "CO.AG-music-only",
	},
	{
		"name": "BeepBoopBip",
		"url": "https://github.com/Golfavel/CDDA-Soundpacks_BeepBoop/archive/refs/heads/master.zip",
		"filename": "BeepBoopBip.zip",
		"internal_path": "CDDA-Soundpacks_BeepBoop-master/sound/BeepBoopBip",
	},
	{
		"name": "@'s soundpack",
		"url": "https://github.com/damalsk/damalsksoundpack/archive/refs/heads/master.zip",
		"filename": "ats-soundpack.zip",
		"internal_path": "damalsksoundpack-master",
	},
	{
		"name": "CDDA-Soundpack",
		"url": "https://github.com/budg3/CDDA-Soundpack/archive/master.zip",
		"filename": "cdda-soundpack.zip",
		"internal_path": "CDDA-Soundpack-master/CDDA-Soundpack",
	},
	{
		"name": "ChestHole",
		"url": "https://web.archive.org/web/20240122133501if_/https://chezzo.com/cdda/ChestHoleSoundSet.zip",
		"filename": "chesthole-soundpack.zip",
		"internal_path": "ChestHole",
	},
	{
		"name": "ChestHoleCC",
		"url": "https://web.archive.org/web/20210401095201if_/http://chezzo.com/cdda/ChestHoleCCSoundset.zip",
		"filename": "chesthole-cc-soundpack.zip",
		"internal_path": "ChestHoleCC",
	},
	{
		"name": "ChestOldTimey",
		"url": "https://web.archive.org/web/20210401095200if_/http://chezzo.com/cdda/ChestOldTimeyLessismore.zip",
		"filename": "chest-old-timey-soundpack.zip",
		"internal_path": "ChestHoleOldTimey",
	},
	{
		"name": "Otopack",
		"url": "https://github.com/Kenan2000/Otopack-Mods-Updates/archive/master.zip",
		"filename": "otopack.zip",
		"internal_path": "Otopack-Mods-Updates-master/Otopack+ModsUpdates",
	},
	{
		"name": "RRFSounds",
		"url": "https://dl.dropboxusercontent.com/s/d8dfmb2facvkdh6/RRFSounds.zip",
		"filename": "rrfsounds.zip",
		"internal_path": "data/sound/RRFSounds",
	},
]


func parse_sound_dir(sound_dir: String) -> Array:
	
	if not Directory.new().dir_exists(sound_dir):
		Status.post(tr("msg_no_sound_dir") % sound_dir, Enums.MSG_ERROR)
		return []
	
	var result = []
	
	for subdir in FS.list_dir(sound_dir):
		var f = File.new()
		var info = sound_dir.plus_file(subdir).plus_file("soundpack.txt")
		if f.file_exists(info):
			f.open(info, File.READ)
			var lines = f.get_as_text().split("\n", false)
			var name = ""
			var desc = ""
			for line in lines:
				if line.begins_with("VIEW: "):
					name = line.trim_prefix("VIEW: ")
				elif line.begins_with("DESCRIPTION: "):
					desc = line.trim_prefix("DESCRIPTION: ")
			var item = {}
			item["name"] = name
			item["description"] = desc
			item["location"] = sound_dir.plus_file(subdir)
			result.append(item)
			f.close()
		
	return result


func get_installed(include_stock = false) -> Array:
	
	var packs = []
	
	if Directory.new().dir_exists(Paths.sound_user):
		packs.append_array(parse_sound_dir(Paths.sound_user))
		for pack in packs:
			pack["is_stock"] = false
	
	if include_stock:
		var stock = parse_sound_dir(Paths.sound_stock)
		for pack in stock:
			pack["is_stock"] = true
		packs.append_array(stock)
		
	return packs


func delete_pack(name: String) -> void:
	
	for pack in get_installed():
		if pack["name"] == name:
			emit_signal("soundpack_deletion_started")
			Status.post(tr("msg_deleting_sound") % pack["location"])
			FS.rm_dir(pack["location"])
			yield(FS, "rm_dir_done")
			emit_signal("soundpack_deletion_finished")
			return
			
	Status.post(tr("msg_soundpack_not_found") % name, Enums.MSG_ERROR)


func get_active_soundpack() -> String:
	# Returns the name of the currently active soundpack from game options
	
	var options_file = Paths.config.plus_file("options.json")
	
	# Check if config directory and options file exist
	if Paths.config == "" or not Directory.new().file_exists(options_file):
		return ""
	
	var f = File.new()
	if f.open(options_file, File.READ) != OK:
		return ""
	
	var json = JSON.parse(f.get_as_text())
	f.close()
	
	if json.error != OK or not (json.result is Array):
		return ""
	
	# Find the SOUNDPACKS option (note: plural, not SOUNDPACK_NAME)
	for option in json.result:
		if option is Dictionary and "name" in option and option["name"] == "SOUNDPACKS":
			if "value" in option:
				return option["value"]
	
	return ""


func set_active_soundpack(soundpack_name: String) -> bool:
	# Sets the active soundpack in game options
	
	var options_file = Paths.config.plus_file("options.json")
	
	# Check if config directory exists
	if Paths.config == "":
		Status.post(tr("msg_no_config_dir"), Enums.MSG_ERROR)
		return false
	
	# Ensure config directory exists
	var d = Directory.new()
	if not d.dir_exists(Paths.config):
		var err = d.make_dir_recursive(Paths.config)
		if err != OK:
			Status.post(tr("msg_could_not_create_config_dir"), Enums.MSG_ERROR)
			return false
	
	var game_options = []
	
	# Load existing options if file exists
	if d.file_exists(options_file):
		var f = File.new()
		if f.open(options_file, File.READ) == OK:
			var json = JSON.parse(f.get_as_text())
			f.close()
			
			if json.error == OK and json.result is Array:
				game_options = json.result
	
	# Convert "Basic" to "basic" (lowercase) for the stock soundpack
	var value_to_write = soundpack_name
	if soundpack_name == "Basic":
		value_to_write = "basic"
	
	# Find and update the SOUNDPACKS option (note: plural, not SOUNDPACK_NAME)
	var found = false
	for option in game_options:
		if option is Dictionary and "name" in option and option["name"] == "SOUNDPACKS":
			option["value"] = value_to_write
			found = true
			break
	
	# If option doesn't exist, add it
	if not found:
		game_options.append({
			"name": "SOUNDPACKS",
			"value": value_to_write,
			"type": "string"
		})
	
	# Write updated options back to file
	var f = File.new()
	if f.open(options_file, File.WRITE) != OK:
		Status.post(tr("msg_could_not_write_options"), Enums.MSG_ERROR)
		return false
	
	f.store_string(JSON.print(game_options, "    "))
	f.close()
	
	Status.post(tr("msg_soundpack_activated") % soundpack_name)
	return true


func install_pack(soundpack_index: int, from_file = null, reinstall = false, keep_archive = false) -> void:
	
	var pack = SOUNDPACKS[soundpack_index]
	var game = Settings.read("game")
	var sound_dir = Paths.sound_user
	var tmp_dir = Paths.tmp_dir.plus_file(pack["name"])
	var archive = ""
	
	emit_signal("soundpack_installation_started")
	
	if reinstall:
		Status.post(tr("msg_reinstalling_sound") % pack["name"])
	else:
		Status.post(tr("msg_installing_sound") % pack["name"])
	
	if from_file:
		archive = from_file
	else:
		archive = Paths.cache_dir.plus_file(pack["filename"])
		if Settings.read("ignore_cache") or not Directory.new().file_exists(archive):
			Downloader.download_file(pack["url"], Paths.cache_dir, pack["filename"])
			yield(Downloader, "download_finished")
		if not Directory.new().file_exists(archive):
			Status.post(tr("msg_sound_download_failed"), Enums.MSG_ERROR)
			emit_signal("soundpack_installation_finished")
			return
		
	if reinstall:
		FS.rm_dir(sound_dir.plus_file(pack["name"]))
		yield(FS, "rm_dir_done")
		
	FS.extract(archive, tmp_dir)
	yield(FS, "extract_done")
	if not keep_archive and not Settings.read("keep_cache"):
		Directory.new().remove(archive)
	FS.move_dir(tmp_dir.plus_file(pack["internal_path"]), sound_dir.plus_file(pack["name"]))
	yield(FS, "move_dir_done")
	
	# On macOS, ensure proper permissions for the installed soundpack
	if OS.get_name() == "OSX":
		var installed_pack_path = sound_dir.plus_file(pack["name"])
		var chmod_result = OS.execute("chmod", ["-R", "755", installed_pack_path], true)
		if chmod_result != 0:
			Status.post("Warning: Could not set soundpack directory permissions", Enums.MSG_WARNING)
	
	FS.rm_dir(tmp_dir)
	yield(FS, "rm_dir_done")
	
	Status.post(tr("msg_sound_installed"))
	emit_signal("soundpack_installation_finished")


func play_sample(sample_path: String, audio_player: AudioStreamPlayer) -> void:
	# Plays a sample audio file for a soundpack - plays once without looping
	
	var audio_file = load(sample_path)
	
	if audio_file == null:
		Status.post(tr("No available preview for this soundpack"), Enums.MSG_ERROR)
		return
	
	# Stop any currently playing audio
	if audio_player.playing:
		audio_player.stop()
	
	# Disable looping on the audio stream
	if audio_file is AudioStream:
		# For OGG Vorbis streams, disable looping
		audio_file.loop = false
	
	# Set the audio stream and play it
	audio_player.stream = audio_file
	audio_player.bus = "Master"
	audio_player.play()
	Status.post("Playing sample...")

