class_name Edificio3D
extends Node3D
## Un edificio del feudo. Se in art/models c'è un modello vero (vedi CatalogoModelli)
## lo usa; altrimenti lo costruisce con forme low-poly provvisorie.

const LEGNO := Color("9b6a3f")
const LEGNO_SCURO := Color("5a3a22")
const PIETRA := Color("9a9488")
const FINESTRA := Color("f2d27a")
const ORO := Color("ffe066")
const COLORI_RISORSE := {
	"legna": Color("8b5a2b"), "pietra": Color("a0a0a0"), "cibo": Color("c0392b"),
	"ferro": Color("4a5568"), "utensili": Color("c8ccd0"), "oro": Color("e5b53a"),
	"grano": Color("e0b84a"), "farina": Color("f2ead8"),
}

var b: Dictionary
var vista: VistaTerreno

var _corpo: MeshInstance3D
var _modello: Node3D  # modello vero, se trovato
var _altezza_modello := 0.0
var _parti_che_girano: Array[Node3D] = []
var _fase := -1  # fase del cantiere mostrata (con i modelli veri)
var _fiamme: MeshInstance3D
var _luce: OmniLight3D
var _bandiera: Node3D
var _oggetti: Array[Node3D] = []  # casse, barili, cataste: crescono con i miglioramenti
var _livello_mostrato := 1
var _stato_campo := ""
var _pale: MeshInstance3D
var _barra: MeshInstance3D
var _avviso: MeshInstance3D
var _cornice: MeshInstance3D
var _completo := false
var _stagione := -1
var _tempo := 0.0
var _arcieri: Node3D  # gli arcieri sopra la torre di guardia
var _arcieri_mostrati := -1
var _larghezza := 4.0
var _profondita := 4.0


func _ready() -> void:
	var d: Dictionary = GameState.edifici[b.tipo]
	# il modello si costruisce dritto e poi si gira: larghezza e profondità sono quelle di base
	var taglia := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
	_larghezza = taglia.x * VistaTerreno.CELLA
	_profondita = taglia.y * VistaTerreno.CELLA
	position = vista.centro_area(b.cella, GameState.taglia_di(b))
	rotation.y = -int(b.get("rot", 0)) * PI / 2.0
	_corpo = MeshInstance3D.new()
	add_child(_corpo)
	_cornice = _mesh(_crea_cornice())
	_cornice.visible = false
	_avviso = _mesh(LowPoly.Costruttore.new().forma(LowPoly.sfera(0.3, 0.6, 4, 2), LowPoly.t(Vector3.ZERO), Color("e03c31")).mesh())
	_avviso.visible = false
	_costruisci()
	GameState.capo_scelto.connect(_su_capo_scelto)
	_metti_bandiera()


