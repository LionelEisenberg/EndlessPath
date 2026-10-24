# Abilities System

## Overview

Abilities are the actions combatants use in [combat](../combat/COMBAT.md). Each one is an `AbilityData` resource: costs, cooldown, cast time, and two lists of `CombatEffectData` — `effects_on_target` (sent to the enemy) and `effects_on_self` (sent to the caster). What an ability "is" (damage, heal, buff, interrupt…) is derived from those lists; there is no type tag.

The system has three parts:

- **Catalog and state** — `AbilityManager` (autoload) indexes the player catalog `resources/abilities/ability_list.tres` by `ability_id` and owns which abilities are unlocked and which sit in the 4 loadout slots. State lives on `SaveGameData`.
- **Abilities view** — a modal overlay (key A) for browsing unlocked abilities and arranging the loadout by button or drag-and-drop.
- **Combat runtime** — at fight start the equipped abilities become `CombatAbilityInstance`s; slot order maps to Q/W/E/R. Runtime behavior is documented in [COMBAT.md](../combat/COMBAT.md#ability-lifecycle).

Enemy abilities use the same `AbilityData` class but are referenced directly by enemy `CombatantData` and are not in the player catalog. Every ability's numbers are in [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md).

## Player Experience

1. A new save starts with Basic Strike (slot 1, Q) and Enforce (slot 2, W) unlocked and equipped; slots 3 and 4 are empty but usable.
2. Buying Pure Core Awakening on the Pure Madra path tree unlocks Empty Palm; buying the Power Font node unlocks Power Font. Unlocks are never auto-equipped. While any unlocked ability is not in a slot, the Abilities button on the zone view's dock shows the brass notification ring (no count).
3. On the zone view the player presses A (or clicks Abilities on the dock). A grey backdrop fades in while the jade Abilities book opens (one of the four menu books, see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#menu-books)).
4. **Left page:** the "Abilities" title ribbon, the inventory's arrows-and-dots filter selector (All / Offensive / Buff / Equipped), and a scrolling list of unlocked abilities on row bars (icon, name, a cost line such as "10 Madra · 15 s · 1 s cast", and the slot's key chip when equipped). The list is in loadout order: the equipped abilities in Q, W, E, R order, then the rest by name. There is no sort selector.
5. **Right page:** a "Loadout" plaque over a card with the 4 slots (96 px, the ability icon at 72 px, key chips Q/W/E/R) and "n / 4 equipped", then a details card for the ability pointed at. Every ability gets the same layout, so pointing around never moves anything:
   - **Header:** icon, name, Madra-type and source badges ("Pure · Path"), targeting plus any extras ("Targeted · Strips buffs"; "Interrupts", "Heals you", "Buffs you", "Debuffs"), and at the right a type icon for what it mainly does: crossed swords for damage, a heart for healing, a gold up arrow for a buff, a purple down arrow for a debuff.
   - **First stat line:** "Damage 34" (or "Heal") with a line under it showing how it adds up: "10 base", then each scaling attribute's icon and what it adds ("+17", "+7"). A buff or debuff shows "Effect" instead, for example "×1.5 damage" with "on your next attack" (or "for 5 s on you").
   - Then Cooldown, Cast time ("Instant" when there is none), Cost ("Free" when there is none), a divider, and the description in a four-line area.

   The details follow the pointer and keep the last ability pointed at; the first ability in the list is shown when the book opens. The damage or heal is worked out from the player's current attributes the first time an ability is described in an opening; pointing back at it reuses that value. The key an ability sits on shows on its row and in the loadout, so the card doesn't repeat it.
6. Right-clicking an ability equips it into the first empty slot, or unequips it when it is equipped. With 4 slots filled, right-clicking an unequipped ability does nothing. Dragging an ability onto a slot puts it there, replacing whatever was in it. Dragging one slot onto another swaps them, which changes the key.
7. Esc, A, the close tab on the book's top edge, or a click outside the book closes it. The next fight uses the loadout as arranged; the Abilities view cannot be opened during an adventure.

## Architecture

```
AbilityManager (autoload)                       singletons/ability_manager/ability_manager.gd
  ├─ _ability_catalog = preload(resources/abilities/ability_list.tres)
  ├─ _abilities_by_id: Dictionary               built in _ready()
  └─ _live_save_data → SaveGameData.unlocked_ability_ids / equipped_ability_ids

MainView (main_game.tscn)
├── MainViewStateMachine/AbilitiesViewState     scenes/abilities/abilities_view_state.gd (BookViewState)
├── GreyBackground                              shows/hides the book, calls animate_open()/animate_close()
└── AbilitiesView (Control)                     scenes/abilities/abilities_view.gd (MenuBookView, theme book_theme.tres)
    ├── BookLayer (centred, scale 2)
    │   ├── BookFrame %                         scenes/ui/book_frame/, style abilities_book_style.tres
    │   └── BookContent: TitleBanner "Abilities", FilterSelector % (SortSubBanner)
    └── PageLayer (centred, screen pixels)
        ├── AbilityScroll/AbilityList % (VBox): AbilityRow × N, down to the page's foot
        └── RightPage (VBox)
            ├── LoadoutPlaque ("Loadout")
            ├── LoadoutCard: SlotsRow (EquipSlot1..EquipSlot4, AbilityEquipSlot), SlotCounter %
            └── DetailCard %: HeaderRow (DetailIcon, DetailName, DetailBadges, DetailTags, TypeSlot/TypeIcon %),
                              StatList (PrimaryStat: PrimaryName %/PrimaryValue %; ExplainRow (34 px):
                              ExplainText %, ScalingPart1..3 %; CooldownStat, CastStat, CostStat),
                              DetailDescription % (four lines, fixed height), DetailSpacer

ScalingPart (HBoxContainer)                     scenes/abilities/scaling_part/scaling_part.gd
└── Icon % (attribute icon, 32 px), ValueLabel % ("+16.5")

AbilityRow (PanelContainer, PanelBookRow)        scenes/abilities/ability_row/ability_row.gd
├── RowHBox: IconSlot (PanelBookSlot)/Icon, TextBox (NameLabel, CostLabel), KeyChip (LabelBookKey)
└── signals hovered(row), quick_equip_requested(ability_id); drag source {"ability_id"}

AbilityDragPreview (Control)                    scenes/abilities/ability_row/ability_drag_preview.tscn
└── Slot (PanelBookSlot)/Icon                   the cursor icon for row and slot drags

AbilityEquipSlot (extends DropTargetSlot)       scenes/abilities/equip_slot/equip_slot.gd (PanelBookSlot)
├── CenterContainer: SlotIcon, EmptyLabel
└── KeyHintPanel (empty style): KeyHintLabel (LabelBookKey), bottom-right

AbilityStatsDisplay (HFlowContainer)            scenes/abilities/ability_stats_display/ability_stats_display.gd
├── StatTooltip                                 scenes/abilities/stat_tooltip/stat_tooltip.gd (built in code)
└── StatLabel × N (stat_label.tscn) and "·" separator Labels
```

`AbilityStatsDisplay` has no user left: its only one, the combat ability tooltip (`CombatAbilityTooltip`, modes `TIMING_COSTS` and `DAMAGE_TOTAL`), was replaced by the technique dock's `TechniqueTooltip`, which formats the same figures through `AbilityRow.format_cost()`, `format_seconds()` and `format_damage()`. The Abilities book's details card has its own stat list. `AbilityStatsDisplay`, `StatLabel` and `StatTooltip` stay in `scenes/abilities/` for now (style guide B8).

## Data Model

### AbilityData (`scripts/resource_definitions/abilities/ability_data.gd`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `ability_id` | `String` | `""` | Unique key used by the catalog, path unlocks and saves |
| `ability_name` | `String` | `""` | Display name |
| `description` | `String` (multiline) | `""` | Card details text |
| `icon` | `Texture2D` | null | Details card, row, loadout slot, technique dock slot, and the enemy's intent tab (`CastBar`, until the fight rework's PR 2 replaces it) |
| `madra_type` | `MadraType` | `NONE` | Flavor badge; independent of `damage_type` |
| `ability_source` | `AbilitySource` | `INNATE` | Badge text; no lifecycle logic reads it |
| `health_cost` / `madra_cost` / `stamina_cost` | `float` | 0.0 | Paid when a cast starts |
| `base_cooldown` | `float` | 0.0 | Starts when the cast resolves; 0 means none |
| `cast_time` | `float` | 0.0 | 0 = instant |
| `effects_on_target` | `Array[CombatEffectData]` | `[]` | Sent to the enemy |
| `effects_on_self` | `Array[CombatEffectData]` | `[]` | Sent to the caster |

