extends SceneTree
## Unit tests for the stat engine, skill compiler, items and inventory.
## Run from the project folder:
##   godot --headless --script res://tests/run_tests.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	DB.ensure_loaded()
	test_stat_block()
	test_conditional_tags()
	test_compiler_supports()
	test_support_requirements()
	test_weapon_damage_only_for_attacks()
	test_weapon_slots_and_chains()
	test_items()
	test_inventory_flow()
	test_data_integrity()
	print("")
	if _failures == 0:
		print("ALL TESTS PASSED (%d checks)" % _checks)
	else:
		print("%d of %d CHECKS FAILED" % [_failures, _checks])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("  FAIL: ", what)


func near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func test_stat_block() -> void:
	print("stat block")
	var s := StatBlock.new()
	s.add("life", "flat", 20)
	s.add("life", "increased", 10)
	s.add("life", "increased", 20)  # increases add: +30%
	s.add("life", "more", 50)
	s.add("life", "more", 10)  # mores multiply: x1.5 x1.1
	# (100 + 20) * 1.3 * 1.5 * 1.1 = 257.4
	check(near(s.calc("life", 100), 257.4), "flat/increased/more math, got %s" % s.calc("life", 100))
	check(near(s.calc("mana", 50), 50), "unrelated stat untouched")


func test_conditional_tags() -> void:
	print("conditional tags")
	var s := StatBlock.new()
	s.add("damage", "increased", 50, ["fire"])
	s.add("damage", "increased", 20, ["spell"])
	check(near(s.multiplier("damage", ["spell", "fire"]), 1.7), "fire spell gets both")
	check(near(s.multiplier("damage", ["spell", "cold"]), 1.2), "cold spell only gets spell bonus")
	check(near(s.multiplier("damage", ["attack", "fire"]), 1.5), "fire attack only gets fire bonus")


func _no_crit_avg(c: Dictionary, el: String) -> float:
	return (c["damage"][el][0] + c["damage"][el][1]) * 0.5


func test_compiler_supports() -> void:
	print("compiler + passives")
	var empty := StatBlock.new()
	var gem := SkillGem.new("fireball", 1)
	var base := SkillCompiler.compile(gem, empty)
	check(base["projectiles"] == 1, "fireball has 1 projectile")
	check(near(_no_crit_avg(base, "fire"), 11.5), "fireball base avg 11.5, got %s" % _no_crit_avg(base, "fire"))

	var ms := SkillCompiler.compile(gem, empty, ["multishot"])
	check(ms["projectiles"] == 3, "multishot adds 2 projectiles")
	check(near(_no_crit_avg(ms, "fire"), 11.5 * 0.7), "multishot 30% less damage")
	check(ms["mana_cost"] > base["mana_cost"], "multishot costs more mana")

	var ac := SkillCompiler.compile(gem, empty, ["added_cold"])
	check(ac["damage"].has("cold") and ac["chill"], "added cold gives cold damage and chill")

	var lvl5 := SkillCompiler.compile(SkillGem.new("fireball", 5), empty)
	check(_no_crit_avg(lvl5, "fire") > _no_crit_avg(base, "fire") * 1.7, "gem level scales damage")

	var nova := SkillGem.new("shock_nova", 1)
	var n0 := SkillCompiler.compile(nova, empty)
	var n1 := SkillCompiler.compile(nova, empty, ["wide_reach"])
	check(near(n1["radius"], n0["radius"] * sqrt(1.5)), "50% increased area -> radius x sqrt(1.5)")

	var cleave := SkillCompiler.compile(SkillGem.new("cleave", 1), empty, ["multishot", "fury"])
	check(cleave["ignored"] == ["Multishot"], "passive that doesn't fit is ignored")
	check(cleave["supports"] == ["Fury"], "passive that fits applies")


