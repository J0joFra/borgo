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

	# Fame per una stagione intera: muore il 20%.
	GameState.nuova_partita(42)
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

	# Tasse in autunno: 10 abitanti x 1 oro, re chiede 15.
	GameState.nuova_partita(42)
	GameState.abitanti = 10
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.stagione = GameState.AUTUNNO
	GameState.risorse.cibo = 1000.0
	for i in 60:
		GameState._tick()
	_verifica(int(GameState.risorse.oro) == 15, "tasse: 20 + 10 - 15 = 15 oro (era %d)" % GameState.risorse.oro)
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
	_verifica(absf(GameState.risorse.cibo - 56.0) < 0.2, "raccoglitore migliorato: 40 -> 56 cibo (%.1f)" % GameState.risorse.cibo)

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

	# Popolazione: arrivano persone se si è felici e pieni di scorte, e c'è posto.
	GameState.nuova_partita(3)
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

	# Strade: 1 pietra in piano, 2 in salita; non si costruisce sopra.
	var ts := TerrenoFeudo.new(13)
	var piano := ts.trova_posto("casa", TerrenoFeudo.centro_feudo())
	var percorso := TerrenoFeudo.percorso(piano, piano + Vector2i(1, 0))
	_verifica(ts.costo_strada(percorso) == 2, "due celle in piano: 2 pietra")
	var collina_s := Vector2i(-1, -1)
	for i in ts.celle.size():
		var c := Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
		if ts.celle[i] == TerrenoFeudo.Tipo.COLLINA and ts.nel_feudo(c):
			collina_s = c
			break
	_verifica(ts.costo_strada([collina_s]) == 2, "in salita costa 2 pietra")
	ts.aggiungi_strada(percorso)
	_verifica(not ts.posizione_valida("casa", piano), "non si costruisce sulle strade")
	_verifica(ts.costo_strada(percorso) == 0, "una strada già fatta non costa")
	var acqua_c := Vector2i(-1, -1)
	for i in ts.celle.size():
		if ts.celle[i] == TerrenoFeudo.Tipo.FIUME and ts.nel_feudo(Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)):
			acqua_c = Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
			break
	_verifica(ts.costo_strada([acqua_c]) == -1, "niente strade sull'acqua")

	# Salvataggio della versione 4: strade, piantine, colture, mercato.
	GameState.ricomincia()
	GameState.avvia()
	var c0 := TerrenoFeudo.centro_feudo() + Vector2i(6, 6)
	GameState.risorse.pietra = 50.0
	var strada_ok := GameState.costruisci_strada(TerrenoFeudo.percorso(GameState.terreno.trova_posto("casa", c0), GameState.terreno.trova_posto("casa", c0)))
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
	for c in GameState._bordo(dimora):
		tocca = tocca or GameState.terreno.strada_a(c)
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
	var lontano := GameState.aggiungi_gratis("raccoglitore", GameState.terreno.trova_posto("raccoglitore", piazza_b.cella + Vector2i(0, 9)), 1.0)
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

	print("TEST: %s (%d errori)" % ["OK" if _errori == 0 else "FALLITI", _errori])
	get_tree().quit(1 if _errori > 0 else 0)


func _verifica(condizione: bool, descrizione: String) -> void:
	if condizione:
		print("  ok   ", descrizione)
	else:
		_errori += 1
		print("  FAIL ", descrizione)
