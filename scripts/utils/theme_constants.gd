class_name ThemeConstants

## ThemeConstants
## Colours for code that must set them at runtime. The themes
## (assets/themes/pixel_theme.tres, assets/themes/lacquer/lacquer_theme.tres)
## are the source of truth; keep these values in step with them.

#-----------------------------------------------------------------------------
# COLOR PALETTE
#-----------------------------------------------------------------------------

## Accents
const ACCENT_GOLD: Color = Color("#D4A84A")

#-----------------------------------------------------------------------------
# LACQUER PALETTE (zone view; lacquer kit §2)
#-----------------------------------------------------------------------------
# For colours set from code in lacquer_theme.tres panels. The theme's Label
# variants already carry these; use the variants first (docs/UI_STYLING.md).

## Outlines, carved lines, text on brass, the shadow of small pieces
const LACQUER_INK: Color = Color("#150909")
## Lit rims of raised lacquer, and the lip under a carved groove
const LACQUER_RIM: Color = Color("#692F2F")
## Straps, caps, painted titles, reward text
const LACQUER_BRASS: Color = Color("#D4A84A")
## Main text
const LACQUER_CREAM: Color = Color("#F0E8D8")
## Labels and secondary text
const LACQUER_TAN: Color = Color("#A89070")
## The two oldest log lines
const LACQUER_DIM: Color = Color("#94806A")
## The top edge of lit Madra
const LACQUER_MADRA_HI: Color = Color("#E8F6FD")
## Madra text (floaters, log level-ups)
const LACQUER_MADRA: Color = Color("#BBD5E7")
## The lower edge of lit Madra
const LACQUER_MADRA_MID: Color = Color("#849BE4")
## Seals (NEW, LOCKED, the count)
const LACQUER_VERMILION: Color = Color("#A83C30")
