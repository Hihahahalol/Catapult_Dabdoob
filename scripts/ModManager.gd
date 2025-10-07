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
		var modinfo = mods_dir.plus_file(subdir).plus_file("modinfo.json")
		
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
						"location": mods_dir.plus_file(subdir),
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
					"authors": ["StandingStorm"],
					"maintainers": ["Vegetabs"],
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
					"maintainers": [],
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
					"authors": ["Photoloss"],
					"maintainers": ["Vegetabs"],
					"description": "Mythical martial arts mod ported to Cataclysm: The Last Generation.",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			}
		}
	# Custom mods for Bright Nights (BN)
	elif Settings.read("game") == "bn":
		available = {
			"CataclysmSecondChance": {
				"location": "https://github.com/Tefnut/Cataclysm-Second-Chance",
				"modinfo": {
					"id": "cataclysm_second_chance",
					"name": "Cataclysm: Second Chance",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "A mod for Cataclysm: Bright Nights which adds my own custom content to it",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			},
			"BetterHolsters": {
				"location": "https://github.com/Tefnut/Better-Holsters",
				"modinfo": {
					"id": "better_holsters",
					"name": "Better Holsters",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "A mod for Cataclysm: Bright Nights that improves the holster experience",
					"category": "items",
					"dependencies": [],
					"stability": 3
				}
			},
			"FalloutNewEnglandRemastered": {
				"location": "https://github.com/Tefnut/Fallout-New-England-Remastered",
				"modinfo": {
					"id": "fallout_new_england_remastered",
					"name": "Fallout: New England Remastered",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "A remastering of my original Fallout mod for C:DDA. Should work with newest Bright Nights release for as long as I update and maintain it.",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			},
			"ReallyDarkSkies": {
				"location": "https://github.com/Zlorthishen/Really_Dark_Skies",
				"modinfo": {
					"id": "realdarkskies",
					"name": "Really Dark Skies",
					"authors": ["Zlorthishen"],
					"maintainers": ["Zlorthishen"],
					"description": "Really Dark Skies. The community supported mod that enhances the Bright Nights experience by adding an inscrutable alien-humanoid paramilitary expeditionary force to your typical survival scenario.",
					"category": "content",
					"dependencies": [],
					"stability": 3
				}
			},
			"TheArcologyMod": {
				"location": "https://github.com/Zlorthishen/The_Arcology_Mod",
				"modinfo": {
					"id": "arcology",
					"name": "The Arcology Mod",
					"authors": ["Zlorthishen"],
					"maintainers": ["Zlorthishen"],
					"description": "The mod that adds Arcology-type buildings, very large, self-contained buildings with a Cyberpunk aesthetic to Bright Nights.",
					"category": "buildings",
					"dependencies": [],
					"stability": 3
				}
			},
			"ZombieHighMod": {
				"location": "https://github.com/Zlorthishen/ZombieHighMod",
				"modinfo": {
					"id": "Zhigh_Mod",
					"name": "Zombie High Mod",
					"authors": ["thhoney08"],
					"maintainers": ["Zlorthishen"],
					"description": "A mod for cataclysm: Bright Nights, which sets on a bunker-like school.",
					"category": "buildings",
					"dependencies": [],
					"stability": 2
				}
			},
			"GrowMoreDrugs": {
				"location": "https://github.com/Zlorthishen/grow_more_drugs",
				"modinfo": {
					"id": "grow_more_drugs",
					"name": "Grow More Drugs",
					"authors": ["jackledead"],
					"maintainers": ["Zlorthishen"],
					"description": "Cataclysm - Bright Nights mod, adding different drug crops that would not grow in New England. Plants/seeds: Coca, coffee, tea, poppy, tobacco. Includes recipes for cocaine.",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			},
			"LonesTechAndWeapons": {
				"location": "https://github.com/Zlorthishen/Lones-Tech-and-Weapons-mod",
				"modinfo": {
					"id": "lonestweaks",
					"name": "Lones Tweaks",
					"authors": ["thelonestander"],
					"maintainers": ["Zlorthishen"],
					"description": "Weapons and tech for the game Bright Nights",
					"category": "items",
					"dependencies": [],
					"stability": 2
				}
			},
			"NoHopeAndDinos": {
				"location": "https://github.com/Zlorthishen/No-Hope-and-Dinos",
				"modinfo": {
					"id": "no_hope_and_dinos",
					"name": "No Hope and Dinos",
					"authors": ["jackledead"],
					"maintainers": ["Zlorthishen"],
					"description": "CDDA Mod. It's like No Hope, but replaces zombies with dinosaurs, and requires TropiCataclysm and Dinomod. Removes portals and portal storms. Only spawn Dinosaurs, Robots, Cyborgs, Mutants, Insects.",
					"category": "content",
					"dependencies": [],
					"stability": 1
				}
			},
			"AddBanditsExpanded": {
				"location": "https://github.com/Zlorthishen/Compatible-Add-Bandits-Expanded",
				"modinfo": {
					"id": "GOV_BANDITS_KAI_R",
					"name": "Add Bandits Expanded+",
					"authors": ["Jolmar7"],
					"maintainers": ["Zlorthishen"],
					"description": "Adds a large amount of content to the Add Bandits mod, and a few NPCs as well",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			},
			"ArcanaAndMagicItems": {
				"location": "https://github.com/Zlorthishen/cdda-arcana-mod",
				"modinfo": {
					"id": "Arcana",
					"name": "Arcana and Magic Items",
					"authors": ["chaosvolt"],
					"maintainers": ["Zlorthishen"],
					"description": "Arcana and Magic Items mod for Cataclysm: Bright Nights",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			},
			"SteampunkMod": {
				"location": "https://github.com/Zlorthishen/CDDA-BN-Steampunk-Mod",
				"modinfo": {
					"id": "steampunk_arcanum",
					"name": "Steampunk Mod",
					"authors": ["Jolmar7"],
					"maintainers": ["Zlorthishen"],
					"description": "A mod that adds several steampunk inspired items, recipes, locations and a small NPC town. Inspired by the Arcanum: Of Steamworks of Magick Obscure RPG.",
					"category": "content",
					"dependencies": [],
					"stability": 1
				}
			},
			"HackThePlanet": {
				"location": "https://github.com/Zlorthishen/hacktheplanet",
				"modinfo": {
					"id": "hacktheplanet",
					"name": "Hack The Planet",
					"authors": ["kettleswordfang"],
					"maintainers": ["Zlorthishen"],
					"description": "CDDA Hacker Gear",
					"category": "items",
					"dependencies": [],
					"stability": 1
				}
			}
		}
			# Custom mods for DDA (Dark Days Ahead)
	elif Settings.read("game") == "dda":
		available = {
			"ArcanaAndMagicItems": {
				"location": "https://github.com/Zlorthishen/cdda-arcana-mod",
				"modinfo": {
					"id": "Arcana",
					"name": "Arcana and Magic Items",
					"authors": ["chaosvolt"],
					"maintainers": ["Zlorthishen"],
					"description": "Arcana and Magic Items mod for Cataclysm: Dark Days Ahead",
					"category": "content",
					"dependencies": [],
					"stability": 2
				}
			},
			"TefnutsExpansion": {
				"location": "https://github.com/Tefnut/Tefnuts-Expansion",
				"modinfo": {
					"id": "tefnuts_expansion",
					"name": "Cataclysm: Second Chance",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "An expansion for Cataclysm:DDA that intends to add a little of everything",
					"category": "content",
					"dependencies": [],
					"stability": 1
				}
			},
			"FalloutInCDDA": {
				"location": "https://github.com/Tefnut/Fallout-in-CDDA",
				"modinfo": {
					"id": "fallout_in_cdda",
					"name": "Fallout New England",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "A WIP mod that adds fallout to CDDA",
					"category": "content",
					"dependencies": [],
					"stability": 0
				}
			},
			"CDDATameAnts": {
				"location": "https://github.com/Tefnut/CDDA-tame-ants",
				"modinfo": {
					"id": "tame_ants",
					"name": "Tame Bugs",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "A mod for Cataclysm: Dark Days Ahead. Contains the ability to tame various insects.",
					"category": "creatures",
					"dependencies": [],
					"stability": 4
				}
			},
			"FalloutNewEnglandRemastered": {
				"location": "https://github.com/Tefnut/Fallout-New-England-Remastered",
				"modinfo": {
					"id": "fallout_new_england_remastered",
					"name": "Fallout: New England Remastered",
					"authors": ["Tefnut"],
					"maintainers": ["Tefnut"],
					"description": "A remastering of my original Fallout mod for C:DDA. Should work with newest Bright Nights release for as long as I update and maintain it.",
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
	
	# If no releases found (404), fall back to repository download
	if response_code == 404:
		Status.post("No releases found for %s, downloading repository directly..." % mod_name, Enums.MSG_INFO)
		_download_repository_directly(mod_name)
		return
	
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
			Status.post("No download assets found in release for %s, downloading repository directly..." % mod_name, Enums.MSG_INFO)
			_download_repository_directly(mod_name)
			return
	
	# Continue with download using the release URL
	_download_and_install_mod(download_url, mod_name)


# Download repository directly when no releases are available
func _download_repository_directly(mod_name: String) -> void:
	
	var mod_id = ""
	var github_url = ""
	
	# Find the mod info from available mods
	for id in available:
		if available[id]["modinfo"]["name"] == mod_name:
			mod_id = id
			github_url = available[id]["location"]
			break
	
	if github_url == "":
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	# Extract owner and repo from GitHub URL
	var url_parts = github_url.replace("https://github.com/", "").split("/")
	if len(url_parts) < 2:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	var owner = url_parts[0]
	var repo = url_parts[1]
	
	# Use GitHub's archive download URL (downloads main branch as ZIP)
	var download_url = "https://github.com/%s/%s/archive/refs/heads/main.zip" % [owner, repo]
	
	Status.post("Downloading repository %s/%s directly from main branch..." % [owner, repo], Enums.MSG_INFO)
	
	# Try main branch first, if it fails we'll try master branch
	_download_and_install_mod_with_fallback(download_url, mod_name, owner, repo, "main")


# Download with fallback to different branch names
func _download_and_install_mod_with_fallback(download_url: String, mod_name: String, owner: String, repo: String, branch: String) -> void:
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Set up proxy if needed
	if Settings.read("proxy_option") == "on":
		var host = Settings.read("proxy_host")
		var port = Settings.read("proxy_port") as int
		http_request.set_http_proxy(host, port)
		http_request.set_https_proxy(host, port)
	
	# Connect signal with additional parameters for fallback
	http_request.connect("request_completed", self, "_on_repository_download_completed", [http_request, mod_name, owner, repo, branch])
	
	# Get authentication headers from the parent Catapult instance if available
	var headers = PoolStringArray()
	var catapult = get_parent()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		headers = catapult._get_github_auth_headers()
	
	# Make the request
	var error = http_request.request(download_url, headers)
	
	if error != OK:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		remove_child(http_request)
		http_request.queue_free()
		emit_signal("_done_installing_mod")


# Handle repository download response with branch fallback
func _on_repository_download_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, http_request: HTTPRequest, mod_name: String, owner: String, repo: String, branch: String) -> void:
	
	# Clean up HTTP request
	remove_child(http_request)
	http_request.queue_free()
	
	# If download failed and we were trying main branch, try master branch
	if (result != HTTPRequest.RESULT_SUCCESS or response_code != 200) and branch == "main":
		Status.post("Main branch not found for %s, trying master branch..." % mod_name, Enums.MSG_INFO)
		var master_url = "https://github.com/%s/%s/archive/refs/heads/master.zip" % [owner, repo]
		_download_and_install_mod_with_fallback(master_url, mod_name, owner, repo, "master")
		return
	
	# If still failed, or we already tried master, give up
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	# Success! Continue with normal mod installation process
	Status.post("Successfully downloaded repository for %s" % mod_name, Enums.MSG_INFO)
	_process_downloaded_mod(body, mod_name)


# Process downloaded mod data (common for both releases and repository downloads)
func _process_downloaded_mod(body: PoolByteArray, mod_name: String) -> void:
	
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
	
	# Ensure the mods directory exists with proper permissions on macOS
	var d = Directory.new()
	if not d.dir_exists(mods_dir):
		var err = d.make_dir_recursive(mods_dir)
		if err:
			Status.post("Failed to create mods directory: %s (error: %d)" % [mods_dir, err], Enums.MSG_ERROR)
			emit_signal("_done_installing_mod")
			return
		
		# On macOS, ensure the directory has proper permissions
		if OS.get_name() == "OSX":
			var chmod_result = OS.execute("chmod", ["755", mods_dir], true)
			if chmod_result != 0:
				Status.post("Warning: Could not set mods directory permissions", Enums.MSG_WARNING)
	
	# Save the downloaded data to cache
	var file = File.new()
	if file.open(archive, File.WRITE) != OK:
		Status.post(tr("msg_mod_download_failed") % mod["modinfo"]["name"], Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	file.store_var(body, true)
	file.close()
	
	# On macOS, ensure the downloaded file has proper permissions
	if OS.get_name() == "OSX":
		var chmod_result = OS.execute("chmod", ["644", archive], true)
		if chmod_result != 0:
			Status.post("Warning: Could not set archive file permissions", Enums.MSG_WARNING)
	
	# Extract the mod
	FS.extract(archive, tmp_dir)
	yield(FS, "extract_done")
	if not Settings.read("keep_cache"):
		Directory.new().remove(archive)
	
	if FS.last_extract_result == 0:
		# Find the extracted directory (GitHub releases can have various structures)
		var contents = FS.list_dir(tmp_dir)
		if contents.size() > 0:
			var extracted_dir = tmp_dir.plus_file(contents[0])
			
			# Special handling for Arcana mod - contains multiple mods for different game forks
			if mod_name == "Arcana and Magic Items":
				var arcana_mod_dir = _find_arcana_mod_directory(extracted_dir)
				if arcana_mod_dir != "":
					Status.post("Installing Arcana mod from: %s" % arcana_mod_dir)
					FS.move_dir(arcana_mod_dir, mods_dir.plus_file(mod_id))
					yield(FS, "move_dir_done")
					_fix_mod_permissions_macos(mods_dir.plus_file(mod_id))
					Status.post(tr("msg_mod_installed") % mod["modinfo"]["name"])
				else:
					Status.post(tr("msg_mod_extraction_failed") % mod["modinfo"]["name"], Enums.MSG_ERROR)
			else:
				# Find the actual mod directory with modinfo.json
				var mod_dir = _find_mod_directory(extracted_dir)
				if mod_dir != "":
					FS.move_dir(mod_dir, mods_dir.plus_file(mod_id))
					yield(FS, "move_dir_done")
					_fix_mod_permissions_macos(mods_dir.plus_file(mod_id))
					Status.post(tr("msg_mod_installed") % mod["modinfo"]["name"])
				else:
					# Fallback to installing the entire directory if no modinfo.json found
					FS.move_dir(extracted_dir, mods_dir.plus_file(mod_id))
					yield(FS, "move_dir_done")
					_fix_mod_permissions_macos(mods_dir.plus_file(mod_id))
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


# Fix file permissions for installed mods on macOS
func _fix_mod_permissions_macos(mod_path: String) -> void:
	if OS.get_name() != "OSX":
		return
		
	# Set directory permissions recursively
	var chmod_result = OS.execute("chmod", ["-R", "755", mod_path], true)
	if chmod_result != 0:
		Status.post("Warning: Could not set mod directory permissions for %s" % mod_path, Enums.MSG_WARNING)
	
	# Set file permissions recursively  
	var find_result = OS.execute("find", [mod_path, "-type", "f", "-exec", "chmod", "644", "{}", "+"], true)
	if find_result != 0:
		Status.post("Warning: Could not set mod file permissions for %s" % mod_path, Enums.MSG_WARNING)


func _download_and_install_mod(download_url: String, mod_name: String) -> void:
	
	# Check if we have a cached version first
	var mod_id = ""
	for id in available:
		if available[id]["modinfo"]["name"] == mod_name:
			mod_id = id
			break
	
	if mod_id == "":
		Status.post(tr("msg_mod_not_found") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	var filename = mod_id + ".zip"
	var archive = Paths.cache_dir.plus_file(filename)
	
	# Use cached version if available and caching is enabled
	if not Settings.read("ignore_cache") and Directory.new().file_exists(archive):
		Status.post("Using cached version of %s" % mod_name, Enums.MSG_INFO)
		var file = File.new()
		if file.open(archive, File.READ) == OK:
			var body = file.get_buffer(file.get_len())
			file.close()
			_process_downloaded_mod(body, mod_name)
			return
	
	# Download using HTTP request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Set up proxy if needed
	if Settings.read("proxy_option") == "on":
		var host = Settings.read("proxy_host")
		var port = Settings.read("proxy_port") as int
		http_request.set_http_proxy(host, port)
		http_request.set_https_proxy(host, port)
	
	# Connect signal
	http_request.connect("request_completed", self, "_on_mod_download_completed", [http_request, mod_name])
	
	# Get authentication headers from the parent Catapult instance if available
	var headers = PoolStringArray()
	var catapult = get_parent()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		headers = catapult._get_github_auth_headers()
	
	# Make the request
	Status.post("Downloading %s from %s..." % [mod_name, download_url], Enums.MSG_INFO)
	var error = http_request.request(download_url, headers)
	
	if error != OK:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		remove_child(http_request)
		http_request.queue_free()
		emit_signal("_done_installing_mod")


# Handle mod download completion
func _on_mod_download_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, http_request: HTTPRequest, mod_name: String) -> void:
	
	# Clean up HTTP request
	remove_child(http_request)
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		Status.post(tr("msg_mod_download_failed") % mod_name, Enums.MSG_ERROR)
		emit_signal("_done_installing_mod")
		return
	
	# Success! Process the downloaded mod
	_process_downloaded_mod(body, mod_name)


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
	
	# Apply stability checking to all channels (both stable and experimental)
	# This ensures mods are checked for compatibility regardless of the channel
	
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


# Fetch release dates for all mods asynchronously using batch API
func fetch_all_mod_release_dates() -> void:
	
	_pending_api_calls.clear()
	
	# Check if we have a GitHubBatchAPI node, if not create one
	var batch_api = get_node_or_null("GitHubBatchAPI")
	if batch_api == null:
		batch_api = load("res://scripts/GitHubBatchAPI.gd").new()
		batch_api.name = "GitHubBatchAPI"
		add_child(batch_api)
		batch_api.connect("batch_request_completed", self, "_on_batch_api_completed")
	
	# Clear any previous queue
	batch_api.clear_queue()
	
	# Queue all mods that need fetching
	var mods_to_fetch = 0
	for mod_id in available:
		var mod = available[mod_id]
		var location = mod["location"]
		
		# Only fetch for GitHub mods that aren't already cached
		if location.begins_with("https://github.com/") and not mod_id in _mod_release_date_cache:
			# Extract owner and repo from GitHub URL
			var url_parts = location.replace("https://github.com/", "").split("/")
			if len(url_parts) >= 2:
				var owner = url_parts[0]
				var repo = url_parts[1]
				batch_api.queue_mod(mod_id, owner, repo)
				_pending_api_calls.append(mod_id)
				mods_to_fetch += 1
	
	# If no API calls are needed (everything is cached), immediately check compatibility
	if mods_to_fetch == 0:
		_check_all_mod_compatibility()
	else:
		Status.post("Fetching release dates for %d mod(s) using batch API..." % mods_to_fetch, Enums.MSG_DEBUG)
		batch_api.execute_batches()


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
			Status.post("JSON parse error for mod %s" % mod_id, Enums.MSG_DEBUG)
	elif response_code == 404:
		# Repository has no releases, try to get last commit date instead
		Status.post("No releases found for %s, trying last commit date..." % mod_id, Enums.MSG_DEBUG)
		_fetch_mod_last_commit_date(mod_id)
		return
	else:
		Status.post("Failed to fetch release date for mod %s (HTTP %d)" % [mod_id, response_code], Enums.MSG_DEBUG)
	
	_on_mod_release_date_received_internal(mod_id, release_date)


# Fetch the last commit date as fallback when no releases exist
func _fetch_mod_last_commit_date(mod_id: String) -> void:
	
	if not mod_id in available:
		_on_mod_release_date_received_internal(mod_id, "")
		return
	
	var mod = available[mod_id]
	var location = mod["location"]
	
	# Extract owner and repo from GitHub URL
	var url_parts = location.replace("https://github.com/", "").split("/")
	if len(url_parts) < 2:
		_on_mod_release_date_received_internal(mod_id, "")
		return
	
	var owner = url_parts[0]
	var repo = url_parts[1]
	
	# GitHub API endpoint for commits (get latest commit)
	var api_url = "https://api.github.com/repos/%s/%s/commits?per_page=1" % [owner, repo]
	
	Status.post("Fetching last commit date for %s..." % mod_id, Enums.MSG_DEBUG)
	
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
	http_request.connect("request_completed", self, "_on_mod_commit_date_received", [http_request, mod_id])
	
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


# Handle response from GitHub API for mod commit date (fallback)
func _on_mod_commit_date_received(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, http_request: HTTPRequest, mod_id: String) -> void:
	
	# Clean up HTTP request
	remove_child(http_request)
	http_request.queue_free()
	
	var commit_date = ""
	
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# Parse JSON response (array of commits)
		var json = JSON.parse(body.get_string_from_utf8())
		if json.error == OK:
			var commits_data = json.result
			if commits_data is Array and len(commits_data) > 0:
				var latest_commit = commits_data[0]
				if "commit" in latest_commit and "committer" in latest_commit["commit"] and "date" in latest_commit["commit"]["committer"]:
					# Parse the ISO 8601 date format from GitHub API (e.g., "2024-01-15T10:30:00Z")
					var date_str = latest_commit["commit"]["committer"]["date"]
					# Extract just the date part (YYYY-MM-DD)
					commit_date = date_str.split("T")[0]
					Status.post("Retrieved last commit date for %s: %s" % [mod_id, commit_date], Enums.MSG_DEBUG)
				else:
					Status.post("No commit date found for mod %s" % mod_id, Enums.MSG_DEBUG)
			else:
				Status.post("No commits found for mod %s" % mod_id, Enums.MSG_DEBUG)
		else:
			Status.post("JSON parse error for commit data of mod %s" % mod_id, Enums.MSG_DEBUG)
	else:
		Status.post("Failed to fetch commit date for mod %s (HTTP %d)" % [mod_id, response_code], Enums.MSG_DEBUG)
	
	_on_mod_release_date_received_internal(mod_id, commit_date)


# Handle batch API results
func _on_batch_api_completed(results: Dictionary) -> void:
	
	Status.post("Batch API completed with %d results" % len(results), Enums.MSG_DEBUG)
	
	# Process all results
	var processed_count = 0
	for mod_id in results:
		var release_date = results[mod_id]
		_mod_release_date_cache[mod_id] = release_date
		processed_count += 1
		
		# Remove from pending calls
		if mod_id in _pending_api_calls:
			_pending_api_calls.erase(mod_id)
	
	Status.post("Processed %d mod release dates" % processed_count, Enums.MSG_DEBUG)
	
	# Clear any remaining pending calls and proceed (in case some failed)
	if len(_pending_api_calls) > 0:
		Status.post("Warning: %d mods still pending, proceeding anyway" % len(_pending_api_calls), Enums.MSG_DEBUG)
		# Cache empty results for pending mods to unblock the UI
		for mod_id in _pending_api_calls:
			if not mod_id in _mod_release_date_cache:
				_mod_release_date_cache[mod_id] = ""
		_pending_api_calls.clear()
	
	# Always proceed to compatibility check
	_check_all_mod_compatibility()


# Internal handler for release date reception (both successful and failed)
# This is kept for backward compatibility with individual requests if needed
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


func _find_mod_directory(extracted_dir: String) -> String:
	
	Status.post("Searching for mod directory in: %s" % extracted_dir)
	
	# Check if the root directory contains modinfo.json
	var modinfo_path = extracted_dir.plus_file("modinfo.json")
	var file = File.new()
	if file.file_exists(modinfo_path):
		Status.post("Found modinfo.json in root directory")
		return extracted_dir
	
	# Search through subdirectories for modinfo.json
	var mod_candidates = []
	var contents = FS.list_dir(extracted_dir)
	
	Status.post("Found %d subdirectories to check: %s" % [len(contents), str(contents)])
	
	for subdir in contents:
		var subdir_path = extracted_dir.plus_file(subdir)
		
		# Skip non-directories
		if not Directory.new().dir_exists(subdir_path):
			continue
			
		var subdir_modinfo = subdir_path.plus_file("modinfo.json")
		Status.post("Checking for modinfo.json at: %s" % subdir_modinfo)
		
		if file.file_exists(subdir_modinfo):
			Status.post("Found modinfo.json in subdirectory: %s" % subdir)
			
			# Verify it's a valid mod by checking the modinfo content
			file.open(subdir_modinfo, File.READ)
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.parse(json_text)
			if json.error == OK:
				var json_result = json.result
				if typeof(json_result) == TYPE_DICTIONARY:
					json_result = [json_result]
				
				for item in json_result:
					if ("type" in item) and (item["type"] == "MOD_INFO"):
						mod_candidates.append(subdir_path)
						Status.post("Valid mod directory found: %s with mod ID: %s" % [subdir, item.get("id", "unknown")])
						break
			else:
				Status.post("Invalid JSON in modinfo.json at: %s" % subdir_modinfo)
		else:
			# Also check for deeper nested modinfo.json files (up to 2 levels deep)
			var nested_contents = FS.list_dir(subdir_path)
			for nested_subdir in nested_contents:
				var nested_path = subdir_path.plus_file(nested_subdir)
				if Directory.new().dir_exists(nested_path):
					var nested_modinfo = nested_path.plus_file("modinfo.json")
					if file.file_exists(nested_modinfo):
						Status.post("Found nested modinfo.json at: %s" % nested_modinfo)
						
						file.open(nested_modinfo, File.READ)
						var json_text = file.get_as_text()
						file.close()
						
						var json = JSON.parse(json_text)
						if json.error == OK:
							var json_result = json.result
							if typeof(json_result) == TYPE_DICTIONARY:
								json_result = [json_result]
							
							for item in json_result:
								if ("type" in item) and (item["type"] == "MOD_INFO"):
									mod_candidates.append(nested_path)
									Status.post("Valid nested mod directory found: %s/%s with mod ID: %s" % [subdir, nested_subdir, item.get("id", "unknown")])
									break
	
	# Return the first valid mod directory found
	if len(mod_candidates) > 0:
		Status.post("Selected mod directory: %s" % mod_candidates[0])
		return mod_candidates[0]
	
	# No valid mod directory found
	Status.post("No valid mod directory found, will install entire repository")
	return ""


func _find_arcana_mod_directory(extracted_dir: String) -> String:
	
	# Look for appropriate mod directory based on game fork
	var game = Settings.read("game")
	var mod_contents = FS.list_dir(extracted_dir)
	var target_mod_dir = ""
	
	Status.post("Arcana installation - searching for mod directory for game: %s" % game)
	
	# Find the appropriate mod directory
	for subdir in mod_contents:
		var subdir_path = extracted_dir.plus_file(subdir)
		var modinfo_path = subdir_path.plus_file("modinfo.json")
		
		# Check if this subdirectory contains a modinfo.json
		var file = File.new()
		if file.file_exists(modinfo_path):
			file.open(modinfo_path, File.READ)
			var json = JSON.parse(file.get_as_text())
			file.close()
			
			if json.error == OK:
				var json_result = json.result
				if typeof(json_result) == TYPE_DICTIONARY:
					json_result = [json_result]
				
				for item in json_result:
					if ("type" in item) and (item["type"] == "MOD_INFO"):
						var info = item
						
						# Check if this is the right mod for the current game fork
						if "id" in info and info["id"] == "Arcana":
							Status.post("Found Arcana mod directory: %s (for game: %s)" % [subdir, game])
							target_mod_dir = subdir_path
							
							# For DDA, prefer directories with "dda" or "dark" in the name
							if game == "dda" and (subdir.to_lower().find("dda") != -1 or subdir.to_lower().find("dark") != -1):
								Status.post("Using DDA-specific Arcana directory: %s" % subdir)
								break
							# For BN, prefer directories with "bn" or "bright" in the name  
							elif game == "bn" and (subdir.to_lower().find("bn") != -1 or subdir.to_lower().find("bright") != -1):
								Status.post("Using BN-specific Arcana directory: %s" % subdir)
								break
		
		# If we found a game-specific directory, use it immediately
		if target_mod_dir != "" and ((game == "dda" and (subdir.to_lower().find("dda") != -1 or subdir.to_lower().find("dark") != -1)) or 
		                             (game == "bn" and (subdir.to_lower().find("bn") != -1 or subdir.to_lower().find("bright") != -1))):
			break
	
	# If no specific directory found but we have a general Arcana directory, use it
	if target_mod_dir == "":
		# Fallback: look for any directory containing "Arcana" 
		for subdir in mod_contents:
			if subdir.to_lower().find("arcana") != -1:
				var subdir_path = extracted_dir.plus_file(subdir)
				var modinfo_path = subdir_path.plus_file("modinfo.json")
				var file = File.new()
				if file.file_exists(modinfo_path):
					target_mod_dir = subdir_path
					Status.post("Using fallback Arcana directory: %s" % subdir)
					break
	
	Status.post("Arcana mod directory selection result: %s" % target_mod_dir)
	return target_mod_dir






