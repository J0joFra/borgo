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
	await _attendi(1.0)
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

	# tende migliorate: una al livello 2, una al 3
	var tende := GameState.buildings.filter(func(b): return b.tipo == "tenda")
	GameState.migliora(tende[0].id)
	GameState.migliora(tende[1].id)
	GameState.migliora(tende[1].id)
	GameState.migliora(tl.id)
	var falo: Dictionary = GameState.buildings[0]
	var pf: Vector3 = f.vista.centro_area(falo.cella, Vector2i(2, 2))
	f.camera.position = Vector3(pf.x, 0, pf.z)
	await _attendi(1.0)
	await _scatta("8_miglioramenti")

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

	f.camera.cambia_zoom(-1)
	await _attendi(1.0)
	await _scatta("10_largo")
	for i in 180:
		GameState._tick()
	await _attendi(1.5)
	await _scatta("11_inverno")

	f._vai_al_regno()
	await _attendi(1.0)
	print("SCENA ", get_tree().current_scene.name)
	await _scatta("9_regno")
	get_tree().quit()


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
