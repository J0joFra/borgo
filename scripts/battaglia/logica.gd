class_name LogicaBattaglia
extends RefCounted
## Le regole della battaglia tattica, in stile Humankind: un campo a esagoni con pianure, boschi,
## colline e acqua; le nostre unità a sinistra, quelle del nemico a destra a difesa della loro
## bandiera. A turni: ogni unità si muove (i boschi e le colline costano di più) e poi attacca,
## corpo a corpo o con l'arco da lontano. Si vince distruggendo l'esercito nemico o tenendo
## la loro bandiera per un turno intero; si perde se cadono tutti i nostri o se finiscono i turni.
## Tutto lo stato sta in un dizionario (GameState.battaglia), così si salva com'è.
## Le celle sono coordinate "offset" (colonna, riga) di esagoni a punta in su, righe dispari spostate.

enum Terreno { PIANURA, BOSCO, COLLINA, ACQUA }

const LARGHEZZA := 12
const ALTEZZA := 9


## Una battaglia nuova: terreno dal seme, le nostre unità (soldati per tipo, uomini dei vassalli)
## e quelle del regno nemico, con la sua bandiera.
## truppe: tipo di soldato (fanti, spadaccini, arcieri, balestrieri, cavalieri) -> quanti.
## armi: non più usato (le armi non ci sono più), resta per non cambiare chi la chiama.
static func crea(regione: String, tipo_nemico: String, truppe: Dictionary, armi: int, aiuti: int, nemici: int, seme: int, cfg: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var terreno: Array = []
	for r in ALTEZZA:
		for c in LARGHEZZA:
			var x := rng.randf()
			var t := Terreno.PIANURA
			if c > 1 and c < LARGHEZZA - 2:
				if x < 0.16:
					t = Terreno.BOSCO
				elif x < 0.28:
					t = Terreno.COLLINA
				elif x < 0.33:
					t = Terreno.ACQUA
			elif x < 0.12:
				t = Terreno.BOSCO
			terreno.append(t)
	var bandiera := Vector2i(LARGHEZZA - 2, ALTEZZA / 2)
	terreno[_i(bandiera)] = Terreno.COLLINA  # la bandiera sta su un'altura
	var b := {"regione": regione, "tipo_nemico": tipo_nemico, "turno": 1, "turni": int(cfg.turni),
		"fase": "noi", "finita": false, "vinta": false, "perche": "", "terreno": terreno,
		"bandiera": [bandiera.x, bandiera.y], "unita": [], "diario": [], "prossimo_id": 1}
	# le nostre unità: gruppi di "per_unita" uomini per ogni tipo di soldato; chi tira sta dietro
	var per := int(cfg.per_unita)
	var soldati := 0
	var gruppi := []  # [tipo, uomini]
	for tipo in ["fanti", "spadaccini", "cavalieri", "balestrieri", "arcieri"]:
		for g in _gruppi(int(truppe.get(tipo, 0)), per):
			gruppi.append([tipo, g])
		soldati += int(truppe.get(tipo, 0))
	for g in _gruppi(aiuti, per):
		gruppi.append(["vassalli", g])
	var righe := _righe_centrali(gruppi.size())
	for k in gruppi.size():
		var tipo: String = gruppi[k][0]
		var dietro := int(cfg.unita[tipo].gittata) > 1 or tipo == "vassalli"
		_aggiungi(b, "noi", tipo, gruppi[k][1], Vector2i(0 if dietro else 1, righe[k]), cfg)
	b.nostri_inizio = soldati
	b.truppe_inizio = truppe.duplicate()
	# le unità nemiche attorno alla bandiera
	var tipi: Array = cfg.eserciti[tipo_nemico]
	var loro := _gruppi(nemici, per)
	var posti := _attorno(bandiera, loro.size(), terreno)
	for i in loro.size():
		var tipo_l: String = tipi[i % tipi.size()]
		_aggiungi(b, "loro", tipo_l, loro[i], posti[i], cfg)
	b.loro_inizio = nemici
	return b


static func _gruppi(n: int, per: int) -> Array[int]:
	var g: Array[int] = []
	var resto := n
	while resto > 0:
		g.append(mini(per, resto))
		resto -= per
	return g


static func _righe_centrali(n: int) -> Array[int]:
	var righe: Array[int] = []
	var centro := ALTEZZA / 2
	for i in n:
		var passo := (i + 1) / 2
		righe.append(clampi(centro + (passo if i % 2 == 1 else -passo), 0, ALTEZZA - 1))
	# se le unità sono più delle righe, le altre vanno nella colonna dietro (vedi _aggiungi)
	return righe


static func _attorno(centro: Vector2i, n: int, terreno: Array) -> Array[Vector2i]:
	var posti: Array[Vector2i] = []
	var anello := [centro]
	var visti := {centro: true}
	while posti.size() < n and not anello.is_empty():
		var prossimo := []
		for c in anello:
			if terreno[_i(c)] != Terreno.ACQUA and posti.size() < n:
				posti.append(c)
			for v in vicini(c):
				if not visti.has(v):
					visti[v] = true
					prossimo.append(v)
		anello = prossimo
	return posti


static func _aggiungi(b: Dictionary, lato: String, tipo: String, uomini: int, cella: Vector2i, cfg: Dictionary) -> void:
	# se la cella è occupata o d'acqua, la prima libera vicina
	var libera := cella
	if occupante(b, libera) >= 0 or b.terreno[_i(libera)] == Terreno.ACQUA:
		for c in _attorno(cella, 30, b.terreno):
			if occupante(b, c) < 0:
				libera = c
				break
	var d: Dictionary = cfg.unita[tipo]
	b.unita.append({"id": b.prossimo_id, "lato": lato, "tipo": tipo, "uomini": uomini, "max": uomini,
		"cella": [libera.x, libera.y], "mosse": int(d.mosse), "attaccato": false})
	b.prossimo_id = int(b.prossimo_id) + 1


# --- Esagoni ---------------------------------------------------------------------------

static func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < LARGHEZZA and c.y < ALTEZZA


static func _i(c: Vector2i) -> int:
	return c.y * LARGHEZZA + c.x


static func cella(u: Dictionary) -> Vector2i:
	return Vector2i(int(u.cella[0]), int(u.cella[1]))


## I sei vicini di un esagono (righe dispari spostate a destra).
static func vicini(c: Vector2i) -> Array[Vector2i]:
	var pari := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)]
	var dispari := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1)]
	var v: Array[Vector2i] = []
	for d in (dispari if c.y % 2 == 1 else pari):
		var n: Vector2i = c + d
		if dentro(n):
			v.append(n)
	return v


