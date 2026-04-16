# Character View — Design Spec

## Overview

A read-only Character view (press C) displaying the player's 8 cultivation attributes with icons, total values, and hover tooltips explaining each stat's mechanical role. Follows the same visual patterns as AbilitiesView and PathTreeView.

## Scope

**In scope:** 8 attribute rows with totals, icons (placeholder), hover tooltips with stat explanations and formulas.

**Out of scope:** Attribute allocation, source breakdowns (base/equipment/path), equipment summary, training activities, cultivation stage display. These are future additions.

## Layout

```
CharacterView (Control, z_index=3)
  UnifiedPanel (PanelContainer)                — same brown-border style as Abilities/Path views
    MainVBox (VBoxContainer)
      Header (PanelContainer)                  — dark semi-transparent background
        HeaderMargin (MarginContainer)         — 24px side margins
          HeaderVBox (VBoxContainer)
            Title (Label)                      — "CHARACTER", LabelTitle
            Subtitle (Label)                   — "Your cultivation attributes", LabelSubheading
      HeaderSep (HSeparator)
      Body (HBoxContainer)                     — main content area
        PhysicalGroup (VBoxContainer)          — left column
          PhysicalLabel (Label)                — "PHYSICAL", LabelHeading
          PhysicalSep (HSeparator)             — thin separator under heading
          StrengthRow (AttributeRow)           — see AttributeRow scene below
          BodyRow (AttributeRow)
          AgilityRow (AttributeRow)
          ResilienceRow (AttributeRow)
        BodyDivider (VSeparator)               — vertical divider between columns
        SpiritualGroup (VBoxContainer)         — right column
          SpiritualLabel (Label)               — "SPIRITUAL", LabelHeading
          SpiritualSep (HSeparator)
          SpiritRow (AttributeRow)
          FoundationRow (AttributeRow)
          ControlRow (AttributeRow)
          WillpowerRow (AttributeRow)
      Footer (MarginContainer)
        FooterLabel (Label)                    — "Press C or ESC to close", LabelMuted (small)
  SharedTooltip (AttributeTooltip)             — single shared tooltip, repositioned on hover
  AnimationPlayer                              — open/close animations (same as Abilities/Path)
```

## AttributeRow (Reusable Scene)

`scenes/character/attribute_row/attribute_row.tscn`

```
AttributeRow (PanelContainer)                  — subtle background stylebox, hover highlight
  RowHBox (HBoxContainer)                      — 14px separation
    Icon (TextureRect)                         — 36x36, placeholder res://icon.svg (Godot logo), stretch_mode keep_aspect_centered
    NameLabel (Label)                          — attribute name, LabelBody, size_flags_horizontal = EXPAND_FILL
    ValueLabel (Label)                         — total value, LabelValueLarge
```

**Script** (`attribute_row.gd`):
- `signal hovered(row: Control)` / `signal unhovered()`
- `@export var attribute_name: String` — display name set per-instance in scene tree
- `@export var attribute_type: CharacterAttributesData.AttributeType` — which attribute this row displays
- `func set_value(value: float) -> void` — updates ValueLabel text to `"%.0f" % value`
- Mouse enter: emit `hovered`, brighten row modulate
- Mouse exit: emit `unhovered`, reset modulate

Each row is a scene instance in the CharacterView scene tree (not created in code). The 8 rows are placed directly as children of PhysicalGroup/SpiritualGroup with their `attribute_name` and `attribute_type` exports configured per-instance in the editor.

## AttributeTooltip (Reusable Scene)

`scenes/character/attribute_tooltip/attribute_tooltip.tscn`

```
AttributeTooltip (PanelContainer)              — PanelTooltip theme variant
  TooltipMargin (MarginContainer)              — 12px padding
    TooltipVBox (VBoxContainer)
      TitleLabel (Label)                       — attribute name, LabelAbilityTitle
      TooltipSep (HSeparator)                  — HSeparatorTooltip variant
      BodyLabel (Label)                        — description text, LabelAbilityBody, autowrap
      EffectsVBox (VBoxContainer)              — formula lines
```

**Script** (`attribute_tooltip.gd`):
- `func show_for_row(row: Control, data: Dictionary) -> void` — populate labels, position above row (global_position.y - size.y - 8), make visible
- `func hide_tooltip() -> void` — set visible = false

