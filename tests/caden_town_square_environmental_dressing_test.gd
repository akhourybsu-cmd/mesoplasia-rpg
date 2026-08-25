extends SceneTree

const TOWN_SQUARE_SCENE := preload("res://scenes/world/caden/TownSquare.tscn")

# The user had an unrelated project.godot working-tree change before this pass.
# This hash records that pre-pass baseline so the dressing work cannot alter it.
const EXPECTED_PROJECT_SHA256 := "d7d8343041bef8aa48c4f540a5ccbb8163832d148134662a5f39252b68044990"
const EXPECTED_RUNTIME_HASHES := {
	"res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.png": "bf97e3cb3df741b0290cbac648bb356a33eb65354f79b094f87466f87c82559a",
	"res://assets/environments/caden/architecture/town_square/town_square_building_northwest_v1_1.png": "55ee5c5c35e2f646e5b8b2295680111eba56e71168d5efed5b246ae9f2c0f770",
	"res://assets/environments/caden/architecture/town_square/town_square_building_southwest_v1_1.png": "790f375a5549e91af59950e91c648fc6c547fc2d1b092591dc33a56ba59b6780",
	"res://assets/environments/caden/architecture/town_square/town_square_building_northeast_v1_1.png": "22c8515c03591d869174392fe83ee2a90c909f6c58b70820fb9a6ea60792d1a6",
	"res://assets/environments/caden/architecture/town_square/town_square_building_southeast_v1_1.png": "68c8686dca3dae8f3173415a094c824f8601021ab51b6904968deef5e84ab487",
	"res://assets/environments/caden/architecture/town_square/town_square_building_south_v1_1.png": "0693a95af32429919b54c72b0d4e5817298d6bd37d06897d7009579bc5394caa",
	"res://assets/environments/caden/nature/ground/caden_nature_ground_runtime_v1.png": "9a9cf0889528763c2cdbdbe4b7d5fb755c5df9247529f9dcf2e5e5864190f045",
	"res://assets/environments/caden/nature/trees/caden_tree_medium_01_v1.png": "4437f65ccff775395b4ac73dd1673ab7da65d7afdbd80256cd9325d09172c828",
	"res://assets/environments/caden/nature/trees/caden_tree_medium_02_v1.png": "c062eca53c29d4f734716e2708c48acb35bfe86cafbfb71c453a667096f735d9",
	"res://assets/environments/caden/nature/trees/caden_tree_small_01_v1.png": "099d85522798fa45f68b20e9b23afab2f171936c7279b0f96795d808d78bce78",
	"res://assets/environments/caden/nature/trees/caden_tree_small_02_v1.png": "907f22a378b064941e7bf92aba877dd1ac9eb08e31f3b2c29c494d16954d9d1e",
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_01_v1.png": "71d4f3883c0cb48ba20b05dea8288fc877b4031aeda2fe4a137141317e6b9c56",
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_02_v1.png": "b7aa6706bd868e828e7c1843535b484eefe2b7416a172cf454c19d85ccb60fe5",
	"res://assets/environments/caden/nature/shrubs/caden_bush_medium_03_v1.png": "d488ebf7a5e5a1b0e198e098c977047d7337c285df376ae75966255a5249cc28",
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_01_v1.png": "1b6f822eeb9344af4964b798596d8397d3bbb46c0df8b094ca1de4176d4e3d51",
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_02_v1.png": "9f0d898a81bce8dbb726e2d132b50ad0fef987cbce8f4aa46af8184d1ba3ed4c",
	"res://assets/environments/caden/nature/shrubs/caden_shrub_small_03_v1.png": "6f18c869d556e9d37128a8cc78a2dfcd6348fe078c9293189ff89d575f6d5113",
	"res://assets/environments/caden/nature/rocks/caden_rock_small_01_v1.png": "1314c6e6e33e4e32588980a7d74821f7ca0f8d27002801926ed45f1c861f4887",
	"res://assets/environments/caden/nature/rocks/caden_rock_small_02_v1.png": "db8d584dcb72613b99e58dfa0d3ec7c034bb3d9ac8735bc22c6df06252b8beb6",
	"res://assets/environments/caden/nature/rocks/caden_rock_cluster_01_v1.png": "1918ff6469b3684e84aba4c5ea6d7437d87894f280c84b5cf2fab0d629927660",
	"res://assets/environments/caden/props/seating/caden_bench_01_v1.png": "49c5ec39182644f034d691626af90770084b3a5924c6dc2f4e42410868e35b79",
	"res://assets/environments/caden/props/seating/caden_bench_02_v1.png": "b5363f4e1616c517864e717f3f88b5596a8f9bb516d6e8f82d0f77885bd075df",
	"res://assets/environments/caden/props/lighting/caden_lantern_post_01_v1.png": "705640a25a52bfddaf1dd624b2e301d6e01c6eaf88cfee717a7f6b6e0e341c59",
	"res://assets/environments/caden/props/lighting/caden_ground_lantern_01_v1.png": "4fcdf7d84a73a6026cd4cd38e72d5a6e482df9a621693682a3e6abc01df2908c",
	"res://assets/environments/caden/props/fences/caden_fence_straight_01_v1.png": "3f2c330f73edcea4cbf438eff7a9da3cff83a800df304bca3105578ac96065bf",
	"res://assets/environments/caden/props/fences/caden_fence_corner_01_v1.png": "1e5594b37e9340155861839c4124215ba13a162dbadd73e1966261a8f548c637",
	"res://assets/environments/caden/props/fences/caden_fence_gate_01_v1.png": "876bbd3f59c18e969294248a9ddea6dabffe5466cf85f1119811074ccf77a35c",
	"res://assets/environments/caden/props/fences/caden_fence_end_01_v1.png": "2e4f396a9241f0d86916fb49f8a31493e0166270c35fa4ded91877b7585919ef",
	"res://assets/environments/caden/props/planters/caden_planter_box_01_v1.png": "27bd2c5c79206ae766d8b36b21431e0d9bf6e67db5a6da22d1e55d681a7d3782",
	"res://assets/environments/caden/props/planters/caden_planter_box_02_v1.png": "c795d44f6d42242f9dbd88df45632e8b0fc8822e2d8da8c5a33dbaef42a6f7c8",
	"res://assets/environments/caden/props/storage/caden_barrel_01_v1.png": "6ba3230d218aa0659c3fe2d22d4f74afb5c6019f461155434b3b0bcfdd8c1e55",
	"res://assets/environments/caden/props/storage/caden_sack_cluster_01_v1.png": "df6d76760b092a75753f8ea10889416e6a14452948e1184b586283679f8bad95",
	"res://assets/environments/caden/props/storage/caden_storage_cluster_01_v1.png": "825732a76e08e1bacdd635ad42ba9227e0c205cd90a15521caea5db905d668c0",
	"res://assets/environments/caden/props/travel/caden_luggage_bundle_01_v1.png": "147b1345512ac5faf2a1754e2e19109a83b460a3b9cee5bb5810fd55994367d1",
	"res://assets/environments/caden/props/travel/caden_travel_pack_01_v1.png": "8d74fb7dc0f439bfb113b7bd2715f672e311273e90468f0a4cb3f3dd099a9caf",
	"res://assets/environments/caden/accents/edenite/caden_edenite_lantern_01_v1.png": "18ce8e4b5066cb228e589e7f9f0cee4dd07fab18e8e9c45f4e12f430a12c36ad",
	"res://assets/environments/caden/accents/edenite/caden_edenite_stone_fixture_01_v1.png": "a82a235360981dff5760934b54131725e9911ac849500ec2dadb3edf7963fb87",
	"res://assets/environments/caden/accents/edenite/caden_edenite_small_fixture_01_v1.png": "b91bc8eb4bb6ae7c86fdd266468549eefc7f648a912f72e09e7d5448215c94ae",
	"res://assets/environments/caden/accents/festival/caden_festival_drape_01_v1.png": "bf5d055d49f0f2502c7dd8d2a99d340a455dc36645416627e69d8a798f317682",
	"res://assets/environments/caden/accents/festival/caden_festival_drape_02_v1.png": "7b3c5e8be8b4975302d5d6356b4ad2b3018c492c813f609e9b7e04355b09756a",
	"res://assets/environments/caden/accents/festival/caden_festival_bunting_01_v1.png": "6077f2b1a34e68cafd676ebd46a4423b5c2076f0ad2715c997c8081a77e8e702",
	"res://assets/environments/caden/accents/festival/caden_festival_bunting_02_v1.png": "83cea2b28180162151a5421a29de1024cda2063aaa465001a5e0a0f02640e27a",
	"res://assets/environments/caden/accents/festival/caden_festival_ribbon_drop_01_v1.png": "7b4878ba8d813707dcb8607ad79f7ffc83f5a5deb352c5e78101197ca2f24373",
	"res://assets/environments/caden/accents/closure/caden_closure_gate_01_v1.png": "e678f42152bca02ad27ed8458e19a053092b480382ac86c1ef57ae01d8ad56a1",
	"res://assets/environments/caden/accents/closure/caden_closure_rope_01_v1.png": "c370800eb12a20286a550f592c1e10863fdc04ec1b044b4f4932b0836413fc1b",
	"res://assets/environments/caden/accents/closure/caden_closure_timbers_01_v1.png": "7c2dd8808384527fe94e2ec407f8b5f256282104e8416f5d25595b82dd9e06fb",
}
const CENTRAL_PLAZA_CALM := Rect2(352, 192, 256, 256)
const RESERVED_SPACE := Rect2(256, 224, 96, 96)
const PRINCIPAL_ROUTES := [
	Rect2(0, 288, 224, 128),
	Rect2(736, 288, 224, 128),
	Rect2(416, 0, 128, 160),
	Rect2(416, 544, 128, 160),
]
const ENTRY_CLEARANCES := [
	Rect2(0, 256, 144, 192),
	Rect2(816, 256, 144, 192),
	Rect2(384, 0, 192, 192),
	Rect2(384, 512, 192, 192),
]
const APPROACH_CLEARANCES := [
	Rect2(96, 160, 96, 64),
	Rect2(96, 608, 96, 64),
	Rect2(784, 256, 96, 64),
	Rect2(768, 608, 96, 64),
	Rect2(304, 656, 96, 48),
	Rect2(240, 400, 96, 96),
	Rect2(624, 208, 96, 96),
]
const LOCKED_SOLIDS := [
	Rect2(0, 0, 960, 32),
	Rect2(0, 672, 960, 32),
	Rect2(0, 0, 32, 704),
	Rect2(928, 0, 32, 704),
	Rect2(64, 64, 160, 96),
	Rect2(64, 512, 160, 96),
	Rect2(768, 160, 128, 96),
	Rect2(736, 512, 160, 96),
	Rect2(288, 592, 128, 64),
	RESERVED_SPACE,
	Rect2(608, 96, 320, 32),
	Rect2(608, 32, 32, 96),
]
const EXPECTED_ENVIRONMENT_COLLIDERS := {
	"EnvironmentalProps/Props/Seating/BenchWest": Vector2(52, 10),
	"EnvironmentalProps/Props/Seating/BenchEast": Vector2(64, 10),
	"EnvironmentalProps/Props/Lighting/LanternNorth": Vector2(12, 10),
	"EnvironmentalProps/Props/Lighting/LanternSouth": Vector2(12, 10),
	"FestivalAndEdenite/EdeniteFixtures/LanternEastPlazaEdge": Vector2(14, 10),
}
const EXPECTED_BUILDINGS := {
	"SolidScenery/Buildings/GenericBuildingNorthwest": [Vector2(144, 112), Vector2(160, 96)],
	"SolidScenery/Buildings/GenericBuildingSouthwest": [Vector2(144, 560), Vector2(160, 96)],
	"SolidScenery/Buildings/GenericBuildingNortheast": [Vector2(832, 208), Vector2(128, 96)],
	"SolidScenery/Buildings/GenericBuildingSoutheast": [Vector2(816, 560), Vector2(160, 96)],
	"SolidScenery/Buildings/GenericBuildingSouth": [Vector2(352, 624), Vector2(128, 64)],
}


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	if not _verify_protected_hashes():
		return
	if not _verify_scene_source_references():
		return
	var town_square := TOWN_SQUARE_SCENE.instantiate() as Node2D
	if town_square == null:
		_fail("Town Square failed to instantiate.")
		return
	root.add_child(town_square)
	await process_frame
	if not _verify_locked_scene_state(town_square):
		return
	if not _verify_composition_structure(town_square):
		return
	var roots := _environment_roots(town_square)
	if roots.is_empty():
		return
	if not _verify_environment_is_visual_only(roots):
		return
	if not _verify_counts_and_clearances(town_square, roots):
		return
	if not _verify_supported_blocking_visuals(town_square):
		return
	if not _verify_premium_cluster_spacing(town_square):
		return
	if not _verify_collision_relationships(town_square, roots):
		return
	if not _verify_fences_and_festival(town_square):
		return
	if not _verify_edenite_density(town_square):
		return
	if not _verify_terrebonne_closure(town_square):
		return
	town_square.queue_free()
	await process_frame
	print("PASS: Caden Town Square composition preserves gameplay geometry while adding plaza hierarchy, grounded buildings, balanced clusters, social NPC anchors, perimeter layering, and a complete Terrebonne closure.")
	quit(0)


