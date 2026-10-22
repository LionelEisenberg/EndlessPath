# Menu Books: one book shell for Inventory, Abilities, Character and Path

Date: 2026-10-21
Status: Built on `feat/inventory-panel-consistency-8ebbee` (2026-10-21), then revised the same day after a first review (see [First review](#first-review-2026-10-21)). For current behaviour read [MAIN_VIEW.md](../../infrastructure/MAIN_VIEW.md#menu-books) and the per-menu docs. One addition while building: the path tree sits on a dark inset inside its card, because its node art was drawn for a dark panel.

## Intent

The four bottom-row menus (Inventory, Abilities, Character, Path) each look and open differently today:

| Menu | Frame | Size on screen | Opens with |
|---|---|---|---|
| Inventory | Book art | ~1210x816 | Book animation; the backdrop appears instantly |
| Character | Flat brown box, muted border | ~820x500 | Fade |
| Abilities, Path | Flat brown box, gold border, shadow | 1680x920 | Fade and slight zoom |

The player should meet one kind of window for one kind of thing. Every bottom-row menu becomes a book built from the inventory's book, with the same frame, animations, chrome and page language, and a small per-book identity so the player can tell them apart at a glance.

This is the first half of a wider consistency pass. Zone actions that open a pop-up (merchant, cycling, the adventure end card) are the second family and get their own project later. The working rule for that later project is "menus are books, action pop-ups are scrolls"; it is noted here, not built.

## Goals

- All four menus are books built from one shared book scene. They share the frame art, the open and close animation, the page-turn animation, the title ribbon, the side tabs (when a book has sections), the close tab and the bookmark.
- Each book has its own colour: the cover edge, the page border line and the bookmark take the book's colour. The title ribbon names the menu.
- One reading rule on every book: the **left page holds what you have**; the **right page holds what you're using, plus details of whatever you point at**. The inventory already works this way.
- No text sits on bare page. Every block of content sits on one of the inventory's own pieces of art: a card, a row bar, a slot, a header plaque or a dark pill.
- All four open and close the same way: the grey backdrop fades in while the book opens, and fades out while it closes. Esc, the menu's own key and the close tab all close it.
- The path book holds the cultivation stages as chapters: side tabs for Foundation, Copper, Iron and Jade.

## Non-goals

- Zone-action pop-ups (merchant, cycling, end card, dialogue).
- Copper, Iron and Jade path content. Only their locked chapter tabs are built.
- New menu features. Each menu keeps what it lets you do today; only the abilities equip gestures change (see Abilities below).
- Switching straight from one book to another. As today, you close one book to open the next, and the menu keys only work from the zone map.
- Fixing the separate bug where the backdrop stops dimming behind Cycling and the end card after a faded panel closes (`docs/infrastructure/MAIN_VIEW.md`, Work Remaining). The inventory stops being affected because it moves to the fade path; the other two are a follow-up.

## Anti-goals

- The inventory losing any of its current behaviour or polish. Its existing tests must keep passing unchanged.
- Cramped or illegible pages. Text keeps its current theme sizes at native resolution; it is never pixel-scaled.
- Pixel art drawn at a different pixel density from the book.
- Four copies of the book scene drifting apart again.

## The shell (shared by all four books)

### What every book has

- **Frame and animations.** The inventory's book spritesheets and timings: `book_opening_spritesheet.png` (open = the close animation played backwards, 0.3 s) and `page_turning_spritesheet.png` (0.54 s, forwards or backwards by direction of travel).
- **Per-book colour.** One master book PNG, recoloured in-engine by a palette-swap shader. The master's cover edge uses three colours, `(162,112,100)`, `(128,72,69)` and `(101,51,60)`. The page border line uses one colour, `(230,201,169)`, which in the book sheet appears only in that line and its corner ornaments, on the fully open frame. Swapping those four colours gives each book its cover and border colour with no new book art. The same colour is also on the turning page (frames 1 to 4 of `page_turning_spritesheet.png`), so the page-turn sprite takes the same swap. The same shader recolours the bookmark. The inventory's side-tab art also uses the border colour on its page edge; the tabs stay as drawn.
- **Title ribbon.** The inventory's `TabBanner` (`scenes/inventory/common/tab_banner/`), top of the left page, same position as the inventory's. It names the menu: "Abilities", "Character", "Path". The inventory's ribbon keeps naming its open tab ("Equipment", "Materials", and so on), because each of its tabs is its own page.
- **Close tab.** The inventory's side-tab art (`tab_button_open.png`, frame 0) rotated to stand up from the **top edge of the right page**, near the right corner, with a pixel-art X. It sits behind the book art so only the part above the book shows. Clicking it closes the book exactly like Esc. Same tab on all four books.
- **Bookmark.** A pixel-art ribbon drawn at the book art's own resolution (the book sheet uses 2x2 blocks). It comes out from under the top page's bottom outline and lies over the page-stack edges below it, so it reads as tucked between the top page and the pages beneath. It has a satin highlight stripe and a forked (swallowtail) end, in the book's colour.
- **Side tabs**, only when a book has sections: the inventory's four categories and the path book's four stages. The inventory's tab buttons, page turn on switch.

The bookmark, the coloured page border and the close tab only exist on the fully open book: the closing frames have no border colour, and the bookmark and close tab are hidden while the book animates.

### Per-book colours (placeholders, tunable as data)

| Book | Cover edge | Page border and bookmark |
|---|---|---|
| Inventory | unchanged maroon | red |
| Abilities | jade | jade |
| Character | indigo | indigo |
| Path | ink | gold |

The mockup values (RGB) are a starting point:

| Book | Cover light / mid / dark | Border | Bookmark dark / mid / light |
|---|---|---|---|
| Inventory | 162,112,100 / 128,72,69 / 101,51,60 | 176,92,84 | 112,34,38 / 160,50,50 / 206,92,84 |
| Abilities | 98,152,128 / 62,112,96 / 42,80,72 | 76,146,120 | 30,94,74 / 50,136,106 / 104,186,148 |
| Character | 112,120,172 / 74,80,134 / 52,54,100 | 104,112,182 | 50,54,118 / 80,88,166 / 132,142,212 |
| Path | 84,76,84 / 56,48,58 / 36,30,40 | 198,156,66 | 138,92,28 / 194,146,52 / 236,200,104 |

### Page language (the inventory's own art)

| Piece | Source art | Used for |
|---|---|---|
| Header plaque | `assets/sprites/inventory/signage/section_header.png` (124x28) | Section titles: Loadout, Physical, Spiritual, Effects, Active Benefits, the hovered thing's name |
| Card | `assets/sprites/inventory/gear_selector/item_description_background.png` (218x108) | Details blocks, the loadout, the path tree |
| Row bar | `assets/sprites/inventory/consumables_tab/consumable_slot.png` (220x30) | List rows: abilities, attributes, benefits |
| Slot | `assets/sprites/inventory/inventory_slot/UI_NoteBook_Slot01a.png` (28x28) | Icons and loadout slots |
| Dark pill | `assets/sprites/inventory/equipment_grid/equipment_category.png` (124x28) | Small status and control pills |
| Filter selector | `SortSubBanner` (`scenes/inventory/common/sort_sub_banner/`) | Arrows-and-dots option selector |

All of this art is drawn at book scale: one art pixel is one book unit, two screen pixels.

All of this art is light cream or peach, while the theme's general Label variants (`LabelBody`, `LabelMuted` and the rest) are light text meant for dark panels. The pages need their own dark-ink Label variants; only the sizes carry over.

### Scale

The inventory draws its book at 2x and counter-scales each text widget to 0.5x so text renders at native resolution. That trick stays inside the inventory's existing pages. The new pages are laid out at screen resolution with ordinary Godot containers, so their text keeps the theme's Label variants at their normal sizes. Their pixel-art chrome must still appear at 2x so it matches the book: fixed-size pieces (plaques, slots) are drawn at exactly twice their texture size, and stretchable pieces (cards, row bars, pills) need 2x nearest-neighbour copies of their textures for 9-slice styleboxes. Inventory widgets authored in book units (`TabBanner`, `SortSubBanner`, the tab buttons) are reused at the book's scale.

Page geometry, in the book's 700x450 frame (screen = 2x): the left page's inner area, inside the border line, is x 82 to 336, y 56 to 400; the right page's is x 364 to 618. Each is about 508x688 screen pixels. The title ribbon sits at (95, 42), 196x66, as in the inventory.

### Opening and closing

All four states open through `GreyBackground.show_with_panel()` and close through `hide_with_panel()`. Today the backdrop's fade-out (0.2 s) decides when the close is done, which would cut the book's 0.3 s close animation short; the close must instead finish when both the fade and the book's close animation have finished. The trash-slot flush the inventory does on close keeps happening.

Closing paths: Esc (`ui_cancel`; `close_inventory` for the inventory), the menu's own key, and the close tab. All three take the same route.

## The four books

Each page below lists blocks from top to bottom.

### Inventory (as built)

Unchanged pages and behaviour. It moves onto the shared book scene, gains the red page border, the bookmark and the close tab, and opens and closes through the backdrop fade.

### Abilities

- **Left page:** title ribbon "Abilities". The filter becomes a `SortSubBanner` with All / Offensive / Buff / Equipped, at the inventory's filter position. Below it, the abilities as row bars: icon in a slot, name, cost and cooldown line (for example "8 Madra · 3 s", plus the cast time when there is one), and the slot key chip (Q/W/E/R) when equipped. The list scrolls when it overflows. At the bottom, where the inventory has its page buttons, a second `SortSubBanner` for sort, worded as orders so it doesn't read as a second filter: By loadout / By name / By Madra / By cooldown. "By loadout" lists the equipped abilities in Q, W, E, R order, then the rest by name.
- **Right page:** header plaque "Loadout", then a card with the four loadout slots (key chips Q, W, E, R) and "N / 4 equipped". Below, a details card for the ability you point at: icon, name, Madra-type and source badges, the effect and target tags, the damage and timing stats (`AbilityStatsDisplay`), the description, the equipped state, and a hint line for the equip gestures.
- **Equip gestures** follow the inventory: drag a row onto a loadout slot (as today; dropping on a filled slot replaces it), right-click a row to equip it into the first free slot or unequip it, and drag one slot onto another to reorder (as today). Right-clicking an unequipped ability with all four slots full does nothing, and the details card says the loadout is full. Dragging a slot out of the loadout still does nothing, as today (`docs/abilities/ABILITIES.md` lists it as a known gap). The expanding cards and their EQUIP button go away.
- Details follow hover and keep showing the last ability pointed at. When the book opens, they show the first ability in the list.

### Character

- **Left page:** title ribbon "Character", header plaque "Physical" with Strength, Body, Agility and Resilience as row bars (icon, name, value), then header plaque "Spiritual" with Spirit, Foundation, Control and Willpower.
- **Right page:** header plaque with the attribute's name, a card with the attribute's icon in a slot, its value, its group and its description, then header plaque "Effects" and a card with the effect lines. This is the text the floating tooltip shows today (`CharacterView.TOOLTIP_DATA`); the tooltip goes away.
- Details follow hover and keep the last attribute; Strength is shown when the book opens.

### Path

- **Side tabs** for Foundation, Copper, Iron and Jade, with stage icons. A stage the player hasn't reached shows a padlock, can't be opened, and hovering it shows a tooltip saying which stage unlocks it. Switching to a reached stage plays the page turn.
- **Left page:** title ribbon "Path", header plaque with the path's name ("Pure Madra"), then a card holding the open stage's tree with today's pan and zoom, and a small hint line. Only the open stage's nodes are shown (`PathNodeData.required_stage`). Each stage has its own layout scene; today only Foundation's (`pure_madra_tier1_layout.tscn`) exists.
- **Right page:** a header plaque with the name of the node you point at, and a card with its type, cost or purchased state, description and effects (today's `PathNodeTooltip` content). Below, header plaque "Active Benefits" and the purchased nodes of every stage as row bars, scrolling when long. At the bottom, a dark pill with the points to spend and points spent.
- Hovering the path-name plaque shows the path's own information on the right page (description, strengths, weaknesses, cycling, combat), replacing today's hover popup. That is also what the right page shows when the book opens.
- Clicking a node buys it, as today.

## Constraints

- Godot 4.6, GDScript, GL Compatibility renderer, 1920x1080 viewport, nearest texture filtering by default. `main` moved to Godot 4.7 (PR #45) while this was built; it was merged into this branch on 2026-10-21, and the suite passes on Godot 4.7.2.
- Project rules in `CLAUDE.md`: UI nodes live in `.tscn` scenes with theme variants, and scripts set data; `%UniqueName` node references; typed variables and return types; `##` doc comments on public functions; `Log`, not `print`.
- No files in `addons/` change.
- Existing GUT tests keep passing. The inventory integration tests find `EquipmentTab` and `TrashSlot` by name anywhere under `inventory_view.tscn`.
- `MainView`'s state stack, `GreyBackground` and the four state nodes in `main_game.tscn` stay the integration points.
- New logic gets GUT tests (`tests/unit/test_<system>.gd`).

## Decided in conversation

- Four separate books from one shared book scene, not one shared journal.
- The per-book identity: cover and page-border colour by palette swap (no corner marks), a bookmark, and a title ribbon naming the menu.
- The page language: everything on cards, row bars, slots, plaques or pills from the inventory's art.
- The layouts above, including Abilities flipping sides from today (list left, loadout right).
- The path book holds stages as chapters (side tabs), not one tall tree.
- The close control is a tab on the top edge of the right page.
- The bookmark is pixel art tucked between the top page and the pages beneath.

## Calls made by the designer (check these)

- The inventory's ribbon keeps naming its open tab.
- Abilities: hover drives the details; right-click quick-equips and unequips like the inventory; the EQUIP button and expanding cards go away; sort becomes a second `SortSubBanner`.
- Right pages keep showing the last thing pointed at; the first ability, Strength, and the path's own information show on opening.
- Locked stage tabs can't be opened and explain their unlock stage on hover.
- The bookmark and close tab hide while the book animates.
- The shared scene is composed into each view (an instance plus the view's own page content), not inherited and not copied.
- One master book PNG plus a shader, rather than baked per-book PNGs.
- After the reviewer's check: the page-turn sprite takes the palette swap too; the side tabs keep their art; dropping on a filled loadout slot replaces it; right-click on a full loadout does nothing; dragging a slot out stays a known gap; Active Benefits lists every stage; the sort options are short and worded as orders ("By loadout" and so on); a locked stage's hint is a tooltip.

## Left to the builder

- Node structure of the shared book scene and how each view composes its pages around it.
- The palette-swap shader and the per-book style resource's shape.
- Producing the new pixel art: bookmark, close tab and X glyph, stage icons, and the 2x copies of the stretchable chrome. The brainstorm mockups generated working versions; the generator approach (palette-based drawing at the book's logical resolution, 2x nearest upscale) can be reused.
- How `GreyBackground` learns that a book's close animation has finished.
- Sharing the four near-identical state scripts.
- Restyling `AbilityEquipSlot` to the slot art without breaking its drag-and-drop.
- Fitting the Foundation tree into its card at a sensible default zoom.
- Which docs change: at least `MAIN_VIEW.md`, `INVENTORY.md`, `CHARACTER.md`, `ABILITIES.md`, `PATH_PROGRESSION.md` and `UI_STYLING.md`.

## First review (2026-10-21)

After trying the books in the editor, the user asked for these changes. All are built; the sections above describe the first build.

**Every book**
- The bookmark hangs half as far below the page stack (about 27 book px instead of 55) and is about 10% narrower (16 px art instead of 18).
- The close tab shows half as much above the page (22 book px), sits about 20 screen px nearer the page corner, and has no hover state. Its X is the game font's X instead of a drawn PNG, centred in the tab.
- The filter pill text ("All", "By loadout") was too big for its pill. `LabelInventorySort` drops from 38 to 30 px, which changes the inventory's pill too.

**Abilities**
- The sort selector is gone and the list keeps loadout order; the list runs to the foot of the page.
- Loadout slots grow from 76 to 96 px and their icons from 48 to 72 px.
- Hovering rebuilt the details, and with them the damage preview and its `CombatEffectData` log lines, on every pointer entry. Pointing again at the described ability now does nothing, and each ability's damage is worked out once per opening (cleared when a base attribute changes).
- Style pass: the stat-pill strip (dark HUD chips with coloured text, mixed number formats and a pulsing border) became a stat list in the book's own type: Damage with its makeup ("30 base + Spirit ×1.5 + Foundation ×0.5"), Cooldown, Cast time, Cost. A divider now sits before the description, and the header icon is larger.

**Character**
- The wide, short rows became tiles, four to a group: the icon at 64 px over a large gold value over the name, all centred.
- The Effects text was wrong in several places; it had been hand-written before the books. Ability lines are now read from the unlocked abilities' data, and the formula lines were corrected to match the code. The Effects card fills the rest of the page.

**Path**
- The "0/3" level labels sat half off their nodes, in the corner; they are now centred captions under the node, larger and outlined.
- Active Benefits are one short line each, about half the old height, with the full text as the tooltip. The list has no scrollbar.
- The points pill became a small badge in the right page's top-right corner that shows only the points to spend.

### Calls made in the review round (check these)

- "10% flatter" for the bookmark was read as 10% narrower.
- "The X we use elsewhere" was read as the game font's X, used by the cycling view's close button ("X ESC"). The inventory's trash slot has a different, chunkier X baked into its slot art; switching to that one would be a small change.
- "No hover" also removed the close tab's "Close" tooltip and hand cursor, matching the side tabs.
- The Character right page keeps its layout; the header now shows the value large on the right.
- Benefit lines put the name and the summary on one line, trimmed with "…" when too long. (Replaced in the second review.)

## Second review (2026-10-21)

The user's second pass. All built.

**Every book**
- The filter pill's text and the plaques' text sat high; they moved down 2 and 3 px and now measure within 1 px of centre.
- The bookmark moved right, to halfway between its first spot and the book's right edge (centred at x 583). It now slides down out from between the pages once the book lies open (0.45 s), instead of popping in.
- No section on a right page moves when you point at something else.

**Abilities**
- The "Equipped in slot W" and "Right-click to equip…" lines are gone; the key already shows on the row and in the loadout.
- Every ability gets the same layout:
  - a header;
  - a first stat line, which is "Damage", "Heal", or "Effect" for buffs and debuffs (Enforce reads "×1.5 damage", "on your next attack");
  - a breakdown line under it;
  - Cooldown, Cast time and Cost;
  - a four-line description area.
- A type icon at the header's right shows what the ability mainly does. The secondary extras stay as text ("Targeted · Strips buffs").
- The damage breakdown shows what each attribute adds right now, with its icon: "10 base", Strength "+17", Agility "+7".

**Character**
- The description and the effects share one pane; the Effects plaque is gone.
- The Control icon's art was off-centre in its canvas; it is re-centred.

**Path**
- The details card keeps one height, with the cost or "Purchased" line at its foot, so Active Benefits never moves.
- Active Benefits is one card of green "▲" lines (each node's benefit summary), with no rows, icons or tooltips.

### Calls made in the second round (check these)

- The equipped key was dropped from the details card rather than shown as a top-right chip.
- Type icons reuse the end card's crossed swords (damage) and heart (heal). Buff and debuff had no art, so they got new gold up and purple down arrows in the same outlined style.
- The breakdown shows each attribute's current contribution rather than its per-point rate; the Character book already shows the rates.
- Active Benefits lines show each node's benefit summary without the node's name.
- The bookmark slides after the book has finished opening, not during the opening frames, since the page edge moves on each of those frames. It hides at once on close.

### After the second review

- After merging `main`, its new AI-Generated Art rule (CLAUDE.md) applies: every image this work generated carries an `_ai` suffix, and the Control icon fix lives in a new `control_icon_ai.png` instead of editing the original.
- A click on the grey backdrop anywhere outside the book closes it, like Esc. The open book's art, (48, 24)-(652, 432) in book units, and the bookmark catch clicks; the transparent margins of the 700 × 450 frame count as outside. (Builder's call: the art's bounding rectangle stands in for its outline, since the open book is nearly rectangular.)

## Reference

- Brainstorm mockups (local only, git-ignored): `.superpowers/brainstorm/1209-1792555484/content/` (`four-books-v2.html` and `path-close-ribbon.html` are the final screens).
- `docs/infrastructure/MAIN_VIEW.md`: state machine, `GreyBackground`, the transition-style and backdrop issues.
- `docs/inventory/INVENTORY.md`: the book's structure.
- `docs/progression/PATH_PROGRESSION.md`: stage tiers and their planned design.
- `docs/UI_STYLING.md`: the Label type-scale.
