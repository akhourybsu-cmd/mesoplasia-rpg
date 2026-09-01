extends SceneTree

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const SPECS := [
	{
		"zone": "Town Square",
		"scene": preload("res://scenes/world/caden/TownSquare.tscn"),
		"prop": "BlueprintV3CivicGarden/CivicGardenEdge",
		"collision": "LowWallCollision",
		"approach_start": Vector2(696, 304),
		"bypass_start": Vector2(640, 304),
		"motion": Vector2(0, -80),
	},
	{
		"zone": "Residential",
		"scene": preload("res://scenes/world/caden/Residential.tscn"),
		"prop": "ZoneIdentityV1/DomesticUtilityYard",
		"collision": "StorageCollision",
		"approach_start": Vector2(302, 728),
		"bypass_start": Vector2(250, 728),
		"motion": Vector2(0, -80),
	},
	{
		"zone": "Commons",
		"scene": preload("res://scenes/world/caden/Commons.tscn"),
		"prop": "ZoneIdentityV1/NaturalBoundaryMass",
		"collision": "CoreCollision",
		"approach_start": Vector2(162, 604),
		"bypass_start": Vector2(220, 604),
		"motion": Vector2(0, -80),
	},
]


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	for spec: Dictionary in SPECS:
		if not await _verify_zone_physics(spec):
			return
	print("PASS: Blueprint v3 active compositions block the real Player at structural footprints, retain adjacent bypass clearance, and support both depth-order states.")
	quit(0)


func _verify_zone_physics(spec: Dictionary) -> bool:
	var zone := (spec["scene"] as PackedScene).instantiate() as Node2D
	root.add_child(zone)
	var prop := zone.get_node_or_null(spec["prop"]) as StaticBody2D
	var collision_shape := prop.get_node_or_null(spec["collision"]) as CollisionShape2D if prop != null else null
	if prop == null or collision_shape == null or not collision_shape.shape is RectangleShape2D:
		return _fail("%s approved structural collision is missing." % spec["zone"])
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	root.add_child(player)
	player.set_physics_process(false)
	(player.get_node("Camera2D") as Camera2D).enabled = false
	(player.get_node("InteractionDetector") as Area2D).process_mode = Node.PROCESS_MODE_DISABLED
	var player_shape := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	if player_shape == null or player_shape.size != Vector2(24, 24):
		return _fail("The runtime Player footprint changed from 24x24.")
	await physics_frame
	await physics_frame

	player.position = spec["approach_start"]
	var collision := player.move_and_collide(spec["motion"], true)
	if collision == null or collision.get_collider() != prop:
		return _fail("%s structural footprint did not block the approaching Player." % spec["zone"])
	player.position = spec["bypass_start"]
	var bypass_collision := player.move_and_collide(spec["motion"], true)
	if bypass_collision != null:
		return _fail("%s adjacent bypass lane is not clear; collided with %s." % [spec["zone"], bypass_collision.get_collider()])

	prop.call("update_depth_for_player", prop.global_position.y - 32.0)
	if prop.z_index != 11:
		return _fail("%s composition did not render in front of a player behind it." % spec["zone"])
	prop.call("update_depth_for_player", prop.global_position.y + 32.0)
	if prop.z_index != 9:
		return _fail("%s composition did not render behind a player in front of it." % spec["zone"])

	player.queue_free()
	zone.queue_free()
	await process_frame
	return true


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
