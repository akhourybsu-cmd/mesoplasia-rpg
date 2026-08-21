extends SceneTree

const LAB_SCENE := preload("res://scenes/development/CharacterScaleLab.tscn")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const CELL_SIZE := Vector2i(40, 56)
const EXPECTED_SHEET_SIZE := Vector2i(160, 224)
const CANDIDATES := {
	"Candidates/CandidateA_32x48": Vector2(32, 48),
	"Candidates/CandidateB_40x56": Vector2(40, 56),
	"Candidates/CandidateC_48x64": Vector2(48, 64),
}
const TEMPLATE_PATHS := [
	"res://assets/source_art/caden/characters/templates/caden_player_directional_template_v1.png",
	"res://assets/source_art/caden/characters/templates/caden_npc_directional_template_v1.png",
	"res://assets/source_art/caden/characters/templates/caden_character_anchor_reference_v1.png",
	"res://assets/source_art/caden/characters/templates/caden_character_collision_reference_v1.png",
]
const EXPECTED_ENVIRONMENT_HASHES := {
	"res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png": "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a",
	"res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
	"res://assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png": "4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828",
	"res://assets/environments/caden/props/seating/caden_bench_01_v1.png": "49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79",
	"res://assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png": "705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59",
	"res://assets/environments/caden/accents/edenite/caden_edenite_lantern_01_v1.png": "18ce8e4b5066cb228e589e7f9f0cee4dd07fab18e8e9c45f4e12f430a12c36ad",
}
const EXPECTED_PROTECTED_PRODUCTION_HASHES := {
	"res://scenes/npcs/StationaryNpc.tscn": "c2ba9b8358c3e0ed27227d3bb93052afc463164fb5aafc64a0b5dfb62fcbe854",
	"res://scripts/npcs/stationary_npc.gd": "8b2a0032376495184e4638b5bc86849d13b712716eabf416487b4b3f78c84e4b",
	"res://scenes/world/caden/TownSquare.tscn": "af98a1d13ac14c0675968621400f21bbc9b1568be815a99b8844959b70af9781",
}
const APPROVED_PLAYER_SOURCE_PATH := "res://assets/source_art/caden/characters/player/caden_player_character_master_v3.png"
const APPROVED_PLAYER_RUNTIME_PATH := "res://assets/characters/caden/player/caden_player_runtime_v1.png"
const NPC_SOURCE_PATH := "res://assets/source_art/caden/characters/npc/caden_npc_base_master_v1.png"
const NPC_RUNTIME_PATH := "res://assets/characters/caden/npc/caden_npc_base_runtime_v1.png"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_source_art_gate():
		return
	if not _verify_protected_files():
		return
	if not _verify_project_configuration():
		return
	if not await _verify_lab_scene():
		return
	if not _verify_templates():
		return
	if not _verify_no_environment_source_master_coupling():
		return

	print("PASS: Character scale lab, approved Player runtime, candidate canvases, 24x24 overlays, transparent 4x4 templates, protected NPC/world hashes, and semantic project configuration.")
	quit(0)


func _verify_source_art_gate() -> bool:
	for path: String in [APPROVED_PLAYER_SOURCE_PATH, APPROVED_PLAYER_RUNTIME_PATH]:
		if not FileAccess.file_exists(path):
			return _fail("Approved Player visual artifact is missing: %s" % path)
	for path: String in [NPC_SOURCE_PATH, NPC_RUNTIME_PATH]:
		if FileAccess.file_exists(path):
			return _fail("NPC visual integration remains out of scope for this Player-only pass: %s" % path)
	return true


func _verify_protected_files() -> bool:
	for path: String in EXPECTED_ENVIRONMENT_HASHES:
		if not FileAccess.file_exists(path):
			return _fail("Missing representative protected environment asset: %s" % path)
		if FileAccess.get_sha256(path) != EXPECTED_ENVIRONMENT_HASHES[path]:
			return _fail("Representative protected environment asset changed: %s" % path)
	for path: String in EXPECTED_PROTECTED_PRODUCTION_HASHES:
		if FileAccess.get_sha256(path) != EXPECTED_PROTECTED_PRODUCTION_HASHES[path]:
			return _fail("Protected NPC or world production file changed during the Player-only pass: %s" % path)
	return true


func _verify_project_configuration() -> bool:
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		return _fail(project_configuration_error)
	return true


