# UI Styling

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
| `LabelTitleSmall` | 40px | Gold | Secondary headers (the consumables hotbar). The zone name now uses `LabelLacquerZoneName` |
| `LabelHeading` | 36px | Gold | Subsection headings |
| `LabelValueLarge` | 34px | Gold | Big value numbers |
| `LabelBodyLarge` | 28px | Beige | Large body text (nothing uses it today) |
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
- **Ability tooltip and stat pill text** (all with a 2px `#1A1208` outline for legibility — don't substitute general variants): `LabelAbilityBody` 18px beige (the stat pills, which no screen shows now, and the enemy plate's buff tooltip) / `LabelAbilityMuted` 16px tan (that tooltip). `LabelAbilityTitle` 34px beige is unused since the ability cards were replaced by the Abilities book's rows
- **Item description panel** (light background): `LabelDescItemName` 32px black / `LabelDescItemType` 20px gray `#606060`
- **Ability stats display:** `LabelSeparatorDot` 26px copper `#C4884A` — dot separators (assigned in code by `ability_stats_display.gd`, which no screen shows now)
- **Inventory chrome.** These labels set `scale = Vector2(0.5, 0.5)` to cancel the `InventoryView` root's 2x scale. The text then rasterizes at native resolution instead of being upscaled and blurred, so the variant size is the on-screen size.
  - `LabelInventoryCount` 24px dark ink `#33261A` — unused since the pressed Materials page dropped `GridToolbar`, whose count text it set
  - `LabelInventorySort` 30px beige — `SortSubBanner` pill label ("All" etc.) on the dark pill background
  - `LabelInventorySignage` 48px dark ink `#33261A` — `TabBanner` signage title ("Character" etc.)
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
| `LabelBookPageTitle` | Label | Yatra One 38px dark ink `#33261A`, line pitch 44 | Page titles: "Equipment", "Gear", a material's or quest item's name |
| `LabelBookItemName` | Label | Yatra One 30px dark ink `#33261A`, pitch 34 | The item's name in a details panel |
| `LabelBookQuestName` | Label | Yatra One 26px dark ink `#33261A`, pitch 30 | A quest's name |
| `LabelBookDropCap` | Label | Yatra One 46px vermilion `#A83C30`, pitch 52 | The Journal's drop cap |
| `LabelBookInk` | Label | BM Euljiro 18px ink `#3B2A20`, pitch 26 | Body text and descriptions |
| `LabelBookInkDark` | Label | BM Euljiro 18px dark ink `#33261A`, pitch 26 | Row names, values, "You have 4,600", the hotbar's key numbers |
| `LabelBookDetail` | Label | BM Euljiro 15px muted ink `#765A43`, pitch 20 | Row details, hints ("Right-click to wear it"), the equipment count |
| `LabelBookDetailDark` | Label | BM Euljiro 15px dark ink `#33261A`, pitch 20 | The number printed in a page button |
| `LabelBookFlavor` | Label | BM Euljiro 16px muted ink `#765A43`, pitch 22 | A quest's flavour text |
| `LabelBookStep` | Label | BM Euljiro 16px ink `#3B2A20`, pitch 22 | A quest's steps |
| `LabelBookCount` | Label | BM Euljiro 20px dark ink `#33261A`, pitch 24 | The count in a list row (`×7`) |
| `LabelBookCaps` | Label | Eul+1 13px muted ink `#765A43`, pitch 18 | Labels in capitals: `HEAD`, `STRENGTH`, `CONSUMABLE · IN SLOT 1`. The page writes the text in capitals |
| `LabelBookTag` | Label | BM Euljiro 13px set 3px low in its line (see below), dark ink `#33261A`, pitch 18, `normal` = `paper_tag.tres` | The count on a paper tag (`×4600`). Use it through `PaperTag` (`scenes/inventory/pressed/paper_tag/`), which rounds the tag's width up to even so its art stays on the 2px grid |
| `LabelBookSeal` | Label | Eul+1 13px seal text `#F0E8D8`, pitch 18, `normal` = `seal.tres` | The word on a seal (`DONE`). Give the Label the seal's 66x26 size and centre the text |
| `LabelBookFilter` | Label | Eul+1 13px set 5px low in its line (see below), muted ink `#765A43`, pitch 18, `normal` = an empty style with 10/6/10/4 content margins | A filter word that is not in use |
| `LabelBookFilterOn` | Label | Eul+1 13px set 5px low in its line (see below), dark ink `#33261A`, pitch 18, `normal` = `pressed_lozenge.tres` | The filter word in use. Its margins match `LabelBookFilter`'s, so swapping the two moves nothing |
| `RichTextBookDetail` | RichTextLabel | BM Euljiro 15px muted ink `#765A43` (`default_color`), `line_separation` 3, pitch 20 | Detail lines with BBCode: what a consumable does, under its name in the list |
| `RichTextBookValue` | RichTextLabel | BM Euljiro 18px dark ink `#33261A` (`default_color`), `line_separation` 5, pitch 26 | The value in a row of a details panel's table, with BBCode: `+20 Madra` in Madra ink, `10 s` |
| `PanelPressed` | PanelContainer | `pressed_panel.tres`: the pressed panel, 16px content margins | The details panels |
| `PanelBookBare` | PanelContainer | An empty style: draws nothing | A `PanelContainer` that must show no panel (the base type draws `panel_tan.tres`) |
| `PanelPrinterMarks` | Panel | `printer_marks.tres`: four vermilion corner marks, no fill | The printer's marks around the item the player picked, laid over it |
| `HSeparatorPressed` | HSeparator | `pressed_rule.tres`: a pressed 4px rule, `separation` 4 | Rules between sections and under rows |

