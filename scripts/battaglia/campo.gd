extends Node3D
## Il campo di battaglia in 3D, in stile Humankind: un piccolo diorama a quadretti come il terreno del
## feudo (pianura, bosco, collina, acqua, e le mura del castello negli assedi),
## le unità come gruppetti di figure con lo stendardo e il numero di uomini, la bandiera nemica
## da conquistare. Prima lo schieramento: si tocca una nostra unità e poi una cella della zona
## azzurra per spostarla, e "Inizia la battaglia". Poi si tocca una nostra unità per sceglierla:
## le celle dove può andare si illuminano, i nemici attaccabili diventano rossi; il primo tocco su
## un nemico mostra le perdite previste (con altura, fianchi, supporto), il secondo attacca.
## "Fine turno" fa muovere il nemico; non c'è limite di turni.
## Le regole sono in LogicaBattaglia; qui grafica, animazioni e comandi.

const CELLA := 3.2  # lato di una cella, in metri
const R := CELLA / 2.0
## altezza della cima per pianura, bosco, collina, acqua, mura (il camminamento)
const QUOTE := [0.3, 0.3, 0.9, 0.0, 2.1]
const SUOLO_MURA := 0.3  # sotto le mura il terreno è pianura
const ALTEZZA_MURA := 1.8
const TERRA := Color("8a6a45")
const COLORI_LATO := {"noi": Color("b03a2e"), "loro": Color("3f6f9f")}
const COLORI_NEMICI := {"signore": Color("3f6f9f"), "banditi": Color("3a3636"), "libera": Color("8a6a3a")}
const TUNICHE := {"fanti": Color("a8322a"), "arcieri": Color("3f6b3a"), "vassalli": Color("d0802c"),
	"cavalieri": Color("3f6f9f"), "balestrieri": Color("2f5a85"), "predoni": Color("2e2a2a"), "contadini": Color("8a6a3a")}
## Le nostre unità sono sempre nei toni del rosso, quelle nemiche nei colori del loro esercito.
const TUNICHE_NOSTRE := {"fanti": Color("a8322a"), "spadaccini": Color("962a2a"), "arcieri": Color("8a3a2a"), "balestrieri": Color("7a2a22"),
	"cavalieri": Color("c0402e"), "vassalli": Color("d0802c")}
const FIGURE_MASSIME := 5
const COLORI_LUCE := [Color("fff6e8"), Color("fff0d0"), Color("ffd6a8"), Color("dfe8ff")]  # come nel feudo, per stagione

var camera: CameraIso
var _cfg: Dictionary
var _nodi: Dictionary = {}  # id unità -> Node3D
var _scelta := -1
var _possibili: Dictionary = {}  # cella -> percorso
var _bersagli: Array = []
var _mirato := -1  # il nemico toccato una volta: si vede l'anteprima, al secondo tocco si attacca
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
	camera.limiti = Rect2(-4, -4, CELLA * LogicaBattaglia.LARGHEZZA + 8, CELLA * LogicaBattaglia.ALTEZZA + 8)
	add_child(camera)
	camera.position = Vector3(CELLA * LogicaBattaglia.LARGHEZZA / 2.0, 0, CELLA * LogicaBattaglia.ALTEZZA / 2.0)
	_crea_interfaccia()
	_aggiorna()
	_disegna_evidenza()


# --- Campo --------------------------------------------------------------------------

func _crea_ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfe3ef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var luce := DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-55, -30, 0)
	luce.light_energy = 0.75
	luce.light_color = COLORI_LUCE[GameState.stagione]
	luce.shadow_enabled = true
	luce.directional_shadow_max_distance = 120.0
	add_child(luce)


## Il centro di una cella, alla quota della sua cima (sulle mura, il camminamento).
func posizione(c: Vector2i) -> Vector3:
	var t := LogicaBattaglia.terreno_a(GameState.battaglia, c)
	return Vector3((c.x + 0.5) * CELLA, QUOTE[t], (c.y + 0.5) * CELLA)


## La quota del terreno di una cella (senza le mura).
func _suolo(c: Vector2i) -> float:
	var t := LogicaBattaglia.terreno_a(GameState.battaglia, c)
	return SUOLO_MURA if t == LogicaBattaglia.Terreno.MURA else float(QUOTE[t])


