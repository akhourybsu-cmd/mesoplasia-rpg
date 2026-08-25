extends SceneTree

const TILESET_PATH := "res://assets/tilesets/caden/terrain/wayfarers_approach_road_runtime_v1.tres"
const ROAD_SCENE_PATH := "res://scenes/world/caden/wayfarers_approach/WayfarersRoadLayer.tscn"
const SHARED_TERRAIN_TILESET_PATH := "res://assets/tilesets/caden/terrain/caden_terrain_runtime_v1_1.tres"
const GROUND_SCENE_PATH := "res://scenes/world/caden/wayfarers_approach/WayfarersGroundLayer.tscn"

const TERRAIN_TEXTURES: Array[String] = [
	"res://assets/environments/caden/wayfarers_approach/terrain/road_horizontal_continuous_1024_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_vertical_continuous_256_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_t_junction_overlay_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_endcap_horizontal_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_endcap_vertical_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_outer_nw_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_inner_ne_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_inner_nw_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_outer_ne_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_split_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_outer_sw_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_inner_se_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_inner_sw_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_outer_se_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_corner_split_south_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/grass_edge_horizontal_a_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/grass_edge_horizontal_b_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/grass_edge_horizontal_c_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/grass_edge_vertical_a_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/grass_edge_vertical_b_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/wheel_ruts_straight_a_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/wheel_ruts_curve_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/wheel_ruts_straight_b_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/wheel_ruts_straight_c_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/footprints_scatter_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_wear_scatter_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_wear_patch_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/rest_field_trampled_a_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/rest_field_dirt_a_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/rest_field_trampled_b_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/rest_field_trampled_c_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/rest_field_straw_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/rest_field_mud_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/edge_detail_grass_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/edge_detail_flowers_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/edge_detail_stones_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_horizontal_wide_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_vertical_wide_v1.png",
	"res://assets/environments/caden/wayfarers_approach/terrain/road_t_junction_v1.png",
]

const TEXTURE_ORIGINS := {
	0: Vector2i(16, 16),
	1: Vector2i(16, 16),
	2: Vector2i(16, -14),
	4: Vector2i(16, 28),
}


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	for source_id in TERRAIN_TEXTURES.size():
		var texture := load(TERRAIN_TEXTURES[source_id]) as Texture2D
		if texture == null:
			_fail("Unable to load imported terrain texture %s" % TERRAIN_TEXTURES[source_id])
			return
		var atlas_source := TileSetAtlasSource.new()
		atlas_source.texture = texture
		atlas_source.texture_region_size = texture.get_size()
		atlas_source.create_tile(Vector2i.ZERO)
		var tile_data := atlas_source.get_tile_data(Vector2i.ZERO, 0)
		tile_data.texture_origin = TEXTURE_ORIGINS.get(source_id, Vector2i.ZERO)
		tile_set.add_source(atlas_source, source_id)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TILESET_PATH.get_base_dir()))
	var result := ResourceSaver.save(tile_set, TILESET_PATH)
	if result != OK:
		_fail("Unable to save road TileSet: %s" % error_string(result))
		return
	tile_set = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	if tile_set == null:
		_fail("Unable to reload external road TileSet")
		return

	var root_node := Node2D.new()
	root_node.name = "WayfarersRoadLayer"
	_add_layer(root_node, "MainCarriageRoad", tile_set, [
		{"cell": Vector2i(15, 9), "source": 0},
	], Vector2(0, 32))
	_add_layer(root_node, "NorthConnector", tile_set, [
		{"cell": Vector2i(15, 3), "source": 1},
	], Vector2(32, 0))
	_add_layer(root_node, "TJunction", tile_set, [
		{"cell": Vector2i(15, 9), "source": 2},
	], Vector2(32, -20))
	_add_layer(root_node, "LowerYardTransition", tile_set, [
		{"cell": Vector2i(15, 17), "source": 4},
	], Vector2(32, 96))

	var packed := PackedScene.new()
	result = packed.pack(root_node)
	if result != OK:
		_fail("Unable to pack road scene: %s" % error_string(result))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROAD_SCENE_PATH.get_base_dir()))
	result = ResourceSaver.save(packed, ROAD_SCENE_PATH)
	if result != OK:
		_fail("Unable to save road scene: %s" % error_string(result))
		return
	result = _build_ground_scene()
	if result != OK:
		_fail("Unable to save shared Caden ground scene: %s" % error_string(result))
		return
	print("tileset=%s" % TILESET_PATH)
	print("road_scene=%s" % ROAD_SCENE_PATH)
	print("ground_scene=%s" % GROUND_SCENE_PATH)
	root_node.free()
	quit(0)


func _build_ground_scene() -> Error:
	var shared_tile_set := load(SHARED_TERRAIN_TILESET_PATH) as TileSet
	if shared_tile_set == null:
		return ERR_CANT_OPEN
	var root_node := Node2D.new()
	root_node.name = "WayfarersGroundLayer"
	var layer := TileMapLayer.new()
	layer.name = "VariedGrass"
	layer.tile_set = shared_tile_set
	root_node.add_child(layer)
	layer.owner = root_node
	for y in 20:
		for x in 32:
			# Stable variation prevents a visible 32-pixel repeat while reusing the
			# shared Caden grass tiles and remaining deterministic across rebuilds.
			var variant := (x * 7 + y * 11 + (x * y) % 5) % 8
			layer.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0), 0)
	var packed := PackedScene.new()
	var result := packed.pack(root_node)
	if result == OK:
		result = ResourceSaver.save(packed, GROUND_SCENE_PATH)
	root_node.free()
	return result


func _add_layer(parent: Node2D, node_name: String, tile_set: TileSet, placements: Array, offset := Vector2.ZERO) -> void:
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.tile_set = tile_set
	layer.position = offset
	parent.add_child(layer)
	layer.owner = parent
	for placement: Dictionary in placements:
		layer.set_cell(placement["cell"], placement["source"], Vector2i.ZERO, 0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
