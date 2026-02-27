shader_type canvas_item;

// Global settings
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;
uniform vec2 camera_global_pos = vec2(0.0);

// Instance Uniforms for variation
instance uniform vec4 outline_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
instance uniform vec2 global_scale = vec2(1.0, 1.0); // Passed from script to compensate outline width
instance uniform vec2 impact_offset = vec2(0.0);
instance uniform float sway_phase = 0.0;
instance uniform float sway_intensity : hint_range(0.0, 50.0) = 5.0;
instance uniform float sway_speed : hint_range(0.0, 5.0) = 1.0;
instance uniform float parallax_factor : hint_range(-0.1, 0.1) = 0.02;

void vertex() {
	// Wind Sway
	// Using VERTEX.y instead of UV.y to support SpriteSheets/Atlases.
	// Assuming centered=true, positive Y is bottom (root), negative Y is top.
	// We want 0 sway at the bottom (positive Y) and max sway at the top (negative Y).
	// A simple heuristic is that anything below 0.0 (center) shouldn't sway much,
	// or we can linearly interpolate assuming the sprite is roughly centered.

	// If VERTEX.y is 10 (bottom), sway should be 0.
	// If VERTEX.y is -10 (top), sway should be max.
	// We don't know the exact height, but we can assume "up" is negative Y.
	// We clamp positive Y contributions to 0 effectively for the mask strength if we only sway the top.

	// Normalized sway mask based on distance from "root" (approximated as Y > 0)
	// Actually, just -VERTEX.y works: Bottom (-10 -> -10) (Wait, bottom is +10).
	// - (+10) = -10.  - (-10) = +10.
	// So -VERTEX.y gives positive values for the top.
	// We clamp to 0 so the bottom half doesn't sway in reverse or weirdly.

	float dist_from_root = max(0.0, -VERTEX.y);

	// Normalize? We don't know the height, so sway_intensity needs to be calibrated in pixels roughly.
	// Or we use a non-linear factor.
	// Let's use dist_from_root / 100.0 as a rough "UV-like" factor if needed, but
	// simple multiplication works if sway_intensity is small.
	// Better: The user asked for sway based on height.
	// "Root (UV.y close to 1.0) stays still".

	// Modified sway calculation: reduced coefficient and non-linear transform
	float sway = sin(TIME * sway_speed + sway_phase) * sway_intensity * (pow(dist_from_root, 1.2) * 0.01);

	// Apply sway to X
	VERTEX.x += sway;

	// Apply Impact Offset
	// Weighted by dist_from_root to pin the bottom
	VERTEX.xy += impact_offset * dist_from_root;

	// Parallax
	// Move VERTEX based on camera position relative to the object.
	// To do this strictly in local vertex space, we need the object's global position.
	// MODEL_MATRIX[3].xy gives us the global position of the instance (Node2D).
	vec2 node_global_pos = MODEL_MATRIX[3].xy;
	vec2 diff = camera_global_pos - node_global_pos;

	// Apply parallax offset
	VERTEX += diff * parallax_factor;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// If the pixel is transparent, we might be on the edge/outside and need to draw outline.
	// But in fragment shader, we are processing a pixel.
	// To get a smooth outline, we check neighbors.

	// Get texture size to calculate pixel size in UV space
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));

	// Compensate for global scale.
	// If global_scale is 0.5, the object is smaller on screen.
	// To keep 1px screen outline, we need to sample 2 texture pixels away.
	// So we divide by global_scale.
	// Prevent division by zero.
	vec2 scale = max(abs(global_scale), vec2(0.001));
	vec2 pixel_size = (1.0 / tex_size) / scale;

	// Sample around the current pixel
	float alpha_max = 0.0;

	// 8-direction sampling or circular sampling for smoothness
	// Using a simple cross + diagonals
	float width = outline_width;

	// Optimization: If current pixel is fully opaque, no need to check outline (unless we want inner outline)
	// Usually outline is drawn "under" or "around".
	// If we want the outline to be *outside* the sprite, we rely on the sprite having transparent padding
	// or the mesh being larger. Since we are using Sprite2D, we can only draw within the quad.
	// If the sprite is tightly cropped, the outline might be cut off.
	// However, usually sprites have some empty space.

	if (col.a < 1.0) {
		// Sample neighbors to see if we are close to an opaque pixel
		// Use a few samples for smoothness
		float steps = 16.0;
		for (float i = 0.0; i < steps; i++) {
			float angle = i * 6.28318 / steps;
			vec2 offset = vec2(cos(angle), sin(angle)) * width * pixel_size;
			alpha_max = max(alpha_max, texture(TEXTURE, UV + offset).a);
		}

		// If we found an opaque neighbor, draw outline
		// Smoothstep for anti-aliasing feel
		if (alpha_max > 0.0) {
			// Mix outline based on how close we are to the opaque pixel (approximated by alpha_max)
			// And keep the original color's alpha if it exists (for semi-transparent pixels)
			float outline_alpha = smoothstep(0.0, 1.0, alpha_max);
			// If the original pixel has some alpha, we blend.
			// Ideally: result = mix(outline, texture, texture.a)

			vec4 outline = outline_color;
			outline.a *= outline_alpha;

			col = mix(outline, col, col.a);
		}
	}

	COLOR = col;
}
