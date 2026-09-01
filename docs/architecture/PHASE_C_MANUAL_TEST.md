# Phase C Manual Test

Phase C is an isolated network-connection sandbox. It does not put multiple players in Caden and it does not network movement or gameplay. The manual gate verifies host/join lifecycle, readable status, local-versus-remote presence, and clean disconnect behavior.

## One-window loopback test

1. Open `scenes/network/NetworkConnectionSandbox.tscn` in Godot.
2. Press **F6** to run the current scene.
3. Leave the address as `127.0.0.1` and the UDP port as `27890` unless that port is already occupied.
4. Enter a temporary access code and a display name. The access code is intentionally not stored by the project.
5. Select **Host + Local Client**.
6. Wait for the status to report authentication. One `LOCAL CLIENT` presence card should appear with a server-issued CharacterId and SessionId above it.
7. Select **Add Loopback Guest**. A second `REMOTE CLIENT` presence card should appear. The guest is a separate client branch connected through loopback ENet.
8. Select **Disconnect**. Both presence cards should clear and the status should return to the disconnected state.

The development access code is a placeholder admission check, not production-grade authentication. It is transmitted through direct ENet/UDP without confidentiality and must not be reused as a real password.

## Two-process or LAN join test

1. Start one sandbox instance as **Host + Local Client**.
2. Start a second project instance with the same scene.
3. On the same computer, join `127.0.0.1`. On another LAN computer, join the host computer's LAN address.
4. Use the same UDP port and temporary access code, but a different display name.
5. Confirm that each client shows exactly one local presence card and one remote presence card.
6. Disconnect the joining client and confirm its remote card disappears from the host client.

LAN testing may require allowing Godot through the host firewall for the selected UDP port. Public Internet exposure and port forwarding are outside this phase's acceptance gate.

## Expected limitations

- Identities and reconnect proofs exist only in server memory and disappear when the host stops.
- There is no account database, allowlist, persistence, encryption, relay, discovery, matchmaking, or platform identity.
- Clients cannot submit avatar spawn, identity, position, or gameplay outcomes. Phase C only replicates server-issued connection presence.
- Production `Main.tscn` and Caden remain on the existing local single-player path.
