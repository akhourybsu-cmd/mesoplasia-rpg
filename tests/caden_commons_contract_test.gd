extends SceneTree

const COMMONS_SCENE := preload("res://scenes/world/caden/Commons.tscn")
const EXPECTED_OBSTACLES := {
	"TreeCluster01": Vector2(192, 160),
	"TreeCluster02": Vector2(800, 224),
	"TreeCluster03": Vector2(768, 512),
	"RockCluster": Vector2(288, 544),
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var commons := COMMONS_SCENE.instantiate() as Node2D
	root.add_child(commons)
	await process_frame
	if commons.get("camera_bounds") != Rect2i(0, 0, 1024, 704):
		_fail("Commons camera bounds changed.")
		return
	var west_path := commons.get_node("WestPath") as Polygon2D
	var north_path := commons.get_node("NorthPath") as Polygon2D
	var quiet_green := commons.get_node("QuietGreen") as Polygon2D
	if west_path.polygon != PackedVector2Array([Vector2(0, 288), Vector2(512, 288), Vector2(512, 416), Vector2(0, 416)]):
		_fail("Commons Town Square route changed.")
		return
	if north_path.polygon != PackedVector2Array([Vector2(448, 0), Vector2(576, 0), Vector2(576, 416), Vector2(448, 416)]):
		_fail("Commons Residential route changed.")
		return
	if quiet_green.polygon != PackedVector2Array([Vector2(608, 128), Vector2(928, 128), Vector2(928, 576), Vector2(608, 576)]):
		_fail("Commons Quiet Green reserved area changed.")
		return

	var greenery := commons.get_node("Greenery")
	if greenery.get_child_count() != 4:
		_fail("Commons fixed obstacle count changed.")
		return
	for obstacle_name: String in EXPECTED_OBSTACLES:
		var obstacle := greenery.get_node(obstacle_name) as StaticBody2D
		if obstacle.position != EXPECTED_OBSTACLES[obstacle_name] or not obstacle.has_method("update_depth_for_player"):
			_fail("Commons obstacle anchor or sorting contract changed: %s" % obstacle_name)
			return
		if (obstacle.get_node("Visual") as CanvasItem).visible:
			_fail("Commons obstacle placeholder remains visible: %s" % obstacle_name)
			return
	var grove_shapes := greenery.get_node("TreeCluster01").find_children("*", "CollisionShape2D", true, false)
	if grove_shapes.size() != 3:
		_fail("Commons grove must use three precise trunk collisions.")
		return
	for collision: CollisionShape2D in grove_shapes:
		var grove_shape := collision.shape as RectangleShape2D
		if grove_shape == null or grove_shape.size != Vector2(14, 12):
			_fail("Commons grove trunk collision changed.")
			return
	for obstacle_name in ["TreeCluster02", "TreeCluster03"]:
		var shape := (greenery.get_node("%s/CollisionShape2D" % obstacle_name) as CollisionShape2D).shape as RectangleShape2D
		if shape == null or shape.size != Vector2(24, 18):
			_fail("Commons tree trunk collision changed: %s" % obstacle_name)
			return
	var rock_shape := (greenery.get_node("RockCluster/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	if rock_shape == null or rock_shape.size != Vector2(40, 20):
		_fail("Commons rock collision is not object-specific.")
		return

	var local := commons.get_node("CommonsLocal")
	if local.position != Vector2(704, 400) or local.get("conversation") == null or local.get("facing_direction") != Vector2.LEFT or not local.get("character_visual_enabled"):
		_fail("Commons resident position, dialogue, or facing changed.")
		return
	if (commons.get_node("EntryPoints/from_town_square") as Marker2D).position != Vector2(128, 352):
		_fail("Commons Town Square entry changed.")
		return
	if (commons.get_node("EntryPoints/from_residential") as Marker2D).position != Vector2(512, 128):
		_fail("Commons Residential entry changed.")
		return
	var town_exit := commons.get_node("Exits/ToTownSquare") as Area2D
	var residential_exit := commons.get_node("Exits/ToResidential") as Area2D
	if town_exit.position != Vector2(64, 352) or town_exit.get("destination_zone") != &"town_square" or town_exit.get("destination_entry") != &"from_commons":
		_fail("Commons Town Square exit changed.")
		return
	if residential_exit.position != Vector2(512, 64) or residential_exit.get("destination_zone") != &"residential" or residential_exit.get("destination_entry") != &"from_commons":
		_fail("Commons Residential exit changed.")
		return
	var horizontal_shape := (town_exit.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	var vertical_shape := (residential_exit.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	if horizontal_shape == null or horizontal_shape.size != Vector2(96, 128) or vertical_shape == null or vertical_shape.size != Vector2(128, 96):
		_fail("Commons transition collision changed.")
		return
	if (commons.get_node("ZoneLabel") as CanvasItem).visible:
		_fail("Commons developer label remains visible.")
		return

	print("PASS: Commons bounds, routes, Quiet Green, fixed anchors, precise collision, resident, entries, and exits.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
