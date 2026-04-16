# Character View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only Character view (press C) showing 8 cultivation attributes in two columns with hover tooltips.

**Architecture:** Follows the exact same pattern as AbilitiesView/PathTreeView — a Control with UnifiedPanel, pushed onto the state stack via GreyBackground. AttributeRow is a reusable subscene instanced 8 times in the scene tree. A shared AttributeTooltip repositions on hover.

**Tech Stack:** Godot 4.6, GDScript, .tscn scene files for all UI

**Design spec:** `docs/superpowers/specs/2026-04-16-character-view-design.md`

---

### Task 1: Add `open_character` input action

**Files:**
- Modify: `project.godot` (input section, after `open_abilities`)

Note: `open_character` is already referenced by `SystemMenuButton.MENU_CONFIG[CHARACTER]` but is missing from project.godot. The CHARACTER toolbar button exists but silently fails because the input action isn't registered.

- [ ] **Step 1: Add input action to project.godot**

Add after the `open_abilities` block (after the closing `]}`). The C key physical keycode is `67`, unicode is `99`:

```ini
open_character={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":67,"key_label":0,"unicode":99,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 2: Verify in Godot editor**

Run: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import`

Open Project > Project Settings > Input Map and confirm `open_character` appears mapped to C.

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "feat(input): add open_character input action mapped to C key"
```

---

### Task 2: Create AttributeRow scene and script

**Files:**
- Create: `scenes/character/attribute_row/attribute_row.tscn`
- Create: `scenes/character/attribute_row/attribute_row.gd`

This is a reusable subscene instanced 8 times in CharacterView. Each instance has its `attribute_name` and `attribute_type` exports configured in the editor.

- [ ] **Step 1: Create attribute_row.gd**

```gdscript
class_name AttributeRow
extends PanelContainer

## A single attribute display row with icon, name, and value.
## Emits hover signals for tooltip management by the parent CharacterView.

signal hovered(row: AttributeRow)
signal unhovered()

@export var attribute_name: String = "ATTRIBUTE"
@export var attribute_type: CharacterAttributesData.AttributeType = CharacterAttributesData.AttributeType.STRENGTH

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_name_label.text = attribute_name

## Updates the displayed attribute value.
func set_value(value: float) -> void:
	_value_label.text = "%.0f" % value

func _on_mouse_entered() -> void:
	modulate = Color(1.15, 1.1, 1.05, 1.0)
	hovered.emit(self)

func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	unhovered.emit()
```

- [ ] **Step 2: Create attribute_row.tscn**

Scene tree structure:

```
AttributeRow (PanelContainer)
  script = attribute_row.gd
  mouse_filter = MOUSE_FILTER_STOP
  theme_override_styles/panel = new StyleBoxFlat:
    bg_color = Color(1, 1, 1, 0.02)
    corner_radius (all) = 3
    content_margin_left = 14
    content_margin_right = 14
    content_margin_top = 10
    content_margin_bottom = 10

  RowHBox (HBoxContainer)
    theme_override_constants/separation = 14

    Icon (TextureRect) [unique name %Icon]
      custom_minimum_size = Vector2(36, 36)
      texture = preload("res://icon.svg")
      expand_mode = EXPAND_KEEP_SIZE (3)
      stretch_mode = STRETCH_KEEP_ASPECT_CENTERED (5)

    NameLabel (Label) [unique name %NameLabel]
      theme_type_variation = "LabelBody"
      text = "ATTRIBUTE"
      size_flags_horizontal = SIZE_EXPAND_FILL (3)
      vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    ValueLabel (Label) [unique name %ValueLabel]
      theme_type_variation = "LabelValueLarge"
      text = "10"
      horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
      vertical_alignment = VERTICAL_ALIGNMENT_CENTER
      custom_minimum_size = Vector2(60, 0)
