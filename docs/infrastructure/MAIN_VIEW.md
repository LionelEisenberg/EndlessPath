# Main View (UI Shell and Navigation)

## Overview

`main_game.tscn` is the only runtime scene. It hosts every full-screen view (zone map, adventure, inventory, cycling, path tree, abilities, character, merchant shop, Tribulation board, adventure end card), the HUD boards (the log and the Goals board; the merchant shop hides them while open, the Tribulation steps them off the screen, cycling leaves them showing, the menu books leave them under the backdrop), and the dev tools. `MainView` decides which views are visible through a small state machine. There is one **base state**, Zone or Adventure. Modal **overlay states** are pushed on a stack above it.

- Menu overlays (Inventory, Path, Abilities, Character) open from the keyboard or the dock at the bottom of the zone view. Both routes produce the same input action. All four are books built on one shared `BookFrame` scene and open and close the same way (see [Menu books](#menu-books)).
- Cycling, the merchant shop, the Tribulation, adventures and the end card are driven by `ActionManager` and `AdventureView` signals.
- Cycling and the Tribulation are the overlays with no backdrop. Their boards sit in the map gap with the zone view up around them, and open and close through one reversible transition, `MainView.open_board()` and `close_board()` (see [Board transitions](#board-transitions)). What each board takes from the zone view is under [Cycling mode](#cycling-mode) and [Tribulation board](#tribulation-board).
- Only the top state receives input. Everything else that reads input (the full log on L, the zone chest's lore and the map popover on Escape, combat hotkeys, camera pan/zoom, the dev hotkey, Dialogic) is handled outside the state machine.

The zone view itself (map, cultivator cabinet, zone chest) is documented in [ZONES.md](../zones/ZONES.md). Related docs: [UI_STYLING.md](../UI_STYLING.md) (themes, including the lacquer theme), [DEV_TOOLS.md](../tooling/DEV_TOOLS.md) (dev panel), [TESTING.md](../testing/TESTING.md).

## Architecture

### Scene tree (`scenes/main/main_game/main_game.tscn`)

```
MainGame (Node2D)                          main_game.gd: Log print level, the playtime tick
├── MainView (Control, 1920x1080)          main_view.gd (class MainView): state stack, input routing, HUD board hiding, the map-gap boards' open and close
│   │                                      theme = pixel_theme.tres, mouse_filter = Ignore
│   ├── MainViewStateMachine (Node)        no script; container for the 10 state nodes
│   │   ├── AdventureViewState             scenes/ui/main_view/states/adventure_view_state.gd
│   │   ├── InventoryViewState             scenes/ui/main_view/states/inventory_view_state.gd
│   │   ├── ZoneViewState                  scenes/ui/main_view/states/zone_view_state.gd
│   │   ├── CyclingViewState               scenes/ui/main_view/states/cycling_view_state.gd
│   │   ├── AdventureEndCardState          scenes/ui/main_view/states/adventure_end_card_state.gd
│   │   ├── PathTreeViewState              scenes/path_progression/path_tree_view_state.gd
│   │   ├── AbilitiesViewState             scenes/abilities/abilities_view_state.gd
│   │   ├── CharacterViewState             scenes/character/character_view_state.gd
│   │   ├── MerchantViewState              scenes/merchant/merchant_view_state.gd
│   │   └── TribulationViewState           scenes/tribulation/tribulation_view_state.gd
│   ├── ZoneView (Control)                 base view; hidden while adventuring
│   │   ├── ZoneTransition (Node)          zone_transition.gd: Madra pellet drain + camera zoom into adventures
│   │   ├── SubViewportContainer           1920x1080, centred
│   │   │   └── SubViewport                transparent bg, always updates, Nearest texture filter; %SubViewport
│   │   │       └── ZoneTilemap            zone_tilemap.tscn (hex map, fog, camera, player, MapMarkers); %ZoneTilemap
│   │   ├── CultivatorPlate                cultivator_plate.tscn: Madra, Core Density, gold (top left); %CultivatorPlate
│   │   ├── ZonePanel                      zone_panel.tscn: the zone chest (top right); %ZonePanel
│   │   └── Dock                           dock.tscn: four SystemMenuButtons (bottom centre); %Dock
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
│   ├── CyclingView             z 3        cycling_view.tscn (the board in the map gap; no backdrop)
│   ├── TribulationView         z 3        tribulation_view.tscn (the board in the map gap; no backdrop; hidden by default)
│   ├── BoardTransition         z 9        board_transition.tscn (class BoardTransition): opens and closes the map-gap boards; full rect, mouse Ignore at rest; %BoardTransition
│   ├── ViewDissolve            z 9        view_dissolve.tscn (full-rect still of the old view, hidden by default)
│   └── DevPanel                z 10       dev_panel.tscn: covers the screen and ignores the mouse; its body, a draggable board of tabs, is closed until Ctrl+Shift+D
└── SaveTimer (Timer)                      save_timer.gd: 5 s, autostart → PersistenceManager.autosave()
```

The cabinet, the chest, the dock, the log and the Goals board take their places from their own scenes' roots. Their instances in `main_game.tscn` are in Anchors layout mode with top-left anchors. Don't switch them to Position mode: setting Position mode snaps a control to its parent's top-left corner, and an editor save drops the offsets that used to put it back, so every panel lands at (0, 0). `test_main_game_layout.gd` checks the places, also after an editor save. The adventure's vitals cabinet, chest and technique dock are instanced the same way in `adventure_view.tscn`, for the same reason (`test_adventure_view_layout.gd`).

Draw order is controlled by `z_index`. LogWindow and GoalsPanel (z 1) sit under the GreyBackground (z 2), so the backdrop of the end card and of the menu books dims them; the merchant shop hides them outright, the Tribulation steps them off the screen, and cycling, which has no backdrop, leaves them as they are (see [HUD boards](#hud-boards)). QuestToast and the dev tools (z 10) draw above every modal. `ViewDissolve` (z 9) draws over every view while it dissolves one into the next, under the toast and the dev tools. Which Control takes a click follows tree order, not `z_index`, so `BoardTransition`, whose shield must take the clicks on a moving board, comes after the boards and before `DevPanel`.

### HUD placement

| Node | Parent | Placement (1920x1080) | Notes |
|------|--------|-----------------------|-------|
| `CultivatorPlate` | `ZoneView` | (24, 24), 440x252 | Madra orb is the drain pellets' source and the cycling Madra pellets' target; the Core orb is the cycling XP pellets' target. Hidden with the zone view during adventures |
| `ZonePanel` | `ZoneView` | (1456, 24), 440 wide, height hugs its content (176 to 1032) | Zone header, Now strip, activity list (the technique list while cycling) |
| `Dock` | `ZoneView` | (722, 976), 476x80 | Four 108x64 buttons. Hidden with the zone view during adventures. Stepped off the bottom of the screen, then hidden, while the cycling or Tribulation board is up |
| `VitalsPlate` | `AdventureView` | (24, 24), 440x252 | The adventure's cabinet, where `CultivatorPlate` stands in the zone view: Health, Madra, Stamina and, in a fight, buffs |
| `AdventureChest` | `AdventureView` | (1456, 24), 440 wide, height hugs its page and its title's lines (176 minimum) | Where `ZonePanel` stands: title (it wraps), run clock, the expedition page. The page and its Here tray and drawers wrap their text and grow |
| `TechniqueDock` | `AdventureView` | (722, 856), 476x200 | The four technique slots under a row of four consumable sockets (the hotbar's); its cast tray sits 52 px above it (44 px tall, 8 px clear of the dock) and grows upward when a long technique name wraps |
| `GoalsPanel` | `MainView` | (24, 276), hung on its cords under the cabinet (the 24 px cords reach 4 px above the root, to the cabinet's rings at y 272), in the zone view and in adventures (under the vitals cabinet) | 220 px tall with both rows, 150 with the milestone alone, 146 with the quest alone, when each text is one line; a wrapped line adds its height and the board grows with its rows. With neither row it hides everything but its root, which stays `MainView`'s to show and hide. Not draggable |
| `LogWindow` | `MainView` | Its 440x204 slot at (24, 852), the board on the slot's bottom edge (screen 1056) growing upward, in both base views | 74 + 26 px per line, up to 5 lines. The full log is a 440x560 board in the same place |
| `QuestToast` | `MainView` | Top-centre, 350x60 at y 28 | `mouse_filter` Ignore; queues messages |
| `DevPanel` | `MainView` | Covers the screen; its body starts at (24, 24), 560x680 at least | Only the body takes the mouse, and it is draggable and always wholly on screen. The time-speed badge sits at the top right, and the warning that saving is off at the top centre. See [DEV_TOOLS.md](../tooling/DEV_TOOLS.md#dev-panel) |

## Core Systems

### State machine (`MainView`)

`MainView` (`scenes/ui/main_view/main_view.gd`) owns the machine. `MainViewStateMachine` is only a node that groups the state children. Every state extends `MainViewState` (`states/main_view_state.gd`), which defines `scene_root: MainView` plus `enter()`, `exit()` and `handle_input(event)`, all no-ops by default. `MainView._ready()` assigns `scene_root` on all 10 states, hands the cabinet to the `CyclingView` (it leaves a view that is not a `CyclingView` alone), finds and binds the board transition (see [Board transitions](#board-transitions)) and calls `change_state(zone_view_state)`. `MainViewState` also holds the full-log block, shared by the menu books, cycling and the Tribulation.

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
| `cultivator_plate`, `zone_panel`, `dock`, `zone_map_viewport` | The zone view's cabinet, chest, dock and map SubViewport (`%CultivatorPlate`, `%ZonePanel`, `%Dock`, `%SubViewport`). A board in the map gap takes the last three over (cycling all three, the Tribulation the dock and the map); the cabinet goes to the `CyclingView`. |
| `tribulation_view`, `tribulation_view_state` | The Tribulation board (`%TribulationView`, a `TribulationView`) and its state. |
| `board_transition` | The `BoardTransition` (`%BoardTransition`), found and bound in `_ready()`, or null on the `MainView`s the view-state tests build, which never run `_ready()`. See [Board transitions](#board-transitions). |
| `open_board(spec)` / `close_board(spec, on_closed)` | Open and close the board a `BoardTransitionSpec` describes, through the transition, or at once without one. See [Board transitions](#board-transitions). |
| `is_board_moving()` / `is_board_closing()` | True while a board opens or closes / closes. Always false without a transition. |
| `set_board_mode(on)` | Hides the dock and the chest's About (`ZonePanel.set_board_mode(on)`, which closes the lore) and turns the map's SubViewport input off for a board in the map gap, or gives them back. Each piece is skipped when missing. Only the instant open and close, without a transition, call it. |
| `_unhandled_input(event)` | Forwards to the current state's `handle_input(event)`. |

In practice at most one overlay is open at a time. Overlay states never push other overlays, and while an overlay is open the GreyBackground covers the dock (cycling and the Tribulation hide the dock instead).

### HUD boards

The log and the Goals board belong to `MainView` because both base views show them. `ZoneViewState` places them, and `AdventureViewState` leaves them where they are.

- `ZoneViewState.enter()` puts the Goals board at `GOALS_POSITION` (24, 276), 4 px under the kit's 272 so the cords between the cabinet and the board read, and the log slot at `LOG_POSITION` (24, 852).
- `AdventureViewState` moves nothing and hides no cords: the adventure's vitals cabinet, chest and technique dock stand where the zone view's cabinet, chest and dock stand, so the Goals board stays under the cabinet with its cords showing and the log stays at the bottom left. `GoalsPanel.set_cords_visible()` and `top_without_hooks` (the hookless `lacquer_goals_top_plain_ai.png`) have no caller in the game now, only `test_goals_panel.gd`.
- The merchant shop calls `scene_root.hide_hud_boards(self)` in `enter()` and `release_hud_boards(self)` in `exit()`. The Tribulation's board transition steps the two boards off the left edge of the screen and back instead (see [Board transitions](#board-transitions)); only its instant open and close, without a transition, hide and release them, through `spec.holder`. `MainView` counts the holders: the first one saves each board's visibility and hides it, and the boards get it back only when the last holder releases them, whatever order the overlays close in. Cycling no longer holds them (its board sits beside them), so `FakeCoveringState` in `test_view_state_hud_positions.gd` stands in for a second holder in the counting tests.
- The menu books (`BookViewState`: Inventory, Abilities, Character, Path) and the end card do not hide them: the backdrop dims them with the rest of the view. A book covers the right end of the Goals board (its count and the end of its bar: from x 300 where the Inventory and Path tabs hang, from x 360 for the other two) and, once the log shows two lines or more, the log's top-right corner (the book ends near y 940). The boards stay under a book like the cabinet and the zone chest. The full log does not stay open: `BookViewState.enter()`, `CyclingViewState.enter()` and `TribulationViewState.enter()` close it if it is open and block it (through `MainViewState`, which calls `LogWindow.set_full_log_blocked(true)`), and `exit()` lifts the block. While a book, the cycling board or the Tribulation board is open L does nothing, so the first Escape always reaches it (`LogWindow` gets `_unhandled_input` before `MainView`).

### States

| State | Kind | `enter()` | `exit()` | Input handled | Leaves via |
|-------|------|-----------|----------|---------------|------------|
| `ZoneViewState` | Base (initial) | Shows `ZoneView`. Places the Goals board and the log. Removes the input blocker. Finds `ZoneTransition` and calls `reset_camera()` to undo the adventure zoom. | Removes the input blocker. Hides `ZoneView`. | `open_inventory` → push Inventory; `open_path` → push PathTree; `open_abilities` → push Abilities; `open_character` → push Character. Ignored while the input blocker exists. | `start_adventure` (handled by `AdventureViewState`) |
| `AdventureViewState` | Base | Shows `AdventureView`. Connects `AdventureView.adventure_completed`. The log and the Goals board stay where they are. | Hides `AdventureView` and disconnects. | None | End card return → `change_state(zone)`. Both ways in and out play `ViewDissolve` first. |
| `AdventureEndCardState` | Overlay on Adventure | Shows GreyBackground. `AdventureViewState` then calls `show_results()`. | Hides `AdventureEndCard` and GreyBackground. | None (the card's own Return button) | Popped by `AdventureViewState` |
| `InventoryViewState` | Overlay (`BookViewState`) | Connects the book's close tab and the backdrop click, then `grey_background.show_with_panel(inventory_view)`. The HUD boards stay under the backdrop; the full log is closed and blocked | Disconnects the close tab and the backdrop click (the view is already hidden), and lifts the full-log block | `close_inventory` or `open_inventory`, the close tab, or a click on the backdrop outside the book → `hide_with_panel()`. `panel_hidden` (one-shot) → `pop_state()`. | Book close and grey fade-out, whichever ends last |
| `CyclingViewState` | Overlay | Blocks the full log, then `open_board()` with a spec that swaps the chest ([Board transitions](#board-transitions)). No backdrop; the HUD boards stay | Lifts the full-log block. The close has already given the board, the chest, the dock and the map back | `close_cycling_view` → `ActionManager.stop_action()`. Nothing while the board closes | `ActionManager.stop_cycling` → `close_board()`, and `remove_state(self)` when the close ends. `start_cycling` pushes the state only if it is not on the stack; while it is (the board closing), it turns the close around |
| `PathTreeViewState` | Overlay (`BookViewState`) | Same as Inventory | Same | `ui_cancel` or `open_path`, the close tab, or a backdrop click → same close path | Same |
| `AbilitiesViewState` | Overlay (`BookViewState`) | Same | Same | `ui_cancel` or `open_abilities`, the close tab, or a backdrop click → same close path | Same |
| `CharacterViewState` | Overlay (`BookViewState`) | Same | Same | `ui_cancel` or `open_character`, the close tab, or a backdrop click → same close path | Same |
| `MerchantViewState` | Overlay | Hides the HUD boards (the shop would cut their text off), then `show_with_panel(merchant_view)` | Releases the HUD boards | `ui_cancel` → `ActionManager.stop_action()` while a merchant action is current; the Leave button (`MerchantView.close_requested`) does the same | `ActionManager.stop_merchant` → `hide_with_panel()`, then `remove_state(self)` on `panel_hidden`. If another state is above it, it hides `MerchantView` at once and removes itself without the fade. `start_merchant` while it is already on the stack only rebinds the stock |
| `TribulationViewState` | Overlay | Blocks the full log, then `open_board()` with a spec that moves the HUD boards ([Board transitions](#board-transitions)). No backdrop | `tribulation_view.close()` (the board hides; a run in progress is dropped and nothing of it is applied), lifts the full-log block. The close has already given the HUD boards, the dock and the map back | `ui_cancel` → `view.cancel()` (the intro only); every other event → `view.handle_press_event()` (`tribulation_press`). While the board opens only `ui_cancel`, and nothing while it closes. The view judges its own mouse presses | `ActionManager.stop_tribulation` → `tribulation_view.halt()`, `close_board()`, and `remove_state(self)` when the close ends (not `pop_state()`, so a view above it stays open). `start_tribulation` sets the view up (`setup(action.tribulation, zone name)`) and pushes the state only if it is not on the stack; while it is (the board closing), it turns the close around |

What each view shows:

| View | Content | Doc |
|------|---------|-----|
| `ZoneView` | Hex zone map at zoom 2 with fog, plates and popovers; cultivator cabinet; zone chest (header, Now strip, activity cards); dock | [ZONES.md](../zones/ZONES.md) |
| `AdventureView` | Adventure hex map with its coins, the combat view, the vitals cabinet, the chest (run clock, Here tray, choice drawers, Run ledger) and the technique dock | [ADVENTURING.md](../adventuring/ADVENTURING.md), [COMBAT.md](../combat/COMBAT.md) |
| `AdventureEndCard` | Scroll with VICTORY/defeat title, run stats, loot slots, Return button | [ADVENTURING.md](../adventuring/ADVENTURING.md) |
| `InventoryView` | Red book with Equipment, Consumables, Materials and Quest Items tabs | [INVENTORY.md](../inventory/INVENTORY.md) |
| `CyclingView` | The cycling board in the map gap: the carved figure with the Madra ball, groove and zones, the status line, the Auto toggle and the close button. The Madra and Core Density readout is the cultivator cabinet, and the techniques and the last cycle's result are in the zone chest | [CYCLING.md](../cycling/CYCLING.md) |
| `PathTreeView` | Ink-and-gold book: a chapter tab per cultivation stage, the open stage's tree (left-drag pan, wheel zoom), node or path details, active benefits, points | [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) |
| `AbilitiesView` | Jade book: filtered and sorted ability rows, 4-slot loadout, details of the ability pointed at | [ABILITIES.md](../abilities/ABILITIES.md) |
| `CharacterView` | Indigo book: 8 attributes in Physical (STR, BODY, AGI, RES) and Spiritual (SPI, FND, CTRL, WILL) groups, and the attribute pointed at described on the right page | [CHARACTER.md](CHARACTER.md) |
| `MerchantView` | Merchant shop: title and Leave, a wrapping greeting, up to 8 stock rows with price and Buy, then the status line and gold. The gold previews a purchase while Buy is hovered. Its root `theme` is the merchant's zone theme | [FOUNDATION_PLAYTHROUGH.md Beat 4](../progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented) |
| `TribulationView` | The Tribulation board in the map gap: the zone's name and the trial's title, the stage (brass ring, the core, the breathing spheres, the hold arc), the phase name and tip with the crack pips, a progress rod, and the intro and result panels over the stage | [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md) |

### GreyBackground (modal backdrop)

`GreyBackground` (`scenes/ui/grey_background/grey_background.gd`, class `GreyBackground`) is a full-rect `Panel` at z 2. Its stylebox is `assets/styleboxes/zones/grey_background.tres`, a flat slate fill `Color(0.176, 0.216, 0.216, 0.557)`. Because it uses the Panel's default mouse filter it blocks clicks to everything beneath it, including the dock. A left press on the backdrop itself emits `clicked`; the menu books close on it, and other users (the merchant) ignore it. States use it in two ways:

| Mode | Behaviour |
|------|-----------|
| Direct toggle | `grey_background.visible = true/false`, with no animation |
| Fade orchestration | `show_with_panel(panel)` sets `self_modulate.a = 0`, shows backdrop and panel, plays `grey_fade_in`, and calls `panel.animate_open()` if it exists. `hide_with_panel(panel)` plays `grey_fade_out` and calls `panel.animate_close()` if it exists. It then hides both nodes and emits `panel_hidden` once the grey fade-out has finished and, for a panel with a `close_finished` signal (the menu books), once that panel's own close has finished too. A panel without the signal (the merchant shop) is done when the fade ends. |

### Cycling mode

Cycling is one of two overlays with no backdrop (the other is the [Tribulation board](#tribulation-board)). Its board (x 680 to 1240) sits in the map gap, so the zone view stays up around it, and `CyclingViewState` opens it with `MainView.open_board()` and a spec that swaps the chest. The board takes the zone view's own furniture over:

| Piece | While cycling | How |
|-------|---------------|-----|
| Zone chest | Lists the learned techniques ("Techniques", "N learned") instead of the activities, with the last cycle's line under the Now tray once a cycle has ended. About hides and an open lore closes | The transition's chest swap: the activity rows step out, `ZonePanel.set_techniques_mode()` turns the list, the drawers step in ([Board transitions](#board-transitions)). About is `ZonePanel.set_board_mode()`, which `open_board()` calls at once and the close's end undoes |
| Dock | Off the screen (the board covers its place) | The transition steps it down, then hides it |
| Map | Takes no clicks, hover or wheel zoom | `open_board()` sets `zone_map_viewport.gui_disable_input`, until the close ends. The `SubViewportContainer` hands a press to its SubViewport with `push_input()`, which a viewport with its input off drops |

- Without a transition, `open_board()` does all three at once (`set_techniques_mode(true)`, and `set_board_mode(true)` for the dock, the map and About), and `close_board()` undoes them. Each piece is skipped when its reference is missing, as it is on the `MainView`s the view-state tests build.
- `MapMarkers` still hears presses at the window level, so a click on the map beside the board closes a pinned popover. Nothing travels.
- The cabinet, the Goals board and the log are left alone. The full log is blocked, so L does nothing and Escape reaches the board.
- While cycling is the top state, I, A, C and P do nothing, because only the top state reads input.
- `MainView._ready()` hands the cabinet to the `CyclingView` so its pellets can fly into the cabinet's orbs.

### Tribulation board

The Tribulation (`scenes/tribulation/`, [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md)) is the second overlay with no backdrop. Its board (952 px wide at (484, 24)) stands in the same map gap as the cycling board, and `TribulationViewState` opens it with `MainView.open_board()` and a spec that moves the HUD boards. The board takes the zone view over until its close ends:

| Piece | While the board is up | How |
|-------|-----------------------|-----|
| Log and Goals board | Off the left edge of the screen. Cycling leaves them showing | The transition steps them off, the Goals board first ([Board transitions](#board-transitions)). Without a transition, `hide_hud_boards(holder)` / `release_hud_boards(holder)` ([HUD boards](#hud-boards)) |
| Dock | Off the screen | The transition steps it down, then hides it. Without one, `set_board_mode(true)` |
| Map | Takes no clicks, hover or wheel zoom | `open_board()` sets `zone_map_viewport.gui_disable_input`, until the close ends |
| Full log | Closed and blocked, so L does nothing and Escape reaches the board | `LogWindow.set_full_log_blocked(true)`, through `MainViewState` |
| Cabinet and chest | Stay up. The chest keeps its activity list, but no card can be pressed (see Click blocking). About hides and an open lore closes | `ZonePanel.set_board_mode(on)`, which `open_board()` calls at once and the close's end undoes (without a transition, `set_board_mode(true)`) |

- **Click blocking.** The `TribulationView` root is a full-screen `Control` with `MOUSE_FILTER_STOP`, and its `_gui_input()` accepts every mouse event, so no click reaches the chest, the cabinet or the map beneath, and no other action can replace the trial (`tribulation_view.gd:239`). Every node on the board except the board itself (`PASS`) and its three buttons ignores the mouse. While the board opens or closes, the transition's shield takes the clicks before the board does.
- **Input.** `MainView` sends input only to the top state, so `TribulationViewState.handle_input()` (`tribulation_view_state.gd:67`) hands `tribulation_press` events (Space) to `view.handle_press_event()` and turns `ui_cancel` into `view.cancel()`, which acts on the intro only. While the board opens only `ui_cancel` is handled, so Space cannot begin the run on a board still growing, and while it closes nothing is. Mouse presses reach the view's `_gui_input()` and go to the same `handle_press_event()`. On the intro only Space, or a click inside the board's rect, begins the run (`tribulation_view.gd:360`): the second click of a double click on the card that opened the trial lands outside the board and does nothing, so it cannot skip the rules or **Not yet**. While the run goes on, a press counts wherever it lands. The board's buttons set `focus_mode = FOCUS_NONE`, so Space never presses one.
- **The hold.** The last breath's hold ends only on a release of the kind of input that started it (the key, or the mouse button), or on a focus loss; the other kind coming up leaves it alone (`tribulation_view.gd:400`; the focus loss, `_notification()`, `:243`).
- **Closing.** Whatever stopped the action (Continue: `finished(passed)` → `ActionManager.stop_action(passed)`, only while a Tribulation action is current; Not yet or Escape on the intro; or a stop from outside mid-run, which nothing in play makes today: only the tests drive one), `stop_tribulation` first calls `view.halt()`: a run in progress is dropped and nothing of it is applied, and the board stays drawn for the close to shrink. Then the state closes the board with `close_board()` and calls `remove_state(self)` when the close ends, and its `exit()` calls `view.close()`, which hides the board. `halt()` leaves the view's mode `CLOSED`, so a second press on Continue does nothing, and the shield takes it anyway.

### Board transitions

The cycling board and the Tribulation board open and close through one reversible transition ([spec](../superpowers/specs/2026-10-27-board-transitions-design.md)). The camera eases in on the cultivator, the dock steps down off the screen, and the board grows out of the cultivator to its place in the map gap. For cycling, the zone chest's activity rows step out to the right and the technique rows step in; for the Tribulation, the Goals board and the log step off the left edge. The close plays the same timeline backwards and leaves every piece where the open found it, the camera exactly. The [spec](../superpowers/specs/2026-10-27-board-transitions-design.md) ends with how far the same system extends to other boards and to the adventure.

#### The player (`BoardTransition`)

`BoardTransition` (`scenes/ui/main_view/board_transition/board_transition.gd` and `.tscn`) is one full-screen `Control` under `MainView` (`%BoardTransition`, z 9) that draws nothing of its own. It holds one progress value, from 0 (closed) to 1 (open), and a phase: `CLOSED`, `OPENING`, `OPEN` or `CLOSING`. While it moves, `_process()` calls `advance(delta)`, which moves the progress in its direction at the rate that crosses the open's timeline in its length, clamped to 0..1, so a long hitch ends it in one step. Every piece is drawn from the progress, at t = progress × the open's length. Nothing else moves time, so tests drive it with `advance()` and `finish()`. Its scene gives it `process_priority` -1, so it moves the camera before the map's markers place themselves from it and the map hit-tests the pointer, and the plates stay on their hexes in every frame of the push.

| Member | Behaviour |
|---|---|
| `bind(dock, zone_panel, hud_boards, camera, cultivator, camera_hold)` | The pieces it moves. `MainView._ready()` binds the dock, the chest, the Goals board and the log (in the order they leave), `%ZoneTilemap`'s camera and its `character_body`, and the camera hold ([The camera push](#the-camera-push-camerapush)). Any of them may be missing: a missing or freed piece is skipped |
| `open(spec)` | From closed: records where the dock, the HUD boards and the board's view rest, begins the camera push, reads the chest's two heights, takes the chest's rows, and starts at 0. While the same board closes (the same spec, or one for the same view), it turns around from where it is and drops the close's callback. While it opens or is open, nothing. If another board is up or moving, that one is first snapped closed: every piece put back and its callback called |
| `close(on_closed)` | Turns the board that is up or moving around from where it is, and calls `on_closed` once when the close ends. A later close's callback replaces it; an open before the end drops it. With no board up, it calls `on_closed` at once |
| `advance(delta)`, `finish()` | Move the progress on by `delta` seconds; jump to the end of the current direction |
| `is_moving()`, `is_closing()`, `is_open()`, `get_progress()`, `get_spec()` | Where it stands |
| `opened`, `closed` | Emitted at the open's end, and at the close's end after the callback |

Reversal is a change of direction: Esc while the board opens, or a start while it closes, plays every piece back from where it is, and nothing jumps.

#### The timeline (`BoardTransitionTiming`)

`BoardTransitionTiming` (`scripts/utils/board_transition_timing.gd`) owns the timeline: static functions of the time into the open, with no node access, and their constants. Times are from the start of the open; the close runs them backwards.

| When | Piece | Motion | Functions |
|---|---|---|---|
| 0–480 ms | Camera | Eases in and out (cubic) from the zoom and position the player left it at to 1.5 times that zoom, with the cultivator at the board's horizontal centre and 70 px under its vertical centre: screen (962, 612) for the cycling board | `camera_weight()`, `cultivator_target()`, `push_camera_position()` |
| 0–140 ms | Dock | Steps straight down off the bottom of the screen, then hides | `dock_offset()` |
| 200–520 ms | Board | Hidden until 200 ms, then scales from 0.03 to full size about the point the camera brings the cultivator to, easing out (cubic), every frame. Everything on the board scales with it | `is_board_shown()`, `board_scale()` |
| 0–300 ms | Chest (cycling) | The Activities header, then each activity row that shows in the scroll window, steps out to the right across the chest's width: 120 ms a row, each starting 20 ms after the one before, or less for a long list, so the last is out by 300 ms | `out_stagger()`, `row_out_offset()` |
| 300 ms | Chest (cycling) | The chest turns to the techniques (`ZonePanel.set_techniques_mode()`) while its header is out of sight, so "Activities · N here" becomes "Techniques · N learned" unseen | `CHEST_SWAP_MS` |
| 300–540 ms | Chest (cycling) | The header, then each technique drawer, steps in from the right: 140 ms a row, each starting 25 ms after the one before, or less for a long list, so the last is in by 540 ms. Meanwhile the chest's frame steps from the activity list's height to the technique list's | `in_stagger()`, `row_in_offset()`, `chest_height()` |
| 0–200 ms | HUD boards (Tribulation) | Step left off the screen: the Goals board over 0–160 ms, the log 40 ms behind it | `hud_offset()` |

The chest shows one list at a time, so its rows go out, then come in. The open takes 540 ms with the chest swap and 520 ms without (`duration_ms()`). The camera and the board's scale move smoothly; every other move steps in whole 2 px steps at constant speed (`snap_even()`). The board's scale is the style guide's named exception to the pixel grid ([STYLE_GUIDE.md §8](../STYLE_GUIDE.md#8-motion)).

#### The camera push (`CameraPush`)

`CameraPush` (`scenes/camera/camera_push/camera_push.gd`, a `RefCounted`) is the transition's camera move. `ZoneTransition`'s zoom into an adventure is one too ([ZONES.md](../zones/ZONES.md#adventure-start-zone-side)):

- `begin(camera, world_point, screen_point, end_zoom)` saves the camera's zoom and position (unless a push is already saved, so a second `begin()` keeps the first start) and works out the end framing: `world_point` at `screen_point` at `end_zoom`. The board passes the cultivator, `cultivator_target()` and 1.5 times the player's zoom.
- `apply(weight)` puts the camera between the start (0) and the end framing (1), zoom and position alike. The caller owns the curve.
- `restore()` puts the camera back to exactly what `begin()` saved and forgets it. The transition calls it at the close's end, also after an open that was turned around part-way.

It sets `zoom` and `position` directly, and nothing else may move the camera from `begin()` to `restore()`. `CameraClampController` clamps only on the other controllers' signals, but `CameraZoomController` eases the zoom on its own for about a second after a wheel tick, and the glide to a zone (`ZoneTilemap.frame_zone()`) and the way back from the adventure zoom (`ZoneTransition.reset_camera()`) are tweens. So the transition calls its camera hold with true before the push saves the camera, and with false after it restores it. The hold `MainView` binds:

- ends the moves under way at their ends: `ZoneTransition.settle_camera()` puts the camera where the way back was taking it, then `ZoneTilemap.hold_camera(true)` puts it where the glide was going (clamped, as the glide's end clamps) and settles the zoom controller on the zoom the player chose (`CameraZoomController.settle()`);
- keeps the zoom controller off (`set_enabled(false)`) until `hold_camera(false)` after the restore.

So the push saves the camera where it comes to rest, the zoom holds while the board is open, and the close starts from where the open ended. The push is not clamped to the zone's camera window.

#### The chest

For cycling, the transition swaps the chest at 300 ms and slides its rows through `ZonePanel`'s animation hooks ([ZONES.md](../zones/ZONES.md#zone-chest-zonepanel)): `get_slide_rows()`, `chest_height_for()`, `set_height_override()` and `clear_height_override()`.

- The rows stay in their containers and slide by `position.x`. A container lays its rows out again at the end of a frame whenever something asks (the swap builds the drawers and shows the other list), which puts them back at rest. So the transition listens to each container's `sort_children`, reads the rows' rest x again there, and slides them back before the frame is drawn.
- It takes the rows of the list that shows when a run starts, when a close starts from open, and at each swap. A row freed mid-slide (the list rebuilt) is skipped; rows that appear meanwhile stay at rest.
- It reads the chest's height in each mode (`chest_height_for()`) when a run starts, when any close starts, and at each swap. The last cycle's line under the Now tray goes when the cycling board shows (200 ms into the open), which changes the chest's techniques height after the run has started.
- From the swap to the open's end the chest's frame is held to the stepped height (`set_height_override()`), and it is let go at both ends.
- The header and the drawers are cut at the chest's inner edge (`SlideClip`), the activity rows at the activity list's scroll window.

#### The board's view

The view is shown from 200 ms and scaled about the point the camera brings the cultivator to. A scaled `Control`'s global position moves, so the pivot is worked out from the view's top-left at full size, recorded when the open starts from closed.

#### The ends

At the open's end the view is at full size, the rows are at rest, the chest hugs its list again, and `opened` is emitted. At the close's end the view is hidden at scale 1, the dock (shown again) and the HUD boards are back where the open found them, the rows are at rest, the chest hugs its list, and the camera is restored exactly; then the close's callback is called and `closed` is emitted.

#### MainView's board API

| Method | With a transition | Without one |
|---|---|---|
| `open_board(spec)` | `board_transition.open(spec)`, then the map's SubViewport takes no input (`gui_disable_input`) and the chest's About hides (`ZonePanel.set_board_mode(true)`) until the close ends. MainView turns nothing else over | At once: `set_board_mode(true)` (the dock and About hide, the map takes no input), the chest lists the techniques for a board that swaps it, the HUD boards hide through `hide_hud_boards(spec.holder)` for a board that moves them, and the view shows |
| `close_board(spec, on_closed)` | `board_transition.close()`, which closes whichever board is up. At the close's end the map takes input again and About comes back, then `on_closed` is called | At once: the open undone in reverse, then `on_closed` |
| `is_board_moving()`, `is_board_closing()` | The transition's `is_moving()` and `is_closing()` | Always false |

The `MainView`s the view-state tests build never run `_ready()`, so they have no transition and take the instant path.

#### How a board declares itself (`BoardTransitionSpec`)

A board describes itself in a `BoardTransitionSpec` (`board_transition_spec.gd`, a `RefCounted`):

| Field | Meaning | Cycling | Tribulation |
|---|---|---|---|
| `view` | The board's view, which the transition shows and scales | `CyclingView` | `TribulationView` |
| `board_rect` | The board's rect on the screen at full size: the camera and the scale aim at it | `CyclingView.get_board_rect()`: the board's laid-out rect, (680, 24) and 564 × 1036 | `TribulationView.get_board_rect()`: the board's top-left (484, 24) and width (952), with `BOARD_REST_HEIGHT` (768) for its height, because the board has not laid out before its first open |
| `swaps_chest` | The chest turns from the activities to the techniques | true | false: the chest keeps its activity list |
| `moves_hud_boards` | The Goals board and the log step off the left edge | false: they stay beside the board | true |
| `holder` | The board's state; the instant open and close hide the HUD boards on its behalf | `CyclingViewState` | `TribulationViewState` |

The two states follow one shape:

- Each builds one spec on its first open and keeps it, since the transition keeps the first spec of a run. `enter()` reads the view and its rect into it, so they are read only when the board opens from closed and never while it moves: a board that is scaling reports a scaled rect.
- `enter()` blocks the full log and calls `open_board()`. The state's stop signal calls `close_board(spec, remove_state(self))`, so the state stays on the stack, on top, until the close ends, and `exit()` (which `remove_state()` calls) lifts the block. A stop that comes while the state is not on the stack is ignored, because the transition closes whichever board is up.
- A start while the state is still on the stack (its board closing) calls `open_board()` with the kept spec, which turns the close around. The state is not pushed twice.
- The Tribulation halts its board before the close (`TribulationView.halt()`), and its `exit()` hides it (`TribulationView.close()`).

A new board in the map gap needs the same three things: a view whose `get_board_rect()` is right before the board has ever shown, a state of this shape, and its spec.

#### Input while a board moves

- **Clicks.** While a board opens or closes, the transition's `mouse_filter` is Stop and, as a full-screen `Control` after the boards in the tree, it takes every click: nothing on the board, the chest, the cabinet or the dock can be pressed mid-motion. At rest it is Ignore.
- **The map** takes no clicks, hover or wheel zoom from the open's start to the close's end, so travel and the wheel zoom are off the whole time a board is up or moving. The map hit-tests a resting pointer again when its camera moves only while its viewport takes input, so the camera push hovers no hex beside the board.
- **Menu keys.** The board's state is the top state from `enter()` until the close ends, so I, A, C and P do nothing, and L does nothing (the full log is blocked).
- **Esc while the board opens** turns it around: cycling stops its action, and the Tribulation does what Esc does on its intro (Not yet). Nothing else is handled while the Tribulation board opens.
- **While the board closes** both states handle no key (`is_board_closing()`): Esc must not stop the idle action that resumed when the board's action stopped. Keys and clicks in the close are dropped, not kept for its end.
- **A start while a board closes** cannot come from the player, since the chest takes no click under the shield, and nothing else in play makes one today. A start from outside, which only the tests drive, turns the close into an open.

### Menu books

The four menus are books (`docs/superpowers/specs/2026-10-21-menu-books-design.md`):

- `BookFrame` (`scenes/ui/book_frame/book_frame.tscn` + `.gd`) is the shared book: the inventory's book spritesheet with its open, close and page-turn animations, the close tab on the top edge of the right page, and the bookmark. The turning page draws one z-level over the book's content, so a page landing on the left page passes over the side tabs instead of under them; its strip's first and last frames are empty, so at rest it covers nothing. The close tab is the side-tab art standing up, showing 22 book px above the page near its corner. Its X is a `CloseGlyph` label in the game font, and like the side tabs it has no hover art, tooltip or hand cursor. The bookmark hangs about 27 book px below the page stack, centred at x 583 (between its first spot and the book's right edge). It sits in a `BookmarkClip` whose top is the top page's bottom edge, and once the book lies open it slides down out of it in `BOOKMARK_SLIDE_SECONDS` (0.45 s, ease out), as if pulled from between the pages; it hides at once when the book starts closing. One palette-swap shader (`assets/shaders/palette_swap.gdshader`) recolours the cover edge, the page border line, the turning page and the bookmark from a `BookStyleData` (`scripts/resource_definitions/ui/book_style_data.gd`; one per book in `resources/ui/book_styles/`). The close tab and bookmark only show while the book lies open. A `BookHitArea` over the open book's art, (48, 24)-(652, 432), and the bookmark catch clicks, so only a click outside the book reaches the backdrop and closes it; the transparent margins of the 700 × 450 frame count as outside. `animate_open()` plays the close animation backwards, and unless it is turning a close around, it first seeks onto that animation's last key (the closed book): the track is discrete, so playback only applies keys it crosses, and a book that has never closed would otherwise start on its open frame and snap shut before opening. Signals: `opened`, `closed`, `close_requested`, `page_turned`.
- `MenuBookView` (`scenes/ui/book_frame/menu_book_view.gd`) is the base script of the four views. `animate_open()` and `animate_close()` drive the `%BookFrame`; the nodes in its `page_content` export are shown only while the book lies open. It re-emits the close tab as `close_requested` and emits `close_finished` when the book has closed. Subclasses can hook in before the open, after the open and after the close.
- `BookViewState` (`scenes/ui/main_view/states/book_view_state.gd`) is the base of the four states. Subclasses name the view and their close keys; Esc, the menu's key, the close tab and `GreyBackground.clicked` (connected in `enter()`, disconnected in `exit()`) all take the same close path. A backdrop click only counts once the book lies open: the state ignores it while `BookFrame.is_moving()`, so a quick second click on the dock button, which lands on the backdrop, can't shut the book mid-open. Esc and the menu's key still close a book that is opening. `enter()` and `exit()` block and unblock the full log through the full-log block in `MainViewState`, which `CyclingViewState` shares.
- Every book view has two layers. A `BookLayer` scaled 2x holds the `BookFrame` and the chrome drawn at book scale (side tabs, the `TabBanner` title ribbon, the `SortSubBanner` selector). A `PageLayer` at screen resolution holds the pages, styled by `assets/themes/book_theme.tres` (see [UI_STYLING.md](../UI_STYLING.md#menu-book-pages)), so their text renders at its own size with no counter-scaling. The inventory's pages are pressed paper ([INVENTORY.md](../inventory/INVENTORY.md#architecture)).

### ActionManager-driven transitions

The state scripts connect to `ActionManager` themselves in `_ready()`. `MainView` connects to nothing.

```
Zone action (cycling) ─► ActionManager.start_cycling ─► CyclingViewState: push_state(cycling)
   └─► enter(): the full log is blocked; open_board(spec): the map's input and About go off, the board opens
         (camera push, dock down, board scales out of the cultivator, chest swaps to the techniques)
Esc ─► close_cycling_view ─► ActionManager.stop_action()      (the board's × calls stop_action() too)
   ├─► CyclingView: the running cycle ends with no result
   ├─► CyclingViewState: close_board(spec, remove_state(cycling)) ─► the open plays backwards
   │     └─► at its end: the map takes input, About is back ─► remove_state(cycling) ─► exit(): the full log unblocked
   └─► the zone's idle action resumes (at once, while the board closes)
start_cycling while the board closes (only the tests) ─► open_board(spec): the close turns around

Zone action (merchant) ─► ActionManager.start_merchant ─► MerchantViewState: merchant_view.setup(action); push_state(merchant)
Leave / Esc ─► ActionManager.stop_action() ─► stop_merchant ─► hide_with_panel ─► panel_hidden ─► remove_state(merchant)

Zone action (Tribulation) ─► ActionManager.select_action() refuses unless can_attempt() ─► start_tribulation
   └─► TribulationViewState: tribulation_view.setup(action.tribulation, zone name); push_state(tribulation) (once)
   └─► enter(): the full log is blocked; open_board(spec): the map's input and About go off, the board opens on its intro
         (camera push, dock down, the Goals board and the log off the left edge, board scales out of the cultivator)
Begin / Space / a click on the board ─► the run begins; the view applies the result itself when it ends
   (advance_to_next_stage() on a pass, lose_core_density_levels() on a failure), then shows the result panel
Continue / Not yet / Esc on the intro ─► TribulationView.finished(passed) ─► ActionManager.stop_action(passed)
   ├─► stop_tribulation ─► view.halt(); close_board(spec, remove_state(tribulation)) ─► the open plays backwards
   │     └─► at its end: the boards, dock, map and About are back ─► remove_state(tribulation) ─► exit(): view.close()
   └─► the zone's idle action resumes (at once, while the board closes)

Zone action (adventure) ─► ActionManager.adventure_start_requested
   ├─► ZoneViewState: adds a full-rect Control (mouse Stop) to ZoneView and ignores keys
   ├─► MapMarkers: hides the map's plates and glyphs
   └─► ZoneTransition: LacquerPellet drain from the cabinet's Madra orb onto the character, then
       from the frame the last pellet lands the camera push (CameraPush) to 1.5x the player's zoom
         └─► ActionManager.confirm_adventure_start(data, budget) ─► start_adventure
               ├─► AdventureViewState: ViewDissolve.play() (a still of the zone view),
               │     then change_state(adventure)                (zone exit removes the blocker)
               └─► AdventureView.start_adventure()               (connected after the state)

Run ends ─► ActionManager.stop_action() ─► stop_adventure (the zone's idle action resumes)
   ├─► AdventureViewState: no-op (waits for the result)
   └─► AdventureView.stop_adventure() ─► adventure_completed(result)
         └─► AdventureViewState: push_state(end_card); adventure_end_card.show_results(result)
               └─► Return button ─► close animation ─► return_requested (one-shot)
                     └─► ViewDissolve.play() (a still of the adventure); pop_state(); change_state(zone)
                           (ZoneTransition.reset_camera())
```

`stop_cycling`, `stop_merchant`, `stop_tribulation` and `stop_adventure` also fire when `ActionManager.select_action()` replaces the current action, or when `ZoneManager.zone_changed` stops it. A stop from outside mid-trial, which only the tests drive today, closes the board through `stop_tribulation` and applies nothing.

### Input routing

1. `DevPanel._input()` runs before the GUI. It handles Ctrl+Shift+D and Ctrl+Shift+R (see [Keybindings](#keybindings)) and marks the event handled. `ZonePanel._input()` also sees every left press, to close the lore at the end of the frame when the press lands outside it.
2. GUI controls consume their own events, for example a focused `LineEdit`/`SpinBox`, button clicks and `gui_input` handlers. While a board in the map gap opens or closes, `BoardTransition` takes every mouse press here (see [Board transitions](#board-transitions)).
3. `_unhandled_input` reaches the nodes in reverse tree order, then `MainView`:
   - `LogWindow` (while visible and none of a menu book, the cycling board and the Tribulation board is open): L (`toggle_log`) opens or closes the full log; Escape closes it while open. A book, the cycling board or the Tribulation board closes the full log and blocks it, so L does nothing under them and Escape goes on to the book or the board.
   - `ZonePanel`: Escape closes the lore, only while it shows and `ZoneViewState` is MainView's current state, so an overlay opened over the zone view takes Escape first.
   - Inside the zone SubViewport, `MapMarkers`: Escape closes a pinned map popover, only while `ZoneViewState` is current with no overlay pushed and the full log is closed. The `SubViewportContainer` hands keys to the SubViewport at its own place in this pass (after `LogWindow` and `ZonePanel`, which sit later in the tree), and the SubViewport has `handle_input_locally` off, so its `set_input_as_handled()` ends the event for `MainView` too. One Escape therefore closes the lore before the popover.
   - `MainView` (routed to the current state only; the Tribulation's keys arrive this way, its mouse presses do not: the board's root takes them in `_gui_input()` and stops them), the combat `TechniqueDock` (Q/W/E/R and 1 to 4 while active and visible), and the camera controllers inside the maps (the zone tilemap's zoom and pan; the adventure tilemap's zoom, which has no pan). A wheel over an adventure board never reaches the map (the boards are `MOUSE_FILTER_STOP`), and the map is hidden during a fight, so neither zooms it.

Escape is bound to three actions: `close_inventory`, `close_cycling_view` and the built-in `ui_cancel`. Inside the state machine they never conflict because only the top state reads input. Menu shortcuts work only while `ZoneViewState` is current. `AdventureViewState.handle_input()` is empty, so I/A/C/P do nothing during an adventure; L still opens the full log. Under a menu book, and while cycling or in the Tribulation, L does nothing.

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
| `toggle_log` | L | `LogWindow._unhandled_input()`, while the log is visible and none of a menu book, the cycling board and the Tribulation board is open | Open / close the full log ([LOGGING.md](LOGGING.md#logwindow)) |
| `close_cycling_view` | Escape | `CyclingViewState` (the board's × calls `ActionManager.stop_action()` directly) | `ActionManager.stop_action()`, also while the board opens (the open turns around). Nothing while it closes |
| `tribulation_press` | Space, left mouse button (`project.godot:144`) | Keys: `TribulationViewState.handle_input()` → `TribulationView.handle_press_event()`. Mouse: `TribulationView._gui_input()` | The trial's one input. On the intro, Space or a click on the board begins the run; during the run, a press (or its release, for the hold) is judged on `Time.get_ticks_usec()` as it arrives; on the result panel it does nothing. Key repeats are not presses. Dialogic's `dialogic_default_action` shares Space and the click but acts only during a timeline. See [Tribulation board](#tribulation-board) |
| `center_zone_map_camera` | Space | Nothing | Unused, no script reads it |
| `ability_slot_1` to `ability_slot_4` | Q, W, E, R | `TechniqueDock._unhandled_input()` (`scenes/ui/combat/technique_dock/technique_dock.gd`), only while the dock is bound to a fight and visible | Emits `ability_selected` for that slot's ability when `can_cast_ability_instance()` accepts it, and shakes the slot when it refuses. `AdventureView` connects it to `AdventureCombat.on_player_ability_selected()` for each fight. |
| `consumable_slot_1` to `consumable_slot_4` | 1, 2, 3, 4 | `TechniqueDock._unhandled_input()`, only while the dock is bound to a fight and visible | Emits `consumable_selected` for the consumable in that hotbar slot when `can_use_consumable_instance()` accepts it, and shakes its socket when it refuses. `AdventureView` connects it to `AdventureCombat.on_player_consumable_selected()` for each fight. |
| `dialogic_default_action` | Enter, Space, X (logical keys), left mouse button, joypad button 0 | Dialogic addon (its plugin adds this action) | Advance dialogue |

Other inputs:

| Input | Handled by | Effect |
|-------|------------|--------|
| Escape (built-in `ui_cancel`) | `PathTreeViewState`, `AbilitiesViewState`, `CharacterViewState`, `MerchantViewState`, `TribulationViewState`; `LogWindow`, `ZonePanel`, `MapMarkers` outside the state machine | Close the overlay (the merchant does it by stopping its action; the Tribulation turns the trial down from its intro and ignores Escape once the run has begun); close the full log, the zone lore or the pinned map popover |
| Ctrl+Shift+D (`KEY_D`, logical) | `DevPanel._input()` | Dev panel toggle. See [DEV_TOOLS.md](../tooling/DEV_TOOLS.md#opening-it). |
| Ctrl+Shift+R (`KEY_R`, logical) | `DevPanel._input()` | In a preset session, restarts the preset and marks the event handled, with the panel open or closed. In any other session the key is left alone and goes on as R, the fourth ability slot (`ability_slot_4`, which `TechniqueDock._unhandled_input()` reads). See [DEV_TOOLS.md](../tooling/DEV_TOOLS.md#opening-it). |
| Right mouse drag | `CameraPanController` on the zone tilemap camera only (the adventure camera follows the player and has no pan controller) | Pan the zone map |
| Mouse wheel | `CameraZoomController` on each map, 10% a tick, eased: the zone map 1.0 to 2.0 (default 2.0); the adventure map 1.0 to 2.0 (default 1.0, and every run opens there). Over the zone chest's list it scrolls the list instead; over an adventure board, or during a fight, it does nothing | Zoom |
| Left drag / wheel in path tree | `PathTreeView` (the tree area's `gui_input`) | Pan / zoom the tree |

### Dock and SystemMenuButton

`Dock` (`scenes/ui/dock/dock.tscn` + `dock.gd`, class `Dock`) is the lacquer kit's 476x80 recessed shelf (§5.4), a child of `ZoneView` at (722, 976), so it exists only on the zone map. It holds four `SystemMenuButton`s at x 10, 126, 242 and 358 inside the shelf (Inventory, Abilities, Character, Path) and decides which are notified:

- **Path:** the brass ring and a cinnabar count seal (a `LacquerCountSeal` over the top-left corner, widening rightward for a long count) while `PathManager.get_point_balance() > 0`, read in `_ready()` and on `points_changed`. This is how the game announces path points.
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

| Widget | Files | API / behaviour |
|--------|-------|-----------------|
| `FloatingText` | `scenes/ui/floating_text/floating_text.tscn` + `.gd` | No screen shows one now. `show_text(text, color, pos, trajectory = Vector2(0, -100))`. Moves along the trajectory over 1.5 s (cubic ease-out). In parallel it fades out over 1.5 s after a 0.45 s delay, then frees itself. The label is `LabelSubheading` with a white fill and 5 px black outline. |
| `GreyBackground` | `scenes/ui/grey_background/grey_background.gd` | See [GreyBackground](#greybackground-modal-backdrop) |
| `ViewDissolve` | `scenes/ui/view_dissolve/view_dissolve.tscn` + `.gd`, `assets/shaders/dither_dissolve.gdshader` | The style guide's 2-step dither dissolve from one whole view to the next. `play()` takes a still of the screen as last drawn (none under the headless display server) and lays it full-rect over the views, which change under it the same frame; `play_over(still)` does the same with a given still. The still shows on half its 2 px art cells, on a quarter after `STEP_SECONDS` (0.1 s), and hides after 0.2 s with `finished`. The shader is inverted on the scene's material, so the still keeps the complement of the cells a view dissolving in would show, and no cell comes back. It never fades and takes no pointer. A second `play()` restarts it. `is_playing()`. `AdventureViewState` plays it into the adventure and back |
| `LogWindow` | `scenes/ui/log_window/` | Placement only here. It listens to `LogManager.message_logged` and `visibility_toggled` and reads `LogManager.get_history()`. See [LOGGING.md](LOGGING.md). |
| `GoalsPanel`, `QuestToast` | `scenes/ui/goals_panel/`, `scenes/ui/quest_toast/` | Placement only here. See [QUESTS.md](../progression/QUESTS.md). |
| Lacquer pieces | `scenes/common/lacquer/` (`LacquerStripRect`, `LacquerRod`, `LacquerFrameOverlay`, `LacquerCountSeal`, `LacquerFloater`, `LacquerPellet` and its `PelletFlight`), `scenes/zones/zone_panel/lacquer_rail/` (`LacquerRail`) | See [UI_STYLING.md](../UI_STYLING.md#lacquer-theme-zone-view) |

Utilities:

| Script | Status |
|--------|--------|
| `scripts/utils/theme_constants.gd` (`ThemeConstants`) | Colours that code sets at runtime: `ACCENT_GOLD` and the `LACQUER_*` colours. See [UI_STYLING.md](../UI_STYLING.md#code-side-constants-themeconstants). |
| `scripts/utils/lacquer_text.gd` (`LacquerText`) | `rate()` and `decimal_bbcode()` for lacquer text. See [UI_STYLING.md](../UI_STYLING.md#lacquer-theme-zone-view). |

### Project settings (`project.godot`)

| Setting | Value |
|---------|-------|
| `config/features` | `"4.7", "Forward Plus"` (feature tags only) |
| Renderer | `rendering_method = "gl_compatibility"` (desktop and mobile) |
| Main scene | `uid://dyrsbe5x01lgo` = `res://scenes/main/main_game/main_game.tscn` |
| Window | 1920x1080 viewport, `stretch/mode = "viewport"` |
| Texture filter | `default_texture_filter = 0` (Nearest, for pixel art). The zone `SubViewport` sets its own `canvas_item_default_texture_filter = 0` too |
| Project theme | `gui/theme/custom = uid://yqkvsb5q7pab` = `res://assets/themes/pixel_theme.tres`. `MainView`, `AdventureView` and several sub-scenes also set it explicitly. The zone-view panels and the HUD boards set `assets/themes/lacquer/lacquer_theme.tres` on their roots |
| Autoloads (in order) | PersistenceManager, CultivationManager, EventManager, CharacterManager, UnlockManager, ResourceManager, ZoneManager, ActionManager, InventoryManager, Dialogic, DialogueManager, PlayerManager, LogManager, CyclingManager, AbilityManager, PathManager, QuestManager, MerchantManager, DevManager |
| Enabled editor plugins | AsepriteWizard, ResourcePlus, dialogic, godot_context_exporter, gut. `hexagon_tilemaplayer` and `script-ide` are installed but not enabled (script-ide was disabled in `39f1817`). |

Autoload order matters. Signal handlers run in connection order, and each manager connects in `_ready()`, so for example `CultivationManager` reacts to `PersistenceManager.save_data_reset` before `EventManager` does.

## Integration Points

| System | Connection |
|--------|------------|
| ActionManager | `start_cycling`/`stop_cycling` → `CyclingViewState` push / close and remove. `start_merchant`/`stop_merchant` → `MerchantViewState` push / fade and remove. `start_tribulation`/`stop_tribulation` → `TribulationViewState` set up and push / halt, close and remove. `adventure_start_requested` → `ZoneViewState` input blocker plus `ZoneTransition` drain. `start_adventure` → `AdventureViewState.change_state()`. `stop_action()` called by `CyclingViewState`, `MerchantViewState` and `TribulationViewState` (on the board's `finished`). |
| AdventureView | `adventure_completed(result)` → end card push. The dev panel's Adventure tab asks `is_in_combat` and `is_adventure_running()` and calls `set_show_whole_map()`; `DevCommands` calls `force_win_combat()` and `force_end_adventure()` ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md#dev-panel)). |
| AdventureEndCard | `show_results(result)`, `return_requested` → pop + `change_state(zone)` |
| InventoryView / PathTreeView / AbilitiesView / CharacterView | `MenuBookView`: `animate_open()` / `animate_close()` called through `GreyBackground`; `close_requested` (close tab) → the state's close path; `close_finished` → `GreyBackground` finishes hiding |
| MerchantView | `animate_open()` / `animate_close()`, called through `GreyBackground` |
| ZoneTransition | `reset_camera()` on zone enter; `settle_camera()` ends that way back at once when a board's camera push begins. Calls `ActionManager.confirm_adventure_start()` after the drain and the zoom. |
| GoalsPanel | Placed by `ZoneViewState` (and left in place by `AdventureViewState`); hidden under the shop and in the Tribulation; left showing beside cycling; dimmed under the menu books and the end card |
| CultivatorPlate / ZonePanel / Dock / zone SubViewport | The board transition steps the dock down and, for cycling, swaps the chest's lists through its animation hooks; `open_board()` turns the map's input and About off until the close ends; without a transition `open_board()` does it all at once (`set_board_mode()` for the dock, the map and About). The `CyclingView` flies its pellets into the cabinet |
| ZoneTilemap | Its camera and `character_body` are bound to the board transition, whose `CameraPush` pushes the camera in on the character while a board opens and restores it on the close; `hold_camera()` keeps the map's own camera moves still in between |
| CultivationManager | The Tribulation board applies its result through `advance_to_next_stage()` and `lose_core_density_levels()` ([CULTIVATION.md](../cultivation/CULTIVATION.md)) |
| ResourceManager | `CultivatorPlate` gold row (`gold_changed`, `get_gold()`) |
| PathManager | `Dock` Path count seal (`points_changed`, `get_point_balance()`) |
| AbilityManager | `Dock` Abilities ring (`ability_unlocked`, `equipped_abilities_changed`, `has_unequipped_unlocks()`) |
| PersistenceManager | `SaveTimer` calls `autosave()` every 5 s ([PERSISTENCE.md](PERSISTENCE.md)) |
| LogManager / Log | `LogWindow` shows `message_logged` and the history. `MainGame.log_print_level` → `Log.set_print_level()`. See [LOGGING.md](LOGGING.md). |
| Dev tools | `DevPanel` owns its two hotkeys, Ctrl+Shift+D and Ctrl+Shift+R, and keeps its open state, place and tab on `DevManager`, which a session switch outlives ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/main/main_game/main_game.tscn` | Entry scene, full UI tree |
| `scenes/main/main_game/main_game.gd` | `log_print_level` export, the playtime tick |
| `scenes/main/main_game/save_timer.gd` | 5 s autosave |
| `scenes/ui/main_view/main_view.gd` | `MainView`: state stack, `push_state`/`pop_state`/`remove_state`/`change_state`, HUD board hiding, `open_board()`/`close_board()`, `set_board_mode()`, input routing |
| `scenes/ui/main_view/board_transition/board_transition.gd` / `.tscn`, `board_transition_spec.gd` | `BoardTransition`, the map-gap boards' open and close, and `BoardTransitionSpec`, a board's description of itself |
| `scripts/utils/board_transition_timing.gd` | `BoardTransitionTiming`: the transition's timeline |
| `scenes/camera/camera_push/camera_push.gd` | `CameraPush`: a reversible camera push with an exact restore |
| `scenes/ui/main_view/states/main_view_state.gd` | `MainViewState` base class and the shared full-log block |
| `scenes/ui/main_view/states/*.gd` | Zone, Adventure, AdventureEndCard, Inventory, Cycling states |
| `scenes/path_progression/path_tree_view_state.gd` | Path tree overlay state |
| `scenes/abilities/abilities_view_state.gd` | Abilities overlay state |
| `scenes/character/character_view_state.gd` | Character overlay state |
| `scenes/merchant/merchant_view_state.gd`, `merchant_view.tscn` | Merchant shop overlay state and view |
| `scenes/tribulation/tribulation_view_state.gd`, `tribulation_view.gd` / `.tscn` | Tribulation board overlay state and view (the stage and the judge: [breakthrough-tribulation.md](../cultivation/breakthrough-tribulation.md)) |
| `scenes/ui/grey_background/grey_background.gd` | Modal backdrop and fade orchestration |
| `scenes/ui/book_frame/book_frame.tscn`, `book_frame.gd`, `menu_book_view.gd` | Shared menu book and the menu views' base script |
| `scenes/ui/main_view/states/book_view_state.gd` | Base state of the four menu books: the backdrop fade and every close route |
| `scenes/ui/dock/dock.tscn`, `dock.gd` | Bottom navigation dock and its notifications |
| `scenes/ui/dock/system_menu_button/system_menu_button.gd` / `.tscn` | `SystemMenuButton` and `MenuType` config |
| `scenes/ui/goals_panel/goals_panel.gd` / `.tscn` | Goals board |
| `scenes/ui/log_window/log_window.gd` / `.tscn` | Log board and full log |
| `scenes/zones/zone_transition/zone_transition.gd` | Adventure-entry drain and zoom; camera reset |
| `scenes/ui/view_dissolve/view_dissolve.gd` / `.tscn` | Dither dissolve between the zone view and the adventure |
| `scenes/ui/floating_text/` | Shared feedback widget |
| `project.godot` | Autoloads, input map, window, renderer, theme |

## Work Remaining

### Bugs

- `[MEDIUM]` The grey backdrop goes invisible after a faded panel closes. `GreyBackground.hide_with_panel()` ends `grey_fade_out` with `self_modulate.a = 0`, and nothing resets it. `AdventureEndCardState.enter()` only sets `visible = true`. After a menu book or the Merchant view has been opened and closed once, the backdrop behind the end card no longer dims the screen, though it still blocks clicks. The menu books are not affected: they open through `show_with_panel()`. Found by reading the code; not reproduced in-game.

### Missing Functionality

- `[LOW]` `center_zone_map_camera` (Space) is declared in `project.godot` but no script reads it, so Space does nothing on the zone map. Clicking the current zone's hex recentres the camera.
- `[LOW]` `open_path_tree` (P) duplicates `open_path` and is never read.
- `[LOW]` I/A/C/P are ignored during adventures because `AdventureViewState.handle_input()` is empty. It is unconfirmed whether this is intended.

### UI

- `[LOW]` Overlays use two transition styles. The end card toggles the backdrop instantly; the menu books and the merchant fade it through `GreyBackground.show_with_panel()`/`hide_with_panel()`. Cycling and the Tribulation use no backdrop and open through the board transition. The zone-action pop-ups are the next consistency pass ("menus are books, action pop-ups are scrolls").
- `[LOW]` The cycling chest's rows are cut at two edges as they slide: the Activities header and the technique drawers at the chest's inner edge (about screen x 1892), the activity rows at the activity list's scroll window (about x 1868), so each activity row vanishes 24 px before the header would, about 7 ms early.
- `[LOW]` The cycling chest stands empty at its full height for up to 180 ms of the open, less for a longer list (about 140 ms with a header, a label and one card): the activity rows are gone before 300 ms, and the techniques start in only then. The close plays the open's timeline backwards, so it stands empty just as long.
- `[LOW]` A board rect read before the board lays out is off by its wrapped lines: a cycling action name that wraps grows the board after `CyclingViewState` has read its rect, and a Tribulation zone name that wraps makes the board taller than `BOARD_REST_HEIGHT`. The pivot and the camera's aim are then off by half the extra height (12 px for a three-line action name), which does not show.
- `[LOW]` Closing a book while it is still opening makes the backdrop flash darker. `hide_with_panel()` plays `grey_fade_out`, whose first key is full alpha, so a backdrop still fading in (alpha 0.56 when seen in play) jumps to 1 before it fades out. Only Esc and the menu's key can close a book mid-open now that backdrop clicks wait for the open.
- `[LOW]` `FloatingText._ready()` sets its size with `add_theme_constant_override("font_size", FONT_SIZE)`. Font sizes need `add_theme_font_size_override`, so `FONT_SIZE` never applies and the size comes from `LabelSubheading` (24 px). The script also uses `$Label` instead of `%Label`.
- `[LOW]` The dock's Path count uses `LabelLacquerSeal`, whose 1 px letter spacing makes a two-digit count ("12") 1 px wider than the mock. A single digit matches.

### Tech Debt

- `[LOW]` `MainView.change_state()` clears `state_stack` without calling `exit()` on stacked overlays. This is only safe because no overlay can be open when the base changes: `ZoneViewState` blocks input during the adventure transition, and the end card is popped first. An overlay skipped this way would also never release the HUD boards. A board's close is one more window: a `change_state()` while the cycling or Tribulation board closes drops the board's state before its `exit()`, so the full log stays blocked. Nothing in play reaches it today: only the adventure's start and end call `change_state()`, and the start needs a click on the chest, which is blocked while a board is up and during any close.
- `[LOW]` `LogWindow._full_log_blocked` is a bool, not a counter. A menu book, the cycling board and the Tribulation board cannot be open together today (menu keys are inert under cycling and the Tribulation, and the dock is hidden), so nothing nests. If that ever changes, it needs a counter.
- `[LOW]` For the idle boards: `BoardTransition.open()` snaps another board closed when it finds one up, but a board that is fully open (not closing) has no close callback pending, so its state stays on `MainView`'s stack. Unreachable while one board moves at a time.
- `[LOW]` For the idle boards: since the full-log block is that bool, a snapped board's state lifts it in its `exit()` while the board now up still holds it.
- `[LOW]` Some nodes are created in code despite the scene-tree UI rule: the input blocker that `ZoneViewState` adds with `Control.new()`.
- `[LOW]` Stale doc comment: the `MainView` class comment lists 5 views (Zone, Adventure, Inventory, Cycling, Tribulation); there are 10 states.
- `[LOW]` `MainGame.log_print_level` is set to `0` (`Log.Event.INFO`) in `main_game.tscn`; the script default is `DEBUG`. `Log.Event` orders `INFO`(0) before `DEBUG`(1), so INFO prints every level and DEBUG would hide INFO lines (see [LOGGING.md](LOGGING.md)).
- `[LOW]` `project.godot` mismatches:
  - `[dialogic] extensions_folder = "res://addons/dialogic_additions"` points to a folder that does not exist.
  - `config/features` lists "Forward Plus" while the renderer is `gl_compatibility`.
