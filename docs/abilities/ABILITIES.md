# Abilities System

Last updated: 2026-10-18

## Overview

Abilities are the actions combatants use in [combat](../combat/COMBAT.md). Each one is an `AbilityData` resource: costs, cooldown, cast time, and two lists of `CombatEffectData` — `effects_on_target` (sent to the enemy) and `effects_on_self` (sent to the caster). What an ability "is" (damage, heal, buff, interrupt…) is derived from those lists; there is no type tag.

The system has three parts:

- **Catalog and state** — `AbilityManager` (autoload) indexes the player catalog `resources/abilities/ability_list.tres` by `ability_id` and owns which abilities are unlocked and which sit in the 4 loadout slots. State lives on `SaveGameData`.
- **Abilities view** — a modal overlay (key A) for browsing unlocked abilities and arranging the loadout by button or drag-and-drop.
- **Combat runtime** — at fight start the equipped abilities become `CombatAbilityInstance`s; slot order maps to Q/W/E/R. Runtime behavior is documented in [COMBAT.md](../combat/COMBAT.md#ability-lifecycle).

Enemy abilities use the same `AbilityData` class but are referenced directly by enemy `CombatantData` and are not in the player catalog. Every ability's numbers are in [ABILITIES_MATRIX.md](ABILITIES_MATRIX.md).

## Player Experience

1. A new save starts with Basic Strike (slot 1, Q) and Enforce (slot 2, W) unlocked and equipped; slots 3 and 4 are empty but usable.
2. Buying Pure Core Awakening on the Pure Madra path tree unlocks Empty Palm; buying the Power Font node unlocks Power Font. Unlocks are never auto-equipped. While any unlocked ability is not in a slot, the ABILITIES button in the system menu shows a badge.
3. On the zone view the player presses A (or clicks ABILITIES). A grey backdrop and the Abilities view fade in: title "ABILITIES", subtitle "Manage your combat techniques", a LOADOUT row of 4 slots with Q/W/E/R hints and an `n / 4` counter, filter buttons (All / Offensive / Buff / Equipped), a sort dropdown (Equipped First / Name A-Z / Madra Cost / Cooldown), and a scrolling list of unlocked-ability cards.
4. Each card shows the icon, name, a PURE badge for Pure Madra abilities, a source badge (Innate / Path), damage pills when the ability hits a target (DMG total with a pulsing gold border, Base, one pill per scaling attribute showing its contribution), timing and cost pills (CD, Cast, Madra/Stamina/Health), and an EQUIP / UNEQUIP button in the bottom-right corner. Hovering a pill shows a breakdown tooltip computed from the player's current attributes.
5. Clicking a card toggles its details: effect tags (Damage, Heal, Buff, Debuff, Interrupt, Strip, plus Targeted / Self-Cast / Mixed) and the description.
6. EQUIP puts the ability in the first empty slot; with 4 slots filled the button reads SLOTS FULL and is disabled. Dragging a card onto a slot puts it there, replacing whatever was in it. Dragging one slot onto another swaps them, which changes the key. UNEQUIP on the card clears its slot.
7. Esc or A closes the view. The next fight uses the loadout as arranged; the Abilities view cannot be opened during an adventure.

## Architecture

```
AbilityManager (autoload)                       singletons/ability_manager/ability_manager.gd
  ├─ _ability_catalog = preload(resources/abilities/ability_list.tres)
  ├─ _abilities_by_id: Dictionary               built in _ready()
  └─ _live_save_data → SaveGameData.unlocked_ability_ids / equipped_ability_ids

MainView (main_game.tscn)
├── MainViewStateMachine/AbilitiesViewState     scenes/abilities/abilities_view_state.gd
├── GreyBackground                              shows/hides the panel, calls animate_open()/animate_close()
└── AbilitiesView (Control)                     scenes/abilities/abilities_view.gd
    ├── UnifiedPanel/MainVBox
    │   ├── Header: Title, Subtitle
    │   ├── HeaderSep
    │   └── Body
    │       ├── LoadoutSidebar/LoadoutVBox
    │       │   ├── LoadoutLabel ("LOADOUT")
    │       │   ├── SlotsRow (HBox): EquipSlot1..EquipSlot4 (AbilityEquipSlot)
    │       │   └── SlotCounter ("n / 4")
    │       ├── BodyDivider
    │       └── MainContent
    │           ├── FilterBarMargin/FilterBar: FilterToggles (FilterAll, FilterOffensive,
    │           │                              FilterBuff, FilterEquipped), SortDropdown
    │           └── ScrollContainer/ScrollMargin/CardList (VBox): AbilityCard × N
    └── AnimationPlayer ("open", "close")

AbilityCard (PanelContainer, PanelAbilityCard)  scenes/abilities/ability_card/ability_card.gd
├── CardVBox
│   ├── MainRow: AbilityIcon, InfoColumn
│   │            ├── NameRow: AbilityName, MadraBadge, SourceBadge
│   │            ├── DamageStatsDisplay (AbilityStatsDisplay, DAMAGE)
│   │            └── TimingStatsDisplay (AbilityStatsDisplay, TIMING_COSTS)
│   ├── ButtonRow (empty)
│   └── ExpandedDetails (hidden): DetailSep, TagsRow, ContentRow/TextColumn/DescriptionLabel
└── EquipButton                                 direct child of the card root, always visible

AbilityEquipSlot (extends DropTargetSlot)       scenes/abilities/equip_slot/equip_slot.gd
├── CenterContainer: SlotIcon, EmptyLabel ("--")
└── KeyHintPanel (panel_keyhint.tres): KeyHintLabel

AbilityStatsDisplay (HFlowContainer)            scenes/abilities/ability_stats_display/ability_stats_display.gd
├── StatTooltip                                 scenes/abilities/stat_tooltip/stat_tooltip.gd (built in code)
└── StatLabel × N (stat_label.tscn) and "·" separator Labels
```

`AbilityStatsDisplay` is also used by the combat ability tooltip (`CombatAbilityTooltip`, modes `TIMING_COSTS` and `DAMAGE_TOTAL`).

## Data Model

### AbilityData (`scripts/resource_definitions/abilities/ability_data.gd`)

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `ability_id` | `String` | `""` | Unique key used by the catalog, path unlocks and saves |
| `ability_name` | `String` | `""` | Display name |
| `description` | `String` (multiline) | `""` | Card details text |
| `icon` | `Texture2D` | null | Card, slot, combat button, tooltip |
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
| `can_afford(vitals)` / `consume_costs(vitals)` | cost check / deduction against a `VitalsManager` | Combat gate and payment; `AbilityButton` affordability |
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
| `has_unequipped_unlocks()` | Any unlocked id not in a slot; drives the system-menu badge |

Signals: `ability_unlocked(ability: AbilityData)`, `equipped_abilities_changed()`.

On `_ready` and on `PersistenceManager.save_data_reset`, the manager re-reads `PersistenceManager.save_game_data` and pads `equipped_ability_ids` to 4 entries. There is no public lookup by id; the catalog is only reachable through the unlocked/equipped getters.

### Unlock flow

```
PathTreeView purchase → PathManager.purchase_node(node_id)
  ├─ deduct points, record purchase, _recalculate_effects()
  │     └─ _apply_effect(UNLOCK_ABILITY) → PathEffectsSummary.unlocked_abilities (read-only aggregate)
  └─ for each node effect with effect_type == UNLOCK_ABILITY:
        AbilityManager.unlock_ability(effect.string_value)   # string_value is an ability_id
            └─ ability_unlocked → SystemMenuButton._refresh_badge()
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
| Card EQUIP | `equip_ability(id)` | First empty slot |
| Card UNEQUIP | `unequip_ability(id)` | Slot cleared (no compaction) |
| Drag card → slot | `equip_ability_at_slot(id, slot)` | Placed in that slot; its old slot (if any) cleared; the occupant is unequipped |
| Drag slot → slot | `swap_slots(from, to)` | Swapped (reorders keys) |
| Drag slot → elsewhere | — | Nothing happens |

After each action `AbilitiesView._refresh_without_rebuild()` updates card buttons, the loadout row and the counter. The full list is rebuilt when the view becomes visible and when the filter or sort changes.

### Filters and sorts (`AbilitiesView`)

| Filter | Shows unlocked abilities where |
|--------|-------------------------------|
| All | always |
| Offensive | `effects_on_target` is non-empty |
| Buff | `effects_on_target` is empty |
| Equipped | `AbilityManager.is_ability_equipped(id)` |

| Sort | Order |
|------|-------|
| Equipped First (default) | equipped before unequipped, then name A-Z |
| Name A-Z | `ability_name` ascending |
| Madra Cost | `madra_cost` ascending |
| Cooldown | `base_cooldown` ascending |

The active filter button is tinted `ThemeConstants.ACCENT_GOLD`.

### Loadout to combat

At fight start `AdventureCombat` sets the player's abilities to `AbilityManager.get_equipped_abilities()` (slot order, gaps skipped). Each `AbilityButton` asks `AbilityManager.get_ability_at_slot()` for its slot, so Q/W/E/R follow the slot even when an earlier slot is empty. Loadout changes take effect at the next fight.

### AbilityStatsDisplay

| Mode | Pills | Used by |
|------|-------|---------|
| `DAMAGE` | DMG total (pulsing gold border), Base, one `+contribution` pill per non-zero scaling | Ability card |
| `DAMAGE_TOTAL` | DMG total only | Combat ability tooltip |
| `TIMING_COSTS` | CD, Cast (or "Cast: Instant"), `·`, non-zero Madra/Stamina/Health costs | Ability card, combat ability tooltip |

- Damage pills read only `effects_on_target[0]` and only when it has a base value or scaling; values are raw (`calculate_value`, before defense and modifiers) using `CharacterManager.get_total_attributes_data()`.
- Hovering a pill shows `StatTooltip` with "Total Damage" (formula breakdown), "<ATTR> Scaling" (your value, %, contribution), "Base Damage", "Cooldown", "Cast Time" or "<Resource> Cost".
- Attribute colours: STR `#E06060`, BODY `#D4A84A`, AGI `#7DCE82`, SPI `#6BA4D4`, FND `#B07DD4`, CTL `#60C4B0`, RES `#C4884A`, WIL `#D470A0`.

## Integration Points

| System | Direction | Connection |
|--------|-----------|------------|
| `PersistenceManager` / `SaveGameData` | in / out | `unlocked_ability_ids`, `equipped_ability_ids`; `save_data_reset` re-binds |
| `PathManager` | in | `purchase_node()` calls `unlock_ability(string_value)` for `UNLOCK_ABILITY` effects |
| Combat (`AdventureCombat`, `AbilitiesPanel`) | out | `get_equipped_abilities()` for the player combatant; `get_ability_at_slot()` for key hints and key routing |
| `SystemMenuButton` (ABILITIES) | out | Listens to `ability_unlocked` and `equipped_abilities_changed`; badge = `has_unequipped_unlocks()` |
| `MainView` state machine | in | `ZoneViewState` pushes `AbilitiesViewState` on `open_abilities` (A); `AbilitiesViewState` closes on `ui_cancel` or `open_abilities` via `GreyBackground.hide_with_panel()` |
| `CharacterManager` | in | Attribute totals for stat pills and tooltips |

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
| `scenes/abilities/ability_card/ability_card.gd` / `.tscn` | Ability card |
| `scenes/abilities/equip_slot/equip_slot.gd` / `.tscn` | Loadout slot (drag source and drop target) |
| `scenes/common/drop_target_slot.gd` | Shared drop-target base (hover tint, drop routing) |
| `scenes/abilities/ability_stats_display/ability_stats_display.gd` | Stat pills |
| `scenes/abilities/stat_label/stat_label.gd` / `.tscn` | Single stat pill |
| `scenes/abilities/stat_tooltip/stat_tooltip.gd` | Pill tooltip |
| `scenes/zones/zone_resource_panel/system_menu/system_menu_button.gd` | ABILITIES menu button and badge |
| `tests/unit/test_ability_manager.gd` | AbilityManager unit tests |

## Work Remaining

### Bugs

- `[MEDIUM]` Stat pills always use the player's attributes, including in the combat tooltip for enemy abilities (see [COMBAT.md](../combat/COMBAT.md#bugs)).
- `[LOW]` Stale "resource path" wording for `UNLOCK_ABILITY`: the enum comment and `string_value` comment in `path_node_effect_data.gd` and `PathEffectsSummary.unlocked_abilities` say resource path; the value is an `ability_id`. The `power_font` node's `benefit_summary` still reads "Madra Strike unlocked".

### Missing Functionality

- `[HIGH]` Path perks that modify abilities do nothing. `efficient_palm` ("-20% Palm Cost"), `lingering_silence` ("+2s Silence Duration"; Empty Palm has no silence), `focused_strike` ("+40% Strike Damage") and `strike_efficiency` ("-15% Stamina Cost"; Power Font costs no Stamina) have empty `effects`. `PathNodeEffectData` has no ability-modifier effect type and abilities have no modifier hook.
- `[MEDIUM]` No slot progression. `MAX_SLOTS` is a constant 4 and all slots are open on a new save; FOUNDATION_PLAYTHROUGH plans slots 3–4 as path-node rewards.
- `[MEDIUM]` `AbilitySource.PATH` has no lifecycle. Nothing relocks or unequips path abilities on `PathManager.reset_path()`, and `AbilityManager` has no relock API.
- `[MEDIUM]` `MadraType` has only `NONE` and `PURE`. Blackflame and Earth path themes exist with no enum values, trees or abilities.
- `[LOW]` No validation: `AbilityData.validate()` is never called, and unknown ids in the save are silently skipped.
- `[LOW]` No public lookup by id; `AbilitiesView._update_loadout_sidebar()` scans the unlocked list for every slot.

### Content

- `[HIGH]` Four player abilities. FOUNDATION_PLAYTHROUGH plans three Pure Madra keystone abilities (Beats 2, 3b, 6); the Beat 6 burst/finisher does not exist. No defensive, sustain, heal, DoT or debuff ability exists for the player (the GDD's "Stand Your Ground" defensive buff is not built).

### UI

- `[LOW]` Dropping a card onto an occupied slot unequips the occupant instead of moving it to the dragged ability's old slot, and dragging a slot onto empty space does nothing. The card button is the only way to unequip.
- `[LOW]` Several cards can be expanded at once: `_on_card_selected()` is empty and `_expanded_card` is never assigned (the 2026-04-12 spec called for one at a time).
- `[LOW]` The EQUIP button is a direct child of the card root and always visible; `ButtonRow` is empty. Cards have no equipped marker other than the button text, slots have no hover tooltip, and clicking a slot does not scroll to its card (spec).
- `[LOW]` UI is built in code, against the project's scene-tree rule: `StatTooltip` builds its whole tree in `_init()` (no `.tscn`), `AbilityStatsDisplay._add_separator()` and `AbilityCard._create_tag_label()` create Labels, `AbilityCard` builds hover/expanded StyleBoxFlats, and `AbilityCard`/`AbilityEquipSlot` build identical drag previews.
- `[LOW]` The pulsing DMG border is a StyleBoxFlat tween; the spec's `damage_total_glow` shader was never added, and pills do not live-update on attribute changes (the view rebuilds on open instead).

### Tech Debt

- `[LOW]` Unused: `StatLabel.set_value()`, `AbilityCard.collapse()`, `AbilitiesView.abilities_closed` (no listeners), `AbilitiesView._expanded_card`.
- `[LOW]` `AbilityCard._set_children_mouse_pass()` says PASS but sets `MOUSE_FILTER_IGNORE`.
- `[LOW]` Public functions without `##` doc comments: `AbilityData.validate()`, `AbilityData.get_total_cost_display()`.
- `[LOW]` `test_ability_manager.gd` does not cover `swap_slots`, `equip_ability_at_slot` (move/overwrite), `get_ability_at_slot` bounds or save reset, and it replaces `AbilityManager._live_save_data` without restoring it. No tests cover `AbilityData` predicates, `can_afford`/`consume_costs`, or the view's filter and sort.
