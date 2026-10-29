extends Node
## Test della logica di gioco, senza grafica:
##   godot --headless --path . res://tools/test_logica.tscn

var _errori := 0


func _ready() -> void:
	GameState.clima_forzato = "temperato"  # i conti dei test sono quelli del clima temperato
	GameState.cancella_salvataggio()
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	GameState.risorse.cibo = 40.0
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	_verifica(GameState.alloggi() == 12, "3 case = 12 alloggi")

	# Senza edifici del cibo: 40 cibo bastano 40 tick, poi fame.
	for i in 40:
		GameState._tick()
	_verifica(GameState.risorse.cibo < 0.01, "cibo finito dopo 40 tick")
	GameState._tick()
	_verifica(GameState.tick_fame > 0, "fame registrata")

	# Fame (dal secondo anno: il primo il signore tiene tutti nel castello).
	GameState.nuova_partita(42)
	GameState.anno = 2
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.risorse.cibo = 0.0
	var felicita_prima := GameState.felicita
	for i in 10:
		GameState._tick()
	_verifica(GameState.abitanti == 9, "fame: dopo 10 tick se ne va una persona (%d)" % GameState.abitanti)
	_verifica(GameState.felicita < felicita_prima and GameState.felicita > felicita_prima - 15, "fame: la felicità scende piano")
	for i in 50:
		GameState._tick()
	_verifica(GameState.stagione == GameState.ESTATE, "dopo 60 tick è estate")

	# Produzione: raccoglitore con 2 lavoratori = 40 cibo a stagione.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	var r := GameState.aggiungi_gratis("raccoglitore", Vector2i(0, 0), 1.0)
	r.lavoratori = 2
	GameState.abitanti = 0
	GameState.risorse.cibo = 0.0
	for i in 59:
		GameState._tick()
	_verifica(GameState.risorse.cibo == 0.0 and GameState.in_arrivo().get("cibo", 0.0) > 38.0, "il raccoglitore mette da parte durante la stagione")
	GameState._tick()
	GameState._consegna_raccolti()
	_verifica(absf(GameState.risorse.cibo - 40.0) < 0.1 and GameState.in_arrivo().is_empty(), "raccoglitore: +40 cibo a fine stagione (%.1f)" % GameState.risorse.cibo)
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 6), 1.0)
	var r_meta := GameState.aggiungi_gratis("raccoglitore", Vector2i(0, 0), 1.0)
	r_meta.lavoratori = 2
	GameState.risorse.cibo = 50.0  # c'è posto in magazzino
	for i in int(GameState.bil.tick_per_stagione) / 2 - 1:
		GameState._tick()
	var cibo_meta: float = GameState.risorse.cibo
	var pronto_meta: float = GameState.in_arrivo().get("cibo", 0.0)
	GameState._tick()
	_verifica(pronto_meta > 15.0 and GameState.in_arrivo().is_empty() and GameState.risorse.cibo > cibo_meta + pronto_meta - 2.0,
		"a metà stagione arriva la prima metà del raccolto (%.1f)" % pronto_meta)

	# Catena grano -> farina -> pane con ingredienti limitati.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	var m := GameState.aggiungi_gratis("mulino", Vector2i(0, 0), 1.0)
	m.lavoratori = 1
	GameState.abitanti = 0
	GameState.risorse.grano = 10.0
	GameState.risorse.cibo = 0.0
	for i in 60:
		GameState._tick()
	_verifica(absf(GameState.risorse.farina - 10.0) < 0.1 and GameState.risorse.grano < 0.1, "mulino si ferma quando finisce il grano")

	# Inverno: le case bruciano legna; senza legna c'è freddo.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.stagione = GameState.INVERNO
	GameState.risorse.cibo = 1000.0
	GameState.risorse.legna = 20.0
	for i in 41:
		GameState._tick()
	_verifica(GameState.risorse.legna < 0.01, "inverno: 3 case consumano 0,5 legna a tick")
	_verifica(GameState.fattori_felicita().has("Freddo"), "freddo quando la legna finisce")

	# Tasse d'autunno: quelle della stagione, poi il re ne chiede 10.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.stagione = GameState.AUTUNNO
	GameState.risorse.cibo = 1000.0
	for i in 60:
		GameState._tick()
	var attese := 20 + int(GameState.ultime_tasse.monete) + GameState.ultimo_affitto - 10
	_verifica(int(GameState.risorse.oro) == attese and int(GameState.ultime_tasse.monete) > 0, "tasse: 20 + %d + %d dalle case - 10 = %d oro (era %d)" % [GameState.ultime_tasse.monete, GameState.ultimo_affitto, attese, GameState.risorse.oro])
	_verifica(GameState.stagione == GameState.INVERNO, "autunno -> inverno")

	# Due autunni senza pagare: sconfitta.
	var perso := [false]
	GameState.game_ended.connect(func(v, _m): perso[0] = not v)
	GameState.risorse.oro = 0.0
	GameState.tasse = "basse"
	GameState.stagione = GameState.AUTUNNO
	for i in 60:
		GameState._tick()
	_verifica(GameState.tasse_non_pagate == 1 and not perso[0], "primo mancato pagamento: avviso")
	GameState.finita = false
	GameState.stagione = GameState.AUTUNNO
	GameState.tick_in_stagione = 0
	GameState.risorse.cibo = 1000.0
	GameState.risorse.oro = 0.0
	for i in 60:
		GameState._tick()
	_verifica(perso[0], "secondo mancato pagamento: partita persa")

	# Livello Borgo.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	GameState.abitanti = 25
	GameState.felicita = 55.0
	GameState.aggiungi_gratis("magazzino", Vector2i(0, 0), 1.0)
	GameState._controlla_livello()
	_verifica(GameState.livello == 1 and GameState.sbloccato("mulino"), "Borgo sbloccato")

	# Salvataggio e caricamento.
	GameState.nuova_partita(7)
	GameState.abitanti = 10
	GameState.aggiungi_gratis("casa", Vector2i(5, 6), 1.0)
	var t := GameState.piazza("taglialegna", Vector2i(10, 10), 0.5)
	t.progresso = 0.4
	GameState.anno = 3
	GameState.salva()
	GameState.nuova_partita(1)
	_verifica(GameState.carica(), "carica() trova il salvataggio")
	_verifica(GameState.seme_mappa == 7 and GameState.anno == 3 and GameState.buildings.size() == 2, "stato ricaricato")
	_verifica(GameState.buildings[1].cella == Vector2i(10, 10) and absf(GameState.buildings[1].progresso - 0.4) < 0.001, "edificio ricaricato")
	var legna_attesa := int(GameState.bil.risorse_iniziali.legna) - int(GameState.edifici.taglialegna.costo.get("legna", 0))
	_verifica(int(GameState.risorse.legna) == legna_attesa, "costo del taglialegna salvato (legna %d, attesa %d)" % [GameState.risorse.legna, legna_attesa])
	GameState.cancella_salvataggio()

	# Terreno del feudo: piazzamento e sovrapposizioni.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	var terreno := TerrenoFeudo.new(42)
	GameState.terreno = terreno
	var centro := TerrenoFeudo.centro_feudo()
	_verifica(terreno.posizione_valida("casa", centro), "il centro della mappa è libero")
	var casa := GameState.aggiungi_gratis("casa", centro, 1.0)
	_verifica(not terreno.posizione_valida("casa", centro + Vector2i(1, 1)), "niente edifici sovrapposti")
	_verifica(terreno.edificio_a(centro + Vector2i(1, 1)) == casa.id, "la cella sa quale edificio contiene")
	GameState.demolisci(casa.id)
	_verifica(terreno.posizione_valida("casa", centro), "demolendo la cella torna libera")
	var collina := Vector2i(-1, -1)
	for i in terreno.celle.size():
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if terreno.celle[i] == TerrenoFeudo.Tipo.COLLINA and terreno.nel_feudo(c):
			collina = c
			break
	_verifica(collina.x >= 0, "la mappa ha almeno una collina")
	_verifica(not terreno.posizione_valida("miniera", centro), "la miniera non va sull'erba")
	var posto_miniera := terreno.trova_posto("miniera", collina)
	_verifica(posto_miniera.x >= 0 and terreno.tipo_a(posto_miniera) == TerrenoFeudo.Tipo.COLLINA, "la miniera trova posto su una collina")
	var posto := terreno.trova_posto("taglialegna", centro)
	_verifica(posto.x >= 0, "trova_posto trova un posto per il taglialegna")
	GameState.terreno = null

	# Famiglie: tre casate, la popolazione è la somma dei loro membri.
	GameState.nuova_partita(5)
	_verifica(GameState.famiglie.size() == 3, "tre famiglie")
	var somma := 0
	for f in GameState.famiglie:
		somma += int(f.membri)
	_verifica(GameState.abitanti == somma, "abitanti = membri delle famiglie (%d)" % somma)
	_verifica(GameState.capo == -1, "all'inizio nessuno guida")
	var prime := GameState.famiglie.map(func(f): return f.casata)
	GameState.nuova_partita(5)
	_verifica(prime == GameState.famiglie.map(func(f): return f.casata), "stesso seme, stesse casate")

	# Scelta della guida: colori, consiglieri, tratto.
	GameState.nuova_partita(5)
	GameState.famiglie[1].tratto = "boscaioli"
	GameState.scegli_capo(1)
	_verifica(GameState.famiglie[1].colore == "red", "la guida porta il rosso")
	_verifica(str(GameState.consiglieri()) == "[0, 2]", "gli altri due sono consiglieri")
	_verifica(is_equal_approx(GameState.bonus_guida("legna"), 1.2) and is_equal_approx(GameState.bonus_guida("cibo"), 1.0), "il tratto della guida vale per la sua risorsa")
	var tl := GameState.aggiungi_gratis("taglialegna", Vector2i(0, 0), 1.0)
	tl.lavoratori = 2
	GameState.aggiungi_gratis("casa", Vector2i(4, 0), 1.0)  # chi è senza casa se ne va
	GameState.abitanti = 2
	GameState.risorse.cibo = 1000.0
	GameState.risorse.legna = 0.0
	for i in 60:
		GameState._tick()
	_verifica(absf(GameState.risorse.legna - 36.0) < 0.1, "boscaioli: 30 legna diventano 36 (%.1f)" % GameState.risorse.legna)

	# Consiglieri: consigli diversi tra loro, e mai per la guida.
	GameState.nuova_partita(5)
	GameState.scegli_capo(0)
	var c1 := Consiglio.per(1)
	var c2 := Consiglio.per(2)
	_verifica(c1 != "" and c2 != "" and c1 != c2, "i due consiglieri dicono cose diverse")
	_verifica(Consiglio.per(0) == "", "la guida non si consiglia da sola")
	_verifica("raccoglitore" in Consiglio.attivi()[0].testo, "senza cibo il primo consiglio è un raccoglitore")

	# Accampamento iniziale e confine del feudo.
	GameState.ricomincia()
	GameState.avvia()
	var falo := 0
	var tende := 0
	for b in GameState.buildings:
		if b.tipo == "falo":
			falo += 1
		if b.tipo == "tenda" and b.has("famiglia"):
			tende += 1
	_verifica(falo == 1 and tende == 3, "si parte con un falò e una tenda per famiglia")
	_verifica(GameState.alloggi() >= GameState.abitanti, "le tende bastano per tutti")
	var id_falo: int = GameState.buildings[0].id
	GameState.demolisci(id_falo)
	_verifica(not GameState.trova(id_falo).is_empty(), "il falò non si demolisce")
	var t2 := GameState.terreno
	var fuori := TerrenoFeudo.area.position - Vector2i(3, 3)
	_verifica(not t2.posizione_valida("tenda", fuori), "fuori dal feudo non si costruisce")
	_verifica(t2.dentro(fuori), "ma il mondo continua oltre il confine")

	# Salvataggio con famiglie e guida.
	GameState.scegli_capo(2)
	GameState.salva()
	var casate := GameState.famiglie.map(func(f): return f.casata)
	GameState.nuova_partita(1)
	_verifica(GameState.carica(), "carica() con le famiglie")
	_verifica(GameState.capo == 2 and GameState.famiglie.map(func(f): return f.casata) == casate, "guida e casate ricaricate")
	var con_famiglia := GameState.buildings.filter(func(b): return b.has("famiglia")).size()
	_verifica(con_famiglia == 3, "le tende ricordano la loro famiglia")
	GameState.cancella_salvataggio()

	# Zone: il fiume esiste, la fertilità è tra 0 e 1 e più alta vicino all'acqua.
	var tz := TerrenoFeudo.new(11)
	var fiume := 0
	var fert_acqua := 0.0
	var n_acqua := 0
	var fert_secco := 0.0
	var n_secco := 0
	for i in tz.celle.size():
		if tz.celle[i] == TerrenoFeudo.Tipo.FIUME:
			fiume += 1
	for y in range(40, 72):
		for x in range(40, 72):
			var c := Vector2i(x, y)
			if not tz.tipo_a(c) in TerrenoFeudo.COSTRUIBILE:
				continue
			var vicino_acqua := tz.conta_attorno(c, Vector2i.ONE, 2, TerrenoFeudo.Tipo.FIUME) + tz.conta_attorno(c, Vector2i.ONE, 2, TerrenoFeudo.Tipo.ACQUA) > 0
			if vicino_acqua:
				fert_acqua += tz.fertilita_a(c)
				n_acqua += 1
			else:
				fert_secco += tz.fertilita_a(c)
				n_secco += 1
	_verifica(fiume >= TerrenoFeudo.LATO, "c'è un fiume che attraversa il mondo (%d celle)" % fiume)
	_verifica(n_acqua > 0 and fert_acqua / n_acqua > fert_secco / maxf(1, n_secco), "vicino all'acqua la terra è più fertile")

	# Resa a zone.
	GameState.nuova_partita(11)
	GameState.terreno = tz
	var cb := TerrenoFeudo.centro_feudo()
	var r_bosco := tz.info_zona("taglialegna", cb, GameState.PRIMAVERA)
	_verifica(r_bosco.resa >= 0.0 and r_bosco.resa <= 2.0, "resa del taglialegna tra 0 e 2 (%.2f)" % r_bosco.resa)
	var bosco_vicino := Vector2i(-1, -1)
	var max_bosco := -1
	for y in range(36, 76, 2):
		for x in range(36, 76, 2):
			var n := tz.conta_attorno(Vector2i(x, y), Vector2i(2, 2), 5, TerrenoFeudo.Tipo.BOSCO)
			if n > max_bosco and tz.posizione_valida("taglialegna", Vector2i(x, y)):
				max_bosco = n
				bosco_vicino = Vector2i(x, y)
	_verifica(tz.resa("taglialegna", bosco_vicino, 0) > tz.resa("taglialegna", cb, 0) or max_bosco == 0, "più bosco attorno, più legna")
	var lago := Vector2i(-1, -1)
	for i in tz.celle.size():
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if tz.celle[i] == TerrenoFeudo.Tipo.ACQUA and tz.nel_feudo(c):
			lago = c
			break
	var posto_pesca := tz.trova_posto("pescatore", lago)
	var estate := tz.resa("pescatore", posto_pesca, GameState.ESTATE)
	var inverno := tz.resa("pescatore", posto_pesca, GameState.INVERNO)
	_verifica(estate > 0.0 and inverno < estate, "pesca: d'inverno il lago ghiacciato rende meno (%.2f -> %.2f)" % [estate, inverno])
	_verifica(GameState.stima_produzione("taglialegna", bosco_vicino).begins_with("Resa:"), "la stima della resa si legge")
	var stima_campo := GameState.stima_produzione("campo", tz.trova_posto("campo", cb), 1, "rape")
	_verifica("rape a stagione in autunno e inverno" in stima_campo, "il campo dice coltura e stagioni (%s)" % stima_campo)

	# Disboscamento: in 3 anni (12 stagioni) il bosco attorno sparisce.
	var tl3 := GameState.aggiungi_gratis("taglialegna", bosco_vicino, 1.0)
	tl3.lavoratori = 2
	tl3.bosco_iniziale = max_bosco
	var tagliate_tot := [0]
	GameState.terreno_cambiato.connect(func(c): tagliate_tot[0] += c.size())
	for stagioni in 12:
		GameState._disbosca()
	var resta := tz.conta_attorno(bosco_vicino, Vector2i(2, 2), 5, TerrenoFeudo.Tipo.BOSCO)
	_verifica(resta == 0 and tagliate_tot[0] == max_bosco, "dopo 12 stagioni il bosco è finito (%d -> %d)" % [max_bosco, resta])
	_verifica(tz.indici_tagliati.size() == max_bosco, "i tagli sono ricordati per il salvataggio")
	GameState.terreno = null

	# Le tende non si migliorano: durano una stagione e poi vanno sostituite da case.
	GameState.nuova_partita(42)
	var tenda := GameState.aggiungi_gratis("tenda", Vector2i(0, 0), 1.0)
	GameState.risorse.legna = 100.0
	GameState.risorse.pietra = 100.0
	_verifica(GameState.prossimo_miglioramento(tenda).is_empty() and not GameState.puo_migliorare(tenda), "le tende non si migliorano")
	var casa_m := GameState.aggiungi_gratis("casa", Vector2i(3, 0), 1.0)
	var alloggi_prima := GameState.alloggi()
	var prossimo_casa := GameState.prossimo_miglioramento(casa_m)
	GameState.migliora(casa_m.id)
	_verifica(int(casa_m.livello) == 2 and GameState.alloggi() > alloggi_prima, "casa migliorata: più posti")
	_verifica(GameState.risorse.legna == 100.0 - float(prossimo_casa.costo.get("legna", 0)) and GameState.risorse.pietra == 100.0 - float(prossimo_casa.costo.get("pietra", 0)), "i miglioramenti costano legna e pietra")
	var mag := GameState.aggiungi_gratis("magazzino", Vector2i(4, 0), 1.0)
	var cap := GameState.capacita()
	GameState.migliora(mag.id)
	_verifica(GameState.capacita() == cap + 100, "magazzino ampliato: più capacità")
	var rc := GameState.aggiungi_gratis("raccoglitore", Vector2i(8, 0), 1.0)
	rc.lavoratori = 2
	GameState.migliora(rc.id)
	GameState.abitanti = 0
	GameState.risorse.cibo = 0.0
	for i in 60:
		GameState._tick()
	GameState._consegna_raccolti()
	# migliorato: +30%, e ogni lavoratore produce la sua parte: con gli stessi 2 lavoratori 40 × 1,3
	_verifica(absf(GameState.risorse.cibo - 40.0 * 1.3) < 0.2, "raccoglitore migliorato: rende di più anche con gli stessi lavoratori (%.1f)" % GameState.risorse.cibo)
	rc.lavoratori = 3
	GameState.risorse.cibo = 0.0
	GameState.tick_in_stagione = 0
	for i in 60:
		GameState._tick()
	GameState._consegna_raccolti()
	# con il terzo lavoratore: 20 a testa × 3 × 1,3
	_verifica(absf(GameState.risorse.cibo - 20.0 * 3.0 * 1.3) < 0.3, "e con il posto in più ancora di più (%.1f)" % GameState.risorse.cibo)

	# Pietra nei costi: la casa la chiede.
	_verifica(GameState.edifici.casa.costo.has("pietra"), "le case costano anche pietra")

	# Il grano sfama quando il cibo finisce.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	GameState.risorse.cibo = 0.0
	GameState.risorse.grano = 50.0
	GameState._tick()
	_verifica(GameState.tick_fame == 0 and absf(GameState.risorse.grano - 49.0) < 0.01, "senza cibo si mangia il grano")

	# Salvataggio: livelli e tagli del bosco.
	GameState.ricomincia()
	GameState.avvia()
	var t_tenda: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "tenda")[0]
	t_tenda.livello = 3
	GameState.terreno.taglia_bosco(TerrenoFeudo.centro_feudo(), Vector2i.ONE, 15, 5)
	var tagli: int = GameState.terreno.indici_tagliati.size()
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	var ricaricata: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "tenda")[0]
	_verifica(int(ricaricata.livello) == 3, "il livello degli edifici si salva")
	_verifica(GameState.terreno.indici_tagliati.size() == tagli and tagli == 5, "i tagli del bosco si salvano")
	GameState.cancella_salvataggio()

	# Dimora del signore: la tenda della guida diventa una torre attaccata al falò.
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	var dimore := GameState.buildings.filter(func(b): return b.tipo == "dimora")
	var falo_b: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "falo")[0]
	_verifica(dimore.size() == 1 and int(dimore[0].famiglia) == 0, "la guida vive nella dimora del signore")
	_verifica(GameState.buildings.filter(func(b): return b.tipo == "tenda").size() == 2, "le altre due famiglie restano in tenda")
	var dist: Vector2i = (dimore[0].cella - falo_b.cella).abs()
	_verifica(dist.x + dist.y <= 2 and (dist.x == 2 or dist.y == 2), "la dimora è attaccata al falò")
	_verifica(GameState.alloggi() >= GameState.abitanti, "con la dimora c'è posto per tutti")
	var semi_tot := 0.0
	for nome in GameState.nomi_colture():
		semi_tot += GameState.risorse[GameState.colture[nome].semi]
	var attesi := float(GameState.colture.semi_iniziali) if GameState.terreno.selvatica_piu_vicina(TerrenoFeudo.centro_feudo()) != "" else 0.0
	_verifica(semi_tot == attesi, "si parte con i semi della pianta selvatica vicina (%s di %s, seme %d)" % [semi_tot, attesi, GameState.seme_mappa])

	# Popolazione (regole da Borgo in poi): arrivano persone se si è felici e pieni di scorte, e c'è posto.
	GameState.nuova_partita(3)
	GameState.livello = 1
	GameState.abitanti = 4
	GameState.aggiungi_gratis("casa", Vector2i(0, 0), 1.0)
	GameState.aggiungi_gratis("casa", Vector2i(3, 0), 1.0)
	GameState.felicita = 90.0
	GameState.risorse.cibo = 100.0
	_verifica(GameState.calcola_attrattiva() > 0.5, "felici e pieni di cibo: il villaggio attira (%.2f)" % GameState.calcola_attrattiva())
	for i in 40:
		GameState._arrivi()
	_verifica(GameState.abitanti > 4 and GameState.abitanti <= 8, "arriva gente ma solo finché c'è posto (%d)" % GameState.abitanti)
	GameState.risorse.cibo = 0.0
	_verifica(GameState.calcola_attrattiva() == 0.0, "senza scorte non arriva nessuno")
	GameState.risorse.cibo = 100.0
	GameState.felicita = 40.0
	_verifica(GameState.calcola_attrattiva() == 0.0, "scontenti: non arriva nessuno")

	# Forestale: pianta nelle radure, in un anno torna bosco.
	var tf := TerrenoFeudo.new(21)
	var cf := TerrenoFeudo.centro_feudo() + Vector2i(0, 3)
	var tagliate_f := tf.taglia_bosco(cf, Vector2i(2, 2), 12, 6)
	var piantate := tf.pianta(cf, Vector2i(2, 2), 12, 4, 4)
	_verifica(piantate.size() == 4 and piantate.all(func(c): return tagliate_f.has(c)), "il forestale ripianta prima le radure")
	_verifica(not tf.posizione_valida("tenda", piantate[0]), "sulle piantine non si costruisce")
	for st in 3:
		tf.cresci_piantine()
	_verifica(tf.tipo_a(piantate[0]) != TerrenoFeudo.Tipo.BOSCO, "dopo 3 stagioni non è ancora bosco")
	tf.cresci_piantine()
	_verifica(piantate.all(func(c): return tf.tipo_a(c) == TerrenoFeudo.Tipo.BOSCO), "dopo un anno le piantine sono bosco")
	_verifica(tf.indici_tagliati.size() == 2, "le radure ripiantate non sono più radure")

	# Colture: semi, stagioni, zona selvatica.
	GameState.nuova_partita(9)
	GameState.terreno = null
	var campo := GameState.aggiungi_gratis("campo", Vector2i(0, 0), 1.0)
	campo.coltura = "rape"
	campo.lavoratori = 2
	GameState.aggiungi_gratis("casa", Vector2i(4, 0), 1.0)
	GameState.abitanti = 1  # un villaggio vuoto chiude la partita: serve almeno una persona
	GameState.risorse.cibo = 1000.0
	GameState.risorse.semi_rape = 6.0
	GameState.stagione = GameState.ESTATE
	for i in 60:
		GameState._tick()
	_verifica(not campo.get("seminato", false) and GameState.risorse.rape < 0.01, "le rape non si seminano d'estate")
	for i in 10:
		GameState._tick()
	_verifica(campo.get("seminato", false) and GameState.risorse.semi_rape < 0.01, "in autunno si seminano, consumando i semi")
	for i in 50 + 60:
		GameState._tick()
	_verifica(GameState.risorse.rape > 70.0, "le rape crescono in autunno e inverno (%.0f)" % GameState.risorse.rape)
	_verifica(not campo.get("seminato", false) and GameState.risorse.semi_rape >= 9.9, "al raccolto si tengono dei semi")
	var campo2 := GameState.aggiungi_gratis("campo", Vector2i(5, 0), 1.0)
	campo2.coltura = "orzo"
	campo2.lavoratori = 2
	GameState.risorse.semi_orzo = 0.0
	for i in 10:
		GameState._tick()
	_verifica(not campo2.get("seminato", false) and campo2.get("senza_semi", false), "senza semi il campo resta fermo")
	var tw := TerrenoFeudo.new(9)
	var una_selvatica: int = tw.selvatiche.keys()[0]
	var cs := Vector2i(una_selvatica % TerrenoFeudo.LATO, una_selvatica / TerrenoFeudo.LATO)
	_verifica(tw.selvatiche.size() > 0 and tw.selvatica_sotto(cs, Vector2i.ONE) != "", "sulla mappa ci sono piante selvatiche")

	# Mercato: prezzi, compravendita, effetto delle regioni.
	GameState.nuova_partita(4)
	var mc := GameState.mercato
	var g := Regioni.genera(4)
	_verifica(mc.costo_lotto("legna", 0, false) > mc.ricavo_lotto("legna", 0, false), "si compra più caro di quanto si vende")
	_verifica(mc.costo_lotto("legna", 0, true) <= mc.costo_lotto("legna", 0, false), "con un mercato costruito si paga meno")
	GameState.risorse.oro = 100.0
	GameState.risorse.pietra = 0.0
	var prima_oro: float = GameState.risorse.oro
	_verifica(GameState.compra("pietra") and GameState.risorse.pietra == 10.0 and GameState.risorse.oro < prima_oro, "comprare 10 pietra costa oro")
	var prezzo_dopo := mc.prezzo("pietra", 0)
	GameState.compra("pietra")
	_verifica(mc.prezzo("pietra", 0) > prezzo_dopo, "comprare tanto fa salire il prezzo")
	_verifica(GameState.vendi("pietra") and GameState.risorse.pietra == 10.0, "vendere 10 pietra")
	_verifica(mc.prezzo("cibo", GameState.INVERNO) > mc.prezzo("cibo", GameState.ESTATE), "d'inverno il cibo costa di più")
	var eventi := 0
	for anno in 10:
		for st in 4:
			mc.nuova_stagione(4, anno, st)
			if not mc.evento.is_empty():
				eventi += 1
	_verifica(eventi > 5 and eventi < 40, "ogni tanto succede qualcosa nel regno (%d eventi in 40 stagioni)" % eventi)
	_verifica(g.regioni.size() == 10, "il mercato conosce le regioni della mappa")

	# Strade sui bordi delle celle: 1 pietra per tratto in piano, 2 in salita.
	var ts := TerrenoFeudo.new(13)
	var piano := Vector2i(-1, -1)
	for y in range(TerrenoFeudo.area.position.y + 2, TerrenoFeudo.area.end.y - 2):
		for x in range(TerrenoFeudo.area.position.x + 2, TerrenoFeudo.area.end.x - 3):
			var tutte := true
			for dy in range(-2, 2):
				for dx in 3:
					if ts.tipo_a(Vector2i(x + dx, y + dy)) != TerrenoFeudo.Tipo.ERBA or not ts.nel_feudo(Vector2i(x + dx, y + dy)):
						tutte = false
			if tutte and piano.x < 0:
				piano = Vector2i(x, y)
	var percorso := TerrenoFeudo.percorso(piano, piano + Vector2i(2, 0))
	_verifica(ts.costo_strada(percorso) == 2, "due tratti in piano: 2 pietra")
	var collina_s := Vector2i(-1, -1)
	for i in ts.celle.size():
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if ts.celle[i] == TerrenoFeudo.Tipo.COLLINA and ts.nel_feudo(c) and ts.tipo_a(c - Vector2i(0, 1)) == TerrenoFeudo.Tipo.COLLINA:
			collina_s = c
			break
	_verifica(ts.costo_strada([collina_s, collina_s + Vector2i(1, 0)]) == 2, "in salita costa 2 pietra")
	var bordo_collina := Vector2i(-1, -1)
	for i in ts.celle.size():
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if ts.celle[i] == TerrenoFeudo.Tipo.COLLINA and ts.nel_feudo(c) and ts.tipo_a(c - Vector2i(0, 1)) == TerrenoFeudo.Tipo.ERBA:
			bordo_collina = c
			break
	_verifica(not ts.verifica_strada([bordo_collina, bordo_collina + Vector2i(1, 0)]).ok, "niente strade sul bordo di una collina")
	var casa_sopra := piano - Vector2i(0, 1)
	_verifica(ts.posizione_valida("casa", casa_sopra), "prima della strada la casa ci sta")
	ts.aggiungi_strada(percorso)
	_verifica(not ts.posizione_valida("casa", casa_sopra), "una strada non può passare dentro una casa")
	_verifica(ts.posizione_valida("casa", piano) and ts.posizione_valida("casa", piano - Vector2i(0, 2)), "ma le case si accostano alla strada da tutti e due i lati")
	_verifica(ts.costo_strada(percorso) == 0, "una strada già fatta non costa")
	_verifica(ts.vertice_su_strada(piano + Vector2i(1, 0)) and ts.lato_vicino(Vector2(piano) + Vector2(0.5, 0.1)) == TerrenoFeudo.lato(piano, piano + Vector2i(1, 0)), "si trova il tratto di strada toccato")
	# ponti sul fiume
	var sul_fiume := -1
	for i in ts.celle.size():
		var v := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if not ts.nel_feudo(v) or not ts.nel_feudo(v - Vector2i(1, 0)):
			continue
		var k := TerrenoFeudo.lato(v, v + Vector2i(0, 1))
		if ts.tipo_lato(k) == "ponte":
			sul_fiume = k
			break
	var ef := TerrenoFeudo.estremi(sul_fiume)
	var vp := ts.verifica_strada(ef)
	_verifica(vp.ok and vp.ponti == 1 and vp.legna == 3 and vp.pietra == 2, "fra due celle di fiume la strada è un ponte (3 legna, 2 pietra)")
	var cella_fiume: Vector2i = TerrenoFeudo.celle_del_lato(sul_fiume)[1]
	_verifica(not ts.percorribile(cella_fiume), "il fiume senza ponte non si attraversa")
	ts.aggiungi_strada(ef)
	_verifica(ts.percorribile(cella_fiume) and ts.tipo_lato(sul_fiume) == "ponte", "col ponte sì")
	# passerelle sul lago: al massimo 3 tratti di fila
	var fila := Vector2i(-1, -1)
	for y in range(TerrenoFeudo.area.position.y + 1, TerrenoFeudo.area.end.y):
		for x in range(TerrenoFeudo.area.position.x, TerrenoFeudo.area.end.x - 6):
			var tutte := true
			for k in 6:
				if ts.tipo_a(Vector2i(x + k, y)) != TerrenoFeudo.Tipo.ACQUA or ts.tipo_a(Vector2i(x + k, y - 1)) != TerrenoFeudo.Tipo.ACQUA:
					tutte = false
			if tutte and fila.x < 0:
				fila = Vector2i(x, y)
	_verifica(fila.x >= 0, "c'è un lago abbastanza largo")
	if fila.x >= 0:
		var tre := TerrenoFeudo.percorso(fila, fila + Vector2i(3, 0))
		var quattro := TerrenoFeudo.percorso(fila, fila + Vector2i(4, 0))
		var v3 := ts.verifica_strada(tre)
		_verifica(v3.ok and v3.passerelle == 3 and v3.legna == 9 and v3.pietra == 0, "passerella di 3 tratti: 9 legna")
		_verifica(not ts.verifica_strada(quattro).ok, "4 tratti sul lago: troppo lunga")
		ts.aggiungi_strada(tre)
		_verifica(not ts.verifica_strada([fila + Vector2i(3, 0), fila + Vector2i(4, 0)]).ok, "non si allunga una passerella già di 3")

	# Mura in pietra: cella per cella, porte dove passa una strada.
	var tm := TerrenoFeudo.new(13)
	var vm := tm.verifica_mura([piano, piano + Vector2i(1, 0)])
	_verifica(vm.ok and vm.pietra == 2 * TerrenoFeudo.COSTO_MURA, "mura: %d pietra per cella" % TerrenoFeudo.COSTO_MURA)
	tm.aggiungi_mura([piano - Vector2i(0, 1), piano])
	_verifica(not tm.posizione_valida("casa", piano) and not tm.percorribile(piano), "sulle mura non si costruisce e non si passa")
	var porta := tm.verifica_strada([piano, piano + Vector2i(1, 0)])
	_verifica(porta.ok and porta.porte == 1, "una strada fra due celle di mura apre una porta")
	_verifica(not tm.verifica_mura([piano]).ok or tm.verifica_mura([piano]).celle == 0, "le mura già fatte non costano")

	# Rotazione: gli edifici rettangolari si girano.
	_verifica(GameState.taglia_tipo("magazzino", 1) == Vector2i(2, 3) and GameState.taglia_tipo("magazzino", 2) == Vector2i(3, 2), "girato di 90° il magazzino è 2x3")
	GameState.nuova_partita(13)
	GameState.terreno = TerrenoFeudo.new(13)
	GameState.risorse.legna = 100.0
	GameState.risorse.pietra = 100.0
	var posto_g := GameState.terreno.trova_posto("magazzino", TerrenoFeudo.centro_feudo(), 1)
	var mag_g := GameState.piazza("magazzino", posto_g, 1.0, 1)
	_verifica(int(mag_g.rot) == 1 and GameState.terreno.edificio_a(posto_g + Vector2i(1, 2)) == mag_g.id and GameState.terreno.edificio_a(posto_g + Vector2i(2, 0)) != mag_g.id,
		"il magazzino girato occupa 2x3 celle")
	GameState.terreno = null

	# Esercito: i soldati non sono abitanti; l'armeria li addestra uno alla volta, la caserma li tiene.
	GameState.nuova_partita(30)
	_verifica(GameState.regni.size() == 9, "nove regni attorno al nostro")
	GameState.capo = 0
	GameState.livello = 1
	GameState.abitanti = 14
	for i in 4:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	_verifica(GameState.perche_non_addestrare() == "serve una caserma", "senza caserma niente soldati")
	var caserma_b := GameState.aggiungi_gratis("caserma", Vector2i(0, 4), 1.0)
	_verifica(GameState.perche_non_addestrare() == "serve un'armeria", "i lancieri vogliono un'armeria")
	var armeria_b := GameState.aggiungi_gratis("armeria", Vector2i(10, 8), 1.0)
	armeria_b.lavoratori = 2
	GameState.risorse.legna = 100.0
	GameState.risorse.pietra = 100.0
	GameState.risorse.ferro = 10.0
	var liberi := GameState.disoccupati()
	_verifica(GameState.addestra() and GameState.risorse.legna == 98.0 and GameState.risorse.pietra == 99.0 and GameState.soldati == 0,
		"un lanciere in coda: si pagano 2 legna e 1 pietra, ma non è ancora pronto")
	for i in 3:
		GameState._addestra_un_giorno()
	_verifica(GameState.soldati == 1 and int(GameState.truppe.fanti) == 1 and GameState.disoccupati() == liberi and GameState.abitanti == 14,
		"dopo 3 giorni il lanciere è in caserma, e non toglie nessuno al villaggio")
	_verifica(GameState.perche_non_addestrare("arcieri") == "serve l'armeria fornita" and GameState.perche_non_addestrare("spadaccini") == "serve l'armeria fornita",
		"arcieri e spadaccini dal livello 2 dell'armeria")
	armeria_b.livello = 2
	_verifica(GameState.addestra("spadaccini") and GameState.addestra("arcieri") and GameState.risorse.ferro == 8.0 and GameState.risorse.legna == 94.0,
		"con l'armeria fornita spadaccini (1 legna, 2 ferro) e arcieri (3 legna)")
	_verifica(GameState.annulla_addestramento() and GameState.coda_esercito.size() == 1 and GameState.risorse.legna == 97.0,
		"togliendo l'ultimo dalla coda si riavrà il materiale")
	armeria_b.lavoratori = 0
	for i in 10:
		GameState._addestra_un_giorno()
	_verifica(GameState.coda_esercito.size() == 1 and GameState.giorni_al_prossimo_soldato() == -1, "senza lavoratori l'armeria non addestra")
	armeria_b.lavoratori = 2
	for i in 4:
		GameState._addestra_un_giorno()
	_verifica(int(GameState.truppe.get("spadaccini", 0)) == 1 and GameState.coda_esercito.is_empty(), "lo spadaccino è pronto dopo 4 giorni")
	_verifica(GameState.perche_non_addestrare("balestrieri") == "serve l'arsenale" and GameState.perche_non_addestrare("cavalieri") == "serve il grande arsenale",
		"balestrieri dal livello 3, cavalieri dal 4")
	GameState.truppe = {"fanti": 10}
	GameState.soldati = 10
	_verifica(GameState.perche_non_addestrare() == "le caserme sono piene", "una caserma tiene 10 soldati")
	_verifica(is_equal_approx(GameState.difesa().forza_soldati, 50.0), "10 lancieri a casa difendono con 50")
	caserma_b.livello = 4
	_verifica(GameState.posti_esercito() == 25 and GameState.alloggi() == 16, "la caserma migliorata 3 volte tiene 25 soldati (e non ospita abitanti)")
	# il costo: una volta l'anno, soldati / 10 arrotondato, metà cibo e metà oro (l'oro paga il dispari)
	GameState.truppe = {"fanti": 88}
	GameState.soldati = 88
	var costo_e := GameState.costo_annuale_esercito()
	_verifica(int(costo_e.cibo) == 4 and int(costo_e.oro) == 5, "88 soldati costano 9 l'anno: 4 cibo e 5 oro")
	GameState.truppe = {"fanti": 84}
	GameState.soldati = 84
	costo_e = GameState.costo_annuale_esercito()
	_verifica(int(costo_e.cibo) == 4 and int(costo_e.oro) == 4, "84 soldati: 8, cioè 4 e 4")
	for cibo_r in GameState.CIBI:
		GameState.risorse[cibo_r] = 0.0
	GameState.risorse.cibo = 50.0
	GameState.risorse.oro = 50.0
	GameState.stagione = GameState.AUTUNNO
	GameState._fine_stagione()
	_verifica(GameState.stagione == GameState.INVERNO and GameState.soldati == 84 and GameState.risorse.cibo <= 46.0 and GameState.risorse.oro <= 50.0 + 40.0,
		"all'arrivo dell'inverno l'esercito si paga")
	GameState.truppe = {"fanti": 88}
	GameState.soldati = 88
	for cibo_r in GameState.CIBI:
		GameState.risorse[cibo_r] = 0.0
	GameState.risorse.cibo = 4.0
	GameState.risorse.oro = 0.0
	GameState._paga_esercito()
	_verifica(GameState.soldati == 88 - ceili(88.0 * 5.0 / 9.0), "senza oro se ne va la parte non pagata (%d restano)" % GameState.soldati)
	_verifica(GameState.congeda("fanti") and GameState.soldati == 88 - ceili(88.0 * 5.0 / 9.0) - 1, "si congeda un soldato alla volta")
	GameState.truppe = {}
	GameState.soldati = 0

	# Mercato automatico: si vende l'eccesso e si compra quel che manca, tenendo da parte l'oro.
	GameState.imposta_auto("legna", "vendi_sopra", 100)
	GameState.imposta_auto("pietra", "compra_sotto", 50)
	GameState.risorse.legna = 137.0
	GameState.risorse.pietra = 0.0
	GameState.risorse.oro = 200.0
	GameState.mercato_automatico()
	_verifica(GameState.risorse.legna == 137.0 and GameState.risorse.pietra == 0.0, "senza un mercato non va da solo")
	GameState.aggiungi_gratis("mercato", Vector2i(14, 8), 1.0)
	GameState.riserva_oro = 60
	GameState.mercato_automatico()
	_verifica(GameState.risorse.legna == 100.0, "tutto l'eccesso di legna oltre 100 si vende")
	_verifica(GameState.risorse.pietra > 0.0 and GameState.risorse.pietra < 50.0 and GameState.risorse.oro >= 60.0, "si compra pietra senza scendere sotto la riserva d'oro")
	GameState.imposta_auto("legna", "compra_sotto", 200)
	_verifica(int(GameState.mercato_auto.legna.vendi_sopra) == 0, "comprare sopra la soglia di vendita la spegne")
	GameState.imposta_auto("legna", "compra_sotto", 0)
	GameState.imposta_auto("legna", "vendi_sopra", 50)
	GameState.riserva_oro = 0
	GameState.risorse.legna = 90.0
	GameState.risorse.oro = 10.0
	var stagione_m := GameState.stagione
	GameState._fine_stagione()
	_verifica(GameState.stagione != stagione_m and GameState.risorse.legna >= 50.0 and GameState.risorse.legna < 51.0,
		"al cambio di stagione il mercato vende da solo (legna %.1f)" % GameState.risorse.legna)

	# Regni vicini: spie, alleanze, guerra (dal Borgo).
	GameState.livello = 0
	var chiave := ""
	var libera := ""
	var forte := ""
	for k in GameState.regni:
		match GameState.regni[k].tipo:
			"signore":
				if chiave == "":
					chiave = k
				elif forte == "":
					forte = k
			"libera":
				libera = k
	_verifica(GameState.perche_no("spia", chiave) != "", "prima del Borgo niente spie")
	GameState.livello = 1
	GameState.risorse.oro = 100.0
	GameState.bil.diplomazia.spia_scoperta = 0.0
	_verifica(GameState.manda_spia(chiave) and GameState.risorse.oro == 85.0 and not GameState.manda_spia(chiave), "la spia parte (15 oro), una per regno")
	var finite := []
	GameState.missione_finita.connect(func(e): finite.append(e))
	for i in int(GameState.bil.diplomazia.giorni_spia):
		GameState._avanza_missioni()
	_verifica(GameState.regni[chiave].spiato and finite.size() == 1, "dopo un mese la spia torna con le notizie")
	GameState.bil.diplomazia.spia_scoperta = 0.2
	GameState.regni[chiave].atteggiamento = 100
	var alleati_ok := false
	for prova in 5:
		GameState.risorse.oro = 100.0
		GameState.proponi_alleanza(chiave)
		for i in int(GameState.bil.diplomazia.giorni_messaggero):
			GameState._avanza_missioni()
		if GameState.regni[chiave].alleato:
			alleati_ok = true
			break
	_verifica(alleati_ok and GameState.perche_no("attacco", chiave) != "", "un signore amico accetta l'alleanza, e gli alleati non si attaccano")
	_verifica(GameState.difesa().alleati == float(GameState.bil.diplomazia.aiuto_alleato), "gli alleati ci aiutano contro i banditi")
	GameState.soldati = 20
	GameState.truppe = {"fanti": 15, "arcieri": 5}
	GameState.abitanti = 30
	_verifica(GameState.attacca(libera) and GameState.soldati_presenti() == 0, "l'esercito parte tutto")
	for i in int(GameState.bil.diplomazia.giorni_marcia):
		GameState._avanza_missioni()
	var bt: Dictionary = GameState.battaglia
	var cfg_b: Dictionary = GameState.bil.battaglia
	var noi_b := LogicaBattaglia.vive(bt, "noi")
	var loro_b := LogicaBattaglia.vive(bt, "loro")
	_verifica(not bt.is_empty() and GameState.velocita == 0 and bt.fase == "schieramento" and noi_b.size() == 4 and loro_b.size() >= 1, "arrivato l'esercito si schiera sul campo: il tempo si ferma")
	# schieramento: si sposta solo nella zona, scambiandosi con le nostre unità
	var zona_b := LogicaBattaglia.zona_schieramento(bt, cfg_b)
	_verifica(zona_b.all(func(c): return c.x < int(cfg_b.zona_schieramento)) and noi_b.all(func(u): return zona_b.has(LogicaBattaglia.cella(u))), "le nostre unità partono nella zona di schieramento")
	var primo_b: Dictionary = noi_b[0]
	var secondo_b: Dictionary = noi_b[1]
	var cella_1 := LogicaBattaglia.cella(primo_b)
	var cella_2 := LogicaBattaglia.cella(secondo_b)
	_verifica(GameState.battaglia_schiera(int(primo_b.id), cella_2) and LogicaBattaglia.cella(primo_b) == cella_2 and LogicaBattaglia.cella(secondo_b) == cella_1, "schierando su una nostra unità le due si scambiano")
	_verifica(not GameState.battaglia_schiera(int(primo_b.id), Vector2i(LogicaBattaglia.LARGHEZZA - 1, 0)), "fuori dalla zona non si schiera")
	_verifica(GameState.battaglia_muovi(int(primo_b.id), cella_1).is_empty(), "durante lo schieramento non si combatte")
	GameState.battaglia_inizia()
	_verifica(bt.fase == "noi" and not GameState.battaglia_schiera(int(primo_b.id), cella_1), "iniziata la battaglia lo schieramento è chiuso")
	_verifica(noi_b.any(func(u): return u.tipo == "arcieri") and noi_b.any(func(u): return u.tipo == "fanti"), "in campo lancieri e arcieri")
	_verifica(GameState.soldati_presenti() == 0, "in battaglia i soldati non sono a casa")
	_verifica(LogicaBattaglia.distanza(Vector2i(0, 0), Vector2i(2, 1)) == 2 and LogicaBattaglia.vicini(Vector2i(3, 3)).size() == 8, "griglia: le diagonali contano come un passo, otto vicini")
	var fante: Dictionary = noi_b.filter(func(u): return u.tipo == "fanti")[0]
	var dove_b: Dictionary = LogicaBattaglia.raggiungibili(bt, fante, cfg_b)
	var meta_b: Vector2i = dove_b.keys()[0]
	var mosse_prima := int(fante.mosse)
	_verifica(not GameState.battaglia_muovi(int(fante.id), meta_b).is_empty() and LogicaBattaglia.cella(fante) == meta_b and int(fante.mosse) < mosse_prima, "un'unità si muove e spende le mosse")
	# mettiamo un fante accanto a un nemico indebolito: l'attacco lo distrugge e la battaglia è vinta
	for u in loro_b:
		u.uomini = 0
	var ultimo_n: Dictionary = loro_b[0]
	ultimo_n.uomini = 1
	var accanto: Vector2i = LogicaBattaglia.vicini(LogicaBattaglia.cella(ultimo_n)).filter(func(c): return LogicaBattaglia.occupante(bt, c) < 0)[0]
	fante.cella = [accanto.x, accanto.y]
	fante.attaccato = false
	var e_b := GameState.battaglia_attacca(int(fante.id), int(ultimo_n.id))
	_verifica(not e_b.is_empty() and int(e_b.morti_difensore) >= 1 and bt.finita and bt.vinta, "distrutto l'esercito nemico, la battaglia è vinta")
	GameState.chiudi_battaglia()
	_verifica(GameState.battaglia.is_empty() and GameState.velocita > 0, "finita la battaglia il tempo riparte")
	var conquista: Dictionary = GameState.regni[libera]
	_verifica(conquista.conquistato and int(conquista.vassallo) in GameState.consiglieri(), "vinta la terra libera: un consigliere ne è vassallo")
	_verifica(GameState.soldati_presenti() > 0 and GameState.soldati <= 20, "i soldati tornano (%d)" % GameState.soldati)
	var oro_t: float = GameState.risorse.oro
	GameState._riscuoti_tributi()
	_verifica(GameState.risorse.oro == oro_t + float(GameState.bil.diplomazia.tributo_oro) + float(GameState.bil.diplomazia.dono_alleato_stagione), "tributo della conquista e dono dell'alleato")
	# la bandiera: chi la tiene per un turno vince
	GameState.soldati = 10
	GameState.abitanti = 30
	GameState.attacca(forte)
	for i in int(GameState.bil.diplomazia.giorni_marcia):
		GameState._avanza_missioni()
	var bf: Dictionary = GameState.battaglia
	var bandiera_b := Vector2i(int(bf.bandiera[0]), int(bf.bandiera[1]))
	var loro_f := LogicaBattaglia.vive(bf, "loro")
	for k in loro_f.size():
		loro_f[k].uomini = 1 if k == 0 else 0
	loro_f[0].cella = [0, 0]
	var nostro_f: Dictionary = LogicaBattaglia.vive(bf, "noi")[0]
	nostro_f.cella = [bandiera_b.x, bandiera_b.y]
	GameState.battaglia_inizia()
	GameState.battaglia_fine_turno()
	_verifica(bf.finita and bf.vinta and GameState.regni[forte].conquistato, "presa e tenuta la loro bandiera: vittoria")
	GameState.chiudi_battaglia()
	GameState.regni[forte].conquistato = false
	# niente limite di turni: si combatte finché un esercito cade (il nemico, dopo un po', attacca)
	GameState.soldati = 10
	GameState.attacca(forte)
	for i in int(GameState.bil.diplomazia.giorni_marcia):
		GameState._avanza_missioni()
	GameState.battaglia_inizia()
	for turno_b in 8:
		if not GameState.battaglia.finita:
			GameState.battaglia_fine_turno()
	var bl: Dictionary = GameState.battaglia
	_verifica(bl.finita or int(bl.turno) > 8, "niente limite di turni: dopo 8 turni si combatte ancora (turno %d)" % int(bl.turno))
	var vicino_l := 99
	for u in LogicaBattaglia.vive(bl, "loro"):
		for v in LogicaBattaglia.vive(bl, "noi"):
			vicino_l = mini(vicino_l, LogicaBattaglia.distanza(LogicaBattaglia.cella(u), LogicaBattaglia.cella(v)))
	if bl.get("assedio", false):
		var band_l := Vector2i(int(bl.bandiera[0]), int(bl.bandiera[1]))
		_verifica(bl.finita or LogicaBattaglia.vive(bl, "loro").all(func(u): return LogicaBattaglia.distanza(LogicaBattaglia.cella(u), band_l) <= 2), "chi è assediato resta dietro le mura")
	else:
		_verifica(bl.finita or vicino_l <= 2, "dopo qualche turno il nemico va all'assalto (distanza %d)" % vicino_l)
	GameState.chiudi_battaglia()
	_prova_forze()
	_prova_assedio()
	_prova_sviluppo_regni()
	_prova_fiume()
	var soldati_r := GameState.soldati
	GameState.attacca(forte)
	for i in int(GameState.bil.diplomazia.giorni_marcia):
		GameState._avanza_missioni()
	GameState.battaglia_ritirata()
	_verifica(GameState.battaglia.finita and not GameState.battaglia.vinta and GameState.soldati == soldati_r, "la ritirata subito salva tutti")
	GameState.chiudi_battaglia()

	# Vassalli: tributo, lealtà, ribellione.
	var chiave_v := libera
	_verifica(GameState.regni[chiave_v].conquistato and int(GameState.regni[chiave_v].lealta) >= int(GameState.bil.vassalli.lealta_consigliere), "il consigliere vassallo parte leale")
	var tributo_normale := GameState.tributo_di(chiave_v)
	GameState.imposta_tributo(chiave_v, "alto")
	_verifica(int(GameState.tributo_di(chiave_v).oro) > int(tributo_normale.oro), "un tributo alto manda più oro")
	var leale_prima := int(GameState.regni[chiave_v].lealta)
	GameState._riscuoti_tributi()
	_verifica(int(GameState.regni[chiave_v].lealta) < leale_prima, "ma la lealtà scende")
	var vassallo_v := int(GameState.regni[chiave_v].vassallo)
	_verifica(GameState.forza_esercito(5) > 5 * float(GameState.bil.esercito.forza_per_soldato), "il vassallo manda truppe in battaglia")
	_verifica(GameState.difesa().vassalli > 0.0, "e contro i banditi")
	GameState.regni[chiave_v].lealta = 0
	for i in 20:
		if GameState.regni[chiave_v].conquistato:
			GameState._riscuoti_tributi()
	_verifica(not GameState.regni[chiave_v].conquistato and not vassallo_v in GameState.consiglieri(), "con lealtà a zero il vassallo si ribella e lascia il consiglio")

	# Miglioramenti: fino a 4 lavoratori per le strutture, 8 abitanti per le case.
	var al_massimo := true
	for tipo in GameState.edifici:
		var dd: Dictionary = GameState.edifici[tipo]
		var mig: Array = dd.get("miglioramenti", [])
		if int(dd.lavoratori) > 0 and tipo != "rovine":
			if mig.is_empty() or int(mig[mig.size() - 1].get("lavoratori", dd.lavoratori)) != 4:
				al_massimo = false
	_verifica(al_massimo, "ogni struttura con lavoratori arriva a 4 posti migliorandola")
	_verifica(int(GameState.edifici.casa.miglioramenti[1].alloggi) == 8, "la casa in pietra ospita 8 persone")

	# Tributo delle case: 1 moneta fino a 4 posti, 2 fino a 6, 3 fino a 8 (solo se abitate).
	GameState.nuova_partita(50)
	GameState.aggiungi_gratis("casa", Vector2i(0, 0), 1.0)
	var casa_6 := GameState.aggiungi_gratis("casa", Vector2i(3, 0), 1.0)
	var casa_8 := GameState.aggiungi_gratis("casa", Vector2i(6, 0), 1.0)
	casa_6.livello = 2
	casa_8.livello = 3
	GameState.abitanti = 4 + 6 + 8
	_verifica(GameState.tributo_case() == 1 + 2 + 3, "case piene: 1 + 2 + 3 monete (%d)" % GameState.tributo_case())
	GameState.abitanti = 5
	_verifica(GameState.tributo_case() == 1 + 2, "la casa vuota non paga (%d)" % GameState.tributo_case())

	# Il re: si paga fino al Borgo, poi siamo indipendenti e lui diffida.
	GameState.nuova_partita(51)
	GameState.capo = 0
	GameState.abitanti = 10
	_verifica(not GameState.indipendente() and GameState.tassa_del_re() > 0 and GameState.stagioni_al_re() == 2, "da villaggio il re vuole la sua tassa in autunno")
	GameState.livello = 0
	GameState.bil.livelli[1].abitanti = 1
	GameState.bil.livelli[1].felicita = 0
	GameState.bil.livelli[1].edifici = {}
	GameState._controlla_livello()
	_verifica(GameState.indipendente() and GameState.re_atteggiamento < 0 and GameState.evento_attivo.get("id", "") == "indipendenza", "diventati Borgo: indipendenti, e il re diffida")
	GameState.scegli_evento(0)
	GameState.stagione = GameState.AUTUNNO
	var oro_re: float = GameState.risorse.oro
	GameState._riscuoti_tasse()
	_verifica(GameState.risorse.oro >= oro_re and GameState.tasse_non_pagate == 0, "in autunno niente più tasse al re")
	GameState.re_atteggiamento = -100
	GameState.bil.re.probabilita_spedizione = 1.0
	GameState._il_re_si_fa_sentire()
	_verifica(not GameState.banditi.is_empty() and GameState.banditi.get("regio", false), "un re molto ostile manda il suo esercito")
	GameState.bil.re.probabilita_spedizione = 0.5
	GameState.bil.livelli[1].abitanti = 25
	GameState.bil.livelli[1].felicita = 50
	GameState.bil.livelli[1].edifici = {"magazzino": 1}

	# Il primo inverno, se finisce il cibo, il signore apre il castello: +50, una volta, e nessuno se ne va.
	GameState.nuova_partita(40)
	GameState.capo = 0
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.stagione = GameState.INVERNO
	for cibo_v in GameState.CIBI:
		GameState.risorse[cibo_v] = 0.0
	GameState._tick()
	_verifica(GameState.aiuto_inverno_dato and GameState.evento_attivo.get("id", "") == "aiuto_inverno" and GameState.risorse.cibo > 45.0,
		"primo inverno senza cibo: il castello apre le dispense (+50)")
	_verifica(int(GameState.evento_attivo.narratore) == GameState.capo, "lo annuncia la guida")
	GameState.scegli_evento(0)
	for cibo_v in GameState.CIBI:
		GameState.risorse[cibo_v] = 0.0
	for i in 40:
		GameState._tick()
	_verifica(GameState.abitanti == 10 and GameState.risorse.cibo < 1.0, "il primo anno nessuno se ne va per la fame, e l'aiuto non torna")
	GameState.nuova_partita(40)
	GameState.capo = 0
	GameState.anno = 2
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.stagione = GameState.INVERNO
	for cibo_v in GameState.CIBI:
		GameState.risorse[cibo_v] = 0.0
	for i in 12:
		GameState._tick()
	_verifica(not GameState.aiuto_inverno_dato and GameState.abitanti < 10, "dal secondo anno la fame fa partire la gente")

	# Le carte evento non bloccano mai il gioco.
	GameState.nuova_partita(41)
	GameState.capo = 0
	for ris_v in GameState.RISORSE:
		GameState.risorse[ris_v] = 0.0
	var tutte_ok := GameState.carte_possibili().all(func(c): return c.scelte.any(func(sc): return GameState._effetti_possibili(sc.effetti)))
	_verifica(tutte_ok and not GameState.carte_possibili().any(func(c): return c.id == "mercante"), "senza risorse escono solo carte in cui si può scegliere qualcosa")
	var carta_m: Dictionary = GameState.dati_eventi.carte.filter(func(c): return c.id == "mercante")[0]
	GameState.mostra_evento(carta_m)
	_verifica(GameState.evento_senza_scelta(), "una carta rimasta senza scelte possibili...")
	GameState.scegli_evento(-1)
	_verifica(GameState.evento_attivo.is_empty() and GameState.velocita > 0, "...si chiude senza effetti e il tempo riparte")

	# Tutorial e suggerimenti.
	GameState.nuova_partita(42)
	GameState.capo = 0
	GameState.inizia_tutorial()
	_verifica(GameState.tutorial_passo == 0 and GameState.dati_tutorial.size() >= 8, "il tutorial parte dal primo passo")
	GameState.avanti_tutorial()
	_verifica(GameState.tutorial_passo == 1, "Avanti sui passi da leggere")
	GameState.avanti_tutorial()
	_verifica(GameState.tutorial_passo == 1, "ma non su quelli che chiedono un'azione")
	GameState.aggiungi_gratis("taglialegna", Vector2i(0, 0), 1.0)
	GameState.aggiungi_gratis("casa", Vector2i(3, 0), 1.0)
	GameState.aggiungi_gratis("casa", Vector2i(6, 0), 1.0)
	GameState.abitanti = 5
	GameState.risorse.cibo = 100.0
	GameState._tick()
	_verifica(GameState.tutorial_passo == 2, "costruito il taglialegna, si passa al raccoglitore")
	GameState.salta_tutorial()
	_verifica(GameState.tutorial_passo == -1, "il tutorial si salta")
	var detti := []
	GameState.suggerimento.connect(func(t): detti.append(t))
	GameState.dati_eventi.probabilita_per_stagione = 0.0
	GameState._tick_evento = -1
	for i in int(GameState.bil.suggerimenti.ogni) * 2:
		GameState._tick()
	_verifica(detti.size() == 2 and detti[0] != detti[1], "ogni tanto un suggerimento, sempre diverso (%d)" % detti.size())
	GameState.suggerimenti_attivi = false
	for i in int(GameState.bil.suggerimenti.ogni) * 2:
		GameState._tick()
	_verifica(detti.size() == 2, "i suggerimenti si spengono")
	GameState.dati_eventi.probabilita_per_stagione = 0.85

	# Dove si è tagliato il bosco restano i ceppi: si costruisce dalla stagione dopo.
	var tc := TerrenoFeudo.new(13)
	var bosco_c := Vector2i(-1, -1)
	for i in tc.celle.size():
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if tc.celle[i] == TerrenoFeudo.Tipo.BOSCO and tc.nel_feudo(c):
			bosco_c = c
			break
	var tagliata := tc.taglia_bosco(bosco_c, Vector2i.ONE, 0, 1)
	_verifica(tagliata.size() == 1 and tc.ceppi.has(bosco_c.y * TerrenoFeudo.LATO + bosco_c.x), "tagliato il bosco restano i ceppi")
	_verifica(not tc.posizione_valida("palizzata", bosco_c), "sui ceppi non si costruisce")
	var libere := tc.togli_ceppi()
	_verifica(libere.has(bosco_c) and tc.posizione_valida("palizzata", bosco_c) == (bosco_c != Vector2i(-1, -1) and tc.tipo_a(bosco_c) in TerrenoFeudo.COSTRUIBILE), "dopo una stagione la cella si può costruire")
	var salvato_t := tc.salva()
	var tc2 := TerrenoFeudo.new(13)
	tc.taglia_bosco(bosco_c + Vector2i(1, 0), Vector2i.ONE, 1, 1)
	tc2.applica_salvataggio(tc.salva())
	_verifica(tc2.ceppi.size() == tc.ceppi.size() and not salvato_t.is_empty(), "i ceppi si salvano")

	# Prova battaglia: senza partita, e non cambia niente.
	GameState.nuova_partita(60)
	var soldati_pr := GameState.soldati
	var abitanti_pr := GameState.abitanti
	GameState.inizia_prova_battaglia({"nemico": "banditi", "fanti": 10, "arcieri": 5, "vassalli": 5, "nemici": 12})
	var bp: Dictionary = GameState.battaglia
	_verifica(bp.prova and LogicaBattaglia.vive(bp, "noi").size() == 4 and LogicaBattaglia.vive(bp, "loro").size() == 3, "la prova schiera gli eserciti scelti")
	for u in LogicaBattaglia.vive(bp, "noi"):
		u.uomini = 0
	LogicaBattaglia._controlla_fine(bp)
	GameState._dopo_azione()
	_verifica(bp.finita and GameState.soldati == soldati_pr and GameState.abitanti == abitanti_pr, "perdere la prova non toglie nessuno alla partita")
	GameState.chiudi_battaglia()
	_verifica(GameState.battaglia.is_empty(), "chiusa la prova non resta niente")

	# Salvataggio della versione 8: esercito, regni, missioni, ponti, mura, rotazione.
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	GameState.livello = 1
	GameState.soldati = 5
	var prima_k: String = GameState.regni.keys()[0]
	GameState.regni[prima_k].spiato = true
	GameState.risorse.oro = 100.0
	GameState.manda_spia(GameState.regni.keys()[1])
	var rac_s := GameState.aggiungi_gratis("raccoglitore", GameState.terreno.trova_posto("raccoglitore", TerrenoFeudo.centro_feudo()), 1.0)
	rac_s.pronto = {"cibo": 12.5}
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	_verifica(GameState.soldati == 5 and GameState.regni[prima_k].spiato and GameState.missioni.size() == 1, "esercito, regni e missioni si salvano")
	_verifica(is_equal_approx(float(GameState.in_arrivo().get("cibo", 0.0)), 12.5), "il raccolto della stagione si salva")
	GameState.risorse.cibo = GameState.capacita() - 5.0
	GameState._consegna_raccolti()
	_verifica(GameState.risorse.cibo == GameState.capacita() and GameState.in_arrivo().is_empty(), "col magazzino pieno il raccolto in più si perde")
	GameState.cancella_salvataggio()

	# Salvataggio della versione 4: strade, piantine, colture, mercato.
	GameState.ricomincia()
	GameState.avvia()
	var c0 := TerrenoFeudo.centro_feudo() + Vector2i(6, 6)
	GameState.risorse.pietra = 50.0
	var strada_ok := false
	for dy in 10:
		var inizio_s := GameState.terreno.trova_posto("casa", c0 + Vector2i(0, dy))
		if not strada_ok:
			strada_ok = GameState.costruisci_strada(TerrenoFeudo.percorso(inizio_s, inizio_s + Vector2i(2, 0)))
	GameState.terreno.taglia_bosco(TerrenoFeudo.centro_feudo(), Vector2i.ONE, 15, 3)
	GameState.terreno.pianta(TerrenoFeudo.centro_feudo(), Vector2i.ONE, 15, 2, 4)
	var cmp := GameState.aggiungi_gratis("campo", GameState.terreno.trova_posto("campo", c0 + Vector2i(4, 0)), 1.0)
	cmp.coltura = "grano"
	cmp.seminato = true
	GameState.mercato.fattori.legna = 1.37
	var n_strade := GameState.terreno.strade.size()
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	_verifica(strada_ok and GameState.terreno.strade.size() == n_strade and n_strade > 0, "le strade si salvano")
	_verifica(GameState.terreno.piantine.size() == 2, "le piantine si salvano")
	var cmp2: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "campo")[0]
	_verifica(cmp2.coltura == "grano" and cmp2.seminato, "coltura e semina si salvano")
	_verifica(is_equal_approx(GameState.mercato.fattori.legna, 1.37), "i prezzi del mercato si salvano")
	GameState.cancella_salvataggio()

	# Strada iniziale, tende che si strappano, piazza dopo un anno.
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(1)
	var dimora: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "dimora")[0]
	var tocca := false
	for v in GameState._bordo(dimora):
		tocca = tocca or GameState.terreno.vertice_su_strada(v)
	_verifica(GameState.terreno.strade.size() == int(GameState.bil.strade.strada_iniziale) and tocca, "dalla dimora parte una strada corta")
	var tende_prima := GameState.buildings.filter(func(b): return b.tipo == "tenda").size()
	GameState.abitanti = 4
	GameState._fine_stagione()
	_verifica(tende_prima == 2 and GameState.buildings.filter(func(b): return b.tipo == "tenda").is_empty(), "dopo una stagione le tende si strappano")
	var tenda_tardi := GameState.piazza("tenda", GameState.terreno.trova_posto("tenda", TerrenoFeudo.centro_feudo() + Vector2i(6, 0)), 1.0)
	GameState.tick_in_stagione = 40
	tenda_tardi.progresso = 1.0
	GameState._completa(tenda_tardi)
	GameState._fine_stagione()
	_verifica(GameState.buildings.has(tenda_tardi), "una tenda finita a stagione inoltrata regge anche la stagione dopo")
	GameState._fine_stagione()
	_verifica(not GameState.buildings.has(tenda_tardi), "...poi si strappa")
	GameState.stagione = GameState.INVERNO
	GameState._fine_stagione()
	_verifica(GameState.anno == 2 and GameState.buildings.filter(func(b): return b.tipo == "piazza").size() == 1 \
		and GameState.buildings.filter(func(b): return b.tipo == "falo").is_empty(), "dopo un anno il falò diventa la piazza")

	# Collegamento alla piazza: senza strada si lavora il 2% in meno.
	var piazza_b: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "piazza")[0]
	# un posto davvero lontano dalle strade (su alcune mappe la strada iniziale passa vicino)
	var lontano: Dictionary = {}
	for scarto in [Vector2i(0, 9), Vector2i(9, 0), Vector2i(-9, 0), Vector2i(0, -9), Vector2i(12, 12), Vector2i(-12, 12), Vector2i(12, -12)]:
		if not lontano.is_empty():
			if not GameState.collegato(lontano):
				break
			GameState.buildings.erase(lontano)
			GameState.terreno.libera(lontano)
			GameState._rete_valida = false
		lontano = GameState.aggiungi_gratis("raccoglitore", GameState.terreno.trova_posto("raccoglitore", piazza_b.cella + scarto), 1.0)
	_verifica(not GameState.collegato(lontano) and is_equal_approx(GameState.efficienza(lontano), 0.98), "lontano dalle strade: -2%")
	_verifica(GameState.collegato(dimora) and GameState.collegato(piazza_b), "piazza e dimora sono il centro")
	# la strada si trova da sola: dalla rete collegata fino al bordo dell'edificio, girando attorno agli ostacoli
	var auto := GameState.strada_per(lontano)
	var v_auto := GameState.verifica_strada(auto)
	_verifica(auto.size() >= 2 and v_auto.ok and GameState._rete_strade.has(auto[0]) and GameState._bordo(lontano).has(auto[-1]),
		"il percorso automatico va dalla rete all'edificio (%d tratti)" % (auto.size() - 1))
	GameState.risorse.pietra = 200.0
	GameState.risorse.legna = 200.0
	_verifica(GameState.costruisci_strada(auto) and GameState.collegato(lontano) and is_equal_approx(GameState.efficienza(lontano), 1.0), "con la strada fino alla piazza il malus sparisce")
	_verifica(GameState.strada_per(lontano).size() == 1, "un edificio già collegato non chiede strade")
	# un ostacolo sul percorso dritto: il percorso lo aggira
	var tz_r := GameState.terreno
	var muro_case := tz_r.trova_posto("casa", piazza_b.cella + Vector2i(8, -6))
	if muro_case.x >= 0:
		var casa_r := GameState.aggiungi_gratis("casa", muro_case, 1.0)
		var attorno: Array[Vector2i] = []
		var tc_r := GameState.taglia_di(casa_r)
		# un punto qualsiasi attorno alla casa (a 1-3 celle dal bordo) a cui si arriva
		for d in range(1, 4):
			if attorno.size() >= 2:
				break
			for dy in range(-d, tc_r.y + d + 1):
				for dx in range(-d, tc_r.x + d + 1):
					if attorno.size() >= 2:
						break
					if dx > -d and dx < tc_r.x + d and dy > -d and dy < tc_r.y + d:
						continue
					attorno = GameState.strada_verso([muro_case + Vector2i(dx, dy)])
		var dentro := false
		for k in TerrenoFeudo.lati_di(attorno):
			var cc: Array[Vector2i] = TerrenoFeudo.celle_del_lato(k)
			dentro = dentro or (tz_r.edificio_a(cc[0]) == casa_r.id and tz_r.edificio_a(cc[1]) == casa_r.id)
		_verifica(attorno.size() >= 2 and not dentro and GameState.verifica_strada(attorno).ok, "il percorso automatico non attraversa le case")
	else:
		_verifica(false, "posto per la casa del test sulle strade")

	# Senza casa: mezza stagione, poi se ne vanno.
	GameState.nuova_partita(5)
	GameState.aggiungi_gratis("casa", Vector2i(0, 0), 1.0)
	GameState.abitanti = GameState.alloggi() + 3
	GameState.risorse.cibo = 1000.0
	var limite := int(GameState.bil.senza_casa.tick_prima_di_andarsene)
	for i in limite - 1:
		GameState._tick()
	var ancora := GameState.abitanti
	GameState._tick()
	_verifica(ancora == GameState.alloggi() + 3 and GameState.abitanti == GameState.alloggi(), "chi è senza casa se ne va dopo mezza stagione (%d -> %d)" % [ancora, GameState.abitanti])

	# Carte evento raccontate dai consiglieri.
	GameState.nuova_partita(8)
	GameState.capo = 0
	var carte := {}
	for carta in GameState.dati_eventi.carte:
		carte[carta.id] = carta
	_verifica(carte.size() >= 10, "ci sono le carte evento (%d)" % carte.size())
	GameState.risorse.legna = 0.0
	GameState.mostra_evento(carte.eremo)
	var narra := int(GameState.evento_attivo.narratore)
	_verifica(GameState.velocita == 0 and narra in GameState.consiglieri(), "la carta la racconta un consigliere e il tempo si ferma")
	_verifica(not GameState.scelta_possibile(0) and GameState.scelta_possibile(1), "le scelte troppo care sono disattivate")
	GameState.risorse.legna = 30.0
	var fel := GameState.felicita
	GameState.scegli_evento(0)
	_verifica(GameState.risorse.legna == 10.0 and GameState.felicita == fel + 10.0 and GameState.velocita > 0 and GameState.evento_attivo.is_empty(), "la scelta applica i suoi effetti")
	GameState.mostra_evento(carte.lupi)
	GameState.scegli_evento(1)
	_verifica(GameState.molt_modificatore("edificio", "taglialegna") == 0.5 and GameState.molt_modificatore("edificio", "cava") == 1.0, "un effetto può rallentare un edificio")
	var tassa := GameState.tassa_del_re()
	GameState.mostra_evento(carte.matrimonio)
	GameState.risorse.oro = 30.0
	GameState.scegli_evento(0)
	_verifica(GameState.tassa_del_re() == int(tassa * 0.5), "il dono alle nozze dimezza la tassa del re")
	GameState._scadono_modificatori()
	_verifica(GameState.molt_modificatore("edificio", "taglialegna") == 1.0 and GameState.modificatori.size() == 1, "gli effetti scadono con le stagioni")
	GameState.stagione = GameState.PRIMAVERA
	var ids := GameState.carte_possibili().map(func(c): return c.id)
	_verifica(not "festa" in ids and not "eremo" in ids and not "lupi" in ids, "le carte seguono stagione ed edifici, e non si ripetono")
	var programmate := 0
	for i in 20:
		GameState._programma_evento()
		if GameState._tick_evento > 0 and GameState._tick_evento < int(GameState.bil.tick_per_stagione):
			programmate += 1
	_verifica(programmate >= 10, "quasi ogni stagione arriva una carta (%d su 20)" % programmate)
	GameState.mostra_evento(carte.profughi)
	var gente := GameState.abitanti
	GameState.risorse.cibo = 50.0
	GameState.scegli_evento(0)
	_verifica(GameState.abitanti == gente + 4, "accogliere i profughi porta gente")

	# Salvataggio della versione 5: effetti, carte uscite, età delle tende.
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	GameState.modificatori = [{"coltura": true, "molt": 1.3, "stagioni": 1}]
	GameState.eventi_usati = ["festa"]
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	_verifica(GameState.modificatori.size() == 1 and GameState.eventi_usati == ["festa"], "effetti e carte uscite si salvano")
	_verifica(GameState.terreno.strade.size() == int(GameState.bil.strade.strada_iniziale), "la strada iniziale si salva")
	GameState.cancella_salvataggio()

	# Tasse ogni stagione: fascia secondo risorse, popolazione e gradimento.
	GameState.nuova_partita(12)
	GameState.abitanti = 10
	GameState.felicita = 100.0
	GameState.risorse.cibo = 500.0
	GameState.risorse.legna = 100.0
	GameState.risorse.pietra = 100.0
	GameState.abitanti = 25
	var alta := GameState.valutazione_tasse()
	GameState.abitanti = 10
	GameState.stagione = GameState.INVERNO
	GameState.felicita = 100.0
	var v_alta := GameState.valutazione_tasse()
	_verifica(alta.fascia == 3, "tutto bene: fascia massima")
	GameState.abitanti = 10
	GameState.felicita = 90.0
	GameState.risorse.pietra = 100.0
	var inv := GameState.valutazione_tasse()
	GameState.stagione = GameState.PRIMAVERA
	var pri := GameState.valutazione_tasse()
	_verifica(inv.monete == int(GameState.bil.tasse_stagionali.monete.inverno[inv.fascia]) and pri.monete == int(GameState.bil.tasse_stagionali.monete.primavera[pri.fascia]),
		"le monete dipendono da stagione e fascia (inverno %d, primavera %d)" % [inv.monete, pri.monete])
	GameState.felicita = 10.0
	GameState.risorse.cibo = 0.0
	GameState.risorse.legna = 0.0
	GameState.risorse.pietra = 0.0
	GameState.abitanti = 3
	var bassa := GameState.valutazione_tasse()
	_verifica(bassa.fascia == 0 and bassa.monete == 1, "villaggio in miseria: fascia bassa, 1 moneta")
	GameState.abitanti = 30
	GameState.felicita = 100.0
	GameState.risorse.cibo = 1000.0
	GameState.risorse.legna = 100.0
	GameState.risorse.pietra = 100.0
	GameState.stagione = GameState.INVERNO
	var grande := GameState.valutazione_tasse()
	_verifica(grande.monete == 15 and v_alta.monete >= 4, "più abitanti, più monete: 30 abitanti in inverno al massimo = 15 (%d)" % grande.monete)
	GameState.tasse = "alte"
	_verifica(GameState.valutazione_tasse().monete > grande.monete, "tasse alte: più oro")
	var oro_prima: float = GameState.risorse.oro
	GameState.stagione = GameState.PRIMAVERA
	GameState._riscuoti_tasse()
	_verifica(GameState.risorse.oro > oro_prima, "a fine primavera si incassa")

	# Prima del Borgo la gente arriva più in fretta: da 10 a 25 in un anno e mezzo, due.
	var stagioni_per_borgo: Array[int] = []
	for seme in [1, 2, 3, 4, 5]:
		GameState.nuova_partita(seme)
		GameState.abitanti = 10
		GameState.felicita = 56.0
		for i in 7:
			GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
		var stagioni := 0
		while GameState.abitanti < 25 and stagioni < 20:
			GameState.risorse.cibo = GameState.abitanti * 6.0  # scorte per una stagione
			for controllo in 4:
				GameState._arrivi()
			stagioni += 1
		stagioni_per_borgo.append(stagioni)
	var media := 0.0
	for n in stagioni_per_borgo:
		media += n
	media /= stagioni_per_borgo.size()
	_verifica(media >= 4.5 and media <= 9.0, "da 10 a 25 abitanti in circa 6-8 stagioni (%s)" % str(stagioni_per_borgo))
	GameState.livello = 1
	var attr_dopo := GameState.calcola_attrattiva()
	GameState.livello = 0
	_verifica(GameState.calcola_attrattiva() > attr_dopo, "da Borgo in poi si cresce più piano")

	# Raccoglitori vicino alle piante selvatiche: nella loro stagione, 2 raccolti su 3.
	var tr: TerrenoFeudo
	var posto_r := Vector2i(-1, -1)
	var pianta := ""
	for prova in 6:
		if posto_r.x >= 0:
			break
		GameState.ricomincia()
		GameState.avvia()
		GameState.cancella_salvataggio()
		tr = GameState.terreno
		posto_r = _posto_selvatico(tr)
		if posto_r.x >= 0:
			pianta = tr.selvatiche_attorno(posto_r, Vector2i(2, 2), 4).keys()[0]
	_verifica(posto_r.x >= 0, "c'è un posto vicino a un solo tipo di pianta selvatica")
	if posto_r.x >= 0:
		var rac := GameState.aggiungi_gratis("raccoglitore", posto_r, 1.0)
		rac.lavoratori = 2
		var col: Dictionary = GameState.colture[pianta]
		GameState.stagione = GameState.CHIAVI_STAGIONI.find(col.stagioni[0])
		_verifica(GameState.selvatica_di_stagione(rac) == pianta, "nella stagione di %s il raccoglitore lo raccoglie" % pianta)
		var risorsa_p: String = col.risorsa
		rac.erase("pronto")
		GameState._tick()
		var d_cibo: float = GameState.in_arrivo().get("cibo", 0.0)
		var d_pianta: float = GameState.in_arrivo().get(risorsa_p, 0.0)
		_verifica(d_cibo > 0.0 and absf(d_pianta / d_cibo - 2.0) < 0.15, "%s e cibo 2 a 1 (%.2f / %.2f)" % [pianta, d_pianta, d_cibo])
		var fuori_st := -1
		for st in 4:
			if not GameState.CHIAVI_STAGIONI[st] in col.stagioni and st != GameState.INVERNO:
				fuori_st = st
		GameState.stagione = fuori_st
		_verifica(GameState.selvatica_di_stagione(rac) == "", "fuori stagione solo cibo")
		var lontano_r := GameState.aggiungi_gratis("raccoglitore", tr.trova_posto("raccoglitore", TerrenoFeudo.centro_feudo() + Vector2i(0, 12)), 1.0)
		GameState.stagione = GameState.CHIAVI_STAGIONI.find(col.stagioni[0])
		var vicine_l := tr.selvatiche_attorno(lontano_r.cella, Vector2i(2, 2), 4)
		_verifica(vicine_l.values().any(func(n): return n >= 2) or GameState.selvatica_di_stagione(lontano_r) == "", "lontano dalle piante solo cibo")
	GameState.cancella_salvataggio()

	# Banditi e difese.
	GameState.nuova_partita(21)
	GameState.capo = 0
	_verifica(not GameState.banditi_possibili(), "da villaggio, i primi anni, niente banditi")
	GameState.livello = 1
	_verifica(GameState.banditi_possibili(), "da Borgo arrivano i banditi")
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	var d0 := GameState.difesa()
	_verifica(is_equal_approx(d0.totale, 3.0), "senza difese c'è solo la milizia: 10 x 0,3 = 3")
	var lontana := GameState.aggiungi_gratis("torre_guardia", Vector2i(0, 4), 1.0)
	_verifica(int(lontana.arcieri) == 2 and lontana.lavoratori == 0, "la torre nasce con 2 arcieri, senza togliere lavoratori")
	_verifica(GameState.difesa().arcieri == 0, "una torre lontana dal centro non combatte nella battaglia")
	GameState.buildings.erase(lontana)
	var centro_b := GameState._cella_centro()
	var torre := GameState.aggiungi_gratis("torre_guardia", centro_b + Vector2i(1, 1), 1.0)
	GameState.aggiungi_gratis("palizzata", Vector2i(4, 4), 1.0)
	GameState.aggiungi_gratis("palizzata", Vector2i(5, 4), 1.0)
	_verifica(is_equal_approx(GameState.difesa().totale, 3.0 + 12.0 + 3.0), "torre vicina con 2 arcieri (+12) e 2 palizzate (+3)")
	GameState._avvista_banditi()
	var bd: Dictionary = GameState.banditi
	_verifica(not bd.is_empty() and TerrenoFeudo.area.has_point(bd.entrata) and int(bd.mancano) == int(GameState.bil.banditi.preavviso_con_torre),
		"la torre avvista i banditi prima (%d giorni)" % int(bd.get("mancano", 0)))
	var esiti := []
	GameState.incursione.connect(func(e): esiti.append(e))
	GameState.banditi.forza = 10.0
	GameState.banditi.mancano = 3
	var fel_b := GameState.felicita
	GameState.risorse.cibo = 1000.0
	for i in 3:
		GameState._tick()
	_verifica(esiti.size() == 1 and esiti[0].vinto and GameState.banditi.is_empty(), "arrivati i banditi, la difesa li respinge")
	_verifica(GameState.felicita > fel_b, "una vittoria fa piacere")
	GameState.buildings.erase(torre)
	GameState.risorse.oro = 100.0
	GameState.risorse.legna = 100.0
	var gente_b := GameState.abitanti
	GameState._avvista_banditi()
	GameState.banditi.forza = 60.0
	GameState._incursione()
	var e2: Dictionary = esiti[1]
	_verifica(not e2.vinto and GameState.risorse.oro < 100.0 and e2.rubato.has("oro"), "sconfitti: rubano l'oro (%s)" % str(e2.rubato))
	_verifica(GameState.abitanti < gente_b, "qualcuno ci lascia la pelle")
	_verifica(e2.bruciato >= 0 and GameState.trova(e2.bruciato).tipo == "rovine", "molto più deboli: bruciano un edificio")
	GameState.demolisci(e2.bruciato)
	_verifica(GameState.trova(e2.bruciato).is_empty(), "le rovine si sgomberano")
	# gli arcieri tirano ai banditi che passano nel raggio, e i banditi rispondono
	var torre_t := GameState.aggiungi_gratis("torre_guardia", Vector2i(10, 10), 1.0)
	GameState._avvista_banditi()
	var strada_b: Array = []
	for x in range(0, 24):
		strada_b.append(Vector2i(x, 11))
	GameState.banditi.percorso = strada_b
	GameState.banditi.totale = 24
	GameState.banditi.mancano = 24
	GameState.banditi.forza = 30.0
	GameState.bil.arcieri.probabilita_colpo = 1.0
	for i in 23:
		GameState.banditi.mancano -= 1
		GameState._tiro_arcieri()
	_verifica(float(GameState.banditi.forza) < 30.0 and float(GameState.banditi.colpiti) > 0.0, "le frecce indeboliscono la banda (%.1f)" % float(GameState.banditi.forza))
	_verifica(int(torre_t.arcieri) < 2, "e i loro arcieri possono uccidere i nostri")
	GameState.bil.arcieri.probabilita_colpo = 0.03
	_verifica(not GameState.in_tiro(torre_t, Vector2i(10, 20)) and GameState.in_tiro(torre_t, Vector2i(14, 14)), "raggio di 3 celle per lato")
	GameState._nuovi_arcieri()
	_verifica(int(torre_t.arcieri) >= 1, "a ogni stagione sale un nuovo arciere")
	GameState.banditi.forza = 0.4
	GameState.banditi.mancano = 12
	GameState._tiro_arcieri()
	_verifica(GameState.banditi.is_empty() and esiti[esiti.size() - 1].fuggiti, "se le frecce bastano, i banditi scappano prima di arrivare")
	var uscite := 0
	for i in 40:
		GameState._programma_banditi()
		if GameState._tick_banditi >= 0:
			uscite += 1
	_verifica(uscite > 5 and uscite < 35, "non tutte le stagioni arrivano banditi (%d su 40)" % uscite)

	# Salvataggio della versione 6: banditi in arrivo.
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	GameState.livello = 1
	GameState._avvista_banditi()
	var entrata_b: Vector2i = GameState.banditi.entrata
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	_verifica(not GameState.banditi.is_empty() and GameState.banditi.entrata == entrata_b, "i banditi in arrivo si salvano")
	GameState.cancella_salvataggio()

	# Girare e spostare gli edifici già fatti; demolendo si riprende metà del speso.
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	var tz_s := GameState.terreno
	var centro_s := TerrenoFeudo.centro_feudo() + Vector2i(6, 6)
	var mag_s := GameState.aggiungi_gratis("taglialegna", tz_s.trova_posto("taglialegna", centro_s), 1.0)
	var da_s: Vector2i = mag_s.cella
	_verifica(not GameState.riposiziona(mag_s.id, da_s + Vector2i(3, 0), 0) and mag_s.cella == da_s, "non si sposta più di 2 caselle")
	var casa_spostata := GameState.aggiungi_gratis("casa", tz_s.trova_posto("casa", centro_s + Vector2i(-8, 0)), 1.0)
	var da_spostata: Vector2i = casa_spostata.cella
	var spostato := false
	for passo in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 1), Vector2i(-1, -1),
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 2), Vector2i(-2, -2)]:
		if GameState.riposiziona(casa_spostata.id, da_spostata + passo, 0):
			spostato = casa_spostata.cella == da_spostata + passo and tz_s.edificio_a(casa_spostata.cella) == casa_spostata.id
			break
	_verifica(spostato, "spostato di qualche casella: occupa il posto nuovo")
	var casa_s := GameState.aggiungi_gratis("casa", tz_s.trova_posto("casa", mag_s.cella + Vector2i(0, 4)), 1.0)
	var vicino_s: Vector2i = casa_s.cella
	_verifica(not GameState.riposiziona(mag_s.id, vicino_s, 0) or GameState.taglia_di(mag_s) == Vector2i.ZERO, "non si sposta sopra un altro edificio")
	var giri := 0
	for i in 4:
		if GameState.gira(mag_s.id):
			giri += 1
	_verifica(giri > 0 and tz_s.edificio_a(mag_s.cella) == mag_s.id, "un edificio fatto si può girare (%d giri)" % giri)
	var tl_s := GameState.trova(mag_s.id)
	tl_s.livello = 2
	var spesi := GameState.materiali_spesi(tl_s)
	var base_s: Dictionary = GameState.edifici.taglialegna.costo
	var migl_s: Dictionary = GameState.edifici.taglialegna.miglioramenti[0].costo
	_verifica(int(spesi.get("legna", 0)) == int(base_s.get("legna", 0)) + int(migl_s.get("legna", 0)), "si conta anche quanto speso per migliorare")
	GameState.risorse.legna = 0.0
	GameState.risorse.pietra = 0.0
	GameState.demolisci(mag_s.id)
	_verifica(int(GameState.risorse.legna) == int(floorf(float(spesi.get("legna", 0)) * 0.5)) and int(GameState.risorse.pietra) == int(floorf(float(spesi.get("pietra", 0)) * 0.5)),
		"demolendo si riprende metà dei materiali (legna %d)" % GameState.risorse.legna)

	# Forma del feudo e biomi (versione 2), e le partite vecchie che restano com'erano.
	GameState.versione_mappa = 2
	var tb := TerrenoFeudo.new(77)
	var conta_b := [0, 0, 0, 0]
	var boschi_b := [0, 0, 0, 0]
	var celle_f := 0
	for y in range(TerrenoFeudo.area.position.y, TerrenoFeudo.area.end.y):
		for x in range(TerrenoFeudo.area.position.x, TerrenoFeudo.area.end.x):
			var cb_ := Vector2i(x, y)
			if tb.nel_feudo(cb_):
				celle_f += 1
				conta_b[tb.bioma_a(cb_)] += 1
				if tb.tipo_a(cb_) == TerrenoFeudo.Tipo.BOSCO:
					boschi_b[tb.bioma_a(cb_)] += 1
	var rett := TerrenoFeudo.area.size.x * TerrenoFeudo.area.size.y
	_verifica(celle_f > 1500 and celle_f < rett * 0.9 and not tb.bordo.is_empty(), "il feudo è una forma tondeggiante, non un quadrato (%d celle su %d)" % [celle_f, rett])
	_verifica(conta_b.all(func(n): return n > 80), "nel feudo ci sono prateria, pineta, palude e rupi %s" % str(conta_b))
	_verifica(tb.bioma_a(TerrenoFeudo.centro_feudo()) == TerrenoFeudo.Bioma.PRATERIA, "attorno all'accampamento c'è la prateria")
	_verifica(float(boschi_b[1]) / conta_b[1] > float(boschi_b[0]) / conta_b[0], "nella pineta c'è più bosco che nella prateria")
	var in_pineta := Vector2i(-1, -1)
	for y in range(TerrenoFeudo.area.position.y, TerrenoFeudo.area.end.y):
		for x in range(TerrenoFeudo.area.position.x, TerrenoFeudo.area.end.x):
			if in_pineta.x < 0 and tb.bioma_a(Vector2i(x + 1, y + 1)) == TerrenoFeudo.Bioma.PINETA:
				in_pineta = Vector2i(x, y)
	_verifica(is_equal_approx(float(tb.effetto_bioma("taglialegna", in_pineta)[0]), float(GameState.bil.biomi.pineta.taglialegna)), "il taglialegna rende di più nella pineta")
	GameState.versione_mappa = 1
	var tv := TerrenoFeudo.new(77)
	_verifica(TerrenoFeudo.area == TerrenoFeudo.FEUDO and tv.nel_feudo(TerrenoFeudo.FEUDO.position) and tv.bioma_a(TerrenoFeudo.centro_feudo() + Vector2i(15, 15)) == TerrenoFeudo.Bioma.PRATERIA,
		"nelle partite vecchie il feudo resta il quadrato di sempre, senza biomi")
	var g1 := Regioni.genera(5, 1)
	var al_centro := 0
	for i in g1.siti.size():
		if g1.siti[i].distance_to(Vector2(0.5, 0.5)) < g1.siti[al_centro].distance_to(Vector2(0.5, 0.5)):
			al_centro = i
	_verifica(g1.mia == al_centro, "nelle partite vecchie la nostra regione resta quella al centro")
	GameState.versione_mappa = 2
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	GameState.salva()
	GameState.in_corso = false
	GameState.versione_mappa = 1
	GameState.avvia()
	_verifica(GameState.versione_mappa == 4, "la versione della mappa si salva")
	GameState.cancella_salvataggio()

	# Climi: ogni regione ne ha uno; il feudo prende quello della sua regione, con nomi e colture adatti.
	var climi_visti := {}
	for seme_c in 8:
		var gc := Regioni.genera(seme_c, 3)
		for reg_c in gc.regioni:
			climi_visti[reg_c.clima] = true
	_verifica(climi_visti.size() == 4, "sulla mappa ci sono climi diversi %s" % str(climi_visti.keys()))
	_verifica(Regioni.genera(3, 2).regioni.all(func(r): return r.clima == "temperato"), "nelle partite di prima è tutto temperato")
	var climi_v4 := {}
	for seme_c in 30:
		for reg_c in Regioni.genera(seme_c, 4).regioni:
			climi_v4[reg_c.clima] = true
	_verifica(climi_v4.size() > 6, "con la versione 4 escono anche i climi nuovi (%d)" % climi_v4.size())
	# ogni clima di data/climi.json ha tutto quello che serve (così un clima aggiunto a mano non rompe il gioco)
	var mancanze: Array[String] = []
	for k_c in GameState.climi:
		var dc: Dictionary = GameState.climi[k_c]
		for voce in ["nome", "fascia", "suolo", "alberi"]:
			if not dc.has(voce):
				mancanze.append("%s: manca %s" % [k_c, voce])
		for colore_s in ["erba", "acqua", "fiume", "roccia", "tinte_zone"]:
			if dc.get("suolo", {}).get(colore_s, []).size() != 4:
				mancanze.append("%s: suolo.%s deve avere 4 colori" % [k_c, colore_s])
		for voce_a in ["colori_primo", "colori_secondo", "quota_secondo"]:
			if dc.get("alberi", {}).get(voce_a, []).size() != 4:
				mancanze.append("%s: alberi.%s deve avere 4 valori" % [k_c, voce_a])
		for coltura in dc.get("colture", {}):
			if not GameState.nomi_colture().has(coltura):
				mancanze.append("%s: la coltura %s non esiste" % [k_c, coltura])
	_verifica(mancanze.is_empty(), "i climi in data/climi.json sono completi %s" % str(mancanze))
	GameState.clima_forzato = "deserto"
	GameState.nuova_partita(5)
	_verifica(GameState.clima == "deserto" and GameState.nome_risorsa("rape") == "Datteri" and GameState.colture.rape.nome == "Datteri",
		"nel deserto le rape sono datteri")
	_verifica(GameState.edifici.casa.nome == "Casa di fango" and GameState.edifici.casa.miglioramenti[1].nome == "Casa di pietra bianca"
		and GameState.edifici.casa.alloggi == GameState.edifici.casa.alloggi, "gli edifici prendono nomi del deserto")
	_verifica(GameState.colture.orzo.stagioni == ["inverno", "primavera"], "e le colture le loro stagioni (ceci d'inverno)")
	GameState.clima_forzato = "savana"
	GameState.nuova_partita(5)
	_verifica(GameState.nome_risorsa("grano") == "Sorgo" and GameState.edifici.casa.nome == "Capanna", "in savana sorgo e capanne")
	GameState.clima_forzato = "temperato"
	GameState.nuova_partita(5)
	_verifica(GameState.edifici.casa.nome == "Casa" and GameState.nome_risorsa("rape") == "Rape" and GameState.colture.orzo.stagioni == ["primavera", "estate"],
		"tornando al temperato tutto torna come prima")
	GameState.clima_forzato = "tundra"
	GameState.ricomincia()
	GameState.avvia()
	GameState.scegli_capo(0)
	GameState.salva()
	GameState.in_corso = false
	GameState.clima_forzato = "temperato"
	GameState.avvia()
	_verifica(GameState.clima == "tundra" and GameState.nome_risorsa("grano") == "Segale", "il clima si salva")
	GameState.cancella_salvataggio()

	print("TEST: %s (%d errori)" % ["OK" if _errori == 0 else "FALLITI", _errori])
	get_tree().quit(1 if _errori > 0 else 0)