func _process(delta: float) -> void:
	_tempo += delta
	var completo: bool = b.progresso >= 1.0
	var fase := _fase_cantiere()
	var stato_campo := "%s|%s|%d" % [b.get("coltura", ""), b.get("seminato", false), GameState.stagione]
	var campo_da_ridisegnare := _ha_forma("campo") and not _modello and stato_campo != _stato_campo
	var migliorato := int(b.get("livello", 1)) != _livello_mostrato
	if migliorato and completo and _completo:
		_costruisci()
		var corpo: Node3D = _modello if _modello else _corpo
		corpo.scale = Vector3.ONE * 0.85
		create_tween().tween_property(corpo, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif completo != _completo or campo_da_ridisegnare or (not completo and fase != _fase):
		var appena_finito := completo and not _completo
		_costruisci()
		if appena_finito:
			# l'edificio "sale" dal terreno con un piccolo rimbalzo
			var corpo: Node3D = _modello if _modello else _corpo
			corpo.scale = Vector3(1, 0.05, 1)
			create_tween().tween_property(corpo, "scale", Vector3.ONE, 0.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not completo and _barra:
		var p: float = maxf(b.progresso, 0.02)
		_barra.scale.x = p
		_barra.position.x = -(_larghezza - 0.8) * (1.0 - p) / 2.0
	if _pale:
		_pale.rotate_z(-delta * 1.5 * GameState.velocita)
	for parte in _parti_che_girano:
		parte.rotate_object_local(parte.get_meta("gira"), -delta * 1.5 * GameState.velocita)
	if _fiamme:
		# il fuoco tremola: fiamme che si allungano e luce che pulsa
		var f := 1.0 + 0.12 * sin(_tempo * 11.0) + 0.08 * sin(_tempo * 17.3)
		_fiamme.scale = Vector3(1.0 / sqrt(f), f, 1.0 / sqrt(f))
		_luce.light_energy = 2.2 + 0.5 * sin(_tempo * 9.0) + 0.3 * sin(_tempo * 23.0)
	if _avviso.visible:
		_avviso.position.y = _altezza_tetto() + 0.8 + sin(_tempo * 4.0) * 0.15
	if completo and GameState.edifici[b.tipo].has("arcieri") and int(b.get("arcieri", 0)) != _arcieri_mostrati:
		_metti_arcieri()


## Gli arcieri in cima alla torre, uno per lato, con l'arco. Quanti ne sono rimasti vivi.
func _metti_arcieri() -> void:
	_arcieri_mostrati = int(b.get("arcieri", 0))
	if _arcieri:
		_arcieri.queue_free()
	_arcieri = Node3D.new()
	add_child(_arcieri)
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cilindro(0.22, 0.17, 0.55, 6), LowPoly.t(Vector3(0, 0.28, 0)), Color("3f6b3a"))
	k.forma(LowPoly.sfera(0.15, 0.3, 6, 3), LowPoly.t(Vector3(0, 0.7, 0)), Color("e0b08a"))
	k.forma(LowPoly.cilindro(0.17, 0.05, 0.22, 6), LowPoly.t(Vector3(0, 0.88, 0)), Color("2f4b2a"))
	k.forma(LowPoly.cubo(Vector3(0.05, 0.9, 0.05)), LowPoly.t(Vector3(0.28, 0.55, 0.1)), Color("6b4a2e"))
	var mesh := k.mesh()
	var cima := _altezza_tetto()
	for i in _arcieri_mostrati:
		var a := MeshInstance3D.new()
		a.mesh = mesh
		a.scale = Vector3.ONE * 1.3
		var lato := -1.0 if i % 2 == 0 else 1.0
		a.position = Vector3(lato * 0.45, cima - 0.1, 0.3 * lato)
		a.rotation.y = lato * 0.8
		_arcieri.add_child(a)


func seleziona(attivo: bool) -> void:
	_cornice.visible = attivo


## Mostra il segnale rosso quando nessuno lavora nell'edificio.
func aggiorna() -> void:
	var d: Dictionary = GameState.edifici[b.tipo]
	_avviso.visible = b.progresso >= 1.0 and int(d.lavoratori) > 0 and b.lavoratori == 0


# --- Forme -------------------------------------------------------------------

func _ha_forma(forma: String) -> bool:
	return GameState.edifici[b.tipo].get("forma", "") == forma


func _costruisci() -> void:
	_completo = b.progresso >= 1.0
	_stagione = GameState.stagione
	_fase = _fase_cantiere()
	_livello_mostrato = int(b.get("livello", 1))
	_stato_campo = "%s|%s|%d" % [b.get("coltura", ""), b.get("seminato", false), GameState.stagione]
	_parti_che_girano.clear()
	for o in _oggetti:
		o.queue_free()
	_oggetti.clear()
	if _pale:
		_pale.queue_free()
		_pale = null
	if _barra:
		_barra.queue_free()
		_barra = null
	if _modello:
		_modello.queue_free()
		_modello = null
	if _fiamme:
		_fiamme.queue_free()
		_luce.queue_free()
		_fiamme = null
		_luce = null
	var k := LowPoly.Costruttore.new()
	if _completo and _ha_forma("falo"):
		_falo(k)
	elif _completo:
		_modello = CatalogoModelli.istanzia(b.tipo, _larghezza, _profondita, int(b.get("livello", 1)))
	else:
		_modello = CatalogoModelli.istanzia_cantiere(b.progresso, _larghezza, _profondita)
	if _modello:
		add_child(_modello)
		_altezza_modello = CatalogoModelli.ingombro(_modello).end.y
		_trova_parti_che_girano(_modello)
		if not _completo:
			_barra_avanzamento(k, _altezza_modello + 0.6)
	elif not _completo:
		_cantiere(k)
	else:
		var d: Dictionary = GameState.edifici[b.tipo]
		var tetto := Color(d.colore)
		match d.get("forma", ""):
			"falo":
				pass  # già disegnato da _falo()
			"tenda":
				match int(b.get("livello", 1)):
					1:
						_tenda(k, tetto, false)
					2:
						_tenda(k, tetto, true)
					_:
						_capanna(k)
			"campo":
				_campo(k)
			"chiesa":
				_casa(k, tetto, 0.75)
				_campanile(k, tetto)
			"castello":
				_castello(k, tetto)
			"mercato":
				_mercato(k)
			_:
				_casa(k, tetto, 1.0)
				if d.has("produce"):
					_mucchio(k, d.produce.keys()[0])
				if d.get("forma", "") == "mulino":
					_crea_pale()
	if _completo and b.tipo == "piazza":
		_selciato(k)
	if _completo and not _ha_forma("tenda"):
		_oggetti_del_livello()
	_corpo.mesh = k.mesh()
	aggiorna()


## Più è migliorato, più roba c'è attorno: casse e barili al livello 2, sacchi e cataste al 3.
func _oggetti_del_livello() -> void:
	var livello_b := int(b.get("livello", 1))
	if livello_b < 2:
		return
	var produce: Dictionary = GameState.edifici[b.tipo].get("produce", {})
	var catasta := "resource_stone" if produce.has("pietra") else "resource_lumber"
	var posti := [
		[["crate_a_big"], Vector3(-1, 0, 1)], [["barrel"], Vector3(1, 0, 1)],
	]
	if livello_b >= 3:
		posti.append([[catasta], Vector3(-1, 0, -1)])
		posti.append([["sack"], Vector3(1, 0, -1)])
	for posto in posti:
		var o := CatalogoModelli.istanzia_parole(posto[0], 1.0, 1.0)
		if o == null:
			continue
		var angolo: Vector3 = posto[1]
		o.position = Vector3(angolo.x * (_larghezza / 2.0 - 0.35), 0, angolo.z * (_profondita / 2.0 - 0.35))
		o.rotation.y = randf() * TAU
		add_child(o)
		_oggetti.append(o)


## Pietre in cerchio, ciocchi incrociati, fiamme che brillano da sole e una luce calda.
## Il pavimento in pietra della piazza: lastre un po' storte di grigi diversi, più larghe dell'area.
func _selciato(k: LowPoly.Costruttore) -> void:
	var lati := 5
	var passo := (_larghezza + 1.2) / lati
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.id) * 31
	for y in lati:
		for x in lati:
			var p := Vector3((x + 0.5) * passo - (_larghezza + 1.2) / 2.0, 0.04, (y + 0.5) * passo - (_profondita + 1.2) / 2.0)
			var colore := PIETRA.lightened(rng.randf_range(0.0, 0.25))
			k.forma(LowPoly.cubo(Vector3(passo * 0.92, 0.08, passo * 0.92)), LowPoly.t(p, Vector3.ONE, rng.randf_range(-0.08, 0.08)), colore)


