extends SceneTree

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const LAB_SCENE := preload("res://scenes/development/CharacterScaleLab.tscn")
const PLAYER_FRAMES := preload("res://assets/characters/caden/player/caden_player_sprite_frames_v1.tres")
const PROJECT_CONFIGURATION := preload("res://tests/project_configuration_test_helper.gd")

const SOURCE_PATH := "res://assets/source_art/caden/characters/player/caden_player_character_master_v3.png"
const SOURCE_SHA256 := "02cf142c088af1852cd08b90db231cbfbc72c2b71c3246d45d1d4cdaa84b9ab8"
const SOURCE_SIZE := Vector2i(1060, 1484)
const SOURCE_CELL_SIZE := Vector2i(265, 371)
const RUNTIME_PATH := "res://assets/characters/caden/player/caden_player_runtime_v1.png"
const RUNTIME_SHA256 := "9f692386e678528708de983463473db1fae63f72160244d52295b1af3e1be282"
const RUNTIME_SIZE := Vector2i(160, 224)
const RUNTIME_CELL_SIZE := Vector2i(40, 56)
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle_down",
	&"idle_left",
	&"idle_right",
	&"idle_up",
	&"walk_down",
	&"walk_left",
	&"walk_right",
	&"walk_up",
]
const DIRECTION_ROWS := {
	"down": 0,
	"left": 1,
	"right": 2,
	"up": 3,
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var project_configuration_error: String = PROJECT_CONFIGURATION.verify()
	if not project_configuration_error.is_empty():
		_fail(project_configuration_error)
		return
	if not _verify_v3_source_master():
		return
	if not _verify_runtime_sheet():
		return
	if not _verify_sprite_frames_contract():
		return
	if not await _verify_scale_lab_runtime():
		return
	if not await _verify_player_integration():
		return

	print("PASS: Caden Player v3 repair, 40x56 runtime sheet, directional SpriteFrames, scale-lab gate, and Player visual-only integration.")
	quit(0)


func _verify_v3_source_master() -> bool:
	if not FileAccess.file_exists(SOURCE_PATH):
		return _fail("Missing immutable Caden Player v3 source master.")
	if FileAccess.get_sha256(SOURCE_PATH) != SOURCE_SHA256:
		return _fail("Caden Player v3 source-master hash changed.")

	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(SOURCE_PATH)) != OK:
		return _fail("Caden Player v3 source master did not decode.")
	if image.get_size() != SOURCE_SIZE or image.get_format() != Image.FORMAT_RGBA8:
		return _fail("Caden Player v3 source master must be RGBA 1060x1484.")

	for row in range(4):
		for column in range(4):
			if _strong_alpha_touches_source_boundary(image, column, row):
				return _fail("Caden Player v3 source frame r%dc%d touches a 265x371 cell boundary." % [row + 1, column + 1])

	for column in range(4):
		var bounds := _local_opaque_bounds(image, column, 3, SOURCE_CELL_SIZE, 0.5)
		if not bounds.has_area() or bounds.position.y < 12:
			return _fail("Caden Player v3 up frame c%d lacks the approved crown headroom." % [column + 1])

	var artifact_origin := Vector2i(SOURCE_CELL_SIZE.x, SOURCE_CELL_SIZE.y * 2)
	for local_x in range(119, 126):
		if image.get_pixel(artifact_origin.x + local_x, artifact_origin.y + 370).a > 0.0:
			return _fail("The documented r3c2 edge artifact reappeared at x%d y370." % local_x)
	return true


