extends Node
## Stato della partita: risorse, abitanti, edifici, stagioni.
## Autoload "GameState". Tutti i numeri arrivano da data/*.json.

signal changed
signal season_changed(stagione: int, anno: int)
signal building_added(b: Dictionary)
signal building_removed(id: int)
signal building_finished(id: int)
signal message(testo: String)
signal game_ended(vittoria: bool, motivo: String)
signal capo_scelto(indice: int)
signal consiglio(famiglia: int, testo: String)

const PRIMAVERA := 0
const ESTATE := 1
const AUTUNNO := 2
const INVERNO := 3
const STAGIONI := ["Primavera", "Estate", "Autunno", "Inverno"]
const CHIAVI_STAGIONI := ["primavera", "estate", "autunno", "inverno"]
const RISORSE := ["legna", "pietra", "cibo", "ferro", "utensili", "oro", "grano", "farina"]
## Le risorse mostrate nella barra in alto (grano e farina restano nascosti).
const RISORSE_VISIBILI := ["legna", "pietra", "cibo", "ferro", "utensili", "oro"]
const SAVE_PATH := "user://save.json"
const VERSIONE_SALVATAGGIO := 2

var edifici: Dictionary = {}  # tipo -> definizione (data/edifici.json)
var bil: Dictionary = {}      # data/bilanciamento.json
var dati_famiglie: Dictionary = {}  # data/famiglie.json

var risorse: Dictionary = {}
var ultimo_delta: Dictionary = {}  # variazione di ogni risorsa nell'ultimo tick
var abitanti: int = 0
var felicita: float = 50.0
var stagione: int = PRIMAVERA
var anno: int = 1
var tick_in_stagione: int = 0
var livello: int = 0
var tasse: String = "normali"
var tasse_non_pagate: int = 0
var tick_fame: int = 0
var velocita: int = 1  # 0 = pausa
var seme_mappa: int = 0
var buildings: Array = []  # {id, tipo, cella: Vector2i, lavoratori, progresso 0..1, bonus}
var finita: bool = false
var terreno: TerrenoFeudo     # celle del feudo; creato da avvia()
var in_corso: bool = false    # c'è una partita caricata o iniziata
var nel_feudo: bool = false   # il tempo scorre solo dentro il feudo
## Le tre famiglie sopravvissute: {casata, capo, membri, tratto, motto, storia, colore}.
## Una guida i sopravvissuti, le altre due sono i consiglieri (in futuro: vassalli).
var famiglie: Array = []
var capo: int = -1            # indice in famiglie della casata che guida; -1 = non ancora scelta
var ultimi_consigli: Dictionary = {}  # famiglia -> ultimo consiglio mostrato
var _tick_dall_ultimo_consiglio := 0

var _prossimo_id: int = 1
var _accumulo: float = 0.0
var _fame: bool = false
var _freddo: bool = false
var _tipi_cibo: int = 0
var _pane: bool = false


func _ready() -> void:
	edifici = (load("res://data/edifici.json") as JSON).data
	bil = (load("res://data/bilanciamento.json") as JSON).data
	dati_famiglie = (load("res://data/famiglie.json") as JSON).data


# --- Partita -----------------------------------------------------------------

## Carica il salvataggio oppure inizia una partita nuova: un falò e una tenda per famiglia.
## Chiamata sia dalla mappa del regno sia dal feudo: la prima volta fa il lavoro, poi niente.
func avvia() -> void:
	if in_corso:
		return
	var caricata := carica()
	if not caricata:
		nuova_partita()
	terreno = TerrenoFeudo.new(seme_mappa)
	for b in buildings:
		terreno.occupa(b)
	if not caricata:
		_prepara_accampamento()
		salva()
	in_corso = true


