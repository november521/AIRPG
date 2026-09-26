extends "res://infrastructure/ai/http_stream_port.gd"
## Real-network streaming HTTP implementation using HTTPClient polled from _process.
## IMPORTANT: this implementation is NOT verified against a live DeepSeek endpoint in the
## G1 package. Offline contract tests use fake streams instead. The host Node is injected by
## composition and owns this node in the scene tree.

const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Contract = preload("res://application/contracts/model_transport_contract.gd")

enum State { IDLE, CONNECTING, REQUESTING, READING, FINISHED }

var _host: Node = null
var _client: HTTPClient = null
var _path: String = ""
var _headers: PackedStringArray = PackedStringArray()
var _body: PackedByteArray = PackedByteArray()
var _state: int = State.IDLE
var _status_code: int = 0
var _status_emitted: bool = false

func _init(host: Node = null) -> void:
	_host = host

func start(url: String, headers: Dictionary, body: PackedByteArray) -> RefCounted:
	if _state != State.IDLE or _host == null or not is_instance_valid(_host):
		return Result.failure(Contract.MODEL_TRANSPORT_ERROR)
	var parts := Config.endpoint_parts(url)
	if parts.is_empty():
		return Result.failure(Contract.MODEL_TRANSPORT_ERROR)
	_path = String(parts["path"])
	_body = body
	_headers = PackedStringArray()
	for name: Variant in headers:
		_headers.append("%s: %s" % [str(name), str(headers[name])])
	_client = HTTPClient.new()
	var error := _client.connect_to_host(String(parts["host"]), int(parts["port"]), TLSOptions.client())
	if error != OK:
		_client = null
		return Result.failure(Contract.MODEL_TRANSPORT_ERROR)
	_state = State.CONNECTING
	if _host != null:
		_host.add_child(self)
	set_process(true)
	return Result.success()

func cancel() -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	if _client != null:
		_client.close()
		_client = null
	_release()

func _process(_delta: float) -> void:
	if _state == State.FINISHED or _client == null:
		return
	var error := _client.poll()
	if error != OK:
		_fail()
		return
	match _client.get_status():
		HTTPClient.STATUS_CONNECTED:
			if _state == State.CONNECTING:
				var request_error := _client.request(HTTPClient.METHOD_POST, _path, _headers, _body)
				if request_error != OK:
					_fail()
					return
				_state = State.REQUESTING
		HTTPClient.STATUS_BODY:
			if not _status_emitted:
				_status_emitted = true
				_status_code = _client.get_response_code()
				response_started.emit(_status_code)
			_state = State.READING
			_read_body()
		HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, \
				HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_fail()
		HTTPClient.STATUS_DISCONNECTED:
			_finish()

func _read_body() -> void:
	while _state == State.READING and _client != null:
		if _client.get_status() != HTTPClient.STATUS_BODY or not _client.has_response():
			break
		var chunk := _client.read_response_body_chunk()
		if chunk.is_empty():
			break
		body_chunk.emit(chunk)
	if _client != null and _client.get_status() != HTTPClient.STATUS_BODY:
		_finish()

func _finish() -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	if _client != null:
		_client.close()
		_client = null
	response_finished.emit(_status_code)
	_release()

func _fail() -> void:
	if _state == State.FINISHED:
		return
	_state = State.FINISHED
	if _client != null:
		_client.close()
		_client = null
	transport_failed.emit(Contract.MODEL_TRANSPORT_ERROR)
	_release()

func _release() -> void:
	set_process(false)
	if not is_queued_for_deletion():
		queue_free()
