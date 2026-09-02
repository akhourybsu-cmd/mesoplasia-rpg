class_name CadenResourceService
extends RefCounted

const SNAPSHOT_SCHEMA_VERSION := 1
const DEFAULT_WORLD_ID := "world.caden.private"

var _registry: RefCounted
var _persistence_coordinator: RefCounted
var _world_id := ""


func configure(
	registry: RefCounted,
	persistence_coordinator: RefCounted,
	world_id: String = DEFAULT_WORLD_ID
) -> bool:
	if (
		registry == null
		or persistence_coordinator == null
		or _registry != null
		or not registry.call("is_valid")
		or not _stable_id(world_id)
	):
		return false
	_registry = registry
	_persistence_coordinator = persistence_coordinator
	_world_id = world_id
	return true


func request_deposit(
	character_id: String,
	deposit_id: String,
	resource_id: String,
	quantity: int,
	expected_inventory_revision: int,
	expected_world_revision: int
) -> Dictionary:
	if _registry == null:
		return _rejected("NOT_CONFIGURED", "Caden resource service is not configured.")
	if not _stable_id(character_id) or not _stable_id(deposit_id):
		return _rejected("INVALID_DEPOSIT_IDENTITY", "Deposit identity is invalid.")
	if not _registry.call("has_resource", resource_id):
		return _rejected("UNKNOWN_RESOURCE", "Resource is not registered for Caden deposits.")
	var resource := _registry.call("get_resource", resource_id) as Dictionary
	if quantity < 1 or quantity > int(resource.maximum_deposit_quantity):
		return _rejected("INVALID_QUANTITY", "Deposit quantity is outside the allowed range.")
	var inventories := _persistence_coordinator.call("get_repository", "inventories") as RefCounted
	var worlds := _persistence_coordinator.call("get_repository", "worlds") as RefCounted
	var outcomes := _persistence_coordinator.call("get_repository", "outcomes") as RefCounted
	if inventories == null or worlds == null or outcomes == null:
		return _rejected("PERSISTENCE_UNAVAILABLE", "Required repositories are unavailable.")
	var existing := outcomes.call("load", deposit_id) as Dictionary
	if not existing.get("accepted", false):
		return _with_reason(existing)
	if existing.get("found", false):
		var replay_payload := ((existing.record as Dictionary).payload as Dictionary).duplicate(true)
		if (
			replay_payload.get("outcome_type", "") != "CADEN_RESOURCE_DEPOSIT"
			or replay_payload.get("character_id", "") != character_id
			or replay_payload.get("resource_id", "") != resource_id
			or int(replay_payload.get("quantity", 0)) != quantity
		):
			return _rejected("DEPOSIT_ID_CONFLICT", "Deposit ID was already used for another request.")
		replay_payload.accepted = true
		replay_payload.reason_code = "OK"
		replay_payload.reason_text = "Deposit result replayed without another mutation."
		replay_payload.replayed = true
		return replay_payload
	var inventory_loaded := inventories.call("load", character_id) as Dictionary
	var world_loaded := worlds.call("load", _world_id) as Dictionary
	if not inventory_loaded.get("accepted", false) or not inventory_loaded.get("found", false):
		return _rejected("INVENTORY_NOT_FOUND", "Character inventory is unavailable.")
	if not world_loaded.get("accepted", false) or not world_loaded.get("found", false):
		return _rejected("WORLD_NOT_FOUND", "Caden world record is unavailable.")
	var inventory_record := inventory_loaded.record as Dictionary
	var world_record := world_loaded.record as Dictionary
	if expected_inventory_revision >= 0 and int(inventory_record.record_revision) != expected_inventory_revision:
		return _rejected("STALE_INVENTORY_REVISION", "Inventory revision is stale.")
	if expected_world_revision >= 0 and int(world_record.record_revision) != expected_world_revision:
		return _rejected("STALE_WORLD_REVISION", "World revision is stale.")
	var inventory_payload := inventory_record.payload as Dictionary
	if int((inventory_payload.get("stacks", {}) as Dictionary).get(resource_id, 0)) < quantity:
		return _rejected("INSUFFICIENT_RESOURCE", "Character does not hold that deposit quantity.")
	var projected_stockpiles := ((world_record.payload as Dictionary).get("stockpiles", {}) as Dictionary).duplicate(true)
	projected_stockpiles[resource_id] = int(projected_stockpiles.get(resource_id, 0)) + quantity
	var projected_projects := ((world_record.payload as Dictionary).get("projects", {}) as Dictionary).duplicate(true)
	var changed_project_ids: Array[String] = []
	for project_id: String in _registry.call("get_project_ids") as Array[String]:
		var definition := _registry.call("get_project", project_id) as Dictionary
		var current := projected_projects.get(
			project_id, {"state": definition.initial_state}
		) as Dictionary
		var previous_state := current.get("state", definition.initial_state) as String
		var next_state := previous_state
		if previous_state != definition.funded_state and _requirements_met(
			definition.required_resources, projected_stockpiles
		):
			next_state = definition.funded_state
		if next_state != previous_state:
			changed_project_ids.append(project_id)
		projected_projects[project_id] = {"state": next_state}
	var result := _persistence_coordinator.call(
		"commit_caden_resource_deposit",
		deposit_id,
		character_id,
		_world_id,
		resource_id,
		quantity,
		expected_inventory_revision,
		expected_world_revision,
		projected_projects,
		changed_project_ids
	) as Dictionary
	return _with_reason(result)


