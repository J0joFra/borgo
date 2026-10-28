class_name TerrenoFeudo
extends RefCounted
## Logica del terreno: tipo e altezza di ogni cella, celle occupate, regole di piazzamento.
## Il mondo è più grande del feudo: attorno ci sono le terre dei vicini, che si vedono
## ma dove non si costruisce. Nessuna grafica: la disegna VistaTerreno.
## Le strade non occupano celle: corrono lungo i bordi fra una cella e l'altra, da un vertice
## della griglia al vicino (i vertici vanno da 0 a LATO). Così gli edifici si possono accostare
## e la strada passa loro accanto. Le mura invece occupano le loro celle.
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

# --- fertilità e acqua --------------------------------------------------------
const FERT_ACQUA_RAGGIO := 3      # raggio d'influenza dell'acqua sulla fertilità
const FERT_ACQUA_PESO := 0.06     # contributo di una cella d'acqua a distanza 0
const FERT_ACQUA_TETTO := 0.55    # bonus massimo cumulabile dall'acqua
const FERT_FIUME_MOLT := 1.35     # il fiume fertiliizza più del lago (limo)

var seme: int
var celle := PackedByteArray()
var fertilita := PackedFloat32Array()  # 0..1 per cella: quanto rende un campo
var indici_tagliati := PackedInt32Array()  # indici (int) delle celle di bosco abbattute
var ceppi: Dictionary = {}             # indice cella -> stagioni prima che i ceppi siano tolti e ci si possa costruire
var selvatiche: Dictionary = {}  # indice cella -> coltura che ci cresce da sola (orzo, grano, rape)
var piantine: Dictionary = {}    # indice cella -> stagioni che mancano perché diventi bosco
var nuovo_bosco := PackedInt32Array()  # celle di prato diventate bosco grazie al forestale
var strade: Dictionary = {}      # chiave del lato (vedi lato) -> true: le strade corrono sui bordi delle celle
var mura: Dictionary = {}        # indice cella -> true: mura in pietra (occupano la cella)
var _occupato: Dictionary = {}   # Vector2i -> id edificio
var _celle_di: Dictionary = {}   # id edificio -> Array[Vector2i] (mappa inversa per libera() O(1))


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


## Fertilità: rumore lento + contributo cumulativo dell'acqua vicina.
## Più celle d'acqua (lago o fiume) attorno, più la terra è fertile,
## con un peso che cala col quadrato della distanza e un tetto per evitare saturazione.
func _calcola_fertilita() -> void:
	var rumore := FastNoiseLite.new()
	rumore.seed = seme + 5
	rumore.frequency = 0.045
	fertilita.resize(LATO * LATO)

	# 1) base: rumore lento, indipendente dall'acqua
	for y in LATO:
		for x in LATO:
			fertilita[y * LATO + x] = clampf((rumore.get_noise_2d(x, y) + 0.6) / 1.4, 0.0, 1.0)

	# 2) contributo dell'acqua: accumulo pesato (somma, non max).
	#    Ogni cella d'acqua sparge il suo peso nelle celle entro il raggio,
	#    con peso 1 al centro e 0 al bordo (curva quadratica: vicino conta molto).
	var bonus := PackedFloat32Array()
	bonus.resize(LATO * LATO)
	var r := FERT_ACQUA_RAGGIO
	var r2 := float(r * r)
	for y in LATO:
		for x in LATO:
			var t := celle[y * LATO + x]
			if t != Tipo.ACQUA and t != Tipo.FIUME:
				continue
			var moltiplicatore := FERT_FIUME_MOLT if t == Tipo.FIUME else 1.0
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= LATO or ny >= LATO:
						continue
					var d2 := float(dx * dx + dy * dy)
					if d2 > r2:
						continue
					var peso := 1.0 - d2 / r2
					peso *= peso  # curva più marcata: l'acqua adiacente pesa molto
					bonus[ny * LATO + nx] += peso * FERT_ACQUA_PESO * moltiplicatore

	# 3) somma col tetto: più acqua attorno = più fertile, ma senza saturare a 1.0
	for i in fertilita.size():
		fertilita[i] = clampf(fertilita[i] + minf(bonus[i], FERT_ACQUA_TETTO), 0.0, 1.0)


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
	var taglia := GameState.taglia_di(b)
	var celle_ed: Array[Vector2i] = []
	for y in taglia.y:
		for x in taglia.x:
			var c: Vector2i = b.cella + Vector2i(x, y)
			_occupato[c] = b.id
			celle_ed.append(c)
	_celle_di[b.id] = celle_ed


