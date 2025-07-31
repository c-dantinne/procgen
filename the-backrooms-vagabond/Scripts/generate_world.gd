extends Node


const floor_scene = preload("res://Scenes/floor.tscn")

@export var perimeter_width : int = 500
@export var perimeter_length : int = 500
@export var perimeter_buffer : int = 100

@export var min_room_size : int = 6
@export var max_room_size : int = 20
#@export var min_hallway_width = 500
#@export var max_hallway_width = 500
#@export var min_hallway_length = 500
#@export var max_hallway_length = 500
@export var min_doorway_size : int = 3
@export var min_surface_area : int = 1000

const NORTH := Vector3i(0, 0, 1)
const EAST := Vector3i(1, 0, 0)
const SOUTH := Vector3i(0, 0, -1)
const WEST := Vector3i(-1, 0, 0)
const directions_arr : Array[Vector3i] = [NORTH, EAST, SOUTH, WEST]

var world_seed : int = 0

var floor_brushes : Array[Node3D] = []
var wall_brushes : Array[Node3D] = []

func _ready() -> void:
	assert(min_doorway_size <= min_room_size / 2)
	
	if !world_seed:
		world_seed = randi()
	seed(world_seed) #todo show seed on ui
	#make_world()
	
	#var instance = floor_scene.instantiate()
	#add_child(instance)
	#instance.get_node("MeshInstance3D").global_scale(Vector3i(perimeter_width, 1, perimeter_length))
	#instance.get_node("MeshInstance3D").get_surface_override_material(0).albedo_color = Color(1,1,1)
	#set_brush_position(instance, Vector3i(0, 0, 0))
	
	make_world()
	

#REQUIREMENTS:
# - rooms must be between a minimum and maximum size
# - rooms need not be rectangles, but must orthogonal (L-shaped, T shaped, Square Hole)
# - rooms may be connected by thin walls or corridors
# - there must be between a minimum and maximum surface area
# - world generation must be repeatable by seed

func test_pass_by_ref(vect: Vector3i):
	vect.x = 1
	vect.y = 2
	vect.z = 3
	return vect

func make_world() -> void:
	pass
	var inner_perimeter_width : int = perimeter_width - perimeter_buffer
	var inner_perimeter_length : int = perimeter_length - perimeter_buffer
	var current_surface_area : int = 0
	var directions_available : Array[Vector3i] = directions_arr.duplicate(true)
	var current_brush_index : int = 0
	var brushes_with_adjacent_space : Array[Node3D] = []

	# 1. Pick a random point within the inner perimeter.
	var starting_point := Vector3i(rand_range(perimeter_buffer, inner_perimeter_width), 0, rand_range(perimeter_buffer, inner_perimeter_length))
	# 2. Generate a rectangular floor with a random size between min and max.
	var instance = floor_scene.instantiate()
	add_child(instance)
	var floor_size = Vector3i(rand_range(min_room_size, max_room_size), 1, rand_range(min_room_size, max_room_size))
	# 3. If floor overlaps perimeter, shrink that side to fix.
	if starting_point.x + floor_size.x > perimeter_width:
		floor_size.x = perimeter_width - starting_point.x
	if starting_point.y + floor_size.y > perimeter_width:
		floor_size.y = perimeter_width - starting_point.y
	current_surface_area += floor_size.x * floor_size.y
	set_brush_scale(instance, floor_size)
	set_brush_position(instance, starting_point)
	brushes_with_adjacent_space.append(instance)
	floor_brushes.append(instance)
	while current_surface_area < min_surface_area:
		# 4. Pick a random side of selected room that does not touch the perimeter.
		# 	 Backtrack brush floors until we can find adjacent space
		var adjacent_space_found = false
		while not adjacent_space_found:
			directions_available.shuffle()
			for dir in directions_available:
				if is_adjacent_space_available(brushes_with_adjacent_space[current_brush_index], dir):
					adjacent_space_found = true
					var new_brush = create_floor_brush(brushes_with_adjacent_space[current_brush_index], dir)
					brushes_with_adjacent_space.append(new_brush)
					floor_brushes.append(new_brush)
					current_surface_area += new_brush.scale.x * new_brush.scale.y
			if not adjacent_space_found:
				current_brush_index -= 1
			else:
				current_brush_index = len(brushes_with_adjacent_space) - 1
			if current_brush_index < 0:
				printerr("ERROR: No adjacent space available before minimum surface area reached. Seed: " + str(seed))
				return
		# 5. Generate another rectangular floor. 70% probability of being a hallway, 30% being a room.
		# 6. Shrink new room if overlapping perimeter or another floor.
		# 7. Check if we are at minimum surface area. If so, proceed to generate walls.
		# 8. Else, repeat floor generation.
	generate_walls()
	
	
