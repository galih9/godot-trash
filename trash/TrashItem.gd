extends Area2D
class_name TrashItem

# 0 = Organic, 1 = Anorganic
var type = 0
var capacity = 1
var texture_path = ""
signal clicked(item)

func _ready():
	# Setup Texture
	if texture_path != "":
		var tex = load(texture_path)
		if tex:
			$Sprite2D.texture = tex
		else:
			print("Error: Could not load texture at: ", texture_path)
	
	# Resize
	scale = Vector2(0.4, 0.4)

	
	# Setup Sway Shader
	var shader = load("res://trash/sway.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		$Sprite2D.material = mat

func setup(data):
	type = data.type
	capacity = data.capacity
	texture_path = data.texture_path


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
