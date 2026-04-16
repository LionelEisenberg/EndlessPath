# Assets Folder Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize `assets/` so every file has exactly one home, naming is snake_case, source files are separate from exports, and dead files are gone.

**Architecture:** Purely a file-move + reference-update operation. No new code, no new systems. Each task moves a group of files via `git mv`, updates all `res://` path references in `.tscn`/`.tres`/`.gd` files via find-and-replace, then commits. A final validation task runs `--headless --import` and the GUT suite to confirm nothing broke.

**Tech Stack:** Git, Godot 4.6 CLI (`--headless --import`), GUT test runner, bash (grep/sed for bulk path replacement)

**Important context:** Godot `.tscn`/`.tres` files use `uid://` identifiers alongside `path=` strings. UIDs survive renames, but the `path=` fallback and `.gd` `preload()`/`load()` calls use string paths that MUST be updated. Always update both UID-bearing `path=` strings and direct path strings.

**Working directory:** `C:\Users\lione\Documents\Godot Games\RealProjects\EndlessPath`

---

### Task 1: Delete unused files

**Files:**
- Delete: `assets/Food_01.png` + `.import`
- Delete: `assets/Food_02.png` + `.import`
- Delete: `assets/RPG_Item_Pack_Retro_Spritesheet.png` + `.import`
- Delete: `assets/themes/pixel_ui_theme/8x8_ui_elements.png~`
- Delete: `assets/dialogue/styles/dialogue_backgrounds/custom_background_layer.gd` + `.uid`
- Delete: `assets/ui_images/vecteezy_geometric-design-element_21048718_128x128.xcf`
- Delete: `assets/labelsettings/` (empty dir)
- Delete: `assets/materials/` (empty dir)

- [ ] **Step 1: Verify zero references for the root PNGs**

```bash
cd "C:\Users\lione\Documents\Godot Games\RealProjects\EndlessPath"
grep -r "Food_01\|Food_02\|RPG_Item_Pack" --include="*.tscn" --include="*.tres" --include="*.gd" .
```

Expected: no output (zero matches). If anything matches, do NOT delete that file — investigate first.

- [ ] **Step 2: Delete the files**

```bash
git rm assets/Food_01.png assets/Food_01.png.import
git rm assets/Food_02.png assets/Food_02.png.import
git rm "assets/RPG_Item_Pack_Retro_Spritesheet.png" "assets/RPG_Item_Pack_Retro_Spritesheet.png.import"
git rm "assets/themes/pixel_ui_theme/8x8_ui_elements.png~"
git rm assets/dialogue/styles/dialogue_backgrounds/custom_background_layer.gd
# Also delete the .uid if it exists:
git rm assets/dialogue/styles/dialogue_backgrounds/custom_background_layer.gd.uid 2>/dev/null || true
git rm "assets/ui_images/vecteezy_geometric-design-element_21048718_128x128.xcf"
rm -rf assets/labelsettings assets/materials
```

- [ ] **Step 3: Delete duplicate stat icon PNGs at ui_images/ root**

These 6 PNGs exist at both `ui_images/` root AND `ui_images/stat_icons/`. Only the `stat_icons/` copies are referenced by code. Delete the root duplicates:

```bash
git rm assets/ui_images/combat_icon.png assets/ui_images/combat_icon.png.import
git rm assets/ui_images/health_icon.png assets/ui_images/health_icon.png.import
git rm assets/ui_images/map_icon.png assets/ui_images/map_icon.png.import
git rm assets/ui_images/skull_icon.png assets/ui_images/skull_icon.png.import
git rm assets/ui_images/time_icon.png assets/ui_images/time_icon.png.import
git rm assets/ui_images/victory_icon.png assets/ui_images/victory_icon.png.import
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(assets): delete unused placeholders, backup file, and duplicates"
```

---

### Task 2: Move ui_images/ → sprites/ui/

**Files:**
- Move: `assets/ui_images/ability_button/` → `assets/sprites/ui/ability_button/`
- Move: `assets/ui_images/action_buttons/` → `assets/sprites/ui/action_buttons/`
- Move: `assets/ui_images/buff_icon/` → `assets/sprites/ui/buff_icon/`
- Move: `assets/ui_images/resources/` → `assets/sprites/ui/resources/`
- Move: `assets/ui_images/stat_icons/` → `assets/sprites/ui/stat_icons/`
- Move: `assets/ui_images/system_menu/` → `assets/sprites/ui/system_menu/`
- Delete: `assets/ui_images/` (empty after moves)
- Modify (path references): 16 `.tscn` files, 4 `.gd` files

