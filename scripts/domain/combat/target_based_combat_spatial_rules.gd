class_name TargetBasedCombatSpatialRules
extends RefCounted

const RULE_SELF := "SELF"
const RULE_ALLY := "ALLY"
const RULE_ENEMY := "ENEMY"


func validate_targets(
	actor_id: String,
	target_ids: Array,
	combatants: Dictionary,
	target_rule: String
) -> Dictionary:
	if not combatants.has(actor_id):
		return _rejected("UNKNOWN_ACTOR")
	if target_ids.size() != 1:
		return _rejected("TARGET_COUNT")
	var target_id := target_ids[0] as String
	if not combatants.has(target_id):
		return _rejected("UNKNOWN_TARGET")
	var actor := combatants[actor_id] as Dictionary
	var target := combatants[target_id] as Dictionary
	if not target.get("alive", false):
		return _rejected("TARGET_DEFEATED")
	match target_rule:
		RULE_SELF:
			if target_id != actor_id:
				return _rejected("TARGET_NOT_SELF")
		RULE_ALLY:
			if target.get("team_id", "") != actor.get("team_id", ""):
				return _rejected("TARGET_NOT_ALLY")
		RULE_ENEMY:
			if target.get("team_id", "") == actor.get("team_id", ""):
				return _rejected("TARGET_NOT_ENEMY")
		_:
			return _rejected("UNKNOWN_TARGET_RULE")
	return {"accepted": true, "reason_code": "OK", "target_ids": [target_id]}


func get_valid_target_ids(
	actor_id: String,
	combatants: Dictionary,
	target_rule: String
) -> Array[String]:
	var result: Array[String] = []
	var ids := combatants.keys()
	ids.sort()
	for target_id_value: Variant in ids:
		var target_id := target_id_value as String
		if validate_targets(actor_id, [target_id], combatants, target_rule).accepted:
			result.append(target_id)
	return result


func serialize_position(_combatant: Dictionary) -> Dictionary:
	return {"model": "TARGET_BASED", "slot": "targetable"}


func _rejected(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "target_ids": []}
