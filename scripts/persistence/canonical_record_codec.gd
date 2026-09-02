class_name CanonicalRecordCodec
extends RefCounted


static func stringify(value: Variant) -> String:
	return JSON.stringify(_normalize_json_numbers(value), "", true, true)


static func checksum(value: Dictionary) -> String:
	var unsigned := value.duplicate(true)
	unsigned.erase("checksum")
	return stringify(unsigned).sha256_text()


static func sign_record(value: Dictionary) -> Dictionary:
	var signed := value.duplicate(true)
	signed["checksum"] = checksum(signed)
	return signed


static func validate_checksum(value: Dictionary) -> bool:
	var expected := value.get("checksum", "") as String
	return not expected.is_empty() and expected == checksum(value)


static func parse(text: String) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed as Dictionary if parsed is Dictionary else {}


static func _normalize_json_numbers(value: Variant) -> Variant:
	if value is int:
		return float(value)
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_normalize_json_numbers(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(first: Variant, second: Variant) -> bool: return str(first) < str(second))
		for key: Variant in keys:
			result[key] = _normalize_json_numbers((value as Dictionary)[key])
		return result
	return value