## La cella sotto un punto del terreno (x, z), o (-1, -1).
func cella_da_punto(p: Vector3) -> Vector2i:
	var c := Vector2i(floori(p.x / CELLA), floori(p.z / CELLA))
	return c if LogicaBattaglia.dentro(c) else Vector2i(-1, -1)


## La cella toccata: si prova dalla quota più alta (le mura) alla più bassa, così si prende la cima
## che si vede davvero e non la cella dietro.
func cella_da_raggio(o: Vector3, d: Vector3) -> Vector2i:
	if absf(d.y) < 1e-4:
		return Vector2i(-1, -1)
	for quota in [QUOTE[LogicaBattaglia.Terreno.MURA], QUOTE[LogicaBattaglia.Terreno.COLLINA], 0.3, 0.0]:
		var c := cella_da_punto(o + d * ((float(quota) - o.y) / d.y))
		if c.x >= 0 and absf(float(QUOTE[LogicaBattaglia.terreno_a(GameState.battaglia, c)]) - float(quota)) < 0.05:
			return c
	return cella_da_punto(o + d * ((0.3 - o.y) / d.y))


## Il clima del campo: quello della regione dove si combatte (nella prova, il nostro).
func _clima_campo() -> Dictionary:
	var b := GameState.battaglia
	var nome := GameState.clima
	if not b.get("prova", false) and str(b.get("regione", "")).is_valid_int():
		var g := Regioni.genera(GameState.seme_mappa)
		var i := int(b.regione)
		if i >= 0 and i < g.regioni.size():
			nome = str(g.regioni[i].get("clima", nome))
	return GameState.climi.get(nome, GameState.dati_clima())


