# UI Styling
Last updated: 2026-10-19

All UI text in the game flows through a **Label theme variant type-scale** defined in `assets/themes/pixel_theme.tres`. Use variants instead of inline size overrides so the type hierarchy stays consistent and global tuning is possible in one place.

`pixel_theme.tres` is the project-wide theme (`project.godot` → `gui/theme/custom`). `MainView`, `AdventureView` and several sub-scenes also assign it explicitly. Theme defaults:

- **Font:** `assets/fonts/BMEULJIROTTF.ttf` at `default_font_size = 14`.
- **Base `Label`:** sets only colours. Font colour is beige `#F0E8D8`. Shadow colour is opaque dark ink `#1A1208`, so every Label draws Godot's default 1 px drop shadow unless a variant overrides it.
- **Bare Label size:** no font size is set on `Label`, so a Label without a variant renders at 14 px.

## Rule of thumb

1. **Find the variant whose size matches** what you need → set `theme_type_variation = &"LabelX"` on the node
2. **If the color is unique** to this context (teal accent, HUD white, resource-specific gold), add `theme_override_colors/font_color` on top of the variant
3. **If no variant has the size you need**, use the closest variant + a `theme_override_font_sizes/font_size` override — this keeps the variant's color/outline/shadow but lets you tweak size. Prefer this over pure direct overrides.
4. **Only fall back to fully direct overrides** for one-off HUD labels (floating damage, cooldown timers, buff stacks) where no variant makes semantic sense, or for `RichTextLabel` nodes which can't consume Label variants

Never write `theme_override_font_sizes/font_size = X` on a bare Label without first checking if a variant matches. If you find yourself adding the same `{size + color}` combo across 3+ scenes, add a new variant to the theme instead.

## General-purpose Label variants

These are size-based and drop into any scene. Colours: Beige `#F0E8D8`, Gold `#D4A84A`, Tan `#A89070`, Green `#7DCE82`, Red `#E06060`.

| Variant | Size | Color | Use for |
|---------|------|-------|---------|
| `LabelTitle` | 50px | Gold + shadow (black 60%, offset 2,2) | Main panel titles (path tree, abilities, character) |
| `LabelTitleSmall` | 40px | Gold | Zone titles, secondary headers |
| `LabelHeading` | 36px | Gold | Subsection headings |
| `LabelValueLarge` | 34px | Gold | Big value numbers |
| `LabelBodyLarge` | 28px | Beige | Large body text (cycling resource panel; the unused InkbrushButton) |
| `LabelMuted` | 26px | Tan | Secondary/muted text |
| `LabelSubheading` | 24px | Tan | Subtitle text under titles |
| `LabelBody` | 22px | Beige | Standard body text |
| `LabelValueMedium` | 22px | Gold | Medium gold values (merchant shop prices) |
| `LabelGreen` | 20px | Green | Positive/buff indicators |
| `LabelRed` | 20px | Red | Negative/debuff indicators |
| `LabelBodySmall` | 16px | Beige | Small body text, menu buttons, HUD text |
| `LabelSmall` | 14px | Beige | Tiny labels, material counts |

## Scoped variants (tight contexts, don't reuse broadly)

- **Adventure end card scroll:**
  - `LabelEndCardTitle` 96px dark gold `#8B6914`, shadow black 30% (2,2)
  - `LabelEndCardSection` 30px dark brown `#33261A`, shadow black 75% (1,1)
  - `LabelEndCardDefeatReason` 26px dark gold `#8B6914`
  - `LabelEndCardStatValue` 22px dark brown `#33261A`
  - `LabelEndCardStatName` 18px brown `#735926`
  - `LabelEndCardMuted` 12px muted brown `#806B54` at 80% alpha
