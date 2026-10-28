# Resource Tracking (Madra and Gold)

## Overview

`ResourceManager` is the global singleton for the game's two currencies:

- **Madra** is the primary resource. Cycling and Aura Well training fill it, and starting an adventure drains it. It is capped by the current cultivation stage.
- **Gold** is the secondary currency. It is earned from combat victories, is uncapped, and is spent at the Traveling Merchant.

Both values live on the shared `SaveGameData` (`madra`, `gold`) and persist with the rest of the save (see [PERSISTENCE.md](PERSISTENCE.md)). There are no other currencies.

## Player Experience

- **Madra orb (zone view):** the cultivator cabinet (`CultivatorPlate`) shows a Madra orb whose pixel-art liquid shader (`lacquer_madra_orb.gdshader`) fills to `current / max` with a moving surface, with `current / max` beside it, and its rate: `+1.5 / s` while a training action trickles Madra, or the Madra the cycling ball is drawing (`+13.3 / s`, measured over the last second and weighted by time, so it holds steady). The cycling board has no readout of its own: its Madra pellets fly into this orb.
- **Filling Madra:**
  - While cycling, Madra ticks up as long as the cursor stays inside the Madra ball, a quiet step every 0.08 s with a pellet flying into the cabinet's orb.
  - The Aura Well training action adds 1.5 Madra per tick, quietly: no log line, but a "+1.5 Madra" floater on the map.
