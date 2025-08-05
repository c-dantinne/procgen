class_name Brush extends Node3D

# walls belonging to this brush, by cardinal direction
var walls_n : Array[Node3D] = []
var walls_e : Array[Node3D] = []
var walls_s : Array[Node3D] = []
var walls_w : Array[Node3D] = []

# neighbors that touch this brush. 
# set is_connected to true if a door connects the two.
# dir_to_neighbor is the vector direction to that neighbor from Brush
# format: [{ neighbor : Brush, is_connected : Bool, dir_to_neighbor : Vector3i}]
var neighbors : Array[Dictionary] = []
