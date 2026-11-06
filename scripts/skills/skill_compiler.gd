class_name SkillCompiler
extends RefCounted
## Turns a SkillGem + the character's stats + its passive gems into final
## numbers ("compiled skill"). Passives are just more modifiers merged into the
## character's StatBlock, so any passive works with any skill whose tags match.

const GEM_DAMAGE_GROWTH := 1.16  ## each gem level = 16% more base damage


## passives: passive gem ids (from the slot and its Soul Chain group).
## Passives that do not fit this skill's tags are skipped.
static func compile(gem: SkillGem, char_stats: StatBlock, passives: Array = []) -> Dictionary:
	var d := gem.data()
	var tags: Array = d.get("tags", []).duplicate()
	var base_tags: Array = tags.duplicate()
	var stats := char_stats.copy()
	var support_names: Array = []
	var ignored: Array = []
	for sid in passives:
		var sup := DB.support(sid)
		if not SkillGem.support_fits(base_tags, sup):
			ignored.append(sup.get("name", sid))
			continue
		stats.add_all(sup.get("mods", []), sid)
		support_names.append(sup.get("name", sid))
		for t in sup.get("adds_tags", []):
			if not tags.has(t):
				tags.append(t)

	var c := {
		"id": gem.skill_id,
		"name": d.get("name", gem.skill_id),
		"level": gem.level,
		"behavior": d.get("behavior", "projectile"),
		"tags": tags,
		"supports": support_names,
		"ignored": ignored,
	}

	# --- Damage ------------------------------------------------------------
	# Element tags are removed from the query and replaced with the type being
	# calculated, so "increased fire damage" only boosts the fire portion.
	var neutral := tags.filter(func(t): return not DB.ELEMENTS.has(t))
	var lvl_mult := pow(GEM_DAMAGE_GROWTH, gem.level - 1)
	var effectiveness: float = d.get("added_effectiveness", 1.0)
	var base_dmg: Dictionary = d.get("damage", {})
	var damage := {}
	for el in DB.ELEMENTS:
		var q: Array = neutral + [el]
		if el != "physical":
			q.append("elemental")
		var mn := 0.0
		var mx := 0.0
		if base_dmg.has(el):
			mn = base_dmg[el][0] * lvl_mult
			mx = base_dmg[el][1] * lvl_mult
		mn += stats.flat("added_%s_min" % el, q) * effectiveness
		mx += stats.flat("added_%s_max" % el, q) * effectiveness
		if mx <= 0.0:
			continue
		var mult := stats.multiplier("damage", q)
		damage[el] = [mn * mult, maxf(mn, mx) * mult]
	c["damage"] = damage

	# --- Speed, cost, cooldown ----------------------------------------------
	var is_attack := tags.has("attack")
	var speed := stats.multiplier("attack_speed" if is_attack else "cast_speed", neutral)
	c["use_time"] = float(d.get("use_time", 0.6)) / maxf(0.1, speed)
	var base_cost := float(d.get("mana_cost", 0)) * (1.0 + 0.08 * (gem.level - 1))
	c["mana_cost"] = roundf(stats.calc("mana_cost", base_cost, tags))
	c["cooldown"] = float(d.get("cooldown", 0.0)) / maxf(0.1, stats.multiplier("cooldown_recovery", tags))

	# --- Projectiles / area -------------------------------------------------
	c["projectiles"] = maxi(1, roundi(stats.calc("projectiles", d.get("projectiles", 1), tags)))
	c["spread"] = float(d.get("spread", 10))
	c["projectile_speed"] = stats.calc("projectile_speed", d.get("projectile_speed", 15), tags)
	c["chains"] = roundi(stats.calc("chains", d.get("chains", 0), tags))
	c["pierce"] = roundi(stats.calc("pierce", d.get("pierce", 0), tags))
	var area_scale := sqrt(stats.multiplier("area", tags))  # area is 2D, so radius grows with sqrt
	c["radius"] = float(d.get("radius", 0.0)) * area_scale
	c["explode_radius"] = float(d.get("explode_radius", 0.0)) * area_scale
	var reach := float(d.get("range", 10.0))
	if c["behavior"] == "melee_arc":
		reach *= area_scale
	c["range"] = reach
	c["arc"] = float(d.get("arc", 90))
	c["delay"] = float(d.get("delay", 0.0))
	c["repeats"] = roundi(stats.calc("repeats", 0, tags))

	# --- Crits & ailments ---------------------------------------------------
	c["crit_chance"] = clampf(stats.calc("crit_chance", d.get("crit", 5), tags), 0.0, 100.0)
	c["crit_multi"] = stats.calc("crit_multi", 150, tags)
	c["ignite_chance"] = clampf(stats.calc("ignite_chance", 15.0 if damage.has("fire") else 0.0, tags), 0.0, 100.0)
	c["shock_chance"] = clampf(stats.calc("shock_chance", 15.0 if damage.has("lightning") else 0.0, tags), 0.0, 100.0)
	c["chill"] = damage.has("cold")
	c["ailment_mult"] = stats.multiplier("ailment_damage", tags)

	# Main colour for visuals = biggest damage type.
	var best := String(d.get("color", "physical"))
	var best_avg := 0.0
	for el in damage:
		var avg: float = (damage[el][0] + damage[el][1]) * 0.5
		if avg > best_avg:
			best_avg = avg
			best = el
	c["color"] = DB.element_color(best)
	c["average_hit"] = average_hit(c)
	return c


