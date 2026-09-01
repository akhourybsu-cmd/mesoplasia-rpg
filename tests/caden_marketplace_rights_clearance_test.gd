extends SceneTree

const RIGHTS_PATH := "res://assets/environments/caden/marketplace/caden_marketplace_source_rights_v1.json"
const RUNTIME_MANIFEST_PATH := "res://assets/environments/caden/marketplace/marketplace_runtime_manifest_v1.json"
const TERRAIN_V12_PATH := "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_2.json"
const TERRAIN_V13_PATH := "res://assets/environments/caden/marketplace/terrain/marketplace_terrain_runtime_v1_3.json"
const EXPECTED_RIGHTS_STATUS := "openai_output_provenance_verified"
const EXPECTED_DISTRIBUTION_STATUS := "project_distribution_allowed_subject_to_applicable_law_and_third_party_rights"


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var rights := _load_json(RIGHTS_PATH)
	if rights.is_empty():
		return
	if rights.get("gate_state", "") != "operational_distribution_clearance_recorded":
		return _fail("Marketplace rights gate is not operationally cleared.")
	var decision := rights.get("decision", {}) as Dictionary
	if decision.get("rights_status", "") != EXPECTED_RIGHTS_STATUS:
		return _fail("Marketplace clearance has an unexpected rights status.")
	if decision.get("distribution_status", "") != EXPECTED_DISTRIBUTION_STATUS:
		return _fail("Marketplace clearance has an unexpected distribution status.")
	if decision.get("legal_character", "").find("not a legal opinion") == -1:
		return _fail("Marketplace clearance omitted its legal limitation.")

	var evidence := rights.get("evidence", {}) as Dictionary
	var library := evidence.get("library_archive", {}) as Dictionary
	var terrain := evidence.get("terrain_master", {}) as Dictionary
	if library.get("sha256", "") != "bd7688541dfeb53e2c5b2252587c3dbebce782c938d418dd3d475b83749f3947":
		return _fail("Marketplace source archive identity changed.")
	if terrain.get("sha256", "") != "eaf2dbf53d955e8e92a71c7b04e63b38bcc66710a7e28a06dbfe3956d354508e":
		return _fail("Marketplace terrain master identity changed.")
	for source: Dictionary in [library, terrain]:
		var download := source.get("windows_download_provenance", {}) as Dictionary
		if download.get("referrer_origin", "") != "https://chatgpt.com" or download.get("host_origin", "") != "https://chatgpt.com":
			return _fail("Marketplace source is missing its ChatGPT download provenance.")
		if download.get("host_path", "") != "/backend-api/estuary/content" or download.get("zone_id", 0) != 3:
			return _fail("Marketplace source download provenance is incomplete.")

	var verification := library.get("selected_source_verification", {}) as Dictionary
	var direct := verification.get("direct_archive_hash_matches", {}) as Dictionary
	var corrected := verification.get("corrected_intake_manifest_records", {}) as Dictionary
	var runtime := _load_json(RUNTIME_MANIFEST_PATH)
	if runtime.is_empty():
		return
	var records := runtime.get("assets", {}) as Dictionary
	for source_id: String in ["01", "03", "04", "13", "14"]:
		if direct.get(source_id, "") != (records.get(source_id, {}) as Dictionary).get("source_sha256", ""):
			return _fail("Marketplace source %s lost its direct archive match." % source_id)
	for source_id: String in ["06", "07"]:
		var correction := corrected.get(source_id, {}) as Dictionary
		if correction.get("approved_source_sha256", "") != (records.get(source_id, {}) as Dictionary).get("source_sha256", ""):
			return _fail("Marketplace corrected source %s lost its approved hash." % source_id)
		if correction.get("status", "").find("not present") == -1:
			return _fail("Marketplace corrected source %s does not disclose its archival limitation." % source_id)

	for path: String in [RUNTIME_MANIFEST_PATH, TERRAIN_V12_PATH, TERRAIN_V13_PATH]:
		var manifest := _load_json(path)
		if manifest.is_empty():
			return
		var provenance := manifest.get("provenance_and_licensing", {}) as Dictionary
		if provenance.get("rights_record", "") != RIGHTS_PATH.trim_prefix("res://"):
			return _fail("Marketplace manifest does not reference the authoritative rights record: %s" % path)
		if provenance.get("rights_status", "") != EXPECTED_RIGHTS_STATUS:
			return _fail("Marketplace manifest has a stale rights status: %s" % path)
		if provenance.get("distribution_status", "") != EXPECTED_DISTRIBUTION_STATUS:
			return _fail("Marketplace manifest has a stale distribution status: %s" % path)
	for source_id: String in records:
		if (records[source_id] as Dictionary).get("rights_status", "") != EXPECTED_RIGHTS_STATUS:
			return _fail("Marketplace asset %s has a stale rights status." % source_id)

	var terms := rights.get("openai_terms", {}) as Dictionary
	if terms.get("url", "") != "https://openai.com/policies/terms-of-use/" or terms.get("effective_date", "") != "2026-01-01":
		return _fail("Marketplace rights record does not identify the governing OpenAI terms.")
	if (evidence.get("marketplace_visual_review", {}) as Dictionary).get("result", "") != "no_obvious_third_party_marks_or_readable_brands":
		return _fail("Marketplace third-party-mark review is incomplete.")
	print("PASS: Marketplace provenance, limited distribution clearance, exceptions, and manifest bindings are valid.")
	quit(0)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Missing JSON: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Invalid JSON object: %s" % path)
		return {}
	return parsed as Dictionary


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
