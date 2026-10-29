class_name LogicaBattaglia
extends RefCounted
## Le regole della battaglia tattica, in stile Humankind: un piccolo campo a quadretti come il terreno
## del feudo, con pianure, boschi, colline e acqua (le diagonali contano come passi); le nostre unità a sinistra, quelle del nemico a destra a difesa della loro
## bandiera. Prima lo schieramento (le nostre unità si dispongono nelle prime colonne), poi a turni,
## senza limite: ogni unità si muove (boschi e colline costano di più) e attacca, corpo a corpo o da
## lontano. Contano l'altura (dall'alto si colpisce più forte), i fianchi (più unità attorno al
## bersaglio), il supporto (i compagni accanto aiutano a difendersi) e le lance contro i cavalli.
## Si vince distruggendo l'esercito nemico o tenendo la loro bandiera per un turno intero; si perde
## se cadono tutti i nostri o con la ritirata.
## Assedio: contro un signore la bandiera sta in un castello con le mura. Sulle mura salgono solo i
## difensori (più difesa, dall'alto, e gli arcieri tirano più lontano); per entrare si sfonda la porta
## corpo a corpo (la porta è un'"unità" che non combatte, con dei punti al posto degli uomini).
## Tutto lo stato sta in un dizionario (GameState.battaglia), così si salva com'è.
## Le celle sono (colonna, riga) di una griglia quadrata.

enum Terreno { PIANURA, BOSCO, COLLINA, ACQUA, MURA }

const LARGHEZZA := 16
const ALTEZZA := 10
const PORTA := "porta"


## Una battaglia nuova: terreno dal seme, le nostre unità (soldati per tipo, uomini dei vassalli)
## e quelle del regno nemico, con la sua bandiera.
## truppe: tipo di soldato (fanti, spadaccini, arcieri, balestrieri, cavalieri) -> quanti.
## armi: non più usato (le armi non ci sono più), resta per non cambiare chi la chiama.
static func crea(regione: String, tipo_nemico: String, truppe: Dictionary, armi: int, aiuti: int, nemici: int, seme: int, cfg: Dictionary) -> Dictionary:
	# il terreno a macchie (colline, boschi, uno stagno), non a celle sparse: si formano alture e
	# boschetti da conquistare; le zone di schieramento (prime e ultime colonne) restano più libere
	var rilievo := FastNoiseLite.new()
	rilievo.seed = seme
	rilievo.frequency = 0.22
	var alberi := FastNoiseLite.new()
	alberi.seed = seme + 1
	alberi.frequency = 0.28
	var terreno: Array = []
	for r in ALTEZZA:
		for c in LARGHEZZA:
			var t := Terreno.PIANURA
			var h := rilievo.get_noise_2d(c * 1.7, r * 2.0)
			var f := alberi.get_noise_2d(c * 1.7 + 40.0, r * 2.0)
			var in_mezzo := c > 2 and c < LARGHEZZA - 2
			if in_mezzo and h > 0.28:
				t = Terreno.COLLINA
			elif in_mezzo and h < -0.5:
				t = Terreno.ACQUA
			elif f > (0.22 if in_mezzo else 0.45):
				t = Terreno.BOSCO
			terreno.append(t)
	var assedio: bool = tipo_nemico == "signore"
	var bandiera := Vector2i(LARGHEZZA - 2 - (1 if assedio else 0), ALTEZZA / 2)
	terreno[_i(bandiera)] = Terreno.COLLINA  # la bandiera sta su un'altura
	var porta := Vector2i(-1, -1)
	if assedio:
		porta = _castello(terreno, bandiera)
	var b := {"regione": regione, "tipo_nemico": tipo_nemico, "turno": 1,
		"fase": "schieramento", "finita": false, "vinta": false, "perche": "", "terreno": terreno,
		"bandiera": [bandiera.x, bandiera.y], "unita": [], "diario": [], "prossimo_id": 1, "assedio": assedio}
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
	if assedio:
		# chi tira sale sulle mura, dalla parte da cui arriviamo; poi la porta chiude il castello
		var sulle_mura: Array[Vector2i] = []
		for i in terreno.size():
			if terreno[i] == Terreno.MURA:
				sulle_mura.append(Vector2i(i % LARGHEZZA, i / LARGHEZZA))
		sulle_mura.sort_custom(func(x, y): return x.x < y.x)
		for u in b.unita:
			if u.lato == "loro" and int(cfg.unita[u.tipo].gittata) > 1 and not sulle_mura.is_empty():
				var posto: Vector2i = sulle_mura.pop_front()
				u.cella = [posto.x, posto.y]
		var punti := int(cfg.get("assedio", {}).get("porta", 20))
		b.unita.append({"id": b.prossimo_id, "lato": "loro", "tipo": PORTA, "uomini": punti, "max": punti,
			"cella": [porta.x, porta.y], "mosse": 0, "attaccato": true})
		b.prossimo_id = int(b.prossimo_id) + 1
	b.loro_inizio = nemici
	return b


