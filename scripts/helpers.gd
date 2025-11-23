extends Node


const INFO_FILENAME := "catapult_install_info.json"


func create_info_file(location: String, name: String) -> void:
	
	var info = {"name": name}
	var path = location.path_join(INFO_FILENAME)
	
	# Ensure the directory exists
	var err = DirAccess.make_dir_absolute(location)
	if err != OK and err != ERR_ALREADY_EXISTS:
		Status.post(tr("msg_cannot_create_install_info") % path + " (mkdir failed: " + str(err) + ")", Enums.MSG_ERROR)
		return
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "    "))
	else:
		Status.post(tr("msg_cannot_create_install_info") % path, Enums.MSG_ERROR)


func get_all_nodes_within(n: Node) -> Array:
	
	var result = []
	for node in n.get_children():
		result.append(node)
		if node.get_child_count() > 0:
			result.append_array(get_all_nodes_within(node))
	return result


func load_json_file(file: String):
	
	var f := FileAccess.open(file, FileAccess.READ)
	
	if f == null:
		var err = FileAccess.get_open_error()
		Status.post(tr("msg_file_read_fail") % [file.get_file(), err], Enums.MSG_ERROR)
		Status.post(tr("msg_debug_file_path") % file, Enums.MSG_DEBUG)
		return null
	
	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(f.get_as_text())
	
	if error != OK:
		Status.post(tr("msg_json_parse_fail") % file.get_file(), Enums.MSG_ERROR)
		Status.post(tr("msg_debug_json_result") % [error, 0, "Parse error"], Enums.MSG_DEBUG)
		return null
	
	return test_json_conv.data


func save_to_json_file(data, file: String) -> bool:
	
	var f := FileAccess.open(file, FileAccess.WRITE)
	
	if f == null:
		var err = FileAccess.get_open_error()
		Status.post(tr("msg_file_write_fail") % [file.get_file(), err], Enums.MSG_ERROR)
		Status.post(tr("msg_debug_file_path") % file, Enums.MSG_DEBUG)
		return false
	
	var text := JSON.stringify(data, "    ")
	f.store_string(text)
	
	return true
