class_name NetworkedCombatPresenter
extends CanvasLayer

signal combat_presented(combat_id: String)
signal combat_closed(outcome: String)

@onready var _combat_root: Control = %CombatRoot
@onready var _state_label: Label = %StateLabel
@onready var _combatants_label: Label = %CombatantsLabel
@onready var _events_label: Label = %EventsLabel
@onready var _result_label: Label = %ResultLabel
@onready var _strike_button: Button = %StrikeButton
@onready var _mend_button: Button = %MendButton
@onready var _guard_button: Button = %GuardButton

var _runtime: Node
var _local_character_id := ""
var _snapshot: Dictionary = {}
var _last_ready_revision := -1
var _action_sequence := 0
var _presented_combat_id := ""
var _closed_combat_id := ""


func _ready() -> void:
	_combat_root.visible = false
	_strike_button.pressed.connect(_submit_ability.bind("development.ability.strike"))
	_mend_button.pressed.connect(_submit_ability.bind("development.ability.mend"))
	_guard_button.pressed.connect(_submit_ability.bind("development.ability.guard"))


func _exit_tree() -> void:
	_disconnect_runtime()


func configure(runtime: Node) -> bool:
	if runtime == null:
		return false
	_disconnect_runtime()
	_runtime = runtime
	_runtime.combat_snapshot_received.connect(_on_combat_snapshot)
	_runtime.combat_command_result_received.connect(_on_combat_result)
	_runtime.client_authenticated.connect(_on_client_authenticated)
	_local_character_id = (
		(_runtime.call("get_client_identity") as Dictionary).get("character_id", "") as String
	)
	var snapshot := _runtime.call("get_combat_snapshot") as Dictionary
	if not snapshot.is_empty():
		_apply_snapshot(snapshot)
	return true


func get_snapshot_for_test() -> Dictionary:
	return _snapshot.duplicate(true)


func submit_ability_for_test(ability_id: String) -> bool:
	return _submit_ability(ability_id)


func _apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	var combat_id := snapshot.get("combat_id", "") as String
	var lifecycle := snapshot.get("lifecycle_state", "NONE") as String
	if combat_id.is_empty() or lifecycle in ["NONE", "CLOSED"]:
		_combat_root.visible = false
		if lifecycle == "CLOSED" and combat_id != _closed_combat_id:
			_closed_combat_id = combat_id
			combat_closed.emit(snapshot.get("outcome", "NONE"))
		return
	_combat_root.visible = true
	if combat_id != _presented_combat_id:
		_presented_combat_id = combat_id
		combat_presented.emit(combat_id)
	_acknowledge_ready_if_needed(snapshot)
	var actor := _combatant(snapshot.get("current_actor_id", ""))
	_state_label.text = "Combat %s  •  r%d  •  round %d  •  %s\nCurrent: %s  •  Outcome: %s" % [
		combat_id,
		int(snapshot.get("revision", -1)),
		int(snapshot.get("round_number", 0)),
		lifecycle,
		actor.get("display_name", "—"),
		snapshot.get("outcome", "NONE"),
	]
	var combatant_lines: Array[String] = []
	for combatant_value: Variant in snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		combatant_lines.append(
			"%s [%s]  HP %d/%d  Focus %d/%d%s" % [
				combatant.display_name,
				combatant.team_id,
				int(combatant.health),
				int(combatant.max_health),
				int(combatant.resource),
				int(combatant.max_resource),
				"  " + combatant.status_summary if not combatant.status_summary.is_empty() else "",
			]
		)
	_combatants_label.text = "\n".join(combatant_lines)
	var event_lines: Array[String] = []
	var events := snapshot.get("events", []) as Array
	for index in range(maxi(0, events.size() - 9), events.size()):
		var event := events[index] as Dictionary
		event_lines.append(
			"%02d  %s  %s" % [event.event_sequence, event.event_type, event.detail]
		)
	_events_label.text = "\n".join(event_lines)
	_update_buttons(actor)


