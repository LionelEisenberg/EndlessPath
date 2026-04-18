# ZoneActionButton Presenter Refactor — Design

**Date:** 2026-04-17
**Status:** Approved — ready for implementation planning

## Problem

`scenes/zones/zone_action_button/zone_action_button.gd` (259 lines) has become a type-check salad that doesn't scale. Every new `ZoneActionData` subtype forces more branching inside the button:

- `_update_progress_fill()` branches on `action_data is ForageActionData` to decide whether to sweep
- `_update_madra_badge()` / `_update_adventure_state()` hard-codes the adventure affordability UI
- `_on_foraging_completed()` receives a foraging-only signal and spawns foraging-only floating text
- `_on_card_input()` hard-codes the adventure rejection branch
- `CATEGORY_COLORS` has no entry for `TRAIN_STATS` (the new action type introduced by the training-action-infrastructure feature)

Adding a `TrainingPresenter`-style view (per-tick progress bar, attribute badge, per-tick sweep, Madra particles) on top of this structure would balloon the file and make the type-coupling worse. We need a clean boundary between "what this button does for every action" (selection, hover, current-state, rejection animation) and "what this specific action looks like on the card" (adventure badge, foraging sweep, training progress bar, etc.).

## Approach

Split the button into a **shell** and a **presenter**:

- **Button (shell)** — owns the card styling, hover/current-state feedback, click handling, and three presentation *slots* where the presenter renders its own content. Type-agnostic.
- **Presenter (per-type)** — owns all type-specific display logic. Implements a small shared interface via an abstract base class. The button instantiates the right presenter via a factory dictionary keyed by `ZoneActionData.ActionType`.

This is composition at the button↔presenter seam (the button *has* a presenter) and inheritance inside the presenter family (each presenter *is* a `ZoneActionPresenter`). Godot's `@abstract class_name` / `@abstract func` annotations (already used on `EffectData`) give us a proper abstract base — the compiler refuses to instantiate abstract types and forces every subclass to implement the abstract methods.

**Execution strategy: two passes.**

- **Pass 1 — Extract presenter pattern.** Introduce the abstract base, rework the button scene to add slots, and port the existing behaviors (foraging, adventure, default) into dedicated presenter scenes. Zero behavior change. No TRAIN_STATS support yet.
- **Pass 2 — TrainingPresenter + particles.** Add the training presenter, the tick-progress-bar widget, level-up flash, attribute badge, and Madra particle spawning. Zero edits to the button shell except the factory-dictionary entry.

Splitting the work this way makes Pass 1 a pure refactor (safe, reviewable against "does it still work exactly the same?") and Pass 2 a pure feature add (reviewable against the training visual spec).

## Architecture

### Scene hierarchy (post-refactor)

```
ZoneActionButtonContainer (MarginContainer)    [zone_action_button.gd]
└── ActionCard (PanelContainer)
    ├── OverlaySlot (Control)                  # full-rect, behind content (sweep lives here)
    └── ContentMargin (MarginContainer)
        └── VBoxContainer
            ├── HBoxContainer
            │   ├── TextSection (VBoxContainer)
            │   │   ├── ActionNameLabel
            │   │   └── ActionDescLabel
            │   └── InlineSlot (Control)       # top-right, next to text (badges live here)
            └── FooterSlot (Control)           # full-width, below text (progress bars live here)
```

**Slot rules:**
- `OverlaySlot` stretches over the whole card, `mouse_filter = IGNORE`. Used for sweep shaders, flash overlays, anything that should sit visually behind the text.
- `InlineSlot` sits top-right within the content row, sized to its children. Used for badges (Madra badge, attribute badge).
- `FooterSlot` sits below the text section, full-width. Used for progress bars and any future full-width ornament.
- The button only ever exposes these three slots. Presenters decide which slots to fill and with what; unused slots stay empty.

### Abstract base

```gdscript
# scripts/ui/zone_action_presenter.gd
@abstract class_name ZoneActionPresenter
extends Node

var action_data: ZoneActionData
var button: Control  # reference to the owning ZoneActionButton, for helpers like get_madra_target_global_position()

@abstract
func setup(data: ZoneActionData, owner_button: Control, overlay_slot: Control, inline_slot: Control, footer_slot: Control) -> void

@abstract
func teardown() -> void

# Lifecycle hooks with safe defaults — subclasses override only what they need.
func set_is_current(_is_current: bool) -> void:
    pass

func can_activate() -> bool:
    return true

func on_activation_rejected() -> void:
    pass
```

