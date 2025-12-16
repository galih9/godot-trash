extends Node2D

var score = 0
var time_left = 60.0
var game_active = true

# Inventory
var held_items: Array[TrashItem] = []
var max_held_items = 1

# Upgrades
var stack_upgrade_cost = 100
var organic_bonus = 0
var inorganic_bonus = 0
var organic_upgrade_cost = 100
var inorganic_upgrade_cost = 100

var organic_send_time_cost = 100
var inorganic_send_time_cost = 100
var organic_capacity_cost = 100
var inorganic_capacity_cost = 100

var max_bin_organic_capacity = 10
var max_bin_anorganic_capacity = 5

# Bin Capacity Logic
var bin_organic_count = 0
var bin_anorganic_count = 0
var bin_organic_shipping = 0
var bin_anorganic_shipping = 0


# Hover tracking
# 0 = None, 1 = Organic, 2 = Inorganic
var hovered_bin_type = 0 

@onready var score_label = $UI/ScoreLabel
@onready var time_label = $UI/TimeLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var shop_panel = $UI/ShopPanel
@onready var shop_skip_button = $"UI/ShopPanel/Shop Container/HBoxContainer4/Button"
@onready var shop_stack_button = $"UI/ShopPanel/Shop Container/HBoxContainer/Button"
@onready var shop_organic_button = $"UI/ShopPanel/Shop Container/HBoxContainer2/Button"
@onready var shop_inorganic_button = $"UI/ShopPanel/Shop Container/HBoxContainer3/Button"
@onready var shop_organic_time_button = $"UI/ShopPanel/Shop Container/HBoxContainer7/Button"
@onready var shop_inorganic_time_button = $"UI/ShopPanel/Shop Container/HBoxContainer8/Button"
@onready var shop_organic_capacity_button = $"UI/ShopPanel/Shop Container/HBoxContainer6/Button"
@onready var shop_inorganic_capacity_button = $"UI/ShopPanel/Shop Container/HBoxContainer5/Button"
@onready var shop_current_score_label = $"UI/ShopPanel/Shop Container/CurrentScore"
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel

# Bin Nodes
@onready var organic_indicator = $BinOrganic/VBoxContainer/Indicator
@onready var organic_send_button = $BinOrganic/VBoxContainer/Button
@onready var organic_progress = $BinOrganic/VBoxContainer/ProgressBar
@onready var organic_timer = $BinOrganic/VBoxContainer/Timer

@onready var anorganic_indicator = $BinAnorganic/VBoxContainer/Indicator
@onready var anorganic_send_button = $BinAnorganic/VBoxContainer/Button
@onready var anorganic_progress = $BinAnorganic/VBoxContainer/ProgressBar
@onready var anorganic_timer = $BinAnorganic/VBoxContainer/Timer


@onready var spawn_area = $SpawnArea
@onready var timer = $Timer

var trash_scene = preload("res://trash/TrashItem.tscn")

func _ready():
	randomize()
	update_ui()
	game_over_panel.visible = false
	shop_panel.visible = false
	shop_skip_button.pressed.connect(_on_shop_skip_pressed)
	shop_stack_button.pressed.connect(_on_buy_stack_upgrade_pressed)
	shop_organic_button.pressed.connect(_on_buy_organic_upgrade_pressed)
	shop_inorganic_button.pressed.connect(_on_buy_inorganic_upgrade_pressed)
	shop_organic_time_button.pressed.connect(_on_buy_organic_time_upgrade_pressed)
	shop_inorganic_time_button.pressed.connect(_on_buy_inorganic_time_upgrade_pressed)
	shop_organic_capacity_button.pressed.connect(_on_buy_organic_capacity_upgrade_pressed)
	shop_inorganic_capacity_button.pressed.connect(_on_buy_inorganic_capacity_upgrade_pressed)
	
	organic_send_button.pressed.connect(_on_organic_send_pressed)
	organic_timer.timeout.connect(_on_organic_timer_timeout)
	
	anorganic_send_button.pressed.connect(_on_anorganic_send_pressed)
	anorganic_timer.timeout.connect(_on_anorganic_timer_timeout)
	
	update_bin_ui()


