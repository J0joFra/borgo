class_name Abitanti3D
extends Node3D
## Gli abitanti che camminano per il feudo. Sono solo decorativi: ogni persona ha una casa
## (tenda o casa) e, se lavora, un edificio dove va e viene; i disoccupati gironzolano
## attorno al falò (poi la piazza). Quando ci sono strade vicino a partenza e arrivo,
## camminano lungo le strade; altrimenti seguono un cammino a piedi che evita l'acqua.
## Al massimo MASSIMO persone visibili, per restare leggeri su telefono.

const MASSIMO := 40
const VELOCITA := 1.6  # metri al secondo, a velocità x1
const TUNICHE := [Color("7a4a3a"), Color("4a6a8a"), Color("6a7a3a"), Color("8a6a3a"), Color("5a4a6a"), Color("9a8a6a")]
const PELLE := Color("e0b08a")
const VICINO_STRADA := 3  # celle: entro questa distanza si va a prendere la strada
const TENTATIVI_PUNTO := 6  # quante volte provare a trovare un punto valido attorno a un edificio

var vista: VistaTerreno

var _persone: Array = []  # {nodo, casa, lavoro, destinazione: Vector3, tappe: Array[Vector3], attesa, verso_lavoro}
var _firma := ""           # per ricalcolare case e lavori solo quando cambiano
var _mesh: Array[ArrayMesh] = []
var _mesh_soldato: ArrayMesh
var _tempo := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(GameState.seme) if "seme" in GameState else 0
	for tunica in TUNICHE:
		_mesh.append(_crea_mesh(tunica))
	_mesh_soldato = _crea_soldato()
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


## Un soldato: tunica rossa, elmo e lancia.
func _crea_soldato() -> ArrayMesh:
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cubo(Vector3(0.3, 0.32, 0.2)), LowPoly.t(Vector3(0, 0.16, 0)), Color("3a2e26"))
	k.forma(LowPoly.cilindro(0.25, 0.2, 0.62, 6), LowPoly.t(Vector3(0, 0.62, 0)), Color("a8322a"))
	k.forma(LowPoly.sfera(0.17, 0.34, 6, 3), LowPoly.t(Vector3(0, 1.1, 0)), PELLE)
	k.forma(LowPoly.sfera(0.2, 0.22, 6, 3), LowPoly.t(Vector3(0, 1.22, 0)), Color("8a9098"))
	k.forma(LowPoly.cilindro(0.03, 0.03, 1.8, 4), LowPoly.t(Vector3(0.3, 0.9, 0.05)), Color("6b4a2e"))
	k.forma(LowPoly.cilindro(0.07, 0.0, 0.25, 4), LowPoly.t(Vector3(0.3, 1.9, 0.05)), Color("c8ccd0"))
	return k.mesh()


## Assegna a ogni persona una casa e, a chi lavora, un edificio. Rifatto solo se cambia qualcosa.
## I soldati a casa stanno attorno alla caserma.
func _ricalcola() -> void:
	var case: Array = []   # un posto letto per voce: id dell'edificio
	var lavori: Array = []  # un lavoratore per voce: id dell'edificio
	var caserme: Array = []
	for b in GameState.buildings:
		if b.progresso < 1.0:
			continue
		for i in int(GameState.def_di(b).get("alloggi", 0)):
			case.append(b.id)
		for i in int(b.lavoratori):
			lavori.append(b.id)
		if int(GameState.def_di(b).get("formazioni", 0)) > 0:
			caserme.append(b.id)
	var soldati_visti := 0 if caserme.is_empty() else mini(GameState.soldati_presenti(), MASSIMO / 3)
	var in_caserma: Array = []
	for i in soldati_visti:
		in_caserma.append(caserme[i % caserme.size()])
	lavori = in_caserma + lavori
	var quante := mini(GameState.abitanti, MASSIMO)
	var firma := "%d|%s|%s|%d" % [quante, str(case), str(lavori), soldati_visti]
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
		var soldato := i < soldati_visti
		(p.nodo as MeshInstance3D).mesh = _mesh_soldato if soldato else _mesh[i % _mesh.size()]


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
				# se il cammino è vuoto (partenza = arrivo), aspetta di nuovo un attimo
				if p.tappe.is_empty():
					p.attesa = _sosta(p)
				else:
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
## Con i banditi in arrivo tutti corrono a rifugiarsi attorno alla dimora del signore (o alla caserma,
## o al falò se non c'è altro).
func _prossima_meta(p: Dictionary) -> Vector3:
	if not GameState.banditi.is_empty():
		for b in GameState.buildings:
			if b.tipo == "dimora":
				return _punto_attorno(b.id)
		for b in GameState.buildings:
			if int(GameState.def_di(b).get("formazioni", 0)) > 0:
				return _punto_attorno(b.id)
		return _punto_falo()
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