## Il falò al centro del feudo e, attorno, una tenda per ogni famiglia.
func _prepara_accampamento() -> void:
	var p: Dictionary = bil.partenza
	var centro := TerrenoFeudo.centro_feudo()
	var falo := terreno.trova_posto(p.falo, centro - Vector2i.ONE)
	if falo.x < 0:
		return
	aggiungi_gratis(p.falo, falo, 1.0)
	var d := int(p.distanza_tende)
	var direzioni := [Vector2i(-d, -1), Vector2i(d, -1), Vector2i(0, d)]
	for i in famiglie.size():
		var c := terreno.trova_posto(p.tenda, falo + direzioni[i % direzioni.size()])
		if c.x >= 0:
			var tenda := aggiungi_gratis(p.tenda, c, 1.0)
			tenda.famiglia = i


## Pesca le famiglie della partita dal seme, così ogni partita ha casate diverse.
func _scegli_famiglie() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme_mappa + 3
	var pool: Array = dati_famiglie.casate.duplicate(true)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	famiglie = pool.slice(0, int(dati_famiglie.numero))
	for f in famiglie:
		f.colore = ""
	abitanti = 0
	for f in famiglie:
		abitanti += int(f.membri)


## La casata scelta davanti al falò guida i sopravvissuti; le altre diventano consiglieri.
## La guida porta il rosso della fazione, i consiglieri gli altri colori.
func scegli_capo(indice: int) -> void:
	capo = indice
	var colori: Array = dati_famiglie.colori
	var prossimo := 1
	for i in famiglie.size():
		if i == indice:
			famiglie[i].colore = colori[0]
		else:
			famiglie[i].colore = colori[prossimo % colori.size()]
			prossimo += 1
	capo_scelto.emit(indice)
	changed.emit()
	salva()


func consiglieri() -> Array[int]:
	var lista: Array[int] = []
	for i in famiglie.size():
		if i != capo:
			lista.append(i)
	return lista


func tratto(famiglia: int) -> Dictionary:
	if famiglia < 0 or famiglia >= famiglie.size():
		return {}
	return dati_famiglie.tratti.get(famiglie[famiglia].tratto, {})


## Moltiplicatore del tratto della guida per una risorsa prodotta.
func bonus_guida(risorsa: String) -> float:
	return float(tratto(capo).get("produzione", {}).get(risorsa, 1.0))


func ricomincia() -> void:
	cancella_salvataggio()
	in_corso = false
	nel_feudo = false
	terreno = null


func nuova_partita(seme: int = -1) -> void:
	risorse = {}
	for r in RISORSE:
		risorse[r] = float(bil.risorse_iniziali.get(r, 0))
	ultimo_delta = {}
	felicita = float(bil.felicita_base)
	stagione = PRIMAVERA
	anno = 1
	tick_in_stagione = 0
	livello = 0
	tasse = "normali"
	tasse_non_pagate = 0
	tick_fame = 0
	velocita = 1
	seme_mappa = seme if seme >= 0 else randi() % 1000000
	capo = -1
	ultimi_consigli = {}
	_tick_dall_ultimo_consiglio = 0
	_scegli_famiglie()
	buildings = []
	finita = false
	terreno = null
	_prossimo_id = 1
	_accumulo = 0.0


## Aggiunge un edificio già pronto, senza costi (case iniziali).
func aggiungi_gratis(tipo: String, cella: Vector2i, bonus: float) -> Dictionary:
	return _aggiungi(tipo, cella, bonus, 1.0)


func _process(delta: float) -> void:
	if finita or not nel_feudo or velocita == 0 or bil.is_empty():
		return
	var dt := delta * velocita
	for b in buildings:
		if b.progresso < 1.0:
			b.progresso = minf(1.0, b.progresso + dt / tempo_costruzione(b.tipo))
			if b.progresso >= 1.0:
				_completa(b)
	_accumulo += dt
	var passo: float = bil.tick_secondi
	while _accumulo >= passo and not finita:
		_accumulo -= passo
		_tick()


# --- Edifici -----------------------------------------------------------------

func sbloccato(tipo: String) -> bool:
	return int(edifici[tipo].livello) <= livello


