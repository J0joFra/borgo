class_name VistaTerreno
extends Node3D
## Disegna il mondo come un diorama: suolo a celle con i bordi a "fetta di terra",
## alberi (MultiMesh, uno per tipo), rocce e la linea che segna il confine del feudo.
## I colori cambiano con le stagioni.

const CELLA := 2.0
const FONDO := -3.0

const ERBA := [Color("6fae47"), Color("8db24a"), Color("b39a48"), Color("e6ecef")]
const ACQUA := [Color("4a90c8"), Color("4a90c8"), Color("4a86b8"), Color("b8d8ea")]
const FIUME := [Color("5aa6dc"), Color("5aa6dc"), Color("5a9cd0"), Color("7aaccc")]  # d'inverno non gela
const RADURA := Color("8a7a4a")  # dove il bosco è stato tagliato
const STRADA := [Color("b09468"), Color("b09468"), Color("a88c64"), Color("d8d0c4")]
const MASSIMO_PIANTATI := 600
const ROCCIA_SUOLO := [Color("9a978d"), Color("9a978d"), Color("968f80"), Color("dfe5e8")]
const CHIOMA_TONDA := [Color("4a9a3e"), Color("5aa035"), Color("d0782c"), Color("8a7a68")]
const CHIOMA_PINO := [Color("2f6b40"), Color("2f6b40"), Color("2f6b40"), Color("c4d6d0")]
const TERRA := Color("8a6a45")
const TERRA_SCURA := Color("6b4f33")
const SENTIERO := Color("c2a273")
const TRONCO := Color("6b4a2e")
const CONFINE := Color("f2c94c")  # linea del confine del feudo
const LARGHEZZA_CONFINE := 0.35
const PARTE_SOPRA := 0
const PARTE_GRADINO := 1
const PARTE_FASCIA := 2
const ROCCIA := Color("8d8d88")

var terreno: TerrenoFeudo
var _suolo: MeshInstance3D
var _suoli_pronti: Dictionary = {}  # stagione -> mesh, costruita una volta sola
var _geometria: LowPoly.Costruttore  # vertici del suolo, uguali in ogni stagione
var _chiavi := PackedInt32Array()     # per vertice: cella * 4 + parte, oppure -1 (colore fisso)
var _tondi: MultiMeshInstance3D
var _pini: MultiMeshInstance3D
var _variazioni_tondi := PackedFloat32Array()
var _variazioni_pini := PackedFloat32Array()
var _tronchi: MultiMeshInstance3D
var _alberi_cella: Dictionary = {}  # indice cella -> [[tipo 0 tondo / 1 pino, indice chioma, indice tronco], ...]
var _tagliate: Dictionary = {}      # indice cella -> true, celle di bosco abbattute
var _zona: MeshInstance3D           # celle colorate mentre si sceglie dove costruire
var _orig_tondi: Array[Transform3D] = []   # forma originale di ogni albero (per ricrescere)
var _orig_pini: Array[Transform3D] = []
var _orig_tronchi: Array[Transform3D] = []
var _pool_chiome: MultiMeshInstance3D       # alberi piantati dal forestale sui prati
var _pool_tronchi: MultiMeshInstance3D
var _orig_pool: Array[Transform3D] = []
var _ciuffi: MultiMeshInstance3D
var _ciuffi_orig: Array[Transform3D] = []
var _ciuffi_cella: Dictionary = {}  # indice cella -> indici dei ciuffi
var _strade: MeshInstance3D  # strade sui bordi delle celle, ponti e passerelle
var _mura: MeshInstance3D    # mura in pietra con le porte


func costruisci(t: TerrenoFeudo) -> void:
	terreno = t
	_suolo = MeshInstance3D.new()
	add_child(_suolo)
	_crea_alberi()
	_crea_ciuffi()
	_crea_rocce()
	_crea_confine()
	_strade = MeshInstance3D.new()
	add_child(_strade)
	_mura = MeshInstance3D.new()
	add_child(_mura)
	_crea_mura()
	applica_stagione(GameState.stagione)


