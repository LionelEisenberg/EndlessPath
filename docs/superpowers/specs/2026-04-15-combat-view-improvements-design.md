# Combat View Improvements — Design Spec

## Summary

Seven improvements to the combat view that bring it to visual and functional parity with the rest of the game. The changes fall into three groups: **ability button enhancements** (costs, affordability, keybinding hints), **tooltip systems** (ability + buff), and **atmosphere**.

## Scope

| # | Feature | Priority | COMBAT.md ref |
|---|---------|----------|---------------|
| 1 | Combat ability tooltip | HIGH | UI — "No ability tooltips" |
| 2 | Q/W/E/R keybindings (combat + ability equip slots) | HIGH | — |
| 3 | Atmosphere in combat view | MEDIUM | UI — "Combat background should be modular" (partial) |
| 4 | Resource costs on ability buttons | HIGH | — |
| 5 | "Can't afford" visual state | HIGH | UI — "Ability icons don't disable when can't afford" |
| 6 | Keybinding hint labels on buttons | HIGH | — |
| 7 | Buff tooltips | MEDIUM | UI — "No buff tooltips" |

## 1. Enhanced Ability Buttons

### 1a. Keybinding Hint Labels

Each `AbilityButton` displays a small letter badge in its **top-left corner** showing the slot's keybinding (Q, W, E, R).

- **Visual:** Dark background pill (`rgba(0,0,0,0.85)`) with a 1px gold (`#D4A84A`) border, rounded top-left to match the button corner. Gold text, ~11px, bold.
- **Data flow:** `AbilityButton` receives a `slot_index: int` during `setup()`. A constant array `["Q", "W", "E", "R"]` maps index to label text. The label is a child `Label` node positioned absolutely in the top-left.
- **Always visible** — persists during cooldown and can't-afford states.

### 1b. Resource Cost Labels

Each `AbilityButton` displays a compact cost strip along its **bottom edge**.

- **Visual:** Dark background bar (`rgba(0,0,0,0.8)`) spanning the button width, rounded bottom corners. Cost values are color-coded: blue (`#6BA4D4`) for madra, gold (`#D4A84A`) for stamina, red (`#E06060`) for health. Only non-zero costs are shown.
- **Data flow:** `AbilityButton.setup()` already receives a `CombatAbilityInstance` which has `ability_data`. Read `madra_cost`, `stamina_cost`, `health_cost` from `ability_data` and populate labels.
- **Layout:** An `HBoxContainer` centered at the bottom. Each cost is a `Label` with the appropriate color override. Costs are separated by a small gap (6px).

### 1c. "Can't Afford" Visual State

When the player lacks resources to cast an ability, the button visually communicates this.

- **Visual:** Icon dims to ~35% opacity. The cost label text for the unaffordable resource(s) turns red (`#E06060`). Button border shifts to a muted red-brown (`#553333`).
- **Data flow:** `AbilityButton` needs a reference to the player's `VitalsManager` to check affordability. This is passed during setup. In `_process()`, call `ability_data.can_afford(vitals_manager)` each frame. If false, apply the can't-afford visual state; if true, restore normal state.
- **Interaction with cooldown:** Cooldown state takes visual priority. If an ability is on cooldown, the cooldown overlay is shown regardless of affordability. The can't-afford state only applies to ready (off-cooldown) abilities.
- **Interaction with casting:** While any ability is casting, all buttons are disabled (existing behavior). Can't-afford visuals are suppressed during casting since buttons are already inactive.

## 2. Combat Ability Tooltip (CombatAbilityTooltip)

A new scene `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn` that appears when the player hovers over an `AbilityButton`.

### Content

- **Header row:** Ability icon (40x40) + ability name (`LabelAbilityTitle` variant, scaled to ~18px)
- **Stats row:** Stat pills using the existing `AbilityStatsDisplay` component, configured to show:
  - Total DMG pill (gold, with pulsing border — same as ability card)
  - CD pill
  - Cast Time pill (only if `cast_time > 0`)
  - Dot separator
  - Cost pills (Madra / Stamina / Health, only non-zero)

