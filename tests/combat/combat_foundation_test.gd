extends SceneTree

const Registry := preload("res://scripts/domain/combat/combat_definition_registry.gd")
const CombatRng := preload("res://scripts/domain/combat/combat_rng.gd")
const SpatialRules := preload("res://scripts/domain/combat/target_based_combat_spatial_rules.gd")


func _initialize() -> void:
	var registry := Registry.new()
	if not registry.is_valid():
		_fail("Development combat definitions are invalid: %s" % registry.get_validation_errors())
		return
	if (
		registry.get_ability_ids().size() != 5
		or registry.get_status_ids().size() != 2
		or registry.get_template_ids().size() != 3
		or registry.get_ability("development.ability.venom").effects.size() != 2
	):
		_fail("Combat definition families were not registered completely.")
		return
	var invalid := Registry.new("res://tests/fixtures/combat_invalid_definitions.json")
	if invalid.is_valid() or invalid.get_validation_errors().size() < 5:
		_fail("Invalid combat content was not rejected comprehensively.")
		return

	var first := CombatRng.new()
	var second := CombatRng.new()
	first.configure(91234)
	second.configure(91234)
	var first_sequence: Array[int] = []
	var second_sequence: Array[int] = []
	for index in 8:
		first_sequence.append(first.range_inclusive(-3, 7))
		second_sequence.append(second.range_inclusive(-3, 7))
	if first_sequence != second_sequence or first.get_state().draw_count != 8:
		_fail("Combat RNG is not deterministic for an identical seed and draw count.")
		return
	var restored := CombatRng.new()
	if not restored.restore_state(first.get_state()):
		_fail("Combat RNG state could not be restored.")
		return
	if restored.next_u32() != first.next_u32():
		_fail("Restored combat RNG did not resume the same stream.")
		return

	var spatial := SpatialRules.new()
	var combatants := {
		"hero.1": {"team_id": "heroes", "alive": true},
		"hero.2": {"team_id": "heroes", "alive": true},
		"enemy.1": {"team_id": "enemies", "alive": true},
		"enemy.defeated": {"team_id": "enemies", "alive": false},
	}
	if not spatial.validate_targets("hero.1", ["hero.1"], combatants, "SELF").accepted:
		_fail("Target-based SELF rule rejected its actor.")
		return
	if not spatial.validate_targets("hero.1", ["hero.2"], combatants, "ALLY").accepted:
		_fail("Target-based ALLY rule rejected a living ally.")
		return
	if not spatial.validate_targets("hero.1", ["enemy.1"], combatants, "ENEMY").accepted:
		_fail("Target-based ENEMY rule rejected a living enemy.")
		return
	if (
		spatial.validate_targets("hero.1", ["hero.2"], combatants, "ENEMY").accepted
		or spatial.validate_targets("hero.1", ["enemy.defeated"], combatants, "ENEMY").accepted
		or spatial.validate_targets("hero.1", ["enemy.1", "hero.2"], combatants, "ENEMY").accepted
	):
		_fail("Target-based spatial validation accepted an illegal target set.")
		return

	print("PASS: Phase G content validation, stable definitions, deterministic RNG state, and replaceable target-based spatial rules.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
