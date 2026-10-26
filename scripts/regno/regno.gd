extends Control
## Mappa del regno a tutto schermo: regioni stile carta antica, ognuna con nome,
## risorsa speciale e proprietario. Toccando la propria regione si entra nel feudo.
## Le regioni sono celle di Voronoi generate dal seme della partita.

const MARGINE := 14.0
const INCHIOSTRO := Color("5a4128")
const PERGAMENA := Color("dccba2")
const PERGAMENA_SCURA := Color("c4b085")
const COLORI_RISORSE := {
	"ferro": Color("4a5568"), "pietra": Color("8a8a8a"), "pesce": Color("3f7fbf"),
	"grano": Color("d4a72c"), "legname": Color("4f7a3a"),
}

var _dati: Dictionary
var _siti: Array[Vector2] = []  # posizioni normalizzate 0..1
var _regioni: Array[Dictionary] = []  # {nome, risorsa, signore, colore, poligono, centro}
var _mia := 0
var _info: Label
var _velo: ColorRect
var _entrando := false


func _ready() -> void:
	GameState.avvia()
	GameState.nel_feudo = false
	if GameState.capo < 0:
		# partita nuova: prima il prologo davanti al falò, poi la mappa
		get_tree().change_scene_to_file.call_deferred("res://scenes/feudo.tscn")
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dati = (load("res://data/regioni.json") as JSON).data
	_genera()
	_crea_interfaccia()
	resized.connect(_calcola_poligoni)
	_calcola_poligoni()


func _genera() -> void:
	var g := Regioni.genera(GameState.seme_mappa)
	_siti = g.siti
	_regioni = g.regioni
	_mia = g.mia


func _area() -> Rect2:
	return Rect2(Vector2(MARGINE, 30), size - Vector2(MARGINE * 2, 30 + 34))


func _calcola_poligoni() -> void:
	var area := _area()
	var punti: Array[Vector2] = []
	for s in _siti:
		punti.append(area.position + s * area.size)
	for i in punti.size():
		var poligono := PackedVector2Array([
			area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
		for j in punti.size():
			if i != j:
				poligono = _taglia(poligono, punti[i], punti[j])
		_regioni[i].poligono = poligono
		_regioni[i].centro = punti[i]
	queue_redraw()


## Tiene la parte del poligono più vicina ad a che a b (un passo di Voronoi).
func _taglia(poligono: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var medio := (a + b) / 2.0
	var normale := b - a
	var risultato := PackedVector2Array()
	for k in poligono.size():
		var p := poligono[k]
		var q := poligono[(k + 1) % poligono.size()]
		var dp := (p - medio).dot(normale)
		var dq := (q - medio).dot(normale)
		if dp <= 0.0:
			risultato.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			risultato.append(p + (q - p) * (dp / (dp - dq)))
	return risultato


func _crea_interfaccia() -> void:
	var tema := Theme.new()
	tema.default_font_size = 8
	theme = tema
	var titolo := Label.new()
	titolo.text = "Le terre dei sopravvissuti di %s  ·  %s, anno %d" % [GameState.dati_famiglie.regno_caduto, GameState.STAGIONI[GameState.stagione], GameState.anno]
	titolo.add_theme_font_size_override("font_size", 12)
	titolo.add_theme_color_override("font_color", INCHIOSTRO)
	titolo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titolo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	titolo.offset_top = 8
	add_child(titolo)
	_info = Label.new()
	_info.text = "Tocca la tua regione, bordata di rosso, per entrare nel feudo"
	_info.add_theme_color_override("font_color", INCHIOSTRO)
	_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.offset_bottom = -12
	add_child(_info)
	_velo = ColorRect.new()
	_velo.color = Color(0, 0, 0, 0)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_velo)


func _draw() -> void:
	if _regioni.is_empty():
		return  # si sta andando al prologo: niente da disegnare
	draw_rect(Rect2(Vector2.ZERO, size), PERGAMENA)
	# macchie della carta, sempre uguali per la stessa partita
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.seme_mappa
	for i in 60:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_circle(p, rng.randf_range(4, 22), Color(PERGAMENA_SCURA, 0.18))
	var font := get_theme_default_font()
	for i in _regioni.size():
		var r: Dictionary = _regioni[i]
		if not r.has("poligono") or r.poligono.size() < 3:
			continue
		draw_colored_polygon(r.poligono, Color(r.colore, 0.28 if i != _mia else 0.4))
	for i in _regioni.size():
		var r: Dictionary = _regioni[i]
		if not r.has("poligono") or r.poligono.size() < 3:
			continue
		var bordo: PackedVector2Array = r.poligono.duplicate()
		bordo.append(bordo[0])
		draw_polyline(bordo, INCHIOSTRO, 1.0, true)
	# la regione del giocatore sopra le altre, con il bordo rosso
	var mia: Dictionary = _regioni[_mia]
	if mia.has("poligono"):
		var bordo: PackedVector2Array = mia.poligono.duplicate()
		bordo.append(bordo[0])
		draw_polyline(bordo, Color("b03a2e"), 2.5, true)
	for i in _regioni.size():
		var r: Dictionary = _regioni[i]
		if not r.has("centro"):
			continue
		var c: Vector2 = r.centro
		draw_string(font, c + Vector2(-60, -4), r.nome, HORIZONTAL_ALIGNMENT_CENTER, 120, 9, INCHIOSTRO)
		draw_circle(c + Vector2(0, 7), 5.5, Color(COLORI_RISORSE[r.risorsa], 0.9))
		draw_arc(c + Vector2(0, 7), 5.5, 0, TAU, 16, INCHIOSTRO, 1.0, true)
		draw_string(font, c + Vector2(-60, 20), r.signore, HORIZONTAL_ALIGNMENT_CENTER, 120, 6, Color(INCHIOSTRO, 0.8))
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), INCHIOSTRO, false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if _entrando:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_tocca(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_entra()  # anche ingrandire con la rotellina porta nel feudo


func _tocca(p: Vector2) -> void:
	for i in _regioni.size():
		var r: Dictionary = _regioni[i]
		if r.has("poligono") and Geometry2D.is_point_in_polygon(p, r.poligono):
			if i == _mia:
				_entra()
			else:
				_info.text = "%s  ·  %s  ·  risorsa: %s" % [r.nome, r.signore, r.risorsa]
			return


## Zoom animato sulla propria regione e dissolvenza, poi la scena 3D del feudo.
func _entra() -> void:
	_entrando = true
	pivot_offset = _regioni[_mia].centro
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(4, 4), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_velo, "color:a", 1.0, 0.6)
	tw.chain().tween_callback(func(): get_tree().change_scene_to_file("res://scenes/feudo.tscn"))
