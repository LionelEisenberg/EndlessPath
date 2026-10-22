# Menu Books Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Inventory, Abilities, Character and Path menus into four books built from one shared book scene, each with its own colour, title ribbon and bookmark.

**Architecture:** A `BookFrame` scene owns the book art, its open/close/page-turn animations, the close tab and the bookmark, recoloured per book by a palette-swap shader fed from a `BookStyleData` resource. Each menu view extends `MenuBookView` and composes a `BookFrame` with its own page content (book-unit widgets at 2x, screen-pixel pages at 1x styled by `book_theme.tres`). The four menu states extend `BookViewState`, which opens and closes through `GreyBackground`; the backdrop now waits for a book's own close animation.

**Tech Stack:** Godot 4.6, GDScript, GUT 9.6.

**Spec:** `docs/superpowers/specs/2026-10-21-menu-books-design.md`

**Execution:** native, in this session, at the user's request ("write up the design then implement").

## Global Constraints

- Godot 4.6 (`C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe`); `main` is on 4.7 and must be merged in before this lands.
- Conventions from `CLAUDE.md`: UI nodes in `.tscn`, scripts set data; `%UniqueName`; typed variables and return types; `##` docs on public functions; `Log`, never `print`; no edits under `addons/`.
- Book art pixels are book units (one art pixel = 2 screen pixels). Book frame 700x450; left page inner area x 82..336, y 56..400; right page x 364..618; title ribbon at (95, 42), 196x66.
- Page text uses the dark-ink variants in `assets/themes/book_theme.tres` (`LabelBookTitle` 28, `LabelBookBody` 20, `LabelBookValue` 20, `LabelBookMuted` 16, `LabelBookPill` 18, `LabelBookPositive` 18, `LabelBookKey` 14, `LabelBookPlaque` 20) and panels `PanelBookCard`, `PanelBookRow`, `PanelBookRowSelected`, `PanelBookSlot`, `PanelBookPill`.
- Commits only with the user's approval (`CLAUDE.md`). Commit steps below mean "group these files for one commit".
- Run tests: `"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit`. After adding a `class_name`, run `--headless --import` first.

## Review Focus

- Esc pressed twice, or the close tab clicked while the book is still opening: the book closes once and the state pops once. Test in Task 3.
- A click near the right page's top-right corner must not close the book: the close tab's clickable area ends above the page. Test in Task 2.
- Books opened one after another keep their own colours (no shared material or atlas region). Test in Task 2.
- Right-clicking an unequipped ability with a full loadout changes nothing. Test in Task 5.
- The player's stage changing between openings (a future breakthrough) unlocks the matching chapter tab the next time the book opens. Test in Task 6.

---

### Task 1: Book art, style data and palette shader — DONE

**Files:**
- Create: `assets/sprites/ui/book/` (`book_bookmark.png`, `book_close_tab.png`, `book_close_tab_hover.png`, `stage_{foundation,copper,iron,jade}.png`, `stage_lock.png`, `book_{card,row,pill,plaque,slot}_2x.png`)
- Create: `assets/shaders/palette_swap.gdshader`, `assets/themes/book_theme.tres`
- Create: `scripts/resource_definitions/ui/book_style_data.gd`, `resources/ui/book_styles/{inventory,abilities,character,path}_book_style.tres`
- Test: `tests/unit/test_book_style_data.gd`

**Interfaces:**
- Produces: `BookStyleData` with `cover_light/mid/dark`, `page_border`, `bookmark_dark/mid/light: Color`; `get_book_colors() -> PackedColorArray` (cover light, mid, dark, border); `get_bookmark_colors() -> PackedColorArray` (dark, mid, light). Shader uniforms `source_colors[8]`, `target_colors[8]`, `color_count`.

- [x] Art generated at the book's logical resolution, 2x nearest; close tab cropped to its 46 visible rows.
- [x] Tests: defaults equal the master art; getters keep source order; every book recolours its border; borders differ.

### Task 2: BookFrame shared scene — DONE

**Files:**
- Create: `scenes/ui/book_frame/book_frame.tscn`, `scenes/ui/book_frame/book_frame.gd`
- Test: `tests/integration/test_book_frame.gd`

**Interfaces:**
- Consumes: `BookStyleData` (Task 1).
- Produces: `BookFrame` (`class_name`), signals `opened`, `closed`, `close_requested`, `page_turned`; `animate_open()`, `animate_close()`, `turn_page(forward: bool)`, `is_moving() -> bool`, `is_chrome_visible() -> bool`; `@export var style: BookStyleData`; constants `BOOK_SOURCE_COLORS`, `BOOKMARK_SOURCE_COLORS`.

