class_name LacquerText

## Text helpers for the lacquer zone view (lacquer kit §3).
## Rates read "+1.5" and "+2". BM Euljiro's decimal point sits low and reads
## as a comma at 15-17 px, so a RichTextLabel sets it in Yatra One instead.

## The decimal point in Yatra One. Yatra's ascent and descent run up to 3 px
## past BM Euljiro's at 13-18 px, so plain Yatra would grow the line (24 px
## instead of 18 at 15 px) and drop its baseline 3 px. The font tag trims
## both by 3 px, like the mock's `.pt { line-height: 0 }`, so a decimal line
## is exactly as tall as the same line without the dot. The trim is set in
## the tag: in Godot 4.7.2 a [font=...] tag that loads a FontVariation .tres
## drops that file's spacing_top and spacing_bottom.
const DECIMAL_POINT_BBCODE: String = "[font name=res://assets/fonts/YatraOne-Regular.ttf top_spacing=-3 bottom_spacing=-3].[/font]"

## A full stop with a digit on each side: the decimal point of a number.
const _DECIMAL_POINT_PATTERN: String = r"(?<=\d)\.(?=\d)"

static var _decimal_point_regex: RegEx = null

#-----------------------------------------------------------------------------
# PUBLIC API
#-----------------------------------------------------------------------------

## Returns a signed rate with at most two decimals and no trailing zeros:
## 1.5 → "+1.5", 2.0 → "+2", 0.5 → "+0.5", -1.5 → "-1.5".
static func rate(value: float) -> String:
	var rounded: float = snappedf(value, 0.01)
	var sign_text: String = "+" if rounded >= 0.0 else ""
	if is_equal_approx(rounded, roundf(rounded)):
		return sign_text + str(int(roundf(rounded)))
	return sign_text + String.num(rounded, 2)

## Returns BBCode for a RichTextLabel from plain text: each "[" escaped as
## "[lb]", so a name with a bracket shows as written instead of opening a tag,
## and each decimal point (a "." between two digits) set in Yatra One, trimmed
## so the line keeps its height at 13-18 px. Other full stops are left alone.
static func decimal_bbcode(text: String) -> String:
	if _decimal_point_regex == null:
		_decimal_point_regex = RegEx.create_from_string(_DECIMAL_POINT_PATTERN)
	return _decimal_point_regex.sub(text.replace("[", "[lb]"), DECIMAL_POINT_BBCODE, true)
