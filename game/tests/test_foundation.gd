extends RefCounted
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Validator = preload("res://domain/content/content_validator.gd")
const Schema = preload("res://shared/schema_validator.gd")
const Conditions = preload("res://domain/story/conditions.gd")
const State = preload("res://domain/story/state_store.gd")
const RandomSource = preload("res://infrastructure/random/godot_random_source.gd")
const MemorySaves = preload("res://infrastructure/persistence/memory_save_repository.gd")
const DisabledModel = preload("res://infrastructure/ai/disabled_provider.gd")
const ModelPort = preload("res://application/ports/model_provider.gd")
const SavePort = preload("res://application/ports/save_repository.gd")
const RandomPort = preload("res://application/ports/random_source.gd")
const Composition = preload("res://bootstrap/composition.gd")
const Keyboard = preload("res://infrastructure/input/keyboard_input.gd")

func run(check: Callable) -> void:
	_content(check)
	_state(check)
	_random(check)
	_ports(check)
	_boot(check)

func _fixture() -> Dictionary:
	# Synthetic metadata only; never shipped as a story or presented to the player.
	return {"schema_version": 1, "pack_id": "test.pack", "content_version": "1",
		"locale": "zh_CN", "flags": {"test.open": false}, "localization": {"test.title": "测试"},
		"definitions": [{"id": "test.scene", "kind": "scene", "text_key": "test.title",
			"references": [], "conditions": [{"flag": "test.open", "equals": true}]}]}

func _content(check: Callable) -> void:
	var schema: Dictionary = JsonFile.read("res://data/schemas/content_pack.schema.json").value
	var valid := _fixture()
	check.call(Validator.validate(valid, schema).ok, "valid catalog accepted")
	var bad := valid.duplicate(true)
	bad.definitions.append(bad.definitions[0].duplicate(true))
	check.call(not Validator.validate(bad, schema).ok, "duplicate ID rejected")
	bad = valid.duplicate(true)
	bad.definitions[0].references = ["test.missing"]
	check.call(not Validator.validate(bad, schema).ok, "missing reference rejected")
	bad = valid.duplicate(true)
	bad.localization.clear()
	check.call(not Validator.validate(bad, schema).ok, "missing localization rejected")
	bad = valid.duplicate(true)
	bad.definitions[0].conditions[0].flag = "test.unknown"
	check.call(not Validator.validate(bad, schema).ok, "unknown condition flag rejected")
	bad = valid.duplicate(true)
	bad.definitions[0].conditions[0].equals = "true"
	check.call(not Validator.validate(bad, schema).ok, "condition type not coerced")
	bad = valid.duplicate(true)
	bad.definitions[0].script = "arbitrary"
	check.call(not Validator.validate(bad, schema).ok, "unrecognized field rejected")
	bad = valid.duplicate(true)
	bad.schema_version = 2
	check.call(not Validator.validate(bad, schema).ok, "future schema rejected")
	bad = valid.duplicate(true)
	bad.schema_version = 1.5
	check.call(not Validator.validate(bad, schema).ok, "fractional schema rejected")
	bad = valid.duplicate(true)
	bad.definitions = [17]
	check.call(not Validator.validate(bad, schema).ok, "malformed entry handled without crash")
	check.call(not Validator.validate(null, schema).ok, "null content rejected")
	check.call(not Schema.validate({}, {"allOf": []}).is_empty(), "unsupported schema fails closed")
	check.call(not Schema.validate({}, {"properties": {"unused": {"allOf": []}}}).is_empty(), "unsupported keyword in absent optional field rejected")
	check.call(not JsonFile.read("res://tests/not_present.json").ok, "missing JSON file handled")
	var parsed: Variant = JSON.parse_string(JSON.stringify(valid))
	check.call(Validator.validate(parsed, schema).ok, "JSON numeric round trip supported")
	var validated := Validator.validate(valid, schema)
	validated.value.flags["test.open"] = true
	check.call(not valid.flags["test.open"], "validated data does not alias caller")
	check.call(Conditions.matches([], {}), "empty conjunction allowed")
	check.call(Conditions.matches(valid.definitions[0].conditions, {"test.open": true}), "declared condition passes")
	check.call(not Conditions.matches(valid.definitions[0].conditions, {}), "missing flag fails closed")
	check.call(not Conditions.matches([{"flag": "x", "equals": false, "op": "evil"}], {"x": false}), "unknown operator fails closed")
	check.call(not Conditions.matches([null], {}), "malformed condition fails closed")

