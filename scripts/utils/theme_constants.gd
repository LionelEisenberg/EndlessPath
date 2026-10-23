class_name ThemeConstants

## ThemeConstants
## Centralized color palette and font size scale for the EndlessPath UI.
## Use these constants in code when you need to reference theme values programmatically.
## The Godot theme (.tres) should use these same values — this is the single source of truth.

#-----------------------------------------------------------------------------
# COLOR PALETTE
#-----------------------------------------------------------------------------

## Backgrounds — flat panels
const BG_DARK: Color = Color("#2A1A12")
const BG_MEDIUM: Color = Color("#3D2E22")
const BG_LIGHT: Color = Color("#564332")

## Backgrounds — texture panel tints
const TINT_PARCHMENT: Color = Color(0.92, 0.82, 0.68, 1.0)
const TINT_DARK_PANEL: Color = Color(0.85, 0.72, 0.55, 1.0)

## Borders
const BORDER_PRIMARY: Color = Color("#C4884A")
const BORDER_SUBTLE: Color = Color("#6B4A30")

## Accents
const ACCENT_GOLD: Color = Color("#D4A84A")
const ACCENT_GREEN: Color = Color("#7DCE82")
const ACCENT_RED: Color = Color("#E06060")

## Text
const TEXT_LIGHT: Color = Color("#F0E8D8")
const TEXT_MUTED: Color = Color("#A89070")
const TEXT_DARK: Color = Color("#1A1208")

## Interactive states
const HOVER_BG: Color = Color("#4A3828")
const PRESSED_BG: Color = Color("#1E1408")
const DISABLED_BG: Color = Color("#2A2420")
const DISABLED_TEXT: Color = Color("#5A4A3A")

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

#-----------------------------------------------------------------------------
# FONT SIZES
#-----------------------------------------------------------------------------

const FONT_TITLE: int = 42
const FONT_HEADING: int = 28
const FONT_BODY: int = 20
const FONT_LABEL: int = 16
const FONT_CAPTION: int = 12

#-----------------------------------------------------------------------------
# SPACING
#-----------------------------------------------------------------------------

const BORDER_WIDTH_THIN: int = 2
const BORDER_WIDTH_NORMAL: int = 4
const BORDER_WIDTH_THICK: int = 8

const CORNER_RADIUS_SMALL: int = 4
const CORNER_RADIUS_NORMAL: int = 8
const CORNER_RADIUS_LARGE: int = 12

const CONTENT_MARGIN_SMALL: int = 8
const CONTENT_MARGIN_NORMAL: int = 16
const CONTENT_MARGIN_LARGE: int = 24