func _falo(k: LowPoly.Costruttore) -> void:
	var pietra := PIETRA.darkened(0.15)
	for i in 9:
		var a := TAU * i / 9.0
		k.forma(LowPoly.sfera(0.28, 0.32, 5, 3), LowPoly.t(Vector3(cos(a), 0.12, sin(a)) * Vector3(1.05, 1, 1.05), Vector3(1.2, 1, 1), a), pietra.lightened(0.05 * (i % 3)))
	for i in 4:
		var a := PI / 4.0 * i
		var ciocco := Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, PI / 2.0 - 0.45), Vector3(0, 0.3, 0))
		k.forma(LowPoly.cilindro(0.1, 0.1, 1.2, 5), ciocco, LEGNO_SCURO)
	k.forma(LowPoly.cilindro(0.7, 0.75, 0.06, 9), LowPoly.t(Vector3(0, 0.03, 0)), Color("3a2a1e"))
	var fuoco := LowPoly.Costruttore.new()
	fuoco.forma(LowPoly.cilindro(0.42, 0.0, 1.1, 6), LowPoly.t(Vector3(0, 0.55, 0)), Color("e8641c"))
	fuoco.forma(LowPoly.cilindro(0.28, 0.0, 1.4, 5), LowPoly.t(Vector3(0.08, 0.7, 0.05), Vector3.ONE, 0.6), Color("f6a623"))
	fuoco.forma(LowPoly.cilindro(0.15, 0.0, 0.9, 5), LowPoly.t(Vector3(-0.05, 0.5, -0.06), Vector3.ONE, 1.2), Color("ffe58a"))
	var mesh := fuoco.mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mesh.surface_set_material(0, mat)
	_fiamme = _mesh(mesh)
	_fiamme.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_luce = OmniLight3D.new()
	_luce.light_color = Color("ff9a3c")
	_luce.omni_range = 9.0
	_luce.position = Vector3(0, 1.2, 0)
	add_child(_luce)


