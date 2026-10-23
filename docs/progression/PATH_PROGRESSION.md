# Path Progression System

Last updated: 2026-10-23

## Overview

Path Progression is a per-path skill tree. The player earns **Path Points** and spends them on nodes in the **Pure Madra** tree, which `PathManager` selects automatically on a new save. One node purchase can unlock combat abilities and cycling techniques, or add numeric perks (Madra generation, max Madra, Core Density XP, and so on).

Status at a glance:

| Area | State on this branch |
|------|----------------------|
| Trees | 1 (`pure_madra`), Tier 1 / Foundation only. 14 nodes, 22 points to max everything |
| Node mix | 2 keystone, 4 major, 5 minor, 3 repeatable |
| Point sources | Every 10th Core Density level (1/2/3/4 points by stage); quest "First Steps Out" (+1); dev panel |
| Perks that work in play | 3 unlock nodes. They grant 2 abilities (Empty Palm, Power Font) and 2 cycling techniques (Smooth Flow, Torrential Flow) |
| Perks that do nothing yet | 7 numeric nodes: aggregated into `PathEffectsSummary`, but no system reads it. 4 nodes have no effects at all |
| Tier gates | Enforced in `PathManager.can_purchase_node()`, with no UI. Every node is Foundation |
| Path choice / ascension / respec | Not built. Pure Madra is auto-selected (`DEFAULT_PATH_ID`) |