func _verify_protected_hashes() -> bool:
	if FileAccess.get_sha256("res://project.godot") != EXPECTED_PROJECT_SHA256:
		return _fail("project.godot changed from the pre-pass working-tree baseline.")
	for path: String in EXPECTED_RUNTIME_HASHES:
		if not FileAccess.file_exists(path):
			return _fail("Missing protected runtime asset: %s" % path)
		if FileAccess.get_sha256(path) != EXPECTED_RUNTIME_HASHES[path]:
			return _fail("Protected runtime asset changed: %s" % path)
	return true


func _verify_scene_source_references() -> bool:
	var scene_file := FileAccess.open("res://scenes/world/caden/TownSquare.tscn", FileAccess.READ)
	if scene_file == null:
		return _fail("Town Square scene could not be read.")
	var scene_text := scene_file.get_as_text()
	if "source_art" in scene_text:
		return _fail("Town Square references a source master directly.")
	return true


func _verify_locked_scene_state(town_square: Node2D) -> bool:
	if town_square.get("camera_bounds") != Rect2i(0, 0, 960, 704):
		return _fail("Town Square camera bounds changed.")
	for path: String in ["TerrainLayers", "Nature", "SolidScenery/Buildings", "EnvironmentalProps", "FestivalAndEdenite", "Actors", "Boundaries", "EntryPoints", "Exits", "DevelopmentLabels"]:
		if town_square.get_node_or_null(path) == null:
			return _fail("Town Square is missing a required broad category: %s" % path)
	if town_square.get_node("Exits").get_child_count() != 4:
		return _fail("Town Square exit count changed.")
	if town_square.get_node("Actors/NPCs").get_child_count() != 5:
		return _fail("Town Square NPC population changed.")
	for path: String in EXPECTED_BUILDINGS:
		var expected: Array = EXPECTED_BUILDINGS[path]
		if not _verify_static_rectangle(town_square.get_node_or_null(path) as StaticBody2D, expected[0], expected[1]):
			return _fail("A locked building footprint changed: %s" % path)
	var expected_tile_counts := {
		"TerrainLayers/BaseTerrainTiles": 660,
		"TerrainLayers/RoadTiles": 116,
		"TerrainLayers/PlazaTiles": 192,
		"TerrainLayers/TerrainTransitions": 16,
		"TerrainLayers/PlazaComposition/TravelCorridors": 24,
		"TerrainLayers/PlazaComposition/ReservedInlay": 9,
	}
	for path: String in expected_tile_counts:
		var layer := town_square.get_node_or_null(path) as TileMapLayer
		if layer == null or layer.get_used_cells().size() != expected_tile_counts[path]:
			return _fail("Locked terrain placement count changed: %s" % path)
	return true