```

- [ ] **Step 3: Commit**

```bash
git add scenes/character/attribute_row/
git commit -m "feat(character): add AttributeRow reusable scene"
```

---

### Task 3: Create AttributeTooltip scene and script

**Files:**
- Create: `scenes/character/attribute_tooltip/attribute_tooltip.tscn`
- Create: `scenes/character/attribute_tooltip/attribute_tooltip.gd`

A shared tooltip that repositions above the hovered row. All UI structure is in the .tscn, not created in code.

- [ ] **Step 1: Create attribute_tooltip.gd**

```gdscript
class_name AttributeTooltip
extends PanelContainer

## Shared tooltip for attribute rows.
## Repositions above the hovered row and displays attribute description + formulas.

@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel
@onready var _effects_label: Label = %EffectsLabel

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Shows the tooltip above the given row with the provided data.
func show_for_row(row: Control, data: Dictionary) -> void:
	_title_label.text = data.get("title", "")
	_body_label.text = data.get("description", "")
	_effects_label.text = data.get("effects", "")
	_effects_label.visible = not data.get("effects", "").is_empty()

	visible = true
	reset_size()

	var rect: Rect2 = row.get_global_rect()
	global_position = Vector2(rect.position.x, rect.position.y - size.y - 8)

## Hides the tooltip.
func hide_tooltip() -> void:
	visible = false
```

- [ ] **Step 2: Create attribute_tooltip.tscn**

Scene tree structure:

```
AttributeTooltip (PanelContainer)
  script = attribute_tooltip.gd
  theme_type_variation = "PanelTooltip"
  top_level = true
  z_index = 100
  mouse_filter = MOUSE_FILTER_IGNORE

  TooltipMargin (MarginContainer)
    theme_override_constants/margin_left = 12
    theme_override_constants/margin_right = 12
    theme_override_constants/margin_top = 12
    theme_override_constants/margin_bottom = 12

    TooltipVBox (VBoxContainer)
      theme_override_constants/separation = 6

      TitleLabel (Label) [unique name %TitleLabel]
        theme_type_variation = "LabelAbilityTitle"
        text = "ATTRIBUTE"

      TooltipSep (HSeparator)
        theme_type_variation = "HSeparatorTooltip"

      BodyLabel (Label) [unique name %BodyLabel]
        theme_type_variation = "LabelAbilityBody"
        autowrap_mode = AUTOWRAP_WORD_SMART (3)
        custom_minimum_size = Vector2(260, 0)
        text = "Description text"

      EffectsLabel (Label) [unique name %EffectsLabel]
        theme_type_variation = "LabelAbilityMuted"
        autowrap_mode = AUTOWRAP_WORD_SMART (3)
        text = "Formula text"
```

- [ ] **Step 3: Commit**

```bash
git add scenes/character/attribute_tooltip/
git commit -m "feat(character): add AttributeTooltip scene"
```

---

### Task 4: Create CharacterView scene and script

**Files:**
- Create: `scenes/character/character_view.tscn`
- Create: `scenes/character/character_view.gd`

The main view. All 8 AttributeRow instances are placed in the scene tree with exports configured per-instance. Tooltip content is a static dictionary in the script.

- [ ] **Step 1: Create character_view.gd**

```gdscript
class_name CharacterView
extends Control

## Character View — displays cultivation attributes in two groups with hover tooltips.

@onready var _tooltip: AttributeTooltip = %SharedTooltip
@onready var _animation_player: AnimationPlayer = %AnimationPlayer

## All attribute rows, looked up by type for refreshing.
var _rows_by_type: Dictionary = {}