func applica_stagione(stagione: int) -> void:
	if not _suoli_pronti.has(stagione):
		_suoli_pronti[stagione] = _mesh_suolo(stagione)
	_suolo.mesh = _suoli_pronti[stagione]
	_crea_strade(stagione)
	for i in _tondi.multimesh.instance_count:
		_tondi.multimesh.set_instance_color(i, CHIOMA_TONDA[stagione].lightened(_variazioni_tondi[i]))
	for i in _pini.multimesh.instance_count:
		_pini.multimesh.set_instance_color(i, CHIOMA_PINO[stagione].lightened(_variazioni_pini[i]))
	for i in _pool_chiome.multimesh.visible_instance_count:
		_pool_chiome.multimesh.set_instance_color(i, CHIOMA_TONDA[stagione].lightened(((i % 16) - 8) / 100.0))


# --- Strade, ponti, passerelle, mura ----------------------------------------------------

const LEGNO_PONTE := Color("8a6038")
const LEGNO_CHIARO := Color("a87a48")
const PIETRA_PONTE := Color("a09a8c")
const PIETRA_MURA := Color("a8a296")
const PIETRA_MURA_SCURA := Color("8a8478")
const QUOTA_PONTE := 0.14  # il piano dove si cammina
const LARGHEZZA_STRADA := 0.9
const ALTEZZA_MURA := 1.8


## Posizione nel mondo di un vertice della griglia: alla quota delle strade che lo toccano
## (la più bassa), altrimenti a quella della terra attorno.
func vertice(v: Vector2i) -> Vector3:
	var su_strada := INF
	for d in TerrenoFeudo.DIREZIONI:
		var k := TerrenoFeudo.lato(v, v + d)
		if terreno.strade.has(k):
			su_strada = minf(su_strada, QUOTA_PONTE if terreno.tipo_lato(k) != "" else terreno.quota_lato(k))
	if su_strada != INF:
		return Vector3(v.x * CELLA, su_strada, v.y * CELLA)
	var h := 0.0
	for c in [v, v - Vector2i(1, 0), v - Vector2i(0, 1), v - Vector2i(1, 1)]:
		if terreno.tipo_a(c) >= 0 and not terreno.tipo_a(c) in [TerrenoFeudo.Tipo.ACQUA, TerrenoFeudo.Tipo.FIUME]:
			h = maxf(h, terreno.altezza(c))
	return Vector3(v.x * CELLA, h, v.y * CELLA)


## Le strade sono strisce di terra battuta lungo i bordi delle celle; fra due celle d'acqua
## diventano un ponte (sul fiume, con parapetto e spallette) o una passerella (sul lago).
func _crea_strade(stagione: int) -> void:
	_strade.mesh = _mesh_lati(terreno.strade.keys(), STRADA[stagione], true)


func _mesh_lati(lati: Array, colore: Color, con_ponti: bool) -> ArrayMesh:
	var k := LowPoly.Costruttore.new()
	if lati.is_empty():
		return null
	for chiave in lati:
		var e := TerrenoFeudo.estremi(chiave)
		var a := vertice(e[0])
		var b := vertice(e[1])
		var centro := (a + b) / 2.0
		var rot := 0.0 if chiave % 2 == 0 else PI / 2.0
		var tipo := terreno.tipo_lato(chiave) if con_ponti else ""
		if tipo == "":
			var h := terreno.quota_lato(chiave)
			k.forma(LowPoly.cubo(Vector3(CELLA + LARGHEZZA_STRADA, 0.08, LARGHEZZA_STRADA)), LowPoly.t(Vector3(centro.x, h + 0.02, centro.z), Vector3.ONE, rot), colore)
		elif tipo == "ponte":
			k.forma(LowPoly.cubo(Vector3(CELLA + 0.2, 0.16, CELLA * 0.7)), LowPoly.t(Vector3(centro.x, QUOTA_PONTE - 0.08, centro.z), Vector3.ONE, rot), LEGNO_PONTE)
			for lato in [-1.0, 1.0]:
				var fuori := Vector3(0, 0, lato * CELLA * 0.36).rotated(Vector3.UP, rot)
				k.forma(LowPoly.cubo(Vector3(CELLA, 0.1, 0.12)), LowPoly.t(Vector3(centro.x, 0.55, centro.z) + fuori, Vector3.ONE, rot), LEGNO_CHIARO)
				for f in [-0.45, 0.45]:
					var palo := Vector3(f * CELLA, 0, 0).rotated(Vector3.UP, rot) + fuori
					k.forma(LowPoly.cubo(Vector3(0.12, 0.5, 0.12)), LowPoly.t(Vector3(centro.x, 0.35, centro.z) + palo), LEGNO_CHIARO)
			# spallette in pietra dove il ponte arriva a terra
			for estremo in e:
				var a_terra := false
				for d in TerrenoFeudo.DIREZIONI:
					var altro := TerrenoFeudo.lato(estremo, estremo + d)
					if altro != chiave and terreno.strade.has(altro) and terreno.tipo_lato(altro) == "":
						a_terra = true
				if a_terra:
					var p := vertice(estremo)
					k.forma(LowPoly.cubo(Vector3(0.6, 0.5, CELLA * 0.8)), LowPoly.t(Vector3(p.x, -0.1, p.z), Vector3.ONE, rot), PIETRA_PONTE)
		else:
			for i in 4:
				var avanti := Vector3((i - 1.5) * CELLA / 4.0, 0, 0).rotated(Vector3.UP, rot)
				var tono := LEGNO_CHIARO if i % 2 == 0 else LEGNO_PONTE
				k.forma(LowPoly.cubo(Vector3(CELLA / 4.0 - 0.06, 0.08, CELLA * 0.5)), LowPoly.t(Vector3(centro.x, QUOTA_PONTE - 0.04, centro.z) + avanti, Vector3.ONE, rot), tono)
			for lato in [-1.0, 1.0]:
				var palo := Vector3(0, 0, lato * CELLA * 0.28).rotated(Vector3.UP, rot)
				k.forma(LowPoly.cubo(Vector3(0.14, 0.7, 0.14)), LowPoly.t(Vector3(centro.x, -0.2, centro.z) + palo), LEGNO_PONTE)
	return k.mesh()