func _verify_composition_structure(town_square: Node2D) -> bool:
	var approaches := town_square.get_node_or_null("TerrainLayers/BuildingApproaches") as Node2D
	if approaches == null or approaches.get_child_count() != 5:
		return _fail("Town Square must retain five visual doorstep approaches.")
	for approach: Node in approaches.get_children():
		if not approach is Polygon2D or approach.get_script() != null:
			return _fail("Building approaches must remain visual-only polygons.")
	for path: String in EXPECTED_BUILDINGS:
		if town_square.get_node_or_null("%s/GroundDarkening" % path) == null:
			return _fail("A building lost its ground-darkening transition: %s" % path)
	var inner_border := town_square.get_node_or_null("TerrainLayers/PlazaComposition/InnerBorder") as Node2D
	if inner_border == null or inner_border.get_child_count() != 8:
		return _fail("The plaza inner border lost one of its eight quiet seam segments.")
	for segment: Node in inner_border.get_children():
		if not segment is Polygon2D or segment.get_script() != null:
			return _fail("The plaza inner border must remain a visual-only stone seam.")

	var inlay := town_square.get_node("TerrainLayers/PlazaComposition/ReservedInlay") as TileMapLayer
	for x: int in range(8, 11):
		for y: int in range(7, 10):
			if inlay.get_cell_source_id(Vector2i(x, y)) != 0:
				return _fail("The reserved 3x3 inlay is incomplete at %s." % Vector2i(x, y))

	var npc_expectations := {
		"SquareLocal": [Vector2(288, 448), null],
		"PassingVisitor": [Vector2(352, 448), null],
		"NorthPlazaWalker": [Vector2(160, 272), 64.0],
		"WestPlazaWalker": [Vector2(752, 352), 96.0],
		"SouthPlazaWalker": [Vector2(656, 496), 64.0],
	}
	for npc_name: String in npc_expectations:
		var npc := town_square.get_node_or_null("Actors/NPCs/%s" % npc_name) as Node2D
		var expected: Array = npc_expectations[npc_name]
		if npc == null or npc.position != expected[0]:
			return _fail("An NPC left its approved activity anchor: %s" % npc_name)
		if expected[1] != null and not is_equal_approx(float(npc.get("patrol_distance")), float(expected[1])):
			return _fail("An ambient NPC patrol left its approved activity cluster: %s" % npc_name)
	return true