func test_support_requirements() -> void:
	print("passive requirements")
	var cleave := SkillGem.new("cleave", 1)
	check(not cleave.fits("multishot"), "multishot rejected on melee skill")
	check(cleave.fits("fury"), "fury accepted on attack")
	check(cleave.fits("added_fire"), "added fire works on anything")
	check(not SkillGem.new("fireball", 1).fits("fury"), "fury rejected on spell")
	check(SkillGem.new("power_shot", 1).fits("multishot"), "multishot fits bow attack")


func test_weapon_damage_only_for_attacks() -> void:
	print("class weapons")
	var w := Weapon.new("warrior")
	var s1 := StatBlock.new()
	s1.add_all(w.mods(1))
	var s20 := StatBlock.new()
	s20.add_all(w.mods(20))
	var cleave1 := SkillCompiler.compile(SkillGem.new("cleave", 1), s1)
	var cleave20 := SkillCompiler.compile(SkillGem.new("cleave", 1), s20)
	var fireball := SkillCompiler.compile(SkillGem.new("fireball", 1), s1)
	check(cleave1["damage"]["physical"][1] > 12.0, "greatsword adds to cleave")
	check(cleave20["damage"]["physical"][1] > cleave1["damage"]["physical"][1] * 2.0, "weapon grows with level")
	check(not fireball["damage"].has("physical"), "greatsword does not add to fireball")
	var staff := StatBlock.new()
	staff.add_all(Weapon.new("mage").mods(1))
	check(SkillCompiler.compile(SkillGem.new("fireball", 1), staff)["average_hit"] > fireball["average_hit"], "staff boosts spells")
	for id in DB.classes:
		check(not Weapon.new(id).describe(10).contains("{"), "weapon text formatted for " + id)


func test_weapon_slots_and_chains() -> void:
	print("weapon slots + soul chains")
	check(Weapon.unlocked_slots(1) == 1, "1 slot at level 1")
	check(Weapon.unlocked_slots(9) == 1, "still 1 slot at level 9")
	check(Weapon.unlocked_slots(10) == 2, "2 slots at level 10")
	check(Weapon.unlocked_slots(55) == 6, "6 slots at level 55")
	check(Weapon.unlocked_slots(90) == 10, "10 slots at level 90")
	check(Weapon.unlocked_slots(100) == 10, "never more than 10 slots")
	check(Weapon.unlock_level(3) == 30, "slot 4 opens at level 30")

	var w := Weapon.new("mage")
	w.slots[0]["passive"] = "multishot"
	w.slots[1]["passive"] = "chain"
	w.slots[2]["passive"] = "echo"
	w.slots[3]["passive"] = "searing"
	check(w.passives_for(0, 10) == ["multishot"], "unchained slot has only its own passive")
	w.toggle_link(0, 1)
	check(w.has_link(1, 0), "links are two-way")
	check(w.passives_for(0, 10) == ["multishot", "chain"], "chained slots share passives")
	check(w.passives_for(1, 10) == ["multishot", "chain"], "sharing goes both ways")
	w.toggle_link(1, 2)
	check(w.passives_for(0, 10).size() == 3, "chains connect through the middle slot")
	check(w.passives_for(3, 10) == ["searing"], "slot outside the chain unaffected")
	check(w.passives_for(0, 2) == ["multishot", "chain"], "chains into locked slots are ignored")
	w.toggle_link(0, 1)
	check(not w.has_link(0, 1), "dragging the same chain again breaks it")
	w.toggle_link(0, 3)
	w.clear_links(0)
	check(w.links == [[1, 2]], "clear removes only that slot's chains")
	w.slots[4]["passive"] = "chain"
	w.toggle_link(1, 4)
	check(w.passives_for(4, 10).count("chain") == 1, "same passive twice counts once")


