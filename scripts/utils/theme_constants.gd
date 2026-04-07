class_name ThemeConstants

## ThemeConstants
## Centralized color palette and font size scale for the EndlessPath UI.
## Use these constants in code when you need to reference theme values programmatically.
## The Godot theme (.tres) should use these same values — this is the single source of truth.

#-----------------------------------------------------------------------------
# COLOR PALETTE
#-----------------------------------------------------------------------------

## Backgrounds
const BG_DARK: Color = Color("#2A1A12")
const BG_MEDIUM: Color = Color("#3D2E22")
const BG_LIGHT: Color = Color("#564332")

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
