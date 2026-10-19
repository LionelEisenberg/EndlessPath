# Endless Path

A cultivation-themed incremental/idle game with active mini-games, built in Godot 4.6. Inspired by the *Cradle* book series by Will Wight, Endless Path follows a sacred artist on their journey from Foundation to mastery, cultivating power through interconnected gameplay systems.

> **Current state:** a playable Foundation-stage slice in one zone. There is no breakthrough to the next stage yet. See [docs/STATE_OF_THE_GAME.md](docs/STATE_OF_THE_GAME.md) for the one-page status and roadmap.

## The Game

The player starts at the **Foundation** stage, cycling Madra through their body and venturing out from a home zone. In the full design, each cultivation stage (Foundation, Copper, Iron, Jade, …) unlocks a new system, and each system feeds the others.

| System | Type | Status | Description |
|--------|------|--------|-------------|
| **Cycling** | Active mini-game | Playable | Keep the cursor on a Madra ball to earn Madra; click cycling zones on time for Core Density XP |
| **Zones and idle actions** | Map + idle | Playable | Hex zone map with foraging, training, NPC dialogue and adventure actions |
| **Adventuring** | Exploration | Playable | Procedurally generated hex maps with fog of war, encounters and an end-of-run summary |
| **Combat** | Real-time | Playable | Abilities cost Health/Madra/Stamina, with cooldowns, cast times, buffs and interrupts |
| **Inventory** | Management | Playable | Paginated equipment grid, gear slots, consumables hotbar, materials, quest journal |
| **Abilities** | Loadout | Playable | 4-slot ability loadout (Q/W/E/R) with drag-and-drop |
| **Path Progression** | Skill tree | Partial | Spend Path Points on nodes; ability and technique unlocks work, numeric perks are not yet applied |
| **Quests** | Narrative | Playable | Multi-step quests driven by events and unlock conditions |
| **Breakthrough / Tribulation** | Stage advancement | *Designed* | Advance to the next cultivation stage |
| **Scripting** | Active mini-game | *Planned* | Calligraphy tracing for short-term buffs |
| **Elixir Making** | Active mini-game | *Planned* | Multi-stage crafting for long-term buffs |
| **Soulsmithing** | Active mini-game | *Planned* | Tetris-like assembly puzzle for gear crafting |

## Core Loop (as built)

1. **Talk** to the Celestial Intervener to receive quests that unlock each activity.
2. **Cycle** to generate Madra (currency) and Core Density XP (progression).
3. **Forage and train** in Spirit Valley while idle.
4. **Adventure** through procedurally generated hex maps, fighting real-time battles for gold and loot.
5. **Spend Path Points** on the Pure Madra skill tree to unlock abilities and cycling techniques, then **equip** them.

Breaking through to the next cultivation stage (step 6 of the design) is not built yet.

## Tech Stack

| Component | Details |
|-----------|---------|
| Engine | Godot 4.6, GDScript, GL Compatibility renderer, 1920×1080 viewport |
| Architecture | 17 autoloads (16 manager singletons + Dialogic), data-driven `Resource` content |
| Entry Scene | `scenes/main/main_game/main_game.tscn` |
| Save System | `user://save.tres` via `ResourceSaver`, auto-saved every 5 s |
| Map System | Hex grids via the `hexagon_tilemaplayer` addon |
| Dialogue | Dialogic addon |
| Tests | GUT 9.6.0 (`tests/unit/`, `tests/integration/`) |

## Project Structure