- [ ] **Step 1: Create destination and move files**

```bash
mkdir -p assets/sprites/ui
git mv assets/ui_images/ability_button assets/sprites/ui/ability_button
git mv assets/ui_images/action_buttons assets/sprites/ui/action_buttons
git mv assets/ui_images/buff_icon assets/sprites/ui/buff_icon
git mv assets/ui_images/resources assets/sprites/ui/resources
git mv assets/ui_images/stat_icons assets/sprites/ui/stat_icons
git mv assets/ui_images/system_menu assets/sprites/ui/system_menu
```

- [ ] **Step 2: Update all res:// path references**

Replace `assets/ui_images/` with `assets/sprites/ui/` in every `.tscn`, `.tres`, and `.gd` file:

```bash
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/ui_images/|assets/sprites/ui/|g' {} +
```

- [ ] **Step 3: Verify no stale references remain**

```bash
grep -r "assets/ui_images/" --include="*.tscn" --include="*.tres" --include="*.gd" .
```

Expected: zero matches. If any remain, fix them manually.

- [ ] **Step 4: Remove the now-empty ui_images/ directory**

```bash
rm -rf assets/ui_images
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(assets): move ui_images/ into sprites/ui/"
```

---

### Task 3: Move images/, lock_icon, and spritesheets/ → sprites/

**Files:**
- Move: `assets/images/path_progression/` → `assets/sprites/path_progression/`
- Move: `assets/lock_icon.png` (+.import) → `assets/sprites/ui/lock_icon.png`
- Move: `assets/spritesheets/Main-Character-8-Direction.png` (+.import) → `assets/sprites/character/main_character_spritesheet.png`
- Delete: `assets/images/`, `assets/spritesheets/` (empty after moves)
- Modify: `scenes/path_progression/path_tree_view.tscn`, `scenes/path_progression/benefit_card.tscn`, `scenes/zones/locked_zone_overlay/locked_zone_overlay.tscn`, `scenes/characters/main_character/character_body_2d.tscn`

- [ ] **Step 1: Move path_progression**

```bash
git mv assets/images/path_progression assets/sprites/path_progression
```

- [ ] **Step 2: Update path_progression references**

```bash
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/images/path_progression/|assets/sprites/path_progression/|g' {} +
```

- [ ] **Step 3: Move lock_icon**

```bash
git mv assets/lock_icon.png assets/sprites/ui/lock_icon.png
git mv assets/lock_icon.png.import assets/sprites/ui/lock_icon.png.import
```

- [ ] **Step 4: Update lock_icon references**

```bash
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/lock_icon\.png|assets/sprites/ui/lock_icon.png|g' {} +
```

- [ ] **Step 5: Move and rename Main-Character spritesheet**

```bash
mkdir -p assets/sprites/character
git mv "assets/spritesheets/Main-Character-8-Direction.png" assets/sprites/character/main_character_spritesheet.png
git mv "assets/spritesheets/Main-Character-8-Direction.png.import" assets/sprites/character/main_character_spritesheet.png.import
```

- [ ] **Step 6: Update Main-Character references**

```bash
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/spritesheets/Main-Character-8-Direction\.png|assets/sprites/character/main_character_spritesheet.png|g' {} +
```

- [ ] **Step 7: Clean up empty directories**

```bash
rm -rf assets/images assets/spritesheets
```

- [ ] **Step 8: Verify no stale references**

```bash
grep -r "assets/images/\|assets/lock_icon\|Main-Character-8-Direction\|assets/spritesheets/" --include="*.tscn" --include="*.tres" --include="*.gd" .
```

