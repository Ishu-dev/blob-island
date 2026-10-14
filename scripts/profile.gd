extends RefCounted
## Everything that survives between runs: the bank (coins and gems), trophies and the
## trophy road, which brawlers, guns, cars and fashion you own, their upgrade levels,
## and what is equipped. Saved to user://profile.cfg.

const PATH := "user://profile.cfg"
const MAX_LEVEL := 5

const BRAWLERS := {
	"blobby": {"name": "BLOBBY", "desc": "All-rounder", "color": "8fd3ff", "hp": 100.0, "speed": 6.0, "radius": 0.45, "jump": 7.5, "price": 0, "perk": ""},
	"chonk": {"name": "CHONK", "desc": "Big and slow, 170 HP, huge punches", "color": "ff9f6b", "hp": 170.0, "speed": 4.9, "radius": 0.58, "jump": 6.9, "price": 400, "perk": "punch"},
	"zippy": {"name": "ZIPPY", "desc": "Tiny and fast, double jump", "color": "9dff7a", "hp": 70.0, "speed": 7.6, "radius": 0.36, "jump": 7.8, "price": 600, "perk": "double_jump"},
	"sparky": {"name": "SPARKY", "desc": "Engineer, towers cost 40% less", "color": "ffe066", "hp": 95.0, "speed": 6.0, "radius": 0.45, "jump": 7.5, "price": 900, "perk": "engineer"},
	"gloopy": {"name": "GLOOPY", "desc": "Regrows 3 HP every second", "color": "d08bff", "hp": 110.0, "speed": 5.6, "radius": 0.5, "jump": 7.2, "price": 1400, "perk": "regen"},
}
# Guns you can buy as your starting gun. Bombs are free and always carried.
const GUN_PRICES := {"bomb": 0, "blaster": 150, "splatter": 250, "crossbow": 350, "netgun": 450, "laser": 700, "rocket": 1000}
const CARS := {
	"buggy": {"name": "BUGGY", "desc": "Light and quick", "color": "ff6b6b", "speed": 14.0, "hp": 80.0, "mass": 5.0, "price": 0},
	"monster": {"name": "MONSTER TRUCK", "desc": "Big wheels, crushes everything", "color": "4dc3ff", "speed": 12.0, "hp": 160.0, "mass": 8.0, "price": 500},
	"tank": {"name": "TANKETTE", "desc": "Slow, armoured, click to fire the cannon", "color": "7f9a4a", "speed": 8.5, "hp": 260.0, "mass": 10.0, "price": 900},
	"hover": {"name": "HOVER UFO", "desc": "Floats over water, drifts like soap", "color": "c08bff", "speed": 16.0, "hp": 90.0, "mass": 4.0, "price": 1500},
}
# Fashion is bought with gems.
const HATS := {"none": 0, "cap": 15, "party": 15, "chef": 20, "headphones": 30, "horns": 35, "cowboy": 40, "halo": 50, "crown": 80}
const GLASSES := {"none": 0, "shades": 10, "monocle": 20, "star": 30}
const UPGRADE_COST := [0, 100, 220, 400, 700]   # cost to go from level i to i+1 (coins)

# Trophy road: [trophies needed, reward type, value, label]
const ROAD := [
	[10, "coins", 150, "150 COINS"],
	[25, "hat", "party", "PARTY HAT"],
	[45, "gems", 20, "20 GEMS"],
	[70, "brawler", "zippy", "ZIPPY"],
	[100, "coins", 400, "400 COINS"],
	[140, "car", "monster", "MONSTER TRUCK"],
	[190, "gems", 40, "40 GEMS"],
	[250, "glasses", "star", "STAR GLASSES"],
	[320, "brawler", "sparky", "SPARKY"],
	[400, "hat", "crown", "CROWN"],
	[500, "car", "hover", "HOVER UFO"],
]

