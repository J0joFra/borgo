extends Node3D
## Scena del feudo: crea luce, terreno, edifici, telecamera e interfaccia,
## e gestisce i gesti (trascinare, pizzicare, toccare) con il dito o con il mouse.

enum Modo { NORMALE, PIAZZA, STRADA }

const SOGLIA_TOCCO := 6.0  # oltre questa distanza un tocco diventa trascinamento
const COLORI_LUCE := [Color("fff6e8"), Color("fff0d0"), Color("ffd6a8"), Color("dfe8ff")]

var vista: VistaTerreno
var camera: CameraIso
var hud: Hud
var banditi: Banditi3D
var luce: DirectionalLight3D

var modo := Modo.NORMALE
var _edifici: Dictionary = {}  # id -> Edificio3D
var _anteprima: MeshInstance3D
var _tipo := ""
var _cella := Vector2i.ZERO
var _selezionato := -1
var _strada_da := Vector2i(-1, -1)  # inizio della strada che si sta tracciando
var _strada_celle: Array[Vector2i] = []
var _strada_toccata := Vector2i(-1, -1)  # strada esistente selezionata

var _dita: Dictionary = {}  # indice -> posizione
var _inizio := Vector2.ZERO
var _mosso := false
var _distanza_pizzico := 0.0


func _ready() -> void:
	GameState.avvia()
	GameState.nel_feudo = true
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
	var f := TerrenoFeudo.FEUDO
	var margine := 8.0
	camera.limiti = Rect2(Vector2(f.position) * VistaTerreno.CELLA - Vector2.ONE * margine,
		Vector2(f.size) * VistaTerreno.CELLA + Vector2.ONE * margine * 2.0)
	add_child(camera)
	var centro := Vector2(TerrenoFeudo.centro_feudo()) * VistaTerreno.CELLA
	camera.position = Vector3(centro.x, 0, centro.y)
	camera.oltre_zoom_minimo.connect(_vai_al_regno)

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
	hud.rimuovi_strada.connect(_rimuovi_strada)
	hud.chiudi_pannello.connect(_seleziona.bind(-1))
	hud.ruota.connect(camera.ruota)
	hud.vai_al_regno.connect(_vai_al_regno)
	hud.nuova_partita.connect(_ricomincia)

	GameState.building_added.connect(_crea_edificio)
	GameState.building_removed.connect(_rimuovi_edificio)
	GameState.season_changed.connect(_cambia_stagione)
	GameState.changed.connect(_aggiorna_edifici)
	GameState.game_ended.connect(_partita_finita)
	GameState.terreno_cambiato.connect(_terreno_cambiato)
	GameState.building_added.connect(_su_edificio_aggiunto)
	vista.aggiorna_ciuffi()
	GameState.changed.emit()  # l'HUD è pronto: rinfresca i numeri
	if GameState.capo < 0:
		_inizia_prologo()
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
	_sposta_anteprima(_cella_sotto(get_viewport().get_visible_rect().size / 2.0))


func _sposta_anteprima(centro: Vector2i) -> void:
	var taglia := _taglia(_tipo)
	_cella = centro - taglia / 2
	var valida := GameState.terreno.posizione_valida(_tipo, _cella)
	var box := BoxMesh.new()
	box.size = Vector3(taglia.x * VistaTerreno.CELLA, 0.3, taglia.y * VistaTerreno.CELLA)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 0.3, 0.5) if valida else Color(0.95, 0.25, 0.2, 0.5)
	box.material = mat
	_anteprima.mesh = box
	var dentro := GameState.terreno.dentro(_cella)
	_anteprima.position = vista.centro_area(_cella if dentro else centro, taglia) + Vector3(0, 0.15, 0)
	_anteprima.visible = true
	# le celle che contano per la resa (bosco, rocce, acqua, fertilità) si colorano
	vista.mostra_zona(_tipo, _cella if dentro else centro)
	var stima := GameState.stima_produzione(_tipo, _cella) if dentro else ""
	hud.mostra_piazzamento(_tipo, valida, stima)


# --- Strade ---------------------------------------------------------------------

