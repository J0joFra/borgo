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
signal evento(carta: Dictionary)  # una carta evento da mostrare (il gioco è in pausa)
signal terreno_cambiato(celle: Array)  # celle cambiate: bosco abbattuto o ricresciuto, piantine, strade

const PRIMAVERA := 0
const ESTATE := 1
const AUTUNNO := 2
const INVERNO := 3
const STAGIONI := ["Primavera", "Estate", "Autunno", "Inverno"]
const CHIAVI_STAGIONI := ["primavera", "estate", "autunno", "inverno"]
const RISORSE := ["legna", "pietra", "cibo", "ferro", "utensili", "oro", "grano", "farina",
	"orzo", "rape", "semi_orzo", "semi_grano", "semi_rape"]
## Cosa si mangia, nell'ordine: prima il cibo pronto, poi le rape, l'orzo e per ultimo il grano (che serve al pane).
const CIBI := ["cibo", "rape", "orzo", "grano"]
## Le risorse mostrate nella barra in alto (grano e farina restano nascosti).
const RISORSE_VISIBILI := ["legna", "pietra", "cibo", "grano", "orzo", "rape", "ferro", "utensili", "oro"]
const SAVE_PATH := "user://save.json"
const VERSIONE_SALVATAGGIO := 5

var edifici: Dictionary = {}  # tipo -> definizione (data/edifici.json)
var bil: Dictionary = {}      # data/bilanciamento.json
var dati_famiglie: Dictionary = {}  # data/famiglie.json
var colture: Dictionary = {}  # data/colture.json
var mercato: Mercato

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
var _tagli_da_applicare: Array = []  # tagli del bosco letti dal salvataggio, applicati da avvia()
var _terreno_salvato: Dictionary = {}  # strade, piantine e boschi nuovi letti dal salvataggio
var _rng := RandomNumberGenerator.new()  # arrivi di nuove persone
var _tick_scontento := 0
var attrattiva := 0.0  # quanto il villaggio attira gente nuova (0..1), per il pannello Info
var tick_senza_casa := 0  # da quanto qualcuno dorme all'aperto
var modificatori: Array = []  # effetti temporanei delle carte evento: {edificio|coltura|riscaldamento|tassa_re, molt, stagioni}
var evento_attivo: Dictionary = {}  # la carta mostrata adesso, con il consigliere che la racconta
var eventi_usati: Array = []
var dati_eventi: Dictionary = {}
var _tick_evento := -1  # in quale tick della stagione arriva la prossima carta (-1: nessuna)
var _velocita_prima := 1
var _evento_da_riprendere := ""
var _rete_strade: Dictionary = {}  # celle di strada collegate alla piazza (calcolate quando servono)
var _rete_valida := false

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
	colture = (load("res://data/colture.json") as JSON).data
	dati_eventi = (load("res://data/eventi.json") as JSON).data
	building_added.connect(func(_b): _rete_valida = false)
	building_removed.connect(func(_id): _rete_valida = false)
	terreno_cambiato.connect(func(_c): _rete_valida = false)


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
	terreno.applica_tagli(_tagli_da_applicare)
	terreno.applica_salvataggio(_terreno_salvato)
	_tagli_da_applicare = []
	_terreno_salvato = {}
	for b in buildings:
		terreno.occupa(b)
	if not caricata:
		_prepara_accampamento()
		# si parte con i semi della pianta selvatica più vicina all'accampamento
		var vicina := terreno.selvatica_piu_vicina(TerrenoFeudo.centro_feudo())
		if vicina != "":
			risorse[colture[vicina].semi] = float(colture.semi_iniziali)
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
	_costruisci_dimora(indice)
	_programma_evento()
	capo_scelto.emit(indice)
	changed.emit()
	salva()


## La tenda della famiglia che guida diventa la dimora del signore, attaccata al falò:
## una torre a forma di castello che segna il centro del feudo.
func _costruisci_dimora(indice: int) -> void:
	if terreno == null:
		return
	var tenda := {}
	var falo := {}
	for b in buildings:
		if b.tipo == "tenda" and b.get("famiglia", -1) == indice:
			tenda = b
		if b.tipo == "falo":
			falo = b
	if tenda.is_empty() or falo.is_empty():
		return
	terreno.libera(tenda)
	buildings.erase(tenda)
	building_removed.emit(tenda.id)
	var posto := Vector2i(-1, -1)
	for spostamento in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, -2), Vector2i(-2, 2)]:
		if terreno.posizione_valida("dimora", falo.cella + spostamento):
			posto = falo.cella + spostamento
			break
	if posto.x < 0:
		posto = terreno.trova_posto("dimora", falo.cella)
	if posto.x >= 0:
		var dimora := aggiungi_gratis("dimora", posto, 1.0)
		dimora.famiglia = indice
		_strada_iniziale(dimora, falo)


