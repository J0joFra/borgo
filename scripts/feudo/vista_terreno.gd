class_name VistaTerreno
extends Node3D
## Disegna il feudo come un diorama: suolo a celle con i bordi a "fetta di terra",
## alberi (MultiMesh, uno per tipo) e rocce. I colori cambiano con le stagioni.

const CELLA := 2.0
const FONDO := -3.0

const ERBA := [Color("6fae47"), Color("8db24a"), Color("b39a48"), Color("e6ecef")]
const ACQUA := [Color("4a90c8"), Color("4a90c8"), Color("4a86b8"), Color("b8d8ea")]
const ROCCIA_SUOLO := [Color("9a978d"), Color("9a978d"), Color("968f80"), Color("dfe5e8")]
const CHIOMA_TONDA := [Color("4a9a3e"), Color("5aa035"), Color("d0782c"), Color("8a7a68")]
const CHIOMA_PINO := [Color("2f6b40"), Color("2f6b40"), Color("2f6b40"), Color("c4d6d0")]
const TERRA := Color("8a6a45")
const TERRA_SCURA := Color("6b4f33")
const SENTIERO := Color("c2a273")
const TRONCO := Color("6b4a2e")
const ROCCIA := Color("8d8d88")

var terreno: TerrenoFeudo
var _suolo: MeshInstance3D
var _tondi: MultiMeshInstance3D
var _pini: MultiMeshInstance3D
var _variazioni_tondi := PackedFloat32Array()
var _variazioni_pini := PackedFloat32Array()


func costruisci(t: TerrenoFeudo) -> void:
	terreno = t
	_suolo = MeshInstance3D.new()
	add_child(_suolo)
	_crea_alberi()
	_crea_rocce()
	applica_stagione(GameState.stagione)


func applica_stagione(stagione: int) -> void:
	_suolo.mesh = _mesh_suolo(stagione)
	for i in _tondi.multimesh.instance_count:
		_tondi.multimesh.set_instance_color(i, CHIOMA_TONDA[stagione].lightened(_variazioni_tondi[i]))
	for i in _pini.multimesh.instance_count:
		_pini.multimesh.set_instance_color(i, CHIOMA_PINO[stagione].lightened(_variazioni_pini[i]))


# --- Coordinate --------------------------------------------------------------

func dimensione() -> float:
	return TerrenoFeudo.LATO * CELLA


## Centro dell'area occupata da un edificio, alla quota del terreno.
func centro_area(cella: Vector2i, taglia: Vector2i) -> Vector3:
	var x := (cella.x + taglia.x / 2.0) * CELLA
	var z := (cella.y + taglia.y / 2.0) * CELLA
	return Vector3(x, terreno.altezza(cella), z)


## La cella colpita da un raggio della telecamera (prima a quota 0, poi alla quota vera).
func cella_da_raggio(origine: Vector3, direzione: Vector3) -> Vector2i:
	var c := _interseca(origine, direzione, 0.0)
	var h := terreno.altezza(c)
	if h != 0.0:
		c = _interseca(origine, direzione, h)
	return c


func _interseca(o: Vector3, d: Vector3, quota: float) -> Vector2i:
	if absf(d.y) < 1e-4:
		return Vector2i(-1, -1)
	var p := o + d * ((quota - o.y) / d.y)
	return Vector2i(floori(p.x / CELLA), floori(p.z / CELLA))


# --- Suolo -------------------------------------------------------------------

func _colore_cella(c: Vector2i, stagione: int) -> Color:
	var base: Color
	match terreno.tipo_a(c):
		TerrenoFeudo.Tipo.ACQUA:
			return ACQUA[stagione]
		TerrenoFeudo.Tipo.ROCCIA:
			base = ROCCIA_SUOLO[stagione]
		TerrenoFeudo.Tipo.COLLINA:
			base = ERBA[stagione].darkened(0.12)
		TerrenoFeudo.Tipo.BOSCO:
			base = ERBA[stagione].darkened(0.08)
		TerrenoFeudo.Tipo.SENTIERO:
			base = SENTIERO
		TerrenoFeudo.Tipo.ERBA_FIORI:
			base = ERBA[stagione].lightened(0.05)
		_:
			base = ERBA[stagione]
	# Una leggera variazione per cella evita l'effetto scacchiera piatta.
	var v := float(absi(hash(c)) % 100) / 100.0
	return base.lightened(v * 0.05) if v > 0.5 else base.darkened(v * 0.05)