```
singletons/                   16 manager autoloads (+ Dialogic from addons/)
  persistence_manager/          Save/load; SaveGameData and its sub-resources
  resource_manager/             Madra and Gold
  cultivation_manager/          Core Density XP/levels, advancement stage, path-point milestones
  character_manager/            Player attributes (base + equipment)
  player_manager/               Persistent player VitalsManager
  inventory_manager/            Equipment, materials, consumables, quest items, hotbar
  zone_manager/                 Selected zone, per-zone progression
  action_manager/               Current zone action lifecycle (one action at a time)
  unlock_manager/               Condition-based content gating
  event_manager/                Persistent one-shot event flags
  quest_manager/                Multi-step quests
  dialogue_manager/             Dialogic wrapper
  cycling_manager/              Cycling techniques (unlocked, equipped, catalog)
  ability_manager/              Abilities (unlocked pool, 4-slot loadout)
  path_manager/                 Path tree, point balance, perk aggregation
  log_manager/                  Player-facing in-game log

scripts/
  resource_definitions/       Data classes (Resource subclasses): abilities, adventure, character,
                              combat, cycling, effects, items, loot, path_progression, quests,
                              unlocks, zones
  tools/                      Editor/CLI tools: map preview, ITEMS.md → .tres generator, uid helper
  ui/                         ZoneActionPresenter base
  utils/                      Log utility, ThemeConstants, hex forest atlas, text effect importer

scenes/
  main/main_game/             Entry scene, save timer
  ui/                         MainView state machine, toolbar, log window, dev panel, quest
                              window/toast, combat UI, shared widgets
  zones/                      Zone tilemap, info panel, action buttons + presenters
  cycling/                    Cycling mini-game
  adventure/                  Adventure view, tilemap, map generator, encounter UI, end card
  combat/                     Combatants, ability/buff/effect managers, enemy AI
  inventory/                  Book-style inventory (4 tabs) and shared grid/list chrome
  abilities/                  Abilities view (cards, loadout slots, stats display)
  character/                  Character (attributes) view
  path_progression/           Path tree view
  common/                     Shared item display / description components, DropTargetSlot
  atmosphere/                 Vignette + mist + motes overlay
  tilemaps/                   Hex tilemap extensions, hover selector
  camera/                     Camera clamp/pan/zoom controllers
  characters/                 Player character body
  tools/                      Map preview scene

resources/                    Authored .tres content
  abilities/                    Player ability catalog
  adventure/                    Adventure data and encounters (per adventure)
  combat/combatant_data/        Enemies and enemy abilities
  cycling/                      Techniques and advancement stages
  path_progression/             Pure Madra tree, nodes, themes
  items/                        Equipment, materials, consumables, quest items
  quests/  unlocks/  effects/   Quests, unlock conditions, shared effects
  zones/                        Zones, zone actions, loot tables

assets/                       aseprite/, sprites/, shaders/, themes/, styleboxes/, fonts/,
                              dialogue/, scroll/, colors/
addons/                       AsepriteWizard, ResourcePlus, dialogic, godot_context_exporter,
                              gut, hexagon_tilemaplayer, script-ide
tests/                        unit/, integration/, label_tests/
docs/                         Game and system documentation (start at docs/README.md)
```

## Documentation

- [docs/README.md](docs/README.md): index of all documentation
- [docs/STATE_OF_THE_GAME.md](docs/STATE_OF_THE_GAME.md): one-page status and roadmap
- [docs/GAMEPLAY_STATE.md](docs/GAMEPLAY_STATE.md): what a player can do today, content inventory, blockers
- [docs/CODEBASE_STATE.md](docs/CODEBASE_STATE.md): architecture overview and cross-cutting concerns
- [CLAUDE.md](CLAUDE.md): coding standards and workflow for contributors and AI agents
- [Game Design Document](Endless%20Path%20Game%20Design%20Document%20%5Bv0.1%5D.txt): original design vision (v0.1)

## Running

Paths assume the Windows install used for development; adjust for your Godot 4.6 binary.

```bash
# Open in the Godot editor
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" project.godot

# Run the game
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64.exe" --path . scenes/main/main_game/main_game.tscn

# Run the test suite (first run in a fresh checkout: --headless --import, then see docs/testing/TESTING.md)
"C:\Program Files (x86)\Godot\Godot_v4.6-stable_win64_console.exe" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/,res://tests/integration/ -gexit
```
