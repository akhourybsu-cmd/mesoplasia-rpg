class_name InteractionDetector
extends Area2D

signal prompt_changed(prompt_text: String, is_visible: bool)
signal interaction_requested(
	character_id: StringName,
	interactable_id: StringName,
	interactable: Area2D
)

const FORWARD_PREFERENCE_WEIGHT := 4096.0

var _candidates: Array[Area2D] = []
var _active_interactable: Area2D
var _facing_direction := Vector2.DOWN
var _interactor: Node2D
var _interaction_enabled := true
var _last_prompt_text := ""
var _character_id: StringName


func _ready() -> void:
	_interactor = get_parent() as Node2D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(_delta: float) -> void:
	_refresh_active_interactable()


func _unhandled_input(event: InputEvent) -> void:
	if _interaction_enabled and event.is_action_pressed("interact"):
		try_interact()
		get_viewport().set_input_as_handled()


func set_facing_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_facing_direction = direction.normalized()


func configure_interactor(character_id: StringName, is_enabled: bool) -> void:
	_character_id = character_id
	set_interaction_enabled(is_enabled)


func try_interact() -> bool:
	if not _interaction_enabled:
		return false

	_refresh_active_interactable()
	if _is_valid_candidate(_active_interactable):
		var interactable_id := _active_interactable.call("get_interactable_id") as StringName
		if interactable_id != &"" and _character_id != &"":
			interaction_requested.emit(_character_id, interactable_id, _active_interactable)
			return true
	return false


func get_active_interactable() -> Area2D:
	_refresh_active_interactable()
	return _active_interactable


func set_interaction_enabled(is_enabled: bool) -> void:
	_interaction_enabled = is_enabled
	set_process_unhandled_input(is_enabled)
	_refresh_active_interactable()


func clear_candidates() -> void:
	_candidates.clear()
	_set_active_interactable(null)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(&"interactables") and not _candidates.has(area):
		_candidates.append(area)
		_refresh_active_interactable()


func _on_area_exited(area: Area2D) -> void:
	_candidates.erase(area)
	_refresh_active_interactable()


func _refresh_active_interactable() -> void:
	_prune_candidates()
	if not _interaction_enabled:
		_set_active_interactable(null)
		return

	var best_candidate: Area2D
	var best_score := INF
	for candidate in _candidates:
		if not _is_valid_candidate(candidate):
			continue

		var offset := candidate.global_position - global_position
		var distance_squared := offset.length_squared()
		var direction_to_candidate := offset.normalized()
		var facing_alignment := maxf(_facing_direction.dot(direction_to_candidate), 0.0)
		var score := distance_squared - facing_alignment * FORWARD_PREFERENCE_WEIGHT
		if score < best_score:
			best_score = score
			best_candidate = candidate

	_set_active_interactable(best_candidate)


func _prune_candidates() -> void:
	for index in range(_candidates.size() - 1, -1, -1):
		var candidate := _candidates[index]
		if not is_instance_valid(candidate) or not candidate.is_inside_tree():
			_candidates.remove_at(index)


func _is_valid_candidate(candidate: Area2D) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate.is_inside_tree()
		and candidate.is_in_group(&"interactables")
		and candidate.has_method("can_interact")
		and candidate.has_method("get_interactable_id")
		and candidate.call("can_interact", _interactor)
	)


func _set_active_interactable(candidate: Area2D) -> void:
	_active_interactable = candidate
	var prompt_text := ""
	if _is_valid_candidate(candidate) and candidate.has_method("get_prompt_text"):
		prompt_text = candidate.call("get_prompt_text") as String

	if prompt_text != _last_prompt_text:
		_last_prompt_text = prompt_text
		prompt_changed.emit(prompt_text, not prompt_text.is_empty())
