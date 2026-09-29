extends PanelContainer

# WorkbenchDropZone.gd - Drop target for constructing words

signal card_dropped(card_data: Dictionary)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data.has("char")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		card_dropped.emit(data)
