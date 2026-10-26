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
var _pale: MeshInstance3D
var _barra: MeshInstance3D
var _avviso: MeshInstance3D
var _cornice: MeshInstance3D
var _completo := false
var _stagione := -1
var _tempo := 0.0
var _larghezza := 4.0
var _profondita := 4.0


func _ready() -> void:
	var d: Dictionary = GameState.edifici[b.tipo]
	var taglia := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
	_larghezza = taglia.x * VistaTerreno.CELLA
	_profondita = taglia.y * VistaTerreno.CELLA
	position = vista.centro_area(b.cella, taglia)
	_corpo = MeshInstance3D.new()
	add_child(_corpo)
	_cornice = _mesh(_crea_cornice())
	_cornice.visible = false
	_avviso = _mesh(LowPoly.Costruttore.new().forma(LowPoly.sfera(0.3, 0.6, 4, 2), LowPoly.t(Vector3.ZERO), Color("e03c31")).mesh())
	_avviso.visible = false
	_costruisci()


func _process(delta: float) -> void:
	_tempo += delta
	var completo: bool = b.progresso >= 1.0
	var fase := _fase_cantiere()
	var campo_da_ridisegnare := _stagione != GameState.stagione and _ha_forma("campo") and not _modello
	if completo != _completo or campo_da_ridisegnare or (not completo and fase != _fase):
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
	if _avviso.visible:
		_avviso.position.y = _altezza_tetto() + 0.8 + sin(_tempo * 4.0) * 0.15


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
	_parti_che_girano.clear()
	if _pale:
		_pale.queue_free()
		_pale = null
	if _barra:
		_barra.queue_free()
		_barra = null
	if _modello:
		_modello.queue_free()
		_modello = null
	var k := LowPoly.Costruttore.new()
	if _completo:
		_modello = CatalogoModelli.istanzia(b.tipo, _larghezza, _profondita)
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
	_corpo.mesh = k.mesh()
	aggiorna()


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


func _campo(k: LowPoly.Costruttore) -> void:
	var colture := [Color("7cb84f"), Color("b8b04a"), Color("e0b84a"), Color("e6ecef")]
	var ww := _larghezza - 0.3
	var dd := _profondita - 0.3
	k.forma(LowPoly.cubo(Vector3(ww, 0.12, dd)), LowPoly.t(Vector3(0, 0.06, 0)), Color("7a5a36"))
	var alt := 0.05 if GameState.stagione == GameState.INVERNO else 0.3
	var z := -dd / 2 + 0.45
	while z < dd / 2 - 0.2:
		k.forma(LowPoly.cubo(Vector3(ww - 0.5, alt, 0.28)), LowPoly.t(Vector3(0, 0.12 + alt / 2, z)), colture[GameState.stagione])
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
