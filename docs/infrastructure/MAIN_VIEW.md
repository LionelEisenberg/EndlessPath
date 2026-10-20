# Main View (UI Shell and Navigation)
Last updated: 2026-10-19

## Overview

`main_game.tscn` is the only runtime scene. It hosts every full-screen view (zone map, adventure, inventory, cycling, path tree, abilities, character, merchant shop, adventure end card), the always-on HUD panels (log, quests), and the dev tools. `MainView` decides which views are visible through a small state machine. There is one **base state**, Zone or Adventure. Modal **overlay states** are pushed on a stack above it.

- Menu overlays (Inventory, Path, Abilities, Character) open from the keyboard or the bottom toolbar. Both routes produce the same input action.
- Cycling, the merchant shop, adventures and the end card are driven by `ActionManager` and `AdventureView` signals.
- Only the top state receives input. Everything else that reads input (combat hotkeys, camera pan/zoom, the dev hotkey, Dialogic) is handled outside the state machine.

Related docs: [UI_STYLING.md](../UI_STYLING.md) (theme), [DEV_TOOLS.md](../tooling/DEV_TOOLS.md) (dev panel), [TESTING.md](../testing/TESTING.md).

## Architecture

### Scene tree (`scenes/main/main_game/main_game.tscn`)

```
MainGame (Node2D)                          main_game.gd: Ctrl+Shift+D dev hotkey, Log print level
├── MainView (Control, 1920x1080)          main_view.gd (class MainView): state stack + input routing
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
│   │   ├── ZoneTransition (Node)          zone_transition.gd: Madra drain + camera zoom into adventures
│   │   ├── SubViewportContainer           1920x1080, centred
│   │   │   └── SubViewport                transparent bg, always updates
│   │   │       ├── ZoneViewBackground     zone_view_background.tscn (parallax)
│   │   │       └── ZoneTilemap            zone_tilemap.tscn (hex map, camera, player)
│   │   ├── ZoneInfoPanel                  right edge, 450 px wide
│   │   ├── ZoneResourcePanel              left middle: Madra + Core Density orbs
│   │   ├── ZoneHeader                     top-left, panel_floating.tres override
│   │   └── Toolbar                        bottom, 60 px: system menu buttons + gold
│   ├── AdventureView           z 0        adventure_view.tscn, hidden by default
│   ├── LogWindow               z 1        log_window.tscn
│   ├── QuestWindow             z 1        quest_window.tscn
│   ├── QuestToast              z 10       quest_toast.tscn
│   ├── GreyBackground (Panel)  z 2        grey_background.gd, hidden by default
│   │   └── GreyBackgroundAnimationPlayer  RESET, grey_fade_in (0.3 s), grey_fade_out (0.2 s)
│   ├── PathTreeView            z 3        path_tree_view.tscn (z set on the scene root)
│   ├── AdventureEndCard        z 3        adventure_end_card.tscn
│   ├── InventoryView           z 3        inventory_view.tscn (root scale 2x, centred)
│   ├── AbilitiesView           z 3        abilities_view.tscn (z set on the scene root)
│   ├── CharacterView           z 3        character_view.tscn (z and visible=false set on the scene root)
│   ├── MerchantView            z 3        merchant_view.tscn (z, visible=false and the Spirit Valley theme set on the scene root)
│   ├── CyclingView             z 3        cycling_view.tscn
│   ├── DevPasswordModal        z 10       dev_password_modal.tscn, hidden
│   └── DevPanel                z 10       dev_panel.tscn, hidden, top-left 340x400
└── SaveTimer (Timer)                      save_timer.gd: 5 s, autostart → PersistenceManager.save_data()
```

Draw order is controlled by `z_index`. LogWindow and QuestWindow (z 1) sit under the GreyBackground (z 2), so a modal dims them and blocks clicks to them. QuestToast and the dev tools (z 10) draw above every modal.

### HUD placement

