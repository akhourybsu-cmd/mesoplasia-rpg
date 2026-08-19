extends SceneTree

const CADEN_SCENE := preload("res://scenes/world/caden/Caden.tscn")

var _caden: Node2D
var _player: CharacterBody2D
var _player_instance_id: int


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	_caden = CADEN_SCENE.instantiate() as Node2D
	root.add_child(_caden)
	await physics_frame

	_player = _caden.get_node("Player") as CharacterBody2D
	_player_instance_id = _player.get_instance_id()

	if not _check_zone(&"WayfarersApproach", Vector2(128, 320), Rect2i(0, 0, 1024, 640)):
		return
	if not await _travel("Exits/ToMarketplace", &"Marketplace", Vector2(128, 320), Rect2i(0, 0, 896, 640)):
		return
	if not await _travel("Exits/ToWayfarersApproach", &"WayfarersApproach", Vector2(512, 128), Rect2i(0, 0, 1024, 640)):
		return
	if not await _travel("Exits/ToTownSquare", &"TownSquare", Vector2(128, 352), Rect2i(0, 0, 960, 704)):
		return
	if not await _travel("Exits/ToMarketplace", &"Marketplace", Vector2(448, 512), Rect2i(0, 0, 896, 640)):
		return
	if not await _travel("Exits/ToTownSquare", &"TownSquare", Vector2(480, 128), Rect2i(0, 0, 960, 704)):
		return
	if not await _travel("Exits/ToResidential", &"Residential", Vector2(128, 384), Rect2i(0, 0, 1152, 768)):
		return
	if not await _travel("Exits/ToTownSquare", &"TownSquare", Vector2(832, 352), Rect2i(0, 0, 960, 704)):
		return
	if not await _travel("Exits/ToCommons", &"Commons", Vector2(128, 352), Rect2i(0, 0, 1024, 704)):
		return
	if not await _travel("Exits/ToResidential", &"Residential", Vector2(576, 640), Rect2i(0, 0, 1152, 768)):
		return
	if not await _travel("Exits/ToCommons", &"Commons", Vector2(512, 128), Rect2i(0, 0, 1024, 704)):
		return
	if not await _travel("Exits/ToTownSquare", &"TownSquare", Vector2(480, 576), Rect2i(0, 0, 960, 704)):
		return
	if not await _travel("Exits/ToWayfarersApproach", &"WayfarersApproach", Vector2(864, 320), Rect2i(0, 0, 1024, 640)):
		return

	print("PASS: All Caden zone connections, entry placement, persistent Player, and camera limits.")
	quit(0)


func _travel(
	exit_path: NodePath,
	expected_zone_name: StringName,
	expected_position: Vector2,
	expected_bounds: Rect2i
) -> bool:
	var current_zone := _caden.get("_current_zone") as Node2D
	var zone_exit := current_zone.get_node(exit_path) as Area2D
	_player.global_position = zone_exit.global_position

	await physics_frame
	await physics_frame
	await physics_frame

	return _check_zone(expected_zone_name, expected_position, expected_bounds)


func _check_zone(
	expected_zone_name: StringName,
	expected_position: Vector2,
	expected_bounds: Rect2i
) -> bool:
	var current_zone := _caden.get("_current_zone") as Node2D
	if current_zone.name != expected_zone_name:
		return _fail("Expected zone '%s', got '%s'." % [expected_zone_name, current_zone.name])
	if not _player.position.is_equal_approx(expected_position):
		return _fail("Expected Player at %s, got %s." % [expected_position, _player.position])
	if _player.get_instance_id() != _player_instance_id:
		return _fail("Player instance changed during a zone transition.")
	var camera_limits := _player.get("camera_limits") as Rect2i
	if camera_limits != expected_bounds:
		return _fail("Expected camera bounds %s, got %s." % [expected_bounds, camera_limits])

	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