func _verify_runtime_sheet() -> bool:
	if not FileAccess.file_exists(RUNTIME_PATH):
		return _fail("Missing approved Caden Player runtime sheet.")
	if FileAccess.get_sha256(RUNTIME_PATH) != RUNTIME_SHA256:
		return _fail("Caden Player runtime-sheet hash changed.")

	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(RUNTIME_PATH)) != OK:
		return _fail("Caden Player runtime sheet did not decode.")
	if image.get_size() != RUNTIME_SIZE or image.get_format() != Image.FORMAT_RGBA8:
		return _fail("Caden Player runtime sheet must be RGBA 160x224.")
	if not _has_binary_alpha(image):
		return _fail("Caden Player runtime sheet must preserve binary pixel-art alpha.")

	for row in range(4):
		for column in range(4):
			var bounds := _local_opaque_bounds(image, column, row, RUNTIME_CELL_SIZE, 0.5)
			if not bounds.has_area():
				return _fail("Caden Player runtime frame r%dc%d is empty." % [row + 1, column + 1])
			if bounds.end.y != RUNTIME_CELL_SIZE.y:
				return _fail("Caden Player runtime frame r%dc%d is not aligned to baseline y55." % [row + 1, column + 1])
			if bounds.size.x < 20 or bounds.size.x > 25 or bounds.size.y < 49 or bounds.size.y > 53:
				return _fail("Caden Player runtime frame r%dc%d left the approved silhouette range." % [row + 1, column + 1])
			var horizontal_center := bounds.position.x + (bounds.size.x - 1) * 0.5
			if absf(horizontal_center - 19.5) > 0.5:
				return _fail("Caden Player runtime frame r%dc%d is not centered consistently." % [row + 1, column + 1])
	return true


func _verify_sprite_frames_contract() -> bool:
	var animation_names := PLAYER_FRAMES.get_animation_names()
	if animation_names.size() != REQUIRED_ANIMATIONS.size():
		return _fail("Caden Player SpriteFrames must contain exactly eight directional animations.")

	for animation_name in REQUIRED_ANIMATIONS:
		if not PLAYER_FRAMES.has_animation(animation_name):
			return _fail("Caden Player SpriteFrames is missing %s." % animation_name)
		var walking := animation_name.begins_with("walk_")
		var expected_count := 4 if walking else 1
		if PLAYER_FRAMES.get_frame_count(animation_name) != expected_count:
			return _fail("Caden Player animation %s has the wrong frame count." % animation_name)
		if PLAYER_FRAMES.get_animation_loop(animation_name) != walking:
			return _fail("Caden Player animation %s has the wrong loop setting." % animation_name)
		if not is_equal_approx(PLAYER_FRAMES.get_animation_speed(animation_name), 8.0):
			return _fail("Caden Player animation %s must run at 8 FPS." % animation_name)

		var direction := String(animation_name).trim_prefix("idle_").trim_prefix("walk_")
		var row := DIRECTION_ROWS[direction] as int
		for frame_index in range(expected_count):
			var expected_column := frame_index if walking else 0
			var texture := PLAYER_FRAMES.get_frame_texture(animation_name, frame_index) as AtlasTexture
			if texture == null:
				return _fail("Caden Player animation %s frame %d is not an AtlasTexture." % [animation_name, frame_index])
			var expected_region := Rect2(expected_column * 40, row * 56, 40, 56)
			if texture.region != expected_region:
				return _fail("Caden Player animation %s frame %d maps to the wrong cell." % [animation_name, frame_index])
			if texture.atlas == null or texture.atlas.resource_path != RUNTIME_PATH:
				return _fail("Caden Player animation %s does not reference the approved runtime sheet." % animation_name)
	return true


func _verify_scale_lab_runtime() -> bool:
	var lab := LAB_SCENE.instantiate() as Node2D
	root.add_child(lab)
	await process_frame

	var candidate := lab.get_node_or_null("Candidates/RuntimeCandidateV1") as Node2D
	if candidate == null:
		return _fail("CharacterScaleLab is missing RuntimeCandidateV1.")
	var sprite := candidate.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames != PLAYER_FRAMES:
		return _fail("CharacterScaleLab runtime candidate does not use the approved SpriteFrames.")
	if candidate.position != Vector2(80, 340) or sprite.position != Vector2(0, -28):
		return _fail("CharacterScaleLab runtime candidate lost its approved foot alignment.")
	var canvas := candidate.get_node("CanvasBounds") as Line2D
	if _points_size(canvas.points) != Vector2(RUNTIME_CELL_SIZE):
		return _fail("CharacterScaleLab runtime candidate no longer shows the 40x56 canvas.")
	var collision := candidate.get_node("CollisionFootprint") as Polygon2D
	if _points_size(collision.polygon) != Vector2(24, 24):
		return _fail("CharacterScaleLab runtime candidate no longer shows the 24x24 collision footprint.")

	lab.queue_free()
	await process_frame
	return true