## Dalla dimora parte una strada corta, possibilmente dalla parte opposta al falò:
## l'inizio del borgo.
func _strada_iniziale(dimora: Dictionary, falo: Dictionary) -> void:
	var lunghezza := int(bil.strade.strada_iniziale)
	var t: Array = edifici[dimora.tipo].taglia
	var w := int(t[0])
	var h := int(t[1])
	var lontano := Vector2(dimora.cella - falo.cella).normalized()
	var direzioni := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	direzioni.sort_custom(func(a, b): return Vector2(a).dot(lontano) > Vector2(b).dot(lontano))
	for dir in direzioni:
		# parte dal lato della dimora rivolto in quella direzione
		var inizio: Vector2i = dimora.cella
		match dir:
			Vector2i(1, 0): inizio += Vector2i(w, h / 2)
			Vector2i(-1, 0): inizio += Vector2i(-1, h / 2)
			Vector2i(0, 1): inizio += Vector2i(w / 2, h)
			_: inizio += Vector2i(w / 2, -1)
		var celle_s := []
		for i in lunghezza:
			celle_s.append(inizio + dir * i)
		if terreno.costo_strada(celle_s) >= 0:
			terreno_cambiato.emit(terreno.aggiungi_strada(celle_s))
			return


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
	_tagli_da_applicare = []
	_terreno_salvato = {}
	_rng.seed = seme_mappa + 17
	_tick_scontento = 0
	tick_senza_casa = 0
	modificatori = []
	evento_attivo = {}
	eventi_usati = []
	_tick_evento = -1
	_evento_da_riprendere = ""
	_rete_valida = false
	attrattiva = 0.0
	mercato = Mercato.new(seme_mappa)
	_scegli_famiglie()
	buildings = []
	finita = false
	terreno = null
	_prossimo_id = 1
	_accumulo = 0.0


## Aggiunge un edificio già pronto, senza costi (case iniziali).
func aggiungi_gratis(tipo: String, cella: Vector2i, bonus: float) -> Dictionary:
	var b := _aggiungi(tipo, cella, bonus, 1.0)
	_segna_eta(b)
	return b


## Le cose che durano poco (le tende) contano le stagioni da quando sono finite;
## finite a stagione inoltrata, quella stagione non conta.
func _segna_eta(b: Dictionary) -> void:
	if int(edifici[b.tipo].get("durata_stagioni", 0)) > 0:
		b.eta = 0 if tick_in_stagione <= int(bil.tick_per_stagione) / 4 else -1


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

## La definizione di un edificio al suo livello: i miglioramenti sostituiscono i valori base
## (alloggi, capacità, felicità, lavoratori...) e "produzione" moltiplica ciò che produce.
func def_di(b: Dictionary) -> Dictionary:
	var d: Dictionary = edifici[b.tipo]
	var livello_b := int(b.get("livello", 1))
	if livello_b <= 1:
		return d
	var unito := d.duplicate()
	var miglioramenti: Array = d.get("miglioramenti", [])
	for i in mini(livello_b - 1, miglioramenti.size()):
		unito.merge(miglioramenti[i], true)
	unito.nome = d.nome if livello_b - 2 >= miglioramenti.size() else miglioramenti[livello_b - 2].nome
	return unito


## Il prossimo miglioramento possibile, o {} se è già al massimo (o non ne ha).
func prossimo_miglioramento(b: Dictionary) -> Dictionary:
	var miglioramenti: Array = edifici[b.tipo].get("miglioramenti", [])
	var i := int(b.get("livello", 1)) - 1
	return miglioramenti[i] if i < miglioramenti.size() else {}


func puo_migliorare(b: Dictionary) -> bool:
	var m := prossimo_miglioramento(b)
	if m.is_empty() or b.progresso < 1.0:
		return false
	for r in m.costo:
		if risorse[r] < m.costo[r]:
			return false
	return true


func migliora(id: int) -> void:
	var b := trova(id)
	if b.is_empty() or not puo_migliorare(b):
		return
	var m := prossimo_miglioramento(b)
	for r in m.costo:
		risorse[r] -= m.costo[r]
	b.livello = int(b.get("livello", 1)) + 1
	message.emit("%s migliorato: ora è %s" % [edifici[b.tipo].nome, m.nome])
	changed.emit()


## Quanto lavora bene un edificio, al di là di zona e lavoratori: chi non è collegato alla
## piazza perde un po' (strade) e le carte evento possono rallentarlo o spingerlo.
func efficienza(b: Dictionary) -> float:
	var e := 1.0
	if int(def_di(b).lavoratori) > 0 and not collegato(b):
		e -= float(bil.strade.malus_non_collegato)
	e *= molt_modificatore("edificio", b.tipo)
	if edifici[b.tipo].get("coltura", false):
		e *= molt_modificatore("coltura")
	return e


