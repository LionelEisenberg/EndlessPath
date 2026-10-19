# Design Specs and Implementation Plans

Last updated: 2026-10-18

This folder is the **historical record** of feature work. Each feature usually has a design spec (`specs/`) and a step-by-step implementation plan (`plans/`), written before the work started. They are not updated after a feature ships, and many plans still have unticked checkboxes. **For current behaviour, read the living system doc** linked in each row. Statuses were verified against the code on `main` (`21b3cb2`) during the 2026-10-18 documentation audit.

Status key:
- **Shipped:** built as specified.
- **Shipped\*:** built, with deviations listed in Notes.
- **Partial:** some of the scope is unbuilt.
- **Superseded:** shipped, then later replaced.

| Date | Feature | Spec | Plan | Status | Notes | Living doc |
|---|---|---|---|---|---|---|
| 2026-04-10 | Adventure end card | [spec](specs/2026-04-10-adventure-end-card-design.md) | [plan](plans/2026-04-10-adventure-end-card.md) | Shipped\* | Timeouts are labelled "You retreated" | [ADVENTURING](../adventuring/ADVENTURING.md) |
| 2026-04-10 | Zone action button visuals | [spec](specs/2026-04-10-zone-action-button-visuals-design.md) | [plan](plans/2026-04-10-zone-action-button-visuals.md) | Shipped\* | PR #18; reworked into presenters in PR #29 | [ZONES](../zones/ZONES.md) |
| 2026-04-11 | Path progression | — | [plan](plans/2026-04-11-path-progression.md) | Shipped\* | Node ids and costs differ from the plan; numeric perks are computed but never applied | [PATH_PROGRESSION](../progression/PATH_PROGRESSION.md) |
| 2026-04-12 | Ability system redesign | [spec](specs/2026-04-12-ability-system-redesign.md) | [plan](plans/2026-04-12-ability-system-redesign.md) | Shipped\* | Unlock call lives in `PathManager.purchase_node()`; path-ability reset not built; drag-drop added beyond spec | [ABILITIES](../abilities/ABILITIES.md) |
| 2026-04-12 | Cycling technique unlock | [spec](specs/2026-04-12-cycling-technique-unlock-design.md) | [plan](plans/2026-04-12-cycling-technique-unlock.md) | Shipped | PR #21 | [CYCLING](../cycling/CYCLING.md) |
| 2026-04-13 | Ability stats display | [spec](specs/2026-04-13-ability-stats-display-design.md) | — | Partial | No glow shader; pills don't live-update | [ABILITIES](../abilities/ABILITIES.md) |
| 2026-04-13 | Tilemap visual overhaul | [spec](specs/2026-04-13-tilemap-visual-overhaul-design.md) | [plan](plans/2026-04-13-tilemap-visual-overhaul.md) | Partial | Shipped: atmosphere, fog, encounter icons, path preview. Not built: boss ring, treasure sparkle, hidden traps, player glow, others | [ADVENTURING](../adventuring/ADVENTURING.md) |
| 2026-04-15 | Assets folder cleanup | [spec](specs/2026-04-15-assets-folder-cleanup-design.md) | [plan](plans/2026-04-15-assets-folder-cleanup.md) | Shipped | The planned `audio/` folder was never created (the game has no audio); a few stray files remain. Current layout in UI_STYLING | [UI_STYLING](../UI_STYLING.md) |
| 2026-04-15 | Combat view improvements | [spec](specs/2026-04-15-combat-view-improvements-design.md) | [plan](plans/2026-04-15-combat-view-improvements.md) | Shipped\* | Enemy ability tooltips use the player's attributes | [COMBAT](../combat/COMBAT.md) |
| 2026-04-15 | Fog of war redesign | [spec](specs/2026-04-15-fog-of-war-redesign-design.md) | [plan](plans/2026-04-15-fog-of-war-redesign.md) | Shipped | Iterated since (veil fade, marker pin) | [ADVENTURING](../adventuring/ADVENTURING.md) |
| 2026-04-16 | Character view | [spec](specs/2026-04-16-character-view-design.md) | [plan](plans/2026-04-16-character-view.md) | Shipped\* | No live update on attribute change; tooltip formulas copied from the spec are wrong | [CHARACTER](../infrastructure/CHARACTER.md) |
| 2026-04-16 | Quest system | [spec](specs/2026-04-16-quest-system-design.md) | [pass 1](plans/2026-04-16-quest-system-pass-1-backend.md), [pass 2](plans/2026-04-16-quest-system-pass-2-ui.md) | Shipped\* | Hand-maintained `quest_list.tres` instead of a folder scan; completed entries aren't dimmed | [QUESTS](../progression/QUESTS.md) |
| 2026-04-17 | Foundation Beat 1 | — | [plan](plans/2026-04-17-foundation-beat-1.md) | Shipped\* | NPC renamed to Celestial Intervener; dagger award removed in `d934de4` | [FOUNDATION_PLAYTHROUGH](../progression/FOUNDATION_PLAYTHROUGH.md) |
| 2026-04-17 | Training action infrastructure | [spec](specs/2026-04-17-training-action-infrastructure-design.md) | [plan](plans/2026-04-17-training-action-infrastructure.md) | Shipped\* | PR #29; content became the Aura Well (PR #36); empty `ticks_per_level` sentinel not built | [ZONES](../zones/ZONES.md) |
| 2026-04-17 | Zone action button presenter refactor | [spec](specs/2026-04-17-zone-action-button-presenter-refactor-design.md) | [pass 1](plans/2026-04-17-zone-action-button-presenter-refactor-pass-1.md), [pass 2](plans/2026-04-17-zone-action-button-presenter-refactor-pass-2.md) | Shipped | PR #29 | [ZONES](../zones/ZONES.md) |
| 2026-04-18 | Foundation Beat 2 | [spec](specs/2026-04-18-foundation-beat-2-design.md) | [plan](plans/2026-04-18-foundation-beat-2.md) | Shipped\* | `test_enemy` retune superseded by real Shallow Woods enemies; only the Abilities badge exists | [FOUNDATION_PLAYTHROUGH](../progression/FOUNDATION_PLAYTHROUGH.md) |
| 2026-04-20 | Beat 3a: Aura Well | [spec](specs/2026-04-20-beat-3a-aura-well-design.md) | [plan](plans/2026-04-20-beat-3a-aura-well.md) | Shipped\* | `negate` flag replaced by condition dictionaries; one Aura Well per map via quotas | [FOUNDATION_PLAYTHROUGH](../progression/FOUNDATION_PLAYTHROUGH.md) |
| 2026-04-20 | Dev panel | [spec](specs/2026-04-20-dev-panel-design.md) | [plan](plans/2026-04-20-dev-panel.md) | Shipped | Added a "Show Whole Map" toggle beyond the spec; the planned dev-panel integration test was never written | [DEV_TOOLS](../tooling/DEV_TOOLS.md) |
| 2026-04-20 | Empty Palm and Power Font redesign | [spec](specs/2026-04-20-empty-palm-power-font-redesign-design.md) | [plan](plans/2026-04-20-empty-palm-power-font-redesign.md) | Shipped\* | No VFX/SFX; the plan's separate cast bar wasn't built | [ABILITIES_MATRIX](../abilities/ABILITIES_MATRIX.md) |
| 2026-04-21 | Beat 3b: merchant unlock | [spec](specs/2026-04-21-beat-3b-merchant-unlock-design.md) | [plan](plans/2026-04-21-beat-3b-merchant-unlock.md) | Shipped | PR #41. The merchant shop UI was deferred by design and is still a stub | [FOUNDATION_PLAYTHROUGH](../progression/FOUNDATION_PLAYTHROUGH.md) |
| 2026-04-21 | Map generation rework | [spec](specs/2026-04-21-map-generation-rework-design.md) | [plan](plans/2026-04-21-map-generation-rework.md) | Shipped | PR #42; Shallow Woods retuned in May | [ADVENTURING](../adventuring/ADVENTURING.md) |
| 2026-04-21 | Quest items tab | [spec](specs/2026-04-21-quest-items-tab-design.md) | [plan](plans/2026-04-21-quest-items-tab.md) | Superseded | Shipped in PR #41, then rebuilt as the Journal tab (PR #43) | [INVENTORY](../inventory/INVENTORY.md) |
| 2026-04-23 | Map preview tool | [spec](specs/2026-04-23-map-preview-tool-design.md) | [plan](plans/2026-04-23-map-preview-tool.md) | Shipped | — | [DEV_TOOLS](../tooling/DEV_TOOLS.md) |
| 2026-05-22 | Items MD → `.tres` generator | — | [plan](plans/2026-05-22-items-md-generator.md) | Shipped\* | Equipment only; no `--delete-orphans`, no icon override column | [ITEMS](../inventory/ITEMS.md) |
| 2026-05-24 | Consumables | [spec](specs/2026-05-24-consumables-design.md) | [MVP plan](plans/2026-05-24-consumables-mvp.md) | Partial | Inventory side shipped. In-combat use is only on the unmerged branch `feat/infallible-chaum-58f8ad` | [INVENTORY](../inventory/INVENTORY.md) |
| 2026-05-25 | Equipment grid pagination | [spec](specs/2026-05-25-equipment-grid-pagination.md) | [plan](plans/2026-05-25-equipment-grid-pagination.md) | Shipped\* | 2 default pages; the tab's 7-column grid shows 42 slots per page against 36 in data | [INVENTORY](../inventory/INVENTORY.md) |
| 2026-05-25 | Inventory UI redesign | [spec](specs/2026-05-25-inventory-ui-redesign.md) | [plan](plans/2026-05-25-inventory-ui-redesign.md) | Partial | PR #43. Missing: rarity notch, ItemDetailCard replacing ItemDescriptionPanel, consumables grid/trash, wired Materials trash, Journal linked-quest row | [INVENTORY](../inventory/INVENTORY.md) |
| 2026-05-28 | SortSubBanner filter | [spec](specs/2026-05-28-sortsubbanner-filter-design.md) | — | Shipped | Equipment tab only | [INVENTORY](../inventory/INVENTORY.md) |

