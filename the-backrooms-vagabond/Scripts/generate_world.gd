extends Node

# we make calculations with brushes assuming that (0,0,0) is the bottom left of the perimeter
# since godot places brushes at their center, we have specific methods for getting and setting position which place brushes correctly

const floor_scene = preload("res://Scenes/brush.tscn")

@export var perimeter_width : int = 2000
@export var perimeter_length : int = 2000
@export var perimeter_buffer : int = 100

@export var min_room_size : int = 16
@export var max_room_size : int = 80
#@export var min_hallway_width = 500
#@export var max_hallway_width = 500
#@export var min_hallway_length = 500
#@export var max_hallway_length = 500
@export var min_doorway_size : int = 8
@export var min_surface_area : int = 20000

const NORTH := Vector3i(0, 0, 1)
const EAST := Vector3i(1, 0, 0)
const SOUTH := Vector3i(0, 0, -1)
const WEST := Vector3i(-1, 0, 0)
const directions_arr : Array[Vector3i] = [NORTH, EAST, SOUTH, WEST]
const WALL_HEIGHT = 10
const EPSILON : float = 0.000001

var world_seed : int = 0410

var floor_brushes : Array[Brush] = []
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
	Engine.print_error_messages = false
	if !world_seed:
		world_seed = randi()
	seed(world_seed) #todo show seed on ui
	#test_add_next_room_setup()
	
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
	#test_create_doorway()
	
	get_tree().root.get_node("Main").get_node("Player").position = floor_brushes[0].position
	get_tree().root.get_node("Main").get_node("Compass").position = floor_brushes[0].position
	
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		pass
		#test_manually_gen_next_room()
		#test_add_next_room()


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
var test_dirs = [NORTH, NORTH, EAST, SOUTH, SOUTH, WEST]
var test_dirs_index = 0
var test_brush_list_index = 0
func test_add_next_room_setup():
	var a = floor_scene.instantiate()
	add_child(a)
	a.scale = Vector3i(min_room_size, 1, min_room_size)
	set_brush_position(a, Vector3(100, 0, 100))
	floor_brushes.append(a)
	
func test_add_next_room():
	#first, pre-defined direction
	if test_dirs_index < len(test_dirs):
		if is_adjacent_space_available(floor_brushes[test_brush_list_index], test_dirs[test_dirs_index]):
			print("test_add_next_room: adjacent space available")
		else:
			print("test_add_next_room: adjacent space not available")
			
		#adjacent space seems to be working great
			
		var new_brush = create_floor_brush(floor_brushes[test_brush_list_index], test_dirs[test_dirs_index])
		test_brush_list_index += 1
		brushes_with_adjacent_space.append(new_brush)
		floor_brushes.append(new_brush)
		test_dirs_index += 1

	