func libera(b: Dictionary) -> void:
	for c in _celle_di.get(b.id, []):
		_occupato.erase(c)
	_celle_di.erase(b.id)


# --- Regole di piazzamento ---------------------------------------------------

## rot: rotazione di 90° in 90° (0..3); con 1 e 3 larghezza e profondità si scambiano.
## Le strade sul bordo non danno fastidio; una strada che passerebbe dentro l'edificio sì.
func posizione_valida(tipo: String, cella: Vector2i, rot := 0) -> bool:
	var d: Dictionary = GameState.edifici[tipo]
	var richiesto: int = PER_NOME.get(d.get("su", ""), -1)
	var quota := altezza(cella)
	var taglia := GameState.taglia_tipo(tipo, rot)
	for y in taglia.y:
		for x in taglia.x:
			var c := cella + Vector2i(x, y)
			var t := tipo_a(c)
			var i := c.y * LATO + c.x
			if not nel_feudo(c) or _occupato.has(c) or altezza(c) != quota or mura.has(i) or piantine.has(i) or ceppi.has(i):
				return false
			if richiesto >= 0 and t != richiesto:
				return false
			if richiesto < 0 and not t in COSTRUIBILE:
				return false
			# lati interni verticali: fra la cella (x,y) e (x+1,y).
			# In coordinate vertice, quel lato va da (x+1, y) a (x+1, y+1).
			if x < taglia.x - 1:
				var va := cella + Vector2i(x + 1, y)
				var vb := cella + Vector2i(x + 1, y + 1)
				if lato_strada(va, vb):
					return false
			# lati interni orizzontali: fra la cella (x,y) e (x,y+1).
			# In coordinate vertice, quel lato va da (x, y+1) a (x+1, y+1).
			if y < taglia.y - 1:
				var ha := cella + Vector2i(x, y + 1)
				var hb := cella + Vector2i(x + 1, y + 1)
				if lato_strada(ha, hb):
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
			var testo := "terra fertile al %d%%" % int(media * 100)
			if media > 0.7:
				testo += " (vicino all'acqua)"
			return {"resa": minimo + (massimo - minimo) * media, "testo": testo}
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
			risultato.append([c, 1.0 if indici_tagliati.has(c.y * LATO + c.x) else 0.5])
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
## Dopo il taglio restano i ceppi: per una stagione lì non si costruisce, poi il terreno è libero.
const STAGIONI_CEPPI := 1


## A fine stagione i ceppi invecchiano; restituisce le celle dove ora si può costruire.
func togli_ceppi() -> Array[Vector2i]:
	var libere: Array[Vector2i] = []
	for i in ceppi.keys():
		ceppi[i] = int(ceppi[i]) - 1
		if ceppi[i] <= 0:
			ceppi.erase(i)
			libere.append(Vector2i(i % LATO, i / LATO))
	return libere


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
	var celle_tagliate: Array[Vector2i] = []
	for c: Vector2i in candidati.slice(0, n):
		var i := c.y * LATO + c.x
		celle[i] = Tipo.ERBA
		indici_tagliati.append(i)
		ceppi[i] = STAGIONI_CEPPI
		celle_tagliate.append(c)
	return celle_tagliate


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
			if not nel_feudo(c) or _occupato.has(c) or mura.has(i) or piantine.has(i) or selvatiche.has(i):
				continue
			if not tipo_a(c) in [Tipo.ERBA, Tipo.ERBA_FIORI]:
				continue
			if indici_tagliati.has(i):
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
	for chiave in piantine.keys():
		var i: int = int(chiave)
		var restanti: int = int(piantine[i]) - 1
		piantine[i] = restanti
		var c := Vector2i(i % LATO, i / LATO)
		cambiate.append(c)
		if restanti <= 0:
			piantine.erase(i)
			celle[i] = Tipo.BOSCO
			var t := indici_tagliati.find(i)
			if t >= 0:
				indici_tagliati.remove_at(t)
			else:
				nuovo_bosco.append(i)
	return cambiate


# --- Strade (sui lati delle celle) ---------------------------------------------------

const LATO_V := LATO + 1  # vertici per riga
const COSTO_PONTE := {"legna": 3, "pietra": 2}
const COSTO_PASSERELLA := {"legna": 3, "pietra": 0}
const MAX_PASSERELLA := 3
const DIREZIONI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## La chiave del lato fra due vertici vicini (orizzontale: pari, verticale: dispari).
static func lato(a: Vector2i, b: Vector2i) -> int:
	if a.y == b.y:
		return (a.y * LATO_V + mini(a.x, b.x)) * 2
	return (mini(a.y, b.y) * LATO_V + a.x) * 2 + 1


