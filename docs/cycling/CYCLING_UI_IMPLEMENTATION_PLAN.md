# Cycling View UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the Cycling View from its current placeholder layout into a polished full-screen overlay with body diagram left, tabbed info panel right (Resources/Techniques tabs), and a visible close button.

**Architecture:** Keep all existing cycling gameplay logic (CyclingTechnique) untouched. Rework the outer layout (CyclingView), replace the resource panel with a compact tabbed version, and eliminate the modal technique selector by integrating it as a tab. User rebuilds scenes in Godot editor; agent writes scripts.

**Tech Stack:** Godot 4.6, GDScript

**Source Design:** `docs/cycling/CYCLING_UI_REDESIGN.md`

---

## User Manual Steps (Godot Editor Required)

| Step | When | What to Do in Editor |
|------|------|---------------------|
| **M1** | After Task 1 | Rebuild `cycling_view.tscn` with new layout structure (HBoxContainer split, close button, controls row). Detailed node tree provided in Task 1. |
| **M2** | After Task 2 | Build the tab bar UI in the info panel — two Button nodes styled as tabs. |
| **M3** | After Task 3 | Rebuild `cycling_resource_panel.tscn` with compact horizontal rows (Madra row, Core Density row, Technique summary). |
| **M4** | After Task 4 | Rebuild `cycling_technique_slot.tscn` as a compact horizontal slot (icon + name + stat line). |
| **M5** | After Task 5 | Verify all signals connect, test cycling gameplay works, technique switching works via tab. |

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `scenes/cycling/cycling_view/cycling_view.gd` | Remove modal logic, add close button + tab switching |
| Modify (editor) | `scenes/cycling/cycling_view/cycling_view.tscn` | New HBoxContainer layout with left/right split |
| Create | `scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd` | Tab switching logic (Resources vs Techniques) |
| Create (editor) | `scenes/cycling/cycling_tab_panel/cycling_tab_panel.tscn` | Tab bar + content container scene |
| Modify | `scenes/cycling/cycling_resource_panel/cycling_resource_panel.gd` | Compact layout, remove open_technique_selector signal/button |
| Modify (editor) | `scenes/cycling/cycling_resource_panel/cycling_resource_panel.tscn` | Horizontal resource rows, technique summary card |
| Modify | `scenes/cycling/cycling_technique_selector/cycling_technique_slot.gd` | Rework to compact slot with equipped/locked states |
| Modify (editor) | `scenes/cycling/cycling_technique_selector/cycling_technique_slot.tscn` | Horizontal compact layout |
| Delete | `scenes/cycling/cycling_technique_selector/cycling_technique_selector.gd` | Replaced by tab panel |
| Delete | `scenes/cycling/cycling_technique_selector/cycling_technique_selector.tscn` | Replaced by tab panel |
| Delete | `scenes/cycling/cycling_technique_selector/info_panel.gd` | No longer needed |
| No change | `scenes/cycling/cycling_technique/cycling_technique.gd` | Core gameplay logic unchanged |
| No change | `scripts/resource_definitions/cycling/cycling_technique/cycling_technique_data.gd` | Data model unchanged |
| No change | `scripts/resource_definitions/cycling/cycling_technique/cycling_zone_data.gd` | Data model unchanged |

---

## Task 1: Create CyclingTabPanel (Tab Switching Logic)

**Files:**
- Create: `scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd`

This is a simple controller that toggles between two child containers based on which tab button is pressed.

- [ ] **Step 1: Write `cycling_tab_panel.gd`**

