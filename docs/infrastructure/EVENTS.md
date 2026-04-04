# Event System

## Overview

`EventManager` is a one-shot narrative event tracker. Events are triggered permanently (never un-triggered) and serve as flags for the unlock system and content gating.

## API

- `trigger_event(event_id)` — records permanently, emits `event_triggered`
- `has_event_triggered(event_id) -> bool` — membership check
- Event IDs are bare strings — no central registry or constants file

## Key Files

| File | Purpose |
|------|---------|
| `singletons/event_manager/event_manager.gd` | Narrative event tracking |

## Known Issues

- Event IDs are magic strings with no central registry — scattered at call sites
