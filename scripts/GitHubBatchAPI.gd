extends Node

# GitHubBatchAPI - Handles batched GitHub API requests for mod information
# Uses GitHub GraphQL API to fetch multiple repositories' data in a single request

signal batch_request_completed(results)

const BATCH_SIZE = 20  # Number of repositories to query per GraphQL request
const MAX_RETRIES = 3

var _pending_batches: Array = []
var _current_batch: Array = []
var _results: Dictionary = {}
var _retry_count: int = 0


# Queue a mod for batch fetching
func queue_mod(mod_id: String, owner: String, repo: String) -> void:
	_current_batch.append({
		"mod_id": mod_id,
		"owner": owner,
		"repo": repo
	})


# Execute all queued batch requests
func execute_batches() -> void:
	if len(_current_batch) == 0:
		Status.post("No mods to fetch, emitting empty results", Enums.MSG_DEBUG)
		emit_signal("batch_request_completed", {})
		return
	
	_results.clear()
	_pending_batches.clear()
	
	# Split current batch into chunks of BATCH_SIZE
	var batch_index = 0
	while batch_index < len(_current_batch):
		var chunk = []
		for i in range(BATCH_SIZE):
			if batch_index + i < len(_current_batch):
				chunk.append(_current_batch[batch_index + i])
		_pending_batches.append(chunk)
		batch_index += BATCH_SIZE
	
	Status.post("Fetching mod information in %d batch(es)..." % len(_pending_batches), Enums.MSG_DEBUG)
	
	# Start processing batches
	_process_next_batch()


# Process the next batch in the queue
func _process_next_batch() -> void:
	if len(_pending_batches) == 0:
		# All batches complete
		Status.post("All batches complete, total results: %d" % len(_results), Enums.MSG_DEBUG)
		_current_batch.clear()
		emit_signal("batch_request_completed", _results)
		return
	
	var batch = _pending_batches.pop_front()
	Status.post("Processing batch with %d mods..." % len(batch), Enums.MSG_DEBUG)
	_fetch_batch_graphql(batch)


# Build and execute a GraphQL query for a batch of repositories
func _fetch_batch_graphql(batch: Array) -> void:
	# Build GraphQL query
	var query = _build_graphql_query(batch)
	
	Status.post("GraphQL query built for %d repos" % len(batch), Enums.MSG_DEBUG)
	
	# Create HTTP request
	var http_request = HTTPRequest.new()
	http_request.timeout = 30  # 30 second timeout
	add_child(http_request)
	
	# Set up proxy if needed
	if Settings.read("proxy_option") == "on":
		var host = Settings.read("proxy_host")
		var port = Settings.read("proxy_port") as int
		http_request.set_http_proxy(host, port)
		http_request.set_https_proxy(host, port)
	
	# Connect signal
	http_request.connect("request_completed", self, "_on_batch_request_completed", [http_request, batch])
	
	# Get authentication headers
	var headers = _get_github_headers()
	
	var query_body = JSON.print({"query": query})
	Status.post("Making GraphQL request to GitHub API...", Enums.MSG_DEBUG)
	
	# Make GraphQL request
	var error = http_request.request(
		"https://api.github.com/graphql",
		headers,
		true,
		HTTPClient.METHOD_POST,
		query_body
	)
	
	if error != OK:
		Status.post("Failed to start batch API request (error: %d)" % error, Enums.MSG_ERROR)
		# Clean up
		remove_child(http_request)
		http_request.queue_free()
		# Process remaining batches
		_retry_count = 0
		_process_next_batch()


# Build a GraphQL query for multiple repositories
func _build_graphql_query(batch: Array) -> String:
	var query_parts = []
	
	for i in range(len(batch)):
		var item = batch[i]
		var alias = "repo%d" % i
		
		# Query for release info and commit info as fallback
		query_parts.append("""
		%s: repository(owner: "%s", name: "%s") {
			defaultBranchRef {
				target {
					... on Commit {
						committedDate
					}
				}
			}
			latestRelease {
				publishedAt
				name
				tagName
			}
		}
		""" % [alias, item["owner"], item["repo"]])
	
	var full_query = "query { %s }" % "\n".join(query_parts)
	return full_query


# Get GitHub API headers with authentication
func _get_github_headers() -> PoolStringArray:
	var headers = PoolStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])
	
	# Get authentication from Catapult root node (traverse up the tree)
	var catapult = _find_catapult_node()
	if catapult and catapult.has_method("_get_github_auth_headers"):
		var auth_headers = catapult._get_github_auth_headers()
		for header in auth_headers:
			headers.append(header)
			Status.post("Added auth header", Enums.MSG_DEBUG)
	else:
		Status.post("No authentication found, using unauthenticated requests", Enums.MSG_DEBUG)
	
	return headers