## Resa della zona per un edificio piazzato (1.0 senza terreno, ad esempio nei test).
func resa_di(b: Dictionary) -> float:
	if terreno == null:
		return 1.0
	return terreno.resa(b.tipo, b.cella, stagione)


## Quanto produrrebbe un edificio qui, a pieno regime, con la spiegazione della zona.
## Es. "Resa: 36 legna a stagione · 24 celle di bosco".
func stima_produzione(tipo: String, cella: Vector2i, livello_b := 1, coltura := "") -> String:
	var d := def_di({"tipo": tipo, "livello": livello_b})
	if d.get("coltura", false) and terreno:
		return _stima_campo(d, cella, coltura if coltura != "" else coltura_iniziale(cella))
	var produce: Dictionary = d.get("produce", {})
	if produce.is_empty() or not d.has("zona") or terreno == null:
		return ""
	var info := terreno.info_zona(tipo, cella, stagione)
	var stagioni: Dictionary = d.get("stagioni", {})
	# un raccolto: produce solo in alcune stagioni (i valori del JSON sono decimali: 0.0, non 0)
	var raccolto: bool = stagioni.values().any(func(v): return float(v) == 0.0) and float(stagioni.get("autunno", 1.0)) > 0.0
	var parti: Array[String] = []
	for r in produce:
		var valore := float(produce[r]) * float(info.resa) * float(d.get("produzione", 1.0)) * bonus_guida(r)
		parti.append("%d %s" % [roundi(valore), r])
	var quando := "al raccolto d'autunno" if raccolto else "a stagione"
	return "Resa: %s %s · %s" % [", ".join(parti), quando, info.testo]


func _stima_campo(d: Dictionary, cella: Vector2i, nome: String) -> String:
	var c: Dictionary = colture[nome]
	var info := terreno.info_zona("campo", cella, stagione)
	var t := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
	var selvatico := terreno.selvatica_sotto(cella, t) == nome
	var valore := float(c.resa) * float(info.resa) * float(d.get("produzione", 1.0)) * bonus_guida(c.risorsa)
	if selvatico:
		valore *= float(colture.bonus_selvatico)
	var semi := "%s selvatico qui: niente semi" % c.nome.to_lower() if selvatico else "semina con %d semi (ne hai %d)" % [int(c.semi_per_semina), int(risorse[c.semi])]
	return "Resa: %d %s a stagione in %s · %s · %s" % [roundi(valore), c.risorsa, " e ".join(c.stagioni), info.testo, semi]


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
	if edifici[tipo].get("coltura", false):
		b.coltura = coltura_iniziale(cella)
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
	if b.lavoratori < int(def_di(b).lavoratori) and disoccupati() > 0:
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
	if d.get("disbosca", false) and terreno:
		# il bosco attorno quando inizia il lavoro: decide quanto se ne taglia a stagione
		var taglia := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
		b.bosco_iniziale = terreno.conta_attorno(b.cella, taglia, int(d.zona.raggio), TerrenoFeudo.Tipo.BOSCO)
	_segna_eta(b)
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
			totale += float(def_di(b).get("capacita", 0))
	return totale


