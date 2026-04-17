# Quest System — Pass 2 (UI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface the already-functional quest backend (Pass 1) in the game UI — a collapsible `QuestWindow` panel, ephemeral `QuestToast` notifications, and a badge dot that signals "new quest activity".

**Architecture:** Both scenes mount at the MainGame level (alongside `LogWindow`) so they're visible in every view state. Both subscribe to `QuestManager` signals (`quest_started`, `quest_step_advanced`, `quest_completed`). UI reads current state via `QuestManager` getters — no UI state persisted. `QuestWindow` uses the LogWindow collapse pattern but is **non-draggable**. Completed quests remain in the list forever (simplified for now).

**Preview-first design:** Every UI scene (`QuestEntry`, `QuestWindow`, `QuestToast`) accepts `@export` preview values so an editor user can open the scene file, drop in test data, and press F6 to render it standalone. When preview data is set, the scene bypasses signal wiring so live `QuestManager` events don't overwrite the preview.

**Styling rule:** Labels use `theme_type_variation` exclusively — no `theme_override_font_sizes` or `theme_override_colors` unless the spec explicitly calls it out (the only exception is the `QuestWindow` title, which clones LogWindow's `LabelHeading + 20px` override pattern to match visual precedent). Styleboxes are extracted to `.tres` resources — no inline StyleBox overrides in scene files.

**Tech Stack:** Godot 4.6, GDScript, existing `pixel_theme.tres` variants (`LabelHeading`, `LabelBody`, `LabelBodySmall`, `LabelMuted`). No new addons. No unit tests — manual playtest per project convention.

**Reference docs:**
- Spec: `docs/superpowers/specs/2026-04-16-quest-system-design.md` (Section 2 — UI)
- Pass 1 plan (merged): `docs/superpowers/plans/2026-04-16-quest-system-pass-1-backend.md`
- UI styling: `docs/UI_STYLING.md`
- LogWindow reference: `scenes/ui/log_window/log_window.gd` + `log_window.tscn`

---

## File Structure

**New files:**
| File | Responsibility |
|---|---|
| `scenes/ui/quest_window/quest_entry/quest_entry.tscn` | One quest row — title + step-or-complete label |
| `scenes/ui/quest_window/quest_entry/quest_entry.gd` | Populates the row from `QuestData` + state + step index |
| `scenes/ui/quest_window/quest_window.tscn` | Main collapsible panel — title bar, badge dot, content list |
| `scenes/ui/quest_window/quest_window.gd` | Listens to QuestManager signals, rebuilds list, manages badge + collapse |
| `scenes/ui/quest_toast/quest_toast.tscn` | Single-line top-center popup with fade+slide anim |
| `scenes/ui/quest_toast/quest_toast.gd` | Queue-based message display driven by QuestManager signals |
| `assets/styleboxes/ui/quest_window.tres` | Content panel background (clone of `log_window.tres`) |
| `assets/styleboxes/ui/quest_titlebar.tres` | Title bar background (clone of `log_titlebar.tres`) |
| `assets/styleboxes/ui/quest_toast.tres` | Toast background — darker/more opaque than titlebar |
| `resources/quests/test_quest_resource.tres` | First real quest — "Speak with the Wisened Dirt Eel" (stays in production) |
| `resources/effects/start_quest/start_test_quest_effect.tres` | `StartQuestEffectData` pointing at the test quest |

**Modified files:**
| File | Change |
|---|---|
| `scenes/main/main_game/main_game.tscn` | Instance `QuestWindow` + `QuestToast` as children of `MainView` |
| `resources/quests/quest_list.tres` | Add `test_quest_resource.tres` to the catalog |
| `resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres` | Prepend the StartQuest effect to `success_effects` |

---

## Task 1: Create QuestEntry sub-scene (with preview exports)

Build the smallest visual unit first — a single row. Add `@export` preview values so an editor user can open `quest_entry.tscn`, drop in a `QuestData` resource, and press F6 to see the row rendered standalone.

**Files:**
- Create: `scenes/ui/quest_window/quest_entry/quest_entry.gd`
- Create: `scenes/ui/quest_window/quest_entry/quest_entry.tscn`

- [ ] **Step 1: Create the script**

```gdscript
class_name QuestEntry
extends VBoxContainer

## One row in the QuestWindow quest list. Displays a quest's name + either
## the current step description (active) or "✓ Complete" (completed).
##
## Preview: drop a QuestData into `preview_quest`, set `preview_state` and
## `preview_step_index`, then launch this scene (F6) to render the row
## standalone. When preview_quest is null, the row waits for a parent to call
## populate() at runtime.

enum State { ACTIVE, COMPLETED }

#-----------------------------------------------------------------------------
# EDITOR PREVIEW
#-----------------------------------------------------------------------------

@export var preview_quest: QuestData
@export var preview_state: State = State.ACTIVE
@export var preview_step_index: int = 0

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _title_label: Label = %TitleLabel
@onready var _detail_label: Label = %DetailLabel

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	if preview_quest != null:
		populate(preview_quest, preview_state, preview_step_index)

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Populates the entry from quest data. For ACTIVE state, `step_index` must be
## a valid index into `quest.steps`. For COMPLETED state, `step_index` is unused.
func populate(quest: QuestData, state: State, step_index: int) -> void:
	if quest == null:
		_title_label.text = "(unknown quest)"
		_detail_label.text = ""
		return
	_title_label.text = quest.quest_name
	match state:
		State.ACTIVE:
			self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			if step_index >= 0 and step_index < quest.steps.size():
				_detail_label.text = quest.steps[step_index].description
			else:
				_detail_label.text = ""
		State.COMPLETED:
			self_modulate = Color(1.0, 1.0, 1.0, 0.55)
			_detail_label.text = "✓ Complete"
```

Note: state-based styling uses `self_modulate` (a node property, not a theme override) to dim completed entries. No font-color overrides; the variant's color palette is preserved.

- [ ] **Step 2: Create the scene**

Write `scenes/ui/quest_window/quest_entry/quest_entry.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b1quest1entry1"]

[ext_resource type="Script" path="res://scenes/ui/quest_window/quest_entry/quest_entry.gd" id="1_qe"]

[node name="QuestEntry" type="VBoxContainer"]
custom_minimum_size = Vector2(0, 48)
size_flags_horizontal = 3
theme_override_constants/separation = 2
script = ExtResource("1_qe")

[node name="TitleLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"LabelBody"
text = "Quest Name"

[node name="DetailLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"LabelBodySmall"
text = "Current step description"
autowrap_mode = 2
```

Label variant choices:
- `LabelBody` — 22px beige for the title
- `LabelBodySmall` — 16px beige for the detail (smaller creates hierarchy; no size/color override needed)
- `theme_override_constants/separation = 2` on the VBox — spacing constant, not a label override, fine

To preview: open `quest_entry.tscn` in the editor, inspect the root node, drag `test_quest_resource.tres` (created in Task 6) into `preview_quest`, toggle `preview_state` / `preview_step_index`, press F6.

- [ ] **Step 3: Verify the project parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly, no errors.

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/quest_window/quest_entry/
git commit -m "feat(quests-ui): add QuestEntry row scene"
```

---

## Task 2: Create stylebox resources for QuestWindow and QuestToast

Clone LogWindow's stylebox pattern so the quest UI visually matches existing panels. One for the title bar, one for the content panel, one for the toast.

**Files:**
- Create: `assets/styleboxes/ui/quest_titlebar.tres`
- Create: `assets/styleboxes/ui/quest_window.tres`
- Create: `assets/styleboxes/ui/quest_toast.tres`

- [ ] **Step 1: Create `quest_titlebar.tres`**

Clone `assets/styleboxes/ui/log_titlebar.tres`:

```
[gd_resource type="StyleBoxFlat" format=3 uid="uid://quest_titlebar_01"]

[resource]
content_margin_left = 12.0
content_margin_top = 8.0
content_margin_right = 12.0
content_margin_bottom = 8.0
bg_color = Color(0.06, 0.07, 0.1, 0.95)
border_width_bottom = 1
border_color = Color(0.831, 0.659, 0.29, 0.25)
corner_radius_top_left = 3
corner_radius_top_right = 3
```

- [ ] **Step 2: Create `quest_window.tres`**

Clone `assets/styleboxes/ui/log_window.tres`:

```
[gd_resource type="StyleBoxFlat" format=3 uid="uid://quest_window_01"]

[resource]
content_margin_left = 12.0
content_margin_top = 8.0
content_margin_right = 12.0
content_margin_bottom = 8.0
bg_color = Color(0.04, 0.05, 0.07, 0.92)
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3
```

- [ ] **Step 3: Create `quest_toast.tres`**

Slightly darker/rounder than the window — toasts should feel like floating popups:

```
[gd_resource type="StyleBoxFlat" format=3 uid="uid://quest_toast_01"]

[resource]
content_margin_left = 20.0
content_margin_top = 12.0
content_margin_right = 20.0
content_margin_bottom = 12.0
bg_color = Color(0.03, 0.04, 0.06, 0.94)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.831, 0.659, 0.29, 0.4)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4
```

- [ ] **Step 4: Verify the project parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly.

- [ ] **Step 5: Commit**

```bash
git add assets/styleboxes/ui/quest_titlebar.tres assets/styleboxes/ui/quest_window.tres assets/styleboxes/ui/quest_toast.tres
git commit -m "feat(quests-ui): add styleboxes for QuestWindow and QuestToast"
```

---

## Task 3: Scaffold QuestWindow scene (collapsible shell, no signals yet)

Clone the LogWindow structure, adapt for quests. Non-draggable (don't copy the drag handler). Add a badge dot to the title bar (hidden by default). Add `@export` preview arrays so the scene renders populated when launched standalone via F6.

**Files:**
- Create: `scenes/ui/quest_window/quest_window.gd`
- Create: `scenes/ui/quest_window/quest_window.tscn`

- [ ] **Step 1: Create the script**

```gdscript
class_name QuestWindow
extends PanelContainer
## Floating collapsible quest panel. Non-draggable — positioned via anchor in
## main_game.tscn. Subscribes to QuestManager signals to rebuild its list and
## flash a badge dot on update. Badge clears when the panel is expanded.
##
## Preview: drop QuestData resources into `preview_active_quests` and/or
## `preview_completed_quests`, then launch this scene (F6) to render the panel
## populated. Preview mode skips QuestManager signal wiring so live events do
## not overwrite the preview list.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const QUEST_ENTRY_SCENE: PackedScene = preload("res://scenes/ui/quest_window/quest_entry/quest_entry.tscn")