func _environment_roots(town_square: Node2D) -> Array[Node]:
	var result: Array[Node] = []
	for path: String in ["Nature", "EnvironmentalProps", "FestivalAndEdenite"]:
		var node := town_square.get_node_or_null(path)
		if node == null:
			_fail("Missing environment category: %s" % path)
			return result
		result.append(node)
	return result


func _verify_environment_is_visual_only(roots: Array[Node]) -> bool:
	for environment_root: Node in roots:
		for node: Node in _descendants(environment_root):
			if node is Area2D:
				return _fail("Environmental dressing added an interaction or trigger area: %s" % node.name)
			if node is RigidBody2D or node is CharacterBody2D or node is AnimatableBody2D:
				return _fail("Environmental dressing added a movable physics body: %s" % node.name)
			if node is Light2D or node is LightOccluder2D:
				return _fail("Environmental dressing added dynamic lighting: %s" % node.name)
			if node is GPUParticles2D or node is CPUParticles2D:
				return _fail("Environmental dressing added particles: %s" % node.name)
			if node.get_script() != null:
				return _fail("Environmental dressing added gameplay logic: %s" % node.name)
			if node is Sprite2D:
				var sprite := node as Sprite2D
				if sprite.texture == null or "source_art" in sprite.texture.resource_path:
					return _fail("Environmental sprite lacks an approved runtime texture: %s" % sprite.name)
	return true


