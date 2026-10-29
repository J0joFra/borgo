extends Node3D
## Menu principale: un piccolo diorama del borgo che gira piano, con il titolo e i pulsanti
## Continua, Nuova partita, Opzioni, Crediti (ed Esci, tranne nel browser).

const VERDE := Color("6fae47")
const TERRA := Color("8a6a45")
const TERRA_SCURA := Color("6b4f33")
const ACQUA := Color("4a90c8")
const CHIOMA := [Color("4a9a3e"), Color("2f6b40"), Color("5aa035")]
const TRONCO := Color("6b4a2e")
const INCHIOSTRO := Color("3b2a1e")
const ORO := Color("f2d24b")

var _perno: Node3D
var _camera: Camera3D
var _parti_che_girano: Array[Node3D] = []
var _principale: VBoxContainer
var _conferma: PanelContainer
var _opzioni: PanelContainer
var _crediti: PanelContainer
var _btn_suggerimenti: CheckButton
var _btn_tutorial: CheckButton
var _btn_schermo: CheckButton


func _ready() -> void:
	GameState.nel_feudo = false
	Audio.musica("regno")
	_crea_ambiente()
	_crea_diorama()
	_crea_interfaccia()


func _process(delta: float) -> void:
	_perno.rotation.y += delta * 0.08
	for parte in _parti_che_girano:
		parte.rotate_object_local(parte.get_meta("gira"), -delta * 1.5)


# --- Diorama ------------------------------------------------------------------

func _crea_ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe3ef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-50, -35, 0)
	luce.light_energy = 0.8
	luce.light_color = Color("fff0d0")
	luce.shadow_enabled = true
	add_child(luce)
	_perno = Node3D.new()
	add_child(_perno)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 34.0
	_camera.position = Vector3(26, 24, 26)
	add_child(_camera)
	_camera.look_at(Vector3(-4, 0, 0), Vector3.UP)