#-----------------------------------------------------------------------------
# EDITOR PREVIEW
#-----------------------------------------------------------------------------

## When non-empty, QuestWindow renders these as active quests (all at step 0)
## and skips live QuestManager wiring.
@export var preview_active_quests: Array[QuestData] = []
## When non-empty, QuestWindow renders these as completed quests.
@export var preview_completed_quests: Array[QuestData] = []
## When true, the panel starts expanded — useful for preview and for testing
## the content layout without clicking.
@export var preview_start_expanded: bool = false

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _content_panel: PanelContainer = %ContentPanel
@onready var _collapse_button: Button = %CollapseButton
@onready var _entries_container: VBoxContainer = %EntriesContainer
@onready var _badge_dot: ColorRect = %BadgeDot
@onready var _empty_label: Label = %EmptyLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _is_collapsed: bool = true

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	_collapse_button.pressed.connect(_on_collapse_pressed)
	_badge_dot.visible = false
	_is_collapsed = not preview_start_expanded
	_content_panel.visible = not _is_collapsed
	_collapse_button.text = "▲" if not _is_collapsed else "▼"

	if _has_preview_data():
		_rebuild_from_preview()
		return

	if QuestManager:
		QuestManager.quest_started.connect(_on_quest_changed)
		QuestManager.quest_step_advanced.connect(_on_quest_step_advanced)
		QuestManager.quest_completed.connect(_on_quest_changed)
	else:
		Log.critical("QuestWindow: QuestManager not available on ready!")
	_rebuild_list()

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Toggles the quest list panel visibility. Clears the badge when opening.
func toggle_collapse() -> void:
	_is_collapsed = not _is_collapsed
	_content_panel.visible = not _is_collapsed
	_collapse_button.text = "▲" if not _is_collapsed else "▼"
	if not _is_collapsed:
		_badge_dot.visible = false

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _has_preview_data() -> bool:
	return not preview_active_quests.is_empty() or not preview_completed_quests.is_empty()

