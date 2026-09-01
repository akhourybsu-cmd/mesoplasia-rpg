# Phase E Manual Test

Phase E adds an authoritative, memory-only party model to the existing private-development network stack. The isolated sandbox starts one server and two real loopback ENet clients, then presents the same party through both client projections. It does not launch an expedition or change the production entry scene.

## Numbered party flow

1. Open `scenes/network/NetworkPartySandbox.tscn` in Godot.
2. Press **F6** to run the current scene.
3. Select **Start 2 Players** and wait until the LOCAL and GUEST rows show server-issued CharacterIds.
4. Select **1 Invite Guest**. The guest row should report one pending invitation.
5. Select **2 Guest Accept**. Both rows should show the same party ID, revision, leader, and two members.
6. Select **3 Select Test Expedition**. This selects a definition placeholder only; Phase E has no launch action.
7. Select **4 Local Ready**, then **5 Guest Ready**. Both rows should end with `ALL READY`.
8. Select **Reconnect Guest**. The guest should briefly appear in disconnect grace, then return with the same stable CharacterId and party membership. The guest ready flag must be cleared.
9. Optionally select **Transfer Leader**. Both rows should identify the guest CharacterId as leader.
10. Optionally select **Guest Leave**. The local row should retain a one-member party and the guest row should become `UNPARTIED`.
11. Select **Stop** to close both clients and the in-memory server cleanly.

## Acceptance checks

- Only the server creates parties, invitation IDs, membership, revisions, and leadership changes.
- Both client rows converge on the same party ID, revision, membership, selected definition, and readiness.
- The invited guest accepts its own invitation; another client cannot accept it on the guest's behalf.
- Only the leader can select the expedition placeholder or transfer leadership.
- Each member changes only its own ready flag, and all present members must be ready for `ALL READY`.
- Reconnect within grace preserves stable identity and membership but clears the disconnected member's readiness.
- There is no expedition launch, dungeon transition, combat, inventory, or persistence control in this phase.

## Expected limitations

- Party and invitation state is ephemeral and disappears when the sandbox server stops.
- The test expedition is a stable definition ID placeholder, not a playable expedition.
- The provisional default party capacity is four, but the server policy is configurable and domain rules do not hard-code four.
- The provisional invite and disconnect grace durations are server policy values.
- Direct ENet/UDP and the development access code remain suitable only for private testing.
- Production `Main.tscn` still launches the legacy local Caden path.