func _verify_counts_and_clearances(town_square: Node2D, roots: Array[Node]) -> bool:
	var nature := town_square.get_node("Nature")
	if nature.get_node("GroundOverlays").get_child_count() != 18:
		return _fail("Nature ground-detail count changed from the retained clustered set.")
	if nature.get_node("LowVegetation").get_child_count() != 18 or nature.get_node("Trees").get_child_count() != 10 or nature.get_node("Rocks").get_child_count() != 3:
		return _fail("Nature category counts changed from the retained clustered set.")
	var props := town_square.get_node("EnvironmentalProps/Props")
	var expected_prop_counts := {"Seating": 2, "Lighting": 3, "Fences": 4, "Planters": 2, "Storage": 3, "Travel": 2}
	for category: String in expected_prop_counts:
		if props.get_node(category).get_child_count() != expected_prop_counts[category]:
			return _fail("Neutral-prop category count changed: %s" % category)

	for environment_root: Node in roots:
		for node: Node in _descendants(environment_root):
			if not node is Sprite2D:
				continue
			var sprite := node as Sprite2D
			var base := sprite.global_position
			if base != base.round():
				return _fail("Environmental placement uses a fractional base: %s" % sprite.name)
			if CENTRAL_PLAZA_CALM.has_point(base):
				return _fail("Environmental dressing enters the calm central plaza: %s" % sprite.name)
			if RESERVED_SPACE.intersects(_sprite_canvas_bounds(sprite)):
				return _fail("Environmental dressing enters the reserved 3x3 space: %s" % sprite.name)
			for protected: Rect2 in ENTRY_CLEARANCES + APPROACH_CLEARANCES:
				if protected.has_point(base):
					return _fail("Environmental base enters an entry, door, or NPC clearance: %s" % sprite.name)
			for route: Rect2 in PRINCIPAL_ROUTES:
				if route.has_point(base):
					return _fail("Environmental base enters a principal 128-pixel route: %s" % sprite.name)
	return true