var coins := 200
var gems := 30
var trophies := 0
var road_claimed := 0
var best_wave := 0
var best_level := 1
var wins := 0
var last_gift := ""
var owned := {"brawler": ["blobby"], "gun": ["bomb"], "car": ["buggy"], "hat": ["none"], "glasses": ["none"]}
var levels := {}     # "gun:blaster" -> 1..5, "brawler:chonk" -> 1..5, "car:buggy" -> 1..5
var equip := {"brawler": "blobby", "gun": "bomb", "car": "buggy", "hat": "none", "glasses": "none"}


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	coins = int(cfg.get_value("bank", "coins", coins))
	gems = int(cfg.get_value("bank", "gems", gems))
	trophies = int(cfg.get_value("bank", "trophies", 0))
	road_claimed = int(cfg.get_value("bank", "road_claimed", 0))
	best_wave = int(cfg.get_value("stats", "best_wave", 0))
	best_level = int(cfg.get_value("stats", "best_level", 1))
	wins = int(cfg.get_value("stats", "wins", 0))
	last_gift = str(cfg.get_value("bank", "last_gift", ""))
	var o = cfg.get_value("items", "owned", owned)
	if o is Dictionary:
		for k in owned:
			if o.has(k):
				owned[k] = o[k]
	var lv = cfg.get_value("items", "levels", {})
	if lv is Dictionary:
		levels = lv
	var eq = cfg.get_value("items", "equip", equip)
	if eq is Dictionary:
		for k in equip:
			if eq.has(k):
				equip[k] = eq[k]


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("bank", "coins", coins)
	cfg.set_value("bank", "gems", gems)
	cfg.set_value("bank", "trophies", trophies)
	cfg.set_value("bank", "road_claimed", road_claimed)
	cfg.set_value("bank", "last_gift", last_gift)
	cfg.set_value("stats", "best_wave", best_wave)
	cfg.set_value("stats", "best_level", best_level)
	cfg.set_value("stats", "wins", wins)
	cfg.set_value("items", "owned", owned)
	cfg.set_value("items", "levels", levels)
	cfg.set_value("items", "equip", equip)
	cfg.save(PATH)


# ---------- queries ----------

func owns(kind: String, id: String) -> bool:
	return id in owned[kind]


func level_of(kind: String, id: String) -> int:
	return int(levels.get(kind + ":" + id, 1))


func price_of(kind: String, id: String) -> int:
	match kind:
		"brawler":
			return BRAWLERS[id]["price"]
		"gun":
			return GUN_PRICES[id]
		"car":
			return CARS[id]["price"]
		"hat":
			return HATS[id]
		"glasses":
			return GLASSES[id]
	return 0


## Fashion costs gems, everything else coins.
func currency_of(kind: String) -> String:
	return "gems" if kind in ["hat", "glasses"] else "coins"


func upgrade_cost(kind: String, id: String) -> int:
	var lv := level_of(kind, id)
	return -1 if lv >= MAX_LEVEL else UPGRADE_COST[lv]


func gun_mult(id: String) -> float:
	return 1.0 + 0.2 * (level_of("gun", id) - 1)


func ammo_mult(id: String) -> float:
	return 1.0 + 0.25 * (level_of("gun", id) - 1)


func brawler() -> Dictionary:
	return BRAWLERS[equip["brawler"]]


func brawler_hp() -> float:
	return brawler()["hp"] * (1.0 + 0.12 * (level_of("brawler", equip["brawler"]) - 1))


func car_stats(id: String) -> Dictionary:
	var s: Dictionary = CARS[id].duplicate()
	var lv := level_of("car", id)
	s["speed"] = s["speed"] * (1.0 + 0.06 * (lv - 1))
	s["hp"] = s["hp"] * (1.0 + 0.2 * (lv - 1))
	return s


# ---------- actions ----------

func buy(kind: String, id: String) -> bool:
	if owns(kind, id):
		return false
	var cost := price_of(kind, id)
	if currency_of(kind) == "gems":
		if gems < cost:
			return false
		gems -= cost
	else:
		if coins < cost:
			return false
		coins -= cost
	owned[kind].append(id)
	equip[kind] = id
	save()
	return true


func upgrade(kind: String, id: String) -> bool:
	var cost := upgrade_cost(kind, id)
	if cost < 0 or coins < cost or not owns(kind, id):
		return false
	coins -= cost
	levels[kind + ":" + id] = level_of(kind, id) + 1
	save()
	return true


func gift_ready() -> bool:
	return last_gift != Time.get_date_string_from_system()


func claim_gift() -> bool:
	if not gift_ready():
		return false
	last_gift = Time.get_date_string_from_system()
	coins += 60
	gems += 5
	save()
	return true


func next_road() -> Array:
	return ROAD[road_claimed] if road_claimed < ROAD.size() else []


## Adds a finished run to the bank. Returns the reward summary and any road rewards.
func finish_run(level: int, wave: int, kills: int, picked_coins: int, bosses: int, won: bool) -> Dictionary:
	var c := picked_coins + kills * 2 + wave * 5
	var g := bosses * 5 + (25 if won else 0)
	var t := wave * 3 + bosses * 10 + (30 if won else 0)
	coins += c
	gems += g
	trophies += t
	best_wave = maxi(best_wave, wave)
	best_level = maxi(best_level, level)
	if won:
		wins += 1
	var unlocked: Array[String] = []
	while road_claimed < ROAD.size() and trophies >= ROAD[road_claimed][0]:
		var r: Array = ROAD[road_claimed]
		match r[1]:
			"coins":
				coins += int(r[2])
			"gems":
				gems += int(r[2])
			_:
				var kind: String = r[1]
				if not owns(kind, r[2]):
					owned[kind].append(r[2])
		unlocked.append(r[3])
		road_claimed += 1
	save()
	return {"coins": c, "gems": g, "trophies": t, "unlocked": unlocked}