static func distanza(a: Vector2i, b: Vector2i) -> int:
	var ca := _cubo(a)
	var cb := _cubo(b)
	return int((absi(ca.x - cb.x) + absi(ca.y - cb.y) + absi(ca.z - cb.z)) / 2)


static func _cubo(c: Vector2i) -> Vector3i:
	var x := c.x - (c.y - (c.y & 1)) / 2
	var z := c.y
	return Vector3i(x, -x - z, z)


static func terreno_a(b: Dictionary, c: Vector2i) -> int:
	return int(b.terreno[_i(c)])


static func costo(b: Dictionary, c: Vector2i, cfg: Dictionary) -> int:
	return int(cfg.terreni[terreno_a(b, c)].costo)


static func occupante(b: Dictionary, c: Vector2i) -> int:
	for u in b.unita:
		if int(u.uomini) > 0 and cella(u) == c:
			return int(u.id)
	return -1


static func trova(b: Dictionary, id: int) -> Dictionary:
	for u in b.unita:
		if int(u.id) == id:
			return u
	return {}


static func vive(b: Dictionary, lato: String) -> Array:
	return b.unita.filter(func(u): return u.lato == lato and int(u.uomini) > 0)


## Le celle dove l'unità può arrivare con le mosse che le restano: {cella: [percorso]}.
static func raggiungibili(b: Dictionary, u: Dictionary, cfg: Dictionary) -> Dictionary:
	var inizio := cella(u)
	var spesa := {inizio: 0}
	var da_dove := {inizio: inizio}
	var coda: Array[Vector2i] = [inizio]
	while not coda.is_empty():
		# la cella più economica per prima (sono poche: va bene una ricerca lineare)
		var migliore := 0
		for k in coda.size():
			if spesa[coda[k]] < spesa[coda[migliore]]:
				migliore = k
		var c: Vector2i = coda.pop_at(migliore)
		for v in vicini(c):
			if terreno_a(b, v) == Terreno.ACQUA or occupante(b, v) >= 0:
				continue
			var nuova: int = spesa[c] + costo(b, v, cfg)
			if nuova <= int(u.mosse) and (not spesa.has(v) or nuova < spesa[v]):
				spesa[v] = nuova
				da_dove[v] = c
				coda.append(v)
	var risultato := {}
	for c in spesa:
		if c == inizio:
			continue
		var percorso: Array[Vector2i] = [c]
		var x: Vector2i = c
		while da_dove[x] != inizio:
			x = da_dove[x]
			percorso.push_front(x)
		risultato[c] = percorso
	return risultato


