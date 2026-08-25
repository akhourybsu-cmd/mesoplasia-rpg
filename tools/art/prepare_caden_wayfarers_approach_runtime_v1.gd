extends SceneTree

## Deterministically converts the supplied Wayfarer's Approach presentation sheets
## into nearest-neighbor runtime sprites. The currently supplied sheets are JPEG
## exports on black; alpha is reconstructed only from border-connected matte pixels.

const SOURCE_ROOT := "res://assets/source_art/caden/environment/wayfarers_approach"
const RUNTIME_ROOT := "res://assets/environments/caden/wayfarers_approach"
const MANIFEST_PATH := RUNTIME_ROOT + "/wayfarers_approach_runtime_manifest_v1.json"
const CONCEPT_PATH := SOURCE_ROOT + "/wayfarers_approach_full_zone_concept_v2_greybox_aligned.jpg"
const MATTE_THRESHOLD := 12.0 / 255.0

const SOURCES := {
	"props": SOURCE_ROOT + "/wayfarers_approach_traveler_props_source_v1.jpg",
	"terrain": SOURCE_ROOT + "/wayfarers_approach_road_terrain_source_v1.jpg",
	"structures": SOURCE_ROOT + "/wayfarers_approach_inn_structures_source_v1.jpg",
}

const FAMILY_SCALE := {
	"props": 1.0 / 3.0,
	"terrain": 0.8,
	"structures": 0.5,
}

