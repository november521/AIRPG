extends RefCounted
## G1 aggregate suite. The integration owner registers this in tests/run_tests.gd;
## this branch runs it through tests/g1/run_g1_tests.gd.

const ConfigSuite = preload("res://tests/g1/test_g1_config_credentials.gd")
const ParserSuite = preload("res://tests/g1/test_g1_sse_parser.gd")
const StreamSuite = preload("res://tests/g1/test_g1_provider_stream.gd")
const LifecycleSuite = preload("res://tests/g1/test_g1_provider_lifecycle.gd")

func run(check: Callable) -> void:
	ConfigSuite.new().run(check)
	ParserSuite.new().run(check)
	StreamSuite.new().run(check)
	LifecycleSuite.new().run(check)
