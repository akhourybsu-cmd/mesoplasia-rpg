extends SceneTree

const PartyService := preload("res://scripts/server/party/party_service.gd")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var service := PartyService.new()
	if not service.configure(3, 100, 200):
		_fail("Party service rejected valid configurable policies.")
		return
	if PartyService.new().configure(0, 100, 200):
		_fail("Party service accepted an invalid capacity policy.")
		return
	for identity: Dictionary in [
		_identity("development.character.1", "Alice"),
		_identity("development.character.2", "Bob"),
		_identity("development.character.3", "Cleo"),
		_identity("development.character.4", "Dara"),
	]:
		if not (service.connect_character(identity, 0) as Dictionary).accepted:
			_fail("Party service could not register a connected character.")
			return

	var invite_bob := service.invite_character(
		"development.character.1", "development.character.2", -1, 0
	) as Dictionary
	if not invite_bob.accepted:
		_fail("Unpartied Alice could not create a party by inviting Bob.")
		return
	var party_id := invite_bob.party_id as String
	var party := service.get_party_state(party_id) as Dictionary
	if (
		party.members.size() != 1
		or party.leader_character_id != "development.character.1"
		or party.lifecycle_state != PartyService.STATE_FORMING
	):
		_fail("Implicit party creation did not establish Alice as the sole leader.")
		return
	var duplicate := service.invite_character(
		"development.character.1", "development.character.2", party.revision, 1
	) as Dictionary
	if duplicate.accepted or duplicate.reason_code != "DUPLICATE_INVITE":
		_fail("Duplicate pending invite was not rejected.")
		return
	var stale_accept := service.accept_invite(
		"development.character.2", invite_bob.invite_id, int(party.revision) - 1, 2
	) as Dictionary
	if stale_accept.accepted or stale_accept.reason_code != "STALE_REVISION":
		_fail("Invite acceptance ignored a stale party revision.")
		return
	var accepted_bob := service.accept_invite(
		"development.character.2", invite_bob.invite_id, party.revision, 3
	) as Dictionary
	if not accepted_bob.accepted:
		_fail("Bob could not accept his valid invite.")
		return
	party = service.get_party_state(party_id)
	if party.members.size() != 2:
		_fail("Accepted invite did not atomically add Bob.")
		return
	var forged_accept := service.accept_invite(
		"development.character.3", invite_bob.invite_id, party.revision, 4
	) as Dictionary
	if forged_accept.accepted or forged_accept.reason_code != "INVALID_INVITE":
		_fail("Another character could accept Bob's invite.")
		return
	var ready_without_selection := service.set_ready(
		"development.character.1", true, party.revision
	) as Dictionary
	if ready_without_selection.accepted or ready_without_selection.reason_code != "INVALID_STATE":
		_fail("Party allowed readiness without an expedition selection.")
		return
	var unauthorized_selection := service.select_expedition(
		"development.character.2", "development.expedition.placeholder", party.revision
	) as Dictionary
	if unauthorized_selection.accepted or unauthorized_selection.reason_code != "NOT_LEADER":
		_fail("Non-leader selected the expedition placeholder.")
		return
	var selected := service.select_expedition(
		"development.character.1", "development.expedition.placeholder", party.revision
	) as Dictionary
	if not selected.accepted:
		_fail("Leader could not select a valid expedition placeholder.")
		return
	party = service.get_party_state(party_id)
	var alice_ready := service.set_ready("development.character.1", true, party.revision) as Dictionary
	var stale_bob_ready := service.set_ready(
		"development.character.2", true, party.revision
	) as Dictionary
	if not alice_ready.accepted or stale_bob_ready.accepted:
		_fail("Ready commands did not enforce aggregate revisions.")
		return
	party = service.get_party_state(party_id)
	var bob_ready := service.set_ready("development.character.2", true, party.revision) as Dictionary
	if not bob_ready.accepted or not (service.get_snapshot_for("development.character.1") as Dictionary).all_present_members_ready:
		_fail("Present members could not complete the ready check.")
		return

	party = service.get_party_state(party_id)
	var invite_cleo := service.invite_character(
		"development.character.1", "development.character.3", party.revision, 10
	) as Dictionary
	if not invite_cleo.accepted:
		_fail("Leader could not invite a third member.")
		return
	party = service.get_party_state(party_id)
	var accepted_cleo := service.accept_invite(
		"development.character.3", invite_cleo.invite_id, party.revision, 11
	) as Dictionary
	if not accepted_cleo.accepted:
		_fail("Third member could not accept within configured capacity.")
		return
	var snapshot := service.get_snapshot_for("development.character.1") as Dictionary
	for member: Variant in snapshot.members:
		if bool((member as Array)[3]):
			_fail("Membership change did not clear all readiness.")
			return
	party = service.get_party_state(party_id)
	var invite_dara := service.invite_character(
		"development.character.1", "development.character.4", party.revision, 12
	) as Dictionary
	if invite_dara.accepted or invite_dara.reason_code != "PARTY_FULL":
		_fail("Configured party capacity was not enforced before inviting.")
		return

	var unauthorized_transfer := service.transfer_leadership(
		"development.character.2", "development.character.3", party.revision
	) as Dictionary
	if unauthorized_transfer.accepted or unauthorized_transfer.reason_code != "NOT_LEADER":
		_fail("Non-leader transferred party leadership.")
		return
	var transferred := service.transfer_leadership(
		"development.character.1", "development.character.2", party.revision
	) as Dictionary
	if not transferred.accepted:
		_fail("Leader could not transfer leadership to a connected member.")
		return
	party = service.get_party_state(party_id)
	var unauthorized_kick := service.kick_member(
		"development.character.1", "development.character.3", party.revision
	) as Dictionary
	if unauthorized_kick.accepted or unauthorized_kick.reason_code != "NOT_LEADER":
		_fail("Former leader retained kick authority.")
		return
	var kicked := service.kick_member(
		"development.character.2", "development.character.3", party.revision
	) as Dictionary
	if not kicked.accepted or not (service.get_party_for_character("development.character.3") as Dictionary).is_empty():
		_fail("Leader could not remove Cleo from the party.")
		return

	party = service.get_party_state(party_id)
	if not service.disconnect_character("development.character.2", 20):
		_fail("Party member disconnect was not recorded.")
		return
	var disconnected := service.get_party_for_character("development.character.2") as Dictionary
	if (disconnected.members as Dictionary)["development.character.2"].connected:
		_fail("Disconnected member did not enter grace state.")
		return
	service.connect_character(_identity("development.character.2", "Bob"), 100)
	if not (service.get_party_for_character("development.character.2") as Dictionary).members["development.character.2"].connected:
		_fail("Reconnect inside grace did not retain membership.")
		return
	service.disconnect_character("development.character.2", 120)
	if service.tick(319):
		_fail("Disconnect grace expired too early.")
		return
	if not service.tick(320):
		_fail("Disconnect grace did not expire at its configured deadline.")
		return
	party = service.get_party_state(party_id)
	if (
		party.leader_character_id != "development.character.1"
		or (party.members as Dictionary).has("development.character.2")
	):
		_fail("Grace expiry did not remove Bob and deterministically transfer leadership.")
		return

	var cleo_invites_dara := service.invite_character(
		"development.character.3", "development.character.4", -1, 400
	) as Dictionary
	if not cleo_invites_dara.accepted:
		_fail("Unpartied Cleo could not create another ephemeral party.")
		return
	var cleo_party := service.get_party_state(cleo_invites_dara.party_id) as Dictionary
	var declined := service.decline_invite(
		"development.character.4", cleo_invites_dara.invite_id, cleo_party.revision, 401
	) as Dictionary
	if not declined.accepted:
		_fail("Dara could not decline her invite.")
		return
	var invite_again := service.invite_character(
		"development.character.3",
		"development.character.4",
		(service.get_party_state(cleo_party.party_id) as Dictionary).revision,
		500
	) as Dictionary
	if not invite_again.accepted or not service.tick(600):
		_fail("Pending invite did not expire deterministically.")
		return
	if (service.get_invite_state(invite_again.invite_id) as Dictionary).status != PartyService.INVITE_EXPIRED:
		_fail("Expired invite retained a pending status.")
		return

	party = service.get_party_state(party_id)
	var exposed := service.get_party_for_character("development.character.1") as Dictionary
	exposed.leader_character_id = "forged.character"
	if (service.get_party_state(party_id) as Dictionary).leader_character_id != party.leader_character_id:
		_fail("Party query exposed mutable authoritative state.")
		return
	var left := service.leave_party("development.character.1", party.revision) as Dictionary
	if not left.accepted or not left.disbanded:
		_fail("Last member leaving did not disband the ephemeral party.")
		return

	print("PASS: Phase E party capacity, invites, revisions, authority, readiness, leadership, grace, expiry, and disband.")
	quit(0)


func _identity(character_id: String, display_label: String) -> Dictionary:
	return {"character_id": character_id, "display_label": display_label}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
