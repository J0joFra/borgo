extends Node
## Prova visiva: regno, entrata nel feudo, costruzioni, rotazione, stagioni.
## Salva screenshot in user:// (serve un display, non funziona con --headless).

func _ready() -> void:
	_via.call_deferred()

func _via() -> void:
	GameState.cancella_salvataggio()
	var segnaposto := Node.new()
	get_tree().root.add_child(segnaposto)
	get_tree().current_scene = segnaposto  # così il cambio di scena non distrugge questo nodo
	get_tree().change_scene_to_file("res://scenes/regno.tscn")
	await _attendi(1.0)
	await _scatta("1_regno")
	var regno = get_tree().current_scene
	regno._tocca(regno._regioni[(regno._mia + 1) % regno._regioni.size()].centro)
	await _attendi(0.2)
	await _scatta("2_regno_info")
	regno._entra()
	await _attendi(1.5)
	var f = get_tree().current_scene
	await _scatta("3_feudo")
	var t: TerrenoFeudo = GameState.terreno
	var c := Vector2i(24, 24)
	for tipo in ["taglialegna", "raccoglitore", "magazzino"]:
		var p := t.trova_posto(tipo, c + Vector2i(0, 4))
		GameState.risorse.legna = 100.0
		GameState.piazza(tipo, p, t.bonus(tipo, p))
	f._inizia_piazzamento("cava")
	GameState.velocita = 3
	await _attendi(2.0)
	await _scatta("4_cantiere")
	f._termina_piazzamento()
	await _attendi(9.0)
	f._seleziona(GameState.buildings[3].id)
	await _attendi(0.8)
	await _scatta("5_costruito")
	# vetrina: un esemplare di ogni edificio, già finito
	GameState.livello = 2
	for r in GameState.risorse:
		GameState.risorse[r] = 500.0
	var vicino := Vector2i(24, 24)
	for tipo in ["mulino", "chiesa", "mercato", "maniero", "campo", "taverna", "fabbro", "cacciatore", "magazzino"]:
		var p := t.trova_posto(tipo, vicino)
		if p.x >= 0:
			var nuovo := GameState.piazza(tipo, p, 1.0)
			nuovo.progresso = 1.0 if tipo != "taverna" else 0.5
	await _attendi(1.5)
	f.camera.position = Vector3(50, 0, 50)
	await _scatta("5b_vetrina")
	f.camera.cambia_zoom(1)
	await _attendi(0.5)
	await _scatta("5c_vetrina_vicino")
	f.camera.cambia_zoom(-1)
	f.camera.cambia_zoom(1)
	f.camera.ruota(1)
	await _attendi(1.0)
	await _scatta("6_zoom_ruotato")
	for i in 120:
		GameState._tick()
	await _attendi(2.0)
	f.camera.cambia_zoom(-1)
	f.camera.cambia_zoom(-1)
	await _attendi(1.0)
	await _scatta("7_autunno_largo")
	for i in 60:
		GameState._tick()
	await _attendi(2.0)
	await _scatta("8_inverno")
	# tocco simulato: proietta un edificio sullo schermo e verifica che il raggio trovi la sua cella
	var b: Dictionary = GameState.buildings[0]
	var mondo: Vector3 = f.vista.centro_area(b.cella, Vector2i(2, 2))
	var schermo: Vector2 = f.camera.camera.unproject_position(mondo)
	print("TOCCO cella attesa area ", b.cella, " trovata ", f._cella_sotto(schermo))
	f._vai_al_regno()
	await _attendi(1.0)
	print("SCENA ", get_tree().current_scene.name)
	get_tree().quit()

func _attendi(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % nome)
