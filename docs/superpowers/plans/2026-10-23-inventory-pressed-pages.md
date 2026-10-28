# Inventory Pressed Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the content of the inventory book's four tabs (Equipment, Consumables, Materials, Journal) in the "pressed paper" page language, laid out at screen resolution, which also fixes the double-size text on Materials and the Journal.

**Architecture:**
- **Book and pages.** `InventoryView` splits the way the other three books already do. A `BookLayer` at 2x holds the frame and side tabs; a `PageLayer` at 1x holds the four tab pages.
- **Art.** A Python generator draws the pressed pieces as `_ai` textures.
- **Theme.** `book_theme.tres` gains additive variants and styleboxes for those pieces.
- **Tabs.** Each tab keeps the public behaviour and node names its tests rely on (drag, equip, discard, hotbar, filter), and its scene is rebuilt from pressed slots, panels, rules, tags, seals and printer's marks.
- **Rules as code.** Text and data rules live in small, unit-tested pieces: `BookText`, `MaterialSources`, `QuestManager.get_quest_id_for_item()`, `QuestStepData.get_progress_text()`.

**Tech Stack:** Godot 4.7.2, GDScript, GUT 9.7.1; Python 3 with Pillow for the art generator.

**Spec:** `docs/superpowers/specs/2026-10-23-inventory-pressed-pages-design.md`. The mockup is `docs/superpowers/mockups/inventory-pressed-mockup.html` (final images in `docs/superpowers/mockups/inventory-pressed/pressed_*_ai.png`). Read both before any task: the spec holds the values, the mockup is the visual reference.

## Global Constraints

- Godot 4.7, GDScript, GL Compatibility, 1920×1080 viewport, nearest filtering.
- Before each task, invoke the GodotPrompter skills (CLAUDE.md): `godot-prompter:godot-ui` for scenes and themes, and `godot-prompter:godot-testing` for GUT.
- CLAUDE.md rules:
  - UI nodes live in `.tscn` files. Instancing a scene from a script is fine; `Node.new()` for UI is not.
  - Scripts set data, text, textures, visibility, and a state's `theme_type_variation` (the pattern `AttributeTile` and `AbilityRow` use).
  - No inline font-size or colour overrides.
  - `%UniqueName` node references, typed variables and return types, `##` doc on every public function.
  - Use `Log`, not `print`. Never edit `addons/`.
- AI art: every new image ends in `_ai`. Never edit, move or delete the user's art files (images without `_ai`); stop referencing them instead.
- Theme changes are additive. The `book_theme.tres` variants the Abilities, Character and Path books use today keep their values.
- **Coordinates.**
  - The spec gives screen px.
  - Inside a tab scene, positions are tab-local px. The origin is the book's top-left, screen (260, 90), so local = screen − (260, 90).
  - Each tab root spans the `PageLayer` offsets (−700, −450) to (700, 450), with `mouse_filter = MOUSE_FILTER_IGNORE` so it never swallows a click on the backdrop.
  - Every position and size is even.
- **Tests that read positions or rects** first call `view._on_book_opened()` and `await wait_process_frames(2)`, so the containers have laid out.
- **Palette (spec, Palette).**

  | Name | Hex |
  |---|---|
  | Paper | `#F7E6CA` |
  | Ink, dark | `#33261A` |
  | Ink | `#3B2A20` |
  | Muted ink (all new variants) | `#765A43` |
  | Owned floor | `#E7CFA6` |
  | Empty and panel floor | `#EFDCBB` |
  | Wall shadow, first step | `#B9996F` |
  | Wall shadow, second step | `#D3B98F` |
  | Lit edge | `#FBF1DE` |
  | Vermilion | `#A83C30`, shade `#7E2A22` |
  | Seal text | `#F0E8D8` |
  | Madra ink | `#1C2F60` |