func test_items() -> void:
	print("items")
	seed(42)
	for i in 300:
		var item := ItemGen.roll_item(randi_range(1, 25))
		var n := item.affixes.size()
		match item.rarity:
			Item.Rarity.NORMAL:
				check(n == 0, "normal has no affixes")
			Item.Rarity.MAGIC:
				check(n >= 1 and n <= 2, "magic has 1-2 affixes")
				check(item.prefix_count() <= 1 and item.suffix_count() <= 1, "magic max 1 prefix + 1 suffix")
			Item.Rarity.RARE:
				check(n >= 3 and n <= 5, "rare has 3-5 affixes (got %d)" % n)
		check(item.prefix_count() <= 3 and item.suffix_count() <= 3, "affix caps")
		var ids := {}
		for a in item.affixes:
			check(not ids.has(a["id"]), "no duplicate affixes")
			ids[a["id"]] = true
			check(not a["text"].contains("{"), "affix text formatted: " + a["text"])
	var low := ItemGen.roll_item(1, Item.Rarity.NORMAL, "chainmail")
	check(low.name == "Chainmail", "forced base works")
	for i in 100:
		check(ItemGen.roll_item(30).slot != "weapon", "weapons never drop (class weapon only)")


func test_inventory_flow() -> void:
	print("inventory")
	var inv := Inventory.new("ranger")
	inv.add_uncut("skill", 3)
	inv.cut(0, "split_arrow")
	check(inv.skill_gems.size() == 1 and inv.skill_gems[0].level == 3, "cut skill gem goes to pouch with its level")
	inv.add_uncut("support", 1)
	inv.cut(0, "fury")
	check(inv.passive_gems == ["fury"], "cut passive goes to pouch")
	check(inv.set_passive(0, "fury") != "", "passive needs an active skill first")
	inv.set_active(0, 0)
	check(inv.weapon.slots[0]["active"].skill_id == "split_arrow" and inv.skill_gems.is_empty(), "active goes into weapon slot")
	check(inv.set_passive(0, "fury") == "", "fury fits split arrow")
	check(inv.passive_gems.is_empty(), "passive leaves the pouch")
	inv.passive_gems.append("quickcast")
	check(inv.set_passive(0, "quickcast") != "", "spell passive rejected on attack")
	# Swapping in a skill the passive doesn't fit returns the passive to the pouch.
	inv.skill_gems.append(SkillGem.new("fireball", 1))
	inv.set_active(0, 0)
	check(inv.weapon.slots[0]["passive"] == "" and inv.passive_gems.has("fury"), "unfitting passive returned")
	check(inv.skill_gems.size() == 1 and inv.skill_gems[0].skill_id == "split_arrow", "old active returned")
	inv.clear_active(0)
	check(inv.weapon.slots[0]["active"] == null and inv.skill_gems.size() == 2, "clear active")
	var item := ItemGen.roll_item(5, Item.Rarity.RARE, "padded_vest")
	inv.add_item(item)
	inv.equip_from_bag(0)
	check(inv.equipment["body"] == item and inv.bag.is_empty(), "equip from bag")
	inv.add_item(ItemGen.roll_item(5, Item.Rarity.MAGIC, "padded_vest"))
	inv.equip_from_bag(0)
	check(inv.bag.size() == 1 and inv.bag[0] == item, "swap puts old item in bag")


func test_data_integrity() -> void:
	print("data integrity")
	for id in DB.skills:
		var c := SkillCompiler.compile(SkillGem.new(id, 1), StatBlock.new())
		check(not c["damage"].is_empty(), "skill %s deals damage" % id)
		check(["projectile", "nova", "melee_arc", "ground_aoe"].has(c["behavior"]), "skill %s behavior valid" % id)
	for id in DB.supports:
		for m in DB.supports[id]["mods"]:
			check(["flat", "increased", "more"].has(m["kind"]), "support %s mod kind valid" % id)
	for id in DB.classes:
		var c := DB.player_class(id)
		check(DB.skills.has(c["start_skill"]), "class %s start skill exists" % id)
		check(not Weapon.new(id).mods(1).is_empty(), "class %s weapon has stats" % id)
	for a in DB.affixes:
		for t in a["tiers"]:
			check(t["values"].size() == a["mods"].size(), "affix %s tier values match mods" % a["id"])
