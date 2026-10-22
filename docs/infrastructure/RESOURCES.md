# Resource Tracking (Madra and Gold)

Last updated: 2026-10-22

## Overview

`ResourceManager` is the global singleton for the game's two currencies:

- **Madra** is the primary resource. Cycling and Aura Well training fill it, and starting an adventure drains it. It is capped by the current cultivation stage.
- **Gold** is the secondary currency. It is earned from combat victories, is uncapped, and is spent at the Traveling Merchant.

Both values live on the shared `SaveGameData` (`madra`, `gold`) and persist with the rest of the save (see [PERSISTENCE.md](PERSISTENCE.md)). There are no other currencies.

## Player Experience

- **Madra orb (zone view):** the cultivator cabinet (`CultivatorPlate`) shows a stepped Madra orb (one of 33 frames) with `current / max`, and `+1.5 / s` while a training action trickles Madra. The cycling view's `CyclingResourcePanel` shows the same values (`Madra: current / max`).
- **Filling Madra:**
  - While cycling, Madra ticks up as long as the cursor stays inside the Madra ball.
  - The Aura Well training action adds 1.5 Madra per tick, quietly: no log line, but a "+1.5 Madra" floater on the map.
- **Spending Madra:** The adventure card reads "Needs <threshold> Madra · you have <madra>" with a Madra rod below the threshold, and "Ready · carries up to <capacity> Madra · <minutes> min run" with an ENTER tag at it. Clicking below the threshold shakes the Madra line and logs `Not enough Madra!`. Starting an adventure pours the budget from the cabinet's orb to the player as stepped Madra pellets.
- **Gold:** The cultivator cabinet's gold row shows the total. Each combat victory adds gold and logs `Gained N Gold`. The Merchant's shop and its activity card show the same total; a purchase spends the price and logs `Spent N Gold`.
- **Log lines:** `Gained N Madra` (cyan) for each Madra award that actually adds at least 1 (none for a quiet award or one the cap swallows), and `Gained/Spent N Gold` (gold) for every gold change made through `add_gold` / `spend_gold`.

## Architecture

```
ResourceManager (autoload Node)                 singletons/resource_manager/resource_manager.gd
  live_save_data: SaveGameData  ── madra, gold
  signals: madra_changed(new_amount), gold_changed(new_amount)
  reads: CultivationManager.get_max_madra() (pool cap), CharacterManager (adventure capacity)

Writers                                          Readers / listeners
  CyclingTechnique ── add_madra ─┐               CultivatorPlate, CyclingResourcePanel (orb + label; the plate's gold row)
  AwardResourceEffectData ── award_resource ─┤   AdventurePresenter (Madra line and rod, can_start_adventure)
  ZoneTransition ── spend_madra ─┤               ActionManager.select_action() (threshold gate)
  AdventureTilemap ── add_gold ─┤                GoalsPanel (a RESOURCE_AMOUNT step's figure)
  MerchantManager ── spend_gold ─┤               MerchantView, MerchantPresenter (gold, row affordability)
  DevPanel ── set_madra / set_gold ─┘            UnlockManager (re-evaluates all conditions on every change)
```

## Data Model

### Persistent fields (`SaveGameData`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `madra` | `float` | `25.0` | Kept in `[0, stage cap]` by `add_madra()` only |
| `gold` | `float` | `0.0` | Uncapped; kept at 0 or above by `set_gold()` and the `spend_gold()` check |

### `ResourceManager.ResourceType`

| Value | Name | Used by |
|-------|------|---------|
| `0` | `MADRA` | `AwardResourceEffectData.resource_type`, `award_resource()` |
| `1` | `GOLD` | Same as MADRA. No content uses it yet |

`RESOURCE_NAMES` (a static dict mapping `ResourceType` to a display name) has no readers.

### Madra caps

Two separate limits apply to Madra.

| Cap | Formula | Source | Value at start |
|-----|---------|--------|----------------|
| **Pool cap** (zone Madra) | `max_madra_base + max_madra_per_core_density_level × core_density_level` | `CultivationManager.get_max_madra()`: `AdvancementStageResource.get_max_madra(level)` for the current stage | Foundation: `100 + 5 × level`, which is 100 at level 0 and 150 at level 10 |
| **Adventure capacity** (and combat Madra max) | `FOUNDATION × 10`, using the total Foundation including equipment | `CharacterAttributesData.get_max_madra()` | 100 (Foundation 10) |

Only `foundation_advancement_stage.tres` exists (`max_madra_base = 100.0`, `max_madra_per_core_density_level = 5.0`). `CultivationManager.advancement_stage_resources` preloads only that resource.

### Public API