## Il castello: un quadrato di mura attorno alla bandiera, con la porta verso di noi; dentro e
## davanti alla porta il terreno è sgombro. Restituisce la cella della porta.
static func _castello(terreno: Array, bandiera: Vector2i) -> Vector2i:
	var raggio := 2
	for y in range(bandiera.y - raggio - 1, bandiera.y + raggio + 2):
		for x in range(bandiera.x - raggio - 2, bandiera.x + raggio + 2):
			var c := Vector2i(x, y)
			if not dentro(c):
				continue
			var lontano := maxi(absi(x - bandiera.x), absi(y - bandiera.y))
			if lontano == raggio:
				terreno[_i(c)] = Terreno.MURA
			elif c != bandiera:
				terreno[_i(c)] = Terreno.PIANURA
	var porta := Vector2i(bandiera.x - raggio, bandiera.y)
	terreno[_i(porta)] = Terreno.PIANURA  # sotto la porta si passa, quando è sfondata
	return porta


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
			if not terreno[_i(c)] in [Terreno.ACQUA, Terreno.MURA] and posti.size() < n:
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


# --- Griglia ---------------------------------------------------------------------------

static func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < LARGHEZZA and c.y < ALTEZZA


static func _i(c: Vector2i) -> int:
	return c.y * LARGHEZZA + c.x


static func cella(u: Dictionary) -> Vector2i:
	return Vector2i(int(u.cella[0]), int(u.cella[1]))


const DIREZIONI := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Gli otto vicini di una cella (anche in diagonale).
static func vicini(c: Vector2i) -> Array[Vector2i]:
	var v: Array[Vector2i] = []
	for d in DIREZIONI:
		var n: Vector2i = c + d
		if dentro(n):
			v.append(n)
	return v


