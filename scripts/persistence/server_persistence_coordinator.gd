class_name ServerPersistenceCoordinator
extends RefCounted

const Repository := preload("res://scripts/persistence/file_record_repository.gd")

var _backend: RefCounted
var _repositories: Dictionary = {}


func configure(backend: RefCounted) -> bool:
	if backend == null or _backend != null or not backend.call("is_ready"):
		return false
	_backend = backend
	for category: String in backend.RECORD_CATEGORIES:
		var repository := Repository.new()
		if not repository.configure(backend, category):
			return false
		_repositories[category] = repository
	return true


func initialize_fresh_server(
	account_id: String,
	character_id: String,
	world_id: String,
	display_label: String
) -> Dictionary:
	if _backend == null:
		return _rejected("NOT_CONFIGURED")
	return _backend.call(
		"commit_transaction",
		"bootstrap.%s.%s" % [world_id, character_id],
		[
			{
				"category": "profiles",
				"record_id": account_id,
				"expected_revision": -1,
				"payload": {"display_label": display_label, "character_ids": [character_id]},
			},
			{
				"category": "characters",
				"record_id": character_id,
				"expected_revision": -1,
				"payload": {"owner_account_id": account_id, "safe_zone_id": "wayfarers_approach"},
			},
			{
				"category": "worlds",
				"record_id": world_id,
				"expected_revision": -1,
				"payload": {"flags": {}, "unlocks": []},
			},
			{
				"category": "inventories",
				"record_id": character_id,
				"expected_revision": -1,
				"payload": {"stacks": {}, "equipment": {}, "transaction_watermarks": []},
			},
			{
				"category": "quests",
				"record_id": character_id,
				"expected_revision": -1,
				"payload": {"progress": {}, "reward_watermarks": []},
			},
		]
	) as Dictionary


func grant_personal_reward(
	entitlement_id: String,
	character_id: String,
	item_definition_id: String,
	quantity: int
) -> Dictionary:
	if _backend == null or quantity < 1 or quantity > 9999:
		return _rejected("INVALID_REWARD")
	var outcomes := _repositories.outcomes as RefCounted
	var existing := outcomes.call("load", entitlement_id) as Dictionary
	if not existing.get("accepted", false):
		return existing
	if existing.get("found", false):
		var original := ((existing.record as Dictionary).payload as Dictionary).duplicate(true)
		original["accepted"] = true
		original["reason_code"] = "OK"
		original["replayed"] = true
		return original
	var inventories := _repositories.inventories as RefCounted
	var inventory_result := inventories.call("load", character_id) as Dictionary
	if not inventory_result.get("accepted", false) or not inventory_result.get("found", false):
		return _rejected("INVENTORY_NOT_FOUND")
	var inventory_record := inventory_result.record as Dictionary
	var inventory := (inventory_record.payload as Dictionary).duplicate(true)
	var stacks := (inventory.get("stacks", {}) as Dictionary).duplicate(true)
	stacks[item_definition_id] = int(stacks.get(item_definition_id, 0)) + quantity
	inventory.stacks = stacks
	var watermarks := (inventory.get("transaction_watermarks", []) as Array).duplicate()
	watermarks.append(entitlement_id)
	inventory.transaction_watermarks = watermarks
	var outcome_payload := {
		"entitlement_id": entitlement_id,
		"character_id": character_id,
		"item_definition_id": item_definition_id,
		"quantity": quantity,
		"resulting_quantity": int(stacks[item_definition_id]),
		"settlement_state": "COMMITTED",
	}
	var transaction := _backend.call(
		"commit_transaction",
		"reward.%s" % entitlement_id,
		[
			{
				"category": "inventories",
				"record_id": character_id,
				"expected_revision": int(inventory_record.record_revision),
				"payload": inventory,
			},
			{
				"category": "outcomes",
				"record_id": entitlement_id,
				"expected_revision": -1,
				"payload": outcome_payload,
			},
		]
	) as Dictionary
	if not transaction.get("accepted", false):
		return transaction
	var result := outcome_payload.duplicate(true)
	result["accepted"] = true
	result["reason_code"] = "OK"
	result["replayed"] = false
	return result


func get_repository(category: String) -> RefCounted:
	return _repositories.get(category) as RefCounted


func get_backend() -> RefCounted:
	return _backend


func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
