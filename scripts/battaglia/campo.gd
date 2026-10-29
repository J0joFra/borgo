extends Node3D
## Il campo di battaglia in 3D, in stile Humankind: esagoni di pianura, bosco, collina e acqua,
## le unità come gruppetti di figure con lo stendardo e il numero di uomini, la bandiera nemica
## da conquistare. Si tocca una nostra unità per sceglierla: le celle dove può andare si
## illuminano, i nemici attaccabili diventano rossi. "Fine turno" fa muovere il nemico.
## Le regole sono in LogicaBattaglia; qui grafica, animazioni e comandi.

const R := 2.2  # raggio di un esagono, in metri
const LARGO := R * 1.7320508  # distanza fra i centri sulla stessa riga
const PASSO_RIGA := R * 1.5
const QUOTE := [0.3, 0.42, 0.95, 0.05]  # altezza della cima per pianura, bosco, collina, acqua
const COLORI_TERRENO := [Color("6fae47"), Color("4f8a3a"), Color("a09a62"), Color("4a90c8")]
const TERRA := Color("8a6a45")
const COLORI_LATO := {"noi": Color("b03a2e"), "loro": Color("3f6f9f")}
const COLORI_NEMICI := {"signore": Color("3f6f9f"), "banditi": Color("3a3636"), "libera": Color("8a6a3a")}
const TUNICHE := {"fanti": Color("a8322a"), "arcieri": Color("3f6b3a"), "vassalli": Color("d0802c"),
	"cavalieri": Color("3f6f9f"), "balestrieri": Color("2f5a85"), "predoni": Color("2e2a2a"), "contadini": Color("8a6a3a")}
## Le nostre unità sono sempre nei toni del rosso, quelle nemiche nei colori del loro esercito.
const TUNICHE_NOSTRE := {"fanti": Color("a8322a"), "spadaccini": Color("962a2a"), "arcieri": Color("8a3a2a"), "balestrieri": Color("7a2a22"),
	"cavalieri": Color("c0402e"), "vassalli": Color("d0802c")}
const FIGURE_MASSIME := 5

var camera: CameraIso
var _cfg: Dictionary
var _nodi: Dictionary = {}  # id unità -> Node3D
var _scelta := -1
var _possibili: Dictionary = {}  # cella -> percorso
var _bersagli: Array = []
var _evidenza: MeshInstance3D
var _occupato := false  # durante le animazioni non si tocca nulla
var _mesh_figure: Dictionary = {}

# interfaccia
var _titolo: Label
var _turno: Label
var _scheda: Label
var _diario: Label
var _btn_fine: Button
var _btn_ritirata: Button
var _esito: PanelContainer
var _esito_testo: Label

# gesti (come nel feudo)
var _dita: Dictionary = {}
var _inizio := Vector2.ZERO
var _mosso := false
var _distanza_pizzico := 0.0


func _ready() -> void:
	GameState.nel_feudo = false
	Audio.musica("battaglia")
	_cfg = GameState.bil.battaglia
	if GameState.battaglia.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		return
	_crea_ambiente()
	_crea_campo()
	_crea_bandiera()
	for u in GameState.battaglia.unita:
		if int(u.uomini) > 0:
			_crea_unita(u)
	_evidenza = MeshInstance3D.new()
	_evidenza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_evidenza)
	camera = CameraIso.new()
	camera.limiti = Rect2(-4, -4, LARGO * LogicaBattaglia.LARGHEZZA + 8, PASSO_RIGA * LogicaBattaglia.ALTEZZA + 8)
	add_child(camera)
	camera.position = Vector3(LARGO * LogicaBattaglia.LARGHEZZA / 2.0, 0, PASSO_RIGA * LogicaBattaglia.ALTEZZA / 2.0)
	_crea_interfaccia()
	_aggiorna()


# --- Campo --------------------------------------------------------------------------

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
	luce.rotation_degrees = Vector3(-55, -30, 0)
	luce.light_energy = 0.8
	luce.light_color = Color("fff0d0")
	luce.shadow_enabled = true
	luce.directional_shadow_max_distance = 120.0
	add_child(luce)


## Il centro di un esagono, alla quota della sua cima.
func posizione(c: Vector2i) -> Vector3:
	var t := LogicaBattaglia.terreno_a(GameState.battaglia, c)
	return Vector3(LARGO * (c.x + 0.5 * (c.y & 1)) + LARGO / 2.0, QUOTE[t], PASSO_RIGA * c.y + R)