## Le mura: un pilastro per cella e un tratto verso ogni cella di mura vicina, con i merli.
## Dove una strada passa fra due celle di mura c'è una porta ad arco.
func _crea_mura() -> void:
	var k := LowPoly.Costruttore.new()
	if terreno.mura.is_empty():
		_mura.mesh = null
		return
	for i in terreno.mura:
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		var h := terreno.altezza(c)
		var centro := Vector3((c.x + 0.5) * CELLA, h, (c.y + 0.5) * CELLA)
		k.forma(LowPoly.cubo(Vector3(0.95, ALTEZZA_MURA + 0.3, 0.95)), LowPoly.t(centro + Vector3(0, (ALTEZZA_MURA + 0.3) / 2.0, 0)), PIETRA_MURA_SCURA)
		for d in TerrenoFeudo.DIREZIONI:
			if not terreno.muro_a(c + d):
				continue
			# il lato fra le due celle: se è strada, lì c'è la porta
			var a := c + Vector2i(maxi(d.x, 0), maxi(d.y, 0))
			var b := a + (Vector2i(0, 1) if d.x != 0 else Vector2i(1, 0))
			var porta := terreno.lato_strada(a, b)
			var lungo := CELLA / 2.0 - (0.55 if porta else 0.0)
			var verso := Vector3(d.x, 0, d.y)
			var mezzo := centro + verso * (lungo / 2.0)
			var dim := Vector3(absf(d.x) * lungo + absf(d.y) * 0.75, ALTEZZA_MURA, absf(d.y) * lungo + absf(d.x) * 0.75)
			k.forma(LowPoly.cubo(dim), LowPoly.t(mezzo + Vector3(0, ALTEZZA_MURA / 2.0, 0)), PIETRA_MURA)
			# merli
			for m in 2:
				var posto := centro + verso * (0.35 + m * 0.4)
				if m * 0.4 + 0.5 < lungo:
					k.forma(LowPoly.cubo(Vector3(0.3, 0.3, 0.3)), LowPoly.t(posto + Vector3(0, ALTEZZA_MURA + 0.15, 0)), PIETRA_MURA_SCURA)
			if porta and d.x + d.y > 0:
				# l'arco della porta sopra il passaggio, una volta sola per coppia
				var sopra := centro + verso * (CELLA / 2.0)
				k.forma(LowPoly.cubo(Vector3(absf(d.x) * 1.2 + absf(d.y) * 0.8, 0.45, absf(d.y) * 1.2 + absf(d.x) * 0.8)), LowPoly.t(sopra + Vector3(0, ALTEZZA_MURA - 0.1, 0)), PIETRA_MURA_SCURA)
	_mura.mesh = k.mesh()


