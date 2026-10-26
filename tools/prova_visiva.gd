extends Node
## Prova visiva: prologo davanti al falò, scelta della guida, mondo esteso col confine,
## consiglio, mappa del regno. Salva screenshot in user:// (serve un display, non --headless).


func _ready() -> void:
	_via.call_deferred()


func _via() -> void:
	GameState.cancella_salvataggio()
	GameState.ricomincia()
	var segnaposto := Node.new()
	get_tree().root.add_child(segnaposto)
	get_tree().current_scene = segnaposto  # così il cambio di scena non distrugge questo nodo
	var inizio := Time.get_ticks_msec()
	get_tree().change_scene_to_file("res://scenes/regno.tscn")
	await _attendi(2.5)
	var f = get_tree().current_scene
	print("SCENA ", f.name, " pronta in circa ", Time.get_ticks_msec() - inizio, " ms")
	await _scatta("1_prologo")

	var prologo: Prologo = f.find_children("*", "Prologo", true, false)[0]
	prologo._carte[1].button_pressed = true
	prologo._seleziona(1)
	await _attendi(0.3)
	await _scatta("2_scelta")
	prologo._conferma_scelta()
	await _attendi(0.3)
	await _scatta("3_consiglio_presentato")
	prologo.finito.emit()
	prologo.queue_free()
	GameState._tick_evento = -1  # le carte le mostriamo noi, più avanti
	await _attendi(1.5)
	await _scatta("4_falo")

	# un po' di vita: taglialegna nel bosco più fitto, raccoglitore e campo, poi il tempo scorre
	var t: TerrenoFeudo = GameState.terreno
	var c := TerrenoFeudo.centro_feudo()
	GameState.risorse.legna = 200.0
	GameState.risorse.pietra = 200.0
	var bosco := _posto_migliore("taglialegna", c)
	var tl := GameState.piazza("taglialegna", bosco, 1.0)
	GameState.piazza("raccoglitore", t.trova_posto("raccoglitore", c + Vector2i(0, 6)), 1.0)
	GameState.velocita = 3
	await _attendi(14.0)
	f.camera.position = Vector3((c.x + 1) * 2.0, 0, (c.y + 3) * 2.0)
	await _attendi(0.5)
	await _scatta("5_abitanti")

	f._inizia_piazzamento("campo")
	f._sposta_anteprima(_posto_migliore("campo", c) + Vector2i(1, 1))
	await _attendi(0.5)
	await _scatta("6_zona_campo")
	f._termina_piazzamento()
	f._inizia_piazzamento("taglialegna")
	f._sposta_anteprima(t.trova_posto("taglialegna", bosco + Vector2i(3, 0)) + Vector2i(1, 1))
	var p_tl: Vector3 = f.vista.centro_area(bosco, Vector2i(2, 2))
	f.camera.position = Vector3(p_tl.x, 0, p_tl.z)
	await _attendi(0.5)
	await _scatta("7_zona_bosco")
	f._termina_piazzamento()

	# una carta evento raccontata da un consigliere
	GameState._tick_evento = -1
	for carta in GameState.dati_eventi.carte:
		if carta.id == "profughi":
			GameState.mostra_evento(carta)
	await _attendi(0.5)
	await _scatta("8_carta_evento")
	GameState.scegli_evento(0)
	GameState._tick_evento = -1

	# le tende si strappano a fine stagione: servono case
	GameState.migliora(tl.id)
	var falo: Dictionary = GameState.buildings[0]
	var pf: Vector3 = f.vista.centro_area(falo.cella, Vector2i(2, 2))
	for i in 2:
		var casa := GameState.piazza("casa", t.trova_posto("casa", falo.cella + Vector2i(5, -3 + i * 3)), 1.0)
		if not casa.is_empty():
			casa.progresso = 1.0
	GameState.abitanti += 6
	f.camera.position = Vector3(pf.x, 0, pf.z)
	await _attendi(1.0)
	var tenda: Array = GameState.buildings.filter(func(b): return b.tipo == "tenda")
	if not tenda.is_empty():
		f._seleziona(tenda[0].id)
	await _attendi(0.3)
	await _scatta("8b_tenda_e_case")
	f._seleziona(-1)

	# un anno e mezzo di taglio: restano i ceppi
	for i in 6:
		GameState._disbosca()
	f.camera.position = Vector3(p_tl.x, 0, p_tl.z)
	await _attendi(1.0)
	await _scatta("9_disboscamento")
	f._seleziona(tl.id)
	await _attendi(0.3)
	await _scatta("9b_pannello_taglialegna")
	f._seleziona(-1)

	# il forestale ripianta: alberelli che crescono
	var fo := GameState.piazza("forestale", t.trova_posto("forestale", bosco + Vector2i(0, 3)), 1.0)
	fo.progresso = 1.0
	fo.lavoratori = 1
	await _attendi(1.0)
	for st in 2:
		GameState._lavora_forestali()
	await _attendi(1.0)
	await _scatta("12_forestale_piantine")
	for st in 3:
		GameState._lavora_forestali()
	await _attendi(1.0)
	await _scatta("13_bosco_ricresciuto")

	# strada a L dal falò, campo con coltura, mercato
	var pf2: Vector3 = f.vista.centro_area(falo.cella, Vector2i(2, 2))
	f.camera.position = Vector3(pf2.x, 0, pf2.z)
	f._inizia_strada()
	f._tocco_strada(falo.cella + Vector2i(-1, 3))
	f._tocco_strada(falo.cella + Vector2i(6, 7))
	await _attendi(0.5)
	await _scatta("14_strada_anteprima")
	f._conferma_piazzamento()
	f._termina_piazzamento()
	var cmp := GameState.piazza("campo", _posto_migliore("campo", c), 1.0)
	cmp.progresso = 1.0
	cmp.lavoratori = 2
	cmp.seminato = true
	await _attendi(1.0)
	var pc: Vector3 = f.vista.centro_area(cmp.cella, Vector2i(3, 3))
	f.camera.position = Vector3(pc.x, 0, pc.z)
	f._seleziona(cmp.id)
	await _attendi(0.5)
	await _scatta("15_campo_coltura")
	f._seleziona(-1)
	f.hud._mercato.visible = true
	f.hud._aggiorna()
	await _attendi(0.3)
	await _scatta("16_mercato")
	f.hud._mercato.visible = false

	f.camera.cambia_zoom(-1)
	await _attendi(1.0)
	await _scatta("10_largo")
	for i in 180:
		GameState._tick()
		if not GameState.evento_attivo.is_empty():
			GameState.scegli_evento(GameState.evento_attivo.scelte.size() - 1)
	await _attendi(1.5)
	await _scatta("11_inverno")

	# dopo un anno il falò diventa la piazza; la gente cammina lungo le strade
	for i in 60:
		GameState._tick()
		if not GameState.evento_attivo.is_empty():
			GameState.scegli_evento(GameState.evento_attivo.scelte.size() - 1)
	GameState.velocita = 1
	GameState._tick_evento = -1
	f.camera.position = Vector3(pf.x + 4, 0, pf.z + 4)
	f.camera.cambia_zoom(1)
	await _attendi(6.0)
	await _scatta("17_piazza_strade")
	f._seleziona(fo.id)
	await _attendi(0.3)
	await _scatta("18_non_collegato")
	f._seleziona(-1)

	# Borgo: difese e banditi
	GameState.livello = 1
	GameState.risorse.legna = 200.0
	GameState.risorse.pietra = 200.0
	GameState.abitanti = maxi(GameState.abitanti, 14)
	var dimora_v: Dictionary = GameState.buildings.filter(func(b): return b.tipo == "dimora")[0]
	var torre := GameState.piazza("torre_guardia", t.trova_posto("torre_guardia", dimora_v.cella + Vector2i(-4, 3)), 1.0)
	torre.progresso = 1.0
	torre.lavoratori = 2
	for i in 4:
		var pal := GameState.piazza("palizzata", t.trova_posto("palizzata", dimora_v.cella + Vector2i(-6 + i, 6)), 1.0)
		if not pal.is_empty():
			pal.progresso = 1.0
	var arm := GameState.piazza("armeria", t.trova_posto("armeria", dimora_v.cella + Vector2i(4, 5)), 1.0)
	arm.progresso = 1.0
	GameState.risorse.armi = 4.0
	f.hud._apri_categoria("difese")
	await _attendi(0.5)
	await _scatta("19_menu_difese")
	f.hud._chiudi_menu()
	GameState._tick_evento = -1
	GameState._avvista_banditi()
	GameState.banditi.mancano = 6
	GameState.banditi.totale = 8
	var pd: Vector3 = f.vista.centro_area(dimora_v.cella, Vector2i(2, 2))
	var pe: Vector3 = f.vista.centro_area(GameState.banditi.entrata, Vector2i.ONE)
	f.camera.position = pd.lerp(pe, 0.35)
	f.camera.cambia_zoom(-1)
	GameState.velocita = 1
	await _attendi(3.0)
	print("BANDITI figure: ", f.banditi._figure.size(), " entrata ", GameState.banditi.entrata, " pos ", f.banditi._figure[0].position if not f.banditi._figure.is_empty() else Vector3.ZERO)
	if not f.banditi._figure.is_empty():
		var pb: Vector3 = f.banditi._figure[0].position
		f.camera.position = Vector3(pb.x, 0, pb.z).lerp(pd, 0.3)
	await _attendi(0.5)
	await _scatta("20_banditi_in_arrivo")
	f.hud._info.visible = true
	f.hud._aggiorna()
	await _attendi(0.3)
	await _scatta("21_info_tasse_difesa")
	f.hud._info.visible = false
	GameState.banditi.forza = 999.0
	GameState._incursione()
	f.camera.position = pd
	await _attendi(1.5)
	await _scatta("22_saccheggio")

	# ponte sul fiume e passerella sul lago, i più vicini alla dimora
	GameState.risorse.legna = 200.0
	GameState.risorse.pietra = 200.0
	var ponte := _attraversamento(TerrenoFeudo.Tipo.FIUME, dimora_v.cella, 6)
	if not ponte.is_empty():
		print("PONTE ", GameState.costruisci_strada(ponte), " ", ponte.size())
	var pontile := _pontile(dimora_v.cella)
	if not pontile.is_empty():
		print("PASSERELLA ", GameState.costruisci_strada(pontile), " ", pontile.size())
	GameState._tick_evento = -1
	GameState.velocita = 1
	if not ponte.is_empty():
		var pp: Vector3 = f.vista.centro_area(ponte[ponte.size() / 2], Vector2i.ONE)
		f.camera.position = Vector3(pp.x, 0, pp.z)
		f.camera.cambia_zoom(1)
		f.camera.cambia_zoom(1)
		await _attendi(1.0)
		await _scatta("23_ponte")
	if not pontile.is_empty():
		var pl: Vector3 = f.vista.centro_area(pontile[pontile.size() - 1], Vector2i.ONE)
		f.camera.position = Vector3(pl.x, 0, pl.z)
		await _attendi(1.0)
		await _scatta("24_passerella")
	# caserma e soldati
	GameState.livello = 1
	var cas := GameState.piazza("caserma", t.trova_posto("caserma", dimora_v.cella + Vector2i(-3, -5)), 1.0)
	cas.progresso = 1.0
	GameState.abitanti = maxi(GameState.abitanti, 30)
	for i in 3:
		var casa_x := GameState.piazza("casa", t.trova_posto("casa", dimora_v.cella + Vector2i(6, -6 + i * 3)), 1.0)
		if not casa_x.is_empty():
			casa_x.progresso = 1.0
	GameState.risorse.cibo = 200.0
	GameState.arruola()
	GameState.arruola()
	var pc2: Vector3 = f.vista.centro_area(cas.cella, Vector2i(3, 2))
	f.camera.position = Vector3(pc2.x, 0, pc2.z)
	await _attendi(4.0)
	await _scatta("25_caserma_soldati")
	f.hud._apri_finestra(f.hud._esercito)
	await _attendi(0.3)
	await _scatta("26_esercito")
	f.hud._apri_finestra(f.hud._esercito)
	GameState.risorse.oro = 200.0
	var spiata: String = GameState.regni.keys()[0]
	GameState.regni[spiata].spiato = true
	GameState.manda_spia(GameState.regni.keys()[1])
	GameState.attacca(GameState.regni.keys()[2])
	for k in GameState.regni:
		if GameState.regni[k].tipo == "libera":
			GameState.regni[k].conquistato = true
			GameState.regni[k].vassallo = GameState.consiglieri()[0]
			break

	f._vai_al_regno()
	await _attendi(1.0)
	print("SCENA ", get_tree().current_scene.name)
	await _scatta("9_regno")
	var mappa = get_tree().current_scene
	mappa._apri_scheda(spiata)
	await _attendi(0.3)
	await _scatta("27_scheda_regione")
	get_tree().quit()


