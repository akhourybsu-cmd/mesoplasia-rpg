class_name EnemyDecisionPolicy
extends RefCounted


func choose_action(
	actor_id: String,
	combatants: Dictionary,
	registry: RefCounted,
	spatial_rules: RefCounted
) -> Dictionary:
	var actor := combatants.get(actor_id, {}) as Dictionary
	if actor.is_empty() or not actor.get("alive", false):
		return {}
	var best: Dictionary = {}
	var ability_ids := (actor.get("ability_ids", []) as Array).duplicate()
	ability_ids.sort()
	for ability_id_value: Variant in ability_ids:
		var ability_id := ability_id_value as String
		var ability := registry.call("get_ability", ability_id) as Dictionary
		if ability.is_empty() or not _ability_available(actor, ability):
			continue
		var target_ids := spatial_rules.call(
			"get_valid_target_ids", actor_id, combatants, ability.target_rule
		) as Array[String]
		for target_id: String in target_ids:
			var target := combatants[target_id] as Dictionary
			var score := _score_action(actor, target, ability)
			if score < 0:
				continue
			var candidate := {
				"ability_id": ability_id,
				"target_ids": [target_id],
				"score": score,
			}
			if _candidate_precedes(candidate, best):
				best = candidate
	return best


func _ability_available(actor: Dictionary, ability: Dictionary) -> bool:
	return (
		int(actor.get("resource", 0)) >= int(ability.get("resource_cost", 0))
		and int((actor.get("cooldowns", {}) as Dictionary).get(ability.ability_id, 0)) <= 0
	)


func _score_action(actor: Dictionary, target: Dictionary, ability: Dictionary) -> int:
	var score := 0
	for effect_value: Variant in ability.effects:
		var effect := effect_value as Dictionary
		match effect.effect_type:
			"DAMAGE":
				score += int(effect.amount) * 10
			"HEAL":
				var missing := int(target.max_health) - int(target.health)
				if missing <= 0:
					return -1
				score += mini(missing, int(effect.amount)) * 12
			"APPLY_STATUS":
				if _has_status(target, effect.status_id):
					score -= 5
				else:
					score += 8
	if target.get("team_id", "") != actor.get("team_id", ""):
		score += int(target.max_health) - int(target.health)
	return score


func _candidate_precedes(candidate: Dictionary, current: Dictionary) -> bool:
	if current.is_empty() or int(candidate.score) > int(current.score):
		return true
	if int(candidate.score) < int(current.score):
		return false
	var candidate_key := "%s|%s" % [candidate.ability_id, candidate.target_ids[0]]
	var current_key := "%s|%s" % [current.ability_id, current.target_ids[0]]
	return candidate_key < current_key


func _has_status(combatant: Dictionary, status_id: String) -> bool:
	for status_value: Variant in combatant.get("statuses", []):
		if (status_value as Dictionary).get("status_id", "") == status_id:
			return true
	return false