func _rebuild_from_preview() -> void:
	_clear_entries()
	_empty_label.visible = false
	for quest: QuestData in preview_active_quests:
		if quest != null:
			_add_entry(quest, QuestEntry.State.ACTIVE, 0)
	for quest: QuestData in preview_completed_quests:
		if quest != null:
			_add_entry(quest, QuestEntry.State.COMPLETED, -1)

## Rebuilds the entry list from QuestManager state. Active quests first,
## completed quests below. Shows an empty-state label if both lists are empty.
func _rebuild_list() -> void:
	_clear_entries()
	if QuestManager == null:
		_empty_label.visible = true
		return
	var active_ids: Array[String] = QuestManager.get_active_quest_ids()
	var completed_ids: Array[String] = QuestManager.get_completed_quest_ids()
	var total: int = active_ids.size() + completed_ids.size()
	_empty_label.visible = total == 0
	for quest_id: String in active_ids:
		var quest: QuestData = QuestManager.get_quest_data(quest_id)
		if quest == null:
			continue
		var step_index: int = QuestManager.get_current_step_index(quest_id)
		_add_entry(quest, QuestEntry.State.ACTIVE, step_index)
	for quest_id: String in completed_ids:
		var quest: QuestData = QuestManager.get_quest_data(quest_id)
		if quest == null:
			continue
		_add_entry(quest, QuestEntry.State.COMPLETED, -1)

