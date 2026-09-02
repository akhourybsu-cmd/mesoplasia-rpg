class_name PersistentIdentityResolver
extends RefCounted

const Protocol := preload("res://scripts/network/protocol/network_protocol_contract.gd")

const WORLD_ID := "world.caden.private"

var _persistence_coordinator: RefCounted


func configure(persistence_coordinator: RefCounted) -> bool:
	if persistence_coordinator == null or _persistence_coordinator != null:
		return false
	_persistence_coordinator = persistence_coordinator
	return true


func resolve_identity(display_label: String) -> Dictionary:
	if _persistence_coordinator == null:
		return {}
	var sanitized := Protocol.sanitize_display_label(display_label)
	if sanitized.is_empty():
		return {}
	var stable_hash := sanitized.to_lower().sha256_text().left(20)
	var account_id := "account.%s" % stable_hash
	var character_id := "character.%s" % stable_hash
	var world_result := _persistence_coordinator.call("ensure_world", WORLD_ID) as Dictionary
	if not world_result.get("accepted", false):
		return {}
	var player_result := _persistence_coordinator.call(
		"initialize_player", account_id, character_id, sanitized
	) as Dictionary
	if not player_result.get("accepted", false):
		return {}
	return {
		"account_id": account_id,
		"character_id": character_id,
		"display_label": sanitized,
	}
