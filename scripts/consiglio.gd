class_name Consiglio
extends RefCounted
## I suggerimenti dei consiglieri. Ogni consigliere ha un'area (dal tratto della sua casata):
## dà per primi i consigli della sua area, poi quelli generali; i due consiglieri
## non ripetono mai lo stesso consiglio. Se va tutto bene, recita il motto di famiglia.


## Il consiglio attuale della famiglia indicata ("" se non è un consigliere).
static func per(famiglia: int) -> String:
	var gs := GameState
	if famiglia == gs.capo or famiglia < 0 or famiglia >= gs.famiglie.size():
		return ""
	var area: String = gs.tratto(famiglia).get("area", "")
	var tutti := attivi()
	var gia_detto := ""
	for altro in gs.consiglieri():
		if altro < famiglia:
			gia_detto = _scegli(tutti, gs.tratto(altro).get("area", ""), "")
	var scelto := _scegli(tutti, area, gia_detto)
	return scelto if scelto != "" else "«%s»" % gs.famiglie[famiglia].motto


static func _scegli(tutti: Array, area: String, escluso: String) -> String:
	for c in tutti:
		if c.area == area and c.testo != escluso:
			return c.testo
	for c in tutti:
		if c.testo != escluso:
			return c.testo
	return ""


## Tutti i consigli validi adesso, dal più urgente: {area, priorita, testo}.
static func attivi() -> Array:
	var gs := GameState
	var lista := []
	var tps := float(gs.bil.tick_per_stagione)

	# Cibo
	if not _esiste(["raccoglitore", "pescatore", "cacciatore", "forno", "campo"]):
		lista.append(_c("cibo", 100, "Nessuno procura cibo. Un raccoglitore vicino al falò ci darebbe 40 cibo a stagione."))
	var d_cibo: float = gs.ultimo_delta.get("cibo", 0.0)
	if d_cibo < 0.0 and gs.risorse.cibo / -d_cibo < tps:
		lista.append(_c("cibo", 90, "Al ritmo di oggi il cibo finisce prima della prossima stagione. Serve un altro edificio del cibo."))

	# Legna e inverno
	if not _esiste(["taglialegna"]):
		lista.append(_c("legna", 95, "Senza un taglialegna non costruiremo nulla. Mettilo vicino al bosco: lontano rende la metà."))
	var serve_inverno := 0
	for b in gs.buildings:
		if b.progresso >= 1.0:
			serve_inverno += int(gs.edifici[b.tipo].get("riscaldamento", 0))
	if gs.stagione in [gs.ESTATE, gs.AUTUNNO] and gs.risorse.legna < serve_inverno:
		lista.append(_c("legna", 80, "L'inverno chiederà %d legna per scaldarci; ne abbiamo %d." % [serve_inverno, int(gs.risorse.legna)]))

	# Case
	if gs.abitanti > gs.alloggi():
		lista.append(_c("case", 85, "%d dei nostri dormono all'aperto: servono tende o case." % (gs.abitanti - gs.alloggi())))
	if gs.conta_completati("tenda") > 0 and gs.conta_completati("casa") == 0:
		lista.append(_c("case", 60, "Le tende sono fredde e scontentano la gente. Una casa vera ospita 4 persone."))
	if gs.felicita >= float(gs.bil.crescita.soglia_arrivi) and gs.alloggi() - gs.abitanti < int(gs.bil.crescita.famiglia):
		lista.append(_c("case", 40, "La gente è contenta e altre famiglie verrebbero in primavera, ma non c'è posto."))

	# Lavoro
	var posti_liberi := 0
	for b in gs.buildings:
		if b.progresso >= 1.0:
			posti_liberi += int(gs.edifici[b.tipo].lavoratori) - int(b.lavoratori)
	if gs.disoccupati() > 0 and posti_liberi > 0:
		lista.append(_c("lavoro", 70, "%d persone sono senza lavoro e ci sono posti liberi: tocca un edificio e premi +." % gs.disoccupati()))
	elif gs.disoccupati() > 2:
		lista.append(_c("lavoro", 50, "Abbiamo %d braccia libere: un nuovo edificio darebbe loro lavoro." % gs.disoccupati()))

	# Oro
	var incasso := int(gs.abitanti * int(gs.bil.tasse[gs.tasse].oro) * float(gs.tratto(gs.capo).get("tasse", 1.0)))
	if gs.stagione in [gs.ESTATE, gs.AUTUNNO] and gs.risorse.oro + incasso < gs.tassa_del_re():
		lista.append(_c("oro", 75, "In autunno il re vorrà %d oro e ne avremo circa %d. Un mercato o tasse più alte ci servirebbero." % [gs.tassa_del_re(), int(gs.risorse.oro) + incasso]))

	# Felicità
	if gs.felicita < 40.0:
		lista.append(_c("felicita", 65, "Il popolo mormora (felicità %d). Cibo vario, case vere o tasse più basse lo calmerebbero." % int(gs.felicita)))

	# Costruire e crescere
	if not _esiste(["cava"]) and gs.risorse.pietra < 20.0:
		lista.append(_c("costruire", 45, "La pietra scarseggia: una cava vicino alle rocce ci servirà presto."))
	if gs.livello + 1 < gs.bil.livelli.size():
		var manca := gs.requisiti_mancanti(gs.livello + 1)
		if not manca.is_empty():
			lista.append(_c("costruire", 30, "Per diventare %s ci mancano: %s." % [gs.bil.livelli[gs.livello + 1].nome, ", ".join(manca)]))

	lista.sort_custom(func(a, b): return a.priorita > b.priorita)
	return lista


static func _c(area: String, priorita: int, testo: String) -> Dictionary:
	return {"area": area, "priorita": priorita, "testo": testo}


## Vero se c'è almeno un edificio di questi tipi, anche in costruzione.
static func _esiste(tipi: Array) -> bool:
	for b in GameState.buildings:
		if b.tipo in tipi:
			return true
	return false
