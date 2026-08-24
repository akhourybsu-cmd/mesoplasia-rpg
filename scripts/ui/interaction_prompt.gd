extends CanvasLayer

@export var input_hint_text := "E"

@onready var _keycap_label: Label = $PromptPanel/PromptContent/KeycapFrame/KeycapLabel
@onready var _label: Label = $PromptPanel/PromptContent/PromptLabel


func update_prompt(prompt_text: String, is_visible: bool) -> void:
	visible = is_visible
	if is_visible:
		_keycap_label.text = _format_input_hint(input_hint_text)
		_label.text = prompt_text


func _format_input_hint(hint_text: String) -> String:
	var formatted := hint_text.strip_edges()
	if formatted.begins_with("[") and formatted.ends_with("]") and formatted.length() > 2:
		return formatted.substr(1, formatted.length() - 2)
	return formatted