## Il campo come il terreno del feudo: i colori del suolo e gli alberi del clima nella stagione di
## adesso, le celle a "fetta di terra" (una fascia d'erba, poi terra e terra scura).
func _crea_campo() -> void:
	var k := LowPoly.Costruttore.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var clima := _clima_campo()
	var st := GameState.stagione
	var suolo: Dictionary = clima.get("suolo", {})
	var dati_alberi: Dictionary = clima.get("alberi", {})
	var erba := Color(str(suolo.get("erba", ["6fae47", "8db24a", "b39a48", "e6ecef"])[st]))
	var acqua := Color(str(suolo.get("acqua", ["4a90c8", "4a90c8", "4a86b8", "b8d8ea"])[st]))
	var roccia := Color(str(suolo.get("roccia", ["9a978d", "9a978d", "968f80", "dfe5e8"])[st]))
	var tinte: Array = suolo.get("tinte_zone", ["000000", "3d6a3c", "6f7a3c", "9a9884"])
	var pineta := Color(str(tinte[TerrenoFeudo.Bioma.PINETA]))
	var rupi := Color(str(tinte[TerrenoFeudo.Bioma.RUPI]))
	var misto := 0.12 if st == GameState.INVERNO else 0.38
	var misure: Array = dati_alberi.get("tronco", [1.2, 1.0])
	var alto_tronco := float(misure[0])
	var tronco := LowPoly.cilindro(0.16 * float(misure[1]), 0.12 * float(misure[1]), alto_tronco, 5)
	var chiome := [VistaTerreno.forma_chioma(str(dati_alberi.get("primo", "tondo")), alto_tronco),
		VistaTerreno.forma_chioma(str(dati_alberi.get("secondo", "pino")), alto_tronco)]
	var colori_chiome := [Color(str(dati_alberi.get("colori_primo", ["4a9a3e", "5aa035", "d0782c", "8a7a68"])[st])),
		Color(str(dati_alberi.get("colori_secondo", ["2f6b40", "2f6b40", "2f6b40", "c4d6d0"])[st]))]
	var quota_secondo := float(dati_alberi.get("quota_secondo", [0.45, 0.92, 0.15, 0.6])[TerrenoFeudo.Bioma.PINETA])
	var masso := LowPoly.sfera(0.8, 1.1, 6, 3)
	var alberi: Array = [[], []]  # per tipo di chioma: [trasformazione, colore]
	for r in LogicaBattaglia.ALTEZZA:
		for c in LogicaBattaglia.LARGHEZZA:
			var cella := Vector2i(c, r)
			var t := LogicaBattaglia.terreno_a(GameState.battaglia, cella)
			var p := posizione(cella)
			var alto := _suolo(cella)
			var colore: Color
			match t:
				LogicaBattaglia.Terreno.ACQUA:
					colore = acqua
				LogicaBattaglia.Terreno.COLLINA:
					colore = erba.darkened(0.12).lerp(rupi, misto * 0.6)
				LogicaBattaglia.Terreno.BOSCO:
					colore = erba.darkened(0.08).lerp(pineta, misto)
				_:
					colore = erba
			# la stessa leggera variazione per cella del feudo, niente scacchiera piatta
			var v := float(absi(hash(cella)) % 100) / 100.0
			colore = colore.lightened(v * 0.05) if v > 0.5 else colore.darkened(v * 0.05)
			_cella_suolo(k, cella, alto, colore)
			match t:
				LogicaBattaglia.Terreno.PIANURA:
					if rng.randf() < 0.5:
						var a := rng.randf() * TAU
						k.forma(LowPoly.cilindro(0.16, 0.0, 0.4, 4), LowPoly.t(p + Vector3(cos(a) * R * 0.55, 0.2, sin(a) * R * 0.55)), colore.darkened(0.2))
				LogicaBattaglia.Terreno.BOSCO:
					for n in 3:
						var a := TAU * n / 3.0 + rng.randf()
						var dove := p + Vector3(cos(a), 0, sin(a)) * R * 0.5
						var scala := rng.randf_range(0.75, 0.95)
						var tipo := 1 if rng.randf() < quota_secondo else 0
						var tr := LowPoly.t(dove, Vector3.ONE * scala, rng.randf() * TAU)
						k.forma(tronco, tr * LowPoly.t(Vector3(0, alto_tronco / 2.0, 0)), VistaTerreno.TRONCO)
						alberi[tipo].append([tr, (colori_chiome[tipo] as Color).lightened(rng.randf_range(-0.08, 0.08))])
				LogicaBattaglia.Terreno.COLLINA:
					k.forma(masso, LowPoly.t(p + Vector3(R * 0.45, 0.15, -R * 0.3), Vector3(0.7, 0.5, 0.6), rng.randf() * TAU), roccia.lightened(rng.randf_range(-0.1, 0.1)))
					k.forma(masso, LowPoly.t(p + Vector3(-R * 0.4, 0.1, R * 0.35), Vector3(0.45, 0.35, 0.4), rng.randf() * TAU), roccia.darkened(rng.randf_range(0.0, 0.1)))
	_crea_mura(k)
	var campo := MeshInstance3D.new()
	campo.mesh = k.mesh()
	add_child(campo)
	# le chiome (bianche: il colore della stagione lo dà ogni istanza)
	for tipo in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = chiome[tipo]
		mm.instance_count = alberi[tipo].size()
		for n in alberi[tipo].size():
			mm.set_instance_transform(n, alberi[tipo][n][0])
			mm.set_instance_color(n, alberi[tipo][n][1])
		var nodo := MultiMeshInstance3D.new()
		nodo.multimesh = mm
		add_child(nodo)


## Una cella come nel feudo: la cima piatta e, dove il vicino è più basso, il gradino; sul bordo del
## campo la fetta di terra (fascia d'erba, terra, terra scura).
func _cella_suolo(k: LowPoly.Costruttore, c: Vector2i, h: float, colore: Color) -> void:
	var x0 := c.x * CELLA
	var z0 := c.y * CELLA
	var x1 := x0 + CELLA
	var z1 := z0 + CELLA
	k.quad(Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Vector3.UP, colore)
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var vicino: Vector2i = c + dir
		var bordo := not LogicaBattaglia.dentro(vicino)
		var h_vicino := VistaTerreno.FONDO if bordo else _suolo(vicino)
		if h_vicino >= h:
			continue
		var n := Vector3(dir.x, 0, dir.y)
		var a: Vector3
		var b: Vector3
		match dir:
			Vector2i(1, 0):
				a = Vector3(x1, 0, z0); b = Vector3(x1, 0, z1)
			Vector2i(-1, 0):
				a = Vector3(x0, 0, z0); b = Vector3(x0, 0, z1)
			Vector2i(0, 1):
				a = Vector3(x0, 0, z1); b = Vector3(x1, 0, z1)
			_:
				a = Vector3(x0, 0, z0); b = Vector3(x1, 0, z0)
		if bordo:
			_parete(k, a, b, h, h - 0.3, n, colore.darkened(0.1))
			_parete(k, a, b, h - 0.3, -1.2, n, VistaTerreno.TERRA)
			_parete(k, a, b, -1.2, VistaTerreno.FONDO, n, VistaTerreno.TERRA_SCURA)
		else:
			_parete(k, a, b, h, h_vicino, n, colore.darkened(0.25))