The panel art is drawn at the book's own pixel density (one art pixel = 2 screen pixels). Their 9-slice styleboxes use 2x nearest-neighbour copies in `assets/sprites/ui/book/` (`book_card_2x_ai.png`, `book_row_2x_ai.png`, `book_pill_2x_ai.png`, `book_plaque_2x_ai.png`, `book_slot_2x_ai.png`) of the inventory originals, so stretched panels keep crisp, matching edges. Separators on cards use `HSeparatorItemDesc` from `pixel_theme.tres`.

Each book's own colours are not theme items: a `BookStyleData` resource per book (`resources/ui/book_styles/`) recolours the cover edge, page border, turning page and bookmark through `assets/shaders/palette_swap.gdshader`.

### Pressed pages

The rows from `LabelBookPageTitle` down are the "pressed paper" pieces for the Inventory's four tabs ([design](superpowers/specs/2026-10-23-inventory-pressed-pages-design.md)). They follow the rules above (their own size, no drop shadow) and add these:

- **One muted ink.** Every new muted variant is `#765A43`: 5.17:1 on the paper and 4.72:1 on a panel's floor (`#EFDCBB`). `LabelBookMuted` keeps `#7D5F47` for the other books, which is 4.34:1 on a panel.
- **Fonts.** Yatra One (`assets/fonts/YatraOne-Regular.ttf`) for titles and names, BM Euljiro for everything else. "Eul+1" is BM Euljiro with 1px letter spacing (`spacing_glyph = 1`): one `FontVariation` shared by `LabelBookCaps` and `LabelBookSeal`, and another, set low (below), shared by `LabelBookFilter` and `LabelBookFilterOn`.
- **Line pitch.** `line_spacing` is the pitch minus the font's height at that size, so wrapped lines step by the pitch, as in the lacquer theme. Heights: Yatra One 46 / 38 / 30 / 26 is 69 / 57 / 45 / 39px (spacing -17 / -13 / -11 / -9); BM Euljiro 20 / 18 / 16 / 15 / 13 is 23 / 21 / 19 / 17 / 16px (spacing +1 / +5 / +3 / +3 / +2). `RichTextBookDetail` and `RichTextBookValue` get their 20 and 26px pitches from `line_separation` 3 and 5, which a RichTextLabel adds under every line, the last one too.
- **One line is only the font's height.** A single-line Label is as tall as its font (16px at 13px), not its pitch, so a style's content margins make up the rest. They are sized so a `LabelBookTag` is 20px tall (16 + 2 + 2, the paper tag's art) and a `LabelBookFilter` or `LabelBookFilterOn` 26px (16 + 6 + 4, the lozenge's art), with no `custom_minimum_size.y` needed. Size the margins of any new styled Label from the font's height, not from the pitch. `LabelBookFilter` and `LabelBookFilterOn` are the same size, so selecting a word moves nothing.
- **Text set low on its art.** A content margin cannot lower a one-line Label's text without making the Label taller by as much. Where the mockups print text below the middle of its art, the font moves it down inside its own line instead: `LabelBookTag`'s font is a `FontVariation` of BM Euljiro with `spacing_top` 3 and `spacing_bottom` -3, so a tag's count sits 16px under the tag's top and the tag stays 20px. A font can lower its glyphs only as far as its descent (5px at 13px), so the filter words' font, Eul+1 with `spacing_top` 5 and `spacing_bottom` -5, takes the last pixel from their styles' 6px top and 4px bottom margins: a word's baseline is 22px under its lozenge's top, where the mockup presses the lozenge.
- **Wrapping in a stack, on even pixels.** Every pitch is even, so a stack of wrapping Labels grows by an even number of px a line, and only a block's one-line height can make it odd. A block whose one line is odd (a `LabelBookDetail` line is 17px, a `LabelBookQuestName` line 39) takes `wrap_pad.tres` as its `normal` style, a 1px pad under it, or an odd margin that evens it out; then a block under a grown one, and its art, stays on even pixels.

Tests: `tests/unit/test_pressed_pieces.gd` checks each variant's font, size, colour, base type, cleared shadow and line pitch, the letter-spaced font, the styleboxes, the rule's height, the one-line heights of tags and filter words and the text contrast.

### Pressed pieces (`assets/styleboxes/book/`)

