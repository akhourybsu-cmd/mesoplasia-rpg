class_name NetworkCombatAgent
extends Node

var _runtime: Node
var _character_id := ""
var _last_ready_revision := -1
var _last_action_revision := -1
var _action_sequence := 0


func configure(runtime: Node) -> bool:
	if runtime == null:
		return false
	_runtime = runtime
	_runtime.combat_snapshot_received.connect(_on_snapshot)
	_character_id = ((_runtime.call("get_client_identity") as Dictionary).get("character_id", "") as String)
	var snapshot := _runtime.call("get_combat_snapshot") as Dictionary
	if not snapshot.is_empty():
		_on_snapshot(snapshot)
	return true


func _exit_tree() -> void:
	if _runtime != null and is_instance_valid(_runtime):
		if _runtime.combat_snapshot_received.is_connected(_on_snapshot):
			_runtime.combat_snapshot_received.disconnect(_on_snapshot)


func _on_snapshot(snapshot: Dictionary) -> void:
	if _character_id.is_empty():
		_character_id = ((_runtime.call("get_client_identity") as Dictionary).get("character_id", "") as String)
	var revision := int(snapshot.get("revision", -1))
	if snapshot.get("lifecycle_state", "") == "WAITING_FOR_CLIENTS":
		if (
			_character_id not in (snapshot.get("ready_controller_ids", []) as Array)
			and revision != _last_ready_revision
		):
			_last_ready_revision = revision
			_runtime.call("send_combat_ready", snapshot.combat_id, revision)
		return
	if snapshot.get("lifecycle_state", "") != "AWAITING_ACTION" or revision == _last_action_revision:
		return
	var actor: Dictionary = {}
	var target: Dictionary = {}
	for value: Variant in snapshot.get("combatants", []):
		var combatant := value as Dictionary
		if combatant.combatant_id == snapshot.current_actor_id:
			actor = combatant
		elif combatant.team_id == "enemies" and combatant.alive:
			if target.is_empty() or int(combatant.health) < int(target.health):
				target = combatant
	if actor.get("controller_id", "") != _character_id or target.is_empty():
		return
	_last_action_revision = revision
	_action_sequence += 1
	_runtime.call(
		"send_combat_action",
		snapshot.combat_id,
		revision,
		"network.agent.%s.%d" % [_character_id, _action_sequence],
		actor.combatant_id,
		"development.ability.strike",
		[target.combatant_id]
	)