## Tooltip content for each attribute.
const TOOLTIP_DATA: Dictionary = {
	CharacterAttributesData.AttributeType.STRENGTH: {
		"title": "STRENGTH",
		"description": "Raw physical power. Scales melee damage and physical ability effects.",
		"effects": "Basic Strike: STR x 0.2",
	},
	CharacterAttributesData.AttributeType.BODY: {
		"title": "BODY",
		"description": "Physical constitution. Determines your health and stamina pools.",
		"effects": "Max Health = 100 + BODY x 10\nMax Stamina = 50 + BODY x 5",
	},
	CharacterAttributesData.AttributeType.AGILITY: {
		"title": "AGILITY",
		"description": "Speed and precision. Scales technique-based damage.",
		"effects": "Empty Palm: AGI x 0.3",
	},
	CharacterAttributesData.AttributeType.RESILIENCE: {
		"title": "RESILIENCE",
		"description": "Physical toughness. Reduces incoming physical damage.",
		"effects": "Reduction = DMG x (100 / (100 + RES))",
	},
	CharacterAttributesData.AttributeType.SPIRIT: {
		"title": "SPIRIT",
		"description": "Spiritual awareness and power. Scales Madra-based abilities and provides spiritual defense.",
		"effects": "Power Font: SPI x 1.5\nSpirit damage defense",
	},
	CharacterAttributesData.AttributeType.FOUNDATION: {
		"title": "FOUNDATION",
		"description": "Depth of your Madra channels. Determines your Madra capacity.",
		"effects": "Max Madra = 50 + FND x 10",
	},
	CharacterAttributesData.AttributeType.CONTROL: {
		"title": "CONTROL",
		"description": "Mastery over your techniques. Will reduce ability cooldowns.",
		"effects": "Not yet active",
	},
	CharacterAttributesData.AttributeType.WILLPOWER: {
		"title": "WILLPOWER",
		"description": "Mental fortitude. Reduces incoming mixed damage.",
		"effects": "Averaged with Resilience for mixed defense",
	},
}

func _ready() -> void:
	# Collect all AttributeRow children from both groups
	for row: AttributeRow in _find_all_rows():
		_rows_by_type[row.attribute_type] = row
		row.hovered.connect(_on_row_hovered)
		row.unhovered.connect(_on_row_unhovered)

## Refreshes all attribute values from CharacterManager.
func refresh() -> void:
	var attrs: CharacterAttributesData = CharacterManager.get_total_attributes_data()
	for attr_type: CharacterAttributesData.AttributeType in _rows_by_type:
		var row: AttributeRow = _rows_by_type[attr_type]
		row.set_value(attrs.get_attribute(attr_type))

## Plays the open animation.
func animate_open() -> void:
	refresh()
	_animation_player.play("open")

## Plays the close animation.
func animate_close() -> void:
	_tooltip.hide_tooltip()
	_animation_player.play("close")

func _find_all_rows() -> Array[AttributeRow]:
	var rows: Array[AttributeRow] = []
	var physical_group: VBoxContainer = %PhysicalGroup
	var spiritual_group: VBoxContainer = %SpiritualGroup
	for child: Node in physical_group.get_children():
		if child is AttributeRow:
			rows.append(child as AttributeRow)
	for child: Node in spiritual_group.get_children():
		if child is AttributeRow:
			rows.append(child as AttributeRow)
	return rows

func _on_row_hovered(row: AttributeRow) -> void:
	var data: Dictionary = TOOLTIP_DATA.get(row.attribute_type, {})
	if not data.is_empty():
		_tooltip.show_for_row(row, data)

func _on_row_unhovered() -> void:
	_tooltip.hide_tooltip()
