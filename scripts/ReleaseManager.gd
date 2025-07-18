extends Node


signal started_fetching_releases
signal done_fetching_releases

var _platform = ""


const _RELEASE_URLS = {
	"dda-experimental":
		"https://api.github.com/repos/CleverRaven/Cataclysm-DDA/releases",
	"bn-experimental":
		"https://api.github.com/repos/cataclysmbnteam/Cataclysm-BN/releases",
	"eod-experimental":
		"https://api.github.com/repos/AtomicFox556/Cataclysm-EOD/releases",
	"tish-experimental":
		"https://api.github.com/repos/Cataclysm-TISH-team/Cataclysm-TISH/releases",
	"tlg-experimental":
		"https://api.github.com/repos/Cataclysm-TLG/Cataclysm-TLG/releases",
}

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
		"substring": "ctlg-windows-tiles-x64",
	},
	"tlg-experimental-mac": {
		"field": "name",
		"substring": "ctlg-osx-tiles",
	},
}

const _DDA_STABLE_LINUX = [
	{
		"name": "0.H Herbert",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.H-RELEASE/cdda-linux-with-graphics-x64-2024-11-23-1857.tar.gz",
		"filename": "cdda-linux-with-graphics-x64-2024-11-23-1857.tar.gz"
	},	
	{
		"name": "0.G Gaiman",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.G/cdda-linux-tiles-x64-2023-03-01-0054.tar.gz",
		"filename": "cdda-linux-tiles-x64-2023-03-01-0054.tar.gz"
	},	
	{
		"name": "0.F-2 Frank-2",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F-2/cataclysmdda-0.F-Linux_x64-Tiles-0.F-2.tar.gz",
		"filename": "cataclysmdda-0.F-Linux_x64-Tiles-0.F-2.tar.gz"
	},
	{
		"name": "0.F-1 Frank-1",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F-1/cataclysmdda-0.F-Linux_x64-Tiles-0.F-1.tar.gz",
		"filename": "cataclysmdda-0.F-Linux_x64-Tiles-0.F-1.tar.gz"
	},
	{
		"name": "0.F Frank",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F/cdda-linux-tiles-x64-2021-07-03-0512.tar.gz",
		"filename": "cdda-linux-tiles-x64-2021-07-03-0512.tar.gz"
	},
	{
		"name": "0.E-3 Ellison-3",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E-3/cataclysmdda-0.E-Linux_x64-Tiles-0.E-3.tar.gz",
		"filename": "cataclysmdda-0.E-Linux_x64-Tiles-0.E-3.tar.gz"
	},
	{
		"name": "0.E-2 Ellison-2",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E-2/cataclysmdda-0.E-Linux_x64-Tiles-0.E-2.tar.gz",
		"filename": "cataclysmdda-0.E-Linux_x64-Tiles-0.E-2.tar.gz"
	},
	{
		"name": "0.E-1 Ellison-1",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E-1/cataclysmdda-0.E-Linux_x64-Tiles-0.E-1.tar.gz",
		"filename": "cataclysmdda-0.E-Linux_x64-Tiles-0.E-1.tar.gz"
	},
	{
		"name": "0.E Ellison",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E/cataclysmdda-0.E-Linux_x64-Tiles-10478.tar.gz",
		"filename": "cataclysmdda-0.E-Linux_x64-Tiles-10478.tar.gz"
	},
	{
		"name": "0.D Danny",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.D/cataclysmdda-0.D-8574-Linux-Tiles.tar.gz",
		"filename": "cataclysmdda-0.D-8574-Linux-Tiles.tar.gz"
	},
]

const _DDA_STABLE_WIN = [
	{
		"name": "0.H Herbert",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.H-RELEASE/cdda-windows-with-graphics-x64-2024-11-23-1857.zip",
		"filename": "cdda-windows-with-graphics-x64-2024-11-23-1857.zip"
	},	
	{
		"name": "0.G Gaiman",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.G/cdda-windows-tiles-x64-2023-03-01-0054.zip",
		"filename": "cdda-windows-tiles-x64-2023-03-01-0054.zip"
	},	
	{
		"name": "0.F-3 Frank-3",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F-3/cataclysmdda-0.F-Windows_x64-Tiles-0.F-3.zip",
		"filename": "cataclysmdda-0.F-Windows_x64-Tiles-0.F-3.zip"
	},	
	{
		"name": "0.F-2 Frank-2",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F-2/cataclysmdda-0.F-Windows_x64-Tiles-0.F-2.zip",
		"filename": "cataclysmdda-0.F-Windows_x64-Tiles-0.F-2.zip"
	},
	{
		"name": "0.F-1 Frank-1",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F-1/cataclysmdda-0.F-Windows_x64-Tiles-0.F-1.zip",
		"filename": "cataclysmdda-0.F-Windows_x64-Tiles-0.F-1.zip"
	},
	{
		"name": "0.F Frank",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.F/cdda-windows-tiles-x64-2021-07-03-0512.zip",
		"filename": "cdda-windows-tiles-x64-2021-07-03-0512.zip"
	},
	{
		"name": "0.E-3 Ellison-3",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E-3/cataclysmdda-0.E-Windows_x64-Tiles-0.E-3.zip",
		"filename": "cataclysmdda-0.E-Windows_x64-Tiles-0.E-3.zip"
	},
	{
		"name": "0.E-2 Ellison-2",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E-2/cataclysmdda-0.E-Windows_x64-Tiles-0.E-2.zip",
		"filename": "cataclysmdda-0.E-Windows_x64-Tiles-0.E-2.zip"
	},
	{
		"name": "0.E-1 Ellison-1",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E-1/cataclysmdda-0.E-Windows_x64-Tiles-0.E-1.zip",
		"filename": "cataclysmdda-0.E-Windows_x64-Tiles-0.E-1.zip"
	},
	{
		"name": "0.E Ellison",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.E/cataclysmdda-0.E-Windows_x64-Tiles-10478.zip",
		"filename": "cataclysmdda-0.E-Windows_x64-Tiles-10478.zip"
	},
	{
		"name": "0.D Danny",
		"url": "https://github.com/CleverRaven/Cataclysm-DDA/releases/download/0.D/cataclysmdda-0.D-8574-Win64-Tiles.zip",
		"filename": "cataclysmdda-0.D-8574-Win64-Tiles.zip"
	},
]

