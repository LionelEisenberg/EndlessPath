# Madra Pool Unification — Implementation Plan

**Status:** Complete (PR #16)

**Goal:** Unify zone Madra and combat Madra into a single economy — cycling fills the pool, adventures drain it, combat uses the drained amount as budget.

**Architecture:** Two-phase adventure start with `ZoneTransition` node orchestrating particle drain, camera zoom, and Madra spending before switching to adventure view.

**Source Design:** `docs/infrastructure/MADRA_UNIFICATION_DESIGN.md`

---

## What Was Built

The implementation expanded beyond the original 4-task plan into a richer system:

| Original Plan | What Was Actually Built |
|---------------|------------------------|
| ResourceManager budget methods | Same as planned |
| VitalsManager starting_madra param | Same as planned |
| AdventureView spends Madra directly | Two-phase start: ActionManager -> ZoneTransition -> confirm |
| ActionManager threshold check | Same, plus `adventure_start_requested` / `confirm_adventure_start` signals |
| *(not planned)* | ZoneTransition node — particle drain, camera zoom orchestration |
| *(not planned)* | Madra badge on adventure buttons with shake-reject UX |
| *(not planned)* | Camera zoom into player before adventure start |
| *(not planned)* | Input blocking overlay during transition |
| *(not planned)* | FlyingParticle curve_spread / curve_bias params |

## Commits (PR #16)

1. `feat(resources): add adventure Madra budget and threshold methods`
2. `feat(combat): VitalsManager accepts starting_madra parameter`
3. `feat(adventure): spend zone Madra on adventure start, pass as combat budget`
4. `feat(adventure): block adventure start below Madra threshold`
5. `feat(adventure): show Madra cost on adventure buttons, particle drain animation`
6. `feat(adventure): two-phase adventure start with threshold check`
7. `feat(particles): add curve_spread and curve_bias params to FlyingParticle`
8. `feat(adventure): Madra drain particle animation from orb to player`
9. `feat(ui): adventure button Madra badge with icon and threshold UX`
10. `refactor(adventure): remove duplicate Madra spend from AdventureView`
11. `style: user editor adjustments`
12. `feat(adventure): camera zoom into player before adventure start`
13. `refactor(zones): extract transition logic into ZoneTransition node`
14. `fix(zones): type safety, signal cleanup, and cached node refs`
15. `refactor(zones): replace Vector2.ZERO sentinel with explicit bool for saved camera`

## Key Files Changed

| File | Change |
|------|--------|
| `singletons/resource_manager/resource_manager.gd` | Added 4 adventure budget/threshold methods |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | `initialize_current_values()` accepts `starting_madra` |
| `scenes/adventure/adventure_view/adventure_view.gd` | Receives `madra_budget` signal param, passes to VitalsManager |
| `singletons/action_manager/action_manager.gd` | Threshold check, two-phase signals |
| `scenes/zones/zone_transition/zone_transition.gd` | **New** — particle drain, camera zoom, Madra spending |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Madra badge, threshold UX, shake-reject, signal cleanup |
| `scenes/ui/main_view/states/zone_view_state.gd` | Input blocking overlay |
| `scenes/ui/main_view/states/adventure_view_state.gd` | Updated signal handler signature |
| `scenes/zones/zone_tilemap/zone_tilemap.gd` | Added `class_name ZoneTilemap` |
| `scenes/ui/flying_particle/flying_particle.gd` | Added `curve_spread` and `curve_bias` params |
