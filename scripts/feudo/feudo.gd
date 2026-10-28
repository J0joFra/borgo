extends Node3D
## Scena del feudo: crea luce, terreno, edifici, telecamera e interfaccia,
## e gestisce i gesti (trascinare, pizzicare, toccare) con il dito o con il mouse.

enum Modo { NORMALE, PIAZZA, STRADA, MURA, SPOSTA }

const SOGLIA_TOCCO := 6.0  # oltre questa distanza un tocco diventa trascinamento
const COLORI_LUCE := [Color("fff6e8"), Color("fff0d0"), Color("ffd6a8"), Color("dfe8ff")]

var vista: VistaTerreno
var camera: CameraIso
var hud: Hud
var segni: SegniEdifici
var banditi: Banditi3D
var luce: DirectionalLight3D

var modo := Modo.NORMALE
var _edifici: Dictionary = {}  # id -> Edificio3D
var _anteprima: MeshInstance3D
var _tipo := ""
var _cella := Vector2i.ZERO
var _selezionato := -1
var _rot := 0  # rotazione dell'edificio da piazzare (0..3, di 90° in 90°)
var _strada_da := Vector2i(-1, -1)  # vertice da cui parte la strada (o cella da cui partono le mura)
var _strada_vertici: Array[Vector2i] = []
var _mura_celle: Array[Vector2i] = []
var _lato_toccato := -1  # lato di strada esistente selezionato
var _muro_toccato := Vector2i(-1, -1)
var _sposta_id := -1          # l'edificio che si sta spostando
var _sposta_da := Vector2i.ZERO  # da dove parte (si va al massimo 2 celle più in là)

var _dita: Dictionary = {}  # indice -> posizione
var _inizio := Vector2.ZERO
var _mosso := false
var _distanza_pizzico := 0.0


func _ready() -> void:
	GameState.avvia()
	GameState.nel_feudo = true
	Audio.musica("feudo")
	_crea_ambiente()

	vista = VistaTerreno.new()
	add_child(vista)
	vista.costruisci(GameState.terreno)
	for b in GameState.buildings:
		_crea_edificio(b)
	var abitanti := Abitanti3D.new()
	abitanti.vista = vista
	add_child(abitanti)
	banditi = Banditi3D.new()
	banditi.vista = vista
	add_child(banditi)
	_anteprima = MeshInstance3D.new()
	_anteprima.visible = false
	add_child(_anteprima)

	camera = CameraIso.new()
	# la visuale resta sopra il feudo, con un margine per vedere un po' oltre il confine
	var f := TerrenoFeudo.area
	var margine := 8.0
	camera.limiti = Rect2(Vector2(f.position) * VistaTerreno.CELLA - Vector2.ONE * margine,
		Vector2(f.size) * VistaTerreno.CELLA + Vector2.ONE * margine * 2.0)
	add_child(camera)
	var centro := Vector2(TerrenoFeudo.centro_feudo()) * VistaTerreno.CELLA
	camera.position = Vector3(centro.x, 0, centro.y)
	camera.oltre_zoom_minimo.connect(_vai_al_regno)

	# i segni sopra gli edifici stanno sotto l'interfaccia
	var livello_segni := CanvasLayer.new()
	livello_segni.layer = 0
	add_child(livello_segni)
	segni = SegniEdifici.new()
	segni.camera = camera.camera
	segni.vista = vista
	livello_segni.add_child(segni)

	hud = Hud.new()
	add_child(hud)
	hud.costruisci.connect(_inizia_piazzamento)
	hud.conferma_piazzamento.connect(_conferma_piazzamento)
	hud.annulla_piazzamento.connect(_termina_piazzamento)
	hud.cambia_lavoratori.connect(_cambia_lavoratori)
	hud.demolisci.connect(GameState.demolisci)
	hud.migliora.connect(GameState.migliora)
	hud.coltura.connect(GameState.cambia_coltura)
	hud.strade.connect(_inizia_strada)
	hud.collega.connect(_collega)
	hud.gira.connect(_gira)
	hud.sposta.connect(_inizia_spostamento)
	hud.mura.connect(_inizia_mura)
	hud.ruota_edificio.connect(_ruota_piazzamento)
	hud.rimuovi_strada.connect(_rimuovi_strada)
	hud.chiudi_pannello.connect(_seleziona.bind(-1))
	hud.ruota.connect(camera.ruota)
	hud.vai_al_regno.connect(_vai_al_regno)
	hud.nuova_partita.connect(_ricomincia)

	GameState.building_added.connect(_crea_edificio)
	GameState.building_removed.connect(_rimuovi_edificio)
	GameState.building_moved.connect(_edificio_spostato)
	GameState.season_changed.connect(_cambia_stagione)
	GameState.changed.connect(_aggiorna_edifici)
	GameState.game_ended.connect(_partita_finita)
	GameState.terreno_cambiato.connect(_terreno_cambiato)
	GameState.building_added.connect(_su_edificio_aggiunto)
	vista.aggiorna_ciuffi()
	GameState.changed.emit()  # l'HUD è pronto: rinfresca i numeri
	GameState.battaglia_iniziata.connect(func(_b): _vai_in_battaglia())
	if GameState.capo < 0:
		_inizia_prologo()
	elif not GameState.battaglia.is_empty():
		_vai_in_battaglia.call_deferred()  # una battaglia lasciata a metà
	else:
		GameState.riprendi_evento()


