# Main View (UI Shell and Navigation)
Last updated: 2026-10-22

## Overview

`main_game.tscn` is the only runtime scene. It hosts every full-screen view (zone map, adventure, inventory, cycling, path tree, abilities, character, merchant shop, adventure end card), the HUD boards (the log and the Goals board; every overlay over the zone view hides them while it is open), and the dev tools. `MainView` decides which views are visible through a small state machine. There is one **base state**, Zone or Adventure. Modal **overlay states** are pushed on a stack above it.

- Menu overlays (Inventory, Path, Abilities, Character) open from the keyboard or the dock at the bottom of the zone view. Both routes produce the same input action. All four are books built on one shared `BookFrame` scene and open and close the same way (see [Menu books](#menu-books)).
- Cycling, the merchant shop, adventures and the end card are driven by `ActionManager` and `AdventureView` signals.
- Only the top state receives input. Everything else that reads input (the full log on L, the zone chest's lore and the map popover on Escape, combat hotkeys, camera pan/zoom, the dev hotkey, Dialogic) is handled outside the state machine.

The zone view itself (map, cultivator cabinet, zone chest) is documented in [ZONES.md](../zones/ZONES.md). Related docs: [UI_STYLING.md](../UI_STYLING.md) (themes, including the lacquer theme), [DEV_TOOLS.md](../tooling/DEV_TOOLS.md) (dev panel), [TESTING.md](../testing/TESTING.md).

## Architecture

### Scene tree (`scenes/main/main_game/main_game.tscn`)

```
MainGame (Node2D)                          main_game.gd: Ctrl+Shift+D dev hotkey, Log print level
├── MainView (Control, 1920x1080)          main_view.gd (class MainView): state stack, input routing, HUD board hiding
│   │                                      theme = pixel_theme.tres, mouse_filter = Ignore
│   ├── MainViewStateMachine (Node)        no script; container for the 9 state nodes
│   │   ├── AdventureViewState             scenes/ui/main_view/states/adventure_view_state.gd
│   │   ├── InventoryViewState             scenes/ui/main_view/states/inventory_view_state.gd
│   │   ├── ZoneViewState                  scenes/ui/main_view/states/zone_view_state.gd
│   │   ├── CyclingViewState               scenes/ui/main_view/states/cycling_view_state.gd
│   │   ├── AdventureEndCardState          scenes/ui/main_view/states/adventure_end_card_state.gd
│   │   ├── PathTreeViewState              scenes/path_progression/path_tree_view_state.gd
│   │   ├── AbilitiesViewState             scenes/abilities/abilities_view_state.gd
│   │   ├── CharacterViewState             scenes/character/character_view_state.gd
│   │   └── MerchantViewState              scenes/merchant/merchant_view_state.gd
│   ├── ZoneView (Control)                 base view; hidden while adventuring
│   │   ├── ZoneTransition (Node)          zone_transition.gd: Madra pellet drain + camera zoom into adventures
│   │   ├── SubViewportContainer           1920x1080, centred
│   │   │   └── SubViewport                transparent bg, always updates, Nearest texture filter
│   │   │       └── ZoneTilemap            zone_tilemap.tscn (hex map, fog, camera, player, MapMarkers)
│   │   ├── CultivatorPlate                cultivator_plate.tscn: Madra, Core Density, gold (top left)
│   │   ├── ZonePanel                      zone_panel.tscn: the zone chest (top right)
│   │   └── Dock                           dock.tscn: four SystemMenuButtons (bottom centre)
│   ├── AdventureView           z 0        adventure_view.tscn, hidden by default
│   ├── LogWindow               z 1        log_window.tscn (lacquer log board and full log)
│   ├── GoalsPanel              z 1        goals_panel.tscn (lacquer Goals board)
│   ├── QuestToast              z 10       quest_toast.tscn
│   ├── GreyBackground (Panel)  z 2        grey_background.gd, hidden by default
│   │   └── GreyBackgroundAnimationPlayer  RESET, grey_fade_in (0.3 s), grey_fade_out (0.2 s)
│   ├── PathTreeView            z 3        path_tree_view.tscn (menu book; z set on the scene root)
│   ├── AdventureEndCard        z 3        adventure_end_card.tscn
│   ├── InventoryView           z 3        inventory_view.tscn (menu book; root scale 2x, centred)
│   ├── AbilitiesView           z 3        abilities_view.tscn (menu book; z set on the scene root)
│   ├── CharacterView           z 3        character_view.tscn (menu book; z and visible=false set on the scene root)
│   ├── MerchantView            z 3        merchant_view.tscn (z, visible=false and the Spirit Valley theme set on the scene root)
│   ├── CyclingView             z 3        cycling_view.tscn
│   ├── DevPasswordModal        z 10       dev_password_modal.tscn, hidden
│   └── DevPanel                z 10       dev_panel.tscn, hidden, top-left 340x400
└── SaveTimer (Timer)                      save_timer.gd: 5 s, autostart → PersistenceManager.save_data()
```

Draw order is controlled by `z_index`. LogWindow and GoalsPanel (z 1) sit under the GreyBackground (z 2), so the end card's backdrop dims them; the zone-view overlays hide them outright (see [HUD boards](#hud-boards)). QuestToast and the dev tools (z 10) draw above every modal.

### HUD placement

| Node | Parent | Placement (1920x1080) | Notes |
|------|--------|-----------------------|-------|
| `CultivatorPlate` | `ZoneView` | (24, 24), 440x252 | Madra orb is the drain pellets' source. Hidden with the zone view during adventures |
| `ZonePanel` | `ZoneView` | (1456, 24), 440 wide, height hugs its content (176 to 1032) | Zone header, Now strip, activity list |
| `Dock` | `ZoneView` | (722, 976), 476x80 | Four 108x64 buttons. Hidden with the zone view during adventures |
| `GoalsPanel` | `MainView` | Zone view: (24, 272), hung on its cords under the cabinet. Adventure view: root at (1456, 4), body at (1456, 24), cords and hooks hidden | 220 px tall with a quest, 150 with the milestone alone. Not draggable |
| `LogWindow` | `MainView` | Zone view: its 440x204 slot at (24, 852), the board on the slot's bottom edge (screen 1056) growing upward. Adventure view: slot at (24, 24), the board hanging from its top edge | 74 + 26 px per line, up to 5 lines. The full log is a 440x560 board in the same place |
| `QuestToast` | `MainView` | Top-centre, 350x60 at y 28 | `mouse_filter` Ignore; queues messages |
| `DevPanel` | `MainView` | (0, 0), 340x400 | Draggable; see [DEV_TOOLS.md](../tooling/DEV_TOOLS.md) |

## Core Systems

### State machine (`MainView`)

`MainView` (`scenes/ui/main_view/main_view.gd`) owns the machine. `MainViewStateMachine` is only a node that groups the state children. Every state extends `MainViewState` (`states/main_view_state.gd`), which defines `scene_root: MainView` plus `enter()`, `exit()` and `handle_input(event)`, all no-ops by default. `MainView._ready()` assigns `scene_root` on all 9 states and calls `change_state(zone_view_state)`.

| Field / method | Behaviour |
|----------------|-----------|
| `base_current_state` | The base view: `ZoneViewState` (initial) or `AdventureViewState`. Only `change_state()` sets it. |
| `state_stack: Array[MainViewState]` | Overlays above the base. The current state is the top of the stack, or the base when the stack is empty. |
| `push_state(state)` | Appends and calls `state.enter()`. The state underneath is **not** exited and stays visible. |
| `pop_state()` | No-op on an empty stack. Otherwise pops and calls `exit()` on the popped state. The state underneath is **not** re-entered. |
| `remove_state(state)` | No-op if `state` isn't on the stack. Otherwise erases it wherever it sits and calls its `exit()`. States above it stay open. `MerchantViewState` closes this way, so it never pops another view. |
| `change_state(new_state)` | Returns early if `new_state` is already the base. Otherwise it clears the stack **without** calling `exit()` on stacked states, calls `exit()` on the old base, then `enter()` on the new base. |
| `hide_hud_boards(holder)` / `release_hud_boards(holder)` | See [HUD boards](#hud-boards). |
| `goals_panel`, `log_window` | The two shared HUD boards, typed `Control` (a test assigns plain Controls). |
| `_unhandled_input(event)` | Forwards to the current state's `handle_input(event)`. |

In practice at most one overlay is open at a time. Overlay states never push other overlays, and while an overlay is open the GreyBackground covers the dock.

### HUD boards

The log and the Goals board belong to `MainView` because both base views show them; each base state places them.

- `ZoneViewState.enter()` puts the Goals board at `GOALS_POSITION` (24, 272) and the log slot at `LOG_POSITION` (24, 852).
- `AdventureViewState.enter()` saves both positions, moves the log slot to (24, 24) and the Goals root to (1456, 24 − `GoalsPanel.CORDS_HEIGHT`), and calls `GoalsPanel.set_cords_visible(false)`, which also swaps the top slice for the hookless `lacquer_goals_top_plain_ai.png`. `exit()` puts both back and shows the cords. The left side is left to the adventure map's encounter panel.
- Every overlay over the zone view (Inventory, Cycling, Path, Abilities, Character, Merchant) calls `scene_root.hide_hud_boards(self)` in `enter()` and `release_hud_boards(self)` in `exit()`. `MainView` counts the holders: the first one saves each board's visibility and hides it, and the boards get it back only when the last holder releases them, whatever order the overlays close in (the shop can leave from under cycling). The end card does not hide them; its backdrop dims them.

### States

| State | Kind | `enter()` | `exit()` | Input handled | Leaves via |
|-------|------|-----------|----------|---------------|------------|
| `ZoneViewState` | Base (initial) | Shows `ZoneView`. Places the Goals board and the log. Removes the input blocker. Finds `ZoneTransition` and calls `reset_camera()` to undo the adventure zoom. | Removes the input blocker. Hides `ZoneView`. | `open_inventory` → push Inventory; `open_path` → push PathTree; `open_abilities` → push Abilities; `open_character` → push Character. Ignored while the input blocker exists. | `start_adventure` (handled by `AdventureViewState`) |
| `AdventureViewState` | Base | Shows `AdventureView`. Moves the log and the Goals board aside. Connects `AdventureView.adventure_completed`. | Hides `AdventureView`, puts the boards back and disconnects. | None | End card return → `change_state(zone)` |
| `AdventureEndCardState` | Overlay on Adventure | Shows GreyBackground. `AdventureViewState` then calls `show_results()`. | Hides `AdventureEndCard` and GreyBackground. | None (the card's own Return button) | Popped by `AdventureViewState` |
| `InventoryViewState` | Overlay (`BookViewState`) | Hides the HUD boards. Connects the book's close tab, then `grey_background.show_with_panel(inventory_view)` | Disconnects the close tab (the view is already hidden). Releases the HUD boards | `close_inventory` or `open_inventory`, the close tab, or a click on the backdrop outside the book → `hide_with_panel()`. `panel_hidden` (one-shot) → `pop_state()`. | Book close and grey fade-out, whichever ends last |
| `CyclingViewState` | Overlay | Hides the HUD boards. Shows `CyclingView` and GreyBackground. | Hides both. Releases the HUD boards. | `close_cycling_view` → `ActionManager.stop_action()` | `ActionManager.stop_cycling` → `pop_state()` |
| `PathTreeViewState` | Overlay (`BookViewState`) | Same as Inventory | Same | `ui_cancel` or `open_path`, the close tab, or a backdrop click → same close path | Same |
| `AbilitiesViewState` | Overlay (`BookViewState`) | Same | Same | `ui_cancel` or `open_abilities`, the close tab, or a backdrop click → same close path | Same |
| `CharacterViewState` | Overlay (`BookViewState`) | Same | Same | `ui_cancel` or `open_character`, the close tab, or a backdrop click → same close path | Same |
| `MerchantViewState` | Overlay | Hides the HUD boards (the shop would cut their text off), then `show_with_panel(merchant_view)` | Releases the HUD boards | `ui_cancel` → `ActionManager.stop_action()` while a merchant action is current; the Leave button (`MerchantView.close_requested`) does the same | `ActionManager.stop_merchant` → `hide_with_panel()`, then `remove_state(self)` on `panel_hidden`. If another state is above it, it hides `MerchantView` at once and removes itself without the fade. `start_merchant` while it is already on the stack only rebinds the stock |

What each view shows:

| View | Content | Doc |
|------|---------|-----|
| `ZoneView` | Hex zone map at zoom 2 with fog, plates and popovers; cultivator cabinet; zone chest (header, Now strip, activity cards); dock | [ZONES.md](../zones/ZONES.md) |
| `AdventureView` | Adventure hex map, combat view, timer, player info panel | [ADVENTURING.md](../adventuring/ADVENTURING.md), [COMBAT.md](../combat/COMBAT.md) |
| `AdventureEndCard` | Scroll with VICTORY/defeat title, run stats, loot slots, Return button | [ADVENTURING.md](../adventuring/ADVENTURING.md) |
| `InventoryView` | Red book with Equipment, Consumables, Materials and Quest Items tabs | [INVENTORY.md](../inventory/INVENTORY.md) |
| `CyclingView` | Cycling mini-game, technique tabs, resource panel, close button | [CYCLING.md](../cycling/CYCLING.md) |
| `PathTreeView` | Ink-and-gold book: a chapter tab per cultivation stage, the open stage's tree (left-drag pan, wheel zoom), node or path details, active benefits, points | [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) |
| `AbilitiesView` | Jade book: filtered and sorted ability rows, 4-slot loadout, details of the ability pointed at | [ABILITIES.md](../abilities/ABILITIES.md) |
| `CharacterView` | Indigo book: 8 attributes in Physical (STR, BODY, AGI, RES) and Spiritual (SPI, FND, CTRL, WILL) groups, and the attribute pointed at described on the right page | [CHARACTER.md](CHARACTER.md) |
| `MerchantView` | Merchant shop: title and Leave, a wrapping greeting, up to 8 stock rows with price and Buy, then the status line and gold. The gold previews a purchase while Buy is hovered. Its root `theme` is the merchant's zone theme | [FOUNDATION_PLAYTHROUGH.md Beat 4](../progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented) |

### GreyBackground (modal backdrop)

`GreyBackground` (`scenes/ui/grey_background/grey_background.gd`, class `GreyBackground`) is a full-rect `Panel` at z 2. Its stylebox is `assets/styleboxes/zones/grey_background.tres`, a flat slate fill `Color(0.176, 0.216, 0.216, 0.557)`. Because it uses the Panel's default mouse filter it blocks clicks to everything beneath it, including the dock. A left press on the backdrop itself emits `clicked`; the menu books close on it, and other users (the merchant) ignore it. States use it in two ways:

| Mode | Used by | Behaviour |
|------|---------|-----------|
| Direct toggle | Cycling, AdventureEndCard states | `grey_background.visible = true/false`, with no animation |
| Fade orchestration | Inventory, PathTree, Abilities, Character, Merchant states | `show_with_panel(panel)` sets `self_modulate.a = 0`, shows backdrop and panel, plays `grey_fade_in`, and calls `panel.animate_open()` if it exists. `hide_with_panel(panel)` plays `grey_fade_out` and calls `panel.animate_close()` if it exists. It then hides both nodes and emits `panel_hidden` once the grey fade-out has finished and, for a panel with a `close_finished` signal (the menu books), once that panel's own close has finished too. A panel without the signal (the merchant shop) is done when the fade ends. |

### Menu books

The four menus are books (`docs/superpowers/specs/2026-10-21-menu-books-design.md`):

- `BookFrame` (`scenes/ui/book_frame/book_frame.tscn` + `.gd`) is the shared book: the inventory's book spritesheet with its open, close and page-turn animations, the close tab on the top edge of the right page, and the bookmark. The close tab is the side-tab art standing up, showing 22 book px above the page near its corner. Its X is a `CloseGlyph` label in the game font (the same X as the cycling view's "X ESC"), and like the side tabs it has no hover art, tooltip or hand cursor. The bookmark hangs about 27 book px below the page stack, centred at x 583 (between its first spot and the book's right edge). It sits in a `BookmarkClip` whose top is the top page's bottom edge, and once the book lies open it slides down out of it in `BOOKMARK_SLIDE_SECONDS` (0.45 s, ease out), as if pulled from between the pages; it hides at once when the book starts closing. One palette-swap shader (`assets/shaders/palette_swap.gdshader`) recolours the cover edge, the page border line, the turning page and the bookmark from a `BookStyleData` (`scripts/resource_definitions/ui/book_style_data.gd`; one per book in `resources/ui/book_styles/`). The close tab and bookmark only show while the book lies open. A `BookHitArea` over the open book's art, (48, 24)-(652, 432), and the bookmark catch clicks, so only a click outside the book reaches the backdrop and closes it; the transparent margins of the 700 × 450 frame count as outside. Signals: `opened`, `closed`, `close_requested`, `page_turned`.
- `MenuBookView` (`scenes/ui/book_frame/menu_book_view.gd`) is the base script of the four views. `animate_open()` and `animate_close()` drive the `%BookFrame`; the nodes in its `page_content` export are shown only while the book lies open. It re-emits the close tab as `close_requested` and emits `close_finished` when the book has closed. Hooks: `_before_open()`, `_after_open()`, `_before_close()`, `_after_close()`.
- `BookViewState` (`scenes/ui/main_view/states/book_view_state.gd`) is the base of the four states. Subclasses name the view (`_get_view()`) and their close keys (`_is_close_event()`); Esc, the menu's key, the close tab and `GreyBackground.clicked` (connected in `enter()`, disconnected in `exit()`) all call `_request_close()`.
- Inventory keeps its own pages in book units (its text widgets counter-scaled to 0.5). The other three books draw their pages at screen resolution in a `PageLayer`, styled by `assets/themes/book_theme.tres` (see [UI_STYLING.md](../UI_STYLING.md#menu-book-pages)), with the inventory's title ribbon (`TabBanner`), selector (`SortSubBanner`) and side tabs reused at book scale.

### ActionManager-driven transitions

The state scripts connect to `ActionManager` themselves in `_ready()`. `MainView` connects to nothing.

```
Zone action (cycling) ─► ActionManager.start_cycling ─► CyclingViewState: push_state(cycling)
Esc / close button ─► close_cycling_view ─► ActionManager.stop_action() ─► stop_cycling ─► pop_state()
                                                       └─► the zone's idle action resumes

Zone action (merchant) ─► ActionManager.start_merchant ─► MerchantViewState: merchant_view.setup(action); push_state(merchant)
Leave / Esc ─► ActionManager.stop_action() ─► stop_merchant ─► hide_with_panel ─► panel_hidden ─► remove_state(merchant)

Zone action (adventure) ─► ActionManager.adventure_start_requested
   ├─► ZoneViewState: adds a full-rect Control (mouse Stop) to ZoneView and ignores keys
   ├─► MapMarkers: hides the map's plates and glyphs
   └─► ZoneTransition: MadraPellet drain from the cabinet's Madra orb, then camera zoom to 3x
         └─► ActionManager.confirm_adventure_start(data, budget) ─► start_adventure
               ├─► AdventureViewState: change_state(adventure)   (zone exit removes the blocker)
               └─► AdventureView.start_adventure()               (connected after the state)

Run ends ─► ActionManager.stop_action() ─► stop_adventure (the zone's idle action resumes)
   ├─► AdventureViewState: no-op (waits for the result)
   └─► AdventureView.stop_adventure() ─► adventure_completed(result)
         └─► AdventureViewState: push_state(end_card); adventure_end_card.show_results(result)
               └─► Return button ─► close animation ─► return_requested (one-shot)
                     └─► pop_state(); change_state(zone)   (ZoneTransition.reset_camera())
```

`stop_cycling`, `stop_merchant` and `stop_adventure` also fire when `ActionManager.select_action()` replaces the current action, or when `ZoneManager.zone_changed` stops it.

### Input routing

1. `MainGame._input()` runs before the GUI. It handles Ctrl+Shift+D and marks the event handled. `ZonePanel._input()` also sees every left press, to close the lore at the end of the frame when the press lands outside it.
2. GUI controls consume their own events, for example a focused `LineEdit`/`SpinBox`, button clicks and `gui_input` handlers.
3. `_unhandled_input` reaches the nodes in reverse tree order, then `MainView`:
   - `LogWindow` (while visible): L (`toggle_log`) opens or closes the full log; Escape closes it while open.
   - `ZonePanel`: Escape closes the lore, only while it shows and `ZoneViewState` is MainView's current state, so an overlay opened over the zone view takes Escape first.
   - Inside the zone SubViewport, `MapMarkers`: Escape closes a pinned map popover, only while `ZoneViewState` is current with no overlay pushed and the full log is closed. The `SubViewportContainer` hands keys to the SubViewport at its own place in this pass (after `LogWindow` and `ZonePanel`, which sit later in the tree), and the SubViewport has `handle_input_locally` off, so its `set_input_as_handled()` ends the event for `MainView` too. One Escape therefore closes the lore before the popover.
   - `MainView` (routed to the current state only), the combat `AbilitiesPanel` (Q/W/E/R while visible), and the camera controllers inside the tilemaps (zoom on both maps, pan on the zone map only).

Escape is bound to three actions: `close_inventory`, `close_cycling_view` and the built-in `ui_cancel`. Inside the state machine they never conflict because only the top state reads input. Menu shortcuts work only while `ZoneViewState` is current. `AdventureViewState.handle_input()` is empty, so I/A/C/P do nothing during an adventure; L still opens the full log.

### Keybindings

Project actions from `project.godot` `[input]`. Key bindings use physical key positions (QWERTY labels) unless noted.

| Action | Binding | Handled by | Effect |
|--------|---------|------------|--------|
| `open_inventory` | I | `ZoneViewState`, `InventoryViewState` | Open inventory / close inventory |
| `close_inventory` | I, Escape | `InventoryViewState` | Close inventory (book animation, then pop) |
| `open_path` | P | `ZoneViewState`, `PathTreeViewState` | Open / close path tree |
| `open_path_tree` | P | Nothing | Unused duplicate of `open_path` |
| `open_abilities` | A | `ZoneViewState`, `AbilitiesViewState` | Open / close abilities view |
| `open_character` | C | `ZoneViewState`, `CharacterViewState` | Open / close character view |
| `toggle_log` | L | `LogWindow._unhandled_input()`, while the log is visible | Open / close the full log ([LOGGING.md](LOGGING.md#logwindow)) |
| `close_cycling_view` | Escape | `CyclingViewState` (the cycling close button fires the same action) | `ActionManager.stop_action()` |
| `center_zone_map_camera` | Space | Nothing | Unused, no script reads it |
| `ability_slot_1` to `ability_slot_4` | Q, W, E, R | `AbilitiesPanel._unhandled_input()` (`scenes/ui/combat/abilities_panel.gd`), only while the panel is visible | Emits `ability_selected` for that slot's ability when its button is enabled. `CombatantInfoPanel` re-emits it, and `AdventureView` connects it to `AdventureCombat.on_player_ability_selected()`. |
| `dialogic_default_action` | Enter, Space, X (logical keys), left mouse button, joypad button 0 | Dialogic addon (its plugin adds this action) | Advance dialogue |

Other inputs:

| Input | Handled by | Effect |
|-------|------------|--------|
| Escape (built-in `ui_cancel`) | `PathTreeViewState`, `AbilitiesViewState`, `CharacterViewState`, `MerchantViewState`; `LogWindow`, `ZonePanel`, `MapMarkers` outside the state machine | Close the overlay (the merchant does it by stopping its action); close the full log, the zone lore or the pinned map popover |
| Ctrl+Shift+D (`KEY_D`, logical) | `MainGame._input()` | Dev password modal or dev panel toggle. No-op unless `user://dev_password.txt` exists. See [DEV_TOOLS.md](../tooling/DEV_TOOLS.md). |
| Right mouse drag | `CameraPanController` on the zone tilemap camera only (the adventure camera follows the player and has no pan controller) | Pan the zone map |
| Mouse wheel | `CameraZoomController`: zone 1.0 to 2.0 (default 2.0), adventure 0.3 to 1.3 (default 1.0); over the zone chest's list it scrolls the list instead | Zoom |
| Left drag / wheel in path tree | `PathTreeView._on_tree_area_gui_input()` | Pan / zoom the tree |

### Dock and SystemMenuButton

`Dock` (`scenes/ui/dock/dock.tscn` + `dock.gd`, class `Dock`) is the lacquer kit's 476x80 recessed shelf (§5.4), a child of `ZoneView` at (722, 976), so it exists only on the zone map. It holds four `SystemMenuButton`s at x 10, 126, 242 and 358 inside the shelf (Inventory, Abilities, Character, Path) and decides which are notified:

- **Path:** the brass ring and a cinnabar count seal (`lacquer_seal_count_ai`, over the top-left corner) while `PathManager.get_point_balance() > 0`, read in `_ready()` and on `points_changed`. This is how the game announces path points.
- **Abilities:** the ring with no count while `AbilityManager.has_unequipped_unlocks()`, refreshed on `ability_unlocked` and `equipped_abilities_changed`.
- Both are read again on `PersistenceManager.save_data_reset`.

Gold left the bar for the cultivator cabinet.

`SystemMenuButton` (`scenes/ui/dock/system_menu_button/system_menu_button.tscn` + `.gd`) is a 108x64 lacquer button configured by one export, `menu_type: MenuType`. `MENU_CONFIG` maps each value:

| `MenuType` | Value | Label | Shortcut hint | Input action | Icon (shown at 32x32) |
|------------|-------|-------|---------------|--------------|------------------------|
| `INVENTORY` | 0 | Inventory | I | `open_inventory` | `assets/sprites/ui/system_menu/inventory_icon.png` (16 px, at 2x) |
| `ABILITIES` | 1 | Abilities | A | `open_abilities` | `assets/ui/lacquer/lacquer_ic_abilities_ai.png` |
| `CHARACTER` | 2 | Character | C | `open_character` | `assets/sprites/ui/system_menu/character_icon.png` (64 px, at half size) |
| `PATH` | 3 | Path | P | `open_path` | `assets/sprites/ui/system_menu/star_icon.png` (64 px, at half size) |

- **Press:** builds an `InputEventAction` (`action`, `pressed = true`), calls `Input.parse_input_event()`, then sends the matching release, so the action is not left held. The press follows the same path as a key press, ending in `ZoneViewState.handle_input()`.
- **Faces:** exactly one shows: `lacquer_btn_hover_ai` while hovered, else `lacquer_btn_ring_ai` while notified, else `lacquer_btn_ai`.
- **Notification API:** `set_notification(active, count = 0)`, `has_notification()`, `get_notification_count()`. The count seal shows only for a count above zero.

### Shared widgets

| Widget | Files | Used by | API / behaviour |
|--------|-------|---------|-----------------|
| `FloatingText` | `scenes/ui/floating_text/floating_text.tscn` + `.gd` | `CyclingTechnique` (XP popups), `ResourceBar` and `ResourceOrb` (combat vitals deltas; per-bar `show_floating_text` export) | `show_text(text, color, pos, trajectory = Vector2(0, -100))`. Moves along the trajectory over 1.5 s (cubic ease-out). In parallel it fades out over 1.5 s after a 0.45 s delay, then frees itself. The label is `LabelSubheading` with a white fill and 5 px black outline. |
| `FlyingParticle` | `scenes/ui/flying_particle/flying_particle.gd` (script only, created with `FlyingParticle.new()`) | `CyclingView` (Madra/XP particles) | `launch(start, target, color, duration = 0.6, size = 5.0, on_arrive = Callable(), curve_spread = 60.0, curve_bias = 0.0)`. Quadratic bezier with ease-in and an 8-point fading trail, drawn with `draw_circle`. Calls `on_arrive`, then frees itself. The zone view's adventure drain uses `MadraPellet` instead ([ZONES.md](../zones/ZONES.md#adventure-start-zone-side)). |
| `TickProgressBar` | `scenes/ui/tick_progress_bar/tick_progress_bar.tscn` + `.gd` | Nothing (the Now strip replaced it on the training card) | `set_progress(current, total)` (`total <= 0` clears it), `set_fill_color(color)`, `flash_and_reset(flash_color, duration = 0.3)`. 2 px bar with 9 gradation marks (10% to 90%) and a `LabelSmall` counter (12 px override) to the right of the bar. |
| `InkbrushButton` | `scenes/ui/inkbrush_button/inkbrush_button.tscn` + `.gd` | Nothing (unused) | `TextureButton` with a random `action_button_1..3.png` texture and a `zone_action_button.gdshader` fill on hover. `setup(label, texture, fill_color)`. |
| `GreyBackground` | `scenes/ui/grey_background/grey_background.gd` | Main view states | See [GreyBackground](#greybackground-modal-backdrop) |
| `LogWindow` | `scenes/ui/log_window/` | `MainView` | Placement only here. It listens to `LogManager.message_logged` and `visibility_toggled` and reads `LogManager.get_history()`. See [LOGGING.md](LOGGING.md). |
| `GoalsPanel`, `QuestToast` | `scenes/ui/goals_panel/`, `scenes/ui/quest_toast/` | `MainView` | Placement only here. See [QUESTS.md](../progression/QUESTS.md). |
| Lacquer pieces | `scenes/common/lacquer/` (`LacquerStripRect`, `LacquerRod`, `LacquerFrameOverlay`), `scenes/zones/zone_panel/lacquer_rail/` (`LacquerRail`) | Zone view panels, Goals and log boards | See [UI_STYLING.md](../UI_STYLING.md#lacquer-theme-zone-view) |

Utilities:

| Script | Status |
|--------|--------|
| `scripts/utils/theme_constants.gd` (`ThemeConstants`) | Colour palette and size constants for code. Referenced: `ACCENT_GOLD`, `BORDER_PRIMARY`, `BG_MEDIUM` and the `LACQUER_*` colours. See [UI_STYLING.md](../UI_STYLING.md#code-side-constants-themeconstants). |
| `scripts/utils/lacquer_text.gd` (`LacquerText`) | `rate()` and `decimal_bbcode()` for lacquer text. See [UI_STYLING.md](../UI_STYLING.md#lacquer-theme-zone-view). |
| `scripts/utils/text_effect_importer.gd` | A `Node` with `@export var _text_effect_scripts: Array[Script]` and `get_text_effect_instances()`, which instantiates each script as a `RichTextEffect`. Not referenced by any scene or script. |

### Project settings (`project.godot`)

| Setting | Value |
|---------|-------|
| `config/features` | `"4.7", "Forward Plus"` (feature tags only) |
| Renderer | `rendering_method = "gl_compatibility"` (desktop and mobile) |
| Main scene | `uid://dyrsbe5x01lgo` = `res://scenes/main/main_game/main_game.tscn` |
| Window | 1920x1080 viewport, `stretch/mode = "viewport"` |
| Texture filter | `default_texture_filter = 0` (Nearest, for pixel art). The zone `SubViewport` sets its own `canvas_item_default_texture_filter = 0` too |
| Project theme | `gui/theme/custom = uid://yqkvsb5q7pab` = `res://assets/themes/pixel_theme.tres`. `MainView`, `AdventureView` and several sub-scenes also set it explicitly. The zone-view panels and the HUD boards set `assets/themes/lacquer/lacquer_theme.tres` on their roots |
| Autoloads (18, in order) | PersistenceManager, CultivationManager, EventManager, CharacterManager, UnlockManager, ResourceManager, ZoneManager, ActionManager, InventoryManager, Dialogic, DialogueManager, PlayerManager, LogManager, CyclingManager, AbilityManager, PathManager, QuestManager, MerchantManager |
| Enabled editor plugins | AsepriteWizard, ResourcePlus, dialogic, godot_context_exporter, gut. `hexagon_tilemaplayer` and `script-ide` are installed but not enabled (script-ide was disabled in `39f1817`). |

Autoload order matters. Signal handlers run in connection order, and each manager connects in `_ready()`, so for example `CultivationManager` reacts to `PersistenceManager.save_data_reset` before `EventManager` does.

## Integration Points

| System | Connection |
|--------|------------|
| ActionManager | `start_cycling`/`stop_cycling` → `CyclingViewState` push/pop. `start_merchant`/`stop_merchant` → `MerchantViewState` push / fade and remove. `adventure_start_requested` → `ZoneViewState` input blocker plus `ZoneTransition` drain. `start_adventure` → `AdventureViewState.change_state()`. `stop_action()` called by `CyclingViewState` and `MerchantViewState`. |
| AdventureView | `adventure_completed(result)` → end card push. `is_in_combat`, `force_win_combat()` and `set_show_whole_map()` are used by the dev panel. |
| AdventureEndCard | `show_results(result)`, `return_requested` → pop + `change_state(zone)` |
| InventoryView / PathTreeView / AbilitiesView / CharacterView | `MenuBookView`: `animate_open()` / `animate_close()` called through `GreyBackground`; `close_requested` (close tab) → the state's close path; `close_finished` → `GreyBackground` finishes hiding |
| MerchantView | `animate_open()` / `animate_close()`, called through `GreyBackground` |
| ZoneTransition | `reset_camera()` on zone enter. Calls `ActionManager.confirm_adventure_start()` after the drain. |
| GoalsPanel | Placed by `ZoneViewState` and `AdventureViewState`; `set_cords_visible()` in adventures; hidden under overlays |
| ResourceManager | `CultivatorPlate` gold row (`gold_changed`, `get_gold()`) |
| PathManager | `Dock` Path count seal (`points_changed`, `get_point_balance()`) |
| AbilityManager | `Dock` Abilities ring (`ability_unlocked`, `equipped_abilities_changed`, `has_unequipped_unlocks()`) |
| PersistenceManager | `SaveTimer` calls `save_data()` every 5 s |
| LogManager / Log | `LogWindow` shows `message_logged` and the history. `MainGame.log_print_level` → `Log.set_print_level()`. See [LOGGING.md](LOGGING.md). |
| Dev tools | `MainGame` owns the Ctrl+Shift+D gate for `DevPasswordModal`/`DevPanel` ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/main/main_game/main_game.tscn` | Entry scene, full UI tree |
| `scenes/main/main_game/main_game.gd` | Dev hotkey gate, `log_print_level` export |
| `scenes/main/main_game/save_timer.gd` | 5 s autosave |
| `scenes/ui/main_view/main_view.gd` | `MainView`: state stack, `push_state`/`pop_state`/`remove_state`/`change_state`, HUD board hiding, input routing |
| `scenes/ui/main_view/states/main_view_state.gd` | `MainViewState` base class |
| `scenes/ui/main_view/states/*.gd` | Zone, Adventure, AdventureEndCard, Inventory, Cycling states |
| `scenes/path_progression/path_tree_view_state.gd` | Path tree overlay state |
| `scenes/abilities/abilities_view_state.gd` | Abilities overlay state |
| `scenes/character/character_view_state.gd` | Character overlay state |
| `scenes/merchant/merchant_view_state.gd`, `merchant_view.tscn` | Merchant shop overlay state and view |
| `scenes/ui/grey_background/grey_background.gd` | Modal backdrop and fade orchestration |
| `scenes/ui/book_frame/book_frame.tscn`, `book_frame.gd`, `menu_book_view.gd` | Shared menu book and the menu views' base script |
| `scenes/ui/main_view/states/book_view_state.gd` | Base state of the four menu books (also hides the HUD boards while a book is open) |
| `scenes/ui/dock/dock.tscn`, `dock.gd` | Bottom navigation dock and its notifications |
| `scenes/ui/dock/system_menu_button/system_menu_button.gd` / `.tscn` | `SystemMenuButton` and `MenuType` config |
| `scenes/ui/goals_panel/goals_panel.gd` / `.tscn` | Goals board |
| `scenes/ui/log_window/log_window.gd` / `.tscn` | Log board and full log |
| `scenes/zones/zone_transition/zone_transition.gd` | Adventure-entry drain and zoom; camera reset |
| `scenes/ui/floating_text/`, `scenes/ui/flying_particle/`, `scenes/ui/tick_progress_bar/` | Shared feedback widgets |
| `project.godot` | Autoloads, input map, window, renderer, theme |

## Work Remaining

### Bugs

- `[MEDIUM]` The grey backdrop goes invisible after a faded panel closes. `GreyBackground.hide_with_panel()` ends `grey_fade_out` with `self_modulate.a = 0`, and nothing resets it. `CyclingViewState.enter()` and `AdventureEndCardState.enter()` only set `visible = true`. After a menu book or the Merchant view has been opened and closed once, the backdrop behind Cycling and the end card no longer dims the screen, though it still blocks clicks. The menu books are not affected: they open through `show_with_panel()`. Found by reading the code; not reproduced in-game.

### Missing Functionality

- `[LOW]` `center_zone_map_camera` (Space) is declared in `project.godot` but no script reads it, so Space does nothing on the zone map. Clicking the current zone's hex recentres the camera.
- `[LOW]` `open_path_tree` (P) duplicates `open_path` and is never read.
- `[LOW]` I/A/C/P are ignored during adventures because `AdventureViewState.handle_input()` is empty. It is unconfirmed whether this is intended.

### UI

- `[LOW]` Overlays use two transition styles. Cycling and the end card toggle the backdrop instantly; the menu books and the merchant fade it through `GreyBackground.show_with_panel()`/`hide_with_panel()`. The zone-action pop-ups are the next consistency pass ("menus are books, action pop-ups are scrolls").
- `[LOW]` `FloatingText._ready()` sets its size with `add_theme_constant_override("font_size", FONT_SIZE)`. Font sizes need `add_theme_font_size_override`, so `FONT_SIZE` never applies and the size comes from `LabelSubheading` (24 px). The script also uses `$Label` instead of `%Label`.
- `[LOW]` The dock's Path count uses `LabelLacquerSeal`, whose 1 px letter spacing makes a two-digit count ("12") 1 px wider than the mock. A single digit matches.

### Tech Debt

- `[LOW]` `MainView.change_state()` clears `state_stack` without calling `exit()` on stacked overlays. This is only safe because no overlay can be open when the base changes: `ZoneViewState` blocks input during the adventure transition, and the end card is popped first. An overlay skipped this way would also never release the HUD boards.
- `[LOW]` `CyclingViewState._on_stop_cycling()` pops whatever state is on top, not specifically the cycling state.
- `[LOW]` `CyclingView._on_close_button_pressed()` sends a pressed `InputEventAction` with no matching release event.
- `[LOW]` Dead code:
  - `InkbrushButton` has no references. It uses the root-level placeholder `res://32.png`, untyped constants, functions without return types, and `$MarginContainer/...` paths.
  - `TickProgressBar` has no references since the lacquer training card replaced its footer.
  - `scripts/utils/text_effect_importer.gd` has no references, no `class_name` and no doc comment.
- `[LOW]` Some nodes are created in code despite the scene-tree UI rule: the `ZoneViewState._add_input_blocker()` `Control.new()`, and `FlyingParticle`, which has no `.tscn`.
- `[LOW]` Stale doc comments:
  - The `MainView` class comment lists 4 views; there are 9 states.
  - `TickProgressBar` says the counter is "below the bar"; the scene places it to the right.
- `[LOW]` `MainGame.log_print_level` is set to `0` (`Log.Event.INFO`) in `main_game.tscn`; the script default is `DEBUG`. `Log.Event` orders `INFO`(0) before `DEBUG`(1), so INFO prints every level and DEBUG would hide INFO lines (see [LOGGING.md](LOGGING.md)).
- `[LOW]` `project.godot` mismatches:
  - `[dialogic] extensions_folder = "res://addons/dialogic_additions"` points to a folder that does not exist.
  - `config/features` lists "Forward Plus" while the renderer is `gl_compatibility`.
