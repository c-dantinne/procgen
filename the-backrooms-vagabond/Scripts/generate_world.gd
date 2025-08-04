extends Node

# we make calculations with brushes assuming that (0,0,0) is the bottom left of the perimeter
# since godot places brushes at their center, we have specific methods for getting and setting position which place brushes correctly

const floor_scene = preload("res://Scenes/floor.tscn")

@export var perimeter_width : int = 300
@export var perimeter_length : int = 300
@export var perimeter_buffer : int = 100

@export var min_room_size : int = 10
@export var max_room_size : int = 20
#@export var min_hallway_width = 500
#@export var max_hallway_width = 500
#@export var min_hallway_length = 500
#@export var max_hallway_length = 500
@export var min_doorway_size : int = 3
@export var min_surface_area : int = 1500

const NORTH := Vector3i(0, 0, 1)
const EAST := Vector3i(1, 0, 0)
const SOUTH := Vector3i(0, 0, -1)
const WEST := Vector3i(-1, 0, 0)
const directions_arr : Array[Vector3i] = [NORTH, EAST, SOUTH, WEST]

var world_seed : int = 0

var floor_brushes : Array[Node3D] = []
var wall_brushes : Array[Node3D] = []

#
var inner_perimeter_width : int = perimeter_width - perimeter_buffer
var inner_perimeter_length : int = perimeter_length - perimeter_buffer
var current_surface_area : int = 0
var directions_available : Array[Vector3i] = directions_arr.duplicate(true)
var current_brush_index : int = 0
var brushes_with_adjacent_space : Array[Node3D] = []

func _ready() -> void:
	assert(min_doorway_size <= float(min_room_size) / 2.0)
	
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
	#test_get_brush_position()
	#test_set_brush_position()
	#test_get_overlapping_brush()
	#test_is_adjacent_space_available()
	
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		test_gen_next_room()


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
	
func test_get_brush_position():
	var instance = floor_scene.instantiate()
	var a : Vector3
	add_child(instance)
	instance.scale = Vector3i(5, 1, 5)
	instance.position = Vector3(2.5, 0, 2.5)
	a = get_brush_position(instance)
	print("get_brush_position() Test 1. Expected: 0 0 0 | Actual: %s %s %s" % [a.x, a.y, a.z])
	
	instance.scale = Vector3i(10, 1, 10)
	instance.position = Vector3(17, 0, 29)
	a = get_brush_position(instance)
	print("get_brush_position() Test 2. Expected: 12 0 24 | Actual: %s %s %s" % [a.x, a.y, a.z])
	
	instance.scale = Vector3i(33, 1, 17)
	instance.position = Vector3(31, 0, 38)
	a = get_brush_position(instance)
	print("get_brush_position() Test 2. Expected: 14.5 0 29.5 | Actual: %s %s %s" % [a.x, a.y, a.z])
	
	instance.queue_free()
	
func test_set_brush_position():
	var instance = floor_scene.instantiate()
	var a : Vector3
	var new_pos : Vector3i
	add_child(instance)
	
	instance.scale = Vector3i(5, 1, 5)
	new_pos = Vector3(5, 0, 5)
	set_brush_position(instance, new_pos)
	print("set_brush_position() Test 1. Expected: 7.5 0 7.5 | Actual: %s %s %s" % [instance.position.x, instance.position.y, instance.position.z])
	
	instance.queue_free()
	
