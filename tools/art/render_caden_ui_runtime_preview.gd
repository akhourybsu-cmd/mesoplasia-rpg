extends SceneTree

const DIALOGUE_SCENE := preload("res://ui/DialogueUI.tscn")
const INTERACTION_SCENE := preload("res://ui/InteractionPrompt.tscn")
const OBJECTIVE_SCENE := preload("res://ui/ObjectiveUI.tscn")
const OUTPUT_DIR := "res://docs/art/previews/caden_ui_runtime_v1"


func _initialize() -> void:
	_render_previews.call_deferred()


func _render_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var dialogue_view := await _render_dialogue_view()
	var interaction_view := await _render_interaction_view()
	var baseline_dialogue_view := await _render_baseline_dialogue_view()
	var baseline_interaction_view := await _render_baseline_interaction_view()
	if dialogue_view == null or interaction_view == null or baseline_dialogue_view == null or baseline_interaction_view == null:
		push_error("The current rendering driver did not return UI preview images.")
		quit(2)
		return

	var combined := Image.create(640, 720, false, Image.FORMAT_RGBA8)
	combined.blit_rect(dialogue_view, Rect2i(0, 0, 640, 360), Vector2i.ZERO)
	combined.blit_rect(interaction_view, Rect2i(0, 0, 640, 360), Vector2i(0, 360))
	var live_path := "%s/caden_ui_live_interfaces_v1.png" % OUTPUT_DIR
	combined.save_png(live_path)
	var baseline := Image.create(640, 720, false, Image.FORMAT_RGBA8)
	baseline.blit_rect(baseline_dialogue_view, Rect2i(0, 0, 640, 360), Vector2i.ZERO)
	baseline.blit_rect(baseline_interaction_view, Rect2i(0, 0, 640, 360), Vector2i(0, 360))
	var comparison := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	comparison.blit_rect(baseline, Rect2i(0, 0, 640, 720), Vector2i.ZERO)
	comparison.blit_rect(combined, Rect2i(0, 0, 640, 720), Vector2i(640, 0))
	comparison.save_png("%s/caden_ui_before_after_v1.png" % OUTPUT_DIR)

	var grayscale := combined.duplicate()
	grayscale.adjust_bcs(1.0, 1.0, 0.0)
	grayscale.save_png("%s/caden_ui_live_interfaces_grayscale_v1.png" % OUTPUT_DIR)
	var reduced_saturation := combined.duplicate()
	reduced_saturation.adjust_bcs(1.0, 1.0, 0.35)
	reduced_saturation.save_png("%s/caden_ui_live_interfaces_reduced_saturation_v1.png" % OUTPUT_DIR)

	print("PASS: Rendered Caden UI live-interface and saturation review previews.")
	quit(0)


func _render_dialogue_view() -> Image:
	var viewport := _make_viewport()
	_add_backdrop(viewport)
	var objective := OBJECTIVE_SCENE.instantiate() as CanvasLayer
	viewport.add_child(objective)
	objective.call("update_objective", "Get Your Bearings", "Visit the Marketplace", false)
	var dialogue := DIALOGUE_SCENE.instantiate() as CanvasLayer
	viewport.add_child(dialogue)
	dialogue.get_node("DialoguePanel/Content/SpeakerName").text = "Square Local"
	dialogue.get_node("DialoguePanel/Content/DialogueText").text = "The marketplace is just beyond the square. You cannot miss the festival banners."
	dialogue.visible = true
	await _settle_viewport()
	var output := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return output


func _render_interaction_view() -> Image:
	var viewport := _make_viewport()
	_add_backdrop(viewport)
	var objective := OBJECTIVE_SCENE.instantiate() as CanvasLayer
	viewport.add_child(objective)
	objective.call("update_objective", "Get Your Bearings", "Visit the Town Square", false)
	var prompt := INTERACTION_SCENE.instantiate() as CanvasLayer
	viewport.add_child(prompt)
	prompt.call("update_prompt", "Talk", true)
	await _settle_viewport()
	var output := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return output


func _render_baseline_dialogue_view() -> Image:
	var viewport := _make_viewport()
	_add_backdrop(viewport)
	_add_baseline_objective(viewport, "Visit the Marketplace")
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var panel := _baseline_panel(Vector2(24, 232), Vector2(592, 108))
	layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var speaker := Label.new()
	speaker.text = "Square Local"
	speaker.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
	speaker.add_theme_font_size_override("font_size", 18)
	content.add_child(speaker)
	content.add_child(HSeparator.new())
	var line := Label.new()
	line.text = "The marketplace is just beyond the square. You cannot miss the festival banners."
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(0, 48)
	content.add_child(line)
	var hint := Label.new()
	hint.text = "[E] Continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(hint)
	await _settle_viewport()
	var output := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return output


func _render_baseline_interaction_view() -> Image:
	var viewport := _make_viewport()
	_add_backdrop(viewport)
	_add_baseline_objective(viewport, "Visit the Town Square")
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var panel := _baseline_panel(Vector2(240, 312), Vector2(160, 32))
	layer.add_child(panel)
	var label := Label.new()
	label.text = "[E] Talk"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	await _settle_viewport()
	var output := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return output


func _add_baseline_objective(viewport: SubViewport, step_text: String) -> void:
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var panel := _baseline_panel(Vector2(388, 16), Vector2(236, 84))
	layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	var development := Label.new()
	development.text = "DEV OBJECTIVE"
	development.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
	development.add_theme_font_size_override("font_size", 10)
	content.add_child(development)
	var title := Label.new()
	title.text = "Get Your Bearings"
	title.add_theme_font_size_override("font_size", 16)
	content.add_child(title)
	content.add_child(HSeparator.new())
	var step := Label.new()
	step.text = step_text
	step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(step)


func _baseline_panel(position_value: Vector2, size_value: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = size_value
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.15, 0.94)
	style.border_color = Color(0.32, 0.34, 0.38, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.disable_3d = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _add_backdrop(viewport: SubViewport) -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("4d6b3c")
	viewport.add_child(backdrop)
	var plaza := ColorRect.new()
	plaza.position = Vector2(76, 36)
	plaza.size = Vector2(488, 288)
	plaza.color = Color("b8aa83")
	backdrop.add_child(plaza)
	var building := ColorRect.new()
	building.position = Vector2(112, 52)
	building.size = Vector2(184, 112)
	building.color = Color("594434")
	backdrop.add_child(building)
	var path := ColorRect.new()
	path.position = Vector2(286, 36)
	path.size = Vector2(68, 288)
	path.color = Color("897b5c")
	backdrop.add_child(path)


func _settle_viewport() -> void:
	await process_frame
	await process_frame
	await process_frame
