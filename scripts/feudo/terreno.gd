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
var selvatiche: Dictionary = {}  # indice cella -> coltura che ci cresce da sola (orzo, grano, rape)
var piantine: Dictionary = {}    # indice cella -> stagioni che mancano perché diventi bosco
var nuovo_bosco := PackedInt32Array()  # celle di prato diventate bosco grazie al forestale
var strade: Dictionary = {}      # indice cella -> true
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
	_semina_selvatiche(rng)


## Una macchia di piante selvatiche per ogni coltura, a 7-15 celle dall'accampamento.
func _semina_selvatiche(rng: RandomNumberGenerator) -> void:
	var centro := Vector2(FEUDO.get_center())
	var nomi: Array = GameState.nomi_colture() if GameState.colture.size() > 0 else []
	var angolo := rng.randf() * TAU
	for i in nomi.size():
		var dove := centro + Vector2.from_angle(angolo + TAU * i / nomi.size()) * rng.randf_range(7.0, 15.0)
		for y in range(int(dove.y) - 2, int(dove.y) + 3):
			for x in range(int(dove.x) - 2, int(dove.x) + 3):
				var c := Vector2i(x, y)
				if nel_feudo(c) and tipo_a(c) in [Tipo.ERBA, Tipo.ERBA_FIORI] and dove.distance_to(Vector2(x, y)) <= 1.9:
					selvatiche[y * LATO + x] = nomi[i]


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
			var i := c.y * LATO + c.x
			if not nel_feudo(c) or _occupato.has(c) or altezza(c) != quota or strade.has(i) or piantine.has(i):
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
		"radura":
			var n := candidati_piantine(cella, taglia, int(z.raggio)).size()
			return {"resa": 1.0, "testo": "%d celle dove ripiantare" % n}
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
	if z.tipo == "radura":
		for c in candidati_piantine(cella, taglia, r):
			risultato.append([c, 1.0 if tagliati.has(c.y * LATO + c.x) else 0.5])
		return risultato
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


# --- Piante selvatiche ----------------------------------------------------------

## La coltura selvatica che cresce sotto un'area (la prima trovata), oppure "".
func selvatica_sotto(cella: Vector2i, taglia: Vector2i) -> String:
	for y in taglia.y:
		for x in taglia.x:
			var c := cella + Vector2i(x, y)
			var i := c.y * LATO + c.x
			if dentro(c) and selvatiche.has(i):
				return selvatiche[i]
	return ""


## Quante celle selvatiche di ogni coltura ci sono entro un raggio: {orzo: 5, ...}
func selvatiche_attorno(cella: Vector2i, taglia: Vector2i, raggio: int) -> Dictionary:
	var conteggio := {}
	for y in range(cella.y - raggio, cella.y + taglia.y + raggio):
		for x in range(cella.x - raggio, cella.x + taglia.x + raggio):
			var i := y * LATO + x
			if dentro(Vector2i(x, y)) and selvatiche.has(i):
				conteggio[selvatiche[i]] = conteggio.get(selvatiche[i], 0) + 1
	return conteggio


func selvatica_piu_vicina(da: Vector2i) -> String:
	var migliore := ""
	var distanza := INF
	for i in selvatiche:
		var d := Vector2(da).distance_squared_to(Vector2(i % LATO, i / LATO))
		if d < distanza:
			distanza = d
			migliore = selvatiche[i]
	return migliore


# --- Piantine del forestale ------------------------------------------------------

## Dove il forestale può piantare: prima le radure lasciate dai taglialegna, poi i prati liberi.
func candidati_piantine(cella: Vector2i, taglia: Vector2i, raggio: int) -> Array[Vector2i]:
	var centro := Vector2(cella) + Vector2(taglia) / 2.0
	var radure: Array[Vector2i] = []
	var prati: Array[Vector2i] = []
	for y in range(cella.y - raggio, cella.y + taglia.y + raggio):
		for x in range(cella.x - raggio, cella.x + taglia.x + raggio):
			var c := Vector2i(x, y)
			var i := y * LATO + x
			if not nel_feudo(c) or _occupato.has(c) or strade.has(i) or piantine.has(i) or selvatiche.has(i):
				continue
			if not tipo_a(c) in [Tipo.ERBA, Tipo.ERBA_FIORI]:
				continue
			if tagliati.has(i):
				radure.append(c)
			else:
				prati.append(c)
	var vicino := func(a: Vector2i, b: Vector2i) -> bool:
		return centro.distance_squared_to(Vector2(a)) < centro.distance_squared_to(Vector2(b))
	radure.sort_custom(vicino)
	prati.sort_custom(vicino)
	return radure + prati