# Find the Catapult root node by traversing up the tree
func _find_catapult_node():
	var node = get_parent()
	while node != null:
		if node.has_method("_get_github_auth_headers"):
			return node
		node = node.get_parent()
	return null


# Handle batch request completion
func _on_batch_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray, http_request: HTTPRequest, batch: Array) -> void:
	
	Status.post("Batch request completed: result=%d, code=%d" % [result, response_code], Enums.MSG_DEBUG)
	
	# Clean up HTTP request
	remove_child(http_request)
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		Status.post("Batch API request failed (result: %d, code: %d)" % [result, response_code], Enums.MSG_WARN)
		
		# Retry logic
		if _retry_count < MAX_RETRIES:
			_retry_count += 1
			Status.post("Retrying batch request (attempt %d/%d)..." % [_retry_count, MAX_RETRIES], Enums.MSG_DEBUG)
			yield(get_tree().create_timer(1.0), "timeout")
			_fetch_batch_graphql(batch)
			return
		else:
			_retry_count = 0
			Status.post("Max retries reached, skipping batch", Enums.MSG_WARN)
			# Mark all mods in this batch as failed with empty dates
			for item in batch:
				_results[item["mod_id"]] = ""
			# Process next batch on failure
			_process_next_batch()
			return
	
	_retry_count = 0
	
	# Check for rate limit or other API errors
	if response_code == 401:
		Status.post("GitHub API authentication failed - check your Auth_Token.txt", Enums.MSG_ERROR)
		# Mark all as failed
		for item in batch:
			_results[item["mod_id"]] = ""
		_process_next_batch()
		return
	elif response_code == 403:
		Status.post("GitHub API rate limit exceeded - please wait or add authentication token", Enums.MSG_WARN)
		# Mark all as failed
		for item in batch:
			_results[item["mod_id"]] = ""
		_process_next_batch()
		return
	elif response_code != 200:
		Status.post("GitHub API returned error code: %d" % response_code, Enums.MSG_WARN)
		var body_str = body.get_string_from_utf8()
		Status.post("Response body: %s" % body_str.substr(0, 200), Enums.MSG_DEBUG)
		# Mark all as failed
		for item in batch:
			_results[item["mod_id"]] = ""
		_process_next_batch()
		return
	
	# Parse JSON response
	var body_str = body.get_string_from_utf8()
	Status.post("Parsing JSON response (%d bytes)..." % len(body_str), Enums.MSG_DEBUG)
	
	var json = JSON.parse(body_str)
	if json.error != OK:
		Status.post("Failed to parse batch API response: %s" % json.error_string, Enums.MSG_ERROR)
		# Mark all as failed
		for item in batch:
			_results[item["mod_id"]] = ""
		_process_next_batch()
		return
	
	var response_data = json.result
	
	# Check for GraphQL errors
	if "errors" in response_data:
		Status.post("GraphQL errors: %s" % str(response_data["errors"]), Enums.MSG_WARN)
		# Continue processing even with errors, as partial data may be available
	
	if not "data" in response_data:
		Status.post("No data in batch API response", Enums.MSG_WARN)
		# Mark all as failed
		for item in batch:
			_results[item["mod_id"]] = ""
		_process_next_batch()
		return
	
	# Parse results for each repository
	var data = response_data["data"]
	for i in range(len(batch)):
		var alias = "repo%d" % i
		var item = batch[i]
		var mod_id = item["mod_id"]
		
		if alias in data and data[alias] != null:
			var repo_data = data[alias]
			var release_date = ""
			
			# Try to get release date first
			if "latestRelease" in repo_data and repo_data["latestRelease"] != null:
				var release = repo_data["latestRelease"]
				if "publishedAt" in release:
					release_date = release["publishedAt"].split("T")[0]
					Status.post("Retrieved release date for %s: %s" % [mod_id, release_date], Enums.MSG_DEBUG)
			
			# Fallback to commit date if no release
			if release_date == "" and "defaultBranchRef" in repo_data and repo_data["defaultBranchRef"] != null:
				var branch = repo_data["defaultBranchRef"]
				if "target" in branch and branch["target"] != null and "committedDate" in branch["target"]:
					release_date = branch["target"]["committedDate"].split("T")[0]
					Status.post("Retrieved commit date for %s: %s" % [mod_id, release_date], Enums.MSG_DEBUG)
			
			_results[mod_id] = release_date
		else:
			Status.post("No data found for %s (owner: %s, repo: %s)" % [mod_id, item["owner"], item["repo"]], Enums.MSG_DEBUG)
			_results[mod_id] = ""
	
	# Process next batch
	_process_next_batch()


# Clear all queued requests
func clear_queue() -> void:
	_current_batch.clear()
	_pending_batches.clear()
	_results.clear()
	_retry_count = 0
	Status.post("Batch queue cleared", Enums.MSG_DEBUG)

