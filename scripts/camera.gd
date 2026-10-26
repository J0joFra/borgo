class_name CameraVillaggio
extends Camera2D
## Telecamera con trascinamento e zoom a scatti interi (pixel sempre nitidi).

const LIVELLI_ZOOM := [1.0, 2.0]

var dimensione_mondo := Vector2(1024, 1024)
var _zoom_attuale := 0


func _ready() -> void:
	zoom = Vector2.ONE * LIVELLI_ZOOM[_zoom_attuale]
	get_viewport().size_changed.connect(_limita)


func sposta(relativo: Vector2) -> void:
	position -= relativo / zoom
	_limita()


## Cambia zoom tenendo fermo il punto del mondo sotto il dito (o il mouse).
func cambia_zoom(direzione: int, fuoco_schermo: Vector2) -> void:
	var nuovo := clampi(_zoom_attuale + direzione, 0, LIVELLI_ZOOM.size() - 1)
	if nuovo == _zoom_attuale:
		return
	var prima := _schermo_a_mondo(fuoco_schermo)
	_zoom_attuale = nuovo
	zoom = Vector2.ONE * LIVELLI_ZOOM[nuovo]
	position += prima - _schermo_a_mondo(fuoco_schermo)
	_limita()


func _schermo_a_mondo(p: Vector2) -> Vector2:
	return position + (p - get_viewport_rect().size / 2.0) / zoom


func _limita() -> void:
	var meta := get_viewport_rect().size / zoom / 2.0
	var p := position
	for asse in 2:
		if meta[asse] * 2.0 >= dimensione_mondo[asse]:
			p[asse] = dimensione_mondo[asse] / 2.0
		else:
			p[asse] = clampf(p[asse], meta[asse], dimensione_mondo[asse] - meta[asse])
	position = p