## La gittata vera: dalle colline gli arcieri tirano una cella più lontano.
static func gittata(b: Dictionary, u: Dictionary, cfg: Dictionary) -> int:
	var g := int(cfg.unita[u.tipo].gittata)
	if g > 1 and terreno_a(b, cella(u)) == Terreno.COLLINA:
		g += 1
	return g


## I nemici che l'unità può attaccare da dove si trova.
static func bersagli(b: Dictionary, u: Dictionary, cfg: Dictionary) -> Array:
	if bool(u.attaccato) or int(u.uomini) <= 0:
		return []
	var g := gittata(b, u, cfg)
	return b.unita.filter(func(v): return v.lato != u.lato and int(v.uomini) > 0 and distanza(cella(u), cella(v)) <= g)


# --- Azioni ------------------------------------------------------------------------------

## Sposta un'unità lungo il percorso (se ci arriva con le mosse che ha).
static func muovi(b: Dictionary, id: int, dove: Vector2i, cfg: Dictionary) -> Array[Vector2i]:
	var u := trova(b, id)
	var possibili := raggiungibili(b, u, cfg)
	if u.is_empty() or bool(u.attaccato) or not possibili.has(dove):
		return []
	var percorso: Array[Vector2i] = possibili[dove]
	var spesa := 0
	for c in percorso:
		spesa += costo(b, c, cfg)
	u.mosse = int(u.mosse) - spesa
	u.cella = [dove.x, dove.y]
	return percorso


