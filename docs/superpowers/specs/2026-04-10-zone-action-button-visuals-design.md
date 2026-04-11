# Zone Action Button Visual Refresh

## Overview

Update the `ZoneActionButton` to provide clear visual feedback for the selected state and a progress sweep for timed actions (foraging). Currently the selected state reuses the hover stylebox (barely distinguishable from normal), and timed actions have zero progress indication.

## Design Decisions

- **Selected state**: Category-colored background tint (green for forage, teal for cycling, red for adventure, gold for dialogue)
- **Progress indicator**: Background sweep — the tint itself fills left-to-right over the timer interval, so the card IS the progress bar
- **Timer reset**: Smooth loop — on completion, ease `fill_amount` back to 0.0 (~0.3s), then restart the fill
- **Non-timed actions**: Static tint (fill set to 1.0 instantly on selection)

## Category Color Mapping

Reuse the exact colors from `zone_action_type_section.gd` category dots:

| ActionType    | Color                        | Hex     |
|---------------|------------------------------|---------|
| FORAGE        | `Color(0.42, 0.67, 0.37)`   | #6bab5f |
| CYCLING       | `Color(0.37, 0.66, 0.62)`   | #5ea89e |
| ADVENTURE     | `Color(0.61, 0.25, 0.25)`   | #9c4040 |
| NPC_DIALOGUE  | `Color(0.83, 0.66, 0.29)`   | #d4a84a |

These map to both the fill color (at ~45% opacity for background tint) and the border accent color.

## Selected State Stylebox

When `is_current_action` is true, the `ActionCard` stylebox changes to `action_card_selected.tres`:

- **bg_color**: Same dark base as normal (`Color(0.18, 0.19, 0.24, 0.8)`) — the background tint comes entirely from the `ProgressFill` ColorRect, not the stylebox
- **border_color**: Category color at ~40% opacity (set programmatically per action type)
- **border_width_left**: 3px (thicker accent, color set programmatically to solid category color)
- **Other borders**: 1px (unchanged from normal)

The stylebox handles border treatment only. The `ProgressFill` ColorRect provides the category-colored background tint (either sweeping for timed actions or instant-filled for non-timed).

## Progress Sweep

### Scene Changes

Add a `ColorRect` node (`ProgressFill`) as a child of `ActionCard` (before `HBoxContainer`):

- Fills the entire PanelContainer (standard PanelContainer child behavior)
- Has a `ShaderMaterial` with a simple left-to-right sweep shader
- `mouse_filter = IGNORE` so it doesn't block card input
- Color set to the category color at the appropriate tint opacity

### Shader

Adapted from the existing `zone_action_button.gdshader`. Only shows color where `UV.x < fill_amount`:

```glsl
shader_type canvas_item;
uniform float fill_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    if (UV.x < fill_amount) {
        COLOR = COLOR; // keep the ColorRect's assigned color
    } else {
        COLOR.a = 0.0; // transparent beyond the fill edge
    }
}
```

### Fill Behavior

- **Forage selected**: Tween `fill_amount` from 0.0 to 1.0 over `ForageActionData.foraging_interval_in_sec`
- **On `foraging_completed`**: Smooth-tween `fill_amount` from 1.0 to 0.0 (~0.3s ease-out), then restart fill
- **Non-forage selected**: Set `fill_amount = 1.0` immediately (static tint)
- **On deselect**: Kill active tweens, set `fill_amount = 0.0`

At `fill_amount = 1.0`, the card looks identical to the static selected state — the sweep IS the selected highlight, just animated for timed actions.

## Signal Flow

No new signals needed. The button hooks into existing `ActionManager` signals:

| Signal | Source | Purpose |
|--------|--------|---------|
| `current_action_changed` | ActionManager | Detect selection/deselection, start/stop sweep |
| `foraging_completed` | ActionManager | Trigger smooth reset on loot roll, restart fill |

The button already connects to `current_action_changed`. The only new connection is `foraging_completed`.

## Files Changed

| File | Change |
|------|--------|
| `scenes/zones/zone_action_button/zone_action_button.tscn` | Add `ProgressFill` ColorRect node to `ActionCard` |
| `scenes/zones/zone_action_button/zone_action_button.gd` | Category color mapping, sweep tween logic, new signal connections, updated `_update_card_style()` |
| `assets/shaders/action_card_sweep.gdshader` (new) | Simple left-to-right fill shader |
| `assets/styleboxes/zones/action_card_selected.tres` (new) | Selected state border treatment |