## Tenda da campo: telo a capanna, entrata scura davanti, pali e picchetti.
func _tenda(k: LowPoly.Costruttore, telo: Color, rinforzata: bool) -> void:
	var largo := _larghezza - (1.0 if rinforzata else 1.4)
	var lungo := _profondita - (0.7 if rinforzata else 1.0)
	var alto := 1.95 if rinforzata else 1.7
	k.forma(LowPoly.cubo(Vector3(largo + 0.4, 0.05, lungo + 0.3)), LowPoly.t(Vector3(0, 0.025, 0)), Color("8a7a5a"))
	k.forma(LowPoly.tetto(Vector3(largo, alto, lungo)), LowPoly.t(Vector3(0, alto / 2.0 + 0.05, 0)), telo)
	k.forma(LowPoly.tetto(Vector3(largo * 0.45, alto * 0.62, 0.06)), LowPoly.t(Vector3(0, alto * 0.31 + 0.05, lungo / 2.0 + 0.01)), Color("3a2a1e"))
	for z in [-lungo / 2.0 - 0.05, lungo / 2.0 + 0.05]:
		k.forma(LowPoly.cilindro(0.05, 0.05, alto + 0.35, 5), LowPoly.t(Vector3(0, (alto + 0.35) / 2.0, z)), LEGNO_SCURO)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.forma(LowPoly.cubo(Vector3(0.06, 0.25, 0.06)), LowPoly.t(Vector3(sx * (largo / 2.0 + 0.15), 0.12, sz * lungo * 0.35)), LEGNO_SCURO)
	if rinforzata:
		# toppe sul telo e una piccola legnaia sul fianco
		k.forma(LowPoly.cubo(Vector3(0.5, 0.4, 0.04)), LowPoly.t(Vector3(-largo * 0.22, alto * 0.45, lungo * 0.2), Vector3.ONE, 0.0), telo.darkened(0.25))
		for i in 3:
			k.forma(LowPoly.cilindro(0.09, 0.09, 0.9, 5), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(largo / 2.0 + 0.3, 0.1 + i * 0.17, -lungo * 0.2 + (i % 2) * 0.1)), LEGNO)


## Al terzo livello la tenda diventa una capanna di legno con il tetto di paglia.
func _capanna(k: LowPoly.Costruttore) -> void:
	_casa(k, Color("b8a058"), 0.8)