## L'esagono sotto un punto del terreno (x, z), o (-1, -1).
func cella_da_punto(p: Vector3) -> Vector2i:
	var x := p.x - LARGO / 2.0
	var z := p.z - R
	var q := (sqrt(3.0) / 3.0 * x - z / 3.0) / R
	var r := (2.0 / 3.0 * z) / R
	# arrotondamento nelle coordinate cubiche
	var cx := q
	var cz := r
	var cy := -cx - cz
	var rx := roundf(cx)
	var ry := roundf(cy)
	var rz := roundf(cz)
	var dx := absf(rx - cx)
	var dy := absf(ry - cy)
	var dz := absf(rz - cz)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy <= dz:
		rz = -rx - ry
	var riga := int(rz)
	var col := int(rx) + (riga - (riga & 1)) / 2
	var c := Vector2i(col, riga)
	return c if LogicaBattaglia.dentro(c) else Vector2i(-1, -1)


func _crea_campo() -> void:
	var k := LowPoly.Costruttore.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for r in LogicaBattaglia.ALTEZZA:
		for c in LogicaBattaglia.LARGHEZZA:
			var cella := Vector2i(c, r)
			var t := LogicaBattaglia.terreno_a(GameState.battaglia, cella)
			var p := posizione(cella)
			var alto: float = QUOTE[t]
			var base := Vector3(p.x, 0, p.z)
			# il corpo di terra, poi la cima colorata
			k.forma(LowPoly.cilindro(R * 0.97, R * 0.97, alto + 1.0, 6), LowPoly.t(base + Vector3(0, (alto - 1.0) / 2.0 - 0.06, 0), Vector3.ONE, PI / 6.0), TERRA)
			var colore: Color = COLORI_TERRENO[t].darkened(rng.randf_range(0.0, 0.08))
			k.forma(LowPoly.cilindro(R * 0.95, R * 0.97, 0.12, 6), LowPoly.t(base + Vector3(0, alto - 0.06, 0), Vector3.ONE, PI / 6.0), colore)
			match t:
				LogicaBattaglia.Terreno.BOSCO:
					for i in 3:
						var a := TAU * i / 3.0 + rng.randf()
						_albero(k, p + Vector3(cos(a), 0, sin(a)) * R * 0.5, rng.randf_range(0.8, 1.1))
				LogicaBattaglia.Terreno.COLLINA:
					k.forma(LowPoly.sfera(0.5, 0.5, 5, 3), LowPoly.t(p + Vector3(R * 0.45, 0.1, -R * 0.3)), Color("9a978d"))
	var campo := MeshInstance3D.new()
	campo.mesh = k.mesh()
	add_child(campo)


func _albero(k: LowPoly.Costruttore, p: Vector3, s: float) -> void:
	k.forma(LowPoly.cilindro(0.12 * s, 0.1 * s, 0.7 * s, 5), LowPoly.t(p + Vector3(0, 0.35 * s, 0)), Color("6b4a2e"))
	k.forma(LowPoly.cilindro(0.7 * s, 0.0, 1.9 * s, 6), LowPoly.t(p + Vector3(0, 1.5 * s, 0)), Color("2f6b40"))


func _crea_bandiera() -> void:
	var b := GameState.battaglia
	var c := Vector2i(int(b.bandiera[0]), int(b.bandiera[1]))
	var p := posizione(c)
	var k := LowPoly.Costruttore.new()
	var colore: Color = COLORI_NEMICI.get(b.tipo_nemico, Color("3f6f9f"))
	k.forma(LowPoly.cilindro(0.08, 0.08, 4.0, 5), LowPoly.t(p + Vector3(-R * 0.55, 2.0, -R * 0.35)), Color("5a3a22"))
	k.forma(LowPoly.cubo(Vector3(1.4, 0.9, 0.06)), LowPoly.t(p + Vector3(-R * 0.55 + 0.7, 3.5, -R * 0.35)), colore)
	k.forma(LowPoly.cilindro(R * 0.9, R * 0.9, 0.05, 6), LowPoly.t(p + Vector3(0, 0.02, 0), Vector3.ONE, PI / 6.0), colore.lightened(0.3))
	var m := MeshInstance3D.new()
	m.mesh = k.mesh()
	add_child(m)


