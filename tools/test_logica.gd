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
	for i in 60:
		GameState._tick()
	_verifica(GameState.abitanti == 8, "fame: 10 -> 8 abitanti (era %d)" % GameState.abitanti)
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
	_verifica("al raccolto" in GameState.stima_produzione("campo", tz.trova_posto("campo", cb)), "il campo rende al raccolto, non a ogni stagione")

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

	# Miglioramenti: tenda -> tenda rinforzata -> capanna.
	GameState.nuova_partita(42)
	var tenda := GameState.aggiungi_gratis("tenda", Vector2i(0, 0), 1.0)
	var alloggi_prima := GameState.alloggi()
	GameState.risorse.legna = 100.0
	GameState.risorse.pietra = 100.0
	GameState.migliora(tenda.id)
	_verifica(int(tenda.livello) == 2 and GameState.alloggi() == alloggi_prima + 1, "tenda rinforzata: un posto in più")
	GameState.migliora(tenda.id)
	_verifica(GameState.def_di(tenda).nome == "Capanna" and GameState.alloggi() == alloggi_prima + 2, "terzo livello: capanna")
	_verifica(GameState.prossimo_miglioramento(tenda).is_empty() and not GameState.puo_migliorare(tenda), "oltre la capanna non si va")
	_verifica(int(GameState.risorse.legna) == 90 and int(GameState.risorse.pietra) == 92, "i miglioramenti costano legna e pietra")
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

	print("TEST: %s (%d errori)" % ["OK" if _errori == 0 else "FALLITI", _errori])
	get_tree().quit(1 if _errori > 0 else 0)


func _verifica(condizione: bool, descrizione: String) -> void:
	if condizione:
		print("  ok   ", descrizione)
	else:
		_errori += 1
		print("  FAIL ", descrizione)