func _verify_player_integration() -> bool:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	root.add_child(player)
	await process_frame

	if not is_equal_approx(player.get("movement_speed") as float, 96.0):
		return _fail("Player movement speed changed during visual integration.")
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	var collision_shape := collision.shape as RectangleShape2D
	if collision.position != Vector2.ZERO or collision_shape == null or collision_shape.size != Vector2(24, 24):
		return _fail("Player collision footprint changed during visual integration.")
	var visual_root := player.get_node("VisualRoot") as Node2D
	var sprite := visual_root.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var fallback := player.get_node("PlaceholderVisual") as Polygon2D
	if visual_root.position != Vector2(0, 12) or sprite.position != Vector2(0, -28):
		return _fail("Player visual hierarchy lost its integer foot alignment.")
	if sprite.sprite_frames != PLAYER_FRAMES or not sprite.visible or fallback.visible:
		return _fail("Player does not use the approved runtime while preserving the hidden fallback.")
	if sprite.animation != &"idle_down":
		return _fail("Player must initialize in idle_down.")

	sprite.call("update_visual_state", Vector2.RIGHT, Vector2.RIGHT)
	if sprite.animation != &"walk_right":
		return _fail("Player movement did not select walk_right.")
	sprite.call("update_visual_state", Vector2.ZERO, Vector2.RIGHT)
	if sprite.animation != &"idle_right":
		return _fail("Player idle did not retain right-facing direction.")
	sprite.call("update_visual_state", Vector2.UP, Vector2.UP)
	if sprite.animation != &"walk_up":
		return _fail("Player movement did not select walk_up.")

	player.set("facing_direction", Vector2.LEFT)
	sprite.call("update_visual_state", Vector2.LEFT, Vector2.LEFT)
	player.call("lock_controls", &"character_runtime_test")
	await physics_frame
	await physics_frame
	if player.velocity != Vector2.ZERO or player.get("facing_direction") != Vector2.LEFT:
		return _fail("Player control lock changed velocity or facing behavior.")
	if sprite.animation != &"idle_left":
		return _fail("Player control lock did not settle on the retained idle direction.")
	player.call("unlock_controls", &"character_runtime_test")

	player.queue_free()
	await process_frame
	return true


func _strong_alpha_touches_source_boundary(image: Image, column: int, row: int) -> bool:
	var origin := Vector2i(column * SOURCE_CELL_SIZE.x, row * SOURCE_CELL_SIZE.y)
	for local_x in range(SOURCE_CELL_SIZE.x):
		if image.get_pixel(origin.x + local_x, origin.y).a >= 0.5:
			return true
		if image.get_pixel(origin.x + local_x, origin.y + SOURCE_CELL_SIZE.y - 1).a >= 0.5:
			return true
	for local_y in range(SOURCE_CELL_SIZE.y):
		if image.get_pixel(origin.x, origin.y + local_y).a >= 0.5:
			return true
		if image.get_pixel(origin.x + SOURCE_CELL_SIZE.x - 1, origin.y + local_y).a >= 0.5:
			return true
	return false


func _local_opaque_bounds(
	image: Image,
	column: int,
	row: int,
	cell_size: Vector2i,
	alpha_threshold: float
) -> Rect2i:
	var minimum := cell_size
	var maximum := Vector2i(-1, -1)
	var origin := Vector2i(column * cell_size.x, row * cell_size.y)
	for local_y in range(cell_size.y):
		for local_x in range(cell_size.x):
			if image.get_pixel(origin.x + local_x, origin.y + local_y).a < alpha_threshold:
				continue
			minimum.x = mini(minimum.x, local_x)
			minimum.y = mini(minimum.y, local_y)
			maximum.x = maxi(maximum.x, local_x)
			maximum.y = maxi(maximum.y, local_y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _has_binary_alpha(image: Image) -> bool:
	var saw_transparent := false
	var saw_opaque := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if is_zero_approx(alpha):
				saw_transparent = true
			elif is_equal_approx(alpha, 1.0):
				saw_opaque = true
			else:
				return false
	return saw_transparent and saw_opaque


func _points_size(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return maximum - minimum


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