## Partita nuova: tempo fermo, visuale vicina al falò e scelta della casata che guida.
func _inizia_prologo() -> void:
	GameState.velocita = 0
	for b in GameState.buildings:
		if GameState.edifici[b.tipo].get("forma", "") == "falo":
			var p := vista.centro_area(b.cella, _taglia(b.tipo))
			camera.position = Vector3(p.x, 0, p.z)
	camera.cambia_zoom(1)
	hud.visible = false  # il prologo occupa tutto lo schermo
	var prologo := Prologo.new()
	add_child(prologo)
	prologo.finito.connect(func():
		hud.visible = true
		GameState.velocita = 1
		if GameState.opzioni.tutorial:
			GameState.inizia_tutorial()
		GameState.changed.emit())


func _crea_ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe3ef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffffff")
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	luce = DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-55, -30, 0)
	luce.light_energy = 0.75
	luce.light_color = COLORI_LUCE[GameState.stagione]
	luce.shadow_enabled = true
	luce.directional_shadow_max_distance = 160.0
	add_child(luce)


func _notification(what: int) -> void:
	# Su mobile l'app può essere chiusa in qualsiasi momento: salviamo quando va in pausa.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.salva()


# --- Edifici -----------------------------------------------------------------

func _crea_edificio(b: Dictionary) -> void:
	var e := Edificio3D.new()
	e.b = b
	e.vista = vista
	add_child(e)
	_edifici[b.id] = e


func _su_edificio_aggiunto(_b: Dictionary) -> void:
	vista.aggiorna_ciuffi()


func _terreno_cambiato(celle: Array) -> void:
	vista.aggiorna_celle(celle)
	vista.aggiorna_ciuffi()


func _rimuovi_edificio(id: int) -> void:
	vista.aggiorna_ciuffi.call_deferred()
	if _edifici.has(id):
		_edifici[id].queue_free()
		_edifici.erase(id)
	if id == _selezionato:
		_seleziona(-1)


## Spostato o girato: si rifà il modello 3D al posto nuovo (e resta selezionato).
func _edificio_spostato(b: Dictionary) -> void:
	var era_selezionato: bool = b.id == _selezionato
	if _edifici.has(b.id):
		_edifici[b.id].queue_free()
		_edifici.erase(b.id)
	_crea_edificio(b)
	vista.aggiorna_ciuffi()
	if era_selezionato:
		_seleziona(b.id)


func _gira(id: int) -> void:
	if not GameState.gira(id):
		hud.mostra_avviso("Non c'è posto per girarlo qui: prova a spostarlo prima.")