func get_snapshot_for(character_id: String) -> Dictionary:
	if _registry == null or not _stable_id(character_id):
		return {}
	var inventories := _persistence_coordinator.call("get_repository", "inventories") as RefCounted
	var worlds := _persistence_coordinator.call("get_repository", "worlds") as RefCounted
	var inventory_loaded := inventories.call("load", character_id) as Dictionary
	var world_loaded := worlds.call("load", _world_id) as Dictionary
	if not inventory_loaded.get("found", false) or not world_loaded.get("found", false):
		return {}
	var inventory_record := inventory_loaded.record as Dictionary
	var world_record := world_loaded.record as Dictionary
	var inventory_payload := inventory_record.payload as Dictionary
	var world_payload := world_record.payload as Dictionary
	var stacks := inventory_payload.get("stacks", {}) as Dictionary
	var stockpiles := world_payload.get("stockpiles", {}) as Dictionary
	var persisted_projects := world_payload.get("projects", {}) as Dictionary
	var inventory_resources: Array = []
	var stockpile_resources: Array = []
	for resource_id: String in _registry.call("get_resource_ids") as Array[String]:
		inventory_resources.append([resource_id, int(stacks.get(resource_id, 0))])
		stockpile_resources.append([resource_id, int(stockpiles.get(resource_id, 0))])
	var projects: Array = []
	for project_id: String in _registry.call("get_project_ids") as Array[String]:
		var definition := _registry.call("get_project", project_id) as Dictionary
		var state_record := persisted_projects.get(
			project_id, {"state": definition.initial_state}
		) as Dictionary
		var required_total := 0
		var deposited_total := 0
		for resource_id_value: Variant in definition.required_resources:
			var resource_id := resource_id_value as String
			var required := int(definition.required_resources[resource_id])
			required_total += required
			deposited_total += mini(required, int(stockpiles.get(resource_id, 0)))
		projects.append(
			[project_id, state_record.get("state", definition.initial_state), deposited_total, required_total]
		)
	var inventory_revision := int(inventory_record.record_revision)
	var world_revision := int(world_record.record_revision)
	return {
		"resource_snapshot_schema_version": SNAPSHOT_SCHEMA_VERSION,
		"projection_revision": world_revision * 100000 + inventory_revision,
		"world_id": _world_id,
		"world_record_revision": world_revision,
		"inventory_record_revision": inventory_revision,
		"inventory_resources": inventory_resources,
		"stockpiles": stockpile_resources,
		"projects": projects,
	}


func _requirements_met(requirements: Dictionary, stockpiles: Dictionary) -> bool:
	for resource_id: Variant in requirements:
		if int(stockpiles.get(resource_id, 0)) < int(requirements[resource_id]):
			return false
	return true


func _with_reason(result: Dictionary) -> Dictionary:
	var normalized := result.duplicate(true)
	if not normalized.has("reason_text"):
		normalized.reason_text = (
			"Caden resource deposit committed."
			if normalized.get("accepted", false)
			else "Caden resource deposit was rejected: %s." % normalized.get("reason_code", "UNKNOWN")
		)
	return normalized


func _rejected(reason_code: String, reason_text: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "reason_text": reason_text}


func _stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 95]
		):
			return false
	return true