- **No alpha, tints, scale pops or eased tweens on the pages** (STYLE_GUIDE §3). Show state with a texture swap, a visibility toggle, an overlay or a variation swap. No text is cut off or ellipsized.
- **UIDs.** Never type a `uid://` by hand. Reference new resources by path, or generate ids with `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s scripts/tools/generate_uid.gd`.
- **Tests.** One file:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/<dir>/<file>.gd -gexit
  ```
  The whole suite:
  ```bash
  "C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
  ```
  Exit code 0 means every test passed. After adding images, run `--headless --import` once so their `.import` sidecars exist, and commit the sidecars with the images.
- **Commits.** Conventional commits (`feat(inventory): …`), staging named files only. Every message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Long names.** 30+ character item, material and quest names wrap inside their rows and panels and never leave the page rects.
2. **Huge counts.** 99,999 and 1,234,567 fit on their tags and in their rows, and the details print them with separators.
3. **Inventory changes while the book is open.** Foraging every 5 s, or a purchase, leaves the details and the marks on the item the player picked.
4. **The shown item disappears.** When it is discarded or used up, the details move to the tab's first item, or hide, and no marks are left behind.
5. **Five equipment pages.** The footer (page slots, count, discard) still fits inside the left page.

---

### Task 1: Pressed art kit

**Files:**
- Create: `docs/superpowers/mockups/inventory-pressed/gen/export_pressed.py`
- Create (generated, each with its `.import` sidecar): the textures below in `assets/sprites/ui/book/pressed/`, plus `assets/sprites/items/materials/spirit_fern_ai.png`, `assets/sprites/items/materials/dewdrop_tear_ai.png` and `assets/sprites/items/quest_items/refugee_camp_map_ai.png`
- Test: `tests/unit/test_pressed_pieces.gd` (new)

**Interfaces:**
- Produces these paths, which later tasks preload. Sizes are screen px. Each texture is drawn in art px and saved at 2× nearest.

| File in `assets/sprites/ui/book/pressed/` | Size | Drawn with |
|---|---|---|
| `pressed_slot_deep_ai.png` | 72×72 | `soft_well(depth=2, floor=#E7CFA6)` |
| `pressed_slot_shallow_ai.png` | 72×72 | `soft_well(depth=1, floor=#EFDCBB)` |
| `pressed_page_deep_ai.png` | 28×28 | `soft_well(depth=2, floor=#E7CFA6)` |
| `pressed_page_shallow_ai.png` | 28×28 | `soft_well(depth=1, floor=#EFDCBB)` |
| `pressed_panel_ai.png` | 32×32 | `soft_well(depth=2, floor=#EFDCBB)`, 9-slice source |
| `pressed_lozenge_ai.png` | 24×26 | `soft_well(depth=2, floor=#E7CFA6)` |
| `pressed_rule_ai.png` | 8×4 | `soft_rule` |
| `pressed_groove_ai.png` | 10×24 | `soft_well(depth=1, floor=#EFDCBB)` |
| `pressed_thumb_ai.png` | 4×8 | flat `#765A43` |
| `title_ornament_ai.png` | 272×14 | `ornament_rule` |
| `printer_marks_ai.png` | 32×32 | four `#A83C30` L marks, arms 5 art px, transparent elsewhere |
| `paper_tag_ai.png` | 12×20 | `soft_tag` |
| `seal_ai.png` | 66×26 | `seal` |
| `tick_box_ai.png` | 22×22 | `tick_box(ticked=False)` |
| `tick_box_ticked_ai.png` | 22×22 | `tick_box(ticked=True)` |
| `printed_cross_ai.png` | 28×28 | the discard × from `gen_r7.py` |
| `gear_plate_ai.png` | 468×268 | the cultivator relief at (166, 0) and the six dotted leaders, exactly as `gen_r7.equipment()` draws them, translated by (−1008, −300) |

- The three icons are 64×64:
  - `spirit_fern_ai.png` and `dewdrop_tear_ai.png` are `assets/ui/lacquer/icons/ic_fern_ai.png` and `ic_dewdrop_ai.png` scaled 4× nearest;
  - `refugee_camp_map_ai.png` is `icons_ai.make('map')`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## The pressed page pieces (spec: Pieces) and the book theme's pressed variants.

const PRESSED_DIR: String = "res://assets/sprites/ui/book/pressed/"
const SIZES: Dictionary[String, Vector2i] = {
	"pressed_slot_deep_ai.png": Vector2i(72, 72), "pressed_slot_shallow_ai.png": Vector2i(72, 72),
	"pressed_page_deep_ai.png": Vector2i(28, 28), "pressed_page_shallow_ai.png": Vector2i(28, 28),
	"pressed_panel_ai.png": Vector2i(32, 32), "pressed_lozenge_ai.png": Vector2i(24, 26),
	"pressed_rule_ai.png": Vector2i(8, 4), "pressed_groove_ai.png": Vector2i(10, 24),
	"pressed_thumb_ai.png": Vector2i(4, 8), "title_ornament_ai.png": Vector2i(272, 14),
	"printer_marks_ai.png": Vector2i(32, 32), "paper_tag_ai.png": Vector2i(12, 20),
	"seal_ai.png": Vector2i(66, 26), "tick_box_ai.png": Vector2i(22, 22),
	"tick_box_ticked_ai.png": Vector2i(22, 22), "printed_cross_ai.png": Vector2i(28, 28),
	"gear_plate_ai.png": Vector2i(468, 268),
}
const ICONS: Array[String] = [
	"res://assets/sprites/items/materials/spirit_fern_ai.png",
	"res://assets/sprites/items/materials/dewdrop_tear_ai.png",
	"res://assets/sprites/items/quest_items/refugee_camp_map_ai.png",
]

func _image(file: String) -> Image:
	return (load(PRESSED_DIR + file) as Texture2D).get_image()

func test_pressed_textures_have_their_sizes() -> void:
	for file: String in SIZES:
		var texture: Texture2D = load(PRESSED_DIR + file) as Texture2D
		assert_not_null(texture, file)
		assert_eq(Vector2i(texture.get_size()), SIZES[file], file)

func test_slot_walls_and_floors_use_the_pressed_palette() -> void:
	var deep: Image = _image("pressed_slot_deep_ai.png")
	assert_eq(deep.get_pixel(0, 36).to_html(false), "b9996f", "left wall, first shadow step")
	assert_eq(deep.get_pixel(2, 36).to_html(false), "d3b98f", "left wall, second step")
	assert_eq(deep.get_pixel(71, 36).to_html(false), "fbf1de", "right wall catches the light")
	assert_eq(deep.get_pixel(36, 36).to_html(false), "e7cfa6", "owned floor")
	assert_eq(deep.get_pixel(0, 0).a, 0.0, "corners are cut")
	var shallow: Image = _image("pressed_slot_shallow_ai.png")
	assert_eq(shallow.get_pixel(36, 36).to_html(false), "efdcbb", "empty floor")
	assert_eq(shallow.get_pixel(2, 36).to_html(false), "efdcbb", "one shadow step only")

func test_marks_leave_their_middle_clear() -> void:
	var marks: Image = _image("printer_marks_ai.png")
	assert_eq(marks.get_pixel(16, 16).a, 0.0)
	assert_eq(marks.get_pixel(0, 0).to_html(false), "a83c30")

func test_seal_and_tag_colours() -> void:
	assert_eq(_image("seal_ai.png").get_pixel(32, 12).to_html(false), "a83c30")
	assert_eq(_image("paper_tag_ai.png").get_pixel(6, 10).to_html(false), "f7e6ca")

func test_placeholder_item_icons_are_64_px() -> void:
	for path: String in ICONS:
		assert_eq(Vector2i((load(path) as Texture2D).get_size()), Vector2i(64, 64), path)
```

- [ ] **Step 2: Run it and see it fail**

Run: the one-file command with `-gtest=res://tests/unit/test_pressed_pieces.gd`
Expected: FAIL; the textures don't load.

- [ ] **Step 3: Write `export_pressed.py`**
  - Make it self-contained. Copy the round-6 primitives and the round-6 palette into it:
    - `rounded`, `soft_well`, `soft_rule` and `soft_tag` from `gen_r6.py`;
    - `ornament_rule` and `cultivator_mask` from `gen_r2.py`;
    - `relief` from `gen_r3.py`;
    - `seal` and `tick_box` from `gen_r5.py`;
    - the leader and cross drawing from `gen_r7.py`.
  - Don't import the `gen_r*` scripts: their paths point at a scratch folder.
  - Take the repo root from `Path(__file__).resolve().parents[5]`.
  - Write every file in the table at 2× nearest, plus the three icons, and print each path.

- [ ] **Step 4: Generate and import**

Run: `python -I docs/superpowers/mockups/inventory-pressed/gen/export_pressed.py`, then `"C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --import`
Expected: 20 paths printed, and a `.png.import` next to each image.

- [ ] **Step 5: Run the test and see it pass**

Run: the one-file command for `test_pressed_pieces.gd`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/mockups/inventory-pressed/gen/export_pressed.py assets/sprites/ui/book/pressed assets/sprites/items/materials/spirit_fern_ai.png assets/sprites/items/materials/spirit_fern_ai.png.import assets/sprites/items/materials/dewdrop_tear_ai.png assets/sprites/items/materials/dewdrop_tear_ai.png.import assets/sprites/items/quest_items/refugee_camp_map_ai.png assets/sprites/items/quest_items/refugee_camp_map_ai.png.import tests/unit/test_pressed_pieces.gd
git commit -m "feat(inventory): draw the pressed page pieces"
```

---

### Task 2: Book theme pressed variants and styleboxes

**Files:**
- Create: `assets/styleboxes/book/` with `pressed_panel.tres`, `pressed_lozenge.tres`, `pressed_rule.tres`, `printer_marks.tres`, `paper_tag.tres`, `seal.tres`, `pressed_groove.tres`, `pressed_thumb.tres`
- Modify: `assets/themes/book_theme.tres`. Add the Yatra One and BM Euljiro `FontFile` ext_resources, one `FontVariation` (BM Euljiro, `spacing_glyph = 1`) and the variants below.
- Modify: `docs/UI_STYLING.md`. Add rows to "Menu book pages" and a "Pressed pieces" stylebox table.
- Test: `tests/unit/test_pressed_pieces.gd` (append)

**Interfaces:**
- Consumes: the Task 1 textures.
- Produces these styleboxes:

| Stylebox | Texture | Texture margins L/T/R/B | Content margins L/T/R/B | Other |
|---|---|---|---|---|
| `pressed_panel.tres` | `pressed_panel_ai.png` | 8/8/8/8 | 16/16/16/16 | |
| `pressed_lozenge.tres` | `pressed_lozenge_ai.png` | 8/0/8/0 | 10/4/10/4 | |
| `pressed_rule.tres` | `pressed_rule_ai.png` | 2/0/2/0 | 0 | |
| `printer_marks.tres` | `printer_marks_ai.png` | 10/10/10/10 | 0 | `draw_center = false` |
| `paper_tag.tres` | `paper_tag_ai.png` | 4/4/4/4 | 5/1/5/1 | |
| `seal.tres` | `seal_ai.png` | 0 | 0 | |
| `pressed_groove.tres` | `pressed_groove_ai.png` | 0/6/0/6 | 0 | |
| `pressed_thumb.tres` | `pressed_thumb_ai.png` | 0/2/0/2 | 0 | |

- Produces these variants. Font "Eul+1" is the FontVariation.
  - The line pitch is the font's height plus the variant's `line_spacing`: set `line_spacing = pitch − font height`. It may be negative for Yatra One, as `LabelLacquerPanelTitle`'s is.

| Variant | Base type | Font | Size | Colour | Pitch | Style |
|---|---|---|---|---|---|---|
| `LabelBookPageTitle` | Label | Yatra | 38 | `#33261A` | 44 | |
| `LabelBookItemName` | Label | Yatra | 30 | `#33261A` | 34 | |
| `LabelBookQuestName` | Label | Yatra | 26 | `#33261A` | 30 | |
| `LabelBookDropCap` | Label | Yatra | 46 | `#A83C30` | 52 | |
| `LabelBookInk` | Label | Euljiro | 18 | `#3B2A20` | 26 | |
| `LabelBookInkDark` | Label | Euljiro | 18 | `#33261A` | 26 | |
| `LabelBookDetail` | Label | Euljiro | 15 | `#765A43` | 20 | |
| `LabelBookDetailDark` | Label | Euljiro | 15 | `#33261A` | 20 | |
| `LabelBookFlavor` | Label | Euljiro | 16 | `#765A43` | 22 | |
| `LabelBookStep` | Label | Euljiro | 16 | `#3B2A20` | 22 | |
| `LabelBookCount` | Label | Euljiro | 20 | `#33261A` | 24 | |
| `LabelBookCaps` | Label | Eul+1 | 13 | `#765A43` | 18 | |
| `LabelBookTag` | Label | Euljiro | 13 | `#33261A` | 18 | `normal` = `paper_tag.tres` |
| `LabelBookSeal` | Label | Eul+1 | 13 | `#F0E8D8` | 18 | `normal` = `seal.tres` |
| `LabelBookFilter` | Label | Eul+1 | 13 | `#765A43` | 18 | `normal` = StyleBoxEmpty with content margins 10/4/10/4 |
| `LabelBookFilterOn` | Label | Eul+1 | 13 | `#33261A` | 18 | `normal` = `pressed_lozenge.tres` |
| `RichTextBookDetail` | RichTextLabel | Euljiro | 15 | `default_color` `#765A43` | 20 | |
| `PanelPressed` | PanelContainer | | | | | `panel` = `pressed_panel.tres` |
| `PanelBookBare` | PanelContainer | | | | | `panel` = StyleBoxEmpty |
| `PanelPrinterMarks` | Panel | | | | | `panel` = `printer_marks.tres` |
| `HSeparatorPressed` | HSeparator | | | | | `separator` = `pressed_rule.tres`, `separation` = 4 |

- [ ] **Step 1: Write the failing tests** (append to `test_pressed_pieces.gd`)

```gdscript
const BOOK_THEME: Theme = preload("res://assets/themes/book_theme.tres")
const YATRA: String = "res://assets/fonts/YatraOne-Regular.ttf"
const EULJIRO: String = "res://assets/fonts/BMEULJIROTTF.ttf"
const STYLEBOX_DIR: String = "res://assets/styleboxes/book/"

## [variant, font file, size, colour hex, line pitch] (plan Task 2 table).
var _variants: Array[Array] = [
	[&"LabelBookPageTitle", YATRA, 38, "33261a", 44], [&"LabelBookItemName", YATRA, 30, "33261a", 34],
	[&"LabelBookQuestName", YATRA, 26, "33261a", 30], [&"LabelBookDropCap", YATRA, 46, "a83c30", 52],
	[&"LabelBookInk", EULJIRO, 18, "3b2a20", 26], [&"LabelBookInkDark", EULJIRO, 18, "33261a", 26],
	[&"LabelBookDetail", EULJIRO, 15, "765a43", 20], [&"LabelBookDetailDark", EULJIRO, 15, "33261a", 20],
	[&"LabelBookFlavor", EULJIRO, 16, "765a43", 22], [&"LabelBookStep", EULJIRO, 16, "3b2a20", 22],
	[&"LabelBookCount", EULJIRO, 20, "33261a", 24], [&"LabelBookCaps", EULJIRO, 13, "765a43", 18],
	[&"LabelBookTag", EULJIRO, 13, "33261a", 18], [&"LabelBookSeal", EULJIRO, 13, "f0e8d8", 18],
	[&"LabelBookFilter", EULJIRO, 13, "765a43", 18], [&"LabelBookFilterOn", EULJIRO, 13, "33261a", 18],
]

func test_pressed_label_variants() -> void:
	for row: Array in _variants:
		var font: Font = BOOK_THEME.get_font(&"font", row[0])
		var base: Font = (font as FontVariation).base_font if font is FontVariation else font
		assert_eq(base.resource_path, row[1], str(row[0]))
		assert_eq(BOOK_THEME.get_font_size(&"font_size", row[0]), row[2], str(row[0]))
		assert_eq(BOOK_THEME.get_color(&"font_color", row[0]).to_html(false), row[3], str(row[0]))
		var pitch: int = roundi(font.get_height(row[2])) + BOOK_THEME.get_constant(&"line_spacing", row[0])
		assert_eq(pitch, row[4], "%s line pitch" % row[0])

func test_capital_variants_space_their_letters() -> void:
	for variant: StringName in [&"LabelBookCaps", &"LabelBookSeal", &"LabelBookFilter", &"LabelBookFilterOn"]:
		var font: FontVariation = BOOK_THEME.get_font(&"font", variant) as FontVariation
		assert_not_null(font, str(variant))
		assert_eq(font.spacing_glyph, 1, str(variant))

func test_variants_the_other_books_use_are_unchanged() -> void:
	assert_eq(BOOK_THEME.get_font_size(&"font_size", &"LabelBookBody"), 20)
	assert_eq(BOOK_THEME.get_font_size(&"font_size", &"LabelBookTitle"), 28)
	assert_eq(BOOK_THEME.get_font_size(&"font_size", &"LabelBookMuted"), 16)
	assert_eq(BOOK_THEME.get_color(&"font_color", &"LabelBookMuted").to_html(false), "7d5f47")

func test_pressed_styleboxes() -> void:
	var panel: StyleBoxTexture = load(STYLEBOX_DIR + "pressed_panel.tres")
	assert_eq(panel.texture_margin_left, 8.0)
	assert_eq(panel.content_margin_top, 16.0)
	var marks: StyleBoxTexture = load(STYLEBOX_DIR + "printer_marks.tres")
	assert_false(marks.draw_center)
	assert_eq(marks.texture_margin_left, 10.0)
	assert_eq(BOOK_THEME.get_stylebox(&"panel", &"PanelPressed"), panel)
	assert_eq(BOOK_THEME.get_stylebox(&"panel", &"PanelPrinterMarks"), marks)
	assert_eq(BOOK_THEME.get_stylebox(&"normal", &"LabelBookTag").resource_path, STYLEBOX_DIR + "paper_tag.tres")
	assert_eq(BOOK_THEME.get_stylebox(&"normal", &"LabelBookFilterOn").resource_path, STYLEBOX_DIR + "pressed_lozenge.tres")
	assert_true(BOOK_THEME.get_stylebox(&"normal", &"LabelBookFilter") is StyleBoxEmpty)
	assert_eq(BOOK_THEME.get_constant(&"separation", &"HSeparatorPressed"), 4)

func test_text_reads_on_paper_and_panels() -> void:
	var paper := Color("#F7E6CA")
	var panel := Color("#EFDCBB")
	assert_gte(_contrast(Color("#765A43"), paper), 4.56, "muted on paper")
	assert_gte(_contrast(Color("#765A43"), panel), 4.56, "muted on a panel")
	assert_gte(_contrast(Color("#3B2A20"), panel), 4.56, "ink on a panel")
	assert_gte(_contrast(Color("#1C2F60"), panel), 4.56, "Madra ink on a panel")
	assert_gte(_contrast(Color("#F0E8D8"), Color("#A83C30")), 4.56, "seal text")

## WCAG 2 contrast ratio between two opaque colours.
func _contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)
```

- [ ] **Step 2: Run it and see it fail.** Expected: FAIL; the variants and styleboxes are missing.
- [ ] **Step 3: Add the styleboxes, the fonts and the variants from the two tables.**
- [ ] **Step 4: Run it and see it pass.** Also run `test_abilities_book.gd`, `test_character_book.gd` and `test_path_book.gd`. Expected: all PASS.
- [ ] **Step 5: Update UI_STYLING.md** ("Menu book pages" rows for every new variant; a "Pressed pieces" table of the styleboxes).
- [ ] **Step 6: Commit**: `feat(ui): add the pressed page variants to the book theme`

---

### Task 3: BookText helpers

**Files:**
- Create: `scripts/utils/book_text.gd` (`class_name BookText`, static functions only)
- Modify: `scripts/utils/theme_constants.gd`. Add `const BOOK_MADRA_INK: Color = Color("#1C2F60")` with a `##` line.
- Test: `tests/unit/test_book_text.gd` (new)

**Interfaces:**
- Produces:
  - `static func count(amount: int) -> String`. Returns `"×7"`.
  - `static func thousands(amount: int) -> String`. Returns `"4,600"`.
  - `static func seconds(value: float) -> String`. Returns `"10 s"`, or `"2.5 s"`. Plain text: RichText callers pass it through `LacquerText.decimal_bbcode()`.
  - `static func range_text(low: int, high: int) -> String`. Returns `"2–6"` (en dash), or `"3"` when `low == high`.
  - `static func yield_text(low: int, high: int, interval_seconds: float) -> String`. Returns `"2–6 every 5 s"`.
  - `static func color_madra(text: String) -> String`. Wraps each `[+-]?\d+(\.\d+)? Madra` in `[color=#1c2f60]…[/color]`, using `ThemeConstants.BOOK_MADRA_INK.to_html(false)`.
  - `static func effect_line(def: ConsumableDefinitionData) -> String`.
    - Joins each effect's `describe()` with `" · "`, then adds `" · " + seconds(cooldown) + " cooldown"` when the cooldown is above 0.
    - Applies `color_madra` and then `LacquerText.decimal_bbcode`.
  - `static func effect_label(effect: EffectData) -> String`. Returns `"RESTORES"` for `ChangeVitalsEffectData`, otherwise `"EFFECT"`.
  - `static func slot_name(slot: EquipmentDefinitionData.EquipmentSlot) -> String`. Returns `"MAIN HAND"`, `"OFF HAND"`, `"HEAD"`, `"BODY"` (for ARMOR) or `"ACCESSORY"`.
  - `static func bonus_pairs(def: EquipmentDefinitionData) -> Array[PackedStringArray]`.
    - One `[name, value]` per non-zero bonus, in `CharacterAttributesData.AttributeType` order.
    - The name is the enum key (`"STRENGTH"`). The value is `"%+d"` for a whole number, otherwise `"%+.1f"`.
  - `static func split_for_drop_cap(text: String, font: Font, font_size: int, narrow_width: float, narrow_lines: int) -> PackedStringArray`.
    - Returns `[cap, narrow, rest]`. The cap is the first character.
    - `narrow` holds the most whole words of the remainder that fit in `narrow_lines` lines of `narrow_width` (measured with `font.get_string_size`); `rest` holds the remaining words.
    - Drop a leading space after the cap when the cap was a word of its own.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## BookText: the pressed pages' number, effect and drop-cap helpers.

func test_count_marks_a_stack() -> void:
	assert_eq(BookText.count(7), "×7")
	assert_eq(BookText.count(4600), "×4600")

func test_thousands_groups_digits() -> void:
	assert_eq(BookText.thousands(12), "12")
	assert_eq(BookText.thousands(4600), "4,600")
	assert_eq(BookText.thousands(1234567), "1,234,567")

func test_seconds_keep_whole_numbers_whole() -> void:
	assert_eq(BookText.seconds(10.0), "10 s")
	assert_eq(BookText.seconds(2.5), "2.5 s")

func test_yield_text() -> void:
	assert_eq(BookText.yield_text(2, 6, 5.0), "2–6 every 5 s")
	assert_eq(BookText.yield_text(3, 3, 5.0), "3 every 5 s")

func test_color_madra_marks_only_madra_amounts() -> void:
	assert_eq(BookText.color_madra("+30 Health, +20 Madra"), "+30 Health, [color=#1c2f60]+20 Madra[/color]")
	assert_eq(BookText.color_madra("+7.5 Madra"), "[color=#1c2f60]+7.5 Madra[/color]")

func test_effect_line_for_crude_scale() -> void:
	var crude: ConsumableDefinitionData = load("res://resources/items/consumables/crude_scale.tres")
	assert_eq(BookText.effect_line(crude), "[color=#1c2f60]+20 Madra[/color] · 10 s cooldown")

func test_effect_line_without_cooldown_has_no_tail() -> void:
	var tonic := ConsumableDefinitionData.new()
	var heal := ChangeVitalsEffectData.new()
	heal.health_change = 30.0
	tonic.effects = [heal]
	assert_eq(BookText.effect_line(tonic), "+30 Health")

func test_effect_labels() -> void:
	assert_eq(BookText.effect_label(ChangeVitalsEffectData.new()), "RESTORES")
	assert_eq(BookText.effect_label(AwardPathPointEffectData.new()), "EFFECT")

func test_slot_names() -> void:
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.MAIN_HAND), "MAIN HAND")
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.ARMOR), "BODY")
	assert_eq(BookText.slot_name(EquipmentDefinitionData.EquipmentSlot.ACCESSORY), "ACCESSORY")

