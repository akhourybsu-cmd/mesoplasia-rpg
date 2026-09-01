class_name OfflineCombatSandbox
extends Control

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")
const EnemyPolicy := preload("res://scripts/domain/combat/enemy_decision_policy.gd")
const CombatService := preload("res://scripts/domain/combat/combat_service.gd")

const LOCAL_CONTROLLER_ID := "development.controller.local"
const TURN_TIMEOUT_MSEC := 10000

@onready var _state_label: Label = %StateLabel
@onready var _combatants_label: Label = %CombatantsLabel
@onready var _events_label: Label = %EventsLabel
@onready var _result_label: Label = %ResultLabel
@onready var _restart_button: Button = %RestartButton
@onready var _strike_button: Button = %StrikeButton
@onready var _mend_button: Button = %MendButton
@onready var _guard_button: Button = %GuardButton

var _registry: RefCounted
var _spatial_rules: RefCounted
var _service: RefCounted
var _combat_id := ""
var _snapshot: Dictionary = {}
var _action_sequence := 0


func _ready() -> void:
	_restart_button.pressed.connect(_start_combat)
	_strike_button.pressed.connect(_on_ability_pressed.bind("development.ability.strike"))
	_mend_button.pressed.connect(_on_ability_pressed.bind("development.ability.mend"))
	_guard_button.pressed.connect(_on_ability_pressed.bind("development.ability.guard"))
	_start_combat()


func _process(_delta: float) -> void:
	if _service == null or _combat_id.is_empty():
		return
	var state := _service.call("get_instance_state", _combat_id) as Dictionary
	if state.get("lifecycle_state", "") == CombatService.STATE_AI_SELECTING:
		_service.call("tick", Time.get_ticks_msec())
		_refresh()
	elif (
		state.get("lifecycle_state", "") == CombatService.STATE_AWAITING_ACTION
		and Time.get_ticks_msec() >= int(state.get("turn_deadline_msec", 0))
	):
		_service.call("tick", Time.get_ticks_msec())
		_result_label.text = "The turn timed out; the domain selected its deterministic fallback."
		_refresh()


func restart_for_test() -> void:
	_start_combat()


func get_service_for_test() -> RefCounted:
	return _service


func get_snapshot_for_test() -> Dictionary:
	return _snapshot.duplicate(true)


func use_ability_for_test(ability_id: String) -> Dictionary:
	return _submit_ability(ability_id)


func _start_combat() -> void:
	_registry = Registry.new()
	_spatial_rules = SpatialRules.new()
	_service = CombatService.new()
	if not _service.configure(
		_registry, _spatial_rules, EnemyPolicy.new(), TURN_TIMEOUT_MSEC, 32
	):
		_result_label.text = "Combat service configuration failed."
		return
	var vanguard := _registry.call(
		"instantiate_combatant",
		"development.combatant.vanguard",
		"development.combatant.viewer.vanguard",
		LOCAL_CONTROLLER_ID
	) as Dictionary
	var warden := _registry.call(
		"instantiate_combatant",
		"development.combatant.warden",
		"development.combatant.viewer.warden",
		LOCAL_CONTROLLER_ID
	) as Dictionary
	var slime := _registry.call(
		"instantiate_combatant",
		"development.combatant.venom_slime",
		"development.combatant.viewer.slime"
	) as Dictionary
	var created := _service.call(
		"create_combat", 73021, [vanguard, warden, slime], Time.get_ticks_msec()
	) as Dictionary
	if not created.get("accepted", false):
		_result_label.text = "Combat creation failed: %s" % created.get("reason_code", "")
		return
	_combat_id = created.combat_id
	var instance := _service.call("get_instance_state", _combat_id) as Dictionary
	_service.call(
		"acknowledge_ready",
		LOCAL_CONTROLLER_ID,
		_combat_id,
		instance.revision,
		Time.get_ticks_msec()
	)
	_action_sequence = 0
	_result_label.text = "Offline fixture started. Choose an ability on a player turn."
	_refresh()


func _on_ability_pressed(ability_id: String) -> void:
	_submit_ability(ability_id)


