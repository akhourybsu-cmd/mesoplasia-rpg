# Caden Wayfarer Protection Audit v1.2

## Decision

Wayfarer's Approach structural recomposition v5 remains authoritative and unchanged. No additional library candidate and no replacement-terrain experiment is justified for this gate.

The existing inn, scene geometry, exits, collision, road corridors, authored surface hierarchy, and approved `05` and `07` pilot assets remain protected. Deferred and rejected Wayfarer candidates remain unintegrated.

## Rationale

Eight approved authored surfaces include grass matched to the current field. Replacing only the base grass would introduce seams without solving a documented threshold or route problem. The active zone already provides joined rooms, road shoulders, layered perimeter planting, open travel lanes, and deliberate player overlap.

## Evidence

- Protection-audit ZIP SHA-256: `18ee4f5039ead183b1a6286dfd41389c339b6b0129f52031b63cec76fec96b21`.
- Fourteen active Compatibility captures byte-match the accepted v5 baseline.
- Full-zone, primary gameplay, road, room, player-overlap, tree-depth, and exact `1280 x 720` display evidence pass.
- `tests/caden_wayfarers_approach_runtime_test.gd` passes.

## Next Authority

Future Wayfarer changes require a specific visible defect and a new inactive comparison. Broad terrain replacement or additional asset integration is not authorized by this audit.