func test_bonus_pairs_follow_attribute_order() -> void:
	var dagger: EquipmentDefinitionData = load("res://resources/items/equipment/spirit_valley/makeshift_dagger.tres")
	var pairs: Array[PackedStringArray] = BookText.bonus_pairs(dagger)
	assert_eq(pairs.size(), 2)
	assert_eq(pairs[0], PackedStringArray(["STRENGTH", "+3"]))
	assert_eq(pairs[1], PackedStringArray(["AGILITY", "+2"]))

func test_drop_cap_split_keeps_every_word() -> void:
	var font: Font = load("res://assets/fonts/BMEULJIROTTF.ttf")
	var text: String = "A hand-drawn map leading to a camp of survivors hidden in the valley."
	var parts: PackedStringArray = BookText.split_for_drop_cap(text, font, 18, 390.0, 2)
	assert_eq(parts[0], "A")
	assert_eq((parts[1] + " " + parts[2]).strip_edges(), "hand-drawn map leading to a camp of survivors hidden in the valley.")
	assert_false(parts[1].is_empty())

func test_drop_cap_split_of_a_short_text_has_no_rest() -> void:
	var font: Font = load("res://assets/fonts/BMEULJIROTTF.ttf")
	assert_eq(BookText.split_for_drop_cap("A small tooth.", font, 18, 390.0, 2), PackedStringArray(["A", "small tooth.", ""]))
```

- [ ] **Step 2: Run it and see it fail.** Expected: FAIL; `BookText` is not declared.
- [ ] **Step 3: Implement `book_text.gd` and the `ThemeConstants` line.**
- [ ] **Step 4: Run it and see it pass.** Expected: PASS (12 tests).
- [ ] **Step 5: Commit**: `feat(inventory): add the pressed pages' text helpers`

---

### Task 4: Page layer, page titles and the open_page contract

**Files:**
- Create: `scenes/inventory/pressed/page_title/page_title.tscn` and `page_title.gd`. `class_name PageTitle extends VBoxContainer`:
  - `%TitleLabel` (`LabelBookPageTitle`, centred, width fills);
  - `%Ornament` (`TextureRect`, `title_ornament_ai.png`, centred);
  - the ornament's line sits 16 px under the title's baseline.
- Modify: `scenes/inventory/inventory_view/inventory_view.tscn`. The tree becomes:
  ```
  InventoryView (Control, full rect, mouse_filter IGNORE, theme = book_theme.tres)
    page_content = [BookLayer/BookContent, PageLayer]
    BookLayer (Control, centred, scale 2, mouse IGNORE)
      BookFrame (unique; offsets ±350/±225; inventory_book_style)
      BookContent (offsets ±350/±225, mouse IGNORE)
        TabSwitcher (unique) + four tab buttons (unchanged)
    PageLayer (Control, centred, scale 1, mouse IGNORE)
      EquipmentTab, ConsumablesTab, MaterialsTab, QuestItemsTab (unique, same names)
  ```
  - In this task only, each tab root sits at PageLayer offsets (−700, −450) with `scale = Vector2(2, 2)`, so it renders exactly as before.
  - Each tab task removes its tab's scale.
- Modify: `scenes/inventory/inventory_view/inventory_view.gd`:
  - `_before_open()` calls `tabs[_last_tab_index].open_page()`;
  - `_on_page_turned()` calls `tabs[_pending_tab_index].open_page()` before showing the tab.
- Modify: the four tab scripts (`equipment_tab.gd`, `consumables_tab.gd`, `materials_tab.gd`, `quest_items_tab.gd`). Each gets `## Shows the tab's first item; called whenever the page is opened.` and `func open_page() -> void:` with a body of `pass`. The tab tasks fill it in.
- Create: `tests/helpers/page_bounds.gd`, `class_name PageBounds extends RefCounted`:
  - `const LEFT_PAGE: Rect2 = Rect2(424, 202, 508, 688)`
  - `const RIGHT_PAGE: Rect2 = Rect2(988, 202, 508, 688)`
  - `static func scaled_text(root: Node) -> Array[String]`: the names of visible Labels and RichTextLabels under `root` whose global transform scale isn't `Vector2.ONE`.
  - `static func escaping_text(root: Node) -> Array[String]`: the names of visible Labels and RichTextLabels whose global rect is not inside either page rect.
- Test: `tests/integration/test_inventory_layers.gd` (new)

**Interfaces:**
- Produces:
  - `PageTitle`: `@export var title: String`, with a setter that writes `%TitleLabel.text`.
  - Every tab exposes `open_page() -> void`; InventoryView calls it on opening and on each page turn.
  - `PageBounds.scaled_text(root)` and `PageBounds.escaping_text(root)`.

- [ ] **Step 1: Write the failing test**

```gdscript
extends GutTest

## The inventory book draws its art at 2x and its pages at 1x (spec: Calls).

const InventoryViewScene: PackedScene = preload("res://scenes/inventory/inventory_view/inventory_view.tscn")
const PageTitleScene: PackedScene = preload("res://scenes/inventory/pressed/page_title/page_title.tscn")

func _view() -> MenuBookView:
	var view: MenuBookView = InventoryViewScene.instantiate() as MenuBookView
	add_child_autofree(view)
	return view

func test_book_art_is_doubled_and_pages_are_not() -> void:
	var view: MenuBookView = _view()
	assert_eq((view.get_node("BookLayer") as Control).scale, Vector2(2, 2))
	assert_eq((view.get_node("PageLayer") as Control).scale, Vector2.ONE)

func test_the_four_tabs_live_on_the_page_layer() -> void:
	var view: MenuBookView = _view()
	for tab_name: String in ["EquipmentTab", "ConsumablesTab", "MaterialsTab", "QuestItemsTab"]:
		assert_eq(view.find_child(tab_name, true, false).get_parent().name, &"PageLayer", tab_name)

func test_pages_show_only_while_the_book_lies_open() -> void:
	var view: MenuBookView = _view()
	assert_false((view.get_node("PageLayer") as Control).visible)
	view._on_book_opened()
	assert_true((view.get_node("PageLayer") as Control).visible)

func test_page_title_shows_its_title() -> void:
	var title: PageTitle = PageTitleScene.instantiate() as PageTitle
	add_child_autofree(title)
	title.title = "Gear"
	assert_eq((title.get_node("%TitleLabel") as Label).text, "Gear")
	assert_eq((title.get_node("%Ornament") as TextureRect).texture.resource_path, "res://assets/sprites/ui/book/pressed/title_ornament_ai.png")
```

- [ ] **Step 2: Run it and see it fail.** Expected: FAIL; there is no node `BookLayer`.
- [ ] **Step 3: Restructure `inventory_view.tscn`, add `open_page()` and the two calls, and create PageTitle and PageBounds.**
- [ ] **Step 4: Run this test, then the full suite.** Expected: PASS, and the full suite exits 0. Today's tabs still render at 2x and behave as before.
- [ ] **Step 5: Commit**: `refactor(inventory): split the book into a 2x art layer and a 1x page layer`

---

### Task 5: Equipment tab