func _su_capo_scelto(_indice: int) -> void:
	_metti_bandiera()


## Accanto alla tenda di una famiglia, la bandiera del suo colore (dopo la scelta della guida).
func _metti_bandiera() -> void:
	if _bandiera:
		_bandiera.queue_free()
		_bandiera = null
	var i: int = b.get("famiglia", -1)
	if i < 0 or i >= GameState.famiglie.size() or GameState.famiglie[i].colore == "":
		return
	_bandiera = CatalogoModelli.istanzia_parole(["flag_" + GameState.famiglie[i].colore], 1.2, 1.2)
	if _bandiera:
		_bandiera.position = Vector3(_larghezza / 2.0 - 0.3, 0, _profondita / 2.0 - 0.3)
		add_child(_bandiera)


func _fase_cantiere() -> int:
	if b.progresso >= 1.0:
		return -1
	return int(b.progresso * CatalogoModelli.numero_fasi_cantiere())


func _trova_parti_che_girano(nodo: Node) -> void:
	if nodo.has_meta("gira"):
		_parti_che_girano.append(nodo)
	for figlio in nodo.get_children():
		_trova_parti_che_girano(figlio)


func _altezza_muri() -> float:
	return 1.4 + 0.2 * minf(_larghezza, _profondita) / VistaTerreno.CELLA


func _altezza_tetto() -> float:
	if _modello:
		return _altezza_modello
	return 0.25 + _altezza_muri() + 0.5 * minf(_larghezza, _profondita)


func _casa(k: LowPoly.Costruttore, tetto: Color, quota_larghezza: float) -> void:
	var ww := (_larghezza - 0.8) * quota_larghezza
	var dd := _profondita - 0.8
	var hw := _altezza_muri()
	var hr := 0.5 * minf(ww, dd)
	var zoccolo := 0.25
	k.forma(LowPoly.cubo(Vector3(ww + 0.2, zoccolo, dd + 0.2)), LowPoly.t(Vector3(0, zoccolo / 2, 0)), PIETRA)
	k.forma(LowPoly.cubo(Vector3(ww, hw, dd)), LowPoly.t(Vector3(0, zoccolo + hw / 2, 0)), LEGNO)
	# il colmo del tetto segue il lato più lungo
	var rot := PI / 2 if ww > dd else 0.0
	var dim := Vector3(dd + 0.4, hr, ww + 0.4) if ww > dd else Vector3(ww + 0.4, hr, dd + 0.4)
	k.forma(LowPoly.tetto(dim), LowPoly.t(Vector3(0, zoccolo + hw + hr / 2, 0), Vector3.ONE, rot), tetto)
	# porta, finestre e comignolo sul lato rivolto verso la telecamera iniziale (+Z)
	k.forma(LowPoly.cubo(Vector3(0.6, 1.0, 0.1)), LowPoly.t(Vector3(0, zoccolo + 0.5, dd / 2 + 0.04)), LEGNO_SCURO)
	if ww >= 3.0:
		for lato in [-1, 1]:
			k.forma(LowPoly.cubo(Vector3(0.4, 0.4, 0.08)), LowPoly.t(Vector3(lato * ww / 4, zoccolo + hw * 0.6, dd / 2 + 0.04)), FINESTRA)
	k.forma(LowPoly.cubo(Vector3(0.35, 1.0, 0.35)), LowPoly.t(Vector3(ww * 0.22, zoccolo + hw + hr * 0.55, -dd * 0.15)), PIETRA)


func _mucchio(k: LowPoly.Costruttore, risorsa: String) -> void:
	var colore: Color = COLORI_RISORSE.get(risorsa, PIETRA)
	var x := -_larghezza / 2 + 0.55
	var z := _profondita / 2 - 0.5
	k.forma(LowPoly.cubo(Vector3(0.6, 0.35, 0.5)), LowPoly.t(Vector3(x, 0.18, z)), colore)
	k.forma(LowPoly.cubo(Vector3(0.4, 0.3, 0.4)), LowPoly.t(Vector3(x + 0.1, 0.5, z - 0.05), Vector3.ONE, 0.4), colore.lightened(0.1))


