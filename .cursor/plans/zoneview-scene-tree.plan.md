# ZoneView Scene Tree Plan

## Overview

The ZoneView scene tree integrates the existing ZoneTilemap (hexagonal TileMapLayer) with ZoneInfoPanel and ActionDetailPanel to create the complete zone view UI structure per section 6 of the zone plan.

## Scene Tree Structure

```
ZoneView (Control)
├── BackgroundTextureRect (TextureRect) [optional]
│   └── MainContainer (HSplitContainer)
│       ├── ZoneMapPanel (PanelContainer or Control)
│       │   └── ZoneTilemap (Node2D instance)
│       │       ├── TileMapLayer
│       │       └── Camera2D
│       │
│       └── ZoneInfoPanel (PanelContainer)
│           └── MarginContainer
│               └── ZoneInfoContent (VBoxContainer)
│                   ├── ZoneHeaderSection (VBoxContainer)
│                   │   ├── ZoneNameLabel (Label)
│                   │   ├── ZoneTierLabel (Label)
│                   │   ├── HSeparator
│                   │   └── ZoneDescriptionLabel (RichTextLabel)
│                   │
│                   ├── ActionsSection (VBoxContainer)
│                   │   ├── ActionsHeaderLabel (Label)
│                   │   ├── HSeparator
│                   │   └── ActionsScrollContainer (ScrollContainer)
│                   │       └── ActionsGridContainer (GridContainer)
│                   │           └── [ZoneActionButton instances - dynamic]
│                   │
│                   └── ForageStatusSection (VBoxContainer) [conditional]
│                       ├── HSeparator
│                       ├── ForageActiveLabel (Label)
│                       └── ForageStopButton (Button)
│
└── ActionDetailPanel (PanelContainer) [modal overlay]
    ├── MarginBackgroundContainer (MarginContainer)
    │   └── PanelContainer
    │       ├── ActionDetailHeader (HBoxContainer)
    │       │   ├── ActionTitleLabel (Label)
    │       │   └── CloseActionDetailButton (TextureButton)
    │       │
    │       └── ActionDetailContent (VBoxContainer)
    │           └── [Action-specific content - dynamic]
```

## Key Components

### 1. ZoneView (Root Control)

- **Location**: `scenes/game_systems/zones/zone_view/zone_view.tscn`
- **Script**: `scenes/game_systems/zones/zone_view/zone_view.gd`
- **Layout**: Full screen anchors (preset 15)
- **Purpose**: Main container, handles zone selection and action triggering

### 2. ZoneTilemap Integration

- **Existing Scene**: `scenes/game_systems/zones/zone_tilemap/zone_tilemap.tscn`
- **Type**: Node2D (instanced in ZoneMapPanel)
- **TileSet**: `horizontal_tile_set.tres` (flat-top hexagonal, 164x190px tiles)
- **Features**: 
  - Camera2D with pan (right-click drag) and zoom (mouse wheel, 0.2-1.5x)
  - TileMapLayer displays zones via `tilemap_location: Vector2i` in ZoneData
- **Required Modifications**:
  - Add signal: `zone_selected(zone_data: ZoneData, tile_coord: Vector2i)`
  - Modify `tile_map_layer.gd` click handler to emit signal
  - Add helper: `get_zone_at_tile(tile_coord: Vector2i) -> ZoneData`
  - Update tile variants based on zone state (locked/unlocked/selected)
  - Remove or disable CharacterBody2D movement (UI-only)

### 3. ZoneInfoPanel

- **Location**: `scenes/game_systems/zones/zone_info_panel/zone_info_panel.tscn`
- **Script**: `scenes/game_systems/zones/zone_info_panel/zone_info_panel.gd`
- **Purpose**: Displays selected zone info and available actions
- **Layout**: Right panel (~60% width) in HSplitContainer

### 4. ZoneActionButton

- **Location**: `scenes/game_systems/zones/zone_action_button/zone_action_button.tscn`
- **Script**: `scenes/game_systems/zones/zone_action_button/zone_action_button.gd`
- **Purpose**: Reusable button for zone actions
- **States**: Normal, locked, completed (one-time), disabled
- **Display**: Icon, name, unlock indicator

### 5. ActionDetailPanel

- **Location**: `scenes/game_systems/zones/action_detail_panel/action_detail_panel.tscn`
- **Script**: `scenes/game_systems/zones/action_detail_panel/action_detail_panel.gd`
- **Purpose**: Modal overlay for action-specific UI (dialogue, merchant, forage, etc.)
- **Pattern**: Center-anchored with large margins (400px), similar to CyclingTechniqueSelector
- **Visibility**: Hidden by default, shown when action selected

## ZoneTilemap Modifications

### zone_tilemap.gd

- Add signal: `signal zone_selected(zone_data: ZoneData, tile_coord: Vector2i)`
- Add method: `get_zone_at_tile(tile_coord: Vector2i) -> ZoneData`
  - Loops through `zone_data_list.list` to find matching `tilemap_location`
- Add method: `update_zone_tile_state(zone_data: ZoneData)`
  - Updates tile variant based on locked/unlocked/selected state

### tile_map_layer.gd

- Modify `_input()` to emit `zone_selected` signal instead of placing tiles
- Remove CharacterBody2D movement code (or make optional via export flag)

## ZoneView Script Structure

```gdscript
extends Control

@onready var zone_tilemap: Node2D = $MainContainer/ZoneMapPanel/ZoneTilemap
@onready var zone_info_panel: PanelContainer = $MainContainer/ZoneInfoPanel
@onready var action_detail_panel: PanelContainer = $ActionDetailPanel

var selected_zone: ZoneData = null

func _ready():
    zone_tilemap.zone_selected.connect(_on_zone_selected)
    # Load initial state, select default zone if available

func _on_zone_selected(zone_data: ZoneData, tile_coord: Vector2i):
    selected_zone = zone_data
    zone_info_panel.update_zone_info(zone_data)
    zone_tilemap.update_zone_tile_state(zone_data)  # Highlight selected
```

## Integration Points

- ZoneView replaces placeholder in `main_game.tscn` at `MainView/MainViewContainer/ZoneView`
- MainView script already references `$MainViewContainer/ZoneView`
- ZoneTilemap loads ZoneDataList resource on `_ready()` (existing functionality)
- ZoneView connects to ZoneManager signals for unlock/action updates (future)

## Implementation Steps

1. **Modify ZoneTilemap**:

   - Add zone_selected signal and helper methods
   - Update click handler to emit signal
   - Add zone state visual feedback

2. **Create ZoneInfoPanel**:

   - Zone header section (name, tier, description)
   - Actions grid container
   - Forage status section

3. **Create ZoneActionButton**:

   - Reusable button component
   - Lock/unlock/complete states
   - Action-specific styling

4. **Create ActionDetailPanel**:

   - Modal structure
   - Dynamic content based on action type

5. **Create ZoneView**:

   - Integrate ZoneTilemap and ZoneInfoPanel with HSplitContainer
   - Connect signals
   - Handle zone selection and action triggering