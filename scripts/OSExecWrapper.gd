class_name OSExecWrapper
extends Object


signal process_exited

var _worker: Thread
var output = []
var exit_code = null
var _capture_output: bool = true

var _mutex := Mutex.new()
var _done := false


func _wrapper(path_and_args: Array) -> void:

	var result = OS.execute(path_and_args[0], path_and_args[1], true, output if _capture_output else [], true)
	exit_code = result
	_mutex.lock()
	_done = true
	_mutex.unlock()
	emit_signal("process_exited")
	_worker.call_deferred("wait_to_finish")

func execute(path: String, args: PoolStringArray, capture_output: bool = true) -> void:

	_capture_output = capture_output
	_worker = Thread.new()
	_worker.start(self, "_wrapper", [path, args])


func is_done() -> bool:
	# Thread-safe, poll-from-main-thread alternative to the "process_exited"
	# signal above. Godot 3's MessageQueue (which both emit_signal on a
	# deferred connection and call_deferred rely on) isn't mutex-protected,
	# so triggering it from this background Thread isn't guaranteed safe.
	# One-shot: returns true exactly once per finished run.
	_mutex.lock()
	var d = _done
	_done = false
	_mutex.unlock()
	return d