func _process(delta):
	if not game_active:
		return
		
	# Update Timer
	time_left -= delta
	if time_left <= 0:
		# Check if there is any trash left
		var trash_count = 0
		for child in get_children():
			if child is TrashItem and not (child in held_items):
				trash_count += 1
		
		# Also check held items just in case, though they should be counted or dropped
		trash_count += held_items.size()
		
		if trash_count > 0:
			game_over()
		else:
			show_shop()
	
	time_label.text = "Time: " + str(int(time_left))
	
	# Update held items position
	if held_items.size() > 0:
		var mouse_pos = get_global_mouse_position()
		for i in range(held_items.size()):
			var item = held_items[i]
			if is_instance_valid(item):
				# Stack them slightly
				item.global_position = mouse_pos + Vector2(0, i * 20)

	# Update Progress Bars
	if not organic_timer.is_stopped():
		organic_progress.value = (1 - organic_timer.time_left / organic_timer.wait_time) * 100
	else:
		organic_progress.value = 0
		
	if not anorganic_timer.is_stopped():
		anorganic_progress.value = (1 - anorganic_timer.time_left / anorganic_timer.wait_time) * 100
	else:
		anorganic_progress.value = 0

func update_ui():
	score_label.text = "Score: " + str(score)

func _on_timer_timeout():
	if game_active and time_left > 10:
		spawn_trash()

func spawn_trash():
	var trash = trash_scene.instantiate()
	trash.type = randi() % 2 # 0 or 1
	
	respawn_item(trash)
	
	# Connect clicked signal
	trash.clicked.connect(_on_trash_clicked)
	
	add_child(trash)

func respawn_item(item):
	var rect = spawn_area.get_rect()
	var x = randf_range(rect.position.x, rect.position.x + rect.size.x)
	var y = randf_range(rect.position.y, rect.position.y + rect.size.y)
	item.position = Vector2(x, y)

func _on_trash_clicked(item: TrashItem):
	if not game_active:
		return
		
	# If already holding this item, do nothing
	if item in held_items:
		return
		
	if held_items.size() < max_held_items:
		held_items.append(item)
		# Disable collision
		item.SetCollision(false)

func _unhandled_input(event):
	if not game_active:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# If we clicked and are holding items...
			if held_items.size() > 0:
				
				# CRITICAL FIX: Check if we are clicking on ANOTHER trash item before deciding to drop
				# If we are, DO NOT DROP. Let the _on_trash_clicked signal handle it.
				var space_state = get_world_2d().direct_space_state
				var query = PhysicsPointQueryParameters2D.new()
				query.position = get_global_mouse_position()
				query.collide_with_areas = true
				query.collide_with_bodies = false # Area2D are areas
				
				var results = space_state.intersect_point(query)
				for result in results:
					var collider = result.collider
					# If we found a TrashItem that is NOT in our held list
					if collider is TrashItem and not (collider in held_items):
						return # Stop! Don't drop. We are clicking a new item.

				drop_items()

func drop_items():
	# Check where we are dropping
	if hovered_bin_type != 0:
		# We are over a bin!
		for item in held_items:
			if is_instance_valid(item):
				if process_score(item, hovered_bin_type):
					item.queue_free()
				else:
					# Bin full, bounce/respawn
					respawn_item(item)
					item.SetCollision(true)
	else:
		# Return to spawn randomly
		for item in held_items:
			if is_instance_valid(item):
				respawn_item(item)
				# Re-enable input
				item.SetCollision(true)
	
	held_items.clear()

func process_score(item: TrashItem, bin_type: int):
	# bin_type: 1 = Organic, 2 = Inorganic
	# item.type: 0 = Organic, 1 = Inorganic
	
	var correct = false
	if bin_type == 1 and item.type == 0:
		correct = true
	elif bin_type == 2 and item.type == 1:
		correct = true
		
	if correct:
		if item.type == 0: # Organic
			if bin_organic_count < max_bin_organic_capacity:
				bin_organic_count += 1
				update_bin_ui()
				return true
			else:
				return false # Full
		else: # Inorganic
			if bin_anorganic_count < max_bin_anorganic_capacity:
				bin_anorganic_count += 1
				update_bin_ui()
				return true
			else:
				return false # Full
	else:
		score -= 5
		update_ui()
		return true # Wrong bin, item consumed but penalized
	
	update_ui()
	return true


func game_over():
	game_active = false
	timer.stop()
	game_over_panel.visible = true
	final_score_label.text = "Final Score: " + str(score)

func show_shop():
	game_active = false
	timer.stop()
	update_shop_ui()
	shop_panel.visible = true

