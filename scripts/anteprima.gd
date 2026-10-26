class_name Anteprima
extends Node2D
## Rettangolo verde/rosso che mostra dove verrà piazzato l'edificio.

var dimensione := Vector2(32, 32)
var valida := true


func _draw() -> void:
	var colore := Color(0.3, 0.9, 0.3) if valida else Color(0.95, 0.25, 0.2)
	draw_rect(Rect2(Vector2.ZERO, dimensione), Color(colore, 0.35))
	draw_rect(Rect2(Vector2(0.5, 0.5), dimensione - Vector2.ONE), colore, false, 1.0)