func _verify_supported_blocking_visuals(town_square: Node2D) -> bool:
	var blocking_paths := [
		"Nature/Trees/TreeWestUpper",
		"Nature/Trees/TreeEastLower",
		"Nature/Trees/TreeWestLower",
		"Nature/Trees/TreeEastUpper",
		"Nature/Trees/SaplingNorthwestFence",
		"Nature/Trees/SaplingNortheast",
		"Nature/LowVegetation/BushNorthwestWest",
		"Nature/LowVegetation/BushNortheastWest",
		"Nature/LowVegetation/BushNorthwestEast",
		"Nature/LowVegetation/BushSoutheastEast",
		"Nature/LowVegetation/BushSouthwestWest",
		"Nature/LowVegetation/BushNortheastEast",
		"Nature/Rocks/RockClusterSoutheastBoundary",
		"EnvironmentalProps/Props/Storage/BarrelSouthwest",
		"EnvironmentalProps/Props/Storage/StorageSouthwest",
		"EnvironmentalProps/Props/Storage/SacksSoutheast",
		"FestivalAndEdenite/EdeniteFixtures/SmallFixtureWestBoundary",
		"FestivalAndEdenite/EdeniteFixtures/StoneFixtureSouthBoundary",
	]
	for path: String in blocking_paths:
		var placement := town_square.get_node_or_null(path) as Node2D
		if placement == null or not _base_is_supported(placement.global_position):
			return _fail("A blocking-looking visual lacks supporting existing collision: %s" % path)
	return true


func _verify_premium_cluster_spacing(town_square: Node2D) -> bool:
	var groups := [
		[
			"EnvironmentalProps/Props/Storage/BarrelSouthwest",
			"EnvironmentalProps/Props/Storage/StorageSouthwest",
			"EnvironmentalProps/Props/Lighting/GroundLanternSouthwest",
		],
		[
			"EnvironmentalProps/Props/Storage/SacksSoutheast",
			"EnvironmentalProps/Props/Travel/TravelPackSoutheast",
		],
	]
	for group: Array in groups:
		var bounds: Array[Rect2] = []
		for path: String in group:
			var sprite := town_square.get_node_or_null(path) as Sprite2D
			if sprite == null:
				return _fail("Premium frontage cluster is missing %s." % path)
			bounds.append(_sprite_canvas_bounds(sprite))
		for index in range(bounds.size()):
			for other_index in range(index + 1, bounds.size()):
				if bounds[index].intersects(bounds[other_index]):
					return _fail("Premium frontage props overlap inside one cluster.")
	var development_labels := town_square.get_node("DevelopmentLabels") as Node2D
	if development_labels.visible:
		return _fail("Development labels still cover the premium Town Square presentation.")
	return true