**Not on `main`:** a combat-consumables spec and plan exist only on the unmerged branch `feat/infallible-chaum-58f8ad`.

## Mockups

`mockups/` holds static HTML mockups referenced by the specs:
- `character-view-mockup.html`
- `consumable-combat-slots-mockup.html`
- `consumable-inventory-equip-mockup.html`
- `inventory-redesign/` (served by the `inventory-redesign` entry in `.claude/launch.json`)

## Older design docs outside this folder

Several system folders hold earlier design/plan pairs that predate this folder. Each now carries a status banner: [CYCLING_UI_REDESIGN](../cycling/CYCLING_UI_REDESIGN.md), [CYCLING_UI_IMPLEMENTATION_PLAN](../cycling/CYCLING_UI_IMPLEMENTATION_PLAN.md), [EQUIPMENT_DESIGN](../inventory/EQUIPMENT_DESIGN.md), [EQUIPMENT_IMPLEMENTATION_PLAN](../inventory/EQUIPMENT_IMPLEMENTATION_PLAN.md), [MADRA_UNIFICATION_DESIGN](../infrastructure/MADRA_UNIFICATION_DESIGN.md), [MADRA_UNIFICATION_PLAN](../infrastructure/MADRA_UNIFICATION_PLAN.md), and the unbuilt [breakthrough-tribulation](../cultivation/breakthrough-tribulation.md).