`StyleBoxTexture` 9-slices of the pressed art in `assets/sprites/ui/book/pressed/`, drawn with nearest filtering at their file scale. Every content margin is set, 0 included: a content margin left unset falls back to the texture margin, which would inset the content by up to 10px on `printer_marks.tres`.

| File | Texture | Texture margins L/T/R/B | Content margins L/T/R/B | Fill | Use |
|------|---------|-------------------------|-------------------------|------|-----|
| `pressed_panel.tres` | `pressed_panel_ai.png` (32x32) | 8/8/8/8 | 16/16/16/16 | yes | `PanelPressed` |
| `pressed_lozenge.tres` | `pressed_lozenge_ai.png` (24x26) | 8/0/8/0 | 10/6/10/4 | yes | `LabelBookFilterOn`, the filter in use. The 6px top and 4px bottom margins make a one-line word 26px tall, the art's height, and set it low on the lozenge (see Text set low on its art) |
| `pressed_rule.tres` | `pressed_rule_ai.png` (8x4) | 2/0/2/0 | 0/2/0/2 | yes | `HSeparatorPressed`. Its 2px top and bottom content margins give the rule its 4px height (see below) |
| `printer_marks.tres` | `printer_marks_ai.png` (32x32) | 10/10/10/10 | 0 | none | `PanelPrinterMarks` |
| `paper_tag.tres` | `paper_tag_ai.png` (12x20) | 4/4/4/4 | 5/2/5/2 | yes | `LabelBookTag`. The 2px top and bottom margins make a one-line count 20px tall, the art's height |
| `seal.tres` | `seal_ai.png` (66x26) | 0 | 0/4/0/0 | yes | `LabelBookSeal`. No 9-slice: size the Label to 66x26. The 4px top margin lowers the centred word onto the mockups' baseline, 18px under the seal's top |
| `pressed_groove.tres` | `pressed_groove_ai.png` (10x24) | 0/6/0/6 | 0 | yes | The scroll groove, stretched between its 6px ends. No variant uses it |
| `pressed_thumb.tres` | `pressed_thumb_ai.png` (4x8) | 0/2/0/2 | 0 | yes | The groove's thumb, stretched between its 2px ends. No variant uses it |

**A separator's style needs margins that add up to its height.** An `HSeparator` draws its style at the style's minimum height, centred in its `separation`, and a `StyleBoxTexture` has no height of its own beyond its margins. With top and bottom margins of 0 the rule is 0px tall and never draws (measured in 4.7.2), so `pressed_rule.tres` carries 2px content margins top and bottom, the 4px of its art, and `HSeparatorPressed` has `separation` 4. `test_pressed_rule_is_as_tall_as_its_separator` guards it. Any other `StyleBoxTexture` used as a separator needs the same.

`book_theme.tres` also holds `StyleBoxEmpty` sub-resources: the one `PanelBookBare` draws, and `LabelBookFilter`'s, with the same 10/6/10/4 content margins as `pressed_lozenge.tres`.

## RichTextLabel variants

RichTextLabels **cannot** use Label-based variants (different base type). `pixel_theme.tres` has one RTL variant:
- `RichTextLabelDark` — dark brown default color `#2A1A12` for light backgrounds (`ItemDescriptionPanel`)

