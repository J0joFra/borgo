class_name TerrenoFeudo
extends RefCounted
## Logica del terreno: tipo e altezza di ogni cella, celle occupate, regole di piazzamento.
## Il mondo è più grande del feudo: attorno ci sono le terre dei vicini, che si vedono
## ma dove non si costruisce. Nessuna grafica: la disegna VistaTerreno.
## Ogni cella ha anche una fertilità (0..1) per i campi. Gli edifici che raccolgono
## dalla natura rendono in base alla loro "zona": celle di bosco, roccia, lago o fiume
## attorno, oppure fertilità sotto il campo. I taglialegna consumano il bosco.

enum Tipo { ERBA, ERBA_FIORI, BOSCO, ACQUA, ROCCIA, COLLINA, SENTIERO, FIUME }

const LATO := 112  # lato del mondo, in celle
const FEUDO := Rect2i(32, 32, 48, 48)  # le celle del giocatore, al centro del mondo
const PER_NOME := {
	"bosco": Tipo.BOSCO, "acqua": Tipo.ACQUA, "fiume": Tipo.FIUME,
	"roccia": Tipo.ROCCIA, "collina": Tipo.COLLINA,
}
const COSTRUIBILE := [Tipo.ERBA, Tipo.ERBA_FIORI, Tipo.COLLINA, Tipo.SENTIERO]
const ALTEZZE := {Tipo.ACQUA: -0.35, Tipo.FIUME: -0.35, Tipo.ROCCIA: 0.45, Tipo.COLLINA: 0.6}

var seme: int
var celle := PackedByteArray()
var fertilita := PackedFloat32Array()  # 0..1 per cella: quanto rende un campo
var tagliati := PackedInt32Array()     # celle di bosco abbattute dai taglialegna (si salvano)
var _occupato: Dictionary = {}  # Vector2i -> id edificio


func _init(s: int) -> void:
	seme = s
	_genera()


func _genera() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var acqua := FastNoiseLite.new()
	acqua.seed = seme
	acqua.frequency = 0.07
	var bosco := FastNoiseLite.new()
	bosco.seed = seme + 1
	bosco.frequency = 0.1

	celle.resize(LATO * LATO)
	for y in LATO:
		for x in LATO:
			var a := acqua.get_noise_2d(x, y)
			var t := Tipo.ERBA
			if a < -0.45:
				t = Tipo.ACQUA
			elif a > 0.5:
				t = Tipo.ROCCIA
			elif a > 0.36:
				t = Tipo.COLLINA
			elif bosco.get_noise_2d(x, y) > 0.25:
				t = Tipo.BOSCO
			elif rng.randf() < 0.15:
				t = Tipo.ERBA_FIORI
			celle[y * LATO + x] = t

	# Garantisce bosco, lago e roccia a pochi passi dal centro del feudo, in direzioni casuali.
	var centro := Vector2(FEUDO.get_center())
	var angolo := rng.randf() * TAU
	_macchia(centro + Vector2.from_angle(angolo) * 10.0, 5.0, Tipo.BOSCO)
	_macchia(centro + Vector2.from_angle(angolo + 2.1) * 10.0, 3.5, Tipo.ACQUA)
	var monte := centro + Vector2.from_angle(angolo + 4.2) * 11.0
	_macchia(monte, 4.5, Tipo.COLLINA)
	_macchia(monte, 2.0, Tipo.ROCCIA)
	_macchia(centro, 5.0, Tipo.ERBA)
	_traccia_fiume(rng)
	_calcola_fertilita()


## Un fiume largo due celle che attraversa tutto il mondo e passa nel feudo,
## lontano almeno 9 celle dall'accampamento.
func _traccia_fiume(rng: RandomNumberGenerator) -> void:
	var centro := FEUDO.get_center()
	var verticale := rng.randf() < 0.5
	var lato := 1 if rng.randf() < 0.5 else -1
	var pos := float(lato * rng.randi_range(11, 15))  # distanza dal centro, sull'asse trasversale
	var deriva := 0.0
	for passo in LATO:
		deriva = clampf(deriva + rng.randf_range(-0.35, 0.35), -0.8, 0.8)
		pos += deriva
		# non avvicinarsi troppo all'accampamento, né uscire dal feudo
		if absf(pos) < 9.0:
			pos = 9.0 * signf(pos if pos != 0.0 else float(lato))
			deriva = -deriva
		pos = clampf(pos, -20.0, 20.0)
		for spessore in 2:
			var trasversale := int(round(pos)) + spessore
			var c := Vector2i(passo, centro.y + trasversale) if not verticale else Vector2i(centro.x + trasversale, passo)
			if dentro(c):
				celle[c.y * LATO + c.x] = Tipo.FIUME