| Node | Parent | Placement (1920x1080) | Notes |
|------|--------|-----------------------|-------|
| `Toolbar` | `ZoneView` | Bottom strip, full width, 60 px tall | Hidden with the zone view during adventures |
| `ZoneHeader` | `ZoneView` | (28, 28) to (424, 245) | Zone name/info |
| `ZoneResourcePanel` | `ZoneView` | Left edge, vertically centred (x 28 to 206) | Madra orb is the drain particle source |
| `ZoneInfoPanel` | `ZoneView` | Right edge, x 1470 to 1920 | Zone actions |
| `LogWindow` | `MainView` | (736, 781) to (1136, 1008) | Draggable by its title bar, starts collapsed; visible in zone and adventure views |
| `QuestWindow` | `MainView` | x 1147 to 1467, y 28 to 271 | Collapsible, not draggable |
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
| `_unhandled_input(event)` | Forwards to the current state's `handle_input(event)`. |

In practice at most one overlay is open at a time. Overlay states never push other overlays, and while an overlay is open the GreyBackground covers the toolbar.

### States

| State | Kind | `enter()` | `exit()` | Input handled | Leaves via |
|-------|------|-----------|----------|---------------|------------|
| `ZoneViewState` | Base (initial) | Shows `ZoneView`. Removes the input blocker. Finds `ZoneTransition` and calls `reset_camera()` to undo the adventure zoom. | Removes the input blocker. Hides `ZoneView`. | `open_inventory` → push Inventory; `open_path` → push PathTree; `open_abilities` → push Abilities; `open_character` → push Character. Ignored while the input blocker exists. | `start_adventure` (handled by `AdventureViewState`) |
| `AdventureViewState` | Base | Shows `AdventureView`. Connects `AdventureView.adventure_completed`. | Hides `AdventureView` and disconnects. | None | End card return → `change_state(zone)` |
| `AdventureEndCardState` | Overlay on Adventure | Shows GreyBackground. `AdventureViewState` then calls `show_results()`. | Hides `AdventureEndCard` and GreyBackground. | None (the card's own Return button) | Popped by `AdventureViewState` |
| `InventoryViewState` | Overlay | Shows GreyBackground. Calls `InventoryView.animate_open()`, then shows the view. | Hides `InventoryView` and GreyBackground. | `close_inventory` or `open_inventory` → `animate_close()`. `inventory_closed` → `pop_state()`. | Book close animation |
| `CyclingViewState` | Overlay | Shows `CyclingView` and GreyBackground. | Hides both. | `close_cycling_view` → `ActionManager.stop_action()` | `ActionManager.stop_cycling` → `pop_state()` |
| `PathTreeViewState` | Overlay | `grey_background.show_with_panel(path_tree_view)` | No-op (already hidden by the fade) | `ui_cancel` or `open_path` → `hide_with_panel()`. `panel_hidden` (one-shot) → `pop_state()`. | Grey fade-out |
| `AbilitiesViewState` | Overlay | `show_with_panel(abilities_view)` | No-op | `ui_cancel` or `open_abilities` → same close path | Grey fade-out |
| `CharacterViewState` | Overlay | `show_with_panel(character_view)` | No-op | `ui_cancel` or `open_character` → same close path | Grey fade-out |
| `MerchantViewState` | Overlay | `show_with_panel(merchant_view)` | No-op | `ui_cancel` → `ActionManager.stop_action()`; the Leave button (`MerchantView.close_requested`) does the same | `ActionManager.stop_merchant` → `hide_with_panel()`, then `remove_state(self)` on `panel_hidden`. If another state is above it, it hides `MerchantView` at once and removes itself without the fade. `start_merchant` while it is already on the stack only rebinds the stock |

What each view shows:

| View | Content | Doc |
|------|---------|-----|
| `ZoneView` | Hex zone map with parallax background, zone header, info panel, resource orbs, toolbar | [ZONES.md](../zones/ZONES.md) |
| `AdventureView` | Adventure hex map, combat view, timer, player info panel | [ADVENTURING.md](../adventuring/ADVENTURING.md), [COMBAT.md](../combat/COMBAT.md) |
| `AdventureEndCard` | Scroll with VICTORY/defeat title, run stats, loot slots, Return button | [ADVENTURING.md](../adventuring/ADVENTURING.md) |
| `InventoryView` | Book with Equipment, Consumables, Materials and Quest Items tabs | [INVENTORY.md](../inventory/INVENTORY.md) |
| `CyclingView` | Cycling mini-game, technique tabs, resource panel, close button | [CYCLING.md](../cycling/CYCLING.md) |
| `PathTreeView` | Path skill tree (left-drag pan, wheel zoom), benefits area | [PATH_PROGRESSION.md](../progression/PATH_PROGRESSION.md) |
| `AbilitiesView` | Ability cards, 4-slot loadout, sort and filter | [ABILITIES.md](../abilities/ABILITIES.md) |
| `CharacterView` | 8 attributes in Physical (STR, BODY, AGI, RES) and Spiritual (SPI, FND, CTRL, WILL) groups, with hover tooltips | [CHARACTER.md](CHARACTER.md) |
| `MerchantView` | Merchant shop: title, greeting, gold, up to 8 stock rows with price and Buy, status line, Leave. Its root `theme` is the merchant's zone theme | [FOUNDATION_PLAYTHROUGH.md Beat 4](../progression/FOUNDATION_PLAYTHROUGH.md#beat-4-merchant-shop-implemented) |

### GreyBackground (modal backdrop)

`GreyBackground` (`scenes/ui/grey_background/grey_background.gd`, class `GreyBackground`) is a full-rect `Panel` at z 2. Its stylebox is `assets/styleboxes/zones/grey_background.tres`, a flat slate fill `Color(0.176, 0.216, 0.216, 0.557)`. Because it uses the Panel's default mouse filter it blocks clicks to everything beneath it, including the toolbar. States use it in two ways:

| Mode | Used by | Behaviour |
|------|---------|-----------|
| Direct toggle | Inventory, Cycling, AdventureEndCard states | `grey_background.visible = true/false`, with no animation |
| Fade orchestration | PathTree, Abilities, Character, Merchant states | `show_with_panel(panel)` sets `self_modulate.a = 0`, shows backdrop and panel, plays `grey_fade_in`, and calls `panel.animate_open()` if it exists. `hide_with_panel(panel)` plays `grey_fade_out`, calls `panel.animate_close()` if it exists, and when the grey animation finishes hides both nodes and emits `panel_hidden`. The grey animation's timing, not the panel's, decides when the close is done. |

### ActionManager-driven transitions

The state scripts connect to `ActionManager` themselves in `_ready()`. `MainView` connects to nothing.

```
Zone action (cycling) ─► ActionManager.start_cycling ─► CyclingViewState: push_state(cycling)
Esc / close button ─► close_cycling_view ─► ActionManager.stop_action() ─► stop_cycling ─► pop_state()

Zone action (merchant) ─► ActionManager.start_merchant ─► MerchantViewState: merchant_view.setup(action); push_state(merchant)
Leave / Esc ─► ActionManager.stop_action() ─► stop_merchant ─► hide_with_panel ─► panel_hidden ─► remove_state(merchant)

Zone action (adventure) ─► ActionManager.adventure_start_requested
   ├─► ZoneViewState: adds a full-rect Control (mouse Stop) to ZoneView and ignores keys
   └─► ZoneTransition: FlyingParticle Madra drain from the Madra orb, then camera zoom to 3x
         └─► ActionManager.confirm_adventure_start(data, budget) ─► start_adventure
               ├─► AdventureViewState: change_state(adventure)   (zone exit removes the blocker)
               └─► AdventureView.start_adventure()               (connected after the state)

Run ends ─► ActionManager.stop_action() ─► stop_adventure
   ├─► AdventureViewState: no-op (waits for the result)
   └─► AdventureView.stop_adventure() ─► adventure_completed(result)
         └─► AdventureViewState: push_state(end_card); adventure_end_card.show_results(result)
               └─► Return button ─► close animation ─► return_requested (one-shot)
                     └─► pop_state(); change_state(zone)   (ZoneTransition.reset_camera())
```

`stop_cycling`, `stop_merchant` and `stop_adventure` also fire when `ActionManager.select_action()` replaces the current action, or when `ZoneManager.zone_changed` stops it.

### Input routing

1. `MainGame._input()` runs before the GUI. It handles Ctrl+Shift+D and marks the event handled.
2. GUI controls consume their own events, for example a focused `LineEdit`/`SpinBox`, button clicks and `gui_input` handlers.
3. `_unhandled_input` reaches `MainView` (routed to the current state only), the combat `AbilitiesPanel` (Q/W/E/R while visible), and the camera controllers inside the tilemaps (zoom on both maps, pan on the zone map only).

Escape is bound to three actions: `close_inventory`, `close_cycling_view` and the built-in `ui_cancel`. They never conflict because only the top state reads input. Menu shortcuts work only while `ZoneViewState` is current. `AdventureViewState.handle_input()` is empty, so I/A/C/P do nothing during an adventure.

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
| `close_cycling_view` | Escape | `CyclingViewState` (the cycling close button fires the same action) | `ActionManager.stop_action()` |
| `center_zone_map_camera` | Space | Nothing | Unused, no script reads it |
| `ability_slot_1` to `ability_slot_4` | Q, W, E, R | `AbilitiesPanel._unhandled_input()` (`scenes/ui/combat/abilities_panel.gd`), only while the panel is visible | Emits `ability_selected` for that slot's ability when its button is enabled. `CombatantInfoPanel` re-emits it, and `AdventureView` connects it to `AdventureCombat.on_player_ability_selected()`. |
| `dialogic_default_action` | Enter, Space, X (logical keys), left mouse button, joypad button 0 | Dialogic addon (its plugin adds this action) | Advance dialogue |

Other inputs:

| Input | Handled by | Effect |
|-------|------------|--------|
| Escape (built-in `ui_cancel`) | `PathTreeViewState`, `AbilitiesViewState`, `CharacterViewState`, `MerchantViewState` | Close the overlay (the merchant does it by stopping its action) |
| Ctrl+Shift+D (`KEY_D`, logical) | `MainGame._input()` | Dev password modal or dev panel toggle. No-op unless `user://dev_password.txt` exists. See [DEV_TOOLS.md](../tooling/DEV_TOOLS.md). |
| Right mouse drag | `CameraPanController` on the zone tilemap camera only (the adventure camera follows the player and has no pan controller) | Pan the zone map |
| Mouse wheel | `CameraZoomController`: zone 0.65 to 1.35 (default 0.729), adventure 0.3 to 1.3 (default 1.0) | Zoom |
| Left drag / wheel in path tree | `PathTreeView._on_tree_area_gui_input()` | Pan / zoom the tree |

### Toolbar and SystemMenuButton

`Toolbar` (`scenes/ui/toolbar/toolbar.tscn` + `toolbar.gd`, class `Toolbar`) is a 1920x60 `PanelContainer` styled with `assets/styleboxes/ui/toolbar_panel.tres`. It holds four `SystemMenuButton` instances, a `VSeparator`, and a gold readout. The readout is `gold_icon.png` plus `GoldLabel` (`LabelSubheading` with a gold `#D4A84A` override), refreshed from `ResourceManager.gold_changed`. It is a child of `ZoneView`, so it exists only on the zone map. There is no `SystemMenu` node in `ZoneResourcePanel`.

`SystemMenuButton` (`scenes/zones/zone_resource_panel/system_menu/system_menu_button.tscn` + `.gd`) is a `Button` configured by one export, `menu_type: MenuType`. `MENU_CONFIG` maps each value:

| `MenuType` | Value | Label | Shortcut hint | Input action | Icon (`assets/sprites/ui/system_menu/`) |
|------------|-------|-------|---------------|--------------|------------------------------------------|
| `INVENTORY` | 0 | INVENTORY | I | `open_inventory` | `inventory_icon.png` |
| `ABILITIES` | 1 | ABILITIES | A | `open_abilities` | `ability_icon.png` |
| `CHARACTER` | 2 | CHARACTER | C | `open_character` | `character_icon.png` |
| `PATH` | 3 | PATH | P | `open_path` | `star_icon.png` |

- **Press:** builds an `InputEventAction` (`action`, `pressed = true`) and calls `Input.parse_input_event()`. The event follows the same path as a key press, ending in `ZoneViewState.handle_input()`.
- **Hover:** the name and shortcut labels turn `ThemeConstants.ACCENT_GOLD`.
- **Badge:** a 12x12 gold `ColorRect`, shown on ABILITIES only, when `AbilityManager.has_unequipped_unlocks()` is true. It refreshes on `AbilityManager.ability_unlocked` and `equipped_abilities_changed`.

### Shared widgets

| Widget | Files | Used by | API / behaviour |
|--------|-------|---------|-----------------|
| `FloatingText` | `scenes/ui/floating_text/floating_text.tscn` + `.gd` | `CyclingTechnique` (XP popups), `ResourceBar` (combat vitals deltas; per-bar `show_floating_text` export), `ForagingPresenter` (forage results) | `show_text(text, color, pos, trajectory = Vector2(0, -100))`. Moves along the trajectory over 1.5 s (cubic ease-out). In parallel it fades out over 1.5 s after a 0.45 s delay, then frees itself. The label is `LabelSubheading` with a white fill and 5 px black outline. |
| `FlyingParticle` | `scenes/ui/flying_particle/flying_particle.gd` (script only, created with `FlyingParticle.new()`) | `ZoneTransition` (Madra drain), `TrainingPresenter` (one Madra particle per tick), `CyclingView` (Madra/XP particles) | `launch(start, target, color, duration = 0.6, size = 5.0, on_arrive = Callable(), curve_spread = 60.0, curve_bias = 0.0)`. Quadratic bezier with ease-in and an 8-point fading trail, drawn with `draw_circle`. Calls `on_arrive`, then frees itself. |
| `TickProgressBar` | `scenes/ui/tick_progress_bar/tick_progress_bar.tscn` + `.gd` | `TrainingPresenter` | `set_progress(current, total)` (`total <= 0` clears it), `set_fill_color(color)`, `flash_and_reset(flash_color, duration = 0.3)`. 2 px bar with 9 gradation marks (10% to 90%) and a `LabelSmall` counter (12 px override) to the right of the bar. |
| `InkbrushButton` | `scenes/ui/inkbrush_button/inkbrush_button.tscn` + `.gd` | Nothing (unused) | `TextureButton` with a random `action_button_1..3.png` texture and a `zone_action_button.gdshader` fill on hover. `setup(label, texture, fill_color)`. |
| `GreyBackground` | `scenes/ui/grey_background/grey_background.gd` | Main view states | See [GreyBackground](#greybackground-modal-backdrop) |
| `LogWindow` | `scenes/ui/log_window/` | `MainView` | Placement only here. It listens to `LogManager.message_logged` and `visibility_toggled`. See [LOGGING.md](LOGGING.md). |
| `QuestWindow`, `QuestToast` | `scenes/ui/quest_window/`, `scenes/ui/quest_toast/` | `MainView` | Placement only here. Both have editor preview exports (`preview_*`). See [QUESTS.md](../progression/QUESTS.md). |

Utilities:

| Script | Status |
|--------|--------|
| `scripts/utils/theme_constants.gd` (`ThemeConstants`) | Colour palette and size constants for code. Only `ACCENT_GOLD`, `BORDER_PRIMARY` and `BG_MEDIUM` are referenced. See [UI_STYLING.md](../UI_STYLING.md#code-side-constants-themeconstants). |
| `scripts/utils/text_effect_importer.gd` | A `Node` with `@export var _text_effect_scripts: Array[Script]` and `get_text_effect_instances()`, which instantiates each script as a `RichTextEffect`. Not referenced by any scene or script. |

### Project settings (`project.godot`)

| Setting | Value |
|---------|-------|
| `config/features` | `"4.6", "Forward Plus"` (feature tags only) |
| Renderer | `rendering_method = "gl_compatibility"` (desktop and mobile) |
| Main scene | `uid://dyrsbe5x01lgo` = `res://scenes/main/main_game/main_game.tscn` |
| Window | 1920x1080 viewport, `stretch/mode = "viewport"` |
| Texture filter | `default_texture_filter = 0` (Nearest, for pixel art) |
| Project theme | `gui/theme/custom = uid://yqkvsb5q7pab` = `res://assets/themes/pixel_theme.tres`. `MainView`, `AdventureView` and several sub-scenes also set it explicitly. |
| Autoloads (17, in order) | PersistenceManager, CultivationManager, EventManager, CharacterManager, UnlockManager, ResourceManager, ZoneManager, ActionManager, InventoryManager, Dialogic, DialogueManager, PlayerManager, LogManager, CyclingManager, AbilityManager, PathManager, QuestManager |
| Enabled editor plugins | AsepriteWizard, ResourcePlus, dialogic, godot_context_exporter, gut. `hexagon_tilemaplayer` and `script-ide` are installed but not enabled (script-ide was disabled in `39f1817`). |

Autoload order matters. Signal handlers run in connection order, and each manager connects in `_ready()`, so for example `CultivationManager` reacts to `PersistenceManager.save_data_reset` before `EventManager` does.

## Integration Points

| System | Connection |
|--------|------------|
| ActionManager | `start_cycling`/`stop_cycling` → `CyclingViewState` push/pop. `start_merchant`/`stop_merchant` → `MerchantViewState` push / fade and remove. `adventure_start_requested` → `ZoneViewState` input blocker plus `ZoneTransition` drain. `start_adventure` → `AdventureViewState.change_state()`. `stop_action()` called by `CyclingViewState`. |
| AdventureView | `adventure_completed(result)` → end card push. `is_in_combat`, `force_win_combat()` and `set_show_whole_map()` are used by the dev panel. |
| AdventureEndCard | `show_results(result)`, `return_requested` → pop + `change_state(zone)` |
| InventoryView | `animate_open()`, `animate_close()`, `inventory_closed` |
| PathTreeView / AbilitiesView / CharacterView / MerchantView | `animate_open()` / `animate_close()`, called through `GreyBackground` |
| ZoneTransition | `reset_camera()` on zone enter. Calls `ActionManager.confirm_adventure_start()` after the drain. |
| ResourceManager | `Toolbar` gold label (`gold_changed`, `get_gold()`) |
| AbilityManager | `SystemMenuButton` badge (`ability_unlocked`, `equipped_abilities_changed`, `has_unequipped_unlocks()`) |
| PersistenceManager | `SaveTimer` calls `save_data()` every 5 s |
| LogManager / Log | `LogWindow` shows `message_logged`. `MainGame.log_print_level` → `Log.set_print_level()`. See [LOGGING.md](LOGGING.md). |
| Dev tools | `MainGame` owns the Ctrl+Shift+D gate for `DevPasswordModal`/`DevPanel` ([DEV_TOOLS.md](../tooling/DEV_TOOLS.md)) |

## Key Files

| File | Purpose |
|------|---------|
| `scenes/main/main_game/main_game.tscn` | Entry scene, full UI tree |
| `scenes/main/main_game/main_game.gd` | Dev hotkey gate, `log_print_level` export |
| `scenes/main/main_game/save_timer.gd` | 5 s autosave |
| `scenes/ui/main_view/main_view.gd` | `MainView`: state stack, `push_state`/`pop_state`/`remove_state`/`change_state`, input routing |
| `scenes/ui/main_view/states/main_view_state.gd` | `MainViewState` base class |
| `scenes/ui/main_view/states/*.gd` | Zone, Adventure, AdventureEndCard, Inventory, Cycling states |
| `scenes/path_progression/path_tree_view_state.gd` | Path tree overlay state |
| `scenes/abilities/abilities_view_state.gd` | Abilities overlay state |
| `scenes/character/character_view_state.gd` | Character overlay state |
| `scenes/merchant/merchant_view_state.gd`, `merchant_view.tscn` | Merchant shop overlay state and view |
| `scenes/ui/grey_background/grey_background.gd` | Modal backdrop and fade orchestration |
| `scenes/ui/toolbar/toolbar.tscn`, `toolbar.gd` | Bottom navigation bar and gold readout |
| `scenes/zones/zone_resource_panel/system_menu/system_menu_button.gd` | `SystemMenuButton` and `MenuType` config |
| `scenes/zones/zone_transition/zone_transition.gd` | Adventure-entry drain and zoom; camera reset |
| `scenes/ui/floating_text/`, `scenes/ui/flying_particle/`, `scenes/ui/tick_progress_bar/` | Shared feedback widgets |
| `project.godot` | Autoloads, input map, window, renderer, theme |

## Work Remaining

### Bugs

- `[MEDIUM]` The grey backdrop goes invisible after a faded panel closes. `GreyBackground.hide_with_panel()` ends `grey_fade_out` with `self_modulate.a = 0`, and nothing resets it. `InventoryViewState.enter()`, `CyclingViewState.enter()` and `AdventureEndCardState.enter()` only set `visible = true`. After the Path, Abilities, Character or Merchant view has been opened and closed once, the backdrop behind Inventory, Cycling and the end card no longer dims the screen, though it still blocks clicks. Found by reading the code; not reproduced in-game.

### Missing Functionality

- `[LOW]` `center_zone_map_camera` (Space) is declared in `project.godot` but no script reads it, so Space does nothing on the zone map.
- `[LOW]` `open_path_tree` (P) duplicates `open_path` and is never read.
- `[LOW]` No log-window hotkey. `LogManager.toggle_window()` emits `visibility_toggled`, which `LogWindow` listens to, but nothing calls `toggle_window()` (also tracked in [LOGGING.md](LOGGING.md)).
- `[LOW]` I/A/C/P are ignored during adventures because `AdventureViewState.handle_input()` is empty. It is unconfirmed whether this is intended.

### UI

- `[LOW]` Overlays use two transition styles. Inventory, Cycling and the end card toggle the backdrop instantly; Path, Abilities and Character fade it through `GreyBackground.show_with_panel()`/`hide_with_panel()`.
- `[LOW]` `FloatingText._ready()` sets its size with `add_theme_constant_override("font_size", FONT_SIZE)`. Font sizes need `add_theme_font_size_override`, so `FONT_SIZE` never applies and the size comes from `LabelSubheading` (24 px). The script also uses `$Label` instead of `%Label`.

### Tech Debt

- `[LOW]` `MainView.change_state()` clears `state_stack` without calling `exit()` on stacked overlays. This is only safe because no overlay can be open when the base changes: `ZoneViewState` blocks input during the adventure transition, and the end card is popped first.
- `[LOW]` `CyclingViewState._on_stop_cycling()` pops whatever state is on top, not specifically the cycling state.
- `[LOW]` `SystemMenuButton` issues:
  - `BADGE_PROVIDER` is unused; `_wire_badge_listeners()` and `_refresh_badge()` hard-code ABILITIES/`AbilityManager`.
  - The comment saying icon textures are null is stale; all four icons exist.
  - The scene still lives under `scenes/zones/zone_resource_panel/system_menu/` although only `scenes/ui/toolbar/toolbar.tscn` uses it.
- `[LOW]` `SystemMenuButton._on_pressed()` and `CyclingView._on_close_button_pressed()` send a pressed `InputEventAction` with no matching release event.
- `[LOW]` Dead code:
  - `InkbrushButton` has no references. It uses the root-level placeholder `res://32.png`, untyped constants, functions without return types, and `$MarginContainer/...` paths.
  - `scripts/utils/text_effect_importer.gd` has no references, no `class_name` and no doc comment.
  - `AbilitiesView.abilities_closed`, `PathTreeView.path_tree_closed` and `InventoryView.inventory_opened` are emitted but have no listeners.
- `[LOW]` Some nodes are created in code despite the scene-tree UI rule: the `ZoneViewState._add_input_blocker()` `Control.new()`, and `FlyingParticle`, which has no `.tscn`.
- `[LOW]` Stale doc comments:
  - The `MainView` class comment lists 4 views; there are 9 states.
  - The `GreyBackground` header names only AbilitiesView/PathTreeView.
  - `TickProgressBar` says the counter is "below the bar"; the scene places it to the right.
- `[LOW]` `MainGame.log_print_level` is set to `0` (`Log.Event.INFO`) in `main_game.tscn`; the script default is `DEBUG`. `Log.Event` orders `INFO`(0) before `DEBUG`(1), so INFO prints every level and DEBUG would hide INFO lines (see [LOGGING.md](LOGGING.md)).
- `[LOW]` `project.godot` mismatches:
  - `[dialogic] extensions_folder = "res://addons/dialogic_additions"` points to a folder that does not exist.
  - `config/features` lists "Forward Plus" while the renderer is `gl_compatibility`.