## Modalità sposta: l'edificio si toglie dal suo posto (solo per l'anteprima) e si sceglie dove
## metterlo, al massimo 2 celle più in là; si può anche girare.
func _inizia_spostamento(id: int) -> void:
	var b := GameState.trova(id)
	if b.is_empty():
		return
	_termina_piazzamento()
	_seleziona(-1)
	modo = Modo.SPOSTA
	_sposta_id = id
	_sposta_da = b.cella
	_tipo = b.tipo
	_rot = int(b.get("rot", 0))
	GameState.terreno.libera(b)
	if _edifici.has(id):
		_edifici[id].visible = false
	segni.nascosto = id
	_aggiorna_spostamento(b.cella + _taglia(_tipo) / 2)


func _aggiorna_spostamento(centro: Vector2i) -> void:
	var taglia := _taglia(_tipo)
	var m := GameState.SPOSTAMENTO_MASSIMO
	var cella := centro - taglia / 2
	_cella = Vector2i(clampi(cella.x, _sposta_da.x - m, _sposta_da.x + m), clampi(cella.y, _sposta_da.y - m, _sposta_da.y + m))
	var valida := GameState.terreno.posizione_valida(_tipo, _cella, _rot)
	_mostra_box(taglia, valida)
	# la zona in cui si può spostare
	var zona: Array[Vector2i] = []
	for y in range(_sposta_da.y - m, _sposta_da.y + taglia.y + m):
		for x in range(_sposta_da.x - m, _sposta_da.x + taglia.x + m):
			zona.append(Vector2i(x, y))
	vista.mostra_celle(zona, Color(1.0, 0.85, 0.4, 0.35))
	hud.mostra_strada("Tocca dove metterlo: al massimo %d caselle più in là (riquadro chiaro). Puoi anche girarlo." % m
		if valida else "Qui non ci sta: tocca un altro punto nel riquadro chiaro.", valida, "Sposta")


func _aggiorna_edifici() -> void:
	for e in _edifici.values():
		e.aggiorna()


func _cambia_stagione(stagione: int, _anno: int) -> void:
	vista.applica_stagione(stagione)
	create_tween().tween_property(luce, "light_color", COLORI_LUCE[stagione], 1.5)


# --- Azioni ------------------------------------------------------------------

func _inizia_piazzamento(tipo: String) -> void:
	_seleziona(-1)
	modo = Modo.PIAZZA
	_tipo = tipo
	_rot = 0
	_sposta_anteprima(_cella_sotto(get_viewport().get_visible_rect().size / 2.0))


## Gira di 90° l'edificio da piazzare (tasto R o pulsante Ruota).
func _ruota_piazzamento() -> void:
	if modo != Modo.PIAZZA and modo != Modo.SPOSTA:
		return
	var centro := _cella + _taglia(_tipo) / 2
	_rot = (_rot + 1) % 4
	if modo == Modo.SPOSTA:
		_aggiorna_spostamento(centro)
	else:
		_sposta_anteprima(centro)


func _sposta_anteprima(centro: Vector2i) -> void:
	var taglia := _taglia(_tipo)
	_cella = centro - taglia / 2
	var valida := GameState.terreno.posizione_valida(_tipo, _cella, _rot)
	var dentro := GameState.terreno.dentro(_cella)
	_mostra_box(taglia, valida, _cella if dentro else centro)
	# le celle che contano per la resa (bosco, rocce, acqua, fertilità) si colorano
	vista.mostra_zona(_tipo, _cella if dentro else centro)
	var stima := GameState.stima_produzione(_tipo, _cella) if dentro else ""
	hud.mostra_piazzamento(_tipo, valida, stima)


## Il riquadro verde (o rosso) dove andrà l'edificio.
func _mostra_box(taglia: Vector2i, valida: bool, dove := Vector2i(-1, -1)) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(taglia.x * VistaTerreno.CELLA, 0.3, taglia.y * VistaTerreno.CELLA)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 0.3, 0.5) if valida else Color(0.95, 0.25, 0.2, 0.5)
	box.material = mat
	_anteprima.mesh = box
	_anteprima.position = vista.centro_area(_cella if dove.x < 0 else dove, taglia) + Vector3(0, 0.15, 0)
	# una freccia sul lato del davanti, per vedere come è girato
	_anteprima.rotation.y = -_rot * PI / 2.0 if taglia.x == taglia.y else 0.0
	_anteprima.visible = true