## Un posto per un raccoglitore vicino a un solo tipo di pianta selvatica (almeno 2 celle).
func _posto_selvatico(tr: TerrenoFeudo) -> Vector2i:
	for i in tr.selvatiche:
		var cella_s := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		var cand := tr.trova_posto("raccoglitore", cella_s)
		if cand.x < 0:
			continue
		var vicine := tr.selvatiche_attorno(cand, Vector2i(2, 2), 4)
		if vicine.size() == 1 and int(vicine.values()[0]) >= 2:
			return cand
	return Vector2i(-1, -1)


func _verifica(condizione: bool, descrizione: String) -> void:
	if condizione:
		print("  ok   ", descrizione)
	else:
		_errori += 1
		print("  FAIL ", descrizione)


## Altura, fianchi, supporto e lance su un campo piatto fatto a mano.
func _prova_forze() -> void:
	var cfg: Dictionary = GameState.bil.battaglia
	var terreno: Array = []
	terreno.resize(LogicaBattaglia.LARGHEZZA * LogicaBattaglia.ALTEZZA)
	terreno.fill(LogicaBattaglia.Terreno.PIANURA)
	var b := {"terreno": terreno, "unita": [], "diario": []}
	var a := {"id": 1, "lato": "noi", "tipo": "spadaccini", "uomini": 10, "max": 10, "cella": [4, 4]}
	var d := {"id": 2, "lato": "loro", "tipo": "spadaccini", "uomini": 10, "max": 10, "cella": [5, 4]}
	b.unita = [a, d]
	var base := float(LogicaBattaglia.forze(b, a, d, cfg).fa)
	var base_d := float(LogicaBattaglia.forze(b, a, d, cfg).fd)
	_verifica(is_equal_approx(base, base_d), "a parità di tutto le forze sono pari")
	terreno[4 * LogicaBattaglia.LARGHEZZA + 4] = LogicaBattaglia.Terreno.COLLINA
	var f_alto := LogicaBattaglia.forze(b, a, d, cfg)
	_verifica(is_equal_approx(float(f_alto.fa), base * (1.0 + float(cfg.altura))) and not f_alto.voci.is_empty(), "dall'alto si colpisce più forte")
	terreno[4 * LogicaBattaglia.LARGHEZZA + 4] = LogicaBattaglia.Terreno.PIANURA
	terreno[4 * LogicaBattaglia.LARGHEZZA + 5] = LogicaBattaglia.Terreno.COLLINA
	var f_basso := LogicaBattaglia.forze(b, a, d, cfg)
	_verifica(float(f_basso.fa) < base and float(f_basso.fd) > base_d, "dal basso, contro chi sta in collina, si fatica")
	terreno[4 * LogicaBattaglia.LARGHEZZA + 5] = LogicaBattaglia.Terreno.PIANURA
	# fianchi: due nostre unità in più attorno al nemico
	var attorno := LogicaBattaglia.vicini(Vector2i(5, 4)).filter(func(c): return c != Vector2i(4, 4))
	var id := 3
	for c in attorno.slice(0, 2):
		b.unita.append({"id": id, "lato": "noi", "tipo": "fanti", "uomini": 5, "max": 5, "cella": [c.x, c.y]})
		id += 1
	_verifica(is_equal_approx(float(LogicaBattaglia.forze(b, a, d, cfg).fa), base * (1.0 + 2 * float(cfg.fianco))), "attaccare dai fianchi aiuta")
	b.unita = [a, d]
	# supporto: un compagno accanto al difensore
	var accanto: Vector2i = LogicaBattaglia.vicini(Vector2i(5, 4)).filter(func(c): return c != Vector2i(4, 4))[0]
	b.unita.append({"id": 9, "lato": "loro", "tipo": "fanti", "uomini": 5, "max": 5, "cella": [accanto.x, accanto.y]})
	_verifica(is_equal_approx(float(LogicaBattaglia.forze(b, a, d, cfg).fd), base_d * (1.0 + float(cfg.supporto))), "i compagni accanto aiutano a difendersi")
	b.unita = [a, d]
	# lance contro cavalli
	a.tipo = "fanti"
	d.tipo = "cavalieri"
	var lance := LogicaBattaglia.forze(b, a, d, cfg)
	_verifica(is_equal_approx(float(lance.fa), 10 * LogicaBattaglia.forza(a, cfg) * float(cfg.lance_contro_cavalli)), "le lance fermano i cavalli")
	a.tipo = "cavalieri"
	d.tipo = "fanti"
	_verifica(is_equal_approx(float(LogicaBattaglia.forze(b, a, d, cfg).fd), 10 * LogicaBattaglia.forza(d, cfg) * float(cfg.lance_contro_cavalli)), "e i cavalli contro le lance soffrono")
	var p := LogicaBattaglia.anteprima(b, 1, 2, cfg)
	_verifica(int(p.morti_difensore) > 0 and int(p.morti_attaccante) >= 0 and not p.da_lontano, "l'anteprima dice le perdite previste")