**Tooltip content per attribute** (hardcoded dictionary in CharacterView):

| Attribute | Description | Formulas |
|-----------|-------------|----------|
| STRENGTH | Raw physical power. Scales melee damage and physical ability effects. | Basic Strike: STR x 0.2 |
| BODY | Physical constitution. Determines your health and stamina pools. | Max Health = 100 + BODY x 10, Max Stamina = 50 + BODY x 5 |
| AGILITY | Speed and precision. Scales technique-based damage. | Empty Palm: AGI x 0.3 |
| SPIRIT | Spiritual awareness and power. Scales Madra-based abilities and provides spiritual defense. | Power Font: SPI x 1.5, Spirit damage defense |
| FOUNDATION | Depth of your Madra channels. Determines your Madra capacity. | Max Madra = 50 + FND x 10 |
| CONTROL | Mastery over your techniques. Will reduce ability cooldowns. | Not yet active |
| RESILIENCE | Physical toughness. Reduces incoming physical damage. | Reduction = DMG x (100 / (100 + RES)) |
| WILLPOWER | Mental fortitude. Reduces incoming mixed damage. | Averaged with Resilience for mixed defense |

## CharacterViewState

`scenes/character/character_view_state.gd`

Identical pattern to `AbilitiesViewState`:

```
class_name CharacterViewState
extends MainViewState

func enter() -> void:
    scene_root.grey_background.show_with_panel(scene_root.character_view)

func handle_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_character"):
        scene_root.grey_background.hide_with_panel(scene_root.character_view)
        scene_root.grey_background.panel_hidden.connect(_on_close_finished, CONNECT_ONE_SHOT)

func _on_close_finished() -> void:
    scene_root.pop_state()
```

## Navigation Wiring

1. **Input action**: Add `open_character` mapped to C key in `project.godot`
2. **MainView**: Add `@onready var character_view` and `@onready var character_view_state` references, wire `scene_root` in `_ready()`
3. **ZoneViewState**: Handle `open_character` input to push `character_view_state`
4. **SystemMenuButton**: Add `CHARACTER` to `MenuType` enum if not already present (toolbar button already exists conceptually)
5. **MainViewStateMachine**: Add `CharacterViewState` as child node

## Data Flow

1. On `enter()`, `CharacterView` calls `CharacterManager.get_total_attributes_data()`
2. Iterates all 8 `AttributeRow` nodes, calls `set_value()` with the attribute total
3. Connects to `CharacterManager.base_attribute_changed` signal for live updates
4. On `exit()`, disconnects the signal

## Theme Variants Used

| Node | Variant |
|------|---------|
| Title | `LabelTitle` |
| Subtitle | `LabelSubheading` |
| Group headings (PHYSICAL/SPIRITUAL) | `LabelHeading` |
| Attribute names | `LabelBody` |
| Attribute values | `LabelValueLarge` |
| Footer hint | `LabelSmall` with muted color override |
| Tooltip title | `LabelAbilityTitle` |
| Tooltip body | `LabelAbilityBody` |
| Tooltip separator | `HSeparatorTooltip` |
| Tooltip panel | `PanelTooltip` |

## New Files

| File | Type |
|------|------|
| `scenes/character/character_view.tscn` | Main view scene |
| `scenes/character/character_view.gd` | View script (data wiring, tooltip management) |
| `scenes/character/character_view_state.gd` | State machine state |
| `scenes/character/attribute_row/attribute_row.tscn` | Reusable attribute row scene |
| `scenes/character/attribute_row/attribute_row.gd` | Row script (hover signals, value setter) |
| `scenes/character/attribute_tooltip/attribute_tooltip.tscn` | Shared tooltip scene |
| `scenes/character/attribute_tooltip/attribute_tooltip.gd` | Tooltip positioning and content |

## Modified Files

| File | Change |
|------|--------|
| `project.godot` | Add `open_character` input action (C key) |
| `scenes/main/main_game/main_game.tscn` | Add CharacterView instance + CharacterViewState to state machine |
| `scenes/ui/main_view/main_view.gd` | Add character_view / character_view_state @onready refs, wire in _ready() |
| `scenes/zones/zone_view_state.gd` | Handle `open_character` input to push state |