func _state(check: Callable) -> void:
	var store := State.new()
	check.call(not store.commit(0, {"a": true}).ok, "unconfigured store denies commit")
	check.call(not store.configure({"a": "false"}).ok, "bad defaults denied")
	var defaults := {"a": false, "b": false}
	check.call(store.configure(defaults).ok, "valid defaults accepted")
	defaults.a = true
	check.call(not store.snapshot().flags.a, "defaults copied")
	check.call(not store.configure({}).ok, "double configuration denied")
	var external := store.snapshot()
	external.flags.a = true
	check.call(not store.snapshot().flags.a, "snapshot mutation isolated")
	var before := store.snapshot()
	check.call(not store.commit(0, {"a": true, "unknown": true}).ok, "mixed invalid patch denied")
	check.call(store.snapshot() == before, "invalid patch has no partial effects")
	check.call(not store.commit(0, {}).ok, "empty patch denied")
	var committed := store.commit(0, {"a": true})
	check.call(committed.ok and store.snapshot().revision == 1, "commit increments revision once")
	committed.value.flags.a = false
	check.call(store.snapshot().flags.a, "commit return value isolated")
	check.call(not store.commit(0, {"b": true}).ok, "late async result rejected by revision")
	check.call(not store.snapshot().flags.b and store.snapshot().revision == 1, "stale response cannot mutate state")

func _random(check: Callable) -> void:
	var first := RandomSource.new(1920)
	var second := RandomSource.new(1920)
	var same := true
	for index: int in 32:
		same = same and first.roll(100).value == second.roll(100).value
	check.call(same, "fixed seeds reproduce 32 draws")
	var checkpoint: Dictionary = JSON.parse_string(JSON.stringify(first.capture()))
	var expected: Array = []
	for index: int in 16:
		expected.append(first.roll(100).value)
	check.call(second.restore(checkpoint).ok, "checkpoint survives JSON round trip")
	var actual: Array = []
	for index: int in 16:
		actual.append(second.roll(100).value)
	check.call(actual == expected, "checkpoint restores next 16 draws")
	var before := first.capture()
	check.call(not first.roll(1).ok and first.capture() == before, "invalid die does not consume RNG")
	check.call(not first.restore({"algorithm": "other", "seed": "0", "state": "0"}).ok, "different algorithm rejected")
	check.call(not first.restore({"algorithm": "godot-4.7.2-pcg", "seed": "0", "state": "99999999999999999999999"}).ok, "overflow checkpoint rejected")
	check.call(first.capture() == before, "invalid restoration leaves RNG unchanged")

func _ports(check: Callable) -> void:
	check.call(not ModelPort.new().start("r1", {}).ok, "base model port fails closed")
	check.call(DisabledModel.new().start("r1", {}).code == "AI_NOT_CONFIGURED", "disabled model does not fabricate text")
	check.call(not SavePort.new().read_snapshot("slot").ok, "base save port fails closed")
	check.call(not RandomPort.new().roll(100).ok, "base RNG port fails closed")
	var saves := MemorySaves.new()
	var original := {"schema_version": 1, "state": {"flags": {"a": false}}}
	check.call(not saves.read_snapshot("missing").ok, "missing save handled")
	check.call(saves.write_snapshot("test", original).ok, "memory adapter accepts snapshot")
	original.state.flags.a = true
	var loaded := saves.read_snapshot("test")
	check.call(not loaded.value.state.flags.a, "save input isolated")
	loaded.value.state.flags.a = true
	check.call(not saves.read_snapshot("test").value.state.flags.a, "save output isolated")

func _boot(check: Callable) -> void:
	var boot := Composition.build()
	check.call(boot.ok, "real content/config compose successfully")
	check.call(boot.value.session.read_state().revision == 0, "boot exposes read facade")
	check.call(not Composition.build("res://tests/missing.json").ok, "missing config stops boot")
	check.call(Keyboard.configure(boot.value.config.input_bindings).ok, "configured inputs accepted")
	check.call(InputMap.has_action("move_left") and InputMap.has_action("investigate"), "input actions registered")
	var events := InputMap.action_get_events("move_left")
	check.call(not Keyboard.configure({"move_left": "D", "invalid": "not-a-key"}).ok, "unknown keyboard name rejected")
	check.call(InputMap.action_get_events("move_left")[0].physical_keycode == events[0].physical_keycode, "invalid binding update is atomic")