func alloggi() -> int:
	var totale := 0
	for b in buildings:
		if b.progresso >= 1.0:
			totale += int(def_di(b).get("alloggi", 0))
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
	return int((bil.re.tassa_iniziale + bil.re.incremento * (anno - 1)) * molt_modificatore("tassa_re"))


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
		var d := def_di(b)
		if d.has("felicita") and _attivo(b) and not visti.has(b.tipo) and int(d.felicita) != 0:
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
	return b.progresso >= 1.0 and (int(def_di(b).lavoratori) == 0 or b.lavoratori > 0)


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
	if d.has("zona"):
		var spiegazioni := {"bosco": "rende di più con tanto bosco attorno", "roccia": "rende di più tra le rocce",
			"acqua": "rende di più vicino a lago o fiume", "fertilita": "rende di più su terra fertile"}
		parti.append(spiegazioni.get(d.zona.tipo, ""))
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
		var d := def_di(b)
		var max_l := int(d.lavoratori)
		var molt := 1.0 if max_l == 0 else float(b.lavoratori) / max_l
		molt *= float(b.bonus) * float(d.get("stagioni", {}).get(CHIAVI_STAGIONI[stagione], 1.0))
		molt *= resa_di(b) * float(d.get("produzione", 1.0)) * efficienza(b)
		if d.get("coltura", false):
			_lavora_campo(b, molt, cap, tps)
			continue
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
		if b.tipo == "raccoglitore":
			_raccogli_semi(b, molt, cap, tps)
		if d.get("pane", false):
			_pane = true
	# cibo vario: quanti cibi diversi ci sono in dispensa
	for r in CIBI:
		if risorse[r] >= 1.0:
			tipi_cibo[r] = true
	_tipi_cibo = tipi_cibo.size()

	# Riscaldamento d'inverno.
	_freddo = false
	if stagione == INVERNO:
		var legna_serve := 0.0
		for b in buildings:
			if b.progresso >= 1.0:
				legna_serve += float(def_di(b).get("riscaldamento", 0)) / tps
		legna_serve *= molt_modificatore("riscaldamento")
		if risorse.legna < legna_serve:
			_freddo = true
		risorse.legna = maxf(0.0, risorse.legna - legna_serve)

	# Cibo per gli abitanti.
	# Si mangia prima il cibo; se non basta, il grano dei campi (non macinato, ma sfama).
	var manca: float = abitanti * bil.cibo_per_abitante_tick
	for r in CIBI:
		var preso := minf(risorse[r], manca)
		risorse[r] -= preso
		manca -= preso
	_fame = manca > 0.0001
	var c: Dictionary = bil.crescita
	# Con la fame la felicità scende piano (vedi fattori) e ogni tanto qualcuno se ne va.
	if _fame:
		tick_fame += 1
		if tick_fame % int(c.fame_partenza_ogni) == 0:
			_togli_abitanti(1)
			message.emit("Una persona se n'è andata: qui si patisce la fame")
	else:
		tick_fame = 0
	if felicita < float(c.soglia_partenze):
		_tick_scontento += 1
		if _tick_scontento % int(c.scontenti_partenza_ogni) == 0:
			_togli_abitanti(1)
			message.emit("Una persona scontenta ha lasciato il villaggio")
	else:
		_tick_scontento = 0
	_controlla_senzatetto()
	if abitanti <= 0:
		_fine(false, "Il villaggio è rimasto vuoto.")
		return
	if (tick_in_stagione + 1) % int(c.controllo_ogni) == 0:
		_arrivi()

	var obiettivo := 0.0
	for v in fattori_felicita().values():
		obiettivo += v
	felicita = move_toward(felicita, clampf(obiettivo, 0.0, 100.0), 1.0)

	ultimo_delta = {}
	for r in risorse:
		ultimo_delta[r] = risorse[r] - prima[r]

	tick_in_stagione += 1
	if tick_in_stagione == _tick_evento:
		_pesca_evento()
	if tick_in_stagione >= tps:
		_fine_stagione()
	_tick_dall_ultimo_consiglio += 1
	if _tick_dall_ultimo_consiglio >= 15:
		_tick_dall_ultimo_consiglio = 0
		_aggiorna_consigli()
	changed.emit()


# --- Campi e colture -----------------------------------------------------------

func coltura_di(b: Dictionary) -> Dictionary:
	return colture.get(b.get("coltura", ""), {})


## Vero se il campo sta (almeno in parte) sulla zona selvatica della sua coltura:
## lì la pianta cresce da sé, quindi non servono semi e rende un po' di più.
func campo_selvatico(b: Dictionary) -> bool:
	if terreno == null:
		return false
	var t: Array = edifici[b.tipo].taglia
	return terreno.selvatica_sotto(b.cella, Vector2i(int(t[0]), int(t[1]))) == b.get("coltura", "")


## La coltura con cui partire su un campo nuovo: quella selvatica sotto, altrimenti
## quella di cui si hanno più semi.
func coltura_iniziale(cella: Vector2i) -> String:
	if terreno:
		var t: Array = edifici.campo.taglia
		var selvatica := terreno.selvatica_sotto(cella, Vector2i(int(t[0]), int(t[1])))
		if selvatica != "":
			return selvatica
	var migliore := "orzo"
	var semi := -1.0
	for nome in colture:
		if colture[nome] is Dictionary and risorse.get(colture[nome].semi, 0.0) > semi:
			semi = risorse[colture[nome].semi]
			migliore = nome
	return migliore


func cambia_coltura(id: int, nome: String) -> void:
	var b := trova(id)
	if b.is_empty() or not colture.has(nome) or b.get("coltura", "") == nome:
		return
	b.coltura = nome
	b.seminato = false
	changed.emit()


## Semina all'inizio della prima stagione della coltura (servono semi, tranne sulla zona
## selvatica), poi produce nelle sue stagioni.
func _lavora_campo(b: Dictionary, molt: float, cap: float, tps: float) -> void:
	var c := coltura_di(b)
	if c.is_empty():
		return
	var chiave: String = CHIAVI_STAGIONI[stagione]
	var attiva: bool = chiave in c.stagioni
	if not b.get("seminato", false):
		if chiave == c.stagioni[0] and tick_in_stagione < tps / 2.0 and b.lavoratori > 0:
			var selvatico := campo_selvatico(b)
			if selvatico or risorse[c.semi] >= float(c.semi_per_semina):
				if not selvatico:
					risorse[c.semi] -= float(c.semi_per_semina)
				b.seminato = true
				b.senza_semi = false
			elif not b.get("senza_semi", false):
				b.senza_semi = true
				message.emit("Il campo resta fermo: mancano %d semi di %s" % [int(c.semi_per_semina), c.nome.to_lower()])
		return
	if attiva and molt > 0.0:
		var extra := float(colture.bonus_selvatico) if campo_selvatico(b) else 1.0
		var r: String = c.risorsa
		risorse[r] = minf(cap, risorse[r] + float(c.resa) / tps * molt * extra * bonus_guida(r))


