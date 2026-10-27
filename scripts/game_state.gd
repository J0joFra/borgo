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
signal evento(carta: Dictionary)
signal suggerimento(testo: String)          # un consiglio su come si gioca
signal tutorial_cambiato(passo: int)        # -1: tutorial finito o saltato
signal banditi_avvistati(dati: Dictionary)  # una banda è in arrivo (vedi banditi)
signal incursione(esito: Dictionary)        # la banda è arrivata: com'è andata
signal missione_finita(esito: Dictionary)   # una spia, un messaggero o l'esercito sono tornati
signal battaglia_iniziata(b: Dictionary)    # l'esercito è arrivato: si combatte sul campo a esagoni (scena battaglia)
signal battaglia_finita(esito: Dictionary)  # una carta evento da mostrare (il gioco è in pausa)
signal terreno_cambiato(celle: Array)  # celle cambiate: bosco abbattuto o ricresciuto, piantine, strade

const PRIMAVERA := 0
const ESTATE := 1
const AUTUNNO := 2
const INVERNO := 3
const STAGIONI := ["Primavera", "Estate", "Autunno", "Inverno"]
const CHIAVI_STAGIONI := ["primavera", "estate", "autunno", "inverno"]
const RISORSE := ["legna", "pietra", "cibo", "ferro", "utensili", "oro", "grano", "farina",
	"orzo", "rape", "semi_orzo", "semi_grano", "semi_rape", "armi"]
## Cosa si mangia, nell'ordine: prima il cibo pronto, poi le rape, l'orzo e per ultimo il grano (che serve al pane).
const CIBI := ["cibo", "rape", "orzo", "grano"]
## Le risorse mostrate nella barra in alto (grano e farina restano nascosti).
const RISORSE_VISIBILI := ["legna", "pietra", "cibo", "grano", "orzo", "rape", "ferro", "utensili", "armi", "oro"]
const SAVE_PATH := "user://save.json"
const VERSIONE_SALVATAGGIO := 9
const VERSIONE_MINIMA := 8  # i salvataggi da qui in poi si caricano ancora (i campi nuovi prendono un valore di base)

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
var _cinta := -1  # cinta_chiusa() in cache: -1 da ricalcolare, 0 no, 1 sì
var banditi: Dictionary = {}  # banda in arrivo: {forza, numero, entrata: Vector2i, mancano, totale} (tick)
var _tick_banditi := -1       # in quale tick della stagione vengono avvistati (-1: nessuno)
var ultime_tasse: Dictionary = {}  # l'ultima riscossione, per il pannello Info
var re_atteggiamento := 0     # cosa pensa di noi il re (-100..100): dal Borgo siamo indipendenti e lui diffida
var ultimo_affitto := 0       # tributo delle case all'ultima riscossione
var aiuto_inverno_dato := false  # il primo inverno, se finisce il cibo, il signore apre le dispense (una volta)
var tutorial_passo := -1         # passo del tutorial iniziale (-1: finito, saltato o mai iniziato)
var suggerimenti_attivi := true
## Opzioni del menu principale, valide per tutte le partite (user://opzioni.cfg).
var opzioni := {"tutorial": true, "suggerimenti": true, "schermo_intero": false, "musica": true, "effetti": true}
const OPZIONI_PATH := "user://opzioni.cfg"
var _prossimo_suggerimento := 0
var _tick_suggerimento := 0
var dati_tutorial: Array = []
var dati_suggerimenti: Array = []
var soldati := 0              # abitanti arruolati: non lavorano, difendono e possono attaccare
var regni: Dictionary = {}    # "indice regione" -> {forza, atteggiamento, spiato, alleato, conquistato, vassallo}
var missioni: Array = []      # {tipo: spia|alleanza|attacco, regione, mancano, soldati}
var battaglia: Dictionary = {}  # la battaglia in corso (vedi _battaglia), {} se nessuna
## Le impostazioni dell'ultima battaglia di prova (menu → Prova battaglia): non toccano la partita.
var prova_battaglia := {"nemico": "signore", "soldati": 20, "armi": 10, "vassalli": 5, "nemici": 25}

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
	_carica_opzioni()
	var guida: Dictionary = (load("res://data/tutorial.json") as JSON).data
	dati_tutorial = guida.passi
	dati_suggerimenti = guida.suggerimenti
	building_added.connect(func(_b): _rete_valida = false)
	building_removed.connect(func(_id): _rete_valida = false)
	terreno_cambiato.connect(func(_c): _rete_valida = false; _cinta = -1)
	building_added.connect(func(_b): _cinta = -1)
	building_removed.connect(func(_id): _cinta = -1)


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
## l'inizio del borgo. Parte dal vertice a metà del lato della dimora e va dritta.
func _strada_iniziale(dimora: Dictionary, falo: Dictionary) -> void:
	var lunghezza := int(bil.strade.strada_iniziale)
	var t := taglia_di(dimora)
	var lontano := Vector2(dimora.cella - falo.cella).normalized()
	var direzioni := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	direzioni.sort_custom(func(a, b): return Vector2(a).dot(lontano) > Vector2(b).dot(lontano))
	for dir in direzioni:
		var inizio: Vector2i = dimora.cella
		match dir:
			Vector2i(1, 0): inizio += Vector2i(t.x, t.y / 2)
			Vector2i(-1, 0): inizio += Vector2i(0, t.y / 2)
			Vector2i(0, 1): inizio += Vector2i(t.x / 2, t.y)
			_: inizio += Vector2i(t.x / 2, 0)
		var vertici := []
		for i in lunghezza + 1:
			vertici.append(inizio + dir * i)
		var v := terreno.verifica_strada(vertici)
		if v.ok and v.ponti == 0 and v.passerelle == 0:
			terreno_cambiato.emit(terreno.aggiungi_strada(vertici))
			return


func consiglieri() -> Array[int]:
	var lista: Array[int] = []
	for i in famiglie.size():
		if i != capo and not famiglie[i].get("ribelle", false):
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
	_cinta = -1
	banditi = {}
	_tick_banditi = -1
	ultime_tasse = {}
	aiuto_inverno_dato = false
	re_atteggiamento = 0
	ultimo_affitto = 0
	tutorial_passo = -1
	_prossimo_suggerimento = 0
	soldati = 0
	missioni = []
	battaglia = {}
	regni = {}
	_prepara_regni()
	attrattiva = 0.0
	mercato = Mercato.new(seme_mappa)
	_scegli_famiglie()
	buildings = []
	finita = false
	terreno = null
	_prossimo_id = 1
	_accumulo = 0.0


## Larghezza e profondità (in celle) di un tipo di edificio girato di rot volte 90°.
func taglia_tipo(tipo: String, rot := 0) -> Vector2i:
	var t: Array = edifici[tipo].taglia
	var taglia := Vector2i(int(t[0]), int(t[1]))
	return Vector2i(taglia.y, taglia.x) if posmod(rot, 2) == 1 else taglia


func taglia_di(b: Dictionary) -> Vector2i:
	return taglia_tipo(b.tipo, int(b.get("rot", 0)))


## Aggiunge un edificio già pronto, senza costi (case iniziali).
func aggiungi_gratis(tipo: String, cella: Vector2i, bonus: float) -> Dictionary:
	var b := _aggiungi(tipo, cella, bonus, 1.0)
	_segna_eta(b)
	_arma_torre(b)
	return b


## Appena finita, sulla torre di guardia salgono i suoi arcieri: non si tolgono, ma possono morire.
func _arma_torre(b: Dictionary) -> void:
	if edifici[b.tipo].has("arcieri"):
		b.arcieri = int(edifici[b.tipo].arcieri)
		_cinta = -1


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
	var testo := "Resa: %s %s · %s" % [", ".join(parti), quando, info.testo]
	if d.has("selvatiche"):
		var finta := {"tipo": tipo, "cella": cella}
		var sel := selvatica_di_stagione(finta)
		if sel != "":
			testo += " · ora 2 raccolti su 3 sono %s selvatico" % colture[sel].nome.to_lower()
		else:
			var vicine := terreno.selvatiche_attorno(cella, Vector2i(int(d.taglia[0]), int(d.taglia[1])), int(d.zona.raggio))
			var nomi: Array[String] = []
			for nome in vicine:
				if int(vicine[nome]) >= int(d.selvatiche.minimo_celle):
					nomi.append("%s (%s)" % [colture[nome].nome.to_lower(), " e ".join(colture[nome].stagioni)])
			if not nomi.is_empty():
				testo += " · qui cresce %s: lo raccoglie nella sua stagione" % ", ".join(nomi)
	return testo


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


func piazza(tipo: String, cella: Vector2i, bonus: float, rot := 0) -> Dictionary:
	if not sbloccato(tipo) or not puo_permettersi(tipo):
		return {}
	var costo: Dictionary = edifici[tipo].get("costo", {})
	for r in costo:
		risorse[r] -= costo[r]
	var b := _aggiungi(tipo, cella, bonus, 0.0, rot)
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


