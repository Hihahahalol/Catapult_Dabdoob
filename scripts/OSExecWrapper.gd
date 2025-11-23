class_name OSExecWrapper
extends Object


signal process_exited

var _worker: Thread
var output = []
var exit_code = null
var _capture_output: bool = true


func _wrapper(path_and_args: Array) -> void:
	var output_array: Array = []
	if _capture_output:
		exit_code = OS.execute(path_and_args[0], path_and_args[1], output, true)
	else:
		exit_code = OS.execute(path_and_args[0], path_and_args[1], output_array, true)
	emit_signal("process_exited")
	_worker.call_deferred("wait_to_finish")

func execute(path: String, args: PackedStringArray, capture_output: bool = true) -> void:
	
	_capture_output = capture_output
	_worker = Thread.new()
	_worker.start(Callable(self, "_wrapper").bind([path, args]))