**Files:**
- Modify: `scenes/inventory/inventory_view/equipment_tab/equipment_tab.tscn` and `equipment_tab.gd`
- Modify: `equipment_grid/equipment_grid.gd` and `.tscn`; `inventory_slot/inventory_slot.gd` and `.tscn`; `gear_selector/gear_selector.gd`, `.tscn`, `gear_slot.gd` and `gear_slot.tscn`; `pagination_bar/pagination_bar.gd` and `.tscn`; `page_button/page_button.tscn`; `trash_slot/trash_slot.gd` and `.tscn`
- Create: `equipment_tab/filter_words/filter_words.tscn` and `.gd`
- Create: `equipment_tab/equipment_details/equipment_details.tscn` and `.gd`, plus `equipment_details/bonus_row.tscn` and `bonus_row.gd`
- Create: `assets/shaders/paper_fade.gdshader` and `assets/shaders/paper_fade_material.tres` (`resource_local_to_scene = false`)
- Modify: `docs/inventory/INVENTORY.md` (the Equipment steps in Player Experience, the Equipment tab tree, Pagination and category filter, Shared components); `docs/STYLE_GUIDE.md` (delete rows K5 and K6)
- Test: `tests/integration/test_equipment_filter.gd` (rewrite the alpha checks), `tests/integration/test_pagination_bar.gd` (add one test), `tests/integration/test_equipment_page.gd` (new)

**Interfaces:**
- Consumes: the Task 1 textures, the Task 2 variants, `BookText.slot_name()` and `BookText.bonus_pairs()`, `PageTitle`, `PageBounds`, and `open_page()`.
- Produces:
  - `InventorySlot`:
    - `const DEEP_TEXTURE: Texture2D` and `const SHALLOW_TEXTURE: Texture2D` (the pressed slots);
    - `set_marked(marked: bool) -> void` and `is_marked() -> bool`;
    - `set_filtered_out(filtered_out: bool) -> void` and `is_filtered_out() -> bool`.
  - `FilterWords extends HBoxContainer`: `signal option_changed(index: int)`, `set_options(labels: PackedStringArray) -> void`, `select(index: int) -> void`, `get_selected() -> int`.
  - `EquipmentDetails extends PanelContainer`:
    - `show_item(data: ItemInstanceData, worn: bool) -> void`, `clear() -> void`, `get_item() -> ItemInstanceData`;
    - `static func wants_hint(name_lines: int, bonus_count: int, description_lines: int) -> bool`. True when `name_lines <= 2 and bonus_count <= 4 and description_lines <= 2`.
  - `BonusRow.setup(left: PackedStringArray, right: PackedStringArray) -> void`. An empty `right` hides the right half.
  - `PaginationBar.set_count(held: int, capacity: int) -> void`, which writes `"%d / %d"` into `%CountLabel`.
  - `EquipmentTab.open_page() -> void`.

**Layout:** tab-local px; the tab root's scale is now 1.

| Node | Rect | Notes |
|---|---|---|
| `LeftTitle` (PageTitle "Equipment") | x 192–644 | baseline at local y 172 |
| `%FilterWords` | centred on x 418 | baseline local 226, separation 14 |
| `%EquipmentGrid` | (192, 244), 452×452 | `num_columns` 6, separations 4. Remove the tab's margin overrides |
| `%PaginationBar` | (192, 706), 452×72 | `PageLabel` caps "PAGE", `%PageButtons` (separation 8), a Spacer, `%CountLabel` (`LabelBookDetail`), `%TrashSlot` |
| `RightTitle` (PageTitle "Gear") | x 748–1216 | |
| `%GearSelector` | (748, 210), 468×268 | see below |
| `%EquipmentDetails` | (748, 516), 468×272 | `PanelPressed`, fixed height |

**GearSelector.**
- `Plate` is a TextureRect showing `gear_plate_ai.png` at (0, 0).
- `LeftColumn` is a VBox at (8, 0), separation 26, holding `HeadGearSlot`, then `MainWeaponGearSlot`, then `Accessory1GearSlot`.
- `RightColumn` is a VBox at (392, 0), holding `ArmorGearSlot`, `OffhandGearSlot`, `Accessory2GearSlot`.
- Six `LabelBookCaps` Labels are centred under the slots at slot top + 78: `HEAD`, `MAIN HAND`, `ACCESSORY`, `BODY`, `OFF HAND`, `ACCESSORY`.
- Delete `Top Signage`, `Title` and `GearSelectorPortrait`.

**EquipmentDetails.**
- The header is an HBox:
  - `IconWell` (TextureRect, deep slot, 72×72) holding `%Icon` (64×64 at +4, +4);
  - a VBox with `%NameLabel` (`LabelBookItemName`, autowrap by word, minimum width 346) and `%SlotLabel` (`LabelBookCaps`, `BookText.slot_name()`).
- `%Bonuses` is a VBox of BonusRow instances, two bonuses per row. Each BonusRow is an HBox — `%LeftName` (caps), `%LeftValue` (`LabelBookInkDark`), an 18 px gap, `%RightName`, `%RightValue` — with an `HSeparatorPressed` under it.
- `%Description` is `LabelBookInk`, autowrap, minimum width 434.
- `%Hint` is `LabelBookDetail`: "Right-click to wear it", or "Right-click to take it off" when worn. It shows only while `wants_hint(name lines, bonus count, description lines)` is true. Read the line counts with `get_line_count()` after setting the text.

**Slots.**
- `InventorySlot` is a 72×72 TextureRect.
  - `_update_slot()` picks `DEEP_TEXTURE` when the slot has an item and isn't filtered out; otherwise `SHALLOW_TEXTURE`.
  - When filtered out, it sets the item icon's `material` to `paper_fade_material.tres`, otherwise to `null`.
  - `setup()`, `grab_item()` and `equip_item()` end by calling `_update_slot()`.
  - `%Marks` is a Panel (`PanelPrinterMarks`) at full rect with offsets −6/−6/+6/+6, hidden, mouse IGNORE.
  - `gear_slot.tscn` and `trash_slot.tscn` get the same `%Marks` node, because the base script uses it. Both slots are 72×72 too.
  - The ItemInstance fills the slot, and its 4 px margin leaves a 64 px icon.
  - Remove the random textures.
- `GearSlot` loses `ITEM_SLOT_OUTLINES`, `slot_background`, the `MarginContainer/SlotBackground` nodes and its `_update_slot` override. It keeps the group, its exports and `is_valid_item`.
- `TrashSlot` is 72×72 and loses `SLOT_TEXTURE`. Its `%Cross` is a TextureRect (`printed_cross_ai.png`, centred, mouse IGNORE); `_update_slot()` calls super, then sets `%Cross.visible = item_instance == null`.
- `page_button.tscn` is a TextureButton, 28×28: normal is the shallow page texture, pressed is the deep one, `toggle_mode` is on. Its child `PageNumber` keeps that name and is a `LabelBookDetailDark` Label, centred.

**FilterWords.**
- Four Labels, `Word0` to `Word3`, with variant `LabelBookFilter` and mouse STOP.
- `set_options` fills the texts, hides unused words and selects 0 without emitting.
- A left press on a word calls `select(i)` and, if the selection changed, emits `option_changed(i)`.
- `select` gives the chosen word `LabelBookFilterOn` and the rest `LabelBookFilter`.

