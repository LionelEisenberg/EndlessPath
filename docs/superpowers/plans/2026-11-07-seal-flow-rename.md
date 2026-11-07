# Seal Flow Technique: renaming Torrential Flow (#152)

Playtest polish issue #152, tracked in #85. Torrential Flow lost its old job in the stats rework (#118, #128): it draws less Madra a cycle than Smooth Flow, and its zone became three seals that train Mind. It gets a name and copy that fit, and plays as before.

## Approved answers

Canvas "Renaming Torrential Flow" (https://claude.ai/artifact/SSvAon5k2fbhcuYifizhth). Lionel picked candidate A; the canvas's other proposed answers stand as drawn. Recorded on #152.

1. **Name:** Seal Flow Technique, on the technique (`technique_name`) and its path node (`display_name`). It ends in "Technique", like the rest of the roster.
2. **Description** (path node only): "A quick cycling technique with three seals on its path. Key each seal open before the ball reaches it, and the ball bursts through. Each seal you open trains Mind."
3. **Benefit line:** "Seal Flow Technique unlocked".
4. **Icon:** a new 16 px seal icon (drawn 2× in a 32 px file like the other technique icons), `assets/ui/lacquer/icons/lacquer_ic_tech_seal_ai.png`. The whirlpool's file stays, unused.
5. **The drawer** keeps its figures and Trains row, no prose. No code changes there.
6. **Ids and files stay** (`torrential_flow`), so saves load unchanged and no save version is claimed.

## Tasks

1. **Tests first.** Point the tests that pin the name at "Seal Flow Technique":
   - `tests/unit/test_path_details_card.gd`: `test_a_technique_unlock_names_the_technique`; rename `test_torrential_flow_s_node_copy` to the new name, and add checks that the node's name matches the technique's and the description names the seals.
   - `tests/integration/test_cycling_view.gd`: `test_title_follows_the_equipped_technique`, `test_showing_names_the_technique_that_is_set_up`. The status-line table's case labels stay (#144 rewrites it).
   - Run them: red.
2. **Data.** `torrential_flow.tres` (technique): `technique_name`, `icon`. `nodes/torrential_flow.tres`: `display_name`, `description`, `benefit_summary`.
3. **Icon.** Add `lacquer_ic_tech_seal_ai.png` and let `--import` write its `.import` (same settings as the other icons).
4. **Doc comments** that use the old name as their example: `CyclingView`'s class doc and `PathDetailsCard.format_effect()`'s.
5. **Suite** green; the Done-when checks on `-- --preset=path_open --save=user://dev/runs/torrential-flow-rename.tres`, plus an old save from `main` with the node bought and the technique equipped with Auto.

## Out of scope

How it plays, its ids and file names, the other techniques' names, Cycling Focus and Madra Reclamation, the running line (#144), hovers (#151), the log's look (#150), and design records that say "Torrential Flow".

## Built differently

Nothing: built as planned. The node test also checks that the node and the technique share one name and that the description names the seals.
