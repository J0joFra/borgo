extends Node
## Prova rapida dell'interfaccia: una partita già avviata, qualche edificio, poche schermate
## (in user://rapida_*.png). Per controllare la grafica senza aspettare la prova visiva intera.


func _ready() -> void:
	_via.call_deferred()


func _via() -> void:
	GameState.cancella_salvataggio()
	GameState.ricomincia()
	var segnaposto := Node.new()
	get_tree().root.add_child(segnaposto)
	get_tree().current_scene = segnaposto
	get_tree().change_scene_to_file("res://scenes/feudo.tscn")
	await _attendi(2.0)
	var f = get_tree().current_scene
	var prologo: Prologo = f.find_children("*", "Prologo", true, false)[0]
	prologo._carte[0].button_pressed = true
	prologo._seleziona(0)
	prologo._conferma_scelta()
	prologo.finito.emit()
	prologo.queue_free()
	GameState.tutorial_passo = -1
	GameState.suggerimenti_attivi = false
	GameState._tick_evento = -1
	await _attendi(0.5)
	var t: TerrenoFeudo = GameState.terreno
	var c := TerrenoFeudo.centro_feudo()
	GameState.risorse.legna = 90.0
	GameState.risorse.pietra = 90.0
	var tl := GameState.piazza("taglialegna", t.trova_posto("taglialegna", c + Vector2i(-5, -3)), 1.0)
	tl.progresso = 1.0
	tl.lavoratori = 2
	var rc := GameState.piazza("raccoglitore", t.trova_posto("raccoglitore", c + Vector2i(4, 5)), 1.0)
	rc.progresso = 1.0
	rc.lavoratori = 2
	GameState.piazza("casa", t.trova_posto("casa", c + Vector2i(-4, 4)), 1.0)
	GameState.tick_in_stagione = 18
	GameState.changed.emit()
	f.camera.position = Vector3(c.x * 2.0, 0, c.y * 2.0)
	await _attendi(1.5)
	await _scatta("rapida_1_mappa")
	f._collega(rc.id)
	await _attendi(0.5)
	await _scatta("rapida_2_collega")
	f._termina_piazzamento()
	f._seleziona(tl.id)
	await _attendi(0.5)
	await _scatta("rapida_3_pannello")
	f._seleziona(-1)
	f.hud._apri_finestra(f.hud._mercato)
	await _attendi(0.5)
	await _scatta("rapida_4_mercato")
	get_tree().quit()


func _attendi(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _scatta(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % nome)