## Una strada dritta che attraversa l'acqua del tipo dato vicino a una cella: da terra a terra.
func _attraversamento(tipo: int, vicino: Vector2i, massimo: int) -> Array[Vector2i]:
	var t: TerrenoFeudo = GameState.terreno
	var migliore: Array[Vector2i] = []
	var dmin := INF
	for y in range(vicino.y - 18, vicino.y + 18):
		for x in range(vicino.x - 18, vicino.x + 18):
			for dir in [Vector2i(1, 0), Vector2i(0, 1)]:
				var c := Vector2i(x, y)
				if t.tipo_a(c) == tipo or not t.nel_feudo(c):
					continue
				var celle: Array[Vector2i] = [c]
				var k := 1
				while k <= massimo and t.tipo_a(c + dir * k) == tipo:
					celle.append(c + dir * k)
					k += 1
				if k == 1 or k > massimo:
					continue
				celle.append(c + dir * k)
				var v := GameState.verifica_strada(celle)
				var d := Vector2(c - vicino).length()
				if v.ok and d < dmin:
					dmin = d
					migliore = celle
	return migliore


## Un pontile: dalla riva del lago, tre celle dentro l'acqua.
func _pontile(vicino: Vector2i) -> Array[Vector2i]:
	var t: TerrenoFeudo = GameState.terreno
	var migliore: Array[Vector2i] = []
	var dmin := INF
	for y in range(vicino.y - 20, vicino.y + 20):
		for x in range(vicino.x - 20, vicino.x + 20):
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c := Vector2i(x, y)
				if t.tipo_a(c) == TerrenoFeudo.Tipo.ACQUA or not t.nel_feudo(c):
					continue
				var celle: Array[Vector2i] = [c, c + dir, c + dir * 2, c + dir * 3]
				var v := GameState.verifica_strada(celle)
				var d := Vector2(c - vicino).length()
				if v.ok and v.passerelle == 3 and d < dmin:
					dmin = d
					migliore = celle
	return migliore


## Il posto valido con la resa più alta in un quadrato attorno a una cella.
func _posto_migliore(tipo: String, attorno: Vector2i) -> Vector2i:
	var t: TerrenoFeudo = GameState.terreno
	var migliore := t.trova_posto(tipo, attorno)
	var resa_migliore := -1.0
	for y in range(attorno.y - 16, attorno.y + 16, 2):
		for x in range(attorno.x - 16, attorno.x + 16, 2):
			var c := Vector2i(x, y)
			if t.posizione_valida(tipo, c):
				var r := t.resa(tipo, c, GameState.stagione)
				if r > resa_migliore:
					resa_migliore = r
					migliore = c
	return migliore


func _attendi(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % nome)
