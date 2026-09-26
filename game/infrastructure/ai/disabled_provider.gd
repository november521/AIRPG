extends "res://application/ports/model_provider.gd"
## Default composition is offline and fail-closed, never fabricates a story response.
const TransportContract = preload("res://application/contracts/model_transport_contract.gd")

func start(_request_id: String, _filtered_context: Dictionary) -> RefCounted:
	return Result.failure(TransportContract.AI_NOT_CONFIGURED)
