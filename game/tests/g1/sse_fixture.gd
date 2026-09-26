extends RefCounted
## Loads offline SSE recording fixtures from JSON. JSON escapes keep the stream byte-exact
## (CRLF preserved); "chunk_size" slices the UTF-8 byte stream at fixed boundaries so
## multi-byte characters are split across transport chunks on purpose. Test-only helper.

static func load_chunks(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return []
	var data: Dictionary = json.data
	if typeof(data.get("text")) != TYPE_STRING:
		return []
	var bytes: PackedByteArray = String(data["text"]).to_utf8_buffer()
	var chunk_size := 0
	var raw_size: Variant = data.get("chunk_size")
	if (typeof(raw_size) == TYPE_INT or typeof(raw_size) == TYPE_FLOAT) \
			and is_finite(float(raw_size)):
		chunk_size = int(raw_size)
	var chunks: Array = []
	if chunk_size <= 0:
		chunks.append(bytes)
		return chunks
	var offset := 0
	while offset < bytes.size():
		var end := mini(offset + chunk_size, bytes.size())
		chunks.append(bytes.slice(offset, end))
		offset = end
	return chunks

static func load_bytes(path: String) -> PackedByteArray:
	var combined := PackedByteArray()
	for chunk: Variant in load_chunks(path):
		combined.append_array(chunk)
	return combined