func test_get_overlapping_brush():
	var a = floor_scene.instantiate()
	var b = floor_scene.instantiate()
	var c = floor_scene.instantiate()
	var d = floor_scene.instantiate()
	var result = null
	var res_dir : Array[Vector3i] = []
	add_child(a)
	a.scale = Vector3i(5, 1, 5)
	set_brush_position(a, Vector3(10, 0, 10))
	floor_brushes.append(a)
	
	#test no overlap
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(5, 0, 5), res_dir)
	print("get_overlapping_brush() Test 1. Expected: null | Actual: ")
	print(result)
	print(res_dir)
	
	#test corner overlap
	result = get_overlapping_brush(Vector3i(6, 1, 6), Vector3i(5, 0, 5), res_dir)
	print("get_overlapping_brush() Test 2. Expected: not null | Actual: ")
	print(result)
	print(res_dir)
	
	#test full overlap
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(10, 0, 10), res_dir)
	print("get_overlapping_brush() Test 3. Expected: not null | Actual: ")
	print(result)
	print(res_dir)
	
	#test adjacent west
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(5, 0, 10), res_dir)
	print("get_overlapping_brush() Test 4. Expected: null | Actual: ")
	print(result)
	print(res_dir)
	
	#test overlap west
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(6, 0, 10), res_dir)
	print("get_overlapping_brush() Test 5. Expected: not null | Actual: ")
	print(result)
	print(res_dir)
	
	#test adjacent north
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(10, 0, 15), res_dir)
	print("get_overlapping_brush() Test 6. Expected: null | Actual: ")
	print(result)
	print(res_dir)
	
	#test overlap north
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(10, 0, 14), res_dir)
	print("get_overlapping_brush() Test 7. Expected: not null | Actual: ")
	print(result)
	print(res_dir)
	
	#test adjacent east
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(15, 0, 10), res_dir)
	print("get_overlapping_brush() Test 8. Expected: null | Actual: ")
	print(result)
	print(res_dir)
	
	#test overlap east
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(14, 0, 10), res_dir)
	print("get_overlapping_brush() Test 9. Expected: not null | Actual: ")
	print(result)
	print(res_dir)
	
	#test adjacent south
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(10, 0, 5), res_dir)
	print("get_overlapping_brush() Test 10. Expected: null | Actual: ")
	print(result)
	print(res_dir)
	
	#test overlap south
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(10, 0, 6), res_dir)
	print("get_overlapping_brush() Test 11. Expected: not null | Actual: ")
	print(result)
	print(res_dir)
	return
	#test overlap on all sides
	add_child(b)
	add_child(c)
	add_child(d)
	a.scale = Vector3i(5, 1, 5)
	set_brush_position(a, Vector3(9, 0, 5))
	b.scale = Vector3i(5, 1, 5)
	set_brush_position(b, Vector3(5, 0, 9))
	c.scale = Vector3i(5, 1, 5)
	set_brush_position(c, Vector3(1, 0, 5))
	d.scale = Vector3i(5, 1, 5)
	set_brush_position(d, Vector3(5, 0, 1))
	floor_brushes.append(b)
	floor_brushes.append(c)
	floor_brushes.append(d)
	var num_overlaps = 0
	result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(5, 0, 5), res_dir)
	print("get_overlapping_brush() Test 12. Overlaps: ")
	while result:
		num_overlaps += 1
		set_brush_position(result, Vector3(-100, 0, -100))
		result = get_overlapping_brush(Vector3i(5, 1, 5), Vector3i(5, 0, 5), res_dir)
		if result:
			print(result)
		
	print("get_overlapping_brush() Test 12. Expected #: 4 | Actual: %s" % str(num_overlaps))
	a.queue_free()
	b.queue_free()
	c.queue_free()
	d.queue_free()
	