## Modalità strada: un tocco fissa l'inizio, i tocchi dopo la fine (percorso a L).
func _inizia_strada() -> void:
	_termina_piazzamento()
	_seleziona(-1)
	modo = Modo.STRADA
	_strada_da = Vector2i(-1, -1)
	_strada_celle = []
	hud.mostra_strada("Tocca dove inizia la strada, poi dove finisce. 1 pietra per cella in piano, 2 in salita; sul fiume un ponte, sul lago una passerella (max 3).", false)


func _tocco_strada(cella: Vector2i) -> void:
	if _strada_da.x < 0:
		_strada_da = cella
	_strada_celle = TerrenoFeudo.percorso(_strada_da, cella)
	var v := GameState.verifica_strada(_strada_celle)
	var colore := Color(0.9, 0.75, 0.45, 0.6) if v.ok else Color(0.95, 0.25, 0.2, 0.5)
	vista.mostra_celle(_strada_celle, colore)
	if not v.ok:
		hud.mostra_strada("Non si può: %s. Scegli un'altra fine." % v.motivo, false)
	else:
		var basta: bool = GameState.risorse.pietra >= v.pietra and GameState.risorse.legna >= v.legna
		var parti: Array[String] = ["%d celle" % _strada_celle.size()]
		if v.ponti > 0:
			parti.append("ponte di %d" % v.ponti)
		if v.passerelle > 0:
			parti.append("passerella di %d" % v.passerelle)
		var costo: Array[String] = []
		if v.pietra > 0:
			costo.append("%d pietra" % v.pietra)
		if v.legna > 0:
			costo.append("%d legna" % v.legna)
		parti.append(", ".join(costo) if not costo.is_empty() else "già fatta")
		hud.mostra_strada(" · ".join(parti) + ("" if basta else " (non basta)"), basta and not costo.is_empty())


func _costruisci_strada() -> void:
	if GameState.costruisci_strada(_strada_celle):
		_strada_da = Vector2i(-1, -1)
		_strada_celle = []
		vista.nascondi_zona()
		hud.mostra_strada("Strada fatta. Tocca per iniziarne un'altra, o Annulla.", false)


func _rimuovi_strada() -> void:
	GameState.rimuovi_strada(_strada_toccata)
	_strada_toccata = Vector2i(-1, -1)
	hud.nascondi_pannello()


func _conferma_piazzamento() -> void:
	if modo == Modo.STRADA:
		_costruisci_strada()
		return
	if modo != Modo.PIAZZA or not GameState.terreno.posizione_valida(_tipo, _cella):
		return
	var b := GameState.piazza(_tipo, _cella, 1.0)
	_termina_piazzamento()
	if not b.is_empty():
		_seleziona(b.id)


func _termina_piazzamento() -> void:
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
	elif modo == Modo.NORMALE:
		hud.nascondi_pannello()


func _cambia_lavoratori(id: int, delta: int) -> void:
	if delta > 0:
		GameState.aggiungi_lavoratore(id)
	else:
		GameState.togli_lavoratore(id)


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
		_tocco_strada(cella)
	else:
		var id := GameState.terreno.edificio_a(cella)
		_seleziona(id)
		if id < 0 and GameState.terreno.strada_a(cella):
			_strada_toccata = cella
			hud.mostra_strada_esistente()


func _cella_sotto(posizione: Vector2) -> Vector2i:
	var r := camera.raggio(posizione)
	return vista.cella_da_raggio(r[0], r[1])


func _taglia(tipo: String) -> Vector2i:
	var t: Array = GameState.edifici[tipo].taglia
	return Vector2i(int(t[0]), int(t[1]))


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


func _trascina(posizione: Vector2, relativo: Vector2) -> void:
	if not _mosso and posizione.distance_to(_inizio) > SOGLIA_TOCCO:
		_mosso = true
		relativo = posizione - _inizio  # recupera il tratto fatto prima della soglia
	if _mosso:
		camera.sposta(relativo)


func _distanza_dita() -> float:
	var punti := _dita.values()
	return (punti[0] as Vector2).distance_to(punti[1]) if punti.size() >= 2 else 0.0
