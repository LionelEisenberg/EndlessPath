# Madra Pool Unification Design

**Status:** Implemented (PR #16)

## Goal

Unify the disconnected zone Madra pool (ResourceManager) and combat Madra pool (VitalsManager) into a single economy. Cycling fills the pool, adventures drain it, combat uses the drained amount as its budget. Creates the core cycle->adventure resource loop.

## Unified Flow

```
Cycling -> Zone Pool (ResourceManager) -> Adventure Start drains pool
    -> Particle animation from orb to player character
    -> Camera zoom into player
    -> Combat Budget (VitalsManager) -> Madra spent on abilities
    -> Adventure End -> Nothing returns (Foundation stage)
    -> Player cycles again to refill
```

## Entry Mechanics

### Budget Calculation

```
foundation_capacity = Foundation attribute * 10
adventure_madra_budget = min(foundation_capacity, current_zone_madra)
```

- Foundation attribute determines the **maximum** you can bring into an adventure
- Your actual zone Madra determines **how much** you actually bring
- If zone Madra > Foundation capacity: enter with Foundation cap, excess stays in zone pool
- If zone Madra < Foundation capacity: enter with what you have

### Minimum Threshold

**50% of `foundation_capacity`**

- Adventure button shows red Madra badge below threshold
- Clicking below threshold triggers shake-reject animation on badge + log message
- Above threshold: badge shows gold with current/capacity values

### Two-Phase Adventure Start

1. Player clicks adventure button -> `ActionManager` checks threshold
2. `ActionManager` emits `adventure_start_requested(action_data)` signal
3. `ZoneTransition` receives signal, begins drain sequence:
   - Spawns staggered particles from Madra orb to player character
   - Drains Madra incrementally per particle
   - Particle count/size scales with budget ratio
4. After particles complete, zooms camera into player character
5. After zoom, calls `ActionManager.confirm_adventure_start(action_data, madra_budget)`
6. `ActionManager` emits `start_adventure(action_data, madra_budget)` signal
7. `AdventureViewState` transitions in, `AdventureView` initializes combat with budget

### Input Blocking

Full-screen `Control` overlay in `ZoneViewState` blocks all mouse input during the transition. `handle_input` also returns early to block keyboard shortcuts (inventory, etc.).

## Return Mechanics

### Foundation Stage (Current Scope)

Nothing returns. The full budget is consumed on entry regardless of outcome. The punishment for failure is missed loot/XP/gold, not extra Madra loss.

### Future Stages (Out of Scope)

Cultivation perks could unlock Madra recovery:
- Copper stage perk: 25% of unspent combat Madra returns on success
- Iron stage perk: 50% returns

## Visual Feedback

### Adventure Button (Zone View)

- Madra badge (icon + cost text) right-aligned on adventure action buttons
- Above threshold: gold text showing `current / capacity`
- Below threshold: red text showing `current / threshold`, name/description dimmed
- Click below threshold: badge scales up + shake-reject animation

### Particle Drain Animation

Staggered `FlyingParticle` instances stream from the Madra orb (via `ZoneResourcePanel.get_madra_orb_global_position()`) to the player character position. Count scales from 8-25 based on budget ratio. Particles use curved bezier paths (`curve_spread` parameter). Madra drains incrementally as each particle spawns.

### Camera Zoom

After drain completes, camera zooms to 3x on the player character over 0.5s. On return to zone view, camera resets to pre-adventure zoom/position.

## Architecture

### Key Files

| File | Responsibility |
|------|---------------|
| `singletons/resource_manager/resource_manager.gd` | Budget/threshold methods: `get_adventure_madra_capacity()`, `get_adventure_madra_budget()`, `get_adventure_madra_threshold()`, `can_start_adventure()` |
| `scenes/combat/combatant/vitals_manager/vitals_manager.gd` | `initialize_current_values(starting_madra)` accepts optional budget parameter |
| `singletons/action_manager/action_manager.gd` | Threshold check, two-phase signals: `adventure_start_requested` and `confirm_adventure_start()` -> `start_adventure` |
| `scenes/zones/zone_transition/zone_transition.gd` | Owns all transition logic: particle drain, camera zoom, Madra spending |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Madra badge display, threshold UX, shake-reject animation |
| `scenes/adventure/adventure_view/adventure_view.gd` | Receives `madra_budget`, passes to VitalsManager |
| `scenes/ui/main_view/states/zone_view_state.gd` | Input blocking overlay during transition |

### Signal Flow

```
User clicks adventure button
  -> ActionManager._execute_adventure_action()
  -> ActionManager.adventure_start_requested.emit(action_data)
  -> ZoneTransition._on_adventure_start_requested()
     -> particle drain + Madra spend
     -> camera zoom
  -> ActionManager.confirm_adventure_start(action_data, budget)
  -> ActionManager.start_adventure.emit(action_data, budget)
  -> AdventureViewState._on_start_adventure()
  -> AdventureView.start_adventure()
```

### Design Decisions

- **ZoneTransition as separate node**: Keeps ZoneResourcePanel display-only and ZoneTilemap free of adventure logic. Single responsibility for transition orchestration.
- **Particles to player character** (not adventure button): More dramatic, creates a "Madra flowing into you" fantasy. Camera zoom follows naturally.
- **Per-particle Madra drain** (not atomic): Visual and mechanical drain happen together — orb depletes as particles fly. See `docs/infrastructure/RESOURCES.md` for a future improvement to make this atomic.
- **`_has_saved_camera` bool**: Explicit flag for whether camera state needs restoring, replacing a `Vector2.ZERO` sentinel.

## Edge Cases

- **Zone Madra is 0**: Badge shows red, click triggers shake-reject + log message
- **Zone Madra between 0 and threshold**: Same as above
- **Zone Madra exactly at threshold**: Badge turns gold, adventure allowed
- **Zone Madra > Foundation capacity**: Enter with Foundation cap, excess stays in pool
- **Multiple adventures in sequence**: Each drains from current pool. Player must cycle between if depleted.
- **Input during transition**: Blocked by full-screen overlay + keyboard guard

## Out of Scope

- Adventure results screen / summary modal
- Madra return perks (tied to future cultivation stages)
- Per-adventure Madra cost variation (all use Foundation-based budget)
- Audio feedback for Madra drain
- Atomic Madra transfer (tracked in RESOURCES.md as LOW tech debt)
