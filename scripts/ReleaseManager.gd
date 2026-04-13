extends Node


signal started_fetching_releases
signal done_fetching_releases

var _platform = ""


const _RELEASE_URLS = {
	"dda-experimental":
		"https://api.github.com/repos/CleverRaven/Cataclysm-DDA/releases",
	"bn-experimental":
		"https://api.github.com/repos/cataclysmbnteam/Cataclysm-BN/releases",
	"bn-rolling":
		"https://api.github.com/repos/cataclysmbn/Cataclysm-BN/releases/tags/experimental",
	"eod-experimental":
		"https://api.github.com/repos/AtomicFox556/Cataclysm-EOD/releases",
	"tish-experimental":
		"https://api.github.com/repos/Cataclysm-TISH-team/Cataclysm-TISH/releases",
	"tlg-experimental":
		"https://api.github.com/repos/Cataclysm-TLG/Cataclysm-TLG/releases",
}

const _CATACLYSM_DB_BASE_URL = "https://github.com/SrGnis/cataclysm-db/releases/download/latest/"
const _STABLE_CACHE_MAX_AGE_SECS = 7 * 24 * 60 * 60  # 7 days, matching cataclysm-db update frequency

const _ASSET_FILTERS = {
	"dda-experimental-linux": {
		"field": "name",
		"substring": "cdda-linux-with-graphics-and-sounds-x64",
	},
	"dda-experimental-win": {
		"field": "name",
		"substring": "cdda-windows-with-graphics-and-sounds-x64",
	},
	"dda-experimental-mac": {
		"field": "name",
		"substring": "cdda-osx-with-graphics-universal",
	},
	"bn-experimental-linux": {
		"field": "name",
		"substring": "cbn-linux-tiles-x64",
	},
	"bn-experimental-win": {
		"field": "name",
		"substring": "cbn-windows-tiles-x64",
	},
	"bn-experimental-mac": {
		"field": "name",
		"substring": "cbn-osx-tiles",
	},
	"eod-experimental-linux": {
		"field": "name",
		"substring": "eod-linux-tiles-x64",
	},
	"eod-experimental-win": {
		"field": "name",
		"substring": "eod-windows-tiles-x64",
	},
	"eod-experimental-mac": {
		"field": "name",
		"substring": "eod-osx-tiles",
	},
	"tish-experimental-linux": {
		"field": "name",
		"substring": "tish-linux-tiles-x64",
	},
	"tish-experimental-win": {
		"field": "name",
		"substring": "tish-windows-tiles-x64",
	},
	"tish-experimental-mac": {
		"field": "name",
		"substring": "tish-osx-tiles",
	},
	"tlg-experimental-linux": {
		"field": "name",
		"substring": "ctlg-linux-tiles-x64",
	},
	"tlg-experimental-win": {
		"field": "name",
		"substring": "ctlg-windows-tiles-sounds-x64-msvc",
	},
	"tlg-experimental-mac": {
		"field": "name",
		"substring": "ctlg-osx-tiles",
	},
}


var releases = {
	"dda-stable": [],
	"dda-experimental": [],
	"bn-stable": [],
	"bn-experimental": [],
	"bn-rolling": [],
	"eod-stable": [],
	#"eod-stable": [], Does not exist?
	"eod-experimental": [],
	"tish-stable": [],
	#"tish-stable": [], Does not exist?
	"tish-experimental": [],
	"tlg-experimental":[],
}


func _ready() -> void:
	
	var p = OS.get_name()
	match p:
		"X11":
			_platform = "linux"
		"Windows":
			_platform = "win"
		"OSX":
			_platform = "mac"
		_:
			Status.post(tr("msg_unsupported_platform") % p, Enums.MSG_ERROR)


func _get_query_string() -> String:
	
	var num_per_page = Settings.read("num_releases_to_request")
	return "?per_page=%s" % num_per_page


func _update_proxy(http: HTTPRequest) -> void:
	if Settings.read("proxy_option") == "on":
		var host = Settings.read("proxy_host")
		var port = Settings.read("proxy_port") as int
		http.set_http_proxy(host, port)
		http.set_https_proxy(host, port)
	else:
		http.set_http_proxy("", -1)
		http.set_https_proxy("", -1)

func _request_releases(http: HTTPRequest, release: String) -> void:
	emit_signal("started_fetching_releases")
	_update_proxy(http)
	
	# Get authentication headers from the parent Catapult instance if available
	var headers = PoolStringArray()
	var catapult = get_parent()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		headers = catapult._get_github_auth_headers()
	
	# Make the request with authentication if available
	http.request(_RELEASE_URLS[release] + _get_query_string(), headers)


func _on_request_completed_dda(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:
	
	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)
	
	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_builds(body, releases["dda-experimental"], _ASSET_FILTERS["dda-experimental-" + _platform])
	
	emit_signal("done_fetching_releases")


