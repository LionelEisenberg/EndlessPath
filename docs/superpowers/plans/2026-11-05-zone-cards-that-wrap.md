# Zone Cards That Wrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every zone card shows its whole title and detail: long text wraps and the card grows, so no card ends in "…" (stats rework chunk #87).

**Architecture:** `ZoneActionButton` stops being a fixed 72 / 96 drawer. Its face becomes a 9-slice with the carved socket as its own piece (the choice drawer's pieces, plus one new running 9-slice), its title wraps beside its NEW seal and tag through the shared `layout_title_row()`, and its detail lines live in one `DetailRow` (a `VBoxContainer` slot beside the right column) whose height the card reads to size itself: 72 px for one line, 18 px more per detail line, 20 more per title line. Presenters put every row they show into that slot, wrapped at the room the card gives them, and call `relayout()` after they change it. `TechniqueDrawer` takes the same faces and title row.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1, Python 3 + Pillow for the art generator.

**Spec:** issue #87 ("Make zone cards wrap their text and grow instead of trimming") and its approved mock-up answers (the issue's comment of 2026-11-05; canvas "Zone cards that wrap", https://claude.ai/artifact/GCqFC1NUNwgvp8g3yMDAVy). Rules: `docs/STYLE_GUIDE.md` rule 14 and §5 "Long text"; `docs/UI_STYLING.md` "Lacquer theme".

## Approved mock-up answers

1. A card grows on a 9-slice face with the socket as its own piece. Resting face `lacquer_drawer9_ai.png` (patch margins 4, 4, 6, 6, drawn 2 px wider and taller than the card for its shadow). Running face, new: `lacquer_drawer9_run_ai.png` (patch margins 16, 16, 20, 20, drawn 4 px wider and taller, the drawer pulled out to (−2, −2)). `lacquer_drawer_tall_ai.png` goes out of use.
2. The socket stays at (8, 12) and the icon at (16, 20): the top, beside the title's first line.
3. `TechniqueDrawer` takes the same two faces and the socket piece.
4. A card's NEW seal clears when the pointer leaves the card (or on a click), not when it arrives.
5. The right column, idle cards included, fits its text up to half the line (158 px) and wraps at 158 past that, right-aligned; the left part wraps in the room left.
6. Out of scope, confirmed: the log board, the zone chest's title, the map plates and popovers and the Abilities view stay on `KNOWN_TRIMMERS`.

Rules the canvas drew: a seal or tag stays beside the title's first line, the seal 10 px after the title's widest line; the detail row starts 4 px under the title's last line; the adventure's Madra row and the Tribulation's Core row are rows of the detail slot, so they ride the detail line and what stands under them grows the card downward; finds keep their icon and name together and move to the next line whole, lines of finds stepping 18 px; the activity list keeps its 8 / 14 px gaps and folds under a whole card.

## Global Constraints

- Godot 4.7.2, GDScript. Tests: `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run_tests.ps1`; one file: `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/<file>.gd -gexit`.
- Explicit return types and typed variables; public functions have a `##` doc comment and no leading `_`; node references use `%UniqueName`; `#----` section headers as in the neighbouring files.
- UI nodes live in `.tscn` scenes with theme variants; scripts set data, sizes and visibility. No `text_overrun_behavior`, `clip_text`, clipping container or `max_lines_visible` on any zone card label.
- Wrapping labels: `autowrap_mode = 3` and a width the card gives (`custom_minimum_size.x` and `size.x`, both). A 15/18 wrapping `Label` takes `assets/styleboxes/lacquer/wrap_pad.tres` as its `normal` style so n lines are 18 n. Heights round up to even px.
- New art ends in `_ai`. No living doc edits in the feature branch (they go in the PR's `## Docs to update`).
- Don't test how a screen looks: test heights the card reports, line counts, visibility, text and what each control does.

## Review Focus

1. A card that changes height while it stands in the list (the NEW seal clearing, the adventure crossing its threshold, the Tribulation's stat line appearing) must make the list re-measure its folds and the chest re-fit. Pinned in Task 4.
2. Hovering a card whose title wrapped only beside its seal must not shrink it under the pointer; leaving it does. Pinned in Task 2.
3. A right column past half the line on an idle card must wrap whole and leave the left part its own room. Pinned in Task 2.
4. A single find whose name is wider than the whole line must wrap inside its yield instead of running past the card. Pinned in Task 2.
5. The adventure's Madra row with a time hint too wide to sit beside the figure must put the hint on a line of its own, not over the rod. Pinned in Task 2.

---

### Task 1: The running face as a 9-slice

**Files:**
- Modify: `docs/superpowers/mockups/adventure-view-lacquer/gen/kit_chest9.py`
- Create: `docs/superpowers/mockups/adventure-view-lacquer/lacquer_drawer9_run_ai.png` (unshadowed), `assets/ui/lacquer/lacquer_drawer9_run_ai.png` and its `.import`

**Interfaces:**
- Produces: `res://assets/ui/lacquer/lacquer_drawer9_run_ai.png`, a clean 9-slice with patch margins (16, 16, 20, 20): the zone kit's running drawer without its socket, its brass caps in the corners and the 4 px shadow baked in.

- [ ] **Step 1: Add `draw_drawer9_run(run_drawer: Image) -> Image` to `kit_chest9.py`**, beside `draw_drawer9()`: corners of `RUN_CORNER = 16` px copied from `zone-view-lacquer/lacquer_drawer_run_ai.png` (392x72, unshadowed), one column or row of each edge repeated `KEEP` times, a flat middle; `audit_nine_slice()` with (16, 16, 16, 16) must pass. In `build()`, prove `compose_drawer`-style that the piece stretched to 392x72 with the socket put back at (8, 12) is the zone kit's running drawer pixel for pixel, and save it to the mock folder. In `import_all()`, bake `SHADOW_BIG` with `bake_shadow()` into `assets/ui/lacquer/` and audit the baked file with (16, 16, 20, 20).
- [ ] **Step 2: Run the generator**

Run: `python docs/superpowers/mockups/adventure-view-lacquer/gen/kit_chest9.py` from that `gen/` folder.
Expected: the drawer9 and rod lines as before, plus "drew lacquer_drawer9_run_ai.png … pixel for pixel" and "… a clean 9-slice, margins (16, 16, 20, 20)". `git status` shows only the new run piece (the other pieces redraw byte for byte).

- [ ] **Step 3: Import it** with `--headless --import` and check the new `.import` matches `lacquer_drawer9_ai.png.import`'s params (lossless, no mipmaps).
- [ ] **Step 4: Commit** the generator, the two PNGs and the `.import`: `feat(ui): add the running drawer as a 9-slice`.

### Task 2: The card and its presenters wrap and grow

**Files:**
- Modify: `scenes/zones/zone_action_button/zone_action_button.tscn`, `zone_action_button.gd`
- Modify: every presenter in `scenes/zones/zone_action_button/presenters/` (`.gd` and `.tscn`), `forage_yield.tscn`
- Modify: `scripts/ui/zone_action_presenter.gd` (class doc: the slots)
- Modify: `scenes/cycling/technique_drawer/technique_drawer.gd` (the `layout_title_row` call only)
- Test: `tests/integration/test_zone_action_cards.gd`, `tests/integration/test_tribulation_card.gd`, `tests/integration/test_boards_never_trim_text.gd` (`KNOWN_TRIMMERS` only)

**Interfaces:**
- Consumes: Task 1's `lacquer_drawer9_run_ai.png`.
- Produces, on `ZoneActionButton`:
  - constants `CARD_WIDTH = 392.0`, `MIN_HEIGHT = 72.0`, `TITLE_X = 64.0`, `TITLE_TOP = 14.0`, `TITLE_ROW_WIDTH = 232.0`, `SEAL_GAP = 10.0`, `TAG_X = 304.0`, `TAG_RAISE = 1.0`, `DETAIL_WIDTH = 316.0`, `DETAIL_GAP = 4.0`, `ROOM_UNDER_DETAIL = 16.0`, `DETAIL_RIGHT_MAX_WIDTH = 158.0`, `RUNNING_OFFSET = Vector2(-2, -2)`.
  - `get_detail_slot() -> VBoxContainer`: the left part of the detail row; presenters stack their rows in it.
  - `get_detail_room() -> float`: 316, or 316 less the right column and its 12 px gap.
  - `set_detail_right(text: String, color: Color = ThemeConstants.LACQUER_TAN) -> void`; `get_detail_right_text() -> String`.
  - `fit_detail_label(label: Label) -> void`: wraps the label at the room and relays out.
  - `set_detail_rich_text(rich: RichTextLabel, text: String, width: float = -1.0) -> void`: decimal points in Yatra (`LacquerText.decimal_bbcode`), wrapped at `width` (the room when negative); relays out.
  - `relayout() -> void`: title row, detail row, height, face. Emits `minimum_size_changed` through `custom_minimum_size` when the height changes.
  - `static func layout_title_row(title: Label, new_seal: Control, tag: Control) -> void` (the `wraps` parameter goes: both callers wrap).
  - `static func fit_face(face: NinePatchRect, running: bool, drawer_size: Vector2) -> void`.
  - Gone: `get_footer_slot()`, `set_tall()`, `fit_detail_rich_text()`, `ellipsize_words()`, `TALL_HEIGHT`, `SHORT_HEIGHT`, `DETAIL_WRAP_LINES`, `ELLIPSIS`, `TRAILING_JOINS`, the fixed drawer textures, `DetailClip`, `FooterSlot`.

- [ ] **Step 1: Rewrite the long-text tests in `test_zone_action_cards.gd`** (drop the three `ellipsize_words` tests, `TALL_HEIGHT`, `ELLIPSIS`):

```gdscript
## Every card is 72 px for one title line and one detail line, 18 px more for
## each detail line after the first and 20 more for each title line after the first.
func test_a_card_grows_by_its_lines() -> void:
	var cases: Array[Dictionary] = [
		{"name": "one line each", "title": "The Intervener", "description": "Your next story step", "height": 72.0},
		{"name": "two detail lines", "title": "The Intervener", "description": "word ".repeat(12).strip_edges(), "height": 90.0},
		{"name": "three detail lines", "title": "The Intervener", "description": "word ".repeat(22).strip_edges(), "height": 108.0},
		{"name": "two title lines", "title": "A title long enough to run past the tag twice over", "description": "Your next story step", "height": 92.0},
	]
	for case: Dictionary in cases:
		var card: ZoneActionButton = _card_for(_story_fixture(case.title, case.description))
		assert_eq(card.custom_minimum_size.y, case.height, "%s: the card's height" % case.name)
		assert_eq(card.size.y, case.height, "%s: and its size" % case.name)
```
(Pick fixture strings so each case lands on its line count; assert the label's `get_line_count()` first if a string is borderline.)

```gdscript
func test_the_first_talk_shows_its_whole_description() -> void:
	# The first card of a new game: its description takes three lines.
	var card: ZoneActionButton = _card(DIALOGUE_ID)
	var label := card.get_detail_slot().find_child("DetailLabel", true, false) as Label
	assert_eq(label.text, ZoneManager.get_action_by_id(DIALOGUE_ID).description)
	assert_eq(label.get_line_count(), 3)
	assert_eq(label.get_visible_line_count(), 3, "every line shows")
	assert_eq(card.size.y, 108.0)

func test_a_title_wraps_beside_its_seal_and_takes_its_room_back() -> void:
	# RETURN_ID = "celestial_intervener_dialogue_2", unseen on a fresh save: "Return to
	# the [INTERVENER]" fits one line beside the tag but not beside the seal.
	var card: ZoneActionButton = _card(RETURN_ID)
	var title := card.get_node("%Title") as Label
	assert_eq(title.get_line_count(), 2, "it wraps beside the seal")
	assert_eq(card.size.y, 110.0)
	card.mouse_entered.emit()
	assert_true(card.is_new_shown(), "the seal stays while the pointer is on the card")
	assert_eq(card.size.y, 110.0, "and the card keeps its height under the pointer")
	card.mouse_exited.emit()
	assert_false(card.is_new_shown(), "the pointer leaving clears it")
	assert_eq(title.get_line_count(), 1)
	assert_eq(card.size.y, 90.0, "the card is a line shorter")
```
Replace `test_new_seal_clears_on_hover` with `test_new_seal_clears_when_the_pointer_leaves` (hover alone keeps it; exit clears it and marks the action seen). Add:
- `test_an_idle_right_column_past_half_wraps_whole`: on the Aura Well card, `set_detail_right("+1 Spirit / level until Spirit Lv 10")`; `get_detail_right_text()` is the whole text, `%DetailRight`'s `get_line_count() == 2`, `get_detail_room() == 316 - 158 - 12`, card 90.
- `test_finds_flow_onto_a_second_line`: the shipped foraging card duplicated with `madra_cost_per_second = 2.0`: both find names show whole (`_texts` has "Dewdrop Tear" and "Spirit Fern"), they sit on two lines (the two yields' global y differ by 18), card 90.
- `test_a_find_too_long_for_the_line_wraps_inside_it` (Review Focus 4): a fixture loot table with one material named "word " × 40; its `YieldText` shows the whole name (`get_parsed_text()`), `get_line_count() > 1`, and its right edge is within the slot.
- `test_the_madra_hint_takes_its_own_line_when_it_does_not_fit` (Review Focus 5): a fixture adventure with a threshold making the figure "12345 / 23456" while the Aura Well runs; `%HintLabel` is visible, its y is 18 under `%MadraFigure`'s, and the card grew by 18.
- Keep every other test; `test_long_detail_wraps_in_tall_drawer` goes (covered by the table).

- [ ] **Step 2: Rewrite `test_tribulation_card.gd`'s layout tests**: `_need_row()` and `_core_rod()` look in `get_detail_slot()`. `SHORT_HEIGHT`/`TALL_HEIGHT` become `MIN_HEIGHT = 72.0` and `STAT_LINE_HEIGHT = 90.0`. Add `test_the_stat_line_grows_the_card_and_the_core_row_stays` (Strength a level short: card 90, `NeedGroup` is the slot's first visible row at y 0; capping Strength back: 72). Rework `test_a_long_ready_line_grows_the_card_and_it_shrinks_back` to assert the ready label and the right column show every line, the card is taller than 72, and 72 once not ready (no await needed: heights are synchronous).
- [ ] **Step 3: Take the card's six files off `KNOWN_TRIMMERS`** in `test_boards_never_trim_text.gd` (the card `.tscn`/`.gd` and the adventure, cycling, default and merchant presenter scenes).
- [ ] **Step 4: Run the three files; expect failures** (the card still ellipsizes and is 72 / 96).
- [ ] **Step 5: Rebuild the card scene.** `Drawer` holds: `Face` (`NinePatchRect`, `lacquer_drawer9_ai.png`, patch 4/4/6/6, 394x74), `Socket` (`TextureRect`, `lacquer_socket_drawer_ai.png` at (8, 12)), `Icon` (16, 20), `Title` (`LabelLacquerName`, `autowrap_mode = 3`, no overrun), `NewSeal`, `Tag`, `DetailRow` (`HBoxContainer` at (64, 38), 316 wide, separation 12) holding `DetailSlot` (`VBoxContainer`, expand, separation 0) and `DetailRight` (`RichTextLacquer`, fit content, `horizontal_alignment = 2`, top-aligned), then `ReadyFrame`, `HoverFrame`, `FlashFrame`. `DetailClip` and `FooterSlot` go.
- [ ] **Step 6: Rewrite `zone_action_button.gd`** to the interface above. `relayout()`: `layout_title_row()`, `DetailRow` at `TITLE_X`, title bottom + `DETAIL_GAP`; height = max(`MIN_HEIGHT`, even(row top + row's combined minimum height + `ROOM_UNDER_DETAIL`)); card, drawer and face follow (`fit_face(_face, _is_running, size)`); `_drawer.position = RUNNING_OFFSET` while running. `set_detail_right()`: measure the text with autowrap off (`get_content_width()`); at or under 158 the column is that width rounded up to even, past it the column wraps at 158; set `custom_minimum_size.x` and `size.x`. `_refresh_new_seal()` ends in `relayout()`. Hover shows the frame only; `mouse_exited` hides it and marks the action seen; a click marks it seen at once (as today). Connect `DetailRow.minimum_size_changed` to `relayout` as a safety net for changes a presenter does not report.
- [ ] **Step 7: Rework the presenters** (each `.tscn` loses `text_overrun_behavior`; wrapping 15/18 `Label`s take `wrap_pad.tres`):
  - default, cycling, merchant: unchanged logic; `fit_detail_label()` now wraps.
  - training: `set_detail_right(parts[1])` then `set_detail_rich_text(_detail_text, parts[0])`.
  - foraging: `set_detail_right()` for a cost, then lay the yields out in lines inside the room: a `VBoxContainer` (`YieldLines`) of `HBoxContainer` lines (separation 12); a yield starts a new line when it would pass the room; a yield wider than the room alone wraps its name at the room less its icon. `forage_yield.tscn`: an `IconBox` `Control` (16x18) holding `Icon` (16x16 at (0, 2)) so a line is 18 px.
  - adventure: `NeedGroup` becomes a row `Control` in the slot (`custom_minimum_size` (316, 18), or (316, 36) when the hint takes its own line) holding a `Pieces` `Control` that the shake moves: `MadraIcon` (0, 0), `MadraRod` (22, 2), `MadraFigure` (184, 0), `HintLabel` right-aligned to x 316 on line 1, or on line 2 when figure + 8 + hint passes 132 px. `ReadyText` goes in the slot through `set_detail_rich_text()`. `_update_state()` ends in `button.relayout()`; keep its other lines as they are (#86 edits the capacity read beside it).
  - tribulation: `NeedGroup` the same way: `Pieces` with `CoreRod` (0, 2), `CoreFigure` (162, 0) and `StatNeedLabel` at (0, 18), 316 wide, wrapping; the row's minimum height is 18 plus the stat line's height while it shows. `ReadyLabel` through `fit_detail_label()`. `set_tall()` calls go; `_update_state()` ends in `button.relayout()`.
  - `ZoneActionPresenter`'s class doc names the one slot (`get_detail_slot()`, a `VBoxContainer` of rows at the detail line) and `relayout()`.
- [ ] **Step 8: `TechniqueDrawer._layout_text()`** calls `ZoneActionButton.layout_title_row(_title, _new_seal, _tag)`.
- [ ] **Step 9: Run the three test files, then the whole suite.** Expected: all pass.
- [ ] **Step 10: Commit**: `feat(zones): make zone cards wrap their text and grow`.

### Task 3: Technique drawers on the cards' faces

**Files:**
- Modify: `scenes/cycling/technique_drawer/technique_drawer.tscn`, `technique_drawer.gd`
- Test: `tests/integration/test_technique_drawer.gd`

**Interfaces:**
- Consumes: `ZoneActionButton.fit_face(face, running, drawer_size)`.

- [ ] **Step 1: Write `test_a_drawer_in_use_grows_on_the_running_face`**: an equipped fixture technique whose detail wraps (a long `technique_name` with the IN USE tag, so two title lines): `drawer.size.y == 92`, and `drawer.custom_minimum_size == drawer.size` (the list reads it). Run it: it passes on height already, so also assert `(drawer.get_node("%Face") as NinePatchRect).patch_margin_bottom == 20` (the face is the running 9-slice, which fails today: it is 14).
- [ ] **Step 2: Rework the drawer**: the scene's `Face` takes `lacquer_drawer9_ai.png` with patch 4/4/6/6 and a `Socket` `TextureRect` at (8, 12) joins it; the script drops `FACE_STRETCH_ROW(S)`, the drawer textures and `_fit_face()`'s band stretch, and calls `ZoneActionButton.fit_face(_face, is_in_use(), custom_minimum_size)` from `_layout_text()`; `refresh()` stops setting the face texture.
- [ ] **Step 3: Run `test_technique_drawer.gd` and `test_zone_panel.gd`.** Expected: pass.
- [ ] **Step 4: Commit**: `fix(cycling): grow the IN USE drawer without stretching its caps`.

### Task 4: The list, and the never-trim test's boards

**Files:**
- Modify: `scenes/zones/zone_panel/activity_list/activity_list.gd` (docs of `layout_changed` and the flow: cards of any height)
- Test: `tests/integration/test_zone_panel.gd`, `tests/integration/test_boards_never_trim_text.gd`

- [ ] **Step 1: Write `test_the_list_refolds_when_a_card_grows`** in `test_zone_panel.gd` (Review Focus 1): Spirit Valley with the Tribulation's card unlocked and Strength and Spirit capped, About open so the list scrolls; read `get_fold_heights()`; set Strength a level short; after a frame the Tribulation card is 90, every fold under it moved down 18, and the list's height is still one of the folds.
- [ ] **Step 2: Add the card to the never-trim walk**: `BOARD_SCENES` gains `zone_action_button.tscn`, the adventure, cycling, default, merchant and tribulation presenter scenes and `technique_drawer.tscn`; the wrapping table gains the card's `Title`, the default, cycling and merchant `DetailLabel`, the Tribulation's `StatNeedLabel` and `ReadyLabel`, and the drawer's `Title` and `Detail`.
- [ ] **Step 3: Update `ActivityList`'s doc comments** where they name the short and tall drawers.
- [ ] **Step 4: Run both files, then the suite.** Expected: all pass.
- [ ] **Step 5: Commit**: `test(zones): walk the zone cards for trimmed text`.

### Task 5: Checks in the game

- [ ] Run each check on presets with `-- --preset=<id> --save=user://dev/runs/zone-cards-87.tres`: `fresh` (the first card's whole description; play the talk, fill the core, the Return card's NEW seal and whole title), `merchant_open` (every card whole, the Aura Well's rate and reward, the finds; start the Aura Well: RUNNING on the running face), `tribulation_ready` (ready line whole; Strength back a level: the card grows, the Core row stays; open About: the list scrolls and folds under a whole card), the cycling board (the drawers' titles, seals and tags sit where the cards' do). Screenshot each for the PR.
- [ ] An old save (a copy of the main checkout's `user://save.tres`) loads and plays: the change saves nothing new.