func _submit_ability(ability_id: String) -> Dictionary:
	if _service == null or _snapshot.is_empty():
		return {"accepted": false, "reason_code": "NO_COMBAT"}
	var actor_id := _snapshot.get("current_actor_id", "") as String
	var actor := _combatant(actor_id)
	var ability := _registry.call("get_ability", ability_id) as Dictionary
	if actor.is_empty() or ability.is_empty():
		return {"accepted": false, "reason_code": "NO_ACTOR_OR_ABILITY"}
	var target_ids := _spatial_rules.call(
		"get_valid_target_ids",
		actor_id,
		_combatants_by_id(),
		ability.target_rule
	) as Array[String]
	if target_ids.is_empty():
		return {"accepted": false, "reason_code": "NO_VALID_TARGET"}
	var target_id := _choose_target(target_ids, ability.target_rule)
	_action_sequence += 1
	var result := _service.call(
		"submit_action",
		LOCAL_CONTROLLER_ID,
		_combat_id,
		_snapshot.revision,
		"viewer.action.%d" % _action_sequence,
		actor_id,
		ability_id,
		[target_id],
		Time.get_ticks_msec()
	) as Dictionary
	_result_label.text = (
		"%s → %s accepted."
		% [actor.display_name, ability.display_name]
		if result.get("accepted", false)
		else "%s rejected: %s" % [ability.display_name, result.get("reason_code", "")]
	)
	_refresh()
	return result


func _refresh() -> void:
	_snapshot = _service.call("get_snapshot", _combat_id) as Dictionary
	var actor := _combatant(_snapshot.get("current_actor_id", ""))
	_state_label.text = "Combat %s  •  r%d  •  round %d  •  %s\nCurrent: %s  •  Outcome: %s" % [
		_snapshot.get("combat_id", ""),
		int(_snapshot.get("revision", -1)),
		int(_snapshot.get("round_number", 0)),
		_snapshot.get("lifecycle_state", ""),
		actor.get("display_name", "—"),
		_snapshot.get("outcome", "NONE"),
	]
	var combatant_lines: Array[String] = []
	for combatant_value: Variant in _snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		var status_names: Array[String] = []
		for status_value: Variant in combatant.get("statuses", []):
			var status := status_value as Dictionary
			status_names.append("%s:%d" % [status.status_id.get_slice(".", 2), status.remaining_turns])
		combatant_lines.append(
			"%s [%s]  HP %d/%d  Focus %d/%d  %s%s" % [
				combatant.display_name,
				combatant.team_id,
				int(combatant.health),
				int(combatant.max_health),
				int(combatant.resource),
				int(combatant.max_resource),
				"DEFEATED" if not combatant.alive else "",
				"  " + ", ".join(status_names) if not status_names.is_empty() else "",
			]
		)
	_combatants_label.text = "\n".join(combatant_lines)
	var event_lines: Array[String] = []
	var events := _snapshot.get("recent_events", []) as Array
	var start := maxi(0, events.size() - 9)
	for index in range(start, events.size()):
		var event := events[index] as Dictionary
		event_lines.append("%02d  %s  %s" % [event.event_sequence, event.event_type, _event_detail(event)])
	_events_label.text = "\n".join(event_lines)
	_update_action_buttons(actor)


func _update_action_buttons(actor: Dictionary) -> void:
	var may_act: bool = (
		_snapshot.get("lifecycle_state", "") == CombatService.STATE_AWAITING_ACTION
		and actor.get("controller_id", "") == LOCAL_CONTROLLER_ID
	)
	for pair: Array in [
		[_strike_button, "development.ability.strike"],
		[_mend_button, "development.ability.mend"],
		[_guard_button, "development.ability.guard"],
	]:
		var button := pair[0] as Button
		var ability_id := pair[1] as String
		button.disabled = not may_act or ability_id not in (actor.get("ability_ids", []) as Array)


func _choose_target(target_ids: Array[String], target_rule: String) -> String:
	if target_rule == "SELF":
		return _snapshot.current_actor_id
	var best_id := target_ids[0]
	var best := _combatant(best_id)
	for target_id: String in target_ids:
		var candidate := _combatant(target_id)
		if (
			int(candidate.health) < int(best.health)
			or (
				int(candidate.health) == int(best.health)
				and target_id < best_id
			)
		):
			best_id = target_id
			best = candidate
	return best_id


func _combatant(combatant_id: String) -> Dictionary:
	for combatant_value: Variant in _snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		if combatant.get("combatant_id", "") == combatant_id:
			return combatant
	return {}


func _combatants_by_id() -> Dictionary:
	var result: Dictionary = {}
	for combatant_value: Variant in _snapshot.get("combatants", []):
		var combatant := combatant_value as Dictionary
		result[combatant.combatant_id] = combatant
	return result


func _event_detail(event: Dictionary) -> String:
	var payload := event.get("payload", {}) as Dictionary
	if payload.has("ability_id"):
		return String(payload.ability_id).get_slice(".", 2)
	if payload.has("amount"):
		return "amount %d" % int(payload.amount)
	if payload.has("outcome"):
		return payload.outcome
	return event.get("actor_id", "")