func test_manually_gen_next_room():
		# 4. Pick a random side of selected room that does not touch the perimeter.
	# 	 Backtrack brush floors until we can find adjacent space
	var adjacent_space_found = false
	while not adjacent_space_found:
		directions_available.shuffle()
		for dir in directions_available:
			if is_adjacent_space_available(brushes_with_adjacent_space[current_brush_index], dir):
				var new_brush = create_floor_brush(brushes_with_adjacent_space[current_brush_index], dir)
				if new_brush:
					adjacent_space_found = true
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
	# 2. Generate a rectangular floor with a random size between min and max.
	# 3. If floor overlaps perimeter, shrink that side to fix.
	# 5. Generate another rectangular floor. 70% probability of being a hallway, 30% being a room.
	# 6. Shrink new room if overlapping perimeter or another floor.
	# 7. Check if we are at minimum surface area. If so, proceed to generate walls.
	# 8. Else, repeat floor generation.
	var starting_point := Vector3i(rand_range(perimeter_buffer, inner_perimeter_width), 0, rand_range(perimeter_buffer, inner_perimeter_length))
	var instance = floor_scene.instantiate()
	add_child(instance)
	var floor_size = Vector3i(rand_range(min_room_size, max_room_size), 1, rand_range(min_room_size, max_room_size))
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
					var new_brush = create_floor_brush(brushes_with_adjacent_space[current_brush_index], dir)
					if new_brush:
						adjacent_space_found = true
						brushes_with_adjacent_space.append(new_brush)
						floor_brushes.append(new_brush)
						current_surface_area += new_brush.scale.x * new_brush.scale.y
						break
			if not adjacent_space_found:
				current_brush_index -= 1
			else:
				current_brush_index = len(brushes_with_adjacent_space) - 1
				#print("current index: " + str(current_brush_index))
			if current_brush_index < 0:
				#printerr("ERROR: No adjacent space available before minimum surface area reached. Seed: " + str(seed))
				return

	generate_ceilings()
	generate_walls()
	get_neighbors_for_all_brushes()
	create_doorways_full()
	
	var num_broken = 0
	for brush in floor_brushes:
		if brush.scale.x == 0 || brush.scale.z == 0:
			num_broken += 1
	print("num broken: " + str(num_broken))
	
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
			if other.position.x < brush_center_pos.x && ignored_direction != WEST:
				ref_direction_to_brush.append(WEST)
				#print("overlap detected - shrinking on the WEST side")
			elif other.position.x > brush_center_pos.x && ignored_direction != EAST:
				ref_direction_to_brush.append(EAST)
				#print("overlap detected - shrinking on the EAST side")
			elif other.position.z < brush_center_pos.z && ignored_direction != SOUTH:
				ref_direction_to_brush.append(SOUTH)
				#print("overlap detected - shrinking on the SOUTH side")
			elif other.position.z > brush_center_pos.z && ignored_direction != NORTH:
				ref_direction_to_brush.append(NORTH)
				#print("overlap detected - shrinking on the NORTH side")
			else: #default to NORTH. should only occur during full overlap. pray it wont crash
				ref_direction_to_brush.append(NORTH)
				#printerr("WARNING: FULL OVERLAP DETECTED")
			#if ref_direction_to_brush[0] == ignored_direction: #continue to next brush
				#print("overlap detected - but its on the ignored direction")
				#continue
			if ref_direction_to_brush.size() > 0:
				return other
	return null

#returns null if brush failed to generate
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
	
	#var t = get_brush_position(instance)
	#print("pos before: %s %s %s" % [t.x, t.y, t.z])
	#print("size before: %s %s %s" % [instance.scale.x, instance.scale.y, instance.scale.z])
	
	instance = prevent_overlap(instance, direction)
	new_brush_pos = get_brush_position(instance)
	new_brush_size = instance.scale
	
	#failed to generate
	if instance.scale.x < 1.0 || instance.scale.z < 1.0:
		instance.queue_free()
		return null
	
	#t = get_brush_position(instance)
	#print("pos after: %s %s %s" % [t.x, t.y, t.z])
	#print("size after: %s %s %s" % [instance.scale.x, instance.scale.y, instance.scale.z])
	
	#prevent brush from being oob
	#if new_brush_pos.x + new_brush_size.x > perimeter_width:
		#new_brush_size.x = perimeter_width - new_brush_pos.x
	#if new_brush_pos.z + new_brush_size.z > perimeter_width:
		#new_brush_size.z = perimeter_length - new_brush_pos.z
	if new_brush_pos.x + new_brush_size.x > perimeter_width || new_brush_pos.z + new_brush_size.z > perimeter_width || new_brush_pos.x < 0 || new_brush_pos.z < 0:
		instance.queue_free()
		return null
	
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
				_: #needed for when get_overlapping_brush detects the ignored direction
					pass
		existing_brush = get_overlapping_brush(new_brush_size, new_brush_pos, directions_to_check, source_direction) #repeat check in case of multiple overlaps
	set_brush_scale(new_brush, new_brush_size)
	set_brush_position(new_brush, new_brush_pos)
	return new_brush

