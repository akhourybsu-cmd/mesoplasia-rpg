extends CanvasLayer

@export var input_hint_text := "[E]"

@onready var _label: Label = $PromptPanel/PromptLabel


func update_prompt(prompt_text: String, is_visible: bool) -> void:
	visible = is_visible
	if is_visible:
		_label.text = "%s %s" % [input_hint_text, prompt_text]