```

- [ ] **Step 2: Create character_view.tscn**

Scene tree structure. The UnifiedPanel styling must match AbilitiesView/PathTreeView exactly (same brown border StyleBoxFlat):

```
CharacterView (Control)
  script = character_view.gd
  visible = false
  z_index = 3
  anchors_preset = PRESET_FULL_RECT
  mouse_filter = MOUSE_FILTER_STOP

  UnifiedPanel (PanelContainer)
    anchors_preset = PRESET_CENTER
    theme_override_styles/panel = (copy from AbilitiesView UnifiedPanel)
    custom_minimum_size = Vector2(820, 0)

    MainVBox (VBoxContainer)
      theme_override_constants/separation = 0

      Header (PanelContainer)
        theme_override_styles/panel = new StyleBoxFlat:
          bg_color = Color(0, 0, 0, 0.35)

        HeaderMargin (MarginContainer)
          theme_override_constants/margin_left = 28
          theme_override_constants/margin_right = 28
          theme_override_constants/margin_top = 20
          theme_override_constants/margin_bottom = 16

          HeaderVBox (VBoxContainer)
            theme_override_constants/separation = 6

            Title (Label)
              theme_type_variation = "LabelTitle"
              text = "CHARACTER"

            Subtitle (Label)
              theme_type_variation = "LabelSubheading"
              text = "Your cultivation attributes"

      HeaderSep (HSeparator)

      BodyMargin (MarginContainer)
        theme_override_constants/margin_left = 32
        theme_override_constants/margin_right = 32
        theme_override_constants/margin_top = 24
        theme_override_constants/margin_bottom = 28

        Body (HBoxContainer)
          theme_override_constants/separation = 32

          PhysicalGroup (VBoxContainer) [unique name %PhysicalGroup]
            size_flags_horizontal = SIZE_EXPAND_FILL (3)
            theme_override_constants/separation = 6

            PhysicalLabel (Label)
              theme_type_variation = "LabelHeading"
              text = "PHYSICAL"

            PhysicalSep (HSeparator)

            StrengthRow (AttributeRow instance)
              attribute_name = "STRENGTH"
              attribute_type = STRENGTH

            BodyRow (AttributeRow instance)
              attribute_name = "BODY"
              attribute_type = BODY

            AgilityRow (AttributeRow instance)
              attribute_name = "AGILITY"
              attribute_type = AGILITY

            ResilienceRow (AttributeRow instance)
              attribute_name = "RESILIENCE"
              attribute_type = RESILIENCE

          BodyDivider (VSeparator)

          SpiritualGroup (VBoxContainer) [unique name %SpiritualGroup]
            size_flags_horizontal = SIZE_EXPAND_FILL (3)
            theme_override_constants/separation = 6

            SpiritualLabel (Label)
              theme_type_variation = "LabelHeading"
              text = "SPIRITUAL"

            SpiritualSep (HSeparator)

            SpiritRow (AttributeRow instance)
              attribute_name = "SPIRIT"
              attribute_type = SPIRIT

            FoundationRow (AttributeRow instance)
              attribute_name = "FOUNDATION"
              attribute_type = FOUNDATION

            ControlRow (AttributeRow instance)
              attribute_name = "CONTROL"
              attribute_type = CONTROL

            WillpowerRow (AttributeRow instance)
              attribute_name = "WILLPOWER"
              attribute_type = WILLPOWER

      Footer (MarginContainer)
        theme_override_constants/margin_bottom = 16

        FooterLabel (Label)
          theme_type_variation = "LabelSmall"
          theme_override_colors/font_color = Color(0.42, 0.38, 0.31, 1)
          text = "Press C or ESC to close"
          horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

  SharedTooltip (AttributeTooltip instance) [unique name %SharedTooltip]

  AnimationPlayer [unique name %AnimationPlayer]
    — Create "open" animation (0.3s): modulate alpha 0→1, scale 0.95→1.0
    — Create "close" animation (0.2s): modulate alpha 1→0, scale 1.0→0.95
    — Copy animation structure from AbilitiesView's AnimationPlayer
```

- [ ] **Step 3: Commit**

```bash
git add scenes/character/character_view.gd scenes/character/character_view.tscn
git commit -m "feat(character): add CharacterView with attribute display and tooltips"
```

---

### Task 5: Create CharacterViewState

**Files:**
- Create: `scenes/character/character_view_state.gd`

Identical pattern to AbilitiesViewState and PathTreeViewState.

- [ ] **Step 1: Create character_view_state.gd**

```gdscript
## State for the Character View.
## Delegates open/close animation to GreyBackground, which plays its own fade
## in parallel with CharacterView.animate_open() / animate_close().
class_name CharacterViewState
extends MainViewState

