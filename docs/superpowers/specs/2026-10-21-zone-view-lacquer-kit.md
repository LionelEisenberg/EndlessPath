# Lacquer and brass: zone view kit (1920x1080)

The art kit for the map-first v2 zone view in the look the user picked on 2026-10-21 ("Lacquer and brass"). Layout and behaviour come from the approved spec ([2026-10-21-zone-view-map-first-design.md](2026-10-21-zone-view-map-first-design.md)) and the repo mock-up ([zone-view-map-first-mockup.html](../mockups/zone-view-map-first-mockup.html)), which is the reference render. Only the look changes, plus the few px the art needs, listed in §7 and §0.

## Godot build notes (read first)

- **Where the files are.** Screen-space textures are in `assets/ui/lacquer/` and show at their file size. Map-space textures (fog atlases, veiled tiles, hex rims, route dots, the character shadow) were drawn at 2x for the screen and are stored **halved** in `assets/ui/lacquer/map/`, because the zone camera's zoom 2 doubles them again. The seven placeholder action and material icons are in `assets/ui/lacquer/icons/` (16x16, show at 2x). The user's own files are used from their own paths (`assets/fonts/`, `assets/sprites/ui/...`, the hex atlas, the character sheet), never copied.
- **Shadows are baked in.** Every piece that §1 rule 3 gives a hard shadow carries it in the project file, which is 4 px (big pieces) or 2 px (small pieces) wider and taller than the kit size: place it at the kit's top-left and it lands right. The zone chest's three slices carry the column's shadow between them, so `chest_mid` tiles cleanly and only `chest_bot` is taller. `lacquer_token_ai.png` (the floater's 9-slice) is 26x26: its margins are 6 on the left and top and 8 on the right and bottom.
- **Superseded rows.** §0 (revision 2) overrides §1–§8 wherever they differ. Files that §1–§8 still name but revision 2 removed: `lacquer_chest_ai`, `lacquer_log_ai`, both `lacquer_bracket_*`, `lacquer_glimmer_strip_ai`, `lacquer_ic_coin_ai`, `lacquer_ic_star_ai`, `lacquer_ic_swords_ai`, `lacquer_ic_character_ai` (use the user's `gold_icon`, `star_icon`, `combat_icon` and `character_icon`, 64 px files shown at 32x32).
- **The Now tray never collapses** (the user's review, 2026-10-22, overriding the mock and the rows below that move the header to 102 and the list to 132). With no idle action running it is drawn empty: tray and plate as always, the ring at frame 0, no action icon, and one 15/18 tan line (`LabelLacquerDetail`) at 1556, top 142.
- **The cabinet after the user's review (2026-10-22),** overriding §4.3 and §5.1 for the game:
  - **The orbs flow.** Two canvas_item shaders draw the fills, `assets/shaders/lacquer_madra_orb.gdshader` over frame 0 of `orb_madra_strip` and `lacquer_core_orb.gdshader` over column 1 (the empty socket) of `orb_core_strip`, or column 0 with no fill at level 0. They keep §1: each colour is worked out per 2 px art cell, only the Madra ramp is used, and time moves in 10 whole steps a second. The Madra liquid has a wavy surface with a 1 art px `#E8F6FD` crest over a `#849BE4` line, rising bubbles, a sliding sheen, drifting current dashes, a darker lower-right ring and a deep band; the core is a turning two-arm spiral in three bands with a bright core and a 1 art px bright edge, from radius 2.5 art px at level 1 to the socket's rim at 100. The strips' other frames, and the 1.5 s swirl phase, are no longer used by the game. See [ZONES.md](../../zones/ZONES.md#orb-shaders).
  - **Beads floor:** r = floor(xp × 18 / need), so a bead lights only once its share is earned and the row never runs ahead of the floored `xp / need XP` figure.
  - **Gold sits at the right:** coin, number and `gold` are one row ending at x 446 (coin top 232, number top 235, `gold` top 239), the right edge of the figures above.
  - **Goals hangs 4 px lower:** the board's root is at (24, 276), so its body starts at 300. The cords are `lacquer_goals_cords_ai.png` (444x24): the old 20 px cords with one more 4 px brass twist on top and the shadow baked from 4 px under the new top, placed 4 px above the root so they still start at the cabinet's rings (y 272).
- **Generators.** `docs/superpowers/mockups/zone-view-lacquer/gen/` holds the Python scripts that drew the kit and `import_kit.py`, which copied it into `assets/ui/lacquer/` (halving and shadow baking). Their paths point at the authoring session's scratch folder; change `lq_base.py` and `look.py` to rebuild.
- **The adventure card is a normal 72 px drawer** (the user's review, 2026-10-22: too much text for what it told; supersedes the §4.2 and §5.5 rows marked 2026-10-22). Below the threshold its detail row is `mini_madra` at x+64, y+38, `rod_adv` at x+86, y+40, `46 / 60` (15/18 tan) at x+248, y+38 and, only while a Madra action runs, `~10 s` (15/18 cream) right-aligned at x+380, y+38. At the threshold the title and tag keep the y+14 row, the detail line reads `5 min run · carries 120 Madra` (15/18 brass, x+64, y+38), and `frame_brass` sits over the card steadily, with no animation, in place of `drawer_tall_ready`. A flash hides that frame for its 1.2 s, then it returns.
- **Card icons sit on the drawer's middle row** (the user's review, 2026-10-22: "the icon should be centered in the box"; supersedes the `drawer_tall` row in §4.2 and the Icon row in §5.5). `drawer_tall` draws its 48x48 socket at (8, 24) instead of (8, 12), and its icon sits at x+16, y+32; the 72 px drawers keep the socket at (8, 12) and the icon at y+20, already centred. `drawer_face` in `gen/kit_ui.py` centres the socket at any height. `drawer_tall_ready` (unused) was not redrawn.

## 0. Revision 2 (after the design review; supersedes the rows it names below)

The repo mock-up (`docs/superpowers/mockups/zone-view-map-first-mockup.html`) is the reference render for revision 2; `gen/preview.py` still draws revision 1. Revision 1 is not kept in the repo.

**Brass marks only state.**
- The cabinet and the zone chest keep their chunky corner straps. Goals, Log, Dock, the lore panel and the map popover previews are plain boards (`board_base`): no corner caps.
- Brass caps stay on the running drawer, pinned map popovers and hovered dock buttons.
- Each board's gloss dash sits in a different place: cabinet top left (swatch), goals centre (swatch), chest top right, log top right, lore right, popovers centre, dock left of centre.

**Panels hug their content.**
- **Zone chest:** `lacquer_chest_top_ai.png` (440x128), `lacquer_chest_mid_ai.png` (440x128, `repeat-y`), `lacquer_chest_bot_ai.png` (440x48), stacked inside one wrapper that carries the 4 px shadow. `lacquer_chest_ai.png` is gone.
  - The height (local to the chest at 1456, 24) is max(176, list top + list height + 24).
  - When the list is taller than the space down to local 992 (screen 1016), it scrolls. The list then folds 8 px under its last whole drawer, so no drawer is cut and no group label is left alone at the bottom. The chest keeps 40 px under the list, so the rail's end cap clears the corner strap by 8 px or more. It snaps to the bottom line (local 1032, screen 1056) when that is within 64 px.
- **Log:** `lacquer_log1_ai.png` to `lacquer_log5_ai.png`, one per line count n, 74 + 26n px tall. Each is bottom-anchored at y 1056, so it grows upward. A line of age a has its top at (height − 42 − 26a). `lacquer_log_ai.png` is gone.
- **Lore:** opens inline. The panel is at the old position (local y 182, under the Now tray); the Activities header and the list move down 276 px (the 264 px panel plus 12).
- **Cards:** a non-idle card whose detail line is wider than 316 px at 15 px uses `drawer_tall` (96) and wraps the detail onto two lines (316 px wide, 18 px lines, from y + 38). This happens to the fresh-save Wilderness Cycling card.

**Map.**
- **Hover and pinned are rim swaps; the brackets are gone** (`lacquer_bracket_*` removed). All rims are laid at the tile's own top-left.
  - `lacquer_hex_hover_ai.png` replaces `hex_open` on an open hex you can travel to.
  - `lacquer_hex_hover_in_ai.png` (1 art px brass, then ink) and `lacquer_hex_pinned_in_ai.png` (2 art px brass, then ink) sit just inside the veiled hexes, inside their own dashed or dotted rim.
  - Draw them after `hex_current`, before the route dots.
- **The glimmer is gone** (`lacquer_glimmer_strip_ai.png` removed). `lacquer_glyph_twinkle_strip_ai.png` (42x14, 3 frames of 14x14, frame 0 empty) goes at (972, 84), next to the `?`. Every 4 s it plays frames 1, 2, 1 for 0.1, 0.2 and 0.1 s.
- **Routes cross only the shared rim:** six 8x8 dots, 24 px apart, centred on the midpoint between the two hex centres. The dot top-left is (centre + t·unit − 4), snapped to even, for t = len/2 + 24i with i = −2.5 … 2.5. They never reach a zone's middle, glyph or plate.
  - North: 1008,608 1020,586 1032,566 1044,546 1056,524 1068,504, then 1068,322 1056,302 1044,280 1032,260 1020,240 1008,218.
  - West: 852 828 804 780 756 732, all at y 698.
- **Character and map ring:**
  - The character is at (960, 740) in Spirit Valley and (632, 740) in Test Zone; the shadow is at +2, +42. The walk is still 328 px in 0.6 s, `steps(164)`.
  - Foraging wanders west only: 0 → −48 → −16 → 0 over 5 s.
  - The map ring is now 64x64 (`lacquer_map_ring_strip_ai.png`, 832x64, 13 frames). It sits on a lacquer disc in the Madra orb's brass rim, at (998, 706), a sibling of the character that stays with the zone's action. The action icon is at (1014, 722).
- **Floaters ride a lacquer token:** `lacquer_token_ai.png` (24x24, 9-slice: `border: 6px solid transparent; border-image: url(...) 6 fill / 6px stretch`, height 28, 2 px shadow).
  - The width is even(text width at 16 px + 28), centred on x 1010, with the top at 674. Text is 16/20, centred, with no outline.
  - `+1.5 Madra` is Madra blue and rises 40 px in 1 s, `steps(20)`. The haul is cream and shows once per haul, as before.

**Icons.** The user's own `character_icon.png`, `star_icon.png`, `gold_icon.png` and `combat_icon.png` are 16 art px drawn at 4x (64 px files), so at 32x32 they sit on the 2x grid. They replace `lacquer_ic_character`, `lacquer_ic_star`, `lacquer_ic_coin` and `lacquer_ic_swords` (removed). Only `ability_icon.png` is 32 art px (off the grid at 32 px), so `lacquer_ic_abilities_ai.png` redraws the user's hand-and-sparkles design at 16 art px in its palette, with the inventory bag's full ink outline. `lacquer_mini_madra` and `lacquer_mini_swords` are recoloured to the palettes of the user's `madra_icon` and `combat_icon`.

**Core Density level 0:** frame 0 of `lacquer_orb_core_strip_ai.png` is now a dormant core, a Madra-blue pebble (radius 5.4 art px) with a lit crescent and one glint, in place of the 1 px dot.

**Kept on purpose:** the mode tags, the microcopy (with its "·" joins and "/ s"), the plate status lines and the Activities header, all from the approved spec; Spirit Valley's centre at (960, 702), so the uncharted hex is still clipped at the top; and the Path button's brass notification ring (spec).

## 1. Rules for every builder

1. **One grid.** One art pixel is 2 screen px. Every `lacquer_*_ai.png` is already drawn at 2x, so show it at its file size, never scaled. The user's files and the placeholder icons (`Hex_Forest_*.png`, `main_character_spritesheet.png`, `inventory_icon.png`, `ic_*_ai.png`) are native size. Show them at exactly 2x.
2. **Nearest neighbour everywhere.** In HTML, put `image-rendering: pixelated` on every `img`, background and border-image. On a canvas, set `ctx.imageSmoothingEnabled = false`. Snap every position and size to even px. The one exception is the map's odd hex rows (see §6).
3. **Shadows are hard offsets only, with no blur:**
   - **4 px in `#050707`:** big pieces (cabinet, goals board, log board, chest, dock, lore panel, map popovers) and the running drawer.
   - **2 px in `#150909`:** small pieces (drawers, buttons, About, the Now plate, Show me, map plates).

   In CSS use `filter: drop-shadow(4px 4px 0 #050707)` or `filter: drop-shadow(2px 2px 0 #150909)`. On a canvas, draw the sprite's silhouette in the shadow colour at +offset first. Nothing else gets a filter.
4. **Never:** glow, halo, blur, `box-shadow` with blur, translucent panels, gradients (linear, radial or conic), opacity fades, rounded CSS pills, thin luminous borders or emoji. Every surface is an opaque texture from this kit.
5. **Jade (`#5CC4A0` ramp) is only for progress fills:** the Aura Well rod, the milestone rod, XP beads and the bead rings. Madra quantities use the Madra blue ramp (the orb and the adventure rod).
6. **Animation moves in whole steps.** Use `steps()` timing, move in 2 px steps and switch frames from strips. Show and hide things outright: never fade them or ease the colour.
7. **File names.** Every agent-made image ends in `_ai`. `Hex_Forest_00_Basic.png`, `Hex_Forest_06_River.png`, `main_character_spritesheet.png`, `inventory_icon.png` and the two fonts are byte-identical copies of the user's files and keep their names. Never edit them.

## 2. Palette

The swatch's palette, kept. The new pieces add only the fog and veil ramps (dark teal, the map ground's own family) and a few colours sampled from the user's icons.

| Hex | Name | Used for |
|---|---|---|
| `#150909` | ink | Outlines, carved lines, the empty rod groove, hard shadows of small pieces, text on brass |
| `#110707` | socket | Inside carved sockets (core orb, rail groove) |
| `#230F0F` | deep | Shaded rims, recessed tags and trays, the uncharted plate |
| `#2C1414` | lacquer | Panel and board fields (cabinet, chest, goals, log, lore, plates, popovers) |
| `#321616` `#391919` | grain | Hand-placed grain streaks |
| `#462020` | raised | Drawer and button faces, the gloss band |
| `#612B2B` | rim shade | Lit lower lips of grooves, hot gloss, a hovered rim |
| `#692F2F` | rim | Lit rims of raised lacquer |
| `#D4A84A` | brass | Straps, caps, the notification ring, painted titles, ENTER, reward text |
| `#A66834` | brass shade | Shaded brass, nail heads |
| `#F0E8D8` | cream | Main text, the brass highlight |
| `#A89070` | tan | Labels and secondary text, dotted rims, route dots |
| `#7A654C` | tan shade | Glyph and dot shading |
| `#94806A` | dim | The two oldest log lines (4.56:1 on lacquer, the floor) |
| `#AAECCE` `#5CC4A0` `#2F6B4A` `#102C1E` | jade ramp | Progress fills only |
| `#E8F6FD` `#BBD5E7` `#849BE4` `#1C2F60` `#16283E` | Madra ramp | Madra orb, adventure rod, core swirl, Madra text (floaters, log level-ups) |
| `#A83C30` `#7E2A22` | vermilion | Seals (NEW, LOCKED, the count), the locked plate rim, the locked hex's dashed rim |
| `#341E0E` `#E3B95A` `#C4884A` | coin gold | Coin and star icons |
| `#090E0E` | map ground | Screen background and grout between hexes |
| `#0C1312` `#111A19` `#16211F` `#1D2B28` | fog tier 1 | Line, shade, base and light pixels of tier-1 fog tiles |
| `#182423` `#0F1716` `#111A19` `#131D1C` | fog tier 2 | Tier 2: the lines are lighter than the fill (etched, as the swatch's grass dashes were) |
| `#0D1514` | fog tier 3 | Flat silhouettes |
| `#151A18` `#39423E` `#4B5550` `#5F6A65` `#76827C` (hover: one step up) | locked veil | The Advancement Zone tile |
| `#0B1211` `#16211F` `#1C2927` `#243431` `#2D3F3B` (hover: one step up) | uncharted veil | The uncharted tile and its glimmer |
| `#FFD1AB` `#E7A581` `#CF7957` `#17111A` | skin | The hand in `ic_abilities` (sampled from the user's `ability_icon.png`) |
| `#FFFFFF` `#BFDDD1` `#95ADB4` `#86718C` `#2E1C2C` | armour | `ic_character` (sampled from the user's `character_icon.png`) |
| `#050707` | shadow | 4 px hard shadows over the map |

## 3. Type

Two families, both in `assets/`:
- **Yatra One** for painted titles: `@font-face { font-family: 'Yatra'; src: url(YatraOne-Regular.ttf) }`.
- **BM Euljiro** for everything else: `@font-face { font-family: 'Euljiro'; src: url(BMEULJIROTTF.ttf) }`.

No text is smaller than 13 px.

| Role | Font, size / line-height | Colour | Background, contrast |
|---|---|---|---|
| Zone name (chest header) | Yatra 30/44, text-shadow `2px 2px 0 #150909` | brass | lacquer 7.8 |
| Panel titles: Goals, Log | Yatra 22/28, same shadow | brass | lacquer 7.8 |
| Activities header | Yatra 20/24, same shadow | brass | lacquer 7.8 |
| Stage name "Foundation" | Yatra 21/28, same shadow | cream | lacquer 14.2 |
| Big numbers: Madra value | Euljiro 30/36 (`/ 260` in tan) | cream | lacquer 14.2 |
| Gold value | Euljiro 22/28, then `gold` in 17/22 tan | cream | lacquer 14.2 |
| Names: card titles, quest and milestone names, `Level 32` | Euljiro 17/20 | cream | raised 11.6, lacquer 14.2 |
| Labels and detail lines: `Madra`, `Core Density`, card detail, figures (`17 / 18 XP`, `32 / 100`) | Euljiro 15/18 | tan | lacquer 5.7, raised 4.6 |
| Madra rate `+1.5 / s` (plate) | Euljiro 17/20 | tan | lacquer 5.7 |
| Now strip: action name / rate / line 2 | Euljiro 18/22 cream / 16/22 cream / 15/18 tan | | deep tray 15.0 and 6.0 |
| Mode tags (IDLE ACTIVE SHOP STORY) | Euljiro 13/22, uppercase, letter-spacing 1px, centred in the 76 px tag | tan; RUNNING cream; ENTER ink on brass | deep 6.0, deep 15.0, brass 8.8 |
| Seals: NEW, LOCKED, count | Euljiro 13/22 (count 15/18) | cream | vermilion 5.1 |
| Now legend | Euljiro 14/22 | ink | brass 8.8 |
| Dock label / hotkey | Euljiro 14/18 cream / 14/18 tan | | raised 11.6 / 4.6 |
| Log lines | Euljiro 15/18 | by tone and age, see §5.3 | lacquer ≥ 4.56 |
| Lore text | Euljiro 16/22 | cream | lacquer 14.2 |
| Map plate name / line | Euljiro 16/18 / 14/18 | see §6.5 | lacquer or deep ≥ 5.7 |
| Map popover title / body | Euljiro 18/22 / 15/20 | cream | lacquer 14.2 |
| Floaters on the map | Euljiro 16/20 with a 2 px ink outline (`text-shadow: 2px 0 #150909, -2px 0 #150909, 0 2px #150909, 0 -2px #150909, 2px 2px #150909`) | Madra blue for Madra, cream for hauls | ink 12.8 |

**Glyph gaps in Euljiro:**
- `›` (U+203A) renders blank, so "Show me" uses `lacquer_chev_ai.png` instead of the character.
- At 15–17 px the `.` in a decimal sits low and reads as a comma. Set the decimal point of a number in Yatra One (`+1<span class="pt">.</span>5`, with `.pt { font-family: 'Yatra' }`), the swatch's fix.
- Yatra One has no `→`, so `Lv 1 → 2` stays in Euljiro, which has one.

## 4. Texture catalogue

"Size" is the file size, which is also the display size for `lacquer_*` (native = half). "Use" says how to draw it. `img` means place the file at its size.

### 4.1 Panels and boards

| File | Size | Native | Use |
|---|---|---|---|
| `lacquer_cult_ai.png` | 440x252 | 220x126 | img, cultivator cabinet. Kept from the swatch. Brass straps and cord rings at x 60 and 378 for the goals board |
| `lacquer_goals_ai.png` | 440x220 | 220x110 | img, goals board. The top 20 px are its two cords (kept from the swatch); the board body is 200 tall |
| `lacquer_log_ai.png` | 440x204 | 220x102 | img, log board with chamfered corners and two bottom brass caps |
| `lacquer_chest_ai.png` | 440x1032 | 220x516 | img, the full-height zone chest |
| `lacquer_lore_ai.png` | 408x264 | 204x132 | img, lore popover panel with brass caps |
| `lacquer_now_tray_ai.png` | 408x88 | 204x44 | img, recessed Now tray |
| `lacquer_now_plate_ai.png` | 60x22 | 30x11 | img, the brass `Now` legend riveted over the tray's top edge. Kept from the swatch |
| `lacquer_dock_ai.png` | 476x80 | 238x40 | img, recessed dock shelf with brass caps |

### 4.2 Drawers, marks, frames, buttons

| File | Size | Use |
|---|---|---|
| `lacquer_drawer_ai.png` | 392x72 | img, activity card. Carved 48x48 icon socket at (8, 12) |
| `lacquer_drawer_run_ai.png` | 392x72 | img, running card: brass corner caps. Drawn **pulled out** at (x−2, y−2) with the 4 px shadow |
| `lacquer_drawer_tall_ai.png` | 392x96 | img, a non-idle card whose detail wraps (§0). Socket at (8, 24), on the middle row (2026-10-22; was (8, 12)). No longer the adventure's (2026-10-22) |
| `lacquer_drawer_tall_ready_ai.png` | 392x96 | img, adventure card at the threshold, with a brass edge. Unused since 2026-10-22: the ready card is a 72 px `drawer` under `frame_brass` |
| `lacquer_frame_brass_ai.png` | 24x24 | **9-slice overlay:** `border: 8px solid transparent; border-image: url(lacquer_frame_brass_ai.png) 8 / 8px stretch;` on a box the size of the target, with no fill. Used for the flash (card and Now tray) and for pinned map plates |
| `lacquer_frame_hover_ai.png` | 16x16 | **9-slice overlay**, `border-image: url(...) 4 / 4px stretch`. Hover on a drawer, the Now tray, Show me and About |
| `lacquer_tag_ai.png` | 76x22 | img, carved recess for IDLE, ACTIVE, SHOP, STORY and RUNNING |
| `lacquer_tag_enter_ai.png` | 76x22 | img, brass plate for ENTER (ink text) |
| `lacquer_tag_wide_ai.png` | 88x22 | img, carved recess for UNKNOWN |
| `lacquer_seal_new_s_ai.png` | 44x22 | img, the cinnabar NEW chop, inline after a card title |
| `lacquer_seal_locked_ai.png` | 88x22 | img, the cinnabar LOCKED chop; `mini_lock` sits at +8, +3 and the word at +26 |
| `lacquer_seal_count_ai.png` | 24x24 | img, Path point count. Kept from the swatch |
| `lacquer_about_ai.png` / `lacquer_about_open_ai.png` | 88x36 | img, About (raised) and About while the lore is open (pressed: no shadow, text +2 px) |
| `lacquer_btn_ai.png` / `lacquer_btn_hover_ai.png` / `lacquer_btn_ring_ai.png` | 108x64 | img, dock button: normal, hover (brass corner caps), notification (2 px brass ring; kept from the swatch) |
| `lacquer_showme_ai.png` | 104x32 | img, the popover's Show me button (text plus `chev`) |
| `lacquer_close_ai.png` / `lacquer_close_hover_ai.png` | 28x28 | img, the popover × with a carved x (tan, cream on hover). It needs no text |
| `lacquer_chev_ai.png` | 10x14 | img, the › after "Show me" |

### 4.3 Progress

| File | Size | Use |
|---|---|---|
| `lacquer_orb_madra_strip_ai.png` | 2640x80, 33 frames of 80x80 | background-position `-80k px 0`, with k = round(Madra / max × 32). Frame 0 is empty, 32 is full |
| `lacquer_orb_core_strip_ai.png` | 1360x320, 17 cols x 4 rows of 80x80 | position `-80k px -80p px`, with k = round(min(level, 100) / 100 × 16) and p the swirl phase 0–3. Optional spin: step p every 1.5 s (one turn per 6 s, as the mock), or hold p = 0. Frame 0 is the fresh-save dot |
| `lacquer_beads_xp_strip_ai.png` | 222x228, 19 rows of 222x12 | position `0 -12r px`, with r = round(xp / need × 18), 0–18 |
| `lacquer_rod_well_empty_ai.png` / `_full_ai.png` / `_end_ai.png` | 308x10 / 308x10 / 2x10 | Aura Well rod (jade). Draw empty, then the full rod clipped to width `2 + 2k`, with k = round(frac × 152), then the end cap at x = 2k when k ≥ 2 |
| `lacquer_rod_goal_*_ai.png` | 280x10 | Milestone rod (jade), k = round(frac × 138) |
| `lacquer_rod_adv_*_ai.png` | 152x10 | Adventure Madra rod (Madra blue), k = round(Madra / threshold × 74) |
| `lacquer_ring_strip_ai.png` | 728x56, 13 frames of 56x56 | Now ring, position `-56f px 0`, f = lit beads 0–12 |
| `lacquer_map_ring_strip_ai.png` | 780x60, 13 frames of 60x60 | The map's ring on its own lacquer disc, position `-60f px 0` |

**Ring timing:** run frames 0→12 once per action cycle: `steps(13)` over 1 s for the Aura Well (one tick), and over 5 s for foraging (one haul). Restart at frame 0 on each tick.

### 4.4 Rail, lips, grooves, bullets

| File | Size | Use |
|---|---|---|
| `lacquer_rail_track_ai.png` | 12x4 | background `repeat-y`, the carved groove |
| `lacquer_rail_thumb_ai.png` | 12x12 | **3-slice:** `border-style: solid; border-width: 4px 0; border-image: url(...) 4 0 4 0 fill / 4px 0 stretch;` at any even height ≥ 32 |
| `lacquer_rail_up_on_ai.png` / `_up_off` / `_down_on` / `_down_off` | 12x14 | img, the rail's end caps. **On** (brass arrow) when the list can scroll that way, **off** (carved) when it can't. They are the top and bottom scroll cues |
| `lacquer_lip_top_ai.png` / `lacquer_lip_bottom_ai.png` | 392x10 | img, a hard shelf shadow with a 2-step dither over the list edge. Shown while the list is scrolled away from that edge, in place of the mock's 24 px fade |
| `lacquer_line_ai.png` | 408x6 | img, carved divider with brass pins. Kept from the swatch |
| `lacquer_groove_ai.png` + `lacquer_groove_end_ai.png` | 4x6 + 6x6 | groove: background `repeat-x` on a flexible span, with the end pin at its right. For group labels and the Activities header |
| `lacquer_bullet_{brass,cream,madra,tan,dim}_ai.png` | 10x10 | img, inlaid diamond bullets for log lines |

### 4.5 Icons and glyphs

| File | Size | Use |
|---|---|---|
| `lacquer_ic_coin_ai.png`, `lacquer_ic_star_ai.png`, `lacquer_ic_swords_ai.png`, `lacquer_ic_core_ai.png` | 32x32 | img (16 art px, all kept from the swatch): gold, Path, adventure cards, the Breakthrough milestone |
| `lacquer_ic_abilities_ai.png`, `lacquer_ic_character_ai.png` | 32x32 | img, dock icons redrawn on the grid. The user's own are 32 art px, which would be off-grid at 32 px |
| `inventory_icon.png` (user) | 16x16 | show at 32x32, the Inventory dock icon |
| `ic_{cycle,forage,well,merchant,story,dewdrop,fern}_ai.png` | 16x16 | show at 32x32: action icons (the mock's placeholders, renamed `_ai`) |
| `lacquer_mini_{madra,dewdrop,forage,fern,well,swords,lock}_ai.png` | 16x16 | img (8 art px), the 16 px icons inside text lines |
| `lacquer_glyph_lock_ai.png` | 44x52 | img, brass padlock over the locked hex (hard shadow baked in) |
| `lacquer_glyph_unknown_ai.png` | 28x36 | img, the tan `?` over the uncharted hex |
| `lacquer_thumb_ai.png` / `lacquer_thumb_basic_ai.png` | 46x52 | img, header thumbnail (Spirit Valley's river tile / Test Zone's basic tile) with its brass outline |

### 4.6 Map

| File | Size | Use |
|---|---|---|
| `Hex_Forest_06_River.png`, `Hex_Forest_00_Basic.png` (user) | 164x190 | show at 328x380: Spirit Valley, Test Zone |
| `lacquer_tile_locked_ai.png` / `_hover_ai.png` | 328x380 | img, the Advancement Zone (Stones tile in a desaturated veil with a dashed vermilion rim baked in); the hover version is one step lighter |
| `lacquer_tile_uncharted_ai.png` / `_hover_ai.png` | 328x380 | img, the uncharted hex (Mountains2 in the dark veil with a dotted tan rim baked in) |
| `lacquer_glimmer_strip_ai.png` | 2952x380, 9 frames of 328x380 | Overlay on the uncharted tile, position `-328f px 0`. Every 6 s, play frames 1→8 at 10 fps (0.8 s), then hold frame 0 (empty) for 5.2 s |
| `lacquer_hex_current_ai.png` | 328x380 | img at the current zone's tile top-left: the brass rim plus a lacquer collar on the grout (the aura, without glow) |
| `lacquer_hex_open_ai.png` | 328x380 | img at an open zone you are not in: a dull brass hairline |
| `lacquer_bracket_hover_ai.png` | 368x420 | img at (cx−184, cy−210): three light brass brackets (top, lower left, lower right), the game selector's layout |
| `lacquer_bracket_pinned_ai.png` | 368x420 | img at (cx−184, cy−210): six heavier brackets with domed nails |
| `lacquer_plate_{current,open,locked,uncharted}_ai.png` + `_hover_ai.png` | 248x52 | img, map plates (see §6.5). The current and open hover versions only lift the rim; their hover is mainly the text colour |
| `lacquer_pop_locked_ai.png` | 272x172 | img, pinned locked popover: card 264 wide, notch on the **right**, brass caps |
| `lacquer_pop_locked_preview_ai.png` | 272x132 | img, hover preview of the locked popover (no caps, no buttons) |
| `lacquer_pop_uncharted_ai.png` / `_preview_ai.png` | 272x112 | img, the uncharted popover, notch on the **left**, pinned and preview |
| `lacquer_route_dot_ai.png` / `lacquer_route_dot_lit_ai.png` | 8x8 | img, dotted route dots: tan, or cream while hovering a zone you can travel to |
| `lacquer_char_shadow_ai.png` | 28x6 | img under the character. Kept from the swatch |
| `main_character_spritesheet.png` (user) | 128x288 | 32x48 element, `background-size: 256px 576px; background-position: -128px -96px` (frame 20 at 2x) |
| `lacquer_fog_{base,open,locked,both}_ai.png` | 1920x1080 | **The whole fog lattice for each demo state**, used as the frame background at (0, 0). States: base = no demo, open = open-zone demo, locked = locked & uncharted demo, both = both demos |
| `lacquer_fog_t{1,2,3}_atlas_ai.png` | 2952x380, 9 cells of 328x380 | Per-cell fog for builders that draw cells one by one: position `-328i px 0`, where i indexes the pool `00_Basic, 07_Mountains1, 09_Clearing1, 11_Lake1, 12_Lake2, 18_Hole, 19_Dead, 21_Ravine, 22_Cave` |

## 5. Panel layout (screen px)

The spec's rects are kept apart from the deltas in §7. Positions are absolute in the 1920x1080 frame.

### 5.1 Cultivator cabinet `24, 24, 440, 252` (4 px shadow)

| Piece | Position | Notes |
|---|---|---|
| Madra orb | 42, 40, 80x80 | `orb_madra_strip` frame |
| `Madra` | 138, 46 | 15/18 tan |
| `46` + ` / 260` | 138, 68 | 30/36 cream, then tan |
| `+1.5 / s` | right edge 446, top 80 | 17/20 tan. Only while the running action awards Madra |
| Core orb | 42, 132, 80x80 | `orb_core_strip` frame |
| `Core Density` | 138, 134 | 15/18 tan |
| `Foundation` | 138, 154 | Yatra 21/28 cream |
| `Level 32` | right 446, top 160 | 17/20 cream |
| XP beads | 138, 192, 222x12 | `beads_xp_strip` row |
| `17 / 18 XP` | right 446, top 189 | 15/18 tan |
| Divider | 40, 222 | `line` |
| Coin | 50, 232, 32x32 | `ic_coin` |
| `120` `gold` | 92, 234 (`gold` top 238) | 22/28 cream; 17/22 tan |

### 5.2 Goals board image `24, 272, 440, 220`, body `24, 292, 440, 200` (4 px shadow)

| Piece | Position | Notes |
|---|---|---|
| `Goals` | 42, 302 | Yatra 22/28 brass |
| Quest icon | 44, 340, 32x32 | `ic_story_ai` |
| Quest name | 88, 338 | 17/20 cream (`First Elite`; fresh save `Awaken Your Core`) |
| Quest figure (measurable steps only) | right 446, top 338 | 15/20 tan (`25 / 100`). It sits on the name row so the board keeps one height |
| Step text | 88, 360 | 15/18 tan |
| Divider | 40, 392 | `line` |
| Milestone icon | 44, 410 | `ic_core` |
| `Breakthrough` | 88, 408 | 17/20 cream |
| `Raise Core Density to 100` | 88, 430 | 15/18 tan |
| Rod | 88, 460, 280x10 | `rod_goal_*` |
| `32 / 100` | right 446, top 456 | 15/18 tan |

When no quest is active, hide the quest row and the divider and move the milestone row up 70 px. The board shrinks by the same 70 px to 440x150, so it hugs its content as the spec says (polish pass, 2026-10-22). The game cuts `lacquer_goals_ai.png` into four slices with no new art: the cords (rows 0–20, their own node, hidden while the board sits at the adventure view's top right), a top slice (rows 20–86), a tiled middle (rows 86–160) and a bottom slice (rows 160–224). At full height the slices rebuild the file exactly; at 150 the middle shows its first 4 plain rows. The cords' two brass hooks are drawn on the top slice, so while the cords are hidden it swaps for `lacquer_goals_top_plain_ai.png`, and the adventure view puts the root at (1456, 4) so the body starts at y 24, level with the log (visual QA, 2026-10-22).

### 5.3 Log board `24, 852, 440, 204` (4 px shadow)

- `Log` at 42, 866, Yatra 22/28 brass. `Full log · L` right-aligned at 446, top 872, 15/18 tan.
- Up to 5 lines, newest at the bottom. A line of age a (0 = newest) has its top at y = 1014 − 26a. Its bullet goes at (44, top + 4) and its text at x 62, 15/18, max width 384 with an ellipsis.
- **Fading is by colour steps, not opacity:**
  - ages 0–1 use their tone: brass for rewards, cream for hauls, Madra blue for level-ups, tan for system lines;
  - age 2 is tan;
  - ages 3–4 are dim `#94806A`.

  The bullet uses the same tone (`bullet_brass/cream/madra/tan/dim`).

### 5.4 Dock `722, 976, 476, 80` (4 px shadow)

- Buttons are 108x64 at x = 732, 848, 964, 1080, y 984 (2 px shadow).
- Icon 32x32 at (bx + 38, 990): Inventory `inventory_icon.png` at 2x, Abilities `ic_abilities`, Character `ic_character`, Path `ic_star`.
- Label 14/18 cream, centred in the button, top 1024. Hotkey 14/18 tan, right edge bx + 96, top 988.
- **Path notification:**
  - `btn_ring` replaces `btn`;
  - `seal_count` 24x24 at (bx − 6, 978) = (1074, 978), count 15/18 cream centred, top 981.

  It overhangs the button's top-left corner. It clears the P (top right) and the neighbouring C, which ends at x 1060.
- Abilities with unequipped unlocks: `btn_ring` with no seal. Hover: `btn_hover`.

### 5.5 Zone chest `1456, 24, 440, 1032` (4 px shadow)

**Header row (the name board):**
- thumbnail at 1472, 38 (46x52);
- zone name at 1530, 40 (Yatra 30/44 brass);
- About at 1792, 46 (88x36), text 15 cream centred on a 36 line. Use `about_open` while the lore is open. Test Zone has no lore, so no About.

**Now tray** (always drawn; empty while no idle action runs): tray at 1472, 106 (408x88); `Now` plate at 1484, 96 (60x22, 2 px shadow, `Now` 14/22 ink centred); ring at 1486, 122 (56x56); action icon 32x32 at 1498, 134. Text column x 1556, right edge 1864.

| Variant | Line 1 (18/22 cream) | Right of line 1 | Line 2 (15/18) | Progress |
|---|---|---|---|---|
| Aura Well | `Aura Well` at top 118 | `mini_madra` + `+1.5 Madra / s` 16/22 cream, right 1864, top 118 | `Lv 1 → 2 · +1 Spirit` tan at 144, `214 / 300` tan right 1864 | `rod_well` at 1556, 170 |
| Foraging | `Spring Forest Foraging` at top 124 | | `mini_dewdrop` at 1556, 156 + `1–5` at 1578; `mini_fern` at 1616, 156 + `2–6` at 1638 (tan, 15/20, top 154); `haul in 3 s` cream right 1864 | none |
| None (empty tray, user review 2026-10-22) | `Aura Well · paused` (the idle action that resumes) or `Nothing running`, 15/18 tan at 1556, top 142, centred on the ring | | | none; ring at frame 0, no action icon |

**Activities header** (`Activities` Yatra 20/24 brass at 1472, 204; `N here` 15/20 tan right 1880, top 206): a groove runs from the title's end + 12 to the count's start − 18, at y 214, with `groove_end` after it. It stays here when the tray is empty (the y 102 collapse was dropped on 2026-10-22).

**Activity list viewport:** 1472, 232, 408, 808, the tray empty or not. Overflow is hidden. Cards fill x 1472–1864; the rail column is 1868–1880 (12 px), with a 4 px gap.
- **Flow from content y 0:**
  - group label row 18 tall (label 15/18 tan; groove from the label's end + 10 to x 1858 at the row's top + 7, `groove_end` at 1858), then a 6 px gap;
  - cards with 8 px between them, and 14 px between groups.
  - Groups and order follow the spec (Talk, Cultivate, Gather, Venture, Visit; labels in title case as in the swatch).
- **Card internals** (x, y = card top-left):

| Piece | Position | Notes |
|---|---|---|
| Face | `drawer` (72) / `drawer_tall` (96), 2 px shadow (`drawer_tall_ready` unused since 2026-10-22) | Running: `drawer_run` at x−2, y−2 with the 4 px shadow, and all its children shift the same −2, −2 |
| Icon | x+16, y+20, 32x32; y+32 in `drawer_tall` (2026-10-22) | In the carved socket, on the drawer's middle row |
| Title | x+64, y+14 | 17/20 cream, the ready adventure too (its y+26 was dropped on 2026-10-22) |
| NEW | `seal_new_s` at x+64+titleWidth (rounded to even)+10, title top − 1 | `NEW` 13/22 cream centred. Cleared on first hover or use |
| Mode tag | x+304, title top − 1 (y+13), 76x22 | `tag` with tan text, RUNNING in cream; ENTER uses `tag_enter` with ink text |
| Detail | x+64, y+38 | 15/18 tan, max 316 px, ellipsis |
| Foraging detail | `mini_dewdrop` x+64, y+40; `1–5` x+86, y+38; `mini_fern` x+120, y+40; `2–6 · every 5 s · free` x+142, y+38 | 15/18 tan |
| Adventure, below threshold (2026-10-22) | `mini_madra` x+64, y+38; `rod_adv` x+86, y+40; `46 / 60` x+248, y+38 (15/18 tan); hint right-aligned at x+380, top y+38 | Hint: `~10 s` cream, only while a Madra action runs; no hint otherwise. Drawer 72 |
| Adventure, ready (2026-10-22) | `5 min run · carries 120 Madra` at x+64, y+38 | 15/18 brass, with the ENTER tag and a steady `frame_brass` over the 72 px drawer |
| Hover | `frame_hover` 9-slice over the card | |
| Flash | `frame_brass` 9-slice over the card: on 300 ms, off 300 ms, twice (`steps(1)`) | The Now tray flashes the same way, once |

- **Rail** (only when the content is taller than the viewport):
  - `rail_up_*` at 1868, top of the list, and `rail_down_*` at 1868, list bottom − 14;
  - `rail_track` from top + 14 to bottom − 14;
  - the thumb: height = max(32, even(round((L − 28) × L / content))), y = top + 14 + even((L − 28 − h) × scrollTop / (content − L)).
- **Lips:** `lip_top` at (1472, list top) while scrollTop > 2; `lip_bottom` at (1472, list bottom − 10) while there is more below.
- **Empty list:** `Nothing to do here yet.` at 1472, list top + 8 (15/18 tan).
- **Lore popover:** `lore` at x 1472, its top on the Activities header's row (y 206 with the strip, 104 without), 4 px shadow. It covers the header and the first cards. Text 16/22 cream at x 1494, width 364, from top + 18, with 10 px between paragraphs.

## 6. Map at zoom 2

### 6.1 Geometry

Pointy-top, odd-r offset (odd rows, negative ones too, sit half a hex right). Tiles are 164x190 native, shown 328x380.

- centre(col, row) = (960 + 328·col + (row odd ? 164 : 0), 702 + 285·row)
- tile top-left = centre − (164, 190)
- hex distance = the mock's `hexDistance` (convert to cube and take the max of |dx|, |dz|, |dx + dz|).

The row step 285 is 142.5 art px, so **odd rows land on odd y** (227, 797, −343) and sit 1 screen px off the even rows' grid. Each tile stays crisp, and this is unavoidable with a 285 step. Don't "fix" it.

| Zone | Cell | Centre | Tile top-left | Art | Brackets top-left |
|---|---|---|---|---|---|
| Spirit Valley (current) | (0, 0) | 960, 702 | 796, 512 | `Hex_Forest_06_River.png` at 2x + `hex_current` | 776, 492 |
| Test Zone (open-zone demo) | (−1, 0) | 632, 702 | 468, 512 | `Hex_Forest_00_Basic.png` at 2x + `hex_open` (or `hex_current` once you are there) | 448, 492 |
| Advancement Zone (locked demo) | (0, −1) | 1124, 417 | 960, 227 | `tile_locked` / `tile_locked_hover` | 940, 207 |
| Uncharted (locked demo) | (0, −2) | 960, 132 | 796, −58 | `tile_uncharted` / `_hover` + `glimmer_strip` | 776, −78 |

**Draw order (back to front):**
1. fog background;
2. uncharted tile and glimmer;
3. locked tile;
4. Spirit Valley;
5. Test Zone;
6. `hex_open`;
7. `hex_current`;
8. route dots;
9. character shadow, character, map ring, floater;
10. lock and `?` glyphs;
11. plates;
12. brackets;
13. map popovers.

The left and right panels and the dock go over the map.

### 6.2 Fog cells

Thirty-two cells touch the screen. Tier = hex distance to the nearest **charted** zone, capped at 3. Charted zones are Spirit Valley, Test Zone (open demo) and the Advancement Zone (locked demo). The uncharted hex is a zone tile but charts nothing. This rule reproduces the mock's hand-placed tiers for the locked demo exactly. "−" means the cell is a zone tile in that state. The full-screen `lacquer_fog_<state>_ai.png` files already contain all of this.

| Cell | Tile top-left | Art | base | open | locked | both |
|---|---|---|---|---|---|---|
| (−3,−3) | −24, −343 | 00_Basic | 3 | 3 | 3 | 3 |
| (−2,−3) | 304, −343 | 00_Basic | 3 | 3 | 3 | 3 |
| (−1,−3) | 632, −343 | 09_Clearing1 | 3 | 3 | 2 | 2 |
| (0,−3) | 960, −343 | 00_Basic | 3 | 3 | 2 | 2 |
| (1,−3) | 1288, −343 | 18_Hole | 3 | 3 | 2 | 2 |
| (2,−3) | 1616, −343 | 00_Basic | 3 | 3 | 3 | 3 |
| (−3,−2) | −188, −58 | 00_Basic | 3 | 3 | 3 | 3 |
| (−2,−2) | 140, −58 | 00_Basic | 3 | 2 | 3 | 2 |
| (−1,−2) | 468, −58 | 21_Ravine | 2 | 2 | 2 | 2 |
| (0,−2) | 796, −58 | 11_Lake1 | 2 | 2 | − | − |
| (1,−2) | 1124, −58 | 07_Mountains1 | 2 | 2 | 1 | 1 |
| (2,−2) | 1452, −58 | 00_Basic | 3 | 3 | 2 | 2 |
| (3,−2) | 1780, −58 | 00_Basic | 3 | 3 | 3 | 3 |
| (−3,−1) | −24, 227 | 00_Basic | 3 | 2 | 3 | 2 |
| (−2,−1) | 304, 227 | 12_Lake2 | 2 | 1 | 2 | 1 |
| (−1,−1) | 632, 227 | 00_Basic | 1 | 1 | 1 | 1 |
| (0,−1) | 960, 227 | 00_Basic | 1 | 1 | − | − |
| (1,−1) | 1288, 227 | 19_Dead | 2 | 2 | 1 | 1 |
| (2,−1) | 1616, 227 | 00_Basic | 3 | 3 | 2 | 2 |
| (−3,0) | −188, 512 | 00_Basic | 3 | 2 | 3 | 2 |
| (−2,0) | 140, 512 | 00_Basic | 2 | 1 | 2 | 1 |
| (−1,0) | 468, 512 | 11_Lake1 | 1 | − | 1 | − |
| (0,0) | 796, 512 | — | − | − | − | − |
| (1,0) | 1124, 512 | 21_Ravine | 1 | 1 | 1 | 1 |
| (2,0) | 1452, 512 | 09_Clearing1 | 2 | 2 | 2 | 2 |
| (3,0) | 1780, 512 | 00_Basic | 3 | 3 | 3 | 3 |
| (−3,1) | −24, 797 | 00_Basic | 3 | 2 | 3 | 2 |
| (−2,1) | 304, 797 | 22_Cave | 2 | 1 | 2 | 1 |
| (−1,1) | 632, 797 | 00_Basic | 1 | 1 | 1 | 1 |
| (0,1) | 960, 797 | 12_Lake2 | 1 | 1 | 1 | 1 |
| (1,1) | 1288, 797 | 00_Basic | 2 | 2 | 2 | 2 |
| (2,1) | 1616, 797 | 00_Basic | 3 | 3 | 3 | 3 |

The fog art is hand-placed from the spec's natural-only pool (Basic, Mountains1, Clearing1, Lake1, Lake2, Hole, Dead, Ravine, Cave). Every other cell is Basic. The pixel classes come from luminance: < 70 line, < 128 shade, < 158 base, otherwise light. Tier 1 keeps the land readable, tier 2 is an etched silhouette and tier 3 a flat silhouette. The grout between hexes is the ground colour.

### 6.3 Character, ring, floaters

| Piece | In Spirit Valley | In Test Zone | Notes |
|---|---|---|---|
| Character 32x48 (frame 20 at 2x) | 992, 720 | 664, 720 | Stands on the grass below the river. The swatch drew it at 2x on the one grid. Walk: translate x by ∓328 over 0.6 s, `steps(164)` |
| `char_shadow` | 994, 762 | 666, 762 | |
| Map ring (60x60 frame) | 1036, 712 | | Action icon 32x32 at 1050, 726. Same frame stepping as the Now ring. Hidden when nothing runs |
| Floater | centred on x 1008, top 686 → 646 | | `+1.5 Madra` (Madra blue) each Well tick: rises 40 px in 1 s with `steps(20)`, then is hidden at once. Foraging: the haul text (`+3 Dewdrop Tear  +4 Spirit Fern`, cream) once per haul |

### 6.4 Glyphs

- `glyph_lock` at 1102, 356 (its hex is at 1124, 417). The existing 0.44 s shake becomes translateX keyframes 0, −8, 8, −6, 4, 0 (even px, `steps(1)` between keys).
- `glyph_unknown` at 946, 92.

### 6.5 Plates (248x52, 2 px shadow)

| Plate | Top-left | Texture | Line 1 (16/18, top + 6, centred) | Line 2 (14/18, top + 26, centred) |
|---|---|---|---|---|
| Spirit Valley, current | 836, 800 | `plate_current` (hover: `_hover`) | brass; cream on hover | `mini_well` + `Aura Well · +1.5 Madra / s` or `mini_forage` + `Foraging · a haul every 5 s`, cream. Icon at top + 28, 6 px before the text, centred as a group. With nothing running: name only, centred at top + 17 |
| Spirit Valley, from Test Zone | 836, 800 | `plate_open` / `_hover` | cream | `Open · 5 activities` tan; on hover `Click to travel` brass |
| Test Zone | 508, 800 | `plate_open` / `_hover` (or `plate_current` once you are there) | cream | `Open · nothing to do yet` tan; on hover `Click to travel` brass |
| Advancement Zone | 1000, 428 | `plate_locked` / `_hover`; pinned: + `frame_brass` overlay | cream | `mini_swords` + `Tribulation Guardian`, cream |
| Uncharted | 836, 150 | `plate_uncharted` / `_hover`; pinned: + `frame_brass` | tan; cream on hover | `After the Tribulation` tan |

Clicking a plate does what clicking its hex does.

### 6.6 Popovers

Only one popover is open at a time; the spec's close rules apply.

**Locked (Advancement Zone).** Placed **left** of the hex: the right side would run into the zone chest at zoom 2.
- **Pinned:** `pop_locked` at (684, 331), 272x172, 4 px shadow; the notch tip at x 956 points at the hex's left side.
- **Preview** (after the 150 ms hover delay): `pop_locked_preview` at (684, 351).
- **Contents** (X = 684, Y = top):
  - `seal_locked` at X+16, Y+14, with `mini_lock` at X+24, Y+17 and `LOCKED` 13/22 cream at X+42;
  - pinned only: `close` at X+220, Y+12;
  - title `Advancement Zone` 18/22 cream at X+16, Y+46;
  - `Defeat the Tribulation Guardian` / `in The Shallow Woods`, 15/20 cream at Y+74 and Y+94 (wrap width 232);
  - pinned only: `showme` at X+16, Y+124 (2 px shadow), with `Show me` 14 cream and `chev` 6 px after it, centred together. It appears only when the requirement names a card in this zone.

**Uncharted.** Placed **right** of the hex.
- `pop_uncharted` (pinned) or `pop_uncharted_preview` at (1128, 76), 272x112; the card starts at X+8, after the notch.
- **Contents:**
  - `tag_wide` at X+24, Y+14 with `UNKNOWN` 13/22 tan centred;
  - pinned only: `close` at X+228, Y+12;
  - `Uncharted` 18/22 cream at X+24, Y+46;
  - `Revealed after the Tribulation.` 15/20 cream at X+24, Y+74.

**Brackets:**
- Hover: `bracket_hover` on the hovered hex: locked, uncharted, or an open hex you can travel to.
- Pinned: `bracket_pinned` on the pinned hex. A hex shows only one of the two.

### 6.7 Routes (dot top-left positions, every 24 px)

**North** (locked demo: Valley → Advancement → Uncharted), always `route_dot`, never lit:
968,678 980,656 992,636 1004,614 1016,594 1028,574 1040,552 1052,532 1064,510 1076,490 1088,470 1100,448 1112,428 1108,392 1096,372 1084,350 1072,330 1060,308 1048,288 1036,268 1024,246 1012,226 1000,204 988,184 976,164 964,142

**West** (open demo: Valley → Test Zone), `route_dot`, or `route_dot_lit` while the Test Zone is hovered and you can travel:
932,698 908,698 884,698 860,698 836,698 812,698 788,698 764,698 740,698 716,698 692,698 668,698 644,698

Dots under a plate are hidden by it, which is fine.

## 7. Changes from the spec and the mock (the look's own needs)

| Item | Spec / mock | Kit | Why |
|---|---|---|---|
| Map zoom | 1.5, tiles 246x285 | 2, tiles 328x380, nearest | 1.5 blurs the ink tiles (all three swatch designers' call) |
| Goals | 24, 292, w 440, height hugs (about 216) | Image 24, 272, 440, 220, board body 200, hung on cords from the cabinet | One hand-drawn board. Fresh-save figure on the name row |
| Now strip | 1472, 104, 408, 84 | 1472, 106, 408, 88 | The tray's carved lip |
| Activities header | 20 tall, ACTIVITIES label | 24 tall, `Activities` in Yatra brass | Reads as the chest's section title over the tan group labels |
| Cards | 396 wide (4 px rail), 72 / 88 tall | 392 wide + 4 gap + 12 px brass rail, 72 / 96 tall | A brass rail needs 6 art px. 96 fits the adventure's three lines on the grid. The 9-card list scrolls by 72 px (880 in an 808 viewport), close to the mock |
| Edge fade (24 px gradient) | gradient | `lip_top` / `lip_bottom` dither and lit rail caps | No gradients |
| Mode tags | rounded pills | carved recess, brass ENTER plate, cinnabar NEW chop | No uniform pills |
| NEW | pill next to the title | `seal_new_s` inline after the title | Same place, as a chop |
| Running card | tint, glow, RUNNING tag | pulled-out drawer (−2, −2, 4 px shadow), brass caps, RUNNING in cream | No tints or glows |
| Action tints (lilac Well, green foraging) | strip, card and ring tints | dropped; the icon identifies the action and every timer ring is jade | Jade only for progress; small palette |
| Lore popover | 408 wide, height hugs | 408x264 fixed | Fixed lacquer panel; fits the Spirit Valley text |
| Map plates | 248 / 232 / 196 / 182 wide | all 248x52 | One plate size for every state |
| Locked popover | right of the hex | left of the hex | At zoom 2 the right side hits the zone chest |
| Map popovers | 216–228 wide | 264 card + 8 notch | The requirement fits on two lines at 15 px |
| Hex states | teal aura, teal / gold brackets, red dashed outline, blur veil | lacquer collar + brass rim, light / heavy brass brackets, vermilion dashes, palette veils | No glow, no teal, no blur |
| Glimmer | translucent sweeping band | 9-frame lighter band, stepped | No translucency |
| Mists, motes, Well wisps, globe shade | present | dropped | Glow and gradient effects |
| Floaters | fade | hard show and hide, 2 px steps | No fades |
| Character | 4x at 1.5 zoom | 2x (32x48) on the 2x grid, as the swatch | One pixel grid |
| Dock icons | user's Abilities and Character icons | redrawn 16 px `ic_abilities`, `ic_character` | The user's are 32 art px: off-grid at 32 px |

## 8. Mock states and what changes

| Mock control | Map | Panels |
|---|---|---|
| state=well | Map ring and Madra floaters; plate line with `mini_well` | Now tray, Well variant; `+1.5 / s` on the cabinet; Aura Well card pulled out |
| state=forage | Map ring (5 s), haul floater; plate line with `mini_forage` | Now tray, foraging variant; no rate on the cabinet; foraging card pulled out |
| state=fresh | No ring or floater; plate name only | Empty Now tray, `Nothing running` (header at 204, list at 232; the mock's collapse to 102 and 132 was dropped on 2026-10-22); Madra 25 / 100; core frame 0; beads 3 / 10; quest `Awaken Your Core` with `25 / 100`; log 2 lines; only the Cycling card |
| list=9 | | Talk group first; the list scrolls; rail, caps and lips show |
| demo=1 | `fog_open`; Test Zone tile + `hex_open` + plate; west route | Travelling there: `hex_current` moves, the panel shows Test Zone (`thumb_basic`, no About, the empty tray reading `Nothing running`, `0 here`, empty list), and the Valley plate becomes `plate_open` |
| locked=1 | `fog_locked` (or `fog_both`); the two veiled tiles, glyphs, plates, north route | |
| popover / hover | Brackets, popovers, plate hover versions; pinned plates get the brass frame | "Show me ›" scrolls to The Shallow Woods card and flashes it |
| lore=1 | | `lore` over the header and first cards; `about_open` |

## 9. Every file in the kit, and where it lives in the project

| File | Kit px | In the project |
|---|---|---|
| `BMEULJIROTTF.ttf` | font | user file: `assets/fonts/BMEULJIROTTF.ttf` |
| `character_icon.png` | 64x64 | user file, used from its own path in `assets/sprites/` |
| `combat_icon.png` | 64x64 | user file, used from its own path in `assets/sprites/` |
| `gold_icon.png` | 64x64 | user file, used from its own path in `assets/sprites/` |
| `Hex_Forest_00_Basic.png` | 164x190 | user file, used from its own path in `assets/sprites/` |
| `Hex_Forest_06_River.png` | 164x190 | user file, used from its own path in `assets/sprites/` |
| `ic_cycle_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_cycle_ai.png` (show at 2x) |
| `ic_dewdrop_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_dewdrop_ai.png` (show at 2x) |
| `ic_fern_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_fern_ai.png` (show at 2x) |
| `ic_forage_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_forage_ai.png` (show at 2x) |
| `ic_merchant_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_merchant_ai.png` (show at 2x) |
| `ic_story_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_story_ai.png` (show at 2x) |
| `ic_well_ai.png` | 16x16 | `assets/ui/lacquer/icons/ic_well_ai.png` (show at 2x) |
| `inventory_icon.png` | 16x16 | user file, used from its own path in `assets/sprites/` |
| `lacquer_about_ai.png` | 88x36 | `assets/ui/lacquer/lacquer_about_ai.png`, 90x38 with its shadow baked in |
| `lacquer_about_open_ai.png` | 88x36 | `assets/ui/lacquer/lacquer_about_open_ai.png` |
| `lacquer_beads_xp_strip_ai.png` | 222x228 | `assets/ui/lacquer/lacquer_beads_xp_strip_ai.png` |
| `lacquer_btn_ai.png` | 108x64 | `assets/ui/lacquer/lacquer_btn_ai.png`, 110x66 with its shadow baked in |
| `lacquer_btn_hover_ai.png` | 108x64 | `assets/ui/lacquer/lacquer_btn_hover_ai.png`, 110x66 with its shadow baked in |
| `lacquer_btn_ring_ai.png` | 108x64 | `assets/ui/lacquer/lacquer_btn_ring_ai.png`, 110x66 with its shadow baked in |
| `lacquer_bullet_brass_ai.png` | 10x10 | `assets/ui/lacquer/lacquer_bullet_brass_ai.png` |
| `lacquer_bullet_cream_ai.png` | 10x10 | `assets/ui/lacquer/lacquer_bullet_cream_ai.png` |
| `lacquer_bullet_dim_ai.png` | 10x10 | `assets/ui/lacquer/lacquer_bullet_dim_ai.png` |
| `lacquer_bullet_madra_ai.png` | 10x10 | `assets/ui/lacquer/lacquer_bullet_madra_ai.png` |
| `lacquer_bullet_tan_ai.png` | 10x10 | `assets/ui/lacquer/lacquer_bullet_tan_ai.png` |
| `lacquer_char_shadow_ai.png` | 28x6 | `assets/ui/lacquer/map/lacquer_char_shadow_ai.png`, halved to 14x3 (map space) |
| `lacquer_chest_bot_ai.png` | 440x48 | `assets/ui/lacquer/lacquer_chest_bot_ai.png`, 444x52 with its shadow baked in |
| `lacquer_chest_mid_ai.png` | 440x128 | `assets/ui/lacquer/lacquer_chest_mid_ai.png`, 444x128 with its shadow baked in |
| `lacquer_chest_top_ai.png` | 440x128 | `assets/ui/lacquer/lacquer_chest_top_ai.png`, 444x128 with its shadow baked in |
| `lacquer_chev_ai.png` | 10x14 | `assets/ui/lacquer/lacquer_chev_ai.png` |
| `lacquer_close_ai.png` | 28x28 | `assets/ui/lacquer/lacquer_close_ai.png` |
| `lacquer_close_hover_ai.png` | 28x28 | `assets/ui/lacquer/lacquer_close_hover_ai.png` |
| `lacquer_cult_ai.png` | 440x252 | `assets/ui/lacquer/lacquer_cult_ai.png`, 444x256 with its shadow baked in |
| `lacquer_dock_ai.png` | 476x80 | `assets/ui/lacquer/lacquer_dock_ai.png`, 480x84 with its shadow baked in |
| `lacquer_drawer_ai.png` | 392x72 | `assets/ui/lacquer/lacquer_drawer_ai.png`, 394x74 with its shadow baked in |
| `lacquer_drawer_run_ai.png` | 392x72 | `assets/ui/lacquer/lacquer_drawer_run_ai.png`, 396x76 with its shadow baked in |
| `lacquer_drawer_tall_ai.png` | 392x96 | `assets/ui/lacquer/lacquer_drawer_tall_ai.png`, 394x98 with its shadow baked in |
| `lacquer_drawer_tall_ready_ai.png` | 392x96 | `assets/ui/lacquer/lacquer_drawer_tall_ready_ai.png`, 394x98 with its shadow baked in |
| `lacquer_fog_base_ai.png` | 1920x1080 | mock only (full-screen fog for one demo state); not in the project |
| `lacquer_fog_both_ai.png` | 1920x1080 | mock only (full-screen fog for one demo state); not in the project |
| `lacquer_fog_locked_ai.png` | 1920x1080 | mock only (full-screen fog for one demo state); not in the project |
| `lacquer_fog_open_ai.png` | 1920x1080 | mock only (full-screen fog for one demo state); not in the project |
| `lacquer_fog_t1_atlas_ai.png` | 2952x380 | `assets/ui/lacquer/map/lacquer_fog_t1_atlas_ai.png`, halved to 1476x190 (map space) |
| `lacquer_fog_t2_atlas_ai.png` | 2952x380 | `assets/ui/lacquer/map/lacquer_fog_t2_atlas_ai.png`, halved to 1476x190 (map space) |
| `lacquer_fog_t3_atlas_ai.png` | 2952x380 | `assets/ui/lacquer/map/lacquer_fog_t3_atlas_ai.png`, halved to 1476x190 (map space) |
| `lacquer_frame_brass_ai.png` | 24x24 | `assets/ui/lacquer/lacquer_frame_brass_ai.png` |
| `lacquer_frame_hover_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_frame_hover_ai.png` |
| `lacquer_glyph_lock_ai.png` | 44x52 | `assets/ui/lacquer/lacquer_glyph_lock_ai.png` |
| `lacquer_glyph_twinkle_strip_ai.png` | 42x14 | `assets/ui/lacquer/lacquer_glyph_twinkle_strip_ai.png` |
| `lacquer_glyph_unknown_ai.png` | 28x36 | `assets/ui/lacquer/lacquer_glyph_unknown_ai.png` |
| `lacquer_goals_ai.png` | 440x220 | `assets/ui/lacquer/lacquer_goals_ai.png`, 444x224 with its shadow baked in |
| `lacquer_goals_cords_ai.png` | 440x24 | `assets/ui/lacquer/lacquer_goals_cords_ai.png`, 444x24: the Goals board's two cords, rows 0–20 of `lacquer_goals_ai.png` with one more brass twist on top, placed 4 px above the board's root (user review, 2026-10-22) |
| `lacquer_goals_top_plain_ai.png` | 440x66 | `assets/ui/lacquer/lacquer_goals_top_plain_ai.png`, 444x66: the Goals top slice (rows 20–86 of `lacquer_goals_ai.png`) with the cords' two brass hooks painted out, for the adventure view (visual QA, 2026-10-22) |
| `lacquer_groove_ai.png` | 4x6 | `assets/ui/lacquer/lacquer_groove_ai.png` |
| `lacquer_groove_end_ai.png` | 6x6 | `assets/ui/lacquer/lacquer_groove_end_ai.png` |
| `lacquer_hex_current_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_hex_current_ai.png`, halved to 164x190 (map space) |
| `lacquer_hex_hover_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_hex_hover_ai.png`, halved to 164x190 (map space) |
| `lacquer_hex_hover_in_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_hex_hover_in_ai.png`, halved to 164x190 (map space) |
| `lacquer_hex_open_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_hex_open_ai.png`, halved to 164x190 (map space) |
| `lacquer_hex_pinned_in_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_hex_pinned_in_ai.png`, halved to 164x190 (map space) |
| `lacquer_ic_abilities_ai.png` | 32x32 | `assets/ui/lacquer/lacquer_ic_abilities_ai.png` |
| `lacquer_ic_core_ai.png` | 32x32 | `assets/ui/lacquer/lacquer_ic_core_ai.png` |
| `lacquer_line_ai.png` | 408x6 | `assets/ui/lacquer/lacquer_line_ai.png` |
| `lacquer_lip_bottom_ai.png` | 392x10 | `assets/ui/lacquer/lacquer_lip_bottom_ai.png` |
| `lacquer_lip_top_ai.png` | 392x10 | `assets/ui/lacquer/lacquer_lip_top_ai.png` |
| `lacquer_log1_ai.png` | 440x100 | `assets/ui/lacquer/lacquer_log1_ai.png`, 444x104 with its shadow baked in |
| `lacquer_log2_ai.png` | 440x126 | `assets/ui/lacquer/lacquer_log2_ai.png`, 444x130 with its shadow baked in |
| `lacquer_log3_ai.png` | 440x152 | `assets/ui/lacquer/lacquer_log3_ai.png`, 444x156 with its shadow baked in |
| `lacquer_log4_ai.png` | 440x178 | `assets/ui/lacquer/lacquer_log4_ai.png`, 444x182 with its shadow baked in |
| `lacquer_log5_ai.png` | 440x204 | `assets/ui/lacquer/lacquer_log5_ai.png`, 444x208 with its shadow baked in |
| `lacquer_lore_ai.png` | 408x264 | `assets/ui/lacquer/lacquer_lore_ai.png`, 412x268 with its shadow baked in |
| `lacquer_madra_pellet_ai.png` | 12x12 | `assets/ui/lacquer/lacquer_madra_pellet_ai.png`: one pellet of the Madra drain before an adventure (6x6 art px, Madra ramp in an ink outline, no shadow), moved in 2 px steps (visual QA, 2026-10-22) |
| `lacquer_map_ring_strip_ai.png` | 832x64 | `assets/ui/lacquer/lacquer_map_ring_strip_ai.png` |
| `lacquer_mini_dewdrop_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_dewdrop_ai.png` |
| `lacquer_mini_fern_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_fern_ai.png` |
| `lacquer_mini_forage_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_forage_ai.png` |
| `lacquer_mini_lock_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_lock_ai.png` |
| `lacquer_mini_madra_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_madra_ai.png` |
| `lacquer_mini_swords_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_swords_ai.png` |
| `lacquer_mini_well_ai.png` | 16x16 | `assets/ui/lacquer/lacquer_mini_well_ai.png` |
| `lacquer_now_plate_ai.png` | 60x22 | `assets/ui/lacquer/lacquer_now_plate_ai.png`, 62x24 with its shadow baked in |
| `lacquer_now_tray_ai.png` | 408x88 | `assets/ui/lacquer/lacquer_now_tray_ai.png` |
| `lacquer_orb_core_strip_ai.png` | 1360x320 | `assets/ui/lacquer/lacquer_orb_core_strip_ai.png` |
| `lacquer_orb_madra_strip_ai.png` | 2640x80 | `assets/ui/lacquer/lacquer_orb_madra_strip_ai.png` |
| `lacquer_plate_current_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_current_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_current_hover_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_current_hover_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_locked_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_locked_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_locked_hover_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_locked_hover_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_open_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_open_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_open_hover_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_open_hover_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_uncharted_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_uncharted_ai.png`, 250x54 with its shadow baked in |
| `lacquer_plate_uncharted_hover_ai.png` | 248x52 | `assets/ui/lacquer/lacquer_plate_uncharted_hover_ai.png`, 250x54 with its shadow baked in |
| `lacquer_pop_locked_ai.png` | 272x172 | `assets/ui/lacquer/lacquer_pop_locked_ai.png`, 276x176 with its shadow baked in |
| `lacquer_pop_locked_preview_ai.png` | 272x132 | `assets/ui/lacquer/lacquer_pop_locked_preview_ai.png`, 276x136 with its shadow baked in |
| `lacquer_pop_uncharted_ai.png` | 272x112 | `assets/ui/lacquer/lacquer_pop_uncharted_ai.png`, 276x116 with its shadow baked in |
| `lacquer_pop_uncharted_preview_ai.png` | 272x112 | `assets/ui/lacquer/lacquer_pop_uncharted_preview_ai.png`, 276x116 with its shadow baked in |
| `lacquer_rail_down_off_ai.png` | 12x14 | `assets/ui/lacquer/lacquer_rail_down_off_ai.png` |
| `lacquer_rail_down_on_ai.png` | 12x14 | `assets/ui/lacquer/lacquer_rail_down_on_ai.png` |
| `lacquer_rail_thumb_ai.png` | 12x12 | `assets/ui/lacquer/lacquer_rail_thumb_ai.png` |
| `lacquer_rail_track_ai.png` | 12x4 | `assets/ui/lacquer/lacquer_rail_track_ai.png` |
| `lacquer_rail_up_off_ai.png` | 12x14 | `assets/ui/lacquer/lacquer_rail_up_off_ai.png` |
| `lacquer_rail_up_on_ai.png` | 12x14 | `assets/ui/lacquer/lacquer_rail_up_on_ai.png` |
| `lacquer_ring_strip_ai.png` | 728x56 | `assets/ui/lacquer/lacquer_ring_strip_ai.png` |
| `lacquer_rod_adv_empty_ai.png` | 152x10 | `assets/ui/lacquer/lacquer_rod_adv_empty_ai.png` |
| `lacquer_rod_adv_end_ai.png` | 2x10 | `assets/ui/lacquer/lacquer_rod_adv_end_ai.png` |
| `lacquer_rod_adv_full_ai.png` | 152x10 | `assets/ui/lacquer/lacquer_rod_adv_full_ai.png` |
| `lacquer_rod_goal_empty_ai.png` | 280x10 | `assets/ui/lacquer/lacquer_rod_goal_empty_ai.png` |
| `lacquer_rod_goal_end_ai.png` | 2x10 | `assets/ui/lacquer/lacquer_rod_goal_end_ai.png` |
| `lacquer_rod_goal_full_ai.png` | 280x10 | `assets/ui/lacquer/lacquer_rod_goal_full_ai.png` |
| `lacquer_rod_well_empty_ai.png` | 308x10 | `assets/ui/lacquer/lacquer_rod_well_empty_ai.png` |
| `lacquer_rod_well_end_ai.png` | 2x10 | `assets/ui/lacquer/lacquer_rod_well_end_ai.png` |
| `lacquer_rod_well_full_ai.png` | 308x10 | `assets/ui/lacquer/lacquer_rod_well_full_ai.png` |
| `lacquer_route_dot_ai.png` | 8x8 | `assets/ui/lacquer/map/lacquer_route_dot_ai.png`, halved to 4x4 (map space) |
| `lacquer_route_dot_lit_ai.png` | 8x8 | `assets/ui/lacquer/map/lacquer_route_dot_lit_ai.png`, halved to 4x4 (map space) |
| `lacquer_seal_count_ai.png` | 24x24 | `assets/ui/lacquer/lacquer_seal_count_ai.png` |
| `lacquer_seal_locked_ai.png` | 88x22 | `assets/ui/lacquer/lacquer_seal_locked_ai.png` |
| `lacquer_seal_new_s_ai.png` | 44x22 | `assets/ui/lacquer/lacquer_seal_new_s_ai.png` |
| `lacquer_showme_ai.png` | 104x32 | `assets/ui/lacquer/lacquer_showme_ai.png`, 106x34 with its shadow baked in |
| `lacquer_tag_ai.png` | 76x22 | `assets/ui/lacquer/lacquer_tag_ai.png` |
| `lacquer_tag_enter_ai.png` | 76x22 | `assets/ui/lacquer/lacquer_tag_enter_ai.png` |
| `lacquer_tag_wide_ai.png` | 88x22 | `assets/ui/lacquer/lacquer_tag_wide_ai.png` |
| `lacquer_thumb_ai.png` | 46x52 | `assets/ui/lacquer/lacquer_thumb_ai.png` |
| `lacquer_thumb_basic_ai.png` | 46x52 | `assets/ui/lacquer/lacquer_thumb_basic_ai.png` |
| `lacquer_tile_locked_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_tile_locked_ai.png`, halved to 164x190 (map space) |
| `lacquer_tile_locked_hover_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_tile_locked_hover_ai.png`, halved to 164x190 (map space) |
| `lacquer_tile_uncharted_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_tile_uncharted_ai.png`, halved to 164x190 (map space) |
| `lacquer_tile_uncharted_hover_ai.png` | 328x380 | `assets/ui/lacquer/map/lacquer_tile_uncharted_hover_ai.png`, halved to 164x190 (map space) |
| `lacquer_token_ai.png` | 24x24 | `assets/ui/lacquer/lacquer_token_ai.png`, 26x26 with its shadow baked in |
| `main_character_spritesheet.png` | 128x288 | user file, used from its own path in `assets/sprites/` |
| `star_icon.png` | 64x64 | user file, used from its own path in `assets/sprites/` |
| `YatraOne-Regular.ttf` | font | user file: `assets/fonts/YatraOne-Regular.ttf` |

## 10. Reference renders and calls made without the user

- **Reference renders:** the mock-up itself (open it in a browser from the repo); the revision-1 PIL check renders were not kept.
- **Calls made in the kit (not ruled on by the user):**
  - character at 2x;
  - Activities header in Yatra;
  - 72 / 96 cards;
  - the locked popover on the left;
  - jade timer rings for every action, with the action tints dropped;
  - fog tier 2 drawn as an etched silhouette;
  - the decimal point in Yatra;
  - one fixed goals-board height.
