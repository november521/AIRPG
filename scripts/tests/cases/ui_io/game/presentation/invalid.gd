extends Control
func bypass() -> void:
	FileAccess.open("user://invalid", FileAccess.WRITE)