func test_is_adjacent_space_available():
	var a = floor_scene.instantiate()
	var b = floor_scene.instantiate()
	var result : bool
	add_child(a)
	add_child(b)
	a.scale = Vector3i(min_room_size, 1, min_room_size)
	set_brush_position(a, Vector3(100, 0, 100))
	floor_brushes.append(a)
	floor_brushes.append(b)
	
	#test available west
	b.scale = Vector3i(5, 1, 5)
	set_brush_position(b, Vector3(100 - min_room_size - b.scale.x, 0, 100))
	result = is_adjacent_space_available(a, WEST)
	print("is_adjacent_space_available Test 1. Expected: true | Actual: " + str(result))
	
	#test unavailable west
	set_brush_position(b, Vector3(100 - min_room_size, 0, 100))
	result = is_adjacent_space_available(a, WEST)
	print("is_adjacent_space_available Test 2. Expected: false | Actual: " + str(result))
	
	#test available north
	set_brush_position(b, Vector3(100, 0, 100 + min_room_size + a.scale.z))
	result = is_adjacent_space_available(a, NORTH)
	print("is_adjacent_space_available Test 3. Expected: true | Actual: " + str(result))
	
	#test unavailable north
	set_brush_position(b, Vector3(100, 0, 100 + min_room_size + a.scale.z - b.scale.z))
	result = is_adjacent_space_available(a, NORTH)
	print("is_adjacent_space_available Test 4. Expected: false | Actual: " + str(result))
	
	#test available east
	set_brush_position(b, Vector3(100 + min_room_size + a.scale.x, 0, 100))
	result = is_adjacent_space_available(a, EAST)
	print("is_adjacent_space_available Test 5. Expected: true | Actual: " + str(result))
	
	#test unavailable east
	set_brush_position(b, Vector3(100 + min_room_size + a.scale.x - b.scale.x, 0, 100))
	result = is_adjacent_space_available(a, EAST)
	print("is_adjacent_space_available Test 6. Expected: false | Actual: " + str(result))
	
	#test available south
	set_brush_position(b, Vector3(100, 0, 100 - min_room_size - b.scale.z))
	result = is_adjacent_space_available(a, SOUTH)
	print("is_adjacent_space_available Test 7. Expected: true | Actual: " + str(result))
	
	#test unavailable south
	set_brush_position(b, Vector3(100, 0, 100 - min_room_size))
	result = is_adjacent_space_available(a, SOUTH)
	print("is_adjacent_space_available Test 8. Expected: false | Actual: " + str(result))
	
	#test available by perimeter
	
	#test unavailable by perimeter
	
	#test available on one side
	set_brush_position(b, Vector3(100, 0, 100 - min_room_size))
	result = is_adjacent_space_available(a, SOUTH)
	print("is_adjacent_space_available Test 11. Expected: false | Actual: " + str(result))
	
	#the problem MUST be with the way im using directions
	
	var c = floor_scene.instantiate()
	var d = floor_scene.instantiate()
	add_child(c)
	add_child(d)
	c.scale = Vector3i(min_room_size, 1, min_room_size)
	set_brush_position(a, Vector3(100, 0, 100))
	floor_brushes.append(a)
	floor_brushes.append(b)
	
	a.queue_free()
	b.queue_free()
	
#a test function to click and add rooms of defined size, position, and/or direction
func test_add_next_room():
	#first, pre-defined direction
	var a = floor_scene.instantiate()
	add_child(a)
	a.scale = Vector3i(min_room_size, 1, min_room_size)
	set_brush_position(a, Vector3(100, 0, 100))
	floor_brushes.append(a)
	
func test_gen_next_room():
		# 4. Pick a random side of selected room that does not touch the perimeter.
	# 	 Backtrack brush floors until we can find adjacent space
	var adjacent_space_found = false
	while not adjacent_space_found:
		directions_available.shuffle()
		for dir in directions_available:
			if is_adjacent_space_available(brushes_with_adjacent_space[current_brush_index], dir):
				#print("Adjacent space found to the %v" % dir)
				adjacent_space_found = true
				var new_brush = create_floor_brush(brushes_with_adjacent_space[current_brush_index], dir)
				brushes_with_adjacent_space.append(new_brush)
				floor_brushes.append(new_brush)
				current_surface_area += new_brush.scale.x * new_brush.scale.y
				break
		if not adjacent_space_found:
			current_brush_index -= 1
		else:
			current_brush_index = len(brushes_with_adjacent_space) - 1
			print("current index: " + str(current_brush_index))
		if current_brush_index < 0:
			printerr("ERROR: No adjacent space available before minimum surface area reached. Seed: " + str(seed))
			return
	
func make_world() -> void:
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
	return
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
				if other_brush_pos.z < z && other_brush_pos.z + other_brush.scale.z > desired_z:
					if other_brush_pos.x + other_brush.scale.x > x && other_brush_pos.x < x + current_brush.scale.x:
						return false
			WEST:
				if other_brush_pos.x < x && other_brush_pos.x + other_brush.scale.x > desired_x:
					if other_brush_pos.z + other_brush.scale.z > z && other_brush_pos.z < z + current_brush.scale.z:
						return false
	return true