## Fine stagione: i campi arrivati all'ultima stagione della coltura raccolgono e tengono dei semi.
func _fine_colture() -> void:
	for b in buildings:
		var c := coltura_di(b)
		if c.is_empty() or not b.get("seminato", false):
			continue
		if CHIAVI_STAGIONI[stagione] == c.stagioni[c.stagioni.size() - 1]:
			b.seminato = false
			var quota := 1.0 if int(def_di(b).lavoratori) == 0 else float(b.lavoratori) / int(def_di(b).lavoratori)
			risorse[c.semi] = minf(capacita(), risorse[c.semi] + float(c.semi_al_raccolto) * quota)


func nomi_colture() -> Array:
	return colture.keys().filter(func(k): return colture[k] is Dictionary)


# --- Forestale ------------------------------------------------------------------

## Fine stagione: le piantine crescono (in un anno diventano bosco) e i forestali
## al lavoro piantano alberelli nelle radure e sui prati attorno.
func _lavora_forestali() -> void:
	if terreno == null:
		return
	var cambiate: Array = terreno.cresci_piantine()
	for b in buildings:
		var d := def_di(b)
		if not d.has("pianta") or b.progresso < 1.0 or b.lavoratori == 0:
			continue
		if float(d.get("stagioni", {}).get(CHIAVI_STAGIONI[stagione], 1.0)) <= 0.0:
			continue  # d'inverno non si pianta
		var quota := float(b.lavoratori) / int(d.lavoratori)
		var n := maxi(1, roundi(float(d.pianta) * quota * float(d.get("produzione", 1.0))))
		var t := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
		cambiate.append_array(terreno.pianta(b.cella, t, int(d.zona.raggio), n, int(bil.piantine.stagioni_per_crescere)))
	if not cambiate.is_empty():
		terreno_cambiato.emit(cambiate)


# --- Tende, senzatetto, piazza ------------------------------------------------------

## Le tende reggono una stagione: poi si strappano e vanno smontate.
func _consuma_tende() -> void:
	for b in buildings.duplicate():
		var durata := int(edifici[b.tipo].get("durata_stagioni", 0))
		if durata <= 0 or b.progresso < 1.0:
			continue
		b.eta = int(b.get("eta", 0)) + 1
		if b.eta >= durata:
			var chi := ""
			if int(b.get("famiglia", -1)) >= 0:
				chi = " dei " + famiglie[b.famiglia].casata
			if terreno:
				terreno.libera(b)
			buildings.erase(b)
			building_removed.emit(b.id)
			message.emit("La tenda%s è logora e va smontata: servono case vere" % chi)


func senza_casa() -> int:
	return maxi(0, abitanti - alloggi())


## Chi dorme all'aperto resta al massimo mezza stagione, poi se ne va.
func _controlla_senzatetto() -> void:
	var fuori := senza_casa()
	if fuori <= 0:
		tick_senza_casa = 0
		return
	tick_senza_casa += 1
	var limite := int(bil.senza_casa.tick_prima_di_andarsene)
	if tick_senza_casa == 1:
		message.emit("%d persone dormono all'aperto: se entro mezza stagione non hanno un tetto, se ne vanno" % fuori)
	elif tick_senza_casa >= limite:
		_togli_abitanti(fuori)
		tick_senza_casa = 0
		message.emit("%d persone senza casa hanno lasciato il villaggio" % fuori)


## Dopo il primo anno il falò diventa la piazza del borgo.
func _falo_diventa_piazza() -> void:
	for b in buildings:
		if b.tipo == "falo":
			building_removed.emit(b.id)
			b.tipo = "piazza"
			building_added.emit(b)
			message.emit("Un anno è passato: attorno al vecchio falò ora c'è la piazza del borgo")
			return


# --- Carte evento ----------------------------------------------------------------------

## A inizio stagione si decide se e quando arriverà una carta (una a stagione al massimo).
func _programma_evento() -> void:
	_tick_evento = -1
	if capo < 0 or dati_eventi.is_empty():
		return
	if _rng.randf() < float(dati_eventi.probabilita_per_stagione):
		var tps := int(bil.tick_per_stagione)
		_tick_evento = _rng.randi_range(tps / 6, tps * 2 / 3)