```gdscript
class_name CyclingTabPanel
extends PanelContainer

## CyclingTabPanel
## Manages tab switching between Resources and Techniques content.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal technique_change_request(data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _resources_tab_button: Button = %ResourcesTabButton
@onready var _techniques_tab_button: Button = %TechniquesTabButton
@onready var _resources_content: Control = %ResourcesContent
@onready var _techniques_content: Control = %TechniquesContent
@onready var _technique_list_container: VBoxContainer = %TechniqueListContainer

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

enum Tab { RESOURCES, TECHNIQUES }
var _active_tab: Tab = Tab.RESOURCES

var _technique_slot_scene: PackedScene = preload("res://scenes/cycling/cycling_technique_selector/cycling_technique_slot.tscn")
var _technique_list: CyclingTechniqueList = null
var _current_technique_data: CyclingTechniqueData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_resources_tab_button.pressed.connect(_on_resources_tab_pressed)
	_techniques_tab_button.pressed.connect(_on_techniques_tab_pressed)
	_switch_tab(Tab.RESOURCES)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initialize with technique list data.
func setup(technique_list: CyclingTechniqueList) -> void:
	_technique_list = technique_list

## Update which technique is currently equipped (for highlight state).
func set_current_technique(data: CyclingTechniqueData) -> void:
	_current_technique_data = data
	_update_technique_slot_states()

## Switch to the Resources tab.
func show_resources_tab() -> void:
	_switch_tab(Tab.RESOURCES)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_resources_tab_pressed() -> void:
	_switch_tab(Tab.RESOURCES)

func _on_techniques_tab_pressed() -> void:
	_switch_tab(Tab.TECHNIQUES)
	_populate_technique_list()

func _switch_tab(tab: Tab) -> void:
	_active_tab = tab
	_resources_content.visible = (tab == Tab.RESOURCES)
	_techniques_content.visible = (tab == Tab.TECHNIQUES)

	# Update tab button visuals
	_resources_tab_button.add_theme_color_override("font_color",
		ThemeConstants.ACCENT_GOLD if tab == Tab.RESOURCES else ThemeConstants.TEXT_MUTED)
	_techniques_tab_button.add_theme_color_override("font_color",
		ThemeConstants.ACCENT_GOLD if tab == Tab.TECHNIQUES else ThemeConstants.TEXT_MUTED)

func _populate_technique_list() -> void:
	if _technique_list == null:
		return

	# Clear previous slots
	for child in _technique_list_container.get_children():
		child.queue_free()

	# Create a slot for each technique
	for technique_data: CyclingTechniqueData in _technique_list.cycling_techniques:
		var slot: Control = _technique_slot_scene.instantiate()
		_technique_list_container.add_child(slot)
		slot.setup(technique_data)
		slot.set_equipped(_current_technique_data == technique_data)
		slot.slot_selected.connect(_on_technique_slot_selected)

func _update_technique_slot_states() -> void:
	for slot in _technique_list_container.get_children():
		if slot.has_method("set_equipped"):
			slot.set_equipped(slot.technique_data == _current_technique_data)

func _on_technique_slot_selected(data: CyclingTechniqueData) -> void:
	technique_change_request.emit(data)
```

- [ ] **Step 2: Commit**

```bash
git add scenes/cycling/cycling_tab_panel/cycling_tab_panel.gd
git commit -m "feat(cycling): add CyclingTabPanel for Resources/Techniques tab switching"
```

---

## Task 2: Build CyclingTabPanel Scene (User — Godot Editor)

**Files:**
- Create (editor): `scenes/cycling/cycling_tab_panel/cycling_tab_panel.tscn`

> **This is manual step M2.**

- [ ] **Step 1: Create the scene with this node tree**

```
CyclingTabPanel (PanelContainer) — attach cycling_tab_panel.gd
├── VBoxContainer
│   ├── TabBar (HBoxContainer)
│   │   ├── ResourcesTabButton (Button, unique name %ResourcesTabButton)
│   │   │   text = "Resources"
│   │   │   size_flags_horizontal = SIZE_EXPAND_FILL
│   │   └── TechniquesTabButton (Button, unique name %TechniquesTabButton)
│   │       text = "Techniques"
│   │       size_flags_horizontal = SIZE_EXPAND_FILL
│   └── TabContentContainer (Control)
│       ├── ResourcesContent (VBoxContainer, unique name %ResourcesContent)
│       │   └── (CyclingResourcePanel will be instanced here in Task 5)
│       └── TechniquesContent (ScrollContainer, unique name %TechniquesContent, visible = false)
│           └── TechniqueListContainer (VBoxContainer, unique name %TechniqueListContainer)
│               size_flags_horizontal = SIZE_EXPAND_FILL
```