- [x] Atlas textures and shader materials are `resource_local_to_scene`; book art, turning page and bookmark all take the palette.
- [x] Tests: open/close signals and chrome visibility; close during open turns around; page turn both ways; close tab emits `close_requested`; style reaches book, turning page and bookmark shaders; two frames keep separate palettes.
- [x] **Add:** `test_close_tab_stays_above_the_page` — the CloseTab's rect bottom is at most y 34 in frame units (the page's top edge is solid from y 32).

### Task 3: Book views, shared state, backdrop wait, inventory on the shell — DONE

**Files:**
- Create: `scenes/ui/book_frame/menu_book_view.gd`, `scenes/ui/main_view/states/book_view_state.gd`
- Modify: `scenes/ui/grey_background/grey_background.gd`, `scenes/ui/main_view/states/inventory_view_state.gd`, `scenes/abilities/abilities_view_state.gd`, `scenes/character/character_view_state.gd`, `scenes/path_progression/path_tree_view_state.gd`, `scenes/inventory/inventory_view/inventory_view.{gd,tscn}`
- Test: `tests/unit/test_grey_background.gd`, `tests/unit/test_book_view_state.gd`

**Interfaces:**
- Produces: `MenuBookView` (`class_name`, extends `Control`): signals `close_requested`, `close_finished`; `@export var page_content: Array[Control]`; `book_frame: BookFrame` from `%BookFrame`; `animate_open()`, `animate_close()`; hooks `_before_open()`, `_before_close()`, `_after_close()`. Subclasses call `super._ready()`.
- Produces: `BookViewState` (`class_name`, extends `MainViewState`): hooks `_get_view() -> MenuBookView`, `_is_close_event(event: InputEvent) -> bool`; `_request_close()`.
- Produces: `GreyBackground.hide_with_panel(panel)` waits for a panel's `close_finished` signal when it has one.

- [x] Inventory moved onto `BookFrame` (page content `[BookContent]`), trash flush in `_after_close()`; `BookContent` and `TabSwitcher` ignore the mouse so the close tab is clickable.
- [x] **Write `tests/unit/test_grey_background.gd`:** build a `GreyBackground` with a `GreyBackgroundAnimationPlayer` child (owner set, unique name) holding 0.05 s `grey_fade_in`/`grey_fade_out` animations. `test_hide_waits_for_the_panels_close` (fake panel with `close_finished`: no `panel_hidden` after the fade, `panel_hidden` once the panel emits); `test_hide_without_close_signal_ends_with_the_fade`.
- [x] **Write `tests/unit/test_book_view_state.gd`** with the `FakeGreyBackground` pattern from `test_merchant_view_state.gd` and a real `character_view.tscn`: `test_close_tab_pops_the_state`, `test_escape_pops_the_state`, `test_second_close_request_pops_once`, `test_exit_disconnects_the_close_tab`.
- [x] Run the suite; expect all green.

### Task 4: Character book — DONE

**Files:**
- Modify: `scenes/character/character_view.{gd,tscn}`, `scenes/character/attribute_row/attribute_row.{gd,tscn}`
- Delete: `scenes/character/attribute_tooltip/`
- Test: `tests/integration/test_character_book.gd`

**Interfaces:**
- Produces: `CharacterView.select_attribute(attr_type)`, `get_selected_attribute()`, `refresh()`; `ATTRIBUTE_DETAILS` (description, effects per attribute); `AttributeRow.hovered(row)`, `set_selected(bool)`, `is_selected()`.

- [x] **Write tests:** `test_opening_shows_strength`; `test_hovering_a_row_describes_it` (emit `BodyRow.hovered` → plaque "Body", description and effects from `ATTRIBUTE_DETAILS`, Body row selected, Strength not); `test_values_come_from_character_manager`.

### Task 5: Abilities book — DONE

**Files:**
- Create: `scenes/abilities/ability_row/ability_row.{tscn,gd}` (`AbilityRow`, extends `PanelContainer`)
- Modify: `scenes/abilities/abilities_view.{gd,tscn}`, `scenes/abilities/equip_slot/equip_slot.{gd,tscn}` (slot art, dark key chip)
- Delete if unreferenced afterwards: `scenes/abilities/ability_card/`
- Test: `tests/integration/test_abilities_book.gd`

