extends Area2D
class_name TrashItem

# 0 = Organic, 1 = Anorganic
var type = 0
signal clicked(item)

func _ready():
	if type == 0:
		modulate = Color(0, 0.8, 0) # Green for Organic
	else:
		modulate = Color(0.5, 0.5, 0.8) # Blue-ish for Anorganic

func _on_input_event(viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("clicked", self)
			viewport.set_input_as_handled()

func SetCollision(enabled: bool):
	input_pickable = enabled
	monitorable = enabled
	monitoring = enabled