- [ ] **Step 2: Style the tab buttons**

Set both tab buttons to use the project theme's button style. For the active state visual, the script handles font color changes via `add_theme_color_override`.

- [ ] **Step 3: Set the PanelContainer's theme_type_variation to `PanelDark`**

This gives the info panel the dark background that contrasts with the body diagram area.

- [ ] **Step 4: Save the scene and commit**

```bash
git add scenes/cycling/cycling_tab_panel/
git commit -m "feat(cycling): add CyclingTabPanel scene with tab bar and content containers"
```

---

## Task 3: Rework CyclingResourcePanel to Compact Layout

**Files:**
- Modify: `scenes/cycling/cycling_resource_panel/cycling_resource_panel.gd`

The resource panel becomes a compact display with horizontal rows. Remove the `open_technique_selector` signal and button — technique selection is now handled by the tab panel.

- [ ] **Step 1: Rewrite `cycling_resource_panel.gd`**

Replace the entire file:

```gdscript
class_name CyclingResourcePanel
extends VBoxContainer

## CyclingResourcePanel
## Compact resource display for the cycling view's Resources tab.
## Shows Madra, Core Density, and active technique summary.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const MAX_CORE_DENSITY_LEVEL: float = 100.0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _madra_circle: TextureRect = %MadraCircle
@onready var _madra_amount_label: Label = %MadraAmountLabel
@onready var _madra_rate_label: Label = %MadraRateLabel

@onready var _core_density_circle: TextureRect = %CoreDensityRect
@onready var _core_density_level_label: Label = %CoreDensityLevelLabel
@onready var _core_density_xp_label: Label = %CoreDensityXPLabel
@onready var _core_density_xp_bar: ProgressBar = %CoreDensityXPBar
@onready var _stage_label: Label = %StageLabel

@onready var _technique_name_label: Label = %TechniqueNameLabel
@onready var _technique_stats_label: Label = %TechniqueStatsLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _current_technique: CyclingTechniqueData = null
var _is_cycling: bool = false
var _last_madra_per_second: float = 0.0
var _last_madra_per_cycle: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if ResourceManager:
		ResourceManager.madra_changed.connect(_on_madra_changed)
	if CultivationManager:
		CultivationManager.core_density_xp_updated.connect(_on_core_density_xp_updated)
		CultivationManager.advancement_stage_changed.connect(_on_advancement_stage_changed)
	_update_all_displays()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Set the active technique and update the summary display.
func set_technique_data(data: CyclingTechniqueData) -> void:
	_current_technique = data
	_update_technique_display()

## Called when a cycle starts.
func on_cycling_started() -> void:
	_is_cycling = true
	_update_madra_rate_display()

## Called when a cycle completes.
func on_cycle_completed(madra_earned: float, mouse_accuracy: float) -> void:
	_last_madra_per_cycle = madra_earned
	if _current_technique:
		_last_madra_per_second = madra_earned / _current_technique.cycle_duration
	_update_madra_rate_display()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_madra_changed(_amount: float) -> void:
	_update_madra_display()

func _on_core_density_xp_updated() -> void:
	_update_core_density_display()

func _on_advancement_stage_changed() -> void:
	_update_stage_display()

func _update_all_displays() -> void:
	_update_madra_display()
	_update_core_density_display()
	_update_stage_display()
	_update_technique_display()
	_update_madra_rate_display()

func _update_madra_display() -> void:
	if not ResourceManager:
		return
	var current: float = ResourceManager.get_madra()
	var max_madra: float = ResourceManager.get_max_madra()
	_madra_amount_label.text = "Madra: %d / %d" % [current, max_madra]

	if _madra_circle and _madra_circle.material:
		var progress: float = current / max_madra if max_madra > 0 else 0.0
		_madra_circle.material.set_shader_parameter("progress", progress)

func _update_madra_rate_display() -> void:
	if _is_cycling:
		_madra_rate_label.text = "+%.1f/s  %.1f/cycle" % [_last_madra_per_second, _last_madra_per_cycle]
	else:
		if _current_technique:
			_madra_rate_label.text = "%.1f/cycle" % _current_technique.base_madra_per_cycle
		else:
			_madra_rate_label.text = ""

func _update_core_density_display() -> void:
	if not CultivationManager:
		return
	var level: int = CultivationManager.get_core_density_level()
	var xp: float = CultivationManager.get_core_density_xp()
	var max_xp: float = CultivationManager.get_core_density_xp_for_next_level()

	_core_density_level_label.text = "Level: %d" % level
	_core_density_xp_label.text = "XP: %d / %d" % [xp, max_xp]

	var xp_ratio: float = xp / max_xp if max_xp > 0 else 0.0
	_core_density_xp_bar.value = xp_ratio * 100.0

	if _core_density_circle and _core_density_circle.material:
		var density_progress: float = level / MAX_CORE_DENSITY_LEVEL
		_core_density_circle.material.set_shader_parameter("progress", density_progress)

func _update_stage_display() -> void:
	if not CultivationManager:
		return
	var stage_name: String = CultivationManager.get_current_stage_name()
	_stage_label.text = "Stage: %s" % stage_name

func _update_technique_display() -> void:
	if _current_technique == null:
		_technique_name_label.text = "No Technique"
		_technique_stats_label.text = ""
		return
	_technique_name_label.text = _current_technique.technique_name
	var zones_count: int = _current_technique.cycling_zones.size()
	_technique_stats_label.text = "%g Madra/cycle  %gs  %d zones" % [
		_current_technique.base_madra_per_cycle,
		_current_technique.cycle_duration,
		zones_count
	]
```

