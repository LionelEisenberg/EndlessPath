# Endless Path

A cultivation-themed incremental/idle game blended with active mini-games, built in Godot 4.6. Inspired by the *Cradle* book series by Will Wight, Endless Path follows a sacred artist on their journey from Foundation to mastery, cultivating power through interconnected gameplay systems.

## The Game

Players start at the **Foundation** stage, where they engage in a **Cycling** mini-game — following a Madra path on a body diagram and clicking inflection points with precise timing to generate resources. As they advance through cultivation stages (Foundation, Copper, Iron, Jade), new gameplay systems unlock sequentially, each feeding into the others:

| System | Type | Description |
|--------|------|-------------|
| **Cycling** | Active mini-game | Follow a path + rhythm-click to generate Madra and Core Density |
| **Adventuring** | Exploration + Combat | Navigate hex grid maps, encounter enemies, earn loot |
| **Combat** | Real-time | AP-based ability system with cooldowns, buffs, and attribute scaling |
| **Inventory** | Management | Equipment slots, materials, drag-and-drop gear management |
| **Path Progression** | Skill tree | Spend path points to unlock perks, techniques, and stat bonuses |
| **Scripting** | Active mini-game | Calligraphy tracing for short-term buffs *(planned)* |
| **Elixir Making** | Active mini-game | Multi-stage crafting for long-term buffs *(planned)* |
| **Soulsmithing** | Active mini-game | Tetris-like assembly puzzle for gear crafting *(planned)* |

## Core Loop

1. **Cycle** to generate Madra (currency) and Core Density XP (progression)
2. **Explore zones** on the hex map — forage for materials, talk to NPCs, start adventures
3. **Adventure** through procedurally generated hex maps with combat encounters
4. **Equip** loot to improve stats and push further
5. **Break through** to the next cultivation stage, unlocking new systems

## Tech Stack

| Component | Details |
|-----------|---------|
| Engine | Godot 4.6 (GDScript) |
| Architecture | 15 autoload singletons, data-driven resource system |
| Entry Scene | `scenes/main/main_game/main_game.tscn` |
| Save System | `user://save.tres` via Godot ResourceSaver |
| Map System | Hex grid via `hexagon_tilemaplayer` addon |
| Dialogue | Dialogic addon |

## Project Structure