# Gets the point at the bottom left corner of the brush
func get_brush_position(brush: Node3D) -> Vector3:
	var pos = brush.position
	pos.x -= brush.scale.x / 2.0
	pos.y -= brush.scale.y / 2.0
	pos.z -= brush.scale.z / 2.0
	return pos
	
#always set the scale BEFORE calling set_brush_position
func set_brush_position(brush: Node3D, position: Vector3):
	if brush.scale.x < 0.1:
		pass
		#printerr("ERROR BRUSH SCALE NOT SET")
	#assert(brush.scale.x > 0.1)
	position.x += brush.scale.x / 2.0
	position.z += brush.scale.z / 2.0
	position.y += brush.scale.y / 2.0
	brush.position = position
	
func set_brush_scale(brush: Node3D, scale: Vector3i):
	#print("Setting New Brush Scale: (%s %s %s)" % [scale.x, scale.y, scale.z])
	brush.scale = scale

func create_doorways_linear():
	#check if room has doors already
	#if not, create one
	#then check other walls where rooms touch but have no connections
	#50% chance of adding a door there
	
	pass
	
func create_doorways_isolated():
	#check if room has doors already
	#if not, create one
	#then check other walls where rooms touch but have no connections
	#50% chance of adding a door there
	
	pass
	
func create_doorways_full():
	for brush in floor_brushes:
		for neighbor in brush.neighbors:
			if not neighbor["is_connected"]:
				create_doorway(brush, neighbor)
	
func test_create_doorway():
	var a = floor_scene.instantiate()
	add_child(a)
	a.scale = Vector3(20, 1, 30)
	set_brush_position(a, Vector3(40, 0, 40))
	floor_brushes.append(a)
	a.name = "Brush a"
	
	var b = floor_scene.instantiate()
	add_child(b)
	b.scale = Vector3(20, 1, 10)
	set_brush_position(b, Vector3(30, 0, 30))
	floor_brushes.append(b)
	b.name = "Brush b"
	
	var c = floor_scene.instantiate()
	add_child(c)
	c.scale = Vector3(5, 1, 5)
	set_brush_position(c, Vector3(35, 0, 45))
	floor_brushes.append(c)
	c.name = "Brush c"
	
	generate_ceilings()
	generate_walls()
	get_neighbors_for_all_brushes()
	create_doorways_full()
	
