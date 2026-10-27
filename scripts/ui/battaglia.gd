class_name SchermataBattaglia
extends Control
## La battaglia per conquistare un regno, a tutto schermo: a sinistra il nostro esercito
## (rosso, con gli uomini dei vassalli in arancio), a destra quello nemico. A ogni turno si
## sceglie una tattica: le due schiere si scontrano al centro e chi cade resta a terra.
## La logica è in GameState.round_battaglia; qui solo il disegno e i pulsanti.

const NOSTRI := Color("b03a2e")
const AIUTI := Color("d0802c")
const CADUTO := Color(0.25, 0.22, 0.2, 0.55)
const COLORI_NEMICI := {"signore": Color("3f6f9f"), "banditi": Color("3a3636"), "libera": Color("8a6a3a")}
const ERBA := Color("7aa24e")
const ERBA_SCURA := Color("5e8a3c")
const INCHIOSTRO := Color("3b2a1e")
const MASSIMO_FIGURE := 40  # oltre, una figura vale più uomini

var _titolo: Label
var _stato: Label
var _racconto: Label
var _bottoni: Dictionary = {}  # tattica -> Button
var _ritirata: Button
var _chiudi: Button
var _scontro := 0.0  # 0..1: quanto le schiere sono avanzate verso il centro
var _caduti_noi := 0
var _caduti_loro := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Hud.crea_tema()
	_titolo = Label.new()
	_titolo.add_theme_font_size_override("font_size", 12)
	_titolo.add_theme_color_override("font_color", INCHIOSTRO)
	_titolo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_titolo.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_titolo.offset_top = 6
	add_child(_titolo)
	_stato = Label.new()
	_stato.add_theme_color_override("font_color", INCHIOSTRO)
	_stato.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_stato.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stato.offset_top = 24
	add_child(_stato)
	var sotto := PanelContainer.new()
	sotto.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sotto.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sotto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sotto.offset_bottom = -4
	add_child(sotto)
	var col := VBoxContainer.new()
	sotto.add_child(col)
	_racconto = Label.new()
	_racconto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_racconto.custom_minimum_size.x = 380
	col.add_child(_racconto)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(riga)
	for nome in GameState.tattiche():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(88, 22)
		b.pressed.connect(_turno.bind(nome))
		riga.add_child(b)
		_bottoni[nome] = b
	_ritirata = Button.new()
	_ritirata.text = "Ritirata"
	_ritirata.focus_mode = Control.FOCUS_NONE
	_ritirata.custom_minimum_size = Vector2(60, 22)
	_ritirata.pressed.connect(_turno.bind("ritirata"))
	riga.add_child(_ritirata)
	_chiudi = Button.new()
	_chiudi.text = "Torna al feudo"
	_chiudi.focus_mode = Control.FOCUS_NONE
	_chiudi.custom_minimum_size = Vector2(100, 22)
	_chiudi.pressed.connect(func(): GameState.chiudi_battaglia(); queue_free())
	riga.add_child(_chiudi)
	GameState.battaglia_turno.connect(_su_turno)
	GameState.battaglia_finita.connect(func(_e): _aggiorna())
	_racconto.text = "Le schiere sono una di fronte all'altra. Scegli la tattica del primo turno."
	_aggiorna()


func _turno(nome: String) -> void:
	if _scontro > 0.0:
		return  # aspetta che finisca lo scontro di prima
	GameState.round_battaglia(nome)


## Le schiere avanzano, si scontrano e tornano indietro; intanto chi cade va a terra.
func _su_turno(t: Dictionary) -> void:
	_racconto.text = t.get("testo", "")
	var tw := create_tween()
	tw.tween_method(_imposta_scontro, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_caduti_noi = int(GameState.battaglia.get("nostri_inizio", 0)) + int(GameState.battaglia.get("aiuti_inizio", 0)) \
			- int(GameState.battaglia.get("nostri", 0)) - int(GameState.battaglia.get("aiuti", 0))
		_caduti_loro = int(GameState.battaglia.get("loro_inizio", 0)) - int(GameState.battaglia.get("loro", 0))
		queue_redraw())
	tw.tween_method(_imposta_scontro, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_aggiorna)


func _imposta_scontro(x: float) -> void:
	_scontro = x
	queue_redraw()


