# Madra Pool Unification Design

## Goal

Unify the disconnected zone Madra pool (ResourceManager) and combat Madra pool (VitalsManager) into a single economy. Cycling fills the pool, adventures drain it, combat uses the drained amount as its budget. Creates the core cycle→adventure resource loop.

## Current State (Broken)

- **Zone Madra** (ResourceManager): Earned from cycling, capped by stage, persisted in SaveGameData. Has no sinks — accumulates forever.
- **Combat Madra** (VitalsManager): Initialized fresh from Foundation attribute (`50 + Foundation * 10`). No connection to zone pool. Evaporates on adventure end.
- **Result**: Two parallel pools with no relationship. Cycling has no purpose beyond filling a number. Adventures have no resource cost.

## Unified Flow

```
Cycling → Zone Pool (ResourceManager) → Adventure Start drains pool
    → Combat Budget (VitalsManager) → Madra spent on abilities
    → Adventure End → Nothing returns (Foundation stage)
    → Player cycles again to refill
```

## Entry Mechanics

### Budget Calculation

```
foundation_capacity = 50 + (Foundation attribute * 10)
adventure_madra_budget = min(foundation_capacity, current_zone_madra)
```

- Foundation attribute determines the **maximum** you can bring into an adventure
- Your actual zone Madra determines **how much** you actually bring
- If zone Madra > Foundation capacity: enter with Foundation cap, excess stays in zone pool
- If zone Madra < Foundation capacity: enter with what you have

### Minimum Threshold

**Starting value: 50% of `foundation_capacity`**

- Adventure button is disabled below this threshold
- Tooltip shows: "Requires X Madra (you have Y)"
- Test plan: Does the player need > 2 cycling sessions to reach threshold? If yes, lower to 33%.

### On Adventure Start

1. Calculate `adventure_madra_budget`
2. `ResourceManager.spend_madra(adventure_madra_budget)`
3. `VitalsManager.initialize_current_values(adventure_madra_budget)` — pass the budget instead of using Foundation-based max
4. Visual: FlyingParticles from Madra orb → adventure button

## Return Mechanics

### Foundation Stage (Current Scope)

Nothing returns. The full budget is consumed on entry regardless of outcome. This is the "admission fee" for attempting an adventure.

### Future Stages (Out of Scope)

Cultivation perks unlock Madra recovery:
- Copper stage perk: 25% of unspent combat Madra returns on success
- Iron stage perk: 50% returns
- etc.

These perks create a progression incentive: higher cultivation = more efficient adventuring.

## Failure Penalty

Same as success — adventure budget is consumed on entry. The punishment for failure is missed loot/XP/gold, not extra Madra loss. Fair and predictable.

## Visual Feedback

### Adventure Button (Zone View)

- Shows Madra cost: "Fight the Baddies! (75 Madra)"
- Below threshold: button disabled, muted, shows "Need X more Madra"
- Above threshold: button enabled, normal styling

### On Adventure Start

FlyingParticles stream from the Madra orb (in ZoneResourcePanel) toward the adventure action button. Reuses the existing `FlyingParticle` system from cycling. After particles complete, adventure transitions in.

### During Adventure

Combat Madra HUD shows the budget amount (not the zone pool max). Player sees their actual available Madra for this adventure.

## Implementation Changes

### Files to Modify

| File | Change |
|------|--------|
| `singletons/resource_manager/resource_manager.gd` | Add `get_adventure_madra_budget()` and `can_afford_adventure()` methods |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | `initialize_current_values()` accepts optional `starting_madra` parameter |
| `scenes/adventure/adventure_view/adventure_view.gd` | Calculate budget, spend from zone pool, pass to vitals |
| `singletons/action_manager/action_manager.gd` | Check Madra threshold before firing `start_adventure` |
| `scenes/zones/zone_action_button/` | Show Madra cost, disable below threshold |
| `scenes/zones/zone_info_panel/zone_info_panel.gd` | Wire particle animation on adventure start |

### New Methods

```
ResourceManager.get_adventure_madra_budget() -> float
    foundation_capacity = 50 + CharacterManager.get_foundation() * 10
    return min(foundation_capacity, get_madra())

ResourceManager.get_adventure_madra_threshold() -> float
    foundation_capacity = 50 + CharacterManager.get_foundation() * 10
    return foundation_capacity * 0.5

ResourceManager.can_afford_adventure() -> bool
    return get_madra() >= get_adventure_madra_threshold()
```

### VitalsManager Change

```gdscript
# Before
func initialize_current_values() -> void:
    current_health = max_health
    current_madra = max_madra  # Always fresh from Foundation
    current_stamina = max_stamina

# After
func initialize_current_values(starting_madra: float = -1.0) -> void:
    current_health = max_health
    current_madra = starting_madra if starting_madra >= 0.0 else max_madra
    current_stamina = max_stamina
```

### Adventure Start Flow Change

```
# Before
AdventureView.start_adventure():
    PlayerManager.vitals_manager.initialize_current_values()

# After
AdventureView.start_adventure():
    var budget = ResourceManager.get_adventure_madra_budget()
    ResourceManager.spend_madra(budget)
    PlayerManager.vitals_manager.initialize_current_values(budget)
```

## Signals

No new signals needed. Existing `madra_changed` on ResourceManager fires when budget is spent, updating the zone Madra orb automatically.

## Edge Cases

- **Zone Madra is 0**: Adventure button disabled. Player must cycle first.
- **Zone Madra between 0 and threshold**: Button disabled. Shows "Need X more Madra."
- **Zone Madra exactly at threshold**: Button enabled. Player enters with threshold amount.
- **Zone Madra > Foundation capacity**: Player enters with Foundation cap. Excess stays in zone pool.
- **Adventure starts during auto-cycle**: Cycling stops via existing `stop_cycling` signal before adventure drains pool. No race condition.
- **Multiple adventures in sequence**: Each one drains from the current zone pool. Player must cycle between adventures if pool is depleted.

## Out of Scope

- Adventure results screen / summary modal
- Madra return perks (tied to future cultivation stages)
- Per-adventure Madra cost variation (all use Foundation-based budget)
- Audio feedback for Madra drain
- Madra display on adventure button (InkbrushButton needs text rework — can be a follow-up)