- [ ] **Step 2: Commit**

```bash
git add scenes/cycling/cycling_resource_panel/cycling_resource_panel.gd
git commit -m "refactor(cycling): rework CyclingResourcePanel to compact layout

Remove open_technique_selector signal and button. Add technique
summary section. Simplify to horizontal resource rows."
```

---

## Task 3b: Rebuild CyclingResourcePanel Scene (User — Godot Editor)

**Files:**
- Modify (editor): `scenes/cycling/cycling_resource_panel/cycling_resource_panel.tscn`

> **This is manual step M3.**

- [ ] **Step 1: Rebuild the scene with this node tree**

The root node should be a `VBoxContainer` (was `MarginContainer`). Attach `cycling_resource_panel.gd`.

```
CyclingResourcePanel (VBoxContainer) — attach cycling_resource_panel.gd
├── MadraRow (HBoxContainer)
│   ├── MadraCircle (TextureRect, unique name %MadraCircle, 48x48)
│   │   material = ShaderMaterial (liquid_wave shader, keep existing)
│   └── MadraInfo (VBoxContainer)
│       ├── MadraAmountLabel (Label, unique name %MadraAmountLabel)
│       │   text = "Madra: 0 / 100"
│       └── MadraRateLabel (Label, unique name %MadraRateLabel)
│           text = "+0.0/s"
│           theme_type_variation = "LabelDark" (if on light bg) or leave default
│
├── HSeparator
│
├── CoreDensityRow (HBoxContainer)
│   ├── CoreDensityRect (TextureRect, unique name %CoreDensityRect, 48x48)
│   │   material = ShaderMaterial (core_density_fill shader, keep existing)
│   └── CoreDensityInfo (VBoxContainer)
│       ├── CoreDensityLevelLabel (Label, unique name %CoreDensityLevelLabel)
│       │   text = "Level: 0"
│       ├── CoreDensityXPBar (ProgressBar, unique name %CoreDensityXPBar)
│       │   custom_minimum_size = (0, 8)
│       ├── CoreDensityXPLabel (Label, unique name %CoreDensityXPLabel)
│       │   text = "XP: 0 / 10"
│       └── StageLabel (Label, unique name %StageLabel)
│           text = "Stage: Foundation"
│
├── HSeparator
│
└── TechniqueSummary (PanelContainer, theme_type_variation = "PanelAccent")
    └── VBoxContainer
        ├── TechniqueNameLabel (Label, unique name %TechniqueNameLabel)
        │   text = "Foundation Technique"
        │   add gold color override or use theme
        └── TechniqueStatsLabel (Label, unique name %TechniqueStatsLabel)
            text = "25 Madra/cycle  10s  3 zones"
```