## Un punto appena fuori dal bordo di un edificio, su un lato a caso, che sia percorribile.
## Se tutti i tentativi cadono su acqua o fuori mappa, torna al centro dell'edificio.
func _punto_attorno(id: int) -> Vector3:
	var b := GameState.trova(id)
	if b.is_empty():
		return _punto_falo()
	var t := GameState.taglia_di(b)
	var w := float(t.x) * VistaTerreno.CELLA / 2.0 + 0.6
	var d := float(t.y) * VistaTerreno.CELLA / 2.0 + 0.6
	var centro := vista.centro_area(b.cella, t)
	for i in TENTATIVI_PUNTO:
		var lato := _rng.randi() % 4
		var u := _rng.randf_range(-1.0, 1.0)
		var offset: Vector3 = [Vector3(u * w, 0, d), Vector3(u * w, 0, -d), Vector3(w, 0, u * d), Vector3(-w, 0, u * d)][lato]
		var p := centro + offset
		if vista.terreno.percorribile(_cella(p)):
			return p
	# fallback: centro dell'edificio (sempre su terra, dato che non si costruisce sull'acqua)
	return centro


## Le tappe per arrivare a una meta. Prova prima la strada; se non conviene o non c'è,
## usa un cammino a piedi che evita l'acqua. In guerra si corre dritti solo se la linea
## diretta non attraversa acqua.
func _cammino(da: Vector3, a: Vector3) -> Array:
	var terreno := vista.terreno
	if GameState.banditi.is_empty() and not terreno.strade.is_empty():
		var inizio := _strada_vicina(da)
		var fine := _strada_vicina(a)
		if inizio.x >= 0 and fine.x >= 0 and inizio != fine:
			var vertici := _percorso_strade(inizio, fine)
			# non vale la pena prendere la strada se allunga troppo il giro
			var diretto := Vector2(a.x - da.x, a.z - da.z).length() / VistaTerreno.CELLA
			if not vertici.is_empty() and vertici.size() <= diretto * 2.5 + 6:
				var tappe := []
				for v in vertici:
					tappe.append(vista.vertice(v))
				tappe.append(a)
				return tappe
	# niente strada: cammino a piedi che evita l'acqua
	return _cammino_terra(da, a)


## Cammino a piedi fra due punti che evita l'acqua (usa terreno.cammino, che già controlla
## percorribile e non taglia gli angoli). Restituisce i punti 3D delle celle.
## Se la meta non è raggiungibile, si ferma alla cella percorribile più vicina.
func _cammino_terra(da: Vector3, a: Vector3) -> Array:
	var terreno := vista.terreno
	var c_da := _cella(da)
	var c_a := _cella(a)
	if c_da == c_a or not terreno.dentro(c_da) or not terreno.dentro(c_a):
		return [a]
	if not terreno.percorribile(c_da):
		# partenza su acqua o mura: la persona "salta" alla cella percorribile più vicina
		c_da = _cella_percorribile_vicina(c_da)
		if c_da.x < 0:
			return [a]
	var celle_c := terreno.cammino(c_da, c_a)
	if celle_c.is_empty():
		return [a]
	var tappe := []
	for i in range(1, celle_c.size()):
		tappe.append(vista.centro_area(celle_c[i], Vector2i.ONE))
	# se il cammino non arriva esattamente alla meta, aggiungi il punto finale esatto
	if not tappe.is_empty() or celle_c.size() == 1:
		tappe.append(a)
	return tappe


## La cella percorribile più vicina a una data (spirale). (-1,-1) se non ne trova.
func _cella_percorribile_vicina(c: Vector2i) -> Vector2i:
	for raggio in range(0, 8):
		for y in range(-raggio, raggio + 1):
			for x in range(-raggio, raggio + 1):
				if maxi(absi(x), absi(y)) != raggio:
					continue
				var v := c + Vector2i(x, y)
				if vista.terreno.dentro(v) and vista.terreno.percorribile(v):
					return v
	return Vector2i(-1, -1)