# --- Unità --------------------------------------------------------------------------

func _mesh_di(tipo: String, lato := "loro") -> ArrayMesh:
	var chiave := tipo + "|" + lato
	if _mesh_figure.has(chiave):
		return _mesh_figure[chiave]
	var tunica: Color = TUNICHE_NOSTRE.get(tipo, Color("a8322a")) if lato == "noi" else TUNICHE.get(tipo, Color("7a4a3a"))
	var k := LowPoly.Costruttore.new()
	if tipo == "cavalieri":
		# un cavallo sotto il cavaliere
		k.forma(LowPoly.cubo(Vector3(0.35, 0.45, 1.0)), LowPoly.t(Vector3(0, 0.55, 0)), Color("6b4a2e"))
		k.forma(LowPoly.cubo(Vector3(0.25, 0.35, 0.35)), LowPoly.t(Vector3(0, 0.85, 0.55)), Color("5a3a22"))
		for x in [-0.12, 0.12]:
			for z in [-0.35, 0.35]:
				k.forma(LowPoly.cubo(Vector3(0.1, 0.4, 0.1)), LowPoly.t(Vector3(x, 0.2, z)), Color("4a3020"))
		k.forma(LowPoly.cilindro(0.2, 0.17, 0.5, 6), LowPoly.t(Vector3(0, 1.05, 0)), tunica)
		k.forma(LowPoly.sfera(0.15, 0.3, 6, 3), LowPoly.t(Vector3(0, 1.45, 0)), Color("8a9098"))
		k.forma(LowPoly.cilindro(0.03, 0.03, 1.8, 4), LowPoly.t(Vector3(0.25, 1.3, 0.3), Vector3.ONE, 0.0), Color("6b4a2e"))
	else:
		k.forma(LowPoly.cubo(Vector3(0.28, 0.3, 0.18)), LowPoly.t(Vector3(0, 0.15, 0)), Color("3a2e26"))
		k.forma(LowPoly.cilindro(0.23, 0.18, 0.6, 6), LowPoly.t(Vector3(0, 0.6, 0)), tunica)
		k.forma(LowPoly.sfera(0.16, 0.32, 6, 3), LowPoly.t(Vector3(0, 1.06, 0)), Color("e0b08a"))
		if tipo == "spadaccini":
			# elmo, spada corta e scudo tondo
			k.forma(LowPoly.sfera(0.19, 0.2, 6, 3), LowPoly.t(Vector3(0, 1.17, 0)), Color("8a9098"))
			k.forma(LowPoly.cubo(Vector3(0.05, 0.55, 0.08)), LowPoly.t(Vector3(0.28, 0.75, 0.12)), Color("c8ccd0"))
			k.forma(LowPoly.cilindro(0.22, 0.22, 0.06, 8), Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-0.26, 0.65, 0.05)), tunica.darkened(0.3))
		elif tipo in ["fanti", "cavalieri", "vassalli"]:
			k.forma(LowPoly.sfera(0.19, 0.2, 6, 3), LowPoly.t(Vector3(0, 1.17, 0)), Color("8a9098"))
			k.forma(LowPoly.cilindro(0.03, 0.03, 1.6, 4), LowPoly.t(Vector3(0.28, 0.85, 0.05)), Color("6b4a2e"))
			k.forma(LowPoly.cubo(Vector3(0.08, 0.45, 0.35)), LowPoly.t(Vector3(-0.25, 0.65, 0.05)), tunica.darkened(0.3))
		elif tipo in ["arcieri", "balestrieri"]:
			k.forma(LowPoly.cilindro(0.18, 0.05, 0.22, 6), LowPoly.t(Vector3(0, 1.22, 0)), tunica.darkened(0.3))
			k.forma(LowPoly.cubo(Vector3(0.05, 0.9, 0.05)), LowPoly.t(Vector3(0.27, 0.7, 0.12)), Color("6b4a2e"))
		elif tipo == "predoni":
			k.forma(LowPoly.cilindro(0.2, 0.04, 0.32, 6), LowPoly.t(Vector3(0, 1.28, -0.02)), tunica)
			k.forma(LowPoly.cubo(Vector3(0.05, 0.7, 0.05)), LowPoly.t(Vector3(0.27, 0.6, 0.1)), Color("5a3a1a"))
		else:
			# contadini con il forcone
			k.forma(LowPoly.cilindro(0.03, 0.03, 1.5, 4), LowPoly.t(Vector3(0.27, 0.8, 0.05)), Color("8a6a3a"))
			k.forma(LowPoly.cubo(Vector3(0.22, 0.05, 0.05)), LowPoly.t(Vector3(0.27, 1.55, 0.05)), Color("8a8a8a"))
	_mesh_figure[chiave] = k.mesh()
	return _mesh_figure[chiave]