### Visual Style

Matches the ability card styling for visual cohesion:
- Background: `#3D2E22` (same as `card_normal.tres`)
- Border: 2px `#8C6647` (same as card hover border)
- Corner radius: 6px
- Padding: 10px 12px
- Width: ~280px (auto-height)
- Shadow: `0 4px 16px rgba(0,0,0,0.6)`

### Behavior

- **Trigger:** Mouse enters `AbilityButton` area.
- **Position:** Appears above the hovered button, horizontally centered on it. If the tooltip would overflow the viewport top, flip to below the button.
- **Dismiss:** Mouse leaves the button OR the player presses any ability keybinding (Q/W/E/R).
- **No pause:** Combat continues running. Keybindings remain active while tooltip is visible.
- **Show delay:** None — appears immediately on hover for quick-glance usage.

### Architecture

- `CombatAbilityTooltip` extends `PanelContainer`.
- Has a `setup(ability_data: AbilityData, owner_attributes: CharacterAttributesData)` method.
- Uses `AbilityStatsDisplay` (existing component) internally for the stat pills, configured in `TIMING_COSTS` + `DAMAGE` combined mode — or two instances, one per row.
- `AbilitiesPanel` owns a single `CombatAbilityTooltip` instance, repositions it per-button on hover. The tooltip is a child of the combat UI layer so it renders above everything.
- `AbilityButton` emits `hovered(instance)` and `unhovered()` signals. `AbilitiesPanel` connects these to show/hide the tooltip.

### Reuse of AbilityStatsDisplay

The existing `AbilityStatsDisplay` component in `scenes/abilities/ability_stats_display/` already handles:
- Calculating total damage with attribute scaling
- Rendering color-coded stat pills (DMG, CD, Cast, costs)
- Gold pulsing border on the total DMG pill
- Hoverable pills with stat tooltips

The combat tooltip reuses this directly. If `AbilityStatsDisplay` currently requires data not available in combat context (e.g., it pulls from `CharacterManager` directly), we'll pass the attributes explicitly via a setup parameter.

## 3. Q/W/E/R Keybindings

### Input Actions

Add four input actions to `project.godot`:

| Action | Key | Purpose |
|--------|-----|---------|
| `ability_slot_1` | Q | Activate ability in slot 0 |
| `ability_slot_2` | W | Activate ability in slot 1 |
| `ability_slot_3` | E | Activate ability in slot 2 |
| `ability_slot_4` | R | Activate ability in slot 3 |

### Combat Keybindings

`AbilitiesPanel` handles `_unhandled_input()`:
- On `ability_slot_N` pressed, look up the `AbilityButton` at index N.
- If the button exists and is not disabled, emit `ability_selected(instance)` — same signal as a click.
- This means all existing click-based logic (cooldown checks, affordability, casting lock) applies identically.

### Ability View Equip Slot Keybindings

The `AbilitiesView` (ability management screen) also displays keybinding hints on its 4 `AbilityEquipSlot` components. Each slot shows a small Q/W/E/R label matching the combat button style, reinforcing the slot-to-key mapping.

These are **display-only** in the ability view — the keys don't trigger equip/unequip actions there. Their purpose is to teach the player which slot maps to which key.

## 4. Atmosphere in Combat View

### Approach

Instance the existing `Atmosphere` scene (`scenes/atmosphere/atmosphere.tscn`) inside the combat view.

### Placement

The combat happens inside a `SubViewport` within the `CombatView` control. The `Atmosphere` instance is added as a child of `AdventureCombat`, layered behind the combatant sprites but above any background.

### Settings

Use the same atmospheric settings as the adventure tilemap for now (consistent feel when transitioning from map to combat):
- Vignette: radius 0.5, softness 0.35, dark blue color
- Mist: 3 drift layers with existing radius/duration settings
- Particles: 25 cyan motes, 8 warm motes

These are set via the `Atmosphere` node's exported properties in the scene, not hardcoded. Future work (out of scope) can make these zone-dependent.