| Function | Behaviour |
|----------|-----------|
| `add_madra(amount, quiet = false)` | `madra = clamp(madra + amount, 0, CultivationManager.get_max_madra())`, then emits `madra_changed`. Logs `[color=cyan]Gained %d Madra[/color]` with the amount actually added, only when that is at least 1.0 and the award is not quiet, so a capped add is silent |
| `spend_madra(amount) -> bool` | All or nothing: deducts and emits only if `madra >= amount` |
| `set_madra(amount)` | `madra = max(0, amount)`, with no cap. Used by the dev panel only |
| `get_madra() -> float` / `can_afford_madra(amount) -> bool` | Read helpers |
| `get_adventure_madra_capacity() -> float` | `CharacterManager.get_total_attributes_data().get_max_madra()` |
| `get_adventure_madra_budget() -> float` | `min(capacity, madra)` |
| `get_adventure_madra_threshold() -> float` | `capacity × 0.5` |
| `can_start_adventure() -> bool` | `madra >= threshold` |
| `add_gold(amount, quiet = false)` | `gold += amount`, emits `gold_changed`, logs `[color=gold]Gained %d Gold[/color]` unless quiet |
| `spend_gold(amount) -> bool` | All or nothing. Logs `Spent %d Gold` on success. `MerchantManager.purchase()` calls it |
| `set_gold(amount)` | `gold = max(0, amount)`. Dev panel only |
| `get_gold() -> float` / `can_afford_gold(amount) -> bool` | Read helpers. `MerchantManager` uses both for a row's state and the "Need N more gold" shortfall |
| `award_resource(type, amount, quiet = false)` | Dispatches to `add_madra` / `add_gold` (passing `quiet`) and calls `Log.error` on an unknown type |

| Signal | Emitted |
|--------|---------|
| `madra_changed(new_amount: float)` | On every Madra mutation, and from `_update_resources()` in `_ready()` and on `save_data_reset` |
| `gold_changed(new_amount: float)` | On every gold mutation, from the same two places |

## Core Flows

### Madra sources

| Source | Amount | Path |
|--------|--------|------|
| Cycling | `base_madra_per_cycle × 0.08 / cycle_duration` per award, every `MADRA_PARTICLE_INTERVAL` (0.08 s) while the cursor is inside the Madra ball | `CyclingTechnique._process` calls `ResourceManager.add_madra()` |
| Aura Well training | 1.5 per training tick (the tick interval defaults to 1.0 s) | `aura_well_training_action.tres` → `effects_per_tick` → `aura_well_madra_trickle_effect.tres` (`AwardResourceEffectData`, `quiet = true`), which calls `award_resource(MADRA, 1.5, true)`. `TrainingActionData.get_madra_per_second()` reads the same effect for the cabinet's and the Now strip's rate |
| Dev panel | Sets an absolute value | `set_madra()` |

The total for a full cycle is roughly `base_madra_per_cycle × mouse accuracy`. That figure is reported by `cycle_completed`, but it is not awarded a second time. Per-award amounts for each technique:

| Technique | `base_madra_per_cycle` / `cycle_duration` | Per award | Logs each award? |
|-----------|-------------------------------------------|-----------|------------------|
| Foundation Technique | 50 / 8 s | 0.5 | No |
| Smooth Flow | 200 / 15 s | ~1.07 | Yes (~12/s) |
| Torrential Flow | 250 / 8 s | 2.5 | Yes (~12/s) |

### Madra sink: adventure start (two-phase)

```
AdventurePresenter.can_activate()          ── false below threshold → shake + "Not enough Madra!"
ActionManager.select_action()              ── re-checks can_start_adventure() before stopping anything
  → _execute_adventure_action() → adventure_start_requested(action_data)
ZoneTransition._on_adventure_start_requested()
  budget = get_adventure_madra_budget()
  8–25 MadraPellets (scaled by budget / capacity) from the cabinet's orb; each spawn calls
  spend_madra(floor(budget / count)), plus one final pellet for the remainder
  → camera zooms in (3x, 0.5 s)
ActionManager.confirm_adventure_start(action_data, budget) → start_adventure(action_data, budget)
AdventureView → PlayerManager.vitals_manager.initialize_current_values(budget)
```

Combat then spends Madra from the player's `VitalsManager`, not from `ResourceManager`. Unspent combat Madra is not returned when the adventure ends. Design history: [MADRA_UNIFICATION_DESIGN.md](MADRA_UNIFICATION_DESIGN.md).

### Gold source: combat victory

```
AdventureCombat._on_enemy_health_changed(<= 0)
  gold = floor(enemy.base_gold_drop × CombatChoice.gold_multiplier
               × AdventureActionData.gold_multiplier × CharacterManager.get_gold_multiplier())
  → trigger_combat_end(true, gold)
AdventureView._on_stop_combat → AdventureTilemap.handle_combat_result(true, gold)
  → ResourceManager.add_gold(gold)   (only when gold > 0)
```