## Un attacco: la forza di ciascuno (uomini × forza dell'unità × terreno, con un po' di fortuna)
## decide quanti cadono. Corpo a corpo il difensore risponde; con l'arco no.
static func attacca(b: Dictionary, id: int, bersaglio: int, cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var a := trova(b, id)
	var d := trova(b, bersaglio)
	if a.is_empty() or d.is_empty() or not bersagli(b, a, cfg).has(d):
		return {}
	var ta: Dictionary = cfg.terreni[terreno_a(b, cella(a))]
	var td: Dictionary = cfg.terreni[terreno_a(b, cella(d))]
	var fa := int(a.uomini) * forza(a, cfg) * float(ta.attacco) * rng.randf_range(0.85, 1.15)
	var fd := int(d.uomini) * forza(d, cfg) * float(td.difesa) * rng.randf_range(0.85, 1.15)
	var da_lontano := distanza(cella(a), cella(d)) > 1
	var morti_d := mini(int(d.uomini), roundi(fa / (fa + fd) * ceili(int(a.uomini) * float(cfg.letalita))))
	var morti_a := 0
	if not da_lontano and int(d.uomini) - morti_d > 0:
		morti_a = mini(int(a.uomini), roundi(fd / (fa + fd) * ceili(int(d.uomini) * float(cfg.risposta))))
	d.uomini = int(d.uomini) - morti_d
	a.uomini = int(a.uomini) - morti_a
	a.attaccato = true
	a.mosse = 0
	var esito := {"tipo": "attacco", "da": id, "a": bersaglio, "morti_attaccante": morti_a, "morti_difensore": morti_d, "da_lontano": da_lontano}
	_diario(b, "%s %s %s: cadono %d dei loro%s." % [cfg.unita[a.tipo].nome, "tirano a" if da_lontano else "attaccano", cfg.unita[d.tipo].nome.to_lower(),
		morti_d, " e %d dei nostri" % morti_a if morti_a > 0 else ""] if a.lato == "noi" else
		"%s attaccano %s: cadono %d dei nostri%s." % [cfg.unita[a.tipo].nome, cfg.unita[d.tipo].nome.to_lower(), morti_d,
		" e %d dei loro" % morti_a if morti_a > 0 else ""])
	_controlla_fine(b)
	return esito


## La forza di un uomo dell'unità.
static func forza(u: Dictionary, cfg: Dictionary) -> float:
	return float(cfg.unita[u.tipo].forza)


static func _diario(b: Dictionary, testo: String) -> void:
	b.diario.append(testo)
	if b.diario.size() > 6:
		b.diario.pop_front()


## Fine del nostro turno: muove il nemico, controlla la bandiera e passa al turno dopo.
## Restituisce le azioni del nemico (per animarle): [{tipo: muovi|attacco, ...}].
static func fine_turno(b: Dictionary, cfg: Dictionary, rng: RandomNumberGenerator) -> Array:
	var azioni := []
	if b.finita:
		return azioni
	b.fase = "loro"
	for u in vive(b, "loro"):
		u.mosse = int(cfg.unita[u.tipo].mosse)
		u.attaccato = false
	for u in vive(b, "loro"):
		if b.finita:
			break
		azioni.append_array(_mossa_nemica(b, u, cfg, rng))
	if not b.finita:
		# chi è sulla loro bandiera dopo il loro turno l'ha tenuta: è nostra
		var bandiera := Vector2i(int(b.bandiera[0]), int(b.bandiera[1]))
		var su := trova(b, occupante(b, bandiera))
		if not su.is_empty() and su.lato == "noi":
			_fine(b, true, "Abbiamo preso e tenuto la loro bandiera!")
		elif int(b.turno) >= int(b.turni):
			_fine(b, false, "Il sole tramonta e la loro bandiera sventola ancora: l'esercito torna a casa.")
	if not b.finita:
		b.turno = int(b.turno) + 1
		b.fase = "noi"
		for u in vive(b, "noi"):
			u.mosse = int(cfg.unita[u.tipo].mosse)
			u.attaccato = false
	return azioni


## Il nemico: attacca se può (il più debole), altrimenti si avvicina a chi minaccia la bandiera
## o a chi gli è vicino; se nessuno è vicino resta a difendere la bandiera.
static func _mossa_nemica(b: Dictionary, u: Dictionary, cfg: Dictionary, rng: RandomNumberGenerator) -> Array:
	var azioni := []
	var colpisci := func() -> bool:
		var possibili := bersagli(b, u, cfg)
		if possibili.is_empty():
			return false
		possibili.sort_custom(func(x, y): return int(x.uomini) < int(y.uomini))
		var e := attacca(b, int(u.id), int(possibili[0].id), cfg, rng)
		if not e.is_empty():
			azioni.append(e)
		return true
	if colpisci.call():
		return azioni
	var bandiera := Vector2i(int(b.bandiera[0]), int(b.bandiera[1]))
	var nostri := vive(b, "noi")
	if nostri.is_empty():
		return azioni
	var vicino: Dictionary = nostri[0]
	for n in nostri:
		if distanza(cella(n), cella(u)) < distanza(cella(vicino), cella(u)):
			vicino = n
	var minaccia := distanza(cella(vicino), bandiera) <= int(cfg.allarme_bandiera) or distanza(cella(vicino), cella(u)) <= int(cfg.unita[u.tipo].mosse) + 1
	var meta := cella(vicino) if minaccia else bandiera
	var possibili := raggiungibili(b, u, cfg)
	var gitt := gittata(b, u, cfg)
	var scelta := cella(u)
	var punteggio := _punteggio(b, cella(u), meta, gitt, minaccia)
	for c in possibili:
		var p := _punteggio(b, c, meta, gitt, minaccia)
		if p < punteggio:
			punteggio = p
			scelta = c
	if scelta != cella(u):
		var percorso := muovi(b, int(u.id), scelta, cfg)
		azioni.append({"tipo": "muovi", "id": u.id, "percorso": percorso.map(func(c): return [c.x, c.y])})
	colpisci.call()
	return azioni


## Più basso è meglio: vicino alla meta (alla distanza di tiro per chi ha l'arco), meglio su colline e boschi.
static func _punteggio(b: Dictionary, c: Vector2i, meta: Vector2i, gitt: int, minaccia: bool) -> float:
	var d := distanza(c, meta)
	var p := float(absi(d - gitt)) if minaccia else float(d)
	match terreno_a(b, c):
		Terreno.COLLINA:
			p -= 0.4
		Terreno.BOSCO:
			p -= 0.3
	return p


static func _controlla_fine(b: Dictionary) -> void:
	if b.finita:
		return
	if vive(b, "loro").is_empty():
		_fine(b, true, "L'esercito nemico è stato distrutto!")
	elif vive(b, "noi").is_empty():
		_fine(b, false, "I nostri sono caduti tutti.")


static func _fine(b: Dictionary, vinta: bool, perche: String) -> void:
	b.finita = true
	b.vinta = vinta
	b.perche = perche
	b.fase = "finita"
	_diario(b, perche)


static func ritirata(b: Dictionary) -> void:
	if not b.finita:
		_fine(b, false, "Ritirata: l'esercito torna a casa con chi è rimasto.")


## Uomini ancora vivi: i nostri soldati (fanti e arcieri) o gli uomini dei vassalli.
static func superstiti(b: Dictionary, lato: String, tipi: Array) -> int:
	var n := 0
	for u in b.unita:
		if u.lato == lato and u.tipo in tipi:
			n += maxi(0, int(u.uomini))
	return n