func create_doorway(brush : Brush, neighbor : Dictionary):
	var other_brush_neighbors = neighbor["neighbor"].neighbors
	var corresponding_neighbor = null
	var brush_pos = get_brush_position(brush)
	var other_pos = get_brush_position(neighbor["neighbor"])
	var other_scale = neighbor["neighbor"].scale
	for n in other_brush_neighbors:
		if n["neighbor"] == brush:
			corresponding_neighbor = n
	assert(corresponding_neighbor != null)
	var inner_min #the edges where the brushes connect
	var inner_max
	var doorway_min : float
	var doorway_max : float
	var doorway_size
	var remaining_space
	var offset
	match neighbor["dir_to_neighbor"]:
		#the inner_min and inner_max are the shortest distance between a.x1 - a.x2, b.x1 - b.x2, a.x1 - b.x2, a.x2 - b.x1
		NORTH, SOUTH: #add 1 to account for wall thickness (1 unit)
			var m = min(abs(brush_pos.x - (brush_pos.x + brush.scale.x)), abs(other_pos.x - (other_pos.x + other_scale.x)), abs(brush_pos.x - (other_pos.x + other_scale.x)), abs(other_pos.x - (brush_pos.x + brush.scale.x)))
			if m == abs(brush_pos.x - (brush_pos.x + brush.scale.x)):
				inner_min = brush_pos.x + 1
				inner_max = (brush_pos.x + brush.scale.x) - 1
			elif m == abs(other_pos.x - (other_pos.x + other_scale.x)):
				inner_min = other_pos.x + 1
				inner_max = (other_pos.x + other_scale.x) - 1
			elif m == abs(brush_pos.x - (other_pos.x + other_scale.x)):
				inner_min = brush_pos.x + 1
				inner_max = (other_pos.x + other_scale.x) - 1
			else:
				inner_min = other_pos.x + 1
				inner_max = (brush_pos.x + brush.scale.x) - 1
		EAST, WEST: #add 2 to account for E + W walls being shorter than N + S
			var m = min(abs(brush_pos.z - (brush_pos.z + brush.scale.z)), abs(other_pos.z - (other_pos.z + other_scale.z)), abs(brush_pos.z - (other_pos.z + other_scale.z)), abs(other_pos.z - (brush_pos.z + brush.scale.z)))
			if m == abs(brush_pos.z - (brush_pos.z + brush.scale.z)):
				inner_min = brush_pos.z + 2
				inner_max = (brush_pos.z + brush.scale.z) - 2
			elif m == abs(other_pos.z - (other_pos.z + other_scale.z)):
				#print("brush.name: " + brush.name)
				#print("neighbor[neighbor].name: " + neighbor["neighbor"].name)
				inner_min = other_pos.z + 2
				inner_max = (other_pos.z + other_scale.z) - 2
				#print("inner_min: " + str(inner_min))
				#print("inner_max: " + str(inner_max))
			elif m == abs(brush_pos.z - (other_pos.z + other_scale.z)):
				inner_min = brush_pos.z + 2
				inner_max = (other_pos.z + other_scale.z) - 2
			else:
				inner_min = other_pos.z + 2
				inner_max = (brush_pos.z + brush.scale.z) - 2
		_:
			printerr("Invalid dir_to_neighbor!")
			
	# Calculate door positions		
	if inner_max - inner_min > min_doorway_size:
		doorway_size = rand_range(min_doorway_size, inner_max - inner_min)
		remaining_space = inner_max - inner_min - doorway_size
		offset = rand_range(1, remaining_space)
	else:
		offset = 0
		remaining_space = 0
	#if remaining_space <= 0:
		#remaining_space = 0
		#offset = 0
	#else:
		#offset = rand_range(1, remaining_space)
	
	doorway_min = inner_min + offset
	doorway_max = inner_max - (remaining_space - offset)
	
	for i in range(2):
		#repeat wall splitting on neighbor brush, simply reverse the direction
		var current_neighbor
		var current_brush
		var new_wall = floor_scene.instantiate()
		add_child(new_wall)
		if i == 0:
			current_neighbor = neighbor
			current_brush = brush
		else:
			current_neighbor = corresponding_neighbor
			current_brush = neighbor["neighbor"]
		
		# Get correct wall to split TODO - what about scenario where two neighbors are adjacent? need to think it through, maybe write test
		var existing_walls
		var wall_to_split = null
		match current_neighbor["dir_to_neighbor"]:
			NORTH:
				existing_walls = current_brush.walls_n
				current_brush.walls_n.append(new_wall)
			EAST:
				existing_walls = current_brush.walls_e
				current_brush.walls_e.append(new_wall)
			SOUTH:
				existing_walls = current_brush.walls_s
				current_brush.walls_s.append(new_wall)
			WEST:
				existing_walls = current_brush.walls_w
				current_brush.walls_w.append(new_wall)
				
		for wall in existing_walls:
			var wall_pos = get_brush_position(wall)
			match current_neighbor["dir_to_neighbor"]:
				NORTH, SOUTH:
					if wall_pos.x <= doorway_min && wall_pos.x + wall.scale.x >= doorway_max:
						wall_to_split = wall
				EAST, WEST:
					if wall_pos.z <= doorway_min && wall_pos.z + wall.scale.z >= doorway_max:
						wall_to_split = wall
					#else:
						#print()
						#print(wall_pos.z)
						#print(wall.scale.z)
			
		if wall_to_split == null:
			if inner_min == doorway_min && inner_max == doorway_max:
				return
			printerr("ERROR: WALL_TO_SPLIT IS NULL. MALFORMED WALLS GENERATED.")
			wall_to_split = existing_walls[0]
			#print("iteration: " + str(i))
			#print(current_brush)
			#print("inner_min: " + str(inner_min))
			#print("inner_max: " + str(inner_max))
			#print("doorway_min: " + str(doorway_min))
			#print("doorway_max: " + str(doorway_max))
			#print(current_neighbor)
			#print(current_neighbor["neighbor"].name)
			#print(existing_walls[0].scale)
			#print("ASSERTION")
			#print()
			#assert(wall_to_split != null)
			
		
		#the problem is that brush a is making a doorway thats bigger than brush c's entire wall
		#we need to consider brush c's size in the doorway calculations
		
		#the new problem is that west and east have walls 1 unit shorter on each side lengthwise!
		
		#Split the wall in two, 
		var wall_prev_pos = get_brush_position(wall_to_split)
		var wall_prev_size = wall_to_split.scale
		var old_wall_new_pos = wall_prev_pos
		new_wall.scale = wall_to_split.scale
		set_brush_position(new_wall, wall_prev_pos)
		new_wall.name = wall_to_split.name + " NEW"
		match current_neighbor["dir_to_neighbor"]:
			NORTH, SOUTH:
				#if abs((wall_prev_pos.x + wall_prev_size.x) - doorway_max) < EPSILON:
					#wall_to_split.queue_free() #only necessary if doorway_min/max offsets are 0
				#else:
				#if doorway_min - wall_prev_pos.x < EPSILON:
				wall_to_split.scale.x = (wall_prev_pos.x + wall_prev_size.x) - doorway_max
				old_wall_new_pos.x = doorway_max
				set_brush_position(wall_to_split, old_wall_new_pos)
				
				new_wall.scale.x = doorway_min - wall_prev_pos.x
				set_brush_position(new_wall, wall_prev_pos)
			EAST ,WEST:
				wall_to_split.scale.z = (wall_prev_pos.z + wall_prev_size.z) - doorway_max
				old_wall_new_pos.z = doorway_max
				set_brush_position(wall_to_split, old_wall_new_pos)
				
				new_wall.scale.z = doorway_min - wall_prev_pos.z
				set_brush_position(new_wall, wall_prev_pos)
		current_neighbor["is_connected"] = true
		
		if wall_to_split.scale.x <= 0 || wall_to_split.scale.z <= 0:
			#print(wall_to_split.name)
			#print("inner_min: " + str(inner_min))
			#print("inner_max: " + str(inner_max))
			#print("doorway_min: " + str(doorway_min))
			#print("doorway_max: " + str(doorway_max))
			#assert(false)
			wall_to_split.queue_free()
		if new_wall.scale.x <= 0 || new_wall.scale.z <= 0:
			#print(new_wall.name)
			#print("inner_min: " + str(inner_min))
			#print("inner_max: " + str(inner_max))
			#print("doorway_min: " + str(doorway_min))
			#print("doorway_max: " + str(doorway_max))
			#assert(false)
			new_wall.queue_free()
		
			