A defeat awards 0. `CharacterManager.get_gold_multiplier()` is hard-coded to `1.0`. `AdventureView` also totals the gold for the end card (`AdventureResultData.gold_earned`).

### Gold sink: the merchant

The Traveling Merchant's shop is the only gold sink. A price is the item's `base_value`, rounded (`MerchantStockEntry.get_price()`). Stock, prices and limits are in [FOUNDATION_PLAYTHROUGH.md Beat 4](../progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented).

```
MerchantStockRow Buy → MerchantView → MerchantManager.purchase(stock, entry)
  get_purchase_status(): INVALID_ENTRY → SOLD_OUT (ledger count ≥ stock_limit)
                         → INSUFFICIENT_GOLD (not can_afford_gold(price)) → EQUIPMENT_FULL → OK
  OK → ResourceManager.spend_gold(price)                → gold_changed, "Spent N Gold"
     → InventoryManager.award_items(item, 1)
     → SaveGameData.merchant_ledgers[merchant_id].purchase_counts[entry_id] += 1
     → MerchantManager.item_purchased(stock, entry)
```

Every check runs before gold moves, so a blocked purchase changes nothing. `INVALID_ENTRY` covers a missing stock or entry, an empty `merchant_id` or `entry_id`, and an item that `award_items()` couldn't place: no item, or a class that doesn't match its `item_type`. Gold is uncapped and may hold fractions (dev panel), so the shortfall shown on a row is rounded up.

## Integration Points

| System | Connection |
|--------|------------|
| CultivationManager | `add_madra()`, the cultivator cabinet and the cycling resource panel read the pool cap from `get_max_madra()` |
| CharacterManager | `get_adventure_madra_capacity()` reads the total Foundation. `get_gold_multiplier()` feeds the gold formula |
| ZoneTransition | Spends the adventure budget one pellet at a time |
| ActionManager | Gates adventure start on `can_start_adventure()` in `select_action()`, before the running action stops, then passes the budget through `confirm_adventure_start` → `start_adventure`. `get_current_madra_per_second()` reports a running training action's trickle |
| AdventurePresenter | Draws the Madra line, rod and hint (or the ready line), sets affordability, and plays the shake-reject. Listens to `madra_changed`, and to `base_attribute_changed` and `inventory_changed` for the capacity |
| CultivatorPlate / CyclingResourcePanel | Draw the orb and the `current / max` label. Listen to `madra_changed`. The cabinet also shows the gold row (`gold_changed`) and the Madra rate |
| GoalsPanel | Shows a RESOURCE_AMOUNT quest step's `current / target` (`madra_changed`, `gold_changed`) |
| MerchantManager / MerchantView | `MerchantManager` checks `can_afford_gold()` and calls `spend_gold()` on a purchase. `MerchantView` shows the gold total and refreshes every row on `gold_changed` |
| AdventureTilemap / AdventureCombat | Calculate and award gold on victory |
| UnlockManager | Calls `_evaluate_all_conditions` on every `madra_changed` and `gold_changed`. That is about 12 times a second while cycling, once per Aura Well tick, and once per drain pellet |
| UnlockConditionData | `RESOURCE_AMOUNT` conditions read `get_madra()` / `get_gold()` (for example, `q_fill_core_madra_full` needs Madra >= 100) |
| AwardResourceEffectData | `process()` calls `award_resource(resource_type, amount, quiet)` (see [EFFECTS.md](EFFECTS.md)) |
| VitalsManager (via PlayerManager) | Holds combat Madra, seeded with the adventure budget |
| PathManager | Aggregates Madra perks (`madra_capacity_bonus`, `madra_generation_mult`, `adventure_madra_return_pct`, `madra_on_level_up`), but nothing applies them (see Work Remaining) |
| LogManager | Cyan Madra lines and gold-coloured gold lines |
| DevPanel | `set_madra()` / `set_gold()` with `[DEV]` log lines |

## Existing Content