func _on_request_completed_bn(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:
	
	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)
	
	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_builds(body, releases["bn-experimental"], _ASSET_FILTERS["bn-experimental-" + _platform])
	
	emit_signal("done_fetching_releases")

func _on_request_completed_eod(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:
	
	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)
	
	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_builds(body, releases["eod-experimental"], _ASSET_FILTERS["eod-experimental-" + _platform])
	
	emit_signal("done_fetching_releases")

func _on_request_completed_tish(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:
	
	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)
	
	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_builds(body, releases["tish-experimental"], _ASSET_FILTERS["tish-experimental-" + _platform])
	
	emit_signal("done_fetching_releases")


func _on_request_completed_tlg(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:
	
	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)
	
	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_builds(body, releases["tlg-experimental"], _ASSET_FILTERS["tlg-experimental-" + _platform])
	
	emit_signal("done_fetching_releases")


func _get_stable_cache_path(game: String) -> String:
	return OS.get_executable_path().get_base_dir().plus_file(
		"stable_cache_%s_%s.json" % [game, _platform]
	)


func _load_stable_cache(game: String) -> Array:
	var path = _get_stable_cache_path(game)
	if not File.new().file_exists(path):
		return []
	var data = Helpers.load_json_file(path)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return []
	if OS.get_unix_time() - data.get("timestamp", 0) > _STABLE_CACHE_MAX_AGE_SECS:
		return []
	var cached = data.get("releases", [])
	if not cached is Array or cached.empty():
		return []
	return cached


func _save_stable_cache(game: String, releases_data: Array) -> void:
	Helpers.save_to_json_file(
		{"timestamp": OS.get_unix_time(), "releases": releases_data},
		_get_stable_cache_path(game)
	)


func _request_stable_releases(http: HTTPRequest, url: String) -> void:
	emit_signal("started_fetching_releases")
	_update_proxy(http)
	http.request(url)


func _get_db_platform() -> String:
	match _platform:
		"win": return "windows"
		"linux": return "linux"
		"mac": return "macos"
	return "unknown"


func _parse_stable_builds_from_db(data: PoolByteArray, write_to: Array) -> void:
	var json = JSON.parse(data.get_string_from_utf8()).result

	if typeof(json) != TYPE_ARRAY:
		if typeof(json) == TYPE_DICTIONARY and "message" in json:
			Status.post(tr("msg_releases_api_failure") % json["message"])
		return

	var db_platform = _get_db_platform()
	var db_arch = "universal" if _platform == "mac" else "x64"
	var tmp_arr = []

	for rec in json:
		var build = {}
		build["name"] = rec.get("name", rec.get("tag_name", ""))
		if Settings.read("shorten_release_names"):
			build["name"] = build["name"].split(" ")[-1]
		build["url"] = ""
		build["filename"] = ""
		build["published_at"] = rec.get("published_at", "")
		build["has_any_assets"] = len(rec.get("assets", [])) > 0

		var best_asset = null
		for asset in rec.get("assets", []):
			if asset.get("platform", "") != db_platform:
				continue
			if asset.get("graphics", "") != "tiles":
				continue
			if asset.get("arch", "") != db_arch:
				continue
			if best_asset == null:
				best_asset = asset
			elif asset.get("sounds", "") == "sounds" and best_asset.get("sounds", "") != "sounds":
				best_asset = asset

		if best_asset != null:
			build["url"] = best_asset.get("download_url", "")
			build["filename"] = best_asset.get("name", "")

		tmp_arr.append(build)

	if len(tmp_arr) > 0:
		write_to.clear()
		write_to.append_array(tmp_arr)
		Status.post(tr("msg_got_n_releases") % len(tmp_arr))


func _on_request_completed_dda_stable(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:

	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)

	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_stable_builds_from_db(body, releases["dda-stable"])
		if not releases["dda-stable"].empty():
			_save_stable_cache("dda", releases["dda-stable"])

	emit_signal("done_fetching_releases")


func _on_request_completed_bn_stable(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:

	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)

	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_stable_builds_from_db(body, releases["bn-stable"])
		if not releases["bn-stable"].empty():
			_save_stable_cache("bn", releases["bn-stable"])

	emit_signal("done_fetching_releases")


func _request_rolling_release(http: HTTPRequest, url: String) -> void:
	emit_signal("started_fetching_releases")
	_update_proxy(http)
	var headers = PoolStringArray()
	var catapult = get_parent()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		headers = catapult._get_github_auth_headers()
	http.request(url, headers)


func _on_request_completed_bn_rolling(result: int, response_code: int,
		headers: PoolStringArray, body: PoolByteArray) -> void:

	Status.post(tr("msg_http_request_info") %
			[result, response_code, headers], Enums.MSG_DEBUG)

	if result:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
	else:
		_parse_rolling_build(body, releases["bn-rolling"])

	emit_signal("done_fetching_releases")


