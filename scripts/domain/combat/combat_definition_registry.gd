class_name CombatDefinitionRegistry
extends RefCounted

const DEFAULT_DEFINITION_PATH := "res://data/combat/development_combat_definitions.json"
const VALID_TARGET_RULES := ["SELF", "ALLY", "ENEMY"]
const VALID_EFFECT_TYPES := ["DAMAGE", "HEAL", "APPLY_STATUS"]
const VALID_STATUS_EFFECTS := ["INCOMING_DAMAGE_REDUCTION", "DAMAGE_OVER_TIME"]

var _abilities: Dictionary = {}
var _statuses: Dictionary = {}
var _templates: Dictionary = {}
var _validation_errors: Array[String] = []


func _init(definition_path: String = DEFAULT_DEFINITION_PATH) -> void:
	_load_definition_file(definition_path)


func is_valid() -> bool:
	return _validation_errors.is_empty()


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func has_ability(ability_id: String) -> bool:
	return _abilities.has(ability_id)


func get_ability(ability_id: String) -> Dictionary:
	return (_abilities.get(ability_id, {}) as Dictionary).duplicate(true)


func get_status(status_id: String) -> Dictionary:
	return (_statuses.get(status_id, {}) as Dictionary).duplicate(true)


func get_template(template_id: String) -> Dictionary:
	return (_templates.get(template_id, {}) as Dictionary).duplicate(true)


func get_ability_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_abilities.keys())
	result.sort()
	return result


func get_status_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_statuses.keys())
	result.sort()
	return result


func get_template_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_templates.keys())
	result.sort()
	return result


func instantiate_combatant(
	template_id: String,
	combatant_id: String,
	controller_id: String = ""
) -> Dictionary:
	var template := get_template(template_id)
	if template.is_empty() or combatant_id.is_empty():
		return {}
	return {
		"combatant_id": combatant_id,
		"template_id": template_id,
		"display_name": template.display_name,
		"team_id": template.team_id,
		"controller_id": controller_id,
		"ai_controlled": template.ai_controlled,
		"connected": true,
		"max_health": template.max_health,
		"health": template.max_health,
		"max_resource": template.max_resource,
		"resource": template.max_resource,
		"speed": template.speed,
		"ability_ids": template.ability_ids.duplicate(),
		"cooldowns": {},
		"statuses": [],
		"alive": true,
		"position": {"model": "TARGET_BASED", "slot": "targetable"},
	}


func _load_definition_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		_validation_errors.append("Definition file does not exist: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_validation_errors.append("Definition file could not be opened: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_validation_errors.append("Definition root must be a dictionary.")
		return
	var root := parsed as Dictionary
	if int(root.get("schema_version", 0)) != 1:
		_validation_errors.append("Unsupported combat definition schema version.")
		return
	_register_statuses(root.get("statuses", []) as Array)
	_register_abilities(root.get("abilities", []) as Array)
	_register_templates(root.get("combatant_templates", []) as Array)


func _register_statuses(rows: Array) -> void:
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		var status_id := row.get("status_id", "") as String
		if not _valid_definition_id(status_id) or _statuses.has(status_id):
			_validation_errors.append("Invalid or duplicate status ID: %s" % status_id)
			continue
		if row.get("timing_hook", "") != "TURN_START":
			_validation_errors.append("Unsupported status timing hook: %s" % status_id)
		if row.get("effect_type", "") not in VALID_STATUS_EFFECTS:
			_validation_errors.append("Unsupported status effect: %s" % status_id)
		_statuses[status_id] = row.duplicate(true)


func _register_abilities(rows: Array) -> void:
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		var ability_id := row.get("ability_id", "") as String
		if not _valid_definition_id(ability_id) or _abilities.has(ability_id):
			_validation_errors.append("Invalid or duplicate ability ID: %s" % ability_id)
			continue
		if row.get("target_rule", "") not in VALID_TARGET_RULES:
			_validation_errors.append("Unsupported target rule: %s" % ability_id)
		if int(row.get("resource_cost", -1)) < 0 or int(row.get("cooldown_turns", -1)) < 0:
			_validation_errors.append("Ability cost/cooldown must be non-negative: %s" % ability_id)
		var effects := row.get("effects", []) as Array
		if effects.is_empty():
			_validation_errors.append("Ability has no effects: %s" % ability_id)
		for effect_value: Variant in effects:
			var effect := effect_value as Dictionary
			if effect.get("effect_type", "") not in VALID_EFFECT_TYPES:
				_validation_errors.append("Unsupported effect in ability: %s" % ability_id)
			if int(effect.get("amount", 0)) < 0 or int(effect.get("variance", 0)) < 0:
				_validation_errors.append("Negative effect amount/variance: %s" % ability_id)
			if effect.get("effect_type", "") == "APPLY_STATUS":
				var status_id := effect.get("status_id", "") as String
				if not _statuses.has(status_id):
					_validation_errors.append("Ability references unknown status: %s" % status_id)
				if int(effect.get("duration_turns", 0)) <= 0:
					_validation_errors.append("Status duration must be positive: %s" % ability_id)
		_abilities[ability_id] = row.duplicate(true)


func _register_templates(rows: Array) -> void:
	for row_value: Variant in rows:
		var row := row_value as Dictionary
		var template_id := row.get("template_id", "") as String
		if not _valid_definition_id(template_id) or _templates.has(template_id):
			_validation_errors.append("Invalid or duplicate combatant template ID: %s" % template_id)
			continue
		if (
			int(row.get("max_health", 0)) <= 0
			or int(row.get("max_resource", -1)) < 0
			or int(row.get("speed", 0)) <= 0
		):
			_validation_errors.append("Invalid combatant numeric values: %s" % template_id)
		var ability_ids := row.get("ability_ids", []) as Array
		if ability_ids.is_empty():
			_validation_errors.append("Combatant template has no abilities: %s" % template_id)
		for ability_id: Variant in ability_ids:
			if not _abilities.has(ability_id):
				_validation_errors.append("Template references unknown ability: %s" % ability_id)
		_templates[template_id] = row.duplicate(true)


func _valid_definition_id(value: String) -> bool:
	return value.begins_with("development.") and value == value.to_lower() and value.length() <= 96