func puo_permettersi(tipo: String) -> bool:
	var costo: Dictionary = edifici[tipo].get("costo", {})
	for r in costo:
		if risorse[r] < costo[r]:
			return false
	return true


func piazza(tipo: String, cella: Vector2i, bonus: float) -> Dictionary:
	if not sbloccato(tipo) or not puo_permettersi(tipo):
		return {}
	var costo: Dictionary = edifici[tipo].get("costo", {})
	for r in costo:
		risorse[r] -= costo[r]
	var b := _aggiungi(tipo, cella, bonus, 0.0)
	changed.emit()
	return b


func demolisci(id: int) -> void:
	var b := trova(id)
	if b.is_empty() or edifici[b.tipo].get("fisso", false):
		return
	var costo: Dictionary = edifici[b.tipo].get("costo", {})
	for r in costo:
		risorse[r] = minf(capacita(), risorse[r] + floorf(costo[r] * bil.rimborso_demolizione))
	if terreno:
		terreno.libera(b)
	buildings.erase(b)
	building_removed.emit(id)
	changed.emit()


func trova(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}


func aggiungi_lavoratore(id: int) -> void:
	var b := trova(id)
	if b.is_empty() or b.progresso < 1.0:
		return
	if b.lavoratori < int(edifici[b.tipo].lavoratori) and disoccupati() > 0:
		b.lavoratori += 1
		changed.emit()


func togli_lavoratore(id: int) -> void:
	var b := trova(id)
	if not b.is_empty() and b.lavoratori > 0:
		b.lavoratori -= 1
		changed.emit()


func tempo_costruzione(tipo: String) -> float:
	var c: Dictionary = bil.costruzione
	var taglia: Array = edifici[tipo].taglia
	var secondi := clampf(c.secondi_per_4_tile * taglia[0] * taglia[1] / 4.0, c.minimo, c.massimo)
	if stagione == INVERNO:
		secondi *= c.molt_inverno
	return secondi * float(tratto(capo).get("costruzione", 1.0))


func _aggiungi(tipo: String, cella: Vector2i, bonus: float, progresso: float) -> Dictionary:
	var b := {
		"id": _prossimo_id, "tipo": tipo, "cella": cella,
		"lavoratori": 0, "progresso": progresso, "bonus": bonus,
	}
	_prossimo_id += 1
	buildings.append(b)
	if terreno:
		terreno.occupa(b)
	building_added.emit(b)
	return b


func _completa(b: Dictionary) -> void:
	var d: Dictionary = edifici[b.tipo]
	b.lavoratori = mini(int(d.lavoratori), disoccupati())
	building_finished.emit(b.id)
	message.emit("%s completato" % d.nome)
	changed.emit()
	if d.get("vittoria", false):
		_fine(true, "Il maniero è pronto: il tuo borgo è diventato una città!")


# --- Conteggi ----------------------------------------------------------------

func capacita() -> float:
	var totale := float(bil.capacita_base)
	for b in buildings:
		if b.progresso >= 1.0:
			totale += float(edifici[b.tipo].get("capacita", 0))
	return totale


func alloggi() -> int:
	var totale := 0
	for b in buildings:
		if b.progresso >= 1.0:
			totale += int(edifici[b.tipo].get("alloggi", 0))
	return totale


func lavoratori_assegnati() -> int:
	var totale := 0
	for b in buildings:
		totale += int(b.lavoratori)
	return totale


func disoccupati() -> int:
	return maxi(0, abitanti - lavoratori_assegnati())


func conta_completati(tipo: String) -> int:
	var n := 0
	for b in buildings:
		if b.tipo == tipo and b.progresso >= 1.0:
			n += 1
	return n


func tassa_del_re() -> int:
	return int(bil.re.tassa_iniziale + bil.re.incremento * (anno - 1))


