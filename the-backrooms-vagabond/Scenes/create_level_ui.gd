extends Control

#i dont understand how this all works. 
#do i emit a generate world signal from here? 
#do i have the main scene connect to the generate world button? 
#do i just deactivate this scene and activate the main scene?

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


	
func verify_values():
	pass


func _on_generate_level_button_pressed() -> void:
	get_tree().get_node("LevelGenerator").make_world()
