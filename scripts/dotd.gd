extends Node
# This node stores donor messages of the day and picks one at random when asked.
# Each entry is a personal message from a donor — these are not translated.


const _DONORS = [
	"[i]\"You can request a message to be shown here by donating to the Dabdoob project!\"[/i]\n    — [color=#f5c842][b]Hihahahalol The Dabdoob[/b][/color]",
]


func get_message() -> String:

	var index = OS.get_system_time_msecs() % len(_DONORS)
	return _DONORS[index]
