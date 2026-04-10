# Cycling View UI Redesign

**Status:** Implemented (PR #12)

## Goal

Overhaul the Cycling View UI from its current placeholder state into a polished, readable, Wuxia-themed full-screen overlay. Replace the modal technique selector with an integrated tabbed panel. Add a visible close button. Improve visual quality of both the body diagram area and the resource/info panel.

## Scope

**In scope (this spec):**
- Layout restructure: body diagram left, tabbed info panel right
- Resource panel cleanup: compact orb + stats rows, technique summary
- Technique selector integration: tab toggle replaces modal
- Close button (ESC)
- Theme integration: use project styleboxes and ThemeConstants
- Controls repositioning (Start Cycle + Auto below body diagram)

**Out of scope (future work):**
- Per-technique body poses, backgrounds, or path art
- Audio/SFX
- Combo/streak systems
- CyclingActionData modifiers (madra_multiplier, etc.)
- Technique unlocking/progression gating
- New technique content creation
- Path curve editor tooling

## Layout

Full-screen overlay (same as current). Two regions side-by-side:

```
┌─────────────────────────────────────────────────────────────────┐
│ [✕ ESC]                                                         │
│                                                                 │
│   ┌──────────────────────┐    ┌──────────────────────────┐     │
│   │                      │    │ [Resources] [Techniques]  │     │
│   │   Body Diagram       │    │                          │     │
│   │   + Path (Line2D)    │    │  (tab content area)      │     │
│   │   + Zones            │    │                          │     │
│   │   + Madra Ball       │    │  Resources: orb rows,    │     │
│   │                      │    │  technique summary       │     │
│   │                      │    │                          │     │
│   │                      │    │  OR                      │     │
│   │                      │    │                          │     │
│   └──────────────────────┘    │  Techniques: scrollable  │     │
│                               │  list with equip-on-click│     │
│     [▶ Start Cycle] [⟳ Auto] │                          │     │
│                               └──────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### Left Side: Body Diagram Area (~60% width)

- **Close button**: Top-left corner. Text: "✕ ESC". Fires `close_cycling_view` input action (same as pressing Escape). Uses `button_default` stylebox.
- **Body diagram**: Centered `TextureRect` with the meditation figure. Universal pose for all techniques (for now).
- **Path visualization**: `Line2D` drawn from the technique's `Curve2D`, rendered on top of the body diagram. Keep current rendering logic.
- **Cycling zones**: Dynamically created `Area2D` nodes at positions from `CyclingZoneData`. Keep current click/timing logic.
- **Madra Ball**: Animated along `PathFollow2D`. Keep current tracking/animation logic.
- **Controls**: Centered horizontally below the body diagram.
  - **Start Cycle** button: Primary style (`button_default` with `border_color = ACCENT_GOLD` on hover).
  - **Auto Cycle** toggle: Adjacent to Start. Needs distinct visual states for on/off (currently identical textures).

### Right Side: Tabbed Info Panel (~40% width, max 400px)

Two tabs sharing the same panel space:

#### Tab Bar
- Two tabs: **Resources** (default active) and **Techniques**
- Tab styling: active tab uses `PanelAccent` border-bottom or highlight, inactive uses muted color
- Switching tabs is instant — no animation needed

#### Resources Tab (default)

Three sections stacked vertically:

**1. Madra Row**
- Madra orb (small, ~48-64px) on the left
- Text on the right:
  - `Madra: {current} / {max}` (heading size)
  - `+{rate}/s` (muted, only shown during active cycling)
  - `{base_madra}/cycle` (muted)

**2. Core Density Row**
- Core Density orb (small, ~48-64px) on the left
- Text on the right:
  - `Level: {level}` (heading size)
  - XP progress bar below (compact)
  - `Stage: {stage_name}` (muted)

**3. Active Technique Summary**
- Bordered card (`panel_default` or `panel_accent` stylebox)
- Technique name (gold/accent color)
- Stats: Madra/cycle, duration, zone count
- No button needed — user switches to Techniques tab to change

#### Techniques Tab

Scrollable vertical list of technique slots:

**Each technique slot contains:**
- Icon placeholder (small square, 28-32px)
- Technique name
- Compact stat line: `{madra}/cycle • {duration}s • {zones} zones`
- Click to equip (replaces current technique immediately)
- Currently equipped technique has highlighted border (`ACCENT_GOLD`)

**Locked techniques:**
- Greyed out (reduced opacity)
- Show lock icon + unlock requirement text instead of stats
- Not clickable

**Data source:** `CyclingTechniqueList` resource (already exists, holds array of `CyclingTechniqueData`)

## Node Structure Changes

### Current Structure
```
CyclingView (Control)
  MarginContainer
    Panel
      CyclingBackground (TextureRect)
        CyclingTechnique (Node2D)
      CyclingResourcePanel (MarginContainer)
      CyclingTechniqueSelector (PanelContainer) ← MODAL, DELETE
```

### Proposed Structure
```
CyclingView (Control)
  CloseButton (Button) ← NEW
  HBoxContainer
    BodyDiagramArea (PanelContainer) ← left ~60%
      VBoxContainer
        CyclingBackground (TextureRect)
          CyclingTechnique (Node2D) ← KEEP existing logic
        ControlsRow (HBoxContainer) ← MOVED from inside CyclingTechnique
          StartCyclingButton
          AutoCycleToggle
    InfoPanel (PanelContainer) ← right ~40%
      VBoxContainer
        TabBar (HBoxContainer) ← NEW
          ResourcesTab (Button)
          TechniquesTab (Button)
        TabContent (Control) ← NEW, swaps children
          ResourcesContent (VBoxContainer) ← REWORKED from CyclingResourcePanel
            MadraRow (HBoxContainer)
            CoreDensityRow (HBoxContainer)
            TechniqueSummary (PanelContainer)
          TechniquesContent (ScrollContainer) ← REWORKED from CyclingTechniqueSelector
            TechniqueList (VBoxContainer)
              TechniqueSlot × N
```

### Scripts

| Script | Change |
|--------|--------|
| `cycling_view.gd` | Remove technique selector modal logic. Add tab switching. Add close button handler. |
| `cycling_technique.gd` | No changes to core logic. Move Start/Auto buttons out of this scene into parent layout. |
| `cycling_resource_panel.gd` | Rework to compact horizontal layout. Remove the "Open Technique Selector" button. Add technique summary section. |
| `cycling_technique_selector.gd` | **Delete.** Replace with inline technique list in the Techniques tab. |
| `cycling_technique_slot.gd` | Rework visual layout to horizontal compact slot. Add equipped/locked states. |

### New Scripts

| Script | Purpose |
|--------|---------|
| `cycling_tab_panel.gd` | Manages tab switching between Resources and Techniques content. Simple show/hide toggle. |

## Styling

All panels use the project theme styleboxes:

| Element | Stylebox / Variant |
|---------|-------------------|
| Outer panel background | `PanelDark` variant (semi-transparent dark) |
| Body diagram area | `panel_default` or no stylebox (body texture is the visual) |
| Info panel | `panel_default` |
| Active tab | `PanelAccent`-like highlight |
| Technique summary card | `panel_accent` |
| Technique slot | `button_default` states (normal/hover/pressed) |
| Locked technique slot | `button_default_disabled` |
| Close button | `button_default` stylebox |
| Controls (Start/Auto) | `button_default` stylebox, primary uses gold border |

Text colors follow ThemeConstants:
- Primary text: `TEXT_LIGHT` on dark backgrounds
- Muted text: `TEXT_MUTED`
- Accent/gold: `ACCENT_GOLD` for technique names, active states
- Values: `TEXT_LIGHT`

## Signals (unchanged)

The signal flow stays the same — only the UI routing changes:

| Signal | Change |
|--------|--------|
| `technique_change_request` | Now emitted from inline TechniqueSlot click instead of modal |
| `open_technique_selector` | **Removed** — tab switching is internal to the panel |
| All other signals | Unchanged |

## What the User Needs to Do in Godot Editor

Since this is primarily a layout restructure:

1. **Rebuild `cycling_view.tscn`** — new HBoxContainer layout with left/right split
2. **Rebuild `cycling_resource_panel.tscn`** — compact horizontal rows instead of vertical stacks
3. **Create tab bar UI** — two Button nodes styled as tabs
4. **Create technique slot scene** — horizontal compact layout (icon + name + stats)
5. **Delete `cycling_technique_selector.tscn`** — replaced by inline tab content
6. **Position/size adjustments** — margins, minimum sizes, stretch ratios

Code changes (scripts) can be done by the agent.

## Mockup Reference

See `docs/mockups/` or `.superpowers/brainstorm/` for the HTML wireframe.
