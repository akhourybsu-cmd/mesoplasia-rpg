class_name ObjectiveStepDefinition
extends Resource

@export var step_id: StringName
@export var display_text := ""
@export var completion_zone_ids: Array[StringName] = []


func is_completed_by_zone(zone_id: StringName) -> bool:
	return completion_zone_ids.has(zone_id)