func _clear_entries() -> void:
	for child in _entries_container.get_children():
		if child == _empty_label:
			continue
		child.queue_free()

func _add_entry(quest: QuestData, state: QuestEntry.State, step_index: int) -> void:
	var entry: QuestEntry = QUEST_ENTRY_SCENE.instantiate()
	_entries_container.add_child(entry)
	entry.populate(quest, state, step_index)

func _on_collapse_pressed() -> void:
	toggle_collapse()

## Handles quest_started and quest_completed (both use (quest_id: String)).
func _on_quest_changed(_quest_id: String) -> void:
	_rebuild_list()
	_flash_badge_if_collapsed()

## Separate handler for quest_step_advanced (extra new_step_index arg).
func _on_quest_step_advanced(_quest_id: String, _new_step_index: int) -> void:
	_rebuild_list()
	_flash_badge_if_collapsed()

func _flash_badge_if_collapsed() -> void:
	if _is_collapsed:
		_badge_dot.visible = true
```

Key behavior decisions baked in here:

- `_clear_entries()` preserves the `EmptyLabel` node across rebuilds (it's a child of the entries container)
- Preview mode branches early in `_ready()` and never connects to QuestManager
- Badge dot only flashes when the panel is collapsed — open panel sees live updates without the dot

- [ ] **Step 2: Create the scene**

Write `scenes/ui/quest_window/quest_window.tscn`:

```
[gd_scene load_steps=4 format=3 uid="uid://b1quest1win1"]

[ext_resource type="Script" path="res://scenes/ui/quest_window/quest_window.gd" id="1_qw"]
[ext_resource type="StyleBox" uid="uid://quest_window_01" path="res://assets/styleboxes/ui/quest_window.tres" id="2_qwbg"]
[ext_resource type="StyleBox" uid="uid://quest_titlebar_01" path="res://assets/styleboxes/ui/quest_titlebar.tres" id="3_qtb"]

[sub_resource type="StyleBoxEmpty" id="StyleBoxEmpty_qw"]

[node name="QuestWindow" type="PanelContainer"]
custom_minimum_size = Vector2(320, 0)
size_flags_horizontal = 0
size_flags_vertical = 0
mouse_filter = 2
theme_override_styles/panel = SubResource("StyleBoxEmpty_qw")
script = ExtResource("1_qw")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 0