func _aggiorna() -> void:
	var b := GameState.battaglia
	if b.is_empty():
		return
	var r: Dictionary = GameState.regni[b.regione]
	_titolo.text = "Battaglia di %s" % r.nome
	_stato.text = "Turno %d di %d  ·  noi %d%s  ·  loro %d (%s)" % [int(b.turno), int(b.turni), int(b.nostri),
		" + %d dei vassalli" % int(b.aiuti) if int(b.aiuti_inizio) > 0 else "", int(b.loro), r.signore]
	var finita: bool = b.finita
	for nome in _bottoni:
		var t: Dictionary = GameState.tattiche()[nome]
		var bt: Button = _bottoni[nome]
		var perche := GameState.perche_no_tattica(nome)
		bt.text = t.nome
		bt.tooltip_text = t.descrizione + ("" if perche == "" else " (%s)" % perche)
		bt.disabled = finita or perche != ""
		bt.visible = not finita
	_ritirata.visible = not finita
	_chiudi.visible = finita
	if finita:
		_racconto.text = "%s\n%s" % [b.get("perche", ""),
			"%s ora è nostra." % r.nome if b.vinta else "Caduti dei nostri: %d." % (int(b.nostri_inizio) - int(b.nostri))]
	queue_redraw()


func _draw() -> void:
	var b := GameState.battaglia
	# il campo: cielo, colline lontane, prato
	draw_rect(Rect2(Vector2.ZERO, size), Color("cfe3ef"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, size.y * 0.32), Vector2(size.x * 0.3, size.y * 0.22),
		Vector2(size.x * 0.6, size.y * 0.3), Vector2(size.x, size.y * 0.2), Vector2(size.x, size.y * 0.45), Vector2(0, size.y * 0.45)]), Color("9cbf72"))
	draw_rect(Rect2(0, size.y * 0.4, size.x, size.y * 0.6), ERBA)
	for i in 12:
		var x := fmod(i * 97.3, size.x)
		draw_rect(Rect2(x, size.y * (0.45 + 0.04 * (i % 5)), 30, 3), ERBA_SCURA)
	if b.is_empty():
		return
	var tipo: String = GameState.regni[b.regione].tipo
	var loro_colore: Color = COLORI_NEMICI.get(tipo, Color("3f6f9f"))
	var noi := int(b.nostri_inizio) + int(b.aiuti_inizio)
	_schiera(noi, int(b.aiuti_inizio), _caduti_noi, true, NOSTRI, AIUTI)
	_schiera(int(b.loro_inizio), 0, _caduti_loro, false, loro_colore, loro_colore)
	# gli stendardi
	_stendardo(Vector2(size.x * 0.08, size.y * 0.42), NOSTRI)
	_stendardo(Vector2(size.x * 0.92, size.y * 0.42), loro_colore)


## Una schiera: figure in righe; le ultime "caduti" sono a terra. Gli aiuti sono gli ultimi in fondo.
func _schiera(totale: int, aiuti: int, caduti: int, sinistra: bool, colore: Color, colore_aiuti: Color) -> void:
	var per_figura := maxi(1, ceili(totale / float(MASSIMO_FIGURE)))
	var figure := ceili(totale / float(per_figura))
	var a_terra := ceili(caduti / float(per_figura))
	var righe := 5
	var passo := Vector2(14, 16)
	var fronte := size.x * (0.4 if sinistra else 0.6)
	var avanzata := _scontro * size.x * 0.07 * (1.0 if sinistra else -1.0)
	for i in figure:
		var colonna := i / righe
		var riga := i % righe
		var x := fronte - (colonna * passo.x + 8) * (1.0 if sinistra else -1.0) + avanzata
		var y := size.y * 0.47 + riga * passo.y + (colonna % 2) * 4
		var caduto := i >= figure - a_terra
		var c := colore_aiuti if i >= figure - ceili(aiuti / float(per_figura)) else colore
		_figura(Vector2(x, y), c, caduto, sinistra)


func _figura(p: Vector2, colore: Color, caduto: bool, verso_destra: bool) -> void:
	if caduto:
		draw_rect(Rect2(p + Vector2(-6, 5), Vector2(12, 4)), CADUTO)
		draw_circle(p + Vector2(7 if verso_destra else -7, 7), 2.2, CADUTO)
		return
	draw_rect(Rect2(p + Vector2(-3, -2), Vector2(6, 9)), colore)
	draw_circle(p + Vector2(0, -5), 2.6, Color("e0b08a"))
	draw_circle(p + Vector2(0, -6.5), 2.4, Color("8a9098"))  # elmo
	var dir := 1.0 if verso_destra else -1.0
	draw_line(p + Vector2(4 * dir, 8), p + Vector2(6 * dir, -10), Color("6b4a2e"), 1.2)  # lancia
	draw_rect(Rect2(p + Vector2(-5 if verso_destra else 2, 0), Vector2(3, 6)), colore.darkened(0.3))  # scudo


func _stendardo(p: Vector2, colore: Color) -> void:
	draw_line(p, p + Vector2(0, -40), INCHIOSTRO, 2.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -40), p + Vector2(18, -35), p + Vector2(0, -28)]), colore)