Expected: zero matches.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(assets): move path_progression, lock_icon, character spritesheet into sprites/"
```

---

### Task 4: Move asperite/ PNGs → sprites/ (the big move)

The `asperite/` folder contains `.aseprite` source files AND their `.png` exports side by side. Many scenes reference the `asperite/` PNGs directly. This task moves every PNG (and its `.import` file) from `asperite/` to the correct `sprites/` subfolder, then updates all references. The `.aseprite` files stay in `asperite/`.

**Files:**
- Move: ~48 PNGs from `assets/asperite/**/*.png` → `assets/sprites/**/*.png`
- Modify: ~30 files (`.tscn`, `.tres`, `.gd`) with path references
- Keep: all `.aseprite` and `.aseprite.import` files in place

- [ ] **Step 1: Move abilities PNGs**

```bash
git mv assets/asperite/abilities/empty_palm.png assets/sprites/abilities/empty_palm.png
git mv assets/asperite/abilities/empty_palm.png.import assets/sprites/abilities/empty_palm.png.import
git mv assets/asperite/abilities/enforce.png assets/sprites/abilities/enforce.png
git mv assets/asperite/abilities/enforce.png.import assets/sprites/abilities/enforce.png.import
git mv assets/asperite/abilities/power_font.png assets/sprites/abilities/power_font.png
git mv assets/asperite/abilities/power_font.png.import assets/sprites/abilities/power_font.png.import
```

- [ ] **Step 2: Move character_profiles PNGs**

```bash
git mv assets/asperite/character_profiles/PlayerProfile.png assets/sprites/character/player_profile.png
git mv assets/asperite/character_profiles/PlayerProfile.png.import assets/sprites/character/player_profile.png.import
git mv assets/asperite/character_profiles/base_player.png assets/sprites/character/base_player.png
git mv assets/asperite/character_profiles/base_player.png.import assets/sprites/character/base_player.png.import
```

- [ ] **Step 3: Move cycling PNGs**

```bash
git mv assets/asperite/cycling/Background.png assets/sprites/cycling/background.png
git mv assets/asperite/cycling/Background.png.import assets/sprites/cycling/background.png.import
git mv assets/asperite/cycling/Border.png assets/sprites/cycling/border.png
git mv assets/asperite/cycling/Border.png.import assets/sprites/cycling/border.png.import
git mv assets/asperite/cycling/Fill.png assets/sprites/cycling/fill.png
git mv assets/asperite/cycling/Fill.png.import assets/sprites/cycling/fill.png.import
git mv assets/asperite/cycling/madra_circle.png assets/sprites/cycling/madra_circle.png
git mv assets/asperite/cycling/madra_circle.png.import assets/sprites/cycling/madra_circle.png.import
```

- [ ] **Step 4: Move inventory PNGs**

Create the destination structure and move all inventory PNGs:

```bash
mkdir -p assets/sprites/inventory/equipment_grid
mkdir -p assets/sprites/inventory/gear_selector
mkdir -p assets/sprites/inventory/inventory_slot
mkdir -p assets/sprites/inventory/materials_tab
mkdir -p assets/sprites/inventory/tab_switcher

# Root inventory PNGs
git mv assets/asperite/inventory/book_background.png assets/sprites/inventory/book_background.png
git mv assets/asperite/inventory/book_background.png.import assets/sprites/inventory/book_background.png.import
git mv assets/asperite/inventory/book_opening_spritesheet.png assets/sprites/inventory/book_opening_spritesheet.png
git mv assets/asperite/inventory/book_opening_spritesheet.png.import assets/sprites/inventory/book_opening_spritesheet.png.import
git mv assets/asperite/inventory/book_opening_spritesheet_blue.png assets/sprites/inventory/book_opening_spritesheet_blue.png
git mv assets/asperite/inventory/book_opening_spritesheet_blue.png.import assets/sprites/inventory/book_opening_spritesheet_blue.png.import
git mv assets/asperite/inventory/dagger_icon.png assets/sprites/inventory/dagger_icon.png
git mv assets/asperite/inventory/dagger_icon.png.import assets/sprites/inventory/dagger_icon.png.import
git mv assets/asperite/inventory/page_turning_spritesheet.png assets/sprites/inventory/page_turning_spritesheet.png
git mv assets/asperite/inventory/page_turning_spritesheet.png.import assets/sprites/inventory/page_turning_spritesheet.png.import
git mv assets/asperite/inventory/sword_icon.png assets/sprites/inventory/sword_icon.png
git mv assets/asperite/inventory/sword_icon.png.import assets/sprites/inventory/sword_icon.png.import