- [ ] **Step 2: Copy shader materials from the old scene**

The MadraCircle and CoreDensityRect need their ShaderMaterial resources. Copy these from the existing `cycling_resource_panel.tscn` before deleting/rebuilding. The textures are `assets/asperite/cycling/madra_circle.png`.

- [ ] **Step 3: Save and commit**

```bash
git add scenes/cycling/cycling_resource_panel/cycling_resource_panel.tscn
git commit -m "refactor(cycling): rebuild CyclingResourcePanel with compact horizontal rows"
```

---

## Task 4: Rework CyclingTechniqueSlot (Compact + Equipped State)

**Files:**
- Modify: `scenes/cycling/cycling_technique_selector/cycling_technique_slot.gd`

The slot becomes a compact horizontal row with an equipped highlight state (replacing the old "selected" concept).

- [ ] **Step 1: Rewrite `cycling_technique_slot.gd`**

Replace the entire file:

```gdscript
extends Control

## CyclingTechniqueSlot
## A compact technique slot for the Techniques tab list.
## Click to equip. Shows equipped state with gold border.

#-----------------------------------------------------------------------------
# SIGNALS
#-----------------------------------------------------------------------------

signal slot_selected(data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _panel: PanelContainer = %CyclingTechniquePanelContainer
@onready var _icon_rect: TextureRect = %CyclingTechniqueIcon
@onready var _name_label: Label = %TechniqueNameLabel
@onready var _stats_label: Label = %TechniqueStatsLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var technique_data: CyclingTechniqueData = null
var _is_equipped: bool = false

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initialize the slot with technique data.
func setup(data: CyclingTechniqueData) -> void:
	technique_data = data
	_update_display()

## Set whether this technique is currently equipped.
func set_equipped(equipped: bool) -> void:
	_is_equipped = equipped
	_update_visual_state()

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _update_display() -> void:
	if technique_data == null:
		_name_label.text = "Unknown"
		_stats_label.text = ""
		return

	_name_label.text = technique_data.technique_name
	var zones_count: int = technique_data.cycling_zones.size()
	_stats_label.text = "%g/cycle  %gs  %d zones" % [
		technique_data.base_madra_per_cycle,
		technique_data.cycle_duration,
		zones_count
	]

func _update_visual_state() -> void:
	if _panel == null:
		return
	if _is_equipped:
		_name_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)
	else:
		_name_label.remove_theme_color_override("font_color")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(technique_data)

func _on_mouse_entered() -> void:
	if not _is_equipped and _name_label:
		_name_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_GOLD)

func _on_mouse_exited() -> void:
	if not _is_equipped and _name_label:
		_name_label.remove_theme_color_override("font_color")
```

- [ ] **Step 2: Commit**

```bash
git add scenes/cycling/cycling_technique_selector/cycling_technique_slot.gd
git commit -m "refactor(cycling): rework technique slot to compact layout with equipped state"
```

---

## Task 4b: Rebuild CyclingTechniqueSlot Scene (User — Godot Editor)

**Files:**
- Modify (editor): `scenes/cycling/cycling_technique_selector/cycling_technique_slot.tscn`

