class_name DrillRules
extends RefCounted

## The rules of a body refining rep, for every drill: one judge turns how well a
## rep was played into a tier, and the tier's factor scales the rep's XP and its
## Health alike. Each input measures its rep as a share from 0 to 1 (how close to
## the band's centre, how long inside the band, how close to the beat), so the
## tiers feel the same on every drill. Strength raises the Health a rep restores.

const AttributeType = CharacterAttributesData.AttributeType

## How a rep was judged. Never saved, so its values may be reordered.
enum Tier { MISS, OK, GOOD, PERFECT }

## The lowest share each tier takes, best first. A share below OK's is a MISS.
const PERFECT_SHARE: float = 0.85
const GOOD_SHARE: float = 0.6
const OK_SHARE: float = 0.3

## The share of a PERFECT rep's XP and Health each tier pays.
const TIER_FACTORS: Dictionary[Tier, float] = {
	Tier.MISS: 0.0,
	Tier.OK: 0.5,
	Tier.GOOD: 0.75,
	Tier.PERFECT: 1.0,
}

## The Health a rep gains for each Strength point above the baseline, as a share
## of the drill's own amount: the shape Spirit gives Madra a cycle.
const HEALTH_PER_STRENGTH_POINT: float = 0.1

## The tier a rep played to `share` (0 to 1) earns.
static func judge(share: float) -> Tier:
	if share >= PERFECT_SHARE:
		return Tier.PERFECT
	if share >= GOOD_SHARE:
		return Tier.GOOD
	if share >= OK_SHARE:
		return Tier.OK
	return Tier.MISS

## The share of a PERFECT rep's XP and Health the tier pays.
static func factor(tier: Tier) -> float:
	return TIER_FACTORS[tier]

## The XP a rep judged `tier` pays, from the XP a PERFECT rep pays.
static func xp_for_rep(base_xp: float, tier: Tier) -> float:
	return base_xp * factor(tier)

## The factor Strength puts on the Health a rep restores: 1.0 at the baseline
## (Lv 1), plus HEALTH_PER_STRENGTH_POINT a point above it. Points below the
## baseline take nothing away.
static func health_multiplier(strength: float) -> float:
	return 1.0 + maxf(0.0, strength - CharacterAttributesData.STAT_BASELINE) * HEALTH_PER_STRENGTH_POINT

## The Health a rep of `drill` judged `tier` restores at `strength`, the
## player's Strength total: health_per_rep x the tier's factor x
## health_multiplier(strength).
static func health_for_rep(drill: DrillData, tier: Tier, strength: float) -> float:
	return drill.health_per_rep * factor(tier) * health_multiplier(strength)

## The XP a perfect set of `drill` pays `stat`: a PERFECT rep's XP for it times
## the reps in a set. 0 for a stat the drill doesn't train.
static func perfect_set_xp(drill: DrillData, stat: AttributeType) -> float:
	var per_rep: float = 0.0
	if stat == AttributeType.STRENGTH:
		per_rep = drill.strength_xp_per_rep
	elif drill.has_minor_stat() and stat == drill.minor_stat:
		per_rep = drill.minor_xp_per_rep
	return per_rep * drill.reps_per_set