# equipment_tab/equipment_grid/
for f in assets/asperite/inventory/equipment_tab/equipment_grid/*.png; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/equipment_grid/$base"
done
for f in assets/asperite/inventory/equipment_tab/equipment_grid/*.png.import; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/equipment_grid/$base"
done

# equipment_tab/gear_selector/
for f in assets/asperite/inventory/equipment_tab/gear_selector/*.png; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/gear_selector/$base"
done
for f in assets/asperite/inventory/equipment_tab/gear_selector/*.png.import; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/gear_selector/$base"
done

# equipment_tab/line.png (single loose file)
git mv assets/asperite/inventory/equipment_tab/line.png assets/sprites/inventory/line.png
git mv assets/asperite/inventory/equipment_tab/line.png.import assets/sprites/inventory/line.png.import

# inventory_slot/
for f in assets/asperite/inventory/inventory_slot/*.png; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/inventory_slot/$base"
done
for f in assets/asperite/inventory/inventory_slot/*.png.import; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/inventory_slot/$base"
done

# materials_tab/
for f in assets/asperite/inventory/materials_tab/*.png; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/materials_tab/$base"
done
for f in assets/asperite/inventory/materials_tab/*.png.import; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/materials_tab/$base"
done

# tab_switcher/
for f in assets/asperite/inventory/tab_switcher/*.png; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/tab_switcher/$base"
done
for f in assets/asperite/inventory/tab_switcher/*.png.import; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/inventory/tab_switcher/$base"
done
```

- [ ] **Step 5: Move UI resource bar PNGs**

```bash
mkdir -p assets/sprites/ui/resource_bar
for f in assets/asperite/ui/resource_bar/*.png; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/ui/resource_bar/$base"
done
for f in assets/asperite/ui/resource_bar/*.png.import; do
  base=$(basename "$f")
  git mv "$f" "assets/sprites/ui/resource_bar/$base"
done
```

- [ ] **Step 6: Move zones PNGs**

Check references first — these may be unused since PR #23 replaced zone encounter icons:

```bash
grep -r "asperite/zones/" --include="*.tscn" --include="*.tres" --include="*.gd" .
```

If referenced, move them to `assets/sprites/zones/`. If unreferenced, delete them:

```bash
# If unreferenced (expected):
git rm assets/asperite/zones/*.png assets/asperite/zones/*.png.import
# If referenced: git mv to assets/sprites/zones/ and update references
```

- [ ] **Step 7: Bulk update all asperite/ path references**

This is the critical step. Replace every `asperite/` PNG path with its new `sprites/` location:

```bash
# abilities
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/abilities/|assets/sprites/abilities/|g' {} +

# character_profiles → character (with renames)
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/character_profiles/PlayerProfile\.png|assets/sprites/character/player_profile.png|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/character_profiles/base_player\.png|assets/sprites/character/base_player.png|g' {} +

# cycling (PascalCase → snake_case renames)
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/cycling/Background\.png|assets/sprites/cycling/background.png|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/cycling/Border\.png|assets/sprites/cycling/border.png|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/cycling/Fill\.png|assets/sprites/cycling/fill.png|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/cycling/madra_circle\.png|assets/sprites/cycling/madra_circle.png|g' {} +

# inventory — flatten the equipment_tab/ nesting
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/equipment_tab/equipment_grid/|assets/sprites/inventory/equipment_grid/|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/equipment_tab/gear_selector/|assets/sprites/inventory/gear_selector/|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/equipment_tab/line\.png|assets/sprites/inventory/line.png|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/inventory_slot/|assets/sprites/inventory/inventory_slot/|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/materials_tab/|assets/sprites/inventory/materials_tab/|g' {} +
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/tab_switcher/|assets/sprites/inventory/tab_switcher/|g' {} +
# Root inventory PNGs (dagger_icon, sword_icon, book_*, page_turning_*)
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/inventory/|assets/sprites/inventory/|g' {} +

# ui/resource_bar
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/ui/resource_bar/|assets/sprites/ui/resource_bar/|g' {} +
```

- [ ] **Step 8: Verify no stale asperite/ PNG references remain**

```bash
grep -r "asperite/.*\.png" --include="*.tscn" --include="*.tres" --include="*.gd" . | grep -v "\.aseprite"
```

Expected: zero matches for PNG references. `.aseprite` file references in `.aseprite.import` files are OK.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(assets): move asperite/ PNG exports into sprites/ by system"
```

---

### Task 5: Renames — asperite folder, Spirit Valley, bar_scroll typo, parallax layers

**Files:**
- Rename: `assets/asperite/` → `assets/aseprite/`
- Rename: `assets/sprites/zones/backgrounds/background 1 - Spirit Valley/` → `assets/sprites/zones/backgrounds/spirit_valley/`
- Rename: parallax layers `0.png`–`11.png` → `layer_00.png`–`layer_11.png`
- Rename: `assets/sprites/inventory/equipment_grid/bar_scroll..png` → `bar_scroll.png`
- Modify: `scenes/zones/zone_view_background/zone_view_background.gd` (Spirit Valley path constant + layer filename pattern)
- Modify: `scenes/zones/zone_view_background/zone_view_background.tscn` (if it references layers directly)

- [ ] **Step 1: Rename asperite → aseprite**

```bash
git mv assets/asperite assets/aseprite
```

Update any remaining references (`.aseprite.import` files contain `source_file` paths — these auto-fix on `--import`). Check for code references:

```bash
grep -r "asperite" --include="*.tscn" --include="*.tres" --include="*.gd" .
```

Fix any matches with sed:

```bash
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|assets/asperite/|assets/aseprite/|g' {} +
```

- [ ] **Step 2: Rename Spirit Valley folder**

```bash
git mv "assets/sprites/zones/backgrounds/background 1 - Spirit Valley" assets/sprites/zones/backgrounds/spirit_valley
```

- [ ] **Step 3: Rename parallax layer files**

```bash
cd assets/sprites/zones/backgrounds/spirit_valley
for i in $(seq 0 11); do
  old="$i.png"
  new=$(printf "layer_%02d.png" $i)
  git mv "$old" "$new"
  git mv "$old.import" "$new.import"
done
cd -
```

- [ ] **Step 4: Update zone_view_background.gd**

Read `scenes/zones/zone_view_background/zone_view_background.gd` and update:

1. The `SPIRIT_VALLEY_PATH` constant: change from `"res://assets/sprites/zones/backgrounds/background 1 - Spirit Valley/"` to `"res://assets/sprites/zones/backgrounds/spirit_valley/"`

2. The layer loading pattern: wherever it loads `str(i) + ".png"`, change to `"layer_%02d.png" % i` (or whatever the current loop pattern is — read the code first).

Also update `scenes/zones/zone_view_background/zone_view_background.tscn` if it hardcodes any layer paths.

- [ ] **Step 5: Fix bar_scroll..png typo**

```bash
git mv "assets/sprites/inventory/equipment_grid/bar_scroll..png" assets/sprites/inventory/equipment_grid/bar_scroll.png
git mv "assets/sprites/inventory/equipment_grid/bar_scroll..png.import" assets/sprites/inventory/equipment_grid/bar_scroll.png.import
```

Update references (note: references were already updated in Task 4 to point to `sprites/inventory/equipment_grid/bar_scroll..png` — now fix the double-dot):

```bash
find . -not -path "./.godot/*" -not -path "./.claude/*" \( -name "*.tscn" -o -name "*.tres" -o -name "*.gd" \) -exec sed -i 's|bar_scroll\.\.png|bar_scroll.png|g' {} +
```

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(assets): fix asperite typo, rename Spirit Valley, fix bar_scroll"
```

---

### Task 6: Validate

- [ ] **Step 1: Run Godot --import**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless --path . --import
```

Expected: completes without new script errors. UID warnings for unrelated files are OK. Any error mentioning a file we moved means a reference was missed — grep for the old path and fix it.

- [ ] **Step 2: Run GUT test suite**

```bash
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```

Expected: 268/268 passing (or current baseline). Zero new failures.

- [ ] **Step 3: Verify no stale references**

```bash
# Check for any remaining references to old paths
grep -r "assets/ui_images/\|assets/images/\|assets/spritesheets/\|asperite/" --include="*.tscn" --include="*.tres" --include="*.gd" . | grep -v "\.aseprite"
```

Expected: zero matches.

- [ ] **Step 4: Spot check folder structure**

```bash
ls assets/
# Expected: aseprite  audio  colors  dialogue  fonts  scroll  shaders  sprites  styleboxes  themes

ls assets/sprites/
# Expected: abilities  adventure  atmosphere  character  combat  cycling  inventory  path_progression  tilemap  ui  zones

ls assets/aseprite/
# Expected: only .aseprite files and .aseprite.import files, NO .png files
```

- [ ] **Step 5: Commit any fixups (if needed)**

If Steps 1-4 revealed issues, fix and commit:

```bash
git add -A
git commit -m "fix(assets): fixup stale references from reorg"
```