func is_adjacent_space_available(current_brush: Node3D, direction: Vector3i) -> bool:
	var z = get_brush_position(current_brush).z
	var x = get_brush_position(current_brush).x
	var desired_z = 0
	var desired_x = 0
	
	match direction:
		NORTH:
			desired_z = z + current_brush.scale.z + min_room_size
		EAST:
			desired_x = x + current_brush.scale.x + min_room_size
		SOUTH:
			desired_z = z - min_room_size
		WEST:
			desired_x = x - min_room_size

	if desired_z > perimeter_length || desired_z < 0 || desired_x > perimeter_width || desired_x < 0:
		return false
		
	#first check if the other brush is at the same level as desired, then check if it will overlap
	for other_brush in floor_brushes:
		var other_brush_pos = get_brush_position(other_brush)
		match direction:
			NORTH:
				if other_brush_pos.z > z + current_brush.scale.z && other_brush_pos.z < desired_z:
					if other_brush_pos.x + other_brush.scale.x > x && other_brush_pos.x < x + current_brush.scale.x:
						return false
			EAST:
				if other_brush_pos.x > x + current_brush.scale.x && other_brush_pos.x < desired_x:
					if other_brush_pos.z + other_brush.scale.z > z && other_brush_pos.z < z + current_brush.scale.z:
						return false
			SOUTH:
				if other_brush_pos.z < z && other_brush_pos.z > desired_z:
					if other_brush_pos.x + other_brush.scale.x > x && other_brush_pos.x < x + current_brush.scale.x:
						return false
			WEST:
				if other_brush_pos.x < x && other_brush_pos.x > desired_x:
					if other_brush_pos.z + other_brush.scale.z > z && other_brush_pos.z < z + current_brush.scale.z:
						return false
	return true

func get_overlapping_brush(brush_size: Vector3i, brush_pos: Vector3i) -> Node3D:
	for other in floor_brushes:
		var other_pos = get_brush_position(other)
		if other_pos.x >= brush_pos.x + brush_size.x || other_pos.x + other.scale.x <= brush_pos.x || other_pos.z >= brush_pos.z + brush_size.z || other_pos.z + other.scale.z <= brush_pos.z:
			continue
		else:
			return other
	return null

func create_floor_brush(prev_brush: Node3D, direction: Vector3i) -> Node3D:
	var instance = floor_scene.instantiate()
	add_child(instance)
	
	var new_brush_pos = Vector3i.ZERO
	var new_brush_size = Vector3i(rand_range(min_room_size, max_room_size), 1, rand_range(min_room_size, max_room_size))
	var prev_brush_pos = get_brush_position(prev_brush)

	match direction:
		NORTH:
			new_brush_pos.z = prev_brush_pos.z + prev_brush.scale.z
			new_brush_pos.x = rand_range(prev_brush_pos.x + min_doorway_size - new_brush_size.x, prev_brush_pos.x + prev_brush.scale.x - min_doorway_size)
		EAST:
			new_brush_pos.x = prev_brush_pos.x + prev_brush.scale.x
			new_brush_pos.z = rand_range(prev_brush_pos.z + min_doorway_size - new_brush_size.z, prev_brush_pos.z + prev_brush.scale.z - min_doorway_size)
		SOUTH:
			new_brush_pos.z = prev_brush_pos.z - new_brush_size.z
			new_brush_pos.x = rand_range(prev_brush_pos.x + min_doorway_size - new_brush_size.x, prev_brush_pos.x + prev_brush.scale.x - min_doorway_size)
		WEST:
			new_brush_pos.x = prev_brush_pos.x - new_brush_size.x
			new_brush_pos.z = rand_range(prev_brush_pos.z + min_doorway_size - new_brush_size.z, prev_brush_pos.z + prev_brush.scale.z - min_doorway_size)

	set_brush_scale(instance, new_brush_size)
	set_brush_position(instance, new_brush_pos)
	instance = prevent_overlap(instance, direction)
	
	#prevent brush from being oob
	if new_brush_pos.x + new_brush_size.x > perimeter_width:
		new_brush_size.x = perimeter_width - new_brush_pos.x
	if new_brush_pos.z + new_brush_size.z > perimeter_width:
		new_brush_size.z = perimeter_length - new_brush_pos.z
	
	set_brush_scale(instance, new_brush_size)
	set_brush_position(instance, new_brush_pos)
	return instance

