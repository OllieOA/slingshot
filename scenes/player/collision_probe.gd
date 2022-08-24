class_name CollisionProbe extends Area2D

func reset_position() -> void:
	position = Vector2(0, 0)


func move_and_probe(target_position: Vector2) -> Array:
	# Returns an array of total gravity effect, and a bool to determine if
	# we should continue probing
	var force_at_point = Vector2.ZERO
	global_position = target_position

	for body in get_overlapping_bodies():
		if body.is_in_group("colliders"):
			return [force_at_point, false]

	for area in get_overlapping_areas():
		force_at_point += area.gravity * area.gravity_vec
		
	return [force_at_point, true]