const SPECS: Array[Dictionary] = [
	# Traveler vehicles and support props.
	{"key": "covered_wagon_side", "family": "props", "crop": Rect2i(12, 35, 410, 245), "path": "props/vehicles/covered_wagon_side_v1.png"},
	{"key": "covered_wagon_rear", "family": "props", "crop": Rect2i(448, 2, 168, 274), "path": "props/vehicles/covered_wagon_rear_v1.png"},
	{"key": "supply_cart_open", "family": "props", "crop": Rect2i(660, 108, 268, 160), "path": "props/vehicles/supply_cart_open_v1.png"},
	{"key": "handcart", "family": "props", "crop": Rect2i(970, 140, 208, 128), "path": "props/vehicles/handcart_v1.png"},
	{"key": "hitching_rail_long", "family": "props", "crop": Rect2i(32, 280, 290, 86), "path": "props/fences/hitching_rail_long_v1.png"},
	{"key": "hitching_rail_short", "family": "props", "crop": Rect2i(455, 278, 170, 88), "path": "props/fences/hitching_rail_short_v1.png"},
	{"key": "hitching_rail_rope", "family": "props", "crop": Rect2i(858, 278, 178, 92), "path": "props/fences/hitching_rail_rope_v1.png"},
	{"key": "fence_opening", "family": "props", "crop": Rect2i(170, 724, 155, 76), "path": "props/fences/fence_opening_v1.png"},
	{"key": "wagon_gate", "family": "props", "crop": Rect2i(350, 716, 386, 84), "path": "props/fences/wagon_gate_v1.png"},
	{"key": "fire_ring_unlit", "family": "props", "crop": Rect2i(510, 370, 164, 102), "path": "props/camp/fire_ring_unlit_v1.png"},
	{"key": "fire_ring_lit", "family": "props", "crop": Rect2i(684, 382, 132, 88), "path": "props/camp/fire_ring_lit_v1.png"},
	{"key": "supply_cluster_green", "family": "props", "crop": Rect2i(852, 364, 178, 120), "path": "props/supplies/supply_cluster_green_v1.png"},
	{"key": "supply_cluster_travel", "family": "props", "crop": Rect2i(632, 470, 190, 120), "path": "props/supplies/supply_cluster_travel_v1.png"},
	{"key": "crates_barrels_cluster", "family": "props", "crop": Rect2i(32, 586, 170, 126), "path": "props/supplies/crates_barrels_cluster_v1.png"},
	{"key": "spare_wagon_wheel", "family": "props", "crop": Rect2i(650, 584, 126, 128), "path": "props/supplies/spare_wagon_wheel_v1.png"},
	{"key": "spare_wagon_wheels", "family": "props", "crop": Rect2i(786, 584, 154, 126), "path": "props/supplies/spare_wagon_wheels_v1.png"},
	{"key": "water_supply_station", "family": "props", "crop": Rect2i(1100, 578, 148, 150), "path": "props/supplies/water_supply_station_v1.png"},

	# Inn and traveler-support structures.
	{"key": "roadside_inn_exterior", "family": "structures", "crop": Rect2i(38, 10, 666, 408), "path": "structures/roadside_inn_exterior_v1.png"},
	{"key": "roadside_inn_rear", "family": "structures", "crop": Rect2i(724, 52, 522, 338), "path": "structures/roadside_inn_rear_v1.png"},
	{"key": "porch_awning", "family": "structures", "crop": Rect2i(28, 412, 254, 138), "path": "structures/porch_awning_v1.png"},
	{"key": "porch_post", "family": "structures", "crop": Rect2i(286, 408, 78, 136), "path": "structures/porch_post_v1.png"},
	{"key": "porch_stairs", "family": "structures", "crop": Rect2i(372, 398, 146, 150), "path": "structures/porch_stairs_v1.png"},
	{"key": "roof_awning", "family": "structures", "crop": Rect2i(556, 414, 202, 128), "path": "structures/roof_awning_v1.png"},
	{"key": "stone_chimney", "family": "structures", "crop": Rect2i(778, 394, 88, 148), "path": "structures/stone_chimney_v1.png"},
	{"key": "roof_dormer", "family": "structures", "crop": Rect2i(866, 398, 104, 146), "path": "structures/roof_dormer_v1.png"},
	{"key": "window_box", "family": "structures", "crop": Rect2i(966, 416, 142, 122), "path": "structures/window_box_v1.png"},
	{"key": "timber_wall", "family": "structures", "crop": Rect2i(1102, 410, 164, 136), "path": "structures/timber_wall_v1.png"},
	{"key": "stone_foundation", "family": "structures", "crop": Rect2i(28, 570, 186, 80), "path": "structures/stone_foundation_v1.png"},
	{"key": "roof_strip", "family": "structures", "crop": Rect2i(220, 568, 260, 78), "path": "structures/roof_strip_v1.png"},
	{"key": "roof_gable", "family": "structures", "crop": Rect2i(464, 552, 132, 112), "path": "structures/roof_gable_v1.png"},
	{"key": "wooden_door", "family": "structures", "crop": Rect2i(638, 548, 94, 120), "path": "structures/wooden_door_v1.png"},
	{"key": "blank_hanging_inn_sign", "family": "structures", "crop": Rect2i(734, 558, 222, 124), "path": "structures/blank_hanging_inn_sign_v1.png"},
	{"key": "edenite_wall_lantern", "family": "structures", "crop": Rect2i(958, 548, 78, 138), "path": "structures/edenite_wall_lantern_v1.png"},
	{"key": "edenite_post_lantern", "family": "structures", "crop": Rect2i(1034, 546, 82, 156), "path": "structures/edenite_post_lantern_v1.png"},
	{"key": "open_wagon_shelter", "family": "structures", "crop": Rect2i(184, 648, 218, 146), "path": "structures/open_wagon_shelter_v1.png"},
	{"key": "roofed_supply_shelter", "family": "structures", "crop": Rect2i(446, 642, 266, 152), "path": "structures/roofed_supply_shelter_v1.png"},

	# Wide carriage-road system and overlays.
	{"key": "road_horizontal_wide", "family": "terrain", "crop": Rect2i(20, 42, 420, 180), "path": "terrain/road_horizontal_wide_v1.png"},
	{"key": "road_vertical_wide", "family": "terrain", "crop": Rect2i(470, 12, 176, 248), "path": "terrain/road_vertical_wide_v1.png"},
	{"key": "road_t_junction", "family": "terrain", "crop": Rect2i(670, 14, 412, 250), "path": "terrain/road_t_junction_v1.png"},
	{"key": "road_endcap_horizontal", "family": "terrain", "crop": Rect2i(1098, 62, 170, 138), "path": "terrain/road_endcap_horizontal_v1.png"},
	{"key": "road_endcap_vertical", "family": "terrain", "crop": Rect2i(1102, 198, 154, 180), "path": "terrain/road_endcap_vertical_v1.png"},
	{"key": "road_corner_outer_nw", "family": "terrain", "crop": Rect2i(24, 258, 132, 120), "path": "terrain/road_corner_outer_nw_v1.png"},
	{"key": "road_corner_inner_ne", "family": "terrain", "crop": Rect2i(154, 258, 132, 120), "path": "terrain/road_corner_inner_ne_v1.png"},
	{"key": "road_corner_inner_nw", "family": "terrain", "crop": Rect2i(286, 258, 126, 120), "path": "terrain/road_corner_inner_nw_v1.png"},
	{"key": "road_corner_outer_ne", "family": "terrain", "crop": Rect2i(412, 258, 112, 120), "path": "terrain/road_corner_outer_ne_v1.png"},
	{"key": "road_corner_split", "family": "terrain", "crop": Rect2i(518, 258, 120, 120), "path": "terrain/road_corner_split_v1.png"},
	{"key": "road_corner_outer_sw", "family": "terrain", "crop": Rect2i(24, 382, 132, 90), "path": "terrain/road_corner_outer_sw_v1.png"},
	{"key": "road_corner_inner_se", "family": "terrain", "crop": Rect2i(154, 382, 132, 90), "path": "terrain/road_corner_inner_se_v1.png"},
	{"key": "road_corner_inner_sw", "family": "terrain", "crop": Rect2i(286, 382, 126, 90), "path": "terrain/road_corner_inner_sw_v1.png"},
	{"key": "road_corner_outer_se", "family": "terrain", "crop": Rect2i(412, 382, 112, 90), "path": "terrain/road_corner_outer_se_v1.png"},
	{"key": "road_corner_split_south", "family": "terrain", "crop": Rect2i(518, 382, 120, 90), "path": "terrain/road_corner_split_south_v1.png"},
	{"key": "grass_edge_horizontal_a", "family": "terrain", "crop": Rect2i(42, 478, 124, 68), "path": "terrain/grass_edge_horizontal_a_v1.png"},
	{"key": "grass_edge_horizontal_b", "family": "terrain", "crop": Rect2i(164, 478, 124, 68), "path": "terrain/grass_edge_horizontal_b_v1.png"},
	{"key": "grass_edge_horizontal_c", "family": "terrain", "crop": Rect2i(286, 478, 118, 68), "path": "terrain/grass_edge_horizontal_c_v1.png"},
	{"key": "grass_edge_vertical_a", "family": "terrain", "crop": Rect2i(378, 466, 54, 92), "path": "terrain/grass_edge_vertical_a_v1.png"},
	{"key": "grass_edge_vertical_b", "family": "terrain", "crop": Rect2i(430, 466, 54, 92), "path": "terrain/grass_edge_vertical_b_v1.png"},
	{"key": "wheel_ruts_straight_a", "family": "terrain", "crop": Rect2i(36, 542, 158, 122), "path": "terrain/wheel_ruts_straight_a_v1.png"},
	{"key": "wheel_ruts_curve", "family": "terrain", "crop": Rect2i(196, 542, 172, 122), "path": "terrain/wheel_ruts_curve_v1.png"},
	{"key": "wheel_ruts_straight_b", "family": "terrain", "crop": Rect2i(378, 542, 174, 122), "path": "terrain/wheel_ruts_straight_b_v1.png"},
	{"key": "wheel_ruts_straight_c", "family": "terrain", "crop": Rect2i(554, 542, 174, 122), "path": "terrain/wheel_ruts_straight_c_v1.png"},
	{"key": "footprints_scatter", "family": "terrain", "crop": Rect2i(748, 542, 174, 112), "path": "terrain/footprints_scatter_v1.png"},
	{"key": "road_wear_scatter", "family": "terrain", "crop": Rect2i(910, 542, 172, 112), "path": "terrain/road_wear_scatter_v1.png"},
	{"key": "road_wear_patch", "family": "terrain", "crop": Rect2i(1074, 542, 158, 112), "path": "terrain/road_wear_patch_v1.png"},
	{"key": "rest_field_trampled_a", "family": "terrain", "crop": Rect2i(24, 654, 192, 130), "path": "terrain/rest_field_trampled_a_v1.png"},
	{"key": "rest_field_dirt_a", "family": "terrain", "crop": Rect2i(202, 654, 204, 130), "path": "terrain/rest_field_dirt_a_v1.png"},
	{"key": "rest_field_trampled_b", "family": "terrain", "crop": Rect2i(394, 654, 196, 130), "path": "terrain/rest_field_trampled_b_v1.png"},
	{"key": "rest_field_trampled_c", "family": "terrain", "crop": Rect2i(578, 654, 196, 130), "path": "terrain/rest_field_trampled_c_v1.png"},
	{"key": "rest_field_straw", "family": "terrain", "crop": Rect2i(772, 666, 142, 112), "path": "terrain/rest_field_straw_v1.png"},
	{"key": "rest_field_mud", "family": "terrain", "crop": Rect2i(910, 666, 140, 112), "path": "terrain/rest_field_mud_v1.png"},
	{"key": "edge_detail_grass", "family": "terrain", "crop": Rect2i(1050, 670, 68, 100), "path": "terrain/edge_detail_grass_v1.png"},
	{"key": "edge_detail_flowers", "family": "terrain", "crop": Rect2i(1114, 670, 76, 100), "path": "terrain/edge_detail_flowers_v1.png"},
	{"key": "edge_detail_stones", "family": "terrain", "crop": Rect2i(1182, 670, 82, 100), "path": "terrain/edge_detail_stones_v1.png"},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loaded_sources: Dictionary = {}
	var source_records: Dictionary = {}
	for family: String in SOURCES:
		var source_path: String = SOURCES[family]
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(source_path))
		if error != OK:
			_fail("Unable to load source %s: %s" % [source_path, error_string(error)])
			return
		loaded_sources[family] = image
		source_records[family] = {
			"path": source_path,
			"dimensions": [image.get_width(), image.get_height()],
			"sha256": FileAccess.get_sha256(source_path),
			"format_note": "Supplied JPEG rendition; lossless transparent PNG master was not present in the attachment payload.",
		}

	var assets: Dictionary = {}
	for spec: Dictionary in SPECS:
		var family: String = spec["family"]
		var source: Image = loaded_sources[family]
		var crop: Rect2i = spec["crop"]
		if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(crop):
			_fail("Crop for %s is outside %s" % [spec["key"], SOURCES[family]])
			return
		var extracted := _extract(source, crop, FAMILY_SCALE[family] as float)
		if extracted.is_empty():
			_fail("No foreground survived extraction for %s" % spec["key"])
			return
		var output_path := "%s/%s" % [RUNTIME_ROOT, spec["path"]]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
		var output_error := (extracted["image"] as Image).save_png(ProjectSettings.globalize_path(output_path))
		if output_error != OK:
			_fail("Unable to save %s: %s" % [output_path, error_string(output_error)])
			return
		assets[spec["key"]] = {
			"family": family,
			"source": SOURCES[family],
			"source_bounds_xywh": [crop.position.x, crop.position.y, crop.size.x, crop.size.y],
			"runtime_path": output_path,
			"runtime_dimensions": extracted["dimensions"],
			"visible_bounds_xywh": extracted["visible_bounds"],
			"anchor": extracted["anchor"],
			"scale": FAMILY_SCALE[family],
			"resampling": "nearest-neighbor",
			"sha256": FileAccess.get_sha256(output_path),
		}
	var derived_assets := _write_continuous_road_assets()
	for key: String in derived_assets:
		assets[key] = derived_assets[key]

	var manifest := {
		"version": 1,
		"generator": "res://tools/art/prepare_caden_wayfarers_approach_runtime_v1.gd",
		"source_quality_limitation": "The requested transparent PNG sources/ZIP were not attached; runtime alpha was reconstructed deterministically from black-matte JPEG renditions.",
		"normalization": {
			"family_scales": FAMILY_SCALE,
			"resampling": "nearest-neighbor only",
			"transparent_padding_pixels": 2,
			"matte_threshold": MATTE_THRESHOLD,
			"lighting": "preserved from upper-left-lit supplied artwork",
		},
		"sources": source_records,
		"concept_reference": {
			"path": CONCEPT_PATH,
			"sha256": FileAccess.get_sha256(CONCEPT_PATH),
			"runtime_usage": "Visual composition reference only; not loaded by the runtime zone.",
		},
		"attachment_provenance": {
			"traveler_props": "1-Photo-1.jpg",
			"road_terrain": "2-Photo-2.jpg",
			"inn_structures": "3-Photo-3.jpg",
			"full_zone_concept": "4-Photo-4.jpg",
		},
		"assets": assets,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUNTIME_ROOT))
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if manifest_file == null:
		_fail("Unable to write %s" % MANIFEST_PATH)
		return
	manifest_file.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	manifest_file.close()
	print("wayfarers_assets=%d" % assets.size())
	print("manifest=%s" % MANIFEST_PATH)
	quit(0)


