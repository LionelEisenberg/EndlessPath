# Style Guide: Lacquer and Brass

The game's visual style, taken from the zone view rework, and the list of screens still to move to it. Read it before you rework a screen or build a new one.

## 1. What this is

- **Status.** Distilled from the zone view rework (PR #51). The zone view, the two HUD boards it shares with the adventure view (Log and Goals), the cycling view, the adventure view's map and frame (vitals cabinet, chest, technique dock) and the Tribulation board use the look today. The rest of [§13](#13-cascade-backlog) is still to do, the adventure's fight view and end card included. This doc changes no code.
- **Use it as a reference in other branches.** Each later branch takes one area of the backlog, applies these rules, and deletes its rows here.
- **The kit's files come with that branch.** The textures (`assets/ui/lacquer/`), the theme (`assets/themes/lacquer/lacquer_theme.tres`), the styleboxes (`assets/styleboxes/lacquer/`), the components (`scenes/common/lacquer/`, `LacquerRail`, `LacquerText`), the two orb shaders and the generators all arrived with PR #51, and the adventure's pieces (the technique dock's slot and key cap, the buff and glyph sockets, the tooltip board, the coin tokens, the veil atlas, the cooldown sweep shader and their generators in `docs/superpowers/mockups/adventure-view-lacquer/gen/`) with PR #58. A branch cut from `main` before those merges does not have them.
- **How it relates to the other docs:**

| Doc | What it holds | Who wins |
|---|---|---|
| [Lacquer kit](superpowers/specs/2026-10-21-zone-view-lacquer-kit.md) | Every zone view texture, its size, its placement in screen px, and the user's review changes (§0 and the build notes) | The kit, for anything in the zone view |
| [UI_STYLING.md](UI_STYLING.md) | Every theme variant (`pixel_theme`, `book_theme`, the lacquer theme), the lacquer styleboxes and pieces | UI_STYLING.md, for variant names, sizes and colours |
| This guide | The rules behind the kit, the patterns to reuse elsewhere, and the cascade backlog | This guide, for screens outside the zone view |

## 2. The look in brief

**What the user rejected.** On 2026-10-21 the user found the round-3 zone view "very AI": teal halos on everything, glow, thin luminous borders, teal tints, translucent dark-glass panels. Most of the game outside the zone view still looks like that.

**What the user chose.** "Lacquer and brass", picked the same evening from three swatches of the same slice (field journal, lacquer and brass, classic pixel windows):

- dark red-brown lacquered wood boards with hand-placed grain;
- brass straps, caps and painted titles;
- cream and tan text;
- jade only for progress fills, Madra blue for Madra, cinnabar (vermilion) seals;
- one 2x pixel grid, hard offset shadows, motion in whole steps;
- no glow, blur, gradient or fade.

The user saw the finished zone view on 2026-10-22 and asked for the look to be carried to the rest of the game, one area at a time.

## 3. Principles

| # | Rule | Why |
|---|---|---|
| 1 | **One grid.** One art pixel is 2 screen px. `lacquer_*_ai.png` files are drawn at 2x already: show them at their file size, never scaled. Native art (hex tiles, the character sheet, `ic_*_ai.png` icons) shows at exactly 2x. | Mixed pixel sizes are the quickest way to look cheap. One grid makes every piece look drawn by one hand. |
| 2 | **Nearest filtering and even px.** Nearest filtering everywhere, SubViewports included. Every position and size is even. The one exception is the zone map's odd hex rows (kit §6.1). | Linear filtering and odd offsets blur pixel edges. |
| 3 | **Opaque materials.** Every surface is an opaque texture: lacquer, brass, carved recesses (and paper in the books). No translucent panels. | Translucent dark glass was the core of the rejected look. |
| 4 | **Brass marks state.** Anchor furniture (the cultivator cabinet, the zone chest) gets chunky brass straps. Secondary boards (Goals, Log, Dock, lore, popover previews) are plain. Brass caps go only on what is running, pinned or hovered. | If everything is brass, nothing stands out. |
| 5 | **Colour has one meaning.** Jade (`#5CC4A0` ramp) only for progress fills. The Madra blue ramp only for Madra. Vermilion only for seals and locked rims. Brass for straps, titles and rewards. | A small palette with fixed meanings reads at a glance. |
| 6 | **Hard offset shadows only.** 4 px `#050707` for big pieces, 2 px `#150909` for small ones, baked into the texture. | Soft shadows are blur. Baked shadows stay on the grid. |
| 7 | **State by art, not by tint, alpha or scale.** Show a state with a texture swap, a frame overlay, a pulled-out drawer or a seal. | Tints, alpha dims and scale pops were the old look's state language. |
| 8 | **Motion in whole steps.** Frame strips, 2 px moves, held keyframes. Show and hide outright. | Eased tweens and fades read as a UI framework, not pixel art. |
| 9 | **Never:** glow, halo, blur, soft gradients (linear, radial, conic), opacity fades, translucency, overbright modulate (above 1), rounded pills, thin luminous borders, emoji. | This is the "AI look". |
| 10 | **Panels hug their content.** A board is as tall as what it holds. | Big empty boards waste space and take weight from the map. |
| 11 | **No text under 13 px.** | A pixel font at 1080p stops reading below that. |
| 12 | **The user's own art first.** Use the user's files from their own paths. Agent-made art ends in `_ai`. Never edit a user file: write an `_ai` file next to it (CLAUDE.md, AI-Generated Art). | The user must be able to tell their art from agent art. |
| 13 | **UI lives in scenes.** Nodes go in `.tscn` files, styling in theme variants and shared `.tres` styleboxes. Scripts set data, textures, visibility and state colours. | The user's standing rule. It keeps the UI inspectable in the editor. |
| 14 | **Text is never cut off.** A Label that can run long wraps by word at a width the scene gives it, and the board it stands on grows with it. No ellipsis (`text_overrun_behavior`), no `clip_text`, no clipping container. A board that must grow stands on a 9-slice (or a stack of slices), never on a fixed texture. See [Long text](#5-type) | A name that ends in `…` hides what it names, and the game's text is open-ended (authored names, quest steps, lore). The user's standing rule from review round 1 of the adventure rework (2026-10-23), for the whole game |

### What to use instead

| Old look | Lacquer answer | Example in the zone view |
|---|---|---|
| Translucent dark panel | Opaque lacquer board with a baked hard shadow | Cabinet, chest, Log |
| Soft or blurred shadow | 4 px or 2 px hard offset, baked | Every kit piece |
| Glowing ring or border | Brass rim, brass frame, carved line | Current hex rim, `frame_brass` |
| Thin luminous border | Carved divider or brass strap | `lacquer_line_ai.png` |
| Gradient | 2-step dither | Shelf lips over a scrolled list |
| Opacity fade | Show or hide outright; a dither dissolve if a crossfade is truly needed | Floaters, popovers |
| Eased tween | Stepped move or frame strip | Floater rise, walk, rail scroll |
| Scale pop or pulse | Frame flash | Card flash |
| Tint for selection or hover | Frame overlay or texture swap | `frame_hover`, dock button faces |
| Alpha for disabled or locked | Palette state: tan text, carved "off" art, a seal | Rail caps off, LOCKED seal |
| Rounded pill | Carved tag or cinnabar seal | Mode tags, NEW |
| Glowing particles | Opaque pellets moving in 2 px steps | Madra drain pellets, the cycling view's Madra and XP pellets |
| Vignette, mists, motes | Nothing: the opaque boards frame the view | Zone view and adventure map (dropped; combat's are still to go) |
| Ellipsis or clipped text | Wrap to the next line and grow the board (rule 14) | Here tray, choice drawers, Goals board, Now strip, cast tray |

## 4. Palette

The kit's §2, unchanged. Hex values are exact.

| Hex | Name | Used for |
|---|---|---|
| `#150909` | ink | Outlines, carved lines, the empty rod groove, small hard shadows, text on brass |
| `#110707` | socket | Inside carved sockets (core orb, rail groove) |
| `#230F0F` | deep | Shaded rims, recessed tags and trays |
| `#2C1414` | lacquer | Board fields |
| `#321616` `#391919` | grain | Hand-placed grain streaks |
| `#462020` | raised | Drawer and button faces, the gloss band |
| `#612B2B` | rim shade | Lit lower lips of grooves, hot gloss, a hovered rim |
| `#692F2F` | rim | Lit rims of raised lacquer |
| `#D4A84A` | brass | Straps, caps, notification ring, painted titles, ENTER, reward text |
| `#A66834` | brass shade | Shaded brass, nail heads |
| `#F0E8D8` | cream | Main text, the brass highlight |
| `#A89070` | tan | Labels, secondary text, dotted rims, route dots |
| `#7A654C` | tan shade | Glyph and dot shading |
| `#94806A` | dim | The oldest log lines (4.56:1 on lacquer, the contrast floor) |
| `#AAECCE` `#5CC4A0` `#2F6B4A` `#102C1E` | jade ramp | Progress fills only |
| `#E8F6FD` `#BBD5E7` `#849BE4` `#1C2F60` `#16283E` | Madra ramp | Madra orb, adventure rod, core swirl, Madra text |
| `#FFD9D2` `#E8737A` `#B8304A` `#5A1626` `#3A0E18` | crimson ramp | Health: the Health orb, Health text (`#E8737A`, 5.9:1 on lacquer), and the Here tray's lock line while a refusal shakes the tray |
| `#EEF5C8` `#C9DB86` `#8FAE3E` `#3E5418` `#1E2A0C` | bamboo ramp | Stamina: the Stamina rod, Stamina text (`#C9DB86`, 11.5:1 on lacquer) |
| `#A83C30` `#7E2A22` | vermilion | Seals (NEW, LOCKED, count), locked rims |
| `#341E0E` `#E3B95A` `#C4884A` | coin gold | Coin and star icons |
| `#090E0E` | map ground | Screen background, grout between hexes |
| `#0C1312` `#111A19` `#16211F` `#1D2B28` | fog tier 1 | Tier-1 fog pixels |
| `#182423` `#0F1716` `#111A19` `#131D1C` | fog tier 2 | Tier-2 fog (etched lines) |
| `#0D1514` | fog tier 3 | Flat silhouettes |
| `#151A18` `#39423E` `#4B5550` `#5F6A65` `#76827C` | locked veil | Locked tile (hover: one step up), a cooling technique's icon (the cooldown sweep), a cleared encounter's glyph |
| `#0B1211` `#16211F` `#1C2927` `#243431` `#2D3F3B` | uncharted veil | Uncharted tile, the adventure's revealed tiles (hover: one step up) |
| `#FFD1AB` `#E7A581` `#CF7957` `#17111A` | skin | Sampled from the user's `ability_icon.png` |
| `#FFFFFF` `#BFDDD1` `#95ADB4` `#86718C` `#2E1C2C` | armour | Sampled from the user's `character_icon.png` |
| `#050707` | shadow | 4 px hard shadows |

**Contrast.** Text on lacquer stays at 4.56:1 or more (dim is the floor). Kit §3 lists the contrast of every text role.

**From code.** `scripts/utils/theme_constants.gd` exposes twelve lacquer colours for code that sets a colour at runtime (log tones, plate hover, floater colour, the cycling groove, the Health and Stamina tones):

| Constant | Value |
|---|---|
| `ThemeConstants.LACQUER_INK` | `#150909` |
| `ThemeConstants.LACQUER_RIM` | `#692F2F` |
| `ThemeConstants.LACQUER_BRASS` | `#D4A84A` |
| `ThemeConstants.LACQUER_CREAM` | `#F0E8D8` |
| `ThemeConstants.LACQUER_TAN` | `#A89070` |
| `ThemeConstants.LACQUER_DIM` | `#94806A` |
| `ThemeConstants.LACQUER_MADRA_HI` | `#E8F6FD` |
| `ThemeConstants.LACQUER_MADRA` | `#BBD5E7` |
| `ThemeConstants.LACQUER_MADRA_MID` | `#849BE4` |
| `ThemeConstants.LACQUER_VERMILION` | `#A83C30` |
| `ThemeConstants.LACQUER_HEALTH` | `#E8737A` |
| `ThemeConstants.LACQUER_STAMINA` | `#C9DB86` |

Sizes and fonts always come from theme variants, never from code. When a reworked screen needs another palette colour from code, add a `LACQUER_*` constant with the kit's name.

**Hit tiers.** A cycling hit is PERFECT in brass, GOOD in cream and OK in tan (the user's call on 2026-10-22; green is dropped), for the floater, the stud on the zone and the XP pellets alike. `CyclingRules.tier_color()` maps the tiers to `LACQUER_BRASS`, `LACQUER_CREAM` and `LACQUER_TAN`.

**Gaps.** Health and Stamina have their ramps. The palette still has no colour for damage taken, heals or gains, or the merchant's reds and greens ([open questions](#open-questions)). A fight's floaters will take the colour of the resource that changed (the adventure spec, PR 2). The one warning set in text is the Here tray's lock line, which turns the Health text colour (`ThemeConstants.LACQUER_HEALTH`, 5.9:1) for the length of a refusal's shake, because the user asked for a warm red and vermilion cannot be text (G2); whether that colour becomes the palette's warning text colour is still open. The Tribulation board's crack edges (`#A83C30` on a whole core, `#7E2A22` on a spent one) and its lit crack pip (`#A83C30`) use vermilion as a stand-in damage colour, although rule 5 keeps vermilion for seals and locked rims; which colour damage takes is an open palette question (G2).

## 5. Type

Two fonts, both in `assets/fonts/`:
- **Yatra One** (`YatraOne-Regular.ttf`) for painted titles only, with a hard 2 px `#150909` shadow.
- **BM Euljiro** (`BMEULJIROTTF.ttf`) for everything else, with no shadow and no outline. The one exception is `LabelLacquerCooldown`, the seconds painted over a technique's icon, which takes the painted titles' hard 2 px `#150909` shadow (offset 2, 2) so the number reads over any icon.

No text is smaller than 13 px. The lacquer theme's variants (full table in [UI_STYLING.md](UI_STYLING.md#lacquer-theme-zone-view)):

| Role | Variant | Font, size / line | Colour |
|---|---|---|---|
| Screen or zone title | `LabelLacquerZoneName` | Yatra 30 / 44 | brass |
| Panel title | `LabelLacquerPanelTitle` | Yatra 22 / 28 | brass |
| Section title | `LabelLacquerSection` | Yatra 20 / 24 | brass |
| Stage name | `LabelLacquerStage` | Yatra 21 / 28 | cream |
| Big number | `LabelLacquerBig` | Euljiro 30 / 36 | cream (`/ max` in tan) |
| Gold value | `LabelLacquerGold` | Euljiro 22 / 28 | cream |
| Names (cards, quests, `Level 32`) | `LabelLacquerName` | Euljiro 17 / 20 | cream |
| Unit after a value (`gold`) | `LabelLacquerRate` | Euljiro 17 / 20 | tan |
| Now strip name / rate | `LabelLacquerNowName` / `LabelLacquerNowRate` | Euljiro 18 / 22, 16 / 22 | cream |
| Labels, detail lines, figures, log lines | `LabelLacquerDetail` | Euljiro 15 / 18 | tan |
| Mode tags | `LabelLacquerTag` | Euljiro 13 / 22, 1 px spacing | tan (RUNNING cream, ENTER ink) |
| Seals | `LabelLacquerSeal` | Euljiro 13 / 22, 1 px spacing | cream |
| Legend on a brass plate | `LabelLacquerLegend` | Euljiro 14 / 22 | ink |
| Dock label / hotkey | `LabelLacquerDock` / `LabelLacquerHotkey` | Euljiro 14 / 18 | cream / tan |
| Lore and long text | `LabelLacquerLore` | Euljiro 16 / 22 | cream |
| Map plate name / line | `LabelLacquerPlateName` / `LabelLacquerPlateLine` | Euljiro 16 / 18, 14 / 18 | cream |
| Popover title / body | `LabelLacquerPopoverTitle` / `LabelLacquerPopoverBody` | Euljiro 18 / 22, 15 / 20 | cream |
| Floater on a token | `RichTextLacquer` at 16 px (`LacquerFloater`; `LabelLacquerFloater` is defined but unused) | Euljiro 16 / 20 | the hit's colour |
| Lines with a decimal number | `RichTextLacquer` | Euljiro 15 / 18 | tan |
| Log text | `RichTextLacquerLog` | Euljiro 15, 26 px pitch | tan |

**Decimal points.** BM Euljiro's `.` sits low and reads as a comma at 15–17 px. Any number with a decimal goes in a `RichTextLacquer` through `LacquerText.decimal_bbcode()`, which sets the point in Yatra One without growing the line (13–18 px; check the line height above 18). `LacquerText.rate(1.5)` gives `"+1.5"`, `rate(2.0)` gives `"+2"`. Where a decimal is not needed, show whole numbers (`5 s`, not `5.0s`).

**Other glyph gaps.** `›` renders blank in Euljiro: use `lacquer_chev_ai.png`. Yatra One has no `→`: keep `Lv 1 → 2` in Euljiro.

**Tags and seals.** Uppercase, 13 px, 1 px letter spacing. Give the Label the tag's full width (76 px) and centre it; the variant's 1 px indent does the rest (UI_STYLING.md, tag and seal indent). Two exceptions:
- The LOCKED seal's word is left-aligned after its `mini_lock`: put the `LabelLacquerSeal` at seal-local x 25, so the indent lands the word on +26 (UI_STYLING.md, "The LOCKED seal is the exception").
- The count seal's number is 15 px (15/18), centred across the seal at top +3 (kit §3 and §5.4). The seal is 24 px wide and widens for a longer number (`LacquerCountSeal`).

**Long text.** Text is never cut off (§3 rule 14): no ellipsis, no `clip_text`. A Label that can run long wraps, and its board grows. The cycling board, the technique drawers and the last cycle's line do so too ([CYCLING.md](cycling/CYCLING.md)).
- **Wrap by word at a width the scene gives.** Set `autowrap_mode` to word smart (3) and a `custom_minimum_size.x`. The width is the room the neighbours leave: the Here tray's name 250 px (238 beside the BOSS seal) and its line 332, a choice drawer's title 250 (238 beside the LOCKED seal) and its detail 332, the walk hint and the lock line 408, the chest's title 312, the Goals board's text 358, the cast tray's name 150, the technique tooltip's name 268. A tag, seal or figure beside a title stays on its first line.
- **A width that changes is set twice.** Give the Label the new width as its minimum and as its size, then call `update_minimum_size()`. A Label whose width changes (a name beside a seal that comes and goes) otherwise leaves its last height cached for the boxes above it.
- **The board follows the lines.** Rows are containers (a `VBoxContainer` column, a `MarginContainer` row), so each box above asks again. Round a grown height up to an even number (`ceilf(h / 2) * 2`). Boards grow down, and what stands under them moves with them (the chest's page slot, the zone chest's header and list); the cast tray grows up from its bottom edge, because the dock stands under it. The icon, socket, plate, tag and seal stay at the top and the face stretches behind them.
- **Pad a wrapped row.** `assets/styleboxes/lacquer/wrap_pad.tres` (a `StyleBoxEmpty`, 1 px bottom content margin) is the Label's `normal` style. A 15/18 or 18/22 Label is 17 or 21 px for one line, so n wrapped lines come to 18 n − 1 or 22 n − 1; with the pad they are 18 n and 22 n and every row stays on an even y. A 17/20 name is 20 px already and needs none.
- **A `RichTextLabel`** wraps by itself (`fit_content`, `autowrap_mode` word): give it a width. It cannot ellipsize, which is why the zone cards' detail lines still drop words (see Where text still trims, below).
- **A title row shared by cards and technique drawers.** `ZoneActionButton.layout_title_row()` lays out both, so their title rows line up: a technique drawer's title wraps where its NEW seal or tag starts (with no tag it runs on to the detail line's 316 px); a card's still ellipsizes there (see the table below).
- **Test it.** `tests/integration/test_boards_never_trim_text.gd` walks every Label of the reworked boards and fails on an overrun behaviour or `clip_text`, on a scene file that sets either, and on a Label that could run long without wrapping. A new board's scene goes in its `BOARD_SCENES`; its own test file checks that it grows. The same file also reads every `.tscn` and `.gd` under `res://scenes` and fails for any file that sets a trimming overrun behaviour or `clip_text` and is not on its `KNOWN_TRIMMERS` list, so new text anywhere in the game wraps; it fails the other way too, for a listed file that no longer trims.

**Where text still trims.** Not every screen follows rule 14 yet. These end in `…` today; the branch that reworks one applies the rule, rewrites the test that pins its ellipsis and takes its files off `KNOWN_TRIMMERS`. That allowlist, in `tests/integration/test_boards_never_trim_text.gd`, pins this list: the files in the last column are the only ones under `res://scenes` that trim or clip text, and the test fails for a file that is missing from it as well as for one that has stopped trimming, so the list only shrinks.

| Surface | What trims | Test that pins it | Files on `KNOWN_TRIMMERS` |
|---|---|---|---|
| Log board | The five `LineLabel`s, one line each at 384 px, on a board texture per line count (`lacquer_log1_ai.png` to `_log5_ai.png`), so a wrapped line means a redesign of the board | `test_log_board.gd`, `test_long_line_ellipsizes` | `log_window.tscn` |
| Zone chest title | `ZoneNameLabel` | `test_zone_panel.gd`, `test_long_zone_name_ellipsizes` | `zone_panel.tscn` |
| Zone cards | The card title, where its NEW seal or tag starts; the detail lines at 316 px (`ZoneActionButton.fit_detail_rich_text()` drops whole words and ends in `…`) | `test_zone_action_cards.gd` | `zone_action_button.tscn` and `.gd`, and the adventure, cycling, default and merchant presenters (`presenters/*_presenter.tscn`) |
| Map plates and popovers | The plates' name and line (228 px slot, the icon and the rate stay whole); the popovers' titles and bodies | `test_map_markers.gd`, `test_zone_travel.gd` | `zone_map_label.tscn`, `zone_map_popover.tscn` |
| Abilities view | `DetailBadges`, `DetailTags` and `PrimaryValue` in `abilities_view.tscn` | None but the list | `abilities_view.tscn` |

**New sizes.** A screen that needs a size the theme lacks (an orb value, a combat number, an end-card title) adds a `LabelLacquer*` variant to `lacquer_theme.tres`, a row to UI_STYLING.md and a check to `tests/unit/test_lacquer_pieces.gd`. It does not add an inline size override.

## 6. Materials and components

Kit sizes below are display sizes. Project files with a baked shadow are 4 or 2 px larger (kit §9).

### Furniture and boards

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Anchor furniture | Lacquer board with chunky brass corner straps, hand-placed grain, a gloss dash, 4 px shadow | `lacquer_cult_ai.png` (440x252); `lacquer_chest_top_ai.png`, `_mid_ai.png` (tiled), `_bot_ai.png` (440 wide) | `CultivatorPlate` (`scenes/zones/cultivator_plate/`), `ZonePanel` (`scenes/zones/zone_panel/`); the adventure's `VitalsPlate` (the cabinet's board) and `AdventureChest` (the chest's slices) |
| Board in the map gap | A strapped board centred between the columns with a figure carved into it, 4 px shadow, laid out in absolute px | `lacquer_cyc_board_ai.png` (560x1032), `lacquer_cyc_body_carved_ai.png` (524x872) | `CyclingView` (`scenes/cycling/cycling_view/`) |
| Plain board | Same lacquer, no caps, chamfered corners, 4 px shadow. Each board's gloss dash sits in a different place | `lacquer_goals_ai.png` (cut into slices), `lacquer_log1_ai.png` to `lacquer_log5_ai.png`, `lacquer_lore_ai.png` (the zone chest's lore board in `ZonePanel`, a 9-slice that tiles its middle), `lacquer_dock_ai.png`, `lacquer_tdock_consumables_ai.png` (476x200: the technique dock with its consumable row) | `GoalsPanel`, `LogWindow`, `Dock`, `TechniqueDock` |
| Tooltip board | A plain 9-slice that hugs its content, 4 px shadow baked in (texture margins 8 left and top, 12 right and bottom) | `lacquer_board9_ai.png` | `board9.tres` on `TechniqueTooltip` and `BuffTooltip` |
| Recessed tray | A carved-in field in deep `#230F0F` with a lit lower lip. A clean 9-slice (4 px of ink on the top and left, a 2 px lit rim on the bottom and right, one flat fill, no baked shadow: `NinePatchRect` margins 4, 4, 2, 2), so a tray grows to hold its text | `lacquer_now_tray_ai.png` (408x88), with `lacquer_now_plate_ai.png` (brass `Now` legend) on its top edge; `lacquer_cast_tray_ai.png` (476x44) | `NowStrip` (`scenes/zones/zone_panel/now_strip/`, 392 wide so its edges are the cards', 88 tall at least); the Here tray of `ExpeditionPage` (the same tray with `Here` on its plate, 408 wide, 88 tall at least); `CastTray` (44 tall at least, grows upward) |

### Drawers, tags, seals, buttons

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Drawer (card) | 392x72 raised face with a carved 48x48 icon socket at (8, 12); icon 32x32 at x+16, y+20 | `lacquer_drawer_ai.png` | `ZoneActionButton` (`scenes/zones/zone_action_button/`), `TechniqueDrawer` (`scenes/cycling/technique_drawer/`) |
| Choice drawer | The same drawer, 408 wide to match the Here tray and 72 tall at least, growing with its text. The face is a 9-slice without the socket; the carved socket is a piece of its own, 8 px in and centred on the face, with the icon 8 px inside it. At 72 px it is the card's drawer pixel for pixel. Its tag and seal stand where the tray's do (x 320 and 308), its title at x 64 stops 6 px short of them, and its detail runs to x 396 | `lacquer_drawer9_ai.png` (22x22, margins 4, 4, 6, 6 with the 2 px shadow baked in), `lacquer_socket_drawer_ai.png` (48x48) | `ChoiceDrawer` (`scenes/adventure/adventure_chest/choice_drawer/`) |
| Running drawer | Pulled out to (−2, −2) with brass corner caps and the 4 px shadow; tag RUNNING (IN USE on a technique drawer) in cream | `lacquer_drawer_run_ai.png` | `ZoneActionButton` running state; `TechniqueDrawer` in use |
| Tall drawer | 392x96, socket at (8, 24), icon at y+32, for a detail that wraps to two lines | `lacquer_drawer_tall_ai.png` | `ZoneActionButton.set_tall()` |
| Mode tag | Carved recess, 76x22; brass plate for ENTER; 88x22 for UNKNOWN | `lacquer_tag_ai.png`, `lacquer_tag_enter_ai.png`, `lacquer_tag_wide_ai.png` | `LabelLacquerTag` |
| Seal | Cinnabar chop: NEW 44x22, LOCKED 88x22 (with `mini_lock`), count 24x24 at least: its worn bites stay in its outer 6 px, so its middle stretches and it widens to fit a long count | `lacquer_seal_new_s_ai.png`, `lacquer_seal_locked_ai.png`, `lacquer_seal_count_ai.png` | `LabelLacquerSeal`; the count seal is `LacquerCountSeal` |
| Dock button | 108x64: normal, hover (brass caps), notified (2 px brass ring) | `lacquer_btn_ai.png`, `lacquer_btn_hover_ai.png`, `lacquer_btn_ring_ai.png` | `SystemMenuButton` (`scenes/ui/dock/system_menu_button/`) |
| Small text button | 88x36 raised; pressed has no shadow and its text 2 px lower | `lacquer_about_ai.png`, `lacquer_about_open_ai.png`; `lacquer_showme_ai.png` (104x32) + `lacquer_chev_ai.png` | Zone chest header, `ZoneMapPopover` |
| Close | 28x28 carved ×, tan; cream on hover | `lacquer_close_ai.png`, `lacquer_close_hover_ai.png` | `ZoneMapPopover` |

### Progress

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Rod | 10 px groove; the full rod clipped to width 2 + 2k with an end cap at x = 2k once k ≥ 2. A rod has one length; to shorten one, take the width out of its flat middle (`rod_now` is `rod_well` less 16 px) | `lacquer_rod_{now,goal,adv,stamina,cast}_{empty,full,end}_ai.png`; `lacquer_rod_well_*` (308 px) has no scene since the Now strip narrowed to 392 | `LacquerRod` (steps: Now strip 144, milestone 138, adventure 74, Stamina and cast 119; the Aura Well's `rod_well` was 152) |
| Beads | 18 jade beads in a strip of 19 rows; r = floor(xp × 18 / need) | `lacquer_beads_xp_strip_ai.png` (222x228) | `LacquerStripRect` |
| Ring | 13-frame jade bead ring: 56x56 (Now tray), 64x64 on a lacquer disc (on the current zone's map plate) | `lacquer_ring_strip_ai.png`, `lacquer_map_ring_strip_ai.png` | `LacquerStripRect`, `MapActionRing` |
| Orbs | 80x80 brass-rimmed sockets. The fill is drawn by a pixel shader (see [§8](#8-motion)) | `lacquer_orb_madra_strip_ai.png` (frame 0), `lacquer_orb_core_strip_ai.png` (column 0 pebble, column 1 socket), `lacquer_orb_health_ai.png` (the Health orb's socket) | `CultivatorPlate` with `lacquer_madra_orb.gdshader`, `lacquer_core_orb.gdshader`; `VitalsPlate` (Health and Madra, the Madra shader with the crimson ramp set on the Health orb's material) |

### Lines, rails, frames, tokens

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Divider | Carved line with brass pins, 408x6 | `lacquer_line_ai.png` | `TextureRect` |
| Groove | A carved groove after a section label, with an end pin | `lacquer_groove_ai.png` (tiled) + `lacquer_groove_end_ai.png` | Activities and Techniques headers, group labels |
| Rail | 12 px carved track, brass thumb, end caps lit only when the list can scroll that way | `lacquer_rail_track_ai.png`, `lacquer_rail_thumb_ai.png`, `lacquer_rail_{up,down}_{on,off}_ai.png` | `LacquerRail` (`scenes/zones/zone_panel/lacquer_rail/`), `rail_thumb.tres` |
| Lips | Hard shelf shadow with a 2-step dither at a scrolled edge | `lacquer_lip_top_ai.png`, `lacquer_lip_bottom_ai.png` | Activity list |
| Hover frame | Thin 9-slice overlay, no fill | `lacquer_frame_hover_ai.png` (16x16, margin 4) | `frame_hover.tres` on a `LacquerFrameOverlay` |
| Brass frame | Heavier 9-slice overlay for flash, ready and pinned | `lacquer_frame_brass_ai.png` (24x24, margin 8) | `frame_brass.tres`, `LacquerFrameOverlay` (brass by default) |
| Token | Small lacquer 9-slice a floater rides on, 2 px shadow baked | `lacquer_token_ai.png` (26x26) | `token.tres`, `LacquerFloater` |
| Bullets | 10x10 inlaid diamonds per tone | `lacquer_bullet_{brass,cream,madra,tan,dim}_ai.png` | `LogWindow` |
| Carved path | A channel carved into a board and drawn per art pixel (2x2 px cells in ink, a rim lip below), lit cell by cell in the Madra ramp behind whatever travels it, and lit whole when nothing does, so the path stands out from the carving. No texture file | none | `CyclingGroove` (`scenes/cycling/cycling_groove/`) |
| Strip pieces for play | A ball with an 8-frame swirl in three breathing sizes (68x68 cells, the ball 60, 64 and 68 px), its four rings (88x88: the ready ring, the solid tracking ring and the ready ring grown twice), a zone socket in six states (48x48, its idle rim a solid loop), an Auto tablet raised and pressed in (120x36) | `lacquer_cyc_{ball_strip,ball_rings,zone_strip,auto,auto_on}_ai.png` | `CyclingTechnique`, `CyclingZone`, `CyclingView` (`LacquerStripRect`, `TextureButton`) |

### The adventure's pieces

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Technique slot | An 80x80 carved socket with a raised lip and the icon at 64x64 inside; a 22x22 key cap at (−6, −6); the cost under it with a mini icon | `lacquer_slot_ai.png` (82x82), `lacquer_keycap_ai.png` (24x24), `lacquer_mini_{health,stamina}_ai.png` | `TechniqueSlot` |
| Consumable socket | The kit's 48x48 glyph socket (the Here tray's), with the consumable's 64 px icon at 32 (§9) 8 px in, the key cap at (−6, −6), and a count seal off its bottom right corner (its right edge 4 px past the socket's) that widens leftward to fit the count. A row of four sits along the top of the technique dock, each over its technique (1 over Q to 4 over R) | `lacquer_socket_glyph_ai.png`, `lacquer_keycap_ai.png`, `lacquer_seal_count_ai.png` | `ConsumableSlot` (on `DockSlot`, as `TechniqueSlot` is), `LacquerCountSeal` |
| Cooldown sweep | The part of the icon still to recharge shows in the locked veil, uncovered clockwise from 12 o'clock in 24 whole steps, with the whole seconds in the centre (`LabelLacquerCooldown`; 15 px on a consumable's 32 px icon). A consumable with none left shows its icon all in the veil, at step 0 | `lacquer_cooldown_sweep.gdshader` (no texture) | `TechniqueSlot`, `ConsumableSlot` |
| Buff socket | A 40x40 carved socket with the buff's icon at 32x32, a count seal for stacks and a brass flash when it lands | `lacquer_socket_buff_ai.png`, `lacquer_seal_count_ai.png` | `VitalsPlate`, `LacquerCountSeal` |
| Glyph socket | A 48x48 carved socket for the Here tray's glyph, at the tray's (8, 20) with the glyph at (16, 28), the columns the choice drawers use (the text column starts at x 64 in both). It is the recessed piece (interior `#110707`); a drawer's socket is the card's (`lacquer_socket_drawer_ai.png`, interior `#230F0F`), the same size in another texture | `lacquer_socket_glyph_ai.png` | `ExpeditionPage` |
| Run clock | An 88x36 carved recess with a mini hourglass and `M:SS`; the vermilion seal at 30 s or less | `lacquer_timer_ai.png`, `lacquer_timer_low_ai.png`, `lacquer_mini_hourglass_ai.png` | `RunClock` |
| Encounter coin | A 52 px coin in a 54x54 frame: glyph (brass rim), carved `?`, carved cleared, boss (vermilion inner ring), with the glyph at 32x32 and spent glyphs for cleared tiles | `lacquer_marker_tokens_ai.png`, `adv_glyph_*_spent_light_ai.png` | `EncounterCoin` |

### Map pieces (zone map and adventure map)

| Component | Kit files | Godot piece |
|---|---|---|
| Hex rims: current (brass rim and lacquer collar), open (hairline), hover, inner hover and pinned rims for veiled hexes | `assets/ui/lacquer/map/lacquer_hex_{current,open,hover,hover_in,pinned_in}_ai.png` | `ZoneHexMarker`, `LockedZoneOverlay`; the adventure's `HoverRim` |
| The adventure's current rim, heavier than the zone's: four px of brass where the zone rim has two. Six rings counted from the inside: two of brass just inside the hex's edge (the tile's outer 2 px of plain ground), the zone rim's two brass rings, its ink and its lacquer collar. The ink and the collar lie where the zone rim's do, so the file stays the tile's 164x190 (six rings do not fit outside a hex: a tile leaves a 4 px margin). The cream highlight and the shaded brass follow the zone rim's light side and shadow side | `map/lacquer_hex_current_heavy_ai.png`, made by `gen/hex_rim.py` and halved into `map/` by the import | The adventure's `CurrentRim`. The zone map keeps `lacquer_hex_current_ai.png` |
| Veiled tiles (locked, uncharted) | `map/lacquer_tile_{locked,uncharted}{,_hover}_ai.png` | `LockedZoneOverlay` |
| The forest atlas in the uncharted veil (the adventure's revealed tiles) | `assets/sprites/tilemap/hex_tiles/forest/hex_forest_veil_atlas_ai.png` (the forest atlas's 23 tiles, rim baked in) | Tileset source 9, `AdventureTilemap` |
| Fog tiers | `map/lacquer_fog_t{1,2,3}_atlas_ai.png` | `FogTileMapLayer`, `ZoneMapMath.fog_tier()`; the adventure's `AdventureFogMap` |
| Route dots | `map/lacquer_route_dot_ai.png`, `_lit_ai.png` | `ZoneRoute`, `AdventureRoute` |
| Plates (248x52) and popovers (264 card + 8 notch) | `lacquer_plate_*_ai.png`, `lacquer_pop_*_ai.png` | `ZoneMapLabel`, `ZoneMapPopover` |
| Glyphs: padlock, `?`, 3-frame twinkle | `lacquer_glyph_lock_ai.png`, `lacquer_glyph_unknown_ai.png`, `lacquer_glyph_twinkle_strip_ai.png` | `MapGlyph` |
| Character shadow | `map/lacquer_char_shadow_ai.png` | Zone map and adventure map character |

## 7. Interaction states

Never glow, tint, fade or scale to show a state.

| State | How it shows | Godot piece | Zone view example |
|---|---|---|---|
| Hover | A thin frame overlay, a hover texture, or a rim swap; text may step one palette tone: tan → cream (the close ×, the uncharted plate's name), brass → cream (the current plate's name), tan → brass (an open plate's line, `Click to travel`) (kit §6.5) | `LacquerFrameOverlay` with `frame_hover.tres`; texture swap | Drawers, Now tray, About; dock faces; hex rims; plates |
| Pressed | The face drops its shadow and its content moves 2 px down | Texture swap | About while the lore is open |
| Selected or pinned | A steady brass frame, a heavier rim, brass caps | `LacquerFrameOverlay` (brass), shown steadily | Pinned plates and popovers, the pinned veiled hex |
| Running (the one current thing) | The drawer pulls out 2 px with brass caps and the 4 px shadow, tag RUNNING in cream | `lacquer_drawer_run_ai.png` | The running idle card; the technique in use (tag IN USE) |
| Ready (can act now) | A steady brass frame, the brass ENTER tag, a brass detail line. Never animate a steady frame | `ZoneActionButton.set_ready_frame()` | The adventure card at its threshold |
| Disabled, locked, unaffordable | Palette, never alpha: tan text, carved "off" art, the LOCKED seal, a desaturated veil | Texture swap, `LabelLacquerSeal` | Rail caps off, locked hex and popover, a locked choice drawer, an unaffordable technique cost in tan |
| New or unseen | The NEW seal inline after the title; cleared on first hover or use (a technique drawer's when the pointer leaves it, since the drawers can turn up under the cursor) | `lacquer_seal_new_s_ai.png` | New activity cards, new technique drawers |
| Notification | A 2 px brass ring on the button, plus a count seal when there is a number | `lacquer_btn_ring_ai.png`, `lacquer_seal_count_ai.png` | Path (points), Abilities (unequipped unlock) |
| Flash (look here, done) | The brass frame on for 300 ms and off for 300 ms, N times; ends hidden. A steady frame hides while a flash runs | `LacquerFrameOverlay.flash(times)` | Card twice, Now tray once, a buff socket when a buff lands, a technique slot when its cooldown ends |
| Cooling down | The part of the icon still to recharge in the locked veil, uncovered clockwise in 24 whole steps, with the whole seconds in the centre | `lacquer_cooldown_sweep.gdshader` | Technique slots and consumable sockets |
| Rejected | A shake in even-px keyframes, each held 0.088 s: the soft shake 0, −4, 4, −2, 2, 0 for a refused press, click or walk, which comes again and again, or the lock shake 0, −8, 8, −6, 4, 0 (the same rhythm at twice the travel) for the locked padlock, plus a log line (not for a refused technique or consumable press: the sweep, the cast tray, the tan cost and the count seal already say why). A line that explains the refusal may take the warning colour for the length of the shake, then go back outright | `MapGlyph.shake_offset_at()` pattern | Locked padlock (the lock shake); the soft shake for the rest: the adventure card's Madra row, a refused walk (the Stamina row, or the Here tray, whose lock line "Choose what to do here before you walk on" turns warm red while it shakes) and a refused technique or consumable press (the slot or socket) |
| Empty | One tan line in the space the content would take; the space stays | `LabelLacquerDetail` | `Nothing running`, `Nothing to do here yet.` |
| Ageing | Colour steps, never opacity: tone → tan → dim | `ThemeConstants.LACQUER_*` | Log lines by age |

## 8. Motion

| Pattern | Rule | Zone view reference |
|---|---|---|
| Frame strips | Switch frames from a strip; never interpolate. Timing in whole steps | Rings: 13 frames over each action cycle (1 s Well, 5 s haul). Twinkle: frames 1, 2, 1 for 0.1, 0.2, 0.1 s every 4 s. Cycling ball swirl: 8 frames, 10 a second. The waiting ball's breath: 60, 64, 68, 64, 60 px over 2 s, in whole steps |
| Stepped moves | Move in 2 px steps (1 map px at zoom 2) at constant speed. Compute the offset from elapsed time and quantise it | Floater: 40 px in 20 steps over 1 s, then hidden (`LacquerFloater.rise_at()`). Walk: `snap_walk_to_whole_px`. The character's idle motion: whole-map-px offsets and frame clips from `ZoneMapMath` (the Aura Well's teleport is a drawn dither dissolve, then hidden outright). A board's open and close: the dock, the chest's rows and height, and the HUD boards (`BoardTransitionTiming`) |
| Snapped paths | A curve is fine; the drawn position snaps to even px every frame | `LacquerPellet` (the drain into the adventure, the cycling and Tribulation pellets; its condense, tail and spark are strip frames, its tail a ramp step darker per dot, never alpha); the cycling ball on its eased path |
| Scrolling | In a few even steps | `LacquerRail.step_to()`: six even-px steps over 200 ms |
| Flash | `steps(1)` on and off | `LacquerFrameOverlay.flash()`: 300 ms on, 300 ms off |
| Shake | Even-px keyframes, each held. Every shake steps through `MapGlyph.shake_offset_at()` over one of its two keyframe sets and never copies the stepping; a refusal (a press, click or walk that cannot act) shakes by the soft set | `MapGlyph`: `SHAKE_KEYFRAMES`, the lock shake, 0, −8, 8, −6, 4, 0 over 0.44 s (the padlock; the adventure's boss coin reuses it as it comes into view), and `SOFT_SHAKE_KEYFRAMES`, 0, −4, 4, −2, 2, 0 over the same 0.44 s, half the travel in even px (the technique slots and consumable sockets, the Here tray, the Stamina row and the zone view's Adventure card). One shake still runs its own: the old fight HUD's cast bar, not yet in the look, shakes on a tween when a cast is interrupted |
| Show and hide | `visible`, never `modulate.a`. A crossfade, if ever needed, is a short 2-step dither dissolve (the mock's 200 ms; not built in the game) | Popovers, floaters, lore |
| Camera | The eased motions that are kept: the zone view's recentre after travel (0.3 s, `TRANS_CUBIC` / `EASE_IN_OUT`), the zoom from 2 to 3 into an adventure, the push in on the cultivator while a board in the map gap opens (to 1.5 times the player's zoom, 0.48 s, ease in and out, cubic; played backwards on the close), the wheel zoom of both maps (`CameraZoomController`, 1 to 2, 10% a tick, eased; the adventure opens at 1) and the adventure's boss-reveal push (45% of the way to the boss and back, 0.5 s and 0.7 s). The boss-reveal push is in screen px, laid on top of the zoom's own camera offset: it moves the view 74 px for a boss one hex away at every zoom, and a zoom that starts meanwhile neither cancels it nor is undone by it. Nothing else eases a camera | `ZoneTilemap.frame_zone()`, `ZoneTransition`, `CameraPush`, `CameraZoomController`, `AdventureTilemap._play_boss_reveal()` |
| Board open and close (an exception) | The board scales smoothly out of the cultivator (0.32 s, ease-out cubic) and back. A named exception to the whole steps on the 2× grid: partway through, the board's 2×2 art pixels are drawn at uneven sizes. The user saw it in slow motion and chose it over a crisp frame that grows at full resolution and uncovers the board in place | `BoardTransition`, `BoardTransitionTiming.board_scale()`; see [MAIN_VIEW.md](infrastructure/MAIN_VIEW.md#board-transitions) |

### Making something feel alive: the pixel-grid shader pattern

In the user's review the first orbs read as static, so the cabinet's orbs got two shaders that animate without breaking the look. Use the same pattern for anything that should breathe (a liquid, a swirl, a keystone, a cooldown):

1. **Draw over a kit frame.** The shader runs on a `TextureRect` showing a strip frame at its file size. Where the effect draws nothing (alpha 0), the frame's own art shows, so rims and sockets stay crisp.
2. **Quantise to the art grid.** Work out each colour per 2 px art cell: `floor(local_px / 2.0)` from `VERTEX`, never per screen pixel or per UV.
3. **Kit palette only.** Colours are constants from one kit ramp. No mixing, no alpha blending, no `smoothstep` edges.
4. **Stepped time.** `t = floor(TIME * steps_per_second) / steps_per_second`, 10 steps a second.
5. **One input.** The script sets one uniform (`progress`) and nothing else. Each `ShaderMaterial` is `resource_local_to_scene`. The orb shader's three colour uniforms (`light`, `pale`, `blue`, defaulting to the Madra ramp) are set in the scene, on a material, never by a script: the Health orb's material holds the crimson ramp.

```glsl
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float steps_per_second : hint_range(1.0, 30.0, 1.0) = 10.0;
const float CELL = 2.0;                                // one art px = 2 screen px
const vec4 LIGHT = vec4(0.909804, 0.964706, 0.992157, 1.0); // #E8F6FD, kit ramp only
varying vec2 local_px;
void vertex() { local_px = VERTEX; }
vec4 effect(vec2 cell, float t) { /* alpha 0 where the frame should show */ return vec4(0.0); }
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float t = floor(TIME * steps_per_second) / steps_per_second;
	vec4 fx = effect(floor(local_px / CELL), t);
	COLOR = fx.a > 0.0 ? fx : art;
}
```

`assets/shaders/lacquer_madra_orb.gdshader` and `lacquer_core_orb.gdshader` are the worked examples. Both assume the 80x80 orb frame (centre at cell 20, socket radius² 249); a different size needs those constants parameterised. `lacquer_cooldown_sweep.gdshader` is a third, for a stepped state: it veils the part of an icon still to recharge in the locked-veil colours, per 2 px cell, in 24 whole steps (its `progress` is k / 24). Its `icon_size` uniform is the icon rect's side (64 by default, 32 on a consumable socket), set on the material in the scene. See [ZONES.md, Orb shaders](zones/ZONES.md#orb-shaders).

## 9. Icons and art

| Rule | Detail |
|---|---|
| Icon sizes | 16 art px icons show at 32x32. `ic_*_ai.png` placeholders are 16x16 files shown at 2x. Mini icons inside text lines are 16x16 files (8 art px) shown at file size. |
| The user's 64 px icons | `gold_icon`, `star_icon`, `combat_icon` and `character_icon` show at 32x32 (kit §0). Measured on 2026-10-22, these and most 64 px item icons are drawn in 2x2 blocks throughout and mostly in 4x4 blocks (83–96% of blocks), so 32x32 drops some 2 px detail and 64x64 keeps all of it. `scripted_bark.png` and `dreadbeast_tooth_necklace.png` have no pixel grid. The icons are on the grid only at 32 or 64. Never show them at 24, 26, 28, 36, 40, 48, 52, 56, 60, 72, 75, 84 or 96, as screens outside the zone view do today. |
| 32 art px art | Shows at 64. If it must sit at 32, redraw it at 16 art px as an `_ai` file, as the kit did with `ability_icon.png` → `lacquer_ic_abilities_ai.png`. |
| Ability icons | The user's painted icons (cyan glow, off the grid) stay as they are, shown at 64x64 in a carved socket, as the technique dock does (decision G9, for the adventure). An on-grid redraw without glow is a separate art task. |
| User art first | Use the user's file from its own path. Never copy, edit or overwrite it. A change goes to a new `_ai` file next to it. |
| The `_ai` rule | Every agent-made image ends in `_ai` (`lacquer_slot_ai.png`), kept when moved. List new `_ai` files in the PR. |
| Shadows | Bake the hard shadow into the file (§3 rule 6). Icons inside sockets get none. Glyphs over the map carry their own (`lacquer_glyph_lock_ai.png`). |
| Map space | Map overlays are drawn at 2x for the screen, then stored halved in `assets/ui/lacquer/map/` because the zone camera's zoom 2 doubles them again. The adventure map shows them 1x when it opens and up to 2x when the wheel zooms in. `import_kit.py` checks every 2x2 block is uniform before halving. |
| Filtering | Nearest everywhere. The project default is nearest, but a `SubViewport` defaults to linear: set `canvas_item_default_texture_filter = 0` on every SubViewport (the zone one and the adventure map's do; the adventure's combat one is still to do, F4). Never set `texture_filter = 2`. |
| Non-pixel art | Painted, vector or downscaled high-res art does not belong: it is a second visual language. Replace it with grid art (`_ai`, or the user draws it); leave the user's file in place. |
| Placeholders | `res://64.png` and `res://icon.svg` (the Godot logo) are not icons. Use a kit icon (`ic_story_ai.png` and friends) until real art exists. |

## 10. Layout and copy

### The frame

| Rule | Value |
|---|---|
| Canvas | 1920x1080, stretch mode `viewport` |
| Margins | 24 px from every edge. The left column starts at x 24, the right at x 1456 (1920 − 24 − 440), the bottom line is y 1056 |
| Columns | Left and right columns are 440 wide. The open map runs from x 464 to 1456, centred on x 960 |
| Dock | 722, 976, 476x80, bottom centre (the adventure's technique dock: 722, 856, 476x200, its consumable row over the techniques; its cast tray stands 8 px over it and grows upward) |
| The adventure view | The same frame: the vitals cabinet at (24, 24), the chest at (1456, 24) and the technique dock at (722, 856), with Goals and the Log where the zone view puts them |
| Overlays on the zone view | Fit in the map gap, about x 488 to 1432 (24 px inside each column), so the cabinet and the chest stay readable |
| Insets | Content sits 16–18 px inside a board's edge (chest content at x 1472; the cabinet's orbs and the Goals and Log titles at x 42). The cabinet's text column after the orbs is at x 138 |
| HUD boards under an overlay | On the zone view the Goals and Log boards are furniture, like the cabinet and the chest. The menu books leave them showing under the backdrop with the rest of the view, by the user's decision (commit `5e8d7394`, "keep the Goals board and the log under an open book"). Cycling leaves them showing beside its board and blocks the full log, as a book does. Only the merchant hides them today (`MainView.hide_hud_boards()`); whether it keeps doing so is part of G1 |
| Grid | Every position and size even |
| Height | Boards hug their content: the chest is max(176, list top + list height + 24); the Log grows upward 26 px a line; Goals loses 70 px when no quest is active. They grow with wrapped text too (rule 14): the adventure chest is max(176, 82 + the lines the title adds + the page + 24), the Here tray and a choice drawer add a line's height (18, 20 or 22 px) per extra line, a Goals row and the Now strip likewise, the cast tray grows upward. Every grown height is even |

### Copy that held up

- Short ledger lines, not sentences: `+1.5 Madra / s`, `haul in 3 s`. The user's review of the first adventure card: too much text "for how little it tells the user".
- An activity card says what you get, in columns, never `text · text`: what the action gives on the left, at most one figure right-aligned under the tag (`+1.5 Madra / s` | `+1 Spirit / level`, `5 min run` | `carries 120 Madra`). Timings, ranges, levels and the gold you carry belong to the Now tray and the cabinet, not the card.
- Numbers carry units with spaces: `+1.5 Madra / s`, `46 / 60`, `17 / 18 XP`, `10 s`.
- A figure beats a sentence: a rod plus `46 / 60` replaced "Needs 60 Madra · you have 46".
- Mixed case for names and labels (`Core Density`, `Full log · L`, group labels in title case). Uppercase only in tags and seals.
- Empty states say what is true: `Nothing running`, `Aura Well · paused`, `Nothing to do here yet.`
- The chest says what a tile is and what a choice does, and no more. The Here tray's line for a fight is `Fight · Amorphous Spirit`, with no enemy Health; a fight's drawer carries its name and the FIGHT tag, with no list of techniques and no gold, unless the choice authors a tooltip (the user's review round 1; Health may come back as an unlockable). A drawer with no detail centres its name.
- Say what holds the player, up front: while an encounter on the tile waits for a choice, one line above the drawers reads `Choose what to do here before you walk on`.

### Copy question still open

The design review wanted the mode tags (IDLE, ACTIVE, SHOP, STORY) and the "·"-joined microcopy gone. The kit kept them on purpose because the approved spec has them (kit §0, "Kept on purpose"), and the user has not ruled on it since. Until they do, reworked screens should not add more mode tags or longer "·" chains than the zone view uses.

## 11. Implementation in Godot

**Theme.**
- Every lacquer root sets `theme = assets/themes/lacquer/lacquer_theme.tres`. Labels take `LabelLacquer*` variants; decimal lines take `RichTextLacquer`.
- The theme sets no `default_font` or `default_font_size`: a default would answer before `pixel_theme.tres`'s own variants. `test_theme_sets_no_defaults` guards this.
- Line pitch: each variant's `line_spacing` is the kit line height minus the font's height.
- Today the theme has only Label and RichTextLabel variants. A Button, PanelContainer, tooltip or scrollbar inside a lacquer root still falls back to `pixel_theme.tres` (backlog F3).

**Fixed pieces.** A `TextureRect` at the texture's size, placed at the kit's top-left; the baked shadow lands right and bottom. Never scale it.

**9-slices.** `StyleBoxTexture` with texture margins equal to the frame's thickness and nearest filtering. Overlay frames set no centre fill. When drawing a new 9-slice, keep grain and gloss out of the stretch zones, or they smear. The six in `assets/styleboxes/lacquer/`:

| Stylebox | Texture | Margins | Fill |
|---|---|---|---|
| `frame_brass.tres` | `lacquer_frame_brass_ai.png` 24x24 | 8 | none |
| `frame_hover.tres` | `lacquer_frame_hover_ai.png` 16x16 | 4 | none |
| `rail_thumb.tres` | `lacquer_rail_thumb_ai.png` 12x12 | top and bottom 4 | yes |
| `token.tres` | `lacquer_token_ai.png` 26x26 | left and top 6, right and bottom 8 | yes |
| `board9.tres` | `lacquer_board9_ai.png` 28x28 | left and top 8, right and bottom 12 (content margins 16 / 14 / 20 / 18) | yes |
| `trib_board9.tres` | `tribulation/lacquer_trib_board9_ai.png` 164x164 | left and top 56, right and bottom 60 (content margins 24 / 20 / 28 / 24) | yes |

`wrap_pad.tres` sits in the same folder but is no 9-slice: a `StyleBoxEmpty` with a 1 px bottom content margin, the `normal` style of a wrapped Label (§5, Long text). Trays and drawer faces that must grow use the texture directly on a `NinePatchRect` (trays: margins 4, 4, 2, 2; the drawer face: 4, 4, 6, 6; the zone chest's lore board: 8, 8, 10, 10, its middle tiled), not a stylebox.

**Baked shadows and stacked slices.**
- A piece with a shadow is 4 or 2 px larger than its kit size. Place it at the kit top-left.
- **The column-shadow trick.** A board that grows is a column of slices (top, tiled middle, bottom) in one wrapper. Each slice carries only its part of the column's shadow: the right-hand strip all the way down, and the bottom strip only on the last slice. So the middle tiles cleanly and only the bottom slice is taller (`import_kit.py`, `bake_column`; the zone chest).
- **Slicing an existing board.** A fixed board can be cut into slices with no new art: `GoalsPanel` cuts `lacquer_goals_ai.png` into cords, top, tiled middle and bottom, so the board can shrink and, since review round 1, grow with its wrapped text.
- **Growing a face that has something baked in.** Audit the texture first: a clean 9-slice has flat edges between its corners and one flat middle, with no grain, gloss or socket in the stretch zones. The trays are clean as drawn. The choice drawer's face was not (its carved socket is baked in at (8, 12)), so it was split into the face without the socket (`lacquer_drawer9_ai.png`) and the socket on its own (`lacquer_socket_drawer_ai.png`); stretched to 392x72 with the socket put back, the pair equals the zone kit's drawer pixel for pixel. `gen/kit_chest9.py` runs the audit and asserts that equality. The lore board's art (`lacquer_lore_ai.png`, 412x268) has gloss dashes in its middle, so it is not clean either, but its edges are flat (margins 8, 8, 10, 10) and a `NinePatchRect` can tile the middle instead of stretching it (`axis_stretch_horizontal` and `axis_stretch_vertical` set to tile): the dashes keep their size, a board narrower than the art is cropped on the right of its middle (no dash is there, which `test_adventure_kit_assets.gd` checks) and a taller one repeats the middle.

**Components.**

| Piece | Use |
|---|---|
| `LacquerStripRect` (`scenes/common/lacquer/lacquer_strip_rect.gd`) | Set `strip` and `frame_size`, then `set_frame(column, row)`. Orbs, beads, rings, any strip |
| `LacquerRod` (`scenes/common/lacquer/lacquer_rod.tscn`) | Set the three textures and `steps`, then `set_fraction(f)` |
| `LacquerFrameOverlay` (`scenes/common/lacquer/lacquer_frame_overlay.tscn`) | Full-rect frame over its parent, hidden, mouse ignored, brass by default. Override the panel style with `frame_hover.tres` for hover. `flash(times)` for a flash; show it for a steady frame |
| `LacquerCountSeal` (`scenes/common/lacquer/lacquer_count_seal.tscn`) | Place it at the seal's 24x24, set `grows_left` for the edge it keeps, then `show_count(n)`: the seal widens to fit the number |
| `LacquerRail` (`scenes/zones/zone_panel/lacquer_rail/lacquer_rail.tscn`) | `bind(host)` to a `ScrollContainer` whose scrollbar is hidden; `step_to(target)` scrolls in steps |
| `LacquerText` (`scripts/utils/lacquer_text.gd`) | `rate()`, `decimal_bbcode()` |
| `LacquerFloater` (`scenes/common/lacquer/lacquer_floater/`), `MapGlyph`, `LacquerPellet` | Stepped rise, even-px shake and twinkle, snapped flight. `LacquerFloater` and `MapGlyph` expose static functions of elapsed time (`rise_at`, `shake_offset_at`, `twinkle_frame`) that tests call directly (`shake_offset_at` steps the keyframe set it is handed, the lock shake's by default: a new shake adds a set, never a copy of the stepping); `LacquerPellet` snaps its point to even px every frame, and its `PelletFlight` and `frame_at` are functions of elapsed time too. Copy this shape for new stepped motion |

**Stepped motion in code.** Drive it from `_process` with an elapsed time, quantise the result (2 px, whole frames), and set `position` or the frame. Do not use a `Tween` with an ease. Show and hide with `visible`.

**Generators.** `docs/superpowers/mockups/zone-view-lacquer/gen/` holds the Python (PIL) scripts that drew the kit:

| Script | Holds |
|---|---|
| `lq_base.py` | Palette constants and primitives: `strap()` (brass corner straps), `streak()` (grain), `gloss()`, `nail()`, `socket()`, `drawer()`, `tray()`, `seal()`, `rod()`, `beads()`, the orbs, `carved_line()`, `icons()` |
| `kit_ui.py` | `board_base()` (plain chamfered board), `caps()`, `drawer_face()` (centres the socket at any height), `frame_brass()`, `frame_hover()`, `token()`, `recess()`, `tags()`, `buttons()`, `rail()`, `groove()`, `rods()`, the strips |
| `kit_map.py` | Hex rims, veils, plates, popovers, fog tiles |
| `kit_icons.py` | The 16 art px icons |
| `build_all.py` | Builds the whole kit; copies the user's files byte for byte |
| `import_kit.py` | Copies the kit into `assets/ui/lacquer/`: bakes shadows (`bake_shadow`, `bake_column`) and halves map art (`halve`) |
| `look.py` | Tiles kit files onto one image for review |

Their output paths point at the authoring session's scratch folder (`SCRATCH` and `OUT` in `lq_base.py`, `A` in `look.py`): change them to rebuild. The cycling pieces come from `docs/superpowers/mockups/cycling-view-lacquer/gen/`: `kit_cycling.py` draws them with these primitives, and `import_cycling.py` copies the used ones into `assets/ui/lacquer/cycling/` (the technique icons into `assets/ui/lacquer/icons/`) and bakes their shadows. The four pieces the game draws differently from the approved mock (the ball strip, the ball rings, the zone strip and the carved figure) are written to the mock folder's `game/` subfolder by `game_kit()`, and the import copies those from there. Draw new pieces for the cascade with these primitives, so new boards share the same rims, grain and palette, and name them `_ai`.

The adventure's pieces come from `docs/superpowers/mockups/adventure-view-lacquer/gen/` (`kit_adventure.py`, `map_render.py`, `veil_atlas.py`, `hex_rim.py`, `stage.py`): `python build_all.py` draws them and `python import_adventure_kit.py` copies them into `assets/`, baking the shadows with the zone kit's `bake_shadow()` and halving the map-space rim into `assets/ui/lacquer/map/`. `kit_chest9.py` stands alone (it imports only the zone kit's `bake_shadow`): `python kit_chest9.py` audits the trays, draws the drawer's 9-slice face and socket and the Now strip's shorter rod, bakes the shadow and copies them into `assets/ui/lacquer/`.

**Scenes, not code.** Every node goes in a `.tscn`. No `Node.new()`, `StyleBoxFlat.new()`, `ShaderMaterial.new()` or `add_theme_*_override()` for styling in scripts. Scripts may set text, textures, frames, visibility, a shader's `progress`, and a state colour from `ThemeConstants.LACQUER_*` (as `LogWindow` and `ZoneMapLabel` do).

**Tests and docs.** A new variant or stylebox gets a check in `tests/unit/test_lacquer_pieces.gd` and a row in UI_STYLING.md. A rework rewrites the tests that pin the old look (the backlog names them).

## 12. Review checklist

Check every reworked screen against this list, ideally on a capture at 1920x1080 and a 2x zoom of its edges.

**Do**
- [ ] Every texture shows at its file size (kit art) or exactly 2x (native art).
- [ ] Every position and size is even. Nothing sits at x.5.
- [ ] Every surface is opaque. A screenshot of the screen over a bright background shows nothing through it.
- [ ] Shadows are hard 4 px `#050707` or 2 px `#150909` offsets, baked.
- [ ] Brass appears only on anchor furniture, titles, rewards and the running, pinned or hovered thing.
- [ ] Jade only on progress fills; Madra blue only for Madra; vermilion only on seals and locked rims.
- [ ] States use texture swaps, frame overlays, pulled-out drawers or seals.
- [ ] Motion moves in 2 px steps or frame strips; things show and hide outright.
- [ ] The root sets `lacquer_theme.tres`; every Label uses a `LabelLacquer*` variant; numbers with a decimal use `RichTextLacquer`.
- [ ] Text is 13 px or larger and at least 4.56:1 on its background.
- [ ] Panels hug their content.
- [ ] No text is cut off: a Label that can run long wraps by word, its board grows with it, and every grown height is even.
- [ ] New art is `_ai`; the user's files are untouched; nearest filtering everywhere, SubViewports included.
- [ ] UI nodes are in the `.tscn`; scripts set data only.

**Don't**
- [ ] No `StyleBoxFlat` with alpha below 1, `corner_radius`, `border_blend`, `shadow_size` or an `anti_aliasing` edge.
- [ ] No `modulate` or `self_modulate` above 1 (overbright) or below 1 in alpha.
- [ ] No `Tween` with `TRANS_SINE`, `TRANS_CUBIC`, `TRANS_BACK`, `TRANS_ELASTIC` or `TRANS_QUAD` on UI art (camera moves aside).
- [ ] No scale tweens (1.06, 1.08, 1.1 …) for hover, press or pulse.
- [ ] No `GradientTexture2D`, `smoothstep` falloff, `exp()` glow or continuous `TIME` in a shader.
- [ ] No GPU particles, mists or vignettes.
- [ ] No text outlines (painted titles get the 2 px shadow instead).
- [ ] No ellipsis (`text_overrun_behavior`) and no `clip_text` on a Label of a reworked board, and no fixed-size texture behind text that can grow.
- [ ] No decimal point in BM Euljiro at 15–17 px.
- [ ] No placeholder icons (`res://64.png`, `res://icon.svg`).

## 13. Cascade backlog

Every surface the 2026-10-22 survey found outside the zone view, grouped by area. Surfaces that several surveys found (the backdrop, the floater) are one row each. F1–F3 are shared prerequisites drawn from the surveys' notes, not surfaces. IDs are for reference in branches and PRs. The adventure's map and frame (A1–A9, B1–B3) are built and their rows deleted; the combat and stage rows say what its fight rework (PR 2) still has to do. Sizes are rough: **S** a day or less, **M** a few days, **L** a week or more, or a lot of new art.

| Area | IDs | Rows | S | M | L |
|---|---|---|---|---|---|
| Foundations (shared) | F1–F7 | 7 | 1 | 5 | 1 |
| Zone view overlays | Z1–Z2 | 2 | 1 | 0 | 1 |
| Dialogue | D1 | 1 | 0 | 0 | 1 |
| Combat HUD | B4–B9 | 6 | 3 | 3 | 0 |
| Adventure stage | S1–S3 | 3 | 1 | 1 | 1 |
| End card | E1 | 1 | 0 | 0 | 1 |
| Menu books | K1–K13 | 13 | 6 | 6 | 1 |
| Project-wide | P1–P2 | 2 | 1 | 0 | 1 |

**Taking a row in another branch:**
1. Make sure the kit's files are there (the branch is cut after PR #51, and after PR #58 for the adventure's pieces).
2. Settle the row's open questions with the user before building.
3. Build to §3–§11 and check the result against §12 on a 1920x1080 capture.
4. Add any new variant or stylebox to UI_STYLING.md and `tests/unit/test_lacquer_pieces.gd`; rewrite the tests that pin the old look.
5. Update the area's living doc, and delete the row here (docs/README.md: delete fixed items rather than striking them through).

### Foundations (shared by several areas)

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| F1 | Palette additions | Health and Stamina have their ramps (crimson, bamboo) and `ThemeConstants.LACQUER_HEALTH` / `LACQUER_STAMINA`, built for the adventure's cabinet. Still without a kit slot: `LabelRed` `#E06060` / `LabelGreen` `#7DCE82` (merchant), `#7EA870` for Madra in item effect text, `#E86A5C` / `#7FD18B` in the old combat bars and numbers, BBCode red and blue in the timeline | The user picks ramps for damage taken and gains or heals, and the merchant's colours. Add them to kit §2, this guide and `ThemeConstants.LACQUER_*`. Madra stays the Madra ramp | S | `scripts/utils/theme_constants.gd`, `scenes/combat/combatant/combatant_visual/combatant_visual.gd`, `scenes/ui/combat/resource_bar/resource_bar.gd` |
| F2 | Shared kit pieces (new art) | The kit has fixed-size boards and five 9-slices (`frame_brass`, `frame_hover`, `rail_thumb`, `token`, `board9`). Almost every other screen needs pieces that grow | New `_ai` art from the generators: a plain board 9-slice (`board_base()`) and a strapped one (`strap()`), a small popover or tooltip 9-slice, a text-button set (normal, hover, pressed, disabled), a dither backdrop tile, a carved slot socket, a 22x22 key cap, rods for health, stamina, cast and intent, a cooldown strip, "off" arrow caps. Grain out of stretch zones; shadows baked. Done so far (the adventure's PR 1 and its review round 1): the tooltip board (`board9.tres`), the carved slot socket, the key cap, the Stamina and cast rods, the trays as 9-slices, and the drawer's 9-slice face with its own socket; and, for the Tribulation board, a strapped board 9-slice that grows (`trib_board9.tres`, drawn for that board, not yet a shared piece) | L | `docs/superpowers/mockups/zone-view-lacquer/gen/`, `assets/ui/lacquer/`, `assets/styleboxes/lacquer/` |
| F3 | Lacquer base types | `lacquer_theme.tres` has only Label and RichText variants, so a Button, PanelContainer, tooltip or scrollbar in a lacquer root falls back to `pixel_theme.tres`: rounded `border_blend` buttons, tan parchment panels, the grey 8x8 pack at 1x | Add Button, PanelContainer, TooltipPanel and TooltipLabel, V/HScrollBar (rail textures, as the full log does), HSeparator (`lacquer_line_ai.png`) and ProgressBar (rod textures) to `lacquer_theme.tres`. Opt-in: only roots that set the theme get them. Keep "no defaults" | M | `assets/themes/lacquer/lacquer_theme.tres`, `tests/unit/test_lacquer_pieces.gd`, `docs/UI_STYLING.md` |
| F4 | Render settings | The adventure's map `SubViewport` sets `canvas_item_default_texture_filter = 0` now. Still linear: the adventure's `CombatSubviewport` (PR 2 draws the fighters at 2x and sets it). Three nodes force `texture_filter = 2` (merchant TopLight and SlotGlow, the combatant Shadow). Window stretch scales fractionally | Set the filter to 0 on the combat SubViewport. Remove the forced linear filters with their screens. Decide integer `scale_mode` (open question). Re-check the merchant after the change | M | `scenes/adventure/adventure_view/adventure_view.tscn`, `project.godot`, `scenes/merchant/merchant_atmosphere/merchant_atmosphere.tscn`, `scenes/merchant/merchant_stock_row/merchant_stock_row.tscn`, `scenes/combat/combatant/combatant_visual/combatant_visual.tscn` |
| F5 | Modal backdrop (`GreyBackground`) | A translucent teal-grey panel (`#2D3737` at 55.7%), shared by the four books, the merchant and the end card. The books and the merchant fade it in over 0.3 s and out over 0.2 s (`show_with_panel` / `hide_with_panel`); the end card toggles `visible` with no fade. The merchant hides the HUD boards (`hide_hud_boards`); the books (the user's decision, `5e8d7394`) and the end card leave them dimmed under it. Cycling uses no backdrop: its board sits in the map gap with the HUD boards up. Its alpha is left at 0 after a fade-out (MAIN_VIEW.md bug). The Dialogic background (`#2D2D2D` at 82.7%) and the dev modal (black at 60%) are translucent too | An opaque 2-step `#050707` dither tile (new `lacquer_dither_backdrop_ai.png`) shown and hidden outright for every user. For the merchant and the end card only, the alternative is no backdrop with `MainView.hide_hud_boards()` (G1). The books keep the HUD boards under their backdrop. Keep `show_with_panel` / `hide_with_panel` / `panel_hidden` / `clicked`, so no state changes. Rewrite the fade-timing tests | M | `scenes/ui/grey_background/grey_background.gd`, `assets/styleboxes/zones/grey_background.tres`, `scenes/main/main_game/main_game.tscn`, `tests/unit/test_grey_background.gd` |
| F6 | Shared floater (`FloatingText`) | Half done. The map's floater was promoted to `LacquerFloater` (`scenes/common/lacquer/lacquer_floater/`: a token with a 16 px `RichTextLacquer`, 40 px in 20 steps, hidden outright), and the map and each cycling zone use it. `FloatingText` (24 px text, a 5 px black outline, engine colours, a 100 px cubic-eased rise and an alpha fade; its `font_size` override is a no-op) has no live user: `ResourceBar` can use it, but the one bar left (the enemy's Health) has it off | Point the fight's bars at `LacquerFloater` with palette colours when the fight is reworked (PR 2); delete `FloatingText` | M | `scenes/ui/floating_text/`, `scenes/ui/combat/resource_bar/resource_bar.gd` |
| F7 | Item hover tooltip (`ItemDisplaySlot`) | A parchment card stretched non-uniformly to 424x264 slides up 15 px with a cubic ease and fades in; black and grey text; tan and green effect lines at 2.5–2.8:1 on cream. Shows over the merchant and the end card | Over lacquer screens, a lacquer popover board (F2): `LabelLacquerPopoverTitle` name, `LabelLacquerDetail` type, `LabelLacquerPopoverBody` text, effects in `RichTextLacquer` via `decimal_bbcode()`. Even px; shown outright | M | `scenes/common/item_display_slot/`, `scenes/common/item_description_panel/` |

### Zone view overlays

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| Z1 | Merchant shop | Dark teal `StyleBoxFlat`s: panel 95%, rows 58%, buttons 55–85%, 1–2 px teal borders at 22–95%, 8 px corners, a 16 px teal glow shadow. `MerchantAtmosphere`: gradient light, mists at x3–3.5, cyan and green GPU motes. Radial slot glows. Title in Euljiro 50 with a teal outline glow. Open and close fades. Gold icon at 24 and 40 px. `LabelGreen` / `LabelRed`. `10.0s` in Euljiro. The 1000 px panel overlaps both columns by 4 px | A strapped lacquer board in the map gap (F2). Title `LabelLacquerZoneName` or `PanelTitle`, greeting `LabelLacquerLore`, `lacquer_line_ai.png` divider. Rows as wide drawers (carved socket, `LabelLacquerName`, effects in `RichTextLacquer`, `gold_icon` at 32 + `LabelLacquerGold`). Sold out as a carved tag, a blocked reason as a tan `LabelLacquerDetail` line (marked, if it needs one, by a vermilion seal with cream text, 5.1:1 per kit §3; never vermilion text on lacquer), a purchase as a `frame_brass` flash and a log line. Buy as a lacquer text button, Leave as `lacquer_close_ai.png` with an Esc hotkey. Footer like the cabinet's gold row. Delete the atmosphere, glows, linear filters and fades. Rewrite the tests that pin the old look | L | `scenes/merchant/`, `assets/themes/merchant/spirit_valley_merchant_theme.tres`, `assets/styleboxes/merchant/`, `tests/unit/test_spirit_valley_merchant_theme.gd`, `tests/integration/test_merchant_shop_flow.gd` |
| Z2 | Quest toast | Near-black blue panel at 94%, 1 px gold border at 40%, 4 px rounded corners; 22 px text with the 1 px shadow; fades in while sliding 20 px on a cubic ease, fades out | A small lacquer board (F2) with a carved tag (`QUEST`, or the brass ENTER-style plate for completion) and a `LabelLacquerName` line. Shown outright, or dropped in 2 px steps. Optional `frame_brass` flash on the Goals board. Keep the queue | S | `scenes/ui/quest_toast/`, `assets/styleboxes/ui/quest_toast.tres` |

### Dialogue

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| D1 | Dialogic textbox, name, portrait, background, choices | A `#2D2D2D` backdrop at 82.7%. Dialogic's default VN textbox (rounded 5 px boxes self-modulated to black at 90%) on top of the dock. White 18 px text. The speaker name in `#1800AB` on black, close to unreadable. Red and blue BBCode in the timeline. A vector `next.svg` with a sine bounce. FADE_UP box and "Fade In Up" portraits. The portrait fit-to-height × 0.75, so its pixels are uneven, over the Goals and Log boards | `addons/` is off limits. Build a custom textbox layer scene in `assets/dialogue/styles/` from Dialogic's own nodes with lacquer pieces around them (board 9-slice, cream 16 px text, a brass name plate, a 16 art px brass chevron, no box animation), or override the VN layer's exports in `default_style.tres`. Joins and leaves `Instant In Or Out` (ships with Dialogic). Backdrop per F5. Choices as drawers. Timeline colours from the palette. The box clear of the dock; the portrait framed at an integer scale | L | `assets/dialogue/styles/default_style.tres`, `assets/dialogue/styles/dialogue_backgrounds/dialogic_background.tscn`, `assets/dialogue/characters/`, `assets/dialogue/timelines/`, `project.godot` |

### Combat HUD

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| B4 | Enemy intent bar | The player's cast bar is done (the technique dock's cast tray). What is left is the enemy's intent tab: navy panels (82–94%) with rounded corners and faint borders; rounded fills; fades in and out; overbright pulses (1.8) and a 2.2 release flash; `1.9s` in Euljiro; black outlines | The adventure spec's opponent page: a Casting tray in the chest (a recessed tray with the `Casting` plate, the cast's name, the time via `decimal_bbcode()`, a jade `lacquer_rod_intent_*`), shown outright; a tan "Gathering its madra" line between casts; an interrupt as "Interrupted" with the even-px shake (PR 2) | M | `scenes/ui/combat/cast_bar/`, `assets/styleboxes/combat/cast_bar_fill_enemy.tres`, `assets/styleboxes/combat/panel_intent.tres` |
| B5 | Enemy nameplate and health bar | A 360 px navy plate at 82% with a 22% gold border, 4 px corners and a soft shadow; rounded red fill; translucent ghost and track; outlines on every label | Decided in the adventure spec: no plate. The opponent page in the chest takes over (a Health row on a `LacquerRod`, the Casting tray (B4), a Buffs row, a Techniques list and the reward row; PR 2), and the plate, `panel_nameplate.tres` and `bar_fill_health.tres` go with it | M | `scenes/ui/combat/enemy_nameplate/`, `assets/styleboxes/combat/panel_nameplate.tres`, `assets/styleboxes/combat/bar_fill_health.tres` |
| B6 | Enemy buff bar and buff icons | The player's buffs are done (the vitals cabinet's carved sockets, with a count seal and a brass flash when a buff lands). What is left is the enemy plate's `BuffBar` and `BuffIcon`: the 64 px ability icon squeezed to 32x32; a translucent duration overlay; `5.0s` in Euljiro; a pale frame and black outlines | The opponent page's Buffs row, shown only while the enemy has a buff: sockets like the cabinet's, with the same `BuffTooltip` (PR 2) | S | `scenes/ui/combat/buff_bar/`, `scenes/ui/combat/buff_icon/` |
| B7 | Enemy buff tooltip | The technique tooltip and the player's buff tooltip are done (both on `board9.tres`). What is left is the enemy plate's `CombatBuffTooltip`: a 600 px brown `StyleBoxFlat` with 8 px corners and an 8 px soft shadow | The opponent page's `BuffTooltip` (the cabinet's scene), so `CombatBuffTooltip` can go (PR 2) | S | `scenes/ui/combat/combat_buff_tooltip/` |
| B8 | Ability stat pills and `StatTooltip` | Unused by the game now: the old ability tooltip was their only user (removed with the adventure frame), and the Abilities book has its own stat list. Still in the project: translucent rounded pills (60% fill, 50% border); a gold border pulsing forever on DMG; a colour per stat (red, green, blue, purple, teal, pink); a tooltip built in code with a soft shadow; cubic count-up; overbright hover | Delete the three scenes, or restyle them if the Abilities book (K10) takes them: carved tags (`lacquer_tag_ai.png`, `lacquer_tag_wide_ai.png`) with `LabelLacquerTag`; values `LabelLacquerDetail`; attribute icons instead of colours; the tooltip as a lacquer board in a `.tscn`; values set outright; no pulse | M | `scenes/abilities/ability_stats_display/`, `scenes/abilities/stat_label/`, `scenes/abilities/stat_tooltip/stat_tooltip.gd`, `assets/styleboxes/abilities/stat_pill.tres` |
| B9 | Damage numbers | 34 px Euljiro with an 8 px near-black outline; off-palette red and green; a scale pop from 0.4 with a back ease; a cubic rise with random drift; a fade out | The shared floater (F6) on a lacquer token (decided, A-Q9); rising in 2 px steps, hidden outright, no scale pop; damage dealt cream, damage taken and heals Health crimson, Madra changes Madra blue, Stamina bamboo (F1) | S | `scenes/combat/combatant/combatant_visual/damage_number.tscn`, `scenes/combat/combatant/combatant_visual/combatant_visual.gd` |

### Adventure stage

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| S1 | Parallax forest backdrop (combat) | The map is done: its opaque ground `#090E0E` and the fog lattice cover the backdrop. What is left is combat: 12 layers at 3.5x (the sky at 15x) drifting at fractional speeds; a teal-green cast; the painting the zone view dropped; layers built in code | A static stage at exactly 2x in kit ramps (the adventure spec: `AdventureData.combat_stage`, a moonlit bamboo grove for the Shallow Woods; PR 2). `ZoneViewBackground` has no other user | M | `scenes/zones/zone_view_background/`, `scenes/adventure/adventure_view/adventure_view.tscn`, `assets/sprites/zones/backgrounds/spirit_valley/` |
| S2 | `Atmosphere` layer (combat) | The map dropped it. Combat still builds its own instance in code: a `smoothstep` vignette; mists at 4–5x tinted pale blue at 56% on sine tweens; cyan and green GPU motes fading on an alpha curve | Decided (A-Q2): none. Remove it from `AdventureCombat._setup_atmosphere()`, as the zone view did, with `vignette.gdshader` (PR 2) | S | `scenes/atmosphere/`, `assets/shaders/vignette.gdshader`, `scenes/combat/adventure_combat/adventure_combat.gd` |
| S3 | Combat stage and combatants | Third-party painted placeholder sprites scaled to 280 px tall by arbitrary factors; radial-gradient blob shadows, linear filtered; cubic, quad and elastic tweens, a sine bob, alpha fades, eased hit flashes, a 1.06 buff pulse; the combat view fades in | New combatant art at a fixed size shown at exactly 2x (the user's or `_ai`), with a hard ink shadow sprite. Slide in 2 px steps at constant speed; bob as held steps; attack and recoil as even-px keyframes; flashes as one or two whole frames; buffs as a frame flash on the nameplate; the view shown outright | L | `scenes/combat/adventure_combat/`, `scenes/combat/combatant/combatant_visual/`, `assets/shaders/hit_flash.gdshader`, `resources/combat/combatant_data/` |

### End card

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| E1 | Adventure end card scroll | A third-party cartoon vector parchment (radial paper gradient, thick black outlines) at 0.85 and 0.9 scale; scale and alpha open and close; a translucent loot tray (40%); `LabelEndCardMuted` 12 px at 80%; 64 px icons at 40 and 75; off-palette colours (`#228b22`, `#4a7ab5`, `#b8860b`, `#8b2020`). Backdrop per F5 | Decide the metaphor (open question). Lacquer: a big strapped board that hugs the loot row (new slices), a Yatra title (a new variant above 30 px), DEFEAT on a vermilion seal, stat rows like the cabinet's with the user's icons at 32, loot in carved sockets, a lacquer text button; shown outright or a stepped unroll strip. Scroll: a pixel-art scroll redrawn at 2x in kit colours (`_ai`), same contents | L | `scenes/adventure/adventure_end_card/`, `assets/scroll/parts/`, `assets/styleboxes/common/panel_loot_tray.tres`, `scenes/ui/main_view/states/adventure_end_card_state.gd` |

### Menu books

The survey's recommendation: keep the paper books, bind them in lacquer, and make only the dark parts that float over the HUD lacquer furniture. The book shell and its open, close and page-turn strips (`assets/sprites/inventory/book_opening_spritesheet.png`, `page_turning_spritesheet.png`) are the user's own art. The page chrome `book_theme.tres` uses and the book's extra pieces (`book_card_2x_ai`, `book_row_2x_ai`, `book_pill_2x_ai`, `book_plaque_2x_ai`, `book_slot_2x_ai`, `book_bookmark_ai`, `book_close_tab_ai` in `assets/sprites/ui/book/`) are agent-made. The books were designed the day before (2026-10-21) and already follow the hard rules (nearest filtering, opaque, hard edges, stepped open, close and page turn). This is open question K-Q1.

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| K1 | Book shell and covers | The book art is drawn in 2x2 blocks and shown at 2x, so one art px is 4 screen px. Covers recoloured jade (Abilities: jade is reserved) and indigo (Character: off-palette). The bookmark slides on a quad ease | Keep the book. Set all four `BookStyleData` covers to the lacquer ramp (`#692F2F`, `#462020`, `#2C1414`) through `palette_swap.gdshader`, no new art. Identity only in the bookmark and border line, from §4. Bookmark in 2 px steps or shown outright. Optional brass corner caps and the kit's carved close × | S | `scenes/ui/book_frame/`, `resources/ui/book_styles/`, `assets/shaders/palette_swap.gdshader` |
| K2 | Page chrome (`book_theme`) | Rounded key chips (radius 3); selection and the path inset shown by `modulate` tints; card, row, pill and plaque art at 4 px per art px (measured 2026-10-22: 100%, 100%, 100% and 99.9% uniform 4x4 blocks) beside 2 px slot art; odd content margins (plaque 11 / 7, key chip 1 / 2); `LabelBookPositive` green `#3E7A3A` off-palette | Selection as a frame overlay; key chips as carved key caps (`lacquer_keycap_ai.png`, built for the technique dock); even margins; benefit text in a palette colour; optional Yatra plaque titles; optional 2 px redraws of card, row, pill and plaque. These are all `_ai` files, so the redraws touch no user art | M | `assets/themes/book_theme.tres`, `assets/sprites/ui/book/` |
| K3 | Side tabs | Interpolated margin and icon-scale tracks (0.95 → 0.75) on stepped sprite frames; 64 px icons in a 26-unit rect (1.625 px per art px); locked at 55% alpha; half-unit offsets (55.5 units = 111 px) | Discrete tracks with whole units and no scale track; icons at on-grid sizes (16 art px redraws where needed); locked as the padlock and an opaque dim from `palette_swap` | S | `scenes/inventory/inventory_view/tab_switcher/`, `scenes/inventory/inventory_view/inventory_view.tscn`, `scenes/path_progression/path_tree_view.tscn` |
| K4 | Inventory chrome (ribbon, sort pill, toolbar, scroll rail) | The ribbon art bakes a translucent 16% black shadow; disabled arrows and dots at 35% alpha; `ScrollRail` stretches its art 4.5x and about 2.6x with an unsnapped grabber; pager dots built in code | An `_ai` ribbon copy with an opaque 2 art px hard shadow (the user's file untouched); "off" art or hidden arrows; `LacquerRail` or an on-grid book rail; dots in the scene | M | `scenes/inventory/common/tab_banner/`, `scenes/inventory/common/sort_sub_banner/`, `scenes/inventory/common/scroll_rail/` |
| K5 | Equipment tab | 64 px item icons at 40 px; the hover selector at scale 2.2; half-unit offsets; filtered items at 30% alpha; gear silhouettes at 36% alpha; `scripted_bark.png` is painterly (no grid) | Icons at 64 (larger `_ai` slot art) or 32 (open question G4); selector at scale 2 or a frame overlay; whole-unit offsets; the filter as an opaque `palette_swap` dim; opaque `_ai` silhouettes; an on-grid `_ai` redraw of `scripted_bark` | M | `scenes/inventory/inventory_view/equipment_tab/`, `scenes/inventory/item_instance/item_instance.tscn` |
| K6 | Item description panel (inventory right page) | A 218x108 card stretched non-uniformly to 470x288 (not a 9-slice); pure black and grey `#606060` text with a 1 px shadow; tan and green effect lines at 2.8:1 and 2.5:1 on cream; the icon at 52 | The `PanelBookCard` 9-slice; `book_theme` labels; effect lines in book ink or book gold; the icon at 64 or 32 | S | `scenes/common/item_description_panel/`, `scenes/inventory/inventory_view/item_description_box.gd` |
| K7 | Consumables tab and hotbar | Hotbar slots with a gold glow (shadow at 45%), rounded corners and a pale 2 px border; a 50% drag ghost; an overbright drop tint in `DropTargetSlot`; a dark-panel title on cream paper | Hotbar slots as lacquer sockets (F2): a steady `frame_brass` when equipped, `frame_hover` on drag-over, the slot number in `LabelLacquerTag`. The rest stays paper (`LabelBookTitle`, `LabelBookMuted`). `DropTargetSlot` is shared with the loadout and combat | S | `scenes/inventory/inventory_view/consumables_tab/`, `assets/styleboxes/inventory/hotbar_slot_equipped.tres`, `scenes/common/drop_target_slot.gd` |
| K8 | Materials tab (**broken**) | Its text renders at 2x and runs over the spiral and the dock; tan parchment cards with tinted text; the Godot logo as icons; slot art stretched 2.14x; the tip promises favourites that "pulse softly" | Fix it first, on the book material: a screen-resolution page layer with `book_theme`, or counter-scaling; `ic_dewdrop_ai.png` and `ic_fern_ai.png` at 32; Worth with `gold_icon`; drop or rewrite the tip | M | `scenes/inventory/inventory_view/materials_tab/`, `scenes/inventory/common/item_detail_card/`, `assets/styleboxes/common/panel_tan.tres` |
| K9 | Journal tab (**broken**) | Its text renders at 2x and clips; a translucent card (40% fill, 60% border, radius 4) shows the zone chest through it; overbright selection; a 7x5 dot stretched about 5.7x; the Godot logo; a flat red wax seal | Rebuild on the book material: `PanelBookCard`, `book_theme` labels, `PanelBookRow` rows with a frame overlay, a vermilion chop, `ic_story_ai.png` until real art exists | M | `scenes/inventory/inventory_view/quest_items_tab/`, `assets/styleboxes/common/panel_loot_tray.tres` |
| K10 | Abilities book | A jade cover; ability icons with cyan glow auras (two with no pixel grid); icons at 36, 48, 60 and 72 px; overbright drag tint; tinted selected row; rounded key chips; a latent `pixel_theme` scrollbar | Keep the book: on-grid icon sizes; frame overlays for hover, selection and drop; carved key caps; cover per K1; `LacquerRail` or a book rail; optional `_ai` icon redraws without glow (open question G9) | M | `scenes/abilities/abilities_view.tscn`, `scenes/abilities/ability_row/`, `scenes/abilities/equip_slot/`, `assets/sprites/abilities/` |
| K11 | Character book | Closest to the rules. A warm tint for selection; an indigo cover; `res://icon.svg` as the editor default texture | Selection as a frame overlay; cover per K1 | S | `scenes/character/character_view.tscn`, `scenes/character/attribute_tile/` |
| K12 | Path tree inset | Vector nodes with antialiased lines in pale Madra blues; a shimmering, glowing border shader; a keystone swirl with an `exp()` halo; a breathing glow ring; `Line2D` energy pulses; hover scale 1.15 on a sine ease; 12 fading particles; 22 px captions that shrink to 8.8 px at zoom 0.4; zoom 0.4–1.5; a tinted inset; much of it built in code | A recessed lacquer tray inside the paper card. Pixel node sprites on the grid (`_ai`: circle, diamond, hex × locked, available, purchased, plus a hover rim). Links as 2 px stepped lines or route dots in jade or Madra blue (open question). The keystone swirl rebuilt with the orb-shader pattern. A purchase as a frame flash. Whole-step zoom, or fit and pan. Captions on a token at a fixed screen size | L | `scenes/path_progression/`, `assets/shaders/path_node_border.gdshader`, `assets/shaders/path_node_keystone.gdshader`, `assets/shaders/path_connection_energy.gdshader` |
| K13 | Path right page and points badge | `star_icon` at 40 and 22 px (off grid); green benefit text | The star at 32; the points badge as the kit's count seal (as on the dock); benefit lines in book ink with `lacquer_bullet_brass_ai.png` bullets | S | `scenes/path_progression/path_details_card.tscn`, `scenes/path_progression/path_tree_view.tscn` |

### Project-wide

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| P1 | Project theme (`pixel_theme.tres`) | Every unthemed control falls back to it: a 1 px ink drop shadow on every Label; rounded `border_blend` buttons (disabled looks enabled); tan parchment panels; tooltips, scrollbars, progress bars and inputs from the grey 8x8 pack at 1x; grey tooltip text `#DDDDDD`; `LabelGreen` / `LabelRed`; sizes 12–96 px; Godot 3 keys and empty font files | After every area has opted in (F3), decide whether the project theme's base types become lacquer (open question G5). A transparent base Label shadow; palette colours; drop the Godot 3 keys. `book_theme` stays for paper pages. Last, with a visual check per area | L | `assets/themes/pixel_theme.tres`, `project.godot` |
| P2 | Boot splash and window icon | No `boot_splash` keys, so the game opens on Godot's default splash; `config/icon` is Godot's default `icon.svg` | `boot_splash/bg_color` `#090E0E` or `#2C1414`; a new `lacquer_splash_ai.png` (the title in Yatra brass on a strapped board, 2x) with `use_filter` off; an `_ai` pixel window icon. Any future title, pause or settings screen built from the kit from the start | S | `project.godot`, `icon.svg` |

### No work needed, or exempt

| Surface | Why |
|---|---|
| Pellets (`LacquerPellet`) | Already lacquer: opaque, snapped to even px, every look a strip frame |
| The cycling view: board, groove, ball, zones, pellets, floaters, technique drawers | Already lacquer (built 2026-10-22 and 23) |
| Log and Goals boards in the adventure view | Already lacquer. `LogWindow.tone_for()` maps each line's first `[color]` tag to a lacquer tone (brass, Madra, cream, or tan for anything else), so adventure and combat log lines need no change |
| Book open, close and page-turn strips | Already stepped frame strips |
| `palette_swap.gdshader`, the attribute icons | Reusable as they are |
| Dev panel | Players never see them. Exempt (confirm, G11); they change for free if P1 lands |

### Suggested order

| Step | Rows | Why this order |
|---|---|---|
| 0. Decide | G1, G2, G4, K-Q1 | They block the most rows: the backdrop (every overlay), the rest of the palette (damage, gains, the merchant), icon sizes (inventory, merchant, end card, hotbars) and the books |
| 1. Foundations | F1–F7 | Shared art and theme types every later area needs. The render fix is cheap and global. The backdrop and the floater have three or more users each |
| 2. Zone view overlays | Z1, Z2 | They sit on top of the finished zone view, so the clash is most visible there. The merchant is the first real user of the new board, button and tooltip pieces |
| 3. Dialogue | D1 | Shown over the zone view and from encounters. One timeline today, so the risk is small, but it needs a custom Dialogic layer |
| 4. Combat HUD | B4–B9 | The player's side is done (the adventure's PR 1). What is left is the enemy's plate, tooltip and numbers, which the adventure spec replaces with the opponent page (PR 2) |
| 5. Adventure stage | S1–S3 | Needs new art and the combatant art (A-Q8). The ambient decision (A-Q2) is made: none |
| 7. End card | E1 | Needs its metaphor decision and the item tooltip (F7) |
| 8. Menu books | K1–K13 | Last or partly never, per K-Q1. **K8 and K9 are broken in the running game: fix them at any time on the book material, whatever the look decision** |
| 9. Project-wide | P1, P2 | Switching the project theme last, once every area has opted in, keeps the blast radius small |

### Open questions

The user decides these. "Lean" is the survey's suggestion, not a decision.

**Global**

| # | Question | Options | Lean | Blocks |
|---|---|---|---|---|
| G1 | What dims the game behind a modal? | An opaque 2-step dither; translucency allowed for backdrops only; for the merchant and the end card only, no backdrop with the HUD boards hidden (cycling already runs with no backdrop and the HUD boards up). Not for the books: the user decided they leave the Goals board and the log showing under the backdrop (`5e8d7394`), and that option would reverse it | Opaque dither | F5, Z1, D1, E1, books |
| G2 | Which palette colours mean health, stamina, damage taken, heals and gains? Is there a warning or danger text colour? | Decided for the adventure: Health crimson (`#FFD9D2 #E8737A #B8304A #5A1626 #3A0E18`, text `#E8737A`, 5.9:1 on lacquer) and Stamina bamboo (`#EEF5C8 #C9DB86 #8FAE3E #3E5418 #1E2A0C`, text `#C9DB86`, 11.5:1); a fight's floaters take the colour of the resource that changed, signed (PR 2). Still open: damage taken, heals and gains outside the adventure, the merchant's reds and greens, and a warning text colour. Vermilion cannot be text: `#A83C30` is 2.76:1 on lacquer and 2.25:1 on the raised face, under the 4.56:1 floor, so until one exists warnings go on a vermilion seal or plate. The one text warning built, the Here tray's lock line while it shakes, borrows the Health text colour `#E8737A` (5.9:1) at the user's review round 1; whether that is the warning text colour is still open | — | F1, B4–B9, F6, Z1 |
| G4 | Item icon size? | The user's 64 px icons at 64 (bigger slots); at 32 like the cabinet's gold icon (some 2 px detail lost); `_ai` redraws at 16 art px | — | K5, K6, K7, Z1, E1, F7 |
| G5 | Project theme: one cascade or opt in? | Make base types lacquer project-wide; each area opts in by setting `lacquer_theme` on its root. Are the cream book pages a sanctioned second material? | Opt in, decide P1 last | F3, P1 |
| G6 | Integer window scaling? | `scale_mode` integer (letterboxes 2560x1440 and 1366x768); fractional | — | F4 |
| G8 | Mode tags and "·"-joined lines? | Keep (spec); drop (design review) | Kept for now | Every reworked screen |
| G9 | The painted ability icons with cyan glow? | Decided for the adventure: the user's icons stay as they are, in carved sockets (the technique dock); an on-grid redraw without glow is a separate art task. Still open for the Abilities book: the same, or `_ai` redraws on the grid | — | K10 |
| G10 | Title, pause or settings screens planned? Replace Godot's splash now? | — | — | P2 |
| G11 | Is the dev panel exempt? | Yes; restyle | Exempt | — |

**Zone view overlays and dialogue**

| # | Question | Options | Blocks |
|---|---|---|---|
| Z-Q1 | The user approved an "Ethereal shop" with one theme per zone on 2026-10-19. Keep per-zone shops as lacquer variants (a different wood or brass per zone), or one lacquer shop? | Per-zone variants; one shop | Z1 |
| Z-Q2 | The shop over a backdrop, or in the map gap with the cabinet and chest left visible? | Backdrop; map gap | Z1 |
| Z-Q3 | Keep the quest toast, or a Goals-board flash plus a log line? Quests write nothing to the log today | Toast; flash and log line | Z2 |
| D-Q1 | How does the portrait sit on the grid? It is 513x679 1x pixel art (1358 px tall at 2x) | Show at 1x; crop to a framed bust; a smaller 2x `_ai` bust. Hide the HUD boards during dialogue? | D1 |

**Combat, adventure and end card**

| # | Question | Options | Blocks |
|---|---|---|---|
| A-Q1 | The painted forest behind the adventure? | Decided (adventure spec): the map ground for the map (built), a new static lacquer stage for combat (PR 2) | S1 |
| A-Q2 | Ambient motion in the adventure? | Decided (adventure spec): none. The `Atmosphere` left the map and leaves combat in PR 2 | S2 |
| A-Q8 | Combatant art? | Decided (adventure spec): `_ai` placeholders drawn in Aseprite at exactly 2x, about 210 px tall on screen (about 104 art px), bosses larger; the user's own art can replace them | S3 |
| A-Q9 | Damage numbers? | Decided (adventure spec): on the lacquer token, like the map floaters (the shared floater, F6) | B9, F6 |
| A-Q12 | End card metaphor? | A pixel-art scroll redrawn at 2x; a lacquer board | E1 |
| A-Q13 | Item tooltip? | Lacquer everywhere; lacquer over the merchant, paper on a scroll end card | F7, E1 |

**Menu books**

| # | Question | Options | Blocks |
|---|---|---|---|
| K-Q1 | Books or cabinets? | Paper books bound in lacquer (survey lean); lacquer cabinets. If books: which palette colours mark each book now that jade and indigo are out, and is the book's 4 px art pixel acceptable next to the HUD's 2 px? | K1–K13 |
| K-Q2 | Yatra One for plaque and ribbon titles? | Yes; keep Euljiro | K2, K4 |
| K-Q3 | Keep the Materials tip card? Drop the "pulse softly" favourites promise? | Keep and rewrite; drop | K8 |
| K-Q4 | Path tree navigation and links? | Whole-step zoom or fit and pan; purchased links jade or Madra blue | K12 |

## 14. References

| What | Where |
|---|---|
| Art kit (textures, placements, review changes) | [superpowers/specs/2026-10-21-zone-view-lacquer-kit.md](superpowers/specs/2026-10-21-zone-view-lacquer-kit.md) |
| Zone view spec (art direction, decisions, review notes) | [superpowers/specs/2026-10-21-zone-view-map-first-design.md](superpowers/specs/2026-10-21-zone-view-map-first-design.md) |
| Menu books spec | [superpowers/specs/2026-10-21-menu-books-design.md](superpowers/specs/2026-10-21-menu-books-design.md) |
| Merchant v1 spec ("Ethereal shop") | [superpowers/specs/2026-10-19-merchant-v1-design.md](superpowers/specs/2026-10-19-merchant-v1-design.md) |
| Reference renders (open in a browser) | [zone view](superpowers/mockups/zone-view-map-first-mockup.html), [cycling view](superpowers/mockups/cycling-view-lacquer-mockup.html), [adventure view](superpowers/mockups/adventure-view-lacquer-mockup.html) |
| Adventure view spec (decisions, layout, tests) | [superpowers/specs/2026-10-22-adventure-view-lacquer-design.md](superpowers/specs/2026-10-22-adventure-view-lacquer-design.md) |
| Generators | `docs/superpowers/mockups/zone-view-lacquer/gen/`, `docs/superpowers/mockups/cycling-view-lacquer/gen/`, `docs/superpowers/mockups/adventure-view-lacquer/gen/` |
| Theme variants, lacquer styleboxes and pieces | [UI_STYLING.md](UI_STYLING.md) |
| The built zone view (map, chest, cards, orb shaders) | [zones/ZONES.md](zones/ZONES.md) |
| The built adventure view (map, coins, cabinet, chest, dock) | [adventuring/ADVENTURING.md](adventuring/ADVENTURING.md), [combat/COMBAT.md](combat/COMBAT.md) |
| UI shell, HUD boards, `GreyBackground`, dock | [infrastructure/MAIN_VIEW.md](infrastructure/MAIN_VIEW.md) |
| The built cycling view (board, groove, pellets, technique drawers) | [cycling/CYCLING.md](cycling/CYCLING.md) |
| Cycling view spec (layout, hit tiers, the choices behind them) | [superpowers/specs/2026-10-22-cycling-view-lacquer-design.md](superpowers/specs/2026-10-22-cycling-view-lacquer-design.md) |
| Built pieces | `assets/themes/lacquer/lacquer_theme.tres`, `assets/ui/lacquer/`, `assets/styleboxes/lacquer/`, `scenes/common/lacquer/`, `scenes/zones/zone_panel/lacquer_rail/`, `scripts/utils/lacquer_text.gd`, `scripts/utils/theme_constants.gd`, `assets/shaders/lacquer_madra_orb.gdshader`, `assets/shaders/lacquer_core_orb.gdshader`, `assets/shaders/lacquer_cooldown_sweep.gdshader`, `scenes/adventure/` (`VitalsPlate`, `AdventureChest`, `ExpeditionPage`, `RunClock`, `AdventureMapMarkers`, `AdventureRoute`), `scenes/ui/combat/technique_dock/` |
| Piece tests | `tests/unit/test_lacquer_pieces.gd`; `tests/integration/test_boards_never_trim_text.gd` (rule 14 on the reworked boards); `tests/unit/test_adventure_kit_assets.gd`, `tests/unit/test_hex_rim_assets.gd` (the adventure's textures) |
| Rules for agent-made art and scene-tree UI | [../CLAUDE.md](../CLAUDE.md) (AI-Generated Art, GDScript Coding Standards) |