[node name="TitleBar" type="PanelContainer" parent="VBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_override_styles/panel = ExtResource("3_qtb")

[node name="HBoxContainer" type="HBoxContainer" parent="VBoxContainer/TitleBar"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 8

[node name="TitleLabel" type="Label" parent="VBoxContainer/TitleBar/HBoxContainer"]
layout_mode = 2
theme_type_variation = &"LabelHeading"
theme_override_font_sizes/font_size = 20
text = "Quests"

[node name="BadgeDot" type="ColorRect" parent="VBoxContainer/TitleBar/HBoxContainer"]
unique_name_in_owner = true
custom_minimum_size = Vector2(10, 10)
layout_mode = 2
size_flags_horizontal = 4
size_flags_vertical = 4
color = Color(0.95, 0.55, 0.2, 1)

[node name="Spacer" type="Control" parent="VBoxContainer/TitleBar/HBoxContainer"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2

[node name="CollapseButton" type="Button" parent="VBoxContainer/TitleBar/HBoxContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.6, 0.57, 0.5, 1)
theme_override_font_sizes/font_size = 16
text = "▼"
flat = true

[node name="ContentPanel" type="PanelContainer" parent="VBoxContainer"]
unique_name_in_owner = true
clip_contents = true
custom_minimum_size = Vector2(0, 200)
layout_mode = 2
theme_override_styles/panel = ExtResource("2_qwbg")

[node name="ScrollContainer" type="ScrollContainer" parent="VBoxContainer/ContentPanel"]
layout_mode = 2

[node name="EntriesContainer" type="VBoxContainer" parent="VBoxContainer/ContentPanel/ScrollContainer"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="EmptyLabel" type="Label" parent="VBoxContainer/ContentPanel/ScrollContainer/EntriesContainer"]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"LabelBodySmall"
text = "No active quests."
```

Label variant note:
- TitleLabel uses `LabelHeading` (36px gold) + `theme_override_font_sizes/font_size = 20` — this clones the LogWindow pattern exactly per `docs/UI_STYLING.md` rule #3 (close match with size override to preserve variant's color palette)
- EmptyLabel uses `LabelBodySmall` at its default 16px beige — no override needed
- CollapseButton keeps its color/size overrides because it's a `Button` (not a `Label`) — variants target label classes only

- [ ] **Step 3: Verify the project parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly.

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/quest_window/quest_window.gd scenes/ui/quest_window/quest_window.tscn
git commit -m "feat(quests-ui): scaffold QuestWindow panel scene"
```

---

## Task 4: Create QuestToast scene with fade+slide animation

Ephemeral top-center popup. Uses `Tween` for timing. Subscribes to all three quest signals and queues messages so rapid updates don't clobber. Add an `@export preview_message` so the scene can be launched solo (F6) to inspect the animation + styling.

**Files:**
- Create: `scenes/ui/quest_toast/quest_toast.gd`
- Create: `scenes/ui/quest_toast/quest_toast.tscn`

- [ ] **Step 1: Create the script**

```gdscript
class_name QuestToast
extends PanelContainer
## Single-line toast popup for quest updates. Anchored top-center. Plays a
## fade+slide animation on each message. Queues messages when busy so multiple
## rapid updates don't clobber each other. Independent of QuestWindow state.
##
## Preview: set `preview_message` to any string and launch this scene (F6) to
## see the animation play once. Preview mode skips QuestManager signal wiring.

#-----------------------------------------------------------------------------
# CONSTANTS
#-----------------------------------------------------------------------------

const FADE_IN_DURATION: float = 0.2
const HOLD_DURATION: float = 2.5
const FADE_OUT_DURATION: float = 0.4
const SLIDE_OFFSET_PX: float = 20.0

#-----------------------------------------------------------------------------
# EDITOR PREVIEW
#-----------------------------------------------------------------------------

## When non-empty, plays this message once on _ready and skips signal wiring.
@export var preview_message: String = ""

#-----------------------------------------------------------------------------
# NODE REFERENCES
#-----------------------------------------------------------------------------

@onready var _label: Label = %MessageLabel

#-----------------------------------------------------------------------------
# STATE
#-----------------------------------------------------------------------------

var _queue: Array[String] = []
var _is_playing: bool = false
var _base_position_y: float = 0.0

#-----------------------------------------------------------------------------
# LIFECYCLE
#-----------------------------------------------------------------------------

func _ready() -> void:
	modulate.a = 0.0
	_base_position_y = position.y

	if not preview_message.is_empty():
		show_message(preview_message)
		return

	if QuestManager:
		QuestManager.quest_started.connect(_on_quest_started)
		QuestManager.quest_step_advanced.connect(_on_quest_step_advanced)
		QuestManager.quest_completed.connect(_on_quest_completed)
	else:
		Log.critical("QuestToast: QuestManager not available on ready!")

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Queues a toast message. If no toast is currently playing, starts immediately.
func show_message(text: String) -> void:
	_queue.append(text)
	if not _is_playing:
		_play_next()

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

func _play_next() -> void:
	if _queue.is_empty():
		_is_playing = false
		return
	_is_playing = true
	var message: String = _queue.pop_front()
	_label.text = message
	modulate.a = 0.0
	position.y = _base_position_y - SLIDE_OFFSET_PX
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_property(self, "position:y", _base_position_y, FADE_IN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(HOLD_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(_play_next)

func _on_quest_started(quest_id: String) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id) if QuestManager else null
	var name: String = quest.quest_name if quest else quest_id
	show_message("Quest Started: %s" % name)

func _on_quest_step_advanced(quest_id: String, new_step_index: int) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id) if QuestManager else null
	if quest == null or new_step_index < 0 or new_step_index >= quest.steps.size():
		show_message("Quest Updated")
		return
	show_message("Quest Updated: %s" % quest.steps[new_step_index].description)

func _on_quest_completed(quest_id: String) -> void:
	var quest: QuestData = QuestManager.get_quest_data(quest_id) if QuestManager else null
	var name: String = quest.quest_name if quest else quest_id
	show_message("Quest Complete: %s" % name)
```

- [ ] **Step 2: Create the scene**

Write `scenes/ui/quest_toast/quest_toast.tscn`:

```
[gd_scene load_steps=3 format=3 uid="uid://b1quest1toast1"]

[ext_resource type="Script" path="res://scenes/ui/quest_toast/quest_toast.gd" id="1_qt"]
[ext_resource type="StyleBox" uid="uid://quest_toast_01" path="res://assets/styleboxes/ui/quest_toast.tres" id="2_qtbg"]

[node name="QuestToast" type="PanelContainer"]
custom_minimum_size = Vector2(400, 0)
size_flags_horizontal = 4
size_flags_vertical = 0
mouse_filter = 2
theme_override_styles/panel = ExtResource("2_qtbg")
script = ExtResource("1_qt")

[node name="MessageLabel" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 2
theme_type_variation = &"LabelBody"
horizontal_alignment = 1
text = ""
```

Label uses `LabelBody` (22px beige) with no size or color overrides. `theme_override_styles/panel` is a stylebox reference (not a label override), loaded from the `.tres` created in Task 2.

- [ ] **Step 3: Verify the project parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly.

- [ ] **Step 4: Commit**

```bash
git add scenes/ui/quest_toast/
git commit -m "feat(quests-ui): add QuestToast scene with fade+slide animation"
```

---

## Task 5: Mount QuestWindow + QuestToast in main_game.tscn

Both scenes need to be instanced as children of `MainView` so they're visible in every view state (zone, adventure, inventory, etc.) and persist across view switches.

**Files:**
- Modify: `scenes/main/main_game/main_game.tscn`

- [ ] **Step 1: Check current main_game.tscn structure**

Read the file to locate the `LogWindow` node (around line 225). Both new instances go near this spot.

- [ ] **Step 2: Add QuestWindow ext_resource and instance**

Use the Godot editor to open `scenes/main/main_game/main_game.tscn`, instance `QuestWindow` and `QuestToast` as children of `MainView`. Then save.

**If editing the `.tscn` directly (faster for an agent):**

Add two `ext_resource` lines near the other ext_resource block at the top of the file. Existing ids in the file already include `26_cvs` as the highest script-style id, so `27_qw` and `28_qt` are safe:

```
[ext_resource type="PackedScene" uid="uid://b1quest1win1" path="res://scenes/ui/quest_window/quest_window.tscn" id="27_qw"]
[ext_resource type="PackedScene" uid="uid://b1quest1toast1" path="res://scenes/ui/quest_toast/quest_toast.tscn" id="28_qt"]
```

Add `QuestWindow` node as a child of `MainView`, anchored left-center so it sits to the right of the `ZoneResourcePanel` area without overlapping (the zone resource panel lives at `offset_left = 28.0`, so QuestWindow sits around `offset_left = 240`):

```
[node name="QuestWindow" parent="MainView" instance=ExtResource("27_qw")]
unique_name_in_owner = true
z_index = 1
layout_mode = 1
anchors_preset = 4
anchor_top = 0.5
anchor_bottom = 0.5
offset_left = 240.0
offset_top = -120.0
offset_right = 560.0
offset_bottom = 120.0
grow_vertical = 2
```

Add `QuestToast` node as a child of `MainView`, anchored top-center:

```
[node name="QuestToast" parent="MainView" instance=ExtResource("28_qt")]
unique_name_in_owner = true
z_index = 10
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 40.0
offset_right = 200.0
offset_bottom = 100.0
grow_horizontal = 2
```

The `z_index = 10` on the toast ensures it draws above other overlay UIs (grey background, end card, etc.).

- [ ] **Step 3: Verify the project parses and the scene opens**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly with no errors about `main_game.tscn` or the new ext_resources.

- [ ] **Step 4: Run the full test suite**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: 297/297 pass.

- [ ] **Step 5: Commit**

```bash
git add scenes/main/main_game/main_game.tscn
git commit -m "feat(quests-ui): mount QuestWindow and QuestToast in main_game.tscn"
```

---

## Task 6: Author test_quest_resource and wire to the dirt eel dialogue

Create the first real quest as production content. It fires when the player first talks to the Wisened Dirt Eel and completes the same turn (since the same dialogue also triggers the event the quest's single step listens for). Good test: exercises start → toast → step-advance → complete → toast in a single interaction.

**Files:**
- Create: `resources/quests/test_quest_resource.tres`
- Create: `resources/effects/start_quest/start_test_quest_effect.tres`
- Modify: `resources/quests/quest_list.tres`
- Modify: `resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres`

- [ ] **Step 1: Create the quest resource**

Write `resources/quests/test_quest_resource.tres`:

```
[gd_resource type="Resource" script_class="QuestData" load_steps=3 format=3 uid="uid://test_quest_resource_01"]

[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_data.gd" id="1_qd"]
[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_step_data.gd" id="2_qsd"]

[sub_resource type="Resource" id="Step_meet_the_eel"]
script = ExtResource("2_qsd")
step_id = "meet_the_eel"
description = "Speak with the Wisened Dirt Eel"
completion_event_id = "initial_spirit_valley_dialogue_1"
completion_conditions = Array[Resource]([])

[resource]
script = ExtResource("1_qd")
quest_id = "test_quest"
quest_name = "A Curious Ripple"
description = "Something stirs in the Spirit Valley. The old eel may know more."
steps = Array[Resource]([SubResource("Step_meet_the_eel")])
completion_effects = Array[Resource]([])
```

The quest has a single step that completes on the `initial_spirit_valley_dialogue_1` event — the same event the existing dialogue action already fires.

- [ ] **Step 2: Create the StartQuestEffectData resource**

Write `resources/effects/start_quest/start_test_quest_effect.tres`:

```
[gd_resource type="Resource" script_class="StartQuestEffectData" load_steps=2 format=3 uid="uid://start_test_quest_effect_01"]

[ext_resource type="Script" path="res://scripts/resource_definitions/effects/start_quest_effect_data.gd" id="1_sqe"]

[resource]
script = ExtResource("1_sqe")
effect_type = 5
quest_id = "test_quest"
```

The `effect_type = 5` value corresponds to `EffectType.START_QUEST` added in Pass 1.

- [ ] **Step 3: Add the quest to the catalog**

Replace `resources/quests/quest_list.tres` with a version that references the new quest:

```
[gd_resource type="Resource" script_class="QuestList" load_steps=3 format=3 uid="uid://bquest1listzz"]

[ext_resource type="Script" path="res://scripts/resource_definitions/quests/quest_list.gd" id="1"]
[ext_resource type="Resource" uid="uid://test_quest_resource_01" path="res://resources/quests/test_quest_resource.tres" id="2_tq"]

[resource]
script = ExtResource("1")
quests = Array[Resource]([ExtResource("2_tq")])
```

- [ ] **Step 4: Wire the StartQuest effect into the dialogue action**

Edit `resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres`. Current file ends with:

```
success_effects = Array[ExtResource("1_nm6h2")]([ExtResource("2_ur7gj"), SubResource("Resource_8j4wv")])
```

Where `ExtResource("2_ur7gj")` is the `TriggerEventEffectData` and `SubResource("Resource_8j4wv")` is the award-dagger effect.

Add a new `ext_resource` line near the top of the file (after the last existing `ext_resource`):

```
[ext_resource type="Resource" uid="uid://start_test_quest_effect_01" path="res://resources/effects/start_quest/start_test_quest_effect.tres" id="6_sqe"]
```

Then prepend the new ext resource to the `success_effects` array:

```
success_effects = Array[ExtResource("1_nm6h2")]([ExtResource("6_sqe"), ExtResource("2_ur7gj"), SubResource("Resource_8j4wv")])
```

**Ordering matters.** With the StartQuest effect first:
1. `StartQuestEffectData.process()` → `QuestManager.start_quest("test_quest")` → `quest_started` fires → QuestToast shows "Quest Started: A Curious Ripple"
2. Retroactive auto-complete runs → event `initial_spirit_valley_dialogue_1` not yet triggered → quest stays at step 0
3. `TriggerEventEffectData.process()` → fires `initial_spirit_valley_dialogue_1` → QuestManager advances the step → quest completes → `quest_completed` fires → QuestToast shows "Quest Complete: A Curious Ripple"
4. `AwardItemEffectData.process()` → gives the dagger (unchanged behavior)

- [ ] **Step 5: Verify the project parses**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --import
```

Expected: exits cleanly with no errors about missing resources, wrong enum values, or malformed `.tres` files. If Godot complains about any of the UIDs (e.g., `uid://test_quest_resource_01` not found), open the relevant file in the Godot editor, save it, and let Godot regenerate UIDs.

- [ ] **Step 6: Run the full test suite**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: 297/297 pass. The Pass 1 load-time validation logs an error if the step has both event and conditions set — verify the step only has `completion_event_id` set (no conditions).

- [ ] **Step 7: Commit**

```bash
git add resources/quests/test_quest_resource.tres resources/effects/start_quest/start_test_quest_effect.tres resources/quests/quest_list.tres resources/zones/spirit_valley_zone/zone_actions/initial_spirit_valley_dialogue_1.tres
git commit -m "feat(quests): add test_quest_resource wired to dirt eel dialogue"
```

---

## Task 7: Preview scenes standalone (no runtime needed)

Before running the full game, spot-check each UI scene by launching it solo (F6 in editor). This catches layout, font, and sizing issues without needing to start a quest in-game.

**What to do (editor workflow, not scriptable):**

1. Open `scenes/ui/quest_window/quest_entry/quest_entry.tscn`
   - Select the root `QuestEntry` node
   - Drag `resources/quests/test_quest_resource.tres` into the `preview_quest` inspector field
   - Set `preview_state` to `ACTIVE`, `preview_step_index` to `0`
   - Press **F6**. Expected: row shows "A Curious Ripple" + "Speak with the Wisened Dirt Eel" at full opacity
   - Change `preview_state` to `COMPLETED`, re-launch. Expected: row is dimmed (self_modulate 0.55) and detail says "✓ Complete"

2. Open `scenes/ui/quest_window/quest_window.tscn`
   - Select the root `QuestWindow` node
   - Drag `test_quest_resource.tres` into `preview_active_quests` (one-element array)
   - Toggle `preview_start_expanded` to `true`
   - Press **F6**. Expected: panel opens expanded showing the quest entry
   - Try moving the quest from `preview_active_quests` to `preview_completed_quests` — expected: shows dimmed + "✓ Complete"
   - Try empty preview arrays → expected: panel shows "No active quests."

3. Open `scenes/ui/quest_toast/quest_toast.tscn`
   - Select the root `QuestToast` node
   - Set `preview_message` to `"Quest Complete: A Curious Ripple"`
   - Press **F6**. Expected: toast slides down + fades in at top center, holds, fades out

**If any preview reveals a layout bug** — wrong font variant, wrapping, sizing, spacing — fix inline in the relevant scene before moving on. Don't fix in-game; previews are faster iteration.

## Task 8: Manual full-game playtest

Now run the full game and walk the real quest flow. The `test_quest_resource` wired to the dirt eel dialogue should fire end-to-end.

- [ ] **Step 1: Launch the game**

```
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --path . scenes/main/main_game/main_game.tscn
```

- [ ] **Step 2: Start from a fresh save**

Options:
- Toggle `reset_save_data` on the `PersistenceManager` node in the editor inspector
- Or delete `user://save.tres` (Windows: `%APPDATA%\Godot\app_userdata\EndlessPath\save.tres`)

- [ ] **Step 3: Walk the flow**

1. Zone view loads. `QuestWindow` is visible on the left, collapsed, titled "Quests"
2. Click the title bar to expand → empty-state "No active quests." label shows
3. Collapse the panel
4. Click the "Talk to the Wisened Dirt Eel" action
5. Step through the dialogue to the end
6. Expected in rapid succession:
   - Toast: "Quest Started: A Curious Ripple" → fades out
   - Badge dot appears on `QuestWindow` title bar
   - Toast: "Quest Complete: A Curious Ripple" → fades out (the TriggerEventEffectData right after the StartQuestEffectData fires the event that completes the single-step quest)
7. Click the `QuestWindow` title bar to expand
8. Expected: badge dot clears; list shows "A Curious Ripple" dimmed with "✓ Complete"
9. Save + reload the game
10. Expected: completed quest persists in the list across save/load

- [ ] **Step 4: Document any issues**

Screenshot or note:
- Font sizing / wrapping issues
- Misalignment with existing zone UI
- Animation jank (toast timing, slide behavior)
- Badge visibility
- Button hover/click responsiveness

Fix inline if trivial; surface anything bigger in the task report.

- [ ] **Step 5: Commit any polish fixes**

```bash
git add <any-touched-files>
git commit -m "polish(quests-ui): <specific polish>"
```

If no fixes needed, skip this step.

---

## Pass 2 summary

On completion (8 tasks total):
- 6 new scene/script files: `QuestEntry`, `QuestWindow`, `QuestToast` (each with `.tscn` + `.gd`)
- 3 new stylebox `.tres` resources
- 1 new quest (`test_quest_resource.tres`) wired to the Wisened Dirt Eel dialogue — first real quest content in the project
- 1 new effect resource (`start_test_quest_effect.tres`)
- `main_game.tscn` gains two new instances mounted at MainView
- Each UI scene exposes `@export` preview values for standalone editor testing (F6)
- All labels use `theme_type_variation` exclusively; the single exception is `QuestWindow`'s title which clones the LogWindow `LabelHeading + 20px` override pattern
- End-to-end playtest validated (preview + full game)
- 297/297 tests still passing
- Quest system is fully usable by content authors: create a `QuestData` .tres, add it to `quest_list.tres`, reference it via `StartQuestEffectData` in any action's `success_effects`. UI + toasts + badge all work automatically.

## Task renumbering from the earlier draft

The original plan had 10 tasks with separate "scaffold" and "wire signals" passes for each UI scene. This revision folds signal wiring directly into the scaffold tasks and replaces the debug harness with a real quest. Current task list:

1. QuestEntry sub-scene (with preview exports)
2. Stylebox `.tres` resources
3. QuestWindow scaffold + signal wiring + preview exports
4. QuestToast scene + animation + signal wiring + preview exports
5. Mount both in `main_game.tscn`
6. Author `test_quest_resource` + wire to dirt eel dialogue
7. Preview scenes standalone (editor F6 spot-check)
8. Manual full-game playtest

## Known post-Pass-2 polish opportunities (not in scope)

- Badge dot could pulse with a tween instead of being static (ties into game's visual vocabulary)
- Toast queue could de-duplicate identical consecutive messages
- Pruning completed quests once the list gets long (spec explicitly defers this)
- Sound effects on quest start/complete (Pass 2 spec flagged Fit ⚠ on audio texture)