## Pianta n alberelli; diventano bosco dopo "stagioni" stagioni. Restituisce le celle piantate.
func pianta(cella: Vector2i, taglia: Vector2i, raggio: int, n: int, stagioni: int) -> Array:
	var piantate := []
	for c in candidati_piantine(cella, taglia, raggio).slice(0, n):
		piantine[c.y * LATO + c.x] = stagioni
		piantate.append(c)
	return piantate


## Fa crescere tutte le piantine di una stagione; quelle pronte diventano bosco.
## Restituisce tutte le celle cambiate (anche quelle solo cresciute un po').
func cresci_piantine() -> Array:
	var cambiate := []
	for i in piantine.keys():
		piantine[i] -= 1
		var c := Vector2i(i % LATO, i / LATO)
		cambiate.append(c)
		if piantine[i] <= 0:
			piantine.erase(i)
			celle[i] = Tipo.BOSCO
			var t := tagliati.find(i)
			if t >= 0:
				tagliati.remove_at(t)
			else:
				nuovo_bosco.append(i)
	return cambiate


# --- Strade -------------------------------------------------------------------

## Il percorso a L tra due celle: prima in orizzontale, poi in verticale.
static func percorso(da: Vector2i, a: Vector2i) -> Array[Vector2i]:
	var celle_p: Array[Vector2i] = []
	var passo_x := 1 if a.x >= da.x else -1
	var passo_y := 1 if a.y >= da.y else -1
	for x in range(da.x, a.x + passo_x, passo_x):
		celle_p.append(Vector2i(x, da.y))
	for y in range(da.y + passo_y, a.y + passo_y, passo_y):
		celle_p.append(Vector2i(a.x, y))
	return celle_p


## Pietra necessaria: 1 per cella in piano, 2 in salita (collina o cambio di quota);
## le celle già strada non costano. -1 se una cella non si può usare.
func costo_strada(celle_s: Array) -> int:
	var costo := 0
	var quota_prima := NAN
	for c in celle_s:
		var i: int = c.y * LATO + c.x
		if not nel_feudo(c) or _occupato.has(c) or piantine.has(i):
			return -1
		if not tipo_a(c) in [Tipo.ERBA, Tipo.ERBA_FIORI, Tipo.COLLINA, Tipo.SENTIERO]:
			return -1
		var quota := altezza(c)
		if not strade.has(i):
			var salita := tipo_a(c) == Tipo.COLLINA or (not is_nan(quota_prima) and quota != quota_prima)
			costo += 2 if salita else 1
		quota_prima = quota
	return costo


func aggiungi_strada(celle_s: Array) -> Array:
	var nuove := []
	for c in celle_s:
		var i: int = c.y * LATO + c.x
		if not strade.has(i):
			strade[i] = true
			nuove.append(c)
	return nuove


func rimuovi_strada(c: Vector2i) -> bool:
	return strade.erase(c.y * LATO + c.x)


func strada_a(c: Vector2i) -> bool:
	return strade.has(c.y * LATO + c.x)


# --- Salvataggio ---------------------------------------------------------------

func salva() -> Dictionary:
	return {"strade": strade.keys(), "piantine": piantine, "nuovo_bosco": Array(nuovo_bosco)}


func applica_salvataggio(d: Dictionary) -> void:
	for i in d.get("strade", []):
		strade[int(i)] = true
	for i in d.get("nuovo_bosco", []):
		celle[int(i)] = Tipo.BOSCO
		nuovo_bosco.append(int(i))
	var p: Dictionary = d.get("piantine", {})
	for k in p:
		piantine[int(k)] = int(p[k])


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
