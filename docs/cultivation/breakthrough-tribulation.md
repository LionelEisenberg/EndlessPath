# Breakthrough and Tribulation

Last updated: 2026-10-23

> **Status:** designed, not built. The design is [2026-10-23-tribulation-breath-of-the-core-design.md](../superpowers/specs/2026-10-23-tribulation-breath-of-the-core-design.md), settled with the user on 2026-10-23, with a [playable prototype](../superpowers/mockups/tribulation-breath-of-the-core-prototype.html). Today `CultivationManager.attempt_breakthrough()` is an empty stub, only the Foundation stage exists, and Core Density rises past 100 with no effect (see [CULTIVATION.md](CULTIVATION.md)).

## How it will play

- **The reveal.** Core Density stops at 100 in Foundation. The first time it gets there, "The Tribulation" appears among Spirit Valley's actions and stays.
- **The trial: Breath of the Core.** About 38 seconds:
  - An aura sphere breathes in and out around the core. The player presses space or clicks as the bright, shrinking sphere crosses a brass ring.
  - Five phases get harder: Steady breath, Heartbeat (an irregular rhythm), Echo (two spheres out of sync), Quickening (faster and faster), and the last breath, which ends in a hold while the aura pours into the core.
  - 4 cracks (misses) fail it.
- **Pass:** the player reaches Copper.
  - Core Density restarts at 0 on Copper's own curve and Madra cap.
  - The Tribulation card goes away.
  - Copper's own systems (Scripting, Elixir Making) come later.
- **Fail:** the core loses 5 levels (100 → 95, a starting value). The card stays, showing "Core 95 / 100", until the player cycles back to 100.
- **No escape mid-trial.** Once it starts, Escape does nothing, and losing window focus doesn't pause it.
- **Later stages** reuse the mini-game, each with its own `TribulationData` (harder timings, different crack limits and penalties).

## What it replaced

Two earlier designs conflicted. On 2026-10-23 the user replaced both with a simpler one:

- **This document's 2025 design:** a Breakthrough tile on adventure maps at Core Density 100, then a mouse-tracking Tribulation built on the cycling technique, with no failure penalty.
- **[FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md) Beats 7–9:** a Tribulation Guardian boss, then an Advancement Zone holding the Tribulation Site.

The user wanted the trial to start from the base as a plain zone action, a mini-game that isn't cycling, and a real penalty. The old text of this document is in git history (for example at `05c437e`).

## Related

- [CULTIVATION.md](CULTIVATION.md): Core Density, stages and the stage resources
- [FOUNDATION_PLAYTHROUGH.md](../progression/FOUNDATION_PLAYTHROUGH.md#beat-9-the-tribulation-planned): Beat 9 in the Foundation spine
