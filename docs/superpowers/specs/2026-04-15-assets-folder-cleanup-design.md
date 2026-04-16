# Assets Folder Reorganization Design

## Goal

Clean up `assets/` so every file has exactly one home, naming is consistent (snake_case, no typos), source files are separated from exports, and unused files are removed.

## Principles

1. **One PNG, one home** — exported PNGs live under `sprites/` organized by game system. No duplicates across `asperite/`, `sprites/`, and `ui_images/`.
2. **Source files are source-only** — `aseprite/` holds `.aseprite` working files. Exported PNGs do NOT live next to their sources.
3. **snake_case everywhere** — folder and file names use snake_case. No spaces, no PascalCase filenames, no double-dot typos.
4. **Delete the dead** — unused placeholder files and empty directories go away.

## Target Structure

```
assets/
  aseprite/                  (RENAMED from "asperite/" — fix typo)
    abilities/               (.aseprite files only)
    character_profiles/
    cycling/
    inventory/
      equipment_tab/
        equipment_grid/
        gear_selector/
      inventory_slot/
      materials_tab/
      tab_switcher/
    ui/
      ability_button/
      buff_icon/
      resource_bar/
    zones/
  audio/
    music/
    sfx/
  colors/                    (keep — has default_color_palette.tres)
  dialogue/                  (unchanged)
  fonts/                     (unchanged)
  scroll/                    (unchanged)
  shaders/                   (unchanged)
  sprites/
    abilities/               (existing — ability icon PNGs)
    adventure/               (existing — encounter glyphs, adventure marker)
    atmosphere/              (existing — mist, motes, aura, smoke veil)
    character/               (NEW — character spritesheet, profiles)
    combat/                  (existing — enemies)
    cycling/                 (existing — cycling backgrounds)
    inventory/               (NEW — equipment/material slot art from asperite exports)
    path_progression/        (MOVED from images/path_progression/)
      node_frames/
    tilemap/                 (existing — hex tiles, forest atlas, path texture)
    ui/                      (MERGED from ui_images/)
      ability_button/
      action_buttons/
      buff_icon/
      resources/
      stat_icons/
      system_menu/
    zones/                   (existing — parallax backgrounds)
      backgrounds/
        spirit_valley/       (RENAMED from "background 1 - Spirit Valley/")
  styleboxes/                (unchanged)
  themes/                    (unchanged)
```

## Deletions

| File/Folder | Reason |
|-------------|--------|
| `assets/Food_01.png` (+.import) | Unused placeholder — zero references in .tscn/.tres/.gd |
| `assets/Food_02.png` (+.import) | Unused placeholder — zero references |
| `assets/RPG_Item_Pack_Retro_Spritesheet.png` (+.import) | Unused placeholder — zero references |
| `assets/themes/pixel_ui_theme/8x8_ui_elements.png~` | Backup file (tilde suffix) — should not be in git |
| `assets/dialogue/styles/dialogue_backgrounds/custom_background_layer.gd` | Unreferenced `@tool` stub — zero references in codebase |
| `assets/labelsettings/` | Empty directory |
| `assets/materials/` | Empty directory |
| `assets/images/` | Emptied after moving path_progression/ to sprites/ |
| `assets/ui_images/` | Emptied after merging into sprites/ui/ |
| `assets/spritesheets/` | Emptied after moving character spritesheet to sprites/character/ |
| `assets/ui_images/vecteezy_*.xcf` | GIMP project file — source art, not a game asset |
| Duplicate stat icons at `ui_images/` root | `combat_icon.png`, `health_icon.png`, `map_icon.png`, `skull_icon.png`, `time_icon.png`, `victory_icon.png` are duplicated at BOTH `ui_images/` root AND `ui_images/stat_icons/`. Keep only the `stat_icons/` versions (verify references first, update if needed). |

## PNG Exports Removed from aseprite/

