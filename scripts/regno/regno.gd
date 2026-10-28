extends Control
## Mappa del regno a tutto schermo: regioni stile carta antica, ognuna con nome,
## risorsa speciale e proprietario. Toccando la propria regione si entra nel feudo.
## Le regioni sono celle di Voronoi generate dal seme della partita, con i confini ondulati.
## Toccando un'altra regione si apre la sua scheda: dal Borgo in poi si mandano spie,
## si propongono alleanze e si attacca (le missioni avanzano mentre il tempo scorre nel feudo).

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
var _scheda: PanelContainer
var _scheda_testo: Label
var _scheda_bottoni: Dictionary = {}  # azione -> Button
var _vassallo_box: VBoxContainer   # per le regioni conquistate: vassallo e tributo
var _btn_tributo: Dictionary = {}  # "basso" | "normale" | "alto" -> Button
var _btn_vassallo: Button
var _scelta := ""  # chiave della regione aperta nella scheda


func _ready() -> void:
	GameState.avvia()
	GameState.nel_feudo = false
	Audio.musica("regno")
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
		if GameState.versione_mappa >= 2:
			poligono = Regioni.ondula(poligono, area, GameState.seme_mappa, 12.0)
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
	_info.text = "Tocca la tua regione, bordata di rosso, per entrare nel feudo; le altre per spie, alleanze e guerra"
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
	var menu := Button.new()
	menu.text = "Menu"
	menu.theme = Hud.crea_tema()
	menu.focus_mode = Control.FOCUS_NONE
	menu.position = Vector2(10, 8)
	menu.custom_minimum_size = Vector2(40, 16)
	menu.pressed.connect(func():
		GameState.salva()
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	add_child(menu)
	add_child(_velo)
	_crea_scheda()
	GameState.changed.connect(func(): _aggiorna_scheda(); queue_redraw())


func _crea_scheda() -> void:
	_scheda = PanelContainer.new()
	_scheda.theme = Hud.crea_tema()
	_scheda.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_scheda.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_scheda.grow_vertical = Control.GROW_DIRECTION_BOTH
	_scheda.offset_right = -10
	_scheda.visible = false
	add_child(_scheda)
	var col := VBoxContainer.new()
	_scheda.add_child(col)
	_scheda_testo = Label.new()
	_scheda_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scheda_testo.custom_minimum_size.x = 190
	col.add_child(_scheda_testo)
	for azione in ["spia", "alleanza", "attacco"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 18)
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_azione.bind(azione))
		col.add_child(b)
		_scheda_bottoni[azione] = b
	_vassallo_box = VBoxContainer.new()
	col.add_child(_vassallo_box)
	var riga := HBoxContainer.new()
	_vassallo_box.add_child(riga)
	var l := Label.new()
	l.text = "Tributo:"
	riga.add_child(l)
	for quanto in ["basso", "normale", "alto"]:
		var b := Button.new()
		b.text = quanto.capitalize()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): GameState.imposta_tributo(_scelta, quanto); GameState.salva())
		riga.add_child(b)
		_btn_tributo[quanto] = b
	_btn_vassallo = Button.new()
	_btn_vassallo.focus_mode = Control.FOCUS_NONE
	_btn_vassallo.pressed.connect(_cambia_vassallo)
	_vassallo_box.add_child(_btn_vassallo)
	var chiudi := Button.new()
	chiudi.text = "Chiudi"
	chiudi.focus_mode = Control.FOCUS_NONE
	chiudi.pressed.connect(func(): _scheda.visible = false; _scelta = ""; queue_redraw())
	col.add_child(chiudi)


func _apri_scheda(chiave: String) -> void:
	_scelta = chiave
	_scheda.visible = true
	_aggiorna_scheda()
	queue_redraw()


func _aggiorna_scheda() -> void:
	if _scelta == "" or not GameState.regni.has(_scelta):
		return
	var r: Dictionary = GameState.regni[_scelta]
	var righe: Array[String] = ["%s · %s" % [r.nome, r.signore], "Risorsa: %s" % r.risorsa]
	_vassallo_box.visible = r.conquistato
	if r.conquistato:
		var v := int(r.vassallo)
		var parti: Array[String] = []
		var t := GameState.tributo_di(_scelta)
		for ris in t:
			parti.append("%d %s" % [t[ris], ris])
		righe.append("È nostra. La governa %s, tuo vassallo%s." % [GameState.nome_vassallo(v),
			" (casata %s, %s)" % [GameState.famiglie[v].casata, GameState.tratto(v).get("nome", "").to_lower()] if v >= 0 else ""])
		righe.append("Ogni stagione manda: %s." % ", ".join(parti))
		righe.append("Lealtà %d%%%s · in battaglia ci manda truppe per %d." % [int(r.lealta),
			" (a rischio di ribellione!)" if int(r.lealta) < int(GameState.bil.vassalli.soglia_ribellione) else "",
			roundi(GameState.leva_vassallo(_scelta))])
		righe.append("Un tributo alto rende di più ma fa perdere lealtà; basso la fa crescere.")
		for quanto in _btn_tributo:
			_btn_tributo[quanto].set_pressed_no_signal(quanto == r.tributo)
		var prossimo := _prossimo_vassallo()
		_btn_vassallo.text = "Affida a %s" % GameState.nome_vassallo(prossimo)
		_btn_vassallo.visible = prossimo != v
	elif r.spiato:
		righe.append("Forza: %d (il nostro esercito: %d)" % [GameState.forza_regno(_scelta), roundi(GameState.forza_esercito(GameState.soldati_presenti()))])
		if r.tipo == "signore":
			righe.append("Verso di noi: %s%s" % [GameState.testo_atteggiamento(int(r.atteggiamento)), " · alleato" if r.alleato else ""])
	else:
		righe.append("Non sappiamo quanto sono forti: manda una spia.")
	var m := GameState.missione_per(_scelta)
	if not m.is_empty():
		righe.append("In viaggio: %s, %d giorni (il tempo scorre nel feudo)" % [m.tipo, int(m.mancano)])
	_scheda_testo.text = "\n".join(righe)
	var d: Dictionary = GameState.bil.diplomazia
	var testi := {"spia": "Manda %s spia (%d oro)" % ["un'altra" if r.spiato else "una", int(d.costo_spia)],
		"alleanza": "Proponi alleanza (dono di %d oro)" % int(d.dono_alleanza),
		"attacco": "Attacca con %d soldati" % GameState.soldati_presenti()}
	for azione in _scheda_bottoni:
		var b: Button = _scheda_bottoni[azione]
		var perche := GameState.perche_no(azione, _scelta)
		b.text = testi[azione] + ("" if perche == "" else "\n(%s)" % perche)
		b.disabled = perche != ""
		b.visible = not r.conquistato and not (azione == "alleanza" and r.tipo != "signore")