**paper_fade.gdshader** (the spec's opaque fade, so the filter never uses alpha):

```glsl
shader_type canvas_item;
uniform vec4 paper_color : source_color = vec4(0.968627, 0.901961, 0.792157, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.7;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, paper_color.rgb, amount), c.a);
}
```

**EquipmentTab behaviour.** The node names and private members tests call stay: `_on_slot_input`, `_input`, `_grid_global_index`, `_on_filter_changed`, `_on_page_hovered`, `_return_to_original`, `equipment_grid`, `trash_slot`, `dragged_item`, `original_slot`, `is_dragging`.
- **Replaced nodes.** `%SortSubBanner` becomes `%FilterWords` and `%ItemDescriptionBox` becomes `%EquipmentDetails`. Delete the `SelectorSprite` node tree, `_update_selector()` and `SELECTOR_OFFSET`.
- **Hover.** Hovering or pressing a slot that holds an item, while not dragging, marks that slot, unmarks the last one and calls `details.show_item(data, slot is GearSlot)`. An empty slot changes nothing.
- **Drag target.** While dragging, mouse motion marks the slot under the cursor if the drop would be accepted. Read the motion event's `global_position`, not `get_global_mouse_position()`, so tests can drive it. A slot counts if it is one of these:
  - a grid slot other than the origin;
  - the trash;
  - a `GearSlot` whose `is_valid_item()` passes.

  A refused slot gets no mark, and the previous target is unmarked. `_cleanup_drag()` clears the target mark.
- **Dragged item.** `POSITION_OFFSET = Vector2(-36, -36)`. The dragged item is 72×72 with `z_index = 10`.
- **Following the shown item.** After a drop and on every `inventory_changed`, call `_follow_item(details.get_item())` deferred. It marks the visible slot (grid or gear) holding that item. If the item is on another page, nothing is marked. If the item no longer exists, it falls back to `open_page()`.
- **`open_page()`.**
  1. Run `_refresh_pagination()`.
  2. Show the first item on the current grid page.
  3. Otherwise, the first worn piece in the order Head, Main hand, Accessory 1, Body, Off hand, Accessory 2.
  4. Otherwise, hide `%EquipmentDetails`.
- **`_refresh_pagination()`** also calls `pagination_bar.set_count(inventory.equipment.size(), inventory.equipment_capacity())`.
- **Filter.** `EquipmentGrid._update_grid()` calls `slots[i].set_filtered_out(not _category_match.call(data))`. Delete `DIM_ALPHA`; nothing sets `modulate`.
- **SortSubBanner stays.** The Abilities book still uses it as `%FilterSelector`, so `sort_sub_banner.*` and `test_sort_sub_banner.gd` are unchanged. The Equipment tab only stops using it.

- [ ] **Step 1: Write the failing tests.**

`test_equipment_filter.gd` replaces the alpha asserts:
- `test_filter_fades_non_matching_and_empty_slots`: under the Weapons filter, `slots[0].is_filtered_out()` is false, the armor slot's and an empty slot's are true, and every slot's `modulate` equals `Color.WHITE`.
- `test_match_all_clears_fading`: no slot is filtered out.
- `test_filter_persists_across_page_flip`: the same checks, made after `set_page(1)`.
- `test_tab_wires_filter_words_to_grid`: `tab._on_filter_changed(1)`, then the armor slot is filtered out.

New `test_equipment_page.gd`:
- **Fixture.**
  - Instantiate `inventory_view.tscn` on a fresh `InventoryData` in `PersistenceManager.save_game_data.inventory`; restore the old one in `after_each`.
  - Find the tab with `view.find_child("EquipmentTab", true, false)`.
  - Award items with `InventoryManager.award_items()`.
  - Before checking bounds, call `view._on_book_opened()` and await 2 process frames.

```gdscript
func test_page_is_six_by_six_slots_of_72_px() -> void:
	var slots: Array[InventorySlot] = _tab().equipment_grid.get_slots()
	assert_eq(slots.size(), 36)
	assert_eq(slots[0].size, Vector2(72, 72))
	assert_eq(slots[1].position.x - slots[0].position.x, 76.0)

func test_hovering_an_item_marks_it_and_shows_it() -> void:
	# award the dagger; emit a mouse motion on slot 0 through _on_slot_input
	assert_true(slot0.is_marked())
	assert_eq((tab.get_node("%EquipmentDetails").get_node("%NameLabel") as Label).text, "Makeshift Dagger")

func test_hovering_an_empty_slot_keeps_the_last_item() -> void:
	# after the above, motion over slot 5 (empty)
	assert_true(slot0.is_marked())
	assert_false(slot5.is_marked())

func test_drag_marks_only_a_slot_that_would_take_the_item() -> void:
	# pick up the dagger with tab._on_slot_input(slot0, LEFT press); then call tab._input() with an
	# InputEventMouseMotion whose global_position = main_hand.get_global_rect().get_center()
	assert_true(main_hand.is_marked())
	# the same motion, centred on HeadGearSlot
	assert_false(head.is_marked())
	assert_false(main_hand.is_marked())

func test_longest_item_fits_with_its_hint() -> void:
	# award the Dreadbeast Tooth Necklace and show it
	assert_eq(name_label.get_line_count(), 2)
	assert_eq(details.get_node("%Bonuses").get_child_count(), 1)
	assert_true((details.get_node("%Hint") as Label).visible)
	assert_eq(PageBounds.escaping_text(tab), [])

func test_hint_gives_way_first() -> void:
	assert_true(EquipmentDetails.wants_hint(2, 4, 2))
	assert_false(EquipmentDetails.wants_hint(2, 5, 1))
	assert_false(EquipmentDetails.wants_hint(1, 2, 3))
	assert_false(EquipmentDetails.wants_hint(3, 2, 1))

func test_main_hand_sits_left_of_the_figure() -> void:
	var plate_mid: float = (tab.get_node("%GearSelector").get_node("Plate") as Control).get_global_rect().get_center().x
	assert_lt(main_hand.get_global_rect().get_center().x, plate_mid)
	assert_gt(armor.get_global_rect().get_center().x, plate_mid)

func test_count_is_the_bag_against_its_capacity() -> void:
	# award 3 pieces
	assert_eq((tab.get_node("%PaginationBar").get_node("%CountLabel") as Label).text, "3 / 72")

func test_discard_slot_shows_its_cross_only_when_empty() -> void:
	assert_true(trash.get_node("%Cross").visible)
	trash.accept(item_data)
	assert_false(trash.get_node("%Cross").visible)
	assert_eq(trash.texture, InventorySlot.DEEP_TEXTURE)

func test_open_page_shows_the_first_item() -> void:
	# the dagger at grid index 0, the cowl at index 1
	tab.open_page()
	assert_eq(details.get_item(), dagger_data)
	assert_true(slots[0].is_marked())

func test_open_page_falls_back_to_worn_gear_then_hides() -> void:
	# only a worn cowl (equip it from the grid with InventoryManager.equip_item)
	tab.open_page()
	assert_eq(details.get_item(), cowl_data)
	# a fresh, empty inventory
	tab.open_page()
	assert_false(details.visible)

func test_discarding_the_shown_item_moves_on() -> void:            # Review Focus 4
	# show item A in slot 0, then remove it as a discard does: erase it from
	# inventory.equipment and emit InventoryManager.inventory_changed
	await wait_process_frames(2)
	assert_ne(details.get_item(), item_a)
	assert_false(slots[0].is_marked() and slots[0].item_instance == null, "no marks on an empty slot")

func test_five_pages_fit_the_footer() -> void:                     # Review Focus 5
	# inventory.unlocked_equipment_pages = 5, then emit inventory_changed
	assert_eq(PageBounds.escaping_text(tab.get_node("%PaginationBar")), [])
	assert_true(PageBounds.LEFT_PAGE.encloses(tab.get_node("%PaginationBar").get_global_rect()))

func test_pages_have_their_titles_and_draw_text_at_1x() -> void:
	assert_eq((tab.get_node("LeftTitle").get_node("%TitleLabel") as Label).text, "Equipment")
	assert_eq((tab.get_node("RightTitle").get_node("%TitleLabel") as Label).text, "Gear")
	assert_eq(PageBounds.scaled_text(tab), [])
```

`test_pagination_bar.gd` adds `test_set_count_shows_bag_against_capacity`: after `bar.set_count(11, 72)`, `%CountLabel` reads `"11 / 72"`.

`FilterWords` gets `test_clicking_a_word_selects_it`, in `test_equipment_page.gd`: a left press on `Word2` makes `get_selected()` 2, emits `option_changed` with `[2]`, and gives `Word2.theme_type_variation` the value `&"LabelBookFilterOn"`.

- [ ] **Step 2: Run them and see them fail.** Expected: FAIL; the new nodes and functions are missing.
- [ ] **Step 3: Build the scenes and scripts as described.**
- [ ] **Step 4: Run the Equipment tests, then the whole suite.**
  - The Equipment tests are `test_equipment_page.gd`, `test_equipment_filter.gd`, `test_pagination_bar.gd`, `test_equipment_drag_paging.gd`, `test_equipment_grid_pagination.gd` and `test_trash_slot_flow.gd`.
  - Expected: all PASS, and the suite exits 0.
- [ ] **Step 5: Update INVENTORY.md's Equipment parts and delete STYLE_GUIDE K5 and K6.**
- [ ] **Step 6: Commit**: `feat(inventory): press the Equipment page into the book`

---

### Task 6: Consumables tab

**Files:**
- Modify: `consumables_tab/consumables_tab.tscn` and `.gd`; `consumable_row.tscn` and `.gd`; `consumables_hotbar/consumables_hotbar.tscn` and `.gd`; `hotbar_slot/hotbar_slot.tscn` and `.gd`
- Modify: `scenes/common/drop_target_slot.gd`
- Modify: `scenes/inventory/common/scroll_rail/scroll_rail.tscn` (and `.gd` if needed); `scenes/inventory/common/inventory_list/inventory_list.tscn`
- Create: `consumables_tab/consumable_details/consumable_details.tscn` and `.gd`
- Create: `scenes/inventory/pressed/table_row/table_row.tscn` and `.gd`
- Create: `scenes/inventory/pressed/item_drag_preview/item_drag_preview.tscn` and `.gd`
- Delete:
  - `scenes/inventory/inventory_view/item_description_box.gd` and its `.uid` (no user remains);
  - `assets/styleboxes/inventory/hotbar_slot_empty.tres` and `hotbar_slot_equipped.tres`;
  - the `PreviewRow1`–`3` placeholders.
- Modify: `docs/inventory/INVENTORY.md` (Consumables parts); `docs/STYLE_GUIDE.md` (delete row K7; drop the scroll-rail text from K4)
- Modify: `tests/integration/test_tab_banner_title.gd`. Delete `test_consumables_banner_title_at_runtime`; the page title is checked below.
- Test: `tests/integration/test_consumables_page.gd` (new), `tests/unit/test_drop_target_slot.gd` (new). `tests/integration/test_consumables_tab_hotbar_equip.gd` must pass unchanged.

**Interfaces:**
- Consumes: the Task 2 variants, `BookText.effect_line()`, `effect_label()`, `color_madra()`, `seconds()` and `count()`, `PageTitle`, `PageBounds`.
- Produces:
  - `TableRow extends VBoxContainer`: `setup(label: String, value_bbcode: String) -> void` and `set_rule_visible(rule_visible: bool) -> void`.
    - Nodes: `%Label` (caps), `%Value` (RichTextLabel, `RichTextBookDetail`, right-aligned, `bbcode_enabled`, `fit_content`), then an `HSeparatorPressed`.
    - Materials reuses it in Task 7.
  - `ItemDragPreview extends Control`: `set_icon(icon: Texture2D) -> void`. Holds a 64×64 icon centred on the cursor.
  - `DropTargetSlot._set_drop_hover(hovered: bool) -> void`, a virtual.
    - Its default does what today's code does: `modulate = HOVER_TINT if hovered else Color.WHITE`.
    - `_can_drop_data` and `_clear_drop_hover` both route through it, so the Abilities loadout is unchanged.
  - `ConsumableRow`:
    - keeps `clicked(row: ConsumableRow, event: InputEvent)`; adds `signal hovered(row: ConsumableRow)`;
    - `set_marked(marked: bool) -> void`, `is_marked() -> bool`, `set_rule_visible(rule_visible: bool) -> void`;
    - `setup()` and `get_definition()` are kept.
  - `HotbarSlot`: adds `signal hovered(slot: HotbarSlot)`, `set_marked(marked: bool) -> void` and `is_marked() -> bool`. It overrides `_set_drop_hover` to toggle `%Marks`, and never touches `modulate`.
  - `ConsumablesHotbar`: adds `signal slot_hovered(slot: HotbarSlot)`.
  - `ConsumableDetails extends PanelContainer`: `show_consumable(def: ConsumableDefinitionData, hotbar_slot: int) -> void` (-1 when the item isn't on the hotbar), `clear() -> void`, `get_consumable() -> ConsumableDefinitionData`.

**Layout** (tab-local):

| Node | Rect | Notes |
|---|---|---|
| `LeftTitle` | "Consumables" | no caption row |
| `%ConsumablesInventoryList` | (192, 210), 452×552 | rows 428×76, separation 4; the rail is 10 px wide, x 632–642 |
| `%EmptyLabel` | (192, 210) | "No consumables yet." (`LabelBookDetail`) |
| `RightTitle` | "Hotbar" | |
| `%ConsumablesHotbar` | (780, 226) | `SlotsRow` (separation 40) holds the four HotbarSlots and nothing else. `KeysRow` under it: four 72-wide `LabelBookInkDark` Labels "1"–"4", centred, baseline local 328. Remove `Banner` and `Lede` |
| `HintLabel` | centred on x 984, width 452 | `LabelBookDetail`, autowrap: "Drag a consumable onto a slot to carry it into combat. Click a slot to empty it." Baselines local 366 and 388 |
| `HintRule` | `HSeparatorPressed`, local (748, 406), 468 wide | |
| `%ConsumableDetails` | (748, 422), 468 wide | `PanelPressed`, grows downward |

**ConsumableRow** (Control, 428×76):
- `%Well` is the deep slot texture at (0, 0); `%Icon` is 64×64 at (4, 4).
- `%Name` is `LabelBookInkDark` at x 88, baseline +30.
- `%Effect` is a RichTextLabel (`RichTextBookDetail`, bbcode on, width 300) at x 88, baseline +56. Its text is `BookText.effect_line(def)`.
- `%Count` is `LabelBookCount`, right edge at x 424, baseline +46. Its text is `BookText.count(qty)`.
- `%Rule` is an `HSeparatorPressed` at y 72–76.
- `%Marks` is a `PanelPrinterMarks` with offsets −8, −8, +4, +4, hidden.
- `_get_drag_data` uses an `ItemDragPreview` instance. Remove the half-alpha ghost.

**HotbarSlot** (PanelContainer, 72×72, `PanelBookBare`):
- `%Well` is a TextureRect showing `InventorySlot.DEEP_TEXTURE` when filled and `InventorySlot.SHALLOW_TEXTURE` when empty.
- `%Icon` is 64×64.
- `%Count` is a `LabelBookTag` anchored to the bottom right, inset 2 px, showing `BookText.count(count)`. It is hidden when the slot is empty.
- `%Marks` is a `PanelPrinterMarks`, offset −6/+6.
- Remove `%Plus`, `%KeyChip` and the key-chip line in the `slot_index` setter. `_get_drag_data` uses `ItemDragPreview`.

**ConsumableDetails** (`PanelPressed`):
- The header holds `IconWell` with `%Icon`, `%NameLabel` (`LabelBookItemName`, autowrap 346) and `%KindLabel` (caps). The kind reads `"CONSUMABLE"`, plus `" · IN SLOT %d" % (slot + 1)` when the item is on the hotbar.
- `%Effects` is a VBox of TableRows:
  - one row per effect: `effect_label(effect)` and `color_madra(effect.describe())`;
  - when the cooldown is above 0, a `COOLDOWN` row with `seconds(cooldown)`.
- `%Description` is `LabelBookInk`, autowrap 434.
- `%Hint` is `LabelBookDetail`, "Drag it onto the hotbar".

**ConsumablesTab behaviour:**
- **Rebuild.**
  - One row per stack, in inventory order. The last row hides its rule.
  - Each row's `hovered` and `clicked` call `_show(def, row)`.
  - `%EmptyLabel` shows only when the list is empty; the details then hide.
  - After a rebuild, keep the shown definition if it is still owned; otherwise show the first.
- **Marks.** `_show(def, pointed)` marks the pointed row or hotbar slot and unmarks the one before. Hovering a filled hotbar slot shows its consumable.
- **On `inventory_changed`.**
  - Rebuild when the stack hash changed, as today.
  - Re-run `show_consumable()` for the shown definition, so `IN SLOT n` stays current.
  - When the shown definition is gone, show the first item.
- **`open_page()`.** Rebuild, then show the first item.
- **Remove** the sort banner, `ConsumablesBanner` and `ConsumablesItemDescriptionBox`.

**ScrollRail.**
- The root is a Control with minimum width 10.
- `Track` is a `NinePatchRect` showing `pressed_groove_ai.png` at full height, with patch margins top and bottom 6.
- `%Grabber` is a `NinePatchRect` showing `pressed_thumb_ai.png`, 4×48, at x 3.
- Delete `TopCap` and `BottomCap`. Keep `bind()` and the positioning maths.
- `InventoryList`'s `ListContainer` keeps separation 4.

- [ ] **Step 1: Write the failing tests**

`test_drop_target_slot.gd`:

```gdscript
extends GutTest

class AcceptingSlot extends DropTargetSlot:
	func _accepts(_data: Variant) -> bool:
		return true

func test_default_drop_hover_still_tints() -> void:
	var slot := AcceptingSlot.new()
	add_child_autofree(slot)
	slot._can_drop_data(Vector2.ZERO, {})
	assert_eq(slot.modulate, DropTargetSlot.HOVER_TINT)
	slot._clear_drop_hover()
	assert_eq(slot.modulate, Color.WHITE)
```

`test_consumables_page.gd`:
- **Fixture.** Instantiate `inventory_view.tscn` on a fresh `InventoryData`, and find `ConsumablesTab`. Make extra consumables with `ConsumableDefinitionData.new()`, a `ChangeVitalsEffectData` and a unique `item_id`.
- **Tests.**
  - `test_rows_show_name_effect_and_count`: with Crude Scale ×7, `%Name` is "Crude Scale", `%Effect.text` is `"[color=#1c2f60]+20 Madra[/color] · 10 s cooldown"`, and `%Count` is "×7".
  - `test_last_row_has_no_rule`: with two kinds, `rows[0]`'s `%Rule` is visible and `rows[1]`'s is not.
  - `test_eight_kinds_scroll`: after 8 kinds and 2 frames, there are 8 rows and the list's `ScrollRail` is visible.
  - `test_hovering_a_row_marks_it_and_shows_it`:
    - after `rows[1].hovered.emit(rows[1])`, `rows[1].is_marked()` is true and `rows[0].is_marked()` is false;
    - `%NameLabel` is the second kind's name and `%KindLabel` is "CONSUMABLE".
  - `test_details_name_the_hotbar_slot`: after `InventoryManager.equip_consumable(crude, 0)`, `%KindLabel` is "CONSUMABLE · IN SLOT 1".
  - `test_hotbar_slot_shows_its_stack_on_a_tag`:
    - Crude ×7 equipped at 3: slot 3's `%Well.texture` is `InventorySlot.DEEP_TEXTURE`, and its `%Count` is visible and reads "×7";
    - slot 0's `%Well.texture` is `InventorySlot.SHALLOW_TEXTURE`, and its `%Count` is hidden.
  - `test_hotbar_keys_are_printed_under_the_slots`: the texts of `KeysRow`'s children are `["1", "2", "3", "4"]`.
  - `test_drag_over_a_hotbar_slot_marks_it_without_tinting`:
    - `slot._can_drop_data(Vector2.ZERO, {"consumable": crude})` leaves `slot.is_marked()` true and `slot.modulate == Color.WHITE`;
    - after `slot._notification(NOTIFICATION_DRAG_END)`, the slot is no longer marked.
  - `test_empty_pack_says_so`: `%EmptyLabel` is visible, `%ConsumableDetails` is hidden, `%ConsumablesHotbar` is visible.
  - `test_details_stay_on_the_shown_item_when_stacks_change` (Review Focus 3): show the second kind, award one more of the first; the details still show the second.
  - `test_using_up_the_shown_item_moves_to_the_first` (Review Focus 4): show the second kind, then call `use_consumable()` until it runs out; the details show the first kind, and no row is marked except the first.
  - `test_huge_stack_fits_its_row` (Review Focus 2): award 1,234,567; `%Count` reads "×1234567", and `PageBounds.escaping_text(tab)` is `[]`.
  - `test_long_names_stay_inside_the_pages` (Review Focus 1): a kind named "Pill of the Thousand Quiet Mornings Beneath the Valley"; both `PageBounds.escaping_text(tab)` and `PageBounds.scaled_text(tab)` are `[]`.
  - `test_pages_have_their_titles`: "Consumables" and "Hotbar".

- [ ] **Step 2: Run them and see them fail.** Expected: FAIL.
- [ ] **Step 3: Build the scenes and scripts as described.**
- [ ] **Step 4: Run the Consumables tests, then the whole suite.**
  - The Consumables tests are `test_consumables_page.gd`, `test_drop_target_slot.gd`, `test_consumables_tab_hotbar_equip.gd` and `test_abilities_book.gd`.
  - Expected: all PASS, and the suite exits 0.
- [ ] **Step 5: Update INVENTORY.md's Consumables parts, delete STYLE_GUIDE K7 and trim K4.**
- [ ] **Step 6: Commit**: `feat(inventory): press the Consumables page into the book`

---

### Task 7: Materials tab

**Files:**
- Create: `scripts/utils/material_sources.gd`, `class_name MaterialSources extends RefCounted`.
- Modify: `materials_tab/materials_tab.tscn` and `.gd`, `material_slot.tscn` and `.gd`; `scenes/inventory/common/inventory_grid/inventory_grid.tscn` (separation 4).
- Create: `materials_tab/material_details/material_details.tscn` and `.gd`.
- Delete:
  - `materials_tab/material_detail_card.*` and `material_tip_card.tscn`;
  - `scenes/inventory/common/item_detail_card/` and `scenes/inventory/common/grid_toolbar/`. No other users remain.
  - `tests/integration/test_item_detail_card.gd`. The spec says to rewrite it, but the component it tests is deleted, and `test_materials_page.gd` covers its replacement.
  - Keep `assets/sprites/inventory/materials_tab/banner.png` (the user's art); just stop using it.
- Modify: `resources/items/materials/spirit_fern.tres` and `dewdrop_tear.tres`:
  - `icon` becomes the Task 1 `_ai` icons;
  - `description` becomes the spec's placeholder lines: "A fern that drinks the valley's aura. Its fronds curl toward a cultivator's core." and "Dew that gathers aura at dawn and keeps it until it is crushed."
- Modify:
  - `docs/inventory/INVENTORY.md`: the Materials parts, and the Work Remaining items this fixes (the card snapping back, the dead trash slot, the tip card);
  - `docs/STYLE_GUIDE.md`: delete row K8, answer K-Q3 ("dropped");
  - `CLAUDE.md`: drop `GridToolbar` and `ItemDetailCard` from the "Inventory chrome" bullet;
  - `docs/CODEBASE_STATE.md`: its ItemDetailCard line.
- Test: `tests/unit/test_material_sources.gd` (new), `tests/integration/test_materials_page.gd` (new), and `tests/unit/test_item_definition_data.gd` (add one test).

**Interfaces:**
- Consumes: `TableRow`, `ScrollRail`, `BookText.count()`, `thousands()` and `yield_text()`, `PageTitle`, `PageBounds`.
- Produces:
  - `MaterialSources.Source` is an inner class (`extends RefCounted`) with `activity_name: String`, `zone_name: String`, `min_quantity: int`, `max_quantity: int` and `interval_seconds: float`.
  - `static func find(material: MaterialDefinitionData) -> Array[MaterialSources.Source]`:
    - for each zone in `ZoneManager.get_map_zones()` whose `get_zone_map_state()` is neither LOCKED nor UNCHARTED;
    - for each `ForageActionData` in `ZoneManager.get_available_actions(zone.zone_id)` that has a loot table;
    - one Source per entry whose `item.item_id == material.item_id`, using `action_name`, `zone_name`, the entry's min and max, and `foraging_interval_in_sec`.
  - `MaterialSlot`: keeps `clicked`; adds `signal hovered(slot: MaterialSlot)`, `set_marked(marked: bool) -> void` and `is_marked() -> bool`.
  - `MaterialDetails extends PanelContainer`: `show_material(def: MaterialDefinitionData, amount: int) -> void`, `clear() -> void`, `get_material() -> MaterialDefinitionData`.

**Layout** (tab-local):

| Node | Rect | Notes |
|---|---|---|
| `LeftTitle` | "Materials" | |
| `%KindsLabel` | centred on x 418 | caps `"%d KINDS"`, baseline local 226 |
| `%MaterialsInventoryGrid` | (192, 244), 452×452 | 6 columns, separation 4; the pressed rail scrolls past 36 |
| `%EmptyLabel` | (192, 244) | "Nothing gathered yet." |
| `RightTitle` | the shown material's name | |
| `%MaterialDetails` | (748, 210), 468 wide | `PanelPressed`, grows downward. Its nodes are listed below |

`%MaterialDetails` holds:
- `IconWell` with `%Icon`;
- `%KindLabel` (caps "MATERIAL");
- `%AmountLabel` (`LabelBookInkDark`, `"You have " + BookText.thousands(n)`);
- `%Description` (`LabelBookInk`, autowrap 434);
- `%Sources`, a VBox with three TableRows per source: `GATHERED BY` (activity), `IN` (zone) and `YIELD` (`yield_text`). It is hidden when there are none.

**MaterialSlot** is a 72×72 TextureRect showing the deep slot:
- `%Icon` is 64×64;
- `%Count` is a `LabelBookTag` at the bottom right, inset 2 px, showing `BookText.count(qty)`;
- `%Marks` is a `PanelPrinterMarks`, offset −6/+6.

**MaterialsTab behaviour:**
- Rebuild on `inventory_changed`, keeping the shown material if it is still owned; otherwise show the first. `%AmountLabel` refreshes.
- `hovered` and `clicked` mark the slot and show it.
- `open_page()` rebuilds, then shows the first material.
- Remove the banner TextureRect, the sort banner and the GridToolbar with its TrashSlot.

- [ ] **Step 1: Write the failing tests**

`test_material_sources.gd`:
- Swap in a fresh `SaveGameData` through `PersistenceManager.save_game_data` and emit `save_data_reset`, as `test_goals_panel.gd` does. Restore the old save after.

```gdscript
func test_spirit_fern_comes_from_spring_forest_foraging_once_unlocked() -> void:
	PersistenceManager.save_game_data.unlock_progression.unlocked_condition_ids.append("q_fill_core_completed")
	var sources: Array[MaterialSources.Source] = MaterialSources.find(load("res://resources/items/materials/spirit_fern.tres"))
	assert_eq(sources.size(), 1)
	assert_eq(sources[0].activity_name, "Spring Forest Foraging")
	assert_eq(sources[0].zone_name, "Spirit Valley")
	assert_eq([sources[0].min_quantity, sources[0].max_quantity], [2, 6])
	assert_eq(sources[0].interval_seconds, 5.0)

func test_dewdrop_yields_one_to_five() -> void: (same unlock) min 1, max 5

func test_locked_activities_are_not_listed() -> void:
	assert_eq(MaterialSources.find(load("res://resources/items/materials/spirit_fern.tres")).size(), 0)
```

`test_materials_page.gd` (fixture: the view on a fresh inventory, Spirit Fern ×4600, Dewdrop Tear ×3300, with foraging unlocked):
- `test_slots_carry_their_counts_on_tags`: the tags read "×4600" and "×3300", and `%KindsLabel` reads "2 KINDS".
- `test_hovering_dewdrop_describes_it`:
  - `RightTitle` reads "Dewdrop Tear" and `%AmountLabel` "You have 3,300";
  - the `%Sources` rows read "GATHERED BY" / "Spring Forest Foraging", "IN" / "Spirit Valley", "YIELD" / "1–5 every 5 s".
- `test_foraging_keeps_the_shown_material` (Review Focus 3): show Dewdrop, award 5 Spirit Fern; the details still show Dewdrop, with the same amount.
- `test_amount_follows_its_stack`: show Dewdrop, award 5 Dewdrop; `%AmountLabel` reads "You have 3,305".
- `test_no_trash_on_the_materials_page`: `tab.find_child("TrashSlot", true, false)` is null.
- `test_a_material_without_sources_hides_the_table`: a new MaterialDefinitionData that no loot table lists; `%Sources` is hidden.
- `test_empty_page_says_so`: `%EmptyLabel` reads "Nothing gathered yet." and the details are hidden.
- `test_huge_counts_fit` (Review Focus 2): with 1,234,567, the tag reads "×1234567", the amount "You have 1,234,567", and `escaping_text` is `[]`.
- `test_long_names_stay_inside_the_pages` (Review Focus 1): a 40-character material name; `escaping_text` and `scaled_text` are `[]`.

`test_item_definition_data.gd` adds `test_spirit_valley_materials_have_their_pressed_icons`: both `.tres` icons point at `spirit_fern_ai.png` and `dewdrop_tear_ai.png`.

- [ ] **Step 2: Run them and see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement MaterialSources, the scenes, the scripts and the `.tres` edits, and delete the dead files.**
- [ ] **Step 4: Run the Materials tests, then the whole suite.**
  - The Materials tests are `test_material_sources.gd`, `test_materials_page.gd`, `test_item_definition_data.gd`, `test_trash_slot_flow.gd` and `test_log_board.gd`.
  - Expected: all PASS, and the suite exits 0.
- [ ] **Step 5: Docs edits as listed.**
- [ ] **Step 6: Commit**: `feat(inventory): press the Materials page into the book`

---

### Task 8: Journal tab

**Files:**
- Modify: `scripts/resource_definitions/quests/quest_step_data.gd`
- Modify: `scenes/ui/goals_panel/goals_panel.gd`. Call the step's new functions and delete `_get_measured_condition`.
- Modify: `singletons/quest_manager/quest_manager.gd`
- Modify: `quest_items_tab/quest_items_tab.tscn` and `.gd`; `journal_row.tscn` and `.gd` (rewrite as `class_name JournalRow extends Control`)
- Create: `quest_items_tab/journal_details/journal_details.tscn` and `.gd`; `quest_items_tab/quest_step_row/quest_step_row.tscn` and `.gd`
- Delete: `quest_journal_card.*` and `wax_seal.tscn`; `tests/integration/test_journal_tab_render.gd`, which `test_journal_page.gd` replaces
- Modify: `resources/items/quest_items/refugee_camp_map.tres`. Its `icon` becomes `refugee_camp_map_ai.png`.
- Modify: `tests/integration/test_tab_banner_title.gd`. Replace the journal test with `test_character_banner_title_at_runtime`, which checks that the Character book's `TitleBanner` reads "Character", so TabBanner keeps a test.
- Modify:
  - `docs/inventory/INVENTORY.md`: the Journal parts; delete the "linked quest deferred" item;
  - `docs/progression/QUESTS.md`: add a line on `get_quest_id_for_item`;
  - `docs/STYLE_GUIDE.md`: delete row K9; answer K-Q1 (books stay, pressed paper) and K-Q2 (Yatra One titles), and G4 for the inventory (64 px).
- Test: `tests/unit/test_quest_step_progress.gd` (new), `tests/unit/test_quest_item_link.gd` (new), `tests/integration/test_journal_page.gd` (new). `tests/integration/test_goals_panel.gd` must pass unchanged.

**Interfaces:**
- Consumes: `BookText.split_for_drop_cap()`, `PageTitle`, `PageBounds`, `InventoryList`.
- Produces:
  - `QuestStepData.get_measured_condition() -> UnlockConditionData`. Today's GoalsPanel rule, moved as is.
  - `QuestStepData.get_progress_text(finished: bool = false) -> String`.
    - Returns `"%d / %d"` of floored current and target, or `""` when nothing is measured.
    - With `finished`, the current value is reported as the target.
  - `QuestManager.get_quest_id_for_item(item: ItemDefinitionData) -> String`. Searches `_quests_by_id` in catalog order:
    - **Needs it:** a step's `completion_conditions` holds an `ITEM_OWNED` condition with `str(target_value) == item.item_id`, and the quest is started (`has_active_quest` or `has_completed_quest`). An active quest wins over a completed one.
    - **Else, gave it:** an `AwardItemEffectData` in `completion_effects` whose `item.item_id == item.item_id`, and the quest is started.
    - **Else** `""`.
  - `JournalRow`:
    - `signal clicked(row: JournalRow)` and `signal hovered(row: JournalRow)`;
    - `setup(item: ItemDefinitionData, second_line: String, done: bool, step_text: String) -> void`;
    - `get_item() -> ItemDefinitionData`, `set_marked(marked: bool) -> void`, `is_marked() -> bool`, `set_rule_visible(rule_visible: bool) -> void`.
  - `JournalDetails extends VBoxContainer`: `show_item(item: ItemDefinitionData) -> void`, `clear() -> void`, `get_item() -> ItemDefinitionData`.
  - `QuestStepRow`: `setup(text: String, ticked: bool, figure: String) -> void`.

**Layout** (tab-local):

| Node | Rect | Notes |
|---|---|---|
| `LeftTitle` | "Journal" | |
| `%CaptionLabel` | | caps "ITEMS OF CONSEQUENCE", baseline local 226 |
| `%JournalList` | (192, 244), 452×546 | an InventoryList; rows 428×76, separation 4 |
| `%EmptyLabel` | | "No quest items yet." |
| `RightTitle` | the shown item's name | |
| `%JournalDetails` | (748, 210), 468 wide | VBox, separation 16. Its two panels are listed below |

`%JournalDetails` holds two `PanelPressed` panels:
- **`%ItemPanel`:**
  - `IconWell` with `%Icon`;
  - `%KindLabel` (caps "QUEST ITEM");
  - `%FromLabel` (`LabelBookDetail`, `"From " + from_source`, hidden when empty);
  - an HBox of `%DropCap` (`LabelBookDropCap`) and `%NarrowText` (`LabelBookInk`, autowrap 390);
  - `%RestText` (`LabelBookInk`, autowrap 434).
  
  Fill the last three from `split_for_drop_cap(description, BM Euljiro, 18, 390, 2)`.
- **`%QuestPanel`:**
  - an HBox of "QUEST" (caps) and `%Seal` (`LabelBookSeal` "DONE", 66×26, shown only when completed);
  - `%QuestName` (`LabelBookQuestName`, autowrap);
  - `%Flavor` (`LabelBookFlavor`, autowrap 434, the quest's `description`);
  - an `HSeparatorPressed`;
  - `%Steps`, a VBox of QuestStepRows. Each row is a `%Tick` TextureRect (tick box ticked or not), `%Text` (`LabelBookStep`) and `%Figure` (`LabelBookDetailDark`, right-aligned).
  
  Hide the whole quest panel for an item with no quest.

**Steps shown:**
- A completed quest ticks every step. Each step's figure is `get_progress_text(true)`.
- An active quest at step index `k`:
  - steps before `k` are ticked, with `get_progress_text(true)`;
  - step `k` is unticked, with `get_progress_text()`;
  - later steps are not shown.

**JournalRow** (Control, 428×76), laid out like ConsumableRow:
- `%Well`, `%Icon`, `%Name` (`LabelBookInkDark`);
- `%SecondLine` (`LabelBookDetail`);
- `%Seal` (`LabelBookSeal` "DONE", 66×26, right edge at x 424);
- `%StepLabel` (`LabelBookDetail`, right-aligned at x 424);
- `%Rule` and `%Marks`.

**Row text:**
- The second line is the quest's name; with no quest, `from_source`.
- `done` is the quest being completed.
- `step_text` is `"Step %d of %d" % [k + 1, steps.size()]` for an active quest, `""` otherwise.

**QuestItemsTab behaviour:**
- Rebuild on `inventory_changed`, keeping the shown item if it is still held, else the first.
- Hovering or clicking a row marks it and shows it.
- The last row's rule is hidden.
- `open_page()` rebuilds, then shows the first item.

- [ ] **Step 1: Write the failing tests**

`test_quest_step_progress.gd`, on a fresh save holding 25 Madra:

```gdscript
func test_event_step_measures_nothing() -> void:
	var step := QuestStepData.new()
	step.completion_event_id = "some_event"
	assert_null(step.get_measured_condition())
	assert_eq(step.get_progress_text(), "")

func test_madra_step_reads_like_the_goals_board() -> void:
	# a step with one RESOURCE_AMOUNT madra >= 100 condition
	assert_eq(step.get_progress_text(), "25 / 100")
	assert_eq(step.get_progress_text(true), "100 / 100")
```

`test_quest_item_link.gd`:
- In `before_each`, keep the old `QuestManager._quests_by_id` and `QuestManager._live_save_data`; in `after_each`, put them back.
- Inject fake QuestData (built in code) and a fresh SaveGameData.

```gdscript
func test_quest_that_gave_it_when_nothing_needs_it() -> void:     # G completed, awards the item -> "G"
func test_quest_that_needs_it_wins() -> void:                      # N active, ITEM_OWNED step; G completed -> "N"
func test_unstarted_quests_are_ignored() -> void:                  # N not started, G completed -> "G"
func test_active_need_wins_over_completed_need() -> void:          # N1 completed needs it, N2 active needs it -> "N2"
func test_no_quest_gives_empty() -> void:                          # -> ""
func test_refugee_camp_map_belongs_to_harden_your_core() -> void:  # real catalog (_build_catalog_index), quest completed -> "q_reach_core_density_10"
```

`test_journal_page.gd`:
- **Fixture.** The view on a fresh inventory that holds the Refugee Camp Map. The real catalog is reloaded, as `test_goals_panel.gd:55-57` does, and `q_reach_core_density_10` is completed in the save.
- **Tests.**
  - `test_row_shows_item_quest_and_seal`: the row's `%Name` is "Refugee Camp Map", its `%SecondLine` "Harden Your Core", and its `%Seal` is visible; its `%StepLabel` is hidden.
  - `test_details_show_where_it_came_from`:
    - `RightTitle` reads "Refugee Camp Map", `%KindLabel` "QUEST ITEM", and `%FromLabel` "From Old Vesh, in the broken shrine";
    - `%DropCap` reads "A", and `%NarrowText` starts with "hand-drawn".
  - `test_finished_quest_ticks_every_step`:
    - there are 2 step rows, both ticked, and the first figure reads "10 / 10";
    - `%Seal` is visible and `%Flavor` holds the quest's description.
  - `test_quest_in_progress_shows_reached_steps_only`:
    - inject a fake active quest of 3 steps at index 1 that needs a fake quest item;
    - the row reads "Step 2 of 3";
    - there are 2 step rows: the first ticked, the second not;
    - `%Seal` is hidden.
  - `test_item_without_a_quest_shows_its_source`: a fake QuestItemDefinitionData with `from_source` "A stranger" that no quest needs or gives. The second line reads "A stranger" and `%QuestPanel` is hidden.
  - `test_empty_journal_says_so`
  - `test_long_names_stay_inside_the_pages` (Review Focus 1): both `escaping_text` and `scaled_text` are `[]`.
  - `test_pages_have_their_titles`

- [ ] **Step 2: Run them and see them fail.** Expected: FAIL.
- [ ] **Step 3: Implement the data functions, refactor GoalsPanel, build the scenes, edit the `.tres` and delete the dead files.**
- [ ] **Step 4: Run the Journal tests, then the whole suite.**
  - The Journal tests are `test_quest_step_progress.gd`, `test_quest_item_link.gd`, `test_journal_page.gd`, `test_goals_panel.gd`, `test_quest_manager.gd`, `test_tab_banner_title.gd` and `test_beat_3b_merchant_unlock.gd`.
  - Expected: all PASS, and the suite exits 0.
- [ ] **Step 5: Docs edits as listed.**
- [ ] **Step 6: Commit**: `feat(inventory): press the Journal page into the book`

---

### Task 9: Docs sweep and in-game check

**Files:**
- Modify:
  - `docs/inventory/INVENTORY.md`: Overview, Architecture, the test list and counts, and Work Remaining (delete the fixed items, page-size mismatch included);
  - `docs/testing/TESTING.md`: the coverage map rows for the new tests;
  - `docs/STYLE_GUIDE.md`: delete K4 if empty; add a short "Pressed paper (the books)" note pointing at the spec;
  - `docs/STATE_OF_THE_GAME.md`: the inventory line.
- Any fixes the check below finds.

- [ ] **Step 1: Run the whole suite.** Expected: exit 0, with no failing or risky tests.
- [ ] **Step 2: Capture the four tabs in the game.**
  - Use the throwaway capture script `.superpowers/capture/capture_inventory.gd` (git-ignored; it lives in this worktree). It runs on an isolated copy of the user's save, so the real save is never touched.
  - **Isolate the save.** Write an `override.cfg` at the repo root:

    ```ini
    [application]
    config/use_custom_user_dir=true
    config/custom_user_dir_name="EndlessPathCaptureTmp"
    ```

    Then copy `%APPDATA%\Godot\app_userdata\EndlessPath\save.tres` into `%APPDATA%\EndlessPathCaptureTmp\`.
  - **Capture.** Run:

    ```bash
    "C:\Program Files (x86)\Godot\Godot_v4.7.2-stable_win64_console.exe" --path . -s res://.superpowers/capture/capture_inventory.gd
    ```

    Set `CAPTURE_OUT` to a scratch folder first.
  - **Clean up.** Delete `override.cfg`.
  - Expected: four 1920×1080 PNGs.
- [ ] **Step 3: Compare the captures with `docs/superpowers/mockups/inventory-pressed/pressed_*_ai.png`.**
  - Check positions, sizes, colours and text.
  - Walk the STYLE_GUIDE §12 checklist: even positions, opaque surfaces, no alpha or tint, text ≥ 13 px, nothing cut off.
  - Fix what differs, re-run the tests, and commit each fix on its own.
- [ ] **Step 4: Update the docs as listed.**
- [ ] **Step 5: Commit**: `docs(inventory): describe the pressed pages as built`

---

## As built

The build departed from this plan where a ruling during the build decided it (the R-numbered rulings are the ones the tests' comments cite) and where the in-game check matched the approved mockups. Each line says what was built differently, and why.

**Every task**
- R1: `test_sort_sub_banner.gd` stays and `test_item_detail_card.gd` went with `ItemDetailCard`: the spec's list of tests to rewrite predates knowing that the Abilities book shares `SortSubBanner` and that nothing else used `ItemDetailCard`.
- R6: The docs follow main's "Keeping Docs Current" rules, which postdate the plan: no CLAUDE.md, STATE_OF_THE_GAME.md or CODEBASE_STATE.md edits, no test list or counts in INVENTORY.md, TESTING.md changed only in its Coverage Gaps and its Directory Layout (`tests/helpers/`), and QUESTS.md lost its "no link back to a quest" item once `get_quest_id_for_item()` existed.
- R8: The whole-suite gate is `tests/run_tests.ps1`, not the one-process command, which exits 0 when a test script fails to parse.

**Art and theme (Tasks 1 to 3)**
- `printed_cross_ai.png` draws the mockup's discard cross (13 px strokes), not a cross inset 2 art px: the approved mockup is the reference.
- R4: Every new muted variant is `#765A43`, on paper and in panels, instead of the spec's `#7D5F47` on paper: one ink, above the 4.56:1 floor on both.
- `pressed_rule.tres` has 2 px top and bottom content margins, not 0: an `HSeparator` draws its style at the style's minimum height, so with 0 the rule never drew.
- One-line tag and filter Labels are as tall as their art (20 and 26 px) through their styles' content margins, not a `custom_minimum_size` on each node.
- Every new Label variant sets a transparent `font_shadow_color`: `pixel_theme`'s base Label draws a shadow the pages must not have.
- R16: `book_theme.tres` gained `RichTextBookValue` (BM Euljiro 18, dark ink) for a table row's value, as the spec's type table prints it.
- R7: `BookText.effect_line()` sets the decimal point before the Madra ink, and `color_madra()` accepts the decimal point's BBCode, since the plan's order escaped the colour tags.
- UI_STYLING.md keeps a ThemeConstants row for `BOOK_MADRA_INK`, as the home of ThemeConstants.

**Page layer (Task 4)**
- `PageTitle` keeps its autowrap, the only way a long title stays on its page, and its `@tool`, so the editor shows the title.

**Equipment (Task 5)**
- R2: The count ends at screen x 816, 16 px before the discard slot, as the spec says, through the bar's separation.
- R9: The gear captions' baseline is the slot's top + 94, as the spec says, not the brief's + 78, which left 2 px between a marked slot's marks and its caption.
- R10: The details panel follows the spec's Dreadbeast Tooth Necklace geometry, shorter items flowing up from its gaps, and the hint shows only while an item's text ends clear of the hint's line: the spec's geometry and its "more than four bonuses" threshold cannot both hold.
- R11, R12 (replacing R5's two-line name cap): The clearance is the necklace's 24 px, whatever the name's line count, so `wants_hint(1, 2, 3)` and `wants_hint(4, 0, 1)` keep the hint.
- R13: A drag-target mark sits on the slot a drop would fill, as `_drop_item()` decides it: over an occupied grid slot only when the swap succeeds, and for an item out of the discard slot where `restore_equipment_instance()` would put it, when that slot is on the page shown.
- Label boxes may start on an odd y, and the slot caption's minimum height and the description's top margin may be odd, where an even spec baseline and the font's metrics force them; every piece of art and every baseline stays even.
- STYLE_GUIDE's K5 row was trimmed to the Scripted Bark icon instead of deleted, since the tab fixed only the rest of the row.

**Consumables (Task 6)**
- R3: The scroll groove sits at screen x 892 to 902, as the spec says, through the list's separation.
- R14: `ConsumableRow` is a container (a 428 × 72 body over its rule, the last row without one), so seven rows fill the spec's 552 px exactly and a wrapped name grows its row.
- R15, R20: A clipping `ListFrame` (460 × 570) holds the list instead of its `ScrollContainer` clipping, so a visible row's printer's marks show whole; a scrolled row can show up to 8 px past the list's top and 10 past its bottom.
- R17: Where the brief's numbers and the approved mockup disagree and the spec is silent, the mockup wins: the row rule at row y 76 to 80, the hotbar's count tag flush right and 2 px up, and the hint as two one-line labels.
- R18: A row's marks reproduce the mockup's rect, (444, 292) to (886, 382) round the first row; the last row's end 6 px under its slot, inside the frame.
- R19: The scroll thumb is proportional, as in the mockup, and travels the groove's floor on even pixels, following both the wheel and scrolls from code.
- A table row's rule sits 8 px under its value's baseline, the Materials mockup's spacing, since at the Consumables mockup's 4 px the descenders touch it.
- `InventoryScrollHost.clear_slots()` removes rows at once, since a rebuild otherwise draws the list a frame off.

**Materials (Task 7)**
- R21: The description flows with no reserved height, and the source table keeps a fixed gap over it sized from Spirit Fern; with no source the table hides with its gap.
- `MaterialDetails.get_shown_material()` (the engine already takes `get_material()`), the mockup's tag inset, shallow empty slots, `1 KIND`, marks 6 px outside a slot, the rail past 36 kinds and a right title hidden on an empty page, each following the spec, the mockup or a sibling tab.

**Journal (Task 8)**
- The step figures use `LabelBookStep`, the quest's header is positioned, a wide drop cap narrows the column beside it, the six-row list shows the top of a seventh (R15's trade-off), and a quest's progress is read when the page opens, each following the mockup or R15.

**The in-game check (Task 9)**
- The right page's titles of Equipment, Consumables and Materials are centred on the spec's x 1244, as the Journal's was, not on screen x 1242, the middle of the plan's box.
- A paper tag's count sits 16 px under the tag's top and a seal's word 18 px under the seal's, as both mockups print them: `LabelBookTag`'s font moves the count 3 px down in its line (a larger top margin would grow the tag), and `seal.tres` has a 4 px top margin.
- The filter's lozenge is pressed from y 294 to 320, as the mockup draws it, with the words still on baseline 316: their font sits 5 px low in its line, and their styles' margins take 6 px over it and 4 under.
- The footer's PAGE ends at x 536 and the page slots start at 556, as the mockup prints them, where the plan began them at the page's left edge.
- A bonus row's rule sits 8 px under its baseline, as the mockup and the other tabs' tables rule it.
- The hotbar hint's rule runs from x 1012 to 1474, as the mockup draws it, not across the plan's 468 px.
- R22 (replacing Task 7's `MATERIAL` at x 1112): The capitals caption in each details panel (`ACCESSORY`, `CONSUMABLE`, `MATERIAL`, `QUEST ITEM`) starts 2 px in, its ink at x 1114 under the name's, where the mockups print it: the spec gives the name's x and no caption x, so the mockup decides (R17).

**The user's review (2026-10-28)**
- The gear slots' names sit just above them, each baseline 4 px over its slot's top (replacing R9): printed under its slot, a name read as the next slot's. The columns start 20 px down the figure, 102 px apart, and the selector is 296 px tall.
- `gear_plate_ai.png` was redrawn: the figure stands 32 px lower, its head and sleeve ends level with the head and hand slots, and it has four straight dotted leaders, three level and the body's level then down onto the right shoulder, and none to the accessories. The sloped leaders stepped unevenly.
- The footer prints no PAGE (replacing Task 9's PAGE at x 536): the page slots start under the grid's first column, 4 px apart, the grid's own gap.
- The filter words sit 4 px higher, on baseline 312, their capitals centred on the lozenge's floor: their font is now 1 px low in its line, not 5 (replacing Task 9's baseline 316). At the mockup's height they read as sinking.
- The consumable's details print no `CONSUMABLE · IN SLOT n` caption and no `Drag it onto the hotbar` hint: the hotbar shows what sits in its slots, and its own line says how to fill one. The name is centred on the slot, padded to an even height by `wrap_pad.tres`, and the panel ends 34 px under the description. `ConsumableDetails.show_consumable()` lost its `hotbar_slot` argument.
- The Materials page prints no `N KINDS` caption; the row over its grid stays empty, kept for a selector. Its details print the count on a `PaperTag` at the panel's top right (`×4,600`, on `MATERIAL`'s baseline) instead of "You have 4,600", and the table says only where to find the material: `FOUND IN` and its zones (`MaterialSources.zone_names()`), not the activity and its yield. `BookText.yield_text()` and `range_text()` went with them.
- The Journal's caption reads `QUEST ITEMS`. The item's description has no drop cap (`LabelBookDropCap` and `BookText.split_for_drop_cap()` went), and a `PaperTag` at the item panel's top right names the zone the item belongs to, from the new `QuestItemDefinitionData.zone_id` (`SpiritValley` on the map).
- The side tabs' icons keep one size, 16 units (32 px), and step with the tab's eight frames on discrete, whole-unit position keys; the scale track (0.95 to 0.75) and the interpolated margins are gone. The icons had slid and shrunk out of step with the frames. The padlock is 7 × 8 units.
- `PaperTag.set_label()` prints any text on a tag, for the two corner tags.

**The user's second review (2026-10-28)**
- The Materials count and the Journal item's zone print in ink at their panels' top right, on the caption's baseline (`4,600` in body-size dark ink, `SPIRIT VALLEY` in capitals), replacing the first review's paper tags: the bright tags and the × read badly in a panel. `PaperTag.set_label()` went with them.
- Font pass: the muted ink darkened from `#765A43` to `#584230` (6.99:1 on a panel, from 4.72:1, replacing R4's ink), and the capitals print at 15 px instead of 13 on the line they had, through a font 1 px higher in its line, so no baseline moved.
- The Equipment details print their bonuses as the tooltip words them, `+2 Strength`, in body-size dark ink, two to a row, instead of a small capital name and its value at the column's edge; `BookText.bonus_lines()` replaced `bonus_pairs()`. The panel prints no hint: `EquipmentDetails.HintMode`, `wants_hint()` and the geometry behind them went (replacing R10 to R12's hint rules; the panel keeps R10's layout).
- The Equipment filter resets to `ALL` whenever the page opens (`open_page()`), so a tab switch or a reopened book starts unfiltered.
- The side tabs' icons are 20 units (40 px), centred on the tab's face between its outline's bracket and the page's edge, 1 to 1.5 units right of where the first review put them.
- The turning page draws one z-level over the books' content (`BookFrame`'s `PageTurningRect`), since its last frames land on the left page where the side tabs, drawn after the book, cut it off.
