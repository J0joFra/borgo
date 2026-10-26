class_name LowPoly
extends RefCounted
## Mesh low-poly a facce piatte con il colore nei vertici.
## Tutto il feudo usa un solo materiale: pochi draw call, adatto a mobile.
## Quando arriveranno i modelli .glb veri, questi pezzi provvisori spariscono.

static var _materiale: StandardMaterial3D


static func materiale() -> StandardMaterial3D:
	if _materiale == null:
		_materiale = StandardMaterial3D.new()
		_materiale.vertex_color_use_as_albedo = true
		_materiale.vertex_color_is_srgb = true  # i colori sono scritti in esadecimale sRGB
		_materiale.roughness = 0.95
		_materiale.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _materiale


## Trasformazione: prima scala, poi rotazione attorno a Y, poi spostamento.
static func t(pos: Vector3, scala := Vector3.ONE, rot_y := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(scala), pos)


static func cubo(dim: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = dim
	return m


static func tetto(dim: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = dim
	return m


static func cilindro(raggio_basso: float, raggio_alto: float, altezza: float, lati := 7) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = raggio_basso
	m.top_radius = raggio_alto
	m.height = altezza
	m.radial_segments = lati
	m.rings = 1
	return m


static func sfera(raggio: float, altezza: float, lati := 7, anelli := 4) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = raggio
	m.height = altezza
	m.radial_segments = lati
	m.rings = anelli
	return m


## Raccoglie più forme in un'unica mesh a facce piatte.
## Scrive direttamente in array nativi (molto più veloce di SurfaceTool vertice per vertice)
## e ricorda sulla forma stessa i suoi dati, così una forma riusata (es. un masso) si legge una volta.
class Costruttore:

	var vertici := PackedVector3Array()
	var normali := PackedVector3Array()
	var colori := PackedColorArray()

	func forma(mesh: PrimitiveMesh, tr: Transform3D, colore: Color) -> Costruttore:
		if not mesh.has_meta("_dati"):
			var arr := mesh.get_mesh_arrays()
			var idx := PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] is PackedInt32Array:
				idx = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx = PackedInt32Array(range((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
			mesh.set_meta("_dati", [arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_NORMAL], idx])
		var dati: Array = mesh.get_meta("_dati")
		var v: PackedVector3Array = dati[0]
		var nn: PackedVector3Array = dati[1]
		var idx: PackedInt32Array = dati[2]
		for i in range(0, idx.size() - 2, 3):
			var a := tr * v[idx[i]]
			var b := tr * v[idx[i + 1]]
			var c := tr * v[idx[i + 2]]
			var n := (b - a).cross(c - a)
			if n.length_squared() < 1e-10:
				continue  # triangolo degenere, ad esempio la punta di un cono
			n = n.normalized()
			var medio := tr.basis * (nn[idx[i]] + nn[idx[i + 1]] + nn[idx[i + 2]])
			if n.dot(medio) < 0.0:
				n = -n
			_triangolo(a, b, c, n, colore)
		return self

	func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, colore: Color) -> Costruttore:
		_triangolo(p0, p1, p2, n, colore)
		_triangolo(p0, p2, p3, n, colore)
		return self

	func _triangolo(a: Vector3, b: Vector3, c: Vector3, n: Vector3, colore: Color) -> void:
		vertici.append(a)
		vertici.append(b)
		vertici.append(c)
		normali.append(n)
		normali.append(n)
		normali.append(n)
		colori.append(colore)
		colori.append(colore)
		colori.append(colore)

	## La mesh con i colori raccolti, oppure con altri colori per gli stessi vertici
	## (serve a cambiare stagione senza ricostruire la geometria).
	func mesh(altri_colori := PackedColorArray()) -> ArrayMesh:
		var m := ArrayMesh.new()
		if vertici.is_empty():
			return m
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vertici
		arr[Mesh.ARRAY_NORMAL] = normali
		arr[Mesh.ARRAY_COLOR] = altri_colori if not altri_colori.is_empty() else colori
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, LowPoly.materiale())
		return m