## Colora i lati di una strada da tracciare (anteprima).
func mostra_lati(lati: Array, colore: Color) -> void:
	var mesh := _mesh_lati(lati, colore, false)
	if mesh == null:
		nascondi_zona()
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mesh.surface_set_material(0, mat)
	if _zona == null:
		_zona = MeshInstance3D.new()
		_zona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_zona)
	_zona.mesh = mesh
	_zona.position = Vector3(0, 0.05, 0)
	_zona.visible = true


## Il vertice della griglia più vicino al punto toccato.
func vertice_da_raggio(origine: Vector3, direzione: Vector3) -> Vector2i:
	var p := _punto(origine, direzione)
	return Vector2i(roundi(p.x / CELLA), roundi(p.z / CELLA))


## Il punto toccato sul terreno (prima a quota 0, poi alla quota vera), in metri.
func _punto(o: Vector3, d: Vector3) -> Vector3:
	if absf(d.y) < 1e-4:
		return Vector3.ZERO
	var p := o + d * ((0.0 - o.y) / d.y)
	var c := Vector2i(floori(p.x / CELLA), floori(p.z / CELLA))
	var h := terreno.altezza(c)
	if h > 0.0:
		p = o + d * ((h - o.y) / d.y)
	return p


## Il punto toccato in coordinate di cella con i decimali (per scegliere un lato di strada).
func punto_celle(origine: Vector3, direzione: Vector3) -> Vector2:
	var p := _punto(origine, direzione)
	return Vector2(p.x / CELLA, p.z / CELLA)


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
		TerrenoFeudo.Tipo.FIUME:
			return FIUME[stagione]
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
	if _tagliate.has(c.y * TerrenoFeudo.LATO + c.x) and terreno.ceppi.has(c.y * TerrenoFeudo.LATO + c.x):
		base = base.lerp(RADURA, 0.35 if stagione != GameState.INVERNO else 0.1)
	elif stagione != GameState.INVERNO and terreno.tipo_a(c) in TerrenoFeudo.COSTRUIBILE:
		# la terra fertile è un verde più scuro e ricco: si riconosce a occhio
		base = base.darkened(0.16 * terreno.fertilita_a(c))
	# Una leggera variazione per cella evita l'effetto scacchiera piatta.
	var v := float(absi(hash(c)) % 100) / 100.0
	return base.lightened(v * 0.05) if v > 0.5 else base.darkened(v * 0.05)


## Colori del suolo per una stagione: la geometria è sempre la stessa (costruita una volta),
## cambiano solo i colori dei vertici che dipendono dalla cella.
func _mesh_suolo(stagione: int) -> ArrayMesh:
	if _geometria == null:
		_costruisci_geometria()
	var celle := TerrenoFeudo.LATO * TerrenoFeudo.LATO
	var sopra := PackedColorArray()
	sopra.resize(celle)
	for y in TerrenoFeudo.LATO:
		for x in TerrenoFeudo.LATO:
			sopra[y * TerrenoFeudo.LATO + x] = _colore_cella(Vector2i(x, y), stagione)
	var gradino := PackedColorArray()
	var fascia := PackedColorArray()
	gradino.resize(celle)
	fascia.resize(celle)
	for i in celle:
		gradino[i] = sopra[i].darkened(0.25)
		fascia[i] = sopra[i].darkened(0.1)
	var colori := _geometria.colori.duplicate()
	for i in colori.size():
		var chiave := _chiavi[i]
		if chiave < 0:
			continue
		var cella := chiave >> 2
		match chiave & 3:
			PARTE_SOPRA:
				colori[i] = sopra[cella]
			PARTE_GRADINO:
				colori[i] = gradino[cella]
			_:
				colori[i] = fascia[cella]
	return _geometria.mesh(colori)


