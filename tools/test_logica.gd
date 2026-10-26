extends Node
## Test della logica di gioco, senza grafica:
##   godot --headless --path . res://tools/test_logica.tscn

var _errori := 0


func _ready() -> void:
	GameState.cancella_salvataggio()
	GameState.nuova_partita(42)
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
	for i in 3:
		GameState.aggiungi_gratis("casa", Vector2i(i * 3, 0), 1.0)
	GameState.risorse.cibo = 0.0
	for i in 60:
		GameState._tick()
	_verifica(GameState.abitanti == 8, "fame: 10 -> 8 abitanti (era %d)" % GameState.abitanti)
	_verifica(GameState.stagione == GameState.ESTATE, "dopo 60 tick è estate")

	# Produzione: raccoglitore con 2 lavoratori = 40 cibo a stagione.
	GameState.nuova_partita(42)
	var r := GameState.aggiungi_gratis("raccoglitore", Vector2i(0, 0), 1.0)
	r.lavoratori = 2
	GameState.abitanti = 0
	GameState.risorse.cibo = 0.0
	for i in 60:
		GameState._tick()
	_verifica(absf(GameState.risorse.cibo - 40.0) < 0.1, "raccoglitore: +40 cibo (%.1f)" % GameState.risorse.cibo)

	# Catena grano -> farina -> pane con ingredienti limitati.
	GameState.nuova_partita(42)
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
	GameState.abitanti = 25
	GameState.felicita = 55.0
	GameState.aggiungi_gratis("magazzino", Vector2i(0, 0), 1.0)
	GameState._controlla_livello()
	_verifica(GameState.livello == 1 and GameState.sbloccato("mulino"), "Borgo sbloccato")

	# Salvataggio e caricamento.
	GameState.nuova_partita(7)
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
	var terreno := TerrenoFeudo.new(42)
	GameState.terreno = terreno
	var centro := Vector2i(TerrenoFeudo.LATO / 2, TerrenoFeudo.LATO / 2)
	_verifica(terreno.posizione_valida("casa", centro), "il centro della mappa è libero")
	var casa := GameState.aggiungi_gratis("casa", centro, 1.0)
	_verifica(not terreno.posizione_valida("casa", centro + Vector2i(1, 1)), "niente edifici sovrapposti")
	_verifica(terreno.edificio_a(centro + Vector2i(1, 1)) == casa.id, "la cella sa quale edificio contiene")
	GameState.demolisci(casa.id)
	_verifica(terreno.posizione_valida("casa", centro), "demolendo la cella torna libera")
	var collina := Vector2i(-1, -1)
	for i in terreno.celle.size():
		if terreno.celle[i] == TerrenoFeudo.Tipo.COLLINA:
			collina = Vector2i(i % TerrenoFeudo.LATO, i / TerrenoFeudo.LATO)
			break
	_verifica(collina.x >= 0, "la mappa ha almeno una collina")
	_verifica(not terreno.posizione_valida("miniera", centro), "la miniera non va sull'erba")
	var posto_miniera := terreno.trova_posto("miniera", collina)
	_verifica(posto_miniera.x >= 0 and terreno.tipo_a(posto_miniera) == TerrenoFeudo.Tipo.COLLINA, "la miniera trova posto su una collina")
	var posto := terreno.trova_posto("taglialegna", centro)
	_verifica(posto.x >= 0, "trova_posto trova un posto per il taglialegna")
	GameState.terreno = null

	print("TEST: %s (%d errori)" % ["OK" if _errori == 0 else "FALLITI", _errori])
	get_tree().quit(1 if _errori > 0 else 0)


func _verifica(condizione: bool, descrizione: String) -> void:
	if condizione:
		print("  ok   ", descrizione)
	else:
		_errori += 1
		print("  FAIL ", descrizione)