# --- Strade ---------------------------------------------------------------------

## Modalità strada: un tocco fissa il vertice di partenza, i tocchi dopo la fine (percorso a L
## lungo i bordi delle celle).
func _inizia_strada() -> void:
	_termina_piazzamento()
	_seleziona(-1)
	modo = Modo.STRADA
	_strada_da = Vector2i(-1, -1)
	_strada_vertici = []
	hud.mostra_strada("Tocca un edificio o un punto: la strada parte da sola dalle strade già collegate e gira attorno a case, bosco e colline. 1 pietra per tratto (2 in salita).", false)


## Un tocco: la strada più conveniente dalla rete collegata fin lì (o fino all'edificio toccato).
func _tocco_strada(vertice: Vector2i, id_edificio := -1) -> void:
	var b := GameState.trova(id_edificio) if id_edificio >= 0 else {}
	_strada_vertici = GameState.strada_per(b) if not b.is_empty() else GameState.strada_verso([vertice])
	if _strada_vertici.is_empty():
		vista.nascondi_zona()
		hud.mostra_strada("Lì non si arriva: case, bosco, rocce o colline chiudono ogni passaggio. Prova un altro punto.", false)
		return
	if _strada_vertici.size() < 2:
		vista.nascondi_zona()
		hud.mostra_strada("%s è già collegato alla rete di strade." % ("L'edificio" if not b.is_empty() else "Questo punto"), false)
		return
	var v := GameState.verifica_strada(_strada_vertici)
	var colore := Color(0.95, 0.8, 0.45, 0.85) if v.ok else Color(0.95, 0.25, 0.2, 0.7)
	vista.mostra_lati(TerrenoFeudo.lati_di(_strada_vertici), colore)
	if not v.ok:
		hud.mostra_strada("Non si può: %s. Prova un altro punto." % v.motivo, false)
	else:
		var basta: bool = GameState.risorse.pietra >= v.pietra and GameState.risorse.legna >= v.legna
		var parti: Array[String] = ["%d tratti" % v.lati]
		if v.ponti > 0:
			parti.append("ponte di %d" % v.ponti)
		if v.passerelle > 0:
			parti.append("passerella di %d" % v.passerelle)
		if v.porte > 0:
			parti.append("porta nelle mura")
		var costo: Array[String] = []
		if v.pietra > 0:
			costo.append("%d pietra" % v.pietra)
		if v.legna > 0:
			costo.append("%d legna" % v.legna)
		parti.append(", ".join(costo) if not costo.is_empty() else "già fatta")
		hud.mostra_strada(" · ".join(parti) + ("" if basta else " (non basta)"), basta and not costo.is_empty())


## Dal pannello di un edificio non collegato: mostra subito la strada che lo collega.
func _collega(id: int) -> void:
	_inizia_strada()
	_tocco_strada(Vector2i(-1, -1), id)


func _costruisci_strada() -> void:
	if GameState.costruisci_strada(_strada_vertici):
		_strada_da = Vector2i(-1, -1)
		_strada_vertici = []
		vista.nascondi_zona()
		hud.mostra_strada("Strada fatta. Tocca un altro punto per continuare, o Annulla.", false)


## Modalità mura: come le strade, ma cella per cella.
func _inizia_mura() -> void:
	_termina_piazzamento()
	_seleziona(-1)
	modo = Modo.MURA
	_strada_da = Vector2i(-1, -1)
	_mura_celle = []
	hud.mostra_strada("Tocca dove iniziano le mura, poi dove finiscono (%d pietra per cella). Chiudi il borgo tutto attorno per difenderlo meglio; dove passa una strada si apre una porta." % TerrenoFeudo.COSTO_MURA, false, "Mura")