#shrinks the sides if they overlap with other brushes
func prevent_overlap(new_brush : Node3D, source_direction: Vector3i) -> Node3D:
	#dont check the side from the source_direction
	var directions_to_check = directions_arr.duplicate(true)
	directions_to_check.erase(source_direction * -1)
	var new_brush_size = new_brush.scale
	var new_brush_pos = get_brush_position(new_brush)
	for dir in directions_to_check:
		var existing_brush = get_overlapping_brush(new_brush_size, new_brush_pos)
		while existing_brush != null:
			match dir:
				NORTH:
					new_brush_size.z = get_brush_position(existing_brush).z - new_brush_pos.z
				EAST:
					new_brush_size.x = get_brush_position(existing_brush).x - new_brush_pos.x
				SOUTH:
					new_brush_size.z = (new_brush_pos.z + new_brush_size.z) - (get_brush_position(existing_brush).z + existing_brush.scale.z)
					new_brush_pos.z = get_brush_position(existing_brush).z + existing_brush.scale.z
				WEST:
					new_brush_size.x = (new_brush_pos.x + new_brush_size.x) - (get_brush_position(existing_brush).x + existing_brush.scale.x)
					new_brush_pos.x = get_brush_position(existing_brush).x + existing_brush.scale.x
			existing_brush = get_overlapping_brush(new_brush_size, new_brush_pos) #repeat check in case of multiple overlaps
	set_brush_scale(new_brush, new_brush_size)
	set_brush_position(new_brush, new_brush_pos)
	return new_brush

# Gets the point at the bottom left corner of the brush
func get_brush_position(brush: Node3D) -> Vector3i:
	var pos = brush.position
	pos.x -= brush.scale.x / 2
	pos.z -= brush.scale.z / 2
	return pos
	
#always set the scale BEFORE calling set_brush_position
func set_brush_position(brush: Node3D, position: Vector3i):
	position.x += brush.scale.x / 2
	position.z += brush.scale.z / 2
	brush.position = position
	
func set_brush_scale(brush: Node3D, scale: Vector3i):
	print("Setting New Brush Scale: (%s %s %s)" % [scale.x, scale.y, scale.z])
	brush.global_scale(scale)
	
func store_walls():
	pass
	#store wall positions into the array on all four sides of the brush. 
	#if a wall will overlap, check if the overlapping wall covers the entirety of the side.
	# if so, that wall is good.
	# if not, fill in on either side until that side is covered
	#wait, this method wont really work because it assumes walls are constant - but they change if a new room touches an existing wall

func create_doorways():
	pass
	
func generate_walls():
	pass
	
func add_items() -> void:
	pass
	#go one unit by one to make a grid of points
	#if the point is in a room and at least 1 unit away from a wall, 
	#save it, otherwise discard it
	#then place items in random points, removing selected points from list
	#optionally make distance requirement between items

func rand_range(n_min, n_max):
	print(str(n_min) + ", " + str(n_max))
	return (randi() % (int(n_max) - int(n_min))) + int(n_min)

	
	
	