func _parse_rolling_build(data: PoolByteArray, write_to: Array) -> void:
	var json = JSON.parse(data.get_string_from_utf8()).result

	if typeof(json) != TYPE_DICTIONARY:
		Status.post(tr("msg_releases_request_failed"), Enums.MSG_WARN)
		return

	if "message" in json:
		Status.post(tr("msg_releases_api_failure") % json["message"])
		return

	var filter = _ASSET_FILTERS["bn-experimental-" + _platform]
	var build = {}
	build["name"] = json.get("name", json.get("tag_name", "experimental"))
	if Settings.read("shorten_release_names"):
		build["name"] = build["name"].split(" ")[-1]
	build["url"] = ""
	build["filename"] = ""
	build["published_at"] = json.get("published_at", "")
	build["has_any_assets"] = len(json.get("assets", [])) > 0

	for asset in json.get("assets", []):
		if filter["substring"] in asset[filter["field"]]:
			build["url"] = asset["browser_download_url"]
			build["filename"] = asset["name"]

	write_to.clear()
	write_to.append(build)
	Status.post(tr("msg_got_n_releases") % 1)


func _parse_builds(data: PoolByteArray, write_to: Array, filter: Dictionary) -> void:

	var json = JSON.parse(data.get_string_from_utf8()).result

	# Check if API rate limit is exceeded
	if "message" in json:
		print(tr("msg_releases_api_failure") % json["message"])
		return

	var tmp_arr = []

	for rec in json:
		var build = {}
		build["name"] = rec["name"]
		if Settings.read("shorten_release_names"):
			build["name"] = build["name"].split(" ")[-1]
		build["url"] = ""
		build["filename"] = ""
		build["published_at"] = rec.get("published_at", "")
		build["has_any_assets"] = len(rec["assets"]) > 0

		for asset in rec["assets"]:
			if filter["substring"] in asset[filter["field"]]:
				build["url"] = asset["browser_download_url"]
				build["filename"] = asset["name"]

		# Include all releases, even those without matching assets
		tmp_arr.append(build)

	if len(tmp_arr) > 0:
		write_to.clear()
		write_to.append_array(tmp_arr)
		Status.post(tr("msg_got_n_releases") % len(tmp_arr))


func fetch(release_key: String) -> void:
	
	match release_key:
		"dda-stable":
			var cached_dda = _load_stable_cache("dda")
			if not cached_dda.empty():
				releases["dda-stable"] = cached_dda
				Status.post(tr("msg_got_n_releases") % len(cached_dda))
				emit_signal("done_fetching_releases")
			else:
				Status.post(tr("msg_fetching_releases") % "DDA Stable")
				Status.post(tr("msg_please_wait_stable"))
				yield(get_tree().create_timer(1.0), "timeout")
				_request_stable_releases($HTTPRequest_DDA_Stable, _CATACLYSM_DB_BASE_URL + "dda_stable_releases.json")
		"dda-experimental":
			Status.post(tr("msg_fetching_releases_dda"))
			_request_releases($HTTPRequest_DDA, "dda-experimental")
		"bn-stable":
			var cached_bn = _load_stable_cache("bn")
			if not cached_bn.empty():
				releases["bn-stable"] = cached_bn
				Status.post(tr("msg_got_n_releases") % len(cached_bn))
				emit_signal("done_fetching_releases")
			else:
				Status.post(tr("msg_fetching_releases") % "BN Stable")
				Status.post(tr("msg_please_wait_stable"))
				yield(get_tree().create_timer(1.0), "timeout")
				_request_stable_releases($HTTPRequest_BN_Stable, _CATACLYSM_DB_BASE_URL + "bn_stable_releases.json")
		"bn-experimental":
			Status.post(tr("msg_fetching_releases_bn"))
			_request_releases($HTTPRequest_BN, "bn-experimental")
		"bn-rolling":
			Status.post(tr("msg_fetching_releases_bn"))
			_request_rolling_release($HTTPRequest_BN_Rolling, _RELEASE_URLS["bn-rolling"])
		"eod-experimental":
			Status.post(tr("msg_fetching_releases_eod"))
			_request_releases($HTTPRequest_EOD, "eod-experimental")
		"tish-experimental":
			Status.post(tr("msg_fetching_releases_tish"))
			_request_releases($HTTPRequest_TISH, "tish-experimental")
		"tlg-experimental":
			Status.post(tr("msg_fetching_releases_tlg"))
			_request_releases($HTTPRequest_TLG, "tlg-experimental")
		_:
			Status.post((tr("msg_invalid_fetch_func_param") % [release_key] ), Enums.MSG_ERROR)