func _aggiungi(tipo: String, cella: Vector2i, bonus: float, progresso: float, rot := 0) -> Dictionary:
	var b := {
		"id": _prossimo_id, "tipo": tipo, "cella": cella,
		"lavoratori": 0, "progresso": progresso, "bonus": bonus,
	}
	if posmod(rot, 4) != 0:
		b.rot = posmod(rot, 4)
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
	_arma_torre(b)
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
	return maxi(0, abitanti - lavoratori_assegnati() - soldati)


func conta_completati(tipo: String) -> int:
	var n := 0
	for b in buildings:
		if b.tipo == tipo and b.progresso >= 1.0:
			n += 1
	return n


## Dal Borgo in poi il feudo è indipendente: niente più tasse al re (che però diffida di noi).
func indipendente() -> bool:
	return livello >= int(bil.re.indipendenza_dal_livello)


## Le stagioni che mancano alla riscossione del re (in autunno): 0 se è questa.
func stagioni_al_re() -> int:
	return posmod(AUTUNNO - stagione, 4)


## Il tributo delle case: ogni casa abitata paga ogni stagione secondo quanta gente può ospitare
## (bilanciamento.tributo_case: fino a 4 posti 1 moneta, fino a 6 2, fino a 8 3).
## Le case si riempiono una dopo l'altra; tende, dimora e caserma non pagano.
func tributo_case() -> int:
	var restano := abitanti
	var totale := 0
	for b in buildings:
		if b.progresso < 1.0:
			continue
		var posti := int(def_di(b).get("alloggi", 0))
		if posti <= 0:
			continue
		var dentro := mini(posti, restano)
		restano -= dentro
		if b.tipo != "casa" or dentro <= 0:
			continue
		for fascia in bil.tributo_case:
			if posti <= int(fascia[0]):
				totale += int(fascia[1])
				break
	return totale


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
	if d.has("arcieri"):
		parti.append("%d arcieri, tirano a %d celle" % [int(d.arcieri), int(d.raggio_tiro)])
	if d.has("difesa"):
		parti.append("difesa +%s" % str(d.difesa))
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
		var selvatica := selvatica_di_stagione(b)
		for r in produce:
			var quanto: float = produce[r] / tps * molt
			if selvatica != "" and r == "cibo":
				# vicino alle piante selvatiche nella loro stagione: su 3 raccolti, 2 sono di quella pianta
				var quota := float(d.selvatiche.quota)
				var c_r: String = colture[selvatica].risorsa
				risorse[c_r] = minf(cap, risorse[c_r] + quanto * quota * bonus_guida(c_r))
				quanto *= 1.0 - quota
			risorse[r] = minf(cap, risorse[r] + quanto * bonus_guida(r))
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
	if _fame and anno == 1 and stagione == INVERNO and not aiuto_inverno_dato:
		_aiuto_primo_inverno()
	# Con la fame la felicità scende piano (vedi fattori) e ogni tanto qualcuno se ne va
	# (ma non il primo anno: il signore tiene tutti nel suo castello).
	if _fame:
		tick_fame += 1
		if tick_fame % int(c.fame_partenza_ogni) == 0 and anno > 1:
			_togli_abitanti(1)
			message.emit("Una persona se n'è andata: qui si patisce la fame")
	else:
		tick_fame = 0
	if felicita < float(c.soglia_partenze):
		_tick_scontento += 1
		if _tick_scontento % int(c.scontenti_partenza_ogni) == 0 and anno > 1:
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
	var mese := int(bil.tick_per_stagione) / int(bil.esercito.mesi_per_stagione)
	if tick_in_stagione % mese == 0:
		_paga_soldati()
	_avanza_missioni()
	if tick_in_stagione == _tick_banditi:
		_avvista_banditi()
	elif not banditi.is_empty():
		banditi.mancano = int(banditi.mancano) - 1
		_tiro_arcieri()
		if not banditi.is_empty() and banditi.mancano <= 0:
			_incursione()
			if finita:
				return
	if tick_in_stagione >= tps:
		_fine_stagione()
	_controlla_tutorial()
	if suggerimenti_attivi and capo >= 0 and tutorial_passo < 0:
		_tick_suggerimento += 1
		if _tick_suggerimento >= int(bil.suggerimenti.ogni) * (1 if anno <= 2 else 2):
			_tick_suggerimento = 0
			_dai_suggerimento()
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
	return terreno.selvatica_sotto(b.cella, taglia_di(b)) == b.get("coltura", "")


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


# --- Tutorial e suggerimenti ------------------------------------------------------------

func _carica_opzioni() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(OPZIONI_PATH) == OK:
		for k in opzioni:
			opzioni[k] = bool(cfg.get_value("opzioni", k, opzioni[k]))
	suggerimenti_attivi = opzioni.suggerimenti
	_applica_schermo()


func imposta_opzione(chiave: String, valore: bool) -> void:
	opzioni[chiave] = valore
	if chiave == "suggerimenti":
		suggerimenti_attivi = valore
	if chiave == "musica":
		Audio.aggiorna_musica()
	_applica_schermo()
	var cfg := ConfigFile.new()
	for k in opzioni:
		cfg.set_value("opzioni", k, opzioni[k])
	cfg.save(OPZIONI_PATH)


