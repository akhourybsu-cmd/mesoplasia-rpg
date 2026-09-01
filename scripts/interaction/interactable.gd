class_name Interactable
extends Area2D

signal interacted(interactor: Node2D)

@export var interaction_enabled := true
@export var prompt_text := "Interact"
@export var interactable_id: StringName


func _ready() -> void:
	add_to_group(&"interactables")


func can_interact(interactor: Node2D) -> bool:
	return interaction_enabled and is_instance_valid(interactor)


func interact(interactor: Node2D) -> void:
	if can_interact(interactor):
		interacted.emit(interactor)


func get_prompt_text() -> String:
	return prompt_text


func set_interactable_id(value: StringName) -> void:
	interactable_id = value


func get_interactable_id() -> StringName:
	return interactable_id