func _verify_lab_scene() -> bool:
	var lab := LAB_SCENE.instantiate() as Node2D
	if lab == null:
		return _fail("CharacterScaleLab failed to instantiate.")
	root.add_child(lab)
	await process_frame

	for required_path: String in [
		"TerrainPatches/Grass",
		"TerrainPatches/Road",
		"TerrainPatches/RoadToPlazaTransition",
		"TerrainPatches/Plaza",
		"EnvironmentReferences/RepresentativeBuilding",
		"EnvironmentReferences/RepresentativeBench",
		"EnvironmentReferences/OrdinaryLantern",
		"EnvironmentReferences/EdeniteFixture",
		"EnvironmentReferences/RepresentativePlanter",
		"EnvironmentReferences/MediumTree",
	]:
		if lab.get_node_or_null(required_path) == null:
			return _fail("CharacterScaleLab is missing required context: %s" % required_path)

	if lab.get_node("Candidates").get_child_count() != 4:
		return _fail("CharacterScaleLab must contain the approved runtime plus three scale silhouettes.")
	var runtime_candidate := lab.get_node_or_null("Candidates/RuntimeCandidateV1") as Node2D
	if runtime_candidate == null:
		return _fail("CharacterScaleLab is missing the approved runtime candidate.")
	if runtime_candidate.position != Vector2(80, 340):
		return _fail("CharacterScaleLab runtime candidate no longer uses the approved comparison position.")
	var runtime_canvas := runtime_candidate.get_node("CanvasBounds") as Line2D
	if _points_size(runtime_canvas.points) != Vector2(CELL_SIZE):
		return _fail("CharacterScaleLab runtime candidate no longer displays the 40x56 canvas.")
	var runtime_collision := runtime_candidate.get_node("CollisionFootprint") as Polygon2D
	if _points_size(runtime_collision.polygon) != Vector2(24, 24):
		return _fail("CharacterScaleLab runtime candidate no longer displays the existing 24x24 Player collision footprint.")
	var runtime_sprite := runtime_candidate.get_node("AnimatedSprite2D") as AnimatedSprite2D
	if runtime_sprite.position != Vector2(0, -28) or runtime_sprite.sprite_frames == null:
		return _fail("CharacterScaleLab runtime sprite lost its approved foot alignment or SpriteFrames resource.")
	for candidate_path: String in CANDIDATES:
		var candidate := lab.get_node_or_null(candidate_path) as Node2D
		if candidate == null:
			return _fail("CharacterScaleLab is missing %s." % candidate_path)
		var expected_size: Vector2 = CANDIDATES[candidate_path]
		var canvas_bounds := candidate.get_node("CanvasBounds") as Line2D
		if _points_size(canvas_bounds.points) != expected_size:
			return _fail("%s canvas bounds do not match %s." % [candidate_path, expected_size])
		var collision := candidate.get_node("CollisionFootprint") as Polygon2D
		if _points_size(collision.polygon) != Vector2(24, 24):
			return _fail("%s no longer displays the existing 24x24 Player collision footprint." % candidate_path)

	lab.queue_free()
	await process_frame
	return true


func _verify_templates() -> bool:
	for path: String in TEMPLATE_PATHS:
		if not FileAccess.file_exists(path):
			return _fail("Missing character production template: %s" % path)
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(path))
		if error != OK:
			return _fail("Character template did not decode: %s" % path)
		if image.get_size() != EXPECTED_SHEET_SIZE:
			return _fail("Character template has wrong dimensions: %s" % path)
		if image.get_width() / CELL_SIZE.x != 4 or image.get_height() / CELL_SIZE.y != 4:
			return _fail("Character template does not contain the expected four rows and four columns: %s" % path)
		if not _has_transparency(image):
			return _fail("Character template does not preserve transparency: %s" % path)
		if not _has_binary_alpha(image):
			return _fail("Character template contains antialiased or smoothed guide alpha: %s" % path)

	for path: String in TEMPLATE_PATHS.slice(0, 2):
		var blank_image := Image.new()
		blank_image.load(ProjectSettings.globalize_path(path))
		if blank_image.get_used_rect().has_area():
			return _fail("Production directional template must contain no final art or in-cell labels: %s" % path)
	return true


func _verify_no_environment_source_master_coupling() -> bool:
	for path: String in [
		"res://scenes/development/CharacterScaleLab.tscn",
		"res://tools/art/create_caden_character_templates_v1.py",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return _fail("Could not inspect character visual artifact: %s" % path)
		var text := file.get_as_text()
		for forbidden: String in [
			"source_art/caden/terrain",
			"source_art/caden/architecture",
			"source_art/caden/nature",
			"source_art/caden/props",
			"source_art/caden/accents",
		]:
			if forbidden in text:
				return _fail("Character visual artifact references an environment source master directly: %s" % path)
	return true


func _points_size(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return maximum - minimum


func _has_transparency(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a == 0.0:
				return true
	return false


func _has_binary_alpha(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha != 0.0 and alpha != 1.0:
				return false
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
