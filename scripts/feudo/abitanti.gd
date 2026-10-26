class_name Abitanti3D
extends Node3D
## Gli abitanti che camminano per il feudo. Sono solo decorativi: ogni persona ha una casa
## (tenda o casa) e, se lavora, un edificio dove va e viene; i disoccupati gironzolano
## attorno al falò (poi la piazza). Quando ci sono strade vicino a partenza e arrivo,
## camminano lungo le strade. Al massimo MASSIMO persone visibili, per restare leggeri su telefono.

const MASSIMO := 40
const VELOCITA := 1.6  # metri al secondo, a velocità x1
const TUNICHE := [Color("7a4a3a"), Color("4a6a8a"), Color("6a7a3a"), Color("8a6a3a"), Color("5a4a6a"), Color("9a8a6a")]
const PELLE := Color("e0b08a")
const VICINO_STRADA := 3  # celle: entro questa distanza si va a prendere la strada

var vista: VistaTerreno

var _persone: Array = []  # {nodo, casa, lavoro, destinazione: Vector3, tappe: Array[Vector3], attesa, verso_lavoro}
var _firma := ""           # per ricalcolare case e lavori solo quando cambiano
var _mesh: Array[ArrayMesh] = []
var _tempo := 0.0


func _ready() -> void:
	for tunica in TUNICHE:
		_mesh.append(_crea_mesh(tunica))
	GameState.changed.connect(_ricalcola)
	GameState.banditi_avvistati.connect(func(_d): _tutti_si_muovono())
	GameState.incursione.connect(func(_e): _tutti_si_muovono())
	_ricalcola()


func _crea_mesh(tunica: Color) -> ArrayMesh:
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cubo(Vector3(0.3, 0.32, 0.2)), LowPoly.t(Vector3(0, 0.16, 0)), Color("3a2e26"))
	k.forma(LowPoly.cilindro(0.24, 0.19, 0.62, 6), LowPoly.t(Vector3(0, 0.62, 0)), tunica)
	k.forma(LowPoly.sfera(0.17, 0.34, 6, 3), LowPoly.t(Vector3(0, 1.1, 0)), PELLE)
	k.forma(LowPoly.cilindro(0.2, 0.12, 0.12, 6), LowPoly.t(Vector3(0, 1.26, 0)), tunica.darkened(0.3))
	return k.mesh()


## Assegna a ogni persona una casa e, a chi lavora, un edificio. Rifatto solo se cambia qualcosa.
func _ricalcola() -> void:
	var case: Array = []   # un posto letto per voce: id dell'edificio
	var lavori: Array = []  # un lavoratore per voce: id dell'edificio
	for b in GameState.buildings:
		if b.progresso < 1.0:
			continue
		for i in int(GameState.def_di(b).get("alloggi", 0)):
			case.append(b.id)
		for i in int(b.lavoratori):
			lavori.append(b.id)
	var quante := mini(GameState.abitanti, MASSIMO)
	var firma := "%d|%s|%s" % [quante, str(case), str(lavori)]
	if firma == _firma:
		return
	_firma = firma
	while _persone.size() < quante:
		_aggiungi_persona()
	while _persone.size() > quante:
		_persone.pop_back().nodo.queue_free()
	for i in _persone.size():
		var p: Dictionary = _persone[i]
		p.casa = case[i] if i < case.size() else -1
		p.lavoro = lavori[i] if i < lavori.size() else -1


func _aggiungi_persona() -> void:
	var nodo := MeshInstance3D.new()
	nodo.mesh = _mesh[_persone.size() % _mesh.size()]
	nodo.scale = Vector3.ONE * 1.15
	add_child(nodo)
	var partenza := _punto_falo()
	nodo.position = partenza
	_persone.append({"nodo": nodo, "casa": -1, "lavoro": -1, "destinazione": partenza, "tappe": [],
		"attesa": randf_range(0.0, 3.0), "verso_lavoro": true, "fase": randf() * TAU})


func _process(delta: float) -> void:
	var dt := delta * GameState.velocita
	_tempo += dt
	for p in _persone:
		var nodo: MeshInstance3D = p.nodo
		if p.attesa > 0.0:
			p.attesa -= dt
			if p.attesa <= 0.0:
				p.tappe = _cammino(nodo.position, _prossima_meta(p))
				p.destinazione = p.tappe.pop_front()
			continue
		var verso: Vector3 = p.destinazione - nodo.position
		verso.y = 0.0
		var passo := VELOCITA * dt * (2.0 if not GameState.banditi.is_empty() else 1.0)
		if verso.length() <= passo:
			nodo.position = Vector3(p.destinazione.x, _quota(p.destinazione), p.destinazione.z)
			if p.tappe.is_empty():
				p.attesa = _sosta(p)
			else:
				p.destinazione = p.tappe.pop_front()
			continue
		var direzione := verso.normalized()
		var pos := nodo.position + direzione * passo
		# un piccolo saltello mentre cammina
		pos.y = _quota(pos) + absf(sin(_tempo * 9.0 + p.fase)) * 0.08
		nodo.position = pos
		nodo.rotation.y = atan2(direzione.x, direzione.z)


## Quando cambia qualcosa di grosso (arrivano i banditi, se ne vanno) ognuno riparte subito.
func _tutti_si_muovono() -> void:
	for p in _persone:
		p.attesa = randf_range(0.0, 0.6)
		p.tappe = []
		p.destinazione = p.nodo.position


