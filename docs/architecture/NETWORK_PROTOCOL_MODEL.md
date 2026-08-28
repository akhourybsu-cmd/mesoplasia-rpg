# Network Protocol Model

## Verified Godot 4.7 API baseline

Verified against the official Godot 4.7 documentation on 2026-08-27:

- `ENetMultiplayerPeer.new()`, `create_server(port, max_clients, max_channels, ...)`, and `create_client(address, port, channel_count, ...)` provide the initial desktop transport.
- assign the peer through `multiplayer.multiplayer_peer` (a `MultiplayerAPI` property);
- use `@rpc`, `Callable.rpc()`/`rpc_id()`, and capture `multiplayer.get_remote_sender_id()` inside the RPC call;
- `@rpc` supports `authority`/`any_peer`, `call_remote`/`call_local`, `unreliable`/`unreliable_ordered`/`reliable`, and a transfer-channel index;
- `SceneTree.set_multiplayer(multiplayer_api, root_path)` can isolate a custom `MultiplayerAPI` to a scene-tree branch;
- Godot RPCs require compatible NodePaths and RPC signatures, so RPC endpoints should be stable protocol gateway nodes rather than arbitrary replicated gameplay nodes.

References: [Godot 4.7 high-level multiplayer](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html) and [Godot 4.7 MultiplayerAPI](https://docs.godotengine.org/en/4.7/classes/class_multiplayerapi.html).

## Initial transport recommendation

Use ENet over UDP for LAN, direct-IP Internet hosting, listen servers, and self-hosted dedicated servers. Wrap it behind a narrow `NetworkEndpoint`/`TransportSession` boundary so commands/events are not coupled to `ENetMultiplayerPeer`. Do not add WebRTC, WebSocket, relays, matchmaking, UPnP automation, platform SDKs, or external middleware in the initial implementation.

ENet does not by itself establish application identity or promise confidentiality. Treat direct-IP friend-server traffic as unencrypted unless a separately verified protection layer is approved.

## Protocol gateway

Keep a small, identically pathed gateway under each network runtime. RPC methods only decode/encode versioned envelopes and hand them to application services. Do not RPC into dynamic NPCs, UI widgets, combatants, or arbitrary scene nodes; Godot requires matching RPC NodePaths/signatures and such coupling would make content changes protocol changes.

```text
CommandEnvelope
  protocol_version
  message_type
  session_id
  command_id
  client_sequence
  expected_revision?
  payload

ServerEnvelope
  protocol_version
  message_type
  server_sequence
  aggregate_id?
  aggregate_revision?
  causation_command_id?
  payload
```

Payloads use Godot-serializable primitives/arrays/dictionaries with strict schemas and size limits. Never transmit Resources, Objects, Callables, node paths, file paths, or client-selected scripts.

## Traffic and channel policy

Use three explicit ENet channels initially; channel 0 also has separate internal streams per transfer mode, but named separation makes policy review clearer.

| Channel | Traffic | Transfer mode | Policy |
| ---: | --- | --- | --- |
| 0 | handshake, auth, disconnect/shutdown, persistent commands/results, party, expedition, dialogue, inventory, combat | reliable ordered | correctness and ordering dominate; messages include IDs/revisions |
| 1 | movement input | unreliable ordered | small homogeneous sequenced packets; newer intent supersedes older |
| 2 | movement/world snapshots and corrections | unreliable ordered normally; reliable full snapshot on resync | homogeneous snapshot stream, sequence-filtered, interpolation-friendly |

Do not add a channel for every domain. Add one only after measurements show head-of-line blocking between materially different streams.

## Delivery by message type

| Message | Delivery | Recovery |
| --- | --- | --- |
| Movement intent | Unreliable ordered, sequenced | newer intent supersedes; server releases stuck input on timeout |
| Frequent avatar snapshots | Unreliable ordered | discard older sequence; request reliable scope snapshot on detected gap/divergence |
| Party/inventory/quest/launch commands | Reliable ordered | idempotency ID plus result replay |
| Combat commands/events | Reliable ordered | aggregate revision; combat snapshot and bounded event replay |
| Cosmetic transient event | Unreliable when safe | may be dropped; durable outcome remains in state |
| Reward/persistent event | Reliable ordered | transaction watermark and owner snapshot |
| Initial/reconnect/zone/instance snapshot | Reliable ordered | checksum/schema validation; retry or disconnect with reason |

## Version handshake

```text
ClientHello
  protocol_version
  game_build_version
  content_version
  content_manifest_hash
  supported_save_schema_range   # informational; server owns saves
  requested_capabilities
  client_nonce

ServerHello
  accepted/rejected
  readable_reason_code/text
  protocol_version
  game_build_version/range
  content_version/hash
  server_save_schema_version
  server_name
  server_rules/capabilities
  session_challenge
```

Order: transport connect -> version/content handshake -> authentication -> account/character load -> world snapshot. Reject before loading player data when protocol or content is incompatible. Save-schema mismatch is primarily a server startup/migration concern; it is advertised so clients can explain maintenance states, not so clients can migrate saves.

## Real-time movement path

| Parameter | Provisional start | Rule |
| --- | ---: | --- |
| Server physics/simulation | 30 Hz | Match or deterministically step movement adapter; measure before increasing. |
| Client input send | 20-30 Hz and on change | Include sequence, client tick, directional intent, button flags. |
| Snapshot rate | 15 Hz | Configurable 10-20 Hz; interest-filter to relevant zone. |
| Interpolation buffer | 120 ms | Configurable 100-150 ms. |
| Soft correction | >4 px divergence | Blend over short presentation window. |
| Hard correction | >32 px, invalid state, or teleport | Snap; clear/reseed prediction buffer. |
| Input silence | 250 ms | Server treats movement as zero until newer intent. |

Exact values are performance targets, not protocol constants.

An input message contains character/session binding implicitly from the server session, input sequence, local tick, cardinal intent, and permitted action flags. It does not contain trusted position. A snapshot contains server tick/sequence, avatar ID, position, velocity, facing, state flags, current zone/room, and last processed owner input sequence.

## Teleport and zone transfer

1. Stop accepting movement for the old transfer revision.
2. Server validates exit and reserves destination.
3. Server emits `ZoneTransferBegin` with transfer ID and destination content ID.
4. Client loads presentation and replies `ZoneContentReady`.
5. Server places avatar at authoritative entry, changes zone membership, increments revision, and sends a reliable full zone snapshot.
6. Client clears prediction/interpolation and acknowledges activation.

If readiness times out, the server keeps or returns the avatar to a safe authoritative state. It never accepts a client-proposed spawn position.

## Snapshot model

Snapshots are scope-specific (`HUB_ZONE`, `PARTY`, `EXPEDITION`, `COMBAT`, `PLAYER_PRIVATE`) and contain a schema version, scope ID, aggregate revision, server sequence/tick, and complete state for that scope. Client state stores apply a full snapshot atomically, discard older deltas, and request resync on revision gaps. Sensitive owner-only data is never included in broad zone snapshots.

## Security and limits at the protocol boundary

- cap packet/message sizes, array lengths, strings, and nested depth;
- sanitize display names/text and reject control characters where inappropriate;
- capture remote sender ID before any `await` because Godot reports `0` outside the active RPC context;
- do not let clients select paths, Resource URIs, scripts, save names, or definition files;
- use rate buckets by IP/session/account/command as appropriate;
- close on repeated malformed protocol, impossible state, or authentication abuse;
- keep error text useful without revealing secrets or allowlist membership unnecessarily.

## Compatibility policy

`PROTOCOL_VERSION` changes when wire schemas/semantics become incompatible. Additive optional fields require advertised capability negotiation. Never silently reinterpret a field. Maintain test fixtures for the current version and readable rejection tests for the immediately previous incompatible version.
