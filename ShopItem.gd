extends HBoxContainer

signal buy_pressed(index)

var upgrade_index = -1
var cost = 0

@onready var label = $Label
@onready var button = $Button

func _ready():
	button.pressed.connect(_on_button_pressed)

func setup(index, data):
	upgrade_index = index
	label.text = data.name
	cost = data.cost
	update_button_text()

func update_button_text():
	button.text = "Buy (" + str(cost) + " score)"

func update_status(current_score):
	button.disabled = current_score < cost

func _on_button_pressed():
	buy_pressed.emit(upgrade_index)