**Interfaces:**
- Consumes: `MenuBookView`, `BookFrame`, `SortSubBanner` (`set_options(PackedStringArray)`, `option_changed(index)`, `current_index`), `AbilityManager` (`get_unlocked_abilities`, `is_ability_equipped`, `equip_ability`, `unequip_ability`, `equip_ability_at_slot`, `swap_slots`, `get_ability_at_slot`, `get_filled_slot_count`, `get_max_slots`).
- Produces: `AbilityRow` signals `hovered(row: AbilityRow)`, `quick_equip_requested(ability_id: String)`; `setup(ability: AbilityData, slot_index: int)` (slot index -1 when unequipped); `get_ability_data() -> AbilityData`; `set_selected(bool)`; drag data `{"ability_id": String}`. `AbilitiesView.FILTER_OPTIONS = ["All", "Offensive", "Buff", "Equipped"]`, `SORT_OPTIONS = ["By loadout", "By name", "By Madra", "By cooldown"]` (By loadout = equipped in slot order, then by name), `select_ability(ability_id: String)`, `get_selected_ability_id() -> String`.

Layout (spec, Abilities): title ribbon "Abilities"; filter selector at the inventory's spot (63, 82) in book units; rows in a `ScrollContainer` on the left page; sort selector at the bottom of the left page; right page plaque "Loadout", loadout card (four slots Q/W/E/R, "N / 4 equipped"), details card (icon, name, Madra-type and source badges, tags, `AbilityStatsDisplay` damage and timing, description, equipped state, hint "Right-click to equip · drag to a slot").

- [x] **Write tests first:** `test_filter_options_match_spec`, `test_sort_options_match_spec`; `test_right_click_equips_into_first_free_slot`; `test_right_click_unequips`; `test_right_click_with_full_loadout_changes_nothing`; `test_hover_selects_and_describes`; `test_opening_selects_the_first_row`; `test_rows_live_in_a_scroll_container`.
- [x] Run; expect failures (no `AbilityRow`).
- [x] Implement `AbilityRow` (row bar, icon slot, name `LabelBookBody`, cost line `LabelBookMuted`, key chip `LabelBookKey`); right-click emits `quick_equip_requested`; `_get_drag_data` returns `{"ability_id": ...}` with the existing drag preview.
- [x] Rebuild `abilities_view.tscn` on the shell (`page_content` = BookContent + PageLayer, theme `book_theme.tres`, style `abilities_book_style.tres`); `AbilitiesView` extends `MenuBookView`; keep its filter/sort logic, replace cards with rows, add details; `_before_open()` refreshes and selects the first row.
- [x] Restyle `AbilityEquipSlot` to `PanelBookSlot` plus key chip; keep its drop/drag code.
- [x] Run suite; capture the book; compare with the mockup.

### Task 6: Path book with stage chapters — DONE