func _verify_collision_relationships(town_square: Node2D, roots: Array[Node]) -> bool:
	var collision_bodies: Array[StaticBody2D] = []
	for environment_root: Node in roots:
		for node: Node in _descendants(environment_root):
			if node is CollisionObject2D and not node is StaticBody2D:
				return _fail("Environmental collision is not static: %s" % node.name)
			if node is StaticBody2D:
				collision_bodies.append(node as StaticBody2D)
	if collision_bodies.size() != EXPECTED_ENVIRONMENT_COLLIDERS.size():
		return _fail("Environmental collider count changed.")

	var collider_rectangles: Array[Rect2] = []
	for path: String in EXPECTED_ENVIRONMENT_COLLIDERS:
		var body := town_square.get_node_or_null(path) as StaticBody2D
		if body == null:
			return _fail("Missing aligned environmental collider: %s" % path)
		var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var rectangle := collision.shape as RectangleShape2D if collision != null else null
		if rectangle == null or rectangle.size != EXPECTED_ENVIRONMENT_COLLIDERS[path]:
			return _fail("Environmental collider is not the approved primitive size: %s" % path)
		if collision.position != Vector2(0, -5):
			return _fail("Environmental collision no longer aligns to its visual base: %s" % path)
		var collision_rectangle := Rect2(collision.global_position - rectangle.size * 0.5, rectangle.size)
		collider_rectangles.append(collision_rectangle)
		for route: Rect2 in PRINCIPAL_ROUTES:
			if collision_rectangle.intersects(route):
				return _fail("Environmental collision narrows a principal route: %s" % path)
		for protected: Rect2 in ENTRY_CLEARANCES + APPROACH_CLEARANCES:
			if collision_rectangle.intersects(protected):
				return _fail("Environmental collision enters a protected clearance: %s" % path)
		for solid: Rect2 in LOCKED_SOLIDS:
			if _distance_between_rectangles(collision_rectangle, solid) < 64.0:
				return _fail("Environmental collision creates a sub-64-pixel gap to locked geometry: %s" % path)
	for index in range(collider_rectangles.size()):
		for other_index in range(index + 1, collider_rectangles.size()):
			if _distance_between_rectangles(collider_rectangles[index], collider_rectangles[other_index]) < 64.0:
				return _fail("Environmental colliders create a gap narrower than 64 pixels.")
	return true


func _verify_fences_and_festival(town_square: Node2D) -> bool:
	var fences: Array[Node2D] = []
	for path: String in ["EnvironmentalProps/Props/Fences", "FestivalAndEdenite/PerimeterFencing/PlainFences"]:
		for node: Node in town_square.get_node(path).get_children():
			fences.append(node as Node2D)
	if fences.size() != 13:
		return _fail("The perimeter must retain thirteen fence segments.")
	var runs := _group_fence_runs(fences)
	if runs.size() != 4:
		return _fail("The thirteen fences must form four coherent perimeter runs.")
	for run: Array in runs:
		if run.size() < 3:
			return _fail("A perimeter fence run is too short to read coherently.")
		var first := run[0] as Node2D
		var last := run[run.size() - 1] as Node2D
		var first_name := String(first.name)
		var last_name := String(last.name)
		if not _is_fence_termination(first_name) or not _is_fence_termination(last_name):
			return _fail("A perimeter fence run lacks clear termination.")
		for fence: Node2D in run:
			if fence.global_position.y > 32.0 and fence.global_position.y < 672.0:
				return _fail("A fence base left the existing perimeter collision.")

	var overlays := town_square.get_node("FestivalAndEdenite/FestivalFabric/FenceOverlays")
	var decorated_count := overlays.get_child_count()
	var ratio := float(decorated_count) / float(fences.size())
	if ratio < 0.20 or ratio > 0.35 or fences.size() <= decorated_count:
		return _fail("Festival fence coverage left the restrained 20-35 percent range or stopped being a minority.")
	var fence_positions: Array[Vector2] = []
	for fence: Node2D in fences:
		fence_positions.append(fence.global_position)
	for overlay_node: Node in overlays.get_children():
		if fence_positions.find((overlay_node as Node2D).global_position) == -1:
			return _fail("Festival fabric no longer follows a supporting fence.")
	var lantern_decor := town_square.get_node("FestivalAndEdenite/FestivalFabric/LanternDecor")
	if lantern_decor.get_child_count() != 1:
		return _fail("Festival lantern decoration is no longer restrained to one ordinary lantern.")
	if (lantern_decor.get_child(0) as Node2D).global_position != (town_square.get_node("EnvironmentalProps/Props/Lighting/LanternSouth") as Node2D).global_position:
		return _fail("The Festival ribbon no longer follows its supporting ordinary lantern.")
	return true


