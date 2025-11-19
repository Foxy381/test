extends CharacterBody3D

@export var mouse_sensitivity = 0.002
@export var move_speed = 5.0
@export var jump_force = 4.5
@export var throw_force_multiplier = 15.0

@onready var camera_pivot = $Node3D
@onready var camera = $Node3D/Camera3D
@onready var ray_cast = $Node3D/Camera3D/RayCast3D
@onready var item_holder = $Node3D/Camera3D/Node3D

var camera_rotation = Vector2.ZERO
var current_camera_tilt = 0.0
var gravity = 9.8

var is_holding_item = false
var current_item = null
var throw_charge_time = 0.0
var max_throw_charge = 2.0

var inventory = []
var current_slot = 0
var max_slots = 4
var inventory_system

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ray_cast.enabled = true
	
	# Безопасное получение инвентаря
	inventory_system = get_node_or_null("/root/Main/InventoryUI")
	if inventory_system == null:
		print("Предупреждение: InventoryUI не найден")
	
	inventory.resize(max_slots)
	# Инициализируем инвентарь null значениями
	for i in range(max_slots):
		inventory[i] = null

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Поворот камеры
		camera_rotation -= event.relative * mouse_sensitivity
		camera_rotation.y = clamp(camera_rotation.y, -1.5, 1.5)
		
		rotation.y = camera_rotation.x
		camera_pivot.rotation.x = camera_rotation.y
		
		# Если держим предмет, обновляем его позицию
		if is_holding_item and current_item:
			current_item.global_position = item_holder.global_position

func _process(delta):
	handle_camera_tilt(delta)
	handle_throw_charging(delta)
	handle_inventory_input()
	
	if Input.is_action_just_pressed("inventory") and inventory_system:
		inventory_system.toggle_inventory()

func _physics_process(delta):
	handle_movement(delta)
	
	# Постоянно обновляем позицию предмета если держим
	if is_holding_item and current_item:
		current_item.global_position = item_holder.global_position
		current_item.rotation = Vector3.ZERO  # Предотвращаем вращение

func handle_camera_tilt(delta):
	var target_tilt = 0.0
	
	if Input.is_action_pressed("camera_tilt_left"):
		target_tilt = deg_to_rad(35.5)
	elif Input.is_action_pressed("camera_tilt_right"):
		target_tilt = deg_to_rad(-35.5)
	
	current_camera_tilt = lerp(current_camera_tilt, target_tilt, 8 * delta)
	camera.rotation.z = current_camera_tilt

func handle_movement(delta):
	var input_dir = Vector3.ZERO
	
	if Input.is_action_pressed("2.1"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("2.2"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("1.1"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("1.2"):
		input_dir += transform.basis.x
	
	input_dir = input_dir.normalized()
	
	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.z * move_speed
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force
	
	move_and_slide()
	
	# После движения обновляем позицию предмета
	if is_holding_item and current_item:
		current_item.global_position = item_holder.global_position

func handle_interaction():
	if Input.is_action_just_pressed("d"):
		if ray_cast.is_colliding():
			var collider = ray_cast.get_collider()
			if collider and collider.has_method("pick_up"):
				var item = collider.pick_up()
				if item:
					add_to_inventory(item)
		
		elif is_holding_item:
			drop_item()
	
	if Input.is_action_just_pressed("throw") and is_holding_item:
		throw_item()

func handle_throw_charging(delta):
	if Input.is_action_pressed("throw_charge") and is_holding_item:
		throw_charge_time = min(throw_charge_time + delta, max_throw_charge)

func handle_inventory_input():
	for i in range(1, max_slots + 1):
		if Input.is_action_just_pressed(str(i)):
			select_slot(i - 1)

func add_to_inventory(item):
	# Находим первый свободный слот
	var slot_index = -1
	for i in range(max_slots):
		if inventory[i] == null:
			slot_index = i
			break
	
	if slot_index != -1:
		# Убираем текущий предмет если держим
		if is_holding_item:
			remove_current_item()
		
		# Добавляем в инвентарь
		inventory[slot_index] = item
		
		if inventory_system:
			inventory_system.update_inventory_display(inventory)
			inventory_system.show_inventory()
		
		# Автоматически выбираем слот и берем предмет
		current_slot = slot_index
		hold_item(item)
		return true
	
	return false

func select_slot(slot_index):
	if slot_index < 0 or slot_index >= max_slots:
		return
	
	# Убираем текущий предмет
	if is_holding_item:
		remove_current_item()
	
	current_slot = slot_index
	
	# Берем предмет из нового слота если он есть
	if inventory[slot_index] != null:
		hold_item(inventory[slot_index])
	else:
		# Если слот пустой, просто переключаемся
		print("Слот ", slot_index + 1, " пустой")

func hold_item(item):
	if is_holding_item:
		remove_current_item()
	
	current_item = item
	is_holding_item = true
	
	# Сохраняем оригинального родителя если еще не сохранен
	if item.original_parent == null:
		item.original_parent = item.get_parent()
	
	# Переносим предмет в ItemHolder
	var item_parent = item.get_parent()
	if item_parent:
		item_parent.remove_child(item)
	
	item_holder.add_child(item)
	
	# Сбрасываем трансформ
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	item.scale = Vector3.ONE  # Сбрасываем масштаб
	
	# Отключаем физику
	if item.has_method("set_physics"):
		item.set_physics(false)
	
	print("Взят предмет: ", item.item_name, " в слот ", current_slot + 1)

func remove_current_item():
	if is_holding_item and current_item:
		current_item.get_parent().remove_child(current_item)
		
		# Возвращаем предмет в оригинального родителя
		if current_item.original_parent:
			current_item.original_parent.add_child(current_item)
			current_item.global_position = item_holder.global_position
		
		is_holding_item = false
		current_item = null

func drop_item():
	if is_holding_item and current_item:
		var item = current_item
		var slot_index = current_slot
		
		remove_current_item()
		inventory[slot_index] = null
		
		if inventory_system:
			inventory_system.update_inventory_display(inventory)
		
		# Бросаем с небольшой силой
		item.throw(transform.basis.z * throw_force_multiplier * 0.3)
		
		print("Предмет выброшен из слота ", slot_index + 1)

func throw_item():
	if is_holding_item and current_item:
		var item = current_item
		var slot_index = current_slot
		
		remove_current_item()
		inventory[slot_index] = null
		
		if inventory_system:
			inventory_system.update_inventory_display(inventory)
		
		# Рассчитываем силу броска
		var throw_power = (throw_charge_time / max_throw_charge) * throw_force_multiplier
		var throw_direction = transform.basis.z
		
		item.throw(throw_direction * throw_power)
		throw_charge_time = 0.0
		
		print("Предмет брошен с силой: ", throw_power)

func get_current_key_level():
	if is_holding_item and current_item.has_method("get_key_level"):
		return current_item.get_key_level()
	return -1

# Функция для взаимодействия с дверями
func interact_with_door(door):
	if is_holding_item and current_item.has_method("use_on_door"):
		return current_item.use_on_door(door)
	return false
