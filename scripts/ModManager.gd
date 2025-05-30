extends Node


signal mod_installation_started
signal mod_installation_finished
signal mod_deletion_started
signal mod_deletion_finished

signal _done_installing_mod
signal _done_deleting_mod





var installed: Dictionary = {} setget , _get_installed
var available: Dictionary = {} setget , _get_available


func _get_installed() -> Dictionary:
	
	if len(installed) == 0:
		refresh_installed()
		
	return installed


func _get_available() -> Dictionary:
	
	if len(available) == 0:
		refresh_available()
	
	return available


func parse_mods_dir(mods_dir: String) -> Dictionary:
	
	if not Directory.new().dir_exists(mods_dir):
		return {}
		
	var result = {}
	
	for subdir in FS.list_dir(mods_dir):
		var f = File.new()
		var modinfo = mods_dir.plus_file(subdir).plus_file("/modinfo.json")
		
		if f.file_exists(modinfo):
			
			f.open(modinfo, File.READ)
			var json = JSON.parse(f.get_as_text())
			if json.error != OK:
				Status.post(tr("msg_mod_json_parsing_failed") % modinfo, Enums.MSG_ERROR)
				continue
			
			var json_result = json.result
			if typeof(json_result) == TYPE_DICTIONARY:
				json_result = [json_result]
			
			for item in json_result:
				if ("type" in item) and (item["type"] == "MOD_INFO"):
					
					var info = item
					info["name"] = _strip_html_tags(info["name"])
					if "description" in info:
						info["description"] = _strip_html_tags(info["description"])
					if not "id" in info:  # Since not all mods have IDs, apparently!
						if "ident" in info:
							info["id"] = info["ident"]
						else:
							info["id"] = info["name"]
					
					result[info["id"]] = {
						"location": mods_dir + "/" + subdir,
						"modinfo": info
					}
					break
					
			f.close()
	
	return result


func _strip_html_tags(text: String) -> String:
	
	var s = text
	var regex = RegEx.new()
	regex.compile("<[^<>]+>")
	
	var matches = regex.search_all(s)
	for match_ in matches:
		var m: RegExMatch = match_
		s = s.replace(m.get_string(), "")
		
	return s


func mod_status(id: String) -> int:
	
	# Returns mod installed status:
	# 0 - not installed;
	# 1 - installed;
	# 2 - stock mod;
	# 3 - stock mod but obsolete;
	# 4 - installed with modified ID.
	
	if id + "__" in installed:
		return 4
	elif id in installed:
		if installed[id]["is_stock"]:
			if installed[id]["is_obsolete"]:
				return 3
			else:
				return 2
		else:
			return 1
	else:
		return 0


func refresh_installed():
	
	installed = {}
	
	var non_stock := {}
	if Directory.new().dir_exists(Paths.mods_user):
		non_stock = parse_mods_dir(Paths.mods_user)
		for id in non_stock:
			non_stock[id]["is_stock"] = false
			
	var stock := parse_mods_dir(Paths.mods_stock)
	for id in stock:
		stock[id]["is_stock"] = true
		if ("obsolete" in stock[id]["modinfo"]) and (stock[id]["modinfo"]["obsolete"] == true):
			stock[id]["is_obsolete"] = true
		else:
			stock[id]["is_obsolete"] = false
			
	for id in non_stock:
		installed[id] = non_stock[id]
		installed[id]["is_stock"] = false
		installed[id]["is_obsolete"] = false
		
	for id in stock:
		installed[id] = stock[id]