## Le carte che possono uscire adesso (stagione, edifici, anno, felicità; mai la stessa due volte
## finché non sono uscite tutte).
func carte_possibili() -> Array:
	var lista := []
	for carta in dati_eventi.get("carte", []):
		if carta.id in eventi_usati:
			continue
		if carta.has("stagioni") and not CHIAVI_STAGIONI[stagione] in carta.stagioni:
			continue
		if anno < int(carta.get("min_anno", 1)) or felicita < float(carta.get("min_felicita", 0)):
			continue
		var ok := true
		for tipo in carta.get("richiede", {}).get("edifici", []):
			if conta_completati(tipo) == 0:
				ok = false
		if ok:
			lista.append(carta)
	return lista


func _pesca_evento() -> void:
	_tick_evento = -1
	var lista := carte_possibili()
	if lista.is_empty() and not eventi_usati.is_empty():
		eventi_usati = []  # tutte uscite: il mazzo si rimescola
		lista = carte_possibili()
	if lista.is_empty():
		return
	mostra_evento(lista[_rng.randi_range(0, lista.size() - 1)])


## Mostra una carta: la racconta il consigliere della sua area (o l'altro), e il tempo si ferma
## finché non si sceglie.
func mostra_evento(carta: Dictionary) -> void:
	var narratore := -1
	for f in consiglieri():
		if narratore < 0 or tratto(f).get("area", "") == carta.area:
			narratore = f
	evento_attivo = carta.duplicate(true)
	evento_attivo.narratore = narratore
	eventi_usati.append(carta.id)
	if velocita > 0:
		_velocita_prima = velocita
	velocita = 0
	evento.emit(evento_attivo)
	changed.emit()


## Vero se le risorse bastano per questa scelta (le scelte che costano troppo sono disattivate).
func scelta_possibile(indice: int) -> bool:
	var scelte: Array = evento_attivo.get("scelte", [])
	if indice < 0 or indice >= scelte.size():
		return false
	var r: Dictionary = scelte[indice].effetti.get("risorse", {})
	for k in r:
		if float(r[k]) < 0.0 and risorse[k] < -float(r[k]):
			return false
	return true


func scegli_evento(indice: int) -> void:
	if evento_attivo.is_empty() or not scelta_possibile(indice):
		return
	var e: Dictionary = evento_attivo.scelte[indice].effetti
	var cap := capacita()
	var r: Dictionary = e.get("risorse", {})
	for k in r:
		risorse[k] = clampf(risorse[k] + float(r[k]), 0.0, maxf(cap, risorse[k]))
	if e.has("felicita"):
		felicita = clampf(felicita + float(e.felicita), 0.0, 100.0)
	var n := int(e.get("abitanti", 0))
	if n > 0:
		abitanti += n
	elif n < 0:
		_togli_abitanti(-n)
	if e.has("distruggi"):
		for b in buildings:
			if b.tipo == e.distruggi and b.progresso >= 1.0:
				if terreno:
					terreno.libera(b)
				buildings.erase(b)
				building_removed.emit(b.id)
				break
	if e.has("modificatore"):
		var m: Dictionary = e.modificatore.duplicate()
		m.stagioni = int(m.stagioni)
		modificatori.append(m)
	evento_attivo = {}
	velocita = maxi(1, _velocita_prima)
	if abitanti <= 0:
		_fine(false, "Il villaggio è rimasto vuoto.")
		return
	changed.emit()


## Prodotto dei modificatori attivi di un tipo ("edificio" con il tipo di edificio,
## "coltura", "riscaldamento", "tassa_re").
func molt_modificatore(chiave: String, tipo := "") -> float:
	var m := 1.0
	for mod in modificatori:
		if chiave == "edificio":
			if tipo != "" and mod.get("edificio", "") == tipo:
				m *= float(mod.molt)
		elif chiave == "coltura":
			if mod.has("coltura"):
				m *= float(mod.molt)
		elif mod.has(chiave):
			m *= float(mod[chiave])
	return m


func _scadono_modificatori() -> void:
	for mod in modificatori:
		mod.stagioni = int(mod.stagioni) - 1
	modificatori = modificatori.filter(func(mod): return int(mod.stagioni) > 0)


# --- Collegamento alla piazza ---------------------------------------------------------

## Vero se l'edificio è attaccato alla piazza (o alla dimora), oppure tocca una strada
## che ci arriva. Chi non è collegato lavora un po' peggio (malus in bilanciamento.strade).
func collegato(b: Dictionary) -> bool:
	if terreno == null:
		return true
	if edifici[b.tipo].get("centro", false):
		return true
	if not _rete_valida:
		_calcola_rete()
	for c in _bordo(b):
		if _rete_strade.has(c) or _centro_in(c):
			return true
	return false


func _calcola_rete() -> void:
	_rete_valida = true
	_rete_strade = {}
	var da_visitare: Array[Vector2i] = []
	for b in buildings:
		if edifici[b.tipo].get("centro", false):
			for c in _bordo(b):
				if terreno.strada_a(c) and not _rete_strade.has(c):
					_rete_strade[c] = true
					da_visitare.append(c)
	while not da_visitare.is_empty():
		var c: Vector2i = da_visitare.pop_back()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + dir
			if terreno.strada_a(v) and not _rete_strade.has(v):
				_rete_strade[v] = true
				da_visitare.append(v)


