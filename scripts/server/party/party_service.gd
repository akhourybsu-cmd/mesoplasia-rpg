class_name PartyService
extends RefCounted

const PARTY_SNAPSHOT_SCHEMA_VERSION := 1
const DEFAULT_MAX_PARTY_SIZE := 4
const DEFAULT_INVITE_LIFETIME_MSEC := 30_000
const DEFAULT_DISCONNECT_GRACE_MSEC := 15_000

const STATE_FORMING := "FORMING"
const STATE_READY_CHECK := "READY_CHECK"
const STATE_EXPEDITION_RESERVED := "EXPEDITION_RESERVED"
const STATE_IN_EXPEDITION := "IN_EXPEDITION"
const STATE_RETURNING := "RETURNING"
const STATE_DISBANDED := "DISBANDED"

const INVITE_PENDING := "PENDING"
const INVITE_ACCEPTED := "ACCEPTED"
const INVITE_DECLINED := "DECLINED"
const INVITE_EXPIRED := "EXPIRED"
const INVITE_CANCELLED := "CANCELLED"

var _max_party_size := DEFAULT_MAX_PARTY_SIZE
var _invite_lifetime_msec := DEFAULT_INVITE_LIFETIME_MSEC
var _disconnect_grace_msec := DEFAULT_DISCONNECT_GRACE_MSEC
var _party_serial := 0
var _invite_serial := 0
var _join_serial := 0
var _projection_revision := 0
var _parties_by_id: Dictionary = {}
var _party_id_by_character_id: Dictionary = {}
var _invites_by_id: Dictionary = {}
var _characters_by_id: Dictionary = {}


func configure(
	max_party_size: int = DEFAULT_MAX_PARTY_SIZE,
	invite_lifetime_msec: int = DEFAULT_INVITE_LIFETIME_MSEC,
	disconnect_grace_msec: int = DEFAULT_DISCONNECT_GRACE_MSEC
) -> bool:
	if (
		max_party_size < 1
		or max_party_size > 8
		or invite_lifetime_msec < 1
		or disconnect_grace_msec < 1
	):
		return false
	_max_party_size = max_party_size
	_invite_lifetime_msec = invite_lifetime_msec
	_disconnect_grace_msec = disconnect_grace_msec
	return true


func connect_character(identity: Dictionary, now_msec: int) -> Dictionary:
	var character_id := identity.get("character_id", "") as String
	if character_id.is_empty():
		return _rejected("INVALID_IDENTITY", "Character identity is missing.")
	var record := _characters_by_id.get(character_id, {}) as Dictionary
	record.character_id = character_id
	record.display_label = identity.get("display_label", character_id) as String
	record.connected = true
	record.last_connected_msec = now_msec
	_characters_by_id[character_id] = record
	var party := _party_for_character(character_id)
	if not party.is_empty():
		var member := (party.members as Dictionary).get(character_id, {}) as Dictionary
		if not member.is_empty() and not member.connected:
			member.connected = true
			member.disconnect_deadline_msec = 0
			member.ready = false
			_increment_party_revision(party)
	return {"accepted": true, "reason_code": "OK", "character_id": character_id}


func disconnect_character(character_id: String, now_msec: int) -> bool:
	var character := _characters_by_id.get(character_id, {}) as Dictionary
	if character.is_empty() or not character.get("connected", false):
		return false
	character.connected = false
	var party := _party_for_character(character_id)
	if not party.is_empty():
		var member := (party.members as Dictionary).get(character_id, {}) as Dictionary
		if not member.is_empty():
			member.connected = false
			member.ready = false
			member.disconnect_deadline_msec = now_msec + _disconnect_grace_msec
			_increment_party_revision(party)
	else:
		_projection_revision += 1
	return true