## Assedio: contro un signore il castello ha le mura e la porta.
func _prova_assedio() -> void:
	var cfg: Dictionary = GameState.bil.battaglia
	var rng := RandomNumberGenerator.new()
	var b := LogicaBattaglia.crea("prova", "signore", {"fanti": 15, "arcieri": 5}, 0, 0, 20, 7, cfg)
	var porta: Dictionary = b.unita.filter(func(u): return u.tipo == LogicaBattaglia.PORTA)[0]
	var bandiera := Vector2i(int(b.bandiera[0]), int(b.bandiera[1]))
	var mura := 0
	for t in b.terreno:
		if int(t) == LogicaBattaglia.Terreno.MURA:
			mura += 1
	_verifica(b.assedio and mura >= 12 and LogicaBattaglia.terreno_a(b, LogicaBattaglia.cella(porta)) == LogicaBattaglia.Terreno.PIANURA, "contro un signore c'è il castello con mura e porta")
	var sulle_mura := LogicaBattaglia.vive(b, "loro").filter(func(u): return LogicaBattaglia.terreno_a(b, LogicaBattaglia.cella(u)) == LogicaBattaglia.Terreno.MURA)
	_verifica(not sulle_mura.is_empty() and sulle_mura.all(func(u): return int(cfg.unita[u.tipo].gittata) > 1), "i balestrieri difendono dalle mura")
	_verifica(LogicaBattaglia.gittata(b, sulle_mura[0], cfg) == int(cfg.unita[sulle_mura[0].tipo].gittata) + 1, "dalle mura si tira più lontano")
	# un nostro fante davanti alla porta: non passa, non sale sulle mura, ma può colpire la porta
	var fante: Dictionary = LogicaBattaglia.vive(b, "noi").filter(func(u): return u.tipo == "fanti")[0]
	var davanti := LogicaBattaglia.cella(porta) - Vector2i(1, 0)
	fante.cella = [davanti.x, davanti.y]
	fante.mosse = 5
	var dove := LogicaBattaglia.raggiungibili(b, fante, cfg)
	_verifica(dove.keys().all(func(c): return LogicaBattaglia.terreno_a(b, c) != LogicaBattaglia.Terreno.MURA and LogicaBattaglia.distanza(c, bandiera) > 1), "le mura non si scavalcano: per entrare serve la porta")
	var arciere: Dictionary = LogicaBattaglia.vive(b, "noi").filter(func(u): return u.tipo == "arcieri")[0]
	var lontano := LogicaBattaglia.cella(porta) - Vector2i(2, 0)
	arciere.cella = [lontano.x, lontano.y]
	_verifica(not LogicaBattaglia.bersagli(b, arciere, cfg).has(porta), "le frecce non aprono la porta")
	_verifica(LogicaBattaglia.bersagli(b, fante, cfg).has(porta), "la porta si colpisce da vicino")
	b.fase = "noi"
	var colpi := 0
	while int(porta.uomini) > 0 and colpi < 20:
		fante.attaccato = false
		fante.uomini = 5
		LogicaBattaglia.attacca(b, int(fante.id), int(porta.id), cfg, rng)
		colpi += 1
	_verifica(int(porta.uomini) <= 0 and int(fante.uomini) == 5 and not b.finita, "la porta non risponde e alla fine cede (%d colpi)" % colpi)
	fante.mosse = 5
	fante.attaccato = false
	_verifica(LogicaBattaglia.raggiungibili(b, fante, cfg).has(LogicaBattaglia.cella(porta)), "dalla porta sfondata si entra")
	# le scale: un fante accanto a un bosco abbatte un albero, poi costruisce le scale e sale sulle mura
	var b2 := LogicaBattaglia.crea("prova", "signore", {"fanti": 5, "cavalieri": 5, "arcieri": 5}, 0, 0, 10, 7, cfg)
	b2.fase = "noi"
	var f2: Dictionary = LogicaBattaglia.vive(b2, "noi").filter(func(u): return u.tipo == "fanti")[0]
	var c2: Dictionary = LogicaBattaglia.vive(b2, "noi").filter(func(u): return u.tipo == "cavalieri")[0]
	var a2: Dictionary = LogicaBattaglia.vive(b2, "noi").filter(func(u): return u.tipo == "arcieri")[0]
	var porta2: Dictionary = b2.unita.filter(func(u): return u.tipo == LogicaBattaglia.PORTA)[0]
	var muro2 := LogicaBattaglia.cella(porta2) + Vector2i(0, -1)
	var sotto2 := muro2 - Vector2i(1, 0)
	for u in LogicaBattaglia.vive(b2, "loro"):
		if LogicaBattaglia.cella(u) == muro2:
			u.cella = [0, 0]
			u.uomini = 0
	f2.cella = [sotto2.x, sotto2.y]
	var bosco2 := sotto2 - Vector2i(1, 0)
	b2.terreno[bosco2.y * LogicaBattaglia.LARGHEZZA + bosco2.x] = LogicaBattaglia.Terreno.BOSCO
	a2.cella = [bosco2.x, bosco2.y + 1]
	_verifica(not LogicaBattaglia.puo_abbattere(b2, a2), "gli arcieri non fanno le scale: solo i fanti")
	_verifica(not LogicaBattaglia.puo_fare_scale(b2, f2), "senza legna niente scale")
	_verifica(LogicaBattaglia.abbatti(b2, int(f2.id), cfg) == bosco2 and LogicaBattaglia.terreno_a(b2, bosco2) == LogicaBattaglia.Terreno.PIANURA and f2.legna and f2.attaccato, "il fante abbatte l'albero: il bosco diventa radura, e il turno è finito")
	f2.attaccato = false
	_verifica(LogicaBattaglia.costruisci_scale(b2, int(f2.id), cfg) and f2.scale and not f2.legna, "con la legna costruisce le scale")
	f2.attaccato = false
	f2.mosse = 3
	_verifica(LogicaBattaglia.raggiungibili(b2, f2, cfg).has(muro2), "con le scale il fante sale sulle mura")
	c2.cella = [sotto2.x, sotto2.y + 3]
	c2.scale = true
	c2.mosse = 6
	_verifica(LogicaBattaglia.raggiungibili(b2, c2, cfg).keys().all(func(c): return LogicaBattaglia.terreno_a(b2, c) != LogicaBattaglia.Terreno.MURA), "i cavalli sulle mura non salgono")
	_verifica(not LogicaBattaglia.calpestabile(b2, muro2, {"lato": "loro", "tipo": "cavalieri"}) and LogicaBattaglia.calpestabile(b2, muro2, {"lato": "loro", "tipo": "balestrieri"}), "nemmeno quelli del nemico; i balestrieri sì")
	# le difese crescono con il feudo del signore
	var pal := LogicaBattaglia.crea("prova", "signore", {"fanti": 5}, 0, 0, 10, 3, cfg, 0)
	var cit := LogicaBattaglia.crea("prova", "signore", {"fanti": 5}, 0, 0, 30, 3, cfg, 2)
	var porta_pal: Dictionary = pal.unita.filter(func(u): return u.tipo == LogicaBattaglia.PORTA)[0]
	var porta_cit: Dictionary = cit.unita.filter(func(u): return u.tipo == LogicaBattaglia.PORTA)[0]
	var case_cit: int = cit.terreno.filter(func(t): return int(t) == LogicaBattaglia.Terreno.CASA).size()
	_verifica(pal.mura.materiale == "legno" and int(porta_pal.uomini) < int(porta_cit.uomini) and float(pal.mura.difesa) < float(cit.mura.difesa), "un villaggio ha la palizzata, più debole delle mura")
	_verifica(cit.mura.torri.size() == 4 and case_cit > 0, "una città ha le torri agli angoli e le case dentro (%d)" % case_cit)
	var bal_torre := LogicaBattaglia.vive(cit, "loro").filter(func(u): return cit.mura.torri.has(u.cella))
	_verifica(not bal_torre.is_empty() and LogicaBattaglia.gittata(cit, bal_torre[0], cfg) == int(cfg.unita[bal_torre[0].tipo].gittata) + 2, "dalle torri si tira ancora più lontano")

	for u in LogicaBattaglia.vive(b, "loro"):
		u.uomini = 0
	LogicaBattaglia._controlla_fine(b)
	_verifica(b.finita and b.vinta, "distrutti i difensori, il castello è preso")