func _write_continuous_road_assets() -> Dictionary:
	var records: Dictionary = {}
	var horizontal_source_path := RUNTIME_ROOT + "/terrain/road_horizontal_wide_v1.png"
	var horizontal := Image.new()
	var error := horizontal.load(ProjectSettings.globalize_path(horizontal_source_path))
	if error != OK:
		return records
	# Repeat only the fully internal strip; presentation-sheet cut edges contain
	# transparent matte pixels that would otherwise become straight seam lines.
	var horizontal_strip := horizontal.get_region(Rect2i(32, 0, 274, horizontal.get_height()))
	var continuous_horizontal := Image.create(1024, horizontal.get_height(), false, Image.FORMAT_RGBA8)
	continuous_horizontal.fill(Color(0, 0, 0, 0))
	for x in range(0, 1024, horizontal_strip.get_width()):
		var copy_width := mini(horizontal_strip.get_width(), 1024 - x)
		continuous_horizontal.blit_rect(horizontal_strip, Rect2i(0, 0, copy_width, horizontal_strip.get_height()), Vector2i(x, 0))
	var horizontal_path := RUNTIME_ROOT + "/terrain/road_horizontal_continuous_1024_v1.png"
	continuous_horizontal.save_png(ProjectSettings.globalize_path(horizontal_path))
	records["road_horizontal_continuous_1024"] = _derived_record(horizontal_path, horizontal_source_path, continuous_horizontal)

	var vertical_source_path := RUNTIME_ROOT + "/terrain/road_vertical_wide_v1.png"
	var vertical := Image.new()
	error = vertical.load(ProjectSettings.globalize_path(vertical_source_path))
	if error != OK:
		return records
	var vertical_strip := vertical.get_region(Rect2i(0, 32, vertical.get_width(), 136))
	var continuous_vertical := Image.create(vertical.get_width(), 256, false, Image.FORMAT_RGBA8)
	continuous_vertical.fill(Color(0, 0, 0, 0))
	for y in range(0, 256, vertical_strip.get_height()):
		var copy_height := mini(vertical_strip.get_height(), 256 - y)
		continuous_vertical.blit_rect(vertical_strip, Rect2i(0, 0, vertical_strip.get_width(), copy_height), Vector2i(0, y))
	var vertical_path := RUNTIME_ROOT + "/terrain/road_vertical_continuous_256_v1.png"
	continuous_vertical.save_png(ProjectSettings.globalize_path(vertical_path))
	records["road_vertical_continuous_256"] = _derived_record(vertical_path, vertical_source_path, continuous_vertical)

	var junction_source_path := RUNTIME_ROOT + "/terrain/road_t_junction_v1.png"
	var junction := Image.new()
	error = junction.load(ProjectSettings.globalize_path(junction_source_path))
	if error != OK:
		return records
	# The presentation sheet's horizontal cut edges are matte-backed. The zone's
	# continuous horizontal road already supplies those pixels, so retain only the
	# widening center of the junction and let it merge into the road beneath it.
	var junction_center := junction.get_width() / 2
	for y in junction.get_height():
		var half_width := junction_center
		if y >= 64:
			half_width = roundi(lerpf(junction_center - 8, 72.0, clampf(float(y - 64) / 120.0, 0.0, 1.0)))
		if y >= 188:
			half_width = 0
		for x in junction.get_width():
			if absi(x - junction_center) > half_width:
				var color := junction.get_pixel(x, y)
				color.a = 0.0
				junction.set_pixel(x, y, color)
	var junction_path := RUNTIME_ROOT + "/terrain/road_t_junction_overlay_v1.png"
	junction.save_png(ProjectSettings.globalize_path(junction_path))
	records["road_t_junction_overlay"] = _derived_record(junction_path, junction_source_path, junction)
	return records