## Le celle che toccano i lati dell'edificio.
func _bordo(b: Dictionary) -> Array[Vector2i]:
	var t: Array = edifici[b.tipo].taglia
	var w := int(t[0])
	var h := int(t[1])
	var bordo: Array[Vector2i] = []
	for x in w:
		bordo.append(b.cella + Vector2i(x, -1))
		bordo.append(b.cella + Vector2i(x, h))
	for y in h:
		bordo.append(b.cella + Vector2i(-1, y))
		bordo.append(b.cella + Vector2i(w, y))
	return bordo


func _centro_in(c: Vector2i) -> bool:
	var id := terreno.edificio_a(c)
	if id < 0:
		return false
	var altro := trova(id)
	return not altro.is_empty() and edifici[altro.tipo].get("centro", false)


# --- Strade ---------------------------------------------------------------------

## Costo in pietra di una strada lungo queste celle (1 in piano, 2 in salita); -1 se non si può.
func costo_strada(celle: Array) -> int:
	if terreno == null:
		return -1
	return terreno.costo_strada(celle)


func costruisci_strada(celle: Array) -> bool:
	var costo := costo_strada(celle)
	if costo < 0 or risorse.pietra < costo:
		return false
	risorse.pietra -= costo
	var nuove := terreno.aggiungi_strada(celle)
	terreno_cambiato.emit(nuove)
	changed.emit()
	return true


func rimuovi_strada(cella: Vector2i) -> void:
	if terreno and terreno.rimuovi_strada(cella):
		terreno_cambiato.emit([cella])
		changed.emit()


# --- Mercato --------------------------------------------------------------------

func ha_mercato() -> bool:
	return conta_completati("mercato") > 0


func costo_lotto(r: String) -> int:
	return mercato.costo_lotto(r, stagione, ha_mercato())


func ricavo_lotto(r: String) -> int:
	return mercato.ricavo_lotto(r, stagione, ha_mercato())


func compra(r: String) -> bool:
	var costo := costo_lotto(r)
	if risorse.oro < costo or risorse[r] + mercato.lotto() > capacita():
		return false
	risorse.oro -= costo
	risorse[r] += mercato.lotto()
	mercato.saturazione[r] = int(mercato.saturazione.get(r, 0)) + 1
	changed.emit()
	return true


func vendi(r: String) -> bool:
	if risorse[r] < mercato.lotto():
		return false
	risorse[r] -= mercato.lotto()
	risorse.oro = minf(capacita(), risorse.oro + ricavo_lotto(r))
	mercato.saturazione[r] = int(mercato.saturazione.get(r, 0)) - 1
	changed.emit()
	return true


## Il raccoglitore vicino alle piante selvatiche porta a casa anche i loro semi.
func _raccogli_semi(b: Dictionary, molt: float, cap: float, tps: float) -> void:
	if terreno == null:
		return
	var d: Dictionary = edifici[b.tipo]
	var t := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
	var conteggio := terreno.selvatiche_attorno(b.cella, t, int(d.zona.raggio))
	for nome in conteggio:
		var semi: String = colture[nome].semi
		risorse[semi] = minf(cap, risorse[semi] + conteggio[nome] * float(colture.semi_raccolti_per_cella) / tps * molt)


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


## I taglialegna al lavoro abbattono una parte del bosco attorno: un bosco grande
## rende tanto, ma in "stagioni_per_esaurire" stagioni (3 anni) sparisce.
func _disbosca() -> void:
	if terreno == null:
		return
	var tagliate: Array = []
	for b in buildings:
		var d := def_di(b)
		if not d.get("disbosca", false) or b.progresso < 1.0 or b.lavoratori == 0:
			continue
		var iniziale := int(b.get("bosco_iniziale", 0))
		var per_stagione := maxi(1, ceili(float(iniziale) / float(bil.disboscamento.stagioni_per_esaurire)))
		var quota := float(b.lavoratori) / float(d.lavoratori)
		var taglia := Vector2i(int(d.taglia[0]), int(d.taglia[1]))
		tagliate.append_array(terreno.taglia_bosco(b.cella, taglia, int(d.zona.raggio), maxi(1, roundi(per_stagione * quota))))
	if not tagliate.is_empty():
		terreno_cambiato.emit(tagliate)


func _fine_stagione() -> void:
	_disbosca()
	_fine_colture()
	_lavora_forestali()
	_consuma_tende()
	_scadono_modificatori()
	if stagione == AUTUNNO:
		_riscuoti_tasse()
	if finita:
		return
	if abitanti <= 0:
		_fine(false, "Il villaggio è rimasto vuoto.")
		return

	stagione = (stagione + 1) % 4
	tick_in_stagione = 0
	if stagione == PRIMAVERA:
		anno += 1
		if anno == 1 + int(bil.piazza.dopo_anni):
			_falo_diventa_piazza()
	mercato.nuova_stagione(seme_mappa, anno, stagione)
	_programma_evento()
	if not mercato.evento.is_empty():
		message.emit("Dal mercato: " + mercato.evento.testo)
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


