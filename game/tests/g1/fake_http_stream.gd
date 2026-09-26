extends "res://infrastructure/ai/http_stream_port.gd"
## Offline test double for the streaming HTTP seam. The test drives every callback manually,
## so ordering, late callbacks and duplicate terminals are deterministic. Test-only.

var started: bool = false
var cancelled: bool = false
var url: String = ""
var headers: Dictionary = {}
var body: PackedByteArray = PackedByteArray()
var start_failure_code: String = ""

func start(request_url: String, request_headers: Dictionary, request_body: PackedByteArray) -> RefCounted:
	if not start_failure_code.is_empty():
		return Result.failure(start_failure_code)
	started = true
	url = request_url
	headers = request_headers.duplicate(true)
	body = request_body
	return Result.success()

func cancel() -> void:
	cancelled = true

func emit_chunk(bytes: PackedByteArray) -> void:
	body_chunk.emit(bytes)

func emit_chunk_text(text: String) -> void:
	body_chunk.emit(text.to_utf8_buffer())

func emit_finished(status_code: int) -> void:
	response_finished.emit(status_code)

func emit_failed(code: String) -> void:
	transport_failed.emit(code)
