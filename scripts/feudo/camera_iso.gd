class_name CameraIso
extends Node3D
## Telecamera isometrica ortografica: trascinamento, 3 livelli di zoom,
## rotazione a scatti di 90°. Il nodo è il perno a terra; la Camera3D sta su un braccio inclinato.

signal oltre_zoom_minimo

const LIVELLI_ZOOM := [56.0, 36.0, 22.0]  # ampiezza verticale inquadrata, in metri
const INCLINAZIONE := -35.0

var limiti := Rect2(0, 0, 96, 96)  # dove può stare il centro della visuale, in metri (x, z)
var camera: Camera3D
var _braccio: Node3D
var _zoom := 1
var _imbardata := 45.0


func _ready() -> void:
	_braccio = Node3D.new()
	_braccio.rotation_degrees.x = INCLINAZIONE
	add_child(_braccio)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = LIVELLI_ZOOM[_zoom]
	camera.position = Vector3(0, 0, 90)
	camera.near = 1.0
	camera.far = 250.0
	_braccio.add_child(camera)
	rotation_degrees.y = _imbardata


func sposta(relativo: Vector2) -> void:
	var metri_per_pixel := camera.size / get_viewport().get_visible_rect().size.y
	var destra := Vector3(global_basis.x.x, 0, global_basis.x.z).normalized()
	var avanti := Vector3(-global_basis.z.x, 0, -global_basis.z.z).normalized()
	# in verticale il terreno è visto di sbieco: un pixel copre più metri
	var scorcio := sin(deg_to_rad(-INCLINAZIONE))
	position += (-destra * relativo.x + avanti * relativo.y / scorcio) * metri_per_pixel
	_limita()


func cambia_zoom(direzione: int) -> void:
	var nuovo := _zoom + direzione
	if nuovo < 0:
		oltre_zoom_minimo.emit()
		return
	nuovo = mini(nuovo, LIVELLI_ZOOM.size() - 1)
	if nuovo == _zoom:
		return
	_zoom = nuovo
	create_tween().tween_property(camera, "size", LIVELLI_ZOOM[nuovo], 0.2)


func ruota(direzione: int) -> void:
	_imbardata += 90.0 * direzione
	create_tween().tween_property(self, "rotation_degrees:y", _imbardata, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Origine e direzione del raggio che parte dal punto toccato sullo schermo.
func raggio(punto: Vector2) -> Array[Vector3]:
	return [camera.project_ray_origin(punto), camera.project_ray_normal(punto)]


func _limita() -> void:
	position.x = clampf(position.x, limiti.position.x, limiti.end.x)
	position.z = clampf(position.z, limiti.position.y, limiti.end.y)