## Gente nuova arriva un po' alla volta, se c'è posto: più il villaggio è felice e
## pieno di scorte (e di legna prima dell'inverno), più è probabile che arrivi qualcuno.
func _arrivi() -> void:
	var c: Dictionary = bil.crescita
	attrattiva = calcola_attrattiva()
	var posti := alloggi() - abitanti
	if posti <= 0 or attrattiva <= 0.0:
		return
	if _rng.randf() < attrattiva * float(c.probabilita_massima):
		var n := _rng.randi_range(1, mini(int(c.massimo_per_volta), posti))
		abitanti += n
		message.emit("%s arrivat%s al villaggio: si parla bene di noi" % ["È" if n == 1 else "Sono", "a una persona" if n == 1 else "e %d persone" % n])


## 0..1: felicità sopra la soglia per abbondanza di scorte di cibo (e di legna d'inverno).
func calcola_attrattiva() -> float:
	var c: Dictionary = bil.crescita
	var consumo_stagione := maxf(1.0, abitanti * float(bil.cibo_per_abitante_tick) * float(bil.tick_per_stagione))
	var scorte := 0.0
	for r in CIBI:
		scorte += risorse[r]
	var abbondanza := clampf(scorte / consumo_stagione, 0.0, 2.0) / 2.0
	if stagione in [AUTUNNO, INVERNO] and risorse.legna < riscaldamento_invernale():
		abbondanza *= 0.5
	var soglia := float(c.soglia_arrivi)
	return clampf((felicita - soglia) / (100.0 - soglia), 0.0, 1.0) * abbondanza


## Legna che serve per scaldare tutto il villaggio per un inverno.
func riscaldamento_invernale() -> float:
	var totale := 0.0
	for b in buildings:
		if b.progresso >= 1.0:
			totale += float(def_di(b).get("riscaldamento", 0))
	return totale


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
			"famiglia": b.get("famiglia", -1), "livello": b.get("livello", 1),
			"bosco_iniziale": b.get("bosco_iniziale", 0),
			"coltura": b.get("coltura", ""), "seminato": b.get("seminato", false),
			"eta": b.get("eta", 0),
		})
	var dati := {
		"versione": VERSIONE_SALVATAGGIO, "famiglie": famiglie, "capo": capo, "risorse": risorse,
		"tagliati": Array(terreno.tagliati) if terreno else [],
		"terreno": terreno.salva() if terreno else {},
		"mercato": mercato.salva(), "abitanti": abitanti, "felicita": felicita,
		"stagione": stagione, "anno": anno, "tick_in_stagione": tick_in_stagione,
		"livello": livello, "tasse": tasse, "tasse_non_pagate": tasse_non_pagate,
		"seme_mappa": seme_mappa, "prossimo_id": _prossimo_id, "buildings": lista,
		"tick_senza_casa": tick_senza_casa, "modificatori": modificatori,
		"eventi_usati": eventi_usati, "tick_evento": _tick_evento,
		"evento_attivo": evento_attivo.get("id", ""),
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
	_tagli_da_applicare = dati.get("tagliati", [])
	_terreno_salvato = dati.get("terreno", {})
	mercato.carica(dati.get("mercato", {}))
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
		b.livello = int(x.get("livello", 1))
		if int(x.get("bosco_iniziale", 0)) > 0:
			b.bosco_iniziale = int(x.bosco_iniziale)
		if str(x.get("coltura", "")) != "":
			b.coltura = x.coltura
			b.seminato = bool(x.get("seminato", false))
		if int(edifici[b.tipo].get("durata_stagioni", 0)) > 0:
			b.eta = int(x.get("eta", 0))
		buildings.append(b)
	tick_senza_casa = int(dati.get("tick_senza_casa", 0))
	modificatori = dati.get("modificatori", [])
	eventi_usati = dati.get("eventi_usati", [])
	_tick_evento = int(dati.get("tick_evento", -1))
	# una carta lasciata a metà torna quando si rientra nel feudo (vedi riprendi_evento)
	_evento_da_riprendere = str(dati.get("evento_attivo", ""))
	return true


## Se la partita è stata chiusa con una carta aperta, la ripropone.
func riprendi_evento() -> void:
	if _evento_da_riprendere == "":
		return
	for carta in dati_eventi.get("carte", []):
		if carta.id == _evento_da_riprendere:
			eventi_usati.erase(carta.id)
			mostra_evento(carta)
	_evento_da_riprendere = ""


func cancella_salvataggio() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
