extends Node2D

var time_left = 60.0
var game_active = true

# Inventory
var held_items: Array[TrashItem] = []

# Bin Capacity Logic (Locally tracked current fill, capacity is in Global)
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
@onready var shop_container = $"UI/ShopPanel/Shop Container"
@onready var shop_skip_button = $"UI/ShopPanel/Shop Container/HBoxContainer4/Button"
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
var shop_item_scene = preload("res://ShopItem.tscn")
var shop_items_nodes = []

func _ready():
	randomize()
	Global.reset()
	
	# Connect Global Signals
	Global.score_changed.connect(update_ui)
	Global.score_changed.connect(update_shop_ui)
	Global.upgrade_purchased.connect(_on_upgrade_purchased)
	
	game_over_panel.visible = false
	shop_panel.visible = false
	shop_skip_button.pressed.connect(_on_shop_skip_pressed)
	
	organic_send_button.pressed.connect(_on_organic_send_pressed)
	organic_timer.timeout.connect(_on_organic_timer_timeout)
	
	anorganic_send_button.pressed.connect(_on_anorganic_send_pressed)
	anorganic_timer.timeout.connect(_on_anorganic_timer_timeout)
	
	generate_shop_ui()
	update_ui()
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
		
		# Also check held items just in case
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
	score_label.text = "Score: " + str(Global.score)

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
	
	# Start from top (random X above screen)
	var start_x = randf_range(rect.position.x, rect.position.x + rect.size.x)
	var start_pos = Vector2(start_x, -100)
	var target_pos = Vector2(x, y)
	
	item.position = start_pos
	
	var tween = create_tween()
	tween.tween_property(item, "position", target_pos, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_trash_clicked(item: TrashItem):
	if not game_active:
		return
		
	# If already holding this item, do nothing
	if item in held_items:
		return
		
	if held_items.size() < Global.max_held_items:
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
				
				# Check if we are clicking on ANOTHER trash item
				var space_state = get_world_2d().direct_space_state
				var query = PhysicsPointQueryParameters2D.new()
				query.position = get_global_mouse_position()
				query.collide_with_areas = true
				query.collide_with_bodies = false 
				
				var results = space_state.intersect_point(query)
				for result in results:
					var collider = result.collider
					# If we found a TrashItem that is NOT in our held list
					if collider is TrashItem and not (collider in held_items):
						return # Stop! Don't drop.
				
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
			if bin_organic_count < Global.max_bin_organic_capacity:
				bin_organic_count += 1
				update_bin_ui()
				return true
			else:
				return false # Full
		else: # Inorganic
			if bin_anorganic_count < Global.max_bin_anorganic_capacity:
				bin_anorganic_count += 1
				update_bin_ui()
				return true
			else:
				return false # Full
	else:
		Global.score -= 5
		shake_bin(bin_type)
		
		# Show -5 indicator
		var bin_node = $BinOrganic if bin_type == 1 else $BinAnorganic
		spawn_float_indicator(bin_node.position + Vector2(0, -50), "-5", Color(1, 0.3, 0.3)) # Red
		return true # Wrong bin, item consumed but penalized
	
	return true


func game_over():
	game_active = false
	timer.stop()
	game_over_panel.visible = true
	final_score_label.text = "Final Score: " + str(Global.score)

func show_shop():
	game_active = false
	timer.stop()
	update_shop_ui()
	shop_panel.visible = true

func generate_shop_ui():
	# Clear existing helper list
	shop_items_nodes.clear()
	
	# We assume the container has Title and Skip Button pre-existing.
	# But we deleted the hardcoded buttons in main.tscn.
	
	# Let's verify we don't duplicate if called multiple times (though currently only called in _ready)
	# If we wanted to support dynamic updates we'd clear children here.
	
	for i in range(Global.upgrades.size()):
		var data = Global.upgrades[i]
		var item = shop_item_scene.instantiate()
		shop_container.add_child(item)
		item.setup(i, data)
		item.buy_pressed.connect(_on_buy_upgrade_pressed)
		shop_items_nodes.append(item)
		
	# Move Skip Button to bottom
	# The skip button is inside a container which is a child of shop_container
	var skip_container = shop_skip_button.get_parent()
	shop_container.move_child(skip_container, shop_container.get_child_count() - 1)

func update_shop_ui():
	shop_current_score_label.text = "Current Coin: " + str(Global.score)
	
	for item in shop_items_nodes:
		item.update_status(Global.score)

func _on_buy_upgrade_pressed(index):
	Global.buy_upgrade(index)

func _on_upgrade_purchased(upgrade_id):
	update_shop_ui()
	update_bin_ui()
	# Add any specific immediate feedbacks here if needed

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
	organic_indicator.text = str(bin_organic_count) + "/" + str(Global.max_bin_organic_capacity)
	anorganic_indicator.text = str(bin_anorganic_count) + "/" + str(Global.max_bin_anorganic_capacity)

func _on_organic_send_pressed():
	if bin_organic_count > 0:
		bin_organic_shipping = bin_organic_count
		bin_organic_count = 0
		organic_send_button.disabled = true
		
		# Calculate dynamic wait time
		var time = 5.0 - Global.organic_send_time_reduction
		if time < 1.0: time = 1.0
		organic_timer.wait_time = time
		
		organic_timer.start()
		update_bin_ui()

func _on_organic_timer_timeout():
	var gained = bin_organic_shipping * (10 + Global.organic_bonus)
	Global.score += gained
	
	# Show indicator
	spawn_float_indicator($BinOrganic.position + Vector2(0, -50), "+" + str(gained), Color(0.3, 1, 0.3)) # Green
	
	bin_organic_shipping = 0
	organic_send_button.disabled = false
	organic_timer.stop()
	update_ui()

func _on_anorganic_send_pressed():
	if bin_anorganic_count > 0:
		bin_anorganic_shipping = bin_anorganic_count
		bin_anorganic_count = 0
		anorganic_send_button.disabled = true
		
		# Calculate dynamic wait time
		var time = 10.0 - Global.inorganic_send_time_reduction
		if time < 1.0: time = 1.0
		anorganic_timer.wait_time = time
		
		anorganic_timer.start()
		update_bin_ui()

func _on_anorganic_timer_timeout():
	var gained = bin_anorganic_shipping * (10 + Global.inorganic_bonus)
	Global.score += gained
	
	# Show indicator
	spawn_float_indicator($BinAnorganic.position + Vector2(0, -50), "+" + str(gained), Color(0.3, 1, 0.3)) # Green
	
	bin_anorganic_shipping = 0
	anorganic_send_button.disabled = false
	anorganic_timer.stop()
	update_ui()

# --- Visual Effects Helpers ---

func shake_bin(bin_type: int):
	var bin_node = null
	if bin_type == 1:
		bin_node = $BinOrganic
	elif bin_type == 2:
		bin_node = $BinAnorganic
		
	if bin_node:
		var original_pos = bin_node.position
		# Use a simpler shake: offset slightly left, then right, then center
		var tween = create_tween()
		tween.tween_property(bin_node, "position", original_pos + Vector2(10, 0), 0.05)
		tween.tween_property(bin_node, "position", original_pos - Vector2(10, 0), 0.05)
		tween.tween_property(bin_node, "position", original_pos + Vector2(5, 0), 0.05)
		tween.tween_property(bin_node, "position", original_pos - Vector2(5, 0), 0.05)
		tween.tween_property(bin_node, "position", original_pos, 0.05)

func spawn_float_indicator(pos: Vector2, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.modulate = color
	# Make it large and bold if possible, or just default size
	label.add_theme_font_size_override("font_size", 32)
	label.position = pos
	label.z_index = 100 # On top of most things
	add_child(label)
	
	var tween = create_tween()
	# Float up and fade out
	tween.set_parallel(true)
	tween.tween_property(label, "position", pos + Vector2(0, -50), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	# Delete after tween
	tween.chain().tween_callback(label.queue_free)