func generate_walls():
	var pos
	for brush in floor_brushes:
		for dir in directions_arr:
			var wall = floor_scene.instantiate()
			add_child(wall)
			match dir:
				NORTH:
					wall.scale.x = brush.scale.x
					wall.scale.y = WALL_HEIGHT
					wall.scale.z = 1
					pos = get_brush_position(brush)
					pos.y += 1
					pos.z += brush.scale.z - 1
					set_brush_position(wall, pos)
					brush.walls_n.append(wall)
					wall.name = brush.name + " North Wall"
				EAST:
					wall.scale.x = 1
					wall.scale.y = WALL_HEIGHT
					wall.scale.z = brush.scale.z - 2
					pos = get_brush_position(brush)
					pos.z += 1
					pos.y += 1
					pos.x += brush.scale.x - 1
					set_brush_position(wall, pos)
					brush.walls_e.append(wall)
					wall.name = brush.name + " East Wall"
				SOUTH:
					wall.scale.x = brush.scale.x
					wall.scale.y = WALL_HEIGHT
					wall.scale.z = 1
					pos = get_brush_position(brush)
					pos.y += 1
					set_brush_position(wall, pos)
					brush.walls_s.append(wall)
					wall.name = brush.name + " South Wall"
				WEST:
					wall.scale.x = 1
					wall.scale.y = WALL_HEIGHT
					wall.scale.z = brush.scale.z - 2
					pos = get_brush_position(brush)
					pos.z += 1
					pos.y += 1
					set_brush_position(wall, pos)
					brush.walls_w.append(wall)
					wall.name = brush.name + " West Wall"
	
