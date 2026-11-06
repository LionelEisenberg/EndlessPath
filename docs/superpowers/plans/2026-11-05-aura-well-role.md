# The Aura Well's role: implementation plan

Stats rework chunk #95 (tracking issue #85). Design: the spec's Phase 3 section and the approved [Aura Well canvas](https://claude.ai/artifact/KFDxk95zh5jfpr8uMc3qZA).

**Goal:** the Aura Well refills Madra only, and its card, Now strip line and map floater say exactly that, promising nothing the Spirit cap or a full pool throws away (OB-02).

## Approved at the mock-up step (2026-11-05, as drawn)

- **Now, not later.** No exception to the anti-goal: the Well trains nothing.
- **Madra only.** It keeps its 1.5 Madra a second, stopping at the max. Its +1 Spirit level per training level stops.
- **Its training levels pay nothing.** The saved ticks stay in the save, unread. The tick curve doesn't change, so no save step: an old save loads as it is and no level pays twice.
- **Copy**, the same below the Spirit cap and at it:
  - Card: "+1.5 Madra / s"; "Madra full" in the right column while the pool is full.
  - Now strip: the rate, "Full in 24 s", the pool's "64 / 100" and a rod toward full. At full: "+0 / s" dimmed, "Madra full", "100 / 100", the rod full.
  - Floater: "+1.5 Madra" each tick; the last tick before full only what fit ("+0.5 Madra"); nothing at full.
- No XP-award effect, so no `EffectData.EffectType` value is claimed.

## Tasks

1. **Write out the defaults** (done before the role changed): `aura_well_training_action.tres` writes its tick interval, curve and tail multiplier; the trickle its resource type; the Spirit award its amount. `tests/unit/test_aura_well_content.gd` checks each file writes them out.
2. **LL-07**: `test_training_flow.gd` binds `CultivationManager` to its own save too, and a test at Copper proves the cap read is that save's.
3. **The role**: `aura_well_training_action.tres` drops its `effects_on_level`, and `aura_well_spirit_award_effect.tres` goes (nothing else uses it). The content test checks the Well awards no stat.
4. **The tick's real gain**: `ActionManager` keeps the Madra the last training tick actually added (`get_last_tick_madra_gain()`), 0 at the max. Test in `test_training_flow.gd`.
5. **The floater**: `MapMarkers` pops that gain, and nothing when it is 0. Tests in `test_map_markers.gd` drive real ticks.
6. **The Now strip**: a training action whose levels grant nothing and which trickles Madra shows the pool: "Full in N s" (N rounded up from the room left over the rate) or "Madra full", "cur / max", the rod at the pool's fraction, and the rate "+0 / s" in dim at full. It follows Madra changes and stats changes (Mind moves the max). An action with a level award keeps today's line. Tests in `test_zone_panel.gd`.
7. **The card**: `TrainingPresenter` shows "Madra full" in the right column while the pool is full and the right column is otherwise empty, following Madra changes. Tests in `test_zone_action_cards.gd`.
8. Suite green; the issue's Done-when checks on `--save=user://dev/runs/aura-well-role.tres`.

## Built differently

- **The tick's gain lives in `ActionManager`**, outside the issue's Touches list. The floater has to know what a tick really added, and only the tick handler sees the pool before and after the trickle. `ActionManager` outside `select_action` is one of #85's allowed overlaps.
- **The cabinet's rate follows the pool too** (Lionel, after the first build, 2026-11-05; noted on #95 since the cabinet is a shared surface outside the Touches). `ActionManager.get_current_madra_per_second()` returns 0 for a training action at the max, and the cabinet re-reads its rate on `madra_changed`, so at full Madra it hides its rate (its rule for a +0 rate) instead of showing "+1.5 / s" beside the strip's "+0 / s".
- **The level award path stays.** The card and the strip still show "+1 Spirit / level" and "+1 Spirit at Lv n" for a training action whose levels grant a stat: no shipped action has one now, but the data allows it, and tests keep it working.
