class_name OSExecWrapper
extends Object


signal process_exited

var _worker: Thread
var output = []
var exit_code = null
var _capture_output: bool = true


func _wrapper(path_and_args: Array) -> void:
	
	exit_code = OS.execute(path_and_args[0], path_and_args[1], true, output if _capture_output else [], true)
	emit_signal("process_exited")
	_worker.call_deferred("wait_to_finish")

func execute(path: String, args: PoolStringArray, capture_output: bool = true) -> void:
	
	_capture_output = capture_output
	_worker = Thread.new()
	_worker.start(self, "_wrapper", [path, args])

