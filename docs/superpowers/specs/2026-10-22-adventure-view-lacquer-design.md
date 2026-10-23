# Adventure View in Lacquer and Brass: Design

> **Status:** design written on 2026-10-22, after a two-round grill with mock reviews, and checked against the code the same day. PR 1 (the map and the frame) was built on 2026-10-23 on `feat/adventure-view-styleguide-1fc223` (not merged); its plan's "As built" section lists the deviations. PR 2 (the fight) is not built.
>
> **Mock-up:** [adventure-view-lacquer-mockup.html](../mockups/adventure-view-lacquer-mockup.html) shows the decided design (1:1 with the 1920x1080 viewport, interactive, mock controls above the frame). Serve the repo root to view it (`.claude/launch.json`, `adventure-mockup`), because it loads the kit, the fonts and the user's art by relative path. Its textures are built by `docs/superpowers/mockups/adventure-view-lacquer/gen/` and drawn in Aseprite (`.../aseprite/`). Where this spec and the mock differ, this spec wins.
>
> **Builds on:** [STYLE_GUIDE.md](../../STYLE_GUIDE.md) (rules, palette, components, the cascade backlog rows A1–A9, S1–S3, B1–B9) and the zone view's [lacquer kit](2026-10-21-zone-view-lacquer-kit.md) and [map-first design](2026-10-21-zone-view-map-first-design.md).
>
> **Scope:** the adventure view (`MainView/AdventureView`): the hex map, the frame around it (vitals cabinet, chest, technique dock), the fight's HUD, the combat stage and the fighters.
>
> **Out of scope:** the end card (`AdventureEndCard`, style guide E1) and its backdrop (F5); the menu books; cycling; dialogue; the zone view, which this design reuses but does not change, apart from the orb shader gaining colour uniforms (see [Shaders](#shaders)) and `MapFloater` moving to the shared `LacquerFloater` (see [The fight](#the-fight)).

## Goal

The zone view became the game's hub in Lacquer and brass (PR 51). Stepping into an adventure still drops the player into the old look. Captures of the running game on 2026-10-22 (`today_*_ai.jpg` in the mock folder) show five problems:

1. **Floating frames.** The Log (top left), Goals (top right), the timer pill, the encounter panel over the map, the HUD dock and, in a fight, the enemy's plate are six boards of similar weight with no frame, the problem the zone view fixed.
2. **The rejected look.** A painted parallax forest with a teal cast, a glowing fog shader with smoke veils and an orange-to-magenta `?`, a teal map pin, translucent navy panels, liquid orbs, gold glow rings, eased tweens and fades (style guide §2).
3. **Mixed pixel sizes.** Tiles at 1x beside a character at 2.5x, glyphs at 84 px, third-party painted fighters scaled to 280 px, icons at off-grid sizes.
4. **Missing information.** The run's progress shows only on the end card. Choices do not say what they do (their authored tooltips are never shown). A click with too little Stamina does nothing and says nothing.
5. **Broken continuity.** Entering an adventure moves the Log and Goals and drops the cabinet, so the Madra the player just drained has nowhere to land.

## Decisions

"User" means the user decided it in review. "User, accepted" means the user accepted a listed assumption or recommendation without changing it.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | The adventure view: the map, the HUD, the fight HUD and the combat stage, in one design. **Not** the end card | User, round 1; the end card cut in round 2 ("we might get away from cutting scope altogether and removing the end screen view redesign") | The end card is taken up (style guide E1); start from mock round 1's paper scroll |
| Delivery | Two PRs: (1) the map and the frame, (2) the fight | User (round 1 had three; the end card PR left with the end card) | — |
| Layout | **Columns**: the zone view's frame stays for the adventure. The left cabinet holds the run's vitals with Goals hung under it and the Log at the bottom, where they sit at home. The right chest holds the run (clock, Here tray, the encounter and its choices, a Run ledger) and, in a fight, the opponent. The four techniques sit in the bottom-centre dock | User, round 1 | — |
| Vitals | The cabinet's three rows become Health, Madra and Stamina for the run | User, round 1 | — |
| Technique dock | Centred at the bottom, in the zone dock's place, not under Goals | User, round 1: it looks better centred | Playtests show players lose track of their resources in a fight |
| Placeholder art | New art (fighters, stage, markers) is placeholder pixel art drawn with the aseprite MCP, in a wuxia spirit, named `_ai` | User, round 1 | The user's own art arrives |
| Beyond the look | The look plus small fixes: say why a click does nothing, show what a choice does, the Run ledger, the opponent's techniques | User, round 1 | — |
| Map zoom | 1, fixed: today's density, no wheel zoom; the camera follows the player | User, accepted (round 2) | Maps outgrow the map window |
| Map markers | **Lacquer coins** in a screen-space layer on the kit's 2x grid: the user's glyph in a brass-rimmed coin; a carved coin with a tan `?` on a revealed tile; a carved coin with the glyph in the locked veil once cleared; a vermilion inner ring for the boss, whose coin shows through the fog once revealed. On the current hex the coin rides above the character | User, accepted (round 2) | — |
| Technique cooldown | A **radial sweep shadows the button**: the part still to recharge shows the icon in the kit's dark locked veil (a palette state, never an alpha overlay), uncovered clockwise from 12 o'clock in 24 whole steps worked out per 2 px cell, with the whole seconds left in the centre (cream, the painted titles' hard 2 px shadow). A brass flash when it is ready. The cost stays under the slot. In the game: one canvas_item shader on the icon with a single `progress` uniform | User, round 2 ("a radial progress bar that basically shadows out the button … with the cooldown in the center of it") | — |
| Interrupt-window cue | None: no "Interrupt now" line and no frame in the last 0.6 s of an enemy cast. "Interrupted" still shows when one lands | User, round 1 | — |
| Opponent chest | Health, its cast (Casting tray), its techniques, the reward; a "Buffs" row only when it has a buff or debuff (round 1's "Effects") | User, round 1; Buffs accepted in round 2 | — |
| Health and Stamina colours (style guide G2) | Health, crimson: `#FFD9D2` `#E8737A` `#B8304A` `#5A1626` `#3A0E18` (text `#E8737A`, 5.9:1 on lacquer). Stamina, bamboo: `#EEF5C8` `#C9DB86` `#8FAE3E` `#3E5418` `#1E2A0C` (text `#C9DB86`, 11.5:1). Floaters take the colour of the resource that changed and a sign for direction | User, accepted (round 2) | — |
| Fighter size | About 210 px tall on screen (about 104 art px at 2x); bosses larger. The mock's placeholders are 168 px | User, accepted (round 2) | — |
| Combat stage | One static stage at 2x per adventure (the Shallow Woods: a moonlit bamboo grove in the fog tiers, the clearing in the forest tiles' greens); no ambient motion; the `Atmosphere` layer (vignette, mist, motes) leaves the adventure. The grill said "per zone"; the stage belongs to the place the fight happens, which is the adventure, so the data lives on `AdventureData` | User, accepted (round 2; style guide A-Q1, A-Q2) | A fight feels too still: stepped fireflies or falling leaves |
| Ability icons (G9) | The user's painted icons, kept as they are in carved sockets. An on-grid redraw is a separate art task (style guide backlog) | User, accepted (round 2) | The user redraws them |
| Map to fight | A 2-step dither dissolve, 200 ms | User, accepted (round 2; G7) | — |
| Plate under the current hex | None: the chest's Here tray names the tile, and at zoom 1 a plate covers neighbouring hexes | User, accepted (round 2) | — |
| Damage numbers | On the lacquer token, like the zone map's floaters (A-Q9) | User, accepted (round 2) | — |
| Boss reveal | No flash: its coin appears, its glyph shakes in even-px steps, the hit-stop stays (A7) | User, accepted (round 2) | — |
| Low time | Under 30 s the clock's readout becomes a vermilion seal (A9) | User, accepted (round 2) | — |
| Character at zoom 1 | The character keeps its 2x size (32x48 on screen) with the kit's shadow, so it reads on a 1x tile; the tiles, rims and route dots are 1x | **Assumed** (this spec; the mock matches) | It looks out of scale in play |
| Cost preview on hover | Dropped: today hovering a technique dims its cost on the orbs and the Stamina bar. The cost line under the slot and the tooltip show the cost instead | **Assumed** (this spec; the mock has none) | Players overspend because they cannot see what a technique leaves them |

## Layout (1920x1080)

The zone view's frame, re-stocked. Columns 440 wide with 24 px margins; the map window runs from x 464 to 1456 and from the top edge to the dock (y 920).

| Region | Rect (x, y, w, h) | Contents |
|---|---|---|
| Map or stage | Full screen, under every board | The hex map at zoom 1 on the map ground `#090E0E`, the current hex's centre at (960, 470); in a fight, the adventure's stage at 2x with the fighters' feet on y 840 (player centred on x 700, opponent on x 1220) |
| Vitals cabinet | 24, 24, 440, 252 | The cultivator cabinet's board (`lacquer_cult_ai.png`). Health orb (42, 40) 80x80; `Health` (138, 46); `142 / 160` (138, 67). Up to three buff sockets right-aligned to x 446 at y 76 (40x40). Madra orb (42, 132); `Madra` (138, 134); `80 / 120` (138, 155). Divider (40, 222). Stamina row: mini bolt (42, 243), `Stamina` (64, 241), rod 240x10 at (136, 245), `80 / 80` right-aligned to x 446 at y 238 |
| Goals | 24, 272 (as in the zone view) | Unchanged GoalsPanel, cords on, hung from the cabinet's rings |
| Log | 24, bottom at 1056 (as in the zone view) | Unchanged LogWindow |
| Chest | 1456, 24, 440, height hugs content | Header: title (Yatra 30/44 brass, ellipsis at 312 px) at (1472, 42), the run clock (88x36) at (1792, 46). Then the expedition page or the opponent page, below |
| · Expedition page | from y 95 | Here tray (1472, 106, 408x88) with its `Here` plate at (1484, 95); then, in flow from y 210: the encounter's lore (16/22), a divider, the choice drawers (392x72), then the Run ledger (128 tall) |
| · Opponent page | from y 104 | `Health` (1472, 108), rod 260x10 at (1540, 112), value right-aligned to x 1880; Casting tray (1472, 146, 408x88) with its `Casting` plate (88x22) at (1484, 135); then in flow from y 254: Buffs row (only with a buff), Techniques, a divider, the reward row |
| Technique dock | 722, 920, 476, 136 | Four slots 80x80 at x 752, 864, 976, 1088, y 938; key caps 22x22 at the slot's (−6, −6); the cost line (mini icon + cost) centred under each slot at +90 |
| Cast tray | 722, 868, 476, 44 | Shown only while the player casts: technique name, rod 240x10 at +170, time right-aligned |
| Technique tooltip | 304 wide, bottom at y 912 (y 860 while the cast tray shows), left at the hovered slot's x − 8 | A plain board (9-slice) with name, cast and cooldown, cost, a divider and the effect text |

Text never goes below 13 px. Every position and size is even.

## Architecture

### Approaches

| | Approach | Verdict |
|---|---|---|
| A | **Dedicated adventure furniture scenes** in `AdventureView`, placed at the zone furniture's coordinates and built from the shared lacquer pieces (`LacquerRod`, `LacquerStripRect`, `LacquerFrameOverlay`, `LacquerText`, the theme, the kit textures). The zone view hides as today; the adventure's boards appear in the same places | **Chosen.** The finished zone view stays untouched, each scene binds to one data source (vitals, run, opponent, loadout), and the board-for-board continuity is visual, which is all the player sees |
| B | Shared furniture with modes: lift `CultivatorPlate` and `ZonePanel` to `MainView` and switch their contents between zone and adventure | Rejected: it couples zone and adventure logic in two finished, complex scenes (`ZonePanel` alone is 284 lines of layout rules) for no visible gain |
| C | Restyle today's scenes in place (`PlayerHud`, `EncounterInfoPanel`, `EnemyNameplate`, `TimerPanel`) and move them into the columns | Rejected: each is built around the old layout (a VBox dock with orbs at its ends, a floating panel, a plate that follows the enemy). Turning them into a cabinet and a chest rewrites them anyway, under names that no longer fit |

For the map:

| | Approach | Verdict |
|---|---|---|
| M1 | **Bring the zone map's machinery into `AdventureTilemap`**: a fog `TileMapLayer` on the zone's `fog_tileset.tres` filled through `ZoneMapMath.fog_tier()` and `fog_art_index()`; a veil atlas source for revealed tiles; rim sprites; route dots through `ZoneRoute.dot_positions()`; a screen-space marker layer modelled on `MapMarkers` | **Chosen.** Same look as the zone map, and the pure helpers are reused as they are |
| M2 | Extract a shared hex-map base class from `ZoneTilemap` first | Rejected for now: a refactor of the finished zone map; revisit when a third hex map appears |
| M3 | Keep the fog shader and restyle it | Rejected: its soft `smoothstep` edge and alpha are the rejected look, and smoke veils cannot be made opaque and stepped |

### Scene tree

New scenes are marked **new**; everything else exists today.

```
MainView
├── ZoneView                                   hidden during a run (ZoneViewState.exit), unchanged
├── AdventureView (Control)                    adventure_view.gd
│   ├── TilemapView (Control)
│   │   └── TilemapSubviewportContainer → SubViewport (canvas_item_default_texture_filter = Nearest)
│   │       └── AdventureTilemap               (tree below)
│   ├── CombatView (Control, hidden off fights) drawn over the map; carries the dither-dissolve material while a fight opens
│   │   ├── CombatStage (TextureRect)          new: AdventureData.combat_stage at 1920x1080 (replaces ZoneViewBackground); use_parent_material
│   │   └── CombatSubviewportContainer → SubViewport (Nearest, transparent); use_parent_material
│   │       └── AdventureCombat                (tree below)
│   ├── VitalsPlate                            new: scenes/adventure/vitals_plate/ (left cabinet; holds a BuffTooltip)
│   ├── AdventureChest                         new: scenes/adventure/adventure_chest/ (right column)
│   │   ├── ChestFrame                         top, tiled middle and bottom slices; hugs the visible page
│   │   ├── TitleLabel, RunClock               RunClock new: scenes/adventure/run_clock/
│   │   ├── ExpeditionPage                     new: HereTray, EncounterSection, RunLedger
│   │   └── OpponentPage                       new: HealthRow, CastingTray, BuffsRow, TechniquesList, RewardRow, a BuffTooltip
│   ├── TechniqueDock                          new: scenes/ui/combat/technique_dock/ (replaces PlayerHud)
│   │   ├── Board, TechniqueSlot x4            new; AbilityButton's role (EMPTY / PREVIEW / ACTIVE) rebuilt in lacquer
│   │   ├── CastTray                           new (replaces CastBar for the player)
│   │   └── TechniqueTooltip                   new (replaces CombatAbilityTooltip) on the plain 9-slice board
│   └── (the Timer moves here from TimerPanel; TimerPanel is deleted)
├── LogWindow                                  stays at the bottom left (no move)
└── GoalsPanel                                 stays under the cabinet (no move)

AdventureTilemap (Node2D)
├── MapGround (CanvasLayer −1) → GroundRect    new: #090E0E, as in ZoneTilemap
├── AdventureFogMap (HexagonTileMapLayer)      new: fog_tileset.tres, tiers 1–3
├── AdventureFullMap                           unchanged (transparent; hex maths for the generator)
├── AdventureVisibleMap                        visited tiles: the forest atlas; revealed tiles: the new veil atlas source
│                                              (AdventureHighlightMap removed)
├── RimLayer (Node2D)                          new: CurrentRim, HoverRim (Sprite2D)
├── RouteDots (Node2D)                         new: AdventureRoute (replaces PathPreview)
├── CharacterBody2D (scale 2) → CharacterShadow, Camera2D (zoom 1; CameraClampController stays, CameraZoomController removed)
└── AdventureMapMarkers (CanvasLayer)          new: an EncounterCoin per revealed tile and per visited encounter tile (screen space)

AdventureCombat (Node2D)
├── PlayerSpot / EnemySpot (Marker2D)          moved into the stage window
├── PlayerCombatant / EnemyCombatant           CombatantNode, unchanged logic
│   └── CombatantVisual                        2x sprite, hard shadow, stepped motion, LacquerFloater numbers
└── (Atmosphere, HudLayer/EnemyNameplate removed)
```

### Node responsibilities

| Scene | Owns | Does | Talks to |
|---|---|---|---|
| `VitalsPlate` | The cabinet board, two orbs (Health, Madra), the Stamina rod, three buff sockets, a `BuffTooltip` | Shows the player's vitals and active buffs; shakes the Stamina row when a walk is refused | Listens to `PlayerManager.vitals_manager` and, in a fight, the player's `CombatBuffManager` |
| `AdventureChest` | The chest frame, title, clock, two pages | Shows one page (expedition on the map, opponent in a fight) and hugs it | Wired by `AdventureView`; forwards `choice_selected` |
| `RunClock` | Recess texture, hourglass mini icon, label | Shows `M:SS`; becomes the vermilion seal at 30 s or less | Reads the run `Timer` |
| `ExpeditionPage` | `HereTray`, `EncounterSection` (lore, choice drawers), `RunLedger` | Shows the tile you stand on, its choices and what each does, and the run so far | `AdventureTilemap` (tile and encounter signals), `AdventureView` (run stats) |
| `OpponentPage` | Health row, Casting tray, Buffs row, Techniques list, reward row | Shows the opponent | The enemy `CombatantNode` (vitals, ability instances, buffs) |
| `TechniqueDock` | Board, four `TechniqueSlot`s, `CastTray`, `TechniqueTooltip` | The loadout on the map (preview), the techniques in a fight | `AbilityManager` (preview), the player's `CombatAbilityManager`; emits `ability_selected` |
| `TechniqueSlot` | Socket, icon with the sweep shader, seconds label, key cap, cost line, frames | EMPTY / PREVIEW / ACTIVE as `AbilityButton` today; casting frame; cooldown sweep; ready flash; refused shake | Its `CombatAbilityInstance` |
| `AdventureMapMarkers` | An `EncounterCoin` per revealed tile and per visited encounter tile | Places coins in screen space each frame (`ZoneMapMath.world_to_screen()`), swaps their state, shakes the boss coin on reveal | `AdventureTilemap` |
| `CombatantVisual` | Sprite at 2x, shadow, number anchor | Stepped enter, attack, hit, bob; whole-frame flashes; floaters | Its `CombatantNode` (as today) |

### Signal map

| Signal | Emitted by | Connected to | Payload | Purpose |
|---|---|---|---|---|
| `health_changed`, `madra_changed`, `stamina_changed` | player `VitalsManager` | `VitalsPlate` | `float` | Orbs, rod and values (existing signals) |
| `buff_applied`, `buff_removed`, `buff_refreshed`, `buff_stacked` | player `CombatBuffManager` | `VitalsPlate` | `buff_id`, duration or count | Player buff sockets (existing signals) |
| the same four | enemy `CombatBuffManager` | `OpponentPage` | as above | The Buffs row, shown only while it has one |
| `health_changed` | enemy `VitalsManager` | `OpponentPage` | `float` | The Health rod and value |
| `cast_started`, `cast_updated`, `cast_finished`, `cast_cancelled` | enemy `CombatAbilityInstance` | `OpponentPage` | instance, time | The Casting tray (existing signals) |
| the same four | player `CombatAbilityInstance` | `CastTray`, `TechniqueSlot` | instance, time | The cast tray; the casting slot's steady brass frame |
| `cooldown_started`, `cooldown_updated`, `cooldown_ready` | player `CombatAbilityInstance` | `TechniqueSlot` | duration or time left | Sweep `progress`, the seconds, the ready flash (existing signals) |
| `ability_selected` | `TechniqueDock` | `AdventureCombat.on_player_ability_selected` | `CombatAbilityInstance` | Same contract as `PlayerHud` today |
| `tile_entered` **new** | `AdventureTilemap` | `AdventureChest` (Here tray, encounter section) | `coord: Vector3i, encounter: AdventureEncounter, first_visit: bool, summary: String` (`""` until resolved) | What the old `encounter_info_panel.setup()/show_panel()` calls did |
| `encounter_resolved` **new** | `AdventureTilemap` | `AdventureChest`, `AdventureMapMarkers` | `coord: Vector3i, summary: String` | The cleared Here tray, completed text and drawers; the coin turns carved (what `show_completed_state()` did) |
| `map_changed` **new** | `AdventureTilemap` | `AdventureMapMarkers`, `RunLedger` | — | Visited or revealed tiles changed |
| `walk_refused` **new** | `AdventureTilemap` | `VitalsPlate` (Stamina shake), `ExpeditionPage` (Here tray shake) | `reason: StringName` (`&"stamina"`, `&"encounter"`) | Say why a click did nothing, or why a walk stopped partway (with a log line) |
| `boss_revealed` **new** | `AdventureTilemap` | `AdventureMapMarkers` | `coord: Vector3i` | The boss coin appears and shakes; the hit-stop runs as today |
| `choice_selected` | `AdventureChest` | `AdventureTilemap._on_choice_selected` | `EncounterChoice` | Same contract as `EncounterInfoPanel` today |
| `run_stats_changed` **new** | `AdventureView` | `RunLedger` | — | Fights, gold, tiles, loot (counters `AdventureView` already keeps for the end card) |
| `start_combat`, `trigger_combat_end`, `boss_defeated` | as today | as today | as today | Unchanged |

### Data flow

**Arriving on an encounter tile.** The walk reaches the tile → `AdventureTilemap._visit()` marks it visited, refills the fog and veil layers, and emits `map_changed` → `AdventureMapMarkers` redraws its coins (the new tile's coin rides above the character) → `tile_entered(coord, encounter, true, "")` → `ExpeditionPage` sets the Here tray (glyph, name, kind tag, one line), the lore, and one drawer per choice whose detail line comes from the choice's `tooltip` (or, for a `CombatChoice` without one, `"Uses <its techniques> · <gold> gold if you win"`, as the mock's "Madra Lash every 3 s · 15 gold if you win" without the cadence, which the enemy's AI does not fix) → `AdventureChest` hugs the new content. Movement locks until a choice resolves the tile, as today.

The fight lines call the production rules rather than repeating them: the enemy is `enemy_pool[0]`, the one `AdventureCombat` fights; the Here tray's Health figure comes from a new static `VitalsManager.max_health_for(attributes)` (Body × 10), which `_get_max_health()` also calls; the gold from a new static `AdventureCombat.gold_reward_for(choice, adventure_action)`, which `_calculate_gold_reward()` also calls. The opponent page's reward row uses the same function.

**Resolving a tile.** A choice resolves → `AdventureTilemap` stores a one-line summary for the tile (a won fight: `Won · <gold> gold`; any other choice: its `success_effects` through `EffectData.describe()`, joined with ` · `, or `Done` when it has none) and emits `encounter_resolved(coord, summary)` → the Here tray shows the summary with the `CLEARED` tag, the lore switches to `text_description_completed` ("Encounter completed." when it has none), the drawers hide (as the choices do today) and the walk hint `Click a hex to walk · 5 Stamina a step · <n> steps left` (n = Stamina / 5, rounded down) shows under the lore, as in the mock, and the tile's coin turns carved. `tile_entered` carries the stored summary on later visits. An effect with no player-facing text (its `describe()` is empty or only its debug string) is left out of a summary.

**Using a technique.** Q → `TechniqueDock` asks the player's `CombatAbilityManager.can_cast_ability_instance()`; a refusal (casting, cooling down, too little of a resource) shakes the slot and goes no further. Otherwise → `ability_selected(instance)` → `AdventureCombat` starts the cast as today → `cast_started` → the slot shows a steady brass frame and `CastTray` appears; `cast_updated` steps its rod → `cast_finished` → `executed` (the fighter's attack keyframes, the target's hit frames and floater) → `cooldown_started(duration)` → the slot's shader `progress` goes to 0 and its label to whole seconds; `cooldown_updated` steps both → `cooldown_ready` → `LacquerFrameOverlay.flash(1)` on the slot.

**Opening a fight.** A `CombatChoice` → `start_combat(choice)` → `AdventureView._on_start_combat()` initialises the fight, binds `OpponentPage` to the enemy and the dock to the player's ability manager, shows the opponent page, and runs the dissolve: `CombatView`, which is drawn over the map, shows half its pixels for 100 ms, then three quarters for 100 ms, then all of them, and `TilemapView` hides. Seen from the map, half of it stays, then a quarter, then none.

## The map

- **Camera.** Zoom 1, fixed; `CameraZoomController` comes off the adventure camera (the zone map keeps its own); `CameraClampController` stays. The camera stays a child of the character and follows it; its drawn position snaps to whole px. The current hex's centre sits at screen (960, 470).
- **Ground and fog.** `MapGround` paints `#090E0E`. `AdventureFogMap` uses the zone's `fog_tileset.tres` (sources 1–3, the kit's fog tiers), filled as `ZoneTilemap` fills its fog: `set_cell(cell, tier, Vector2i(ZoneMapMath.fog_art_index(cell), 0))`, with tier = `ZoneMapMath.fog_tier()` against the visited and revealed tiles (hex distance to the nearest, capped at 3). It covers every cell within the camera's reach (the map's radius plus a screen's margin) that is neither visited nor revealed, and refills when either set changes. Unrevealed map tiles look like any other fog, so the map's shape stays hidden. Both maps instance `hexagon_tile_map_layer.tscn`, so they share one hex layout; the adventure converts with its own layers' `map_to_cube()` and `cube_to_map()`.
- **Tiles.** Visited tiles keep the forest atlas (source 8, `HexForestAtlas.pick()`). Revealed tiles use a new atlas source in `tilemap_tileset.tres`, `hex_forest_veil_atlas_ai.png`: the same 23 variants in the kit's uncharted veil ramp (`#0B1211` `#16211F` `#1C2927` `#243431` `#2D3F3B`, by brightness band) with the uncharted tile's dotted tan rim baked in, at the same atlas coordinates. `AdventureHighlightMap` and its grey overlay go: a cleared tile is marked by its coin.
- **Rims.** `CurrentRim` shows `map/lacquer_hex_current_ai.png` on the player's hex. `HoverRim` shows `lacquer_hex_hover_ai.png` over a hovered visited tile and `lacquer_hex_hover_in_ai.png` over a hovered revealed one. Both are map-space art (the halved kit files), so at zoom 1 they are 1x like the tiles. `HexHoverSelector` goes.
- **Route.** `AdventureRoute` lays the zone map's lit route dots (`map/lacquer_route_dot_lit_ai.png`) hop by hop along the A* route, through `ZoneRoute.dot_positions()` for each pair of tile centres. During a committed walk, dots behind the character hide one at a time. `PathPreview` goes.
- **Character.** `CharacterBody2D` at scale 2 (32x48 on screen), the kit's `map/lacquer_char_shadow_ai.png` under it at scale 2, its drawn position snapped to even px while walking.
- **Coins.** `AdventureMapMarkers` (a `CanvasLayer`, screen space, the kit's 2x grid) holds an `EncounterCoin` per revealed tile and per visited tile with an encounter:

| Tile | Coin frame (`lacquer_marker_tokens_ai.png`, 4 frames of 52x52) | Glyph (32x32) |
|---|---|---|
| Revealed, not the boss (empty tiles too) | 1: carved, tan `?` | none |
| Revealed boss | 3: brass rim, vermilion inner ring | `boss_spritesheet.png`, its 7 frames at 0.2 s each (today's pace) |
| Visited, not cleared | 0: brass rim, lacquer field | the encounter's glyph (`combat_icon.png`, `elite.png`, `rest-sheet.png` (5 frames at 0.4 s each), `treasure.png`, `trap.png`) |
| Visited, cleared | 2: carved | the glyph in the kit's locked veil, lighter steps (`*_spent_light_ai.png`) |

  A coin's centre is the tile's centre 8 px up; on the hex the player stands on it is 56 px up, clear of the character's head (the mock's 40 px assumed the character stood lower on its tile). Coins show and hide outright (no pop-in or stagger). A revealed empty tile shows the `?` coin like any other, as today's veil hides it, so a coin never gives away an empty tile; a visited NoOp tile has no coin. Under the dev panel's Show Whole Map (`set_dev_reveal_all`), every unvisited encounter tile shows its glyph coin (frame 0), as its icon shows today. Glyph mapping by `EncounterType` follows `EncounterIcon` (ambush shows combat). `EncounterIcon` stays for the editor map preview tool (`scripts/tools/map_preview.gd`).

  Glyph sizes follow the style guide's rule for the user's 64 px icons (§9: on the grid at 32 or 64): `combat_icon`, `elite`, `treasure` and the rest strip are drawn in 2x2 blocks (85–100%), so they show at 32. Two are off the grid at 32 and stand in until `_ai` redraws at 16 art px (style guide A4): the boss strip (62% in 2x2 blocks, so halving drops detail) and `trap.png` (32 px native art, shown at file size; no Shallow Woods encounter uses it).
- **Boss reveal.** The first time the boss tile is revealed: the hit-stop runs as today (`Engine.time_scale` 0.25 for 0.15 s), the boss coin appears and shakes on `MapGlyph.SHAKE_KEYFRAMES` (0, −8, 8, −6, 4, 0, each held 0.088 s), and the camera push stays (the one eased motion kept, G7). `BossFlashRect` goes.
- **Walking.** A click that cannot start a walk, and a walk that stops partway because Stamina ran out, emit `walk_refused` (see [Beyond the look](#beyond-the-look)). The rest of the walk logic (A* route, per-step Stamina, committed destination) is unchanged.
- **Removed from the map:** the fog shader's `FogLayer` and `FogOfWarRect`, `FogVeilContainer` and `FogVeilSprite`, `EncounterIconContainer` (no `EncounterIcon` on the map), `AdventureMarker`, `PathPreview`, `HoverSelector`, `AdventureHighlightMap`, the `Atmosphere` instance, `BossFlashLayer`, and the `CanvasLayer` holding `EncounterInfoPanel`.

## The left column

- **Board.** `lacquer_cult_ai.png` (the cultivator cabinet's board) at (24, 24); the Goals board hangs from its rings as in the zone view.
- **Orbs.** Two `TextureRect`s on frame 0 of their orb strips with the orb shader (see [Shaders](#shaders)): Madra on `lacquer_orb_madra_strip_ai.png`, Health on the new `lacquer_orb_health_ai.png` (frame 0 of the Madra strip recoloured to the crimson ramp). `progress` = current / max, set directly. Values in `LabelLacquerBig` (`142` cream, ` / 160` tan), as the cultivator plate shows Madra.
- **Stamina.** A `LacquerRod` with `lacquer_rod_stamina_{empty,full,end}_ai.png` (240 px, 119 steps), the mini bolt and `Stamina` in `LabelLacquerDetail`, `80 / 80` in `LabelLacquerName`. A refused walk shakes the row (the even-px keyframes above).
- **Buffs.** Up to three sockets (`lacquer_socket_buff_ai.png`, 40x40) at x 318, 362 and 406 (the group ends at x 446), y 76, filled from the left, each with the buff's `buff_icon` at 32x32, a count seal (`lacquer_seal_count_ai.png`) for stacks, and a `frame_brass` that flashes once when the buff lands. Hovering one shows the plate's `BuffTooltip` (new, on the plain 9-slice board, replacing `CombatBuffTooltip`: name, whole seconds left, stacks, effect text). The sockets show only in a fight.
- **Goals and Log** stay where the zone view puts them, the Goals cords showing. `AdventureViewState` stops moving them and stops hiding the cords.

## The right chest

- **Frame.** `chest_top` (128), a tiled `chest_mid`, `chest_bot` (48), with the column-shadow trick (style guide §11). Height = max(176, the visible page's bottom + 24), as the zone chest.
- **Header.** The title in `LabelLacquerZoneName`: the adventure action's `action_name` ("The Shallow Woods") on the expedition page, the enemy's `character_name` in a fight. `RunClock` at (1792, 46): `lacquer_timer_ai.png` (a carved recess, 88x36), the hourglass mini icon at +12, +10, `M:SS` in `LabelLacquerNowName`. At 30 s or less the recess becomes `lacquer_timer_low_ai.png` (a vermilion seal, cream text at 5.1:1); nothing flashes. The clock keeps running in fights, as the timer does today. The run's `Timer` node moves from `TimerPanel` to `AdventureView`.
- **Here tray.** `lacquer_now_tray_ai.png` with `lacquer_now_plate_ai.png` reading `Here`; a 48x48 glyph socket at (1488, 126) with the glyph at 32; the name in `LabelLacquerNowName` (ellipsis at 236 px); a carved tag at (1792, 123); one `LabelLacquerDetail` line. States:

| Standing on | Name | Tag | Line |
|---|---|---|---|
| An unresolved fight | its `encounter_name` | `FIGHT` (regular, ambush), `ELITE`, or `BOSS` (a vermilion seal) | `<kind> · <enemy> · <health> Health` |
| Another unresolved encounter | its `encounter_name` | `REST`, `TREASURE` or `TRAP` | its kind |
| A resolved encounter | its `encounter_name` | `CLEARED` | the tile's summary (see [Data flow](#data-flow)) |
| A NoOp tile | `Open ground` (tan) | none | `Click a hex to walk · 5 Stamina a step` |

- **Encounter section.** The encounter's `description` (`text_description_completed` once resolved) in `LabelLacquerLore`, a divider (`lacquer_line_ai.png`), then one drawer per choice: the zone's drawer face (`lacquer_drawer_ai.png`, 392x72), the encounter's glyph at 32 in its socket (`ic_story_ai.png` for a `DialogueChoice`), its `label` in `LabelLacquerName`, a carved tag for a fight (`FIGHT`) or a talk (`TALK`), and the detail line (the choice's `tooltip`, or the derived combat line). A choice whose requirements fail shows tan text and the LOCKED seal; a completed one shows its `completed_label` in tan. Hover is `frame_hover`. No fades. The section holds three drawers in its `.tscn` (the most choices any encounter has is two) and hides the unused ones. Retires `EncounterInfoPanel`, `EncounterChoiceButton` and `action_card_normal.tres` / `_hover.tres`.
- **Run ledger.** A section title `Run` with a groove (the mock's `3 of 23 tiles` beside it repeats the explored figure, so it goes); three figures (the user's `combat_icon`, `gold_icon` and `map_icon` at 32): fights / combat tiles (`_combats_fought` against `get_total_combat_count()`; a lost fight ends the run, so every fight in the ledger was won), gold earned this run, tiles explored / total; then `Loot` and six sockets (40x40) holding the run's latest item awards at 32. Values come from the counters `AdventureView` keeps for the end card.
- **Opponent page.** Health row (`lacquer_rod_health_*`, 260 px); the Casting tray (`now_tray` with the `Casting` plate): the cast's name in `LabelLacquerNowName`, the time left right-aligned (`LacquerText.decimal_bbcode()`), one detail line, and `lacquer_rod_intent_*` (256 px, jade: a cast is progress) on its third row; between casts one tan line, `Gathering its madra`; an interrupt shows `Interrupted` in brass with the even-px shake for 0.6 s. Then the Buffs row (only with a buff: sockets like the cabinet's), the Techniques list (one row per enemy ability: name, cast time, roughly how much it hits for, from `CombatEffectData.calculate_value()` before defence), a divider, and the reward (`gold_icon`, `<gold> gold`, `if you win`).

## The technique dock

- **Board** `lacquer_tdock_ai.png` (476x136, a plain board).
- **Slot.** `lacquer_slot_ai.png` (an 80x80 carved socket with a raised lip, 2 px shadow), the ability icon as a 64x64 `TextureRect` at +8 with the cooldown sweep material, the seconds in a new `LabelLacquerCooldown` centred on the icon, a key cap (`lacquer_keycap_ai.png`, 22x22) at (−6, −6) with the bound key in `LabelLacquerHotkey`, and the cost line under the slot (the resource's mini icon at 16, the cost in `LabelLacquerDetail`).

| State | Shows |
|---|---|
| Empty slot | The socket and the key cap; no icon, no cost |
| Preview (on the map) | The icon; key cap text tan |
| Ready (in a fight) | The icon; key cap text cream; cost cream, or tan when unaffordable |
| Casting | A steady `frame_brass` over the slot |
| Cooling down | The sweep: `progress` = 1 − time left / duration, 24 steps; whole seconds in the centre |
| Ready again | `frame_brass` flashes once |
| Refused (casting, cooling down or unaffordable, per `can_cast_ability_instance()`) | The slot shakes in even px (`MapGlyph.SHAKE_KEYFRAMES`); no log line, since the sweep, the cast tray and the tan cost already say why |
| Hover | `frame_hover`, and the tooltip above the dock |

The dock takes over `AbilitiesPanel`'s input: `ability_slot_1`–`ability_slot_4` (Q, W, E, R) in `_unhandled_input`, only in a fight and while visible, and a click on a slot does the same.

- **Cast tray.** `lacquer_cast_tray_ai.png` (476x44) at (722, 868): the technique's name in `LabelLacquerName`, `lacquer_rod_cast_*` (240 px, jade) at +170, the time left right-aligned. Shown outright while the player casts, hidden otherwise.
- **Tooltip.** A plain lacquer board, `board9.tres` (a `StyleBoxTexture` on `lacquer_board9_ai.png` with its 4 px shadow baked in: margins 8 left and top, 12 right and bottom, filled), a child of the dock (shown and hidden, never instanced): the name in `LabelLacquerPopoverTitle`; `Cast 1.2 s · Cooldown 3 s` (or `Instant`); the cost with its mini icon; a divider; the effect text in `LabelLacquerPopoverBody`. The damage figure today's tooltip shows stays, as one more detail line. Numbers and costs go through `AbilityRow.format_cost()`, `format_seconds()` and `format_number()`, so the dock reads like the Abilities book.

## The fight

- **Stage.** `CombatStage` shows `AdventureData.combat_stage` (new `@export var combat_stage: Texture2D`), a 1920x1080 file drawn at 960x540 art px. The Shallow Woods gets the moonlit bamboo grove (fog-tier stalks and peaks, a flat moon, a stone lantern, the clearing in the forest tiles' greens). Static; no parallax. `ZoneViewBackground` (no other user) and `AdventureCombat._setup_atmosphere()` go. Both SubViewports set nearest filtering (style guide F4).
- **Fighters.** `CombatantVisual` draws the texture at an integer scale of 2: no `display_height` fitting and no fractional scale. Elites get larger art instead of `CombatantData.scale` (1.15 on the Coalescing Spirit and the Ravenous Dreadbeast today), which is removed from the class and the enemy `.tres` files. The shadow is a small hard ellipse sprite in the clearing's dark greens at 2x, with nearest filtering (it forces linear today, style guide F4), drawn per fighter and set on a new `CombatantData.shadow_texture`. Placeholders drawn in Aseprite (wuxia, `_ai`, about 104 art px tall, elites about 120): the player cultivator (loaded in `AdventureCombat._create_player_combatant()`), and the four enemies with their own `CombatantData`: the Starving and Ravenous Dreadbeasts, the Amorphous and Coalescing Spirits. They replace `test_character_sprite.png` and `test_enemy_sprite.png` (third-party placeholders), which every fighter uses today. The boss encounter ("Manifested Spirit Encounter") fights `amorphous_spirit.tres`, so the boss looks like an Amorphous Spirit until it gets its own `CombatantData` (a content task, not this rework).
- **Motion**, all stepped, computed from elapsed time like `MapFloater.rise_at()` (static functions the tests call):

| Today | Lacquer |
|---|---|
| Slide in over 0.45 s, cubic, with an alpha fade | 2 px steps at constant speed over 0.4 s; shown outright |
| Lunge: quad and cubic tweens | Even-px keyframes, each held: −8, +40, +40, 0 (0.06 s each) |
| Hit: recoil with an elastic return, eased white flash | Keyframes −12, −12, 0; the flash is the existing `hit_flash.gdshader` at 1.0 for two frames (0.066 s), then 0, in cream |
| Idle bob: sine tween | Held steps 0, −2, −4, −2 px, 0.6 s each |
| Buff pulse: scale 1.06 | None; the buff socket flashes `frame_brass` once |

- **Floaters.** `MapFloater` moves to `scenes/common/lacquer/lacquer_floater/` as `LacquerFloater` (style guide F6; the zone map's `MapMarkers` follows the rename) and replaces `damage_number.tscn` on the fighters: a token, `LabelLacquerFloater`, 40 px in 20 steps over 1 s, hidden outright. Colours by resource and signed: damage dealt `-23` cream; damage taken `-9` and heals `+12` in Health crimson (`#E8737A`); Madra changes Madra blue; Stamina bamboo. Each fighter's scene holds four floaters and reuses them in turn (a fifth number takes the oldest), where `CombatantVisual` instances a `DamageNumber` per hit today. Cycling's `FloatingText` (the rest of F6) stays for the cycling rework; its combat users (the HUD's orbs and bars) go with them.

## Transitions and timing

| Moment | Lacquer |
|---|---|
| Zone to adventure | Unchanged: the Madra pellets fly from the cabinet's Madra orb to the character, the zone camera zooms 2 to 3 (0.5 s, the eased camera move the zone view keeps), then the adventure view shows outright. Its cabinet, chest and dock stand where the zone view's did; only their contents change |
| Map to fight | The dither dissolve: `CombatView`, drawn over the map, carries a `dither_dissolve.gdshader` material for 200 ms (`dissolve_step` 1: half its pixels in a 2 px checker, 100 ms; 2: three quarters, 100 ms), then drops it, and `TilemapView` hides. Replaces today's 0.25 s alpha fade-in (`AdventureView._fade_in_combat_view()`) |
| Fight to map | Outright |
| Adventure to zone | Unchanged (through today's end card) |
| Boss reveal, low time | See [The map](#the-map) and [The right chest](#the-right-chest) |

## Beyond the look

| Fix | Behaviour |
|---|---|
| A refused walk | Too little Stamina, at the click or partway through a walk: the log says `Too tired to walk · 5 Stamina a step` and the Stamina row shakes. While an encounter waits for a choice: `Choose what to do here first` and the Here tray shakes. Clicks during a walk stay ignored. The log lines are plain (tan) |
| What a choice does | The drawer's detail line, from `EncounterChoice.tooltip` (authored today, never shown) or the derived combat line |
| The run so far | The Run ledger |
| The opponent | The Techniques list and the reward on the opponent page |
| Interrupts | `Interrupted` in the Casting tray (no interrupt-window cue) |

## Theme, palette and shaders

### Theme and palette

- **New variant:** `LabelLacquerCooldown`, BM Euljiro 22/28, cream, a hard 2 px `#150909` shadow (the painted titles' shadow, on the cooldown seconds over the icon). Everything else uses existing `LabelLacquer*` and `RichTextLacquer` variants.
- **New stylebox:** `assets/styleboxes/lacquer/board9.tres` (style guide F2's plain board 9-slice), used by both tooltips.
- **Palette:** the crimson (Health) and bamboo (Stamina) ramps join the style guide's §4 and kit §2; `ThemeConstants` gains `LACQUER_HEALTH` (`#E8737A`) and `LACQUER_STAMINA` (`#C9DB86`) for the floaters. The Log keeps its four tones.
- Every new root (`VitalsPlate`, `AdventureChest`, `TechniqueDock`) sets `lacquer_theme.tres`; nodes live in `.tscn` files; scripts set text, textures, frames, visibility, shader `progress` and `ThemeConstants` colours only (style guide §11, CLAUDE.md).
- Fixed counts are built in the scene and shown or hidden: four technique slots, three buff sockets per side, three choice drawers, six loot sockets, four technique rows on the opponent page (enemies have one or two today), four floaters per fighter, the tooltips. The one exception is the map's coins, whose count depends on the generated map: `AdventureMapMarkers` instances one `EncounterCoin` scene per tile, as `MapMarkers` does for the zone map's plates and glyphs.

### Shaders

- **`lacquer_cooldown_sweep.gdshader`** (new, canvas_item, on the slot's icon): `uniform float progress`; `const float STEPS = 24.0`, `CELL = 2.0`. Per 2 px cell, the angle from 12 o'clock clockwise of the cell's centre around the icon's centre; a cell whose angle is at or past `floor(progress * STEPS + 0.5) / STEPS * TAU` takes the icon's colour mapped by brightness onto the kit's locked veil ramp (`#151A18` `#39423E` `#4B5550` `#5F6A65`); others keep the icon. No alpha blending, no `smoothstep`, no `TIME`. The material is `resource_local_to_scene`. The mock's `adv_ability_*_cd_strip_ai.png` frames are its reference output.
- **`lacquer_madra_orb.gdshader`** gains three colour uniforms (`light`, `pale`, `blue`) whose defaults are today's Madra constants, so the cultivator cabinet does not change; the Health orb's material sets the crimson ramp. `progress` stays the only uniform the scripts touch.
- **`dither_dissolve.gdshader`** (new, canvas_item): `uniform int dissolve_step` (not `step`, a built-in function name); from `FRAGCOORD` in 2 px cells, it discards half the cells (a checker) at 1 and a quarter at 2, so both of `CombatView`'s children (which use the parent's material) dither in one pattern. No alpha.
- **Retired:** `fog_of_war.gdshader` (PR 1) and `vignette.gdshader` (PR 2, with `Atmosphere`), both adventure only. `liquid_wave.gdshader` stays (cycling uses it). `hit_flash.gdshader` stays, driven in whole frames.

## Art

New `_ai` files the build adds. The mock's generators and Aseprite sources make them; an import step bakes the 2 px and 4 px shadows and copies them into `assets/`, as the zone kit's `import_kit.py` did.

| Files | Where | Made by | PR |
|---|---|---|---|
| `lacquer_orb_health_ai.png`, `lacquer_rod_{stamina,health,cast,intent}_{empty,full,end}_ai.png`, `lacquer_slot_ai.png`, `lacquer_keycap_ai.png`, `lacquer_socket_buff_ai.png`, `lacquer_socket_glyph_ai.png`, `lacquer_mini_{health,stamina,hourglass}_ai.png`, `lacquer_plate_casting_ai.png`, `lacquer_timer_ai.png`, `lacquer_timer_low_ai.png`, `lacquer_cast_tray_ai.png`, `lacquer_tdock_ai.png`, `lacquer_board9_ai.png`, `lacquer_marker_tokens_ai.png` | `assets/ui/lacquer/` | `gen/kit_adventure.py`; the coins in Aseprite | 1 (health rod, intent rod, Casting plate: 2) |
| `adv_glyph_{combat,elite,rest,boss,treasure,trap}_spent_light_ai.png` | `assets/sprites/adventure/encounter_glyphs/` | `gen/map_render.py` from the user's glyphs (the mock makes the first four) | 1 |
| `hex_forest_veil_atlas_ai.png` | `assets/sprites/tilemap/hex_tiles/forest/`, next to the user's atlas | a new generator step from `hex_forest_atlas.png` | 1 |
| `shallow_woods_stage_ai.png` | `assets/sprites/combat/stages/` | Aseprite (`adv_stage_bamboo_ai.aseprite`) | 2 |
| Five fighters (the player and four enemies) at about 104 art px, elites about 120, and their shadows | `assets/sprites/combat/` and `.../enemies/` | Aseprite, redrawn larger than the mock's two | 2 |

The user's files (forest tiles and atlas, glyphs, stat and resource icons, ability icons, character sheet, fonts) are used from their own paths and never edited.

## Removed

The enemy's floating plate still needs `ResourceBar`, `BuffBar`, `BuffIcon`, `CombatBuffTooltip` and `CastBar` (its `IntentBar` inherits `cast_bar.tscn`) until PR 2 replaces it, so those go in PR 2.

| PR | Scenes and scripts | Styleboxes and shaders (no other users) |
|---|---|---|
| 1 | `PlayerHud`, `AbilitiesPanel`, `AbilityButton`, `CombatAbilityTooltip`, `ResourceOrb`, `TimerPanel`, `EncounterInfoPanel`, `EncounterChoiceButton`, `AdventureMarker`, `PathPreview`, `FogVeilSprite`, `HexHoverSelector`; from the map scene `AdventureHighlightMap`, `FogLayer`, `BossFlashLayer`, the `Atmosphere` and `CameraZoomController` instances; `AdventureViewState`'s board moves and cord hiding | `panel_dock`, `bar_fill_stamina`, `cost_line`, `orb_ring`, `orb_shine`, `slot_cast_glow`, `panel_keyhint`, `panel_timer`, `panel_encounter`, `action_card_normal`, `action_card_hover` (`.tres`); `fog_of_war.gdshader` |
| 2 | `EnemyNameplate`, `IntentBar`, `CastBar`, `ResourceBar`, `BuffBar`, `BuffIcon`, `CombatBuffTooltip`, `DamageNumber`, `ZoneViewBackground`, `Atmosphere` (`scenes/atmosphere/`, unused once the fight drops it); in `AdventureCombat`, `_setup_atmosphere()`, `_place_nameplate()` and `HudLayer`; `AdventureView._fade_in_combat_view()`; `CombatantData.scale` and `CombatantVisual.display_height` | `panel_nameplate`, `panel_intent`, `cast_bar_fill`, `cast_bar_fill_enemy`, `bar_fill_health`, `bar_track` (`.tres`); `vignette.gdshader` |

Art files these leave unused are the user's or third-party, so they stay until the user says to delete them: `adventure_marker.png`, `smoke_veil_spritesheet.png`, `hex_selector_spritesheet.png` and the two `ability_button_*.png` frames (PR 1); the two `buff_icon_*.png` frames, the five `zones/backgrounds/spirit_valley/` layers, `test_character_sprite.png` and `test_enemy_sprite.png` (PR 2). The mist and mote sprites stay in use by the merchant's own `MerchantAtmosphere`.

`EncounterIcon` (the map preview tool and its test), `CameraZoomController` (the zone map), `liquid_wave.gdshader` and `madra_circle.png` (cycling), `time_icon.png` (the end card), `tooltip_panel.tres` (`pixel_theme`) and `hit_flash.gdshader` stay. Each PR checks every file for other users again before it goes.

## Tests

Per CLAUDE.md, tests call production code; pure maths gets static functions the tests call directly (the `MapFloater.rise_at()` pattern).

| Area | New or rewritten tests |
|---|---|
| Sweep | `TechniqueSlot.sweep_step(time_left, duration)` → 0–24; a ready slot is 24; the seconds round up |
| Clock | `RunClock` formats `M:SS`, switches to the low state at 30 s, not 31 |
| Vitals | `VitalsPlate` follows the vitals signals (orb `progress`, rod step, values); buff sockets add, stack and clear |
| Chest | page switching; the hug height; Here tray states; the choice detail line (tooltip, derived combat line, locked, completed); the tile summaries (won fight, effects, `Done`); Run ledger values |
| Rules | `VitalsManager.max_health_for()` and `AdventureCombat.gold_reward_for()` give what a fight then uses (the vitals manager's max Health, `_calculate_gold_reward()`) |
| Map | fog tiers around visited and revealed tiles; revealed tiles use the veil source at the forest variant's coordinates; coin frame per tile state; a revealed empty tile shows `?`, a visited one no coin; the boss coin only once revealed; dev reveal shows glyph coins; route dot positions per hop; `walk_refused` at the click and partway, with its reasons |
| Dock | the slot states; a refused press shakes and does not emit `ability_selected`; Q/W/E/R only in a fight |
| Fight | the opponent page follows the enemy's health, casts (casting, gathering, interrupted) and buffs; `CombatantVisual` offsets at given times (enter, attack, hit, bob); the floater's colour by resource; the floater pool reuses the oldest |
| Pieces | `test_lacquer_pieces.gd`: `LabelLacquerCooldown`, `board9.tres` |
| Rewritten | `test_view_state_hud_positions.gd`: the adventure leaves Goals, its cords and the Log in place. `test_adventure_flow.gd`, `test_adventure_end_flow.gd`, `test_adventure_combat_count.gd` and `test_adventure_combat_victory_event.gd` keep passing, rewritten only where they reach a removed node |

The full GUT suite passes before each PR, and each PR is checked on a 1920x1080 capture (`--write-movie`, with the save backed up and its hash compared) against the mock's screens and the style guide's §12 list.

## Docs to update

`docs/adventuring/ADVENTURING.md` and `docs/combat/COMBAT.md` (the new scenes, signals and flows); `docs/infrastructure/MAIN_VIEW.md` (the adventure keeps the boards in place); `docs/STYLE_GUIDE.md` (delete the done rows A1–A9, S1–S3, B1–B9; the F1, F4 and F6 progress; the palette rows; G2, G7 and G9 answered for the adventure; A-Q1–A-Q11 answered, A-Q12 and A-Q13 left with the end card); `docs/UI_STYLING.md` (`LabelLacquerCooldown`, `board9.tres`); in `CLAUDE.md`, the reusable components (drop `Atmosphere`, `HexHoverSelector`, `PathPreview`; add the new pieces), the Hex Grid section, the Shaders count and the Game Systems line for adventuring; `docs/README.md`.

## Delivery

| PR | Contents | The game between PRs |
|---|---|---|
| 1. The map and the frame | The map (fog, veils, rims, route, character, coins, boss reveal, zoom 1, nearest filtering); `VitalsPlate` with buffs and the `BuffTooltip`; `AdventureChest` with `RunClock` and the expedition page; `TechniqueDock` with every slot state, the sweep, the cast tray and the tooltip; the refused-walk and choice-line fixes; the Run ledger; the two static rules; palette, theme, shaders, tests, docs | Fights use the new cabinet and dock, and the chest keeps the expedition page; the enemy keeps today's floating plate, the old fighters and their fade-in; the old painted forest shows behind fights (the map's opaque ground covers it on the map) |
| 2. The fight | The opponent page (Casting tray, Buffs, Techniques, reward); `CombatStage` and `AdventureData.combat_stage`; the Aseprite fighters at 2x and the stepped motion; `LacquerFloater`; the dither dissolve; the PR 2 removals | Done; only the end card keeps the old look |

## Risks and checks

- **Readability at zoom 1.** The 1x tiles' ink lines are thin; check the veil and fog contrast on a capture.
- **Icons under the sweep.** The user's painted icons have glow pixels; check that the veil mapping still reads as "shadowed" on each of the four.
- **The seconds on bright icons.** The 2 px shadow carries the number over light areas (the Empty Palm palm); check it.
- **Glyphs off the grid.** The boss strip and `trap.png` stand in off the 2x grid until their `_ai` redraws (see [The map](#the-map)).
- **A ✓ in the data.** The Aura Well's `completed_label` is "✓ Location noted"; check BM Euljiro draws the ✓, or drop it from the `.tres`.
- **Fighter art** is the largest new art task (five sprites); placeholders may land first at the mock's size, with the 2x rule kept.
- **Save safety.** No save field changes. Captures follow the zone view's routine (back up the save, compare its hash).

## Open / deferred

- The end card (style guide E1): out of this rework. The run ends on today's end card until it is taken up. Mock round 1's paper scroll is the starting point; the round 2 hanging scroll is gone from the mock but can be rebuilt.
- The fighters' final art: the user's or `_ai` at about 210 px. The mock's Aseprite placeholders stand in.
- A boss of its own: the Manifested Spirit encounter fights the Amorphous Spirit's data; its own `CombatantData` and art are a content task.
- On-grid redraws: the ability icons (G9), the boss and trap glyphs (A4). Separate art tasks.
- The cost preview on hover: dropped, **assumed** (see Decisions).
- Deleting the user's art that this rework leaves unused: waits for the user's word (see [Removed](#removed)).
