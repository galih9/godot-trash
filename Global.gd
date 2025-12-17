extends Node

signal score_changed
signal upgrade_purchased(upgrade_id)

var score = 0:
	set(value):
		score = value
		score_changed.emit()

# State Variables managed by upgrades
var max_held_items = 1
var organic_bonus = 0
var inorganic_bonus = 0
var organic_send_time_reduction = 0 # Seconds to reduce
var inorganic_send_time_reduction = 0
var max_bin_organic_capacity = 10
var max_bin_anorganic_capacity = 5

# Upgrade Definitions
# You can add new upgrades here!
# required: id, name, cost, target_var, op (add, sub), val
var upgrades = [
	{
		"id": "stack_size",
		"name": "Stack Size +1",
		"cost": 50,
		"target_var": "max_held_items",
		"op": "add",
		"val": 1
	},
	{
		"id": "organic_bonus",
		"name": "Coin Bonus +5 (Organic)",
		"cost": 100,
		"target_var": "organic_bonus",
		"op": "add",
		"val": 5
	},
	{
		"id": "inorganic_bonus",
		"name": "Coin Bonus +5 (Recycle)",
		"cost": 100,
		"target_var": "inorganic_bonus",
		"op": "add",
		"val": 5
	},
	{
		"id": "organic_time",
		"name": "Send Time -1s (Organic)",
		"cost": 150,
		"target_var": "organic_send_time_reduction",
		"op": "add",
		"val": 1
	},
	{
		"id": "inorganic_time",
		"name": "Send Time -1s (Recycle)",
		"cost": 150,
		"target_var": "inorganic_send_time_reduction",
		"op": "add",
		"val": 1
	},
	{
		"id": "organic_cap",
		"name": "Bin Capacity +2 (Organic)",
		"cost": 200,
		"target_var": "max_bin_organic_capacity",
		"op": "add",
		"val": 2
	},
	{
		"id": "inorganic_cap",
		"name": "Bin Capacity +2 (Recycle)",
		"cost": 200,
		"target_var": "max_bin_anorganic_capacity",
		"op": "add",
		"val": 2
	}
]

func _ready():
	reset()

func reset():
	score = 0
	max_held_items = 1
	organic_bonus = 0
	inorganic_bonus = 0
	organic_send_time_reduction = 0
	inorganic_send_time_reduction = 0
	max_bin_organic_capacity = 10
	max_bin_anorganic_capacity = 5

func can_buy(cost):
	return score >= cost

func buy_upgrade(upgrade_idx):
	var data = upgrades[upgrade_idx]
	if can_buy(data.cost):
		score -= data.cost
		apply_upgrade(data)
		data.cost *= 2 # Double the cost
		upgrade_purchased.emit(data.id)
		return true
	return false

func apply_upgrade(data):
	var curr = get(data.target_var)
	if data.op == "add":
		set(data.target_var, curr + data.val)
	elif data.op == "sub":
		set(data.target_var, curr - data.val)