```
scripts/
  resource_definitions/       Data structure classes (Resource subclasses)
    abilities/                  AbilityData
    adventure/                  AdventureData, encounters, choices
    character/                  CharacterAttributesData
    combat/                     CombatEffectData, BuffEffectData, CombatantData
    cycling/                    CyclingTechniqueData, AdvancementStage
    path_progression/           PathNodeData, PathTreeData
    effects/                    EffectData hierarchy (awards, triggers, vitals)
    items/                      ItemDefinitionData, equipment, materials
    loot/                       LootTable, LootTableEntry
    unlocks/                    UnlockConditionData
    zones/                      ZoneData, ZoneActionData subclasses
  utils/                      Log utility, text effect importer

singletons/                   15 autoload manager singletons
  persistence_manager/          Save/load system (SaveGameData, InventoryData, etc.)
  resource_manager/             Madra and Gold tracking
  cultivation_manager/          Core Density leveling and stage progression
  inventory_manager/            Equipment and material management
  zone_manager/                 Active zone and zone progression
  action_manager/               Action queue and lifecycle dispatch
  unlock_manager/               Feature and content gating
  event_manager/                One-shot narrative event tracking
  character_manager/            Player attributes and abilities
  player_manager/               Player VitalsManager container
  cycling_manager/              Cycling technique state (unlocked, equipped, catalog)
  path_manager/                 Path progression tree, point balance, perk effects
  ability_manager/              Ability unlock/equip (4-slot loadout, catalog)
  dialogue_manager/             Dialogic wrapper
  log_manager/                  In-game log signal bus

scenes/
  main/main_game/             Entry scene (main_game.tscn), save timer
  cycling/                    Cycling mini-game (view, technique, zones, resource panel)
  path_progression/           Path skill tree UI and node interactions
  abilities/                  Ability management (cards, loadout slots, stats display)
  combat/                     Combat system (combatant nodes, ability/buff/effect managers, AI)
  adventure/                  Adventure mode (tilemap, map generator, encounter panels)
  inventory/                  Inventory UI (equipment grid, gear slots, materials tab)
  zones/                      Zone tilemap, info panel, action buttons
  common/                     Reusable UI components (item display, description panels)
  ui/                         Shared UI (main view state machine, log window, floating text)
  game_systems/               Cross-system coordination scenes
  camera/                     Camera controllers (clamp, pan, zoom)
  characters/                 Player character body and animation
  tilemaps/                   Hex tilemap extensions and pulse effects

resources/                    Authored .tres data files
  abilities/                    Ability definitions (basic_strike, empty_palm, enforce, etc.)
  adventure/                    Adventure configs, encounter definitions, choice data
  combat/combatant_data/        Enemy definitions (amorphous_spirit, starving_dreadbeast)
  cycling/                      Technique definitions, advancement stage data
  path_progression/             Path tree and node definitions
  effects/                      Effect instances (award_resource, trigger_event)
  items/                        Item definitions (dagger, spirit_fern, dewdrop_tear)
  loot_tables/                  (empty — system built, no content yet)
  unlocks/                      Unlock condition list
  zones/                        Zone definitions (spirit_valley, test_zone)

assets/
  asperite/                   Aseprite source files (abilities, cycling, zones, UI, characters)
  sprites/                    Exported sprite PNGs (abilities, combat, cycling, tilemap, zones)
  shaders/                    Custom shaders (liquid_wave, core_density_fill, pulse_node)
  themes/                     Godot theme resources (main_theme.tres, pixel_ui_theme/)
  styleboxes/                 Custom StyleBox resources
  fonts/                      Font files
  ui_images/                  UI element textures (ability buttons, action buttons, buff icons)
  dialogue/                   Dialogic data (characters, styles, timelines)
  colors/                     Color palette resources
  spritesheets/               Sprite atlas sheets

addons/                       Godot plugins
  dialogic/                     Dialogue/narrative system
  AsepriteWizard/               Aseprite import pipeline
  hexagon_tilemaplayer/         Hex grid tilemap with pathfinding
  script-ide/                   Script editor enhancements
  godot_context_exporter/       Context export tool
  ResourcePlus/                 Resource editing enhancements

docs/                         Game system documentation
```

## Documentation

Detailed documentation for each game system lives in `docs/`:

- [Cycling](docs/cycling/CYCLING.md) — Madra generation mini-game
- [Path Progression](docs/progression/PATH_PROGRESSION.md) — Skill tree and perk system
- [Combat](docs/combat/COMBAT.md) — Real-time ability-based combat
- [Adventuring](docs/adventuring/ADVENTURING.md) — Hex grid exploration and encounters
- [Inventory](docs/inventory/INVENTORY.md) — Equipment and materials management
- [Zones](docs/zones/ZONES.md) — World map and zone actions
- [Cultivation](docs/cultivation/CULTIVATION.md) — Progression, resources, and unlocks
- [Scripting](docs/planned/SCRIPTING.md) — Calligraphy buff system *(planned)*
- [Elixir Making](docs/planned/ELIXIR_MAKING.md) — Potion crafting system *(planned)*
- [Soulsmithing](docs/planned/SOULSMITHING.md) — Assembly puzzle crafting *(planned)*
- [Codebase State](docs/CODEBASE_STATE.md) — Technical health and completeness
- [Gameplay State](docs/GAMEPLAY_STATE.md) — Current status of each mechanic

## Running

```bash
# Open in Godot editor
godot project.godot

# Run the game
godot --path . scenes/main/main_game/main_game.tscn
```