## Ogni voce che pesa sulla felicità, per il calcolo e per il pannello Info.
func fattori_felicita() -> Dictionary:
	var f: Dictionary = bil.felicita
	var fattori := {"Base": float(bil.felicita_base)}
	if _tipi_cibo >= 2:
		fattori["Cibo vario"] = f.cibo_vario
	if _pane:
		fattori["Pane"] = f.pane
	var visti := {}
	for b in buildings:
		var d: Dictionary = edifici[b.tipo]
		if d.has("felicita") and _attivo(b) and not visti.has(b.tipo):
			visti[b.tipo] = true
			fattori[d.nome] = d.felicita
	fattori["Tasse " + tasse] = bil.tasse[tasse].felicita
	if tratto(capo).has("felicita"):
		fattori["Guida " + tratto(capo).nome.to_lower()] = tratto(capo).felicita
	if abitanti > alloggi():
		fattori["Senza casa"] = f.senza_casa
	if _fame:
		fattori["Fame"] = f.fame
	if _freddo:
		fattori["Freddo"] = f.freddo
	if abitanti > 0 and float(disoccupati()) / abitanti > f.soglia_disoccupazione:
		fattori["Disoccupati"] = f.disoccupazione
	return fattori


func _attivo(b: Dictionary) -> bool:
	return b.progresso >= 1.0 and (int(edifici[b.tipo].lavoratori) == 0 or b.lavoratori > 0)


## Testo breve sull'effetto di un edificio, per menu e pannelli.
func testo_effetto(tipo: String) -> String:
	var d: Dictionary = edifici[tipo]
	var parti: Array[String] = []
	var consuma: Dictionary = d.get("consuma", {})
	var produce: Dictionary = d.get("produce", {})
	if not consuma.is_empty():
		parti.append("%s → %s" % [_elenco(consuma), _elenco(produce)])
	elif not produce.is_empty():
		parti.append("+" + _elenco(produce))
	if d.has("alloggi"):
		parti.append("ospita %d" % d.alloggi)
	if d.has("capacita"):
		parti.append("+%d capacità" % d.capacita)
	if d.has("felicita"):
		parti.append("%+d felicità" % d.felicita)
	if d.has("vicino"):
		parti.append("vicino a " + d.vicino)
	if d.has("su"):
		parti.append("solo su " + d.su)
	if d.get("vittoria", false):
		parti.append("vince la partita")
	return " · ".join(parti)


func testo_costo(tipo: String) -> String:
	return _elenco(edifici[tipo].get("costo", {}))


func _elenco(valori: Dictionary) -> String:
	var parti: Array[String] = []
	for r in valori:
		parti.append("%d %s" % [valori[r], r])
	return ", ".join(parti)


# --- Tick e stagioni ---------------------------------------------------------

func _tick() -> void:
	var tps: float = bil.tick_per_stagione
	var prima := risorse.duplicate()
	var cap := capacita()
	var tipi_cibo := {}
	_pane = false

	for b in buildings:
		if b.progresso < 1.0:
			continue
		var d: Dictionary = edifici[b.tipo]
		var max_l := int(d.lavoratori)
		var molt := 1.0 if max_l == 0 else float(b.lavoratori) / max_l
		molt *= float(b.bonus) * float(d.get("stagioni", {}).get(CHIAVI_STAGIONI[stagione], 1.0))
		if molt <= 0.0:
			continue
		# Se manca un ingrediente, l'edificio lavora solo per la parte disponibile.
		var consuma: Dictionary = d.get("consuma", {})
		for r in consuma:
			var serve: float = consuma[r] / tps * molt
			if serve > 0.0:
				molt *= minf(1.0, risorse[r] / serve)
		if molt <= 0.0:
			continue
		for r in consuma:
			risorse[r] = maxf(0.0, risorse[r] - consuma[r] / tps * molt)
		var produce: Dictionary = d.get("produce", {})
		for r in produce:
			risorse[r] = minf(cap, risorse[r] + produce[r] / tps * molt * bonus_guida(r))
		if produce.has("cibo"):
			tipi_cibo[b.tipo] = true
		if d.get("pane", false):
			_pane = true
	_tipi_cibo = tipi_cibo.size()

	# Riscaldamento d'inverno.
	_freddo = false
	if stagione == INVERNO:
		var legna_serve := 0.0
		for b in buildings:
			if b.progresso >= 1.0:
				legna_serve += float(edifici[b.tipo].get("riscaldamento", 0)) / tps
		if risorse.legna < legna_serve:
			_freddo = true
		risorse.legna = maxf(0.0, risorse.legna - legna_serve)

	# Cibo per gli abitanti.
	var cibo_serve: float = abitanti * bil.cibo_per_abitante_tick
	_fame = risorse.cibo < cibo_serve
	if _fame:
		tick_fame += 1
	risorse.cibo = maxf(0.0, risorse.cibo - cibo_serve)

	var obiettivo := 0.0
	for v in fattori_felicita().values():
		obiettivo += v
	felicita = move_toward(felicita, clampf(obiettivo, 0.0, 100.0), 1.0)

	ultimo_delta = {}
	for r in risorse:
		ultimo_delta[r] = risorse[r] - prima[r]

	tick_in_stagione += 1
	if tick_in_stagione >= tps:
		_fine_stagione()
	_tick_dall_ultimo_consiglio += 1
	if _tick_dall_ultimo_consiglio >= 15:
		_tick_dall_ultimo_consiglio = 0
		_aggiorna_consigli()
	changed.emit()


