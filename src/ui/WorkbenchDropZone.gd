extends PanelContainer

# WorkbenchDropZone.gd - Drop target for constructing words
#
# The drop POSITION is passed along with the card so the board can work out which
# gap between the existing cards the player is aiming at, and insert there
# instead of always appending to the end of the word.

signal card_dropped(card_data: Dictionary, at_position: Vector2)
## Emitted while a card hovers the zone so the UI can draw an insertion caret.
signal drop_hovered(at_position: Vector2, valid: bool)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.has("type") and data.has("char")
	drop_hovered.emit(at_position, ok)
	return ok

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		card_dropped.emit(data, at_position)