func _tocco_mura(cella: Vector2i) -> void:
	if _strada_da.x < 0:
		_strada_da = cella
	_mura_celle = TerrenoFeudo.percorso(_strada_da, cella)
	var v := GameState.verifica_mura(_mura_celle)
	vista.mostra_celle(_mura_celle, Color(0.75, 0.72, 0.65, 0.7) if v.ok else Color(0.95, 0.25, 0.2, 0.5))
	if not v.ok:
		hud.mostra_strada("Non si può: %s." % v.motivo, false, "Mura")
	else:
		var basta: bool = GameState.risorse.pietra >= v.pietra
		hud.mostra_strada("%d celle · %d pietra%s" % [v.celle, v.pietra, "" if basta else " (non basta)"], basta and v.celle > 0, "Mura")


func _costruisci_mura() -> void:
	if GameState.costruisci_mura(_mura_celle):
		_strada_da = Vector2i(-1, -1)
		_mura_celle = []
		vista.nascondi_zona()
		hud.mostra_strada("Mura fatte. Tocca per continuare, o Annulla.", false, "Mura")


func _rimuovi_strada() -> void:
	if _muro_toccato.x >= 0:
		GameState.demolisci_muro(_muro_toccato)
	elif _lato_toccato >= 0:
		GameState.rimuovi_strada(_lato_toccato)
	_lato_toccato = -1
	_muro_toccato = Vector2i(-1, -1)
	hud.nascondi_pannello()


func _conferma_piazzamento() -> void:
	if modo == Modo.STRADA:
		_costruisci_strada()
		return
	if modo == Modo.MURA:
		_costruisci_mura()
		return
	if modo == Modo.SPOSTA:
		var id := _sposta_id
		if GameState.riposiziona(id, _cella, _rot):
			_sposta_id = -1  # già al posto nuovo: _termina_piazzamento non deve rimetterlo
			_termina_piazzamento()
			_seleziona(id)
		return
	if modo != Modo.PIAZZA or not GameState.terreno.posizione_valida(_tipo, _cella, _rot):
		return
	var b := GameState.piazza(_tipo, _cella, 1.0, _rot)
	_termina_piazzamento()
	if not b.is_empty():
		_seleziona(b.id)


func _termina_piazzamento() -> void:
	if modo == Modo.SPOSTA and _sposta_id >= 0:
		# annullato: l'edificio torna com'era
		var b := GameState.trova(_sposta_id)
		if not b.is_empty():
			GameState.terreno.occupa(b)
		if _edifici.has(_sposta_id):
			_edifici[_sposta_id].visible = true
	_sposta_id = -1
	segni.nascosto = -1
	modo = Modo.NORMALE
	_tipo = ""
	_anteprima.visible = false
	vista.nascondi_zona()
	hud.nascondi_pannello()


func _seleziona(id: int) -> void:
	if _edifici.has(_selezionato):
		_edifici[_selezionato].seleziona(false)
	_selezionato = id
	if _edifici.has(id):
		_edifici[id].seleziona(true)
		hud.mostra_edificio(id)
		_mostra_tiro(GameState.trova(id))
	elif modo == Modo.NORMALE:
		hud.nascondi_pannello()
		vista.nascondi_zona()


## Per una torre di guardia: il riquadro dove arrivano le frecce dei suoi arcieri.
func _mostra_tiro(b: Dictionary) -> void:
	var r := int(GameState.edifici[b.tipo].get("raggio_tiro", 0))
	if r <= 0:
		vista.nascondi_zona()
		return
	var t := GameState.taglia_di(b)
	var celle := []
	for y in range(b.cella.y - r, b.cella.y + t.y + r):
		for x in range(b.cella.x - r, b.cella.x + t.x + r):
			celle.append(Vector2i(x, y))
	vista.mostra_celle(celle, Color(1.0, 0.85, 0.3, 0.35))


func _cambia_lavoratori(id: int, delta: int) -> void:
	if delta > 0:
		GameState.aggiungi_lavoratore(id)
	else:
		GameState.togli_lavoratore(id)


## L'esercito è arrivato: si va sul campo di battaglia (e alla fine si torna qui).
func _vai_in_battaglia() -> void:
	GameState.salva()
	GameState.nel_feudo = false
	get_tree().change_scene_to_file("res://scenes/battaglia.tscn")