## I feudi dei signori crescono come il nostro: più abitanti, più soldati, difese più forti.
func _prova_sviluppo_regni() -> void:
	var signore := ""
	for k in GameState.regni:
		if GameState.regni[k].tipo == "signore" and not GameState.regni[k].conquistato:
			signore = k
			break
	if signore == "":
		_verifica(false, "c'è un signore da far crescere")
		return
	var r: Dictionary = GameState.regni[signore]
	var abitanti_prima := GameState.abitanti
	r.abitanti = 15
	r.ritmo = 1.0
	_verifica(GameState.livello_regno(signore) == 0 and GameState.difese_regno(signore) == "Palizzata", "un signore piccolo ha un villaggio con la palizzata")
	var forza_prima := GameState.forza_regno(signore)
	GameState.abitanti = 80
	for i in 12:
		GameState._sviluppa_regni()
	_verifica(int(r.abitanti) > 60 and int(r.abitanti) <= 80, "il suo feudo cresce verso il nostro (%d)" % int(r.abitanti))
	_verifica(GameState.livello_regno(signore) == 2 and GameState.forza_regno(signore) > forza_prima * 3, "diventa una città con un esercito più grande")
	GameState.abitanti = 5
	var ora := int(r.abitanti)
	GameState._sviluppa_regni()
	_verifica(int(r.abitanti) == ora, "e non cala se il nostro si svuota")
	GameState.abitanti = abitanti_prima