func get_neighbors_for_all_brushes():
	var pos
	for brush in floor_brushes:
		pos = get_brush_position(brush)
		for other in floor_brushes:
			if other == brush:
				continue
			var other_pos = get_brush_position(other)
			for dir in directions_arr:
				match dir:
					NORTH: 
						if abs(other_pos.z - (pos.z + brush.scale.z)) > EPSILON || other_pos.x + other.scale.x < pos.x + min_doorway_size || other_pos.x > pos.x + brush.scale.x - min_doorway_size:
							continue
					EAST:
						if abs(other_pos.x - (pos.x + brush.scale.x)) > EPSILON || other_pos.z + other.scale.z < pos.z + min_doorway_size || other_pos.z > pos.z + brush.scale.z - min_doorway_size:
							continue
					SOUTH:
						if abs((other_pos.z + other.scale.z) - pos.z) > EPSILON || other_pos.x + other.scale.x < pos.x + min_doorway_size || other_pos.x > pos.x + brush.scale.x - min_doorway_size:
							continue
					WEST:
						if abs((other_pos.x + other.scale.x) - pos.x) > EPSILON || other_pos.z + other.scale.z < pos.z + min_doorway_size || other_pos.z > pos.z + brush.scale.z - min_doorway_size:
							continue
					_:
						continue
				var duplicate_entry = false
				for neighbor in brush.neighbors:
					if neighbor["neighbor"] == other:
						duplicate_entry = true
						continue
				if not duplicate_entry:
					brush.neighbors.append({"neighbor": other, "is_connected": false, "dir_to_neighbor": dir})
		#print(brush)
		#for n in brush.neighbors:
			#print(n)

func generate_ceilings():
	var brushes_to_remove = []
	for brush in floor_brushes:
		#remove invalid brushes
		if brush.scale.x <= 3 || brush.scale.z <= 3:
			brushes_to_remove.append(brush)
		else:
			var ceiling = floor_scene.instantiate()
			add_child(ceiling)
			ceiling.scale = brush.scale
			ceiling.position = brush.position + Vector3(0, WALL_HEIGHT + 1, 0)
			ceiling.name = brush.name + " Ceiling"
	for brush in brushes_to_remove:
		floor_brushes.erase(brush)
		brush.queue_free()
		

	
func add_items() -> void:
	var items
	var accessible_floor_brushes = []
	for brush in floor_brushes:
		if brush.scale.x > min_doorway_size && brush.scale.z > min_doorway_size:
			accessible_floor_brushes.append(brush)
	for item in items:
		pass
	#go one unit by one to make a grid of points
	#if the point is in a room and at least 1 unit away from a wall, 
	#save it, otherwise discard it
	#then place items in random points, removing selected points from list
	#optionally make distance requirement between items

func rand_range(n_min, n_max):
	#print(str(n_min) + ", " + str(n_max))
	#n_min inclusive, n_max exclusive
	if n_min == n_max:
		return n_min
	return (randi() % (int(n_max) - int(n_min))) + int(n_min)

	
	
	