func _parete(k: LowPoly.Costruttore, a: Vector3, b: Vector3, sopra: float, sotto: float, n: Vector3, colore: Color) -> void:
	k.quad(Vector3(a.x, sopra, a.z), Vector3(b.x, sopra, b.z), Vector3(b.x, sotto, b.z), Vector3(a.x, sotto, a.z), n, colore)


## Le mura del castello, come quelle del feudo: un pilastro per cella, i tratti verso le celle di
## mura vicine (e verso la porta), i merli; sopra la porta l'arco.
func _crea_mura(k: LowPoly.Costruttore) -> void:
	var b := GameState.battaglia
	var porta := Vector2i(-1, -1)
	for u in b.unita:
		if u.tipo == LogicaBattaglia.PORTA:
			porta = LogicaBattaglia.cella(u)
	var largo := CELLA * 0.62
	for r in LogicaBattaglia.ALTEZZA:
		for c in LogicaBattaglia.LARGHEZZA:
			var cella := Vector2i(c, r)
			if LogicaBattaglia.terreno_a(b, cella) != LogicaBattaglia.Terreno.MURA:
				continue
			var centro := Vector3((c + 0.5) * CELLA, SUOLO_MURA, (r + 0.5) * CELLA)
			k.forma(LowPoly.cubo(Vector3(largo + 0.15, ALTEZZA_MURA + 0.05, largo + 0.15)), LowPoly.t(centro + Vector3(0, (ALTEZZA_MURA + 0.05) / 2.0, 0)), VistaTerreno.PIETRA_MURA_SCURA)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: Vector2i = cella + d
				if not LogicaBattaglia.dentro(v) or (LogicaBattaglia.terreno_a(b, v) != LogicaBattaglia.Terreno.MURA and v != porta):
					continue
				var verso := Vector3(d.x, 0, d.y)
				var lungo := CELLA / 2.0
				var dim := Vector3(absf(d.x) * lungo + absf(d.y) * largo, ALTEZZA_MURA, absf(d.y) * lungo + absf(d.x) * largo)
				k.forma(LowPoly.cubo(dim), LowPoly.t(centro + verso * (lungo / 2.0) + Vector3(0, ALTEZZA_MURA / 2.0, 0)), VistaTerreno.PIETRA_MURA)
			# merli sui quattro angoli del camminamento
			for m in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				k.forma(LowPoly.cubo(Vector3(0.35, 0.4, 0.35)), LowPoly.t(centro + Vector3(m.x * largo * 0.42, ALTEZZA_MURA + 0.2, m.y * largo * 0.42)), VistaTerreno.PIETRA_MURA_SCURA)
	if porta.x >= 0:
		var sopra := Vector3((porta.x + 0.5) * CELLA, SUOLO_MURA, (porta.y + 0.5) * CELLA)
		k.forma(LowPoly.cubo(Vector3(largo, 0.5, CELLA)), LowPoly.t(sopra + Vector3(0, ALTEZZA_MURA - 0.25, 0)), VistaTerreno.PIETRA_MURA_SCURA)


