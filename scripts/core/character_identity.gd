class_name CharacterIdentity
extends RefCounted

const LOCAL_PRIMARY: StringName = &"local.character.primary"


static func is_valid(character_id: StringName) -> bool:
	var text := String(character_id)
	if text.is_empty() or text != text.strip_edges() or text != text.to_lower():
		return false

	for invalid_fragment: String in [" ", "\t", "\n", "/", "\\"]:
		if text.contains(invalid_fragment):
			return false

	return true