## Un'unità: figure in gruppetto (una ogni uomo, fino a FIGURE_MASSIME), stendardo del colore
## della sua parte e il numero di uomini sopra.
func _crea_unita(u: Dictionary) -> void:
	var nodo := Node3D.new()
	nodo.scale = Vector3.ONE * 1.35
	add_child(nodo)
	_nodi[int(u.id)] = nodo
	nodo.position = posizione(LogicaBattaglia.cella(u))
	nodo.rotation.y = PI / 2.0 if u.lato == "noi" else -PI / 2.0
	var colore: Color = COLORI_LATO.noi if u.lato == "noi" else COLORI_NEMICI.get(GameState.battaglia.tipo_nemico, COLORI_LATO.loro)
	var asta := MeshInstance3D.new()
	var k := LowPoly.Costruttore.new()
	k.forma(LowPoly.cilindro(0.05, 0.05, 2.6, 4), LowPoly.t(Vector3(-0.9, 1.3, -0.6)), Color("5a3a22"))
	k.forma(LowPoly.cubo(Vector3(0.06, 0.6, 0.8)), LowPoly.t(Vector3(-0.9, 2.3, -0.2)), colore)
	asta.mesh = k.mesh()
	nodo.add_child(asta)
	var figure := Node3D.new()
	figure.name = "Figure"
	nodo.add_child(figure)
	var etichetta := Label3D.new()
	etichetta.name = "Numero"
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.position = Vector3(0, 2.9, 0)
	etichetta.font_size = 110
	etichetta.pixel_size = 0.01
	etichetta.outline_size = 12
	etichetta.no_depth_test = true
	nodo.add_child(etichetta)
	_aggiorna_unita(u)


func _aggiorna_unita(u: Dictionary) -> void:
	var nodo: Node3D = _nodi.get(int(u.id))
	if nodo == null:
		return
	var figure: Node3D = nodo.get_node("Figure")
	var quante := mini(FIGURE_MASSIME, int(u.uomini))
	while figure.get_child_count() > quante:
		var f := figure.get_child(figure.get_child_count() - 1)
		figure.remove_child(f)
		f.queue_free()
	var posti := [Vector3(0, 0, 0), Vector3(0.6, 0, 0.45), Vector3(-0.6, 0, 0.45), Vector3(0.6, 0, -0.45), Vector3(-0.6, 0, -0.45)]
	while figure.get_child_count() < quante:
		var m := MeshInstance3D.new()
		m.mesh = _mesh_di(u.tipo, u.lato)
		m.position = posti[figure.get_child_count()]
		figure.add_child(m)
	var etichetta: Label3D = nodo.get_node("Numero")
	etichetta.text = str(int(u.uomini))
	etichetta.modulate = Color("ffd0c8") if u.lato == "noi" else Color("d0e0ff")
	if int(u.uomini) <= 0:
		var tw := create_tween()
		tw.tween_property(nodo, "scale", Vector3(1.35, 0.05, 1.35), 0.4)
		tw.tween_callback(nodo.queue_free)
		_nodi.erase(int(u.id))


## Un numero che sale e svanisce sopra un'unità (es. "-2").
func _numero_volante(dove: Vector3, testo: String, colore: Color) -> void:
	var l := Label3D.new()
	l.text = testo
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 72
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = colore
	l.no_depth_test = true
	add_child(l)
	l.position = dove + Vector3(0, 3.2, 0)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 1.6, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# --- Comandi ---------------------------------------------------------------------------

