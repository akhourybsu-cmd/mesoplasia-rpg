extends StaticBody2D

@export var conversation: Resource


func _on_interacted(interactor: Node2D) -> void:
	if conversation != null and interactor.has_method("start_dialogue"):
		interactor.call("start_dialogue", conversation)