> **This is manual step M4.**

- [ ] **Step 1: Rebuild the scene with this node tree**

```
CyclingTechniqueSlot (Control) — attach cycling_technique_slot.gd
├── CyclingTechniquePanelContainer (PanelContainer, unique name %CyclingTechniquePanelContainer)
│   theme_override_styles/panel = button_default_normal.tres
│   └── HBoxContainer (separation = 8)
│       ├── CyclingTechniqueIcon (TextureRect, unique name %CyclingTechniqueIcon)
│       │   custom_minimum_size = (28, 28)
│       │   expand_mode = FIT_WIDTH_PROPORTIONAL
│       │   stretch_mode = KEEP_ASPECT_CENTERED
│       └── VBoxContainer
│           ├── TechniqueNameLabel (Label, unique name %TechniqueNameLabel)
│           │   text = "Technique Name"
│           └── TechniqueStatsLabel (Label, unique name %TechniqueStatsLabel)
│               text = "25/cycle  10s  3 zones"
│               theme_type_variation = "LabelDark" or muted color
```

- [ ] **Step 2: Set size_flags_horizontal = SIZE_EXPAND_FILL on the root Control**

- [ ] **Step 3: Save and commit**

```bash
git add scenes/cycling/cycling_technique_selector/cycling_technique_slot.tscn
git commit -m "refactor(cycling): rebuild technique slot scene as compact horizontal row"
```

---

## Task 5: Rewrite CyclingView to Wire Everything Together

**Files:**
- Modify: `scenes/cycling/cycling_view/cycling_view.gd`
- Delete: `scenes/cycling/cycling_technique_selector/cycling_technique_selector.gd`
- Delete: `scenes/cycling/cycling_technique_selector/info_panel.gd`

- [ ] **Step 1: Rewrite `cycling_view.gd`**

Replace the entire file:

```gdscript
## Manages the cycling view, including technique selection and execution.
extends Control

signal current_technique_changed(technique_data: CyclingTechniqueData)

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var cycling_technique_node: CyclingTechnique = %CyclingTechnique
@onready var cycling_resource_panel_node: CyclingResourcePanel = %CyclingResourcePanel
@onready var cycling_tab_panel: CyclingTabPanel = %CyclingTabPanel
@onready var close_button: Button = %CloseButton

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var current_cycling_technique_data: CyclingTechniqueData = null
var technique_list: CyclingTechniqueList = preload("res://resources/cycling/cycling_techniques/cycling_technique_list.tres")
var foundation_technique: CyclingTechniqueData = technique_list.cycling_techniques[0]
var cycling_action_data: CyclingActionData = null

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	# Technique change propagation
	current_technique_changed.connect(cycling_technique_node.set_technique_data)
	current_technique_changed.connect(cycling_resource_panel_node.set_technique_data)
	current_technique_changed.connect(cycling_tab_panel.set_current_technique)

	# Cycling state signals
	cycling_technique_node.cycling_started.connect(cycling_resource_panel_node.on_cycling_started)
	cycling_technique_node.cycle_completed.connect(cycling_resource_panel_node.on_cycle_completed)

	# Tab panel technique change
	cycling_tab_panel.technique_change_request.connect(_on_technique_change_request)
	cycling_tab_panel.setup(technique_list)

	# Close button
	close_button.pressed.connect(_on_close_button_pressed)

	# ActionManager
	ActionManager.stop_cycling.connect(_on_stop_cycling)

	# Load saved technique
	_load_saved_technique()

#-----------------------------------------------------------------------------
# PUBLIC FUNCTIONS
#-----------------------------------------------------------------------------

## Initializes the view with action data.
func initialize_cycling_action_data(action_data: CyclingActionData) -> void:
	cycling_action_data = action_data

## Sets the current technique.
func set_current_technique(technique_data: CyclingTechniqueData) -> void:
	current_cycling_technique_data = technique_data
	current_technique_changed.emit(technique_data)
	_save_current_technique(technique_data)

#-----------------------------------------------------------------------------
# PRIVATE FUNCTIONS
#-----------------------------------------------------------------------------

func _on_technique_change_request(technique_data: CyclingTechniqueData) -> void:
	set_current_technique(technique_data)
	cycling_tab_panel.show_resources_tab()

func _on_close_button_pressed() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"close_cycling_view"
	event.pressed = true
	Input.parse_input_event(event)

func _on_stop_cycling() -> void:
	cycling_technique_node.stop_cycling()

func _load_saved_technique() -> void:
	if not PersistenceManager or not PersistenceManager.save_game_data:
		set_current_technique(foundation_technique)
		return

	if not technique_list:
		set_current_technique(foundation_technique)
		return

	var saved_name: String = PersistenceManager.save_game_data.current_cycling_technique_name
	var found_technique: CyclingTechniqueData = null
	for technique: CyclingTechniqueData in technique_list.cycling_techniques:
		if technique.technique_name == saved_name:
			found_technique = technique
			break

	set_current_technique(found_technique if found_technique else foundation_technique)

func _save_current_technique(technique_data: CyclingTechniqueData) -> void:
	if not PersistenceManager or not PersistenceManager.save_game_data:
		return
	if technique_data and technique_data.technique_name:
		PersistenceManager.save_game_data.current_cycling_technique_name = technique_data.technique_name
```

