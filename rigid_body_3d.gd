extends RigidBody3D

@export var item_name = "Item"
@export var item_level = 0

var is_in_inventory = false
var original_parent = null
var original_position = Vector3.ZERO

func _ready():
	original_parent = get_parent()
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false

func pick_up():
	if is_in_inventory:
		return null
	
	original_parent = get_parent()
	original_position = global_transform.origin
	is_in_inventory = true
	
	# Отключаем физику
	set_physics(false)
	
	return self

func throw(force):
	# Возвращаем в мир
	get_parent().remove_child(self)
	get_node("/root/Main/World").add_child(self)
	
	# Восстанавливаем позицию
	global_transform.origin = get_node("/root/Main/Player/ItemHolder").global_transform.origin
	
	# Включаем физику
	set_physics(true)
	
	# Применяем силу
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	apply_central_impulse(force)
	
	is_in_inventory = false

func set_physics(enabled):
	if enabled:
		freeze = false
		collision_layer = 2
		collision_mask = 2
		gravity_scale = 1.0
	else:
		freeze = true
		collision_layer = 0
		collision_mask = 0
		gravity_scale = 0.0
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO

func _on_body_entered(body):
	if body.has_method("break_window"):
		body.break_window()
