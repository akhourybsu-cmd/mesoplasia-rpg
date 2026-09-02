class_name CadenResourceDefinitionRegistry
extends RefCounted

const DEFAULT_DEFINITION_PATH := "res://data/caden/development_resource_projects.json"

var _resources: Dictionary = {}
var _projects: Dictionary = {}
var _validation_errors: Array[String] = []


func _init() -> void:
	load_definition_file(DEFAULT_DEFINITION_PATH)


func load_definition_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_validation_errors.append("Caden resource definition file is missing: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_validation_errors.append("Caden resource definition file could not be opened: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int((parsed as Dictionary).get("schema_version", 0)) != 1:
		_validation_errors.append("Caden resource definition schema must be 1.")
		return false
	var source := parsed as Dictionary
	for resource_value: Variant in source.get("resources", []):
		if not resource_value is Dictionary:
			_validation_errors.append("Caden resource definition must be an object.")
			continue
		var resource := (resource_value as Dictionary).duplicate(true)
		var resource_id := resource.get("resource_id", "") as String
		if (
			not _stable_id(resource_id)
			or _resources.has(resource_id)
			or (resource.get("display_name", "") as String).strip_edges().is_empty()
			or int(resource.get("maximum_deposit_quantity", 0)) < 1
			or int(resource.get("maximum_deposit_quantity", 0)) > 9999
		):
			_validation_errors.append("Invalid Caden resource definition: %s" % resource_id)
			continue
		_resources[resource_id] = resource
	for project_value: Variant in source.get("projects", []):
		if not project_value is Dictionary:
			_validation_errors.append("Caden project definition must be an object.")
			continue
		var project := (project_value as Dictionary).duplicate(true)
		var project_id := project.get("project_id", "") as String
		var costs: Variant = project.get("required_resources", {})
		var valid := (
			_stable_id(project_id)
			and not _projects.has(project_id)
			and not (project.get("display_name", "") as String).strip_edges().is_empty()
			and project.get("initial_state", "") is String
			and project.get("funded_state", "") is String
			and costs is Dictionary
			and not (costs as Dictionary).is_empty()
		)
		if valid:
			for resource_id_value: Variant in costs:
				var resource_id := resource_id_value as String
				if (
					not _resources.has(resource_id)
					or int((costs as Dictionary)[resource_id_value]) < 1
					or int((costs as Dictionary)[resource_id_value]) > 999999
				):
					valid = false
					break
		if not valid:
			_validation_errors.append("Invalid Caden project definition: %s" % project_id)
			continue
		_projects[project_id] = project
	return is_valid()


func is_valid() -> bool:
	return not _resources.is_empty() and not _projects.is_empty() and _validation_errors.is_empty()


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func has_resource(resource_id: String) -> bool:
	return _resources.has(resource_id)


func get_resource(resource_id: String) -> Dictionary:
	return (_resources.get(resource_id, {}) as Dictionary).duplicate(true)


func get_resource_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_resources.keys())
	result.sort()
	return result


func get_project_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_projects.keys())
	result.sort()
	return result


func get_project(project_id: String) -> Dictionary:
	return (_projects.get(project_id, {}) as Dictionary).duplicate(true)


func _stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
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
