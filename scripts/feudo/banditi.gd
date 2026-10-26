class_name Banditi3D
extends Node3D
## La banda di banditi che si vede sul feudo: compare al confine quando è avvistata, cammina verso
## la dimora del signore e ci arriva quando scatta l'incursione (GameState.banditi.mancano).
## Poi scappa da dove è venuta: di corsa se è stata respinta, con i sacchi se ha saccheggiato.
## Solo grafica: la battaglia la decide GameState.

const MANTELLO := Color("2e2a2a")
const FAZZOLETTO := Color("8a2a20")
const PELLE := Color("d0a07a")
const FUGA := 4.0  # metri al secondo, a velocità x1

var vista: VistaTerreno

var _mesh: ArrayMesh
var _mesh_sacco: ArrayMesh
var _figure: Array[Node3D] = []
var _scarti: Array[Vector3] = []  # ognuno cammina un po' di lato agli altri
var _partenza := Vector3.ZERO
var _arrivo := Vector3.ZERO
var _in_fuga := false
var _tempo := 0.0


func _ready() -> void:
	_mesh = _crea_mesh(false)
	_mesh_sacco = _crea_mesh(true)
	GameState.banditi_avvistati.connect(_compaiono)
	GameState.incursione.connect(_scappano)
	if not GameState.banditi.is_empty():
		_compaiono(GameState.banditi)


func _crea_mesh(sacco: bool) -> ArrayMesh:
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cubo(Vector3(0.3, 0.32, 0.2)), LowPoly.t(Vector3(0, 0.16, 0)), Color("1e1a18"))
	k.forma(LowPoly.cilindro(0.26, 0.2, 0.64, 6), LowPoly.t(Vector3(0, 0.62, 0)), MANTELLO)
	k.forma(LowPoly.cilindro(0.2, 0.18, 0.1, 6), LowPoly.t(Vector3(0, 0.98, 0)), FAZZOLETTO)
	k.forma(LowPoly.sfera(0.17, 0.34, 6, 3), LowPoly.t(Vector3(0, 1.12, 0)), PELLE)
	# il cappuccio
	k.forma(LowPoly.cilindro(0.21, 0.04, 0.34, 6), LowPoly.t(Vector3(0, 1.32, -0.02)), MANTELLO)
	if sacco:
		k.forma(LowPoly.sfera(0.26, 0.36, 6, 3), LowPoly.t(Vector3(0, 0.95, -0.28)), Color("c8b48a"))
	else:
		# la torcia accesa, che si vede da lontano anche in mezzo al bosco
		k.forma(LowPoly.cilindro(0.05, 0.04, 1.0, 4), LowPoly.t(Vector3(0.32, 1.0, 0.1)), Color("5a3a1a"))
		k.forma(LowPoly.cilindro(0.16, 0.0, 0.45, 5), LowPoly.t(Vector3(0.32, 1.7, 0.1)), Color("ff8a1c"))
		k.forma(LowPoly.cilindro(0.09, 0.0, 0.3, 5), LowPoly.t(Vector3(0.32, 1.66, 0.1)), Color("ffe04a"))
	return k.mesh()


func _compaiono(dati: Dictionary) -> void:
	_togli_figure()
	_in_fuga = false
	var entrata: Vector2i = dati.entrata
	_partenza = vista.centro_area(entrata, Vector2i.ONE)
	_arrivo = _bersaglio()
	for i in int(dati.numero):
		var nodo := MeshInstance3D.new()
		nodo.mesh = _mesh
		nodo.scale = Vector3.ONE * 1.4
		add_child(nodo)
		_figure.append(nodo)
		var a := TAU * i / float(dati.numero)
		_scarti.append(Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 2.2))
		nodo.position = _partenza + _scarti[i]


## Dove vanno: la dimora del signore (o il centro del feudo).
func _bersaglio() -> Vector3:
	for b in GameState.buildings:
		if b.tipo == "dimora" or b.tipo == "piazza" or b.tipo == "falo":
			return vista.centro_area(b.cella, Vector2i(2, 2))
	var c := TerrenoFeudo.centro_feudo()
	return vista.centro_area(c, Vector2i.ONE)


func _scappano(esito: Dictionary) -> void:
	_in_fuga = true
	if not esito.vinto:
		for f in _figure:
			(f as MeshInstance3D).mesh = _mesh_sacco


func _process(delta: float) -> void:
	if _figure.is_empty():
		return
	var dt := delta * maxi(1, GameState.velocita)
	_tempo += dt
	for i in _figure.size():
		var f := _figure[i]
		var meta: Vector3
		if _in_fuga:
			meta = _partenza + _scarti[i]
			var verso := meta - f.position
			verso.y = 0.0
			var passo := FUGA * dt
			if verso.length() > passo:
				var pos := f.position + verso.normalized() * passo
				f.rotation.y = atan2(verso.x, verso.z)
				f.position = Vector3(pos.x, _quota(pos), pos.z)
		elif not GameState.banditi.is_empty():
			# avanzano in modo che arrivino alla meta proprio quando scatta l'incursione
			var totale := float(GameState.banditi.totale)
			var fatto := clampf((totale - float(GameState.banditi.mancano) + GameState._accumulo / float(GameState.bil.tick_secondi)) / totale, 0.0, 1.0)
			meta = _partenza.lerp(_arrivo, fatto) + _scarti[i] * (1.0 - 0.5 * fatto)
			var verso := meta - f.position
			verso.y = 0.0
			if verso.length() > 0.01:
				f.rotation.y = atan2(verso.x, verso.z)
			f.position = Vector3(meta.x, _quota(meta) + absf(sin(_tempo * 8.0 + i)) * 0.08, meta.z)
	# finita la fuga, spariscono oltre il confine
	if _in_fuga:
		var arrivati := true
		for i in _figure.size():
			var d := _figure[i].position - (_partenza + _scarti[i])
			d.y = 0.0
			if d.length() > 0.3:
				arrivati = false
		if arrivati:
			_togli_figure()


func _togli_figure() -> void:
	for f in _figure:
		f.queue_free()
	_figure.clear()
	_scarti.clear()


func _quota(p: Vector3) -> float:
	var c := Vector2i(floori(p.x / VistaTerreno.CELLA), floori(p.z / VistaTerreno.CELLA))
	return maxf(vista.terreno.altezza(c), 0.0)
