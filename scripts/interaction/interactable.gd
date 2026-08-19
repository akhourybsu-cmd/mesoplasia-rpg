class_name Interactable
extends Area2D

signal interacted(interactor: Node2D)

@export var interaction_enabled := true
@export var prompt_text := "Interact"


func _ready() -> void:
	add_to_group(&"interactables")


func can_interact(interactor: Node2D) -> bool:
	return interaction_enabled and is_instance_valid(interactor)


func interact(interactor: Node2D) -> void:
	if can_interact(interactor):
		interacted.emit(interactor)


func get_prompt_text() -> String:
	return prompt_text
