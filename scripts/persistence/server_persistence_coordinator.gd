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
				"payload": {"flags": {}, "unlocks": [], "stockpiles": {}, "projects": {}},
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


func ensure_world(world_id: String) -> Dictionary:
	if _backend == null or world_id.is_empty():
		return _rejected("NOT_CONFIGURED")
	var worlds := _repositories.worlds as RefCounted
	var loaded := worlds.call("load", world_id) as Dictionary
	if not loaded.get("accepted", false):
		return loaded
	if loaded.get("found", false):
		return {"accepted": true, "reason_code": "OK", "replayed": true}
	return worlds.call(
		"store",
		world_id,
		{"flags": {}, "unlocks": [], "stockpiles": {}, "projects": {}},
		-1,
		"bootstrap.world.%s" % world_id
	) as Dictionary


func initialize_player(account_id: String, character_id: String, display_label: String) -> Dictionary:
	if _backend == null:
		return _rejected("NOT_CONFIGURED")
	return _backend.call(
		"commit_transaction",
		"bootstrap.player.%s" % character_id,
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


func commit_caden_resource_deposit(
	deposit_id: String,
	character_id: String,
	world_id: String,
	resource_id: String,
	quantity: int,
	expected_inventory_revision: int,
	expected_world_revision: int,
	project_states: Dictionary,
	changed_project_ids: Array
) -> Dictionary:
	if _backend == null or quantity < 1 or quantity > 9999:
		return _rejected("INVALID_DEPOSIT")
	var outcomes := _repositories.outcomes as RefCounted
	var existing := outcomes.call("load", deposit_id) as Dictionary
	if not existing.get("accepted", false):
		return existing
	if existing.get("found", false):
		var original := ((existing.record as Dictionary).payload as Dictionary).duplicate(true)
		if (
			original.get("outcome_type", "") != "CADEN_RESOURCE_DEPOSIT"
			or original.get("character_id", "") != character_id
			or original.get("resource_id", "") != resource_id
			or int(original.get("quantity", 0)) != quantity
		):
			return _rejected("DEPOSIT_ID_CONFLICT")
		original.accepted = true
		original.reason_code = "OK"
		original.replayed = true
		return original
	var inventories := _repositories.inventories as RefCounted
	var worlds := _repositories.worlds as RefCounted
	var inventory_result := inventories.call("load", character_id) as Dictionary
	var world_result := worlds.call("load", world_id) as Dictionary
	if not inventory_result.get("accepted", false) or not inventory_result.get("found", false):
		return _rejected("INVENTORY_NOT_FOUND")
	if not world_result.get("accepted", false) or not world_result.get("found", false):
		return _rejected("WORLD_NOT_FOUND")
	var inventory_record := inventory_result.record as Dictionary
	var world_record := world_result.record as Dictionary
	var inventory_revision := int(inventory_record.record_revision)
	var world_revision := int(world_record.record_revision)
	if expected_inventory_revision >= 0 and inventory_revision != expected_inventory_revision:
		return _rejected("STALE_INVENTORY_REVISION")
	if expected_world_revision >= 0 and world_revision != expected_world_revision:
		return _rejected("STALE_WORLD_REVISION")
	var inventory := (inventory_record.payload as Dictionary).duplicate(true)
	var stacks := (inventory.get("stacks", {}) as Dictionary).duplicate(true)
	var current_quantity := int(stacks.get(resource_id, 0))
	if current_quantity < quantity:
		return _rejected("INSUFFICIENT_RESOURCE")
	stacks[resource_id] = current_quantity - quantity
	inventory.stacks = stacks
	var watermarks := (inventory.get("transaction_watermarks", []) as Array).duplicate()
	watermarks.append(deposit_id)
	inventory.transaction_watermarks = watermarks
	var world := (world_record.payload as Dictionary).duplicate(true)
	var stockpiles := (world.get("stockpiles", {}) as Dictionary).duplicate(true)
	stockpiles[resource_id] = int(stockpiles.get(resource_id, 0)) + quantity
	world.stockpiles = stockpiles
	world.projects = project_states.duplicate(true)
	var outcome_payload := {
		"outcome_type": "CADEN_RESOURCE_DEPOSIT",
		"deposit_id": deposit_id,
		"character_id": character_id,
		"world_id": world_id,
		"resource_id": resource_id,
		"quantity": quantity,
		"resulting_inventory_quantity": int(stacks[resource_id]),
		"resulting_stockpile_quantity": int(stockpiles[resource_id]),
		"inventory_record_revision": inventory_revision + 1,
		"world_record_revision": world_revision + 1,
		"project_states": project_states.duplicate(true),
		"changed_project_ids": changed_project_ids.duplicate(),
		"settlement_state": "COMMITTED",
	}
	var transaction := _backend.call(
		"commit_transaction",
		"caden.deposit.%s" % deposit_id,
		[
			{
				"category": "inventories",
				"record_id": character_id,
				"expected_revision": inventory_revision,
				"payload": inventory,
			},
			{
				"category": "worlds",
				"record_id": world_id,
				"expected_revision": world_revision,
				"payload": world,
			},
			{
				"category": "outcomes",
				"record_id": deposit_id,
				"expected_revision": -1,
				"payload": outcome_payload,
			},
		]
	) as Dictionary
	if not transaction.get("accepted", false):
		return transaction
	var result := outcome_payload.duplicate(true)
	result.accepted = true
	result.reason_code = "OK"
	result.replayed = false
	return result


func get_repository(category: String) -> RefCounted:
	return _repositories.get(category) as RefCounted


func get_backend() -> RefCounted:
	return _backend


func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code}