## Passi fra due celle, contando le diagonali come un passo.
static func distanza(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Si può passare da una cella alla vicina? In diagonale non si scivola fra due mura o due stagni.
static func _passo_libero(b: Dictionary, da: Vector2i, a: Vector2i, lato: String) -> bool:
	if not _calpestabile(b, a, lato):
		return false
	if da.x != a.x and da.y != a.y:
		return _calpestabile(b, Vector2i(a.x, da.y), lato) or _calpestabile(b, Vector2i(da.x, a.y), lato)
	return true


## Acqua mai; le mura solo per chi difende il castello.
static func _calpestabile(b: Dictionary, c: Vector2i, lato: String) -> bool:
	var t := terreno_a(b, c)
	return t != Terreno.ACQUA and (t != Terreno.MURA or lato == "loro")


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
			if not _passo_libero(b, c, v, u.lato) or occupante(b, v) >= 0:
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


## La gittata vera: dalle colline e dalle mura gli arcieri tirano una cella più lontano.
static func gittata(b: Dictionary, u: Dictionary, cfg: Dictionary) -> int:
	var g := int(cfg.unita[u.tipo].gittata)
	if g > 1 and quota(b, cella(u)) > 0:
		g += 1
	return g


## I nemici che l'unità può attaccare da dove si trova.
static func bersagli(b: Dictionary, u: Dictionary, cfg: Dictionary) -> Array:
	if bool(u.attaccato) or int(u.uomini) <= 0:
		return []
	var g := gittata(b, u, cfg)
	# la porta si sfonda solo da vicino: le frecce non la aprono
	return b.unita.filter(func(v): return v.lato != u.lato and int(v.uomini) > 0 and distanza(cella(u), cella(v)) <= (1 if v.tipo == PORTA else g))


# --- Schieramento ------------------------------------------------------------------------

## Le celle dove schierare le nostre unità: le prime colonne, fuori dall'acqua.
static func zona_schieramento(b: Dictionary, cfg: Dictionary) -> Array[Vector2i]:
	var zona: Array[Vector2i] = []
	for r in ALTEZZA:
		for c in int(cfg.get("zona_schieramento", 3)):
			var x := Vector2i(c, r)
			if _calpestabile(b, x, "noi"):
				zona.append(x)
	return zona


## Durante lo schieramento sposta una nostra unità in un'altra cella della zona (se è occupata
## da una nostra unità, le due si scambiano il posto). Vero se l'ha fatto.
static func schiera(b: Dictionary, id: int, dove: Vector2i, cfg: Dictionary) -> bool:
	var u := trova(b, id)
	if b.fase != "schieramento" or u.is_empty() or u.lato != "noi" or not zona_schieramento(b, cfg).has(dove):
		return false
	var altro := trova(b, occupante(b, dove))
	if not altro.is_empty():
		if altro.lato != "noi":
			return false
		altro.cella = u.cella.duplicate()
	u.cella = [dove.x, dove.y]
	return true


## Fine dello schieramento: si comincia a combattere.
static func inizia(b: Dictionary) -> void:
	if b.fase == "schieramento":
		b.fase = "noi"
		_diario(b, "Le schiere sono pronte: all'attacco!")


# --- Forze in campo ------------------------------------------------------------------------

## Quanto è in alto una cella (le colline e le mura sono alture).
static func quota(b: Dictionary, c: Vector2i) -> int:
	return 1 if terreno_a(b, c) in [Terreno.COLLINA, Terreno.MURA] else 0


## Quante unità di un lato stanno attorno a una cella (senza contare chi è escluso).
static func _vicini_di(b: Dictionary, c: Vector2i, lato: String, escluso: int) -> int:
	var n := 0
	for v in vicini(c):
		var u := trova(b, occupante(b, v))
		if not u.is_empty() and u.lato == lato and int(u.id) != escluso and u.tipo != PORTA:
			n += 1
	return n


## Le forze di un attacco, senza fortuna, con la spiegazione di ogni bonus (per l'anteprima):
## {fa, fd, voci: ["dall'alto +25%", ...], da_lontano}.
static func forze(b: Dictionary, a: Dictionary, d: Dictionary, cfg: Dictionary) -> Dictionary:
	var voci: Array[String] = []
	var ca := cella(a)
	var cd := cella(d)
	var da_lontano := distanza(ca, cd) > 1
	if d.tipo == PORTA:
		# la porta non si difende: conta solo quanti colpiscono
		return {"fa": int(a.uomini) * forza(a, cfg), "fd": 0.0, "voci": ["contro la porta"], "da_lontano": false}
	var ma := float(cfg.terreni[terreno_a(b, ca)].attacco)
	var md := float(cfg.terreni[terreno_a(b, cd)].difesa)
	if not is_equal_approx(md, 1.0):
		voci.append("difende in %s ×%.2f" % [str(cfg.terreni[terreno_a(b, cd)].nome).to_lower(), md])
	# altura: chi sta più in alto colpisce più forte; in mischia dal basso si fatica
	if quota(b, ca) > quota(b, cd):
		ma *= 1.0 + float(cfg.get("altura", 0.25))
		voci.append("dall'alto +%d%%" % roundi(float(cfg.get("altura", 0.25)) * 100))
	elif quota(b, ca) < quota(b, cd) and not da_lontano:
		ma *= 1.0 - float(cfg.get("dal_basso", 0.15))
		voci.append("dal basso -%d%%" % roundi(float(cfg.get("dal_basso", 0.15)) * 100))
	# fianchi: le altre unità dell'attaccante attorno al bersaglio
	var massimo := int(cfg.get("massimo_vicini", 3))
	var fianchi := mini(massimo, _vicini_di(b, cd, a.lato, int(a.id)))
	if fianchi > 0:
		ma *= 1.0 + fianchi * float(cfg.get("fianco", 0.1))
		voci.append("fianchi +%d%%" % roundi(fianchi * float(cfg.get("fianco", 0.1)) * 100))
	# supporto: i compagni accanto al difensore lo aiutano
	var supporto := mini(massimo, _vicini_di(b, cd, d.lato, int(d.id)))
	if supporto > 0:
		md *= 1.0 + supporto * float(cfg.get("supporto", 0.1))
		voci.append("loro supporto +%d%%" % roundi(supporto * float(cfg.get("supporto", 0.1)) * 100))
	# le lance fermano i cavalli (in attacco e in difesa)
	var lance := float(cfg.get("lance_contro_cavalli", 1.5))
	if a.tipo == "fanti" and d.tipo == "cavalieri":
		ma *= lance
		voci.append("lance contro cavalli ×%.1f" % lance)
	elif a.tipo == "cavalieri" and d.tipo == "fanti" and not da_lontano:
		md *= lance
		voci.append("cavalli contro lance (loro ×%.1f)" % lance)
	return {"fa": int(a.uomini) * forza(a, cfg) * ma, "fd": int(d.uomini) * forza(d, cfg) * md, "voci": voci, "da_lontano": da_lontano}


## Le perdite che ci si aspetta da un attacco (senza fortuna), per decidere prima di colpire.
static func anteprima(b: Dictionary, id: int, bersaglio: int, cfg: Dictionary) -> Dictionary:
	var a := trova(b, id)
	var d := trova(b, bersaglio)
	if a.is_empty() or d.is_empty():
		return {}
	var f := forze(b, a, d, cfg)
	var morti := _perdite(a, d, float(f.fa), float(f.fd), bool(f.da_lontano), cfg)
	return {"morti_difensore": morti[0], "morti_attaccante": morti[1], "voci": f.voci, "da_lontano": f.da_lontano}


## Quanti cadono: [difensori, attaccanti]. Corpo a corpo il difensore risponde (contrattacco), da lontano no.
static func _perdite(a: Dictionary, d: Dictionary, fa: float, fd: float, da_lontano: bool, cfg: Dictionary) -> Array[int]:
	var morti_d := mini(int(d.uomini), roundi(fa / (fa + fd) * ceili(int(a.uomini) * float(cfg.letalita))))
	var morti_a := 0
	if not da_lontano and int(d.uomini) - morti_d > 0:
		morti_a = mini(int(a.uomini), roundi(fd / (fa + fd) * ceili(int(d.uomini) * float(cfg.risposta))))
	return [morti_d, morti_a]


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
	var f := forze(b, a, d, cfg)
	var fa := float(f.fa) * rng.randf_range(0.85, 1.15)
	var fd := float(f.fd) * rng.randf_range(0.85, 1.15)
	var da_lontano: bool = f.da_lontano
	var morti := _perdite(a, d, fa, fd, da_lontano, cfg)
	var morti_d := morti[0]
	var morti_a := morti[1]
	d.uomini = int(d.uomini) - morti_d
	a.uomini = int(a.uomini) - morti_a
	a.attaccato = true
	a.mosse = 0
	var esito := {"tipo": "attacco", "da": id, "a": bersaglio, "morti_attaccante": morti_a, "morti_difensore": morti_d, "da_lontano": da_lontano}
	if d.tipo == PORTA:
		_diario(b, "La porta è sfondata: il castello è aperto!" if int(d.uomini) <= 0 else "%s colpiscono la porta (-%d)." % [cfg.unita[a.tipo].nome, morti_d])
		return esito
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
		if u.tipo != PORTA:
			azioni.append_array(_mossa_nemica(b, u, cfg, rng))
	if not b.finita:
		# chi è sulla loro bandiera dopo il loro turno l'ha tenuta: è nostra
		var bandiera := Vector2i(int(b.bandiera[0]), int(b.bandiera[1]))
		var su := trova(b, occupante(b, bandiera))
		if not su.is_empty() and su.lato == "noi":
			_fine(b, true, "Abbiamo preso e tenuto la loro bandiera!")
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
	# senza limite di turni il nemico non aspetta per sempre: dopo qualche turno va all'assalto
	# (ma chi è assediato resta dietro le mura)
	var minaccia: bool = distanza(cella(vicino), bandiera) <= int(cfg.allarme_bandiera) or distanza(cella(vicino), cella(u)) <= int(cfg.unita[u.tipo].mosse) + 1 \
		or (int(b.turno) >= int(cfg.get("assalto_dal_turno", 5)) and not b.get("assedio", false))
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
		Terreno.MURA:
			p -= 0.6
		Terreno.COLLINA:
			p -= 0.4
		Terreno.BOSCO:
			p -= 0.3
	return p


static func _controlla_fine(b: Dictionary) -> void:
	if b.finita:
		return
	if vive(b, "loro").all(func(u): return u.tipo == PORTA):
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
