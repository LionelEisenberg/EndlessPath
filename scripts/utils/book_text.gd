class_name BookText

## Text helpers for the inventory book's pressed pages: stack counts, seconds,
## consumable effect lines, equipment slot captions and gear bonus lines.
## Everything returns plain text except color_madra() and effect_line(), which
## return BBCode for a RichTextLabel.

## Marks a stack count: "×7". The multiplication sign, not the letter x.
const _COUNT_MARK: String = "×"

## Between the parts of an effect line: "+20 Madra · 10 s cooldown".
const _EFFECT_SEPARATOR: String = " · "

static var _madra_amount_regex: RegEx = null

#-----------------------------------------------------------------------------
# NUMBERS
#-----------------------------------------------------------------------------

## Returns a stack count as a tag or a row shows it: 7 → "×7". The digits are
## not grouped, so the tags print the full number ("×4600").
static func count(amount: int) -> String:
	return _COUNT_MARK + str(amount)

## Returns a number with its digits grouped by commas, as the details print it:
## 4600 → "4,600", 1234567 → "1,234,567".
static func thousands(amount: int) -> String:
	var grouped: String = str(absi(amount))
	for comma_at: int in range(grouped.length() - 3, 0, -3):
		grouped = grouped.insert(comma_at, ",")
	return ("-" if amount < 0 else "") + grouped

## Returns a duration with whole numbers kept whole: 10.0 → "10 s", 2.5 → "2.5 s".
## Plain text: a RichTextLabel passes it through LacquerText.decimal_bbcode()
## to set the decimal point.
static func seconds(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d s" % roundi(value)
	return "%.1f s" % value

#-----------------------------------------------------------------------------
# EFFECT LINES
#-----------------------------------------------------------------------------

## Returns BBCode with each Madra amount ("+20 Madra", "-7.5 Madra") in the
## book's Madra ink. The amount may be plain text, or already set through
## LacquerText.decimal_bbcode(), whose decimal point is a BBCode tag.
static func color_madra(text: String) -> String:
	if _madra_amount_regex == null:
		_madra_amount_regex = RegEx.create_from_string(_madra_amount_pattern())
	var open_tag: String = "[color=#%s]" % ThemeConstants.BOOK_MADRA_INK.to_html(false)
	return _madra_amount_regex.sub(text, open_tag + "$0[/color]", true)

## Returns the BBCode line under a consumable's name: its effects and its
## cooldown, set apart by middle dots ("+20 Madra · 10 s cooldown"), with the
## Madra amounts in Madra ink and the decimal points set in Yatra One.
static func effect_line(def: ConsumableDefinitionData) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for effect: EffectData in def.effects:
		parts.append(effect.describe())
	if def.cooldown_seconds > 0.0:
		parts.append(seconds(def.cooldown_seconds) + " cooldown")
	# The colour tags go on last: decimal_bbcode() escapes every "[" it is given.
	return color_madra(LacquerText.decimal_bbcode(_EFFECT_SEPARATOR.join(parts)))

## Returns the caption over an effect's line on the details page: "RESTORES"
## for an effect that changes vitals, "EFFECT" for any other.
static func effect_label(effect: EffectData) -> String:
	if effect is ChangeVitalsEffectData:
		return "RESTORES"
	return "EFFECT"

#-----------------------------------------------------------------------------
# EQUIPMENT
#-----------------------------------------------------------------------------

## Returns the caption of an equipment slot: "MAIN HAND", "OFF HAND", "HEAD",
## "BODY" (the armour slot) or "ACCESSORY".
static func slot_name(slot: EquipmentDefinitionData.EquipmentSlot) -> String:
	match slot:
		EquipmentDefinitionData.EquipmentSlot.MAIN_HAND:
			return "MAIN HAND"
		EquipmentDefinitionData.EquipmentSlot.OFF_HAND:
			return "OFF HAND"
		EquipmentDefinitionData.EquipmentSlot.HEAD:
			return "HEAD"
		EquipmentDefinitionData.EquipmentSlot.ARMOR:
			return "BODY"
		EquipmentDefinitionData.EquipmentSlot.ACCESSORY:
			return "ACCESSORY"
	Log.error("BookText: Unknown equipment slot %s" % slot)
	return ""

## Returns one line for each bonus the gear gives: each stat it has a percent
## above 0 for, in CharacterAttributesData.AttributeType order, as "+10%
## Strength (+1)", then "Armor 6" and "Ward 4", each when above 0. The number
## in parentheses is what the stat gains at its value in `trained_values`
## (AttributeType to float; a stat it lacks counts as STAT_BASELINE, its Lv 1
## value). It comes from get_stat_bonus(), as the totals' bonus does, so card
## and total can't disagree. The space before "(" is a no-break space, so a
## wrapping row never parts the figure from its stat.
static func gear_bonus_lines(def: EquipmentDefinitionData, trained_values: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for stat: CharacterAttributesData.AttributeType in CharacterAttributesData.AttributeType.values():
		var percent: float = def.stat_percent_bonuses.get(CharacterAttributesData.stat_key(stat), 0.0)
		if percent <= 0.0:
			continue
		var bonus: float = def.get_stat_bonus(stat, trained_values.get(stat, CharacterAttributesData.STAT_BASELINE))
		lines.append("%s%% %s\u00a0(%s)" % [_signed(percent * 100.0), CharacterManager.get_attribute_display_name(stat), _signed(bonus)])
	if def.armor > 0.0:
		lines.append("Armor %s" % _plain(def.armor))
	if def.ward > 0.0:
		lines.append("Ward %s" % _plain(def.ward))
	return lines

#-----------------------------------------------------------------------------
# PRIVATE
#-----------------------------------------------------------------------------

## A signed Madra amount: "+20 Madra", "-7.5 Madra", "5 Madra". The decimal
## point is a plain "." or the BBCode that LacquerText.decimal_bbcode() sets in
## its place, quoted whole (\Q...\E) so none of its characters read as regex.
static func _madra_amount_pattern() -> String:
	var decimal_point: String = r"(?:\.|\Q%s\E)" % LacquerText.DECIMAL_POINT_BBCODE
	return r"[+-]?\d+(?:%s\d+)? Madra" % decimal_point

## A bonus with its sign, a decimal only when it has one: 3.0 → "+3", -1.5 → "-1.5".
static func _signed(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%+d" % roundi(value)
	return "%+.1f" % value

## A number without a sign, a decimal only when it has one: 6.0 → "6", 6.5 → "6.5".
static func _plain(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % roundi(value)
	return "%.1f" % value