func tick(now_msec: int) -> bool:
	var changed := false
	var parties_with_expired_invites: Dictionary = {}
	for invite_id: Variant in _invites_by_id:
		var invite := _invites_by_id[invite_id] as Dictionary
		if invite.status == INVITE_PENDING and now_msec >= int(invite.expires_msec):
			invite.status = INVITE_EXPIRED
			parties_with_expired_invites[invite.party_id] = true
			changed = true
	for party_id: Variant in parties_with_expired_invites:
		var party := _active_party(party_id as String)
		if not party.is_empty():
			_increment_party_revision(party)

	var expired_members: Array[Dictionary] = []
	for party_id: Variant in _parties_by_id:
		var party := _active_party(party_id as String)
		if party.is_empty():
			continue
		if party.lifecycle_state in [
			STATE_EXPEDITION_RESERVED,
			STATE_IN_EXPEDITION,
			STATE_RETURNING,
		]:
			continue
		for character_id: Variant in (party.members as Dictionary):
			var member := (party.members as Dictionary)[character_id] as Dictionary
			if (
				not member.connected
				and int(member.disconnect_deadline_msec) > 0
				and now_msec >= int(member.disconnect_deadline_msec)
			):
				expired_members.append(
					{"party_id": party.party_id, "character_id": character_id}
				)
	for expired: Dictionary in expired_members:
		var party := _active_party(expired.party_id)
		if not party.is_empty() and (party.members as Dictionary).has(expired.character_id):
			_remove_member(party, expired.character_id, "disconnect_grace_expired")
			changed = true
	return changed