#side effect: sets an array of the direction in which an overlap occurs, or an empty array if there are no overlaps
# must be an array because arrays are passed by reference
func get_overlapping_brush(brush_size: Vector3i, brush_pos: Vector3i, ref_direction_to_brush: Array[Vector3i], ignored_direction = null) -> Node3D:
	ref_direction_to_brush.clear()
	for other in floor_brushes:
		var other_pos = get_brush_position(other)
		var brush_center_pos : Vector3 = brush_pos
		brush_center_pos.x += brush_size.x / 2.0
		brush_center_pos.z += brush_size.z / 2.0
		if other_pos.x >= brush_pos.x + brush_size.x || other_pos.x + other.scale.x <= brush_pos.x || other_pos.z >= brush_pos.z + brush_size.z || other_pos.z + other.scale.z <= brush_pos.z:
			continue
		else:
			if other.position.x < brush_center_pos.x:
				ref_direction_to_brush.append(WEST)
			elif other.position.x > brush_center_pos.x:
				ref_direction_to_brush.append(EAST)
			elif other.position.z < brush_center_pos.z:
				ref_direction_to_brush.append(SOUTH)
			elif other.position.z > brush_center_pos.z:
				ref_direction_to_brush.append(NORTH)
			else: #default to north. should only occur during full overlap
				ref_direction_to_brush.append(NORTH)
				printerr("WARNING: FULL OVERLAP DETECTED")
			if ref_direction_to_brush[0] == ignored_direction:
				return null
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
	source_direction *= -1
	var new_brush_size = new_brush.scale
	var new_brush_pos = get_brush_position(new_brush)
	var directions_to_check : Array[Vector3i] = []
	var existing_brush = get_overlapping_brush(new_brush_size, new_brush_pos, directions_to_check, source_direction)
	while existing_brush:
		for dir in directions_to_check:
			print(dir)
			if dir == source_direction: #skip checking where we came from
				print("skipping")
				continue 
			match dir: 
				NORTH:
					print("changing north")
					new_brush_size.z = get_brush_position(existing_brush).z - new_brush_pos.z
				EAST:
					print("changing east")
					new_brush_size.x = get_brush_position(existing_brush).x - new_brush_pos.x
				SOUTH:
					print("changing south")
					new_brush_size.z = (new_brush_pos.z + new_brush_size.z) - (get_brush_position(existing_brush).z + existing_brush.scale.z)
					new_brush_pos.z = get_brush_position(existing_brush).z + existing_brush.scale.z
				WEST:
					print("changing west")
					new_brush_size.x = (new_brush_pos.x + new_brush_size.x) - (get_brush_position(existing_brush).x + existing_brush.scale.x)
					new_brush_pos.x = get_brush_position(existing_brush).x + existing_brush.scale.x
		existing_brush = get_overlapping_brush(new_brush_size, new_brush_pos, directions_to_check, source_direction) #repeat check in case of multiple overlaps
	set_brush_scale(new_brush, new_brush_size)
	set_brush_position(new_brush, new_brush_pos)
	return new_brush

# Gets the point at the bottom left corner of the brush
func get_brush_position(brush: Node3D) -> Vector3:
	var pos = brush.position
	pos.x -= brush.scale.x / 2.0
	pos.z -= brush.scale.z / 2.0
	return pos
	
#always set the scale BEFORE calling set_brush_position
func set_brush_position(brush: Node3D, position: Vector3):
	if brush.scale.x < 0.1:
		printerr("ERROR BRUSH SCALE NOT SET")
	#assert(brush.scale.x > 0.1)
	position.x += brush.scale.x / 2.0
	position.z += brush.scale.z / 2.0
	brush.position = position
	
func set_brush_scale(brush: Node3D, scale: Vector3i):
	#print("Setting New Brush Scale: (%s %s %s)" % [scale.x, scale.y, scale.z])
	brush.scale = scale
	
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

	
	
	