- **Ability card text** (all with a 2px `#1A1208` outline for legibility — don't substitute general variants): `LabelAbilityTitle` 34px beige / `LabelAbilityBody` 18px beige / `LabelAbilityMuted` 16px tan
- **Item description panel** (light background): `LabelDescItemName` 32px black / `LabelDescItemType` 20px gray `#606060`
- **Ability stats display:** `LabelSeparatorDot` 26px copper `#C4884A` — dot separators (assigned in code by `ability_stats_display.gd`)
- **Inventory chrome.** These labels set `scale = Vector2(0.5, 0.5)` to cancel the `InventoryView` root's 2x scale. The text then rasterizes at native resolution instead of being upscaled and blurred, so the variant size is the on-screen size.
  - `LabelInventoryCount` 24px dark ink `#33261A` — `GridToolbar` count text ("8 / 60" etc.) on the parchment background
  - `LabelInventorySort` 38px beige — `SortSubBanner` pill label ("All", "Weapons" etc.) on the dark pill background
  - `LabelInventorySignage` 48px dark ink `#33261A` — `TabBanner` signage title ("Equipment" etc.); `GearSelector`'s "Gear Selector" title uses it with a 30px size override
  - These are scoped: they only render correctly when their Label has `scale = 0.5` and an appropriate `pivot_offset`. Don't use them outside the inventory chrome.
- **Merchant shop (zone themes).** These variants are not in `pixel_theme.tres`. Each zone's merchant theme defines them, for example `assets/themes/merchant/spirit_valley_merchant_theme.tres` (styleboxes in `assets/styleboxes/merchant/`). `MerchantView` sets the merchant's `shop_theme` as its root `theme`; everything else (the Label type scale, red and green states, gold values) falls back to `pixel_theme.tres`. A new zone adds one Theme file with the same entries.
  - `MerchantPanel` (PanelContainer) — dark tinted shop panel with a glowing edge. It is 95% opaque: the log and quest windows sit under the shop, and their text reads through a lighter panel. Its content margins are left at the border width, so `MerchantAtmosphere` reaches the border; the 16px / 12px padding lives in `MerchantView`'s `ContentMargin`
  - `MerchantRow` (PanelContainer) — translucent stock row with a thin luminous edge
  - `MerchantButton` (Button) — Buy and Leave, 20px; every state, disabled included. No StyleBoxFlat shadow: Godot draws it under a translucent box, which fills the button
  - `LabelMerchantTitle` (base `LabelTitle`) — `LabelTitle`'s gold colour and 2px drop shadow, inherited from `pixel_theme.tres`, plus a zone-coloured glow (10px outline at low alpha). It repeats `LabelTitle`'s 50px size: `pixel_theme.tres` sets `default_font_size = 14`, and Godot returns that default for `LabelMerchantTitle` before it reaches `LabelTitle`. Colours and constants have no theme default, so they inherit. `test_title_matches_label_title_in_game` fails if the two sizes drift apart
  - `LabelMerchantGreeting` (base `LabelSubheading`) — the greeting under the title. It keeps `LabelSubheading`'s tan and shadow from `pixel_theme.tres` at 16px, and the label wraps (`autowrap_mode` word smart) across the header. The size is set in the zone theme for the same reason as the title's: otherwise `pixel_theme.tres`'s default font size answers first. `test_greeting_is_smaller_than_a_subheading_in_game` checks both
  - `HSeparatorMerchant` (HSeparator) — 1px zone-coloured divider, 8px inset, separation 24
  - `MerchantAtmosphere` colours `mist`, `mote_primary`, `mote_secondary`, `light`, `slot_glow` — read in code with `get_theme_color()` by `MerchantAtmosphere` and `MerchantStockRow` and applied as `modulate`
  - `MerchantAtmosphereMask` (Panel) — the shape `MerchantAtmosphere` clips its light, mist and motes to (`clip_children`). It is opaque, with corners rounded to the panel's inner radius (corner radius minus border width). It is a separate type because making `MerchantAtmosphere` a Panel variation would hide its colours from a zone theme that doesn't declare that variation

## RichTextLabel variants

RichTextLabels **cannot** use Label-based variants (different base type). Only one RTL variant exists:
- `RichTextLabelDark` — dark brown default color `#2A1A12` for light backgrounds (`ItemDescriptionPanel`, `ItemDetailCard`, `QuestJournalCard`)

For RTLs that need a custom size, set `theme_override_font_sizes/normal_font_size` directly. Match one of the Label variant sizes for visual consistency (e.g. use 22 if body text elsewhere uses `LabelBody`).

## HSeparator variants

- Base `HSeparator` (no variant) — 2px copper `#C4884A` line, inset 8px at each end.
- `HSeparatorTooltip` — 1px separator with **no inset**, muted brown `#6B4A30` at 50% alpha, separation 6. Use for tooltip and ability card detail dividers (ability card, path node tooltip, attribute tooltip).
- `HSeparatorItemDesc` — 2px parchment `#E9CEAD`, no inset, separation 12. Top separator under the item type in `ItemDescriptionPanel`, `ItemDetailCard`, `QuestJournalCard`.
- `HSeparatorItemDescThin` — 1px parchment `#E9CEAD`, inset 100px at each end, separation 10. Separates the description from the effects in the same panels.
- `HSeparatorResourcePanel` — 2px gold `#D4A84A` at 60% alpha, no inset. Divider between the Madra and Core Density orbs in `ZoneResourcePanel`.

## Other variants

| Variant | Base type | Style | Used by |
|---------|-----------|-------|---------|
| `ButtonEndCard` | `Button` | Scroll button styleboxes (`assets/styleboxes/buttons/scroll/`), 20px, cream font `#F0E0C2` | `AdventureEndCard` Return button |
| `CyclingTabContainer` | `TabContainer` | `common/tab_*` styleboxes; selected gold, unselected tan, hovered beige | `CyclingView` |
| `PanelAbilityCard` | `PanelContainer` | `abilities/card_normal.tres` (dark brown, 2px brown border) | `AbilityCard` |
| `PanelAccent` | `PanelContainer` | `common/panel_accent.tres` (brown 92%, 3px copper border) | `CyclingView` |
| `PanelLootTray` | `PanelContainer` | `common/panel_loot_tray.tres` (translucent parchment) | `AdventureEndCard` |
| `PanelStatPill` | `PanelContainer` | `abilities/stat_pill.tres` (small dark pill) | `StatLabel` |
| `PanelTooltip` | `PanelContainer` | `abilities/tooltip_panel.tres` (dark brown, 2px copper border) | Ability/buff tooltips, `CombatantInfoPanel`, `AttributeTooltip`, `StatTooltip` (set in code) |
| `PanelDark` | `PanelContainer` | `common/panel_dark.tres` (dark texture) | Unused |

Base types without a variant:

- `Panel` and `PanelContainer` default to `common/panel_tan.tres` (tan parchment texture).
- `Button` uses `buttons/button_default_normal.tres`, `button_default_pressed.tres`, and `button_default_hover.tres` for both hover and disabled, with a gold hover/pressed font colour. `button_default_disabled.tres` is referenced only by `ability_card.tscn`.

## Pattern examples

**Good — size matches a variant, color is unique to this context:**
```
theme_type_variation = &"LabelBody"
theme_override_colors/font_color = Color(0.55, 0.75, 0.72, 1)  # teal Madra accent
```

**Good — size matches exactly, default variant color works:**
```
theme_type_variation = &"LabelSubheading"
```

**Good — close match, use variant for color inheritance + size override:**
```
theme_type_variation = &"LabelHeading"   # inherits gold
theme_override_font_sizes/font_size = 18  # but at 18px
```

**Good — HUD label keeps white+outline overrides on top of a variant:**
```
theme_type_variation = &"LabelBodySmall"
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
```

**Avoid — inline size+color with no variant:**
```
theme_override_colors/font_color = Color(0.941, 0.91, 0.847, 1)  # default beige
theme_override_font_sizes/font_size = 22  # when LabelBody already exists at 22px beige
```

## Label testing scene

Visual reference for variants: `tests/label_tests/label_testing_scene.tscn` (script `label_testing_scene.gd`; not collected by GUT). Open it in the editor and run it with F6. Each variant row shows stats, then samples on dark and light backgrounds in six columns: the theme font, plus BMEULJIROTTF, Pixelmix, Korean Calligraphy, YatraOne and Ubage at "matched" sizes. Update this scene's `LABEL_VARIANTS` array when adding or renaming variants.

**The scene is currently stale.** It was last updated on 2026-04-13, the same day the font swap reduced every size by 2px. So:

- `LABEL_VARIANTS` holds 23 entries (base `Label`, 21 variants, `TooltipLabel`) with pre-swap values, for example `LabelTitle` 52 and `LabelEndCardTitle` 128.
- It is missing `LabelBodyLarge`, `LabelBodySmall`, `LabelSmall`, `LabelTitleSmall`, `LabelInventoryCount`, `LabelInventorySort` and `LabelInventorySignage`.
- `_create_sample_panel()` always applies the array's `font_size`, so samples render at those stale sizes rather than the theme's.
- The first column is still labelled "m5x7", although the theme font is now BMEULJIROTTF.

Until it is refreshed, trust `pixel_theme.tres` and the tables above over the scene.

## Source of truth

`assets/themes/pixel_theme.tres` is the source of truth for all variant sizes and colors. When you change a variant, update this doc and the testing scene to match.

## Code-side constants (ThemeConstants)

`scripts/utils/theme_constants.gd` (`class_name ThemeConstants`) mirrors the palette for code that sets colours at runtime. Its header calls it the "single source of truth"; in practice the theme file is.

| Constant | Value | Matches in theme | Referenced in code |
|----------|-------|------------------|--------------------|
| `ACCENT_GOLD` | `#D4A84A` | Gold Label variants | 8 times: `AbilitiesView`, `CyclingTechniqueSlot`, path tree nodes (`path_node_container.gd`, `path_node_ui.gd`), `SystemMenuButton` hover |
| `BORDER_PRIMARY` | `#C4884A` | `LabelSeparatorDot`, base `HSeparator` | 3 times |
| `BG_MEDIUM` | `#3D2E22` | — | 2 times |
| `TEXT_LIGHT` / `TEXT_MUTED` / `TEXT_DARK` | `#F0E8D8` / `#A89070` / `#1A1208` | Beige / tan / Label shadow | Unused |
| `ACCENT_GREEN` / `ACCENT_RED` | `#7DCE82` / `#E06060` | `LabelGreen` / `LabelRed` | Unused |
| `BG_DARK` | `#2A1A12` | `RichTextLabelDark` | Unused |
| `BG_LIGHT`, `TINT_*`, `BORDER_SUBTLE`, `HOVER_BG`, `PRESSED_BG`, `DISABLED_*` | — | — | Unused |
| `FONT_TITLE` 42 / `FONT_HEADING` 28 / `FONT_BODY` 20 / `FONT_LABEL` 16 / `FONT_CAPTION` 12 | — | **Do not match** the variant scale above | Unused |
| `BORDER_WIDTH_*`, `CORNER_RADIUS_*`, `CONTENT_MARGIN_*` | — | — | Unused |

Use the Label variants for sizes. Use `ThemeConstants` only for colours that must be set from code.

## Theme and asset files

| Path | Contents |
|------|----------|
| `assets/themes/pixel_theme.tres` | Project theme: base types, all variants above |
| `assets/themes/pixel_ui_theme/` | Third-party pixel UI pack: `8x8_ui_elements*.png` and `8x8_ui_icons.png` atlases, `m5x7.ttf`, 8 colour-variant `PixelTheme-*.tres`, `TabContainer.tscn`. `pixel_theme.tres` uses only the two base atlases; the variant themes are not referenced by the game. |
| `assets/styleboxes/` | StyleBox `.tres` grouped by area: `abilities`, `adventure`, `buttons` (+`scroll`), `combat`, `common`, `cycling`, `inventory`, `textures`, `ui`, `zones` |
| `assets/fonts/` | `BMEULJIROTTF.ttf` (theme font). `Korean_Calligraphy.ttf`, `pixelmix.ttf`, `Ubage-woA3P.otf` and `YatraOne-Regular.ttf` are loaded only by the label testing scene. |
| `assets/sprites/` | Exported PNGs by system: `abilities`, `adventure`, `atmosphere`, `character`, `combat`, `cycling`, `inventory`, `items`, `path_progression`, `tilemap`, `ui` (`ability_button`, `action_buttons`, `attribute_icons`, `buff_icon`, `resource_bar`, `resources`, `stat_icons`, `system_menu`, `lock_icon.png`), `zones/backgrounds/spirit_valley` (`layer_00..11.png`) |
| `assets/aseprite/` | Aseprite sources: `abilities`, `character_profiles`, `cycling`, `ui/{ability_button,buff_icon,resource_bar}`, `zones`, plus root `madra_circle.aseprite`, `Sprite-0003*.aseprite` and a stray `Sprite-0003.gif` |
| `assets/shaders/` | 15 `.gdshader` files |
| `assets/scroll/` | Scroll art (and `parts/`) used by the adventure end card |
| `assets/dialogue/` | Dialogic `characters/`, `styles/` (including `dialogue_backgrounds/custom_background_layer.gd`), `timelines/` |
| `assets/colors/` | `default_color_palette.tres` (not referenced by game scenes or scripts) |

There is no `assets/audio/` folder; the project has no audio files. The 2026-04-15 asset cleanup ([spec](superpowers/specs/2026-04-15-assets-folder-cleanup-design.md)) produced this layout.

## Known issues

- `[MEDIUM]` The label testing scene is stale (see above).
- `[LOW]` `PanelDark` is defined but not used by any scene or script.
- `[LOW]` `ThemeConstants.FONT_*` (42/28/20/16/12) disagree with the variant scale and are unused. The header's "single source of truth" claim conflicts with this doc.
- `[LOW]` `pixel_theme.tres` still carries Godot 3-style item names inherited from the pixel UI pack, which Godot 4 does not read. Examples: `Button/colors/font_color_hover`, `font_color_pressed`, `font_color_disabled`, and `*/constants/hseparation`. The Godot 4 names (`font_hover_color`, etc.) are also present for `Button`.
- `[LOW]` A few UI files still set sizes inline instead of using a variant. Examples: the dev panel title (`LabelHeading` + 20px), `TickProgressBar`'s counter (`LabelSmall` + 12px), and `scenes/tools/encounter_id_label.tscn` (bare Label + 11px).
- `[LOW]` Some non-snake_case asset names remain outside the cleanup spec's rename list: `sprites/cycling/Cycling_Technique_Background.webp`, `sprites/cycling/Madra-Ball.png`, `aseprite/Sprite-0003*.aseprite`, `aseprite/ui/resource_bar/Sprite-0001.aseprite`. Also, `sprites/tilemap/hex_selector_spritesheet.aseprite` is a source file sitting in `sprites/`.