func _applica_schermo() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var voluta := DisplayServer.WINDOW_MODE_FULLSCREEN if opzioni.schermo_intero else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != voluta and (opzioni.schermo_intero or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
		DisplayServer.window_set_mode(voluta)


## Il tutorial comincia dopo il prologo, nelle partite nuove.
func inizia_tutorial() -> void:
	tutorial_passo = 0
	tutorial_cambiato.emit(tutorial_passo)


func salta_tutorial() -> void:
	tutorial_passo = -1
	tutorial_cambiato.emit(tutorial_passo)
	salva()


## "Avanti" sui passi che non aspettano un'azione.
func avanti_tutorial() -> void:
	if tutorial_passo >= 0 and dati_tutorial[tutorial_passo].get("condizione", "") == "":
		_passo_tutorial_fatto()


func _passo_tutorial_fatto() -> void:
	tutorial_passo += 1
	if tutorial_passo >= dati_tutorial.size():
		tutorial_passo = -1
	tutorial_cambiato.emit(tutorial_passo)


func _controlla_tutorial() -> void:
	if tutorial_passo < 0:
		return
	var cond: String = dati_tutorial[tutorial_passo].get("condizione", "")
	if cond != "" and condizione_tutorial(cond):
		var fatto: String = dati_tutorial[tutorial_passo].titolo
		_passo_tutorial_fatto()
		message.emit("Fatto: %s!" % fatto.to_lower())


## Le condizioni dei passi del tutorial (data/tutorial.json).
func condizione_tutorial(cond: String) -> bool:
	match cond:
		"lavora":
			for b in buildings:
				if b.progresso >= 1.0 and b.tipo in ["taglialegna", "raccoglitore"] and b.lavoratori > 0:
					return true
			return false
		"collegati":
			var lavoro := 0
			for b in buildings:
				if b.progresso >= 1.0 and int(def_di(b).lavoratori) > 0:
					lavoro += 1
					if not collegato(b):
						return false
			return lavoro > 0
		_:
			if cond.begins_with("edificio:"):
				var tipo := cond.substr(9)
				for b in buildings:
					if b.tipo == tipo:
						return true
	return false


## Ogni tanto un consiglio su come si gioca, a turno (data/tutorial.json, "suggerimenti").
func _dai_suggerimento() -> void:
	if dati_suggerimenti.is_empty() or not evento_attivo.is_empty():
		return
	suggerimento.emit(dati_suggerimenti[_prossimo_suggerimento % dati_suggerimenti.size()])
	_prossimo_suggerimento += 1


# --- Carte evento ----------------------------------------------------------------------

## Il primo inverno, se il cibo finisce, la guida raduna tutti nel castello e apre le dispense:
## 50 di cibo, una volta sola. Per tutto il primo anno nessuno se ne va per la fame.
func _aiuto_primo_inverno() -> void:
	aiuto_inverno_dato = true
	var c: Dictionary = bil.primo_inverno
	risorse.cibo += float(c.cibo)
	_fame = false
	tick_fame = 0
	mostra_evento({"id": "aiuto_inverno", "area": "", "narratore": capo,
		"titolo": "Le porte del castello si aprono",
		"testo": "Il cibo è finito e la neve è alta. Apro le porte del mio castello a tutte le famiglie: dormiremo vicini al fuoco e divideremo le scorte della mia dispensa, %d di cibo. Quest'inverno nessuno se ne andrà." % int(c.cibo),
		"scelte": [{"testo": "Grazie, mio signore", "effetti": {}}]})


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
		# niente carte in cui non si può scegliere niente
		if ok and carta.scelte.any(func(sc): return _effetti_possibili(sc.effetti)):
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
	var narratore := int(carta.get("narratore", -1))
	if not carta.has("narratore"):
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
	return _effetti_possibili(scelte[indice].effetti)


func _effetti_possibili(effetti: Dictionary) -> bool:
	var r: Dictionary = effetti.get("risorse", {})
	for k in r:
		if float(r[k]) < 0.0 and risorse[k] < -float(r[k]):
			return false
	return true


## Vero se nella carta aperta non si può scegliere niente (le risorse sono cambiate): allora
## si chiude senza effetti con scegli_evento(-1).
func evento_senza_scelta() -> bool:
	var scelte: Array = evento_attivo.get("scelte", [])
	for i in scelte.size():
		if scelta_possibile(i):
			return false
	return true


func scegli_evento(indice: int) -> void:
	if evento_attivo.is_empty():
		return
	if indice == -1 and evento_senza_scelta():
		evento_attivo = {}
		velocita = maxi(1, _velocita_prima)
		changed.emit()
		return
	if not scelta_possibile(indice):
		return
	var e: Dictionary = evento_attivo.scelte[indice].effetti
	var cap := capacita()
	var r: Dictionary = e.get("risorse", {})
	for k in r:
		risorse[k] = clampf(risorse[k] + float(r[k]), 0.0, maxf(cap, risorse[k]))
	if e.has("felicita"):
		felicita = clampf(felicita + float(e.felicita), 0.0, 100.0)
	if e.has("re"):
		re_atteggiamento = clampi(re_atteggiamento + int(e.re), -100, 100)
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


# --- Banditi e difese -----------------------------------------------------------------

## I banditi arrivano dal Borgo in poi (o comunque dal terzo anno): più passano gli anni, più spesso.
func banditi_possibili() -> bool:
	var c: Dictionary = bil.banditi
	return capo >= 0 and (livello >= int(c.dal_livello) or anno >= int(c.dall_anno))


func _programma_banditi() -> void:
	_tick_banditi = -1
	if not banditi_possibili() or not banditi.is_empty():
		return
	var c: Dictionary = bil.banditi
	var p := minf(float(c.probabilita_massima), float(c.probabilita) + float(c.in_piu_per_anno) * (anno - 1))
	for k in regni:
		if regni[k].conquistato and regni[k].tipo == "banditi":
			p *= float(bil.diplomazia.banditi_dopo_conquista)  # meno covi di banditi attorno
	if _rng.randf() < p:
		var tps := int(bil.tick_per_stagione)
		_tick_banditi = _rng.randi_range(tps / 10, tps / 2)


## Una banda è avvistata al confine: arriva tra qualche giorno (di più se una torre di guardia
## la vede prima). La forza cresce con gli anni e con l'oro che abbiamo.
func _avvista_banditi() -> void:
	_tick_banditi = -1
	var c: Dictionary = bil.banditi
	var forza: float = (float(c.forza_base) + float(c.forza_per_anno) * (anno - 1) + risorse.oro / float(c.oro_per_forza))
	forza *= _rng.randf_range(1.0 - float(c.variazione), 1.0 + float(c.variazione))
	var avvistati_prima := false
	for b in buildings:
		if b.progresso >= 1.0 and edifici[b.tipo].get("avvista", false) and int(b.get("arcieri", 0)) > 0:
			avvistati_prima = true
	var preavviso := int(c.preavviso_con_torre if avvistati_prima else c.preavviso)
	var lati := ["nord", "est", "sud", "ovest"]
	var lato := 0
	var entrata := Vector2i.ZERO
	var f := TerrenoFeudo.FEUDO
	# entrano da un punto del confine sulla terra (non dal lago o dal fiume)
	for prova in 30:
		lato = _rng.randi_range(0, 3)
		var lungo := _rng.randi_range(4, f.size.x - 5)
		entrata = [Vector2i(f.position.x + lungo, f.position.y), Vector2i(f.end.x - 1, f.position.y + lungo),
			Vector2i(f.position.x + lungo, f.end.y - 1), Vector2i(f.position.x, f.position.y + lungo)][lato]
		if terreno == null or terreno.percorribile(entrata):
			break
	banditi = {"forza": forza, "numero": clampi(roundi(forza / 3.0), 4, 14), "entrata": entrata,
		"mancano": preavviso, "totale": preavviso, "da": lati[lato], "percorso": []}
	# la strada che faranno, a piedi attorno all'acqua e alle mura
	if terreno:
		banditi.percorso = terreno.cammino(entrata, _cella_centro())
	var chi := _consigliere_per("costruire")
	var testo := "Banditi avvistati a %s! Saranno qui tra %d giorni. Sono circa %d (forza %d); noi ci difendiamo con %d." % [
		banditi.da, preavviso, banditi.numero, roundi(forza), roundi(difesa().totale)]
	if chi >= 0:
		consiglio.emit(chi, testo)
	else:
		message.emit(testo)
	banditi_avvistati.emit(banditi)
	changed.emit()


func _consigliere_per(area: String) -> int:
	var scelto := -1
	for f in consiglieri():
		if scelto < 0 or tratto(f).get("area", "") == area:
			scelto = f
	return scelto


## Quanto sa difendersi il villaggio: tutti danno una mano (milizia), le guardie nelle torri
## valgono molto di più (e ancora di più con le armi), le palizzate fermano i banditi.
func difesa() -> Dictionary:
	var c: Dictionary = bil.banditi
	var arcieri := 0
	var forza_arcieri := 0.0
	var palizzate := 0.0
	var centro := _cella_centro()
	for b in buildings:
		if b.progresso < 1.0:
			continue
		var d := def_di(b)
		# gli arcieri combattono solo se il centro del borgo è nel loro raggio di tiro
		if d.has("difesa_per_arciere") and in_tiro(b, centro):
			arcieri += int(b.get("arcieri", 0))
			forza_arcieri += int(b.get("arcieri", 0)) * float(d.difesa_per_arciere)
		palizzate += float(d.get("difesa", 0.0))
	var armate := mini(arcieri, int(risorse.armi))
	if arcieri > 0:
		forza_arcieri *= 1.0 + (float(c.bonus_armi) - 1.0) * armate / arcieri
	# poi si armano i soldati rimasti a casa, e le armi avanzate vanno alla milizia
	var presenti := soldati_presenti()
	var armi_soldati := mini(presenti, int(risorse.armi) - armate)
	var forza_soldati := presenti * float(bil.esercito.difesa_per_soldato)
	if presenti > 0:
		forza_soldati *= 1.0 + (float(c.bonus_armi) - 1.0) * armi_soldati / presenti
	var civili := maxi(0, abitanti - soldati)
	var armi_milizia := mini(int(risorse.armi) - armate - armi_soldati, civili)
	var milizia := civili * float(c.milizia_per_abitante) + armi_milizia * 0.5
	var alleati := 0.0
	var vassalli := 0.0
	for k in regni:
		if regni[k].alleato:
			alleati += float(bil.diplomazia.aiuto_alleato)
		if regni[k].conquistato:
			vassalli += leva_vassallo(k)
	var mura := 0.0
	if terreno:
		mura = terreno.mura.size() * float(bil.mura.difesa_per_cella)
	var somma := milizia + forza_arcieri + palizzate + forza_soldati + alleati + vassalli + mura
	var cinta := cinta_chiusa()
	if cinta:
		somma *= 1.0 + float(bil.mura.bonus_cinta)
	return {"milizia": milizia, "arcieri": arcieri, "forza_arcieri": forza_arcieri, "palizzate": palizzate,
		"soldati": presenti, "forza_soldati": forza_soldati, "alleati": alleati, "vassalli": vassalli,
		"mura": mura, "cinta": cinta, "armi_usate": armate + armi_soldati + armi_milizia, "totale": somma}


## La cella è entro il raggio di tiro della torre (raggio_tiro celle per lato attorno all'edificio)?
func in_tiro(torre: Dictionary, c: Vector2i) -> bool:
	var r := int(edifici[torre.tipo].get("raggio_tiro", 0))
	var t := taglia_di(torre)
	return c.x >= torre.cella.x - r and c.x < torre.cella.x + t.x + r \
		and c.y >= torre.cella.y - r and c.y < torre.cella.y + t.y + r


## Ogni giorno in cui la banda passa nel raggio di una torre, gli arcieri tirano: la banda
## perde forza. Gli arcieri della banda rispondono e ogni tanto uccidono un arciere sulla torre.
func _tiro_arcieri() -> void:
	var percorso: Array = banditi.get("percorso", [])
	if percorso.is_empty():
		return
	var a: Dictionary = bil.arcieri
	var fatto := 1.0 - float(banditi.mancano) / float(banditi.totale)
	var dove: Vector2i = percorso[clampi(int(fatto * (percorso.size() - 1)), 0, percorso.size() - 1)]
	for b in buildings:
		var n := int(b.get("arcieri", 0))
		if n <= 0 or b.progresso < 1.0 or not in_tiro(b, dove):
			continue
		var colpi := n * float(a.danno_per_tiro)
		banditi.forza = maxf(0.0, float(banditi.forza) - colpi)
		banditi.colpiti = float(banditi.get("colpiti", 0.0)) + colpi
		var loro_arcieri := ceili(banditi_vivi() * float(a.quota_arcieri_banditi))
		if _rng.randf() < minf(0.5, loro_arcieri * float(a.probabilita_colpo)):
			b.arcieri = n - 1
			message.emit("Un arciere della torre è stato colpito dai banditi")
	if float(banditi.forza) <= 0.0:
		_incursione()


## Quanti banditi sono ancora in piedi (per la grafica): uno ogni 3 di forza.
func banditi_vivi() -> int:
	if banditi.is_empty():
		return 0
	return clampi(ceili(float(banditi.forza) / 3.0), 0, int(banditi.numero))


## A ogni stagione sulle torri che hanno perso arcieri ne sale uno nuovo.
func _nuovi_arcieri() -> void:
	for b in buildings:
		var massimo := int(edifici[b.tipo].get("arcieri", 0))
		if massimo > 0 and b.progresso >= 1.0 and int(b.get("arcieri", 0)) < massimo:
			b.arcieri = mini(massimo, int(b.get("arcieri", 0)) + int(bil.arcieri.nuovi_per_stagione))
			message.emit("Un nuovo arciere è salito sulla torre di guardia")


## La banda arriva. Se la difesa basta la respingiamo; altrimenti rubano una parte delle scorte
## (tanto più quanto eravamo deboli), qualcuno ci lascia la pelle e, se eravamo molto deboli,
## danno fuoco a una casa.
func _incursione() -> void:
	var c: Dictionary = bil.banditi
	var dif := difesa()
	var forza := float(banditi.forza)
	var rapporto: float = dif.totale / maxf(1.0, forza)
	var esito := {"vinto": rapporto >= 1.0, "entrata": banditi.entrata, "numero": banditi.numero,
		"forza": forza, "difesa": dif.totale, "rubato": {}, "bruciato": -1, "morti": 0,
		"colpiti": float(banditi.get("colpiti", 0.0)), "fuggiti": forza <= 0.0}
	# le armi si consumano un po' in battaglia (una su tre)
	risorse.armi = maxf(0.0, risorse.armi - ceilf(dif.armi_usate / 3.0))
	if banditi.get("regio", false):
		esito.regio = true
		# il re rispetta chi gli resiste, e si prende la sua parte da chi perde
		re_atteggiamento = clampi(re_atteggiamento + (30 if esito.vinto else 15), -100, 100)
		_racconta("costruire", "Abbiamo respinto l'esercito del re: ora ci rispetta un po' di più." if esito.vinto \
			else "L'esercito del re ci ha battuti e si è preso la sua parte. Almeno per un po' ci lascerà stare.")
	if esito.fuggiti:
		felicita = minf(100.0, felicita + float(c.felicita_vittoria))
		message.emit("Gli arcieri delle torri hanno messo in fuga i banditi prima che arrivassero!")
	elif esito.vinto:
		felicita = minf(100.0, felicita + float(c.felicita_vittoria))
		var frecce := " (gli arcieri ne avevano già colpiti molti)" if esito.colpiti >= 3.0 else ""
		message.emit("Banditi respinti! %d contro %d: la gente festeggia%s" % [roundi(dif.totale), roundi(forza), frecce])
	else:
		var quota: float = float(c.bottino_massimo) * (1.0 - rapporto)
		for r in ["oro", "cibo", "rape", "orzo", "grano", "farina", "legna", "pietra", "ferro", "utensili", "armi"]:
			var tolto := floorf(risorse[r] * quota)
			if tolto >= 1.0:
				risorse[r] -= tolto
				esito.rubato[r] = int(tolto)
		felicita = maxf(0.0, felicita + float(c.felicita_sconfitta))
		esito.morti = mini(abitanti - 1, roundi((1.0 - rapporto) * 3.0))
		if esito.morti > 0:
			_togli_abitanti(esito.morti)
		if rapporto < float(c.incendio_sotto):
			esito.bruciato = _brucia_qualcosa()
		var parti: Array[String] = []
		for r in esito.rubato:
			parti.append("%d %s" % [esito.rubato[r], r])
		message.emit("I banditi hanno saccheggiato il villaggio: %s%s" % [", ".join(parti) if not parti.is_empty() else "poco o niente",
			", e hanno dato fuoco a un edificio" if esito.bruciato >= 0 else ""])
	banditi = {}
	incursione.emit(esito)
	changed.emit()
	if abitanti <= 0:
		_fine(false, "I banditi hanno distrutto il villaggio.")


## Un edificio 2×2 qualunque (non il centro) va a fuoco e restano le rovine, da sgomberare.
func _brucia_qualcosa() -> int:
	var candidati := []
	for b in buildings:
		var d: Dictionary = edifici[b.tipo]
		if b.progresso >= 1.0 and not d.get("fisso", false) and not d.get("centro", false) \
				and taglia_di(b) == taglia_tipo("rovine") and b.tipo != "rovine":
			candidati.append(b)
	if candidati.is_empty():
		return -1
	var b: Dictionary = candidati[_rng.randi_range(0, candidati.size() - 1)]
	building_removed.emit(b.id)
	b.tipo = "rovine"
	b.lavoratori = 0
	b.livello = 1
	b.erase("coltura")
	b.erase("eta")
	building_added.emit(b)
	return b.id


# --- Esercito ------------------------------------------------------------------------

## Si arruola una formazione alla volta (bilanciamento.esercito.per_formazione persone), prese fra
## chi non lavora. Ogni caserma ne ospita alcune. Ogni formazione mangia del cibo ogni mese.
func formazioni() -> int:
	return ceili(soldati / float(bil.esercito.per_formazione))


func formazioni_massime() -> int:
	var n := 0
	for b in buildings:
		if b.progresso >= 1.0:
			n += int(def_di(b).get("formazioni", 0))
	return n


func soldati_in_marcia() -> int:
	var n := 0
	for m in missioni:
		n += int(m.get("soldati", 0))
	if not battaglia.is_empty() and not battaglia.finita:
		n += LogicaBattaglia.superstiti(battaglia, "noi", ["fanti", "arcieri"])
	return n


func soldati_presenti() -> int:
	return maxi(0, soldati - soldati_in_marcia())


## "" se si può arruolare, altrimenti il perché.
func perche_non_arruolare() -> String:
	if formazioni_massime() == 0:
		return "serve una caserma"
	if formazioni() >= formazioni_massime():
		return "le caserme sono piene"
	if disoccupati() < int(bil.esercito.per_formazione):
		return "servono %d persone senza lavoro" % int(bil.esercito.per_formazione)
	return ""


func arruola() -> bool:
	if perche_non_arruolare() != "":
		return false
	soldati += int(bil.esercito.per_formazione)
	message.emit("Una nuova formazione di %d soldati: mangia %d cibo al mese" % [int(bil.esercito.per_formazione), int(bil.esercito.cibo_al_mese)])
	changed.emit()
	return true


func congeda() -> bool:
	if soldati_presenti() < int(bil.esercito.per_formazione):
		return false
	soldati -= int(bil.esercito.per_formazione)
	changed.emit()
	return true


func cibo_esercito_al_mese() -> int:
	return formazioni() * int(bil.esercito.cibo_al_mese)


## A ogni mese le formazioni si mangiano la loro razione; se il cibo non basta, una formazione se ne torna a casa.
func _paga_soldati() -> void:
	var serve := float(cibo_esercito_al_mese())
	if serve <= 0.0:
		return
	var preso := 0.0
	for r in CIBI:
		var x := minf(risorse[r], serve - preso)
		risorse[r] -= x
		preso += x
	if preso + 0.001 < serve and soldati_presenti() > 0:
		soldati -= mini(int(bil.esercito.per_formazione), soldati_presenti())
		message.emit("Senza cibo una formazione di soldati ha lasciato l'esercito")


# --- Regni vicini: spie, alleanze, guerra --------------------------------------------

## Lo stato delle altre regioni della mappa, dal seme della partita: forza dell'esercito,
## atteggiamento verso di noi (-100 ostile .. 100 amico), cosa sappiamo di loro.
func _prepara_regni() -> void:
	var g := Regioni.genera(seme_mappa)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme_mappa + 51
	var f: Dictionary = bil.diplomazia.forza
	for i in g.regioni.size():
		var r: Dictionary = g.regioni[i]
		if r.tipo == "mia":
			continue
		var intervallo: Array = f[r.tipo]
		var atteggiamento := 0
		match r.tipo:
			"signore":
				atteggiamento = rng.randi_range(-30, 40)
			"banditi":
				atteggiamento = -80
		regni[str(i)] = {"tipo": r.tipo, "nome": r.nome, "signore": r.signore, "risorsa": r.risorsa,
			"forza": rng.randi_range(int(intervallo[0]), int(intervallo[1])), "atteggiamento": atteggiamento,
			"spiato": false, "alleato": false, "conquistato": false, "vassallo": -1, "lealta": 0, "tributo": "normale"}


func diplomazia_possibile() -> bool:
	return livello >= int(bil.diplomazia.dal_livello)


## La forza di un regno adesso: cresce un po' ogni anno.
func forza_regno(chiave: String) -> int:
	return roundi(float(regni[chiave].forza) * (1.0 + float(bil.diplomazia.crescita_forza_per_anno) * (anno - 1)))


## La forza in battaglia di n soldati (con le armi), più le truppe mandate dai vassalli.
func forza_esercito(n: int) -> float:
	var armati := mini(n, int(risorse.armi))
	var f := n * float(bil.esercito.forza_per_soldato) * (1.0 + (float(bil.banditi.bonus_armi) - 1.0) * armati / maxf(1.0, n))
	if n > 0:
		for k in regni:
			if regni[k].conquistato:
				f += leva_vassallo(k)
	return f


func missione_per(chiave: String) -> Dictionary:
	for m in missioni:
		if m.regione == chiave:
			return m
	return {}


## "" se l'azione si può fare su quel regno, altrimenti il perché.
func perche_no(azione: String, chiave: String) -> String:
	if not diplomazia_possibile():
		return "si può dal Borgo in poi"
	var r: Dictionary = regni[chiave]
	if r.conquistato:
		return "è già nostro"
	if not missione_per(chiave).is_empty():
		return "c'è già qualcuno in viaggio"
	var d: Dictionary = bil.diplomazia
	match azione:
		"spia":
			if risorse.oro < float(d.costo_spia):
				return "servono %d oro" % int(d.costo_spia)
		"alleanza":
			if r.tipo != "signore":
				return "lì non c'è un signore con cui trattare"
			if r.alleato:
				return "siamo già alleati"
			if risorse.oro < float(d.dono_alleanza):
				return "servono %d oro per il dono" % int(d.dono_alleanza)
		"attacco":
			if r.alleato:
				return "sono nostri alleati"
			if soldati_presenti() <= 0:
				return "serve un esercito (arruola soldati in caserma)"
	return ""


func manda_spia(chiave: String) -> bool:
	if perche_no("spia", chiave) != "":
		return false
	risorse.oro -= float(bil.diplomazia.costo_spia)
	missioni.append({"tipo": "spia", "regione": chiave, "mancano": int(bil.diplomazia.giorni_spia)})
	changed.emit()
	return true


func proponi_alleanza(chiave: String) -> bool:
	if perche_no("alleanza", chiave) != "":
		return false
	risorse.oro -= float(bil.diplomazia.dono_alleanza)
	missioni.append({"tipo": "alleanza", "regione": chiave, "mancano": int(bil.diplomazia.giorni_messaggero)})
	changed.emit()
	return true


## Tutti i soldati a casa partono per l'attacco: tornano (chi torna) dopo la battaglia.
func attacca(chiave: String) -> bool:
	if perche_no("attacco", chiave) != "":
		return false
	missioni.append({"tipo": "attacco", "regione": chiave, "mancano": int(bil.diplomazia.giorni_marcia), "soldati": soldati_presenti()})
	changed.emit()
	return true


func _avanza_missioni() -> void:
	for m in missioni.duplicate():
		m.mancano = int(m.mancano) - 1
		if m.mancano <= 0:
			missioni.erase(m)
			match m.tipo:
				"spia":
					_ritorno_spia(m)
				"alleanza":
					_risposta_alleanza(m)
				"attacco":
					_battaglia(m)


func _racconta(area: String, testo: String) -> void:
	var chi := _consigliere_per(area)
	if chi >= 0:
		consiglio.emit(chi, testo)
	else:
		message.emit(testo)


static func testo_atteggiamento(a: int) -> String:
	if a >= 40:
		return "amichevole"
	if a >= 0:
		return "tranquillo"
	if a > -40:
		return "diffidente"
	return "ostile"


func _ritorno_spia(m: Dictionary) -> void:
	var r: Dictionary = regni[m.regione]
	var esito := {"tipo": "spia", "regione": m.regione, "riuscita": true}
	if _rng.randf() < float(bil.diplomazia.spia_scoperta):
		esito.riuscita = false
		r.atteggiamento = int(r.atteggiamento) - 15
		_racconta("oro", "La nostra spia è stata scoperta a %s: non sapremo niente, e ora ci guardano storto." % r.nome)
	else:
		r.spiato = true
		var cosa := "forza %d" % forza_regno(m.regione)
		if r.tipo == "signore":
			cosa += ", %s è %s verso di noi" % [r.signore, testo_atteggiamento(int(r.atteggiamento))]
		elif r.tipo == "banditi":
			cosa += ": un covo di banditi, da lì vengono a saccheggiarci"
		else:
			cosa += ": nessun signore, solo qualche pastore armato"
		_racconta("oro", "La spia è tornata da %s: %s. Il nostro esercito vale %d." % [r.nome, cosa, roundi(forza_esercito(soldati))])
	missione_finita.emit(esito)
	changed.emit()


func _risposta_alleanza(m: Dictionary) -> void:
	var r: Dictionary = regni[m.regione]
	var probabilita := clampf(0.35 + int(r.atteggiamento) / 100.0, 0.05, 0.95)
	var esito := {"tipo": "alleanza", "regione": m.regione, "riuscita": _rng.randf() < probabilita}
	if esito.riuscita:
		r.alleato = true
		r.atteggiamento = mini(100, int(r.atteggiamento) + 30)
		_racconta("oro", "%s accetta l'alleanza! Ci manderà rinforzi contro i banditi e un dono ogni stagione." % r.signore)
	else:
		r.atteggiamento = int(r.atteggiamento) - 10
		_racconta("oro", "%s ha tenuto il dono ma rifiuta l'alleanza." % r.signore)
	missione_finita.emit(esito)
	changed.emit()


## L'esercito arriva e si schiera: la battaglia si combatte sul campo a esagoni (LogicaBattaglia,
## scena battaglia). Il tempo del feudo si ferma finché non finisce.
func _battaglia(m: Dictionary) -> void:
	var r: Dictionary = regni[m.regione]
	var c: Dictionary = bil.battaglia
	var aiuti := 0
	for k in regni:
		if regni[k].conquistato:
			aiuti += roundi(leva_vassallo(k) / float(c.unita.vassalli.forza))
	var nemici := maxi(2, roundi(forza_regno(m.regione) / float(c.unita[c.eserciti[r.tipo][0]].forza)))
	battaglia = LogicaBattaglia.crea(m.regione, r.tipo, int(m.soldati), int(risorse.armi), aiuti, nemici, _rng.randi(), c)
	risorse.armi = maxf(0.0, risorse.armi - float(battaglia.armi_usate))
	if velocita > 0:
		_velocita_prima = velocita
	velocita = 0
	_racconta("costruire", "Il nostro esercito è arrivato a %s: %d soldati%s contro %d. Si combatte!" % [
		r.nome, int(m.soldati), " e %d uomini dei vassalli" % aiuti if aiuti > 0 else "", nemici])
	battaglia_iniziata.emit(battaglia)
	changed.emit()


## Le azioni della battaglia, chiamate dalla scena: muovere, attaccare, finire il turno, ritirarsi.
func battaglia_muovi(id: int, dove: Vector2i) -> Array[Vector2i]:
	if battaglia.is_empty() or battaglia.fase != "noi":
		return []
	return LogicaBattaglia.muovi(battaglia, id, dove, bil.battaglia)


func battaglia_attacca(id: int, bersaglio: int) -> Dictionary:
	if battaglia.is_empty() or battaglia.fase != "noi":
		return {}
	var e := LogicaBattaglia.attacca(battaglia, id, bersaglio, bil.battaglia, _rng)
	_dopo_azione()
	return e


func battaglia_fine_turno() -> Array:
	if battaglia.is_empty() or battaglia.fase != "noi":
		return []
	var azioni := LogicaBattaglia.fine_turno(battaglia, bil.battaglia, _rng)
	_dopo_azione()
	return azioni


func battaglia_ritirata() -> void:
	if battaglia.is_empty():
		return
	LogicaBattaglia.ritirata(battaglia)
	_dopo_azione()


## Una battaglia di prova, senza partita: si sceglie tutto e alla fine non cambia niente.
func inizia_prova_battaglia(p: Dictionary) -> void:
	prova_battaglia = p.duplicate()
	var nomi := {"signore": "Il castello del Duca", "banditi": "Il covo dei banditi", "libera": "La terra libera"}
	battaglia = LogicaBattaglia.crea("prova", p.nemico, int(p.soldati), int(p.armi), int(p.vassalli), int(p.nemici), randi(), bil.battaglia)
	battaglia.prova = true
	battaglia.titolo = "Prova: %s" % nomi.get(p.nemico, "battaglia")


func _dopo_azione() -> void:
	if battaglia.get("prova", false):
		return  # la prova non cambia la partita
	if battaglia.finita and not battaglia.get("chiusa", false):
		battaglia.chiusa = true
		_fine_battaglia(battaglia.vinta, battaglia.perche)


## Fine della battaglia: i caduti fra i nostri soldati lasciano il villaggio; con la vittoria
## la regione è nostra e la governa un vassallo.
func _fine_battaglia(vinta: bool, perche: String) -> void:
	var b := battaglia
	var r: Dictionary = regni[b.regione]
	var vivi := LogicaBattaglia.superstiti(b, "noi", ["fanti", "arcieri"])
	var caduti := int(b.nostri_inizio) - vivi
	soldati -= caduti
	abitanti -= caduti
	var esito := {"tipo": "attacco", "regione": b.regione, "riuscita": vinta, "caduti": caduti, "perche": perche}
	if vinta:
		r.conquistato = true
		r.alleato = false
		var liberi := consiglieri_liberi()
		nomina_vassallo(b.regione, liberi[0] if not liberi.is_empty() else CAVALIERE)
		for k in regni:
			if regni[k].tipo == "signore" and k != b.regione:
				regni[k].atteggiamento = int(regni[k].atteggiamento) - 10  # i vicini ci temono
		message.emit("Vittoria! %s è nostra: la governa %s, tuo vassallo. Caduti: %d." % [r.nome, nome_vassallo(int(r.vassallo)), caduti])
		felicita = minf(100.0, felicita + 5.0)
	else:
		r.atteggiamento = int(r.atteggiamento) - 40
		r.forza = int(r.forza) + 2  # chi ha resistito si fa più forte
		message.emit("%s Tornano %d soldati su %d." % [perche, vivi, int(b.nostri_inizio)])
		felicita = maxf(0.0, felicita - 8.0)
	esito.battaglia = b.duplicate()
	battaglia_finita.emit(esito)
	missione_finita.emit(esito)
	changed.emit()


## Chiude la schermata della battaglia: il tempo riparte.
func chiudi_battaglia() -> void:
	if battaglia.is_empty() or not battaglia.finita:
		return
	if battaglia.get("prova", false):
		battaglia = {}
		return
	battaglia = {}
	velocita = maxi(1, _velocita_prima)
	if abitanti <= 0:
		_fine(false, "Nessuno è rimasto a casa.")
	changed.emit()
	salva()


const RISORSA_DEL_TRIBUTO := {"ferro": "ferro", "pietra": "pietra", "pesce": "cibo", "grano": "grano", "legname": "legna"}


## Le terre conquistate mandano un tributo ogni stagione (secondo quanto chiediamo al vassallo
## e la sua arte), gli alleati un dono. Chiedere molto rende di più ma fa perdere lealtà:
## sotto la soglia il vassallo può ribellarsi e la regione torna libera.
func _riscuoti_tributi() -> void:
	var d: Dictionary = bil.diplomazia
	var v: Dictionary = bil.vassalli
	var cap := capacita()
	for k in regni:
		var r: Dictionary = regni[k]
		if r.conquistato:
			for ris in tributo_di(k):
				risorse[ris] = minf(cap, risorse[ris] + float(tributo_di(k)[ris]))
			var lealta := int(r.lealta) + int(v.tributo[r.tributo].lealta)
			if int(r.vassallo) >= 0 and tratto(int(r.vassallo)).has("felicita"):
				lealta += 3  # i devoti restano fedeli
			r.lealta = clampi(lealta, 0, 100)
			if r.lealta < int(v.soglia_ribellione) and _rng.randf() < (int(v.soglia_ribellione) - r.lealta) / 60.0:
				_ribellione(k)
		elif r.alleato:
			risorse.oro = minf(cap, risorse.oro + float(d.dono_alleato_stagione))


const CAVALIERE := -2  # vassallo che non è un consigliere: un cavaliere qualunque


func consiglieri_liberi() -> Array[int]:
	var liberi: Array[int] = []
	for f in consiglieri():
		if vassallo_di(f) == "":
			liberi.append(f)
	return liberi


func nome_vassallo(chi: int) -> String:
	if chi >= 0:
		return famiglie[chi].capo
	return "un cavaliere" if chi == CAVALIERE else "nessuno"


## Affida una regione conquistata a un consigliere libero (o a un cavaliere): la lealtà riparte.
func nomina_vassallo(chiave: String, chi: int) -> bool:
	var r: Dictionary = regni[chiave]
	if not r.conquistato or (chi >= 0 and (not chi in consiglieri() or (vassallo_di(chi) != "" and int(r.vassallo) != chi))):
		return false
	r.vassallo = chi
	var v: Dictionary = bil.vassalli
	r.lealta = int(v.lealta_consigliere) if chi >= 0 else int(v.lealta_cavaliere)
	changed.emit()
	return true


func imposta_tributo(chiave: String, quanto: String) -> void:
	if regni[chiave].conquistato and bil.vassalli.tributo.has(quanto):
		regni[chiave].tributo = quanto
		changed.emit()


## Cosa manda una regione ogni stagione: oro e la sua risorsa, per quanto chiediamo,
## più qualcosa nell'arte del vassallo (es. i boscaioli mandano più legna).
func tributo_di(chiave: String) -> Dictionary:
	var r: Dictionary = regni[chiave]
	var d: Dictionary = bil.diplomazia
	var molt := float(bil.vassalli.tributo[r.tributo].molt)
	var t := {"oro": roundi(float(d.tributo_oro) * molt)}
	var ris: String = RISORSA_DEL_TRIBUTO.get(r.risorsa, "cibo")
	t[ris] = int(t.get(ris, 0)) + roundi(float(d.tributo_risorsa) * molt)
	if int(r.vassallo) >= 0:
		var arte: Dictionary = tratto(int(r.vassallo)).get("produzione", {})
		if not arte.is_empty():
			var dove: String = arte.keys()[0]
			t[dove] = int(t.get(dove, 0)) + int(bil.vassalli.bonus_tratto)
	return t


## Le truppe che un vassallo manda in aiuto (contro i banditi e in guerra): più è leale, più ne manda.
func leva_vassallo(chiave: String) -> float:
	return float(bil.vassalli.leva) * float(regni[chiave].lealta) / 100.0


func _ribellione(chiave: String) -> void:
	var r: Dictionary = regni[chiave]
	var chi := int(r.vassallo)
	r.conquistato = false
	r.vassallo = -1
	r.atteggiamento = -60
	r.spiato = false
	if chi >= 0:
		famiglie[chi].ribelle = true  # la casata lascia il consiglio
	message.emit("%s si è ribellato: %s non è più nostra!%s" % [nome_vassallo(chi).capitalize(), r.nome,
		" La casata %s ha lasciato il consiglio." % famiglie[chi].casata if chi >= 0 else ""])
	changed.emit()


func vassallo_di(famiglia: int) -> String:
	for k in regni:
		if int(regni[k].vassallo) == famiglia:
			return regni[k].nome
	return ""


# --- Collegamento alla piazza ---------------------------------------------------------

## Vero se l'edificio è collegato da una strada (o perché li tocca direttamente) a un punto
## da cui partono le strade: falò o piazza, dimora del signore, torre di guardia.
## Chi non è collegato lavora un po' peggio (malus in bilanciamento.strade).
func collegato(b: Dictionary) -> bool:
	if terreno == null:
		return true
	if _radice(b):
		return true
	if not _rete_valida:
		_calcola_rete()
	for v in _bordo(b):
		if _rete_strade.has(v):
			return true
	return false


func _radice(b: Dictionary) -> bool:
	var d: Dictionary = edifici[b.tipo]
	return d.get("centro", false) or (d.get("radice_strade", false) and b.progresso >= 1.0)


## I vertici raggiunti dalle strade che partono dalle radici (contando anche i vertici
## sul bordo delle radici: chi le tocca è collegato).
func _calcola_rete() -> void:
	_rete_valida = true
	_rete_strade = {}
	var da_visitare: Array[Vector2i] = []
	for b in buildings:
		if _radice(b):
			for v in _bordo(b):
				if not _rete_strade.has(v):
					_rete_strade[v] = true
					da_visitare.append(v)
	while not da_visitare.is_empty():
		var v: Vector2i = da_visitare.pop_back()
		for dir in TerrenoFeudo.DIREZIONI:
			var w: Vector2i = v + dir
			if not _rete_strade.has(w) and terreno.lato_strada(v, w):
				_rete_strade[w] = true
				da_visitare.append(w)


## I vertici sul perimetro dell'edificio.
func _bordo(b: Dictionary) -> Array[Vector2i]:
	var t := taglia_di(b)
	var bordo: Array[Vector2i] = []
	for x in t.x + 1:
		bordo.append(b.cella + Vector2i(x, 0))
		bordo.append(b.cella + Vector2i(x, t.y))
	for y in range(1, t.y):
		bordo.append(b.cella + Vector2i(0, y))
		bordo.append(b.cella + Vector2i(t.x, y))
	return bordo


# --- Strade ---------------------------------------------------------------------

## Costo in pietra di una strada lungo queste celle (1 in piano, 2 in salita); -1 se non si può.
func costo_strada(celle: Array) -> int:
	if terreno == null:
		return -1
	return terreno.costo_strada(celle)


func verifica_strada(celle: Array) -> Dictionary:
	if terreno == null:
		return {"ok": false, "pietra": 0, "legna": 0, "ponti": 0, "passerelle": 0, "motivo": ""}
	return terreno.verifica_strada(celle)


## Costruisce la strada lungo questi vertici (vedi TerrenoFeudo.verifica_strada).
func costruisci_strada(vertici: Array) -> bool:
	var v := verifica_strada(vertici)
	if not v.ok or risorse.pietra < v.pietra or risorse.legna < v.legna:
		return false
	risorse.pietra -= v.pietra
	risorse.legna -= v.legna
	var nuove := terreno.aggiungi_strada(vertici)
	terreno_cambiato.emit(nuove)
	changed.emit()
	return true


## Toglie un lato di strada (la chiave del lato, vedi TerrenoFeudo.lato).
func rimuovi_strada(k: int) -> void:
	if terreno and terreno.rimuovi_lato(k):
		terreno_cambiato.emit(TerrenoFeudo.celle_del_lato(k))
		changed.emit()


# --- Mura -------------------------------------------------------------------------

func verifica_mura(celle: Array) -> Dictionary:
	if terreno == null or livello < int(bil.mura.dal_livello):
		return {"ok": false, "pietra": 0, "celle": 0, "motivo": "le mura si fanno dal Borgo in poi"}
	return terreno.verifica_mura(celle)


func costruisci_mura(celle: Array) -> bool:
	var v := verifica_mura(celle)
	if not v.ok or risorse.pietra < v.pietra or v.celle == 0:
		return false
	risorse.pietra -= v.pietra
	terreno_cambiato.emit(terreno.aggiungi_mura(celle))
	changed.emit()
	return true


func demolisci_muro(c: Vector2i) -> void:
	if terreno and terreno.rimuovi_muro(c):
		risorse.pietra = minf(capacita(), risorse.pietra + floorf(TerrenoFeudo.COSTO_MURA * float(bil.rimborso_demolizione)))
		terreno_cambiato.emit([c])
		changed.emit()


## Vero se le mura chiudono il borgo: da un punto qualunque del confine non si arriva a piedi
## alla dimora (o al centro). Calcolato quando servono le difese.
func cinta_chiusa() -> bool:
	if terreno == null or terreno.mura.is_empty():
		return false
	if _cinta < 0:
		_cinta = 1 if _calcola_cinta() else 0
	return _cinta == 1


func _calcola_cinta() -> bool:
	var centro := _cella_centro()
	var f := TerrenoFeudo.FEUDO
	for partenza in [Vector2i(f.position.x, f.position.y + f.size.y / 2), Vector2i(f.end.x - 1, f.position.y + f.size.y / 2),
			Vector2i(f.position.x + f.size.x / 2, f.position.y), Vector2i(f.position.x + f.size.x / 2, f.end.y - 1)]:
		if terreno.percorribile(partenza) and not terreno.chiuso_da_mura(partenza, centro):
			return false
	return true


## La cella al centro del borgo: dove arrivano i banditi.
func _cella_centro() -> Vector2i:
	for tipo in ["dimora", "piazza", "falo"]:
		for b in buildings:
			if b.tipo == tipo:
				return b.cella + taglia_di(b) / 2
	return TerrenoFeudo.centro_feudo()


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
## La pianta selvatica che un raccoglitore raccoglie adesso: quella con più celle attorno, se è la sua
## stagione (quella in cui la coltura cresce) e ce n'è abbastanza; "" altrimenti (solo cibo).
func selvatica_di_stagione(b: Dictionary) -> String:
	var d: Dictionary = edifici[b.tipo]
	if not d.has("selvatiche") or terreno == null:
		return ""
	var conteggio := terreno.selvatiche_attorno(b.cella, taglia_di(b), int(d.zona.raggio))
	var migliore := ""
	var piu := int(d.selvatiche.minimo_celle) - 1
	for nome in conteggio:
		if CHIAVI_STAGIONI[stagione] in colture[nome].stagioni and int(conteggio[nome]) > piu:
			piu = int(conteggio[nome])
			migliore = nome
	return migliore


func _raccogli_semi(b: Dictionary, molt: float, cap: float, tps: float) -> void:
	if terreno == null:
		return
	var d: Dictionary = edifici[b.tipo]
	var conteggio := terreno.selvatiche_attorno(b.cella, taglia_di(b), int(d.zona.raggio))
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
		tagliate.append_array(terreno.taglia_bosco(b.cella, taglia_di(b), int(d.zona.raggio), maxi(1, roundi(per_stagione * quota))))
	if not tagliate.is_empty():
		terreno_cambiato.emit(tagliate)


func _fine_stagione() -> void:
	if terreno:
		var libere := terreno.togli_ceppi()
		if not libere.is_empty():
			terreno_cambiato.emit(libere)
	_disbosca()
	_fine_colture()
	_lavora_forestali()
	_consuma_tende()
	_nuovi_arcieri()
	_scadono_modificatori()
	_riscuoti_tasse()
	_riscuoti_tributi()
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
	_programma_banditi()
	_il_re_si_fa_sentire()
	if not mercato.evento.is_empty():
		message.emit("Dal mercato: " + mercato.evento.testo)
	_controlla_livello()
	season_changed.emit(stagione, anno)
	salva()


## Ogni fine stagione la gente paga le tasse: quanto dipende dalla media fra risorse, popolazione
## e gradimento, che cade in una fascia (da 0, la più bassa, a 3). Ogni stagione ha le sue monete
## per fascia (bilanciamento.tasse_stagionali), per ogni gruppo di abitanti; il livello delle
## tasse e il tratto della guida le moltiplicano. In autunno si paga anche il re.
func valutazione_tasse() -> Dictionary:
	var t: Dictionary = bil.tasse_stagionali
	var consumo := maxf(1.0, abitanti * float(bil.cibo_per_abitante_tick) * float(bil.tick_per_stagione))
	var cibo := 0.0
	for r in CIBI:
		cibo += risorse[r]
	var voce_risorse := (minf(1.0, cibo / consumo) + minf(1.0, risorse.legna / maxf(20.0, riscaldamento_invernale()))
		+ minf(1.0, risorse.pietra / float(t.pietra_buona))) / 3.0
	var obiettivo := float(bil.livelli[mini(livello + 1, bil.livelli.size() - 1)].get("abitanti", 25))
	var voce_popolazione := minf(1.0, abitanti / maxf(1.0, obiettivo))
	var voce_gradimento := felicita / 100.0
	var media := (voce_risorse + voce_popolazione + voce_gradimento) / 3.0
	var fascia := 0
	for soglia in t.soglie:
		if media >= float(soglia):
			fascia += 1
	var per_quota := int(t.monete[CHIAVI_STAGIONI[stagione]][fascia])
	var gruppi := maxf(1.0, abitanti / float(t.abitanti_per_quota))
	var molt := float(bil.tasse[tasse].molt) * float(tratto(capo).get("tasse", 1.0))
	var monete := maxi(1, roundi(per_quota * gruppi * molt)) if abitanti > 0 else 0
	return {"risorse": voce_risorse, "popolazione": voce_popolazione, "gradimento": voce_gradimento,
		"media": media, "fascia": fascia, "monete": monete}


const NOMI_FASCE := ["bassa", "media", "buona", "massima"]


func _riscuoti_tasse() -> void:
	var v := valutazione_tasse()
	ultime_tasse = v
	ultimo_affitto = tributo_case()
	risorse.oro = minf(capacita(), risorse.oro + v.monete + ultimo_affitto)
	var case := " e %d dalle case" % ultimo_affitto if ultimo_affitto > 0 else ""
	if stagione != AUTUNNO or indipendente():
		message.emit("Tasse di %s: +%d oro (fascia %s)%s" % [STAGIONI[stagione].to_lower(), v.monete, NOMI_FASCE[v.fascia], case])
		return
	var dovuto := tassa_del_re()
	if risorse.oro >= dovuto:
		risorse.oro -= dovuto
		tasse_non_pagate = 0
		message.emit("Tasse d'autunno: +%d oro dagli abitanti%s, %d oro al re" % [v.monete, case, dovuto])
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
	var probabilita := float(_crescita().get("probabilita_massima", c.probabilita_massima))
	if _rng.randf() < attrattiva * probabilita:
		var n := _rng.randi_range(1, mini(int(c.massimo_per_volta), posti))
		abitanti += n
		message.emit("%s arrivat%s al villaggio: si parla bene di noi" % ["È" if n == 1 else "Sono", "a una persona" if n == 1 else "e %d persone" % n])


## 0..1: felicità sopra la soglia per abbondanza di scorte di cibo (e di legna d'inverno).
func calcola_attrattiva() -> float:
	var c: Dictionary = bil.crescita
	var presto := _crescita()
	if _fame:
		return 0.0
	var consumo_stagione := maxf(1.0, abitanti * float(bil.cibo_per_abitante_tick) * float(bil.tick_per_stagione))
	var scorte := 0.0
	for r in CIBI:
		scorte += risorse[r]
	var abbondanza := maxf(clampf(scorte / consumo_stagione, 0.0, 2.0) / 2.0, float(presto.get("abbondanza_minima", 0.0)))
	if stagione in [AUTUNNO, INVERNO] and risorse.legna < riscaldamento_invernale():
		abbondanza *= 0.5
	var soglia := float(presto.get("soglia_arrivi", c.soglia_arrivi))
	return clampf((felicita - soglia) / (100.0 - soglia), 0.0, 1.0) * abbondanza


## Finché non si è Borgo la gente arriva più facilmente (bilanciamento.crescita_prima_del_borgo):
## così in un anno e mezzo, due, si può diventare Borgo. Dopo valgono le regole normali.
func _crescita() -> Dictionary:
	return bil.get("crescita_prima_del_borgo", {}) if livello == 0 else {}


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
		if livello == int(bil.re.indipendenza_dal_livello):
			_indipendenza()


## Diventati Borgo ci stacchiamo dal regno: niente più tasse al re, che ci guarda con diffidenza.
func _indipendenza() -> void:
	re_atteggiamento = int(bil.re.atteggiamento_indipendenza)
	tasse_non_pagate = 0
	if not evento_attivo.is_empty():
		message.emit("Siamo un borgo libero: niente più tasse al re, che però ora ci guarda con diffidenza")
		return
	var chi := _consigliere_per("oro")
	mostra_evento({"id": "indipendenza", "area": "oro", "narratore": chi,
		"titolo": "Un borgo libero",
		"testo": "Ormai siamo un borgo: non abbiamo più bisogno della protezione del re e non gli pagheremo più le tasse. Ma il re non la prende bene: da oggi ci guarda con diffidenza, e prima o poi manderà qualcuno a chiedere il suo.",
		"scelte": [{"testo": "Siamo liberi", "effetti": {"felicita": 5}}]})


## Ogni stagione, da indipendenti, il re si fa sentire: un messo chiede un tributo (pagando
## si calma, rifiutando si arrabbia); se è molto ostile manda il suo esercito.
func _il_re_si_fa_sentire() -> void:
	if not indipendente() or capo < 0:
		return
	var r: Dictionary = bil.re
	re_atteggiamento = clampi(re_atteggiamento - int(r.diffidenza_per_stagione), -100, 100)
	if re_atteggiamento <= int(r.soglia_spedizione) and banditi.is_empty() and _rng.randf() < float(r.probabilita_spedizione):
		_avvista_banditi()
		banditi.regio = true
		banditi.forza = float(banditi.forza) * float(r.forza_spedizione)
		banditi.numero = clampi(roundi(float(banditi.forza) / 3.0), 4, 14)
		_racconta("costruire", "L'esercito del re marcia contro di noi da %s! Arriva tra %d giorni: forza %d contro la nostra %d." % [
			banditi.da, int(banditi.mancano), roundi(banditi.forza), roundi(difesa().totale)])
		banditi_avvistati.emit(banditi)
	elif _rng.randf() < float(r.probabilita_messo) and evento_attivo.is_empty():
		var chiesto := roundi(float(r.tributo_messo) * (1.0 + 0.2 * (anno - 1)))
		mostra_evento({"id": "messo_del_re", "area": "oro", "titolo": "Il messo del re",
			"testo": "Un messo del re, col mantello blu e la scorta, chiede %d oro: «il prezzo della pace», dice. Il re è %s verso di noi." % [chiesto, testo_atteggiamento(re_atteggiamento)],
			"scelte": [{"testo": "Paghiamo", "effetti": {"risorse": {"oro": -chiesto}, "re": int(r.pace_pagando)}},
				{"testo": "Non gli dobbiamo niente", "effetti": {"re": -int(r.offesa_rifiutando)}}]})


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
	# se mancano braccia lasciano prima il lavoro, poi l'esercito
	var eccesso := lavoratori_assegnati() + soldati - abitanti
	var dai_soldati := maxi(0, eccesso - lavoratori_assegnati())
	if dai_soldati > 0:
		soldati -= dai_soldati
		eccesso -= dai_soldati
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
			"eta": b.get("eta", 0), "rot": b.get("rot", 0), "arcieri": b.get("arcieri", 0),
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
		"banditi": _banditi_salvati(), "tick_banditi": _tick_banditi,
		"soldati": soldati, "regni": regni, "missioni": missioni, "battaglia": battaglia,
		"aiuto_inverno_dato": aiuto_inverno_dato, "tutorial_passo": tutorial_passo, "re_atteggiamento": re_atteggiamento,
		"suggerimenti_attivi": suggerimenti_attivi, "prossimo_suggerimento": _prossimo_suggerimento,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dati))