| Resource | Type | Effect |
|----------|------|--------|
| `resources/cycling/advancement_stages/foundation_advancement_stage/foundation_advancement_stage.tres` | `AdvancementStageResource` | Pool cap `100 + 5 × level` |
| `resources/zones/spirit_valley_zone/zone_actions/aura_well_madra_trickle_effect.tres` | `AwardResourceEffectData` (`quiet = true`) | +1.5 Madra per Aura Well tick, with no log line |
| `resources/effects/award_resource/award_madra_5_effect_data.tres` | `AwardResourceEffectData` | +5 Madra, but nothing references it |
| `resources/combat/combatant_data/amorphous_spirit.tres` | `base_gold_drop` | 15 |
| `resources/combat/combatant_data/starving_dreadbeast.tres` | `base_gold_drop` | 20 |
| `resources/combat/combatant_data/ravenous_dreadbeast.tres` | `base_gold_drop` | 20 |
| `resources/items/consumables/crude_scale.tres`, `barely_coalesced_scale.tres` | `ChangeVitalsEffectData` (`madra_change = 20`) | Would add combat Madra to `PlayerManager.vitals_manager`, not the zone pool. Nothing calls `InventoryManager.use_consumable()` yet |

## Key Files

| File | Purpose |
|------|---------|
| `singletons/resource_manager/resource_manager.gd` | Madra and Gold state, caps, adventure budget helpers |
| `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd` | `get_max_madra(level)` (pool cap) |
| `scripts/resource_definitions/character/character_attributes_data.gd` | `get_max_madra()` (`FOUNDATION × 10`) |
| `scripts/resource_definitions/effects/award_resource_effect_data.gd` | Data-driven resource award |
| `scenes/cycling/cycling_technique/cycling_technique.gd` | Per-particle Madra generation |
| `scenes/zones/zone_transition/zone_transition.gd`, `madra_pellet.gd` | Adventure-start drain |
| `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` | Adventure card's Madra line, rod and threshold UX |
| `scenes/zones/cultivator_plate/cultivator_plate.gd` | Zone Madra orb, Madra rate and gold display |
| `singletons/cultivation_manager/cultivation_manager.gd` | `get_max_madra()` (pool cap) |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Gold reward formula (`_calculate_gold_reward`) |
| `tests/unit/test_resource_manager.gd` | See Tech Debt: does not call `ResourceManager` |
| `tests/unit/test_quiet_madra.gd` | Calls the real `add_madra()` / `award_resource()`: quiet awards add without a log line, capped adds log nothing |
| `tests/unit/test_cultivation_getters.gd` | `CultivationManager.get_max_madra()` follows the level |

## Work Remaining

### Bugs

- `[MEDIUM]` Madra log spam. `add_madra()` logs `Gained N Madra` on every call that adds 1.0 or more, and cycling calls it every 0.08 s. Smooth Flow (~1.07 per award) and Torrential Flow (2.5) therefore write about 12 log lines a second, which fill the log board and the 200-line history. Foundation Technique (0.5) writes none, and the Aura Well's quiet trickle writes none. Aggregate the cycling messages, for example once per cycle, or make them quiet too.
- `[LOW]` `add_madra()` clamps to 0 when the current stage has no `AdvancementStageResource`, because the cap falls back to `0.0`. Only the Foundation resource exists, so this will empty the pool when a Copper breakthrough ships.
- `[LOW]` `set_madra()` ignores the pool cap. This is dev-panel only, and the next `add_madra()` pulls the value back to the cap.

### Missing Functionality

- `[HIGH]` Path Madra perks are not applied. `PathManager._recalculate_effects()` fills in `PathEffectsSummary.madra_capacity_bonus` (Expanded Core "+25 Max Madra"), `madra_generation_mult` (Madra Surge "+10% Madra Gen"), `adventure_madra_return_pct` (Madra Reclamation "+10% Madra Return") and `madra_on_level_up` (Breakthrough Surge "+10 Madra on Level Up"), but no production code reads `PathManager.get_effects()`. Players spend path points on these perks for no effect. See [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md).
- `[LOW]` `CharacterManager.get_gold_multiplier()` always returns `1.0` (a `TODO`).
- `[LOW]` Madra is not transferred atomically. `ZoneTransition` deducts the budget pellet by pellet and ignores the `bool` returned by `spend_madra()`. If anything else spends Madra mid-drain, the budget passed to combat can exceed what was actually deducted. Deduct once up front and animate the drain separately.

### Tech Debt

- `[MEDIUM]` `tests/unit/test_resource_manager.gd` (37 tests) never calls `ResourceManager`. Each test repeats the arithmetic inline on a bare `SaveGameData`, and the `_create_manager()` helper is unused. The capacity tests assert `50 + FOUNDATION × 10` (150) while the code computes `FOUNDATION × 10` (100), so the suite passes whatever the production code does. Rewrite it against the real script, with stubbed stage and attribute data.
- `[LOW]` UnlockManager re-evaluates every unlock condition on each `madra_changed`, which is high-frequency during cycling and the drain.
- `[LOW]` `RESOURCE_NAMES` is untyped (`static var RESOURCE_NAMES = {...}`) and unused. The public functions have no `##` doc comments, and the locals in `add_madra()` are untyped.