The original design (paths as Madra types, tier gates, budget branching, ascension) is kept in [Planned Design](#planned-design-not-built).

## Player Experience

1. A new save starts on the Pure Madra tree with 0 points. The Path button is always on the zone view's dock.
2. From the zone view, press **P** or click **Path** on the dock. A grey backdrop fades in while the ink-and-gold Path book opens (one of the four menu books, see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md#menu-books)). Other views ignore P.
3. **Chapters.** Side tabs on the book's left edge hold the cultivation stages: Foundation, Copper, Iron and Jade. A stage the player hasn't reached shows a padlock, can't be opened, and its tooltip says "Reach <Stage> to open this chapter." The book opens at the highest stage reached (always Foundation today, since nothing advances the stage). Switching to another reached stage plays the page turn.
4. **Left page:** the "Path" title ribbon, a plaque with the path's name ("Pure Madra"), and a card holding the open stage's tree on a dark inset, fitted to the card, with "Foundation · stage 1 of 4" above it. Only nodes whose `required_stage` is the open stage are shown, joined by prerequisite lines:
   - Keystones are hexagons with a swirling shader.
   - Majors are diamonds.
   - Minors and repeatables are circles; repeatables show `n/max` centred under the node.
   - A purchasable keystone pulses with a glow ring.
5. **Right page:** a plaque and a card describing what was last pointed at. Hovering a node enlarges it to 1.15× and describes it: name (plus `(n/max)` on repeatables), type ("Major node"), description, green effect lines, and either `Cost: N point(s) · click the node to buy it` or `Purchased`. Hovering the path-name plaque describes the path itself (description, Strengths, Weaknesses, Cycling and Combat lines); that is also what shows when the book opens. The card keeps one height (300 px) whatever it describes, with the cost or "Purchased" line at its foot, so nothing below it moves. Below: an "Active Benefits" plaque over a card listing what each purchased node of every stage grants, one green "▲" line each ("▲ +25 Max Madra"), or "None yet. Buy a node on the tree." The list scrolls with the wheel, shows no scrollbar and has no tooltips. The points to spend sit in a small badge (star and number) in the right page's top-right corner, beside the plaque.
6. Left-drag on empty space pans the tree. The mouse wheel zooms between 0.4× and 1.5× toward the cursor.
7. Points come from finishing the quest "First Steps Out" (+1) and from every 10th Core Density level (+1 in Foundation). While any point is unspent, the dock's Path button shows the brass ring and a cinnabar seal with the balance; no log line or toast announces a new point.
8. Clicking an available node buys one level:
   - The point is deducted and node and line colors update.
   - Energy pulses run along lines that join two purchased nodes.
   - A particle burst plays on a node's first purchase.
   - The node appears under **Active Benefits**, and the points badge updates.
   - Clicking a node that can't be bought does nothing.
9. Pure Core Awakening unlocks the Empty Palm ability and the Smooth Flow technique. Power Font unlocks the Power Font ability. Torrential Flow unlocks the Torrential Flow technique. The player equips them in the Abilities view (its dock button shows a ring while one is unequipped) and from the technique drawers in the zone chest while cycling.
10. The other 11 nodes can be bought and are listed as active benefits, but they change nothing in play today.
11. **Esc** (`ui_cancel`), **P**, the close tab on the book's top edge, or a click outside the book closes it.

## Architecture

```
PathManager (autoload Node)                   — singletons/path_manager/path_manager.gd

MainView (scenes/main/main_game/main_game.tscn)
  MainViewStateMachine
    PathTreeViewState (Node)                  — path_tree_view_state.gd (BookViewState)
  GreyBackground (Panel, z 2)                 — scenes/ui/grey_background/grey_background.gd (shared modal backdrop)
  PathTreeView (Control, z 3, hidden)         — path_tree_view.tscn / path_tree_view.gd (MenuBookView, theme book_theme.tres)
    BookLayer (centred, scale 2)
      %BookFrame                              — scenes/ui/book_frame/, style path_book_style.tres
      BookContent
        %StageTabs                            — tab_switcher.gd: FoundationTab, CopperTab, IronTab, JadeTab (tab_button.tscn,
                                                stage_*.png icons, set_locked() with a padlock and tooltip)
        %TitleBanner                          — TabBanner "Path"
    %PageLayer (centred, screen pixels)
      LeftPage (VBox)
        %PathPlaque (Label, LabelBookPlaque)  — tree.path_name; hover → show_path_info()
        TreeCard (PanelBookCard) > TreeVBox
          %StageLabel                         — "Foundation · stage 1 of 4"
          TreeInset (PanelBookInset, dark)
            %TreeArea (Control, clip_contents) — pan/zoom input (gui_input)
              %NodeContainer (Control)        — path_node_container.gd; draws connection lines
                PathNodeUI × N                — runtime instances of path_node_ui.tscn
                Line2D × M                    — runtime energy overlays (child index 0, behind nodes)
          TreeHint                            — "drag to pan · wheel to zoom"
      RightPage (VBox)
        %DetailPlaque                         — the node's or the path's name
        %DetailsCard (PathDetailsCard)        — path_details_card.tscn / .gd, fixed 300 px tall
        BenefitsPlaque ("Active Benefits")
        BenefitsCard (PanelBookCard)          — fills the rest of the page
          %BenefitsArea (ScrollContainer)     — benefits_area.gd, scrollbar hidden > BenefitsBox > %BenefitsLabel (LabelBookPositive),
                                                %BenefitsEmpty (LabelBookMuted)
      PointsBadge (PanelBookPill, top-right)  — StarIcon, %PointsLabel ("N"); tooltip "Path points to spend"

PathNodeUI (TextureButton)                    — path_node_ui.gd
  %Border (Panel)                             — legacy; hidden in _ready()
  %LevelLabel (Label)                         — "n/max" on repeatables, centred under the node (22 px, dark outline)
  (runtime) swirl ColorRect                   — keystones: path_node_keystone.gdshader
  (runtime) border ColorRect                  — majors/minors/repeatables: path_node_border.gdshader
  (runtime) 12 particle ColorRects            — first purchase only

PathDetailsCard (PanelContainer, PanelBookCard) — path_details_card.gd
  HeaderRow (IconSlot > %DetailIcon, %DetailName, %DetailType), %DetailDescription,
  %DetailEffects (LabelBookPositive), %DetailTraits (path only), FooterSpacer,
  %DetailFooter (cost or "Purchased", at the card's foot)

PureMadraTier1Layout (Node2D)                 — layouts/pure_madra_tier1_layout.tscn
  <node_id> (Marker2D + PathLayoutMarker) × 14
```

Exported wiring in `path_tree_view.tscn`:
- `PathTreeView.stage_layouts` = `[pure_madra_tier1_layout.tscn]`: one layout per chapter, in `PathTreeView.STAGES` order (Foundation, Copper, Iron, Jade). Chapters without a layout are empty.
- `PathTreeView.path_node_ui_scene` = `path_node_ui.tscn`.
- PathDetailsCard icons are `keystone.png`, `major.png`, and `minor.png`; repeatables reuse `minor.png`. The path's own icon is `star_icon.png`.

## Data Model

### PathTreeList (`Resource`)
| Field | Type | Description |
|-------|------|-------------|
| `path_trees` | `Array[PathTreeData]` | Registry loaded by PathManager (`resources/path_progression/path_tree_list.tres`) |

### PathTreeData (`Resource`)
| Field | Type | Description |
|-------|------|-------------|
| `path_id` | `String` | Unique key, e.g. `"pure_madra"`. Stored in `SaveGameData.current_path_id` |
| `path_name` | `String` | Header title, uppercased |
| `path_description` | `String` (multiline) | Madra info popup |
| `madra_strengths` / `madra_weaknesses` / `madra_cycling` / `madra_combat` | `String` | Popup lines, prefixed "Strengths:", "Weaknesses:", "Cycling:", "Combat:" |
| `theme` | `PathThemeData` | Optional. When set, nodes get shader overlays and themed colors |
| `nodes` | `Array[PathNodeData]` | Every node across all tiers |

Methods:
- `get_node_by_id(id)`.
- `get_nodes_for_stage(stage)`, unused in production.
- `get_total_tree_cost()`, which sums `point_cost × max_purchases`; unused in production.
- `validate()`, which requires a non-empty `path_id` and valid nodes, unique ids, and prerequisites that are non-null and in the tree.

### PathNodeData (`Resource`)
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String` | `""` | Unique within the tree. Also the layout `Marker2D` name and the save key |
| `display_name` | `String` | `""` | Details card title |
| `description` | `String` (multiline) | `""` | Details card body (plain text; the card is a `Label`) |
| `node_type` | `NodeType` | `MINOR` | `KEYSTONE` (0), `MAJOR` (1), `MINOR` (2), `REPEATABLE` (3). Visual and label only; PathManager never reads it |
| `icon` | `Texture2D` | `null` | Used as `texture_normal` if set. Unset on every node |
| `prerequisites` | `Array[PathNodeData]` | `[]` | Direct resource references. All must be at level ≥ 1 (AND) |
| `required_stage` | `CultivationManager.AdvancementStage` | `FOUNDATION` | Tier gate, compared with `>=` |
| `point_cost` | `int` | `1` | Cost per purchase (≥ 1) |
| `max_purchases` | `int` | `1` | `> 1` makes the node repeatable (`is_repeatable()`) |
| `effects` | `Array[PathNodeEffectData]` | `[]` | Applied once per purchased level |
| `benefit_summary` | `String` | `""` | Sidebar value text; falls back to `description` |

`validate()` requires a non-empty `id` and `display_name`, `point_cost >= 1`, and `max_purchases >= 1`.

### PathNodeEffectData (`Resource`)
| Field | Type | Description |
|-------|------|-------------|
| `effect_type` | `EffectType` | See table below |
| `float_value` | `float` | Numeric magnitude |
| `attribute_type` | `CharacterAttributesData.AttributeType` | `ATTRIBUTE_BONUS` only (default `STRENGTH`) |
| `string_value` | `String` | `UNLOCK_ABILITY`: an `ability_id`. `UNLOCK_CYCLING_TECHNIQUE`: a technique `id` |

| # | EffectType | `PathEffectsSummary` field | Stacking per level | Used by (Pure Madra) | Consumed in game? |
|---|-----------|----------------------------|--------------------|----------------------|-------------------|
| 0 | `ATTRIBUTE_BONUS` | `attribute_bonuses[attr]` | `+ value × level` | — | No |
| 1 | `MADRA_GENERATION_MULT` | `madra_generation_mult` | `× value^level` | `madra_surge` | No |
| 2 | `MADRA_CAPACITY_BONUS` | `madra_capacity_bonus` | `+ value × level` | `expanded_core` | No |
| 3 | `CORE_DENSITY_XP_MULT` | `core_density_xp_mult` | `× value^level` | `dedicated_cultivation` | No |
| 4 | `STAMINA_RECOVERY_MULT` | `stamina_recovery_mult` | `× value^level` | `iron_will` | No |
| 5 | `CYCLING_ACCURACY_BONUS` | `cycling_accuracy_bonus` | `+ value × level` | `cycling_focus` | No |
| 6 | `ADVENTURE_MADRA_RETURN_PCT` | `adventure_madra_return_pct` | `+ value × level`, clamped to `1.0` | `madra_reclamation` | No |
| 7 | `MADRA_ON_LEVEL_UP` | `madra_on_level_up` | `+ value × level` | `breakthrough_surge` | No |
| 8 | `UNLOCK_ABILITY` | `unlocked_abilities` | Appended once | `pure_core_awakening`, `power_font` | Yes. `purchase_node()` → `AbilityManager.unlock_ability()` |
| 9 | `UNLOCK_CYCLING_TECHNIQUE` | `unlocked_cycling_techniques` | Appended once | `pure_core_awakening`, `torrential_flow` | Yes. `purchase_node()` → `CyclingManager.unlock_technique()` |

### PathEffectsSummary (`RefCounted`)
An aggregated snapshot that `PathManager._recalculate_effects()` rebuilds from scratch. Defaults are the "no bonus" values:
- `attribute_bonuses: Dictionary = {}`
- the three `*_mult: float` fields = `1.0`
- the other float fields = `0.0`
- `unlocked_abilities` and `unlocked_cycling_techniques: Array[String] = []`

### PathThemeData (`Resource`)
| Field | Used by |
|-------|---------|
| `swirl_primary` / `swirl_secondary` / `swirl_tertiary` | Keystone swirl shader colors |
| `border_color` | Available-node border; border shader `border_color` (locked = ×0.65, alpha 0.8) |
| `border_glow_color` | Purchased border; keystone glow ring; shader `glow_color`; purchase particles |
| `fill_available` | Available fill (locked = ×0.75) |
| `fill_purchased` | Purchased/maxed fill |
| `line_available` | Line from a purchased prerequisite (locked = ×0.5) |
| `line_purchased` | Line between two purchased nodes; base color of the energy line |
| `line_energy_color` | Energy pulse color |
| `panel_accent_color` | Unused |

### Save fields (`SaveGameData`)
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `current_path_id` | `String` | `""` | Active tree. Set to `"pure_madra"` on first load |
| `path_node_purchases` | `Dictionary[String, int]` | `{}` | node `id` → purchase level |
| `path_points` | `int` | `0` | Unspent balance |

`SaveGameData.reset()` restores all three. Purchases persist through the 5 s `SaveTimer` that calls `PersistenceManager.save_data()`; see [PERSISTENCE.md](../infrastructure/PERSISTENCE.md).

### AwardPathPointEffectData (`EffectData`)
| Field | Type | Description |
|-------|------|-------------|
| `amount` | `int` (default `1`) | Points granted. `process()` is a no-op when `amount <= 0` |

`_init()` sets `effect_type = AWARD_PATH_POINT` (EffectData enum value 7). `process()` logs through `Log.info` (console/file only) and calls `PathManager.add_points(amount)`.

## Core Systems

### PathManager API
| Method | Returns | Notes |
|--------|---------|-------|
| `set_path(path_id)` | `bool` | Sets the tree, clears purchases, sets points to 0, emits `path_set`. Called only by tests |
| `get_current_tree()` | `PathTreeData` | `null` if no path |
| `get_point_balance()` | `int` | |
| `add_points(amount)` | `void` | No sign check. Emits `points_changed` |
| `get_node_purchase_count(node_id)` | `int` | 0 if never purchased |
| `can_purchase_node(node_id)` | `bool` | Checks, in order: tree set → node exists → level < `max_purchases` → points ≥ `point_cost` → stage ≥ `required_stage` → all prerequisites at level ≥ 1 |
| `purchase_node(node_id)` | `bool` | See [Purchase Flow](#purchase-flow) |
| `get_effects()` | `PathEffectsSummary` | Cached summary. Only tests call it |
| `get_unlocked_abilities()` / `get_unlocked_cycling_techniques()` | `Array[String]` | Aggregated unlock ids. Tests only |
| `reset_path()` | `void` | Clears the tree, path id, purchases, and points; emits `points_changed(0)` and `effects_changed`. Tests only |

| Signal | Emitted by | Listeners |
|--------|-----------|-----------|
| `node_purchased(node_id: String, new_level: int)` | `purchase_node()` | `PathTreeView._on_node_purchased` |
| `points_changed(new_balance: int)` | `add_points()`, `purchase_node()`, `reset_path()`, `_restore_current_path()` | `PathTreeView._on_points_changed` |
| `path_set(path_tree: PathTreeData)` | `set_path()`, `_restore_current_path()` | `PathTreeView._on_path_set` |
| `effects_changed(effects: PathEffectsSummary)` | `_recalculate_effects()`, `reset_path()` | None |

Constants and hooks:
- `DEFAULT_PATH_ID = "pure_madra"`.
- `_test_stage_override: int = -1` is a test-only override of the tier-gate stage check.

### Point Economy

| Source | Amount | Trigger |
|--------|--------|---------|
| Core Density milestone | `CultivationManager.PATH_POINTS_PER_STAGE[stage]`: Foundation 1, Copper 2, Iron 3, Jade 4; any other stage (Silver) falls back to 1 | Each level-up in `CultivationManager.add_core_density_xp()` where `level % PATH_POINT_LEVEL_INTERVAL (10) == 0` |
| Quest `q_first_steps` ("First Steps Out") | 1 | `completion_effects` → `AwardPathPointEffectData` (default `amount = 1`) |
| Dev panel "Path Points" row | 0–1000 | `DevPanel._on_apply_points()` → `add_points()` |

The quest awards its point after two steps: defeat an enemy, then return to the Celestial Intervener.

Budget facts:
- The player can't leave Foundation: `CultivationManager.attempt_breakthrough()` is a stub, nothing writes `current_advancement_stage`, and only the Foundation `AdvancementStageResource` exists. Every milestone therefore pays 1 point.
- Through CD 100 a Foundation player can earn 11 points: 10 milestones plus the quest. The tree costs 22 to max, so that is 50% completion.
- Core Density has no level cap in code, and Breakthrough is unimplemented, so milestone points keep coming past CD 100. See [CULTIVATION.md](../cultivation/CULTIVATION.md).
- There are no refunds, respecs, or point sinks outside the tree.

### Purchase Flow

```
PathNodeUI.pressed → node_clicked(node_id)
  → PathTreeView._on_node_clicked(node_id) → PathManager.purchase_node(node_id)
       can_purchase_node(node_id)? else return false (silent)
       path_points -= point_cost; path_node_purchases[node_id] = level + 1
       _recalculate_effects()                    → effects_changed (no listeners)
       points_changed(balance)                   → PathTreeView._refresh_all_nodes()
       node_purchased(node_id, level)            → _refresh_all_nodes() + BenefitsArea.rebuild()
       for each UNLOCK_CYCLING_TECHNIQUE effect  → CyclingManager.unlock_technique(string_value)
       for each UNLOCK_ABILITY effect            → AbilityManager.unlock_ability(string_value)
  → PathNodeUI: if the node went from level 0 to ≥ 1 → _spawn_purchase_particles()
```

Both unlock calls are idempotent and `push_error` on unknown ids. Abilities and techniques go into their own save fields (`unlocked_ability_ids`, `unlocked_cycling_technique_ids`). Nothing equips them automatically.

### Effect Aggregation

`_recalculate_effects()` builds a new `PathEffectsSummary`. For every node at level ≥ 1, it calls `_apply_effect(effect, level)` once per effect:
- **Additive** types add `float_value × level`. `ADVENTURE_MADRA_RETURN_PCT` is clamped to `1.0` after each add.
- **Multiplicative** types multiply by `pow(float_value, level)`, compounding across nodes. Madra Surge at 3/3 gives `1.1³ = 1.331`.
- **Unlock** types append `string_value` once (non-empty, deduplicated).

It runs from `set_path()`, `purchase_node()`, and `_restore_current_path()`.

### Startup, Persistence, Reset

```
PathManager._ready()
  _live_save_data = PersistenceManager.save_game_data
  PersistenceManager.save_data_reset → _on_save_data_reset()
  _load_all_path_trees()      — PathTreeList entries that pass validate(), keyed by path_id
  _restore_current_path()
    current_path_id known    → _current_tree = tree; _recalculate_effects(); path_set
    current_path_id empty    → auto-select DEFAULT_PATH_ID (points untouched); _recalculate_effects(); path_set
    current_path_id unknown  → no tree (view shows "NO PATH")
    always                   → points_changed(path_points)

_on_save_data_reset()       — re-point _live_save_data, clear tree and summary, _restore_current_path()
```

`_restore_current_path()` and `_recalculate_effects()` never re-apply `UNLOCK_*` effects. Unlock state lives only in the AbilityManager and CyclingManager save fields.

### Path Tree View

**Chapters.** `PathTreeView.STAGES` lists Foundation, Copper, Iron and Jade, one side tab each. `is_stage_unlocked(stage)` compares the stage with `CultivationManager.get_current_advancement_stage()`. `_before_open()` re-locks the tabs (so a stage reached between openings unlocks next time), opens the highest reached stage with `open_stage()` (no page turn), and shows the path info. A tab click (`StageTabs.tab_changed`) hides the pages and title ribbon, plays `BookFrame.turn_page()` forwards or backwards by direction, and rebuilds the tree for the new stage on `page_turned`.

**Build.** `PathTreeView._ready()` connects to `node_purchased`, `points_changed`, and `path_set`, then calls `build_tree()`. `build_tree()` builds the open chapter:
1. Clears the container (nodes are freed at once).
2. Passes `tree.theme` to `PathNodeContainer.set_theme_data()`.
3. Reads the chapter's layout from `stage_layouts` (`read_layout_positions()` maps Marker2D **name** → position).
4. Instantiates one `PathNodeUI` per node of the open stage (`PathTreeData.get_nodes_for_stage()`), centered on its marker. A node with no marker lands at (0, 0).
5. Registers a connection for every prerequisite → dependent pair; links to another chapter's nodes are skipped by the container.
6. Refreshes all nodes, rebuilds the benefits list and the points badge, and fits the tree: `_fit_tree()` zooms and centres the chapter's node bounds (marker positions ± 36 px) in `%TreeArea` with a 12 px margin, clamped to [0.4, 1.5]. It runs again when `%TreeArea` resizes and after the book has opened.

**Refresh.** `_refresh_all_nodes()` runs on `points_changed` and `node_purchased`. It updates the balance label, calls `PathNodeUI.refresh(level, PathManager.can_purchase_node(id))` on every node, redraws the lines, and rebuilds the energy `Line2D`s.

**Node visuals.**

| Type | Size | Shape | With a theme |
|------|------|-------|--------------|
| `KEYSTONE` | 72×72 | Hexagon r = 34, drawn in `_draw()` | Swirl `ColorRect` (inset 6 px), `path_node_keystone.gdshader`; spins 3× faster on hover; glow ring (r = 38) while purchasable and unpurchased |
| `MAJOR` | 50×50 | Diamond r = 23 | `path_node_border.gdshader` overlay (`shape_type 1`, `radius 0.34`) replaces the `_draw()` shape |
| `MINOR` / `REPEATABLE` | 40×40 | Circle r = 18 | `path_node_border.gdshader` overlay (`shape_type 0`, `radius 0.38`) |

States:
- **locked**: level 0 and `can_purchase_node()` false.
- **available**: `can_purchase_node()` true.
- **purchased**: level ≥ 1.
- **maxed**: level ≥ `max_purchases`.

The shader `state` uniform is 0 / 1 / 2; purchased and maxed both use 2. Border widths are 2.0 / 2.5 / 3.0 / 3.5. Without a theme, the hardcoded `FILL_*` and `BORDER_*` constants apply.

**Connections.** `PathNodeContainer._draw()` draws an antialiased line from center to center for each connection:
- Both ends purchased: `line_purchased`, 3.0 px.
- Only the prerequisite purchased: `line_available`, 2.5 px.
- Otherwise: `line_available × 0.5`, 2.0 px.

Fallback constants apply without a theme. When the tree has a theme, `rebuild_energy_lines()` adds a 4 px `Line2D` with `path_connection_energy.gdshader` to each both-purchased connection: `line_color = line_purchased`, `energy_color = line_energy_color`.

**Pan and zoom.** `_on_tree_area_gui_input()` handles input:
- A left press on empty `%TreeArea` space starts a pan that moves `%NodeContainer.position`. Nodes are `TextureButton`s, so presses on them don't pan.
- The wheel steps `_zoom_level` by ±0.1 within [0.4, 1.5] and keeps the point under the cursor fixed.

**Right page.** `_on_node_hovered()` calls `show_node_details()`: the plaque takes the node's name and `PathDetailsCard.show_node()` fills the card. The details stay until another node or the path plaque is pointed at. `PathDetailsCard.format_effect()` renders one `▲` line per effect:
- `+15 Cycling Accuracy`
- `+10% Madra Generation` (multipliers display as `(value − 1) × 100`)
- `+10% Madra Return`
- `Unlocks: Empty Palm` (the ability's file name, capitalized)

Hovering `%PathPlaque` calls `show_path_info()`, which shows the path's description and its Strengths, Weaknesses, Cycling and Combat lines from `PathTreeData`.

**Benefits.** `BenefitsArea.rebuild()` writes one `"▲ " + benefit_summary` line (the description when the summary is empty) per purchased node of every stage, in `tree.nodes` order, into `%BenefitsLabel`; with none it shows `%BenefitsEmpty` instead. `get_purchased_count()` counts nodes at level ≥ 1. The points badge shows `PathManager.get_point_balance()` only; the spend total was dropped on 2026-10-21. The row-per-node `BenefitCard` scene was removed the same day.

**Open/close.** `PathTreeViewState` is a `BookViewState`: `enter()` calls `GreyBackground.show_with_panel(path_tree_view)` (the log and the Goals board stay under the backdrop); `ui_cancel`, `open_path`, the book's close tab or a backdrop click call `hide_with_panel()`, and `panel_hidden` pops the state once both the grey fade and the book's close animation have finished.
- **Entry points.** `ZoneViewState.handle_input()` pushes the state on `open_path` (P). The dock's `PathButton` (`SystemMenuButton.MenuType.PATH`) fires `open_path` through `Input.parse_input_event()`, then releases it.

### Layouts

A layout is a `Node2D` scene with one `Marker2D` per node. Each marker is **named after the node `id`** and runs `PathLayoutMarker`, whose `@export var node_data: PathNodeData` lets you edit the node resource inline in the editor. Only the marker name and position are read at runtime. `PathTreeView.stage_layouts` holds one layout per chapter; today only Foundation's, `pure_madra_tier1_layout.tscn`, for whichever tree is loaded. A Copper layout would be the second entry.

### Shaders

| Shader | Applied to | Key uniforms |
|--------|-----------|--------------|
| `assets/shaders/path_node_keystone.gdshader` | Keystone swirl `ColorRect` (hex-clipped) | `swirl_col_primary/secondary/tertiary`, `glow_color`, `state` (brightness 0.3 → 1.0, glow halo when purchased), `hover` (3× spin) |
| `assets/shaders/path_node_border.gdshader` | Major/minor/repeatable overlay | `shape_type` (0 circle, 1 diamond), `border_color`, `glow_color`, `fill_color`, `state`, `radius`, `glow_size`; shimmer and pulse animation |
| `assets/shaders/path_connection_energy.gdshader` | Energy `Line2D` on purchased connections | `line_color`, `energy_color`, `flow_speed` 1.0, `pulse_width` 0.25, `pulse_count` 3, `energy_intensity` 0.8 (base glow 0.15) |

## Integration Points

| System | Direction | Interaction |
|--------|-----------|-------------|
| `CultivationManager` | → PathManager | `add_core_density_xp()` calls `PathManager.add_points(PATH_POINTS_PER_STAGE[stage])` on each level that is a multiple of 10 |
| `CultivationManager` | ← PathManager | `_is_stage_reached()` reads `get_current_advancement_stage()`. `AdvancementStage` types `required_stage` |
| `QuestManager` / `AwardPathPointEffectData` | → PathManager | `q_first_steps` completion → `add_points(1)` ([FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md) Beat 2) |
| `AbilityManager` | ← PathManager | `purchase_node()` → `unlock_ability(id)`. The dock's Abilities ring reflects new unlocks ([ABILITIES.md](../abilities/ABILITIES.md)) |
| `CyclingManager` | ← PathManager | `purchase_node()` → `unlock_technique(id)` ([CYCLING.md](../cycling/CYCLING.md)) |
| `PersistenceManager` / `SaveGameData` | ↔ | Three save fields. `save_data_reset` → `_on_save_data_reset()` |
| `MainView` / `ZoneViewState` / `PathTreeViewState` | → view | `open_path` (P) opens and closes. See [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md) |
| `Dock` `PathButton` (`SystemMenuButton`, `MenuType.PATH`) | ← PathManager, → input | Label "Path", hint "P", `star_icon.png`. The `Dock` reads `get_point_balance()` on ready and listens to `points_changed`: ring plus count seal while the balance is above 0 |
| `GreyBackground` | ↔ PathTreeView | `show_with_panel` / `hide_with_panel` ↔ `animate_open` / `animate_close`; waits for `close_finished` |
| `DevPanel` | → PathManager | "Path Points" SpinBox (0–1000) → `add_points()` |
| `ResourceManager`, `CharacterManager`, `CyclingTechnique`, `AdventureView`, combat | — | **Do not read** `PathEffectsSummary`; numeric perks are inert |

## Existing Content

### Trees
| `path_id` | Name | Nodes | Cost to max | Theme | Layout |
|-----------|------|-------|-------------|-------|--------|
| `pure_madra` | Pure Madra | 14 (2 keystone, 4 major, 5 minor, 3 repeatable) | 22 | `pure_madra_theme.tres` | `pure_madra_tier1_layout.tscn` |

Popup data:
- Description: "The path of Pure Madra. Versatile and balanced, specializing in disruption and neutralization of enemy techniques."
- Strengths: "Disruption, technique cancellation, versatility"
- Weaknesses: "No elemental damage, lower raw power"
- Cycling: "Smooth and balanced, steady generation"
- Combat: "Neutralize, strip buffs, efficient strikes"

### Pure Madra Tier 1 Nodes
Every node is `required_stage = FOUNDATION` and `point_cost = 1`. Status: **Works** = has an in-game effect. **Inert** = effect aggregated but unread. **Stub** = no effects.

| `id` | Name | Type | Max | Prerequisites | Effects (per level) | `benefit_summary` | Status |
|------|------|------|-----|---------------|---------------------|-------------------|--------|
| `pure_core_awakening` | Pure Core Awakening | Keystone | 1 | — | `UNLOCK_ABILITY "empty_palm"`, `UNLOCK_CYCLING_TECHNIQUE "smooth_flow"` | Empty Palm + Smooth Flow | Works |
| `power_font` | Power Font | Keystone | 1 | `pure_core_awakening` | `UNLOCK_ABILITY "power_font"` | Madra Strike unlocked | Works |
| `torrential_flow` | Torrential Flow | Major | 1 | `pure_core_awakening` | `UNLOCK_CYCLING_TECHNIQUE "torrential_flow"` | Torrent Flow unlocked | Works |
| `expanded_core` | Expanded Core | Minor | 1 | `pure_core_awakening` | `MADRA_CAPACITY_BONUS 25.0` | +25 Max Madra | Inert |
| `lingering_silence` | Lingering Silence | Major | 1 | `expanded_core` | — | +2s Silence Duration | Stub |
| `efficient_palm` | Efficient Palm | Minor | 1 | `expanded_core` | — | -20% Palm Cost | Stub |
| `madra_surge` | Madra Surge | Repeatable | 3 | `efficient_palm` **and** `lingering_silence` | `MADRA_GENERATION_MULT 1.1` | +10% Madra Gen | Inert |
| `focused_strike` | Focused Strike | Major | 1 | `power_font` | — | +40% Strike Damage | Stub |
| `strike_efficiency` | Strike Efficiency | Minor | 1 | `power_font` | — | -15% Stamina Cost | Stub |
| `cycling_focus` | Cycling Focus | Minor | 1 | `torrential_flow` | `CYCLING_ACCURACY_BONUS 15.0` | +15 Cycling Accuracy | Inert |
| `dedicated_cultivation` | Dedicated Cultivation | Repeatable | 3 | `cycling_focus` | `CORE_DENSITY_XP_MULT 1.1` | +10% Core Density XP | Inert |
| `breakthrough_surge` | Breakthrough Surge | Minor | 1 | `cycling_focus` | `MADRA_ON_LEVEL_UP 10.0` | +10 Madra on Level Up | Inert |
| `madra_reclamation` | Madra Reclamation | Repeatable | 5 | `torrential_flow` | `ADVENTURE_MADRA_RETURN_PCT 0.1` | +10% Madra Return | Inert |
| `iron_will` | Iron Will | Major | 1 | `madra_reclamation` | `STAMINA_RECOVERY_MULT 1.2` | +20% Stamina Recovery | Inert |

Aggregates at max (unread today):
- `madra_generation_mult` 1.331
- `core_density_xp_mult` 1.331
- `adventure_madra_return_pct` 0.5
- `stamina_recovery_mult` 1.2
- `madra_capacity_bonus` 25
- `cycling_accuracy_bonus` 15
- `madra_on_level_up` 10

Points that buy a working effect: 3 of 22.

### Prerequisite Graph

K = keystone, M = major, m = minor, R = repeatable (×max purchases).

```
pure_core_awakening (K)
├── power_font (K)
│   ├── focused_strike (M)             [stub]
│   └── strike_efficiency (m)          [stub]
├── expanded_core (m)
│   ├── lingering_silence (M) [stub] ─┐
│   └── efficient_palm (m)    [stub] ─┴─ madra_surge (R ×3)   (requires both)
└── torrential_flow (M)
    ├── cycling_focus (m)
    │   ├── dedicated_cultivation (R ×3)
    │   └── breakthrough_surge (m)
    └── madra_reclamation (R ×5)
        └── iron_will (M)
```

### Unlock Targets
| Node | Unlock id | Catalog resource | Display name |
|------|-----------|------------------|--------------|
| `pure_core_awakening` | `empty_palm` | `resources/abilities/empty_palm.tres` | Empty Palm: 8 Madra, 3 s cooldown, damage + cancel cast |
| `pure_core_awakening` | `smooth_flow` | `resources/cycling/cycling_techniques/smooth_flow/smooth_flow.tres` | Smooth Flow Technique |
| `power_font` | `power_font` | `resources/abilities/power_font.tres` | Power Font: 30 Madra, 25 s cooldown, 3 s cast, damage + strip buffs |
| `torrential_flow` | `torrential_flow` | `resources/cycling/cycling_techniques/torrential_flow/torrential_flow.tres` | Torrential Flow |

All four ids resolve in `ability_list.tres` and `cycling_technique_list.tres`. [ABILITIES_MATRIX.md](../abilities/ABILITIES_MATRIX.md) has the authoritative ability stats.

### Themes
RGB(A) values from `resources/path_progression/themes/`. Alpha is 1 unless shown.

| Field | `pure_madra_theme` (used) | `blackflame_theme` (unreferenced) | `earth_theme` (unreferenced) |
|-------|---------------------------|-----------------------------------|------------------------------|
| `swirl_primary` | (0.6, 0.8, 1.0, 0.7) | (0.9, 0.3, 0.1, 0.8) | (0.55, 0.7, 0.35, 0.7) |
| `swirl_secondary` | (0.5, 0.7, 0.95) | (1.0, 0.5, 0.1) | (0.7, 0.6, 0.3) |
| `swirl_tertiary` | (0.4, 0.6, 0.85) | (0.4, 0.1, 0.05) | (0.4, 0.5, 0.25) |
| `border_color` | (0.55, 0.72, 0.95) | (0.85, 0.3, 0.1) | (0.6, 0.7, 0.35) |
| `border_glow_color` | (0.75, 0.88, 1.0) | (1.0, 0.5, 0.15) | (0.75, 0.8, 0.45) |
| `fill_available` | (0.3, 0.4, 0.55) | (0.45, 0.22, 0.15) | (0.38, 0.42, 0.25) |
| `fill_purchased` | (0.38, 0.5, 0.65) | (0.55, 0.28, 0.15) | (0.48, 0.52, 0.28) |
| `line_available` | (0.5, 0.65, 0.8) | (0.7, 0.38, 0.2) | (0.58, 0.62, 0.38) |
| `line_purchased` | (0.6, 0.78, 1.0) | (0.85, 0.3, 0.1) | (0.6, 0.7, 0.35) |
| `line_energy_color` | (0.9, 0.95, 1.0) | (1.0, 0.6, 0.2) | (0.8, 0.85, 0.5) |
| `panel_accent_color` | (0.5, 0.7, 0.95) | (0.85, 0.3, 0.1) | (0.6, 0.7, 0.35) |

## Key Files

| File | Purpose |
|------|---------|
| `singletons/path_manager/path_manager.gd` | `PathManager` autoload: tree state, points, purchases, effect aggregation |
| `scripts/resource_definitions/path_progression/path_tree_list.gd` | `PathTreeList` registry class |
| `scripts/resource_definitions/path_progression/path_tree_data.gd` | `PathTreeData` |
| `scripts/resource_definitions/path_progression/path_node_data.gd` | `PathNodeData` + `NodeType` |
| `scripts/resource_definitions/path_progression/path_node_effect_data.gd` | `PathNodeEffectData` + `EffectType` |
| `scripts/resource_definitions/path_progression/path_effects_summary.gd` | `PathEffectsSummary` (RefCounted) |
| `scripts/resource_definitions/path_progression/path_theme_data.gd` | `PathThemeData` |
| `scripts/resource_definitions/effects/award_path_point_effect_data.gd` | `AwardPathPointEffectData` |
| `singletons/cultivation_manager/cultivation_manager.gd` | `PATH_POINTS_PER_STAGE`, `PATH_POINT_LEVEL_INTERVAL`, milestone award |
| `singletons/persistence_manager/save_game_data.gd` | `current_path_id`, `path_node_purchases`, `path_points` |
| `resources/path_progression/path_tree_list.tres` | Registry (Pure Madra only) |
| `resources/path_progression/pure_madra/pure_madra_tree.tres` | Pure Madra tree |
| `resources/path_progression/pure_madra/nodes/*.tres` | 14 node resources (effects as sub-resources) |
| `resources/path_progression/themes/*.tres` | Pure Madra, Blackflame, Earth themes |
| `resources/quests/q_first_steps.tres` | Quest whose completion awards 1 path point |
| `scenes/path_progression/path_tree_view.tscn` / `.gd` | `PathTreeView` book (chapters, tree, right page) |
| `scenes/path_progression/path_tree_view_state.gd` | `PathTreeViewState` (`BookViewState`) |
| `scenes/path_progression/path_node_container.gd` | `PathNodeContainer`: connections and energy lines |
| `scenes/path_progression/path_node_ui.tscn` / `.gd` | `PathNodeUI` node button |
| `scenes/path_progression/path_details_card.tscn` / `.gd` | `PathDetailsCard`: node or path details on the right page |
| `scenes/path_progression/benefits_area.gd` | `BenefitsArea`: the Active Benefits lines and count |
| `scenes/path_progression/layouts/path_layout_marker.gd` | `PathLayoutMarker` |
| `scenes/path_progression/layouts/pure_madra_tier1_layout.tscn` | Pure Madra node positions |
| `assets/shaders/path_node_keystone.gdshader`, `path_node_border.gdshader`, `path_connection_energy.gdshader` | Node and line shaders |
| `assets/sprites/path_progression/node_frames/{keystone,major,minor}.png` | Node-type icons in the details card |
| `assets/sprites/ui/book/stage_{foundation,copper,iron,jade}_ai.png`, `stage_lock_ai.png` | Chapter tab icons and padlock |
| `tests/integration/test_path_book.gd`, `test_tab_switcher.gd` | Chapters and locking, per-stage tree, right page (stays put between nodes), benefits (marked lines in one card, no scrollbar or tooltips), points badge, level labels under their nodes, tree fit; side tabs |
| `scenes/ui/grey_background/grey_background.gd` | Shared modal backdrop |
| `scenes/ui/main_view/states/zone_view_state.gd` | Pushes `PathTreeViewState` on `open_path` |
| `scenes/ui/dock/dock.gd` / `scenes/ui/dock/system_menu_button/system_menu_button.gd` | The dock's Path button and its count seal |
| `scenes/ui/dev_panel/dev_panel.gd` | Dev "Path Points" grant |

## Tests

| File | Tests | Covers |
|------|-------|--------|
| `tests/unit/test_path_manager.gd` | 25 | Point balance and signal; `set_path` (valid, invalid, clears state); purchase validation (points, max level, prerequisites, no path); purchase execution (deduct, level up, signal, failure); aggregation (additive, a single multiplicative level, repeatable additive stacking, 100% return cap); unlock tracking and dedupe; `reset_path` |
| `tests/unit/test_award_path_point_effect_data.gd` | 4 | `process()` adds `amount`; 0 and negative are no-ops; `effect_type` is `AWARD_PATH_POINT` |
| `tests/integration/test_path_tree_resource_loading.gd` | 3 | `pure_madra_tree.tres` loads and validates; `focused_strike` → `power_font` prerequisite ref; `madra_surge` has two prerequisites |
| `tests/integration/test_dock.gd` | 12 | The dock's Path count seal follows `points_changed` and reads the balance on ready; the Path button fires `open_path`, then releases it |

Untested gaps are listed under [Tech Debt](#tech-debt).

## Planned Design (not built)

Design intent from the original spec (written with PR #20). Nothing in this section exists in code unless it says so.

### Paths and runs
- **Paths are Madra types.** The type drives the cycling technique, the combat abilities, and encounter matchups.
- **One path per run, chosen at the start of each ascension.** The first run is always Pure Madra; today that is the `DEFAULT_PATH_ID` auto-select, with no selection UI. Perks are unique to each path's tree.
- **The tree resets on ascension.** Separate **Ascension Perks** carry over: double path points in Foundation, new paths beyond Pure Madra, and a second core at Jade that grants a second tree.

### Tree structure
- A freeform, constellation-style node graph, fully visible from the start of a run.
- **Tier gates** sit at stage boundaries, drawn as dotted dividers, each entered through a keystone. Keystones can also appear mid-tier. Today `required_stage` is enforced in `can_purchase_node()`, with no dividers.

  | Tier | Required stage |
  |------|----------------|
  | 1 | Foundation |
  | 2 | Copper |
  | 3 | Iron |
  | 4 | Jade |

- **Budget branching.** There are no exclusive forks; scarcity forces the trade-offs. Completion targets are ~60–70% on a first run, ~80% at mid ascensions, and ~90–100% at late ascensions.
- **Node mix target.** Keystone ~20%, Major ~30%, Minor ~25%, Repeatable ~25%. Pure Madra Tier 1 today is 14% / 29% / 36% / 21%.
- **Opening keystone template.** It establishes the Madra type and unlocks one path combat ability and one path cycling technique. Pure Core Awakening follows this template.

### Point economy targets
| Stage | Points per award | Award frequency | Points per stage | Node cost |
|-------|-----------------|-----------------|------------------|-----------|
| Foundation | 1 | Every 10 CD levels | ~10 | 1 |
| Copper | 2 | Every 10 CD levels | ~20 | 2–3 |
| Iron | 3 | Every 10 CD levels | ~30 | 3–4 |
| Jade | 4 | Every 10 CD levels | ~40 | 4–6 |

- The per-award values are implemented (`PATH_POINTS_PER_STAGE`); no node costs more than 1 yet.
- Target first-run budget is ~100 points against a ~140–160 point tree.
- Planned extra sources: adventure first-clears, hidden encounters, a multiplied award on the first level of a new stage, and ascension perks. One-time quest rewards already exist through `AwardPathPointEffectData`.

### Pacing targets (first ascension)
| Transition | Estimated time | Cumulative |
|------------|---------------|------------|
| Foundation → Copper | ~35 min | 35 min |
| Copper → Iron | ~70 min | ~1.75 h |
| Iron → Jade | ~140 min | ~4 h |
| Jade → Silver | ~280 min | ~8.5 h |

That works out to about one point every 3–4 minutes in Foundation and one every ~7 minutes in Jade. Later ascensions should run at about 50–70% of first-run times.

### Pure Madra identity
- **Design intent.** A jack of all trades and master of disruption: neutralize enemy techniques, strip buffs, strike efficiently; smooth, balanced cycling; no elemental specialization and lower raw damage.
- **Tier 1 groupings.**
  - Cycling: accuracy forgiveness, Madra per cycle, max Madra.
  - Combat: Empty Palm and strike upgrades, stamina recovery.
  - Progression: a repeatable CD XP bonus, Madra on level-up, unspent adventure Madra return (10–50%).
- **Tiers 2–4** wait on Tier 1 playtesting, combat development, and the crafting systems.
- **Foundation beat plan.** [FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md) maps keystones to beats:
  - Keystone #1: Pure Core Awakening (built).
  - Keystone #2: an ability keystone. Power Font, the tree's only other keystone, unlocks an ability.
  - Keystone #3: a burst/finisher (not built).
  - Ability slots 3–4 come from non-keystone nodes (not built).

### Other paths (sketches)
| Path | Opening keystone | Combat feel | Cycling feel | Risk |
|------|------------------|-------------|--------------|------|
| Blackflame | Blackflame Striker (burns own health) + aggressive technique | Burst and burn, glass cannon | Fast, punishes misses | High (self-damage) |
| Earth | Stone Pillar (long cast) + Bedrock technique | Time and crush | Slow, more Madra/CD per cycle | Low, but slow |

Theme resources exist for both. Neither has a tree.

### Relationship to the GDD
GDD v0.1 plans three related systems:
- An **Iron Body Tree** unlocked at Iron (basic passives and skill unlocks).
- A **Main Advancement Tree** that unlocks new skills.
- Typed-Madra **Paths** as a Jade-and-beyond stretch goal.

The built system merges the advancement tree and Paths into one per-path tree available from Foundation. There is no Iron Body tree.

### Open design questions
1. Ascension perks: how they are earned, the full list, and how they interact with paths.
2. Second core: when it unlocks, how points split across two trees, and whether both trees can be the same path.
3. Tier 2–4 perk design.
4. Paths beyond three: how many, which Madra types, and which ascension milestones unlock them.
5. Exact node counts per tier and repeatable caps.
6. Award frequency (every 10 CD levels is the starting value), and what to do with points earned past CD ~30 in Foundation ([FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md) Q-6).

## Work Remaining

### Bugs
- `[LOW]` **Zoom starts out of sync.**
  - `PathTreeView._zoom_level` starts at `0.8`, but `%NodeContainer.scale` starts at `1.0` and is only set inside `_apply_zoom()`.
  - The first wheel-up therefore shrinks the tree (1.0 → 0.9), and the cursor anchoring uses the wrong old zoom for that step.
- `[LOW]` **Renamed nodes orphan old purchases.**
  - `path_node_purchases` is keyed by node `id`. The 2026-04-21 renames (`madra_strike` → `power_font`, `torrent_flow` → `torrential_flow`) left stale keys in older saves, and the points spent on them are not refunded.
  - `_restore_current_path()` doesn't migrate or prune unknown keys.
  - A saved `current_path_id` that is missing from `path_tree_list.tres` leaves no tree loaded, with no fallback to `DEFAULT_PATH_ID`.
- `[LOW]` **Energy pulses may not travel along the line (unverified).**
  - `path_connection_energy.gdshader` animates along `UV.x`, but `PathNodeContainer._add_energy_line()` creates `Line2D`s with the default `texture_mode` (none). Godot may not generate UVs in that mode, so the pulse would flash uniformly instead of flowing.
  - Needs an in-game check.

### Missing Functionality
- `[HIGH]` **Numeric perks do nothing.** `PathManager.get_effects()` and `effects_changed` have no callers outside tests. That makes 7 nodes (11 of 22 tree points) inert. Where each effect should plug in:
  - `MADRA_GENERATION_MULT` (Madra Surge): the cycling Madra step, `CyclingTechnique._madra_per_step()` (paid by `_draw_madra_step()` through `ResourceManager.add_madra(amount, true)`).
  - `MADRA_CAPACITY_BONUS` (Expanded Core): the max-Madra calculation. `CultivationManager.get_max_madra()` (the stage's `AdvancementStageResource.get_max_madra()`) is read by `ResourceManager.add_madra()`, the zone view's `CultivatorPlate` and `CyclingTechnique`'s cap check, so the bonus belongs there.
  - `CORE_DENSITY_XP_MULT` (Dedicated Cultivation): `CultivationManager.add_core_density_xp()`.
  - `MADRA_ON_LEVEL_UP` (Breakthrough Surge): the level-up loop in `CultivationManager.add_core_density_xp()`.
  - `CYCLING_ACCURACY_BONUS` (Cycling Focus): the zone radius, `CyclingRules.ZONE_RADIUS` (20). `CyclingRules.tier_for_distance()` and `CyclingTechnique._update_zones()` read it, and each `CyclingZone`'s `CircleShape2D` (radius 20 in the scene) is pinned to it by a test.
  - `ADVENTURE_MADRA_RETURN_PCT` (Madra Reclamation): `AdventureView.stop_adventure()`, by refunding a share of `PlayerManager.vitals_manager.current_madra`.
  - `STAMINA_RECOVERY_MULT` (Iron Will): `AdventureView._update_stamina_regen()`.
  - `ATTRIBUTE_BONUS` (no content uses it): `CharacterManager._get_attribute_bonuses()`, which only sums equipment.
- `[MEDIUM]` **Path points are announced only by the dock.**
  - The dock's Path button shows a ring and a count seal while points are unspent, which is the signal FOUNDATION_PLAYTHROUGH Beat 6 relies on.
  - Neither `CultivationManager` nor `PathManager.add_points()` writes to the in-game `LogManager`, and nothing shows a toast, so a point earned while cycling (the dock hides) or in an adventure (the zone view is hidden) goes unseen until the zone view shows again.
- `[HIGH]` **No effect type can modify an ability.** The upgrade nodes need per-ability cost, damage, cooldown, or duration modifiers that `PathNodeEffectData.EffectType` can't express, and combat (`CombatAbilityInstance` / `CombatEffectManager`) would have to read them.
- `[MEDIUM]` **No ability-slot unlocks.** FOUNDATION_PLAYTHROUGH expects slots 3–4 to come from non-keystone nodes. `AbilityManager.MAX_SLOTS` is a fixed 4 with no gating, and there is no slot effect type.
- `[MEDIUM]` **Tier gates show only as locked chapters.** Each stage is a chapter tab that unlocks when the stage is reached (re-checked each time the book opens), but a node blocked by its stage never says so, and a prerequisite in an earlier chapter shows no link across the page. `PathTreeView` doesn't listen to `CultivationManager.advancement_stage_changed`, so an open book keeps its tabs until it is reopened.
- `[MEDIUM]` **Layouts belong to the view, not the tree.** `PathTreeView.stage_layouts` holds one layout per chapter for whichever tree is loaded. A second path needs a layout reference on `PathTreeData`.
- `[LOW]` **No path selection, respec, or ascension reset in play.**
  - `set_path()` and `reset_path()` are only called by tests.
  - Neither revokes abilities or techniques granted by earlier purchases.
  - `reset_path()` doesn't emit `path_set`, so an open `PathTreeView` would keep the old nodes, all drawn as locked.
- `[LOW]` **The tree opens only from the zone view.** `open_path` is handled only in `ZoneViewState.handle_input()`; see [MAIN_VIEW.md](../infrastructure/MAIN_VIEW.md).

### Content
- `[HIGH]` **Four nodes have no effects, and their text no longer matches the abilities:**
  - `lingering_silence` promises "+2s Silence Duration", but Empty Palm has no silence; its effects are damage + `CANCEL_CAST`.
  - `efficient_palm` promises "-20% Palm Cost" (Empty Palm costs 8 Madra).
  - `focused_strike` promises "+40% Strike Damage", and its description still says "Madra Strike".
  - `strike_efficiency` promises "-15% Stamina Cost", but Power Font has no stamina cost (30 Madra), and its description still says "Madra Strike".
- `[MEDIUM]` **Madra Surge sits behind two stubs.** `madra_surge`, a cycling repeatable, requires both `efficient_palm` and `lingering_silence`, so reaching it costs 2 points that buy nothing.
- `[MEDIUM]` **Foundation budget doesn't match the targets.**
  - 11 points through CD 100 against a 22-point tree is 50% completion; the target is 60–70%.
  - With no CD cap, points keep accruing indefinitely.
- `[MEDIUM]` **Keystone #3 is missing.** The Beat 6 burst/finisher ability from [FOUNDATION_PLAYTHROUGH.md](FOUNDATION_PLAYTHROUGH.md) isn't authored.
- `[MEDIUM]` **Only Tier 1 exists.** All 14 nodes are `FOUNDATION`; there are no Copper nodes.
- `[LOW]` **One tree only.** `path_tree_list.tres` lists only Pure Madra. `blackflame_theme.tres` and `earth_theme.tres` are referenced by nothing.
- `[LOW]` **Text mismatches:**
  - `power_font.benefit_summary` reads "Madra Strike unlocked"; the ability is Power Font.
  - `torrential_flow.benefit_summary` reads "Torrent Flow unlocked".
  - `torrential_flow.description` has the typo "unweildly".
  - `cycling_focus.description` promises a ball slowdown, but the effect is a flat accuracy bonus.
- `[LOW]` **No node icons.** `PathNodeData.icon` is unset everywhere, and `assets/sprites/path_progression/node_icons/pure_madra/` holds only `.gitkeep`. There is no repeatable frame; the sidebar reuses `minor.png`.

### UI
- `[MEDIUM]` **Locked and unaffordable look the same.** A node looks "available" only when `can_purchase_node()` is true, so a node with its prerequisites met but no points looks the same as one missing prerequisites. With a theme, a partially bought repeatable also looks the same as a maxed one.
- `[MEDIUM]` **The details card never explains a block.** It doesn't list prerequisites, the required stage, or "not enough points".
- `[MEDIUM]` **ACTIVE BENEFITS shows inert perks as active**, for example "Lingering Silence — +2s Silence Duration" and "Expanded Core — +25 Max Madra".
- `[LOW]` **Unlock lines use ids, not names.** Abilities read "Unlocks: Empty Palm" from the capitalized file name and techniques read "Unlocks: smooth_flow", instead of `AbilityData.ability_name` / `CyclingTechniqueData.technique_name`.
- `[LOW]` **Repeatables show per-level values only.** The details card's effect line and the Active Benefits line never show the stacked total or the level; Madra Surge at 3/3 still reads "+10% Madra Gen".
- `[LOW]` **Little purchase feedback.** A failed purchase gives no feedback and there are no SFX. The particle burst plays only on a node's first purchase (`PathNodeUI._on_pressed()` checks `was_purchased`).
- `[LOW]` **No pan bounds or reset-view control.** The tree is fitted when a chapter opens, but a pan can push it out of the card until the book is reopened.

### Tech Debt
- `[MEDIUM]` **Missing tests:**
  - The Core Density milestone award in `CultivationManager.add_core_density_xp()` (tested nowhere).
  - Tier gates (`_test_stage_override` is always `JADE`).
  - `_restore_current_path()` auto-select and restore.
  - The unlock calls `purchase_node()` makes to AbilityManager and CyclingManager.
  - Multiplicative stacking above level 1.
  - A content test that every `UNLOCK_*` id resolves and every node has a layout marker.
- `[LOW]` **Stale doc comments:**
  - `PathNodeEffectData` says `UNLOCK_ABILITY.string_value` is a resource path (it's an `ability_id`) and that effects "stack additively" (multipliers compound via `pow`).
  - `PathEffectsSummary.unlocked_abilities` / `unlocked_cycling_techniques` say "Not yet consumed… (wired during ability rework)".
  - The `PathNodeContainer` class comment says lines meet node edges; `_draw()` draws center to center.
- `[LOW]` **Unused API and nodes:**
  - `get_unlocked_abilities()`, `get_unlocked_cycling_techniques()`, `get_total_tree_cost()`, and `PathNodeData.is_repeatable()` have no production callers.
  - `PathThemeData.panel_accent_color` and `PathNodeContainer._node_radii` are never read.
  - The `PathNodeUI` `%Border` panel is always hidden.
  - The `open_path_tree` input action duplicates `open_path` (both bound to P) and is unused.
- `[LOW]` **Duplicated values:** `_create_node_ui()` duplicates the shape radii from `PathNodeUI._draw()`.
- `[LOW]` **UI nodes are built in code** instead of following the scene-first convention:
  - `PathNodeUI` builds its swirl, border, and particle `ColorRect`s.
  - `PathNodeContainer._add_energy_line()` builds `Line2D`s.
- `[LOW]` **Path state and unlock state can drift.** UNLOCK effects are applied only at purchase time. Saves that bought Pure Core Awakening before the CyclingManager/AbilityManager wiring (PRs #21/#22) never received Smooth Flow or Empty Palm, and nothing reconciles them on load.
- `[LOW]` **Robustness gaps:**
  - `add_points()` accepts negative amounts with no floor.
  - `get_node_purchase_count()`, `can_purchase_node()`, and `reset_path()` dereference `_live_save_data` without a null check.
  - `PathTreeData.validate()` doesn't check `UNLOCK_*` ids against the catalogs or that each node has a layout marker.
- `[LOW]` **Test isolation.** `test_path_manager.gd`'s `after_each()` gives back only `CyclingManager`'s save and technique index. It leaves behind `PathManager._test_stage_override = JADE`, a throwaway `_live_save_data`, and a one-entry `AbilityManager._abilities_by_id` for later tests.
