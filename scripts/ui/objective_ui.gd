class_name ObjectiveUI
extends CanvasLayer

const COMPLETION_TEXT := "Objective Complete"

@export var active_marker_texture: Texture2D
@export var complete_marker_texture: Texture2D

@onready var _title_label: Label = $ObjectivePanel/Content/Title
@onready var _step_label: Label = $ObjectivePanel/Content/CurrentStep
@onready var _objective_marker: TextureRect = $ObjectivePanel/Content/ObjectiveHeader/ObjectiveMarker
@onready var _completion_timer: Timer = $CompletionTimer


func update_objective(objective_title: String, current_step_text: String, is_complete: bool) -> void:
	_title_label.text = objective_title
	_step_label.text = COMPLETION_TEXT if is_complete else current_step_text
	_objective_marker.texture = complete_marker_texture if is_complete else active_marker_texture
	visible = not objective_title.is_empty()
	if is_complete:
		_completion_timer.start()
	else:
		_completion_timer.stop()


func _on_completion_timer_timeout() -> void:
	visible = false
