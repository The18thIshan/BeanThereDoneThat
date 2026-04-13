extends StaticBody2D

# The Mirror handles its own safety limits now!
const MAX_BOUNCES = 5

# ==========================================
# --- THE REFRACTION ENGINE ---
# ==========================================
# The Bean passes its Line2D into this function so the mirror can draw on it!
func reflect_beam(line: Line2D, hit_pos: Vector2, incoming_dir: Vector2, hit_normal: Vector2, distance_remaining: float, current_bounce: int):
	# Failsafe: Prevent infinite loops
	if current_bounce > MAX_BOUNCES:
		return
		
	# 1. Calculate the mathematical bounce angle
	var bounce_dir = incoming_dir.bounce(hit_normal)
	
	# 2. Push the new laser origin 1 pixel away from the glass so it doesn't shoot itself
	var start_pos = hit_pos + (hit_normal * 1.0)
	
	# 3. Fire the refracted physics ray
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, start_pos + (bounce_dir * distance_remaining))
	query.exclude = [self] # Don't hit our own mirror
	
	var hit_data = space_state.intersect_ray(query)
	
	if hit_data:
		var end_pos = hit_data.position
		line.add_point(end_pos) # Draw the bounced segment!
		
		var target = hit_data.collider
		
		# Did the bounce hit a puzzle switch?
		if target.has_method("hit_by_laser"):
			target.hit_by_laser()
			
		# Did the bounce hit ANOTHER mirror?! Pass the baton!
		if target.has_method("reflect_beam"):
			var new_dist = distance_remaining - start_pos.distance_to(end_pos)
			target.reflect_beam(line, end_pos, bounce_dir, hit_data.normal, new_dist, current_bounce + 1)
			
	else:
		# The bounce went into the void. Draw to max range.
		line.add_point(start_pos + (bounce_dir * distance_remaining))