## Il prossimo candidato a vassallo: i consiglieri liberi, poi un cavaliere.
func _prossimo_vassallo() -> int:
	var r: Dictionary = GameState.regni[_scelta]
	var candidati: Array[int] = GameState.consiglieri_liberi()
	if int(r.vassallo) >= 0:
		candidati.append(int(r.vassallo))
	candidati.append(GameState.CAVALIERE)
	var i := candidati.find(int(r.vassallo))
	return candidati[(i + 1) % candidati.size()]


func _cambia_vassallo() -> void:
	GameState.nomina_vassallo(_scelta, _prossimo_vassallo())
	GameState.salva()


func _azione(azione: String) -> void:
	match azione:
		"spia":
			GameState.manda_spia(_scelta)
		"alleanza":
			GameState.proponi_alleanza(_scelta)
		"attacco":
			GameState.attacca(_scelta)
	GameState.salva()
	_aggiorna_scheda()
	queue_redraw()


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
		var colore: Color = r.colore
		var stato: Dictionary = GameState.regni.get(str(i), {})
		if stato.get("conquistato", false):
			colore = Color("b03a2e")
		var tinta := Color(colore, 0.28 if i != _mia else 0.4)
		# un bordo ondulato che si incrocia non si riempie: prima lo si ripulisce (via i piccoli nodi)
		if Geometry2D.triangulate_polygon(r.poligono).is_empty():
			for pezzo in Geometry2D.offset_polygon(r.poligono, 0.2):
				if not Geometry2D.triangulate_polygon(pezzo).is_empty():
					draw_colored_polygon(pezzo, tinta)
		else:
			draw_colored_polygon(r.poligono, tinta)
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
	# alleati bordati di verde, la regione scelta di giallo, missioni in viaggio tratteggiate
	for i in _regioni.size():
		var r: Dictionary = _regioni[i]
		var stato: Dictionary = GameState.regni.get(str(i), {})
		if not r.has("poligono") or r.poligono.size() < 3:
			continue
		var bordo_r: PackedVector2Array = r.poligono.duplicate()
		bordo_r.append(bordo_r[0])
		if stato.get("alleato", false):
			draw_polyline(bordo_r, Color("4f8a3b"), 2.0, true)
		if str(i) == _scelta:
			draw_polyline(bordo_r, Color("f2c94c"), 2.0, true)
	for m in GameState.missioni:
		var a: Vector2 = _regioni[_mia].get("centro", Vector2.ZERO)
		var b: Vector2 = _regioni[int(m.regione)].get("centro", Vector2.ZERO)
		var colore_m := Color("8a2a20") if m.tipo == "attacco" else INCHIOSTRO
		draw_dashed_line(a, b, colore_m, 1.5, 4.0)
		var fatto := 1.0 - float(m.mancano) / float({"spia": GameState.bil.diplomazia.giorni_spia,
			"alleanza": GameState.bil.diplomazia.giorni_messaggero, "attacco": GameState.bil.diplomazia.giorni_marcia}[m.tipo])
		draw_circle(a.lerp(b, clampf(fatto, 0.0, 1.0)), 3.0, colore_m)
	for i in _regioni.size():
		var r: Dictionary = _regioni[i]
		if not r.has("centro"):
			continue
		var c: Vector2 = r.centro
		var stato: Dictionary = GameState.regni.get(str(i), {})
		if stato.get("spiato", false) and not stato.get("conquistato", false):
			draw_string(font, c + Vector2(-60, 28), "forza %d" % GameState.forza_regno(str(i)), HORIZONTAL_ALIGNMENT_CENTER, 120, 6, Color("8a2a20"))
		elif stato.get("conquistato", false):
			draw_string(font, c + Vector2(-60, 28), "nostra", HORIZONTAL_ALIGNMENT_CENTER, 120, 6, Color("8a2a20"))
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
				_apri_scheda(str(i))
			return
	_scheda.visible = false
	_scelta = ""
	queue_redraw()


## Zoom animato sulla propria regione e dissolvenza, poi la scena 3D del feudo.
func _entra() -> void:
	_entrando = true
	pivot_offset = _regioni[_mia].centro
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector2(4, 4), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_velo, "color:a", 1.0, 0.6)
	tw.chain().tween_callback(func(): get_tree().change_scene_to_file("res://scenes/feudo.tscn"))
