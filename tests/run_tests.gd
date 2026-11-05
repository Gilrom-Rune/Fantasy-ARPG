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
	print("compiler + supports")
	var empty := StatBlock.new()
	var gem := SkillGem.new("fireball", 1)
	var base := SkillCompiler.compile(gem, empty)
	check(base["projectiles"] == 1, "fireball has 1 projectile")
	check(near(_no_crit_avg(base, "fire"), 11.5), "fireball base avg 11.5, got %s" % _no_crit_avg(base, "fire"))

	gem.supports = ["multishot"]
	var ms := SkillCompiler.compile(gem, empty)
	check(ms["projectiles"] == 3, "multishot adds 2 projectiles")
	check(near(_no_crit_avg(ms, "fire"), 11.5 * 0.7), "multishot 30% less damage")
	check(ms["mana_cost"] > base["mana_cost"], "multishot costs more mana")

	gem.supports = ["added_cold"]
	var ac := SkillCompiler.compile(gem, empty)
	check(ac["damage"].has("cold") and ac["chill"], "added cold gives cold damage and chill")

	var lvl5 := SkillCompiler.compile(SkillGem.new("fireball", 5), empty)
	check(_no_crit_avg(lvl5, "fire") > _no_crit_avg(base, "fire") * 1.7, "gem level scales damage")

	var nova := SkillGem.new("shock_nova", 1)
	var n0 := SkillCompiler.compile(nova, empty)
	nova.supports = ["wide_reach"]
	var n1 := SkillCompiler.compile(nova, empty)
	check(near(n1["radius"], n0["radius"] * sqrt(1.5)), "50% increased area -> radius x sqrt(1.5)")


func test_support_requirements() -> void:
	print("support requirements")
	var cleave := SkillGem.new("cleave", 1)
	check(cleave.can_socket("multishot") != "", "multishot rejected on melee skill")
	check(cleave.can_socket("fury") == "", "fury accepted on attack")
	check(cleave.can_socket("added_fire") == "", "added fire works on anything")
	var fb := SkillGem.new("fireball", 1)
	check(fb.can_socket("fury") != "", "fury rejected on spell")
	fb.supports = ["chain", "pierce"]
	check(fb.can_socket("multishot") != "", "level 1 gem has only 2 sockets")
	check(SkillGem.new("fireball", 9).max_supports() == 5, "level 9 gem has 5 sockets")


func test_weapon_damage_only_for_attacks() -> void:
	print("weapon damage")
	var s := StatBlock.new()
	s.add_all(DB.bases["rusted_sword"]["implicit"])
	var cleave := SkillCompiler.compile(SkillGem.new("cleave", 1), s)
	var fireball := SkillCompiler.compile(SkillGem.new("fireball", 1), s)
	check(cleave["damage"]["physical"][1] > 12.0, "sword adds to cleave")
	check(not fireball["damage"].has("physical"), "sword does not add to fireball")


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
	var low := ItemGen.roll_item(1, Item.Rarity.NORMAL, "war_axe")
	check(low.name == "War Axe", "forced base works")


func test_inventory_flow() -> void:
	print("inventory")
	var inv := Inventory.new()
	inv.add_uncut("skill", 3)
	inv.cut(0, "arc_bolt")
	check(inv.skill_slots[0] != null and inv.skill_slots[0].skill_id == "arc_bolt", "cut gem goes to first empty slot")
	check(inv.skill_slots[0].level == 3, "cut gem keeps level")
	inv.add_uncut("support", 1)
	inv.cut(0, "chain")
	check(inv.supports.has("chain"), "support goes to pool")
	check(inv.socket(0, "chain") == "", "socket chain into arc bolt")
	check(inv.supports.is_empty(), "socketed support leaves pool")
	inv.unsocket(0, 0)
	check(inv.supports.has("chain") and inv.skill_slots[0].supports.is_empty(), "unsocket returns support")
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
	for a in DB.affixes:
		for t in a["tiers"]:
			check(t["values"].size() == a["mods"].size(), "affix %s tier values match mods" % a["id"])