func _tocco(schermo: Vector2) -> void:
	var b := GameState.battaglia
	if _occupato or b.is_empty() or b.finita or b.fase != "noi":
		return
	var raggio := camera.raggio(schermo)
	var o: Vector3 = raggio[0]
	var d: Vector3 = raggio[1]
	if absf(d.y) < 1e-4:
		return
	var cella := cella_da_punto(o + d * ((0.4 - o.y) / d.y))
	if cella.x < 0:
		_scegli(-1)
		return
	var chi := LogicaBattaglia.occupante(b, cella)
	var u := LogicaBattaglia.trova(b, chi)
	if not u.is_empty() and u.lato == "noi":
		_scegli(chi)
	elif not u.is_empty() and _scelta >= 0 and _bersagli.any(func(x): return int(x.id) == chi):
		_attacca(_scelta, chi)
	elif _possibili.has(cella):
		_muovi(_scelta, cella)
	else:
		_scegli(-1)


func _scegli(id: int) -> void:
	_scelta = id
	_possibili = {}
	_bersagli = []
	var u := LogicaBattaglia.trova(GameState.battaglia, id)
	if not u.is_empty():
		if not bool(u.attaccato):
			_possibili = LogicaBattaglia.raggiungibili(GameState.battaglia, u, _cfg)
		_bersagli = LogicaBattaglia.bersagli(GameState.battaglia, u, _cfg)
	_disegna_evidenza()
	_aggiorna()


func _muovi(id: int, dove: Vector2i) -> void:
	var percorso := GameState.battaglia_muovi(id, dove)
	if percorso.is_empty():
		return
	_occupato = true
	await _anima_cammino(id, percorso)
	_occupato = false
	_scegli(id)


func _anima_cammino(id: int, percorso: Array) -> void:
	var nodo: Node3D = _nodi.get(id)
	if nodo == null:
		return
	var tw := create_tween()
	var prima := nodo.position
	for c in percorso:
		var p := posizione(Vector2i(int(c[0]), int(c[1])) if c is Array else c)
		var verso := p - prima
		prima = p
		tw.tween_callback(_gira.bind(nodo, atan2(verso.x, verso.z)))
		tw.tween_property(nodo, "position", p, 0.22)
	await tw.finished


func _gira(nodo: Node3D, angolo: float) -> void:
	nodo.rotation.y = angolo


func _attacca(id: int, bersaglio: int) -> void:
	var e := GameState.battaglia_attacca(id, bersaglio)
	if e.is_empty():
		return
	_occupato = true
	await _anima_attacco(e)
	_occupato = false
	_scegli(id if not LogicaBattaglia.trova(GameState.battaglia, id).is_empty() and int(LogicaBattaglia.trova(GameState.battaglia, id).uomini) > 0 else -1)
	_controlla_fine()


## L'attaccante scatta verso il bersaglio (o tira da lontano), poi cadono gli uomini.
func _anima_attacco(e: Dictionary) -> void:
	var a: Node3D = _nodi.get(int(e.da))
	var d: Node3D = _nodi.get(int(e.a))
	if a and d:
		var verso := d.position - a.position
		a.rotation.y = atan2(verso.x, verso.z)
		var partenza := a.position
		var tw := create_tween()
		if e.da_lontano:
			Audio.effetto("freccia")
			tw.tween_property(a, "position", partenza + verso.normalized() * 0.3, 0.12)
			tw.tween_property(a, "position", partenza, 0.2)
		else:
			tw.tween_property(a, "position", partenza + verso * 0.4, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): Audio.effetto("scontro"))
			tw.tween_property(a, "position", partenza, 0.25)
		await tw.finished
		if int(e.morti_difensore) > 0:
			_numero_volante(d.position, "-%d" % int(e.morti_difensore), Color("ffdf6b"))
		if int(e.morti_attaccante) > 0:
			_numero_volante(a.position, "-%d" % int(e.morti_attaccante), Color("ff8f80"))
	for id in [int(e.da), int(e.a)]:
		_aggiorna_unita(LogicaBattaglia.trova(GameState.battaglia, id))
	await get_tree().create_timer(0.35).timeout


func _fine_turno() -> void:
	if _occupato or GameState.battaglia.fase != "noi":
		return
	_scegli(-1)
	_occupato = true
	_aggiorna()
	var azioni := GameState.battaglia_fine_turno()
	_turno.text = "Turno del nemico…"
	for a in azioni:
		if a.tipo == "muovi":
			await _anima_cammino(int(a.id), a.percorso)
		else:
			await _anima_attacco(a)
	_occupato = false
	_aggiorna()
	_controlla_fine()