static func average_hit(c: Dictionary) -> float:
	var total := 0.0
	for el in c["damage"]:
		total += (c["damage"][el][0] + c["damage"][el][1]) * 0.5
	var crit_factor: float = 1.0 + c["crit_chance"] / 100.0 * (c["crit_multi"] / 100.0 - 1.0)
	return total * crit_factor


## Rolls the actual damage for one hit on one target.
static func roll_hit(c: Dictionary) -> Dictionary:
	var crit: bool = randf() * 100.0 < float(c["crit_chance"])
	var dmg := {}
	for el in c["damage"]:
		var r: Array = c["damage"][el]
		var v := randf_range(r[0], r[1])
		if crit:
			v *= c["crit_multi"] / 100.0
		dmg[el] = v
	return {
		"damage": dmg,
		"crit": crit,
		"ignite_chance": c["ignite_chance"],
		"shock_chance": c["shock_chance"],
		"chill": c["chill"],
		"ailment_mult": c["ailment_mult"],
	}


## Human-readable summary used in tooltips.
static func describe(c: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s  (Level %d)" % [c["name"], c["level"]])
	lines.append("Tags: " + ", ".join(c["tags"]))
	if not c["supports"].is_empty():
		lines.append("Passives: " + ", ".join(c["supports"]))
	if not c["ignored"].is_empty():
		lines.append("Not compatible (ignored): " + ", ".join(c["ignored"]))
	lines.append("")
	for el in c["damage"]:
		lines.append("%s damage: %d - %d" % [el.capitalize(), roundi(c["damage"][el][0]), roundi(c["damage"][el][1])])
	lines.append("Average hit: %.1f" % c["average_hit"])
	lines.append("Crit: %.1f%%  x%d%%" % [c["crit_chance"], roundi(c["crit_multi"])])
	lines.append("%s time: %.2fs" % ["Attack" if c["tags"].has("attack") else "Cast", c["use_time"]])
	lines.append("Mana cost: %d" % c["mana_cost"])
	if c["cooldown"] > 0.0:
		lines.append("Cooldown: %.1fs" % c["cooldown"])
	match c["behavior"]:
		"projectile":
			lines.append("Projectiles: %d" % c["projectiles"])
			if c["chains"] > 0:
				lines.append("Chains: %d" % c["chains"])
			if c["pierce"] > 0:
				lines.append("Pierces: %d" % c["pierce"])
			if c["explode_radius"] > 0.0:
				lines.append("Explosion radius: %.1fm" % c["explode_radius"])
		"nova", "ground_aoe":
			lines.append("Radius: %.1fm" % c["radius"])
		"melee_arc":
			lines.append("Reach: %.1fm" % c["range"])
	if c["repeats"] > 0:
		lines.append("Repeats: %d" % c["repeats"])
	if c["ignite_chance"] > 0.0:
		lines.append("Ignite chance: %d%%" % roundi(c["ignite_chance"]))
	if c["shock_chance"] > 0.0:
		lines.append("Shock chance: %d%%" % roundi(c["shock_chance"]))
	if c["chill"]:
		lines.append("Chills enemies")
	return "\n".join(lines)