func update_shop_ui():
	shop_current_score_label.text = "Current Coin: " + str(score)
	
	shop_stack_button.disabled = score < stack_upgrade_cost
	shop_stack_button.text = "Buy Stack +1 (" + str(stack_upgrade_cost) + " score)"
	
	shop_organic_button.disabled = score < organic_upgrade_cost
	shop_organic_button.text = "Buy Coin +5 (" + str(organic_upgrade_cost) + " score)"
	
	shop_inorganic_button.disabled = score < inorganic_upgrade_cost
	shop_inorganic_button.text = "Buy Coin +5 (" + str(inorganic_upgrade_cost) + " score)"

	shop_organic_time_button.disabled = score < organic_send_time_cost
	shop_organic_time_button.text = "Send Time -1s (" + str(organic_send_time_cost) + " score)"

	shop_inorganic_time_button.disabled = score < inorganic_send_time_cost
	shop_inorganic_time_button.text = "Send Time -1s (" + str(inorganic_send_time_cost) + " score)"

	shop_organic_capacity_button.disabled = score < organic_capacity_cost
	shop_organic_capacity_button.text = "Bin Capacity +2 (" + str(organic_capacity_cost) + " score)"

	shop_inorganic_capacity_button.disabled = score < inorganic_capacity_cost
	shop_inorganic_capacity_button.text = "Bin Capacity +2 (" + str(inorganic_capacity_cost) + " score)"

func _on_buy_stack_upgrade_pressed():
	if score >= stack_upgrade_cost:
		score -= stack_upgrade_cost
		max_held_items += 1
		
		update_ui()
		update_shop_ui()

func _on_buy_organic_upgrade_pressed():
	if score >= organic_upgrade_cost:
		score -= organic_upgrade_cost
		organic_bonus += 5
		
		update_ui()
		update_shop_ui()

func _on_buy_inorganic_upgrade_pressed():
	if score >= inorganic_upgrade_cost:
		score -= inorganic_upgrade_cost
		inorganic_bonus += 5
		
		update_ui()
		update_shop_ui()

func _on_buy_organic_time_upgrade_pressed():
	if score >= organic_send_time_cost:
		score -= organic_send_time_cost
		if organic_timer.wait_time > 1:
			organic_timer.wait_time -= 1
		
		update_ui()
		update_shop_ui()

func _on_buy_inorganic_time_upgrade_pressed():
	if score >= inorganic_send_time_cost:
		score -= inorganic_send_time_cost
		if anorganic_timer.wait_time > 1:
			anorganic_timer.wait_time -= 1
			
		update_ui()
		update_shop_ui()

func _on_buy_organic_capacity_upgrade_pressed():
	if score >= organic_capacity_cost:
		score -= organic_capacity_cost
		max_bin_organic_capacity += 2
		
		update_ui()
		update_shop_ui()
		update_bin_ui()

func _on_buy_inorganic_capacity_upgrade_pressed():
	if score >= inorganic_capacity_cost:
		score -= inorganic_capacity_cost
		max_bin_anorganic_capacity += 2
		
		update_ui()
		update_shop_ui()
		update_bin_ui()


func _on_shop_skip_pressed():
	shop_panel.visible = false
	time_left = 60.0
	game_active = true
	timer.start()
	update_ui()

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

# Bin Signals
func _on_bin_organic_mouse_entered():
	hovered_bin_type = 1

func _on_bin_organic_mouse_exited():
	if hovered_bin_type == 1:
		hovered_bin_type = 0

func _on_bin_anorganic_mouse_entered():
	hovered_bin_type = 2

func _on_bin_anorganic_mouse_exited():
	if hovered_bin_type == 2:
		hovered_bin_type = 0

func update_bin_ui():
	organic_indicator.text = str(bin_organic_count) + "/" + str(max_bin_organic_capacity)
	anorganic_indicator.text = str(bin_anorganic_count) + "/" + str(max_bin_anorganic_capacity)

func _on_organic_send_pressed():
	if bin_organic_count > 0:
		bin_organic_shipping = bin_organic_count
		bin_organic_count = 0
		organic_send_button.disabled = true
		organic_timer.start()
		update_bin_ui()

func _on_organic_timer_timeout():
	score += bin_organic_shipping * (10 + organic_bonus)
	bin_organic_shipping = 0
	organic_send_button.disabled = false
	organic_timer.stop()
	update_ui()

func _on_anorganic_send_pressed():
	if bin_anorganic_count > 0:
		bin_anorganic_shipping = bin_anorganic_count
		bin_anorganic_count = 0
		anorganic_send_button.disabled = true
		anorganic_timer.start()
		update_bin_ui()

func _on_anorganic_timer_timeout():
	score += bin_anorganic_shipping * (10 + inorganic_bonus)
	bin_anorganic_shipping = 0
	anorganic_send_button.disabled = false
	anorganic_timer.stop()
	update_ui()
