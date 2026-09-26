extends RefCounted
## Presentation-facing facade. No networking, persistence, or mutable state escapes.
const StateStore = preload("res://domain/story/state_store.gd")

signal state_changed(snapshot: Dictionary)

var _state: StateStore

func _init(state: StateStore) -> void:
	_state = state

func read_state() -> Dictionary:
	return _state.snapshot()

func diagnostics() -> Dictionary:
	return {"revision": _state.snapshot().revision}

# Feature-specific commands will be added here (or dedicated use cases).
# No generic UI-accessible set_flag/execute_script command is exposed.