func _crea_bandiera() -> void:
	var b := GameState.battaglia
	var c := Vector2i(int(b.bandiera[0]), int(b.bandiera[1]))
	var p := posizione(c)
	var k := LowPoly.Costruttore.new()
	var colore: Color = COLORI_NEMICI.get(b.tipo_nemico, Color("3f6f9f"))
	k.forma(LowPoly.cilindro(0.08, 0.08, 4.0, 5), LowPoly.t(p + Vector3(-R * 0.55, 2.0, -R * 0.35)), Color("5a3a22"))
	k.forma(LowPoly.cubo(Vector3(1.4, 0.9, 0.06)), LowPoly.t(p + Vector3(-R * 0.55 + 0.7, 3.5, -R * 0.35)), colore)
	k.forma(LowPoly.cubo(Vector3(CELLA * 0.9, 0.05, CELLA * 0.9)), LowPoly.t(p + Vector3(0, 0.02, 0)), colore.lightened(0.3))
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
	if u.tipo == LogicaBattaglia.PORTA:
		_crea_porta(u)
		return
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
	nodo.add_child(_barra("Fondo", Color(0.06, 0.06, 0.08, 0.85), 1.0, 0))
	nodo.add_child(_barra("Vita", Color("e2574c") if u.lato == "noi" else Color("5f9ee0"), 1.0, 1))
	_aggiorna_unita(u)


const LARGO_BARRA := 1.8