## Il campo mostra la sua coltura: solchi di terra se non è seminato, file colorate
## che crescono nelle stagioni della coltura, neve d'inverno (tranne sulle rape, che ci crescono).
func _campo(k: LowPoly.Costruttore) -> void:
	var ww := _larghezza - 0.3
	var dd := _profondita - 0.3
	k.forma(LowPoly.cubo(Vector3(ww, 0.12, dd)), LowPoly.t(Vector3(0, 0.06, 0)), Color("7a5a36"))
	var c := GameState.coltura_di(b)
	var seminato: bool = b.get("seminato", false) and not c.is_empty()
	var inverno := GameState.stagione == GameState.INVERNO
	var colore := Color("5e4228")
	var alt := 0.06
	if seminato:
		# più avanti nella coltura, più alte le piante
		var posizione: int = c.stagioni.find(GameState.CHIAVI_STAGIONI[GameState.stagione])
		var crescita := 0.5 if posizione <= 0 else 1.0
		colore = Color(c.colore).lerp(Color("6aa040"), 0.5 * (1.0 - crescita))
		alt = 0.15 + 0.25 * crescita
	if inverno and GameState.dati_clima().get("neve", true) and not (seminato and "inverno" in c.stagioni):
		colore = Color("e6ecef")
		alt = 0.05
	var z := -dd / 2 + 0.45
	while z < dd / 2 - 0.2:
		k.forma(LowPoly.cubo(Vector3(ww - 0.5, alt, 0.28)), LowPoly.t(Vector3(0, 0.12 + alt / 2, z)), colore)
		z += 0.6


func _campanile(k: LowPoly.Costruttore, tetto: Color) -> void:
	var z := -_profondita / 2 + 1.0
	var x := _larghezza / 2 - 1.0
	var h := _altezza_tetto() + 1.0
	k.forma(LowPoly.cubo(Vector3(1.3, h, 1.3)), LowPoly.t(Vector3(x, h / 2, z)), PIETRA)
	k.forma(LowPoly.cilindro(1.0, 0.0, 1.8, 4), LowPoly.t(Vector3(x, h + 0.9, z), Vector3.ONE, PI / 4), tetto)


func _castello(k: LowPoly.Costruttore, tetto: Color) -> void:
	var ww := _larghezza - 1.2
	var dd := _profondita - 1.2
	k.forma(LowPoly.cubo(Vector3(ww, 1.6, dd)), LowPoly.t(Vector3(0, 0.8, 0)), PIETRA.darkened(0.1))
	k.forma(LowPoly.cubo(Vector3(ww * 0.55, 3.2, dd * 0.55)), LowPoly.t(Vector3(0, 1.6, 0)), PIETRA)
	k.forma(LowPoly.tetto(Vector3(ww * 0.6, 1.4, dd * 0.6)), LowPoly.t(Vector3(0, 3.9, 0)), tetto)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var p := Vector3(sx * ww / 2, 0, sz * dd / 2)
			k.forma(LowPoly.cilindro(0.7, 0.7, 3.6, 8), LowPoly.t(p + Vector3(0, 1.8, 0)), PIETRA)
			k.forma(LowPoly.cilindro(0.9, 0.0, 1.4, 8), LowPoly.t(p + Vector3(0, 4.3, 0)), tetto)


func _mercato(k: LowPoly.Costruttore) -> void:
	k.forma(LowPoly.cubo(Vector3(_larghezza - 0.4, 0.1, _profondita - 0.4)), LowPoly.t(Vector3(0, 0.05, 0)), PIETRA.lightened(0.1))
	var teli := [Color("c0392b"), Color("e5b53a"), Color("3f6f9f")]
	for i in 3:
		var x := (i - 1) * (_larghezza / 3.2)
		var z := 0.8 if i % 2 == 0 else -0.8
		k.forma(LowPoly.cubo(Vector3(1.4, 0.7, 0.8)), LowPoly.t(Vector3(x, 0.45, z)), LEGNO)
		k.forma(LowPoly.tetto(Vector3(1.7, 0.6, 1.2)), LowPoly.t(Vector3(x, 1.5, z)), teli[i])
		for sx in [-0.7, 0.7]:
			k.forma(LowPoly.cubo(Vector3(0.08, 1.2, 0.08)), LowPoly.t(Vector3(x + sx, 0.6, z + 0.5)), LEGNO_SCURO)