## 5. Buff Tooltips (CombatBuffTooltip)

A new scene `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn` that appears when the player hovers over a `BuffIcon`.

### Content

- **Header row:** Buff icon (32x32) + buff name (16px, `LabelAbilityBody`-scaled)
- **Description:** Effect text in muted tan (`#A89070`, 13px). Generated from buff data:
  - Attribute modifier: "Strength ×1.5, Spirit ×1.5"
  - DoT: "{damage} damage per second"
  - Damage modifier: "Outgoing damage ×{multiplier}" or "Incoming damage ×{multiplier}"
- **Meta row:** Remaining duration ("5.2s remaining" in gold) + stack count ("×2 stacks" in beige, only if stacks > 1)

### Visual Style

Same card styling as the ability tooltip for consistency:
- Background: `#3D2E22`
- Border: 2px `#8C6647`
- Corner radius: 6px
- Padding: 10px 12px
- Width: ~220px
- Shadow: `0 4px 16px rgba(0,0,0,0.6)`

### Behavior

- **Trigger:** Mouse enters `BuffIcon` area.
- **Position:** Appears to the right of the buff icon (buffs sit to the right of the info panel). If it would overflow viewport, flip to left.
- **Dismiss:** Mouse leaves the buff icon.
- **Duration updates:** The tooltip updates its remaining duration each frame while visible (reads from `ActiveBuff.remaining_duration`).

### Architecture

- `CombatBuffTooltip` extends `PanelContainer`.
- `setup(active_buff: ActiveBuff)` populates fields from buff data.
- `BuffIcon` emits `hovered(active_buff)` and `unhovered()` signals.
- `CombatantInfoPanel` owns a single tooltip instance, repositions per icon.

## Files Changed

### New Files
| File | Purpose |
|------|---------|
| `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.tscn` | Ability tooltip scene |
| `scenes/ui/combat/combat_ability_tooltip/combat_ability_tooltip.gd` | Ability tooltip script |
| `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.tscn` | Buff tooltip scene |
| `scenes/ui/combat/combat_buff_tooltip/combat_buff_tooltip.gd` | Buff tooltip script |

### Modified Files
| File | Changes |
|------|---------|
| `project.godot` | Add `ability_slot_1..4` input actions (Q/W/E/R) |
| `scenes/ui/combat/ability_button/ability_button.tscn` | Add keybinding hint label, cost strip, can't-afford visual nodes |
| `scenes/ui/combat/ability_button/ability_button.gd` | Add `slot_index` param to setup, cost display logic, affordability check in `_process()`, hover signals |
| `scenes/ui/combat/abilities_panel.gd` | Handle `_unhandled_input()` for keybindings, manage tooltip instance, connect hover signals |
| `scenes/ui/combat/abilities_panel.tscn` | Add `CombatAbilityTooltip` child node |
| `scenes/combat/adventure_combat/adventure_combat.tscn` | Add `Atmosphere` instance |
| `scenes/combat/adventure_combat/adventure_combat.gd` | Pass `vitals_manager` reference to abilities panel for affordability checks |
| `scenes/combat/combatant/combat_buff_manager/buff_icon.gd` | Add hover signals |
| `scenes/combat/combatant/combat_buff_manager/buff_icon.tscn` | Enable mouse input for hover detection |
| `scenes/ui/combat/combatant_info_panel/combatant_info_panel.tscn` | Add `CombatBuffTooltip` child node |
| `scenes/ui/combat/combatant_info_panel/combatant_info_panel.gd` | Connect buff icon hover signals to tooltip |
| `scenes/abilities/equip_slot/equip_slot.tscn` | Add keybinding hint label |
| `scenes/abilities/equip_slot/equip_slot.gd` | Display Q/W/E/R based on slot index |

## Out of Scope

- Zone-specific combat atmosphere (different backdrops per zone)
- Per-attribute damage breakdown in combat tooltip (reserved for ability card)
- Ability description text in combat tooltip
- Keybinding rebinding UI
- Tooltip animations (fade in/out) — add later if desired