| Enum | Values |
|------|--------|
| `MadraType` | `NONE` (physical / no affinity), `PURE` |
| `AbilitySource` | `INNATE` ("Always available, persists across path changes"), `PATH` ("Unlocked via path tree, resets with path" — the reset is not implemented) |

Effect fields, damage types and buff fields are documented in [COMBAT.md](../combat/COMBAT.md#data-model).

### Derived predicates and methods

| Method | Returns / true when | Used by |
|--------|---------------------|---------|
| `deals_damage()` | a `DAMAGE` effect is in `effects_on_target` | Outgoing-modifier consumption in `execute_ability()`; card tag |
| `heals_self()` | a `HEAL` effect is in `effects_on_self` | `SimpleEnemyAI` heal gate; card tag |
| `buffs_self()` | a `BUFF` effect is in `effects_on_self` | Card tag |
| `debuffs_target()` | a `BUFF` effect is in `effects_on_target` | Card tag |
| `interrupts_target()` | a `CANCEL_CAST` effect is in `effects_on_target` | Card tag |
| `strips_target_buffs()` | a `STRIP_BUFFS` effect is in `effects_on_target` | Card tag |
| `get_total_self_heal(attrs)` | summed scaled value of self `HEAL` effects | `SimpleEnemyAI` heal gate |
| `can_afford(vitals)` / `consume_costs(vitals)` | cost check / deduction against a `VitalsManager` | Combat gate and payment; `TechniqueSlot` affordability |
| `get_total_cost_display()` | `"Madra: 8"`-style string or `"Free"` | `_to_string()` only |
| `validate()` | id and name set | Never called |

Target shape, shown as a card tag:

| `effects_on_target` | `effects_on_self` | Tag | Examples |
|---------------------|-------------------|-----|----------|
| empty | populated | Self-Cast | Enforce, Coalesce |
| populated | empty | Targeted | Basic Strike, Empty Palm, Power Font, Madra Lash |
| populated | populated | Mixed | Famishing Bite (damage + Hunger on self) |

### AbilityListData (`ability_list_data.gd`)

`abilities: Array[AbilityData]`. The single instance is `resources/abilities/ability_list.tres` with `basic_strike`, `empty_palm`, `enforce`, `power_font`.

### Save data (`singletons/persistence_manager/save_game_data.gd`)

```gdscript
@export var unlocked_ability_ids: Array[String] = ["basic_strike", "enforce"]
@export var equipped_ability_ids: Array[String] = ["basic_strike", "enforce", "", ""]
```

`reset()` restores the same values. The equipped array is positional: index = slot = key (0 → Q … 3 → R); `""` is an empty slot.

## Core Systems

### AbilityManager API

`MAX_SLOTS = 4`. All methods return safe defaults when no save data is attached.

| Method | Behavior |
|--------|----------|
| `get_unlocked_abilities()` | `Array[AbilityData]` for unlocked ids, in unlock order; unknown ids skipped |
| `get_equipped_abilities()` | `Array[AbilityData]` in slot order, empty slots and unknown ids skipped |
| `get_ability_at_slot(i)` | id in slot `i`, or `""` (also for out-of-range) |
| `unlock_ability(id)` | No-op if already unlocked; `push_error` for ids not in the catalog; appends and emits `ability_unlocked(ability)` |
| `equip_ability(id)` | Errors if unknown or locked; returns true if already equipped; else fills the first empty slot and emits `equipped_abilities_changed`; returns false when all 4 are full |
| `equip_ability_at_slot(id, i)` | Errors if unknown, locked or `i` out of range; clears the id from any other slot, overwrites slot `i` (the previous occupant becomes unequipped), emits |
| `unequip_ability(id)` | No-op if not equipped; clears every slot holding the id, emits |
| `swap_slots(a, b)` | Swaps two slots (empty allowed), emits; silently ignores out-of-range indices |
| `is_ability_unlocked(id)` / `is_ability_equipped(id)` | Membership checks |
| `get_max_slots()` / `get_filled_slot_count()` | 4 / non-empty slot count |
| `has_unequipped_unlocks()` | Any unlocked id not in a slot; drives the dock's Abilities notification ring |

Signals: `ability_unlocked(ability: AbilityData)`, `equipped_abilities_changed()`.

On `_ready` and on `PersistenceManager.save_data_reset`, the manager re-reads `PersistenceManager.save_game_data` and pads `equipped_ability_ids` to 4 entries. There is no public lookup by id; the catalog is only reachable through the unlocked/equipped getters.

### Unlock flow

```
PathTreeView purchase → PathManager.purchase_node(node_id)
  ├─ deduct points, record purchase, _recalculate_effects()
  │     └─ _apply_effect(UNLOCK_ABILITY) → PathEffectsSummary.unlocked_abilities (read-only aggregate)
  └─ for each node effect with effect_type == UNLOCK_ABILITY:
        AbilityManager.unlock_ability(effect.string_value)   # string_value is an ability_id
            └─ ability_unlocked → Dock._on_ability_unlocked() → Abilities button ring
```

`purchase_node()` makes the `AbilityManager.unlock_ability()` call itself. `_apply_effect()` only aggregates into `PathEffectsSummary` (exposed by `PathManager.get_unlocked_abilities()`) and never calls `AbilityManager`; `AbilityManager` is the source of truth for unlock state.

| Path node (`resources/path_progression/pure_madra/nodes/`) | Type | Cost | Prerequisite | Unlocks |
|-------------------------------------------------------------|------|------|--------------|---------|
| `pure_core_awakening` | KEYSTONE | 1 point | none (root) | `empty_palm` + cycling technique `smooth_flow` |
| `power_font` | KEYSTONE | 1 point | `pure_core_awakening` | `power_font` |

Both require the FOUNDATION stage (default). `PathManager.reset_path()` does not touch `AbilityManager`, so PATH abilities stay unlocked and equipped after a path reset. Path progression is documented in [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md).

### Equip flows in the Abilities view

| Player action | Call | Result |
|---------------|------|--------|
| Right-click an unequipped row | `equip_ability(id)` (`AbilitiesView.toggle_equipped`) | First empty slot; nothing when all 4 are full |
| Right-click an equipped row | `unequip_ability(id)` | Slot cleared (no compaction) |
| Drag row → slot | `equip_ability_at_slot(id, slot)` | Placed in that slot; its old slot (if any) cleared; the occupant is unequipped |
| Drag slot → slot | `swap_slots(from, to)` | Swapped (reorders keys) |
| Drag slot → elsewhere | — | Nothing happens |

After each action `AbilitiesView.refresh()` rebuilds the rows, the loadout and the details. A right-click equip is deferred one frame, because it rebuilds the row that is still handling the click. The list is also rebuilt when the book opens and when the filter changes (the order is fixed: there is no sort selector).

### Filter and order (`AbilitiesView`)

| Filter | Shows unlocked abilities where |
|--------|-------------------------------|
| All | always |
| Offensive | `effects_on_target` is non-empty |
| Buff | `effects_on_target` is empty |
| Equipped | `AbilityManager.is_ability_equipped(id)` |

The filter is a `SortSubBanner` selector (`FILTER_OPTIONS`). The list is always in loadout order (`_order_by_loadout()`): equipped abilities in slot order (Q, W, E, R), then the rest by name A-Z. The sort selector was dropped on 2026-10-21 to give the list the room.

### Details card (`AbilitiesView`)

- `select_ability(id)` does nothing when `id` is already described, so moving the pointer around one row doesn't rebuild the card.
- `AbilityKind` (`_get_kind()`): DAMAGE if `deals_damage()`, else HEAL if `heals_self()`, else BUFF if `buffs_self()`, else DEBUFF if `debuffs_target()`, else OTHER. It picks the type icon (`_KIND_ICONS`: `stat_icons/combat_icon.png`, `stat_icons/health_icon.png`, `book/type_buff_ai.png`, `book/type_debuff_ai.png`) and the first stat line, and is left out of the tags.
- Damage (or heal) uses the first `DAMAGE` effect in `effects_on_target` (or `HEAL` in `effects_on_self`): `calculate_value()` with `CharacterManager.get_total_attributes_data()` (raw, before defense and modifiers), stored in `_value_previews` by ability id. The store is cleared when the book opens and on `CharacterManager.base_attribute_changed`, which also redraws the card. The breakdown shows `base_value` and, for each attribute with a non-zero `get_scaling()` (up to three), a `ScalingPart` with that attribute's icon and `get_scaling_contribution()`; those parts add up to `calculate_value()` (`test_combat_effect_data.gd`).
- A buff (`BuffEffectData`) reads `×damage_multiplier damage` (OUTGOING_DAMAGE_MODIFIER), `×N Attribute` per `attribute_modifiers` entry, or `N damage per tick`; under it, "on your next attack" when `consume_on_use`, else "for N s on you" ("on the target" for a debuff).
- Numbers use `AbilityRow.format_number()` / `format_seconds()` / `format_cost()`: whole numbers without ".0", others with up to two decimals.

### Loadout to combat

At fight start `AdventureCombat` sets the player's abilities to `AbilityManager.get_equipped_abilities()` (slot order, gaps skipped). `TechniqueDock` asks `AbilityManager.get_ability_at_slot()` for each instance's slot (the first free slot otherwise), so Q/W/E/R follow the slot even when an earlier slot is empty; on the map it previews the equipped loadout the same way. Loadout changes take effect at the next fight.

### AbilityStatsDisplay

| Mode | Pills | Used by |
|------|-------|---------|
| `DAMAGE` | DMG total (pulsing gold border), Base, one `+contribution` pill per non-zero scaling | Nothing since the Abilities book got its own stat list |
| `DAMAGE_TOTAL` | DMG total only | Nothing since the technique dock's tooltip replaced the combat ability tooltip |
| `TIMING_COSTS` | CD, Cast (or "Cast: Instant"), `·`, non-zero Madra/Stamina/Health costs | Nothing since the technique dock's tooltip replaced the combat ability tooltip |

- Damage pills read only `effects_on_target[0]` and only when it has a base value or scaling; values are raw (`calculate_value`, before defense and modifiers) using `CharacterManager.get_total_attributes_data()`.
- Hovering a pill shows `StatTooltip` with "Total Damage" (formula breakdown), "<ATTR> Scaling" (your value, %, contribution), "Base Damage", "Cooldown", "Cast Time" or "<Resource> Cost".
- Attribute colours: STR `#E06060`, BODY `#D4A84A`, AGI `#7DCE82`, SPI `#6BA4D4`, FND `#B07DD4`, CTL `#60C4B0`, RES `#C4884A`, WIL `#D470A0`.

## Integration Points

| System | Direction | Connection |
|--------|-----------|------------|
| `PersistenceManager` / `SaveGameData` | in / out | `unlocked_ability_ids`, `equipped_ability_ids`; `save_data_reset` re-binds |
| `PathManager` | in | `purchase_node()` calls `unlock_ability(string_value)` for `UNLOCK_ABILITY` effects |
| Combat (`AdventureCombat`, `TechniqueDock`) | out | `get_equipped_abilities()` for the player combatant; `get_ability_at_slot()` for key hints and key routing |
| `Dock` (Abilities `SystemMenuButton`) | out | Listens to `ability_unlocked` and `equipped_abilities_changed` (and re-reads on save reset); ring = `has_unequipped_unlocks()`, via `SystemMenuButton.set_notification()` |
| `MainView` state machine | in | `ZoneViewState` pushes `AbilitiesViewState` on `open_abilities` (A); `AbilitiesViewState` (`BookViewState`) closes on `ui_cancel`, `open_abilities`, the book's close tab or a backdrop click via `GreyBackground.hide_with_panel()` |
| `CharacterManager` | in | Attribute totals for the details card's damage and the technique tooltip's damage line; `base_attribute_changed` clears the book's damage previews |

## Existing Content

| Ability | Source | Madra type | Unlock | In catalog |
|---------|--------|------------|--------|------------|
| `basic_strike` | INNATE | NONE | New save | Yes |
| `enforce` | INNATE | NONE | New save | Yes |
| `empty_palm` | PATH | PURE | `pure_core_awakening` node | Yes |
| `power_font` | PATH | PURE | `power_font` node | Yes |
| `madra_lash` | (enemy) | NONE | Amorphous Spirit, Coalescing Spirit | No |
| `famishing_bite` | (enemy) | NONE | Starving and Ravenous Dreadbeast | No |
| `coalesce` | (enemy) | NONE | Coalescing Spirit | No |

Costs, timings, scaling and effects for all seven: [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md).

## Adding a New Ability

1. Create `resources/abilities/<ability_id>.tres` (enemy-only abilities go in `resources/combat/combatant_data/enemy_abilities/`). Set `ability_id`, `ability_name`, `description`, `icon`, `madra_type`, `ability_source`, costs, `base_cooldown`, `cast_time`.
2. Add effects: `CombatEffectData` sub-resources for damage, heal, `CANCEL_CAST` or `STRIP_BUFFS`; `BuffEffectData` for buffs. Put enemy-facing effects in `effects_on_target` and caster-facing ones in `effects_on_self`. A 0 s `base_cooldown` also removes the 1.5 s opening cooldown.
3. Player abilities: add the resource to `abilities` in `resources/abilities/ability_list.tres`. Enemy abilities: add it to the enemy's `CombatantData.abilities` instead.
4. Unlock: INNATE → add the id to the `unlocked_ability_ids` default and `reset()` in `save_game_data.gd`. PATH → add a `PathNodeEffectData` with `effect_type = UNLOCK_ABILITY` (8) and `string_value = "<ability_id>"` to a path node.
5. Update [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md).
6. Run the test suite (`test_ability_manager.gd` covers unlock/equip), then play an encounter; `CombatEffectData.calculate_value()` logs the scaling breakdown.

## Key Files

| File | Purpose |
|------|---------|
| `scripts/resource_definitions/abilities/ability_data.gd` | `AbilityData` definition, predicates, cost helpers |
| `scripts/resource_definitions/abilities/ability_list_data.gd` | `AbilityListData` catalog class |
| `resources/abilities/ability_list.tres` | Player ability catalog |
| `resources/abilities/*.tres` | Player abilities |
| `resources/combat/combatant_data/enemy_abilities/*.tres` | Enemy abilities |
| `singletons/ability_manager/ability_manager.gd` | Unlock/equip state |
| `singletons/persistence_manager/save_game_data.gd` | Ability save fields |
| `singletons/path_manager/path_manager.gd` | `purchase_node()` → `unlock_ability()` |
| `scenes/abilities/abilities_view.gd` / `.tscn` | Abilities view |
| `scenes/abilities/abilities_view_state.gd` | View state (open/close input) |
| `scenes/abilities/ability_row/ability_row.gd` / `.tscn` | Ability row (list entry, right-click equip, drag source) |
| `scenes/abilities/ability_row/ability_drag_preview.gd` / `.tscn` | Drag cursor icon for rows and slots |
| `tests/integration/test_abilities_book.gd` | Filter options, no sort selector, loadout order, rows, quick equip (full loadout), details (no status lines, damage and each attribute's part, buff effect, type icon, tags, timing and cost, one damage preview per opening, same layout for every ability, fits the page), large loadout icons |
| `scenes/abilities/scaling_part/scaling_part.gd` / `.tscn` | One attribute's icon and contribution in the damage breakdown |
| `scenes/abilities/equip_slot/equip_slot.gd` / `.tscn` | Loadout slot (drag source and drop target) |
| `scenes/common/drop_target_slot.gd` | Shared drop-target base (hover tint, drop routing) |
| `scenes/abilities/ability_stats_display/ability_stats_display.gd` | Stat pills (no screen uses them now; style guide B8) |
| `scenes/abilities/stat_label/stat_label.gd` / `.tscn` | Single stat pill |
| `scenes/abilities/stat_tooltip/stat_tooltip.gd` | Pill tooltip |
| `scenes/ui/dock/dock.gd`, `scenes/ui/dock/system_menu_button/system_menu_button.gd` | The dock's Abilities button and its notification ring |
| `tests/unit/test_ability_manager.gd` | AbilityManager unit tests |

## Work Remaining

### Bugs

- `[LOW]` `AbilityStatsDisplay` leaks a tween on every `DAMAGE` / `DAMAGE_TOTAL` `setup()`: `_setup_damage_border_pulse()` starts an endless `set_loops()` tween with `create_tween()` on the display, not the label, and the tween keeps its `StyleBoxFlat` alive. Each call adds another tween that runs until the display is freed. Nothing calls `setup()` now that the combat ability tooltip is gone, so the leak only matters if the component is used again. Creating the tween on the label (`label.create_tween()`) would let it die with the label.
- `[LOW]` `CombatEffectData.calculate_value()` logs four or more INFO lines per call, so every damage preview (the Abilities book, the technique tooltip's damage line) writes to the log as if a hit landed.
- `[LOW]` Stale "resource path" wording for `UNLOCK_ABILITY`: the enum comment and `string_value` comment in `path_node_effect_data.gd` and `PathEffectsSummary.unlocked_abilities` say resource path; the value is an `ability_id`. The `power_font` node's `benefit_summary` still reads "Madra Strike unlocked".

### Missing Functionality

- `[HIGH]` Path perks that modify abilities do nothing. `efficient_palm` ("-20% Palm Cost"), `lingering_silence` ("+2s Silence Duration"; Empty Palm has no silence), `focused_strike` ("+40% Strike Damage") and `strike_efficiency` ("-15% Stamina Cost"; Power Font costs no Stamina) have empty `effects`. `PathNodeEffectData` has no ability-modifier effect type and abilities have no modifier hook.
- `[MEDIUM]` No slot progression. `MAX_SLOTS` is a constant 4 and all slots are open on a new save; FOUNDATION_PLAYTHROUGH plans slots 3–4 as path-node rewards.
- `[MEDIUM]` `AbilitySource.PATH` has no lifecycle. Nothing relocks or unequips path abilities on `PathManager.reset_path()`, and `AbilityManager` has no relock API.
- `[MEDIUM]` `MadraType` has only `NONE` and `PURE`. Blackflame and Earth path themes exist with no enum values, trees or abilities.
- `[LOW]` No validation: `AbilityData.validate()` is never called, and unknown ids in the save are silently skipped.
- `[LOW]` No public lookup by id; `AbilitiesView._find_ability()` scans the unlocked list for every slot and for the details card.

### Content

- `[HIGH]` Four player abilities. FOUNDATION_PLAYTHROUGH plans three Pure Madra keystone abilities (Beats 2, 3b, 6); the Beat 6 burst/finisher does not exist. No defensive, sustain, heal, DoT or debuff ability exists for the player (the GDD's "Stand Your Ground" defensive buff is not built).

### UI

- `[LOW]` Dropping an ability onto an occupied slot unequips the occupant instead of moving it to the dragged ability's old slot, and dragging a slot onto empty space does nothing. Right-clicking a row is the only way to unequip.
- `[LOW]` Right-clicking an unequipped ability with all four slots full does nothing and says nothing, since the details card's "Loadout full" line was removed on 2026-10-21.
- `[LOW]` The damage breakdown shows at most three scaling attributes (`ScalingPart1..3`); a fourth would be left out.
- `[LOW]` Slots have no hover tooltip, and clicking a slot does not select its ability on the right page.
- `[LOW]` UI is built in code, against the project's scene-tree rule: `StatTooltip` builds its whole tree in `_init()` (no `.tscn`) and `AbilityStatsDisplay._add_separator()` creates Labels.

### Tech Debt

- `[LOW]` Public functions without `##` doc comments: `AbilityData.validate()`, `AbilityData.get_total_cost_display()`.
- `[LOW]` `test_ability_manager.gd` does not cover `swap_slots`, `equip_ability_at_slot` (move/overwrite), `get_ability_at_slot` bounds or save reset, and it replaces `AbilityManager._live_save_data` without restoring it. No tests cover `AbilityData` predicates or `can_afford`/`consume_costs`.