- `setup(data, owner_button, overlay_slot, inline_slot, footer_slot)` — called when the button's `action_data` is assigned. Presenter stores references, reparents its content into whichever slots it wants to fill, and connects its signals.
- `teardown()` — called from `_exit_tree` on the button. Presenter disconnects signals and kills tweens.
- `set_is_current(is_current)` — called by the button when selection state flips. Presenters that animate on selection (foraging sweep, training sweep) react here.
- `can_activate()` — gate for click handling. Button calls this before `ActionManager.select_action`; adventure returns `false` when Madra is below threshold, everything else returns `true`.
- `on_activation_rejected()` — called when `can_activate()` returned `false`. Adventure plays its shake; others no-op.

The base extends `Node` rather than `Control` because presenters are utility holders whose visible content lives inside the slots. The presenter scene itself has no layout.

### Button responsibilities (after refactor)

- Hold the presenter instance and forward lifecycle calls.
- Own the card styling (normal / hover / selected) and `_update_card_style`.
- Own `_setup_labels` (action name + description — both are type-agnostic `ZoneActionData` fields).
- Own click-to-select with the `can_activate()` gate.
- Own the category-color lookup, exposed so presenters can tint their content consistently.
- Route `ActionManager.current_action_changed` to `presenter.set_is_current`.
- Expose a helper `get_madra_target_global_position() -> Vector2` used by presenters that spawn particles aimed at the Madra orb. Resolved once in `_ready` via `get_tree().current_scene.find_child("ZoneResourcePanel", true, false)` — same pattern as `scenes/zones/zone_transition/zone_transition.gd`.

### Presenter factory

The button holds a `PRESENTER_SCENES: Dictionary` mapping `ZoneActionData.ActionType` → `PackedScene`. After Pass 2 it looks like:

```gdscript
# zone_action_button.gd
const PRESENTER_SCENES: Dictionary = {
    ZoneActionData.ActionType.FORAGE: preload("res://scenes/zones/zone_action_button/presenters/foraging_presenter.tscn"),
    ZoneActionData.ActionType.ADVENTURE: preload("res://scenes/zones/zone_action_button/presenters/adventure_presenter.tscn"),
    ZoneActionData.ActionType.CYCLING: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
    ZoneActionData.ActionType.NPC_DIALOGUE: preload("res://scenes/zones/zone_action_button/presenters/default_presenter.tscn"),
    ZoneActionData.ActionType.TRAIN_STATS: preload("res://scenes/zones/zone_action_button/presenters/training_presenter.tscn"),
}
```

Pass 1 ships without the `TRAIN_STATS` entry; Pass 2 adds it.