`book_theme.tres` has two more for the pressed pages, `RichTextBookDetail` and `RichTextBookValue` (see [Menu book pages](#menu-book-pages)).

For RTLs that need a custom size, set `theme_override_font_sizes/normal_font_size` directly. Match one of the Label variant sizes for visual consistency (e.g. use 22 if body text elsewhere uses `LabelBody`).

## HSeparator variants

- Base `HSeparator` (no variant) — 2px copper `#C4884A` line, inset 8px at each end.
- `HSeparatorItemDesc` — 2px parchment `#E9CEAD`, no inset, separation 12. Top separator under the item type in `ItemDescriptionPanel`.
- `HSeparatorItemDescThin` — 1px parchment `#E9CEAD`, inset 100px at each end, separation 10. Separates the description from the effects in the same panel.
- `HSeparatorResourcePanel` — 2px gold `#D4A84A` at 60% alpha, no inset. Unused since the lacquer cultivator cabinet replaced the zone view's old resource panel, whose orbs it divided.

## Other variants

| Variant | Base type | Style |
|---------|-----------|-------|
| `ButtonEndCard` | `Button` | Scroll button styleboxes (`assets/styleboxes/buttons/scroll/`), 20px, cream font `#F0E0C2` |
| `CyclingTabContainer` | `TabContainer` | `common/tab_*` styleboxes; selected gold, unselected tan, hovered beige. Unused |
| `PanelAccent` | `PanelContainer` | `common/panel_accent.tres` (brown 92%, 3px copper border). Unused |
| `PanelLootTray` | `PanelContainer` | `common/panel_loot_tray.tres` (translucent parchment) |
| `PanelStatPill` | `PanelContainer` | `abilities/stat_pill.tres` (small dark pill). No screen shows it |
| `PanelTooltip` | `PanelContainer` | `abilities/tooltip_panel.tres` (dark brown, 2px copper border) |

Base types without a variant:

- `Panel` and `PanelContainer` default to `common/panel_tan.tres` (tan parchment texture).
- `Button` uses `buttons/button_default_normal.tres`, `button_default_pressed.tres`, and `button_default_hover.tres` for both hover and disabled, with a gold hover/pressed font colour.

## Lacquer theme (zone view)

The map-first zone view ("Lacquer and brass") has its own theme, `assets/themes/lacquer/lacquer_theme.tres`. Sizes and colours come from the art kit's §2 and §3 ([2026-10-21-zone-view-lacquer-kit.md](superpowers/specs/2026-10-21-zone-view-lacquer-kit.md)).

**Rule:** every zone-view panel (cultivator cabinet, Goals board, log board, dock, zone chest, map plates and popovers), the cycling board and every adventure board (vitals cabinet, chest, technique dock and their tooltips) sets `theme = lacquer_theme.tres` on its root and gives its Labels the `LabelLacquer*` variants below. Everything else (base types, `pixel_theme.tres`'s own variants) still falls back to `pixel_theme.tres`.

How the theme is built, so a reused piece inside a lacquer panel keeps its own look:

- **No defaults.** The theme sets no `default_font` or `default_font_size`. A default would answer for every type, `pixel_theme.tres`'s variants included, before Godot reached them (the `LabelMerchantTitle` problem above). Each variant sets its own `font` and `font_size` instead. `test_theme_sets_no_defaults` guards this.
- **Shadows.** `pixel_theme.tres`'s base `Label` draws a 1 px ink shadow. The four painted titles and `LabelLacquerCooldown` (a number painted over an icon) set the kit's hard 2 px shadow (`#150909`, offset 2, 2, `shadow_outline_size` 0). Every other lacquer variant sets a transparent `font_shadow_color`, so it draws none.
- **Line pitch.** Each variant's `line_spacing` is the kit's line height minus the font's height at that size, so wrapped lines (lore, two-line card details, popover bodies) step by the kit's line height. A single-line Label is only the font's height (17 px for 15 px BM Euljiro), not the kit's line height. `LabelLacquerCooldown` is the exception to the rule: it is one line by design and sets no `line_spacing`.
- **Placing a Label against the mock.** The mock's text sits in CSS line boxes, a Label is the font's height, so a Label's top is the mock's top plus (the kit's line height − the font's height) / 2. The cabinet's 30 px figures (a 36 px line) sit 1 px lower than the mock's top (y 44 and 132 where the CSS tops are 43 and 131). The adventure chest's Yatra 30 title (45 px tall on a 44 px line) sits 1 px higher (y 17 where the CSS top is 18), as the zone chest's name does (15 for 16). A font shorter than its line, centred in a fixed-height rect (the 18 px clock text in a 22 px line), needs no correction.
- **Flowing rows on even y.** A wrapping `LabelLacquerLore` Label is 22 n − 3 px tall for n lines, so a flow pads it 2 px above and 1 px under (a `StyleBoxEmpty`), which makes n lines 22 n tall and seats the glyphs where the mock's 22 px line boxes do. A wrapping `LabelLacquerDetail` (15/18) or `LabelLacquerNowName` (18/22) Label is 18 n − 1 or 22 n − 1 tall, so it takes `wrap_pad.tres` (below) as its `normal` style: n lines are then 18 n or 22 n, and a single line is 18 or 22 (the Label alone is 17 or 21). A 17/20 `LabelLacquerName` line is 20 px already and takes no pad. Every row then stays on an even y (`ExpeditionPage`, `ChoiceDrawer`, `GoalsPanel`, `NowStrip`).
- **Text wraps; it is never cut off.** On a lacquer board a Label that can run long sets `autowrap_mode` to word smart (3) and a `custom_minimum_size.x`, and has no `text_overrun_behavior` and no `clip_text`; the board grows with the lines (STYLE_GUIDE rule 14 and §5, Long text). A Label whose width changes is given the new width as its minimum and as its size, and `update_minimum_size()` is called, or the boxes above keep its last height. `tests/integration/test_boards_never_trim_text.gd` walks the reworked boards' Labels for it, and reads every scene and script under `res://scenes` for it, failing for any file that trims or clips text and is not on `KNOWN_TRIMMERS` (the files not yet swept).
- **Fonts.** Yatra One (`assets/fonts/YatraOne-Regular.ttf`) for the painted titles, BM Euljiro for everything else. Tags and seals use a `FontVariation` of BM Euljiro with 1 px letter spacing (`spacing_glyph = 1`).
- **Tag and seal indent.** The 1 px letter spacing also trails the last letter, which would pull centred text 0.5 px left. Tags and seals therefore have a `normal` style of their own, a `StyleBoxEmpty` with a 1 px left content margin: the mock's `text-indent: 1px`. For the mode tags, NEW and UNKNOWN, give the Label the tag's or seal's full width (76 px for a tag) and centre the text. Add no offset of your own.
- **The LOCKED seal is the exception.** Its word is left-aligned, not centred: `mini_lock` sits at seal +8, +3 and the word starts at seal +26 (kit §4.2; the mock has no `text-indent` there). The variant's 1 px indent still applies, so put the `LabelLacquerSeal` at seal-local x 25, left-aligned, and the word lands on +26. A Label placed at +26 draws its word at +27, off the 2 px grid.

Colours: brass `#D4A84A`, cream `#F0E8D8`, tan `#A89070`, ink `#150909`.

| Variant | Font, size / kit line height | Colour | Use for |
|---------|------------------------------|--------|---------|
| `LabelLacquerZoneName` | Yatra 30 / 44, shadow | Brass | Zone name in the chest header |
| `LabelLacquerPanelTitle` | Yatra 22 / 28, shadow | Brass | Panel titles: Goals, Log |
| `LabelLacquerSection` | Yatra 20 / 24, shadow | Brass | The Activities and Techniques headers |
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
| `LabelLacquerFloater` | Euljiro 16 / 20 | Cream | Nothing today. `LacquerFloater` (the map's floater and the cycling zones') puts its text in a `RichTextLacquer` at 16 px instead (see below), so a decimal (`+1.5 Madra`, Madra blue) gets its Yatra point. No outline (`outline_size` set to 0): the kit's §0 dropped it when the floaters moved onto the token |
| `LabelLacquerCooldown` | Euljiro 22, shadow | Cream | A technique's cooldown seconds, centred on its ability icon. The painted titles' 2 px ink shadow keeps the number readable over any icon. Single line only: it sets no `line_spacing`, so do not wrap it |

`RichTextLacquer` (base `RichTextLabel`): BM Euljiro 15, tan, `line_separation` 1, so each line is 18 px (15/18), the first included. Use it for the few lines with a decimal number: BM Euljiro's `.` sits low and reads as a comma at 15–17 px, so `LacquerText.decimal_bbcode()` sets each decimal point in Yatra One (kit §3, glyph gaps). Set `bbcode_enabled`, `fit_content` and, for one-line text, `autowrap_mode` off.

- **The dot never grows its line.** Yatra One's ascent and descent run up to 3 px past BM Euljiro's, so a plain Yatra dot would make a 15 px line 24 px tall and drop its baseline 3 px. `decimal_bbcode()` writes the dot as `[font name=…YatraOne-Regular.ttf top_spacing=-3 bottom_spacing=-3]`, the mock's `.pt { line-height: 0 }`. At 13 to 18 px a line with a decimal is exactly as tall as the same line without one (`test_decimal_point_never_grows_a_line`). Above 18 px the trim is not enough: check the line height before using it there.
- **Other sizes.** Override `normal_font_size` for the 16 px Now rate and floater or the 17 px cabinet rate, and the colour (`default_color`) where the kit colours the line. The line is then the font's height + 1: 20 px at 16, 21 at 17. The kit's cabinet rate is 17/20, but it is one line, so only its box is 1 px taller: the baseline is where a Label's would be.
- **No `text_overrun_behavior`.** A `RichTextLabel` cannot ellipsize, and on a reworked board it wraps instead (`fit_content`, `autowrap_mode` word, a width). An activity card's detail line, one of the surfaces that still trims (STYLE_GUIDE §5, Where text still trims), goes through `ZoneActionButton.fit_detail_rich_text()`, which drops whole words until the line fits its width (316 px, kit §5.5), ends it in `…` with no separator left before it, and then applies `decimal_bbcode()`.
- **Not `[font=path]` with a `FontVariation` file.** In Godot 4.7.2 a `[font=…]` tag that loads a `FontVariation` `.tres` drops its `spacing_top` / `spacing_bottom` (measured: the line still grows to 24 px), while `push_font()` with the same object keeps them. Put the spacing in the tag's options, as `decimal_bbcode()` does.

`RichTextLacquerLog` (base `RichTextLacquer`): the same 15 px tan text with `line_separation` 9, so lines are 26 px apart, the first included: the log's line pitch (kit §0). The full log's `FullLogText` uses it; give such a text area a height that is a whole number of 26 px lines (it is 468, 18 lines), or a sliver of an older line shows at its top when it sits scrolled to the bottom.

Per-label colour overrides on top of these variants are expected where the kit colours by state: log lines by tone and age, plate names on hover, RUNNING and ENTER tags, Madra-blue text.

### Lacquer styleboxes (`assets/styleboxes/lacquer/`)

Six `StyleBoxTexture` 9-slices of kit textures, drawn with nearest filtering at their file scale, and one empty pad:

| File | Texture | Margins | Fill | Use |
|------|---------|---------|------|-----|
| `board9.tres` | `lacquer_board9_ai.png` (28x28) | left and top 8, right and bottom 12 | yes | The plain board under the technique and buff tooltips. The 4 px shadow is baked into the right and bottom edges |
| `frame_brass.tres` | `lacquer_frame_brass_ai.png` (24x24) | 8 | none | Flash frame on cards, technique drawers and the Now tray, pinned map plates |
| `frame_hover.tres` | `lacquer_frame_hover_ai.png` (16x16) | 4 | none | Hover frame on cards, technique drawers, the Now tray, the Auto toggle, Show me, About |
| `rail_thumb.tres` | `lacquer_rail_thumb_ai.png` (12x12) | top and bottom 4 | yes | The activity list's rail thumb, any even height of 32 or more |
| `token.tres` | `lacquer_token_ai.png` (26x26) | left and top 6, right and bottom 8 | yes | `LacquerFloater`'s token, for the map's floater and the cycling zones'. The 2 px shadow is baked into the right and bottom edges |
| `trib_board9.tres` | `tribulation/lacquer_trib_board9_ai.png` (164x164) | left and top 56, right and bottom 60 | yes | The Tribulation board's frame: a strapped board (brass-strapped corners, one strap worn and a nail lost) whose 28 art px corners are the only part with detail, so the middle stretches cleanly to any size. The 4 px shadow is baked into the right and bottom edges |
| `wrap_pad.tres` | none (a `StyleBoxEmpty`) | bottom content margin 1 | none | The `normal` style of a wrapping 15/18 or 18/22 Label (the Here tray's name and line, the walk hint and lock line, a drawer's detail, the Goals board's step and milestone lines, the Now strip's wrapping labels), so its lines come to 18 n or 22 n. On the pressed pages, the pad of a wrapping Label whose one line is odd (see [Pressed pages](#pressed-pages)). Not for a 17/20 name (20 px a line already) or the lore label (it has a pad of its own) |

`token.tres` also sets content margins 14, 4, 16 and 6 (left, top, right, bottom), so a `PanelContainer` with this style hugs one 20 px text line to the kit's token: 30 px tall (28 + the 2 px shadow), the text 14 px in and 4 px down, and text width + 30 wide (text + 28 + the shadow). A 16 px `RichTextLacquer` line is 20 px already (`test_token_hugs_a_floater_line`). A one-line `LabelLacquerFloater` is 19 px, so give it `custom_minimum_size.y = 20`. The kit rounds the token's width to even (`even(text + 28)`): the floater sets that width itself.

`board9.tres` also sets content margins 16, 14, 20 and 18 (left, top, right, bottom; `test_board9_margins` pins the margins): the text sits 16 px in and 14 px down, and the right and bottom margins are the same 16 and 14 plus the 4 px baked shadow. A `PanelContainer` with this style therefore pads its content 16 px left and right and 14 px top and bottom inside the board's visible edge, and is 4 px wider and taller than that board.

`trib_board9.tres` sets content margins 24, 20, 28 and 24 (left, top, right, bottom; `test_tribulation_art.gd` pins the margins). The Tribulation board is a `PanelContainer` on it, 952 px wide with no set height, so the 900 px stage frame sits 24 px in from the left and 28 from the right (24 plus the 4 px baked shadow), and the board grows with the text it holds.

### Lacquer pieces (`scenes/common/lacquer/`)

- **`LacquerStripRect`** (`lacquer_strip_rect.gd`, a `TextureRect` script): set `strip` and `frame_size`, then `set_frame(column, row)` shows that frame through the rect's own `AtlasTexture` (orbs, XP beads, timer rings). Frames clamp to the strip. It is `@tool`, so a placed rect shows frame 0 in the editor. Its `texture` is derived and read-only, and is never saved into the scene: `strip` and `frame_size` are.
- **`LacquerRod`** (`lacquer_rod.tscn`): set `empty_texture`, `full_texture`, `end_texture` and `steps`, then `set_fraction(f)`. It shows the full rod clipped to width 2 + 2k with the end cap at x = 2k once k ≥ 2, k = round(f × steps) (kit §4.3). Steps: Now strip 144 (`lacquer_rod_now_*`, 292 px), milestone 138, adventure 74, Stamina and cast 119. The Aura Well's 152-step, 308 px `lacquer_rod_well_*` has no scene now. It is `@tool`: in the editor a placed rod is the groove's size and shows empty. Its minimum size comes from `empty_texture`, so leave its size and `custom_minimum_size` alone.
- **`LacquerFrameOverlay`** (`lacquer_frame_overlay.tscn`, a `Panel`): a full-rect frame over its parent, hidden, mouse ignored, brass by default. Override its `theme_override_styles/panel` with `frame_hover.tres` for the hover frame. `flash(times)` shows it 300 ms and hides it 300 ms, `times` times, and ends hidden. The ready adventure card shows one steadily (`ZoneActionButton.set_ready_frame()`); never animate a steady frame.
- **`LacquerText`** (`scripts/utils/lacquer_text.gd`): `rate(1.5)` → `"+1.5"`, `rate(2.0)` → `"+2"`; `decimal_bbcode(text)` for `RichTextLacquer`.
- **`LacquerFloater`** (`scenes/common/lacquer/lacquer_floater/lacquer_floater.tscn`, promoted from the map's floater when the cycling view needed one per zone): a short gain on a lacquer token (`token.tres`). `pop(text, color)` shows it and `stop()` hides it. It rises 40 px over 1 s in 2 px steps (`rise_at(elapsed)`, `get_rise()`), then hides outright. It does not move itself: the placer positions it each frame and raises it by `get_rise()` (`MapMarkers` for the map's floater, `CyclingView` for each zone's). Its text is a `RichTextLacquer` at 16 px (a `normal_font_size` override) through `decimal_bbcode()`, in the colour given to `pop()`, not a `LabelLacquerFloater` Label, so a decimal point gets its Yatra point. The token is 28 px tall and `even(text width + 28)` wide, plus the baked 2 px shadow.
- **Cycling pieces.** The cycling board sets `lacquer_theme.tres` on its root ([CYCLING.md](cycling/CYCLING.md)). Its action name and `Auto` label are `LabelLacquerDetail`, the technique's name `LabelLacquerPanelTitle`, `Esc` `LabelLacquerHotkey`, and the status line `LabelLacquerName`. The board has no result line: the zone chest shows the last cycle's under its Now tray, in a `LabelLacquerDetail` (`%LastCycleLabel`). Its Madra is a whole number, so it needs no `RichTextLacquer`. A `TechniqueDrawer` in the zone chest uses `LabelLacquerName` for the title, `LabelLacquerDetail` for the line, `LabelLacquerSeal` for NEW and `LabelLacquerTag` for IN USE (cream), with `frame_hover.tres` and `frame_brass.tres` overlays. `CyclingGroove` draws its cells in code from the `LACQUER_*` constants and needs no theme.
- **Tribulation pieces.** The Tribulation board sets `lacquer_theme.tres` on its root ([breakthrough-tribulation.md](cultivation/breakthrough-tribulation.md)). Its zone name, the rules line, the buttons' words, the stats line and the phase tip are `LabelLacquerDetail`, its title and the panels' titles `LabelLacquerPanelTitle`, the panels' lore lines `LabelLacquerLore`, and the grade and the phase name `LabelLacquerName`; a wrapping 15/18 label takes `wrap_pad.tres`. The board's frame is `trib_board9.tres`, and the panels over the stage are a `PanelContainer` with an empty style stacking a `NinePatchRect` face on `lacquer_drawer9_ai.png` (patch margins 4, 4, 6, 6). The ring, the core and the crack pips are `LacquerStripRect` strips (`assets/ui/lacquer/tribulation/`), the board's progress rod is a `LacquerRod` on the goal rod's art (138 steps), the zone card's Core rod a `LacquerRod` on `lacquer_rod_core_*_ai.png` (74 steps), the buttons `TextureButton`s on the About button's art, and the word floaters `LacquerFloater`s. The spheres and the hold arc have no art: `TribulationStage` draws them per 2 px cell from the same band rule the ring art follows.
- **`LacquerRail`** (`scenes/zones/zone_panel/lacquer_rail/lacquer_rail.tscn`): the brass scroll rail (kit §4.4) that stands in for a `ScrollContainer`'s hidden scrollbar. `bind(host)` follows the host's scroll; it shows only while the content overflows, lights each end cap only when the list can scroll that way, sizes its thumb (`rail_thumb.tres`) from the visible share, and `step_to(target)` scrolls in six even-px steps over 200 ms. The zone chest's activity list uses it; the full log styles its own scrollbar's caps with the same textures.

Tests: `tests/integration/test_boards_never_trim_text.gd` walks the Labels of the adventure chest, cast tray, tooltip, Goals board and Now strip for an ellipsis or clipping, and reads every scene and script under `res://scenes` for either, against its `KNOWN_TRIMMERS` list. `tests/unit/test_lacquer_pieces.gd` checks every variant's font, size, colour and shadow, the line pitch measured on real Labels and RichTextLabels (decimal lines included), the tag indent, the styleboxes' margins (`board9.tres` included; `trib_board9.tres` is in `test_tribulation_art.gd`) and `wrap_pad.tres` (its 1 px bottom pad, and the uid the scenes that use it name it by), the token hugging a floater line, the pieces, and the Madra orb shader's colour uniforms and their defaults.

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

`scripts/utils/theme_constants.gd` (`class_name ThemeConstants`) holds colours for code that sets them at runtime. Its header names the themes (`pixel_theme.tres` and `lacquer/lacquer_theme.tres`) as the source of truth.

| Constant | Value | Matches in theme | For |
|----------|-------|------------------|--------------------|
| `ACCENT_GOLD` | `#D4A84A` | Gold Label variants | Gold highlights set from code (the path tree). The lacquer dock buttons swap textures on hover instead |
| `LACQUER_INK` / `LACQUER_BRASS` / `LACQUER_CREAM` / `LACQUER_TAN` | `#150909` / `#D4A84A` / `#F0E8D8` / `#A89070` | The `LabelLacquer*` variants | The lacquer views (lacquer kit §2). The last three are also the cycling hit tiers |
| `LACQUER_RIM` | `#692F2F` | — | The lip under the cycling groove |
| `LACQUER_DIM` / `LACQUER_VERMILION` | `#94806A` / `#A83C30` | — | Old log lines, seals |
| `LACQUER_MADRA_HI` / `LACQUER_MADRA` / `LACQUER_MADRA_MID` | `#E8F6FD` / `#BBD5E7` / `#849BE4` | — | The lit cycling groove (top edge, body, bottom edge). `LACQUER_MADRA` is also Madra text |
| `BOOK_MADRA_INK` | `#1C2F60` | — | Madra amounts in the text of the book's paper pages. A Label variant colours a whole label, so the amount takes this colour in BBCode. The lacquer Madra tints read on dark lacquer, not on cream |
| `LACQUER_HEALTH` / `LACQUER_STAMINA` | `#E8737A` / `#C9DB86` | — | The text steps of the Health crimson and Stamina bamboo ramps, kept for the fight's floaters. Nothing reads them yet |

Use the Label variants for sizes. Use `ThemeConstants` only for colours that must be set from code, and keep each value in step with its theme.

## Theme and asset files

| Path | Contents |
|------|----------|
| `assets/themes/pixel_theme.tres` | Project theme: base types, all variants above except the book, merchant and lacquer ones |
| `assets/themes/book_theme.tres` | Menu book page variants ([Menu book pages](#menu-book-pages)) |
| `assets/themes/lacquer/lacquer_theme.tres` | Zone view theme: the `LabelLacquer*` variants and `RichTextLacquer` (see Lacquer theme) |
| `assets/themes/pixel_ui_theme/` | Third-party pixel UI pack: `8x8_ui_elements*.png` and `8x8_ui_icons.png` atlases, `m5x7.ttf`, 8 colour-variant `PixelTheme-*.tres`, `TabContainer.tscn`. `pixel_theme.tres` uses only the two base atlases; the variant themes are not referenced by the game. |
| `assets/styleboxes/` | StyleBox `.tres` grouped by area: `abilities`, `book` (the pressed pieces), `buttons` (+`scroll`), `combat`, `common`, `inventory`, `lacquer`, `merchant`, `textures`, `ui`, `zones` |
| `assets/fonts/` | `BMEULJIROTTF.ttf` (theme font). `YatraOne-Regular.ttf` (the lacquer theme's painted titles and the book theme's pressed-page titles). `Korean_Calligraphy.ttf`, `pixelmix.ttf` and `Ubage-woA3P.otf` are loaded only by the label testing scene. |
| `assets/sprites/` | Exported PNGs by system: `abilities`, `adventure`, `atmosphere`, `character`, `combat`, `cycling`, `inventory`, `items`, `path_progression`, `tilemap`, `ui` (`ability_button`, `action_buttons`, `attribute_icons`, `buff_icon`, `resource_bar`, `resources`, `stat_icons`, `system_menu`, `book` (menu book bookmark, close tab, stage icons, padlock, 2x panel art), `lock_icon.png`), `zones/backgrounds/spirit_valley` (`layer_00..11.png`) |
| `assets/aseprite/` | Aseprite sources: `abilities`, `character_profiles`, `cycling`, `ui/{ability_button,buff_icon,resource_bar}`, `zones`, plus root `madra_circle.aseprite`, `Sprite-0003*.aseprite` and a stray `Sprite-0003.gif` |
| `assets/shaders/` | 10 `.gdshader` files (`palette_swap.gdshader` recolours the menu books) |
| `assets/scroll/` | Scroll art (and `parts/`) used by the adventure end card |
| `assets/dialogue/` | Dialogic `characters/`, `styles/` (including `dialogue_backgrounds/custom_background_layer.gd`), `timelines/` |
| `assets/colors/` | `default_color_palette.tres` (not referenced by game scenes or scripts) |

There is no `assets/audio/` folder; the project has no audio files. The 2026-04-15 asset cleanup ([spec](superpowers/specs/2026-04-15-assets-folder-cleanup-design.md)) produced this layout.

## Known issues

- `[MEDIUM]` The label testing scene is stale (see above).
- `[LOW]` `assets/styleboxes/textures/panel_dark_texture.png` and `bamboo_panel_texture.png` are unreferenced: the styleboxes that used them were deleted as dead code. Delete or reuse the textures.
- `[LOW]` `pixel_theme.tres` still carries Godot 3-style item names inherited from the pixel UI pack, which Godot 4 does not read. Examples: `Button/colors/font_color_hover`, `font_color_pressed`, `font_color_disabled`, and `*/constants/hseparation`. The Godot 4 names (`font_hover_color`, etc.) are also present for `Button`.
- `[LOW]` A few UI files still set sizes inline instead of using a variant. Examples: the dev panel title (`LabelHeading` + 20px) and `scenes/tools/encounter_id_label.tscn` (bare Label + 11px).
- `[LOW]` Some non-snake_case asset names remain outside the cleanup spec's rename list: `sprites/cycling/Cycling_Technique_Background.webp`, `sprites/cycling/Madra-Ball.png`, `aseprite/Sprite-0003*.aseprite`, `aseprite/ui/resource_bar/Sprite-0001.aseprite`. Also, `sprites/tilemap/hex_selector_spritesheet.aseprite` is a source file sitting in `sprites/`.