func _costruisci_geometria() -> void:
	var k := LowPoly.Costruttore.new()
	_geometria = k
	var lati := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in TerrenoFeudo.LATO:
		for x in TerrenoFeudo.LATO:
			var c := Vector2i(x, y)
			var indice := y * TerrenoFeudo.LATO + x
			var h := terreno.altezza(c)
			var x0 := x * CELLA
			var z0 := y * CELLA
			var x1 := x0 + CELLA
			var z1 := z0 + CELLA
			k.quad(Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.UP, Color.WHITE)
			_segna(indice * 4 + PARTE_SOPRA)
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
					_parete(k, a, b, h, fascia, n, Color.WHITE)
					_segna(indice * 4 + PARTE_FASCIA)
					_parete(k, a, b, fascia, -1.2, n, TERRA)
					_segna(-1)
					_parete(k, a, b, -1.2, FONDO, n, TERRA_SCURA)
					_segna(-1)
				else:
					_parete(k, a, b, h, h_vicino, n, Color.WHITE)
					_segna(indice * 4 + PARTE_GRADINO)


## Ricorda a quale cella e parte appartengono i 6 vertici dell'ultimo quadrato aggiunto.
func _segna(chiave: int) -> void:
	for i in 6:
		_chiavi.append(chiave)


## Una striscia colorata appena sopra il terreno, lungo i quattro lati del feudo.
func _crea_confine() -> void:
	var k := LowPoly.Costruttore.new()
	var f := TerrenoFeudo.FEUDO
	var m := LARGHEZZA_CONFINE / 2.0
	for x in range(f.position.x, f.end.x):
		_tratto_confine(k, Vector2i(x, f.position.y), Vector2(x * CELLA, f.position.y * CELLA), Vector2((x + 1) * CELLA, f.position.y * CELLA), m)
		_tratto_confine(k, Vector2i(x, f.end.y - 1), Vector2(x * CELLA, f.end.y * CELLA), Vector2((x + 1) * CELLA, f.end.y * CELLA), m)
	for y in range(f.position.y, f.end.y):
		_tratto_confine(k, Vector2i(f.position.x, y), Vector2(f.position.x * CELLA, y * CELLA), Vector2(f.position.x * CELLA, (y + 1) * CELLA), m)
		_tratto_confine(k, Vector2i(f.end.x - 1, y), Vector2(f.end.x * CELLA, y * CELLA), Vector2(f.end.x * CELLA, (y + 1) * CELLA), m)
	var nodo := MeshInstance3D.new()
	nodo.mesh = k.mesh()
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)


func _tratto_confine(k: LowPoly.Costruttore, cella: Vector2i, a: Vector2, b: Vector2, m: float) -> void:
	var h := terreno.altezza(cella) + 0.04
	var lato := Vector2(m, 0) if is_equal_approx(a.x, b.x) else Vector2(0, m)
	var p0 := a - lato
	var p1 := b - lato
	var p2 := b + lato
	var p3 := a + lato
	k.quad(Vector3(p0.x, h, p0.y), Vector3(p1.x, h, p1.y), Vector3(p2.x, h, p2.y), Vector3(p3.x, h, p3.y), Vector3.UP, CONFINE)


func _parete(k: LowPoly.Costruttore, a: Vector3, b: Vector3, sopra: float, sotto: float, n: Vector3, colore: Color) -> void:
	k.quad(Vector3(a.x, sopra, a.z), Vector3(b.x, sopra, b.z), Vector3(b.x, sotto, b.z), Vector3(a.x, sotto, a.z), n, colore)


# --- Alberi e rocce ----------------------------------------------------------

