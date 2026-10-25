# Combat Consumables in the Lacquer Dock: Design

> **Status:** written on 2026-10-25. It carries the June combat-consumables design onto the lacquer adventure view. The user skipped the questions ("Put the consumables where you think they fit the lacquer frame best"), so every new choice below is Claude's and is marked as such.
>
> **Builds on:**
> - the June design, `docs/superpowers/specs/2026-06-01-combat-consumables-design.md` on the unmerged branch `feat/infallible-chaum-58f8ad` (20 commits, 2026-06-01). Its behaviour is kept. Its code and its look are not: it put a strip on the player's `CombatantInfoPanel`, which the adventure rework removed;
> - the [adventure view's lacquer design](2026-10-22-adventure-view-lacquer-design.md) (the technique dock, its tooltip and the cast tray);
> - the [style guide](../../STYLE_GUIDE.md).
>
> **Scope:** using the hotbar's consumables in a fight, and showing them on the technique dock.
>
> **Out of scope:**
> - a drop source for consumables;
> - new consumables, and any icon for Barely Coalesced Scale;
> - using consumables outside a fight;
> - the inventory's hotbar page, which the inventory pressed-pages design rebuilds;
> - the fight's own redesign (the adventure design's PR 2).

## Goal

The inventory can put four consumables on its hotbar ("carry it into combat"), but nothing on `main` uses them. With this design, the player can use them in a fight: they press 1 to 4 or click a socket. Each socket has its own cooldown, and a used consumable comes out of the inventory.

## Decisions

| Decision | Choice | From |
|---|---|---|
| Where they show | A row of four consumable sockets along the top of the technique dock, each over its technique: 1 over Q, 2 over W, 3 over E and 4 over R. The dock's board grows upward to hold the row | Claude. On the keyboard the number row sits over Q to R, and the dock is already where the player's hands are. The old home, the player's combat panel, is gone |
| Slots | Four, one per hotbar slot (`InventoryData.equipped_consumables`, keys 0 to 3). An empty hotbar slot shows an empty socket | June |
| Input | A click on a socket, or keys 1 to 4 (`consumable_slot_1` to `consumable_slot_4`, physical keys 1 to 4, unbound until now) | June |
| Cooldown | One per socket, from `ConsumableDefinitionData.cooldown_seconds`. It is reset every fight: the instances are freed with the player's combatant | June |
| Fight start | No opening cooldown: a socket is ready as the fight opens | June |
| While casting | A consumable can be used while a technique casts. It neither waits for the cast nor stops it | June |
| None left | The socket keeps its consumable: the icon all in the locked veil (the sweep at step 0) and a count seal reading `0`. A press is refused | June (dim + `x0`), in the lacquer palette (no alpha) |
| Who | The player only. An enemy's manager stays empty | June |
| On the map | The row previews the hotbar: icons, counts and tan keys, and it takes no press. Hovering a socket shows its tooltip, as hovering a technique does | Claude, following the dock's technique preview |
| Equipping during a run | No: the inventory opens only from the zone view. The fight takes the hotbar as it is at its start | June |
| Tooltip | The dock's own tooltip (the `board9` board). It shows the name, `Instant · Cooldown 10 s` (`Instant` with no cooldown), one line per effect (`EffectData.describe()`, `+20 Madra`), a divider and the description | Claude (June reused `ItemDescriptionPanel`, which has the old look) |
| A refused press | Pressing a socket that is recharging or has none left shakes it softly (`MapGlyph.SOFT_SHAKE_KEYFRAMES`), as a refused technique does. There is no log line, because the sweep and the seal already say why. An empty socket does nothing | Claude, following the technique slot |
| Ready again | One brass flash, as for a technique. A socket with none left does not flash | Claude, following the technique slot |
| The count | A vermilion count seal hanging off the socket's bottom right corner, where the inventory's hotbar puts its stack count. It grows leftward to fit the number, so a count is never cut off. The first capture had the seal at the top right, as on the cabinet's buff sockets, but there it crowded the key cap and ran into the seconds | Claude (style guide rule 14) |
| Log | No line when a consumable is used. Techniques log none either; the cabinet's orbs show the gain | Claude |

## Layout (1920x1080)