## Fertilità: rumore lento, più alta vicino all'acqua (terra di fiume e di lago).
func _calcola_fertilita() -> void:
	var rumore := FastNoiseLite.new()
	rumore.seed = seme + 5
	rumore.frequency = 0.045
	fertilita.resize(LATO * LATO)
	for y in LATO:
		for x in LATO:
			fertilita[y * LATO + x] = clampf((rumore.get_noise_2d(x, y) + 0.6) / 1.4, 0.0, 1.0)
	var bagnate := {}
	for y in LATO:
		for x in LATO:
			if celle[y * LATO + x] in [Tipo.ACQUA, Tipo.FIUME]:
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var c := Vector2i(x + dx, y + dy)
						if dentro(c):
							var vicino := 1.0 - Vector2(dx, dy).length() / 4.5
							bagnate[c] = maxf(bagnate.get(c, 0.0), vicino)
	for c in bagnate:
		var i: int = c.y * LATO + c.x
		fertilita[i] = clampf(fertilita[i] + 0.35 * bagnate[c], 0.0, 1.0)


func _macchia(centro: Vector2, raggio: float, t: int) -> void:
	for y in range(int(centro.y - raggio), int(centro.y + raggio) + 1):
		for x in range(int(centro.x - raggio), int(centro.x + raggio) + 1):
			if x >= 0 and y >= 0 and x < LATO and y < LATO and centro.distance_to(Vector2(x, y)) <= raggio:
				celle[y * LATO + x] = t


# --- Lettura -----------------------------------------------------------------

func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < LATO and c.y < LATO


func nel_feudo(c: Vector2i) -> bool:
	return FEUDO.has_point(c)


static func centro_feudo() -> Vector2i:
	return FEUDO.get_center()


func tipo_a(c: Vector2i) -> int:
	return celle[c.y * LATO + c.x] if dentro(c) else -1


func altezza(c: Vector2i) -> float:
	return ALTEZZE.get(tipo_a(c), 0.0)


func edificio_a(c: Vector2i) -> int:
	return _occupato.get(c, -1)


# --- Occupazione -------------------------------------------------------------

func occupa(b: Dictionary) -> void:
	var taglia: Array = GameState.edifici[b.tipo].taglia
	for y in int(taglia[1]):
		for x in int(taglia[0]):
			_occupato[b.cella + Vector2i(x, y)] = b.id


func libera(b: Dictionary) -> void:
	for c in _occupato.keys():
		if _occupato[c] == b.id:
			_occupato.erase(c)


# --- Regole di piazzamento ---------------------------------------------------

func posizione_valida(tipo: String, cella: Vector2i) -> bool:
	var d: Dictionary = GameState.edifici[tipo]
	var richiesto: int = PER_NOME.get(d.get("su", ""), -1)
	var quota := altezza(cella)
	for y in int(d.taglia[1]):
		for x in int(d.taglia[0]):
			var c := cella + Vector2i(x, y)
			var t := tipo_a(c)
			if not nel_feudo(c) or _occupato.has(c) or altezza(c) != quota:
				return false
			if richiesto >= 0 and t != richiesto:
				return false
			if richiesto < 0 and not t in COSTRUIBILE:
				return false
	return true


# --- Zone e rese ---------------------------------------------------------------

func fertilita_a(c: Vector2i) -> float:
	return fertilita[c.y * LATO + c.x] if dentro(c) else 0.0


## Quanto rende un edificio della natura messo qui, rispetto alla sua produzione base
## (1.0 = base). Dipende da cosa c'è attorno e, per la pesca, dalla stagione.
func resa(tipo: String, cella: Vector2i, stagione: int) -> float:
	return float(info_zona(tipo, cella, stagione).resa)