- [ ] **Step 2: Delete old technique selector files**

```bash
rm scenes/cycling/cycling_technique_selector/cycling_technique_selector.gd
rm scenes/cycling/cycling_technique_selector/cycling_technique_selector.tscn
rm scenes/cycling/cycling_technique_selector/info_panel.gd
```

- [ ] **Step 3: Commit**

```bash
git add scenes/cycling/cycling_view/cycling_view.gd
git rm scenes/cycling/cycling_technique_selector/cycling_technique_selector.gd
git rm scenes/cycling/cycling_technique_selector/cycling_technique_selector.tscn
git rm scenes/cycling/cycling_technique_selector/info_panel.gd
git commit -m "feat(cycling): rewrite CyclingView with tab panel, close button, no modal

Replace modal technique selector with CyclingTabPanel tabs.
Add close button that fires close_cycling_view input action.
Technique changes auto-switch back to Resources tab."
```

---

## Task 6: Rebuild CyclingView Scene (User — Godot Editor)

**Files:**
- Modify (editor): `scenes/cycling/cycling_view/cycling_view.tscn`

> **This is manual step M1.**

- [ ] **Step 1: Rebuild the scene with this node tree**

```
CyclingView (Control) — attach cycling_view.gd
│  anchors_preset = FULL_RECT
│  mouse_filter = MOUSE_FILTER_IGNORE
│
├── MarginContainer (margins: 80 left, 60 top, 80 right, 60 bottom)
│   │  anchors_preset = FULL_RECT
│   │
│   └── HBoxContainer (separation = 0)
│       │
│       ├── BodyDiagramArea (PanelContainer, size_flags_h = EXPAND_FILL, stretch_ratio = 1.5)
│       │   theme_type_variation = "PanelDefault" or panel_tan stylebox
│       │   │
│       │   └── VBoxContainer
│       │       │
│       │       ├── CyclingBackground (TextureRect)
│       │       │   texture = Cycling_Technique_Background.webp
│       │       │   expand_mode = IGNORE_SIZE
│       │       │   stretch_mode = KEEP_ASPECT_CENTERED
│       │       │   size_flags_vertical = EXPAND_FILL
│       │       │   mouse_filter = MOUSE_FILTER_IGNORE
│       │       │   │
│       │       │   └── CyclingTechnique (instance, unique name %CyclingTechnique)
│       │       │       (keep existing scene — DO NOT modify)
│       │       │
│       │       └── ControlsRow (HBoxContainer, alignment = CENTER)
│       │           ├── StartCyclingButton (Button)
│       │           │   text = "Start Cycle"
│       │           └── AutoCycleToggle (TextureButton or CheckButton)
│       │
│       └── InfoPanelArea (PanelContainer, size_flags_h = EXPAND_FILL, stretch_ratio = 1.0)
│           │
│           └── CyclingTabPanel (instance, unique name %CyclingTabPanel)
│               └── ResourcesContent should contain:
│                   CyclingResourcePanel (instance, unique name %CyclingResourcePanel)
│
├── CloseButton (Button, unique name %CloseButton)
│   anchors_preset = TOP_LEFT
│   offset = (20, 20)
│   text = "✕ ESC"
│   stylebox = button_default
```