## Ogni tanto i consiglieri guardano il villaggio; se uno ha un consiglio nuovo, lo dice.
## Ne parla uno solo per volta, per non riempire lo schermo.
func _aggiorna_consigli() -> void:
	if capo < 0:
		return
	for i in consiglieri():
		var testo := Consiglio.per(i)
		if testo != "" and testo != ultimi_consigli.get(i, ""):
			ultimi_consigli[i] = testo
			consiglio.emit(i, testo)
			return


func _fine_stagione() -> void:
	var c: Dictionary = bil.crescita
	if tick_fame >= int(bil.tick_per_stagione):
		var morti := ceili(abitanti * c.quota_morti_fame)
		_togli_abitanti(morti)
		message.emit("La fame ha ucciso %d abitanti" % morti)
	elif felicita < c.soglia_partenze:
		var partiti := ceili(abitanti * c.quota_partenze)
		_togli_abitanti(partiti)
		message.emit("%d abitanti scontenti se ne sono andati" % partiti)

	if stagione == AUTUNNO:
		_riscuoti_tasse()
	if finita:
		return
	if abitanti <= 0:
		_fine(false, "Il villaggio è rimasto vuoto.")
		return

	stagione = (stagione + 1) % 4
	tick_in_stagione = 0
	tick_fame = 0
	if stagione == PRIMAVERA:
		anno += 1
		_arrivi()
	_controlla_livello()
	season_changed.emit(stagione, anno)
	salva()


func _riscuoti_tasse() -> void:
	var incasso := int(abitanti * int(bil.tasse[tasse].oro) * float(tratto(capo).get("tasse", 1.0)))
	risorse.oro = minf(capacita(), risorse.oro + incasso)
	var dovuto := tassa_del_re()
	if risorse.oro >= dovuto:
		risorse.oro -= dovuto
		tasse_non_pagate = 0
		message.emit("Tasse: +%d oro dagli abitanti, %d oro al re" % [incasso, dovuto])
		return
	tasse_non_pagate += 1
	felicita = maxf(0.0, felicita - bil.re.malus_felicita)
	if tasse_non_pagate >= int(bil.re.mancati_per_sconfitta):
		_fine(false, "Non hai pagato il re per due autunni: ha mandato un nuovo signore.")
	else:
		message.emit("Non hai %d oro per il re! Al prossimo autunno perdi il villaggio" % dovuto)


func _arrivi() -> void:
	var c: Dictionary = bil.crescita
	if felicita < c.soglia_arrivi:
		return
	var famiglie := int((alloggi() - abitanti) / c.famiglia)
	if famiglie > 0:
		abitanti += famiglie * int(c.famiglia)
		message.emit("Sono arrivate %d nuove famiglie" % famiglie)


