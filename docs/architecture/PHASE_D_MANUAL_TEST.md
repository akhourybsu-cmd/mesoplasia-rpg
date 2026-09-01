# Phase D Manual Test

Phase D keeps the legacy single-player `Main.tscn` path available and provides an isolated networked Caden scene for acceptance. The demo starts an authoritative server, one locally controlled client, and one independently connected moving guest through loopback ENet.

## One-click two-client test

1. Open `scenes/network/NetworkedCadenSandbox.tscn` in Godot.
2. Press **F6** to run the current scene.
3. Select **Start 2-Client Demo**.
4. Wait for the status to report authentication. The HUD should show a server-issued CharacterId, `wayfarers_approach`, and two same-zone avatars.
5. Confirm that the `Moving Guest` walks back and forth without controlling the local camera, interaction prompt, or dialogue UI.
6. Move the local player with **WASD** or the arrow keys. Movement may look slightly stepped because this transitional implementation presents server snapshots without client prediction.
7. Approach a speaking NPC and press **E**. The server must accept the in-range interaction before the local conversation opens. The moving guest should continue independently.
8. Walk through the east exit into Town Square. The HUD should change to `town_square` and one same-zone avatar; the guest remains active in Wayfarer's Approach and does not have its world unloaded by the local transfer.
9. Return to Wayfarer's Approach. The HUD should return to two same-zone avatars.
10. Select **Reconnect Local** away from an obstacle. The transient peer/session is replaced while the same CharacterId and safe server-owned Caden location return.
11. Select **Stop** to close both clients and the in-memory server cleanly.

## Acceptance checks

- Exactly one camera, interaction prompt, and dialogue composition belongs to the local avatar.
- Both avatars are visible while they occupy the same zone; only the local avatar responds to keyboard input.
- Remote movement and patrol NPC movement remain readable and originate from server snapshots.
- A local zone transfer changes only that client's presented zone.
- NPC interaction is range-validated and does not stop the other player.
- Reconnect restores the stable CharacterId and a safe server-owned location.

## Expected limitations

- This is a private development sandbox over unencrypted ENet/UDP, not an Internet-ready hosting mode.
- Hub identities, reconnect proofs, and world state are memory-only and disappear when the demo server stops.
- Movement deliberately has no client prediction or interpolation yet, so visual stepping is expected.
- Inventory, quests, party, expedition, combat, persistence, relay, discovery, and matchmaking are outside Phase D.
- Production `Main.tscn` still launches the legacy local Caden path until networked parity is manually approved.