**Important notes:**
- The `CyclingTechnique` scene is instanced INSIDE `CyclingBackground` — this preserves the body diagram + path + zones relationship
- The `StartCyclingButton` and `AutoCycleToggle` need to be **moved out** of the CyclingTechnique scene into the new `ControlsRow`. You'll need to update CyclingTechnique's `@onready` references — OR leave them inside CyclingTechnique and just restyle/reposition them there. **Recommendation: leave them inside CyclingTechnique** to avoid breaking the gameplay script. Just visually position them below the body diagram using the existing scene.
- The `CyclingResourcePanel` instance goes inside the `CyclingTabPanel`'s `ResourcesContent` node
- The `CloseButton` is a direct child of CyclingView, positioned absolute top-left

- [ ] **Step 2: Verify all unique names resolve**

The scripts reference these unique names:
- `%CyclingTechnique` — must be on the CyclingTechnique instance
- `%CyclingResourcePanel` — must be on the CyclingResourcePanel instance
- `%CyclingTabPanel` — must be on the CyclingTabPanel instance
- `%CloseButton` — must be on the close button

- [ ] **Step 3: Save and commit**

```bash
git add scenes/cycling/cycling_view/cycling_view.tscn
git commit -m "refactor(cycling): rebuild CyclingView scene with left/right split layout"
```

---

## Task 7: Smoke Test (User — Godot Editor)

> **This is manual step M5.**

- [ ] **Step 1: Launch the game and enter a Cycling zone action**

Verify the cycling view opens with the new layout: body diagram left, tabbed panel right.

- [ ] **Step 2: Test Resources tab**

- Madra orb and amount display correctly
- Core Density level and XP bar display correctly
- Stage shows "Foundation"
- Technique summary shows "Foundation Technique" with stats

- [ ] **Step 3: Test cycling gameplay**

- Click Start Cycle — ball animates along path
- Click cycling zones — timing feedback appears
- Madra rate updates during cycling
- Cycle completes — madra earned, XP awarded

- [ ] **Step 4: Test Techniques tab**

- Click "Techniques" tab — technique list appears
- Current technique is highlighted in gold
- Click a different technique — it equips and switches back to Resources tab
- Technique summary updates

- [ ] **Step 5: Test close button**

- Click "✕ ESC" — cycling view closes, returns to zone view
- Press Escape key — same behavior (existing functionality)

- [ ] **Step 6: Test auto-cycle**

- Toggle auto-cycle on — cycles repeat automatically
- Toggle off — cycling stops after current cycle

---

## Summary of Changes

| What | Before | After |
|------|--------|-------|
| Layout | Body diagram + resource panel in a flat Panel | HBoxContainer: body left (60%), tabbed panel right (40%) |
| Technique selector | Modal overlay (CyclingTechniqueSelector) | Tab in info panel (Techniques tab) |
| Resource display | Vertical stacked orbs + labels | Compact horizontal rows |
| Close button | None (only ESC key) | Visible "✕ ESC" button top-left |
| Technique summary | Buried in resource panel | Distinct card in Resources tab |
| Files deleted | — | cycling_technique_selector.gd, .tscn, info_panel.gd |
| Files created | — | cycling_tab_panel.gd, .tscn |