func _controlla_livello() -> void:
	var livelli: Array = bil.livelli
	while livello + 1 < livelli.size() and requisiti_mancanti(livello + 1).is_empty():
		livello += 1
		message.emit("Il villaggio ora è un %s! Nuovi edifici disponibili" % livelli[livello].nome)


## Elenco leggibile di ciò che manca per raggiungere un livello (vuoto = raggiunto).
func requisiti_mancanti(liv: int) -> Array[String]:
	var req: Dictionary = bil.livelli[liv]
	var manca: Array[String] = []
	if abitanti < int(req.get("abitanti", 0)):
		manca.append("%d abitanti" % req.abitanti)
	if felicita < float(req.get("felicita", 0)):
		manca.append("felicità %d" % req.felicita)
	var richiesti: Dictionary = req.get("edifici", {})
	for tipo in richiesti:
		if conta_completati(tipo) < int(richiesti[tipo]):
			manca.append("%d %s" % [richiesti[tipo], edifici[tipo].nome.to_lower()])
	return manca


func _togli_abitanti(n: int) -> void:
	abitanti = maxi(0, abitanti - n)
	var eccesso := lavoratori_assegnati() - abitanti
	for i in range(buildings.size() - 1, -1, -1):
		if eccesso <= 0:
			break
		var tolti := mini(int(buildings[i].lavoratori), eccesso)
		buildings[i].lavoratori -= tolti
		eccesso -= tolti


func _fine(vittoria: bool, motivo: String) -> void:
	finita = true
	cancella_salvataggio()
	game_ended.emit(vittoria, motivo)


# --- Salvataggio -------------------------------------------------------------

func salva() -> void:
	if finita or bil.is_empty() or buildings.is_empty():
		return
	var lista := []
	for b in buildings:
		lista.append({
			"id": b.id, "tipo": b.tipo, "cella": [b.cella.x, b.cella.y],
			"lavoratori": b.lavoratori, "progresso": b.progresso, "bonus": b.bonus,
			"famiglia": b.get("famiglia", -1),
		})
	var dati := {
		"versione": VERSIONE_SALVATAGGIO, "famiglie": famiglie, "capo": capo, "risorse": risorse, "abitanti": abitanti, "felicita": felicita,
		"stagione": stagione, "anno": anno, "tick_in_stagione": tick_in_stagione,
		"livello": livello, "tasse": tasse, "tasse_non_pagate": tasse_non_pagate,
		"seme_mappa": seme_mappa, "prossimo_id": _prossimo_id, "buildings": lista,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dati))


func carica() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var dati = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	# i salvataggi delle versioni precedenti (mappa più piccola, niente famiglie) non si caricano
	if not dati is Dictionary or int(dati.get("versione", 0)) != VERSIONE_SALVATAGGIO:
		return false
	nuova_partita(int(dati.seme_mappa))
	famiglie = dati.famiglie
	for f in famiglie:
		f.membri = int(f.membri)
	capo = int(dati.capo)
	for r in dati.risorse:
		risorse[r] = float(dati.risorse[r])
	abitanti = int(dati.abitanti)
	felicita = float(dati.felicita)
	stagione = int(dati.stagione)
	anno = int(dati.anno)
	tick_in_stagione = int(dati.tick_in_stagione)
	livello = int(dati.livello)
	tasse = dati.tasse
	tasse_non_pagate = int(dati.tasse_non_pagate)
	_prossimo_id = int(dati.prossimo_id)
	for x in dati.buildings:
		if not edifici.has(x.tipo):
			continue
		var b := {
			"id": int(x.id), "tipo": x.tipo, "cella": Vector2i(int(x.cella[0]), int(x.cella[1])),
			"lavoratori": int(x.lavoratori), "progresso": float(x.progresso), "bonus": float(x.bonus),
		}
		if int(x.get("famiglia", -1)) >= 0:
			b.famiglia = int(x.famiglia)
		buildings.append(b)
	return true


func cancella_salvataggio() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