func _derived_record(path: String, source_path: String, image: Image) -> Dictionary:
	return {
		"family": "terrain",
		"derived_from": source_path,
		"runtime_path": path,
		"runtime_dimensions": [image.get_width(), image.get_height()],
		"visible_bounds_xywh": [0, 0, image.get_width(), image.get_height()],
		"scale": FAMILY_SCALE["terrain"],
		"resampling": "nearest-neighbor; repeated internal source strip",
		"sha256": FileAccess.get_sha256(path),
	}


func _extract(source: Image, crop: Rect2i, scale: float) -> Dictionary:
	var isolated := source.get_region(crop)
	isolated.convert(Image.FORMAT_RGBA8)
	_reconstruct_alpha(isolated)
	var used := isolated.get_used_rect()
	if used.size == Vector2i.ZERO:
		return {}
	used = used.grow(2).intersection(Rect2i(Vector2i.ZERO, isolated.get_size()))
	var trimmed := isolated.get_region(used)
	var target_size := Vector2i(
		maxi(1, roundi(trimmed.get_width() * scale)),
		maxi(1, roundi(trimmed.get_height() * scale))
	)
	trimmed.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	var visible := trimmed.get_used_rect()
	var canvas := Image.create(target_size.x + 4, target_size.y + 4, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(trimmed, Rect2i(Vector2i.ZERO, trimmed.get_size()), Vector2i(2, 2))
	return {
		"image": canvas,
		"dimensions": [canvas.get_width(), canvas.get_height()],
		"visible_bounds": [visible.position.x + 2, visible.position.y + 2, visible.size.x, visible.size.y],
		"anchor": [canvas.get_width() / 2, canvas.get_height() - 2],
	}


func _reconstruct_alpha(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var matte := PackedByteArray()
	matte.resize(width * height)
	var queue: Array[Vector2i] = []
	for x in width:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, height - 1))
	for y in range(1, height - 1):
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(width - 1, y))
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		var index := point.y * width + point.x
		if matte[index] != 0:
			continue
		var color := image.get_pixelv(point)
		if maxf(color.r, maxf(color.g, color.b)) > MATTE_THRESHOLD:
			continue
		matte[index] = 1
		if point.x > 0:
			queue.append(Vector2i(point.x - 1, point.y))
		if point.x + 1 < width:
			queue.append(Vector2i(point.x + 1, point.y))
		if point.y > 0:
			queue.append(Vector2i(point.x, point.y - 1))
		if point.y + 1 < height:
			queue.append(Vector2i(point.x, point.y + 1))
	for y in height:
		for x in width:
			var index := y * width + x
			var color := image.get_pixel(x, y)
			color.a = 0.0 if matte[index] != 0 else 1.0
			image.set_pixel(x, y, color)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
