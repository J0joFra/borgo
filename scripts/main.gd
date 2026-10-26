extends Node2D
## Scena principale: collega mappa, telecamera e interfaccia e gestisce i gesti
## (trascinare, pizzicare, toccare) sia con il dito sia con il mouse.

enum Modo { NORMALE, PIAZZA }

const SOGLIA_TOCCO := 6.0  # pixel di viewport oltre i quali un tocco diventa trascinamento

@onready var mappa: Mappa = $Mappa
@onready var camera: CameraVillaggio = $Camera
@onready var hud: Hud = $Hud

var modo := Modo.NORMALE
var _tipo := ""
var _cella := Vector2i.ZERO
var _selezionato := -1

var _dita: Dictionary = {}  # indice -> posizione
var _inizio := Vector2.ZERO
var _mosso := false
var _distanza_pizzico := 0.0


func _ready() -> void:
	if GameState.carica():
		mappa.genera(GameState.seme_mappa)
		mappa.ricostruisci_edifici()
	else:
		_nuova_partita()
	camera.dimensione_mondo = mappa.dimensione_px()
	camera.position = mappa.centro_px()
	camera.sposta(Vector2.ZERO)

	hud.costruisci.connect(_inizia_piazzamento)
	hud.conferma_piazzamento.connect(_conferma_piazzamento)
	hud.annulla_piazzamento.connect(_termina_piazzamento)
	hud.cambia_lavoratori.connect(_cambia_lavoratori)
	hud.demolisci.connect(_demolisci)
	hud.chiudi_pannello.connect(_seleziona.bind(-1))
	hud.nuova_partita.connect(_ricomincia)
	GameState.building_removed.connect(func(id): if id == _selezionato: _seleziona(-1))
	GameState.game_ended.connect(func(_v, _m): _termina_piazzamento())
	GameState.changed.emit()  # l'HUD è pronto prima della partita: rinfresca i numeri


func _nuova_partita() -> void:
	GameState.nuova_partita()
	mappa.genera(GameState.seme_mappa)
	var centro := Vector2i(Mappa.LATO / 2, Mappa.LATO / 2)
	for i in int(GameState.bil.case_iniziali):
		var c := mappa.trova_posto("casa", centro + Vector2i(i * 3 - 3, 0))
		if c.x >= 0:
			GameState.aggiungi_gratis("casa", c, 1.0)
	GameState.salva()


func _ricomincia() -> void:
	GameState.cancella_salvataggio()
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	# Su mobile l'app può essere chiusa in qualsiasi momento: salviamo quando va in pausa.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.salva()


# --- Azioni ------------------------------------------------------------------

func _inizia_piazzamento(tipo: String) -> void:
	_seleziona(-1)
	modo = Modo.PIAZZA
	_tipo = tipo
	var taglia: Array = GameState.edifici[tipo].taglia
	var centro := mappa.cella_da_schermo(get_viewport_rect().size / 2.0)
	_sposta_anteprima(centro - Vector2i(int(taglia[0]) / 2, int(taglia[1]) / 2))


func _sposta_anteprima(cella: Vector2i) -> void:
	_cella = cella
	hud.mostra_piazzamento(_tipo, mappa.mostra_anteprima(_tipo, cella))


func _conferma_piazzamento() -> void:
	if modo != Modo.PIAZZA or not mappa.posizione_valida(_tipo, _cella):
		return
	var b := GameState.piazza(_tipo, _cella, mappa.bonus(_tipo, _cella))
	_termina_piazzamento()
	if not b.is_empty():
		_seleziona(b.id)


func _termina_piazzamento() -> void:
	modo = Modo.NORMALE
	_tipo = ""
	mappa.nascondi_anteprima()
	hud.nascondi_pannello()


func _seleziona(id: int) -> void:
	_selezionato = id
	mappa.seleziona(id)
	if id >= 0:
		hud.mostra_edificio(id)
	elif modo == Modo.NORMALE:
		hud.nascondi_pannello()


func _cambia_lavoratori(id: int, delta: int) -> void:
	if delta > 0:
		GameState.aggiungi_lavoratore(id)
	else:
		GameState.togli_lavoratore(id)


func _demolisci(id: int) -> void:
	GameState.demolisci(id)


func _tocco(posizione: Vector2) -> void:
	if GameState.finita:
		return
	var cella := mappa.cella_da_schermo(posizione)
	if modo == Modo.PIAZZA:
		var taglia: Array = GameState.edifici[_tipo].taglia
		_sposta_anteprima(cella - Vector2i(int(taglia[0]) / 2, int(taglia[1]) / 2))
	else:
		_seleziona(mappa.edificio_a(cella))


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
				var punti := _dita.values()
				camera.cambia_zoom(1 if d > _distanza_pizzico else -1, (punti[0] + punti[1]) / 2.0)
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
					camera.cambia_zoom(1, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					camera.cambia_zoom(-1, event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_trascina(event.position, event.relative)


func _trascina(posizione: Vector2, relativo: Vector2) -> void:
	if not _mosso and posizione.distance_to(_inizio) > SOGLIA_TOCCO:
		_mosso = true
		relativo = posizione - _inizio  # recupera il tratto fatto prima della soglia
	if _mosso:
		camera.sposta(relativo)


func _distanza_dita() -> float:
	var punti := _dita.values()
	return (punti[0] as Vector2).distance_to(punti[1]) if punti.size() >= 2 else 0.0
