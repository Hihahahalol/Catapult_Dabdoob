extends Node


signal mod_installation_started
signal mod_installation_finished
signal mod_deletion_started
signal mod_deletion_finished

signal _done_installing_mod
signal _done_deleting_mod

# Stability rating mappings (in days)
const STABILITY_RATINGS = {
	-1: 7,      # 1 week
	0: 30,      # 1 month
	1: 90,      # 3 months
	2: 180,     # 6 months
	3: 270,     # 9 months
	4: 365,     # 1 year
	5: 730,     # 2 years
	100: -1     # supported forever (negative means no expiry)
}

var installed: Dictionary = {} setget , _get_installed
var available: Dictionary = {} setget , _get_available

# Cache for mod release dates to avoid repeated API calls
var _mod_release_date_cache: Dictionary = {}
var _pending_api_calls: Array = []

signal mod_compatibility_checked(compatible_count, incompatible_count)


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
					"id": "mindovermatter",
					"name": "Mind Over Matter",
					"authors": ["Vegetabs"],
					"description": "Port of MoM from CDDA to CTLG. Adds nine separate psionic power paths to Cataclysm including Biokinesis, Clairsentience, Electrokinesis, Photokinesis, Pyrokinesis, Telekinesis, Telepathy, Teleportation, and Vitakinesis.",
					"category": "content",
					"dependencies": [],
					"stability": 1
				}
			},
			"BionicsExpanded": {
				"location": "https://github.com/Vegetabs/BionicsExpanded-CTLG",
				"modinfo": {
					"id": "bionics_expanded",
					"name": "Bionics Expanded",
					"authors": ["Vegetabs"],
					"description": "Expanded bionics system for Cataclysm: The Last Generation.",
					"category": "content",
					"dependencies": [],
					"stability": 4
				}
			},
			"MythicalMartialArts": {
				"location": "https://github.com/Vegetabs/MythicalMartialArts-CTLG",
				"modinfo": {
					"id": "MMA",
					"name": "Mythical Martial Arts",
					"authors": ["Vegetabs"],
					"description": "Mythical martial arts mod ported to Cataclysm: The Last Generation.",
					"category": "content",
					"dependencies": [],
					"stability": 2
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


# Check if a mod is compatible based on its stability rating and the latest release date
func is_mod_compatible(mod_id: String) -> bool:
	
	# Only check compatibility for experimental channel
	if Settings.read("channel") != "experimental":
		return true
	
	# Check if mod exists and has stability rating
	if not mod_id in available:
		return false
	
	var mod_info = available[mod_id]["modinfo"]
	if not "stability" in mod_info:
		return false
	
	var stability_rating = mod_info["stability"]
	if not stability_rating in STABILITY_RATINGS:
		return false
	
	var max_days = STABILITY_RATINGS[stability_rating]
	
	# If stability rating is 100 (forever), always compatible
	if max_days == -1:
		return true
	
	# Get the latest release date for this specific mod
	var mod_release_date = _get_mod_latest_release_date(mod_id)
	if mod_release_date == "":
		# If we can't get the mod's release date, assume incompatible
		return false
	
	# Calculate days difference since the mod's last release
	var days_since_mod_release = _calculate_days_since_release(mod_release_date)
	
	# Check if mod is still within its stability window
	return days_since_mod_release <= max_days


# Get the latest release date for a specific mod's GitHub repository
func _get_mod_latest_release_date(mod_id: String) -> String:
	
	if not mod_id in available:
		return ""
	
	# Check cache first
	if mod_id in _mod_release_date_cache:
		return _mod_release_date_cache[mod_id]
	
	var mod = available[mod_id]
	var location = mod["location"]
	
	# Check if this is a GitHub URL
	if not location.begins_with("https://github.com/"):
		# For non-GitHub mods, we can't determine release date
		return ""
	
	# Return empty string for now - real data will be fetched asynchronously
	return ""


# Fetch release dates for all mods asynchronously
func fetch_all_mod_release_dates() -> void:
	
	_pending_api_calls.clear()
	
	for mod_id in available:
		var mod = available[mod_id]
		var location = mod["location"]
		
		# Only fetch for GitHub mods that aren't already cached
		if location.begins_with("https://github.com/") and not mod_id in _mod_release_date_cache:
			_pending_api_calls.append(mod_id)
			_fetch_mod_release_date_async(mod_id)
	
	# If no API calls are needed (everything is cached), immediately check compatibility
	if len(_pending_api_calls) == 0:
		_check_all_mod_compatibility()


# Fetch the latest release date for a specific mod from GitHub API (async)
func _fetch_mod_release_date_async(mod_id: String) -> void:
	
	if not mod_id in available:
		_on_mod_release_date_received_internal(mod_id, "")
		return
	
	var mod = available[mod_id]
	var location = mod["location"]
	
	# Check if this is a GitHub URL
	if not location.begins_with("https://github.com/"):
		_on_mod_release_date_received_internal(mod_id, "")
		return
	
	# Extract owner and repo from GitHub URL
	var url_parts = location.replace("https://github.com/", "").split("/")
	if len(url_parts) < 2:
		_on_mod_release_date_received_internal(mod_id, "")
		return
	
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
	http_request.connect("request_completed", self, "_on_mod_release_date_received", [http_request, mod_id])
	
	# Get authentication headers from the parent Catapult instance if available
	var headers = PoolStringArray()
	var catapult = get_parent()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		headers = catapult._get_github_auth_headers()
	
	# Make the request with authentication if available
	var error = http_request.request(api_url, headers)
	
	if error != OK:
		remove_child(http_request)
		http_request.queue_free()
		_on_mod_release_date_received_internal(mod_id, "")


# Handle response from GitHub API for mod release date
func _on_mod_release_date_received(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, http_request: HTTPRequest, mod_id: String) -> void:
	
	# Clean up HTTP request
	remove_child(http_request)
	http_request.queue_free()
	
	var release_date = ""
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Parse JSON response
		var json = JSON.parse(body.get_string_from_utf8())
		if json.error == OK:
			var release_data = json.result
			if "published_at" in release_data:
				# Parse the ISO 8601 date format from GitHub API (e.g., "2024-01-15T10:30:00Z")
				var date_str = release_data["published_at"]
				# Extract just the date part (YYYY-MM-DD)
				release_date = date_str.split("T")[0]
				Status.post("Retrieved release date for %s: %s" % [mod_id, release_date], Enums.MSG_DEBUG)
			else:
				Status.post("No published_at found for mod %s" % mod_id, Enums.MSG_DEBUG)
	else:
		Status.post("Failed to fetch release date for mod %s (HTTP %d)" % [mod_id, response_code], Enums.MSG_DEBUG)
	
	_on_mod_release_date_received_internal(mod_id, release_date)


# Internal handler for release date reception (both successful and failed)
func _on_mod_release_date_received_internal(mod_id: String, release_date: String) -> void:
	
	# Cache the result (even if empty)
	_mod_release_date_cache[mod_id] = release_date
	
	# Remove from pending calls
	if mod_id in _pending_api_calls:
		_pending_api_calls.erase(mod_id)
	
	# If all API calls are complete, emit signal for UI update
	if len(_pending_api_calls) == 0:
		_check_all_mod_compatibility()


# Check compatibility for all mods and emit signal with results
func _check_all_mod_compatibility() -> void:
	
	var compatible_count = 0
	var incompatible_count = 0
	
	for mod_id in available:
		if is_mod_compatible(mod_id):
			compatible_count += 1
		else:
			incompatible_count += 1
	
	emit_signal("mod_compatibility_checked", compatible_count, incompatible_count)


# Calculate days between release date and current date
func _calculate_days_since_release(release_date: String) -> int:
	
	# Parse release date (format: YYYY-MM-DD)
	var parts = release_date.split("-")
	if len(parts) != 3:
		return 0
	
	var release_year = int(parts[0])
	var release_month = int(parts[1])
	var release_day = int(parts[2])
	
	# Get current date
	var current_date = OS.get_datetime()
	
	# Simple day calculation (approximate)
	var release_days = release_year * 365 + release_month * 30 + release_day
	var current_days = current_date.year * 365 + current_date.month * 30 + current_date.day
	
	return current_days - release_days