func _controlla_fine() -> void:
	var b := GameState.battaglia
	if b.is_empty() or not b.finita:
		return
	_esito_testo.text = "%s\n\n%s" % ["Vittoria!" if b.vinta else "Sconfitta", b.perche]
	_esito.visible = true
	_btn_fine.visible = false
	_btn_ritirata.visible = false


# --- Interfaccia --------------------------------------------------------------------

func _crea_interfaccia() -> void:
	var livello := CanvasLayer.new()
	add_child(livello)
	var radice := Control.new()
	radice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.theme = Hud.crea_tema()
	livello.add_child(radice)
	var b := GameState.battaglia
	var prova: bool = b.get("prova", false)
	var regione: Dictionary = {"nome": b.get("titolo", "prova"), "signore": "senza partita"} if prova else GameState.regni[b.regione]

	var testa := PanelContainer.new()
	testa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	testa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	testa.offset_top = 4
	radice.add_child(testa)
	var col := VBoxContainer.new()
	testa.add_child(col)
	_titolo = Label.new()
	_titolo.text = b.titolo if prova else "Battaglia di %s  ·  %s" % [regione.nome, regione.signore]
	_titolo.add_theme_font_size_override("font_size", 11)
	_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_titolo)
	var obiettivo := Label.new()
	obiettivo.text = "Prendi la loro bandiera e tienila per un turno, o distruggi il loro esercito"
	obiettivo.add_theme_font_size_override("font_size", 7)
	obiettivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(obiettivo)
	_turno = Label.new()
	_turno.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_turno)

	var scheda := PanelContainer.new()
	scheda.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	scheda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	scheda.offset_left = 4
	scheda.offset_bottom = -4
	radice.add_child(scheda)
	_scheda = Label.new()
	_scheda.custom_minimum_size = Vector2(150, 0)
	_scheda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scheda.add_theme_font_size_override("font_size", 7)
	scheda.add_child(_scheda)

	_diario = Label.new()
	_diario.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_diario.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_diario.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_diario.offset_bottom = -6
	_diario.custom_minimum_size.x = 160
	_diario.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diario.add_theme_font_size_override("font_size", 7)
	_diario.add_theme_color_override("font_outline_color", Color.BLACK)
	_diario.add_theme_constant_override("outline_size", 3)
	_diario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radice.add_child(_diario)

	var comandi := VBoxContainer.new()
	comandi.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	comandi.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	comandi.grow_vertical = Control.GROW_DIRECTION_BEGIN
	comandi.offset_right = -4
	comandi.offset_bottom = -4
	radice.add_child(comandi)
	_btn_fine = Button.new()
	_btn_fine.text = "Fine turno"
	_btn_fine.custom_minimum_size = Vector2(80, 26)
	_btn_fine.focus_mode = Control.FOCUS_NONE
	_btn_fine.pressed.connect(_fine_turno)
	comandi.add_child(_btn_fine)
	_btn_ritirata = Button.new()
	_btn_ritirata.text = "Ritirata"
	_btn_ritirata.custom_minimum_size = Vector2(80, 18)
	_btn_ritirata.focus_mode = Control.FOCUS_NONE
	_btn_ritirata.pressed.connect(func():
		if _occupato:
			return
		GameState.battaglia_ritirata()
		_aggiorna()
		_controlla_fine())
	comandi.add_child(_btn_ritirata)

	_esito = PanelContainer.new()
	_esito.set_anchors_preset(Control.PRESET_CENTER)
	_esito.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_esito.grow_vertical = Control.GROW_DIRECTION_BOTH
	_esito.visible = false
	radice.add_child(_esito)
	var ce := VBoxContainer.new()
	_esito.add_child(ce)
	_esito_testo = Label.new()
	_esito_testo.custom_minimum_size.x = 220
	_esito_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_esito_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ce.add_child(_esito_testo)
	var torna := Button.new()
	torna.text = "Torna alla prova" if prova else "Torna al feudo"
	torna.custom_minimum_size = Vector2(0, 22)
	torna.focus_mode = Control.FOCUS_NONE
	torna.pressed.connect(func():
		GameState.chiudi_battaglia()
		get_tree().change_scene_to_file("res://scenes/prova_battaglia.tscn" if prova else "res://scenes/feudo.tscn"))
	ce.add_child(torna)
	_controlla_fine()


