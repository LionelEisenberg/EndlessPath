# Merchant v1 (Foundation Beat 4) — Design

> **Status:** decisions settled with the user on 2026-10-19 (godot-grill); design approved (MerchantManager, per-merchant ledgers, zone themes) and implemented the same day. Built as designed except: row padding comes from the `MerchantRow` stylebox (no `RowMargin` node), `MerchantAtmosphere` masks itself instead of `ShopPanel` clipping its children (so hover tooltips aren't cut off), and `MerchantButton` styleboxes have no glow shadow (Godot draws it under translucent boxes). After the playtest, the panel is 95% opaque, because the log and quest windows under the shop read through a translucent one. The shop also hides those windows while it is open, because it cut their text off. The atmosphere fills the panel inside its border through a rounded mask (`clip_children`), with the panel's padding moved into a `ContentMargin` container.
>
> **Scope:** the Traveling Merchant's shop: a gold sink that makes the six unobtainable gear pieces and the Crude Scale buyable. Selling, rotation and merchant dialogue are out of scope.

## Goal

Today every fight pays gold and nothing spends it, and 6 of the 7 equipment items have no source. The `spirit_valley_merchant` action (unlocked by `merchant_discovered` at the end of Beat 3b) only logs "Shop coming soon". Merchant v1 turns that action into a shop, so the loop "die, get stronger, go further" has a "get stronger" step that runs on adventure gold.

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Stock | Makeshift Dagger, Iron Shortsword, Cultivator's Cowl, Reinforced Robes, Scripted Bark, Leeching Ring, Crude Scale | The six gear pieces have no other source on `main`; Crude Scale is the consumable with an icon | Loot drops (Beat 5) or Copper content add sources |
| Prices | The starting values below, stored in each item's `base_value` | [ITEMS.md](../../inventory/ITEMS.md) already names `cost` → `base_value` as the merchant price driver, so each item keeps one gold value | A second merchant needs a different price for the same item |
| Rotation and limits | Fixed stock. Each merchant keeps its own ledger, so a gear piece can be bought **once per save from that merchant**: it stays sold out even if the player trashes it. Crude Scale is unlimited | User choice; per-merchant ledgers let two merchants stock the same item with different limits (one Cowl here, three elsewhere) | Players regret trashing bought gear, or rotation gets a larger item pool |
| Selling | Buy-only | Materials are reserved for Elixir Making / Soulsmithing. Foraging yields ~84 materials a minute while idle, so even 1 gold each would out-earn adventuring (~10–15 gold a minute). Gear sell-back needs spare gear, which loot drops will create | Loot drops produce duplicates, or crafting consumes materials |
| Full equipment pages | Block the purchase before any gold is spent. Buy is disabled and the row reads "Equipment full". Consumables are unaffected | Never take gold for an item that can't be placed | An overflow or mailbox system exists |
| Buy interaction | **Assumed:** one click buys one item, no confirm step | Gear sells out after one copy, so a misclick can't stack duplicates | Misclick complaints in playtests |
| Merchant fiction | **Assumed:** no Dialogic timeline in v1; the shop shows the action name and a one-line greeting | Narrative content after Beat 3b isn't written yet | A narrative pass names the merchant |
| Idle actions during a visit | Opening the shop replaces a running foraging or training action; leaving resumes it (not after a zone change, and never cycling) | Final review: the shop behaves like a menu, and the other menus leave idle actions running | Idle actions run alongside other activities |
| Look | Ethereal shop. Each merchant action picks a zone Theme for its panel, rows, buttons, title glow, mist and motes; text keeps the global type scale | User ask; styling stays in theme resources, one file per zone | A zone needs more than colours and styleboxes, such as its own layout |

## Starting values and test plan

All prices are **starting values**. "Runs" assumes ~45 gold per run (2–3 fights at 15–20 gold; Coalescing Spirit pays 0). Players reach the merchant after at least 2 runs, so they arrive with roughly 60–250 gold.

| Item | Slot | Price | ≈ Runs | Effect today |
|---|---|---|---|---|
| Crude Scale | Consumable | 10 | 0.2 | +20 combat Madra, once in-combat consumables merge |
| Cultivator's Cowl | Head | 40 | ~1 | Almost none: +1 SPIRIT; WILLPOWER has no combat effect |
| Makeshift Dagger | Main hand | 60 | ~1.5 | Basic Strike 25 → 29 |
| Scripted Bark | Off hand | 75 | ~2 | +20 max HP |
| Leeching Ring | Accessory | 120 | ~3 | +20 adventure Madra capacity; CONTROL has no combat effect |
| Iron Shortsword | Main hand | 150 | ~3–4 | Basic Strike 25 → 31 |
| Reinforced Robes | Armor | 180 | ~4 | +40 max HP, ~2% less physical damage |

Basic Strike is `10 + STR × 1.0 + AGI × 0.5`. Max HP is `BODY × 10`; gear raises it only after the max-vitals fix from the parallel combat session lands. Buying every gear piece costs 625 gold, about 14 runs.

The three cheap pieces are deliberately below Q-8's "3–5 runs per piece", so the first visit has a purchase. The Ring, Shortsword and Robes meet Q-8.

**Test plan** (feeds [FOUNDATION_PLAYTHROUGH.md Q-8](../../progression/FOUNDATION_PLAYTHROUGH.md#q-8-merchant-pricing-vs-adventure-gold)):

1. In at least 5 playthroughs, record the gold banked at the first merchant visit and what was bought.
2. Record the number of runs between buying each of the Ring, Shortsword and Robes.
3. **Pass:** the first visit buys at most one cheap piece plus scales, and each of the three main pieces takes 3–5 runs.
4. **Fail:** a main piece is bought on the first visit (raise prices about 25%), or one takes more than 6 runs (lower them about 25%).

## Open / deferred

- Gear sell-back is Merchant v2, once loot drops create spare gear.
- Spirit Fern and Dewdrop Tear still have no use.
- The Cowl's WILLPOWER and the Ring's CONTROL do nothing in combat until the attribute design pass.
- **Assumed:** `InventoryManager.award_items()` logs gear purchases as "Looted 1x …" (Crude Scales as "Obtained 1x …"). The shop shows its own "Bought …" line; the log wording is a follow-up.

## Design

### Approach

**Chosen: a `MerchantManager` autoload owns the purchase rules.** It keeps one ledger per merchant in a new `SaveGameData.merchant_ledgers`, spends gold through `ResourceManager` and awards items through `InventoryManager`. `ActionManager` only opens and closes the shop, through `start_merchant` / `stop_merchant` signals, the same way cycling works. This mirrors `CyclingManager`, `AbilityManager` and `PathManager`, which each own one slice of `SaveGameData`. The view stays dumb, and tests call the manager directly.

Rejected:

- **Purchase logic on `MerchantActionData`** (the `EffectData.process()` style), with counts in `ZoneProgressionData`. It needs fewer files, but a Resource running a three-manager transaction is hard to test, and per-zone counts don't match "once per save".
- **`InventoryManager.buy_item()`.** It couples the inventory to gold and stock rules, and the parallel consumables session is editing `InventoryManager`.

### Data model

| Class | File | Fields |
|---|---|---|
| `MerchantStockEntry` (Resource) | `scripts/resource_definitions/merchant/merchant_stock_entry.gd` | `entry_id: String` (ledger key, unique within its stock), `item: ItemDefinitionData`, `stock_limit: int` (0 = unlimited, N = copies per save from this merchant), `get_price() -> int` (rounded `item.base_value`) |
| `MerchantStock` (Resource) | `scripts/resource_definitions/merchant/merchant_stock.gd` | `merchant_id: String` (ledger key, unique across merchants), `entries: Array[MerchantStockEntry]` (mirrors `LootTable` / `LootTableEntry`) |
| `MerchantActionData` (`ZoneActionData`) | `scripts/resource_definitions/zones/zone_action_data/merchant_action_data/merchant_action_data.gd` | `stock: MerchantStock`, `greeting: String`, `shop_theme: Theme` (the zone's merchant look; null keeps the scene default); `_init()` sets `action_type = MERCHANT` |
| `SaveGameData.merchant_ledgers` | `singletons/persistence_manager/save_game_data.gd` | `Dictionary[String, MerchantLedgerData]`: `merchant_id` → that merchant's ledger, created on demand by `get_merchant_ledger()` |
| `MerchantLedgerData` (Resource) | `singletons/persistence_manager/merchant_ledger_data.gd` | `merchant_id: String`, `purchase_counts: Dictionary[String, int]` (`entry_id` → copies bought). Compared with the merchant's `MerchantStock` to find what is sold out; mirrors `ZoneProgressionData` |
| `InventoryData.has_free_equipment_slot()` | `singletons/persistence_manager/inventory_data.gd` | `true` while any slot below `equipment_capacity()` is empty |

Content: `resources/merchants/spirit_valley_merchant_stock.tres` (`merchant_id` `spirit_valley_merchant`; 7 entries whose `entry_id` is the item id; gear `stock_limit` 1, Crude Scale 0). `spirit_valley_merchant_action.tres` becomes a `MerchantActionData` that references it. Prices go into the item `.tres` `base_value` and the ITEMS.md `cost` column.

### MerchantManager API

| Member | Behaviour |
|---|---|
| `enum PurchaseResult { OK, INVALID_ENTRY, SOLD_OUT, INSUFFICIENT_GOLD, EQUIPMENT_FULL }` | Checked in that order. `INVALID_ENTRY` also covers an empty `merchant_id` or `entry_id`, and an item whose class doesn't match its `item_type` (which `award_items()` would drop after the gold was spent) |
| `get_purchase_status(stock, entry) -> PurchaseResult` | No side effects; drives each row's state |
| `purchase(stock, entry) -> PurchaseResult` | Checks the status first. On `OK`: `spend_gold(price)`, `award_items(item, 1)`, adds 1 to the entry in that merchant's ledger, emits `item_purchased(stock, entry)` |
| `get_purchase_count(stock, entry) -> int`, `get_remaining_stock(stock, entry) -> int` (-1 = unlimited) | Read the merchant's ledger and compare it with `entry.stock_limit` |
| `signal item_purchased(stock: MerchantStock, entry: MerchantStockEntry)` | Emitted after a successful purchase |

### Scene tree

Mock at 1:1 game scale: [`docs/superpowers/mockups/merchant-shop-mockup.html`](../mockups/merchant-shop-mockup.html) (`#spirit-valley` and `#advancement` frame one zone each).

```
MerchantView (Control, full rect, hidden, z 3)        scenes/merchant/merchant_view.gd (class MerchantView)
│                                                     theme = the merchant's shop_theme (scene default: spirit_valley_merchant_theme.tres)
├── AnimationPlayer (%)                               RESET / open (0.3 s fade-in) / close (0.2 s fade-out)
└── ShopPanel (PanelContainer, MerchantPanel, centred, sized to its content; content margins = border width)
    ├── MerchantAtmosphere (%, Panel, MerchantAtmosphereMask, clip_children, mouse ignored)   fills the panel inside its border; colours from the theme's MerchantAtmosphere type
    │   ├── TopLight (TextureRect, GradientTexture2D)
    │   ├── MistA / MistB / MistC (Sprite2D, mist_sheet.png cells, slow drift)
    │   └── MotesPrimary / MotesSecondary (GPUParticles2D, mote_particle.png)
    └── ContentMargin (MarginContainer, 16 sides / 12 top and bottom)
        └── MainVBox (%, VBoxContainer)
            ├── HeaderMargin (MarginContainer, 8 sides / 4 top): HeaderHBox
            │   ├── TitleBlock: TitleLabel (%, LabelMerchantTitle) · GreetingLabel (%, LabelSubheading)
            │   └── GoldBox: GoldIcon (TextureRect, gold_icon.png) · GoldLabel (%, LabelValueLarge)
            ├── HSeparator (HSeparatorMerchant)
            ├── StockList (%, VBoxContainer)          8 pre-instanced MerchantStockRow scenes; extras hidden
            ├── HSeparator (HSeparatorMerchant)
            └── FooterMargin (MarginContainer, 8 sides / 4 bottom): FooterHBox: StatusLabel (%, LabelGreen) · LeaveButton (%, MerchantButton, "Leave [Esc]")

MerchantStockRow (PanelContainer, MerchantRow)        scenes/merchant/merchant_stock_row/merchant_stock_row.gd
└── RowMargin > RowHBox
    ├── SlotStack: SlotGlow (TextureRect, radial gradient) · ItemSlot (%, ItemDisplaySlot instance)
    ├── InfoVBox: NameLabel (%, LabelBody) · DetailLabel (%, RichTextLabel 16 px: "Main Hand: +5 Strength, +2 Agility")
    ├── BlockReasonLabel (%, LabelRed)                "Need 40 more gold" / "Equipment full"
    ├── SoldOutLabel (%, LabelMuted)                  "Sold out"
    ├── PriceBox (%): GoldIcon · PriceLabel (%, LabelValueMedium)
    └── BuyButton (%, MerchantButton)
```

`MerchantViewState` (`scenes/merchant/merchant_view_state.gd`) joins `MainViewStateMachine` and uses the `GreyBackground` fade, like the Character view. Rows are pre-instanced in the `.tscn`; scripts only set text, visibility, the disabled state, `modulate` from theme colours and the view's `theme`.

### Zone look

Each merchant action picks a zone Theme, so a zone (or one area of it) can give its shop its own look without code. `MerchantActionData.shop_theme: Theme` is set as the MerchantView root's `theme` when the shop opens; null keeps the scene default, Spirit Valley.

| Theme entry | Drives |
|---|---|
| `MerchantPanel` (PanelContainer variant) | Dark tinted panel, 95% opaque so the HUD under it doesn't read through; glowing edge (StyleBoxFlat border and shadow) |
| `MerchantRow` (PanelContainer variant) | Translucent rows with a thin luminous edge |
| `MerchantButton` (Button variant) | Buy and Leave in every state, disabled included |
| `LabelMerchantTitle` (`LabelTitle` variant) | `LabelTitle`'s gold title with a zone-coloured glow (shadow outline). It repeats `LabelTitle`'s size, because `pixel_theme.tres`'s default font size answers first |
| `HSeparatorMerchant` (HSeparator variant) | Zone-coloured dividers |
| `MerchantAtmosphere` colours: `mist`, `mote_primary`, `mote_secondary`, `light`, `slot_glow` | Mist, motes, top light and the glow behind item icons; read by `MerchantAtmosphere` and `MerchantStockRow` on `NOTIFICATION_THEME_CHANGED` |

Everything else (the Label type scale, red and green states, gold prices) falls back to `pixel_theme.tres`, so text reads the same in every zone. Spirit Valley's theme is `assets/themes/merchant/spirit_valley_merchant_theme.tres`; a new zone adds one Theme file with these entries.

Rejected: a colour resource applied by script with `add_theme_*_override()`, which breaks the project rule that styling lives in theme resources; and one shop scene per zone, which would duplicate the layout.

### Signal map

| Signal | Emitted by | Consumed by | Payload |
|---|---|---|---|
| `ActionManager.start_merchant` | `_execute_merchant_action()` | `MerchantViewState`: `merchant_view.setup()`, then `push_state()` unless it is already on the stack | `MerchantActionData` |
| `ActionManager.stop_merchant` | `_stop_merchant_action()` | `MerchantViewState`: `hide_with_panel()`, or an instant hide and `remove_state()` when another view sits above the shop | — |
| `GreyBackground.panel_hidden` | End of the fade-out | `MerchantViewState`: `MainView.remove_state(self)` (removes only itself) | — |
| `MerchantView.close_requested` | Leave button | `MerchantViewState`: `ActionManager.stop_action()` | — |
| `MerchantStockRow.buy_pressed` | Buy button | `MerchantView`: `MerchantManager.purchase()` | `MerchantStockEntry` |
| `MerchantManager.item_purchased` | A successful `purchase()` | None yet (hook for quests and analytics) | `MerchantStock`, `MerchantStockEntry` |
| `ResourceManager.gold_changed`, `InventoryManager.inventory_changed` | Purchases, dev panel | `MerchantView`: gold label and row states | — |

Escape (`ui_cancel`) in `MerchantViewState.handle_input()` also calls `ActionManager.stop_action()`.

### Data flow

```
Open:  card click → ActionManager.select_action(merchant)
         → _execute_merchant_action → start_merchant(action)       # action stays current
         → MerchantViewState: merchant_view.setup(action); push_state → show_with_panel (fade in)

Buy:   BuyButton → MerchantStockRow.buy_pressed(entry) → MerchantView → MerchantManager.purchase(stock, entry)
         status: INVALID_ENTRY → SOLD_OUT (ledger count ≥ limit) → INSUFFICIENT_GOLD → EQUIPMENT_FULL → OK
         OK: ResourceManager.spend_gold(price)        → gold_changed, "Spent N Gold"
             InventoryManager.award_items(item, 1)    → inventory_changed
             merchant_ledgers[merchant_id].purchase_counts[entry_id] += 1
             item_purchased(stock, entry)
         → MerchantView: "Bought <item>." and every row refreshes
       SaveTimer writes save.tres within 5 s; gold, inventory and ledgers are one resource, so they save together

Close: Leave / Escape → ActionManager.stop_action()
         → completion count +1 → _stop_merchant_action → stop_merchant, success_effects
         → MerchantViewState: hide_with_panel → panel_hidden → remove_state(self)
```

### Tests

- `tests/unit/test_merchant_manager.gd`: spending; exact gold; insufficient gold changes nothing; full equipment blocks before spending; consumables still buyable with full equipment; sold out after one copy, and still sold out after the item is trashed; unlimited entries; limits kept per merchant (the same item at limit 1 in one stock and 3 in another); invalid entries; `item_purchased` signal; save round-trip of the ledgers.
- `tests/unit/test_spirit_valley_merchant_stock.gd`: the real `.tres` wiring (seven entries, a merchant id, unique entry ids, limits, prices above zero, the action is a `MerchantActionData`).
- `tests/integration/test_merchant_shop_flow.gd`: the `ActionManager` route stays open until `stop_action()`; `MerchantView` binds the real stock and disables Buy when gold is short.
- Added by the final-review follow-ups: `tests/unit/test_merchant_view_state.gd` (the overlay pushes once and removes only itself, on a `MainView` that never enters the tree) and `tests/unit/test_spirit_valley_merchant_theme.gd` (every variant and `MerchantAtmosphere` colour). `test_merchant_shop_flow.gd` also covers a merchant with no stock, entries without an item, the "Equipment full" row, a closed shop skipping refreshes, and the title's `LabelTitle` inheritance.
- Added by the playtest fixes: `test_spirit_valley_merchant_theme.gd` checks the panel's opacity, and `test_merchant_shop_flow.gd` checks the mock's header and footer padding and that the panel fits its rows. A second round checks that the atmosphere fills the panel inside its border with a mask matching its corners (`test_merchant_shop_flow.gd`, `test_spirit_valley_merchant_theme.gd`), and that `MerchantViewState` hides and restores the log and quest windows (`test_merchant_view_state.gd`).