## I due vertici di un lato.
static func estremi(k: int) -> Array[Vector2i]:
	var base := k / 2
	var v := Vector2i(base % LATO_V, base / LATO_V)
	return [v, v + (Vector2i(1, 0) if k % 2 == 0 else Vector2i(0, 1))]


## Le due celle che il lato separa (sopra e sotto, oppure a sinistra e a destra).
static func celle_del_lato(k: int) -> Array[Vector2i]:
	var v := estremi(k)[0]
	if k % 2 == 0:
		return [v + Vector2i(0, -1), v]
	return [v + Vector2i(-1, 0), v]


## Il percorso a L tra due vertici: prima in orizzontale, poi in verticale (elenco di vertici).
static func percorso(da: Vector2i, a: Vector2i) -> Array[Vector2i]:
	var vertici: Array[Vector2i] = []
	var passo_x := 1 if a.x >= da.x else -1
	var passo_y := 1 if a.y >= da.y else -1
	for x in range(da.x, a.x + passo_x, passo_x):
		vertici.append(Vector2i(x, da.y))
	for y in range(da.y + passo_y, a.y + passo_y, passo_y):
		vertici.append(Vector2i(a.x, y))
	return vertici


## I lati fra vertici consecutivi; [] (con errore) se due vertici non sono adiacenti.
static func lati_di(vertici: Array) -> Array[int]:
	var lati: Array[int] = []
	for i in range(1, vertici.size()):
		var a: Vector2i = vertici[i - 1]
		var b: Vector2i = vertici[i]
		if absi(a.x - b.x) + absi(a.y - b.y) != 1:
			push_error("TerrenoFeudo.lati_di: vertici non adiacenti %s → %s" % [a, b])
			return []
		lati.append(lato(a, b))
	return lati


func lato_strada(a: Vector2i, b: Vector2i) -> bool:
	return strade.has(lato(a, b))


## C'è una strada che tocca questo vertice?
func vertice_su_strada(v: Vector2i) -> bool:
	for d in DIREZIONI:
		if strade.has(lato(v, v + d)):
			return true
	return false


func _acqua(c: Vector2i) -> bool:
	return tipo_a(c) in [Tipo.ACQUA, Tipo.FIUME]


## La quota a cui sta una strada su questo lato: quella delle sue celle di terra.
func quota_lato(k: int) -> float:
	var c := celle_del_lato(k)
	var h := -INF
	for x in c:
		if not _acqua(x):
			h = maxf(h, altezza(x))
	return 0.0 if h == -INF else h


## "ponte" se il lato passa sul fiume, "passerella" se sul lago, "" sulla terra.
func tipo_lato(k: int) -> String:
	var c := celle_del_lato(k)
	if not (_acqua(c[0]) and _acqua(c[1])):
		return ""
	return "ponte" if tipo_a(c[0]) == Tipo.FIUME or tipo_a(c[1]) == Tipo.FIUME else "passerella"