func invite_character(
	inviter_character_id: String,
	recipient_character_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	if inviter_character_id == recipient_character_id:
		return _rejected("INVALID_TARGET", "A character cannot invite itself.")
	if not _is_connected(inviter_character_id) or not _is_connected(recipient_character_id):
		return _rejected("TARGET_UNAVAILABLE", "Both characters must be connected.")
	if _party_id_by_character_id.has(recipient_character_id):
		return _rejected("TARGET_ALREADY_PARTIED", "The target already belongs to a party.")
	var party := _party_for_character(inviter_character_id)
	if party.is_empty():
		if expected_revision != -1:
			return _stale(-1)
		party = _create_party(inviter_character_id)
	else:
		if not party.lifecycle_state in [STATE_FORMING, STATE_READY_CHECK]:
			return _rejected("PARTY_BUSY", "Party membership is locked during an expedition.", party)
		var revision_check := _require_revision(party, expected_revision)
		if not revision_check.accepted:
			return revision_check
		if party.leader_character_id != inviter_character_id:
			return _rejected("NOT_LEADER", "Only the party leader may invite members.", party)
	if (party.members as Dictionary).size() >= _max_party_size:
		return _rejected("PARTY_FULL", "The party is at capacity.", party)
	for invite_id: Variant in party.invite_ids:
		var existing := _invites_by_id.get(invite_id, {}) as Dictionary
		if existing.status == INVITE_PENDING and existing.recipient_character_id == recipient_character_id:
			return _rejected("DUPLICATE_INVITE", "A pending invite already exists.", party)

	_invite_serial += 1
	var invite_id := "development.party_invite.%d" % _invite_serial
	var invite := {
		"invite_id": invite_id,
		"party_id": party.party_id,
		"party_revision_at_creation": int(party.revision) + 1,
		"inviter_character_id": inviter_character_id,
		"recipient_character_id": recipient_character_id,
		"created_msec": now_msec,
		"expires_msec": now_msec + _invite_lifetime_msec,
		"status": INVITE_PENDING,
	}
	_invites_by_id[invite_id] = invite
	party.invite_ids.append(invite_id)
	_increment_party_revision(party)
	return _accepted(party, {"invite_id": invite_id})


func accept_invite(
	recipient_character_id: String,
	invite_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var invite_check := _pending_invite_for_recipient(
		recipient_character_id, invite_id, now_msec
	)
	if not invite_check.accepted:
		return invite_check
	var invite := _invites_by_id[invite_id] as Dictionary
	var party := _active_party(invite.party_id)
	if party.is_empty():
		return _rejected("PARTY_UNAVAILABLE", "The inviting party no longer exists.")
	if not party.lifecycle_state in [STATE_FORMING, STATE_READY_CHECK]:
		return _rejected("PARTY_BUSY", "Party membership is locked during an expedition.", party)
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if _party_id_by_character_id.has(recipient_character_id):
		return _rejected("TARGET_ALREADY_PARTIED", "The recipient already belongs to a party.", party)
	if (party.members as Dictionary).size() >= _max_party_size:
		return _rejected("PARTY_FULL", "The party filled before the invite was accepted.", party)
	_add_member(party, recipient_character_id)
	invite.status = INVITE_ACCEPTED
	_cancel_other_pending_invites_for(recipient_character_id, invite_id)
	_reset_selection_after_membership_change(party)
	_increment_party_revision(party)
	return _accepted(party, {"invite_id": invite_id})


func decline_invite(
	recipient_character_id: String,
	invite_id: String,
	expected_revision: int,
	now_msec: int
) -> Dictionary:
	var invite_check := _pending_invite_for_recipient(
		recipient_character_id, invite_id, now_msec
	)
	if not invite_check.accepted:
		return invite_check
	var invite := _invites_by_id[invite_id] as Dictionary
	var party := _active_party(invite.party_id)
	if party.is_empty():
		return _rejected("PARTY_UNAVAILABLE", "The inviting party no longer exists.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	invite.status = INVITE_DECLINED
	_increment_party_revision(party)
	return _accepted(party, {"invite_id": invite_id})


func leave_party(character_id: String, expected_revision: int) -> Dictionary:
	var party := _party_for_character(character_id)
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if not party.lifecycle_state in [STATE_FORMING, STATE_READY_CHECK]:
		return _rejected("PARTY_BUSY", "Party membership is locked during an expedition.", party)
	var party_id := party.party_id as String
	_remove_member(party, character_id, "left")
	return {
		"accepted": true,
		"reason_code": "OK",
		"reason_text": "Party left.",
		"party_id": party_id,
		"revision": int(party.revision),
		"disbanded": party.lifecycle_state == STATE_DISBANDED,
	}


func kick_member(
	leader_character_id: String,
	target_character_id: String,
	expected_revision: int
) -> Dictionary:
	var party := _party_for_character(leader_character_id)
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if party.leader_character_id != leader_character_id:
		return _rejected("NOT_LEADER", "Only the party leader may remove a member.", party)
	if not party.lifecycle_state in [STATE_FORMING, STATE_READY_CHECK]:
		return _rejected("PARTY_BUSY", "Party membership is locked during an expedition.", party)
	if target_character_id == leader_character_id:
		return _rejected("INVALID_TARGET", "The leader must leave rather than kick itself.", party)
	if not (party.members as Dictionary).has(target_character_id):
		return _rejected("NOT_A_MEMBER", "The target is not a party member.", party)
	_remove_member(party, target_character_id, "kicked")
	return _accepted(party, {"target_character_id": target_character_id})


func transfer_leadership(
	leader_character_id: String,
	target_character_id: String,
	expected_revision: int
) -> Dictionary:
	var party := _party_for_character(leader_character_id)
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if party.leader_character_id != leader_character_id:
		return _rejected("NOT_LEADER", "Only the current leader may transfer leadership.", party)
	if not party.lifecycle_state in [STATE_FORMING, STATE_READY_CHECK]:
		return _rejected("PARTY_BUSY", "Leadership is locked during an expedition.", party)
	var target := (party.members as Dictionary).get(target_character_id, {}) as Dictionary
	if target.is_empty() or not target.connected:
		return _rejected("TARGET_UNAVAILABLE", "Leadership target must be a connected member.", party)
	if target_character_id == leader_character_id:
		return _rejected("INVALID_TARGET", "The target is already the leader.", party)
	party.leader_character_id = target_character_id
	_increment_party_revision(party)
	return _accepted(party, {"leader_character_id": target_character_id})


func set_ready(character_id: String, is_ready: bool, expected_revision: int) -> Dictionary:
	var party := _party_for_character(character_id)
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if party.lifecycle_state != STATE_READY_CHECK or party.selected_expedition_definition_id.is_empty():
		return _rejected("INVALID_STATE", "Select an expedition before readying.", party)
	var member := (party.members as Dictionary)[character_id] as Dictionary
	if not member.connected:
		return _rejected("MEMBER_DISCONNECTED", "A disconnected member cannot ready.", party)
	if member.ready == is_ready:
		return _accepted(party, {"is_ready": is_ready, "unchanged": true})
	member.ready = is_ready
	_increment_party_revision(party)
	return _accepted(party, {"is_ready": is_ready})


func select_expedition(
	leader_character_id: String,
	expedition_definition_id: String,
	expected_revision: int
) -> Dictionary:
	var party := _party_for_character(leader_character_id)
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if party.leader_character_id != leader_character_id:
		return _rejected("NOT_LEADER", "Only the party leader may select an expedition.", party)
	if not _is_stable_definition_id(expedition_definition_id):
		return _rejected("INVALID_DEFINITION", "Expedition definition ID is invalid.", party)
	party.selected_expedition_definition_id = expedition_definition_id
	party.lifecycle_state = STATE_READY_CHECK
	_clear_readiness(party)
	_increment_party_revision(party)
	return _accepted(party, {"expedition_definition_id": expedition_definition_id})


func reserve_expedition(
	leader_character_id: String,
	expedition_id: String,
	expedition_definition_id: String,
	expected_revision: int
) -> Dictionary:
	var party := _party_for_character(leader_character_id)
	if party.is_empty():
		return _rejected("NOT_IN_PARTY", "The character is not in a party.")
	var revision_check := _require_revision(party, expected_revision)
	if not revision_check.accepted:
		return revision_check
	if party.leader_character_id != leader_character_id:
		return _rejected("NOT_LEADER", "Only the party leader may launch an expedition.", party)
	if (
		party.lifecycle_state != STATE_READY_CHECK
		or party.selected_expedition_definition_id != expedition_definition_id
	):
		return _rejected("INVALID_STATE", "The selected expedition is not ready to launch.", party)
	if not party.current_expedition_id.is_empty():
		return _rejected("DUPLICATE_LAUNCH", "The party already has an expedition.", party)
	for character_id: Variant in party.members:
		var member := (party.members as Dictionary)[character_id] as Dictionary
		if not member.connected:
			return _rejected("MEMBER_DISCONNECTED", "Every party member must be connected to launch.", party)
		if not member.ready:
			return _rejected("PARTY_NOT_READY", "Every party member must be ready to launch.", party)
	party.current_expedition_id = expedition_id
	party.lifecycle_state = STATE_EXPEDITION_RESERVED
	_increment_party_revision(party)
	return _accepted(party, {"expedition_id": expedition_id})


func commit_expedition(expedition_id: String) -> Dictionary:
	var party := _party_for_expedition(expedition_id)
	if party.is_empty() or party.lifecycle_state != STATE_EXPEDITION_RESERVED:
		return _rejected("INVALID_STATE", "The expedition reservation cannot be committed.", party)
	party.lifecycle_state = STATE_IN_EXPEDITION
	_clear_readiness(party)
	_increment_party_revision(party)
	return _accepted(party, {"expedition_id": expedition_id})


func rollback_expedition(expedition_id: String) -> Dictionary:
	var party := _party_for_expedition(expedition_id)
	if party.is_empty():
		return _rejected("EXPEDITION_NOT_FOUND", "The party reservation no longer exists.")
	if party.lifecycle_state not in [STATE_EXPEDITION_RESERVED, STATE_RETURNING]:
		return _rejected("INVALID_STATE", "The party expedition cannot be rolled back.", party)
	party.lifecycle_state = STATE_FORMING
	party.current_expedition_id = ""
	party.selected_expedition_definition_id = ""
	_clear_readiness(party)
	_increment_party_revision(party)
	return _accepted(party, {"expedition_id": expedition_id})


func begin_return(expedition_id: String) -> Dictionary:
	var party := _party_for_expedition(expedition_id)
	if party.is_empty() or party.lifecycle_state != STATE_IN_EXPEDITION:
		return _rejected("INVALID_STATE", "The party is not in that expedition.", party)
	party.lifecycle_state = STATE_RETURNING
	_increment_party_revision(party)
	return _accepted(party, {"expedition_id": expedition_id})


func complete_return(expedition_id: String) -> Dictionary:
	var party := _party_for_expedition(expedition_id)
	if party.is_empty() or party.lifecycle_state != STATE_RETURNING:
		return _rejected("INVALID_STATE", "The party return is not pending.", party)
	party.lifecycle_state = STATE_FORMING
	party.current_expedition_id = ""
	party.selected_expedition_definition_id = ""
	_clear_readiness(party)
	_increment_party_revision(party)
	return _accepted(party, {"expedition_id": expedition_id})


func get_snapshot_for(character_id: String) -> Dictionary:
	var party := _party_for_character(character_id)
	var member_rows: Array = []
	var invitation_rows: Array = []
	var party_id := ""
	var revision := -1
	var lifecycle_state := "UNPARTIED"
	var leader_character_id := ""
	var selected_expedition_definition_id := ""
	var current_expedition_id := ""
	var all_present_members_ready := false
	if not party.is_empty():
		party_id = party.party_id
		revision = party.revision
		lifecycle_state = party.lifecycle_state
		leader_character_id = party.leader_character_id
		selected_expedition_definition_id = party.selected_expedition_definition_id
		current_expedition_id = party.current_expedition_id
		all_present_members_ready = _all_present_members_ready(party)
		var member_ids := (party.members as Dictionary).keys()
		member_ids.sort_custom(
			func(first: Variant, second: Variant) -> bool:
				var first_member := (party.members as Dictionary)[first] as Dictionary
				var second_member := (party.members as Dictionary)[second] as Dictionary
				if first_member.join_order == second_member.join_order:
					return String(first) < String(second)
				return int(first_member.join_order) < int(second_member.join_order)
		)
		for member_id: Variant in member_ids:
			var member := (party.members as Dictionary)[member_id] as Dictionary
			member_rows.append(
				[
					member_id,
					_display_label(member_id),
					member.connected,
					member.ready,
					member.join_order,
					member.disconnect_deadline_msec,
				]
			)
		for invite_id: Variant in party.invite_ids:
			var invite := _invites_by_id.get(invite_id, {}) as Dictionary
			if invite.status == INVITE_PENDING:
				invitation_rows.append(_invite_row(invite, party.revision))
	else:
		for invite_id: String in get_pending_invite_ids_for(character_id):
			var invite := _invites_by_id[invite_id] as Dictionary
			var inviting_party := _active_party(invite.party_id)
			if not inviting_party.is_empty():
				invitation_rows.append(_invite_row(invite, inviting_party.revision))
	return {
		"party_snapshot_schema_version": PARTY_SNAPSHOT_SCHEMA_VERSION,
		"projection_revision": _projection_revision,
		"party_id": party_id,
		"revision": revision,
		"lifecycle_state": lifecycle_state,
		"leader_character_id": leader_character_id,
		"selected_expedition_definition_id": selected_expedition_definition_id,
		"current_expedition_id": current_expedition_id,
		"max_party_size": _max_party_size,
		"all_present_members_ready": all_present_members_ready,
		"members": member_rows,
		"invitations": invitation_rows,
	}


func get_party_for_character(character_id: String) -> Dictionary:
	var party := _party_for_character(character_id)
	return party.duplicate(true) if not party.is_empty() else {}


func get_party_state(party_id: String) -> Dictionary:
	var party := _parties_by_id.get(party_id, {}) as Dictionary
	return party.duplicate(true) if not party.is_empty() else {}


func get_invite_state(invite_id: String) -> Dictionary:
	var invite := _invites_by_id.get(invite_id, {}) as Dictionary
	return invite.duplicate(true) if not invite.is_empty() else {}


func get_pending_invite_ids_for(character_id: String) -> Array[String]:
	var result: Array[String] = []
	for invite_id: Variant in _invites_by_id:
		var invite := _invites_by_id[invite_id] as Dictionary
		if invite.status == INVITE_PENDING and invite.recipient_character_id == character_id:
			result.append(invite_id as String)
	result.sort()
	return result


func get_active_party_count() -> int:
	var count := 0
	for party_id: Variant in _parties_by_id:
		if (_parties_by_id[party_id] as Dictionary).lifecycle_state != STATE_DISBANDED:
			count += 1
	return count


func _create_party(leader_character_id: String) -> Dictionary:
	_party_serial += 1
	var party_id := "development.party.%d" % _party_serial
	var party := {
		"party_id": party_id,
		"revision": 0,
		"lifecycle_state": STATE_FORMING,
		"leader_character_id": leader_character_id,
		"selected_expedition_definition_id": "",
		"current_expedition_id": "",
		"members": {},
		"invite_ids": [],
	}
	_parties_by_id[party_id] = party
	_add_member(party, leader_character_id)
	_increment_party_revision(party)
	return party


func _add_member(party: Dictionary, character_id: String) -> void:
	_join_serial += 1
	(party.members as Dictionary)[character_id] = {
		"character_id": character_id,
		"join_order": _join_serial,
		"connected": _is_connected(character_id),
		"ready": false,
		"disconnect_deadline_msec": 0,
	}
	_party_id_by_character_id[character_id] = party.party_id


func _remove_member(party: Dictionary, character_id: String, _reason: String) -> void:
	(party.members as Dictionary).erase(character_id)
	_party_id_by_character_id.erase(character_id)
	_cancel_pending_invites_involving(character_id, party.party_id)
	_reset_selection_after_membership_change(party)
	if (party.members as Dictionary).is_empty():
		party.lifecycle_state = STATE_DISBANDED
		party.leader_character_id = ""
		party.selected_expedition_definition_id = ""
		_increment_party_revision(party)
		return
	if party.leader_character_id == character_id:
		party.leader_character_id = _select_successor(party)
	_increment_party_revision(party)


func _select_successor(party: Dictionary) -> String:
	var candidates: Array[Dictionary] = []
	for character_id: Variant in (party.members as Dictionary):
		var member := (party.members as Dictionary)[character_id] as Dictionary
		if member.connected:
			candidates.append(member)
	if candidates.is_empty():
		for character_id: Variant in (party.members as Dictionary):
			candidates.append((party.members as Dictionary)[character_id] as Dictionary)
	candidates.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			if first.join_order == second.join_order:
				return first.character_id < second.character_id
			return int(first.join_order) < int(second.join_order)
	)
	return candidates[0].character_id as String


func _clear_readiness(party: Dictionary) -> void:
	for character_id: Variant in (party.members as Dictionary):
		((party.members as Dictionary)[character_id] as Dictionary).ready = false


func _reset_selection_after_membership_change(party: Dictionary) -> void:
	_clear_readiness(party)
	if party.lifecycle_state in [STATE_FORMING, STATE_READY_CHECK]:
		party.lifecycle_state = STATE_FORMING
		party.selected_expedition_definition_id = ""


func _all_present_members_ready(party: Dictionary) -> bool:
	if party.selected_expedition_definition_id.is_empty():
		return false
	var present_count := 0
	for character_id: Variant in (party.members as Dictionary):
		var member := (party.members as Dictionary)[character_id] as Dictionary
		if member.connected:
			present_count += 1
			if not member.ready:
				return false
	return present_count > 0


func _cancel_pending_invites_involving(character_id: String, party_id: String) -> void:
	for invite_id: Variant in _invites_by_id:
		var invite := _invites_by_id[invite_id] as Dictionary
		if (
			invite.status == INVITE_PENDING
			and invite.party_id == party_id
			and (
				invite.inviter_character_id == character_id
				or invite.recipient_character_id == character_id
			)
		):
			invite.status = INVITE_CANCELLED


func _cancel_other_pending_invites_for(character_id: String, accepted_invite_id: String) -> void:
	for invite_id: Variant in _invites_by_id:
		if invite_id == accepted_invite_id:
			continue
		var invite := _invites_by_id[invite_id] as Dictionary
		if invite.status == INVITE_PENDING and invite.recipient_character_id == character_id:
			invite.status = INVITE_CANCELLED


func _pending_invite_for_recipient(
	recipient_character_id: String,
	invite_id: String,
	now_msec: int
) -> Dictionary:
	var invite := _invites_by_id.get(invite_id, {}) as Dictionary
	if invite.is_empty() or invite.recipient_character_id != recipient_character_id:
		return _rejected("INVALID_INVITE", "The invite does not belong to this character.")
	if invite.status != INVITE_PENDING:
		return _rejected("INVITE_UNAVAILABLE", "The invite is no longer pending.")
	if now_msec >= int(invite.expires_msec):
		invite.status = INVITE_EXPIRED
		var party := _active_party(invite.party_id)
		if not party.is_empty():
			_increment_party_revision(party)
		return _rejected("INVITE_EXPIRED", "The invite has expired.", party)
	return {"accepted": true, "reason_code": "OK"}


func _invite_row(invite: Dictionary, current_party_revision: int) -> Array:
	return [
		invite.invite_id,
		invite.party_id,
		invite.party_revision_at_creation,
		current_party_revision,
		invite.inviter_character_id,
		_display_label(invite.inviter_character_id),
		invite.recipient_character_id,
		invite.created_msec,
		invite.expires_msec,
		invite.status,
	]


func _increment_party_revision(party: Dictionary) -> void:
	party.revision = int(party.revision) + 1
	_projection_revision += 1


func _require_revision(party: Dictionary, expected_revision: int) -> Dictionary:
	if int(party.revision) != expected_revision:
		return _stale(int(party.revision), party)
	return {"accepted": true, "reason_code": "OK"}


func _party_for_character(character_id: String) -> Dictionary:
	var party_id := _party_id_by_character_id.get(character_id, "") as String
	return _active_party(party_id)


func _party_for_expedition(expedition_id: String) -> Dictionary:
	if expedition_id.is_empty():
		return {}
	for party_id: Variant in _parties_by_id:
		var party := _active_party(party_id as String)
		if not party.is_empty() and party.current_expedition_id == expedition_id:
			return party
	return {}


func _active_party(party_id: String) -> Dictionary:
	var party := _parties_by_id.get(party_id, {}) as Dictionary
	if party.is_empty() or party.lifecycle_state == STATE_DISBANDED:
		return {}
	return party


func _is_connected(character_id: String) -> bool:
	return (_characters_by_id.get(character_id, {}) as Dictionary).get("connected", false)


func _display_label(character_id: String) -> String:
	return (_characters_by_id.get(character_id, {}) as Dictionary).get(
		"display_label", character_id
	) as String


func _is_stable_definition_id(value: String) -> bool:
	return (
		not value.is_empty()
		and value == value.strip_edges()
		and value == value.to_lower()
		and not value.contains(" ")
		and not value.contains("/")
		and not value.contains("\\")
		and value.length() <= 128
	)


func _accepted(party: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"accepted": true,
		"reason_code": "OK",
		"reason_text": "Party command accepted.",
		"party_id": party.get("party_id", ""),
		"revision": int(party.get("revision", -1)),
	}
	result.merge(extra, true)
	return result


func _stale(current_revision: int, party: Dictionary = {}) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": "STALE_REVISION",
		"reason_text": "Party state changed; apply the latest snapshot and retry.",
		"party_id": party.get("party_id", ""),
		"revision": current_revision,
	}


func _rejected(reason_code: String, reason_text: String, party: Dictionary = {}) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"reason_text": reason_text,
		"party_id": party.get("party_id", ""),
		"revision": int(party.get("revision", -1)),
	}
