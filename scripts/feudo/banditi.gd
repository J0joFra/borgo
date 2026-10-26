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
var _cammino: Array[Vector3] = []  # i punti del percorso, sulla terra (o sui ponti)
var _lunghezze: Array[float] = []  # distanza percorsa fino a ogni punto
var _in_fuga := false
var _tempo_fuga := 0.0
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
	_prepara_cammino(dati.get("percorso", []))
	for i in int(dati.numero):
		var nodo := MeshInstance3D.new()
		nodo.mesh = _mesh
		nodo.scale = Vector3.ONE * 1.4
		add_child(nodo)
		_figure.append(nodo)
		var a := TAU * i / float(dati.numero)
		_scarti.append(Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.0))
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
	_tempo_fuga = 0.0
	if not esito.vinto:
		for f in _figure:
			(f as MeshInstance3D).mesh = _mesh_sacco


func _process(delta: float) -> void:
	if _figure.is_empty():
		return
	var dt := delta * maxi(1, GameState.velocita)
	_tempo += dt
	var vivi := GameState.banditi_vivi() if not _in_fuga else _figure.size()
	if not _in_fuga:
		_tira_frecce(delta)
	for i in _figure.size():
		var f := _figure[i]
		if not _in_fuga and i >= vivi and f.visible:
			_cade(f)
		if not f.visible:
			continue
		var meta: Vector3
		if _in_fuga:
			# scappano ripercorrendo la strada fatta all'andata
			var dove := _fatto_da(f.position)
			meta = _punto_a(maxf(0.0, dove - 0.08)) + _scarti[i] * 0.5
			if dove <= 0.01:
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
			meta = _punto_a(fatto) + _scarti[i] * (1.0 - 0.5 * fatto)
			var verso := meta - f.position
			verso.y = 0.0
			if verso.length() > 0.01:
				f.rotation.y = atan2(verso.x, verso.z)
			f.position = Vector3(meta.x, _quota(meta) + absf(sin(_tempo * 8.0 + i)) * 0.08, meta.z)
	# finita la fuga, spariscono oltre il confine
	if _in_fuga:
		_tempo_fuga += dt
		var arrivati := _tempo_fuga > 40.0
		for i in _figure.size():
			if not _figure[i].visible:
				continue
			var d := _figure[i].position - (_partenza + _scarti[i])
			d.y = 0.0
			if d.length() > 0.3 and _tempo_fuga <= 40.0:
				arrivati = false
		if arrivati:
			_togli_figure()


## Il percorso lo calcola GameState (attorno all'acqua e alle mura, lo stesso che usano gli
## arcieri per sapere quando tirare). Se le mura chiudono il borgo si fermano davanti alle mura.
func _prepara_cammino(celle: Array) -> void:
	_cammino.clear()
	_lunghezze.clear()
	if celle.size() < 2:
		_cammino = [_partenza, _arrivo]
	else:
		for cella in celle:
			_cammino.append(vista.centro_area(cella, Vector2i.ONE))
		var ultima: Vector2i = celle[celle.size() - 1]
		if Vector2(ultima).distance_to(Vector2(_arrivo.x, _arrivo.z) / VistaTerreno.CELLA) < 3.0:
			_cammino.append(_arrivo)
		else:
			_arrivo = _cammino[_cammino.size() - 1]
	var totale := 0.0
	_lunghezze.append(0.0)
	for k in range(1, _cammino.size()):
		totale += _cammino[k].distance_to(_cammino[k - 1])
		_lunghezze.append(totale)


## Il punto del percorso a una certa frazione (0 = confine, 1 = dimora).
func _punto_a(frazione: float) -> Vector3:
	if _cammino.size() < 2:
		return _partenza.lerp(_arrivo, frazione)
	var dist := frazione * _lunghezze[_lunghezze.size() - 1]
	for k in range(1, _cammino.size()):
		if _lunghezze[k] >= dist:
			var tratto := maxf(0.001, _lunghezze[k] - _lunghezze[k - 1])
			return _cammino[k - 1].lerp(_cammino[k], (dist - _lunghezze[k - 1]) / tratto)
	return _cammino[_cammino.size() - 1]


## A che frazione del percorso è più o meno questo punto (il punto del percorso più vicino).
func _fatto_da(p: Vector3) -> float:
	if _cammino.size() < 2:
		return 0.0
	var migliore := 0
	var dmin := INF
	for k in _cammino.size():
		var d := Vector2(_cammino[k].x - p.x, _cammino[k].z - p.z).length_squared()
		if d < dmin:
			dmin = d
			migliore = k
	return _lunghezze[migliore] / maxf(0.001, _lunghezze[_lunghezze.size() - 1])


## Un bandito colpito dalle frecce cade e sparisce.
func _cade(f: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(f, "rotation:x", PI / 2.0, 0.3)
	tw.tween_callback(func(): f.visible = false)


var _ricarica := 0.0


## Ogni tanto, da ogni torre con arcieri, parte una freccia verso il bandito più vicino nel raggio.
func _tira_frecce(delta: float) -> void:
	_ricarica -= delta * maxi(1, GameState.velocita)
	if _ricarica > 0.0 or GameState.banditi.is_empty():
		return
	_ricarica = 0.5
	for b in GameState.buildings:
		var n := int(b.get("arcieri", 0))
		if n <= 0 or b.progresso < 1.0:
			continue
		var bersaglio: Node3D = null
		for f in _figure:
			var c := Vector2i(floori(f.position.x / VistaTerreno.CELLA), floori(f.position.z / VistaTerreno.CELLA))
			if f.visible and GameState.in_tiro(b, c):
				bersaglio = f
				break
		if bersaglio == null:
			continue
		var da := vista.centro_area(b.cella, GameState.taglia_di(b)) + Vector3(0, 5.5, 0)
		_freccia(da, bersaglio.position + Vector3(0, 1.0, 0))


func _freccia(da: Vector3, a: Vector3) -> void:
	var f := MeshInstance3D.new()
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cubo(Vector3(0.06, 0.06, 0.9)), LowPoly.t(Vector3.ZERO), Color("5a3a1a"))
	k.forma(LowPoly.cubo(Vector3(0.12, 0.12, 0.15)), LowPoly.t(Vector3(0, 0, 0.45)), Color("c8ccd0"))
	f.mesh = k.mesh()
	add_child(f)
	f.position = da
	f.look_at_from_position(da, a, Vector3.UP)
	f.rotate_object_local(Vector3.UP, PI)
	var tw := create_tween()
	tw.tween_property(f, "position", a, 0.35)
	tw.tween_callback(f.queue_free)


func _togli_figure() -> void:
	for f in _figure:
		f.queue_free()
	_figure.clear()
	_scarti.clear()


func _quota(p: Vector3) -> float:
	var c := Vector2i(floori(p.x / VistaTerreno.CELLA), floori(p.z / VistaTerreno.CELLA))
	if vista.terreno.tipo_a(c) in [TerrenoFeudo.Tipo.ACQUA, TerrenoFeudo.Tipo.FIUME] and vista.terreno.ponte_vicino(c):
		return VistaTerreno.QUOTA_PONTE
	return maxf(vista.terreno.altezza(c), 0.0)