| Piece | Rect (x, y, w, h) | Notes |
|---|---|---|
| Technique dock | 722, 856, 476, 200 | Was 722, 920, 476, 136. The bottom edge stays on y 1056. Board `lacquer_tdock_consumables_ai.png` (476x200, with a 4 px shadow baked in: 480x204) |
| Consumable sockets | Dock-local x 46, 158, 270, 382; y 18; 48x48 | Centred on the technique slots' centres (70, 182, 294, 406). On screen: 768, 880, 992 and 1104, at y 874 |
| · Icon | Socket +8, +8; 32x32 | The item's 64 px icon at 32 (style guide §9: on the grid at 32 or 64), with the cooldown sweep |
| · Key cap | Socket −6, −6; 22x22 | `lacquer_keycap_ai.png`. The key is read from the input map, in `LabelLacquerHotkey` |
| · Count seal | Right edge at socket +52, top at +30 (4 px past the socket's right edge, 6 px below its bottom); 24x24 at least | `lacquer_seal_count9_ai.png` on a `NinePatchRect` (margins 6 left and right). Count in `LabelLacquerSeal` at 15 px, as on the other count seals. Width is max(24, the text's width + 8, rounded up to even) |
| · Seconds | Centred on the icon | `LabelLacquerCooldown` at 15 px (a cooldown timer's direct size override, UI_STYLING's rule of thumb): the variant's 22 px filled the 32 px icon and ran into the seal. Whole seconds rounded up, as on a technique |
| Technique slots | Dock-local x 30, 142, 254, 366; y 82 (was 18) | Key caps at y 76; cost lines at +90, as before |
| Cast tray | Dock-local 0, −52 (screen 722, 804, 476x44) | Unchanged relative to the dock. It still grows upward, now from y 848 |
| Tooltip | Bottom at y 848 (was 912), or 8 px over the cast tray's top while the tray shows (y 796 for its 44 px; was 860) | Left 8 px left of the hovered socket's, as for a technique |

Every position and size is even. The consumable sockets' bottom (dock-local y 66) clears the technique key caps (y 76) by 10 px. A count seal reaches y 72, but at x 74 to 98 (for the first socket), between two technique key caps.

## Architecture

The runtime mirrors the ability system: `CombatAbilityManager` and its `CombatAbilityInstance`s become `CombatConsumableManager` and its `CombatConsumableInstance`s. That pattern was June's, and the dock already binds to it.

```
CombatantNode (per fight, freed when the fight ends)
├── CombatAbilityManager → CombatAbilityInstance x n
└── CombatConsumableManager            new: %CombatConsumableManager in combatant_node.tscn
    └── CombatConsumableInstance x n   new: one per filled hotbar slot, player only

TechniqueDock (scenes/ui/combat/technique_dock/)
├── Board                              lacquer_tdock_consumables_ai.png
├── ConsumableSlot1..4                 new scene: scenes/ui/combat/technique_dock/consumable_slot/
├── Slot1..4                           TechniqueSlot, moved down 64 px
├── CastTray
└── TechniqueTooltip                   gains show_for_consumable()
```

| Piece | Owns | Does |
|---|---|---|
| `CombatConsumableInstance` | Its consumable, its hotbar slot index, a one-shot cooldown `Timer`, a use count | `use()` fires the consumable through `InventoryManager.use_consumable()` (its effects, then one off the stack) and starts the cooldown when `cooldown_seconds` > 0. It refuses while recharging or when none are left. It emits `cooldown_started`, `cooldown_updated` every frame while recharging, and `cooldown_ready` |
| `CombatConsumableManager` | The instances, in slot order | Builds one instance per filled hotbar slot at `setup()`, for the player only. `can_use_consumable_instance()` checks that the instance is its own, ready, and that at least one is left. `use_consumable_instance()` checks the same, uses the instance and emits `consumable_used`. It never looks at the ability manager's casting |
| `InventoryManager.get_consumable_count()` | — | How many of a consumable the player holds (0 for none or null) |
| `ConsumableSlot` | Socket, icon with the sweep, seconds, key cap, count seal, hover frame, ready flash | Three states, as a technique slot: EMPTY (socket and key cap), PREVIEW (on the map: icon, seal, tan key), ACTIVE (in a fight: cream key, the sweep, the flash). It reads its count from `InventoryManager`. When a press is refused, the socket shakes while the key cap and the seal stay put |
| `TechniqueDock` | The four consumable sockets beside the four technique slots | `show_loadout()` previews the hotbar too. `bind()` takes the consumable manager as a third argument. `consumable_slot_1..4` and clicks press a socket in a fight. An accepted press emits `consumable_selected`; a refused one shakes. On `InventoryManager.inventory_changed` the counts refresh, and on the map the preview is read again |
| `AdventureCombat.on_player_consumable_selected()` | — | Uses the instance through the player's consumable manager. A consumable needs no target |
| `AdventureView` | — | At a fight's start it binds the dock with the player's consumable manager and connects `consumable_selected`. `_release_fight_boards()` disconnects it |