func _vai_al_regno() -> void:
	if GameState.finita:
		return
	GameState.salva()
	GameState.nel_feudo = false
	get_tree().change_scene_to_file("res://scenes/regno.tscn")


func _partita_finita(_vittoria: bool, _motivo: String) -> void:
	_termina_piazzamento()


func _ricomincia() -> void:
	GameState.ricomincia()
	get_tree().change_scene_to_file("res://scenes/regno.tscn")


func _tocco(posizione: Vector2) -> void:
	if GameState.finita:
		return
	var cella := _cella_sotto(posizione)
	if modo == Modo.PIAZZA:
		_sposta_anteprima(cella)
	elif modo == Modo.STRADA:
		var r := camera.raggio(posizione)
		_tocco_strada(vista.vertice_da_raggio(r[0], r[1]), GameState.terreno.edificio_a(cella))
	elif modo == Modo.MURA:
		_tocco_mura(cella)
	elif modo == Modo.SPOSTA:
		_aggiorna_spostamento(cella)
	else:
		var segno := segni.segno_a(posizione)
		if segno.get("azione", "") == "collega":
			_collega(int(segno.id))
			return
		var id := GameState.terreno.edificio_a(cella)
		if segno.get("azione", "") == "migliora":
			id = int(segno.id)
		vista.nascondi_zona()
		_seleziona(id)
		_lato_toccato = -1
		_muro_toccato = Vector2i(-1, -1)
		if id >= 0:
			return
		if GameState.terreno.muro_a(cella):
			_muro_toccato = cella
			hud.mostra_strada_esistente("Mura")
			return
		var r := camera.raggio(posizione)
		var k := GameState.terreno.lato_vicino(vista.punto_celle(r[0], r[1]))
		if k >= 0:
			_lato_toccato = k
			vista.mostra_lati([k], Color(1.0, 0.85, 0.3, 0.9))
			hud.mostra_strada_esistente()


func _cella_sotto(posizione: Vector2) -> Vector2i:
	var r := camera.raggio(posizione)
	return vista.cella_da_raggio(r[0], r[1])


func _taglia(tipo: String) -> Vector2i:
	return GameState.taglia_tipo(tipo, _rot)


# --- Gesti -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# Su telefono Godot genera anche eventi mouse "emulati" dai tocchi: li ignoriamo,
	# altrimenti ogni tocco verrebbe contato due volte.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_dita[event.index] = event.position
			if _dita.size() == 1:
				_inizio = event.position
				_mosso = false
			else:
				_mosso = true  # con due dita non è mai un tocco
				_distanza_pizzico = _distanza_dita()
		else:
			_dita.erase(event.index)
			if _dita.is_empty() and not _mosso:
				_tocco(event.position)
	elif event is InputEventScreenDrag:
		_dita[event.index] = event.position
		if _dita.size() == 1:
			_trascina(event.position, event.relative)
		elif _dita.size() == 2:
			var d := _distanza_dita()
			if d > _distanza_pizzico * 1.4 or d < _distanza_pizzico / 1.4:
				camera.cambia_zoom(1 if d > _distanza_pizzico else -1)
				_distanza_pizzico = d

	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_inizio = event.position
					_mosso = false
				elif not _mosso:
					_tocco(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					camera.cambia_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					camera.cambia_zoom(-1)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_trascina(event.position, event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				camera.ruota(-1)
			KEY_E:
				camera.ruota(1)
			KEY_R:
				_ruota_piazzamento()


func _trascina(posizione: Vector2, relativo: Vector2) -> void:
	if not _mosso and posizione.distance_to(_inizio) > SOGLIA_TOCCO:
		_mosso = true
		relativo = posizione - _inizio  # recupera il tratto fatto prima della soglia
	if _mosso:
		camera.sposta(relativo)


func _distanza_dita() -> float:
	var punti := _dita.values()
	return (punti[0] as Vector2).distance_to(punti[1]) if punti.size() >= 2 else 0.0
