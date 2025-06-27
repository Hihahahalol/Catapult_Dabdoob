class_name OSExecWrapper
extends Object


signal process_exited

var _worker: Thread
var output = []
var error_output = []
var exit_code = null
var _capture_output: bool = true


func _wrapper(path_and_args: Array) -> void:
	
	# For Godot 3, OS.execute only captures stdout, not stderr
	# We need to use a shell wrapper to capture both
	if _capture_output and (OS.get_name() == "X11" or OS.get_name() == "OSX"):
		# On Unix systems, use bash to capture both stdout and stderr
		var temp_script_content = """#!/bin/bash
%s %s 2>&1
echo "EXIT_CODE:$?"
""" % [path_and_args[0], PoolStringArray(path_and_args[1]).join(" ")]
		
		var temp_script_path = OS.get_user_data_dir().plus_file("temp_exec.sh")
		var temp_file = File.new()
		temp_file.open(temp_script_path, File.WRITE)
		temp_file.store_string(temp_script_content)
		temp_file.close()
		
		# Make script executable
		OS.execute("chmod", ["+x", temp_script_path], true)
		
		# Execute the script
		var combined_output = []
		exit_code = OS.execute("/bin/bash", [temp_script_path], true, combined_output, true)
		
		# Parse output to separate stdout from exit code
		output = []
		error_output = []
		var actual_exit_code = null
		
		for line in combined_output:
			if line.begins_with("EXIT_CODE:"):
				actual_exit_code = int(line.substr(10))
			else:
				output.append(line)
		
		# If we found an exit code in the output, use that instead
		if actual_exit_code != null:
			exit_code = actual_exit_code
		
		# Clean up temp script
		var cleanup_dir = Directory.new()
		if cleanup_dir.file_exists(temp_script_path):
			cleanup_dir.remove(temp_script_path)
	else:
		# Windows or non-capture mode - use original method
		exit_code = OS.execute(path_and_args[0], path_and_args[1], true, output if _capture_output else [], true)
	
	emit_signal("process_exited")
	_worker.call_deferred("wait_to_finish")

func execute(path: String, args: PoolStringArray, capture_output: bool = true) -> void:
	
	_capture_output = capture_output
	output = []
	error_output = []
	exit_code = null
	_worker = Thread.new()
	_worker.start(self, "_wrapper", [path, args])