func carica() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var dati = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	# i salvataggi delle versioni precedenti (mappa più piccola, niente famiglie) non si caricano
	if not dati is Dictionary or int(dati.get("versione", 0)) < VERSIONE_MINIMA:
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
		if int(x.get("rot", 0)) != 0:
			b.rot = int(x.rot)
		if edifici[b.tipo].has("arcieri"):
			b.arcieri = int(x.get("arcieri", 0))
		buildings.append(b)
	tick_senza_casa = int(dati.get("tick_senza_casa", 0))
	modificatori = dati.get("modificatori", [])
	eventi_usati = dati.get("eventi_usati", [])
	_tick_evento = int(dati.get("tick_evento", -1))
	_tick_banditi = int(dati.get("tick_banditi", -1))
	soldati = int(dati.get("soldati", 0))
	aiuto_inverno_dato = bool(dati.get("aiuto_inverno_dato", anno > 1))
	tutorial_passo = int(dati.get("tutorial_passo", -1))
	re_atteggiamento = int(dati.get("re_atteggiamento", -40 if livello >= 1 else 0))
	_prossimo_suggerimento = int(dati.get("prossimo_suggerimento", 0))
	var salvati: Dictionary = dati.get("regni", {})
	for k in salvati:
		if regni.has(k):
			for campo in ["forza", "atteggiamento", "vassallo", "lealta"]:
				regni[k][campo] = int(salvati[k].get(campo, 0))
			regni[k].tributo = str(salvati[k].get("tributo", "normale"))
			for campo in ["spiato", "alleato", "conquistato"]:
				regni[k][campo] = bool(salvati[k][campo])
	missioni = dati.get("missioni", [])
	battaglia = dati.get("battaglia", {})
	if not battaglia.is_empty() and not battaglia.has("unita"):
		battaglia = {}  # una battaglia del vecchio tipo: si lascia perdere
	for k in ["turno", "turni", "nostri_inizio", "loro_inizio", "prossimo_id", "armi_usate"]:
		if battaglia.has(k):
			battaglia[k] = int(battaglia[k])
	for u in battaglia.get("unita", []):
		for k in ["id", "uomini", "max", "mosse"]:
			u[k] = int(u[k])
		u.cella = [int(u.cella[0]), int(u.cella[1])]
	if battaglia.has("terreno"):
		battaglia.terreno = battaglia.terreno.map(func(x): return int(x))
	for m in missioni:
		m.mancano = int(m.mancano)
		if m.has("soldati"):
			m.soldati = int(m.soldati)
	banditi = dati.get("banditi", {})
	if not banditi.is_empty():
		banditi.entrata = Vector2i(int(banditi.entrata[0]), int(banditi.entrata[1]))
		banditi.percorso = banditi.get("percorso", []).map(func(c): return Vector2i(int(c[0]), int(c[1])))
		for k in ["numero", "mancano", "totale"]:
			banditi[k] = int(banditi[k])
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


func _banditi_salvati() -> Dictionary:
	if banditi.is_empty():
		return {}
	var copia := banditi.duplicate()
	copia.entrata = [banditi.entrata.x, banditi.entrata.y]
	copia.percorso = banditi.get("percorso", []).map(func(c): return [c.x, c.y])
	return copia


func cancella_salvataggio() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