func _acknowledge_ready_if_needed(snapshot: Dictionary) -> void:
	if snapshot.get("lifecycle_state", "") != "WAITING_FOR_CLIENTS":
		return
	if _local_character_id in (snapshot.get("ready_controller_ids", []) as Array):
		return
	var revision := int(snapshot.get("revision", -1))
	if revision < 0 or revision == _last_ready_revision:
		return
	_last_ready_revision = revision
	_runtime.call("send_combat_ready", snapshot.combat_id, revision)


func _update_buttons(actor: Dictionary) -> void:
	var may_act: bool = (
		_snapshot.get("lifecycle_state", "") == "AWAITING_ACTION"
		and actor.get("controller_id", "") == _local_character_id
	)
	var template_id := actor.get("template_id", "") as String
	_strike_button.disabled = not may_act
	_guard_button.disabled = not may_act
	_mend_button.disabled = (
		not may_act
		or template_id != "development.combatant.warden"
		or not _has_injured_ally(actor)
	)
	_mend_button.text = "Mend" if template_id == "development.combatant.warden" else "Mend (Warden)"


func _submit_ability(ability_id: String) -> bool:
	if _runtime == null or _snapshot.is_empty():
		return false
	var actor := _combatant(_snapshot.get("current_actor_id", ""))
	if actor.get("controller_id", "") != _local_character_id:
		return false
	var target_id := _choose_target(actor, ability_id)
	if target_id.is_empty():
		return false
	_action_sequence += 1
	var sent := _runtime.call(
		"send_combat_action",
		_snapshot.combat_id,
		int(_snapshot.revision),
		"network.ui.%s.%d" % [_local_character_id, _action_sequence],
		actor.combatant_id,
		ability_id,
		[target_id]
	) as bool
	if sent:
		_result_label.text = "%s submitted by %s." % [ability_id.get_slice(".", 2), actor.display_name]
	return sent


func _choose_target(actor: Dictionary, ability_id: String) -> String:
	if ability_id == "development.ability.guard":
		return actor.get("combatant_id", "")
	var candidates: Array[Dictionary] = []
	for combatant_value: Variant in _snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		if not combatant.get("alive", false):
			continue
		if ability_id == "development.ability.mend":
			if combatant.team_id == actor.team_id and int(combatant.health) < int(combatant.max_health):
				candidates.append(combatant)
		elif combatant.team_id != actor.team_id:
			candidates.append(combatant)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			if ability_id == "development.ability.mend":
				var first_missing := int(first.max_health) - int(first.health)
				var second_missing := int(second.max_health) - int(second.health)
				if first_missing != second_missing:
					return first_missing > second_missing
			elif int(first.health) != int(second.health):
				return int(first.health) < int(second.health)
			return String(first.combatant_id) < String(second.combatant_id)
	)
	return candidates[0].combatant_id


func _has_injured_ally(actor: Dictionary) -> bool:
	for combatant_value: Variant in _snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		if (
			combatant.get("team_id", "") == actor.get("team_id", "")
			and combatant.get("alive", false)
			and int(combatant.health) < int(combatant.max_health)
		):
			return true
	return false


func _combatant(combatant_id: String) -> Dictionary:
	for combatant_value: Variant in _snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		if combatant.get("combatant_id", "") == combatant_id:
			return combatant
	return {}


func _on_client_authenticated(identity: Dictionary) -> void:
	_local_character_id = identity.get("character_id", "") as String
	_runtime.call("request_combat_snapshot")


func _on_combat_snapshot(snapshot: Dictionary) -> void:
	_apply_snapshot(snapshot)


func _on_combat_result(result: Dictionary) -> void:
	_result_label.text = (
		"%s accepted." % result.command_type
		if result.get("accepted", false)
		else "%s rejected: %s" % [result.command_type, result.reason_code]
	)


func _disconnect_runtime() -> void:
	if _runtime == null or not is_instance_valid(_runtime):
		_runtime = null
		return
	if _runtime.combat_snapshot_received.is_connected(_on_combat_snapshot):
		_runtime.combat_snapshot_received.disconnect(_on_combat_snapshot)
	if _runtime.combat_command_result_received.is_connected(_on_combat_result):
		_runtime.combat_command_result_received.disconnect(_on_combat_result)
	if _runtime.client_authenticated.is_connected(_on_client_authenticated):
		_runtime.client_authenticated.disconnect(_on_client_authenticated)
	_runtime = null