## Dove va ora: chi lavora fa avanti e indietro tra lavoro e casa, gli altri girano attorno al falò.
## Con i banditi in arrivo tutti corrono a rifugiarsi attorno alla dimora del signore.
func _prossima_meta(p: Dictionary) -> Vector3:
	if not GameState.banditi.is_empty():
		for b in GameState.buildings:
			if b.tipo == "dimora":
				return _punto_attorno(b.id)
	if p.lavoro >= 0 and (p.verso_lavoro or p.casa < 0):
		p.verso_lavoro = randf() < 0.75  # di solito resta a lavorare, ogni tanto torna a casa
		return _punto_attorno(p.lavoro)
	if p.lavoro >= 0:
		p.verso_lavoro = true
		return _punto_attorno(p.casa)
	if p.casa >= 0 and randf() < 0.3:
		return _punto_attorno(p.casa)
	return _punto_falo()


func _sosta(p: Dictionary) -> float:
	if p.lavoro >= 0 and not p.verso_lavoro:
		return randf_range(6.0, 12.0)  # appena arrivato al lavoro: lavora un po'
	return randf_range(2.0, 6.0)


## Un punto appena fuori dal bordo di un edificio, su un lato a caso.
func _punto_attorno(id: int) -> Vector3:
	var b := GameState.trova(id)
	if b.is_empty():
		return _punto_falo()
	var t: Array = GameState.edifici[b.tipo].taglia
	var w := float(t[0]) * VistaTerreno.CELLA / 2.0 + 0.6
	var d := float(t[1]) * VistaTerreno.CELLA / 2.0 + 0.6
	var centro := vista.centro_area(b.cella, Vector2i(int(t[0]), int(t[1])))
	var lato := randi() % 4
	var u := randf_range(-1.0, 1.0)
	var offset: Vector3 = [Vector3(u * w, 0, d), Vector3(u * w, 0, -d), Vector3(w, 0, u * d), Vector3(-w, 0, u * d)][lato]
	return centro + offset


## Le tappe per arrivare a una meta: se partenza e arrivo sono vicini alla stessa rete di strade
## si segue la strada (cella per cella), altrimenti si va dritti.
func _cammino(da: Vector3, a: Vector3) -> Array:
	var terreno := vista.terreno
	if terreno.strade.is_empty() or not GameState.banditi.is_empty():
		return [a]  # in guerra si corre dritti, strade o no
	var cella_da := _cella(da)
	var cella_a := _cella(a)
	var inizio := _strada_vicina(cella_da)
	var fine := _strada_vicina(cella_a)
	if inizio.x < 0 or fine.x < 0 or inizio == fine:
		return [a]
	var celle := _percorso_strade(inizio, fine)
	# non vale la pena prendere la strada se allunga troppo il giro
	var diretto := Vector2(cella_a - cella_da).length()
	if celle.is_empty() or celle.size() > diretto * 2.5 + 6:
		return [a]
	var tappe := []
	for c in celle:
		tappe.append(vista.centro_area(c, Vector2i.ONE))
	tappe.append(a)
	return tappe


func _cella(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / VistaTerreno.CELLA), floori(p.z / VistaTerreno.CELLA))


func _strada_vicina(c: Vector2i) -> Vector2i:
	var migliore := Vector2i(-1, -1)
	var dist := 1 << 30
	for dy in range(-VICINO_STRADA, VICINO_STRADA + 1):
		for dx in range(-VICINO_STRADA, VICINO_STRADA + 1):
			var v := c + Vector2i(dx, dy)
			if vista.terreno.strada_a(v) and dx * dx + dy * dy < dist:
				dist = dx * dx + dy * dy
				migliore = v
	return migliore


## Il cammino più corto lungo le strade (ricerca in ampiezza), [] se non sono collegate.
func _percorso_strade(da: Vector2i, a: Vector2i) -> Array[Vector2i]:
	var da_dove := {da: da}
	var coda: Array[Vector2i] = [da]
	var i := 0
	while i < coda.size():
		var c := coda[i]
		i += 1
		if c == a:
			break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + dir
			if not da_dove.has(v) and vista.terreno.strada_a(v):
				da_dove[v] = c
				coda.append(v)
	var cammino: Array[Vector2i] = []
	if not da_dove.has(a):
		return cammino
	var indietro := a
	while indietro != da:
		cammino.push_front(indietro)
		indietro = da_dove[indietro]
	cammino.push_front(da)
	return cammino


func _punto_falo() -> Vector3:
	for b in GameState.buildings:
		if b.tipo == "falo" or b.tipo == "piazza":
			var c := vista.centro_area(b.cella, Vector2i(2, 2))
			var a := randf() * TAU
			return c + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 5.0)
	var centro := Vector2(TerrenoFeudo.centro_feudo()) * VistaTerreno.CELLA
	return Vector3(centro.x, 0, centro.y)


func _quota(p: Vector3) -> float:
	var c := Vector2i(floori(p.x / VistaTerreno.CELLA), floori(p.z / VistaTerreno.CELLA))
	return maxf(vista.terreno.altezza(c), 0.0)  # sull'acqua camminano sulla riva (niente bagni)
