extends RefCounted
## UI-facing command facade. The API key is forwarded once to the injected adapter and is
## never stored, returned, logged or included in diagnostics by this service.

const Result = preload("res://shared/result.gd")
const Configuration = preload("res://application/ports/model_configuration.gd")

signal changed(summary: Dictionary)

var _configuration: Configuration

func _init(configuration: Configuration) -> void:
	_configuration = configuration

func configure(endpoint_url: String, model: String, api_key: String) -> RefCounted:
	if endpoint_url.length() > 2048 or model.length() > 128 or api_key.length() > 512:
		return Result.failure("MODEL_CONFIG_INVALID")
	var result: RefCounted = _configuration.configure(endpoint_url, model, api_key)
	if result.ok:
		changed.emit(_configuration.diagnostics().duplicate(true))
	return result

func clear() -> void:
	_configuration.clear()
	changed.emit(_configuration.diagnostics().duplicate(true))

func diagnostics() -> Dictionary:
	return _configuration.diagnostics().duplicate(true)
