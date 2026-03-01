extends Node

signal narrative_generated(event_type: String, event_data: Dictionary)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[NarrativeLogger] initialized")

func log_action(narrative_text: String, action_data: Dictionary = {}):
	var data = {
		"event": "Action",
		"narrative": narrative_text,
		"data": action_data,
		"timestamp": Time.get_unix_time_from_system()
	}

	_print_log(data)
	narrative_generated.emit("Action", data)

func log_event(narrative_text: String, event_type: String = "GameEvent", event_data: Dictionary = {}):
	var data = {
		"event": event_type,
		"narrative": narrative_text,
		"data": event_data,
		"timestamp": Time.get_unix_time_from_system()
	}

	_print_log(data)
	narrative_generated.emit(event_type, data)

func _print_log(data: Dictionary):
	print("[NarrativeLog] %s: %s | %s" % [data.event, data.narrative, JSON.stringify(data.data)])
