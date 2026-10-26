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
class Costruttore:
	var st := SurfaceTool.new()
	var vuoto := true

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func forma(mesh: PrimitiveMesh, tr: Transform3D, colore: Color) -> Costruttore:
		var arr := mesh.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] is PackedInt32Array:
			idx = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))
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
		for p in [a, b, c]:
			st.set_normal(n)
			st.set_color(colore)
			st.add_vertex(p)
		vuoto = false

	func mesh() -> ArrayMesh:
		if vuoto:
			return ArrayMesh.new()
		var m := st.commit()
		m.surface_set_material(0, LowPoly.materiale())
		return m
