# Inventory: pressed pages for the four tabs

Date: 2026-10-23
Status: Design from the brainstorm (mockup rounds 1 to 7), awaiting the user's review. Not built.
Mockup: [inventory-pressed-mockup.html](../mockups/inventory-pressed-mockup.html) (open it in a browser; images 1:1 with the 1920x1080 viewport)

## Intent

The inventory book has four tabs. Two work and two are broken:

- **Equipment** and **Consumables** work, but the user doesn't like how they look. Their review: the book looks "a little out of place given the rest of the game", and, more importantly, the content "feels like it's not living in the page". Every piece is its own framed sticker sitting on the paper: bevelled slot tiles, a dark pill with arrows, a cartoon ribbon, the "Gear Selector" plaque, one card for the figure and another for the details.
- **Materials** and **Journal** don't work. The book is drawn at 2x and those two tabs never counter-scale their text, so it renders at double size, spills off the book and covers the dock. They also show the Godot logo as item icons.

This project rebuilds the content of all four tabs in one page language, called "pressed". The book stays. Slots, panels and the gear figure are pressed into the paper, and labels are printed in ink. The look is the user's pick from three directions (inked, pressed, a lacquer board with no book) over six mockup rounds.

The user also worried about how Consumables would hold up "once we blow up the amount of consumables". They expect 5 to 10 kinds.

## Goals

- All four tabs read as part of the page: nothing on a page has a frame of its own. Content is pressed in, printed or stamped.
- Materials and Journal work. All text renders at native resolution, wraps, and stays inside the page.
- One page language across the four tabs, with the same title, slot, panel, rule, tag, mark and seal.
- Equipment and Consumables keep every behaviour they have today (drag, equip, quick-equip, discard, pages, filter, hotbar).
- The Journal shows each quest item with its quest, the way the Goals board shows a quest, plus the quest's flavour text.
- Consumables hold a pack of 5 to 10 kinds without crowding, and more by scrolling.

## Non-goals

- The other three books (Abilities, Character, Path). They move to the pressed look in a later project. The new pieces should be reusable for that, but nothing in those books changes now.
- The book itself: cover, spiral, side tabs, close tab and bookmark stay as they are (the user: "leave").
- Comparing gear with what you're wearing (the user: "not necessary yet").
- New content: no new consumables, materials or quest items. The mockup's extra consumables are placeholders that show the list at scale.
- Using consumables in combat, crafting, selling, or a quest log.
- Categories or a filter for Consumables or Materials.

## Anti-goals

- Content that looks like stickers on the page again: framed tiles, plaques, ribbons, dark pills, cards with their own borders.
- Any text cut off, ellipsized, overflowing the page, or drawn at 2x.
- Losing or changing an Equipment or Consumables behaviour the player relies on today.
- Off-grid pixels: icons at 40 px, art scaled by non-integer factors, odd positions.
- Changing how the other books look. All theme and art changes are additive.

## The look: pressed paper

Light comes from the top left. A pressed thing is cut into the page: its top and left inner walls are in shadow, its bottom and right walls catch the light, and its floor stays close to the paper's colour. Printed things are flat ink. Raised things (paper tags stuck on) are the inverse of pressed: lit top and left, shaded bottom and right. All art keeps the game's grid (one art pixel = 2 screen pixels) with hard edges and no gradients, glow or alpha (STYLE_GUIDE.md §3).

### Palette

