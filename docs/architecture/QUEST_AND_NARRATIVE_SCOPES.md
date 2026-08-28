# Quest and Narrative Scopes

## Definition and progress separation

`QuestDefinition` and `DialogueDefinition` are immutable content. `QuestProgress`, `DialogueSessionState`, persistent flags, votes, and reward watermarks are server-owned runtime/persistent records. UI displays projected state and text; it does not advance authoritative progress by changing labels or indices.

## Quest scope matrix

| Scope | Owner/authority | Persistence | Replication | Who may advance | Join in progress | Reward scope |
| --- | --- | --- | --- | --- | --- | --- |
| `PLAYER` | server record keyed by CharacterId | player/character save | owner only | owner command plus validated server events | load current progress | character entitlement |
| `PARTY` | server party/quest record | checkpoint while relevant; durable if narrative requires | current eligible party | policy-authorized command or party event | snapshot; eligibility defined by quest | party or per-member entitlements |
| `SERVER_WORLD` | server world record | world save | affected connected players | only validated world rule/admin; never one silent client | full relevant world snapshot | world unlock and explicit participant grants |
| `EXPEDITION` | expedition instance | active checkpoint/outcome record | expedition members | dungeon/combat/party events | expedition snapshot | expedition participants by eligibility rule |

Scope is declared by content and validated; it is not inferred from which UI is open.

## Dialogue presentation versus decision state

Ordinary linear Caden conversations default to player-scoped sessions with local text presentation. Multiple players may talk to the same ordinary NPC. A conversation only requires a shared lock when it mutates exclusive NPC/world state.

Authoritative dialogue session state includes session ID, definition/conversation ID, scope owner ID, participants, current authoritative node where needed, available choice IDs, decision policy, revision, persistent flags already applied, and outcome/transaction watermarks.

## Cooperative decision record

```text
PartyDecisionState
  decision_id
  scope_owner_id
  eligible_character_ids
  choice_ids
  policy                 # leader / majority / unanimous / individual / server
  deadline
  votes_by_character_id
  tie_policy
  revision
  final_outcome?
```

The server checks voter identity, eligibility, choice existence, deadline, duplicate/replaced-vote policy, and revision. It resolves exactly once and emits an authoritative outcome before flags/rewards apply.

## Decision policy recommendations

| Situation | Provisional policy | Notes |
| --- | --- | --- |
| Ordinary Caden talk | individual/player-scoped | never pauses everyone |
| Personal quest choice | individual | private persistence unless content says otherwise |
| Expedition route preference | leader or majority by definition | low-impact decisions should not overuse voting UI |
| Shared irreversible narrative choice | majority; unanimous only when explicitly authored | tie and disconnect rules required |
| Server-world decision | explicit world rule/host-approved policy | no single client may silently decide it |

Party-vote and story-leader policy remain open. Definitions select from approved policies rather than embedding custom vote algorithms.

## Progress event model

Quest services subscribe to authoritative domain events such as `ZoneEntered`, `InteractionCompleted`, `CombatWon`, `ItemGranted`, `ExpeditionCompleted`, and `DialogueDecisionResolved`. They validate scope/eligibility and emit `QuestProgressUpdated` plus reward intents. They do not read UI state or arbitrary scene labels.

Current `development_get_your_bearings` can migrate by mapping its zone IDs to a player-scoped progress record; its definition and development-only flag remain intact.

## Failure, reconnect, and tests

- A vote timeout resolves by the definition's explicit rule (provisional majority of cast votes, leader tie-break; no votes -> safe default/cancel).
- Disconnect does not erase a recorded vote; eligibility after grace follows policy.
- Reconnect receives current dialogue/decision/quest snapshots.
- Persistent flags and rewards share an idempotent save transaction where they are causally linked.
- Tests cover each scope, unauthorized advancement, join-in-progress, ties, deadlines, disconnect, duplicate resolution, world privacy, and reward deduplication.