## Resa e spiegazione per l'interfaccia: {resa, testo}.
func info_zona(tipo: String, cella: Vector2i, stagione: int) -> Dictionary:
	var d: Dictionary = GameState.edifici[tipo]
	if not d.has("zona"):
		return {"resa": 1.0, "testo": ""}
	var z: Dictionary = d.zona
	var taglia := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
	var massimo := float(z.get("massimo", 2.0))
	var minimo := float(z.get("minimo", 0.0))
	match z.tipo:
		"fertilita":
			var somma := 0.0
			for y in taglia.y:
				for x in taglia.x:
					somma += fertilita_a(cella + Vector2i(x, y))
			var media := somma / (taglia.x * taglia.y)
			return {"resa": minimo + (massimo - minimo) * media, "testo": "terra fertile al %d%%" % int(media * 100)}
		"acqua":
			var lago := conta_attorno(cella, taglia, int(z.raggio), Tipo.ACQUA)
			var fiume := conta_attorno(cella, taglia, int(z.raggio), Tipo.FIUME)
			var f_lago := 1.0
			var f_fiume := 1.0
			if stagione == GameState.INVERNO:
				f_lago = float(z.inverno.lago)
				f_fiume = float(z.inverno.fiume)
			var r := minf(massimo, lago * float(z.lago) * f_lago + fiume * float(z.fiume) * f_fiume)
			var testo := "%d celle di lago, %d di fiume" % [lago, fiume]
			if stagione == GameState.INVERNO and lago > 0:
				testo += " (lago ghiacciato)"
			return {"resa": r, "testo": testo}
		_:
			var cercato: int = PER_NOME[z.tipo]
			var n := conta_attorno(cella, taglia, int(z.raggio), cercato)
			var r := clampf(minimo + n * float(z.per_cella), 0.0, massimo)
			return {"resa": r, "testo": "%d celle di %s" % [n, z.tipo]}


## Quante celle di un tipo ci sono entro un raggio dall'area dell'edificio.
func conta_attorno(cella: Vector2i, taglia: Vector2i, raggio: int, cercato: int) -> int:
	var n := 0
	for y in range(cella.y - raggio, cella.y + taglia.y + raggio):
		for x in range(cella.x - raggio, cella.x + taglia.x + raggio):
			if tipo_a(Vector2i(x, y)) == cercato:
				n += 1
	return n


## Le celle che contano per la zona di un edificio messo qui, con un valore 0..1
## (per colorarle mentre si sceglie dove costruire).
func celle_zona(tipo: String, cella: Vector2i) -> Array:
	var d: Dictionary = GameState.edifici[tipo]
	var risultato := []
	if not d.has("zona"):
		return risultato
	var z: Dictionary = d.zona
	var taglia := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
	if z.tipo == "fertilita":
		for y in range(cella.y - 5, cella.y + taglia.y + 5):
			for x in range(cella.x - 5, cella.x + taglia.x + 5):
				var c := Vector2i(x, y)
				if nel_feudo(c) and tipo_a(c) in COSTRUIBILE:
					risultato.append([c, fertilita_a(c)])
		return risultato
	var r := int(z.raggio)
	var cercati := [Tipo.ACQUA, Tipo.FIUME] if z.tipo == "acqua" else [PER_NOME[z.tipo]]
	for y in range(cella.y - r, cella.y + taglia.y + r):
		for x in range(cella.x - r, cella.x + taglia.x + r):
			var c := Vector2i(x, y)
			if tipo_a(c) in cercati:
				risultato.append([c, 1.0])
	return risultato


# --- Disboscamento -------------------------------------------------------------

## Abbatte le n celle di bosco più vicine all'edificio (entro il raggio) e le
## trasforma in radura. Restituisce le celle tagliate.
func taglia_bosco(cella: Vector2i, taglia: Vector2i, raggio: int, n: int) -> Array[Vector2i]:
	var centro := Vector2(cella) + Vector2(taglia) / 2.0
	var candidati: Array[Vector2i] = []
	for y in range(cella.y - raggio, cella.y + taglia.y + raggio):
		for x in range(cella.x - raggio, cella.x + taglia.x + raggio):
			var c := Vector2i(x, y)
			if tipo_a(c) == Tipo.BOSCO:
				candidati.append(c)
	candidati.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return centro.distance_squared_to(Vector2(a) + Vector2(0.5, 0.5)) < centro.distance_squared_to(Vector2(b) + Vector2(0.5, 0.5)))
	var tagliate: Array[Vector2i] = []
	for c in candidati.slice(0, n):
		celle[c.y * LATO + c.x] = Tipo.ERBA
		tagliati.append(c.y * LATO + c.x)
		tagliate.append(c)
	return tagliate


## Rimette i tagli di un salvataggio.
func applica_tagli(indici: Array) -> void:
	for i in indici:
		celle[int(i)] = Tipo.ERBA
		tagliati.append(int(i))


## Cerca a spirale il posto valido più vicino a una cella.
func trova_posto(tipo: String, vicino_a: Vector2i) -> Vector2i:
	for raggio in 20:
		for y in range(-raggio, raggio + 1):
			for x in range(-raggio, raggio + 1):
				if maxi(absi(x), absi(y)) != raggio:
					continue
				var c := vicino_a + Vector2i(x, y)
				if posizione_valida(tipo, c):
					return c
	return Vector2i(-1, -1)