func _mesh_suolo(stagione: int) -> ArrayMesh:
	var k := LowPoly.Costruttore.new()
	var lati := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in TerrenoFeudo.LATO:
		for x in TerrenoFeudo.LATO:
			var c := Vector2i(x, y)
			var h := terreno.altezza(c)
			var x0 := x * CELLA
			var z0 := y * CELLA
			var x1 := x0 + CELLA
			var z1 := z0 + CELLA
			var colore := _colore_cella(c, stagione)
			k.quad(Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.UP, colore)
			for dir in lati:
				var vicino: Vector2i = c + dir
				var bordo := not terreno.dentro(vicino)
				var h_vicino := FONDO if bordo else terreno.altezza(vicino)
				if h_vicino >= h:
					continue
				var n := Vector3(dir.x, 0, dir.y)
				# i due spigoli della cella sul lato rivolto verso il vicino
				var a: Vector3
				var b: Vector3
				match dir:
					Vector2i(1, 0):
						a = Vector3(x1, 0, z0); b = Vector3(x1, 0, z1)
					Vector2i(-1, 0):
						a = Vector3(x0, 0, z0); b = Vector3(x0, 0, z1)
					Vector2i(0, 1):
						a = Vector3(x0, 0, z1); b = Vector3(x1, 0, z1)
					_:
						a = Vector3(x0, 0, z0); b = Vector3(x1, 0, z0)
				if bordo:
					# fetta di terra: una fascia d'erba, poi terra fino al fondo
					var fascia := h - 0.3
					_parete(k, a, b, h, fascia, n, colore.darkened(0.1))
					_parete(k, a, b, fascia, -1.2, n, TERRA)
					_parete(k, a, b, -1.2, FONDO, n, TERRA_SCURA)
				else:
					_parete(k, a, b, h, h_vicino, n, colore.darkened(0.25))
	return k.mesh()


func _parete(k: LowPoly.Costruttore, a: Vector3, b: Vector3, sopra: float, sotto: float, n: Vector3, colore: Color) -> void:
	k.quad(Vector3(a.x, sopra, a.z), Vector3(b.x, sopra, b.z), Vector3(b.x, sotto, b.z), Vector3(a.x, sotto, a.z), n, colore)


# --- Alberi e rocce ----------------------------------------------------------

func _crea_alberi() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = terreno.seme + 7
	var tondi: Array[Transform3D] = []
	var pini: Array[Transform3D] = []
	for y in TerrenoFeudo.LATO:
		for x in TerrenoFeudo.LATO:
			var c := Vector2i(x, y)
			var tipo := terreno.tipo_a(c)
			var quanti := 0
			if tipo == TerrenoFeudo.Tipo.BOSCO:
				quanti = 2 if rng.randf() < 0.45 else 1
			elif tipo == TerrenoFeudo.Tipo.ERBA and rng.randf() < 0.012:
				quanti = 1
			for i in quanti:
				var pos := Vector3((x + rng.randf_range(0.2, 0.8)) * CELLA, terreno.altezza(c), (y + rng.randf_range(0.2, 0.8)) * CELLA)
				var s := rng.randf_range(0.8, 1.25)
				var tr := LowPoly.t(pos, Vector3.ONE * s, rng.randf() * TAU)
				if rng.randf() < 0.45:
					pini.append(tr)
				else:
					tondi.append(tr)

	var tronco := LowPoly.Costruttore.new().forma(LowPoly.cilindro(0.16, 0.12, 1.2, 5), LowPoly.t(Vector3(0, 0.6, 0)), TRONCO).mesh()
	var chioma_tonda := LowPoly.Costruttore.new().forma(LowPoly.sfera(0.95, 1.7, 7, 4), LowPoly.t(Vector3(0, 1.8, 0)), Color.WHITE).mesh()
	var chioma_pino := LowPoly.Costruttore.new() \
		.forma(LowPoly.cilindro(0.95, 0.0, 1.6, 7), LowPoly.t(Vector3(0, 1.5, 0)), Color.WHITE) \
		.forma(LowPoly.cilindro(0.7, 0.0, 1.3, 7), LowPoly.t(Vector3(0, 2.3, 0)), Color.WHITE).mesh()

	var tutti: Array[Transform3D] = []
	tutti.append_array(tondi)
	tutti.append_array(pini)
	_multimesh(tronco, tutti, false)
	_tondi = _multimesh(chioma_tonda, tondi, true)
	_pini = _multimesh(chioma_pino, pini, true)
	for i in tondi.size():
		_variazioni_tondi.append(rng.randf_range(-0.08, 0.08))
	for i in pini.size():
		_variazioni_pini.append(rng.randf_range(-0.08, 0.08))


func _multimesh(mesh: Mesh, trasformazioni: Array[Transform3D], colori: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colori
	mm.mesh = mesh
	mm.instance_count = trasformazioni.size()
	for i in trasformazioni.size():
		mm.set_instance_transform(i, trasformazioni[i])
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = mm
	add_child(nodo)
	return nodo


func _crea_rocce() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = terreno.seme + 11
	var k := LowPoly.Costruttore.new()
	var masso := LowPoly.sfera(0.8, 1.1, 6, 3)
	for y in TerrenoFeudo.LATO:
		for x in TerrenoFeudo.LATO:
			var c := Vector2i(x, y)
			var tipo := terreno.tipo_a(c)
			if tipo == TerrenoFeudo.Tipo.ROCCIA or (tipo == TerrenoFeudo.Tipo.COLLINA and rng.randf() < 0.08):
				var pos := Vector3((x + rng.randf_range(0.3, 0.7)) * CELLA, terreno.altezza(c) + 0.25, (y + rng.randf_range(0.3, 0.7)) * CELLA)
				var s := Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.6, 1.1), rng.randf_range(0.8, 1.3))
				k.forma(masso, LowPoly.t(pos, s, rng.randf() * TAU), ROCCIA.lightened(rng.randf_range(-0.1, 0.1)))
	var nodo := MeshInstance3D.new()
	nodo.mesh = k.mesh()
	add_child(nodo)