## Costi e regole di una strada lungo questi vertici:
## - sulla terra 1 pietra per lato in piano, 2 in salita (collina o cambio di quota);
## - fra due celle di fiume è un ponte (COSTO_PONTE), fra due di lago una passerella
##   (COSTO_PASSERELLA), lunga al massimo MAX_PASSERELLA lati di fila con quelle che tocca;
## - non passa dentro un edificio, né su bosco o rocce da entrambi i lati;
## - fra due celle di mura diventa una porta.
## I lati già strada non costano. {ok, pietra, legna, ponti, passerelle, porte, lati, motivo}.
func verifica_strada(vertici: Array) -> Dictionary:
	var v := {"ok": true, "pietra": 0, "legna": 0, "ponti": 0, "passerelle": 0, "porte": 0, "lati": 0, "motivo": ""}
	var lago: Array[int] = []
	for k in lati_di(vertici):
		v.lati += 1
		var c := celle_del_lato(k)
		if not nel_feudo(c[0]) or not nel_feudo(c[1]):
			return _no(v, "il percorso esce dal feudo")
		if edificio_a(c[0]) >= 0 and edificio_a(c[0]) == edificio_a(c[1]):
			return _no(v, "il percorso passa dentro un edificio")
		var gia := strade.has(k)
		var tipo := tipo_lato(k)
		if tipo == "ponte":
			if not gia:
				v.legna += COSTO_PONTE.legna
				v.pietra += COSTO_PONTE.pietra
				v.ponti += 1
			continue
		if tipo == "passerella":
			if not gia:
				v.legna += COSTO_PASSERELLA.legna
				v.passerelle += 1
			lago.append(k)
			continue
		var aperto := func(x: Vector2i) -> bool: return tipo_a(x) in COSTRUIBILE or _acqua(x)
		if not (aperto.call(c[0]) or aperto.call(c[1])):
			return _no(v, "il percorso passa in mezzo al bosco o alle rocce")
		# lungo il bordo di una collina la strada starebbe a metà del gradino
		if not _acqua(c[0]) and not _acqua(c[1]) and altezza(c[0]) != altezza(c[1]):
			return _no(v, "il percorso corre sul bordo di una collina: passa sopra o sotto")
		if mura.has(c[0].y * LATO + c[0].x) and mura.has(c[1].y * LATO + c[1].x):
			v.porte += 1
		if not gia:
			var salita := tipo_a(c[0]) == Tipo.COLLINA or tipo_a(c[1]) == Tipo.COLLINA
			v.pietra += 2 if salita else 1
	# ogni passerella (lati di lago di fila, con quelle già fatte attaccate) al massimo 3 lati
	var nel_percorso := {}
	for k in lago:
		nel_percorso[k] = true
	var visti := {}
	for k in lago:
		if visti.has(k):
			continue
		var pezzo := 0
		var coda: Array[int] = [k]
		visti[k] = true
		while not coda.is_empty():
			var x: int = coda.pop_back()
			pezzo += 1
			for e in estremi(x):
				for d in DIREZIONI:
					var y := lato(e, e + d)
					if not visti.has(y) and (nel_percorso.has(y) or strade.has(y)) and tipo_lato(y) == "passerella":
						visti[y] = true
						coda.append(y)
		if pezzo > MAX_PASSERELLA:
			return _no(v, "una passerella sul lago può essere lunga al massimo %d celle" % MAX_PASSERELLA)
	return v


func _no(v: Dictionary, motivo: String) -> Dictionary:
	v.ok = false
	v.motivo = motivo
	return v


## Pietra necessaria per la strada, -1 se non si può fare (vedi verifica_strada).
func costo_strada(vertici: Array) -> int:
	var v := verifica_strada(vertici)
	return int(v.pietra) if v.ok else -1


## Aggiunge la strada; restituisce le celle accanto ai lati nuovi (per ridisegnare).
func aggiungi_strada(vertici: Array) -> Array:
	var toccate := []
	for k in lati_di(vertici):
		if not strade.has(k):
			strade[k] = true
			toccate.append_array(celle_del_lato(k))
	return toccate


func rimuovi_lato(k: int) -> bool:
	return strade.erase(k)


## Il lato di strada più vicino a un punto del mondo (in celle, con i decimali), o -1.
func lato_vicino(p: Vector2, massima := 0.45) -> int:
	var migliore := -1
	var dmin := massima
	var v := Vector2i(roundi(p.x), roundi(p.y))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var a := v + Vector2i(dx, dy)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var k := lato(a, a + d)
				if not strade.has(k):
					continue
				var m := (Vector2(a) + Vector2(a + d)) / 2.0
				var dist := Geometry2D.get_closest_point_to_segment(p, Vector2(a), Vector2(a + d)).distance_to(p)
				if dist < dmin or (is_equal_approx(dist, dmin) and m.distance_to(p) < 0.5):
					dmin = dist
					migliore = k
	return migliore


## Una cella d'acqua si attraversa solo se un ponte o una passerella le passa accanto.
func ponte_vicino(c: Vector2i) -> bool:
	var vertici := [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]
	for k in [lato(vertici[0], vertici[1]), lato(vertici[2], vertici[3]), lato(vertici[0], vertici[2]), lato(vertici[1], vertici[3])]:
		if strade.has(k) and tipo_lato(k) != "":
			return true
	return false


## Si può camminare qui (a piedi, fuori dalle strade)? Terra, bosco e rocce sì; l'acqua solo
## accanto a un ponte o a una passerella; le mura mai (in guerra le porte sono chiuse).
func percorribile(c: Vector2i) -> bool:
	if not dentro(c) or mura.has(c.y * LATO + c.x):
		return false
	return not _acqua(c) or ponte_vicino(c)


