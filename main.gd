extends Node2D

var score = 0
var time_left = 60.0
var game_active = true

# Inventory
var held_items: Array[TrashItem] = []
var max_held_items = 3

# Hover tracking
# 0 = None, 1 = Organic, 2 = Inorganic
var hovered_bin_type = 0 

@onready var score_label = $UI/ScoreLabel
@onready var time_label = $UI/TimeLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var final_score_label = $UI/GameOverPanel/FinalScoreLabel
@onready var spawn_area = $SpawnArea
@onready var timer = $Timer

var trash_scene = preload("res://TrashItem.tscn")

func _ready():
	randomize()
	update_ui()
	game_over_panel.visible = false

func _process(delta):
	if not game_active:
		return
		
	# Update Timer
	time_left -= delta
	if time_left <= 0:
		game_over()
	
	time_label.text = "Time: " + str(int(time_left))
	
	# Update held items position
	if held_items.size() > 0:
		var mouse_pos = get_global_mouse_position()
		for i in range(held_items.size()):
			var item = held_items[i]
			if is_instance_valid(item):
				# Stack them slightly
				item.global_position = mouse_pos + Vector2(0, i * 20)

func update_ui():
	score_label.text = "Score: " + str(score)

func _on_timer_timeout():
	if game_active:
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
				process_score(item, hovered_bin_type)
				item.queue_free()
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
		score += 10
	else:
		score -= 5
	
	update_ui()

func game_over():
	game_active = false
	timer.stop()
	game_over_panel.visible = true
	final_score_label.text = "Final Score: " + str(score)

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