func refresh_available():
	
	# Custom mods for TLG (Cataclysm: The Last Generation)
	if Settings.read("game") == "tlg":
		available = {
			"MindOverMatter": {
				"location": "https://github.com/Vegetabs/MindOverMatter-CTLG",
				"modinfo": {
					"id": "MindOverMatter",
					"name": "Mind Over Matter",
					"authors": ["Vegetabs"],
					"description": "Port of MoM from CDDA to CTLG. Adds nine separate psionic power paths to Cataclysm including Biokinesis, Clairsentience, Electrokinesis, Photokinesis, Pyrokinesis, Telekinesis, Telepathy, Teleportation, and Vitakinesis.",
					"category": "content",
					"dependencies": []
				}
			},
			"BionicsExpanded": {
				"location": "https://github.com/Vegetabs/BionicsExpanded-CTLG",
				"modinfo": {
					"id": "BionicsExpanded",
					"name": "Bionics Expanded",
					"authors": ["Vegetabs"],
					"description": "Expanded bionics system for Cataclysm: The Last Generation.",
					"category": "content",
					"dependencies": []
				}
			},
			"MythicalMartialArts": {
				"location": "https://github.com/Vegetabs/MythicalMartialArts-CTLG",
				"modinfo": {
					"id": "MythicalMartialArts",
					"name": "Mythical Martial Arts",
					"authors": ["Vegetabs"],
					"description": "Mythical martial arts mod ported to Cataclysm: The Last Generation.",
					"category": "content",
					"dependencies": []
				}
			}
		}
	else:
		available = parse_mods_dir(Paths.mod_repo)


func _delete_mod(mod_id: String) -> void:
	
	yield(get_tree().create_timer(0.05), "timeout")
	# Have to introduce an artificial delay, otherwise the engine becomes very
	# crash-happy when processing large numbers of mods.
	
	if mod_id in installed:
		var mod = installed[mod_id]
		FS.rm_dir(mod["location"])
		yield(FS, "rm_dir_done")
		Status.post(tr("msg_mod_deleted") % mod["modinfo"]["name"])
	else:
		Status.post(tr("msg_mod_not_found") % mod_id, Enums.MSG_ERROR)
	
	emit_signal("_done_deleting_mod")


func delete_mods(mod_ids: Array) -> void:
	
	if len(mod_ids) == 0:
		return
	
	if len(mod_ids) > 1:
		Status.post(tr("msg_deleting_n_mods") % len(mod_ids))
	
	emit_signal("mod_deletion_started")
	
	for id in mod_ids:
		if mod_status(id) == 4:
			_delete_mod(id + "__")
		else:
			_delete_mod(id)
		yield(self, "_done_deleting_mod")
	
	refresh_installed()
	emit_signal("mod_deletion_finished")


func _get_latest_release_url(github_url: String, mod_name: String) -> void:
	
	# Extract owner and repo from GitHub URL
	var url_parts = github_url.replace("https://github.com/", "").split("/")
	var owner = url_parts[0]
	var repo = url_parts[1]
	
	# GitHub API endpoint for latest release
	var api_url = "https://api.github.com/repos/%s/%s/releases/latest" % [owner, repo]
	
	# Create HTTP request for GitHub API
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Set up proxy if needed
	if Settings.read("proxy_option") == "on":
		var host = Settings.read("proxy_host")
		var port = Settings.read("proxy_port") as int
		http_request.set_http_proxy(host, port)
		http_request.set_https_proxy(host, port)
	
	# Connect signal and make request
	http_request.connect("request_completed", self, "_on_release_info_received", [http_request, mod_name])
	
	# Get authentication headers from the parent Catapult instance if available
	var headers = PoolStringArray()
	var catapult = get_parent()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		headers = catapult._get_github_auth_headers()
	
	# Make the request with authentication if available
	var error = http_request.request(api_url, headers)
	
	if error != OK:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		remove_child(http_request)
		http_request.queue_free()
		emit_signal("_done_installing_mod")


func _on_release_info_received(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, http_request: HTTPRequest, mod_name: String) -> void:
	
	# Clean up HTTP request
	remove_child(http_request)
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	# Parse JSON response
	var json = JSON.parse(body.get_string_from_utf8())
	if json.error != OK:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	var release_data = json.result
	var download_url = ""
	
	# Look for ZIP asset in the release
	if "assets" in release_data and release_data["assets"] is Array:
		for asset in release_data["assets"]:
			if asset["name"].ends_with(".zip"):
				download_url = asset["browser_download_url"]
				break
	
	# If no ZIP asset found, fall back to tarball
	if download_url == "":
		if "zipball_url" in release_data:
			download_url = release_data["zipball_url"]
		else:
			Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
			emit_signal("_done_installing_mod")
			return
	
	# Continue with download using the release URL
	_download_and_install_mod(download_url, mod_name)


