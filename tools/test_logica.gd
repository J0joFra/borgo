extends Node
## Test della logica di gioco, senza grafica:
##   godot --headless --path . res://tools/test_logica.tscn

var _errori := 0


func _ready() -> void:
	GameState.cancella_salvataggio()
	GameState.nuova_partita(42)
	GameState.abitanti = 10
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
	for i in 60:
		GameState._tick()
	_verifica(absf(GameState.risorse.cibo - 40.0) < 0.1, "raccoglitore: +40 cibo (%.1f)" % GameState.risorse.cibo)

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
	_verifica(int(GameState.risorse.legna) == 22, "costo del taglialegna salvato (legna %d)" % GameState.risorse.legna)
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
	var fuori := TerrenoFeudo.FEUDO.position - Vector2i(3, 3)
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
	_verifica(tz.tagliati.size() == max_bosco, "i tagli sono ricordati per il salvataggio")
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
	# migliorato: 3 posti di lavoro e +30%; con 2 lavoratori su 3 rende 40 × 1,3 × 2/3
	_verifica(absf(GameState.risorse.cibo - 40.0 * 1.3 * 2.0 / 3.0) < 0.2, "raccoglitore migliorato: più posti e più efficienza (%.1f)" % GameState.risorse.cibo)

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
	var tagli := GameState.terreno.tagliati.size()
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	var ricaricata: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "tenda")[0]
	_verifica(int(ricaricata.livello) == 3, "il livello degli edifici si salva")
	_verifica(GameState.terreno.tagliati.size() == tagli and tagli == 5, "i tagli del bosco si salvano")
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
	_verifica(tf.tagliati.size() == 2, "le radure ripiantate non sono più radure")

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
	for y in range(TerrenoFeudo.FEUDO.position.y + 2, TerrenoFeudo.FEUDO.end.y - 2):
		for x in range(TerrenoFeudo.FEUDO.position.x + 2, TerrenoFeudo.FEUDO.end.x - 3):
			var tutte := true
			for dy in range(-2, 2):
				for dx in 3:
					if ts.tipo_a(Vector2i(x + dx, y + dy)) != TerrenoFeudo.Tipo.ERBA:
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
	for y in range(TerrenoFeudo.FEUDO.position.y + 1, TerrenoFeudo.FEUDO.end.y):
		for x in range(TerrenoFeudo.FEUDO.position.x, TerrenoFeudo.FEUDO.end.x - 6):
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

	# Esercito: formazioni in caserma, cibo al mese, difesa.
	GameState.nuova_partita(30)
	_verifica(GameState.regni.size() == 9, "nove regni attorno al nostro")
	GameState.capo = 0
	GameState.livello = 1
	GameState.abitanti = 14
	for i in 4:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	_verifica(GameState.perche_non_arruolare() == "serve una caserma", "senza caserma niente soldati")
	GameState.aggiungi_gratis("caserma", Vector2i(0, 4), 1.0)
	var liberi := GameState.disoccupati()
	_verifica(GameState.arruola() and GameState.soldati == 5 and GameState.disoccupati() == liberi - 5, "arruolata una formazione di 5")
	_verifica(GameState.arruola() and not GameState.arruola(), "la caserma tiene 2 formazioni")
	_verifica(GameState.cibo_esercito_al_mese() == 6, "2 formazioni: 6 cibo al mese")
	_verifica(is_equal_approx(GameState.difesa().forza_soldati, 50.0), "10 soldati difendono con 50")
	GameState.risorse.cibo = 100.0
	GameState.tick_in_stagione = 19
	GameState._tick()
	_verifica(absf(GameState.risorse.cibo - (100.0 - 6.0 - 14 * 0.1)) < 0.01, "a fine mese i soldati mangiano 6 cibo")
	for cibo_r in GameState.CIBI:
		GameState.risorse[cibo_r] = 0.0
	GameState._paga_soldati()
	_verifica(GameState.soldati == 5, "senza cibo una formazione se ne va")

	# Caserma grande (15 posti) e tipi di soldati secondo il livello dell'armeria.
	GameState.abitanti = 40
	var caserma_b: Dictionary = GameState.buildings.filter(func(x): return x.tipo == "caserma")[0]
	caserma_b.livello = 2
	_verifica(GameState.formazioni_massime() == 3, "la caserma grande tiene 15 soldati")
	_verifica(GameState.perche_non_arruolare("arcieri") == "serve un'armeria", "gli arcieri vogliono un'armeria")
	GameState.aggiungi_gratis("armeria", Vector2i(10, 8), 1.0)
	var armeria_b: Dictionary = GameState.buildings.filter(func(x): return x.tipo == "armeria")[0]
	GameState.risorse.armi = 5.0
	_verifica(GameState.arruola("arcieri") and int(GameState.truppe.arcieri) == 5 and GameState.risorse.armi == 0.0, "con l'armeria si arruolano arcieri per 5 armi")
	_verifica(GameState.perche_non_arruolare("balestrieri") == "serve l'armeria fornita", "i balestrieri vogliono l'armeria fornita")
	armeria_b.livello = 3
	GameState.risorse.armi = 10.0
	GameState.risorse.oro = 20.0
	_verifica(GameState.arruola("cavalieri") and GameState.soldati == 15 and GameState.perche_non_arruolare("fanti") == "le caserme sono piene", "con l'arsenale i cavalieri; poi la caserma è piena")
	_verifica(GameState.cibo_esercito_al_mese() == 11, "i cavalieri mangiano di più")
	_verifica(GameState.congeda("arcieri") and int(GameState.truppe.arcieri) == 0 and GameState.soldati == 10, "si congedano gli arcieri")

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
	_verifica(GameState.risorse.legna == 107.0, "l'eccesso di legna oltre 100 si vende")
	_verifica(GameState.risorse.pietra > 0.0 and GameState.risorse.pietra < 50.0 and GameState.risorse.oro >= 60.0, "si compra pietra senza scendere sotto la riserva d'oro")
	GameState.imposta_auto("legna", "compra_sotto", 200)
	_verifica(int(GameState.mercato_auto.legna.vendi_sopra) == 0, "comprare sopra la soglia di vendita la spegne")

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
	GameState.risorse.armi = 20.0
	_verifica(GameState.attacca(libera) and GameState.soldati_presenti() == 0, "l'esercito parte tutto")
	for i in int(GameState.bil.diplomazia.giorni_marcia):
		GameState._avanza_missioni()
	var bt: Dictionary = GameState.battaglia
	var cfg_b: Dictionary = GameState.bil.battaglia
	var noi_b := LogicaBattaglia.vive(bt, "noi")
	var loro_b := LogicaBattaglia.vive(bt, "loro")
	_verifica(not bt.is_empty() and GameState.velocita == 0 and bt.fase == "noi" and noi_b.size() == 4 and loro_b.size() >= 1, "arrivato l'esercito si schiera sul campo: il tempo si ferma")
	_verifica(noi_b.any(func(u): return u.tipo == "arcieri") and noi_b.any(func(u): return u.get("armati", false)), "con le armi: arcieri e fanti armati")
	_verifica(GameState.soldati_presenti() == 0, "in battaglia i soldati non sono a casa")
	_verifica(LogicaBattaglia.distanza(Vector2i(0, 0), Vector2i(2, 0)) == 2 and LogicaBattaglia.vicini(Vector2i(3, 3)).size() == 6, "esagoni: distanze e vicini")
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
	GameState.risorse.armi = 0.0
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
	GameState.battaglia_fine_turno()
	_verifica(bf.finita and bf.vinta and GameState.regni[forte].conquistato, "presa e tenuta la loro bandiera: vittoria")
	GameState.chiudi_battaglia()
	GameState.regni[forte].conquistato = false
	# finiscono i turni senza prendere niente: si torna a casa
	GameState.soldati = 10
	GameState.attacca(forte)
	for i in int(GameState.bil.diplomazia.giorni_marcia):
		GameState._avanza_missioni()
	for turno_b in int(GameState.bil.battaglia.turni):
		GameState.battaglia_fine_turno()
	_verifica(GameState.battaglia.finita and not GameState.battaglia.vinta and int(GameState.battaglia.turno) == int(GameState.bil.battaglia.turni), "dopo %d turni senza la bandiera la battaglia è persa" % int(GameState.bil.battaglia.turni))
	GameState.chiudi_battaglia()
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
	GameState.inizia_prova_battaglia({"nemico": "banditi", "fanti": 10, "arcieri": 5, "armi": 10, "vassalli": 5, "nemici": 12})
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
	GameState.salva()
	GameState.in_corso = false
	GameState.avvia()
	_verifica(GameState.soldati == 5 and GameState.regni[prima_k].spiato and GameState.missioni.size() == 1, "esercito, regni e missioni si salvano")
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
	var verso := TerrenoFeudo.percorso(GameState._bordo(piazza_b)[0], GameState._bordo(lontano)[0])
	GameState.terreno_cambiato.emit(GameState.terreno.aggiungi_strada(verso))
	_verifica(GameState.collegato(lontano) and is_equal_approx(GameState.efficienza(lontano), 1.0), "con la strada fino alla piazza il malus sparisce")

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
		var cibo_p: float = GameState.risorse.cibo
		var pianta_p: float = GameState.risorse[risorsa_p]
		GameState._tick()
		var d_cibo: float = GameState.risorse.cibo - cibo_p + GameState.abitanti * float(GameState.bil.cibo_per_abitante_tick)
		var d_pianta: float = GameState.risorse[risorsa_p] - pianta_p
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
	GameState.risorse.armi = 2.0
	_verifica(is_equal_approx(GameState.difesa().forza_arcieri, 18.0), "arcieri armati: x1,5")
	GameState._avvista_banditi()
	var bd: Dictionary = GameState.banditi
	_verifica(not bd.is_empty() and TerrenoFeudo.FEUDO.has_point(bd.entrata) and int(bd.mancano) == int(GameState.bil.banditi.preavviso_con_torre),
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
	GameState.risorse.armi = 0.0
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