## Il campo non è un rettangolo, e spesso c'è un fiume da passare con un ponte di barche.
func _prova_fiume() -> void:
	var cfg: Dictionary = GameState.bil.battaglia
	var con_fuori := 0
	var con_fiume := 0
	var collegati := true
	var bosco_nostro := true
	var senza_ponte := {}
	for seme in 30:
		var b := LogicaBattaglia.crea("prova", ["libera", "banditi", "signore"][seme % 3], {"fanti": 10}, 0, 0, 10, seme * 31, cfg)
		if b.terreno.has(LogicaBattaglia.Terreno.FUORI):
			con_fuori += 1
		if LogicaBattaglia.ha_fiume(b):
			con_fiume += 1
			if not b.terreno.has(LogicaBattaglia.Terreno.PONTE) and senza_ponte.is_empty():
				senza_ponte = b
		# tutto il campo (fiume e mura comprese) è un pezzo solo, e tocca la zona di schieramento
		var dentro := []
		for i in b.terreno.size():
			if b.terreno[i] != LogicaBattaglia.Terreno.FUORI:
				dentro.append(Vector2i(i % LogicaBattaglia.LARGHEZZA, i / LogicaBattaglia.LARGHEZZA))
		var visti := {dentro[0]: true}
		var coda := [dentro[0]]
		while not coda.is_empty():
			var x: Vector2i = coda.pop_back()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = x + d
				if LogicaBattaglia.dentro(v) and not visti.has(v) and LogicaBattaglia.terreno_a(b, v) != LogicaBattaglia.Terreno.FUORI:
					visti[v] = true
					coda.append(v)
		if visti.size() != dentro.size() or LogicaBattaglia.zona_schieramento(b, cfg).size() < 10:
			collegati = false
		# dalla nostra parte c'è un bosco per la legna
		var limite := LogicaBattaglia.LARGHEZZA
		for i in b.terreno.size():
			if b.terreno[i] in [LogicaBattaglia.Terreno.FIUME, LogicaBattaglia.Terreno.PONTE, LogicaBattaglia.Terreno.MURA]:
				limite = mini(limite, i % LogicaBattaglia.LARGHEZZA)
		var bosco := false
		for i in b.terreno.size():
			if b.terreno[i] == LogicaBattaglia.Terreno.BOSCO and i % LogicaBattaglia.LARGHEZZA < limite:
				bosco = true
		bosco_nostro = bosco_nostro and bosco
	_verifica(con_fuori >= 25, "il campo ha una forma irregolare, non è un rettangolo (%d su 30)" % con_fuori)
	_verifica(collegati, "il campo è un pezzo solo, con la zona di schieramento")
	_verifica(con_fiume >= 8 and con_fiume <= 26, "spesso c'è un fiume (%d su 30)" % con_fiume)
	_verifica(bosco_nostro, "dalla nostra parte c'è sempre un bosco per la legna")
	if senza_ponte.is_empty():
		_verifica(false, "c'è un fiume senza ponte")
		return
	var b: Dictionary = senza_ponte
	b.fase = "noi"
	var f: Dictionary = LogicaBattaglia.vive(b, "noi")[0]
	# il fante sulla riva, accanto al fiume
	var riva := Vector2i(-1, -1)
	for i in b.terreno.size():
		var c := Vector2i(i % LogicaBattaglia.LARGHEZZA, i / LogicaBattaglia.LARGHEZZA)
		if b.terreno[i] == LogicaBattaglia.Terreno.PIANURA and LogicaBattaglia.dentro(c + Vector2i(1, 0)) and LogicaBattaglia.terreno_a(b, c + Vector2i(1, 0)) == LogicaBattaglia.Terreno.FIUME and LogicaBattaglia.occupante(b, c) < 0:
			riva = c
			break
	f.cella = [riva.x, riva.y]
	f.mosse = 8
	# per ogni riga, dove scorre il fiume: "di là" è a destra del fiume della propria riga
	var fiume_in := {}
	for i in b.terreno.size():
		if b.terreno[i] == LogicaBattaglia.Terreno.FIUME:
			fiume_in[i / LogicaBattaglia.LARGHEZZA] = i % LogicaBattaglia.LARGHEZZA
	var di_la := func(c: Vector2i) -> bool: return fiume_in.has(c.y) and c.x > int(fiume_in[c.y])
	_verifica(not LogicaBattaglia.raggiungibili(b, f, cfg).keys().any(di_la), "senza ponte il fiume non si passa")
	_verifica(not LogicaBattaglia.puo_fare_ponte(b, f), "senza legna niente ponte")
	f.legna = true
	var ponte := LogicaBattaglia.costruisci_ponte(b, int(f.id), cfg)
	_verifica(ponte == riva + Vector2i(1, 0) and LogicaBattaglia.terreno_a(b, ponte) == LogicaBattaglia.Terreno.PONTE and not f.legna and str(b.ponti[str(ponte.y * LogicaBattaglia.LARGHEZZA + ponte.x)]) == "barche", "con la legna i fanti gettano un ponte di barche")
	f.attaccato = false
	f.mosse = 8
	_verifica(LogicaBattaglia.raggiungibili(b, f, cfg).keys().any(di_la), "dal ponte si passa dall'altra parte")
