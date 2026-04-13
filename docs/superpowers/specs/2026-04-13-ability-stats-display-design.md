# AbilityStatsDisplay Component

Reusable sub-scene for displaying ability stats (damage, scaling, cooldown, cast time, costs) as individual hoverable labels with interactive tooltips, shader effects, and animated number transitions.

## 1. StatLabel Sub-Scene

`scenes/abilities/stat_label/stat_label.gd` + `.tscn`

A single hoverable stat display unit. PanelContainer with subtle tinted StyleBoxFlat background, a Label child for text (21px, m5x7 at 3x native).

**Properties:**
- `stat_name: String` — display name (e.g., "AGI", "CD", "Madra")
- `stat_value: float` — numeric value
- `stat_color: Color` — tint for the name portion
- `format_string: String` — how to display (e.g., "%s +%.1f", "%s: %.1fs")
- `tooltip_data: Dictionary` — data passed to StatTooltip on hover

**Visual behaviors:**
- Hover: modulate brightens to 1.2x, reverts on exit
- `set_value(new_val)`: tweens the displayed number over 0.3s (count up/down)
- Optional `ShaderMaterial` property — applied to the Label for effects (used only on damage total)

**Mouse filter:** MOUSE_FILTER_STOP (needs to capture hover for tooltips)

## 2. AbilityStatsDisplay Scene

`scenes/abilities/ability_stats_display/ability_stats_display.gd` + `.tscn`

Container that creates StatLabels from AbilityData.

**Scene tree:**
```
AbilityStatsDisplay (HFlowContainer)
└── StatTooltip (PanelContainer, floating, hidden, z_index=10)
    └── TooltipMargin (MarginContainer, 12px)
        └── TooltipContent (VBoxContainer)
            ├── TooltipTitle (Label, LabelPathBody, 21px)
            ├── TooltipSep (HSeparator)
            └── TooltipBody (RichTextLabel, bbcode, 21px)
```

StatLabels and separators are created dynamically in `setup()`.

**Public API:**
```gdscript
func setup(ability_data: AbilityData) -> void
```

**setup() logic:**
1. Clear existing children (except StatTooltip)
2. Read `ability_data.effects[0]` for damage/scaling
3. If offensive (has base_value or scaling):
   - Create DamageTotalLabel with golden glow shader — shows computed total
   - Create BaseDamageLabel — "Base: X"
   - For each non-zero scaling attribute: create colored StatLabel — "AGI +3.0"
   - Add separator "·"
4. Create CooldownLabel — "CD: X.Xs"
5. Create CastTimeLabel — "Cast: Instant" or "Cast: X.Xs"
6. Add separator "·"
7. For each non-zero cost (madra, stamina, health): create cost StatLabel

**Tooltip positioning:** On StatLabel hover, position StatTooltip above the hovered label. Build tooltip content from the label's `tooltip_data`.

**Tooltip content by type:**
- **Damage total**: Title "Total Damage", body shows base + each scaling line (colored) + separator + total. Full formula breakdown.
- **Scaling stat**: Title "[Attribute] Scaling", body shows "Your [Attr]: X\nScaling: Y%\nContribution: +Z damage"
- **CD/Cast**: Title "Cooldown"/"Cast Time", one-line explanation
- **Cost**: Title "[Resource] Cost", one-line "Costs X [resource] per use"

**Live updates:** Connect to `CharacterManager.base_attribute_changed` signal. On attribute change, re-tween affected StatLabels to new values.

## 3. Damage Total Glow Shader

`assets/shaders/damage_total_glow.gdshader`

Simple golden shimmer applied as ShaderMaterial on the DamageTotalLabel's Label node.

```glsl
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.83, 0.66, 0.29, 0.6);
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float glow = pulse * glow_intensity;
    COLOR = tex + glow_color * glow * tex.a;
}
```

## 4. Integration with AbilityCard

**Replace in ability_card.tscn:**
- Remove `CostLabel` (RichTextLabel) from CollapsedRow
- Remove `ScalingLabel` (RichTextLabel) from ExpandedDetails/ContentRow/TextColumn
- Add `AbilityStatsDisplay` instance as second child of CardVBox (between CollapsedRow and ExpandedDetails)

**Remove from ability_card.gd:**
- `_cost_label`, `_scaling_label` onready vars
- `_update_cost_display()`, `_update_scaling_display()`, `_append_scaling()`, `_has_damage_or_scaling()`

**Add to ability_card.gd:**
- `@onready var _stats_display: AbilityStatsDisplay = %AbilityStatsDisplay`
- In `_update_display()`: call `_stats_display.setup(_ability_data)`

## 5. Tooltip Styling

StatTooltip uses a StyleBoxFlat matching PathNodeTooltip:
- bg_color: BG_MEDIUM (#3D2E22)
- border: 2px BORDER_PRIMARY (#C4884A)
- corner_radius: 8px
- shadow: size 8, color black 50%
- content_margin: 12px all sides

Tooltip title uses LabelPathBody. Body uses RichTextLabel with bbcode for colored stat lines. Separator uses the existing path separator StyleBoxLine.

Tooltip fades in (tween modulate alpha 0→1, 0.15s) on hover, fades out on exit.

## Files Summary

### New
| File | Purpose |
|------|---------|
| `scenes/abilities/stat_label/stat_label.gd` | StatLabel component script |
| `scenes/abilities/stat_label/stat_label.tscn` | StatLabel scene |
| `scenes/abilities/ability_stats_display/ability_stats_display.gd` | Stats display container script |
| `scenes/abilities/ability_stats_display/ability_stats_display.tscn` | Stats display scene with tooltip |
| `assets/shaders/damage_total_glow.gdshader` | Golden shimmer shader |

### Modified
| File | Change |
|------|--------|
| `scenes/abilities/ability_card/ability_card.gd` | Remove cost/scaling display, add stats_display setup |
| `scenes/abilities/ability_card/ability_card.tscn` | Remove CostLabel/ScalingLabel, add AbilityStatsDisplay instance |
