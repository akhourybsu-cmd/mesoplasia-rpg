extends RefCounted

const APPROVED_MAIN_SCENE := "res://scenes/Main.tscn"
const REQUIRED_FEATURES := ["4.7", "GL Compatibility"]
const REQUIRED_INPUT_ACTIONS := [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"interact",
	&"attack",
	&"secondary_action",
	&"pause",
]
const REQUIRED_SETTINGS := {
	"display/window/size/viewport_width": 640,
	"display/window/size/viewport_height": 360,
	"display/window/size/window_width_override": 1280,
	"display/window/size/window_height_override": 720,
	"display/window/stretch/mode": "viewport",
	"display/window/stretch/scale_mode": "integer",
	"rendering/textures/canvas_textures/default_texture_filter": 0,
	"rendering/renderer/rendering_method": "gl_compatibility",
	"rendering/renderer/rendering_method.mobile": "gl_compatibility",
}


static func verify() -> String:
	var features: PackedStringArray = ProjectSettings.get_setting(
		"application/config/features",
		PackedStringArray()
	)
	for feature: String in REQUIRED_FEATURES:
		if not features.has(feature):
			return "project.godot is missing the required '%s' compatibility feature." % feature

	var configured_main_scene: String = ProjectSettings.get_setting(
		"application/run/main_scene",
		""
	)
	var configured_main_scene_path := configured_main_scene
	if configured_main_scene.begins_with("uid://"):
		configured_main_scene_path = ResourceUID.get_id_path(
			ResourceUID.text_to_id(configured_main_scene)
		)
	if configured_main_scene_path != APPROVED_MAIN_SCENE:
		return "project.godot no longer launches the approved Main scene."

	for setting_name: String in REQUIRED_SETTINGS:
		var expected: Variant = REQUIRED_SETTINGS[setting_name]
		var actual: Variant = ProjectSettings.get_setting(setting_name)
		if actual != expected:
			return "project.godot setting '%s' is %s; expected %s." % [
				setting_name,
				actual,
				expected,
			]

	# Godot 4.7 omits this setting from project.godot when it uses the
	# approved default. Verify the effective value instead of serialized text.
	var stretch_aspect: String = ProjectSettings.get_setting(
		"display/window/stretch/aspect",
		"keep"
	)
	if stretch_aspect != "keep":
		return "project.godot stretch aspect is '%s'; expected 'keep'." % stretch_aspect

	for action: StringName in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action):
			return "project.godot is missing the required Input Map action '%s'." % action

	for property: Dictionary in ProjectSettings.get_property_list():
		var property_name := str(property.get("name", ""))
		if property_name.begins_with("autoload/"):
			return "project.godot contains the unexpected autoload '%s'." % property_name

	var enabled_plugins: PackedStringArray = ProjectSettings.get_setting(
		"editor_plugins/enabled",
		PackedStringArray()
	)
	if not enabled_plugins.is_empty():
		return "project.godot enables unexpected editor plugins: %s." % enabled_plugins

	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://addons")):
		return "The project contains an unexpected addons directory."

	return ""
