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
	var rimasti := maxf(1.0, gs.prossima_consegna() - gs.tick_in_stagione)
	var a_fine: float = gs.risorse.cibo + d_cibo * rimasti + float(gs.previsione_raccolti().get("cibo", 0.0))
	if d_cibo < 0.0 and gs.risorse.cibo + d_cibo * rimasti < 0.0:
		lista.append(_c("cibo", 95, "Il cibo finisce prima che arrivi il raccolto %s. Compralo al mercato o costruisci un forno." % gs.quando_consegna()))
	elif d_cibo < 0.0 and a_fine + d_cibo * tps / 2.0 < 0.0:
		lista.append(_c("cibo", 90, "Anche con il prossimo raccolto il cibo non basterà fino a quello dopo. Serve un altro edificio del cibo."))

	# Legna e inverno
	if not _esiste(["taglialegna"]):
		lista.append(_c("legna", 95, "Senza un taglialegna non costruiremo nulla. Mettilo dove il bosco è più fitto: più alberi, più legna."))
	for b in gs.buildings:
		if b.tipo == "taglialegna" and b.progresso >= 1.0 and gs.terreno:
			var d: Dictionary = gs.edifici[b.tipo]
			var resta := gs.terreno.conta_attorno(b.cella, Vector2i(int(d.taglia[0]), int(d.taglia[1])), int(d.zona.raggio), TerrenoFeudo.Tipo.BOSCO)
			if resta < 6:
				lista.append(_c("legna", 88, "Il bosco attorno al taglialegna è quasi finito (%d celle). Costruiscine uno nuovo vicino a un altro bosco." % resta))
				break
	var serve_inverno := 0
	for b in gs.buildings:
		if b.progresso >= 1.0:
			serve_inverno += int(gs.def_di(b).get("riscaldamento", 0))
	if gs.stagione in [gs.ESTATE, gs.AUTUNNO] and gs.risorse.legna < serve_inverno:
		lista.append(_c("legna", 80, "L'inverno chiederà %d legna per scaldarci; ne abbiamo %d." % [serve_inverno, int(gs.risorse.legna)]))

	# Case
	if gs.senza_casa() > 0:
		var resta := int(gs.bil.senza_casa.tick_prima_di_andarsene) - gs.tick_senza_casa
		lista.append(_c("case", 92, "%d dei nostri dormono all'aperto: se tra %d giorni non hanno un tetto se ne vanno. Servono case." % [gs.senza_casa(), maxi(1, resta)]))
	if gs.conta_completati("tenda") > 0:
		lista.append(_c("case", 82 if gs.conta_completati("casa") == 0 else 60, "Le tende reggono una sola stagione, poi si strappano: prima che cadano servono case vere (ospitano 4 persone)."))
	if gs.calcola_attrattiva() > 0.3 and gs.alloggi() - gs.abitanti <= 0:
		lista.append(_c("case", 40, "La voce gira: altra gente verrebbe a vivere qui, ma non c'è nemmeno un posto letto libero."))

	# Lavoro
	var posti_liberi := 0
	for b in gs.buildings:
		if b.progresso >= 1.0:
			posti_liberi += int(gs.def_di(b).lavoratori) - int(b.lavoratori)
	if gs.disoccupati() > 0 and posti_liberi > 0:
		lista.append(_c("lavoro", 70, "%d persone sono senza lavoro e ci sono posti liberi: tocca un edificio e premi +." % gs.disoccupati()))
	elif gs.disoccupati() > 2:
		lista.append(_c("lavoro", 50, "Abbiamo %d braccia libere: un nuovo edificio darebbe loro lavoro." % gs.disoccupati()))

	# Oro
	var v := gs.valutazione_tasse()
	var incasso := int(v.monete) * (gs.AUTUNNO - gs.stagione + 1)
	if not gs.indipendente() and gs.stagione in [gs.ESTATE, gs.AUTUNNO] and gs.risorse.oro + incasso < gs.tassa_del_re():
		lista.append(_c("oro", 75, "In autunno il re vorrà %d oro e ne avremo circa %d. Un mercato o tasse più alte ci servirebbero." % [gs.tassa_del_re(), int(gs.risorse.oro) + incasso]))
	if v.fascia <= 1 and gs.abitanti > 0:
		var debole: String = "le scorte" if v.risorse <= minf(v.popolazione, v.gradimento) else ("la popolazione" if v.popolazione <= v.gradimento else "il gradimento")
		lista.append(_c("oro", 38, "Le tasse rendono poco (%d oro a stagione, fascia %s): pesa soprattutto %s." % [v.monete, gs.NOMI_FASCE[v.fascia], debole]))

	# Campi: cibo per l'inverno
	if not _esiste(["campo"]) and gs.stagione == gs.PRIMAVERA:
		lista.append(_c("cibo", 55, "Seminiamo un campo dove la terra è scura e fertile, vicino all'acqua: in autunno darà grano per l'inverno."))
	if gs.stagione == gs.AUTUNNO and _esiste(["pescatore"]):
		lista.append(_c("cibo", 58, "D'inverno il lago gela e i pescatori prenderanno poco: il fiume invece scorre sempre."))

	# Forestale: il legno non deve finire
	if _esiste(["taglialegna"]) and not _esiste(["forestale"]) and gs.terreno and gs.terreno.indici_tagliati.size() > 15:
		lista.append(_c("legna", 70, "Abbiamo tagliato %d celle di bosco. Un forestale ripianterebbe gli alberi: in un anno tornano bosco." % gs.terreno.indici_tagliati.size()))

	# Semi e colture
	for b in gs.buildings:
		if b.get("senza_semi", false):
			var c := gs.coltura_di(b)
			lista.append(_c("cibo", 78, "Un campo è fermo: mancano i semi di %s. Si comprano al mercato, o li raccoglie un raccoglitore vicino alle piante selvatiche." % c.get("nome", "").to_lower()))
			break
	if not _esiste(["campo"]) and gs.stagione == gs.ESTATE:
		lista.append(_c("cibo", 50, "Le rape si seminano in autunno e crescono anche d'inverno: un campo ci terrebbe in vita fino alla primavera."))

	# Mercato
	var m := gs.mercato
	if m and not m.evento.is_empty():
		lista.append(_c("oro", 42, "Notizie dal mercato: %s. Conviene guardare i prezzi." % m.evento.testo))
	if gs.risorse.oro >= 40.0 and gs.risorse.cibo < 20.0:
		lista.append(_c("oro", 72, "Abbiamo oro ma poco cibo: al mercato se ne può comprare."))

	# Strade
	if gs.terreno:
		var staccati := 0
		for b in gs.buildings:
			if b.progresso >= 1.0 and int(gs.def_di(b).lavoratori) > 0 and not gs.collegato(b):
				staccati += 1
		if staccati > 0:
			lista.append(_c("costruire", 36, "%d edifici non sono collegati alla piazza da una strada: lavorano il 2%% in meno. Una strada che li tocchi e arrivi in piazza toglie il ritardo." % staccati))

	# Banditi e difese
	if not gs.banditi.is_empty():
		var dif: Dictionary = gs.difesa()
		if dif.totale < float(gs.banditi.forza):
			lista.append(_c("costruire", 99, "I banditi arrivano tra %d giorni e siamo più deboli (%d contro %d). Costruisci torri di guardia lungo la loro strada, alza palizzate e mura, compra armi." % [int(gs.banditi.mancano), roundi(dif.totale), roundi(gs.banditi.forza)]))
		else:
			lista.append(_c("costruire", 60, "I banditi arrivano tra %d giorni, ma siamo pronti: %d contro %d." % [int(gs.banditi.mancano), roundi(dif.totale), roundi(gs.banditi.forza)]))
	elif gs.livello >= 1 and not _esiste(["torre_guardia", "palizzata"]):
		lista.append(_c("costruire", 74, "Ora che siamo un borgo si parla di noi, anche tra i banditi. Una torre di guardia (con due arcieri) e qualche palizzata ci proteggerebbero; con le mura in pietra possiamo chiudere il borgo."))
	elif gs.livello >= 1 and _esiste(["torre_guardia"]) and not _esiste(["armeria"]) and gs.risorse.armi < 1.0:
		lista.append(_c("costruire", 34, "Gli arcieri e i soldati combattono meglio armati: un'armeria fa armi con ferro e legna."))
	if gs.diplomazia_possibile() and gs.missioni.is_empty() and not gs.regni.values().any(func(r): return r.spiato):
		lista.append(_c("oro", 33, "Ora che siamo un borgo possiamo mandare spie nei regni vicini (dalla mappa del Regno): sapremo chi è forte, chi è amico e dove si può attaccare."))
	if gs.soldati > 0 and gs.risorse.cibo + gs.risorse.rape + gs.risorse.orzo < gs.cibo_esercito_al_mese():
		lista.append(_c("cibo", 86, "I soldati mangiano %d cibo al mese e non ne abbiamo abbastanza: se resteranno senza, una formazione se ne andrà." % gs.cibo_esercito_al_mese()))
	for b in gs.buildings:
		if b.tipo == "rovine":
			lista.append(_c("case", 48, "Le rovine bruciate dai banditi intristiscono la gente: sgomberiamole (tocca le rovine, Demolisci)."))
			break

	# Felicità
	if gs.felicita < 40.0:
		lista.append(_c("felicita", 65, "Il popolo mormora (felicità %d). Cibo vario, case vere o tasse più basse lo calmerebbero." % int(gs.felicita)))

	# Costruire e crescere
	if not _esiste(["cava"]) and gs.risorse.pietra < 20.0:
		lista.append(_c("costruire", 45, "La pietra scarseggia e le case la chiedono: una cava in mezzo alle rocce ci servirà presto."))
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
