extends SceneTree

const DIALOGUE_SCENE := preload("res://ui/DialogueUI.tscn")
const INTERACTION_SCENE := preload("res://ui/InteractionPrompt.tscn")
const OBJECTIVE_SCENE := preload("res://ui/ObjectiveUI.tscn")

const PANEL_SOURCE_HASH := "28ba4e9631c32fc9f4145d598751b0abb818dca34338da72a8b9e214b5ee3aaa"
const ICON_SOURCE_HASH := "92c4b1253bc1ea3a11239278dd44d362ba8de1b587b2cba61ee7c48f8c154694"

var _viewport: SubViewport


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	root.add_child(_viewport)
	if not _check_source_hashes():
		return
	if not await _check_dialogue_ui():
		return
	if not await _check_interaction_prompt():
		return
	if not await _check_objective_ui():
		return

	print("PASS: Caden UI runtime assets, dynamic labels, 9-slice styles, state markers, and 640x360 safe layout.")
	quit(0)


func _check_source_hashes() -> bool:
	var panel_hash := FileAccess.get_sha256("res://assets/source_art/caden/ui/panels/caden_ui_panels_frames_master_v1.png")
	var icon_hash := FileAccess.get_sha256("res://assets/source_art/caden/ui/icons/caden_ui_icons_cursors_input_prompts_batch_b_master_v2.png")
	if panel_hash != PANEL_SOURCE_HASH:
		return _fail("The immutable Caden panel source hash changed.")
	if icon_hash != ICON_SOURCE_HASH:
		return _fail("The immutable Caden icon source hash changed.")
	return true


func _check_dialogue_ui() -> bool:
	var dialogue := DIALOGUE_SCENE.instantiate() as CanvasLayer
	_viewport.add_child(dialogue)
	dialogue.visible = true
	await process_frame

	var panel := dialogue.get_node("DialoguePanel") as PanelContainer
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if panel_style == null or panel_style.texture == null:
		return _fail("DialogueUI is missing its Caden panel StyleBoxTexture.")
	if panel_style.texture.get_size() != Vector2(99, 63):
		return _fail("Dialogue panel runtime texture has the wrong source-supported size.")
	var continue_indicator := dialogue.get_node("DialoguePanel/Content/AdvanceRow/ContinueIndicator") as TextureRect
	if not continue_indicator.texture is AtlasTexture:
		return _fail("Dialogue continue indicator is not an AtlasTexture cell.")
	if not _is_inside_viewport(panel):
		return _fail("DialogueUI leaves the 640x360 safe viewport: %s" % panel.get_global_rect())

	dialogue.queue_free()
	await process_frame
	return true


func _check_interaction_prompt() -> bool:
	var prompt := INTERACTION_SCENE.instantiate() as CanvasLayer
	_viewport.add_child(prompt)
	prompt.call("update_prompt", "Speak", true)
	await process_frame

	var keycap_label := prompt.get_node("PromptPanel/PromptContent/KeycapFrame/KeycapLabel") as Label
	var prompt_label := prompt.get_node("PromptPanel/PromptContent/PromptLabel") as Label
	if keycap_label.text != "E" or prompt_label.text != "Speak":
		return _fail("InteractionPrompt did not keep the key and prompt as separate dynamic labels.")
	var keycap := prompt.get_node("PromptPanel/PromptContent/KeycapFrame") as TextureRect
	if not keycap.texture is AtlasTexture:
		return _fail("InteractionPrompt does not use the blank runtime keycap atlas.")
	var panel := prompt.get_node("PromptPanel") as PanelContainer
	if not _is_inside_viewport(panel):
		return _fail("InteractionPrompt leaves the 640x360 safe viewport: %s" % panel.get_global_rect())

	prompt.queue_free()
	await process_frame
	return true


func _check_objective_ui() -> bool:
	var objective := OBJECTIVE_SCENE.instantiate() as CanvasLayer
	_viewport.add_child(objective)
	objective.call("update_objective", "Get Your Bearings", "Visit the Marketplace", false)
	await process_frame

	var marker := objective.get_node("ObjectivePanel/Content/ObjectiveHeader/ObjectiveMarker") as TextureRect
	var active_texture := objective.get("active_marker_texture") as Texture2D
	var complete_texture := objective.get("complete_marker_texture") as Texture2D
	if marker.texture != active_texture or not marker.texture is AtlasTexture:
		return _fail("ObjectiveUI did not begin with the active atlas marker.")
	objective.call("update_objective", "Get Your Bearings", "", true)
	if marker.texture != complete_texture:
		return _fail("ObjectiveUI did not switch to the completion atlas marker.")
	var step_label := objective.get_node("ObjectivePanel/Content/CurrentStep") as Label
	if step_label.text != "Objective Complete":
		return _fail("ObjectiveUI completion text behavior changed.")
	var panel := objective.get_node("ObjectivePanel") as PanelContainer
	if not _is_inside_viewport(panel):
		return _fail("ObjectiveUI leaves the 640x360 safe viewport: %s" % panel.get_global_rect())

	objective.queue_free()
	await process_frame
	return true


func _is_inside_viewport(control: Control) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= 0.0 \
		and rect.position.y >= 0.0 \
		and rect.end.x <= 640.0 \
		and rect.end.y <= 360.0


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