**Files:**
- Modify: `scenes/path_progression/path_tree_view.{gd,tscn}`, `scenes/path_progression/benefit_card.{gd,tscn}` (row bar), `scenes/inventory/inventory_view/tab_switcher/tab_switcher.gd` (collect child tab buttons, skip locked), `scenes/inventory/inventory_view/tab_switcher/tab_button.{gd,tscn}` (locked state)
- Create: `scenes/path_progression/path_node_details.{gd,tscn}` (`PathNodeDetails`, the right-page card; takes over `PathNodeTooltip`'s text formatting)
- Delete if unreferenced afterwards: `scenes/path_progression/path_node_tooltip.{gd,tscn}`
- Modify: `scenes/path_progression/path_tree_view_state.gd` (remove the TEMP cast)
- Test: `tests/integration/test_path_book.gd`, `tests/integration/test_tab_switcher.gd`

**Interfaces:**
- Consumes: `MenuBookView`, `PathManager` (`get_current_tree`, `get_node_purchase_count`, `can_purchase_node`, `purchase_node`, `get_point_balance`, signals `node_purchased`, `points_changed`, `path_set`), `CultivationManager.get_current_advancement_stage()`, `CultivationManager.AdvancementStage`.
- Produces: `PathTreeView.STAGES: Array[CultivationManager.AdvancementStage]` = FOUNDATION, COPPER, IRON, JADE; `@export var stage_layouts: Array[PackedScene]` (index = position in `STAGES`; only Foundation's set); `is_stage_unlocked(stage) -> bool`; `get_open_stage()`; `open_stage(stage)`; `show_node_details(node_data: PathNodeData)`; `show_path_info()`. `TabButton.locked: bool`, `locked_tooltip: String`. `TabSwitcher` emits `tab_changed(index)` only for unlocked tabs and exposes `select_tab(index)`.

- [x] **Write tests first:** `test_only_reached_stages_unlock` (stage FOUNDATION → only tab 0 unlocked); `test_locked_tab_does_not_switch`; `test_open_stage_shows_only_its_nodes`; `test_hover_shows_node_details`; `test_opening_shows_path_info`; `test_benefits_list_every_purchased_node`; `test_tabs_relock_on_open` (Review Focus: override stage, reopen, tab unlocks); tab switcher: `test_locked_button_ignores_press`.
- [x] Implement tab locking (padlock icon `stage_lock.png`, tooltip "Reach <Stage> to open this chapter"), generalise `TabSwitcher` to its children (inventory unchanged).
- [x] Rebuild `path_tree_view.tscn` on the shell: side tabs with stage icons; left page plaque (path name, hover = path info) and tree card with pan/zoom; right page plaque + `PathNodeDetails`, "Active Benefits" plaque, scrolling benefit rows, points pill ("N points to spend · M spent").
- [x] Fit the Foundation tree in its card (default zoom and centre from the layout's bounds).
- [x] Run suite; capture the book; compare with the mockup.

### Task 7: Docs, full verification — DONE

**Files:**
- Modify: `docs/infrastructure/MAIN_VIEW.md`, `docs/inventory/INVENTORY.md`, `docs/infrastructure/CHARACTER.md`, `docs/abilities/ABILITIES.md`, `docs/progression/PATH_PROGRESSION.md`, `docs/UI_STYLING.md`, `docs/testing/TESTING.md`, this plan and the spec's status.

- [x] Full suite green; capture all four books open, mid-hover and closed; check each against `.superpowers/brainstorm/1209-1792555484/content/four-books-v2.html` and `path-close-ribbon.html`.
- [x] Docs describe what exists: the shell, the states, `GreyBackground`'s wait, the book theme, each book's pages and gestures, stage chapters; remove the fixed "two transition styles" issue for the four menus.

## Outcome (2026-10-21)

- Full suite: 76 scripts, 686 tests, all passing (618 before this work); orphans unchanged at 24.
- In-game screenshots of all four books open, mid-hover and closed matched the mockups. Changes found while capturing: the title ribbon and filter selector moved to the inventory's real positions (115, 62) and (131, 126); sort options reworded as orders; the path tree got a dark inset (`PanelBookInset`) because its node art was drawn for a dark panel.
- `main` moved to Godot 4.7 meanwhile; merging it needed the repository's pinned origin confirmed in the app (Help → Troubleshooting → Review Pinned Git Origins), because it touches `.claude/agents/`. Merged on 2026-10-21 (see the end of this plan).

## Review round (2026-10-21)

The user's first review is recorded in the spec's [First review](../specs/2026-10-21-menu-books-design.md#first-review-2026-10-21) section. What changed in code:

- `BookFrame`: regenerated `book_bookmark.png` (16 × 34) and `book_close_tab.png` (37 × 24, no X); deleted `book_close_tab_hover.png`. The close tab moved to (578, 10)-(615, 34) and lost its hover and pressed art, tooltip and hand cursor. The X is a `CloseGlyph` label (`LabelBookTitle` at 0.5 scale, nudged 4 book px down to centre in the visible tab).
- `pixel_theme.tres`: `LabelInventorySort` 38 → 30 px.
- `CombatEffectData.get_scaling(attribute)`: a lookup of the eight `*_scaling` fields, used by the Abilities details and the Character effects (`tests/unit/test_combat_effect_data.gd`).
- Abilities: no `SortSelector` or `SortMode`; `_order_by_loadout()`; `select_ability()` returns early on the described ability; `_damage_previews` is cleared on open and on `base_attribute_changed`; the details card's `AbilityStatsDisplay` pills were replaced by `StatList`; `AbilityRow.format_number()` (now public), `format_seconds()` and `format_cost()`; `AbilityEquipSlot` is 96 px with a 72 px icon.
- Character: `AttributeRow` became `AttributeTile` (`git mv`, same uids) in 4-column `GridContainer`s; new theme variants `PanelBookTile`, `PanelBookTileSelected` and `LabelBookValueLarge`; `ATTRIBUTE_DETAILS` holds `formulas`, and `_describe_effects()` adds unlocked-ability scaling lines; `NO_EFFECTS_TEXT`.
- Path: `PathNodeUI`'s `LevelLabel` is bottom-centre anchored under the node (22 px, outlined); `BenefitCard` is one 30 px line (`PanelBookRowCompact`, `LabelBookBodySmall`, ellipsis, tooltip); `BenefitsArea` hides its scrollbar and lost `get_points_spent()`; `PointsBadge` replaced `PointsPill`.
- Full suite: 77 scripts, 707 tests, all passing; orphans unchanged at 24. Re-captured all four books in-game, and added a test that the Abilities details card fits its page with Power Font's description (the old spacing overflowed it by 17 px).

## Second review round (2026-10-21)

Recorded in the spec's [Second review](../specs/2026-10-21-menu-books-design.md#second-review-2026-10-21) section. What changed in code:

- `SortSubBanner`'s label moved down 1 unit (2 screen px); the `LabelBookPlaque` stylebox's content margins went from 8/10 to 11/7 (top/bottom). Measured on captures: both within 1 px of centre.
- `control_icon.png`: art shifted 6 px left to centre it in the 64 px canvas (a 2 px multiple, so the 2×2 pixel blocks stay aligned).
- `BookFrame`: the bookmark lives in a `BookmarkClip` at (575, 420)-(591, 454); `_set_chrome_visible(true)` slides it from `-size.y` to 0 over `BOOKMARK_SLIDE_SECONDS` (0.45 s, quad ease out), and the tween is killed whenever the chrome hides.
- `CombatEffectData.get_scaling_contribution(attribute, caster_attributes)`, with a test that base plus contributions equals `calculate_value()`.
- Abilities: `AbilityKind` and `_KIND_ICONS`; a `PrimaryStat` row and an `ExplainRow` with three `ScalingPart` instances (new `scenes/abilities/scaling_part/`); `_value_previews` (was `_damage_previews`) covers heals too; `DetailStatus`, `DetailHint` and `_describe_status()` are gone; the description has a fixed four-line area. New art: `assets/sprites/ui/book/type_buff.png` and `type_debuff.png`.
- Character: `EffectsPlaque` and `EffectsCard` are gone; `EffectsSep`, `EffectsCaption` and `EffectsLabel` now sit in `DetailCard`, which fills the page; the description has a fixed three-line area.
- Path: the `DetailsCard` instance is 300 px tall, and `PathDetailsCard` has a `FooterSpacer` before `DetailFooter`. `BenefitsArea` writes marked lines into `%BenefitsLabel` (or shows `%BenefitsEmpty`) inside a `BenefitsCard`. `BenefitCard` (`.tscn`, `.gd`, `.uid`) was deleted, along with the node-frame icon exports and the now-unused `LabelBookBodySmall` and `PanelBookRowCompact` theme variants.
- Layout tests: the Abilities details sections, the Character effects and the Path benefits plaque each keep their position while pointing at every ability, attribute or node.
- Full suite: 77 scripts, 721 tests, all passing; orphans unchanged at 24. Captured all four books, the Enforce card, and seven frames of the bookmark slide.

### Backdrop click (after the second review)

- `GreyBackground.clicked`: a left press on the backdrop itself. `BookViewState` connects it to `_request_close()` in `enter()` and disconnects it in `exit()`, like the close tab, so the merchant (which shows the same backdrop) is unaffected.
- `BookFrame` gains a `BookHitArea` at (48, 24)-(652, 432), the open book's measured art bounds, and `BookmarkClip` now stops the mouse too, so clicks on the book never reach the backdrop.
- Tests: `test_grey_background.gd` (left press only), `test_book_view_state.gd` (backdrop click pops the state; not after exit), `test_book_frame.gd` (hit area and bookmark catch clicks). Checked in the real main scene with synthetic mouse input: the grey area and the frame's transparent margin close the book; the spine and the bookmark leave it open.

## Merge with main (2026-10-21)

- `origin/main` (Godot 4.7.2, GUT 9.7.1, the Dialogic 4.7 patch, and PR #48's AI-Generated Art rule) was merged after the user confirmed the pinned origin. The work stays uncommitted on top of `main`: it was set aside in a temporary commit for the app's sync and the branch was then reset to `origin/main`.
- AI-Generated Art rule: the 14 generated images in `assets/sprites/ui/book/` gained an `_ai` suffix (each `.import` keeps its uid, with its paths and hash moved to the new name), and every scene, theme, script and test now points at the new names. The re-centred Control icon moved from an in-place edit of `control_icon.png` (restored) to a new `control_icon_ai.png`, used by the Character tile and the Abilities breakdown. The generator script writes the `_ai` names.
- On Godot 4.7.2: headless import clean and `project.godot` unchanged (Dialogic registry intact); full suite 77 scripts, 727 tests, all passing; all four books captured; backdrop-click check passes.
