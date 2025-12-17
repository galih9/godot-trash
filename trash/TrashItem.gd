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
		
	# Setup Sway Shader
	var shader = load("res://trash/sway.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		$Sprite2D.material = mat

var prev_pos = Vector2.ZERO
var velocity = Vector2.ZERO

func _process(delta):
	# Calculate velocity for sway effect
	var current_pos = global_position
	if delta > 0:
		var raw_velocity = (current_pos - prev_pos) / delta
		# Smooth it out
		velocity = velocity.lerp(raw_velocity, 15.0 * delta)
		
		# Apply to shader
		if $Sprite2D.material:
			$Sprite2D.material.set_shader_parameter("motion", velocity)
			
	prev_pos = current_pos

func _on_input_event(viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("clicked", self)
			viewport.set_input_as_handled()

func SetCollision(enabled: bool):
	input_pickable = enabled
	monitorable = enabled
	monitoring = enabled