## Un'isola esagonale con il castello, le case, il mulino, un laghetto e il bosco.
func _crea_diorama() -> void:
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cilindro(15.0, 13.5, 3.0, 6), LowPoly.t(Vector3(0, -1.6, 0)), TERRA_SCURA)
	k.forma(LowPoly.cilindro(15.2, 15.0, 0.4, 6), LowPoly.t(Vector3(0, -0.15, 0)), TERRA)
	k.forma(LowPoly.cilindro(15.0, 15.0, 0.12, 6), LowPoly.t(Vector3(0, 0.0, 0)), VERDE)
	k.forma(LowPoly.cilindro(3.2, 3.2, 0.1, 8), LowPoly.t(Vector3(-7, 0.03, 5)), ACQUA)
	# un sentiero di terra battuta dal castello alle case
	k.forma(LowPoly.cubo(Vector3(12, 0.06, 1.0)), LowPoly.t(Vector3(3, 0.08, -1.0), Vector3.ONE, 0.5), Color("b09468"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.0, 14.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.distance_to(Vector3(-7, 0, 5)) < 4.0:
			continue
		_albero(k, p, rng.randf_range(0.8, 1.3), CHIOMA[i % CHIOMA.size()], i % 3 == 1)
	var terra := MeshInstance3D.new()
	terra.mesh = k.mesh()
	_perno.add_child(terra)
	_modello("maniero", Vector3(-1, 0, -3), 8.0, 0.0)
	_modello("casa", Vector3(6, 0, 1), 4.0, 0.6)
	_modello("casa", Vector3(2, 0, 5), 4.0, -0.4)
	_modello("taverna", Vector3(7, 0, -5), 6.0, 0.3)
	_modello("mulino", Vector3(-6, 0, -9), 4.0, 0.0)
	_modello("torre_guardia", Vector3(10, 0, 6), 4.0, 0.0)
	_modello("campo", Vector3(-9, 0, -2), 6.0, 0.0)


func _albero(k: LowPoly.Costruttore, p: Vector3, s: float, chioma: Color, pino: bool) -> void:
	k.forma(LowPoly.cilindro(0.15 * s, 0.12 * s, 0.9 * s, 5), LowPoly.t(p + Vector3(0, 0.45 * s, 0)), TRONCO)
	if pino:
		k.forma(LowPoly.cilindro(0.9 * s, 0.0, 2.4 * s, 6), LowPoly.t(p + Vector3(0, 2.0 * s, 0)), chioma)
	else:
		k.forma(LowPoly.sfera(0.95 * s, 1.7 * s, 6, 4), LowPoly.t(p + Vector3(0, 1.7 * s, 0)), chioma)


func _modello(tipo: String, p: Vector3, lato: float, rot: float) -> void:
	var m := CatalogoModelli.istanzia(tipo, lato, lato)
	if m == null:
		return
	m.position = p
	m.rotation.y = rot
	_perno.add_child(m)
	for n in m.find_children("*", "Node3D", true, false):
		if n.has_meta("gira"):
			_parti_che_girano.append(n)


# --- Interfaccia ------------------------------------------------------------------

func _crea_interfaccia() -> void:
	var livello := CanvasLayer.new()
	add_child(livello)
	var radice := Control.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.theme = Hud.crea_tema()
	livello.add_child(radice)

	# una colonna a sinistra: titolo e pulsanti; con l'interfaccia grande (telefono) più compatta
	var grande: bool = GameState.opzioni.interfaccia_grande
	var colonna := VBoxContainer.new()
	colonna.position = Vector2(26, 12 if grande else 16)
	colonna.add_theme_constant_override("separation", 0)
	radice.add_child(colonna)
	var titolo := Label.new()
	titolo.text = "Borgo"
	titolo.add_theme_font_size_override("font_size", 26 if grande else 34)
	titolo.add_theme_color_override("font_color", ORO)
	titolo.add_theme_color_override("font_outline_color", INCHIOSTRO)
	titolo.add_theme_constant_override("outline_size", 6)
	colonna.add_child(titolo)
	var sotto := Label.new()
	sotto.text = "Dalle ceneri di %s, un feudo da far crescere" % GameState.dati_famiglie.get("regno_caduto", "Valmora")
	sotto.add_theme_color_override("font_color", Color("f3e3c3"))
	sotto.add_theme_color_override("font_outline_color", INCHIOSTRO)
	sotto.add_theme_constant_override("outline_size", 3)
	colonna.add_child(sotto)
	var spazio := Control.new()
	spazio.custom_minimum_size.y = 6 if grande else 12
	colonna.add_child(spazio)

	_principale = VBoxContainer.new()
	_principale.add_theme_constant_override("separation", 3 if grande else 5)
	colonna.add_child(_principale)
	var salvata := _partita_salvata()
	if not salvata.is_empty():
		var continua := _bottone("Continua")
		continua.pressed.connect(_continua)
		_principale.add_child(continua)
		var info := Label.new()
		info.text = salvata
		info.add_theme_font_size_override("font_size", 7)
		info.add_theme_color_override("font_color", Color("f3e3c3"))
		info.add_theme_color_override("font_outline_color", INCHIOSTRO)
		info.add_theme_constant_override("outline_size", 3)
		_principale.add_child(info)
	var nuova := _bottone("Nuova partita")
	nuova.pressed.connect(func():
		if salvata.is_empty():
			_nuova_partita()
		else:
			_mostra(_conferma))
	_principale.add_child(nuova)
	var opzioni := _bottone("Opzioni")
	opzioni.pressed.connect(func(): _mostra(_opzioni))
	_principale.add_child(opzioni)
	var prova := _bottone("Prova battaglia")
	prova.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/prova_battaglia.tscn"))
	_principale.add_child(prova)
	var crediti := _bottone("Crediti")
	crediti.pressed.connect(func(): _mostra(_crediti))
	_principale.add_child(crediti)
	if not OS.has_feature("web"):
		var esci := _bottone("Esci")
		esci.pressed.connect(func(): get_tree().quit())
		_principale.add_child(esci)

	_conferma = _finestra(radice, "Iniziare una nuova partita? Quella salvata andrà persa.")
	var riga := HBoxContainer.new()
	_conferma.get_child(0).add_child(riga)
	var si := _bottone("Sì, ricomincia", 90)
	si.pressed.connect(_nuova_partita)
	riga.add_child(si)
	var no := _bottone("No", 50)
	no.pressed.connect(func(): _mostra(null))
	riga.add_child(no)

	_opzioni = _finestra(radice, "Opzioni")
	var col: VBoxContainer = _opzioni.get_child(0)
	_btn_tutorial = _interruttore(col, "Tutorial nelle partite nuove", GameState.opzioni.tutorial, "tutorial")
	_btn_suggerimenti = _interruttore(col, "Suggerimenti ogni tanto", GameState.opzioni.suggerimenti, "suggerimenti")
	_interruttore(col, "Musica", GameState.opzioni.musica, "musica")
	_interruttore(col, "Effetti sonori", GameState.opzioni.effetti, "effetti")
	_interruttore(col, "Interfaccia grande (telefono)", GameState.opzioni.interfaccia_grande, "interfaccia_grande")
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_btn_schermo = _interruttore(col, "Schermo intero", GameState.opzioni.schermo_intero, "schermo_intero")
	var chiudi_o := _bottone("Chiudi", 60)
	chiudi_o.pressed.connect(func(): _mostra(null))
	col.add_child(chiudi_o)

	_crediti = _finestra(radice, "Borgo, un city builder medievale per telefono e browser.\n\nModelli 3D degli edifici: KayKit Medieval Hexagon Pack di Kay Lousberg (CC0).\nTerreno, alberi, abitanti e interfaccia: disegnati in codice.\nFatto con Godot 4.")
	var chiudi_c := _bottone("Chiudi", 60)
	chiudi_c.pressed.connect(func(): _mostra(null))
	_crediti.get_child(0).add_child(chiudi_c)


func _bottone(testo: String, larghezza := 120) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(larghezza, 21 if GameState.opzioni.interfaccia_grande else 24)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 10)
	return b


func _finestra(radice: Control, testo: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	radice.add_child(p)
	var col := VBoxContainer.new()
	p.add_child(col)
	var l := Label.new()
	l.text = testo
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 240
	col.add_child(l)
	return p


func _interruttore(col: VBoxContainer, testo: String, attivo: bool, chiave: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = testo
	c.button_pressed = attivo
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(v): GameState.imposta_opzione(chiave, v))
	col.add_child(c)
	return c


## Mostra una finestra (o nessuna) e nasconde i pulsanti principali mentre è aperta.
func _mostra(finestra: PanelContainer) -> void:
	for f in [_conferma, _opzioni, _crediti]:
		f.visible = f == finestra
	_principale.visible = finestra == null


## "Anno 2, estate · casata Ferrante · Villaggio", o "" se non c'è una partita salvata.
func _partita_salvata() -> String:
	if not FileAccess.file_exists(GameState.SAVE_PATH):
		return ""
	var dati = JSON.parse_string(FileAccess.get_file_as_string(GameState.SAVE_PATH))
	if not dati is Dictionary or int(dati.get("versione", 0)) < GameState.VERSIONE_MINIMA:
		return ""
	var parti: Array[String] = ["Anno %d, %s" % [int(dati.anno), GameState.STAGIONI[int(dati.stagione)].to_lower()]]
	var capo := int(dati.get("capo", -1))
	if capo >= 0 and capo < dati.famiglie.size():
		parti.append("casata %s" % dati.famiglie[capo].casata)
	parti.append(GameState.bil.livelli[int(dati.livello)].nome)
	parti.append("%d abitanti" % int(dati.abitanti))
	return " · ".join(parti)


func _continua() -> void:
	get_tree().change_scene_to_file("res://scenes/regno.tscn")


func _nuova_partita() -> void:
	GameState.ricomincia()
	get_tree().change_scene_to_file("res://scenes/regno.tscn")