func _download_and_install_mod(download_url: String, mod_name: String) -> void:
	
	var mod_id = ""
	var mod = {}
	
	# Find the mod info from available mods
	for id in available:
		if available[id]["modinfo"]["name"] == mod_name:
			mod_id = id
			mod = available[id]
			break
	
	if mod_id == "":
		Status.post(tr("msg_mod_not_found") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	var mods_dir = Paths.mods_user
	var filename = mod_id + ".zip"
	var archive = Paths.cache_dir.plus_file(filename)
	var tmp_dir = Paths.tmp_dir.plus_file(mod_id)
	
	# Download the mod
	if Settings.read("ignore_cache") or not Directory.new().file_exists(archive):
		Downloader.download_file(download_url, Paths.cache_dir, filename)
		yield(Downloader, "download_finished")
	
	if not Directory.new().file_exists(archive):
		Status.post(tr("msg_mod_download_failed") % mod["modinfo"]["name"], Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	# Extract the mod
	FS.extract(archive, tmp_dir)
	yield(FS, "extract_done")
	if not Settings.read("keep_cache"):
		Directory.new().remove(archive)
	
	if FS.last_extract_result == 0:
		# Find the extracted directory (GitHub releases can have various structures)
		var contents = FS.list_dir(tmp_dir)
		if contents.size() > 0:
			var extracted_dir = tmp_dir + "/" + contents[0]
			FS.move_dir(extracted_dir, mods_dir.plus_file(mod_id))
			yield(FS, "move_dir_done")
			Status.post(tr("msg_mod_installed") % mod["modinfo"]["name"])
		else:
			Status.post(tr("msg_mod_extraction_failed") % mod["modinfo"]["name"], Enums.MSG_ERROR)
			emit_signal("_done_installing_mod")
			return
	else:
		Status.post(tr("msg_mod_extraction_error") % [mod["modinfo"]["name"], FS.last_extract_result], Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
		
	# Clean up temporary directory
	FS.rm_dir(tmp_dir)
	yield(FS, "rm_dir_done")
	
	emit_signal("_done_installing_mod")


func _install_mod(mod_id: String) -> void:
	
	yield(get_tree().create_timer(0.05), "timeout")
	# For stability; see above.

	var mods_dir = Paths.mods_user
	
	if mod_id in available:
		var mod = available[mod_id]
		
		# Check if this is a GitHub URL
		if mod["location"].begins_with("https://github.com/"):
			# Handle GitHub mod installation - get latest release
			_get_latest_release_url(mod["location"], mod["modinfo"]["name"])
			return
		else:
			# Handle local mod installation (existing code)
			FS.copy_dir(mod["location"], mods_dir)
			yield(FS, "copy_dir_done")
			
			if (mod_id in installed) and (installed[mod_id]["is_obsolete"] == true):
				Status.post(tr("msg_obsolete_mod_collision") % [mod_id, mod["modinfo"]["name"]])
				var modinfo = mod["modinfo"].duplicate()
				modinfo["id"] += "__"
				modinfo["name"] += "*"
				var f = File.new()
				f.open(mods_dir.plus_file(mod["location"].get_file()).plus_file("modinfo.json"), File.WRITE)
				f.store_string(JSON.print(modinfo, "    "))
						
			Status.post(tr("msg_mod_installed") % mod["modinfo"]["name"])
	else:
		Status.post(tr("msg_mod_not_found") % mod_id, Enums.MSG_ERROR)
	
	emit_signal("_done_installing_mod")


func install_mods(mod_ids: Array) -> void:
	
	if len(mod_ids) == 0:
		return
	
	if len(mod_ids) > 1:
		Status.post(tr("msg_installing_n_mods") % len(mod_ids))
	
	emit_signal("mod_installation_started")
	
	for id in mod_ids:
		_install_mod(id)
		yield(self, "_done_installing_mod")
	
	refresh_installed()
	emit_signal("mod_installation_finished")