## Called when entering this state.
func enter() -> void:
	scene_root.grey_background.show_with_panel(scene_root.character_view)

## Called when exiting this state.
## Hiding is driven by grey_background.panel_hidden -> _on_close_finished -> pop_state,
## so by the time exit() runs the grey background and character view are already hidden.
func exit() -> void:
	pass

## Handle input events in this state.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_character"):
		if not scene_root.grey_background.panel_hidden.is_connected(_on_close_finished):
			scene_root.grey_background.panel_hidden.connect(_on_close_finished, CONNECT_ONE_SHOT)
		scene_root.grey_background.hide_with_panel(scene_root.character_view)

## Handle completion of the grey background hide animation to pop the state.
func _on_close_finished() -> void:
	scene_root.pop_state()
```

- [ ] **Step 2: Commit**

```bash
git add scenes/character/character_view_state.gd
git commit -m "feat(character): add CharacterViewState"
```

---

### Task 6: Wire CharacterView into MainView and state machine

**Files:**
- Modify: `scenes/ui/main_view/main_view.gd`
- Modify: `scenes/main/main_game/main_game.tscn`
- Modify: `scenes/ui/main_view/states/zone_view_state.gd`

- [ ] **Step 1: Add CharacterView and CharacterViewState to main_game.tscn**

In the Godot editor (or by editing the .tscn):

1. Instance `scenes/character/character_view.tscn` as a child of `MainView`, between `AbilitiesView` and `LogWindow`. Set unique name `%CharacterView`.
2. Add a new `Node` child under `MainViewStateMachine` named `CharacterViewState`. Attach `scenes/character/character_view_state.gd` as its script.

- [ ] **Step 2: Add @onready references in main_view.gd**

Add to the "Main Views" section, after the `abilities_view` line:

```gdscript
@onready var character_view: CharacterView = %CharacterView
```

Add to the "State machine states" section, after the `abilities_view_state` line:

```gdscript
@onready var character_view_state: MainViewState = %MainViewStateMachine/CharacterViewState
```

- [ ] **Step 3: Wire scene_root in _ready()**

Add after the `abilities_view_state.scene_root = self` line:

```gdscript
	character_view_state.scene_root = self
```

- [ ] **Step 4: Handle open_character in zone_view_state.gd**

Add a new `elif` branch in `handle_input()`, after the `open_abilities` check:

```gdscript
	elif event.is_action_pressed("open_character"):
		scene_root.push_state(scene_root.character_view_state)
```

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/main_view/main_view.gd scenes/main/main_game/main_game.tscn scenes/ui/main_view/states/zone_view_state.gd
git commit -m "feat(character): wire CharacterView into MainView and state machine"
```

---

### Task 7: End-to-end test and polish

**Files:**
- No new files — manual testing in the running game

- [ ] **Step 1: Run the game and test**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn
```

Verify:
1. Press C on zone view — Character panel fades in with grey background
2. Two columns visible: PHYSICAL (Strength, Body, Agility, Resilience) and SPIRITUAL (Spirit, Foundation, Control, Willpower)
3. All values show "10" (default base attributes)
4. Hover over any row — tooltip appears above with title, description, and formula
5. Move mouse away — tooltip hides
6. Press C again or ESC — panel fades out
7. Click CHARACTER button in toolbar — same panel opens
8. Open Inventory (I), close, then open Character (C) — no conflicts
9. Open during adventure — should not work (ZoneViewState only)

- [ ] **Step 2: Fix any visual issues**

Common adjustments:
- UnifiedPanel anchor/offset if not centered on screen
- Tooltip clipping at top of screen (may need to flip below row if near top)
- AnimationPlayer keyframe timing if open/close feels off
- Column width balance if one side looks cramped

- [ ] **Step 3: Final commit**

```bash
git add -A  # only if fixing visual tweaks in .tscn
git commit -m "fix(character): polish character view layout and animations"
```