func _verify_edenite_density(town_square: Node2D) -> bool:
	var fixtures := town_square.get_node("FestivalAndEdenite/EdeniteFixtures")
	if fixtures.get_child_count() != 3:
		return _fail("Town Square should retain exactly three separated Edenite accents.")
	var points: Array[Vector2] = []
	for fixture: Node in fixtures.get_children():
		points.append((fixture as Node2D).global_position)
	var maximum_visible := 0
	for left in range(0, 321):
		for top in range(0, 345):
			var view := Rect2(left, top, 640, 360)
			var visible_count := 0
			for point: Vector2 in points:
				if view.has_point(point):
					visible_count += 1
			maximum_visible = maxi(maximum_visible, visible_count)
	if maximum_visible > 2:
		return _fail("More than two Edenite accents can appear in one 640x360 view.")
	return true


func _verify_terrebonne_closure(town_square: Node2D) -> bool:
	var collision_root := town_square.get_node("SolidScenery/TerrebonneClosure")
	if not _verify_static_rectangle(collision_root.get_node("HorizontalBarrier") as StaticBody2D, Vector2(768, 112), Vector2(320, 32)):
		return _fail("The horizontal Terrebonne closure collision changed.")
	if not _verify_static_rectangle(collision_root.get_node("VerticalBarrier") as StaticBody2D, Vector2(624, 80), Vector2(32, 96)):
		return _fail("The vertical Terrebonne closure collision changed.")
	var art := town_square.get_node("FestivalAndEdenite/TerrebonneClosure")
	if art.get_child_count() != 6:
		return _fail("The closure must retain its corner, gate, rope, timbers, end treatment, and hedge.")
	var horizontal := Rect2(608, 96, 320, 32)
	var vertical := Rect2(608, 32, 32, 96)
	for closure_asset: Node in art.get_children():
		var point := (closure_asset as Node2D).global_position
		if not horizontal.has_point(point) and not vertical.has_point(point):
			return _fail("Closure art no longer aligns with the existing L-shaped collision: %s" % closure_asset.name)
	return true


func _group_fence_runs(fences: Array[Node2D]) -> Array:
	var ordered := fences.duplicate()
	ordered.sort_custom(func(first: Node2D, second: Node2D) -> bool:
		if is_equal_approx(first.global_position.y, second.global_position.y):
			return first.global_position.x < second.global_position.x
		return first.global_position.y < second.global_position.y
	)
	var runs: Array = []
	for fence: Node2D in ordered:
		if runs.is_empty():
			runs.append([fence])
			continue
		var current_run: Array = runs[runs.size() - 1]
		var previous := current_run[current_run.size() - 1] as Node2D
		if not is_equal_approx(previous.global_position.y, fence.global_position.y) or fence.global_position.x - previous.global_position.x > 128.0:
			runs.append([fence])
		else:
			current_run.append(fence)
	return runs


func _is_fence_termination(node_name: String) -> bool:
	return "Corner" in node_name or "End" in node_name or "Gate" in node_name


func _base_is_supported(point: Vector2) -> bool:
	if point.x <= 32.0 or point.x >= 928.0 or point.y <= 32.0 or point.y >= 672.0:
		return true
	for footprint: Rect2 in [
		Rect2(64, 64, 160, 96),
		Rect2(64, 512, 160, 96),
		Rect2(768, 160, 128, 96),
		Rect2(736, 512, 160, 96),
		Rect2(288, 592, 128, 64),
	]:
		if footprint.grow(0.5).has_point(point):
			return true
	return false


func _sprite_canvas_bounds(sprite: Sprite2D) -> Rect2:
	var frame_size := sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
	var scale := sprite.global_scale.abs()
	var size := frame_size * scale
	var center := sprite.global_position + sprite.offset * scale
	return Rect2(center - size * 0.5, size)


func _verify_static_rectangle(body: StaticBody2D, expected_position: Vector2, expected_size: Vector2) -> bool:
	if body == null or body.position != expected_position:
		return false
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var rectangle := collision.shape as RectangleShape2D if collision != null else null
	return rectangle != null and rectangle.size == expected_size


func _distance_between_rectangles(first: Rect2, second: Rect2) -> float:
	var dx := maxf(maxf(second.position.x - first.end.x, first.position.x - second.end.x), 0.0)
	var dy := maxf(maxf(second.position.y - first.end.y, first.position.y - second.end.y), 0.0)
	return Vector2(dx, dy).length()


func _descendants(parent: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in parent.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
