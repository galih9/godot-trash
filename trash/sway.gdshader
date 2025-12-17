shader_type canvas_item;

uniform vec2 motion = vec2(0.0);
uniform float sway_intensity = 0.0001; // Reduced intensity to prevent excessive distortion

void vertex() {
	// Skew the sprite based on movement direction
	
	// motion.x * VERTEX.y:
	// If motion.x > 0 (Right), Vertical parts should lag.
	// Top (y < 0): motion.x * y is Negative. shifts Left. Correct.
	// Bottom (y > 0): motion.x * y is Positive. shifts Right. Correct (it "leads" or the top lags).
	
	float skew_x = motion.x * VERTEX.y;
	float skew_y = motion.y * VERTEX.x;
	
	VERTEX.x += skew_x * sway_intensity;
	VERTEX.y += skew_y * sway_intensity;
}