**Instantiation + wiring.** On `_ready`, the button:
1. Picks the presenter scene by `action_data.action_type`, defaulting to `default_presenter.tscn` if no entry exists.
2. Instantiates the presenter and adds it as a child of the button (a hidden utility node — the presenter itself doesn't render; its *content* renders inside the slots).
3. Calls `presenter.setup(action_data, overlay_slot, inline_slot, footer_slot)` — signature extended to accept the three slot `Control` references.
4. The presenter's `setup()` reparents its own pre-authored child content into whichever slots it wants to fill (using `Node.reparent()`), and leaves slots it doesn't want to use untouched.

This keeps each presenter self-contained — the presenter scene can be opened in the editor, its contents tweaked visually, and at runtime those contents are snapped into the slot layout defined by the button shell.

### Presenters (Pass 1)

- **DefaultPresenter** — empty. Used for Cycling and NPC_Dialogue, which need no extra ornament beyond the text + card styling. Implements `setup`/`teardown` as no-ops.
- **ForagingPresenter** — owns the sweep overlay (currently `ProgressFill` + `action_card_sweep.gdshader`). Starts the sweep on `set_is_current(true)`; resets-and-restarts on `ActionManager.foraging_completed`; stops on `set_is_current(false)`. Also owns `_spawn_foraging_floating_text`.
- **AdventurePresenter** — owns the Madra badge + shake. `setup` connects to `ResourceManager.madra_changed` and updates the badge / name dim. `can_activate()` returns `ResourceManager.can_start_adventure()`. `on_activation_rejected()` plays the shake and logs the red error message.

### Presenters (Pass 2)

**TrainingPresenter** fills three slots:

| Slot | Element | Source of truth |
|---|---|---|
| OverlaySlot | Per-tick sweep (same shader as foraging) | Bound to `ActionManager.action_timer`; duration = `tick_interval_seconds` |
| InlineSlot | Attribute badge "`current` / `max`" | Current = `ticks_per_level.size()` × first `AwardAttributeEffectData.amount` from `effects_on_level`; max = same; level_data = `get_current_level(ticks)` × that amount |
| FooterSlot | `tick_progress_bar` widget — 2px-tall bar, gradations at 10%/20%/…/90%, right-edge counter "`34 / 60`" | Fill = `get_progress_within_level(ticks)`; counter = ticks-within-level and `get_ticks_required_for_level(next_level)` |

**Per-tick behavior** (on `ActionManager.training_tick_processed`):
1. Read new tick count.
2. Update footer bar fill + counter.
3. Spawn a Madra particle via `FlyingParticle`, from a point on the button to `button.get_madra_target_global_position()`. Only spawn when `tick.effects_per_tick` contains a Madra award — no need to filter at UI level for now since all trainings grant Madra, but the presenter queries the tick's effect amount rather than hard-coding.

**Level-up behavior** (on `ActionManager.training_level_gained`):
1. Fire a 0.3s flash/fade tween on the footer bar (category-color flash, ease out, fade to transparent).
2. On tween complete, snap the bar back to 0 and resume tracking.
3. Bump the attribute badge "current" value.

**Sweep speed:** the sweep represents one *tick*, not one level. Duration matches `tick_interval_seconds` exactly. The existing foraging sweep logic (shader param + `_process` timer polling) is the right template — but the presenter tracks `ActionManager.action_timer` using the same pattern.

### Particle target lookup (no new singleton)

The existing `scenes/ui/flying_particle/flying_particle.gd` has a complete API (`launch(start, target, color, duration, size, on_arrive, curve_spread, curve_bias)`). We don't need a new singleton to manage particles — one already exists in spirit (the class). For the destination position, the pattern is already in `scenes/zones/zone_transition/zone_transition.gd:46` — walk the tree once at ready time to find `ZoneResourcePanel`, call its public `get_madra_orb_global_position()` (already defined at `zone_resource_panel.gd:27`).

Adding this to `ResourceManager` would be a layering violation — data singletons shouldn't know about UI positions. Adding a `ParticleManager` singleton would reinvent `FlyingParticle` with no payoff. The tree-walk pattern is local, tested (already used by zone_transition), and keeps UI knowledge in UI code.

## File plan

### New files (Pass 1)
- `scripts/ui/zone_action_presenter.gd` — abstract base
- `scenes/zones/zone_action_button/presenters/default_presenter.gd` / `.tscn`
- `scenes/zones/zone_action_button/presenters/foraging_presenter.gd` / `.tscn`
- `scenes/zones/zone_action_button/presenters/adventure_presenter.gd` / `.tscn`

### Modified files (Pass 1)
- `scenes/zones/zone_action_button/zone_action_button.tscn` — add OverlaySlot, InlineSlot, FooterSlot; remove `ProgressFill` and `MadraBadgeContainer` (now owned by presenters)
- `scenes/zones/zone_action_button/zone_action_button.gd` — delete all type-specific branches; add presenter factory, slot references, `get_madra_target_global_position` helper

### New files (Pass 2)
- `scenes/zones/zone_action_button/presenters/training_presenter.gd` / `.tscn`
- `scenes/ui/tick_progress_bar/tick_progress_bar.gd` / `.tscn` — custom widget

### Modified files (Pass 2)
- `scenes/zones/zone_action_button/zone_action_button.gd` — add `TRAIN_STATS` entries to `PRESENTER_SCENES` and `CATEGORY_COLORS`

## Testing

- `scenes/zones/zone_action_button/zone_action_button.tscn` is an in-scene UI component with tight coupling to `ActionManager`, `ResourceManager`, and live save data, so integration coverage rather than unit tests is the right fit.
- **Pass 1 verification:** run the existing project, pick a zone with all four existing action types, confirm zero visible regression (foraging sweep still works, adventure badge / shake still work, hover / current-action styling unchanged).
- **Pass 2 verification:** run the project on a zone with a training action, confirm per-tick progress-bar increments, per-tick Madra particle, level-up flash, attribute badge update. No existing GUT test covers the button visuals; adding one for this refactor would require mocking the entire manager graph and isn't warranted.
- Run `tests/integration/test_training_flow.gd` after Pass 2 to confirm the presenter didn't break the training manager wiring.

## Out of scope

- Non-Madra resources in training particles (only Madra for now; other resources can be added to the presenter when those trainings exist).
- Presenter-level resource filtering (no need; all current training actions grant Madra).
- Replacing foraging's sweep shader — we're reusing it as-is.
- Changing `ActionManager` signals — the presenter subscribes to existing signals.
- Any visual redesign of the card itself; this is a structural refactor with one feature add (Pass 2).

## Success criteria

- **Pass 1:** `zone_action_button.gd` contains zero `action_data is X` or `action_type == X` branches. All four existing action types render and behave exactly as before. Each presenter scene can be opened in the editor and inspected independently.
- **Pass 2:** A zone with a `TrainingActionData` shows the button with attribute badge, thin progress bar with gradations, per-tick sweep matching `tick_interval_seconds`, Madra particles flying to the Madra orb on each tick, and a 0.3s flash on level-up before the bar resets.
