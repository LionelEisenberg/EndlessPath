# UI Styling

All UI text in the game flows through a **Label theme variant type-scale** defined in `assets/themes/pixel_theme.tres`. Use variants instead of inline size overrides so the type hierarchy stays consistent and global tuning is possible in one place.

## Rule of thumb

1. **Find the variant whose size matches** what you need → set `theme_type_variation = &"LabelX"` on the node
2. **If the color is unique** to this context (teal accent, HUD white, resource-specific gold), add `theme_override_colors/font_color` on top of the variant
3. **If no variant has the size you need**, use the closest variant + a `theme_override_font_sizes/font_size` override — this keeps the variant's color/outline/shadow but lets you tweak size. Prefer this over pure direct overrides.
4. **Only fall back to fully direct overrides** for one-off HUD labels (floating damage, cooldown timers, buff stacks) where no variant makes semantic sense, or for `RichTextLabel` nodes which can't consume Label variants

Never write `theme_override_font_sizes/font_size = X` on a bare Label without first checking if a variant matches. If you find yourself adding the same `{size + color}` combo across 3+ scenes, add a new variant to the theme instead.

## General-purpose Label variants

These are size-based and drop into any scene. Default color is beige (inherited from the base `Label` theme type) unless noted:

| Variant | Size | Color | Use for |
|---------|------|-------|---------|
| `LabelTitle` | 50px | Gold + shadow | Main panel titles (path tree, abilities) |
| `LabelTitleSmall` | 40px | Gold | Zone titles, secondary headers |
| `LabelHeading` | 36px | Gold | Subsection headings |
| `LabelValueLarge` | 34px | Gold | Big value numbers |
| `LabelBodyLarge` | 28px | Beige | Large body text (cycling, adventure, inkbrush) |
| `LabelMuted` | 26px | Tan | Secondary/muted text |
| `LabelSubheading` | 24px | Tan | Subtitle text under titles |
| `LabelBody` | 22px | Beige | Standard body text |
| `LabelValueMedium` | 22px | Gold | Medium gold values |
| `LabelGreen` | 20px | Green | Positive/buff indicators |
| `LabelRed` | 20px | Red | Negative/debuff indicators |
| `LabelBodySmall` | 16px | Beige | Small body text, menu buttons, HUD text |
| `LabelSmall` | 14px | Beige | Tiny labels, material counts |

## Scoped variants (tight contexts, don't reuse broadly)

- **Adventure end card scroll:** `LabelEndCardTitle` 96px gold+shadow / `LabelEndCardSection` 30px / `LabelEndCardDefeatReason` 26px gold / `LabelEndCardStatValue` 22px / `LabelEndCardStatName` 18px / `LabelEndCardMuted` 12px
- **Ability card text** (all with 2px outline for legibility — don't substitute general variants): `LabelAbilityTitle` 34px / `LabelAbilityBody` 18px / `LabelAbilityMuted` 16px
- **Item description panel** (light background): `LabelDescItemName` 32px black / `LabelDescItemType` 20px gray
- **Ability stats display:** `LabelSeparatorDot` 26px orange — Dot separators

## RichTextLabel variants

RichTextLabels **cannot** use Label-based variants (different base type). Only one RTL variant exists:
- `RichTextLabelDark` — Dark brown default color for light backgrounds (item description body)

For RTLs that need a custom size, set `theme_override_font_sizes/normal_font_size` directly. Match one of the Label variant sizes for visual consistency (e.g. use 22 if body text elsewhere uses `LabelBody`).

## HSeparator variants

- `HSeparatorTooltip` — 1px thin separator with **no inset**, muted brown. Use for tooltip and ability card detail dividers.
- `HSeparatorItemDesc` — Thicker separator for item description panel top
- `HSeparatorItemDescThin` — Thin separator for item description panel bottom

## Pattern examples

**Good — size matches a variant, color is unique to this context:**
```
theme_type_variation = &"LabelBody"
theme_override_colors/font_color = Color(0.55, 0.75, 0.72, 1)  # teal Madra accent
```

**Good — size matches exactly, default variant color works:**
```
theme_type_variation = &"LabelSubheading"
```

**Good — close match, use variant for color inheritance + size override:**
```
theme_type_variation = &"LabelHeading"   # inherits gold
theme_override_font_sizes/font_size = 18  # but at 18px
```

**Good — HUD label keeps white+outline overrides on top of a variant:**
```
theme_type_variation = &"LabelBodySmall"
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 3
```

**Avoid — inline size+color with no variant:**
```
theme_override_colors/font_color = Color(0.941, 0.91, 0.847, 1)  # default beige
theme_override_font_sizes/font_size = 22  # when LabelBody already exists at 22px beige
```

## Label testing scene

Visual reference for every variant: `tests/label_tests/label_testing_scene.tscn`. Open it in the editor to compare sizes side-by-side with sample text on dark + light backgrounds. Update this scene's `LABEL_VARIANTS` array when adding or renaming variants.

## Source of truth

`assets/themes/pixel_theme.tres` is the source of truth for all variant sizes and colors. When you change a variant, update this doc and the testing scene to match.
