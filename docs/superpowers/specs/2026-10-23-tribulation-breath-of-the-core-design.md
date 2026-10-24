# Tribulation: Breath of the Core (Foundation to Copper) — Design

> **Status:** decisions settled with the user on 2026-10-23 (godot-grill), after the user played three prototypes. The user chose the route (a Spirit Valley action), the mini-game (Breath of the Core, without the Heavenly Lightning finale) and the failure penalty, and accepted the recommendations for everything else. Not built.
>
> **Scope:** the Foundation → Copper breakthrough: a Spirit Valley zone action that opens when Core Density first reaches 100 and runs the Breath of the Core mini-game. A pass moves the player to a thin Copper stage; a failure costs 5 Core Density levels. Out of scope: Copper's systems, sound, dialogue and the Core Density curve retune.
>
> **Supersedes:** [breakthrough-tribulation.md](../../cultivation/breakthrough-tribulation.md) (a Breakthrough tile on adventure maps and a mouse-tracking Tribulation built on cycling) and Beats 7–9 of [FOUNDATION_PLAYTHROUGH.md](../../progression/FOUNDATION_PLAYTHROUGH.md) (a Tribulation Guardian boss and an Advancement Zone).
>
> **Prototype:** [mockups/tribulation-breath-of-the-core-prototype.html](../mockups/tribulation-breath-of-the-core-prototype.html) is the playable reference for the rules, timings and feel (published copy: https://claude.ai/artifact/66fFPzShqZCNt1Kb9MQcY4). Its Spirit Valley bar, sound, tuning sliders, run log, millisecond offsets, and its stop when the browser tab is hidden are prototype-only.

## Goal

Foundation has no ending today. Core Density climbs past 100 and nothing happens, because `CultivationManager.attempt_breakthrough()` is an empty stub and only the Foundation stage exists. This adds the breakthrough: once the core is full, the Tribulation appears in Spirit Valley as a roughly 40-second breathing trial. Passing it moves the player to Copper. Failing it costs the core 5 levels, so the player cycles back to 100 before trying again.

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Where it happens | A zone action in Spirit Valley, "The Tribulation". No Guardian boss, Advancement Zone or adventure tile | User's call: the simplest route. The two earlier designs needed a new boss and zone, or a new encounter type inside the adventure view | A later stage wants its breakthrough somewhere special |
| Mini-game | Breath of the Core: an aura sphere breathes around the core and the player presses as the bright, shrinking sphere crosses a brass ring. Five phases end in a press-and-hold (see The trial) | Chosen after playing three prototypes. The user dropped the Heavenly Lightning finale | Playtests say it's samey or too long |
| Not cycling | The trial doesn't reuse `CyclingTechnique`, its mouse tracking or its Madra and XP payout | User: the old design was "basically just cycling" | — |
| When it appears | The first time Core Density reaches 100. It then stays (unlocks latch). Below 100 its card shows "Core 95 / 100" and refuses to start, the way the adventure card shows its Madra threshold | Reaching 100 becomes a reveal, and the card's need row already exists | Players miss the card |
| Core Density cap | Core Density stops at 100 in Foundation (each stage's cap is data). XP earned at the cap is lost, and cycling shows the core is full | Without a cap, a player at 105 could fail for free | A stage design wants overflow |
| Failure | Lose 5 Core Density levels (100 → 95). Nothing else is lost; the action stays and works again at 100 | User: there must be a penalty. Cycling back to 100 is the friction | The Core Density retune changes how long 5 levels take |
| Path points | A Core Density milestone pays its path point once per stage. Regaining level 100 after a failure pays nothing | Today the award re-pays on every crossing of a multiple of 10, so failing would farm path points | — |
| Saves past 100 | A Foundation save above 100 is set to 100 on load. Levels run past 100 today, playtest saves included. Path points already earned stay. Madra above a lowered cap is kept until spent: adding Madra never takes any away | Without it, a level-130 save shows "Core 130 / 100" and can neither start the Tribulation nor level up | — |
| Pass | Advance to Copper. The stage changes, Core Density restarts at 0 on Copper's own curve and Madra cap, and the Tribulation card goes away. Nothing changes on the map in v1 | Foundation gets an ending, and Copper's systems hook into the stage change later. User's call: no teaser hex until Zone 2 is designed | Copper content or Zone 2 is designed |
| Grade | Flawless (0 cracks), Clean (1), Scraped through (2–3), shown on the result. No reward | The trial passes once, so a missed bonus could never be earned back | — |
| Sound | None in v1 | The game has no audio yet | The game-wide audio pass |
| Later stages | Each stage's breakthrough reuses this mini-game with its own `TribulationData` (phases, timings, windows, cracks, penalty) | The GDD ends every stage in a breakthrough, and the data file costs almost nothing now | A later stage wants a different mini-game |
| Story | The trial's own intro and result panels, with placeholder lines. No dialogue scene | Narrative content after Beat 3b isn't written, and the Celestial Intervener has left | The narrative pass |
| Controls | Space or left click. Hold through the last breath | Matches the prototype the user played | Players ask for rebinding |
| Quitting | The intro panel can be left ("Not yet", or Escape). Once the trial starts there's no way out: Escape does nothing and there's no close button. If the game closes mid-trial, nothing is applied | Commitment for 40 seconds. Nothing is written until the result | Players exploit quitting |
| Losing focus | The run keeps going when the window loses focus. An alt-tab or a notification turns into misses and can cost the 5 levels; a hold in progress ends as an early release | User's call: no free escape from the penalty | Players report unfair losses |
| Presentation | A lacquer board in the map gap, like the cycling view: HUD boards hidden, map input off, no grey backdrop. It follows [STYLE_GUIDE.md](../../STYLE_GUIDE.md): the prototype's timing and feel carry over, but its glows, gradients, fades and motes don't (see Feedback) | The user asked for the lacquer look across the game (2026-10-22). The guide bans the prototype's effects, and its treatment for overlays is a board in the map gap (§13, Z1) | — |
| Curve | The Core Density curve isn't retuned here | A separate pacing pass owns it | That pass |

## The trial

### A breath

The board shows the core in the middle and a brass ring of radius R around it. An aura sphere breathes around the core:

- **Breathing in:** the sphere grows from 0.42 R to 1.88 R over the first half of the breath. It is drawn faint; no press is expected.
- **Breathing out:** it shrinks back to 0.42 R over the second half, drawn bright. The **beat** is the moment it crosses the ring: 60.5% of the way through the out-breath, (1.88 − 1) / (1.88 − 0.42).

The prototype draws in a 1000 × 620 space with R = 130, the core at 34 rising to 58, and the sphere from 55 to 245. Scale those to the board.

### Schedule

At tempo 1.0:

| Phase | HUD tip | Breaths | Notes |
|---|---|---|---|
| Lead-in | — | 1.2 s of stillness | |
| Steady breath | "Press as the bright aura crosses the brass ring" | 6 × 1.7 s | |
| Heartbeat | "The rhythm breaks. Follow it." | 1.45, 0.95, 1.4, 0.9, 1.25, 0.85 s | |
| Echo | "A second breath answers the first. Catch both." | Sphere A: 3 × 1.6 s. Sphere B, in the light Madra step: 3 × 1.5 s, starting 0.6 s after A | 6 beats, interleaved; the closest pair is about 0.3 s apart |
| Quickening | "The breaths come faster. Keep up." | 0.8 s after Echo: 1.3, 1.15, 1.0, 0.9, 0.8, 0.72 s | Madra pellets stream into the core |
| The last breath | "Press as it crosses the ring, then hold while it pours into your core" | 0.5 s after Quickening: one breath that grows to 2.54 R over 1.8 s and shrinks over 4.5 s | Press at the crossing, then hold until the sphere reaches the core, about 1.23 s |

The run ends 1.2 s after the last breath: about 38 s and 25 beats. `tempo` divides every duration.

### Judging

- **Hits:** a press within the good window of the nearest unjudged beat is a hit, perfect within the perfect window and good otherwise.
- **Early misses:** a press earlier than the good window, but no more than max(0.30 s, good window + 0.10 s) before that beat, is a miss for that beat.
- **Ignored presses:** presses farther from any beat are ignored, so a stray press while the sphere breathes in is free.
- **Late misses:** a beat that passes by more than the good window without a press is a miss.
- **The hold:** on the last breath a hit starts a hold. Releasing more than 0.05 s before the sphere reaches the core is a crack ("Released too early"); holding to the end is "Held".
- **Cracks:** every miss and early release is a crack. The trial fails the moment cracks reach `cracks_to_fail` (4); otherwise it passes at the end.
- **Grade:** 0 cracks Flawless, 1 Clean, 2–3 Scraped through. Cosmetic only.
- **Timing:** judge each press when it arrives (in the state's `handle_input`) against a clock read from `Time.get_ticks_usec()` at that moment, not from accumulated frame delta, so judging doesn't drift with the frame rate.
- **Focus loss:** nothing pauses. The clock keeps running, so beats pass as late misses. On `NOTIFICATION_APPLICATION_FOCUS_OUT` during the hold, call `run.release()`, so a key-up lost to another window can't keep the hold alive.

### Feedback (no sound in v1)

Everything follows [STYLE_GUIDE.md](../../STYLE_GUIDE.md): opaque art on the 2 px grid, state shown by art, motion in whole steps, and no glow, gradient, fade or translucency. The prototype's effects translate like this:

| Prototype | In the game |
|---|---|
| A faint sphere breathing in, a bright one breathing out | Breathing in: a dashed tan ring. Breathing out: a solid Madra-blue ring, 2 art px wide, with a 1 art px `#E8F6FD` crest inside. The radius snaps to even px every frame (the guide's snapped paths), not to 10 steps a second, because judging needs every frame |
| The brass ring pulses on a hit | The ring swaps to a lit frame for one `steps(1)` flash |
| Motes burst off the ring | Opaque Madra pellets (`MadraPellet`) fly off the ring in 2 px steps |
| The core grows | The core art steps up through a few sizes (frames, or the pixel-grid shader pattern of §8) |
| Glowing cracks on the core | Ember crack overlays on the core art; a crack pip lights in the HUD |
| The board shakes on a miss | `MapGlyph.shake_offset_at()` keyframes: the soft set for a miss, the full set for the crack that fails the trial |
| A glow and pulling motes in Quickening and the last breath | No glow. Madra pellets stream from the board's edges into the core in 2 px steps |
| A brass arc fills during the hold | A brass arc in 24 whole steps, like `lacquer_cooldown_sweep.gdshader` |
| "Perfect", "Good" and "Miss" fading at the board's right | `LacquerFloater` words in brass, Madra blue or ember ("Too early" / "Too late" under a miss), rising in whole steps and hidden outright |
| A copper core on a pass, a dimmed core on a fail | A palette swap to the brass ramp (`palette_swap.gdshader`) on a pass; a carved "spent" core frame on a fail, never alpha |

The prototype's millisecond offsets were a tuning aid; the game shows only the words.

### Panels

- **Intro panel**, when the view opens:
  - the title and one rules line built from the data ("4 cracks end the trial and cost 5 levels of Core Density");
  - **Begin** and **Not yet**. Space or a click on the board also begins. **Not yet** and Escape close the view with nothing changed.
- **During the run:** no way out (see Decisions).
- **Result panel:**
  - **Pass:** "Breakthrough" and "Your core condenses into Copper."
  - **Fail:** "Your core cracks" and "Core Density falls from 100 to 95."
  - Either way, the grade, the perfect / good / missed counts, and **Continue**, which closes the view.

All copy is placeholder and lives in the `TribulationData`.

## Starting values and test plan

All values are **starting values**, kept in `foundation_tribulation.tres` so they tune without code.

| Value | Start | Test | If it fails |
|---|---|---|---|
| Perfect / good windows | ±70 ms / ±140 ms | Five first attempts by a player who has played for a while: aim for 2–3 passes | All five pass → good window ±120 ms, or 3 cracks to fail. Zero or one pass → good window ±160 ms |
| Early-miss reach | max(0.30 s, good + 0.10 s) before a beat | Mashing Space through a run must fail | Mashing passes → widen it |
| Cracks to fail | 4 | The same five attempts | See the windows row |
| Release tolerance | 0.05 s | A player who holds to the end never reads "Released too early" | 0.10 s |
| Length | About 38 s, 25 beats | Ask after each attempt whether it dragged | Cut Steady breath to 4 breaths |
| Penalty | 5 levels | Time to get back to 100 | Today about 40–75 s of Smooth Flow cycling: levels 96–100 cost about 342 XP, and a cycle gives 70–125 XP. The Core Density retune sets the real weight |
| Copper stage | 20 × 1.02^(L−1) XP per level; Madra cap 600 + 10 × L | None: placeholders until Copper is designed. The cap starts at Foundation's 600, so it never drops at the breakthrough | — |

## Open / deferred

- **The Core Density curve retune.** It sets when level 100 arrives and how heavy the 5-level penalty feels.
- **Sound,** in the game-wide audio pass.
- **Copper content:** Scripting, Elixir Making, a second path-tree tier and the Iron Tribulation. Until then, Copper path points pile up unspent, and reaching Copper's cap does nothing.
- **Narrative:** the lines are placeholders.
- **A map teaser for Zone 2** was dropped from v1 (user, 2026-10-23). The map shows a zone as UNCHARTED whenever its chart condition is unmet, before it looks at the unlock condition (`zone_manager.gd:147-151`). So "locked in Foundation, uncharted at Copper" would need a rule change or new veil art. It belongs in Zone 2's design.
- **Closing the game mid-trial** still applies nothing, so it remains a way out of a failing run. Staking the penalty when the trial starts would close that gap, at the cost of penalising crashes.
- **Save versioning:** a save that has reached Copper, opened in a build from before this feature, still hits the endless level-up loop. The guard below only protects new builds.

## Design

### Approach

**Chosen: a pure `TribulationRun` judges, the view draws it, and `CultivationManager` applies the result.**

- `TribulationRun` is a `RefCounted` that builds the beat schedule from a `TribulationData` and answers presses, releases and the passage of time. It has no nodes, so tests drive it with exact times.
- `TribulationView` reads it every frame to draw the board and HUD.
- When the run ends, the view calls `CultivationManager.advance_to_next_stage()` or `lose_core_density_levels()` right away, before the result panel shows, so closing the game on that panel can't dodge the penalty.
- `ActionManager` only opens and closes the view, through `start_tribulation` and `stop_tribulation`, as it does for cycling and the merchant.

Rejected:

- **Building on `CyclingTechnique`,** as the old design did. The trial isn't cycling any more: its tracking model, ball and Madra payout don't fit.
- **A `TribulationManager` autoload.** The Tribulation keeps no state of its own: the result is one `CultivationManager` call, and the run only lives while the view is open.
- **Applying the result through the action's `success_effects` and `failure_effects`.** Those run in `stop_action()`, when the player presses Continue, so quitting on the result panel would skip the penalty. No effect type changes the stage or Core Density either (`scripts/resource_definitions/effects/effect_data.gd:4-14`).

### Data model

| Class | File | Fields |
|---|---|---|
| `TribulationPhaseData` (Resource) | `scripts/resource_definitions/tribulation/tribulation_phase_data.gd` | `phase_name: String`, `tip: String`, `gap_before: float`, `breath_periods: PackedFloat32Array`, `echo_periods: PackedFloat32Array` (a second sphere in the light Madra step; empty for none), `echo_offset: float`, `aura_rush: bool` (pellets stream into the core) |
| `TribulationData` (Resource) | `scripts/resource_definitions/tribulation/tribulation_data.gd` | `target_stage: CultivationManager.AdvancementStage`; copy: `title`, `intro_text`, `pass_title`, `pass_text`, `fail_title`, `fail_text`. Timing: `tempo` 1.0, `lead_in` 1.2, `phases: Array[TribulationPhaseData]`, `last_breath_gap` 0.5, `last_breath_in` 1.8, `last_breath_out` 4.5, `last_breath_max_ratio` 2.54, `end_pause` 1.2. Geometry: `sphere_min_ratio` 0.42, `sphere_max_ratio` 1.88 (of the ring radius). Judging: `perfect_window` 0.07, `good_window` 0.14, `early_reach_min` 0.30, `release_tolerance` 0.05, `cracks_to_fail` 4. Penalty: `failure_level_loss` 5 |
| `TribulationActionData` (`ZoneActionData`) | `scripts/resource_definitions/zones/zone_action_data/tribulation_action_data/tribulation_action_data.gd` | `tribulation: TribulationData`; `_init()` sets `action_type = TRIBULATION` (like `merchant_action_data.gd:23-24`) |
| `ZoneActionData.ActionType.TRIBULATION` | `zone_action_data.gd:4-12` | Appended as 7. `.tres` files store the number, so it must not be inserted |
| `AdvancementStageResource.max_core_density_level` | `scripts/resource_definitions/cycling/advancement_stage/advancement_stage.gd` | `int`, default 100. Replaces the display-only `CultivationManager.BREAKTHROUGH_LEVEL` (`cultivation_manager.gd:36`; read by `cultivator_plate.gd:112` and `goals_panel.gd:136-139`) |
| `SaveGameData.core_density_milestones` | `singletons/persistence_manager/save_game_data.gd` | `Dictionary[int, int]`: stage enum → the highest milestone level already paid. Missing on old saves; seeded from the current level on load (see below) |

`TribulationRun` (`scripts/tribulation/tribulation_run.gd`, `RefCounted`) has no fields of its own to configure:

| Member | Behaviour |
|---|---|
| `_init(data: TribulationData)` | Builds the breaths (start, in-time, out-time, max radius, which sphere) and the beats (time, phase, whether it is the last breath, hold length), sorted by time |
| `press(t: float) -> Dictionary` | `{result: PERFECT / GOOD / EARLY_MISS / IGNORED, offset: float, last: bool}`; a hit on the last breath starts the hold |
| `release(t: float) -> Dictionary` | `{result: HELD / RELEASED_EARLY / IGNORED}` |
| `advance(t: float) -> Array[Dictionary]` | Late misses and a completed hold since the last call |
| `cracks`, `perfect_count`, `good_count`, `is_failed()`, `is_finished(t)`, `grade() -> String` | Read by the view and the tests |
| `phase_at(t) -> TribulationPhaseData` (null during the last breath), `spheres_at(t) -> Array` (radius ratio, bright or faint, which sphere), `hold_progress(t)`, `progress(t)` | Drawing |

### CultivationManager changes

All in `singletons/cultivation_manager/cultivation_manager.gd`.

| Member | Behaviour |
|---|---|
| `get_core_density_cap() -> int`, `is_core_full() -> bool` | The current stage's `max_core_density_level`; full means the level equals it |
| `add_core_density_xp()` | The level-up loop (`:83-98`) stops at the cap. XP earned at the cap is discarded, and the stored XP stays 0. Each level-up emits `core_density_level_updated` as today |
| Path-point milestones (`:92-95`) | Pay a stage's milestone only when the level is above that stage's entry in `core_density_milestones`, then record it. On load, a stage with no entry is seeded with its current level rounded down to a multiple of 10, so old saves aren't paid twice. Check `tests/unit/test_cultivation_manager.gd:173-178`, which pins today's award, and keep it passing for first-time crossings |
| Endless-loop guard | If the XP cost for the next level is 0 or less (`:106-111`, no stage resource), log an error and stop levelling instead of looping forever |
| `lose_core_density_levels(count: int) -> void` | `level = max(0, level − count)`, `xp = 0`, emits `core_density_level_updated`. Path points already earned stay |
| `advance_to_next_stage() -> bool` | Reads the current stage resource's `next_stage`; false if there is none. Sets `current_advancement_stage` to its `stage_id`, level and XP to 0, emits `core_density_level_updated` and `advancement_stage_changed`, and logs "You break through to Copper." |
| `signal core_filled(stage)` | Emitted on the level-up that reaches the cap. The view-independent hook for the log line below |
| `attempt_breakthrough()` | Deleted; `advance_to_next_stage()` replaces it. Nothing calls it today |
| Load clamp | On load (`_update_resources()`), a level above the current stage's cap is set to the cap with XP 0. Path points already earned stay, and the milestone record is seeded from the clamped level |

Registration: add the Copper resource to the exported `advancement_stage_resources` array (`:23-25`) and to `advancement_stage_list.tres`, and set Foundation's `next_stage` to it.

### Other code changes

- **`ActionManager`** (`singletons/action_manager/action_manager.gd`):
  - signals `start_tribulation(action: TribulationActionData)` and `stop_tribulation()`, next to `start_cycling` (`:17-19`);
  - a TRIBULATION arm in `_execute_action` (`:175-209`) and in `_stop_executing_current_action` (`:213-235`), with handlers shaped like the cycling ones (`:283-285`, `:356-360`);
  - a gate in `select_action` beside the adventure's Madra gate (`:121-124`): refuse unless `CultivationManager.is_core_full()` and the current stage is the one before `tribulation.target_stage`;
  - TRIBULATION is not an idle action, so stopping it resumes the zone's idle action, as cycling does.
- **The Tribulation card:**
  - a `TribulationPresenter` scene and script registered in `PRESENTER_SCENES` (`scenes/zones/zone_action_button/zone_action_button.gd:61-70`);
  - it copies the adventure presenter's NeedGroup (`adventure_presenter.tscn:13-66`, `adventure_presenter.gd:65-85`) to show "Core 95 / 100" and refreshes on `core_density_level_updated`;
  - `can_activate()` returns `is_core_full()`, and `on_activation_rejected()` shakes the row and logs "Your core must be full to face the Tribulation (95 / 100)." as the adventure card does (`:51-59`).
- **Card group** (`scripts/utils/zone_action_groups.gd`): TRIBULATION joins the Cultivate group with the tag "TRIAL". Unknown types would otherwise land under Visit as "STORY" (`:30-40`, `:58-66`).
- **Hiding the card after the pass:** unlocks latch (`unlock_manager.gd:87-99`), so the Core Density condition can't hide it again. Wherever ZoneManager filters a zone's available actions, skip a `TribulationActionData` whose `tribulation.target_stage` is at or below the current stage.
- **Goals board** (`scenes/ui/goals_panel/goals_panel.gd:134-140`):
  - At the cap, row 2 reads "Face the Tribulation" with the rod full.
  - When the current stage has no `next_stage`, it reads "Copper reached" (the stage's name) with the rod full.
  - Connect `advancement_stage_changed` beside the existing refresh signals (`:75-76`).
- **Cycling at the cap:** while `is_core_full()`, a cycling-zone hit shows "Core full" where it would show "+N XP". Madra still flows.
- **`ResourceManager.add_madra()`** (`resource_manager.gd:75`): adding Madra never lowers it. When Madra is already above the cap (after a failure lowers the cap, or after the load clamp), a gain is discarded instead of trimming the pool to the cap.
- **Log line:** on `core_filled`, `LogManager.log_message()` writes "Your core is full. The Tribulation waits in Spirit Valley." No toast: the card's NEW seal already marks it (`zone_action_button.gd:335-337`).
- **Input:** a new action `tribulation_press` bound to Space and the left mouse button in `project.godot`. Every button in the view sets `focus_mode = FOCUS_NONE`, so Space never activates them (as `cycling_view.tscn:78,125` does). Dialogic also sees Space and clicks, but acts only during a timeline (`addons/dialogic/Modules/Core/subsystem_input.gd:117-134`).
- **`MainView`:** a `TribulationViewState` node under `MainViewStateMachine` (`main_game.tscn:108-142`, referenced in `main_view.gd:37-45`) and a hidden `TribulationView` node at z 3, like `MerchantView`.

### Content

- `resources/tribulation/foundation_tribulation.tres`: the `TribulationData` with four `TribulationPhaseData` sub-resources (Steady breath, Heartbeat, Echo, Quickening) and the values in The trial; `target_stage` COPPER.
- `resources/zones/spirit_valley_zone/zone_actions/tribulation_action.tres`: a `TribulationActionData` named "The Tribulation", with `unlock_conditions` set to the condition below. Referenced in `spirit_valley_zone.tres` and appended to its `all_actions` (`:25`).
- `resources/unlocks/core_density_full.tres`: CULTIVATION_LEVEL `>=` 100, modelled on `q_reach_cd_10.tres`. Add it to `unlock_condition_list.tres`, because unlisted conditions are never evaluated (`unlock_manager.gd:86`).
- `resources/cycling/advancement_stages/copper_advancement_stage/copper_advancement_stage.tres`: `stage_id` 1, name "Copper", `core_density_base_xp_cost` 20, `core_xp_scaling_factor` 1.02, `max_madra_base` 600, `max_madra_per_core_density_level` 10, `max_core_density_level` 100, `next_stage` empty.

### Scene tree

```
TribulationView (Control, full rect, hidden, z 3)        scenes/tribulation/tribulation_view.gd (class TribulationView)
│                                                        theme = assets/themes/lacquer/lacquer_theme.tres
└── Board (NinePatchRect, in the map gap, about 1240 × 800)  lacquer board art: lacquer_cyc_board_ai.png if its 9-patch stretches
    │                                                     to landscape cleanly, otherwise a new lacquer_trib_board_ai.png
    ├── BoardMargin (MarginContainer) > BoardVBox
    │   ├── HeaderHBox: ActionLabel (%, the zone's name) · TitleLabel (%, "The Tribulation")
    │   ├── StageFrame (Control, expand) > Stage (%, Control, 1000 × 620, clip)   scenes/tribulation/tribulation_stage.gd
    │   │   ├── Ring (%, TextureRect: the brass ring, with a lit frame for hit flashes)
    │   │   ├── Core (%, TextureRect: core sizes, crack overlays, the spent frame; palette_swap material for copper)
    │   │   ├── HoldArc (%, TextureRect + a cooldown-sweep-style shader, 24 steps)
    │   │   ├── Pellets (%, Node2D: pre-instanced MadraPellet nodes, reused for bursts and the aura rush)
    │   │   └── Floaters (%: pre-instanced LacquerFloater words at the stage's right)
    │   │   The spheres are drawn by the Stage in _draw() on even px in kit colours (dashed tan breathing in,
    │   │   solid Madra blue breathing out), from the current TribulationRun
    │   ├── HudHBox: PhaseVBox (PhaseNameLabel (%), PhaseTipLabel (%)) · CrackPips (%, HBoxContainer of
    │   │   6 pre-instanced pip TextureRects; the view shows cracks_to_fail of them)
    │   └── ProgressRod (%, the lacquer rod from scenes/common/lacquer/)
    ├── IntroPanel (%, a lacquer drawer over the stage): IntroTitle · IntroText · RulesLabel · BeginButton (%) · NotYetButton (%)
    └── ResultPanel (%, a lacquer drawer over the stage): ResultTitle · ResultText · GradeLabel · StatsLabel · ContinueButton (%)
```

- **Styling:**
  - labels take lacquer theme variants (`docs/UI_STYLING.md`, `lacquer_theme.tres`);
  - nodes are authored in the `.tscn`; scripts set only text, visibility, textures and the stage's run;
  - panels and words show and hide outright, with no fades (STYLE_GUIDE §8);
  - long lines such as the last breath's tip wrap, and their board grows to fit (STYLE_GUIDE rule 14).
- **New art,** all following the `_ai` naming rule in CLAUDE.md and STYLE_GUIDE §9, probably:
  - the board, if the cycling board doesn't stretch;
  - the ring and its lit frame;
  - the core sizes, crack overlays and spent frame;
  - the crack pips and the hold arc frame.

  List each new file in the build summary.
- **The state:** `TribulationViewState` (`scenes/tribulation/tribulation_view_state.gd`) follows `CyclingViewState`, not the merchant's grey backdrop:
  - on enter, hide the HUD boards and turn map input off, as cycling mode does (`main_view.gd:135-141`);
  - on stop, hide the view, restore both, and `remove_state(self)`.
- **Input:** `MainView` sends input only to the top state (`main_view.gd:75-78`), so the state's `handle_input` routes `tribulation_press` to the view and ignores Escape once the run has started. The board's mouse filter stops clicks from reaching the map under it.

### Signal map

| Signal | Emitted by | Consumed by | Payload |
|---|---|---|---|
| `CultivationManager.core_density_level_updated` | Level-ups, `lose_core_density_levels()`, `advance_to_next_stage()` | UnlockManager (re-check), TribulationPresenter (need row), Goals board, cultivator plate | xp, level |
| `CultivationManager.core_filled` | The level-up that reaches the cap | A log line | stage |
| `UnlockManager.condition_unlocked` | `core_density_full` | Zone chest (shows the card) | condition id |
| `ActionManager.start_tribulation` | `_execute_tribulation_action()` | `TribulationViewState`: `view.setup(action.tribulation)`, then `push_state()` once | `TribulationActionData` |
| `TribulationView.finished` | Continue on the result panel, or Not yet | `TribulationViewState`: `ActionManager.stop_action(passed)` | `passed: bool` |
| `ActionManager.stop_tribulation` | `_stop_tribulation_action()` | `TribulationViewState`: hide the view, restore the HUD boards and map input, then `remove_state(self)` | — |
| `CultivationManager.advancement_stage_changed` | `advance_to_next_stage()` | UnlockManager (re-check, `unlock_manager.gd:48`), Goals board, cultivator plate, zone chest (the card hides) | new stage |

### Data flow

```
Core fills:  cycling XP → add_core_density_xp → the level reaches the cap (100) → core_filled → log line
               → core_density_level_updated → UnlockManager re-checks → core_density_full latches
               → the Tribulation card appears with a NEW seal; the Goals board reads "Face the Tribulation"

Open:        card click → TribulationPresenter.can_activate() (core full)
               → ActionManager.select_action → gate passes → start_tribulation(action)
               → TribulationViewState: view.setup(data); push_state → HUD boards hide, map input off, IntroPanel shows

Run:         Begin / Space / click → run = TribulationRun.new(data); t0 = Time.get_ticks_usec()
             each frame: run.advance(t) → late misses, hold done → feedback; Stage redraws; HUD updates
             tribulation_press down → run.press(t);  up → run.release(t)
             run.is_failed() → end(false);  run.is_finished(t) → end(true)

End, pass:   CultivationManager.advance_to_next_stage() → stage COPPER, level 0, xp 0
               → advancement_stage_changed → the card hides; the Goals board reads "Copper reached"
               → ResultPanel: "Breakthrough" + grade
End, fail:   CultivationManager.lose_core_density_levels(5) → level 95
               → the card shows "Core 95 / 100"; ResultPanel: "Your core cracks" + grade

Close:       Continue → finished(passed) → ActionManager.stop_action(passed)
               → completion count +1, stop_tribulation, the action's effects (none in v1)
               → TribulationViewState hides the view, restores the HUD and map input, remove_state(self)
               → the zone's idle action resumes
             SaveTimer writes save.tres within 5 s. Nothing is written before the result, so a crash mid-trial changes nothing
```

### Tests

Follow `docs/testing/TESTING.md`:
- call real autoload methods with their state swapped and restored in `after_each()`;
- no GUT doubles;
- never instance `main_game.tscn`.

The tests to write:

- **`tests/unit/test_tribulation_run.gd`:**
  - the Foundation schedule: 25 beats, about 38 s, phase boundaries and tempo scaling;
  - judging: perfect, good, early miss, late miss, and ignored presses;
  - the nearest beat chosen in Echo's close pair;
  - the hold: early release and held;
  - failing the moment cracks reach the limit, passing at the end, and the grades.
- **`tests/unit/test_cultivation_manager.gd`** (extend):
  - the cap: no level 101, XP at the cap discarded;
  - 100 → 95 → 100 pays no second path point, while first crossings still pay;
  - seeding milestones for an old save;
  - `lose_core_density_levels`;
  - `advance_to_next_stage` (stage, level, XP, signals, the Copper Madra cap, false with no next stage);
  - the endless-loop guard;
  - the load clamp: a save at 130 loads at 100 and keeps its path points.
- **Madra tests** (wherever `ResourceManager.add_madra()` is tested): a gain above a lowered cap keeps the pool instead of trimming it.
- **Existing tests that load saves above 100** and need new expectations: `tests/integration/test_goals_panel.gd:275` and `tests/integration/test_cultivator_plate.gd:213`.
- **`tests/unit/test_foundation_tribulation_data.gd`:** the real `.tres` wiring:
  - phases and values, the action is a `TribulationActionData` gated on `core_density_full`;
  - that condition is registered;
  - Foundation's `next_stage` is Copper, and Copper is registered.
- **`tests/unit/test_tribulation_view_state.gd`:** the overlay pushes once, ignores Escape during a run, restores the HUD boards and map input, and removes only itself. Modelled on `test_merchant_view_state.gd` and `test_cycling_mode.gd`.
- **`tests/integration/test_tribulation_flow.gd`:**
  - reaching 100 unlocks the card;
  - `select_action` refuses below 100;
  - a pass sets Copper and level 0 and hides the card;
  - a fail sets 95 and the card stays;
  - stopping resumes the idle action.
- **Focus loss** (in the view's tests): a focus-out notification during the hold counts as an early release, and the run's clock keeps going.
- **`tests/unit/test_zone_action_groups.gd`:** TRIBULATION is grouped under Cultivate.

Living docs to update when it ships: [CULTIVATION.md](../../cultivation/CULTIVATION.md), [ZONES.md](../../zones/ZONES.md), [FOUNDATION_PLAYTHROUGH.md](../../progression/FOUNDATION_PLAYTHROUGH.md), [UNLOCKS.md](../../infrastructure/UNLOCKS.md), [MAIN_VIEW.md](../../infrastructure/MAIN_VIEW.md) and [STATE_OF_THE_GAME.md](../../STATE_OF_THE_GAME.md).
