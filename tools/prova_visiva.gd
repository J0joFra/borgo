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

	# un po' di vita: taglialegna e raccoglitore, poi il tempo scorre
	var t: TerrenoFeudo = GameState.terreno
	var c := TerrenoFeudo.centro_feudo()
	for tipo in ["taglialegna", "raccoglitore"]:
		var p := t.trova_posto(tipo, c + Vector2i(0, 6))
		GameState.piazza(tipo, p, t.bonus(tipo, p))
	GameState.velocita = 3
	await _attendi(12.0)
	for i in 20:
		GameState._tick()
	await _attendi(0.5)
	await _scatta("5_avviso_consigliere")
	f.hud._consiglio.visible = true
	f.hud._aggiorna()
	await _attendi(0.3)
	await _scatta("6_pannello_consiglio")
	f.hud._consiglio.visible = false

	f.camera.cambia_zoom(-1)
	f.camera.cambia_zoom(-1)
	f.camera.position.x = TerrenoFeudo.FEUDO.position.x * VistaTerreno.CELLA
	await _attendi(1.0)
	await _scatta("7_confine")
	var ora := Time.get_ticks_msec()
	for i in 120:
		GameState._tick()
	await _attendi(1.5)
	print("CAMBIO STAGIONE in circa ", Time.get_ticks_msec() - ora - 1500, " ms")
	await _scatta("8_autunno_confine")

	f._vai_al_regno()
	await _attendi(1.0)
	print("SCENA ", get_tree().current_scene.name)
	await _scatta("9_regno")
	get_tree().quit()


func _attendi(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % nome)
