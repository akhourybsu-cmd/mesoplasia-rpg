# Inventory, Loot, and Rewards

## Authoritative ownership model

Inventory belongs to a server-owned character/account record. Definitions are immutable content; stack entries and unique item instances are mutable state.

```text
InventoryState
  owner_character_id
  revision
  stack_entries: ItemDefinitionId -> quantity
  item_instances: ItemInstanceId -> ItemInstanceState
  equipment: EquipmentSlotId -> ItemInstanceId?
  transaction_watermarks
```

Final item categories, slot design, capacity, bind/trade rules, and equipment restrictions remain open.

## Transaction contract

Every mutation is expressed as an `InventoryTransaction` with transaction ID, actor/account/character, source, destination, item definition or instance ID, quantity, expected inventory/source revisions, reason, causation ID, and proposed write set.

Validation requires authenticated actor authority, item/instance existence, ownership, positive bounded quantity, adequate source quantity, compatible destination/slot, allowed gameplay phase, and unreplayed transaction ID. The server computes post-state; the client never submits a replacement inventory.

Commit rules:

1. validate the entire write set without mutation;
2. reserve/lock the aggregate or compare revision;
3. apply stack, instance, equipment, currency, and reward-watermark changes atomically;
4. persist at the transaction boundary;
5. record the result by transaction ID;
6. emit owner-private events and any permitted public equipment change.

If persistence fails, roll back in-memory mutation or retain it in an explicit not-yet-acknowledged transaction journal according to the backend contract. Never tell the client a grant succeeded before its durability policy is satisfied.

## Prevention rules

- Duplicate rewards/loot: transaction/entitlement ID is idempotent and persists with the grant.
- Negative stacks: deltas are server-calculated and postconditions require nonnegative bounded values.
- Unauthorized transfer: server derives source owner and validates destination policy.
- Stale overwrite: commands contain expected revision; clients send operations, not full arrays.
- Inventory overflow: apply an approved deterministic overflow rule (reject, mailbox-like holding, or server recovery pool); do not silently discard. This rule is open.
- Invalid equip: validate definition tags/slot/character state; atomic swap returns displaced item to inventory.

## Loot policy options

| Policy | Advantages | Disadvantages |
| --- | --- | --- |
| Personal loot | simplest concurrency and reconnect; no contention; easy idempotency | less shared excitement/trading value |
| Shared party pool | strong cooperation and visible scarcity | ownership/vote/timeout complexity |
| Need/greed | familiar and participatory | UI, timers, eligibility, disconnect, tie RNG |
| Leader distribution | mechanically simple | trust/agency risk and host pressure |
| Hybrid | flexible per reward | highest rules/content complexity |

**Provisional MVP recommendation:** personal loot entitlements resolved server-side, plus explicitly shared quest/world rewards where definitions require them. Loot distribution remains open and recorded in ADR-015.

## Reward settlement

Encounter, room, checkpoint, and expedition rewards produce `RewardEntitlement` records before inventory mutation. Each contains stable entitlement/transaction ID, recipients, source instance/encounter, reward definition/roll result, settlement state, and content version.

The server owns all loot RNG. Settlement may group inventory, currency, XP/progression (if later approved), and quest updates in one save transaction. On crash/retry, an already committed entitlement returns the original result. An unresolved entitlement resumes or rolls back; it never rolls again silently.

## Phase K development deposit boundary

Phase K proves one narrow post-settlement transfer without deciding the final economy. A registered development resource may move from the authenticated character's durable inventory into the shared Caden world stockpile through one atomic inventory/world/outcome transaction. The deposit ID is the persistent idempotency key; replay returns its original result and a conflicting reuse is rejected. A development-only project derives `AWAITING_RESOURCES` or `FUNDED` from the stockpile threshold. Funding does not spend the stockpile, unlock gameplay, or change production visuals; those policies remain explicit future decisions.

## Replication and privacy

An owning client receives full inventory/equipment snapshots and transaction results. Other clients receive only approved visible equipment/cosmetic projections, not private stacks/currency. Party loot sessions expose only policy-relevant entitlement/vote state.

## Tests

Test duplicate transaction replay across restart, concurrent commands with one revision winner, negative/overflow quantities, wrong owner, invalid slot, missing content ID, atomic equipment swap, save failure, personal reward reconnect, duplicate encounter completion, and privacy of replicated state.