func _crea_alberi() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = terreno.seme + 7
	var tondi: Array[Transform3D] = []
	var pini: Array[Transform3D] = []
	for i in terreno.indici_tagliati:
		_tagliate[i] = true
	var nati_dopo := {}  # boschi piantati dal forestale: non fanno parte del bosco originale
	for i in terreno.nuovo_bosco:
		nati_dopo[i] = true
	for y in TerrenoFeudo.LATO:
		for x in TerrenoFeudo.LATO:
			var c := Vector2i(x, y)
			var indice := y * TerrenoFeudo.LATO + x
			var tipo := terreno.tipo_a(c)
			var quanti := 0
			# conta il bosco com'era all'inizio (anche le celle tagliate), così gli alberi sono
			# sempre gli stessi: diventano ceppi, poi ricrescono
			var bosco_originale := (tipo == TerrenoFeudo.Tipo.BOSCO and not nati_dopo.has(indice)) or _tagliate.has(indice)
			if bosco_originale:
				quanti = 2 if rng.randf() < 0.45 else 1
			elif (tipo == TerrenoFeudo.Tipo.ERBA or nati_dopo.has(indice)) and rng.randf() < 0.012:
				quanti = 1
			for i in quanti:
				var pos := Vector3((x + rng.randf_range(0.2, 0.8)) * CELLA, terreno.altezza(c), (y + rng.randf_range(0.2, 0.8)) * CELLA)
				var s := rng.randf_range(0.8, 1.25)
				var tr := LowPoly.t(pos, Vector3.ONE * s, rng.randf() * TAU)
				var pino := rng.randf() < 0.45
				var elenco: Array = _alberi_cella.get(indice, [])
				if pino:
					elenco.append([1, pini.size(), -1])
					pini.append(tr)
				else:
					elenco.append([0, tondi.size(), -1])
					tondi.append(tr)
				_alberi_cella[indice] = elenco

	var tronco := LowPoly.Costruttore.new().forma(LowPoly.cilindro(0.16, 0.12, 1.2, 5), LowPoly.t(Vector3(0, 0.6, 0)), TRONCO).mesh()
	var chioma_tonda := LowPoly.Costruttore.new().forma(LowPoly.sfera(0.95, 1.7, 7, 4), LowPoly.t(Vector3(0, 1.8, 0)), Color.WHITE).mesh()
	var chioma_pino := LowPoly.Costruttore.new() \
		.forma(LowPoly.cilindro(0.95, 0.0, 1.6, 7), LowPoly.t(Vector3(0, 1.5, 0)), Color.WHITE) \
		.forma(LowPoly.cilindro(0.7, 0.0, 1.3, 7), LowPoly.t(Vector3(0, 2.3, 0)), Color.WHITE).mesh()

	var tutti: Array[Transform3D] = []
	tutti.append_array(tondi)
	tutti.append_array(pini)
	for elenco in _alberi_cella.values():
		for albero in elenco:
			albero[2] = albero[1] if albero[0] == 0 else tondi.size() + albero[1]
	_orig_tondi = tondi
	_orig_pini = pini
	_orig_tronchi = tutti
	_tronchi = _multimesh(tronco, tutti, false)
	_tondi = _multimesh(chioma_tonda, tondi, true)
	_pini = _multimesh(chioma_pino, pini, true)
	for i in tondi.size():
		_variazioni_tondi.append(rng.randf_range(-0.08, 0.08))
	for i in pini.size():
		_variazioni_pini.append(rng.randf_range(-0.08, 0.08))

	# scorta di alberi per i prati dove il forestale pianta (lì all'inizio non c'era bosco)
	_pool_chiome = _multimesh(chioma_tonda, [] as Array[Transform3D], true, MASSIMO_PIANTATI)
	_pool_tronchi = _multimesh(tronco, [] as Array[Transform3D], false, MASSIMO_PIANTATI)
	_pool_chiome.multimesh.visible_instance_count = 0
	_pool_tronchi.multimesh.visible_instance_count = 0

	var da_sistemare := {}
	for i in _tagliate:
		da_sistemare[i] = true
	for i in terreno.piantine:
		da_sistemare[i] = true
	for i in nati_dopo:
		da_sistemare[i] = true
	for i in da_sistemare:
		_aggiorna_alberi(i)


## Le celle sono cambiate (bosco tagliato o ricresciuto, piantine, strade): alberi e suolo si aggiornano.
func aggiorna_celle(celle: Array) -> void:
	for c in celle:
		_aggiorna_alberi(c.y * TerrenoFeudo.LATO + c.x)
	_suoli_pronti.clear()
	_crea_mura()
	applica_stagione(GameState.stagione)


func _aggiorna_alberi(indice: int) -> void:
	var tipo: int = terreno.celle[indice]
	if tipo == TerrenoFeudo.Tipo.BOSCO:
		_tagliate.erase(indice)
		if not _alberi_cella.has(indice):
			_prendi_dalla_scorta(indice)
		_scala_alberi(indice, 1.0)
	elif terreno.piantine.has(indice):
		if not _alberi_cella.has(indice):
			_prendi_dalla_scorta(indice)
		# l'alberello cresce stagione dopo stagione
		var totale := float(GameState.bil.piantine.stagioni_per_crescere)
		var fatto := 1.0 - float(terreno.piantine[indice]) / totale
		_scala_alberi(indice, 0.25 + 0.55 * fatto)
	elif _alberi_cella.has(indice):
		_tagliate[indice] = true
		if terreno.ceppi.has(indice):
			_a_ceppo(indice)
		else:
			_sgombera(indice)