func _cella(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / VistaTerreno.CELLA), floori(p.z / VistaTerreno.CELLA))


## Il vertice di strada più vicino a un punto, entro VICINO_STRADA celle, che sia anche
## raggiungibile a piedi dal punto (o (-1, -1)).
func _strada_vicina(p: Vector3) -> Vector2i:
	var v0 := Vector2i(roundi(p.x / VistaTerreno.CELLA), roundi(p.z / VistaTerreno.CELLA))
	var migliore := Vector2i(-1, -1)
	var dist := 1 << 30
	for dy in range(-VICINO_STRADA, VICINO_STRADA + 1):
		for dx in range(-VICINO_STRADA, VICINO_STRADA + 1):
			var v := v0 + Vector2i(dx, dy)
			if dx * dx + dy * dy >= dist:
				continue
			if not vista.terreno.vertice_su_strada(v):
				continue
			# il vertice è su strada, ma le celle attorno devono essere raggiungibili a piedi
			# (es. un ponte sopra l'acqua non basta se non c'è modo di arrivarci)
			if not _vertice_raggiungibile(v, v0):
				continue
			dist = dx * dx + dy * dy
			migliore = v
	return migliore


## Vero se esiste almeno una cella percorribile adiacente al vertice (o il vertice stesso
## è su terra) e il vertice è raggiungibile in linea retta senza attraversare acqua.
func _vertice_raggiungibile(v: Vector2i, da: Vector2i) -> bool:
	# il vertice tocca 4 celle: se almeno una è percorribile, ci si può arrivare
	var attorno := [v, v + Vector2i(-1, 0), v + Vector2i(0, -1), v + Vector2i(-1, -1)]
	var almeno_terra := false
	for c in attorno:
		if vista.terreno.dentro(c) and vista.terreno.percorribile(c):
			almeno_terra = true
			break
	if not almeno_terra:
		return false
	# e il percorso in linea retta da "da" al vertice non deve attraversare solo acqua
	var c_da := _cella_percorribile_vicina(da)
	if c_da.x < 0:
		return false
	var celle := vista.terreno.cammino(c_da, v)
	if celle.is_empty():
		return false
	# se il cammino arriva vicino al vertice, ok
	return Vector2(celle[celle.size() - 1] - v).length() <= 1.5


## Il cammino più corto lungo le strade, di vertice in vertice (ricerca in ampiezza), [] se non
## sono collegate.
func _percorso_strade(da: Vector2i, a: Vector2i) -> Array[Vector2i]:
	var da_dove := {da: da}
	var coda: Array[Vector2i] = [da]
	var i := 0
	while i < coda.size():
		var c := coda[i]
		i += 1
		if c == a:
			break
		for dir in TerrenoFeudo.DIREZIONI:
			var v: Vector2i = c + dir
			if not da_dove.has(v) and vista.terreno.lato_strada(c, v):
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


## Un punto attorno al falò (o alla piazza), su una cella percorribile.
func _punto_falo() -> Vector3:
	for b in GameState.buildings:
		if b.tipo == "falo" or b.tipo == "piazza":
			var t := GameState.taglia_di(b)
			var c := vista.centro_area(b.cella, t)
			for i in TENTATIVI_PUNTO:
				var a := _rng.randf() * TAU
				var p := c + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 5.0)
				if vista.terreno.percorribile(_cella(p)):
					return p
			return c
	var centro := Vector2(TerrenoFeudo.centro_feudo()) * VistaTerreno.CELLA
	return Vector3(centro.x, 0, centro.y)


func _quota(p: Vector3) -> float:
	var c := Vector2i(floori(p.x / VistaTerreno.CELLA), floori(p.z / VistaTerreno.CELLA))
	if vista.terreno.tipo_a(c) in [TerrenoFeudo.Tipo.ACQUA, TerrenoFeudo.Tipo.FIUME] and vista.terreno.ponte_vicino(c):
		return VistaTerreno.QUOTA_PONTE  # sopra il ponte o la passerella
	return maxf(vista.terreno.altezza(c), 0.0)  # sull'acqua camminano sulla riva (niente bagni)