func _cantiere(k: LowPoly.Costruttore) -> void:
	var ww := _larghezza - 0.6
	var dd := _profondita - 0.6
	k.forma(LowPoly.cubo(Vector3(ww, 0.2, dd)), LowPoly.t(Vector3(0, 0.1, 0)), Color("8a7a62"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			k.forma(LowPoly.cubo(Vector3(0.14, 2.0, 0.14)), LowPoly.t(Vector3(sx * ww / 2.3, 1.1, sz * dd / 2.3)), LEGNO)
	k.forma(LowPoly.cubo(Vector3(ww * 0.9, 0.14, 0.14)), LowPoly.t(Vector3(0, 2.0, dd / 2.3)), LEGNO)
	k.forma(LowPoly.cubo(Vector3(ww * 0.9, 0.14, 0.14)), LowPoly.t(Vector3(0, 2.0, -dd / 2.3)), LEGNO)
	k.forma(LowPoly.cubo(Vector3(0.9, 0.3, 0.6)), LowPoly.t(Vector3(-ww / 4, 0.35, 0)), COLORI_RISORSE.legna)
	_barra_avanzamento(k, 2.8)


## Barra gialla sopra il cantiere: lo sfondo va nella mesh del corpo, la parte che cresce è a parte.
func _barra_avanzamento(k: LowPoly.Costruttore, quota: float) -> void:
	var lunga := _larghezza - 0.8
	k.forma(LowPoly.cubo(Vector3(lunga + 0.1, 0.16, 0.16)), LowPoly.t(Vector3(0, quota, 0)), Color(0.15, 0.1, 0.05))
	_barra = _mesh(LowPoly.Costruttore.new().forma(LowPoly.cubo(Vector3(lunga, 0.2, 0.2)), LowPoly.t(Vector3(0, quota, 0)), ORO).mesh())


func _crea_pale() -> void:
	var k := LowPoly.Costruttore.new()
	for i in 4:
		var rot := Basis(Vector3.FORWARD, i * PI / 2)
		k.forma(LowPoly.cubo(Vector3(0.35, 1.6, 0.05)), Transform3D(rot, rot * Vector3(0, 0.9, 0)), Color("e8dcc0"))
	k.forma(LowPoly.cubo(Vector3(0.3, 0.3, 0.3)), LowPoly.t(Vector3.ZERO), LEGNO_SCURO)
	_pale = _mesh(k.mesh())
	_pale.position = Vector3(0, 0.25 + _altezza_muri() + 0.3, (_profondita - 0.8) / 2 + 0.25)


func _crea_cornice() -> ArrayMesh:
	var k := LowPoly.Costruttore.new()
	var w := _larghezza
	var d := _profondita
	k.forma(LowPoly.cubo(Vector3(w, 0.12, 0.15)), LowPoly.t(Vector3(0, 0.06, d / 2)), ORO)
	k.forma(LowPoly.cubo(Vector3(w, 0.12, 0.15)), LowPoly.t(Vector3(0, 0.06, -d / 2)), ORO)
	k.forma(LowPoly.cubo(Vector3(0.15, 0.12, d)), LowPoly.t(Vector3(w / 2, 0.06, 0)), ORO)
	k.forma(LowPoly.cubo(Vector3(0.15, 0.12, d)), LowPoly.t(Vector3(-w / 2, 0.06, 0)), ORO)
	return k.mesh()


func _mesh(m: Mesh) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.mesh = m
	add_child(nodo)
	return nodo
