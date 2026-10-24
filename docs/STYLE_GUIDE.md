# Style Guide: Lacquer and Brass
Last updated: 2026-10-23

The game's visual style, taken from the zone view rework, and the list of screens still to move to it. Read it before you rework a screen or build a new one.

## 1. What this is

- **Status.** Distilled from the zone view rework on `feat/zone-view-redesign-4656b7` (built 2026-10-22, not merged). The zone view, the two HUD boards it shares with the adventure view (Log and Goals) and the cycling view (built 2026-10-22 and 23 on `feat/cycling-view-styleguide-ea3170`) use the look today. Everything in [§13](#13-cascade-backlog) is still to do. This doc changes no code.
- **Use it as a reference in other branches.** Each later branch takes one area of the backlog, applies these rules, and deletes its rows here.
- **The kit's files come with that branch.** The textures (`assets/ui/lacquer/`), the theme (`assets/themes/lacquer/lacquer_theme.tres`), the styleboxes (`assets/styleboxes/lacquer/`), the components (`scenes/common/lacquer/`, `LacquerRail`, `LacquerText`), the two orb shaders and the generators all arrive with `feat/zone-view-redesign-4656b7`. A branch cut from `main` before it merges does not have them.
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
| Vignette, mists, motes | Nothing: the opaque boards frame the view | Zone view (all dropped) |

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
| `#A83C30` `#7E2A22` | vermilion | Seals (NEW, LOCKED, count), locked rims |
| `#341E0E` `#E3B95A` `#C4884A` | coin gold | Coin and star icons |
| `#090E0E` | map ground | Screen background, grout between hexes |
| `#0C1312` `#111A19` `#16211F` `#1D2B28` | fog tier 1 | Tier-1 fog pixels |
| `#182423` `#0F1716` `#111A19` `#131D1C` | fog tier 2 | Tier-2 fog (etched lines) |
| `#0D1514` | fog tier 3 | Flat silhouettes |
| `#151A18` `#39423E` `#4B5550` `#5F6A65` `#76827C` | locked veil | Locked tile (hover: one step up) |
| `#0B1211` `#16211F` `#1C2927` `#243431` `#2D3F3B` | uncharted veil | Uncharted tile (hover: one step up) |
| `#FFD1AB` `#E7A581` `#CF7957` `#17111A` | skin | Sampled from the user's `ability_icon.png` |
| `#FFFFFF` `#BFDDD1` `#95ADB4` `#86718C` `#2E1C2C` | armour | Sampled from the user's `character_icon.png` |
| `#050707` | shadow | 4 px hard shadows |

**Contrast.** Text on lacquer stays at 4.56:1 or more (dim is the floor). Kit §3 lists the contrast of every text role.

**From code.** `scripts/utils/theme_constants.gd` exposes ten lacquer colours for code that sets a colour at runtime (log tones, plate hover, floater colour, the cycling groove):

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

Sizes and fonts always come from theme variants, never from code. When a reworked screen needs another palette colour from code, add a `LACQUER_*` constant with the kit's name.

**Hit tiers.** A cycling hit is PERFECT in brass, GOOD in cream and OK in tan (the user's call on 2026-10-22; green is dropped), for the floater, the stud on the zone and the XP pellets alike. `CyclingRules.tier_color()` maps the tiers to `LACQUER_BRASS`, `LACQUER_CREAM` and `LACQUER_TAN`.

**Gaps.** The palette has no colour for health, stamina, damage taken, heals or gains. Combat and the merchant need them. The user must add them before those screens are reworked ([open questions](#open-questions)).

## 5. Type

Two fonts, both in `assets/fonts/`:
- **Yatra One** (`YatraOne-Regular.ttf`) for painted titles only, with a hard 2 px `#150909` shadow.
- **BM Euljiro** (`BMEULJIROTTF.ttf`) for everything else, with no shadow and no outline.

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
- The count seal's number is 15 px (15/18), centred across the seal's 24 px at top +3 (kit §3 and §5.4; the dock's `CountLabel`).

**Long text.**
- No text is cut off. A label that runs out of room wraps, and the board, drawer or tray around it grows to fit. The cycling board, the technique drawers and the last cycle's line do so (CYCLING.md). The older pieces in the bullets below still ellipsize and are due the same change.
- A Label that can overflow sets `text_overrun_behavior` to ellipsis at a fixed width: log lines at 384 px, card details at 316 px, plate lines at 228 px.
- A card's title ellipsizes where its NEW seal or tag starts; a technique drawer's wraps there instead, and with no tag its row runs on to the detail line's 316 px. `ZoneActionButton.layout_title_row()` lays the row out for both, so their title rows line up.
- Icons and figures stay whole: a plate line drops its name text, never its icon or rate.
- A `RichTextLabel` cannot ellipsize. Use `ZoneActionButton.fit_detail_rich_text()`: drop whole words until the line fits, end it in `…` with no separator left before it, then apply `decimal_bbcode()`.

**New sizes.** A screen that needs a size the theme lacks (an orb value, a combat number, an end-card title) adds a `LabelLacquer*` variant to `lacquer_theme.tres`, a row to UI_STYLING.md and a check to `tests/unit/test_lacquer_pieces.gd`. It does not add an inline size override.

## 6. Materials and components

Kit sizes below are display sizes. Project files with a baked shadow are 4 or 2 px larger (kit §9).

### Furniture and boards

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Anchor furniture | Lacquer board with chunky brass corner straps, hand-placed grain, a gloss dash, 4 px shadow | `lacquer_cult_ai.png` (440x252); `lacquer_chest_top_ai.png`, `_mid_ai.png` (tiled), `_bot_ai.png` (440 wide) | `CultivatorPlate` (`scenes/zones/cultivator_plate/`), `ZonePanel` (`scenes/zones/zone_panel/`) |
| Board in the map gap | A strapped board centred between the columns with a figure carved into it, 4 px shadow, laid out in absolute px | `lacquer_cyc_board_ai.png` (560x1032), `lacquer_cyc_body_carved_ai.png` (524x872) | `CyclingView` (`scenes/cycling/cycling_view/`) |
| Plain board | Same lacquer, no caps, chamfered corners, 4 px shadow. Each board's gloss dash sits in a different place | `lacquer_goals_ai.png` (cut into slices), `lacquer_log1_ai.png` to `lacquer_log5_ai.png`, `lacquer_lore_ai.png`, `lacquer_dock_ai.png` | `GoalsPanel`, `LogWindow`, `Dock` |
| Recessed tray | A carved-in field in deep `#230F0F` with a lit lower lip | `lacquer_now_tray_ai.png` (408x88), with `lacquer_now_plate_ai.png` (brass `Now` legend) on its top edge | `NowStrip` (`scenes/zones/zone_panel/now_strip/`) |

### Drawers, tags, seals, buttons

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Drawer (card) | 392x72 raised face with a carved 48x48 icon socket at (8, 12); icon 32x32 at x+16, y+20 | `lacquer_drawer_ai.png` | `ZoneActionButton` (`scenes/zones/zone_action_button/`), `TechniqueDrawer` (`scenes/cycling/technique_drawer/`) |
| Running drawer | Pulled out to (−2, −2) with brass corner caps and the 4 px shadow; tag RUNNING (IN USE on a technique drawer) in cream | `lacquer_drawer_run_ai.png` | `ZoneActionButton` running state; `TechniqueDrawer` in use |
| Tall drawer | 392x96, socket at (8, 24), icon at y+32, for a detail that wraps to two lines | `lacquer_drawer_tall_ai.png` | `ZoneActionButton.set_tall()` |
| Mode tag | Carved recess, 76x22; brass plate for ENTER; 88x22 for UNKNOWN | `lacquer_tag_ai.png`, `lacquer_tag_enter_ai.png`, `lacquer_tag_wide_ai.png` | `LabelLacquerTag` |
| Seal | Cinnabar chop: NEW 44x22, LOCKED 88x22 (with `mini_lock`), count 24x24 | `lacquer_seal_new_s_ai.png`, `lacquer_seal_locked_ai.png`, `lacquer_seal_count_ai.png` | `LabelLacquerSeal` |
| Dock button | 108x64: normal, hover (brass caps), notified (2 px brass ring) | `lacquer_btn_ai.png`, `lacquer_btn_hover_ai.png`, `lacquer_btn_ring_ai.png` | `SystemMenuButton` (`scenes/ui/dock/system_menu_button/`) |
| Small text button | 88x36 raised; pressed has no shadow and its text 2 px lower | `lacquer_about_ai.png`, `lacquer_about_open_ai.png`; `lacquer_showme_ai.png` (104x32) + `lacquer_chev_ai.png` | Zone chest header, `ZoneMapPopover` |
| Close | 28x28 carved ×, tan; cream on hover | `lacquer_close_ai.png`, `lacquer_close_hover_ai.png` | `ZoneMapPopover` |

### Progress

| Component | Look | Kit files | Godot piece |
|---|---|---|---|
| Rod | 10 px groove; the full rod clipped to width 2 + 2k with an end cap at x = 2k once k ≥ 2 | `lacquer_rod_{well,goal,adv}_{empty,full,end}_ai.png` | `LacquerRod` (steps: Aura Well 152, milestone 138, adventure 74) |
| Beads | 18 jade beads in a strip of 19 rows; r = floor(xp × 18 / need) | `lacquer_beads_xp_strip_ai.png` (222x228) | `LacquerStripRect` |
| Ring | 13-frame jade bead ring: 56x56 (Now tray), 64x64 on a lacquer disc (map) | `lacquer_ring_strip_ai.png`, `lacquer_map_ring_strip_ai.png` | `LacquerStripRect`, `MapActionRing` |
| Orbs | 80x80 brass-rimmed sockets. The fill is drawn by a pixel shader (see [§8](#8-motion)) | `lacquer_orb_madra_strip_ai.png` (frame 0), `lacquer_orb_core_strip_ai.png` (column 0 pebble, column 1 socket) | `CultivatorPlate` with `lacquer_madra_orb.gdshader`, `lacquer_core_orb.gdshader` |

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

### Map pieces (zone map; reusable for the adventure map)

| Component | Kit files | Godot piece |
|---|---|---|
| Hex rims: current (brass rim and lacquer collar), open (hairline), hover, inner hover and pinned rims for veiled hexes | `assets/ui/lacquer/map/lacquer_hex_{current,open,hover,hover_in,pinned_in}_ai.png` | `ZoneHexMarker`, `LockedZoneOverlay` |
| Veiled tiles (locked, uncharted) | `map/lacquer_tile_{locked,uncharted}{,_hover}_ai.png` | `LockedZoneOverlay` |
| Fog tiers | `map/lacquer_fog_t{1,2,3}_atlas_ai.png` | `FogTileMapLayer`, `ZoneMapMath.fog_tier()` |
| Route dots | `map/lacquer_route_dot_ai.png`, `_lit_ai.png` | `ZoneRoute` |
| Plates (248x52) and popovers (264 card + 8 notch) | `lacquer_plate_*_ai.png`, `lacquer_pop_*_ai.png` | `ZoneMapLabel`, `ZoneMapPopover` |
| Glyphs: padlock, `?`, 3-frame twinkle | `lacquer_glyph_lock_ai.png`, `lacquer_glyph_unknown_ai.png`, `lacquer_glyph_twinkle_strip_ai.png` | `MapGlyph` |
| Character shadow | `map/lacquer_char_shadow_ai.png` | Zone map character |

## 7. Interaction states

Never glow, tint, fade or scale to show a state.

| State | How it shows | Godot piece | Zone view example |
|---|---|---|---|
| Hover | A thin frame overlay, a hover texture, or a rim swap; text may step one palette tone: tan → cream (the close ×, the uncharted plate's name), brass → cream (the current plate's name), tan → brass (an open plate's line, `Click to travel`) (kit §6.5) | `LacquerFrameOverlay` with `frame_hover.tres`; texture swap | Drawers, Now tray, About; dock faces; hex rims; plates |
| Pressed | The face drops its shadow and its content moves 2 px down | Texture swap | About while the lore is open |
| Selected or pinned | A steady brass frame, a heavier rim, brass caps | `LacquerFrameOverlay` (brass), shown steadily | Pinned plates and popovers, the pinned veiled hex |
| Running (the one current thing) | The drawer pulls out 2 px with brass caps and the 4 px shadow, tag RUNNING in cream | `lacquer_drawer_run_ai.png` | The running idle card; the technique in use (tag IN USE) |
| Ready (can act now) | A steady brass frame, the brass ENTER tag, a brass detail line. Never animate a steady frame | `ZoneActionButton.set_ready_frame()` | The adventure card at its threshold |
| Disabled, locked, unaffordable | Palette, never alpha: tan text, carved "off" art, the LOCKED seal, a desaturated veil | Texture swap, `LabelLacquerSeal` | Rail caps off, locked hex and popover |
| New or unseen | The NEW seal inline after the title; cleared on first hover or use (a technique drawer's when the pointer leaves it, since the drawers can turn up under the cursor) | `lacquer_seal_new_s_ai.png` | New activity cards, new technique drawers |
| Notification | A 2 px brass ring on the button, plus a count seal when there is a number | `lacquer_btn_ring_ai.png`, `lacquer_seal_count_ai.png` | Path (points), Abilities (unequipped unlock) |
| Flash (look here, done) | The brass frame on for 300 ms and off for 300 ms, N times; ends hidden. A steady frame hides while a flash runs | `LacquerFrameOverlay.flash(times)` | Card twice, Now tray once |
| Rejected | A shake in even-px keyframes 0, −8, 8, −6, 4, 0, each held 0.088 s, plus a log line | `MapGlyph.shake_offset_at()` pattern | Locked padlock; the adventure card's Madra row |
| Empty | One tan line in the space the content would take; the space stays | `LabelLacquerDetail` | `Nothing running`, `Nothing to do here yet.` |
| Ageing | Colour steps, never opacity: tone → tan → dim | `ThemeConstants.LACQUER_*` | Log lines by age |

## 8. Motion

| Pattern | Rule | Zone view reference |
|---|---|---|
| Frame strips | Switch frames from a strip; never interpolate. Timing in whole steps | Rings: 13 frames over each action cycle (1 s Well, 5 s haul). Twinkle: frames 1, 2, 1 for 0.1, 0.2, 0.1 s every 4 s. Cycling ball swirl: 8 frames, 10 a second. The waiting ball's breath: 60, 64, 68, 64, 60 px over 2 s, in whole steps |
| Stepped moves | Move in 2 px steps (1 map px at zoom 2) at constant speed. Compute the offset from elapsed time and quantise it | Floater: 40 px in 20 steps over 1 s, then hidden (`LacquerFloater.rise_at()`). Walk: `snap_walk_to_whole_px`. Well bob: 0, −1, −2, −1 map px every 0.6 s |
| Snapped paths | A curve is fine; the drawn position snaps to even px every frame | `MadraPellet` drain into the adventure; the cycling ball on its eased path and its pellets |
| Scrolling | In a few even steps | `LacquerRail.step_to()`: six even-px steps over 200 ms |
| Flash | `steps(1)` on and off | `LacquerFrameOverlay.flash()`: 300 ms on, 300 ms off |
| Shake | Even-px keyframes, each held | `MapGlyph`: 0, −8, 8, −6, 4, 0 over 0.44 s |
| Show and hide | `visible`, never `modulate.a`. A crossfade, if ever needed, is a short 2-step dither dissolve (the mock's 200 ms; not built in the game) | Popovers, floaters, lore |
| Camera | The one eased motion the zone view keeps: the recentre after travel (0.3 s, `TRANS_CUBIC` / `EASE_IN_OUT`) and the zoom from 2 to 3 into an adventure. Whether other screens keep eased camera moves is an [open question](#open-questions) | `ZoneTilemap.frame_zone()`, `ZoneTransition` |

### Making something feel alive: the pixel-grid shader pattern

In the user's review the first orbs read as static, so the cabinet's orbs got two shaders that animate without breaking the look. Use the same pattern for anything that should breathe (a liquid, a swirl, a keystone, a cooldown):

1. **Draw over a kit frame.** The shader runs on a `TextureRect` showing a strip frame at its file size. Where the effect draws nothing (alpha 0), the frame's own art shows, so rims and sockets stay crisp.
2. **Quantise to the art grid.** Work out each colour per 2 px art cell: `floor(local_px / 2.0)` from `VERTEX`, never per screen pixel or per UV.
3. **Kit palette only.** Colours are constants from one kit ramp. No mixing, no alpha blending, no `smoothstep` edges.
4. **Stepped time.** `t = floor(TIME * steps_per_second) / steps_per_second`, 10 steps a second.
5. **One input.** The script sets one uniform (`progress`) and nothing else. Each `ShaderMaterial` is `resource_local_to_scene`.

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

`assets/shaders/lacquer_madra_orb.gdshader` and `lacquer_core_orb.gdshader` are the worked examples. Both assume the 80x80 orb frame (centre at cell 20, socket radius² 249); a different size needs those constants parameterised. See [ZONES.md, Orb shaders](zones/ZONES.md#orb-shaders).

## 9. Icons and art

| Rule | Detail |
|---|---|
| Icon sizes | 16 art px icons show at 32x32. `ic_*_ai.png` placeholders are 16x16 files shown at 2x. Mini icons inside text lines are 16x16 files (8 art px) shown at file size. |
| The user's 64 px icons | `gold_icon`, `star_icon`, `combat_icon` and `character_icon` show at 32x32 (kit §0). Measured on 2026-10-22, these and most 64 px item icons are drawn in 2x2 blocks throughout and mostly in 4x4 blocks (83–96% of blocks), so 32x32 drops some 2 px detail and 64x64 keeps all of it. `scripted_bark.png` and `dreadbeast_tooth_necklace.png` have no pixel grid. The icons are on the grid only at 32 or 64. Never show them at 24, 26, 28, 36, 40, 48, 52, 56, 60, 72, 75, 84 or 96, as screens outside the zone view do today. |
| 32 art px art | Shows at 64. If it must sit at 32, redraw it at 16 art px as an `_ai` file, as the kit did with `ability_icon.png` → `lacquer_ic_abilities_ai.png`. |
| User art first | Use the user's file from its own path. Never copy, edit or overwrite it. A change goes to a new `_ai` file next to it. |
| The `_ai` rule | Every agent-made image ends in `_ai` (`lacquer_slot_ai.png`), kept when moved. List new `_ai` files in the PR. |
| Shadows | Bake the hard shadow into the file (§3 rule 6). Icons inside sockets get none. Glyphs over the map carry their own (`lacquer_glyph_lock_ai.png`). |
| Map space | Map overlays are drawn at 2x for the screen, then stored halved in `assets/ui/lacquer/map/` because the zone camera's zoom 2 doubles them again. `import_kit.py` checks every 2x2 block is uniform before halving. |
| Filtering | Nearest everywhere. The project default is nearest, but a `SubViewport` defaults to linear: set `canvas_item_default_texture_filter = 0` on every SubViewport (the zone one does). Never set `texture_filter = 2`. |
| Non-pixel art | Painted, vector or downscaled high-res art does not belong: it is a second visual language. Replace it with grid art (`_ai`, or the user draws it); leave the user's file in place. |
| Placeholders | `res://64.png` and `res://icon.svg` (the Godot logo) are not icons. Use a kit icon (`ic_story_ai.png` and friends) until real art exists. |

## 10. Layout and copy

### The frame

| Rule | Value |
|---|---|
| Canvas | 1920x1080, stretch mode `viewport` |
| Margins | 24 px from every edge. The left column starts at x 24, the right at x 1456 (1920 − 24 − 440), the bottom line is y 1056 |
| Columns | Left and right columns are 440 wide. The open map runs from x 464 to 1456, centred on x 960 |
| Dock | 722, 976, 476x80, bottom centre |
| Overlays on the zone view | Fit in the map gap, about x 488 to 1432 (24 px inside each column), so the cabinet and the chest stay readable |
| Insets | Content sits 16–18 px inside a board's edge (chest content at x 1472; the cabinet's orbs and the Goals and Log titles at x 42). The cabinet's text column after the orbs is at x 138 |
| HUD boards under an overlay | On the zone view the Goals and Log boards are furniture, like the cabinet and the chest. The menu books leave them showing under the backdrop with the rest of the view, by the user's decision (commit `5e8d7394`, "keep the Goals board and the log under an open book"). Cycling leaves them showing beside its board and blocks the full log, as a book does. Only the merchant hides them today (`MainView.hide_hud_boards()`); whether it keeps doing so is part of G1 |
| Grid | Every position and size even |
| Height | Boards hug their content: the chest is max(176, list top + list height + 24); the Log grows upward 26 px a line; Goals loses 70 px when no quest is active |

### Copy that held up

- Short ledger lines, not sentences: `Aura Well · +1.5 Madra / s`, `5 min run · carries 120 Madra`, `haul in 3 s`. The user's review of the first adventure card: too much text "for how little it tells the user".
- Numbers carry units with spaces: `+1.5 Madra / s`, `46 / 60`, `17 / 18 XP`, `10 s`.
- A figure beats a sentence: a rod plus `46 / 60` replaced "Needs 60 Madra · you have 46".
- Mixed case for names and labels (`Core Density`, `Full log · L`, group labels in title case). Uppercase only in tags and seals.
- Empty states say what is true: `Nothing running`, `Aura Well · paused`, `Nothing to do here yet.`

### Copy question still open

The design review wanted the mode tags (IDLE, ACTIVE, SHOP, STORY) and the "·"-joined microcopy gone. The kit kept them on purpose because the approved spec has them (kit §0, "Kept on purpose"), and the user has not ruled on it since. Until they do, reworked screens should not add more mode tags or longer "·" chains than the zone view uses.

## 11. Implementation in Godot

**Theme.**
- Every lacquer root sets `theme = assets/themes/lacquer/lacquer_theme.tres`. Labels take `LabelLacquer*` variants; decimal lines take `RichTextLacquer`.
- The theme sets no `default_font` or `default_font_size`: a default would answer before `pixel_theme.tres`'s own variants. `test_theme_sets_no_defaults` guards this.
- Line pitch: each variant's `line_spacing` is the kit line height minus the font's height.
- Today the theme has only Label and RichTextLabel variants. A Button, PanelContainer, tooltip or scrollbar inside a lacquer root still falls back to `pixel_theme.tres` (backlog F3).

**Fixed pieces.** A `TextureRect` at the texture's size, placed at the kit's top-left; the baked shadow lands right and bottom. Never scale it.

**9-slices.** `StyleBoxTexture` with texture margins equal to the frame's thickness and nearest filtering. Overlay frames set no centre fill. When drawing a new 9-slice, keep grain and gloss out of the stretch zones, or they smear. The four in `assets/styleboxes/lacquer/`:

| Stylebox | Texture | Margins | Fill |
|---|---|---|---|
| `frame_brass.tres` | `lacquer_frame_brass_ai.png` 24x24 | 8 | none |
| `frame_hover.tres` | `lacquer_frame_hover_ai.png` 16x16 | 4 | none |
| `rail_thumb.tres` | `lacquer_rail_thumb_ai.png` 12x12 | top and bottom 4 | yes |
| `token.tres` | `lacquer_token_ai.png` 26x26 | left and top 6, right and bottom 8 | yes |

**Baked shadows and stacked slices.**
- A piece with a shadow is 4 or 2 px larger than its kit size. Place it at the kit top-left.
- **The column-shadow trick.** A board that grows is a column of slices (top, tiled middle, bottom) in one wrapper. Each slice carries only its part of the column's shadow: the right-hand strip all the way down, and the bottom strip only on the last slice. So the middle tiles cleanly and only the bottom slice is taller (`import_kit.py`, `bake_column`; the zone chest).
- **Slicing an existing board.** A fixed board can be cut into slices with no new art: `GoalsPanel` cuts `lacquer_goals_ai.png` into cords, top, tiled middle and bottom, so the board can shrink.

**Components.**

| Piece | Use |
|---|---|
| `LacquerStripRect` (`scenes/common/lacquer/lacquer_strip_rect.gd`) | Set `strip` and `frame_size`, then `set_frame(column, row)`. Orbs, beads, rings, any strip |
| `LacquerRod` (`scenes/common/lacquer/lacquer_rod.tscn`) | Set the three textures and `steps`, then `set_fraction(f)` |
| `LacquerFrameOverlay` (`scenes/common/lacquer/lacquer_frame_overlay.tscn`) | Full-rect frame over its parent, hidden, mouse ignored, brass by default. Override the panel style with `frame_hover.tres` for hover. `flash(times)` for a flash; show it for a steady frame |
| `LacquerRail` (`scenes/zones/zone_panel/lacquer_rail/lacquer_rail.tscn`) | `bind(host)` to a `ScrollContainer` whose scrollbar is hidden; `step_to(target)` scrolls in steps |
| `LacquerText` (`scripts/utils/lacquer_text.gd`) | `rate()`, `decimal_bbcode()` |
| `LacquerFloater` (`scenes/common/lacquer/lacquer_floater/`), `MapGlyph`, `MadraPellet` | Stepped rise, even-px shake and twinkle, snapped flight. `LacquerFloater` and `MapGlyph` expose static functions of elapsed time (`rise_at`, `shake_offset_at`, `twinkle_frame`) that tests call directly; `MadraPellet` snaps its point to even px every frame, and `set_texture()` swaps its art for another 12x12 pellet (the cycling XP pellets). Copy this shape for new stepped motion |

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
- [ ] No text is cut off: a line too long for its width wraps, and its board grows.
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
- [ ] No decimal point in BM Euljiro at 15–17 px.
- [ ] No placeholder icons (`res://64.png`, `res://icon.svg`).

## 13. Cascade backlog

Every surface the 2026-10-22 survey found outside the zone view, grouped by area. Surfaces that several surveys found (the backdrop, the floater) are one row each. F1–F3 are shared prerequisites drawn from the surveys' notes, not surfaces. IDs are for reference in branches and PRs. Sizes are rough: **S** a day or less, **M** a few days, **L** a week or more, or a lot of new art.

| Area | IDs | Rows | S | M | L |
|---|---|---|---|---|---|
| Foundations (shared) | F1–F7 | 7 | 1 | 5 | 1 |
| Zone view overlays | Z1–Z2 | 2 | 1 | 0 | 1 |
| Dialogue | D1 | 1 | 0 | 0 | 1 |
| Combat HUD | B1–B9 | 9 | 2 | 6 | 1 |
| Adventure map | A1–A9 | 9 | 5 | 3 | 1 |
| Adventure stage | S1–S3 | 3 | 1 | 1 | 1 |
| End card | E1 | 1 | 0 | 0 | 1 |
| Menu books | K1–K13 | 13 | 6 | 6 | 1 |
| Project-wide | P1–P2 | 2 | 1 | 0 | 1 |
| **Total** | | **47** | **17** | **21** | **9** |

**Taking a row in another branch:**
1. Make sure the kit's files are there (the branch includes `feat/zone-view-redesign-4656b7`).
2. Settle the row's open questions with the user before building.
3. Build to §3–§11 and check the result against §12 on a 1920x1080 capture.
4. Add any new variant or stylebox to UI_STYLING.md and `tests/unit/test_lacquer_pieces.gd`; rewrite the tests that pin the old look.
5. Update the area's living doc, and delete the row here (docs/README.md: delete fixed items rather than striking them through).

### Foundations (shared by several areas)

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| F1 | Palette additions | Combat and the merchant use colours with no kit slot: `#E86A5C` / `#7FD18B` (bars, orbs, damage numbers), `LabelRed` `#E06060` / `LabelGreen` `#7DCE82` (merchant), `#7EA870` for Madra in item effect text, BBCode red and blue in the timeline | The user picks ramps for health, stamina, damage taken and gains or heals. Add them to kit §2, this guide and `ThemeConstants.LACQUER_*`. Madra stays the Madra ramp | S | `scripts/utils/theme_constants.gd`, `scenes/combat/combatant/combatant_visual/combatant_visual.gd`, `scenes/ui/combat/resource_bar/resource_bar.gd` |
| F2 | Shared kit pieces (new art) | The kit has fixed-size boards and four 9-slices (`frame_brass`, `frame_hover`, `rail_thumb`, `token`). Almost every other screen needs pieces that grow | New `_ai` art from the generators: a plain board 9-slice (`board_base()`) and a strapped one (`strap()`), a small popover or tooltip 9-slice, a text-button set (normal, hover, pressed, disabled), a dither backdrop tile, a carved slot socket, a 22x22 key cap, rods for health, stamina, cast and intent, a cooldown strip, "off" arrow caps. Grain out of stretch zones; shadows baked | L | `docs/superpowers/mockups/zone-view-lacquer/gen/`, `assets/ui/lacquer/`, `assets/styleboxes/lacquer/` |
| F3 | Lacquer base types | `lacquer_theme.tres` has only Label and RichText variants, so a Button, PanelContainer, tooltip or scrollbar in a lacquer root falls back to `pixel_theme.tres`: rounded `border_blend` buttons, tan parchment panels, the grey 8x8 pack at 1x | Add Button, PanelContainer, TooltipPanel and TooltipLabel, V/HScrollBar (rail textures, as the full log does), HSeparator (`lacquer_line_ai.png`) and ProgressBar (rod textures) to `lacquer_theme.tres`. Opt-in: only roots that set the theme get them. Keep "no defaults" | M | `assets/themes/lacquer/lacquer_theme.tres`, `tests/unit/test_lacquer_pieces.gd`, `docs/UI_STYLING.md` |
| F4 | Render settings | The adventure's `TilemapSubviewport` and `CombatSubviewport` set no `canvas_item_default_texture_filter`, so they render linear. Three nodes force `texture_filter = 2` (merchant TopLight and SlotGlow, the combatant Shadow). Window stretch scales fractionally | Set the filter to 0 on both SubViewports. Remove the forced linear filters with their screens. Decide integer `scale_mode` (open question). Re-check the fog shader and smoke veils after the change | M | `scenes/adventure/adventure_view/adventure_view.tscn`, `project.godot`, `scenes/merchant/merchant_atmosphere/merchant_atmosphere.tscn`, `scenes/merchant/merchant_stock_row/merchant_stock_row.tscn`, `scenes/combat/combatant/combatant_visual/combatant_visual.tscn` |
| F5 | Modal backdrop (`GreyBackground`) | A translucent teal-grey panel (`#2D3737` at 55.7%), shared by the four books, the merchant and the end card. The books and the merchant fade it in over 0.3 s and out over 0.2 s (`show_with_panel` / `hide_with_panel`); the end card toggles `visible` with no fade. The merchant hides the HUD boards (`hide_hud_boards`); the books (the user's decision, `5e8d7394`) and the end card leave them dimmed under it. Cycling uses no backdrop: its board sits in the map gap with the HUD boards up. Its alpha is left at 0 after a fade-out (MAIN_VIEW.md bug). The Dialogic background (`#2D2D2D` at 82.7%) and the dev modal (black at 60%) are translucent too | An opaque 2-step `#050707` dither tile (new `lacquer_dither_backdrop_ai.png`) shown and hidden outright for every user. For the merchant and the end card only, the alternative is no backdrop with `MainView.hide_hud_boards()` (G1). The books keep the HUD boards under their backdrop. Keep `show_with_panel` / `hide_with_panel` / `panel_hidden` / `clicked`, so no state changes. Rewrite the fade-timing tests | M | `scenes/ui/grey_background/grey_background.gd`, `assets/styleboxes/zones/grey_background.tres`, `scenes/main/main_game/main_game.tscn`, `tests/unit/test_grey_background.gd` |
| F6 | Shared floater (`FloatingText`) | Half done. The map's floater was promoted to `LacquerFloater` (`scenes/common/lacquer/lacquer_floater/`: a token with a 16 px `RichTextLacquer`, 40 px in 20 steps, hidden outright), and the map and each cycling zone use it. Still on `FloatingText`: the combat bars and orbs, with 24 px text, a 5 px black outline, engine colours, a 100 px cubic-eased rise and an alpha fade; its `font_size` override is a no-op | Point the combat bars and orbs at `LacquerFloater` with palette colours; delete `FloatingText` | M | `scenes/ui/floating_text/`, `scenes/ui/combat/resource_bar/resource_bar.gd`, `scenes/ui/combat/resource_orb/resource_orb.gd` |
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
| B1 | Player HUD dock and stamina bar | A 700 px navy `StyleBoxFlat` (93%, gold border at 45%, 14 and 6 px corners, 5 px soft shadow); translucent track, ghost (55%) and cost preview (45% white, alpha pulse); eased value tween; white text with black outlines; `pixel_theme` root | A recessed lacquer shelf like the dock (new wider `_ai` art, 4 px shadow). Stamina as a `LacquerRod` (F2, colour per F1); the ghost a second rod one step lighter; the cost preview a stepped blink. `LabelLacquerDetail` labels; `lacquer_theme` root | M | `scenes/ui/combat/player_hud/`, `scenes/ui/combat/resource_bar/`, `assets/styleboxes/combat/` |
| B2 | Resource orbs (Health, Madra) | 130 px orbs on `liquid_wave` (continuous time, smooth waves); translucent liquid, ghost and shine; a `StyleBoxFlat` ring with a soft shadow; an overbright red low-health pulse; lerped fills | Madra: the cabinet's orb (strip frame 0 + `lacquer_madra_orb.gdshader`). Health: a rim frame and a health version of the shader in the F1 ramp. The shaders assume 80x80: keep 80 or parameterise. Values `LabelLacquerBig` with a tan `/ max`; low health as a stepped frame flash or a seal; the ghost as a stepped second level | L | `scenes/ui/combat/resource_orb/`, `assets/shaders/liquid_wave.gdshader`, `assets/shaders/lacquer_madra_orb.gdshader` |
| B3 | Ability bar slots | A gold glow ring (3 px border plus a 6 px shadow at 35%) pulsing in alpha while casting; hover scale 1.06 and brightness 1.2; ready pulse 1.1; 35% alpha for unaffordable and empty; translucent key chips; `5.0s` in Euljiro; off-palette cost pips; mixed icon densities | Carved slot sockets (F2, about 80x80, 2 px shadow). Hover `frame_hover`; casting a steady `frame_brass`; ready `flash(1)`. Key cap (F2) with `LabelLacquerHotkey`. Costs with mini icons and `LabelLacquerDetail`. Cooldown as a stepped strip with whole seconds or a Yatra point. Unaffordable and empty as palette states | M | `scenes/ui/combat/ability_button/`, `assets/styleboxes/combat/slot_cast_glow.tres`, `assets/styleboxes/combat/panel_keyhint.tres` |
| B4 | Player cast bar and enemy intent bar | Navy panels (82–94%) with rounded corners and faint borders; rounded fills; fades in and out; overbright pulses (1.8) and a 2.2 release flash; `1.9s` in Euljiro; black outlines | A recessed tray like the Now tray (narrower `_ai` art), a 32 px icon in a socket, the cast as a `LacquerRod` (player and enemy rods, F2), the time via `decimal_bbcode()`. Shown outright; release as `frame_brass` `flash(1)`; interrupt as an even-px shake | M | `scenes/ui/combat/cast_bar/`, `assets/styleboxes/combat/cast_bar_fill.tres`, `assets/styleboxes/combat/panel_intent.tres` |
| B5 | Enemy nameplate and health bar | A 360 px navy plate at 82% with a 22% gold border, 4 px corners and a soft shadow; rounded red fill; translucent ghost and track; outlines on every label | A lacquer plate in the map-plate family (new `_ai`, about 360 wide; a boss version with brass caps). Name `LabelLacquerName` (brass for a boss); health as a `LacquerRod` with a stepped ghost | M | `scenes/ui/combat/enemy_nameplate/`, `assets/styleboxes/combat/panel_nameplate.tres`, `assets/styleboxes/combat/bar_fill_health.tres` |
| B6 | Buff bar and buff icons | The 64 px ability icon squeezed to 32x32 (halving 1x-detail art); a translucent duration overlay; `5.0s` in Euljiro; a pale frame and black outlines | A carved 40x40 socket, 16 art px buff icons (`_ai`, or the user's), a stepped duration strip (`LacquerStripRect`), the stack count on `lacquer_seal_count_ai.png`, whole seconds | S | `scenes/ui/combat/buff_bar/`, `scenes/ui/combat/buff_icon/` |
| B7 | Combat tooltips (ability, buff) | A 600 px brown `StyleBoxFlat` with 8 px corners and an 8 px soft shadow; the 64 px icon at 96; rounded stat pills; placeholder `res://64.png` | A lacquer board that sizes to its content (F2 9-slice); icon at 64 or 32; `LabelLacquerPopoverTitle` / `PopoverBody`; `LabelLacquerDetail` figures; `lacquer_line_ai.png` dividers; stats as carved tags (B8) | M | `scenes/ui/combat/combat_ability_tooltip/`, `scenes/ui/combat/combat_buff_tooltip/`, `assets/styleboxes/abilities/tooltip_panel.tres` |
| B8 | Ability stat pills and `StatTooltip` | Translucent rounded pills (60% fill, 50% border); a gold border pulsing forever on DMG; a colour per stat (red, green, blue, purple, teal, pink); a tooltip built in code with a soft shadow; cubic count-up; overbright hover | Carved tags (`lacquer_tag_ai.png`, `lacquer_tag_wide_ai.png`) with `LabelLacquerTag`; values `LabelLacquerDetail`; attribute icons instead of colours; the tooltip as a lacquer board in a `.tscn`; values set outright; no pulse | M | `scenes/abilities/ability_stats_display/`, `scenes/abilities/stat_label/`, `scenes/abilities/stat_tooltip/stat_tooltip.gd`, `assets/styleboxes/abilities/stat_pill.tres` |
| B9 | Damage numbers | 34 px Euljiro with an 8 px near-black outline; off-palette red and green; a scale pop from 0.4 with a back ease; a cubic rise with random drift; a fade out | The shared floater (F6), or bare Euljiro with the kit's 2 px ink outline (A-Q9; an exception to §12's "No text outlines"); rising in 2 px steps, hidden outright, no scale pop; colours from F1 | S | `scenes/combat/combatant/combatant_visual/damage_number.tscn`, `scenes/combat/combatant/combatant_visual/combatant_visual.gd` |

### Adventure map

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| A1 | Map camera, tile density, character | Tiles at zoom 1.0, half the zone map's density; wheel zoom 0.3–1.3 with easing, so most zooms are fractional; the character at scale 2.5 with no `snap_walk_to_whole_px` | Match the zone map: zoom 2 (or its 1–2 range), the character at scale 1 with `snap_walk_to_whole_px` and `lacquer_char_shadow_ai.png`, clamped like the zone map | M | `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn`, `scenes/camera/camera_zoom_controller/camera_zoom_controller.gd`, `scenes/characters/main_character/character_body_2d.tscn` |
| A2 | Fog of war | A full-screen shader: navy at 85% with a soft `smoothstep` edge round the visited tiles (a green halo in captures); painted smoke veils at 1.5x, 92% opaque, fading out over 0.25 s; an orange-to-magenta `?`; visited tiles darkened by a 35% overlay tile | Rebuild as the zone map's lattice: a fog `TileMapLayer` with `lacquer_fog_t{1,2,3}_atlas_ai.png` tiered by `ZoneMapMath.fog_tier()` on the map ground. Unknown neighbours as veiled tiles with a dotted tan rim and the tan `?` (`MapGlyph`), shown outright. Visited tiles without alpha (open question). New art: veils for the adventure's forest variants | L | `assets/shaders/fog_of_war.gdshader`, `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, `scenes/adventure/fog_veil_sprite.tscn`, `scenes/tilemaps/tilemap_tileset.tres` |
| A3 | Hover selector and current tile | An 8-frame pale-yellow bracket strip: the brackets the zone view dropped as reticle-like. No mark on the player's own hex | Rim swaps from `assets/ui/lacquer/map/`: `hex_current` on the player's hex, `hex_open` on reachable neighbours, `hex_hover` on hover, `hover_in` / `pinned_in` in veiled hexes. Retire `HexHoverSelector` (the adventure is its only user) | S | `scenes/tilemaps/hex_hover_selector.tscn`, `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn` |
| A4 | Encounter icons | Glyphs scaled to 84 px (1.31x of 64, 2.63x of the 32 px trap); mixed 2x and 1x art; completed at 90% alpha with a smooth green tick; pop-in from scale 0.3 with a back ease and a fade; placeholder `res://64.png` | An `_ai` glyph set at 16 or 24 art px (32 or 48 on screen), ink outline, 2 px shadow, kit colours. Reuse `combat_icon.png` at 32 and `lacquer_mini_swords_ai.png`. The boss as a stepped strip. Completed as a seal or a "spent" palette (open question). Shown outright | M | `scenes/adventure/encounter_icon/`, `assets/sprites/adventure/encounter_glyphs/` |
| A5 | `AdventureMarker` | A 280 px smooth teal map pin with a white outline at scale 0.5, the glyph at 0.7 | A lacquer pin (new `_ai`, brass rim, ink outline, 2 px shadow) holding the glyph at file size, or no pin: the current-hex rim and a map plate (open question) | S | `scenes/adventure/adventure_marker/` |
| A6 | `PathPreview` | A 20 px `Line2D` with a 1x stone texture, round caps and joints, and an alpha gradient fading the part behind the character | The zone map's dotted route (`lacquer_route_dot_ai.png`, `_lit_ai.png`), laid hex to hex like `ZoneRoute`; dots behind the character hide one at a time | S | `scenes/adventure/path_preview/` |
| A7 | Boss reveal | A full-screen light-blue flash at 60% fading over 0.4 s; a cubic-eased camera push | Drop the flash. The pinned inner rim shown outright, the boss glyph shaken in even px, a vermilion seal or plate naming the boss. Keep the hit-stop | S | `scenes/adventure/adventure_tilemap/adventure_tilemap.gd`, `scenes/adventure/adventure_tilemap/adventure_tilemap.tscn` |
| A8 | `EncounterInfoPanel` and choices | A fixed 376x400 navy panel at 92% with a gold stripe at 60% and a 1 px gold line at 40%; choice buttons on the old round-3 card styleboxes (80% fill, 8% white border); fades; disabled at 40% alpha; does not hug a one-choice encounter | A lacquer board that hugs its content, or a popover pinned beside the hex (`ZoneMapPopover` pattern). `LabelLacquerPanelTitle`, `LabelLacquerLore`, `lacquer_line_ai.png`; choices as drawers with `frame_hover`; disabled as tan text and the LOCKED seal; shown outright. Retires `action_card_normal.tres` / `_hover.tres` | M | `scenes/adventure/adventure_tilemap/encounter_info_panel.tscn`, `scenes/adventure/adventure_tilemap/encounter_choice_button.gd`, `assets/styleboxes/adventure/panel_encounter.tres` |
| A9 | Adventure timer | A 140x44 navy pill (88%, 6 px corners, gold border at 45%, 3 px soft shadow); the 32 px hourglass at 28x28; black-outlined gold text; red `#e86a5c` and a 1.08 scale pop each second under 30 s | A small lacquer plate (new `_ai`, 2 px shadow), the hourglass redrawn at 16 art px shown at 32, cream text with no outline; low time as the cream time on a vermilion plate or seal, plus a `frame_brass` flash each second (never vermilion text on lacquer: 2.76:1) | S | `scenes/adventure/adventure_view/timer_panel.gd`, `scenes/adventure/adventure_view/adventure_view.tscn`, `assets/styleboxes/adventure/panel_timer.tres` |

### Adventure stage

| ID | Surface | What breaks the guide today | Lacquer treatment | Size | Key files |
|---|---|---|---|---|---|
| S1 | Parallax forest backdrop | 12 layers at 3.5x (the sky at 15x) drifting at fractional speeds; a teal-green cast over the map and combat; the painting the zone view dropped; layers built in code | Map: drop it; the map ground `#090E0E` under the fog lattice. Combat: a new stage at exactly 2x in kit ramps, static or frame-strip motion. If kept anywhere, an even integer scale with integer parallax steps. `ZoneViewBackground` has no other user | M | `scenes/zones/zone_view_background/`, `scenes/adventure/adventure_view/adventure_view.tscn`, `assets/sprites/zones/backgrounds/spirit_valley/` |
| S2 | `Atmosphere` layer | A `smoothstep` vignette; mists at 4–5x tinted pale blue at 56% on sine tweens; cyan and green GPU motes fading on an alpha curve; combat builds its own instance in code | Depends on A-Q2. If the rules hold: remove it from the adventure tilemap and from `AdventureCombat._setup_atmosphere()`, as the zone view did; if life is wanted, a few opaque 2x-grid motes in kit colours, switching frames and moving in 2 px steps. If the user keeps it as a declared exception to §3 rule 9, leave it and record the exception here | S | `scenes/atmosphere/`, `assets/shaders/vignette.gdshader`, `scenes/combat/adventure_combat/adventure_combat.gd` |
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
| K2 | Page chrome (`book_theme`) | Rounded key chips (radius 3); selection and the path inset shown by `modulate` tints; card, row, pill and plaque art at 4 px per art px (measured 2026-10-22: 100%, 100%, 100% and 99.9% uniform 4x4 blocks) beside 2 px slot art; odd content margins (plaque 11 / 7, key chip 1 / 2); `LabelBookPositive` green `#3E7A3A` off-palette | Selection as a frame overlay; key chips as carved key caps (F2) shared with combat (B3); even margins; benefit text in a palette colour; optional Yatra plaque titles; optional 2 px redraws of card, row, pill and plaque. These are all `_ai` files, so the redraws touch no user art | M | `assets/themes/book_theme.tres`, `assets/sprites/ui/book/` |
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
| Madra drain pellets (`MadraPellet`) | Already lacquer: opaque, snapped to even px, no trail |
| The cycling view: board, groove, ball, zones, pellets, floaters, technique drawers | Already lacquer (built 2026-10-22 and 23) |
| Log and Goals boards in the adventure view | Already lacquer. `LogWindow.tone_for()` maps each line's first `[color]` tag to a lacquer tone (brass, Madra, cream, or tan for anything else), so adventure and combat log lines need no change |
| Book open, close and page-turn strips | Already stepped frame strips |
| `palette_swap.gdshader`, the attribute icons | Reusable as they are |
| Dev panel and dev password modal | Players never see them. Exempt (confirm, G11); they change for free if P1 lands |

### Suggested order

| Step | Rows | Why this order |
|---|---|---|
| 0. Decide | G1, G2, G4, K-Q1 | They block the most rows: the backdrop (every overlay), the palette (combat, merchant), icon sizes (inventory, merchant, end card, hotbars) and the books |
| 1. Foundations | F1–F7 | Shared art and theme types every later area needs. The render fix is cheap and global. The backdrop and the floater have three or more users each |
| 2. Zone view overlays | Z1, Z2 | They sit on top of the finished zone view, so the clash is most visible there. The merchant is the first real user of the new board, button and tooltip pieces |
| 3. Dialogue | D1 | Shown over the zone view and from encounters. One timeline today, so the risk is small, but it needs a custom Dialogic layer |
| 4. Combat HUD | B1–B9 | Needs the palette decision. Large reuse (orb shader, rods, frames, tags) |
| 5. Adventure map | A1–A9 | Reuses the zone map's machinery (fog tiers, rims, routes, glyphs, popovers). Depends on the zoom decision (A-Q4) |
| 6. Adventure stage | S1–S3 | Needs new art, the combatant-art decision (A-Q8) and the ambient decision (A-Q2) |
| 7. End card | E1 | Needs its metaphor decision and the item tooltip (F7) |
| 8. Menu books | K1–K13 | Last or partly never, per K-Q1. **K8 and K9 are broken in the running game: fix them at any time on the book material, whatever the look decision** |
| 9. Project-wide | P1, P2 | Switching the project theme last, once every area has opted in, keeps the blast radius small |

### Open questions

The user decides these. "Lean" is the survey's suggestion, not a decision.

**Global**

| # | Question | Options | Lean | Blocks |
|---|---|---|---|---|
| G1 | What dims the game behind a modal? | An opaque 2-step dither; translucency allowed for backdrops only; for the merchant and the end card only, no backdrop with the HUD boards hidden (cycling already runs with no backdrop and the HUD boards up). Not for the books: the user decided they leave the Goals board and the log showing under the backdrop (`5e8d7394`), and that option would reverse it | Opaque dither | F5, Z1, D1, E1, books |
| G2 | Which palette colours mean health, stamina, damage taken, heals and gains? Is there a warning or danger text colour? | New ramps (vermilion is for seals, jade for progress fills, brass for rewards). Vermilion cannot be text: `#A83C30` is 2.76:1 on lacquer and 2.25:1 on the raised face, under the 4.56:1 floor, so until a text colour exists warnings go on a vermilion seal or plate | — | F1, B1–B9, F6, Z1, A9 |
| G4 | Item icon size? | The user's 64 px icons at 64 (bigger slots); at 32 like the cabinet's gold icon (some 2 px detail lost); `_ai` redraws at 16 art px | — | K5, K6, K7, Z1, E1, F7 |
| G5 | Project theme: one cascade or opt in? | Make base types lacquer project-wide; each area opts in by setting `lacquer_theme` on its root. Are the cream book pages a sanctioned second material? | Opt in, decide P1 last | F3, P1 |
| G6 | Integer window scaling? | `scale_mode` integer (letterboxes 2560x1440 and 1366x768); fractional | — | F4 |
| G7 | Eased camera moves? | Keep them (the zone view does: recentre, adventure zoom-in); step them | Keep | A7, the adventure zoom-in |
| G8 | Mode tags and "·"-joined lines? | Keep (spec); drop (design review) | Kept for now | Every reworked screen |
| G9 | The painted ability icons with cyan glow? | Keep the user's icons in a carved socket; `_ai` redraws on the grid without glow | — | B3, B6, K10 |
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
| A-Q1 | The painted forest behind the adventure? | Keep it on the grid; the map ground for the map and a new lacquer stage for combat | S1, A2 |
| A-Q2 | Ambient motion in the adventure? | None; a stepped pixel ambient (fireflies, falling leaves); keep the `Atmosphere` (vignette, mists, motes) in the adventure as a declared exception to §3 rule 9 | S2 |
| A-Q3 | Visited but not current hexes, without a translucent overlay? | Unchanged; a darker veil step; marked only by rims and route dots | A2 |
| A-Q4 | Adventure map zoom? | 2, like the zone map (needs panning on a 21+ tile map); a zoom-1 overview (half the density) | A1–A7 |
| A-Q5 | Encounter glyphs? | 32 or 48 px on the map; completed as a seal or a palette change | A4, A5 |
| A-Q6 | "You are here"? | A floating lacquer pin; the brass current-hex rim plus a plate | A5 |
| A-Q7 | Encounter panel? | A side board at a fixed spot; a popover anchored to the hex | A8 |
| A-Q8 | Combatant art? | Who draws it (the user or `_ai` placeholders) and at what size (for example 64x96 art px shown at 128x192) | S3 |
| A-Q9 | Damage numbers? | On the lacquer token like map floaters; bare Euljiro with the kit's 2 px ink outline. The outline is an exception to §12 ("No text outlines"), taken from kit §3 as it stood before revision 2 dropped it (kit §0) | B9 |
| A-Q10 | Combat orb size? | The kit's 80 px; a new even size (parameterise the shader) | B2 |
| A-Q11 | Buff icons? | Their own small icons; the ability icon in a socket | B6 |
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
| Reference renders (open in a browser) | [zone view](superpowers/mockups/zone-view-map-first-mockup.html), [cycling view](superpowers/mockups/cycling-view-lacquer-mockup.html) |
| Generators | `docs/superpowers/mockups/zone-view-lacquer/gen/`, `docs/superpowers/mockups/cycling-view-lacquer/gen/` |
| Theme variants, lacquer styleboxes and pieces | [UI_STYLING.md](UI_STYLING.md) |
| The built zone view (map, chest, cards, orb shaders) | [zones/ZONES.md](zones/ZONES.md) |
| UI shell, HUD boards, `GreyBackground`, dock | [infrastructure/MAIN_VIEW.md](infrastructure/MAIN_VIEW.md) |
| The built cycling view (board, groove, pellets, technique drawers) | [cycling/CYCLING.md](cycling/CYCLING.md) |
| Cycling view spec (layout, hit tiers, the choices behind them) | [superpowers/specs/2026-10-22-cycling-view-lacquer-design.md](superpowers/specs/2026-10-22-cycling-view-lacquer-design.md) |
| Built pieces | `assets/themes/lacquer/lacquer_theme.tres`, `assets/ui/lacquer/`, `assets/styleboxes/lacquer/`, `scenes/common/lacquer/`, `scenes/zones/zone_panel/lacquer_rail/`, `scripts/utils/lacquer_text.gd`, `scripts/utils/theme_constants.gd`, `assets/shaders/lacquer_madra_orb.gdshader`, `assets/shaders/lacquer_core_orb.gdshader` |
| Piece tests | `tests/unit/test_lacquer_pieces.gd` |
| Rules for agent-made art and scene-tree UI | [../CLAUDE.md](../CLAUDE.md) (AI-Generated Art, GDScript Coding Standards) |