## Una barretta sempre rivolta alla camera sopra l'unità: il fondo scuro e quanti uomini restano.
func _barra(nome: String, colore: Color, quota: float, ordine: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nome
	var q := QuadMesh.new()
	q.size = Vector2(LARGO_BARRA * quota, 0.26)
	q.center_offset = Vector3(-LARGO_BARRA * (1.0 - quota) / 2.0, 0, 0)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = ordine
	mat.albedo_color = colore
	m.material_override = mat
	m.position = Vector3(0, 2.35, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## La porta del castello: due battenti di legno sotto l'arco, con la barra dei punti che restano.
func _crea_porta(u: Dictionary) -> void:
	var nodo := Node3D.new()
	add_child(nodo)
	_nodi[int(u.id)] = nodo
	nodo.position = Vector3((int(u.cella[0]) + 0.5) * CELLA, SUOLO_MURA, (int(u.cella[1]) + 0.5) * CELLA)
	var k := LowPoly.Costruttore.new()
	for lato in [-1, 1]:
		k.forma(LowPoly.cubo(Vector3(0.3, ALTEZZA_MURA - 0.5, CELLA * 0.48)), LowPoly.t(Vector3(0, (ALTEZZA_MURA - 0.5) / 2.0, lato * CELLA * 0.25)), VistaTerreno.LEGNO_PONTE)
		for f in 2:
			k.forma(LowPoly.cubo(Vector3(0.34, 0.1, CELLA * 0.44)), LowPoly.t(Vector3(0, 0.35 + f * 0.6, lato * CELLA * 0.25)), Color("4a4a4a"))
	var m := MeshInstance3D.new()
	m.name = "Figure"
	m.mesh = k.mesh()
	nodo.add_child(m)
	var etichetta := Label3D.new()
	etichetta.name = "Numero"
	etichetta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etichetta.position = Vector3(0, ALTEZZA_MURA + 1.4, 0)
	etichetta.font_size = 110
	etichetta.pixel_size = 0.01
	etichetta.outline_size = 12
	etichetta.no_depth_test = true
	nodo.add_child(etichetta)
	var fondo := _barra("Fondo", Color(0.06, 0.06, 0.08, 0.85), 1.0, 0)
	var vita := _barra("Vita", Color("c8a060"), 1.0, 1)
	for barra in [fondo, vita]:
		barra.position.y = ALTEZZA_MURA + 0.9
		nodo.add_child(barra)
	_aggiorna_unita(u)


func _aggiorna_unita(u: Dictionary) -> void:
	var nodo: Node3D = _nodi.get(int(u.id))
	if nodo == null:
		return
	if u.tipo == LogicaBattaglia.PORTA:
		_aggiorna_porta(u, nodo)
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
	var vita: MeshInstance3D = nodo.get_node("Vita")
	var quota := clampf(float(u.uomini) / maxf(1.0, float(u.max)), 0.0, 1.0)
	var q: QuadMesh = vita.mesh
	q.size.x = LARGO_BARRA * quota
	q.center_offset.x = -LARGO_BARRA * (1.0 - quota) / 2.0
	vita.visible = quota > 0.0
	if int(u.uomini) <= 0:
		var tw := create_tween()
		tw.tween_property(nodo, "scale", Vector3(1.35, 0.05, 1.35), 0.4)
		tw.tween_callback(nodo.queue_free)
		_nodi.erase(int(u.id))


func _aggiorna_porta(u: Dictionary, nodo: Node3D) -> void:
	var etichetta: Label3D = nodo.get_node("Numero")
	etichetta.text = str(int(u.uomini))
	etichetta.modulate = Color("f0dcb0")
	var vita: MeshInstance3D = nodo.get_node("Vita")
	var quota := clampf(float(u.uomini) / maxf(1.0, float(u.max)), 0.0, 1.0)
	var q: QuadMesh = vita.mesh
	q.size.x = LARGO_BARRA * quota
	q.center_offset.x = -LARGO_BARRA * (1.0 - quota) / 2.0
	if int(u.uomini) <= 0:
		# sfondata: i battenti cadono
		var tw := create_tween()
		tw.tween_property(nodo, "scale", Vector3(1.0, 0.05, 1.0), 0.4)
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
	if _occupato or b.is_empty() or b.finita or not (b.fase in ["noi", "schieramento"]):
		return
	var raggio := camera.raggio(schermo)
	var o: Vector3 = raggio[0]
	var d: Vector3 = raggio[1]
	var cella := cella_da_raggio(o, d)
	if cella.x < 0:
		_scegli(-1)
		return
	var chi := LogicaBattaglia.occupante(b, cella)
	var u := LogicaBattaglia.trova(b, chi)
	if b.fase == "schieramento":
		_tocco_schieramento(chi, u, cella)
		return
	if not u.is_empty() and u.lato == "noi":
		_scegli(chi)
	elif not u.is_empty() and _scelta >= 0 and _bersagli.any(func(x): return int(x.id) == chi):
		if _mirato == chi:
			_attacca(_scelta, chi)
		else:
			_mirato = chi
			_disegna_evidenza()
			_aggiorna()
	elif _possibili.has(cella):
		_muovi(_scelta, cella)
	else:
		_scegli(-1)


## Durante lo schieramento: si sceglie una nostra unità e la si mette in una cella della zona
## (se c'è già una nostra unità, le due si scambiano).
func _tocco_schieramento(chi: int, u: Dictionary, cella: Vector2i) -> void:
	if _scelta >= 0 and chi != _scelta and GameState.battaglia_schiera(_scelta, cella):
		Audio.effetto("click")
		for x in GameState.battaglia.unita:
			var nodo: Node3D = _nodi.get(int(x.id))
			if nodo and nodo.position.distance_to(posizione(LogicaBattaglia.cella(x))) > 0.01:
				create_tween().tween_property(nodo, "position", posizione(LogicaBattaglia.cella(x)), 0.2)
		_scegli(-1)
	elif not u.is_empty() and u.lato == "noi":
		_scegli(chi)
	else:
		_scegli(-1)


func _scegli(id: int) -> void:
	_scelta = id
	_mirato = -1
	_possibili = {}
	_bersagli = []
	var u := LogicaBattaglia.trova(GameState.battaglia, id)
	if not u.is_empty() and GameState.battaglia.fase == "noi":
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
	if not _occupato and GameState.battaglia.fase == "schieramento":
		GameState.battaglia_inizia()
		_scegli(-1)
		return
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
	obiettivo.text = ("Assedio: sfonda la porta del castello, prendi la loro bandiera e tienila per un turno, o distruggi i difensori" if b.get("assedio", false)
		else "Prendi la loro bandiera e tienila per un turno, o distruggi il loro esercito")
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
	var loro := LogicaBattaglia.vive(b, "loro").filter(func(x): return x.tipo != LogicaBattaglia.PORTA)
	var uomini_noi: int = noi.reduce(func(s, u): return s + int(u.uomini), 0)
	var uomini_loro: int = loro.reduce(func(s, u): return s + int(u.uomini), 0)
	if b.fase == "schieramento":
		_turno.text = "Schieramento  ·  noi %d uomini, loro %d" % [uomini_noi, uomini_loro]
	else:
		_turno.text = "Turno %d  ·  %s  ·  noi %d uomini, loro %d" % [int(b.turno),
			"il tuo turno" if b.fase == "noi" else ("turno del nemico" if b.fase == "loro" else "finita"), uomini_noi, uomini_loro]
	_btn_fine.text = "Inizia la battaglia" if b.fase == "schieramento" else "Fine turno"
	_diario.text = "\n".join(b.diario.slice(maxi(0, b.diario.size() - 3)))
	var u := LogicaBattaglia.trova(b, _scelta)
	var m := LogicaBattaglia.trova(b, _mirato)
	if b.fase == "schieramento":
		_scheda.text = ("%s: tocca una cella azzurra per spostarla (o un'altra tua unità per scambiarle)." % _cfg.unita[u.tipo].nome) if not u.is_empty() \
			else "Schiera l'esercito: tocca una tua unità e poi una cella azzurra. Metti le lance davanti ai cavalli, gli arcieri dietro, e cerca le colline. Poi \"Inizia la battaglia\"."
	elif not u.is_empty() and not m.is_empty():
		var p := GameState.battaglia_anteprima(_scelta, _mirato)
		_scheda.text = "%s contro %s (%d %s)\nPerdite previste: loro %d, noi %d%s\n%s\nTocca di nuovo il nemico per attaccare." % [
			_cfg.unita[u.tipo].nome, _cfg.unita[m.tipo].nome, int(m.uomini), "punti" if m.tipo == LogicaBattaglia.PORTA else "uomini", int(p.morti_difensore), int(p.morti_attaccante),
			" (da lontano, niente risposta)" if p.da_lontano else "", ", ".join(p.voci) if not p.voci.is_empty() else "Nessun vantaggio di terreno."]
	elif u.is_empty():
		_scheda.text = "Tocca una tua unità (stendardo rosso) per muoverla: le celle chiare sono dove può andare, i nemici in rosso quelli che può attaccare. Boschi e colline costano 2 mosse ma difendono meglio; dall'alto si colpisce più forte, attaccare in tanti attorno a un nemico aiuta (fianchi), stare vicini protegge (supporto)."
	else:
		var d: Dictionary = _cfg.unita[u.tipo]
		var t: Dictionary = _cfg.terreni[LogicaBattaglia.terreno_a(b, LogicaBattaglia.cella(u))]
		_scheda.text = "%s%s\nUomini %d/%d · forza %.1f a testa\nMosse %d · gittata %d\nSu %s (attacco ×%.1f, difesa ×%.2f)\n%s" % [
			d.nome, "", int(u.uomini), int(u.max), LogicaBattaglia.forza(u, _cfg),
			int(u.mosse), LogicaBattaglia.gittata(b, u, _cfg), t.nome.to_lower(), float(t.attacco), float(t.difesa),
			"Ha già attaccato in questo turno." if bool(u.attaccato) else ("Nemici a tiro: %d" % _bersagli.size() if not _bersagli.is_empty() else "")]
	_btn_fine.disabled = _occupato or not (b.fase in ["noi", "schieramento"])
	for x in b.unita:
		_aggiorna_unita(x)


## Illumina le celle raggiungibili (chiare), l'unità scelta (oro) e i nemici attaccabili (rosso).
func _disegna_evidenza() -> void:
	var k := LowPoly.Costruttore.new()
	var vuoto := true
	var b := GameState.battaglia
	if b.get("fase", "") == "schieramento":
		for c in LogicaBattaglia.zona_schieramento(b, _cfg):
			_casella(k, c, Color(0.35, 0.7, 1.0, 0.35))
			vuoto = false
	var u := LogicaBattaglia.trova(b, _scelta)
	if not u.is_empty():
		_casella(k, LogicaBattaglia.cella(u), Color(1.0, 0.85, 0.3, 0.7))
		vuoto = false
	for c in _possibili:
		_casella(k, c, Color(1, 1, 1, 0.35))
		vuoto = false
	for x in _bersagli:
		_casella(k, LogicaBattaglia.cella(x), Color(1.0, 0.1, 0.05, 0.85) if int(x.id) == _mirato else Color(1.0, 0.25, 0.2, 0.5))
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


func _casella(k: LowPoly.Costruttore, c: Vector2i, colore: Color) -> void:
	var p := posizione(c)
	k.forma(LowPoly.cubo(Vector3(CELLA * 0.86, 0.04, CELLA * 0.86)), LowPoly.t(p + Vector3(0, 0.06, 0)), colore)


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
