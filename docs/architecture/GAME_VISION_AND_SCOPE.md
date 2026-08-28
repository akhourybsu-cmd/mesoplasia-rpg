# Game Vision and Scope

## Locked direction

Mesoplasia is a small-group cooperative fantasy RPG set during the **Halcyon Age**, after the Age of Reckoning. The game begins in **Caden**, immediately outside Terrebonne. Caden is a persistent social and preparation hub; Terrebonne is not part of the current playable implementation. Festival of the Six references remain contextual and restrained.

Alex hosts a private server for friends. The server may run headlessly, as a listen server with a local host player, or as a one-player local host. Every mode uses the same authoritative gameplay rules.

The core loop is:

1. connect or start a local authoritative session;
2. load a persistent account and character;
3. meet, interact, form a party, and prepare in Caden;
4. launch a real-time top-down dungeon expedition;
5. enter server-resolved turn-based encounters;
6. settle rewards and return to Caden after success, retreat, defeat, or abandonment;
7. persist Caden and player progression between server sessions.

## Architectural quality priorities

In descending order when tradeoffs are otherwise equal:

1. preserve the working Caden build;
2. migrate incrementally;
3. keep the server authoritative;
4. separate simulation from presentation;
5. keep content data-driven and ID-addressed;
6. test rules without rendered graphics;
7. make persistence and reconnect idempotent;
8. keep solo behavior on the same ruleset;
9. support modest self-hosting;
10. avoid MMO-scale complexity.

## Provisional capacity envelope

| Dimension | Provisional recommendation | Status |
| --- | --- | --- |
| Expedition party | 1-4 characters | Open; configurable, do not encode four in domain rules. |
| Connected users | Small friend group; start with 4-8 configuration capacity | Open exact cap. |
| Active expeditions | One for MVP; every record still has an expedition ID | Open whether concurrent parties are required. |
| Encounter size | Modest authored groups | Balance/content remains undefined. |
| Server tick | 30 authoritative simulation ticks/second | Provisional measurement target. |
| Movement snapshots | 10-20/second, begin at 15 | Provisional and network-tested. |
| Client interpolation buffer | 100-150 ms, begin at 120 ms | Provisional. |
| Dirty save flush | 30 seconds plus transaction/checkpoint saves | Provisional. |
| Reconnect grace | 120 seconds | Provisional and configurable. |
| Combat turn timeout | 60 seconds | Provisional, configurable, and not a final design decision. |

These values belong in configuration or policy objects, not scattered constants.

## Explicit initial non-goals

- MMO-scale population, public matchmaking, public server browser, or global presence.
- PvP, battle royale, guilds, global auction house, or cross-server economy.
- Microtransactions, voice chat, cloud accounts, external identity providers, or required cloud services.
- Relay/NAT-punch infrastructure, platform lobby SDKs, or external networking middleware.
- Infinite worlds or a fully procedural dungeon generator.
- Mobile-first networking, cheat-proof competitive security, or elaborate web administration.
- Combat, dungeon, networking, persistence, or server implementation during this planning task.

## Canon guardrails

- Do not invent Caden institutions, named residents, factions, classes, ancestries, religions, or history.
- Do not define final character creation, progression, equipment taxonomy, combat balance, dungeon story, or defeat consequences.
- The existing `development_get_your_bearings` objective remains development-only content.
- Architecture may describe scopes and records; it must not turn placeholders into canon.

## Success definition for the architecture

The blueprint succeeds if each future milestone can be built behind a testable boundary, the Caden build remains playable at every checkpoint, authority and reconnect behavior are explicit, and open product decisions can change without replacing the networking or persistence foundations.
