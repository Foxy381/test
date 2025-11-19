extends CanvasLayer

var is_visible = false
var show_timer = 0.0
var show_duration = 5.0

var inventory_slots = []
var viewport_height = 0.0

func _ready():
	viewport_height = get_viewport().get_visible_rect().size.y
	create_inventory_visual()
	hide_inventory_immediate()

func create_inventory_visual():
	for i in range(4):
		var slot = ColorRect.new()
		slot.size = Vector2(70, 70)
		slot.position = Vector2(20 + i * 80, viewport_height - 90)  # Нормальная позиция
		slot.color = Color(0.1, 0.1, 0.1, 0.8)
		
		var frame = ColorRect.new()
		frame.size = Vector2(66, 66)
		frame.position = Vector2(2, 2)
		frame.color = Color(0.3, 0.3, 0.3, 0.9)
		slot.add_child(frame)
		
		var item_area = ColorRect.new()
		item_area.size = Vector2(58, 58)
		item_area.position = Vector2(6, 6)
		item_area.color = Color(0.5, 0.5, 0.5, 0.3)
		item_area.name = "ItemArea"
		slot.add_child(item_area)
		
		add_child(slot)
		inventory_slots.append(slot)

func show_inventory():
	is_visible = true
	show_timer = show_duration
	
	# Просто показываем (без анимации)
	for slot in inventory_slots:
		slot.visible = true

func hide_inventory():
	is_visible = false
	
	# Просто скрываем (без анимации)
	for slot in inventory_slots:
		slot.visible = false

func hide_inventory_immediate():
	for slot in inventory_slots:
		slot.visible = false

func toggle_inventory():
	if is_visible:
		hide_inventory()
	else:
		show_inventory()

func _process(delta):
	# Только таймер скрытия
	if is_visible and show_timer > 0:
		show_timer -= delta
		if show_timer <= 0:
			hide_inventory()

func update_inventory_display(items):
	# Очищаем предыдущие предметы
	for slot in inventory_slots:
		var item_area = slot.get_node("ItemArea")
		for child in item_area.get_children():
			child.queue_free()
	
	# Отображаем текущие предметы
	for i in range(min(items.size(), inventory_slots.size())):
		if items[i] != null:
			var item_display = ColorRect.new()
			item_display.size = Vector2(54, 54)
			item_display.position = Vector2(2, 2)
			
			if items[i].has_method("get_key_level"):
				item_display.color = Color(1.0, 0.8, 0.0)
			else:
				item_display.color = Color(0.8, 0.2, 0.2)
			
			inventory_slots[i].get_node("ItemArea").add_child(item_display)
	
	show_inventory()