func _aggiorna() -> void:
	var b := GameState.battaglia
	if b.is_empty() or _turno == null:
		return
	var noi := LogicaBattaglia.vive(b, "noi")
	var loro := LogicaBattaglia.vive(b, "loro")
	var uomini_noi: int = noi.reduce(func(s, u): return s + int(u.uomini), 0)
	var uomini_loro: int = loro.reduce(func(s, u): return s + int(u.uomini), 0)
	_turno.text = "Turno %d di %d  ·  %s  ·  noi %d uomini, loro %d" % [int(b.turno), int(b.turni),
		"il tuo turno" if b.fase == "noi" else ("turno del nemico" if b.fase == "loro" else "finita"), uomini_noi, uomini_loro]
	_diario.text = "\n".join(b.diario.slice(maxi(0, b.diario.size() - 3)))
	var u := LogicaBattaglia.trova(b, _scelta)
	if u.is_empty():
		_scheda.text = "Tocca una tua unità (stendardo rosso) per muoverla: le celle chiare sono dove può andare, i nemici in rosso quelli che può attaccare. Boschi e colline costano 2 mosse ma difendono meglio; dalle colline si colpisce più forte e gli arcieri tirano più lontano."
	else:
		var d: Dictionary = _cfg.unita[u.tipo]
		var t: Dictionary = _cfg.terreni[LogicaBattaglia.terreno_a(b, LogicaBattaglia.cella(u))]
		_scheda.text = "%s%s\nUomini %d/%d · forza %.1f a testa\nMosse %d · gittata %d\nSu %s (attacco ×%.1f, difesa ×%.2f)\n%s" % [
			d.nome, "", int(u.uomini), int(u.max), LogicaBattaglia.forza(u, _cfg),
			int(u.mosse), LogicaBattaglia.gittata(b, u, _cfg), t.nome.to_lower(), float(t.attacco), float(t.difesa),
			"Ha già attaccato in questo turno." if bool(u.attaccato) else ("Nemici a tiro: %d" % _bersagli.size() if not _bersagli.is_empty() else "")]
	_btn_fine.disabled = _occupato or b.fase != "noi"
	for x in b.unita:
		_aggiorna_unita(x)


## Illumina le celle raggiungibili (chiare), l'unità scelta (oro) e i nemici attaccabili (rosso).
func _disegna_evidenza() -> void:
	var k := LowPoly.Costruttore.new()
	var vuoto := true
	var u := LogicaBattaglia.trova(GameState.battaglia, _scelta)
	if not u.is_empty():
		_esagono(k, LogicaBattaglia.cella(u), Color(1.0, 0.85, 0.3, 0.7))
		vuoto = false
	for c in _possibili:
		_esagono(k, c, Color(1, 1, 1, 0.35))
		vuoto = false
	for x in _bersagli:
		_esagono(k, LogicaBattaglia.cella(x), Color(1.0, 0.25, 0.2, 0.6))
		vuoto = false
	if vuoto:
		_evidenza.mesh = null
		return
	var mesh := k.mesh()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mesh.surface_set_material(0, mat)
	_evidenza.mesh = mesh


func _esagono(k: LowPoly.Costruttore, c: Vector2i, colore: Color) -> void:
	var p := posizione(c)
	k.forma(LowPoly.cilindro(R * 0.8, R * 0.8, 0.04, 6), LowPoly.t(p + Vector3(0, 0.05, 0), Vector3.ONE, PI / 6.0), colore)


# --- Gesti --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_dita[event.index] = event.position
			if _dita.size() == 1:
				_inizio = event.position
				_mosso = false
			else:
				_mosso = true
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
			KEY_SPACE, KEY_ENTER:
				_fine_turno()


func _trascina(posizione_dito: Vector2, relativo: Vector2) -> void:
	if not _mosso and posizione_dito.distance_to(_inizio) > 6.0:
		_mosso = true
		relativo = posizione_dito - _inizio
	if _mosso:
		camera.sposta(relativo)


func _distanza_dita() -> float:
	var punti := _dita.values()
	return (punti[0] as Vector2).distance_to(punti[1]) if punti.size() >= 2 else 0.0