**Using one.** The player presses 1. `TechniqueDock` asks `CombatConsumableManager.can_use_consumable_instance()`. If the answer is no (recharging, none left), the socket shakes and nothing else happens. If yes, `consumable_selected(instance)` goes to `AdventureCombat.on_player_consumable_selected()`, which calls `use_consumable_instance()`. That fires the consumable: the effects apply to `PlayerManager.vitals_manager`, which is the player's combat vitals, so the cabinet's orbs move. The stack loses one and `inventory_changed` fires, so the seal counts down. Then `cooldown_started` starts the socket's sweep, `cooldown_updated` steps it, and `cooldown_ready` flashes it once.

**The sweep shader** (`lacquer_cooldown_sweep.gdshader`) gains `uniform float icon_size = 64.0`, the icon rect's side, which sets the sweep's centre. It is set to 32 on the consumable socket's material in the scene and never by a script. The technique slots keep the default.

## Art

New `_ai` files. They are drawn by the adventure kit's generator (`docs/superpowers/mockups/adventure-view-lacquer/gen/kit_adventure.py`, `consumable_pieces()`) and imported by `import_adventure_kit.py`:

| File | What | Shadow |
|---|---|---|
| `assets/ui/lacquer/lacquer_slot_consumable_ai.png` | The technique slot's carved socket with its raised lip, at 24 art px (48x48) | 2 px `#150909` (50x50) |
| `assets/ui/lacquer/lacquer_tdock_consumables_ai.png` | The plain dock board at 238x100 art px (476x200), with its own grain and gloss | 4 px `#050707` (480x204) |
| `assets/ui/lacquer/lacquer_seal_count9_ai.png` | The count seal (12x12 art px) with its worn bites kept to the outer three columns, so its middle stretches | None, like the count seal |

`lacquer_tdock_ai.png` leaves `assets/` because nothing uses it any more. The mock keeps its own copy, since its page still draws the old dock.

## Tests

- **Unit:**
  - `CombatConsumableInstance`: ready at start; `use()` takes one off and starts the cooldown; it refuses while recharging and with none left; `cooldown_ready` fires.
  - `CombatConsumableManager`: one instance per filled slot, player only; the gate; it ignores casting.
  - `get_consumable_count()`.
- **Dock:**
  - the preview (icons, counts, tan keys, empty sockets) and the bind (cream keys, instances by slot index);
  - 1 to 4 and clicks emit `consumable_selected` in a fight, and nothing on the map;
  - a refused press shakes and emits nothing;
  - the sweep and seconds, the ready flash, and none left (step 0, seal `0`);
  - the seal grows for long counts, on even widths;
  - the tooltip for a consumable, and over the cast tray;
  - the layout above.
- **Frame:** in a real fight, 1 uses the hotbar's first consumable (the count drops, Madra rises), and the fight's end lets the dock go.
- **Geometry:** the dock's tests, the frame test and the layout test move with the dock to (722, 856).

## Docs to update

- `docs/combat/COMBAT.md`: the consumable manager and the use flow. Drop the "only on the unmerged branch" item.
- `docs/adventuring/ADVENTURING.md`: the dock's consumable row.
- `docs/inventory/INVENTORY.md`: the combat hook. The "can't be used" item becomes "no drop source".
- `docs/infrastructure/MAIN_VIEW.md`: the keybindings.
- `docs/STYLE_GUIDE.md`: the dock's rect, the new pieces, and the sweep's `icon_size`.
- `docs/planned/SCRIPTING.md`: the hotbar line.
- `docs/superpowers/README.md`: the rows.

## Risks and handoffs

- **The adventure design's PR 2 places the fighters' feet on y 840, with the player centred on x 700.** While the player casts, the cast tray now stands at y 804 to 848 and from x 722. It would cover the lower right of the player's fighter there. PR 2 should move the player left or account for the tray. Today's fighters stand on y 790, clear of it.
- **Icons at 32.** Crude Scale's 64 px icon shows at half size. Barely Coalesced Scale has no icon, so its socket shows the seal and the key but no picture until it gets one.
- **Counts of 1,000 or more.** The seal grows over the icon. Such counts are far from today's prices.