All `.png` files inside `aseprite/` subfolders are deleted. These are Aseprite auto-exports that duplicate the canonical PNGs in `sprites/`. The `.aseprite` source files and their `.aseprite.import` metadata stay.

Affected folders and approximate counts:
- `aseprite/abilities/` — 3 PNGs
- `aseprite/character_profiles/` — 2 PNGs
- `aseprite/cycling/` — 4 PNGs
- `aseprite/inventory/**` — ~28 PNGs across 5 subfolders
- `aseprite/ui/resource_bar/` — 5 PNGs
- `aseprite/zones/` — 6 PNGs

**Pre-check before deleting:** For each PNG in `aseprite/`, grep the codebase for its `res://` path. If a `.tscn`/`.tres` references the `aseprite/` copy (rather than the `sprites/` copy), update the reference to point to the correct `sprites/` location BEFORE deleting.

## Moves

| From | To | Notes |
|------|----|-------|
| `assets/ui_images/ability_button/` | `assets/sprites/ui/ability_button/` | |
| `assets/ui_images/action_buttons/` | `assets/sprites/ui/action_buttons/` | |
| `assets/ui_images/buff_icon/` | `assets/sprites/ui/buff_icon/` | |
| `assets/ui_images/resources/` | `assets/sprites/ui/resources/` | |
| `assets/ui_images/stat_icons/` | `assets/sprites/ui/stat_icons/` | |
| `assets/ui_images/system_menu/` | `assets/sprites/ui/system_menu/` | |
| `assets/images/path_progression/` | `assets/sprites/path_progression/` | |
| `assets/lock_icon.png` (+.import) | `assets/sprites/ui/lock_icon.png` | |
| `assets/spritesheets/Main-Character-8-Direction.png` (+.import) | `assets/sprites/character/main_character_spritesheet.png` | Rename to snake_case |

## Renames (in-place)

| Old | New | Referenced by |
|-----|-----|---------------|
| `assets/asperite/` | `assets/aseprite/` | .aseprite.import files (will regenerate on --import) |
| `sprites/zones/backgrounds/background 1 - Spirit Valley/` | `sprites/zones/backgrounds/spirit_valley/` | zone_view_background.gd/.tscn |
| Parallax layers `0.png`–`11.png` inside spirit_valley/ | `layer_00.png`–`layer_11.png` | zone_view_background.tscn |
| `aseprite/inventory/equipment_tab/equipment_grid/bar_scroll..png` | `bar_scroll.png` (fix double-dot) | equipment_grid.tscn, inventory_view.tscn (via UID) |

## Reference Update Strategy

Every move or rename requires updating all files that reference the old `res://` path. The process per file:

1. `grep -r "old/path" --include="*.tscn" --include="*.tres" --include="*.gd"` in project root
2. Replace old path with new path in every match
3. Delete old `.import` file (Godot regenerates on next `--import`)
4. Run `--headless --import` after all moves to rebuild the import cache

UID-based references (`uid://...`) in `.tscn`/`.tres` files do NOT break on rename — Godot resolves UIDs independently of file paths. But the `path=` fallback string next to the UID should still be updated for readability and for cases where the UID cache is stale.

## Out of Scope

- Reorganizing `styleboxes/` — already organized by system, low value
- Reorganizing `themes/pixel_ui_theme/` internals — this is a third-party theme pack, leave it as-is
- Renaming PascalCase files inside `aseprite/inventory/inventory_slot/` (e.g., `UI_NoteBook_Slot01a.png`) — these are Aseprite source names, renaming them risks breaking the Aseprite → export pipeline
- Audio folder structure — empty, nothing to reorganize

## Validation

After all moves, renames, and deletions:
1. Run `--headless --import` — zero new errors
2. Run the GUT test suite — 268/268 passing
3. Launch the game and verify: zone map loads, adventure loads, inventory opens, cycling opens
4. `git diff` — no unexpected file changes beyond what's listed above