## Il cammino più corto a piedi fra due celle (anche in diagonale, senza tagliare gli angoli),
## entro il feudo e un piccolo margine. Se la meta non si raggiunge, si ferma alla cella
## raggiungibile più vicina. [] solo se si parte da una cella non percorribile.
func cammino(da: Vector2i, a: Vector2i) -> Array[Vector2i]:
	var limite := FEUDO.grow(4)
	var da_dove := {da: da}
	var coda: Array[Vector2i] = [da]
	var i := 0
	var arrivo := da
	var migliore := INF
	while i < coda.size():
		var c := coda[i]
		i += 1
		var dist := Vector2(c - a).length()
		if dist < migliore:
			migliore = dist
			arrivo = c
		if dist <= 1.5:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var v: Vector2i = c + d
			if da_dove.has(v) or not limite.has_point(v) or not percorribile(v):
				continue
			if d.x != 0 and d.y != 0 and not (percorribile(c + Vector2i(d.x, 0)) and percorribile(c + Vector2i(0, d.y))):
				continue
			da_dove[v] = c
			coda.append(v)
	var celle_c: Array[Vector2i] = []
	var c := arrivo
	while c != da:
		celle_c.push_front(c)
		c = da_dove[c]
	celle_c.push_front(da)
	return celle_c


## Vero se a piedi da qui non si arriva fino alla meta (per esempio: le mura la chiudono).
func chiuso_da_mura(da: Vector2i, a: Vector2i) -> bool:
	var c := cammino(da, a)
	return c.is_empty() or Vector2(c[c.size() - 1] - a).length() > 1.5


# --- Mura in pietra -----------------------------------------------------------------

const COSTO_MURA := 4  # pietra per cella


func muro_a(c: Vector2i) -> bool:
	return mura.has(c.y * LATO + c.x)


## Le mura si tracciano come le strade, ma cella per cella: sulla terra libera, non sull'acqua,
## non sopra edifici o alberelli. {ok, pietra, celle, motivo}.
func verifica_mura(celle_m: Array) -> Dictionary:
	var v := {"ok": true, "pietra": 0, "celle": 0, "motivo": ""}
	for c in celle_m:
		var i: int = c.y * LATO + c.x
		if mura.has(i):
			continue
		if not nel_feudo(c) or _occupato.has(c) or piantine.has(i) or ceppi.has(i):
			return _no(v, "le mura passano su edifici, alberelli, ceppi o fuori dal feudo")
		if _acqua(c):
			return _no(v, "le mura non si possono mettere sull'acqua")
		if not tipo_a(c) in COSTRUIBILE:
			return _no(v, "le mura si fanno solo su erba, fiori o collina")
		v.pietra += COSTO_MURA
		v.celle += 1
	return v


func aggiungi_mura(celle_m: Array) -> Array:
	var nuove := []
	for c in celle_m:
		var i: int = c.y * LATO + c.x
		if not mura.has(i):
			mura[i] = true
			nuove.append(c)
	return nuove


func rimuovi_muro(c: Vector2i) -> bool:
	return mura.erase(c.y * LATO + c.x)


# --- Salvataggio ---------------------------------------------------------------

func salva() -> Dictionary:
	return {
		"strade": strade.keys(),
		"mura": mura.keys(),
		"piantine": piantine,
		"nuovo_bosco": Array(nuovo_bosco),
		"ceppi": ceppi,
		"selvatiche": selvatiche,
	}


func applica_salvataggio(d: Dictionary) -> void:
	for i in d.get("strade", []):
		strade[int(i)] = true
	for i in d.get("mura", []):
		mura[int(i)] = true
	var cp: Dictionary = d.get("ceppi", {})
	for k in cp:
		ceppi[int(k)] = int(cp[k])
	for i in d.get("nuovo_bosco", []):
		celle[int(i)] = Tipo.BOSCO
		nuovo_bosco.append(int(i))
	var p: Dictionary = d.get("piantine", {})
	for k in p:
		piantine[int(k)] = int(p[k])
	var sv: Dictionary = d.get("selvatiche", {})
	for k in sv:
		selvatiche[int(k)] = sv[k]


## Rimette i tagli di un salvataggio.
func applica_tagli(indici: Array) -> void:
	for i in indici:
		celle[int(i)] = Tipo.ERBA
		indici_tagliati.append(int(i))


## Cerca a spirale il posto valido più vicino a una cella.
func trova_posto(tipo: String, vicino_a: Vector2i, rot := 0) -> Vector2i:
	for raggio in 20:
		for y in range(-raggio, raggio + 1):
			for x in range(-raggio, raggio + 1):
				if maxi(absi(x), absi(y)) != raggio:
					continue
				var c := vicino_a + Vector2i(x, y)
				if posizione_valida(tipo, c, rot):
					return c
	return Vector2i(-1, -1)