## Un albero in più dalla scorta, in una posizione fissa per quella cella.
func _prendi_dalla_scorta(indice: int) -> void:
	var n := _pool_chiome.multimesh.visible_instance_count
	if n >= MASSIMO_PIANTATI:
		return
	var c := Vector2i(indice % TerrenoFeudo.LATO, indice / TerrenoFeudo.LATO)
	var h := absi(hash(indice))
	var pos := Vector3((c.x + 0.3 + (h % 40) / 100.0) * CELLA, terreno.altezza(c), (c.y + 0.3 + (h / 40 % 40) / 100.0) * CELLA)
	var tr := LowPoly.t(pos, Vector3.ONE * (0.85 + (h % 30) / 100.0), float(h % 628) / 100.0)
	_orig_pool.append(tr)
	_pool_chiome.multimesh.set_instance_transform(n, tr)
	_pool_tronchi.multimesh.set_instance_transform(n, tr)
	_pool_chiome.multimesh.set_instance_color(n, CHIOMA_TONDA[GameState.stagione])
	_pool_chiome.multimesh.visible_instance_count = n + 1
	_pool_tronchi.multimesh.visible_instance_count = n + 1
	_alberi_cella[indice] = [[2, n, n]]


## Alberi della cella a una certa grandezza (1 = adulto), partendo dalla loro forma originale.
func _scala_alberi(indice: int, k: float) -> void:
	for albero in _alberi_cella.get(indice, []):
		var orig_chioma: Transform3D = _orig_della_chioma(albero)
		var orig_tronco: Transform3D = _orig_pool[albero[2]] if albero[0] == 2 else _orig_tronchi[albero[2]]
		_chiome_di(albero).set_instance_transform(albero[1], Transform3D(orig_chioma.basis * Basis.from_scale(Vector3.ONE * k), orig_chioma.origin))
		_tronchi_di(albero).set_instance_transform(albero[2], Transform3D(orig_tronco.basis * Basis.from_scale(Vector3.ONE * k), orig_tronco.origin))


func _a_ceppo(indice: int) -> void:
	for albero in _alberi_cella.get(indice, []):
		var orig_chioma: Transform3D = _orig_della_chioma(albero)
		var orig_tronco: Transform3D = _orig_pool[albero[2]] if albero[0] == 2 else _orig_tronchi[albero[2]]
		_chiome_di(albero).set_instance_transform(albero[1], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), orig_chioma.origin))
		_tronchi_di(albero).set_instance_transform(albero[2], Transform3D(orig_tronco.basis * Basis.from_scale(Vector3(1.3, 0.25, 1.3)), orig_tronco.origin))


## Tolti i ceppi: la cella è libera, degli alberi non resta nulla.
func _sgombera(indice: int) -> void:
	for albero in _alberi_cella.get(indice, []):
		var orig_chioma: Transform3D = _orig_della_chioma(albero)
		var orig_tronco: Transform3D = _orig_pool[albero[2]] if albero[0] == 2 else _orig_tronchi[albero[2]]
		_chiome_di(albero).set_instance_transform(albero[1], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), orig_chioma.origin))
		_tronchi_di(albero).set_instance_transform(albero[2], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), orig_tronco.origin))


func _orig_della_chioma(albero: Array) -> Transform3D:
	match int(albero[0]):
		0:
			return _orig_tondi[albero[1]]
		1:
			return _orig_pini[albero[1]]
		_:
			return _orig_pool[albero[1]]


func _chiome_di(albero: Array) -> MultiMesh:
	match int(albero[0]):
		0:
			return _tondi.multimesh
		1:
			return _pini.multimesh
		_:
			return _pool_chiome.multimesh


func _tronchi_di(albero: Array) -> MultiMesh:
	return _pool_tronchi.multimesh if int(albero[0]) == 2 else _tronchi.multimesh


# --- Piante selvatiche ------------------------------------------------------------

