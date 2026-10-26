class_name Mercato
extends RefCounted
## Il mercato del regno: si compra e si vende a lotti, pagando in oro.
## I prezzi seguono l'andamento di tutte le regioni della mappa:
## - più regioni producono una risorsa (la loro risorsa speciale), più costa poco;
## - ogni stagione i prezzi oscillano un po' e può succedere un evento in una regione
##   (carestia, incendio, nuova miniera...) che li sposta;
## - d'inverno il cibo rincara; comprare o vendere molto nella stessa stagione sposta il prezzo.

var dati: Dictionary
var fattori: Dictionary = {}      # risorsa -> oscillazione casuale (intorno a 1)
var precedenti: Dictionary = {}   # risorsa -> prezzo della stagione scorsa (per le frecce)
var evento: Dictionary = {}       # {testo, risorse, effetto} oppure vuoto
var saturazione: Dictionary = {}  # risorsa -> lotti comprati (+) o venduti (-) in questa stagione
var _offerta: Dictionary = {}     # risorsa -> sconto per l'offerta delle regioni


func _init(seme: int) -> void:
	dati = (load("res://data/mercato.json") as JSON).data
	for r in dati.prezzi_base:
		fattori[r] = 1.0
	var g := Regioni.genera(seme)
	var conteggio := {}
	for i in g.regioni.size():
		if i == g.mia:
			continue
		for r in dati.risorse_regione.get(g.regioni[i].risorsa, []):
			conteggio[r] = conteggio.get(r, 0) + 1
	for r in dati.prezzi_base:
		_offerta[r] = maxf(0.5, 1.0 - conteggio.get(r, 0) * float(dati.offerta_per_regione))


func risorse() -> Array:
	return dati.prezzi_base.keys()


func lotto() -> int:
	return int(dati.lotto)


## Prezzo di un'unità, prima dei margini.
func prezzo(r: String, stagione: int) -> float:
	var p: float = float(dati.prezzi_base[r]) * float(_offerta[r]) * float(fattori.get(r, 1.0))
	if stagione == GameState.INVERNO and r in dati.cibi:
		p *= float(dati.inverno_cibo)
	if not evento.is_empty() and r in evento.risorse:
		p *= 1.0 + float(evento.effetto)
	p *= 1.0 + float(saturazione.get(r, 0)) * float(dati.saturazione_per_lotto)
	return maxf(0.2, p)


## Quanto oro costa comprare un lotto (con un mercato costruito si paga meno).
func costo_lotto(r: String, stagione: int, con_mercato: bool) -> int:
	var margine := float(dati.margine_acquisto_con_mercato if con_mercato else dati.margine_acquisto)
	return maxi(1, ceili(prezzo(r, stagione) * margine * lotto()))


## Quanto oro si ricava vendendo un lotto.
func ricavo_lotto(r: String, stagione: int, con_mercato: bool) -> int:
	var margine := float(dati.margine_vendita_con_mercato if con_mercato else dati.margine_vendita)
	return maxi(1, floori(prezzo(r, stagione) * margine * lotto()))


## +1 se il prezzo è salito rispetto alla stagione scorsa, -1 se è sceso, 0 se uguale.
func tendenza(r: String, stagione: int) -> int:
	if not precedenti.has(r):
		return 0
	var d := prezzo(r, stagione) - float(precedenti[r])
	return 0 if absf(d) < 0.05 else (1 if d > 0.0 else -1)


func notizia() -> String:
	return evento.testo if not evento.is_empty() else "Il mercato è tranquillo: nessuna notizia dalle regioni."


## A ogni cambio di stagione: oscillazioni, un possibile evento in una regione, fine della saturazione.
func nuova_stagione(seme: int, anno: int, stagione: int) -> void:
	var stagione_prima := (stagione + 3) % 4
	for r in fattori:
		precedenti[r] = prezzo(r, stagione_prima)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme * 31 + anno * 4 + stagione
	var vol := float(dati.volatilita)
	for r in fattori:
		var f: float = fattori[r] * (1.0 + rng.randf_range(-vol, vol))
		fattori[r] = clampf(lerpf(f, 1.0, 0.15), 0.6, 1.6)  # torna piano verso il prezzo normale
	evento = {}
	if rng.randf() < float(dati.probabilita_evento):
		var e: Dictionary = dati.eventi[rng.randi() % dati.eventi.size()]
		var g := Regioni.genera(seme)
		var altre := []
		for i in g.regioni.size():
			if i != g.mia:
				altre.append(g.regioni[i].nome)
		evento = {"testo": e.testo % altre[rng.randi() % altre.size()], "risorse": e.risorse, "effetto": e.effetto}
	saturazione = {}


func salva() -> Dictionary:
	return {"fattori": fattori, "precedenti": precedenti, "evento": evento, "saturazione": saturazione}


func carica(d: Dictionary) -> void:
	for r in d.get("fattori", {}):
		fattori[r] = float(d.fattori[r])
	for r in d.get("precedenti", {}):
		precedenti[r] = float(d.precedenti[r])
	evento = d.get("evento", {})
	for r in d.get("saturazione", {}):
		saturazione[r] = int(d.saturazione[r])
