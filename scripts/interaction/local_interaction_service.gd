class_name LocalInteractionService
extends Node

const CharacterIdentityContract := preload("res://scripts/core/character_identity.gd")


func request_interaction(
	character_id: StringName,
	interactor: Node2D,
	interactable_id: StringName,
	interactable: Area2D
) -> bool:
	if not CharacterIdentityContract.is_valid(character_id):
		return false
	if not is_instance_valid(interactor) or not interactor.has_method("get_character_id"):
		return false
	if (interactor.call("get_character_id") as StringName) != character_id:
		return false
	if not is_instance_valid(interactable) or not interactable.has_method("get_interactable_id"):
		return false
	if (
		interactable_id == &""
		or (interactable.call("get_interactable_id") as StringName) != interactable_id
	):
		return false
	if not interactable.has_method("can_interact") or not interactable.call("can_interact", interactor):
		return false

	interactable.call("interact", interactor)
	return true