## Ciuffi colorati dove crescono orzo, grano e rape selvatici.
func _crea_ciuffi() -> void:
	var trasformazioni: Array[Transform3D] = []
	var colori: Array[Color] = []
	for i in terreno.selvatiche:
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		var colore := Color(GameState.colture[terreno.selvatiche[i]].colore)
		for k in 4:
			var h := absi(hash(i * 7 + k))
			var pos := Vector3((c.x + 0.15 + (h % 70) / 100.0) * CELLA, terreno.altezza(c), (c.y + 0.15 + (h / 70 % 70) / 100.0) * CELLA)
			trasformazioni.append(LowPoly.t(pos, Vector3.ONE * (0.8 + (h % 40) / 100.0), float(h % 628) / 100.0))
			colori.append(colore.lightened(((h % 20) - 10) / 100.0))
			_ciuffi_cella[i] = _ciuffi_cella.get(i, []) + [trasformazioni.size() - 1]
	var ciuffo := LowPoly.Costruttore.new() \
		.forma(LowPoly.cilindro(0.18, 0.0, 0.7, 4), LowPoly.t(Vector3(0, 0.35, 0)), Color.WHITE) \
		.forma(LowPoly.cilindro(0.14, 0.0, 0.55, 4), LowPoly.t(Vector3(0.18, 0.27, 0.06)), Color.WHITE) \
		.forma(LowPoly.cilindro(0.14, 0.0, 0.5, 4), LowPoly.t(Vector3(-0.15, 0.25, -0.08)), Color.WHITE).mesh()
	_ciuffi = _multimesh(ciuffo, trasformazioni, true)
	_ciuffi_orig = trasformazioni
	for n in colori.size():
		_ciuffi.multimesh.set_instance_color(n, colori[n])


## Dove c'è un edificio (es. un campo sopra le piante selvatiche) i ciuffi non si vedono.
func aggiorna_ciuffi() -> void:
	if _ciuffi == null:
		return
	for i in _ciuffi_cella:
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		var nascosto := terreno.edificio_a(c) >= 0 or terreno.muro_a(c)
		for n in _ciuffi_cella[i]:
			var tr: Transform3D = _ciuffi_orig[n]
			_ciuffi.multimesh.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), tr.origin) if nascosto else tr)


# --- Zona dell'edificio da piazzare -------------------------------------------------

## Colora le celle che contano per l'edificio: bosco, rocce, acqua o la fertilità della terra.
func mostra_zona(tipo: String, cella: Vector2i) -> void:
	var celle := terreno.celle_zona(tipo, cella)
	if celle.is_empty():
		nascondi_zona()
		return
	var fertilita: bool = GameState.edifici[tipo].zona.tipo == "fertilita"
	var colorate := []
	for coppia in celle:
		var valore: float = coppia[1]
		var colore := Color(1.0, 0.92, 0.35, 0.3 + 0.3 * valore)
		if fertilita:
			colore = Color(0.85, 0.25, 0.15).lerp(Color(0.25, 0.85, 0.25), valore)
			colore.a = 0.45
		colorate.append([coppia[0], colore])
	_disegna_celle(colorate)


## Colora un elenco di celle tutte dello stesso colore (es. il percorso di una strada).
func mostra_celle(celle: Array, colore: Color) -> void:
	_disegna_celle(celle.map(func(c): return [c, colore]))


func _disegna_celle(colorate: Array) -> void:
	var k := LowPoly.Costruttore.new()
	for coppia in colorate:
		var c: Vector2i = coppia[0]
		var colore: Color = coppia[1]
		var h := terreno.altezza(c) + 0.06
		var x0 := c.x * CELLA + 0.15
		var z0 := c.y * CELLA + 0.15
		var x1 := (c.x + 1) * CELLA - 0.15
		var z1 := (c.y + 1) * CELLA - 0.15
		k.quad(Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.UP, colore)
	var mesh := k.mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mesh.surface_set_material(0, mat)
	if _zona == null:
		_zona = MeshInstance3D.new()
		_zona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_zona)
	_zona.mesh = mesh
	_zona.position = Vector3.ZERO
	_zona.visible = true


func nascondi_zona() -> void:
	if _zona:
		_zona.visible = false


func _multimesh(mesh: Mesh, trasformazioni: Array[Transform3D], colori: bool, quante := -1) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colori
	mm.mesh = mesh
	mm.instance_count = trasformazioni.size() if quante < 0 else quante
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
	var masso := LowPoly.sfera(0.8, 1.1, 6, 3)  # la stessa forma per tutti: letta una volta sola
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
