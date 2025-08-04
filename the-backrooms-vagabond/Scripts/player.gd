extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var speed = 100
var jump_speed = 50
var mouse_sensitivity = 0.002

func _ready():
	pass
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	velocity.y -= gravity * delta
	var input = Input.get_vector("left", "right", "forward", "back")
	var dir = transform.basis * Vector3(input.x, 0, input.y) * speed
	move_and_slide()
	#if is_on_floor() and Input.is_action_just_pressed("jump"):
	if Input.is_action_pressed("jump"):
		dir.y = jump_speed
	if Input.is_action_pressed("crouch"):
		dir.y = -jump_speed
	velocity = dir
		
func _input(event) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
		$Camera3D.rotation.x = clampf($Camera3D.rotation.x, -deg_to_rad(90), deg_to_rad(90))
		
		
		
		
