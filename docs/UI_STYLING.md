# UI Styling
Last updated: 2026-10-22

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
| `LabelTitleSmall` | 40px | Gold | Secondary headers (the encounter panel, the consumables hotbar). The zone name now uses `LabelLacquerZoneName` |
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
- **Ability tooltip and stat pill text** (all with a 2px `#1A1208` outline for legibility — don't substitute general variants): `LabelAbilityBody` 18px beige (stat pills, combat tooltips) / `LabelAbilityMuted` 16px tan (tooltips). `LabelAbilityTitle` 34px beige is unused since the ability cards were replaced by the Abilities book's rows
- **Item description panel** (light background): `LabelDescItemName` 32px black / `LabelDescItemType` 20px gray `#606060`
- **Ability stats display:** `LabelSeparatorDot` 26px copper `#C4884A` — dot separators (assigned in code by `ability_stats_display.gd`)
- **Inventory chrome.** These labels set `scale = Vector2(0.5, 0.5)` to cancel the `InventoryView` root's 2x scale. The text then rasterizes at native resolution instead of being upscaled and blurred, so the variant size is the on-screen size.
  - `LabelInventoryCount` 24px dark ink `#33261A` — `GridToolbar` count text ("8 / 60" etc.) on the parchment background
  - `LabelInventorySort` 30px beige — `SortSubBanner` pill label ("All", "Weapons" etc.) on the dark pill background
  - `LabelInventorySignage` 48px dark ink `#33261A` — `TabBanner` signage title ("Equipment" etc.); `GearSelector`'s "Gear Selector" title uses it with a 30px size override
  - These are scoped: they only render correctly when their Label has `scale = 0.5` and an appropriate `pivot_offset`. Don't use them outside the inventory chrome.
- **Merchant shop (zone themes).** These variants are not in `pixel_theme.tres`. Each zone's merchant theme defines them, for example `assets/themes/merchant/spirit_valley_merchant_theme.tres` (styleboxes in `assets/styleboxes/merchant/`). `MerchantView` sets the merchant's `shop_theme` as its root `theme`; everything else (the Label type scale, red and green states, gold values) falls back to `pixel_theme.tres`. A new zone adds one Theme file with the same entries.
  - `MerchantPanel` (PanelContainer) — dark tinted shop panel with a glowing edge. It is 95% opaque: the log and the Goals board sit under the shop's place (the shop hides them while it is open), and their text would read through a lighter panel. Its content margins are left at the border width, so `MerchantAtmosphere` reaches the border; the 16px / 12px padding lives in `MerchantView`'s `ContentMargin`
  - `MerchantRow` (PanelContainer) — translucent stock row with a thin luminous edge
  - `MerchantButton` (Button) — Buy and Leave, 20px; every state, disabled included. No StyleBoxFlat shadow: Godot draws it under a translucent box, which fills the button
  - `LabelMerchantTitle` (base `LabelTitle`) — `LabelTitle`'s gold colour and 2px drop shadow, inherited from `pixel_theme.tres`, plus a zone-coloured glow (10px outline at low alpha). It repeats `LabelTitle`'s 50px size: `pixel_theme.tres` sets `default_font_size = 14`, and Godot returns that default for `LabelMerchantTitle` before it reaches `LabelTitle`. Colours and constants have no theme default, so they inherit. `test_title_matches_label_title_in_game` fails if the two sizes drift apart
  - `LabelMerchantGreeting` (base `LabelSubheading`) — the greeting under the title. It keeps `LabelSubheading`'s tan and shadow from `pixel_theme.tres` at 16px, and the label wraps (`autowrap_mode` word smart) across the header. The size is set in the zone theme for the same reason as the title's: otherwise `pixel_theme.tres`'s default font size answers first. `test_greeting_is_smaller_than_a_subheading_in_game` checks both
  - `HSeparatorMerchant` (HSeparator) — 1px zone-coloured divider, 8px inset, separation 24
  - `MerchantAtmosphere` colours `mist`, `mote_primary`, `mote_secondary`, `light`, `slot_glow` — read in code with `get_theme_color()` by `MerchantAtmosphere` and `MerchantStockRow` and applied as `modulate`
  - `MerchantAtmosphereMask` (Panel) — the shape `MerchantAtmosphere` clips its light, mist and motes to (`clip_children`). It is opaque, with corners rounded to the panel's inner radius (corner radius minus border width). It is a separate type because making `MerchantAtmosphere` a Panel variation would hide its colours from a zone theme that doesn't declare that variation

## Menu book pages

The four menu books (Inventory, Abilities, Character, Path; see [MAIN_VIEW.md](infrastructure/MAIN_VIEW.md#menu-books)) have cream pages, where the general Label variants (light text for dark panels) don't read. The Abilities, Character and Path views set `assets/themes/book_theme.tres` as their root `theme`; it holds only the variants below, and every other lookup falls back to `pixel_theme.tres`. Each variant sets its own font size and clears the base Label's drop shadow.

| Variant | Base type | Style | Use |
|---------|-----------|-------|-----|
| `LabelBookTitle` | Label | 28px dark ink `#33261A` | Card titles (the ability, attribute or node shown) |
| `LabelBookBody` | Label | 20px dark brown `#3B2A20` | Body text, row names |
| `LabelBookValue` | Label | 20px dark gold `#8B6914` | Values, equipped state |
| `LabelBookValueLarge` | Label | 28px dark gold `#8B6914` | The big number on an attribute tile and the Character details header |
| `LabelBookMuted` | Label | 16px muted brown `#7D5F47` | Secondary lines, hints, captions |
| `LabelBookPositive` | Label | 18px dark green `#3E7A3A` | Path node effect lines and the Active Benefits lines |
| `LabelBookPill` | Label | 18px cream `#F4DCBF` | Text on a dark pill |
| `LabelBookKey` | Label | 14px cream on a dark rounded chip | Loadout key chips (Q/W/E/R) |
| `LabelBookPlaque` | Label | 20px dark ink on the header plaque art (`normal` stylebox) | Section headers ("Loadout", "Physical", "Active Benefits", the pointed-at name). Set `custom_minimum_size = (248, 52)` and centre the text; the stylebox's 11px top and 7px bottom content margins centre it on the plaque's face |
| `PanelBookCard` | PanelContainer | The inventory's item-details card art | Details blocks, the loadout, the tree card |
| `PanelBookRow` / `PanelBookRowSelected` | PanelContainer | The consumables row-bar art; the selected one is tinted warm | List rows (abilities) |
| `PanelBookTile` / `PanelBookTileSelected` | PanelContainer | The card art with tight 6px side margins; the selected one is tinted warm like rows | Attribute tiles in the Character book |
| `PanelBookSlot` | PanelContainer | The inventory's slot art | Icon slots and loadout slots |
| `PanelBookPill` | PanelContainer | The inventory's dark category pill | Small status pills (the path points badge) |
| `PanelBookInset` | PanelContainer | The dark pill art, darkened | The path tree's map window |

The panel art is drawn at the book's own pixel density (one art pixel = 2 screen pixels). Their 9-slice styleboxes use 2x nearest-neighbour copies in `assets/sprites/ui/book/` (`book_card_2x_ai.png`, `book_row_2x_ai.png`, `book_pill_2x_ai.png`, `book_plaque_2x_ai.png`, `book_slot_2x_ai.png`) of the inventory originals, so stretched panels keep crisp, matching edges. Separators on cards use `HSeparatorItemDesc` from `pixel_theme.tres`.

Each book's own colours are not theme items: a `BookStyleData` resource per book (`resources/ui/book_styles/`) recolours the cover edge, page border, turning page and bookmark through `assets/shaders/palette_swap.gdshader`.

## RichTextLabel variants

RichTextLabels **cannot** use Label-based variants (different base type). Only one RTL variant exists:
- `RichTextLabelDark` — dark brown default color `#2A1A12` for light backgrounds (`ItemDescriptionPanel`, `ItemDetailCard`, `QuestJournalCard`)

For RTLs that need a custom size, set `theme_override_font_sizes/normal_font_size` directly. Match one of the Label variant sizes for visual consistency (e.g. use 22 if body text elsewhere uses `LabelBody`).

## HSeparator variants

- Base `HSeparator` (no variant) — 2px copper `#C4884A` line, inset 8px at each end.
- `HSeparatorTooltip` — 1px separator with **no inset**, muted brown `#6B4A30` at 50% alpha, separation 6. Use for tooltip and ability card detail dividers (ability card, path node tooltip, attribute tooltip).
- `HSeparatorItemDesc` — 2px parchment `#E9CEAD`, no inset, separation 12. Top separator under the item type in `ItemDescriptionPanel`, `ItemDetailCard`, `QuestJournalCard`.
- `HSeparatorItemDescThin` — 1px parchment `#E9CEAD`, inset 100px at each end, separation 10. Separates the description from the effects in the same panels.
- `HSeparatorResourcePanel` — 2px gold `#D4A84A` at 60% alpha, no inset. Unused since the lacquer cultivator cabinet replaced the zone view's old resource panel, whose orbs it divided.

## Other variants

| Variant | Base type | Style | Used by |
|---------|-----------|-------|---------|
| `ButtonEndCard` | `Button` | Scroll button styleboxes (`assets/styleboxes/buttons/scroll/`), 20px, cream font `#F0E0C2` | `AdventureEndCard` Return button |
| `CyclingTabContainer` | `TabContainer` | `common/tab_*` styleboxes; selected gold, unselected tan, hovered beige | `CyclingView` |
| `PanelAbilityCard` | `PanelContainer` | `abilities/card_normal.tres` (dark brown, 2px brown border) | Unused (the ability card it styled was replaced by `AbilityRow`) |
| `PanelAccent` | `PanelContainer` | `common/panel_accent.tres` (brown 92%, 3px copper border) | `CyclingView` |
| `PanelLootTray` | `PanelContainer` | `common/panel_loot_tray.tres` (translucent parchment) | `AdventureEndCard` |
| `PanelStatPill` | `PanelContainer` | `abilities/stat_pill.tres` (small dark pill) | `StatLabel` |
| `PanelTooltip` | `PanelContainer` | `abilities/tooltip_panel.tres` (dark brown, 2px copper border) | Ability/buff tooltips, `CombatantInfoPanel`, `StatTooltip` (set in code) |
| `PanelDark` | `PanelContainer` | `common/panel_dark.tres` (dark texture) | Unused |

Base types without a variant:

- `Panel` and `PanelContainer` default to `common/panel_tan.tres` (tan parchment texture).
- `Button` uses `buttons/button_default_normal.tres`, `button_default_pressed.tres`, and `button_default_hover.tres` for both hover and disabled, with a gold hover/pressed font colour. `button_default_disabled.tres` is referenced only by `ability_card.tscn`.

## Lacquer theme (zone view)

The map-first zone view ("Lacquer and brass") has its own theme, `assets/themes/lacquer/lacquer_theme.tres`. Sizes and colours come from the art kit's §2 and §3 ([2026-10-21-zone-view-lacquer-kit.md](superpowers/specs/2026-10-21-zone-view-lacquer-kit.md)).

**Rule:** every zone-view panel (cultivator cabinet, Goals board, log board, dock, zone chest, map plates and popovers) sets `theme = lacquer_theme.tres` on its root and gives its Labels the `LabelLacquer*` variants below. Everything else (base types, `pixel_theme.tres`'s own variants) still falls back to `pixel_theme.tres`.

How the theme is built, so a reused piece inside a lacquer panel keeps its own look:

- **No defaults.** The theme sets no `default_font` or `default_font_size`. A default would answer for every type, `pixel_theme.tres`'s variants included, before Godot reached them (the `LabelMerchantTitle` problem above). Each variant sets its own `font` and `font_size` instead. `test_theme_sets_no_defaults` guards this.
- **Shadows.** `pixel_theme.tres`'s base `Label` draws a 1 px ink shadow. The four painted titles set the kit's hard 2 px shadow (`#150909`, offset 2, 2, `shadow_outline_size` 0). Every other lacquer variant sets a transparent `font_shadow_color`, so it draws none.
- **Line pitch.** Each variant's `line_spacing` is the kit's line height minus the font's height at that size, so wrapped lines (lore, two-line card details, popover bodies) step by the kit's line height. A single-line Label is only the font's height (17 px for 15 px BM Euljiro), not the kit's line height.
- **Fonts.** Yatra One (`assets/fonts/YatraOne-Regular.ttf`) for the painted titles, BM Euljiro for everything else. Tags and seals use a `FontVariation` of BM Euljiro with 1 px letter spacing (`spacing_glyph = 1`).
- **Tag and seal indent.** The 1 px letter spacing also trails the last letter, which would pull centred text 0.5 px left. Tags and seals therefore have a `normal` style of their own, a `StyleBoxEmpty` with a 1 px left content margin: the mock's `text-indent: 1px`. For the mode tags, NEW and UNKNOWN, give the Label the tag's or seal's full width (76 px for a tag) and centre the text. Add no offset of your own.
- **The LOCKED seal is the exception.** Its word is left-aligned, not centred: `mini_lock` sits at seal +8, +3 and the word starts at seal +26 (kit §4.2; the mock has no `text-indent` there). The variant's 1 px indent still applies, so put the `LabelLacquerSeal` at seal-local x 25, left-aligned, and the word lands on +26. A Label placed at +26 draws its word at +27, off the 2 px grid.

Colours: brass `#D4A84A`, cream `#F0E8D8`, tan `#A89070`, ink `#150909`.

| Variant | Font, size / kit line height | Colour | Use for |
|---------|------------------------------|--------|---------|
| `LabelLacquerZoneName` | Yatra 30 / 44, shadow | Brass | Zone name in the chest header |
| `LabelLacquerPanelTitle` | Yatra 22 / 28, shadow | Brass | Panel titles: Goals, Log |
| `LabelLacquerSection` | Yatra 20 / 24, shadow | Brass | The Activities header |
| `LabelLacquerStage` | Yatra 21 / 28, shadow | Cream | Stage name ("Foundation") |
| `LabelLacquerBig` | Euljiro 30 / 36 | Cream | The Madra value. The cabinet's `/ max` after it uses it too, with a tan colour override |
| `LabelLacquerGold` | Euljiro 22 / 28 | Cream | The gold value |
| `LabelLacquerName` | Euljiro 17 / 20 | Cream | Card titles, quest and milestone names, `Level 32` |
| `LabelLacquerRate` | Euljiro 17 / 20 | Tan | The `gold` word after the cabinet's gold value. The cabinet's Madra rate (`+1.5 / s`) has a decimal point, so it is a 17 px `RichTextLacquer` (see below), not this variant |
| `LabelLacquerNowName` | Euljiro 18 / 22 | Cream | Now strip action name |
| `LabelLacquerNowRate` | Euljiro 16 / 22 | Cream | Now strip rate |
| `LabelLacquerDetail` | Euljiro 15 / 18 | Tan | Labels, card detail lines, figures (`17 / 18 XP`), log lines, group labels, the empty Now tray's line (`Aura Well · paused`, `Nothing running`) |
| `LabelLacquerTag` | Euljiro 13 / 22, 1 px spacing | Tan | Mode tags (IDLE, ACTIVE, SHOP, STORY, UNKNOWN). RUNNING overrides to cream, ENTER to ink |
| `LabelLacquerSeal` | Euljiro 13 / 22, 1 px spacing | Cream | Seals: NEW, LOCKED |
| `LabelLacquerLegend` | Euljiro 14 / 22 | Ink | The `Now` legend on its brass plate |
| `LabelLacquerDock` | Euljiro 14 / 18 | Cream | Dock button labels |
| `LabelLacquerHotkey` | Euljiro 14 / 18 | Tan | Dock hotkeys |
| `LabelLacquerLore` | Euljiro 16 / 22 | Cream | Zone lore text: the zone chest's `LoreText`, a wrapping Label whose one override, `paragraph_spacing` 10, is the kit's gap between paragraphs |
| `LabelLacquerPlateName` | Euljiro 16 / 18 | Cream | Map plate zone names |
| `LabelLacquerPlateLine` | Euljiro 14 / 18 | Cream | Map plate status lines |
| `LabelLacquerPopoverTitle` | Euljiro 18 / 22 | Cream | Map popover titles |
| `LabelLacquerPopoverBody` | Euljiro 15 / 20 | Cream | Map popover body text |
| `LabelLacquerFloater` | Euljiro 16 / 20 | Cream | Map floaters on their lacquer token. No outline (`outline_size` set to 0): the kit's §0 dropped it when the floaters moved onto the token. A floater with a decimal (`+1.5 Madra`, Madra blue) needs the Yatra point, so it is a `RichTextLacquer` at 16 px instead (see below) |

`RichTextLacquer` (base `RichTextLabel`): BM Euljiro 15, tan, `line_separation` 1, so each line is 18 px (15/18), the first included. Use it for the few lines with a decimal number: BM Euljiro's `.` sits low and reads as a comma at 15–17 px, so `LacquerText.decimal_bbcode()` sets each decimal point in Yatra One (kit §3, glyph gaps). Set `bbcode_enabled`, `fit_content` and, for one-line text, `autowrap_mode` off.

- **The dot never grows its line.** Yatra One's ascent and descent run up to 3 px past BM Euljiro's, so a plain Yatra dot would make a 15 px line 24 px tall and drop its baseline 3 px. `decimal_bbcode()` writes the dot as `[font name=…YatraOne-Regular.ttf top_spacing=-3 bottom_spacing=-3]`, the mock's `.pt { line-height: 0 }`. At 13 to 18 px a line with a decimal is exactly as tall as the same line without one (`test_decimal_point_never_grows_a_line`). Above 18 px the trim is not enough: check the line height before using it there.
- **Other sizes.** Override `normal_font_size` for the 16 px Now rate and floater or the 17 px cabinet rate, and the colour (`default_color`) where the kit colours the line. The line is then the font's height + 1: 20 px at 16, 21 at 17. The kit's cabinet rate is 17/20, but it is one line, so only its box is 1 px taller: the baseline is where a Label's would be.
- **No `text_overrun_behavior`.** A `RichTextLabel` cannot ellipsize. An activity card's detail line goes through `ZoneActionButton.fit_detail_rich_text()`, which drops whole words until the line fits its width (316 px, kit §5.5), ends it in `…` with no separator left before it, and then applies `decimal_bbcode()`.
- **Not `[font=path]` with a `FontVariation` file.** In Godot 4.7.2 a `[font=…]` tag that loads a `FontVariation` `.tres` drops its `spacing_top` / `spacing_bottom` (measured: the line still grows to 24 px), while `push_font()` with the same object keeps them. Put the spacing in the tag's options, as `decimal_bbcode()` does.

`RichTextLacquerLog` (base `RichTextLacquer`): the same 15 px tan text with `line_separation` 9, so lines are 26 px apart, the first included: the log's line pitch (kit §0). The full log's `FullLogText` uses it; give such a text area a height that is a whole number of 26 px lines (it is 468, 18 lines), or a sliver of an older line shows at its top when it sits scrolled to the bottom.

Per-label colour overrides on top of these variants are expected where the kit colours by state: log lines by tone and age, plate names on hover, RUNNING and ENTER tags, Madra-blue text.

### Lacquer styleboxes (`assets/styleboxes/lacquer/`)

All `StyleBoxTexture` 9-slices of kit textures, drawn with nearest filtering at their file scale:

| File | Texture | Margins | Fill | Use |
|------|---------|---------|------|-----|
| `frame_brass.tres` | `lacquer_frame_brass_ai.png` (24x24) | 8 | none | Flash frame on cards and the Now tray, pinned map plates |
| `frame_hover.tres` | `lacquer_frame_hover_ai.png` (16x16) | 4 | none | Hover frame on cards, the Now tray, Show me, About |
| `rail_thumb.tres` | `lacquer_rail_thumb_ai.png` (12x12) | top and bottom 4 | yes | The activity list's rail thumb, any even height of 32 or more |
| `token.tres` | `lacquer_token_ai.png` (26x26) | left and top 6, right and bottom 8 | yes | The map floater's token. The 2 px shadow is baked into the right and bottom edges |

`token.tres` also sets content margins 14, 4, 16 and 6 (left, top, right, bottom), so a `PanelContainer` with this style hugs one 20 px text line to the kit's token: 30 px tall (28 + the 2 px shadow), the text 14 px in and 4 px down, and text width + 30 wide (text + 28 + the shadow). A 16 px `RichTextLacquer` line is 20 px already (`test_token_hugs_a_floater_line`). A one-line `LabelLacquerFloater` is 19 px, so give it `custom_minimum_size.y = 20`. The kit rounds the token's width to even (`even(text + 28)`): the floater sets that width itself.

### Lacquer pieces (`scenes/common/lacquer/`)

- **`LacquerStripRect`** (`lacquer_strip_rect.gd`, a `TextureRect` script): set `strip` and `frame_size`, then `set_frame(column, row)` shows that frame through the rect's own `AtlasTexture` (orbs, XP beads, timer rings). Frames clamp to the strip. It is `@tool`, so a placed rect shows frame 0 in the editor. Its `texture` is derived and read-only, and is never saved into the scene: `strip` and `frame_size` are.
- **`LacquerRod`** (`lacquer_rod.tscn`): set `empty_texture`, `full_texture`, `end_texture` and `steps`, then `set_fraction(f)`. It shows the full rod clipped to width 2 + 2k with the end cap at x = 2k once k ≥ 2, k = round(f × steps) (kit §4.3). Steps: Aura Well 152, milestone 138, adventure 74. It is `@tool`: in the editor a placed rod is the groove's size and shows empty. Its minimum size comes from `empty_texture`, so leave its size and `custom_minimum_size` alone.
- **`LacquerFrameOverlay`** (`lacquer_frame_overlay.tscn`, a `Panel`): a full-rect frame over its parent, hidden, mouse ignored, brass by default. Override its `theme_override_styles/panel` with `frame_hover.tres` for the hover frame. `flash(times)` shows it 300 ms and hides it 300 ms, `times` times, and ends hidden.
- **`LacquerText`** (`scripts/utils/lacquer_text.gd`): `rate(1.5)` → `"+1.5"`, `rate(2.0)` → `"+2"`; `decimal_bbcode(text)` for `RichTextLacquer`.
- **`LacquerRail`** (`scenes/zones/zone_panel/lacquer_rail/lacquer_rail.tscn`): the brass scroll rail (kit §4.4) that stands in for a `ScrollContainer`'s hidden scrollbar. `bind(host)` follows the host's scroll; it shows only while the content overflows, lights each end cap only when the list can scroll that way, sizes its thumb (`rail_thumb.tres`) from the visible share, and `step_to(target)` scrolls in six even-px steps over 200 ms. The zone chest's activity list uses it; the full log styles its own scrollbar's caps with the same textures.

Tests: `tests/unit/test_lacquer_pieces.gd` checks every variant's font, size, colour and shadow, the line pitch measured on real Labels and RichTextLabels (decimal lines included), the tag indent, the styleboxes' margins, the token hugging a floater line, and the pieces.

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
| `ACCENT_GOLD` | `#D4A84A` | Gold Label variants | 6 times: `AbilitiesView`, `CyclingTechniqueSlot`, path tree nodes (`path_node_container.gd`, `path_node_ui.gd`). The lacquer dock buttons swap textures on hover instead |
| `BORDER_PRIMARY` | `#C4884A` | `LabelSeparatorDot`, base `HSeparator` | 3 times |
| `BG_MEDIUM` | `#3D2E22` | — | 2 times |
| `TEXT_LIGHT` / `TEXT_MUTED` / `TEXT_DARK` | `#F0E8D8` / `#A89070` / `#1A1208` | Beige / tan / Label shadow | Unused |
| `ACCENT_GREEN` / `ACCENT_RED` | `#7DCE82` / `#E06060` | `LabelGreen` / `LabelRed` | Unused |
| `BG_DARK` | `#2A1A12` | `RichTextLabelDark` | Unused |
| `BG_LIGHT`, `TINT_*`, `BORDER_SUBTLE`, `HOVER_BG`, `PRESSED_BG`, `DISABLED_*` | — | — | Unused |
| `FONT_TITLE` 42 / `FONT_HEADING` 28 / `FONT_BODY` 20 / `FONT_LABEL` 16 / `FONT_CAPTION` 12 | — | **Do not match** the variant scale above | Unused |
| `BORDER_WIDTH_*`, `CORNER_RADIUS_*`, `CONTENT_MARGIN_*` | — | — | Unused |
| `LACQUER_INK` / `LACQUER_BRASS` / `LACQUER_CREAM` / `LACQUER_TAN` | `#150909` / `#D4A84A` / `#F0E8D8` / `#A89070` | The `LabelLacquer*` variants | Zone view panels (lacquer kit §2) |
| `LACQUER_DIM` / `LACQUER_MADRA` / `LACQUER_VERMILION` | `#94806A` / `#BBD5E7` / `#A83C30` | — | Old log lines, Madra text, seals |

Use the Label variants for sizes. Use `ThemeConstants` only for colours that must be set from code.

## Theme and asset files

| Path | Contents |
|------|----------|
| `assets/themes/pixel_theme.tres` | Project theme: base types, all variants above except the book, merchant and lacquer ones |
| `assets/themes/book_theme.tres` | Menu book page variants ([Menu book pages](#menu-book-pages)) |
| `assets/themes/lacquer/lacquer_theme.tres` | Zone view theme: the `LabelLacquer*` variants and `RichTextLacquer` (see Lacquer theme) |
| `assets/themes/pixel_ui_theme/` | Third-party pixel UI pack: `8x8_ui_elements*.png` and `8x8_ui_icons.png` atlases, `m5x7.ttf`, 8 colour-variant `PixelTheme-*.tres`, `TabContainer.tscn`. `pixel_theme.tres` uses only the two base atlases; the variant themes are not referenced by the game. |
| `assets/styleboxes/` | StyleBox `.tres` grouped by area: `abilities`, `adventure`, `buttons` (+`scroll`), `combat`, `common`, `cycling`, `inventory`, `lacquer`, `merchant`, `textures`, `ui`, `zones` |
| `assets/fonts/` | `BMEULJIROTTF.ttf` (theme font). `YatraOne-Regular.ttf` (the lacquer theme's painted titles). `Korean_Calligraphy.ttf`, `pixelmix.ttf` and `Ubage-woA3P.otf` are loaded only by the label testing scene. |
| `assets/sprites/` | Exported PNGs by system: `abilities`, `adventure`, `atmosphere`, `character`, `combat`, `cycling`, `inventory`, `items`, `path_progression`, `tilemap`, `ui` (`ability_button`, `action_buttons`, `attribute_icons`, `buff_icon`, `resource_bar`, `resources`, `stat_icons`, `system_menu`, `book` (menu book bookmark, close tab, stage icons, padlock, 2x panel art), `lock_icon.png`), `zones/backgrounds/spirit_valley` (`layer_00..11.png`) |
| `assets/aseprite/` | Aseprite sources: `abilities`, `character_profiles`, `cycling`, `ui/{ability_button,buff_icon,resource_bar}`, `zones`, plus root `madra_circle.aseprite`, `Sprite-0003*.aseprite` and a stray `Sprite-0003.gif` |
| `assets/shaders/` | 16 `.gdshader` files (`palette_swap.gdshader` recolours the menu books) |
| `assets/scroll/` | Scroll art (and `parts/`) used by the adventure end card |
| `assets/dialogue/` | Dialogic `characters/`, `styles/` (including `dialogue_backgrounds/custom_background_layer.gd`), `timelines/` |
| `assets/colors/` | `default_color_palette.tres` (not referenced by game scenes or scripts) |

There is no `assets/audio/` folder; the project has no audio files. The 2026-04-15 asset cleanup ([spec](superpowers/specs/2026-04-15-assets-folder-cleanup-design.md)) produced this layout.

## Known issues

- `[MEDIUM]` The label testing scene is stale (see above).
- `[LOW]` `PanelDark` is defined but not used by any scene or script.
- `[LOW]` `ThemeConstants.FONT_*` (42/28/20/16/12) disagree with the variant scale and are unused. The header's "single source of truth" claim conflicts with this doc.
- `[LOW]` `pixel_theme.tres` still carries Godot 3-style item names inherited from the pixel UI pack, which Godot 4 does not read. Examples: `Button/colors/font_color_hover`, `font_color_pressed`, `font_color_disabled`, and `*/constants/hseparation`. The Godot 4 names (`font_hover_color`, etc.) are also present for `Button`.
- `[LOW]` A few UI files still set sizes inline instead of using a variant. Examples: the dev panel title (`LabelHeading` + 20px), the now unused `TickProgressBar`'s counter (`LabelSmall` + 12px), and `scenes/tools/encounter_id_label.tscn` (bare Label + 11px).
- `[LOW]` Some non-snake_case asset names remain outside the cleanup spec's rename list: `sprites/cycling/Cycling_Technique_Background.webp`, `sprites/cycling/Madra-Ball.png`, `aseprite/Sprite-0003*.aseprite`, `aseprite/ui/resource_bar/Sprite-0001.aseprite`. Also, `sprites/tilemap/hex_selector_spritesheet.aseprite` is a source file sitting in `sprites/`.