- **Spending Madra:** Below the threshold the adventure card shows a Madra rod and `<madra> / <threshold>`; at it, a brass frame, "<minutes> min run · carries <capacity> Madra" and an ENTER tag. Clicking below the threshold shakes the Madra row and logs `Not enough Madra!`. Starting an adventure pours the budget from the cabinet's orb to the player as stepped Madra pellets.
- **Gold:** The cultivator cabinet's gold row, at the right of its bottom row, shows the total. Each combat victory adds gold and logs `Gained N Gold`. The Merchant's shop and its activity card show the same total; a purchase spends the price and logs `Spent N Gold`.
- **Log lines:** `Gained N Madra` (cyan) for each Madra award that actually adds at least 1 (none for a quiet award or one the cap swallows; cycling's steps are quiet, and a finished cycle writes one cyan `Cycle · +186 Madra · …` line instead), and `Gained/Spent N Gold` (gold) for every gold change made through `add_gold` / `spend_gold`.

## Architecture

```
ResourceManager (autoload Node)                 singletons/resource_manager/resource_manager.gd
  live_save_data: SaveGameData  ── madra, gold
  signals: madra_changed(new_amount), gold_changed(new_amount)
  reads: CultivationManager.get_max_madra() (pool cap), CharacterManager (adventure capacity)

Writers                                          Readers / listeners
  CyclingTechnique ── add_madra ─┐               CultivatorPlate (orb + label; the plate's gold row)
  AwardResourceEffectData ── award_resource ─┤   AdventurePresenter (Madra line and rod, can_start_adventure)
  ZoneTransition ── spend_madra ─┤               ActionManager.select_action() (threshold gate)
  AdventureTilemap ── add_gold ─┤                GoalsPanel (a RESOURCE_AMOUNT step's figure)
  MerchantManager ── spend_gold ─┤               MerchantView, MerchantPresenter (gold, row affordability)
  Dev tools ── set_madra / set_gold ─┘           UnlockManager (re-evaluates all conditions on every change)
```

## Data Model

### Persistent fields (`SaveGameData`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `madra` | `float` | `25.0` | Never below 0, and never raised past the stage cap, by `add_madra()` only. A pool already above the cap (a failed Tribulation lowers the level, and so the cap) is kept until it is spent |
| `gold` | `float` | `0.0` | Uncapped; kept at 0 or above by `set_gold()` and the `spend_gold()` check |

### `ResourceManager.ResourceType`

| Value | Name | Used by |
|-------|------|---------|
| `0` | `MADRA` | `AwardResourceEffectData.resource_type`, `award_resource()` |
| `1` | `GOLD` | Same as MADRA. No content uses it yet |

### Madra caps

Two separate limits apply to Madra.

| Cap | Formula | Source | Value at start |
|-----|---------|--------|----------------|
| **Pool cap** (zone Madra) | `max_madra_base + max_madra_per_core_density_level × core_density_level` | `CultivationManager.get_max_madra()`: `AdvancementStageResource.get_max_madra(level)` for the current stage | Foundation: `100 + 5 × level`, which is 100 at level 0 and 150 at level 10 |
| **Adventure capacity** (and combat Madra max) | `FOUNDATION × 10`, using the total Foundation including equipment | `CharacterAttributesData.get_max_madra()` | 100 (Foundation 10) |

Two stage resources exist, both preloaded by `CultivationManager.advancement_stage_resources`: `foundation_advancement_stage.tres` (`max_madra_base = 100.0`, `max_madra_per_core_density_level = 5.0`) and `copper_advancement_stage.tres` (`600.0` and `10.0`). Copper starts at the 600 that Foundation ends on, so the breakthrough never drops the cap. A failed Tribulation does lower it, by 5 levels' worth (25 Madra in Foundation), which can leave a full pool above the cap.

The two caps are independent. The adventure threshold is half the capacity (`FOUNDATION × 5`), so it can be higher than the pool cap. In the Foundation stage, once the total FOUNDATION attribute is above `20 + level`, even a full pool cannot start an adventure (see Work Remaining).

### Public API

| Function | Behaviour |
|----------|-----------|
| `add_madra(amount, quiet = false) -> float` | `madra = clampf(before + amount, 0, maxf(CultivationManager.get_max_madra(), before))`, then emits `madra_changed` (`resource_manager.gd:75-84`). The cap is the larger of the stage's and the pool already held, so a gain stops at the cap, a pool above it is kept (a gain is lost, never trimmed) and a negative amount still lowers it. Returns the amount actually added, snapped to 0.001: 0 at the cap or above it. Logs `[color=cyan]Gained %d Madra[/color]` with that amount, only when it is at least 1.0 and the award is not quiet, so a capped add is silent |
| `spend_madra(amount) -> bool` | All or nothing: deducts and emits only if `madra >= amount` |
| `set_madra(amount)` | `madra = max(0, amount)`, with no cap. Used by the dev tools only (the dev panel and `DevCommands`) |
| `get_madra() -> float` | Read helper |
| `get_adventure_madra_capacity() -> float` | `CharacterManager.get_total_attributes_data().get_max_madra()` |
| `get_adventure_madra_budget() -> float` | `min(capacity, madra)` |
| `get_adventure_madra_threshold() -> float` | `capacity × 0.5` |
| `can_start_adventure() -> bool` | `madra >= threshold` |
| `add_gold(amount, quiet = false)` | `gold += amount`, emits `gold_changed`, logs `[color=gold]Gained %d Gold[/color]` unless quiet |
| `spend_gold(amount) -> bool` | All or nothing. Logs `Spent %d Gold` on success. `MerchantManager.purchase()` calls it |
| `set_gold(amount)` | `gold = max(0, amount)`. Dev tools only (the dev panel and `DevCommands`) |
| `get_gold() -> float` / `can_afford_gold(amount) -> bool` | Read helpers. `MerchantManager` uses both for a row's state and the "Need N more gold" shortfall |
| `award_resource(type, amount, quiet = false)` | Dispatches to `add_madra` / `add_gold` (passing `quiet`) and calls `Log.error` on an unknown type |

| Signal | Emitted |
|--------|---------|
| `madra_changed(new_amount: float)` | On every Madra mutation, and from `_ready()` and on `save_data_reset` |
| `gold_changed(new_amount: float)` | On every gold mutation, from the same two places |

## Core Flows

### Madra sources

| Source | Amount | Path |
|--------|--------|------|
| Cycling | `base_madra_per_cycle × 0.08 / cycle_duration` per step, every `MADRA_PARTICLE_INTERVAL` (0.08 s, the remainder carried) while the cursor is inside the Madra ball. Nothing at or above the cap | `CyclingTechnique.advance()` (from `_process`) calls `ResourceManager.add_madra(amount, true)` (quiet) for each step |
| Aura Well training | 1.5 per training tick (the tick interval defaults to 1.0 s) | `aura_well_training_action.tres` → `effects_per_tick` → `aura_well_madra_trickle_effect.tres` (`AwardResourceEffectData`, `quiet = true`), which calls `award_resource(MADRA, 1.5, true)`. `TrainingActionData.get_madra_per_second()` reads the same effect for the cabinet's and the Now strip's rate |
| Dev tools | Sets an absolute value | `set_madra()` |

A full cycle with the cursor on the ball the whole time pays `base_madra_per_cycle` to within one step: it pays the whole 0.08 s steps its `cycle_duration` holds, all 100 for the 8 s techniques, and 187 (199.47 Madra) for Smooth Flow, whose 15 s hold 187.5. The frame rate does not change the step count: the steps carry their remainder, the frame that ends the cycle counts only the time left in it, and a step pays to within 1e-6 s of its 0.08 s, so float error cannot drop the last one. `cycle_completed` reports what the steps really added (`CycleResult.madra_added`); it is not awarded a second time. Every step is quiet, and the finished cycle writes one log line. Per-step amounts for each technique:

| Technique | `base_madra_per_cycle` / `cycle_duration` | Per step |
|-----------|-------------------------------------------|----------|
| Foundation Technique | 50 / 8 s | 0.5 |
| Smooth Flow | 200 / 15 s | ~1.07 |
| Torrential Flow | 250 / 8 s | 2.5 |

### Madra sink: adventure start (two-phase)

```
AdventurePresenter.can_activate()          ── false below threshold → shake + "Not enough Madra!"
ActionManager.select_action()              ── re-checks can_start_adventure() before stopping anything
  → adventure_start_requested(action_data)
ZoneTransition, on adventure_start_requested
  budget = get_adventure_madra_budget()
  8–25 LacquerPellets (scaled by budget / capacity) from the cabinet's orb; each spawn calls
  spend_madra(floor(budget / count)), plus one final pellet for the remainder
  → as the last pellet lands, camera zooms in (1.5x the player's zoom, 0.5 s)
ActionManager.confirm_adventure_start(action_data, budget) → start_adventure(action_data, budget)
AdventureView → PlayerManager.vitals_manager.initialize_current_values(budget)
```

Combat then spends Madra from the player's `VitalsManager`, not from `ResourceManager`. Unspent combat Madra is not returned when the adventure ends. Design history: [MADRA_UNIFICATION_DESIGN.md](MADRA_UNIFICATION_DESIGN.md).

### Gold source: combat victory

```
AdventureCombat: the enemy's health reaches 0
  gold = floor(enemy.base_gold_drop × CombatChoice.gold_multiplier
               × AdventureActionData.gold_multiplier × CharacterManager.get_gold_multiplier())
  → trigger_combat_end(true, gold)
AdventureView → AdventureTilemap.handle_combat_result(true, gold)
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
| CultivationManager | `add_madra()`, the cultivator cabinet and the cycling technique (its cap check) read the pool cap from `get_max_madra()` |
| CharacterManager | `get_adventure_madra_capacity()` reads the total Foundation. `get_gold_multiplier()` feeds the gold formula |
| ZoneTransition | Spends the adventure budget one pellet at a time |
| ActionManager | Gates adventure start on `can_start_adventure()` in `select_action()`, before the running action stops, then passes the budget through `confirm_adventure_start` → `start_adventure`. `get_current_madra_per_second()` reports a running training action's trickle, or the running cycle's measured rate while the cycling action runs |
| AdventurePresenter | Draws the Madra line, rod and hint (or the ready line), sets affordability, and plays the shake-reject. Listens to `madra_changed`, and to `base_attribute_changed` and `inventory_changed` for the capacity |
| CultivatorPlate | Draws the orb and the `current / max` label. Listens to `madra_changed`. The cabinet also shows the gold row (`gold_changed`) and the Madra rate (also while cycling, on `CyclingManager.madra_rate_changed`) |
| GoalsPanel | Shows a RESOURCE_AMOUNT quest step's `current / target` (`madra_changed`, `gold_changed`) |
| MerchantManager / MerchantView | `MerchantManager` checks `can_afford_gold()` and calls `spend_gold()` on a purchase. `MerchantView` shows the gold total and refreshes every row on `gold_changed` |
| AdventureTilemap / AdventureCombat | Calculate and award gold on victory |
| UnlockManager | Re-evaluates every unlock condition on every `madra_changed` and `gold_changed`. That is about 12 times a second while cycling, once per Aura Well tick, and once per drain pellet |
| UnlockConditionData | `RESOURCE_AMOUNT` conditions read `get_madra()` / `get_gold()` (for example, `q_fill_core_madra_full` needs Madra >= 100) |
| AwardResourceEffectData | `process()` calls `award_resource(resource_type, amount, quiet)` (see [EFFECTS.md](EFFECTS.md)) |
| VitalsManager (via PlayerManager) | Holds combat Madra, seeded with the adventure budget |
| PathManager | Aggregates Madra perks (`madra_capacity_bonus`, `madra_generation_mult`, `adventure_madra_return_pct`, `madra_on_level_up`), but nothing applies them (see Work Remaining) |
| LogManager | Cyan Madra lines and gold-coloured gold lines |
| DevPanel, DevCommands | `set_madra()` / `set_gold()` with `[DEV]` log lines |

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
| `scenes/cycling/cycling_technique/cycling_technique.gd` | Madra steps while the cursor follows the ball |
| `scenes/zones/zone_transition/zone_transition.gd` | Adventure-start drain |
| `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` | Adventure card's Madra line, rod and threshold UX |
| `scenes/zones/cultivator_plate/cultivator_plate.gd` | Zone Madra orb, Madra rate and gold display |
| `singletons/cultivation_manager/cultivation_manager.gd` | `get_max_madra()` (pool cap) |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Gold reward formula (the static `gold_reward_for()`) |

Tests: `tests/unit/test_resource_manager.gd` and `tests/unit/test_quiet_madra.gd`, among others named after what they check; [TESTING.md](../testing/TESTING.md#coverage-gaps) lists what they do not cover.

## Work Remaining

### Bugs

- `[LOW]` `set_madra()` ignores the pool cap. This is dev-tools only, and the next `add_madra()` keeps the value: a gain above the cap is lost, and the pool stays where the dev tools put it until it is spent.
- `[LOW]` When the current stage has no `AdvancementStageResource` the cap falls back to `0.0`, so `add_madra()` adds nothing (the pool is kept). Foundation and Copper have resources and nothing reaches another stage, but a later stage needs its resource before its Tribulation.
- `[LOW]` The adventure threshold can exceed the pool cap. The threshold is `FOUNDATION × 5` and the Foundation-stage pool cap is `100 + 5 × level`, so once the total FOUNDATION attribute is above `20 + level` the pool can never reach the threshold and no adventure can start. Shipped content stays well below that: base FOUNDATION is 10, and only the Leeching Ring adds to it (+2). Raise the pool cap with Foundation, or base the threshold on the pool.

### Missing Functionality

- `[HIGH]` Path Madra perks are not applied. `PathManager` fills in `PathEffectsSummary.madra_capacity_bonus` (Expanded Core "+25 Max Madra"), `madra_generation_mult` (Madra Surge "+10% Madra Gen"), `adventure_madra_return_pct` (Madra Reclamation "+10% Madra Return") and `madra_on_level_up` (Breakthrough Surge "+10 Madra on Level Up"), but no production code reads `PathManager.get_effects()`. Players spend path points on these perks for no effect. See [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md).
- `[LOW]` `CharacterManager.get_gold_multiplier()` always returns `1.0` (a `TODO`).
- `[LOW]` Madra is not transferred atomically. `ZoneTransition` deducts the budget pellet by pellet and ignores the `bool` returned by `spend_madra()`. If anything else spends Madra mid-drain, the budget passed to combat can exceed what was actually deducted. Deduct once up front and animate the drain separately.

### Tech Debt

- `[LOW]` UnlockManager re-evaluates every unlock condition on each `madra_changed`, which is high-frequency during cycling and the drain.
- `[LOW]` `award_resource()` and the Madra and gold functions have no `##` doc comments, and the locals in `add_madra()` are untyped.