| Colour | Hex | Use |
|---|---|---|
| Paper | `#F7E6CA` | The book's page (already the book art's colour) |
| Ink, dark | `#33261A` | Titles, names, values (the book theme's title ink) |
| Ink | `#3B2A20` | Body text (the book theme's body ink) |
| Ink, muted | `#7D5F47` on paper; `#765A43` inside panels | Labels, captions, hints, leader lines. `#7D5F47` is 4.76:1 on the paper but 4.34:1 on a panel's floor; `#765A43` keeps 4.72:1 there |
| Floor, owned slot | `#E7CFA6` | Inside a slot that holds something |
| Floor, empty slot and panel | `#EFDCBB` | Inside an empty slot and inside the large panels |
| Wall shadow | `#B9996F` | First shadow step on the top and left walls; pressed rules |
| Wall shadow, second | `#D3B98F` | Second shadow step on deep slots |
| Lit edge | `#FBF1DE` | Bottom and right walls; the lit half of a pressed rule; a tag's lit edge |
| Vermilion | `#A83C30`, shade `#7E2A22` | Printer's marks, seals, the Journal's drop cap |
| Seal text | `#F0E8D8` | Words on a seal (5.1:1 on vermilion) |
| Madra ink | `#1C2F60` | Madra amounts (the kit's deep Madra blue; Madra blue means Madra everywhere in the game) |

### Type

BM Euljiro for everything except titles, which are Yatra One. Every size is a theme variant; no text is under 13 px.

| Role | Font, size | Colour |
|---|---|---|
| Page title ("Equipment", "Gear", a material's or quest item's name) | Yatra One 38 | Ink, dark |
| Item name in a panel | Yatra One 30 | Ink, dark |
| Quest name | Yatra One 26 | Ink, dark |
| Drop cap (Journal) | Yatra One 46 | Vermilion |
| Body, description | Euljiro 18 | Ink |
| Row name, value, "You have 4,600" | Euljiro 18 | Ink, dark |
| Row detail (what a consumable does, a quest item's quest) | Euljiro 15 | Ink, muted |
| Label in capitals (`HEAD`, `STRENGTH`, `CONSUMABLE · IN SLOT 1`, filter words) | Euljiro 13, 1 px letter spacing, uppercase | Ink, muted (the filter in use: ink, dark) |
| Count in a list row (`×7`) | Euljiro 20 | Ink, dark |
| Count on a tag, seal word | Euljiro 13 | Ink, dark; seal: seal text |
| Hotbar key number | Euljiro 18 | Ink, dark |
| Hint (`Right-click to wear it`) | Euljiro 15 | Ink, muted |
| Quest flavour text and steps | Euljiro 16 | Flavour: ink, muted; steps: ink |

### Pieces

Every piece is new agent-drawn art (`_ai`), drawn on the 2x grid with the palette above. `docs/superpowers/mockups/inventory-pressed/gen/` draws all of them (see References).

| Piece | Look | Size (screen px) |
|---|---|---|
| Deep slot | Floor `#E7CFA6`; two shadow steps on the top and left walls, lit edge bottom and right; corners rounded 4 px (2 art px) | 72 × 72, holds a 64 px icon at +4, +4 |
| Shallow slot | Floor `#EFDCBB`; one shadow step | 72 × 72 |
| Panel | Floor `#EFDCBB`; two shadow steps; corners rounded 6 px; stretches (9-slice, corners and walls kept out of the stretch) | Any size |
| Pressed rule | A 2 px shadow line over a 2 px lit line | Any width |
| Title ornament | A 2 px muted-ink line, 272 px long, broken at the centre by a 14 px ink diamond | 272 × 14 |
| Printer's marks | Four vermilion L-shaped corner marks, 10 px arms, 2 px thick, 6 px outside what they mark; nothing between them | Overlay, any size |
| Paper tag | Paper fill, lit top and left edge, shaded bottom and right, corners cut 2 px | Hugs its text: text width + 10, 20 tall |
| Seal | A vermilion chop with its edge bitten in a few places, darker bottom and right edge | 66 × 26 |
| Tick box | A shallow 22 × 22 slot; ticked, an ink tick in it | 22 × 22 |
| Scroll groove | A shallow slot 10 px wide; the thumb a 4 px ink bar inside it | 10 × list height |
| Cultivator relief | A standing cultivator in a long robe with wide sleeves and a topknot, pressed in (shadowed top-left walls, lit bottom-right, creases for the collar, sash, sleeve openings and the robe's front fold) | 140 × 224 |

## Page frame

The book, its open, close and page-turn animations, the side tabs, close tab and bookmark are unchanged. Only the content of the two pages changes. All positions are screen px in the 1920x1080 viewport.

| What | Value |
|---|---|
| Left page, inside its border line | x 424 to 932, y 202 to 890 |
| Right page, inside its border line | x 988 to 1496, y 202 to 890 |
| Left page content | x 452 to 904 (centre 678) |
| Right page content | x 1008 to 1476 (title centre 1244) |
| Page title | Yatra 38, baseline y 262, centred on the page |
| Title ornament | Centred under the title, its line at y 278 |
| Caption row (filter, `2 KINDS`, `ITEMS OF CONSEQUENCE`) | Baseline y 316, centred |
| Content starts | y 334 under a caption row, y 300 without one |
| Content ends | By y 880 |

## The four tabs

Each tab's left page holds what you have; its right page holds what you're using and details of what you point at, as on every menu book (menu books spec).

### Equipment

Left page:
- Title "Equipment".
- Filter in the caption row: `ALL`, `WEAPONS`, `ARMOR`, `ACCESSORIES`, printed. The one in use is printed in dark ink and pressed in (a shallow pressed lozenge 26 px tall behind the word). Click a word to filter, as the arrows do today.
- A page of 6 × 6 slots, 72 px at a 76 px pitch (452 × 452), from (452, 334). A slot holding an item is deep; an empty one is shallow. Items fill the page in their saved order.
- Under the grid, a footer row:
  - at the left, `PAGE` and a small slot per page: 28 × 28 at y 818, the page shown pressed deep and the others shallow, its number printed in it;
  - the count `11 / 72` (equipment you hold / `equipment_capacity()`), right-aligned at x 816, baseline 838;
  - the discard slot at the right, a full 72 × 72 slot at (832, 796). Empty, it is a shallow slot with a printed ×. Holding an item, it is a deep slot showing the item with no ×, and you drag the item back out to keep it, as today.
- Filtered out: items that don't match the filter are drawn faded into the paper (an opaque mix towards the paper colour, never alpha) in shallow slots, and stay draggable.

Right page:
- Title "Gear".
- The cultivator relief at (1174, 300), with six deep gear slots around it. Left column at x 1016: Head (y 300), Main hand (y 398), Accessory (y 496). Right column at x 1400: Body, Off hand, Accessory, at the same heights. This mirrors the figure. Today Main hand and Off hand are both on the right.
- Each slot's name is printed in capitals, centred under it (baseline at slot top + 94).
- A dotted leader line in muted ink (a 2 px dot every 6 px) runs from each slot's inner side to what it dresses: the head, the left sleeve's end, the sash's left, the chest, the right sleeve's end, the sash's right.
- An empty gear slot is a shallow slot. Today's grey slot outlines go away.
- The details panel, (1008, 606) to (1476, 878). The panel can't grow on this page, so it is laid out for the longest real item, the Dreadbeast Tooth Necklace (see the mockup):
  - the item in a deep slot at (1024, 622). Beside it, its name (Yatra 30, x 1112, wrapping onto a second line within 346 px, baselines 654 and 688), then its slot in capitals (`ACCESSORY`, `MAIN HAND`) 26 px under the name's last line;
  - its bonuses in two columns, two to a row: the attribute in capitals with its value right-aligned (columns x 1024 to 1232 and 1250 to 1458), first row at baseline 752, a pressed rule under each row;
  - the description from baseline 798, wrapping at 434 px;
  - the hint at the panel's foot, baseline 866: `Right-click to wear it` (`Right-click to take it off` when it is worn). The hint is the first thing to go when an item needs the room: more than four bonuses, or a description over two lines.

### Consumables

Left page:
- Title "Consumables", no caption row.
- A list from y 300, one row every 80 px, seven rows in view:
  - the item in a deep slot at x 452;
  - its name (Euljiro 18) at x 540, baseline +30;
  - what it does at baseline +56. That is each effect's `describe()` joined with ` · `, then the cooldown (`+20 Madra · 10 s cooldown`). Madra amounts print in Madra ink.
  - how many you have (`×7`, Euljiro 20), right-aligned at x 876, baseline +46.
  - A pressed rule under each row except the last, x 452 to 880.
- More than seven kinds scroll. The scroll groove is at x 892 to 902, y 300 to 852, and appears only when the list overflows.

Right page:
- Title "Hotbar".
- Four slots, 72 px, at x 1040, 1152, 1264 and 1376, y 316. A filled slot is deep, an empty one shallow.
- Each slot's key number (1 to 4) is printed under it (baseline 418). The stack count sits on a paper tag at the slot's bottom right.
- A printed hint, centred, at baselines 456 and 478: `Drag a consumable onto a slot to carry it into combat.` / `Click a slot to empty it.` A pressed rule follows at y 498.
- The details panel, (1008, 512) to (1476, 824):
  - the item in a deep slot, its name (Yatra 30), and `CONSUMABLE` in capitals, plus `· IN SLOT n` when it is on the hotbar;
  - a table: one row per effect (`RESTORES` → `+20 Madra`; the label is the effect's kind) and `COOLDOWN` → `10 s`;
  - the description, then the hint `Drag it onto the hotbar`.

Behaviour as today: drag a row onto a slot to equip it, drag between slots to move or swap, click a filled slot to empty it. A consumable sits in one slot at most.

### Materials

Kept minimal (the user: "for now you can almost ignore the materials").

Left page:
- Title "Materials".
- Caption `N KINDS`.
- The same 6 × 6 page of slots as Equipment, from (452, 334). Each material sits in a deep slot, with its count on a paper tag at the slot's bottom right (`×4600`). There is no filter, no trash and no pages: all owned kinds are listed, and the page scrolls if there are ever more than 36.

Right page:
- The title is the material's name.
- One panel, (1008, 300) to (1476, 646):
  - the material in a deep slot;
  - `MATERIAL` in capitals and `You have 4,600` beside it;
  - the description;
  - a table of where it comes from: `GATHERED BY` → the activity's name, `IN` → the zone's name, `YIELD` → `2–6 every 5 s` (the loot entry's quantity range and the activity's interval). There is one block of rows per source.
  - With no known source, the table is left out.

Removed: the tip card, the "Used in" and "Worth" rows, the Source Zones line and the materials trash slot. The `used_in` and `source_description` data fields stay; nothing in the UI reads them.

### Journal

Left page:
- Title "Journal".
- Caption `ITEMS OF CONSEQUENCE`.
- A list from y 334, one row every 80 px, in the same format as Consumables:
  - the item in a deep slot;
  - its name (Euljiro 18);
  - its quest's name (Euljiro 15, muted).
  - At the right, a seal reading `DONE` when the quest is finished. Otherwise the step you're on, `Step 1 of 3` (Euljiro 15, muted, right-aligned at x 876).
  - An item with no quest (none needs it, none gave it) shows its `from_source` instead of a quest name, and nothing at the right.

Right page:
- The title is the item's name.
- The item's panel, (1008, 300) to (1476, 496):
  - the item in a deep slot;
  - `QUEST ITEM` in capitals and `From Old Vesh, in the broken shrine` (`from_source`) beside it;
  - the description, opening with a two-line drop cap in vermilion.
- The quest's panel, (1008, 512) to (1476, 776), the way the Goals board shows a quest:
  - `QUEST` in capitals, with the `DONE` seal at the top right when it is finished;
  - the quest's name (Yatra 26);
  - the quest's own description as flavour text (Euljiro 16, muted);
  - a pressed rule;
  - the steps reached so far, each in a tick box. Finished steps are ticked. The current step is unticked, with its progress figure (`7 / 10`) at the right, worked out as the Goals board does. Steps not yet reached are not shown.
- The quest panel is left out for an item with no quest.

### Shared behaviour

| Behaviour | All four tabs |
|---|---|
| Details | Follow the pointer (slot, row, gear or hotbar slot) and keep showing the last thing pointed at. On opening a tab, they show its first item. Today Consumables and Materials need a click. |
| What the details show | Printer's marks sit round that slot or row |
| Drag target | While dragging, printer's marks sit on the slot that would take the item; nothing marks one that would refuse it |
| Removed | The animated hover ring (`SelectorSprite`) |
| Empty tab | The left page prints one muted line where the content would be (`No consumables yet.`, `Nothing gathered yet.`, `No quest items yet.`) and the right page's details stay hidden. The hotbar and gear slots still show. |
| Counts | Full numbers on tags and in rows (`×4600`), thousands separators in the details (`4,600`) |
| Long text | Wraps, and the panel grows downward to fit; nothing is cut off or ellipsized. The Equipment details panel is the exception: it can't grow, so its hint gives way first (see Equipment) |
| Close | Unchanged: Escape, I, the close tab or the backdrop. Anything in the discard slot returns on close, as today |

## Data the tabs read

| Need | Source |
|---|---|
| A quest item's quest | First choice, the quest that **needs** the item: a quest with a step whose `completion_conditions` include an `ITEM_OWNED` condition (`UnlockConditionData`, `target_value` = the item's `item_id`). Only quests the player has started count (active or completed, never one not yet started, so nothing is spoiled). An active one wins over a completed one. Otherwise, the quest that **gave** it: the quest whose `completion_effects` include an `AwardItemEffectData` for that item. Both come from QuestManager's quest catalog; the quest's state comes from `has_completed_quest()` and `get_current_step_index()`. Today the Refugee Camp Map falls back to "Harden Your Core", which gave it, so its card reads DONE. The in-progress view appears as soon as a quest has a step that needs an item. |
| The current step's progress figure | The Goals board's rule: the step's first completion condition, `current / target`, whole numbers (`GoalsPanel._get_measured_condition()`). Share that helper rather than copy it. |
| A material's sources | Every zone activity whose loot table lists the material: the activity's name, its zone's name, the entry's `min_quantity` to `max_quantity`, and the activity's interval (`foraging_interval_in_sec` for foraging). Only sources the player can already see are listed: activities they have unlocked, in zones the map shows them (never a hidden zone such as Test Zone), so the page spoils nothing. The list is worked out when the tab is shown. Today the only source is Spring Forest Foraging in Spirit Valley. |
| A consumable's effect lines | `EffectData.describe()` per effect, `cooldown_seconds` as whole seconds |
| A consumable's hotbar slot | `InventoryData.equipped_consumables` |

## Constraints

- Godot 4.7, GDScript, GL Compatibility renderer, 1920x1080 viewport, nearest filtering.
- CLAUDE.md rules:
  - UI nodes live in `.tscn` scenes; scripts set data, textures, visibility and state colours;
  - theme variants, never inline size overrides;
  - `%UniqueName` node references, typed variables, `##` docs on public functions;
  - `Log`, not `print`;
  - no edits in `addons/`;
  - new images end in `_ai`, and the user's art files are never edited.
- Theme changes are additive: new variants in `book_theme.tres`. The variants the other books use today don't change.
- `InventoryData` keeps 6 × 6 pages (`PAGE_ROWS`, `PAGE_COLUMNS`, `SLOTS_PER_PAGE` = 36). The Equipment page shows exactly that, which also fixes today's mismatch (a 7-column page showing 42 slots).
- Existing behaviour tests keep passing:
  - drag paging;
  - trash flow;
  - the hotbar;
  - the Equipment filter;
  - pagination;
  - `test_inventory_*`.
  
  They find `EquipmentTab` and `TrashSlot` by name under `inventory_view.tscn`. Tests that pin the old look are rewritten:
  - the TabBanner title;
  - the SortSubBanner;
  - `ItemDetailCard`;
  - the journal render;
  - the part of the Equipment filter test that checks the 30% alpha dimming, rewritten for the faded state. The filter's matching rules are unchanged.
- `MainView`, `InventoryViewState`, `BookFrame` and `GreyBackground` stay the integration points.

## Decisions

From the brainstorm and the grill, 2026-10-23.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Look | Pressed paper: the book stays; slots, panels and the figure are pressed in; labels printed | The user's pick over inked pages and a lacquer board with no book (round 1), refined in rounds 2 and 3 | The other books adopt it |
| Details | A pressed panel with the text printed in ink | The user's pick over pressing the letters themselves (round 3) | — |
| Depth and edges | Pressed a step darker than round 2; corners rounded and walls gentler (round 6) | The user: "a little darker", then "a little less sharp and a tiny bit less square" | After seeing it in the game |
| Scope | The inventory's four tabs only | The user: "inventory for now" | Abilities, Character and Path move next |
| The book | Unchanged | The user: "leave" | The shell is reworked for every book |
| Journal | Quest items, each with its quest shown like the Goals board, plus the quest's flavour text | The user | A quest log is wanted |
| A quest item's quest | The quest that needs it (a step requiring it), else the quest that gave it | The user, after the builder check: the reward link alone would make every card DONE | Items start arriving another way |
| Consumables | A list | The user; 5 to 10 kinds expected | Past about 20 kinds |
| Materials | Minimal: what you have and where it really comes from | The user: "almost ignore the materials" | Crafting or selling arrives |
| Gear comparison | Not now | The user: "not necessary yet" | Gear choices get harder |
| Missing icons | Claude draws placeholders (`_ai`) | The user | The user draws the real ones |
| Titles | Yatra One (style guide K-Q2) | In every approved mockup | — |

## Calls made by the designer (check these)

- 6 × 6 pages, matching the save data.
- Item icons at 64 px everywhere, the user's files shown 1:1 (style guide G4, for the inventory).
- Gear mirrored to the figure: main hand left, off hand right.
- Details follow the pointer on every tab, keep the last item, and show the first item on opening.
- Red printer's marks for what the details show, and for the slot a dragged item would land in.
- Items outside the filter fade into the paper (opaque) instead of dropping to 30% alpha.
- Full counts on tags, thousands separators in the details.
- The Equipment count is the whole bag against its capacity (`11 / 72`), not the page.
- After the builder check:
  - the Equipment details lay out for the longest real item, with bonuses in two columns and the hint dropping first;
  - the discard slot is a full 72 px slot, so it can show what it holds;
  - material sources list only places the player has found.
- No filter on Consumables or Materials. The Materials trash slot goes.
- The right page's title: "Gear" and "Hotbar" for Equipment and Consumables; the selected material's or quest item's name for Materials and the Journal.
- Journal steps: finished ones ticked, the current one with its figure, later ones hidden.
- Madra amounts in Madra ink.
- Muted ink `#765A43` inside panels, for contrast.
- Placeholder content until the user replaces it:
  - icons for Spirit Fern and Dewdrop Tear: the zone kit's `ic_fern_ai.png` and `ic_dewdrop_ai.png` at 64, saved as item icons;
  - a new 16 art px map icon for the Refugee Camp Map;
  - the material descriptions from the mockup ("A fern that drinks the valley's aura. Its fronds curl toward a cultivator's core."; "Dew that gathers aura at dawn and keeps it until it is crushed.") in place of "Spirit Fern Description" and "Dewdrop Tear Description".
- The pages move to a screen-resolution page layer, as Abilities, Character and Path already do (`BookLayer` at 2x for the frame and side tabs, `PageLayer` at 1x for the pages). This is what makes the double-size text impossible, rather than counter-scaling each label.

## Left to the builder

- The node structure of each tab, and how far today's shared pieces are reused: `InventoryGrid`, `InventoryList`, `InventoryScrollHost`, `ScrollRail`, `SortSubBanner`, `GridToolbar`, `TabBanner`, `ItemDetailCard`, `ItemDescriptionPanel`. `ItemDescriptionPanel` also serves the adventure end card's tooltip, so it can't simply be restyled for the book.
- How the art is cut (fixed textures and 9-slices), and the generator that writes the final `_ai` textures.
- The theme variant names, and the `FontVariation` for the 1 px letter spacing (the lacquer theme's tag variant does the same).
- How the dragged item is drawn while dragging, and how the two drag systems (Equipment's manual one, the hotbar's built-in one) show the drag-target marks.
- How the faded "filtered out" icon is drawn (a small shader or a material), within the no-alpha rule.
- Which tests to rewrite and which to add, and the docs: `INVENTORY.md`, `UI_STYLING.md`, and `STYLE_GUIDE.md` (the K5 to K9 rows and the answers to K-Q1, K-Q2, K-Q3 and, for the inventory, G4).

## References

- Mockup: [inventory-pressed-mockup.html](../mockups/inventory-pressed-mockup.html). The final images are `inventory-pressed/pressed_*_ai.png`; `now_*_ai.png` are the game before this work; `round*_ai.png` are the directions tried.
- Mockup generators, Python 3 with Pillow: `docs/superpowers/mockups/inventory-pressed/gen/`.
  - `gen_r7.py` holds the final Equipment page and `gen_r5.py` the other three tabs (`gen_r3.py` is the round 3 Equipment page they build on).
  - `gen_r6.py` applies the final softer pieces. `soft_well()`, `soft_rule()` and `soft_tag()` are the pieces to export.
  - `gen_r2.cultivator_mask()` is the relief's shape.
  - `icons_ai.py` holds the placeholder icons.
  - Their `SCR` and `OUT` paths point at the authoring session's scratch folder; change them to rebuild. The `now` captures are the base images.
- [INVENTORY.md](../../inventory/INVENTORY.md) (the system as built), [STYLE_GUIDE.md](../../STYLE_GUIDE.md) (§3 rules, §13 K5 to K9 and K-Q1 to K-Q3), [UI_STYLING.md](../../UI_STYLING.md) (book theme variants).
- [Menu books spec](2026-10-21-menu-books-design.md) (the shared book, its page rects, the page layer of the other books).
- [2026-05-25 inventory redesign](2026-05-25-inventory-ui-redesign.md): the trash rule, hotbar uniqueness and tab order, all kept.