const _BN_STABLE_LINUX = [
	{
		"name": "0.7.0",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/v0.7.0/cbn-linux-tiles-x64-v0.7.0.tar.gz",
		"filename": "cbn-linux-tiles-x64-v0.7.0.tar.gz"
	},
	{
		"name": "0.6.0",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/v0.6.0/cbn-linux-tiles-x64-v0.6.0.tar.gz",
		"filename": "cbn-linux-tiles-x64-v0.6.0.tar.gz"
	},
	{
		"name": "0.5.2",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.5.2/cbn-linux-tiles-x64-0.5.2.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.5.2.tar.gz"
	},
	{
		"name": "0.5.1",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.5.1/cbn-linux-tiles-x64-0.5.1.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.5.1.tar.gz"
	},
	{
		"name": "0.5",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.5/cbn-linux-tiles-x64-0.5.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.5.tar.gz"
	},
	{
		"name": "0.4",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.4/cbn-linux-tiles-x64-0.4.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.4.tar.gz"
	},
	{
		"name": "0.3",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.3/cbn-linux-tiles-x64-0.3.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.3.tar.gz"
	},
	{
		"name": "0.2",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.2/cbn-linux-tiles-x64-0.2.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.2.tar.gz"
	},
	{
		"name": "0.1",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.1/cbn-linux-tiles-x64-0.1.tar.gz",
		"filename": "cbn-linux-tiles-x64-0.1.tar.gz"
	},
]

const _BN_STABLE_WIN = [
	{
		"name": "0.7.0",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/v0.7.0/cbn-windows-tiles-x64-v0.7.0.zip",
		"filename": "cbn-windows-tiles-x64-v0.7.0.zip"
	},
	{
		"name": "0.6.0",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/v0.6.0/cbn-windows-tiles-x64-v0.6.0.zip",
		"filename": "cbn-windows-tiles-x64-v0.6.0.zip"
	},
	{
		"name": "0.5.2",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/v0.5.2/cbn-windows-tiles-x64-msvc-v0.5.2.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.5.2.zip"
	},
	{
		"name": "0.5.1",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.5.1/cbn-windows-tiles-x64-msvc-0.5.1.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.5.1.zip"
	},
	{
		"name": "0.5",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.5/cbn-windows-tiles-x64-msvc-0.5.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.5.zip"
	},
	{
		"name": "0.4",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.4/cbn-windows-tiles-x64-msvc-0.4.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.4.zip"
	},
	{
		"name": "0.3",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.3/cbn-windows-tiles-x64-msvc-0.3.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.3.zip"
	},
	{
		"name": "0.2",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.2/cbn-windows-tiles-x64-msvc-0.2.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.2.zip"
	},
	{
		"name": "0.1",
		"url": "https://github.com/cataclysmbnteam/Cataclysm-BN/releases/download/cbn-0.1/cbn-windows-tiles-x64-msvc-0.1.zip",
		"filename": "cbn-windows-tiles-x64-msvc-0.1.zip"
	}
]

var releases = {
	"dda-stable": [],
	"dda-experimental": [],
	"bn-stable": [],
	"bn-experimental": [],
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
		build["published_at"] = rec.get("published_at", "")
		
		for asset in rec["assets"]:
			if filter["substring"] in asset[filter["field"]]:
				build["url"] = asset["browser_download_url"]
				build["filename"] = asset["name"]
		
		if build["url"] != "":
			tmp_arr.append(build)
	
	if len(tmp_arr) > 0:
		write_to.clear()
		write_to.append_array(tmp_arr)
		Status.post(tr("msg_got_n_releases") % len(tmp_arr))


func fetch(release_key: String) -> void:
	
	match release_key:
		"dda-stable":
			match _platform:
				"linux":
					releases["dda-stable"] = _DDA_STABLE_LINUX
				"win":
					releases["dda-stable"] = _DDA_STABLE_WIN
			emit_signal("done_fetching_releases")
		"dda-experimental":
			Status.post(tr("msg_fetching_releases_dda"))
			_request_releases($HTTPRequest_DDA, "dda-experimental")
		"bn-stable":
			match _platform:
				"linux":
					releases["bn-stable"] = _BN_STABLE_LINUX
				"win":
					releases["bn-stable"] = _BN_STABLE_WIN
			emit_signal("done_fetching_releases")
		"bn-experimental":
			Status.post(tr("msg_fetching_releases_bn"))
			_request_releases($HTTPRequest_BN, "bn-experimental")
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

