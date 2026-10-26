class_name Prologo
extends CanvasLayer
## Il prologo davanti al falò: il regno è caduto, restano tre famiglie.
## Il giocatore sceglie quale casata guiderà i sopravvissuti; le altre due diventano il consiglio.

signal finito

const TESTO := Color("f3e3c3")
const TESTO_CHIARO := Color("d9c7a0")
const ORO := Color("f2c94c")

var _radice: Control
var _carte: Array[Button] = []
var _conferma: Button
var _scelta := -1


func _ready() -> void:
	layer = 5
	_radice = Control.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radice.theme = Hud.crea_tema()
	add_child(_radice)
	var velo := ColorRect.new()
	velo.color = Color(0.05, 0.03, 0.02, 0.6)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radice.add_child(velo)
	_mostra_scelta()


func _mostra_scelta() -> void:
	var col := _colonna()
	var regno: String = GameState.dati_famiglie.regno_caduto
	col.add_child(_testo("Le ceneri di %s" % regno, 15, ORO))
	col.add_child(_testo(
		"Il Regno di %s è caduto. In una valle sconosciuta, attorno a un falò, restano tre famiglie: %d anime in tutto.\nChi guiderà i sopravvissuti?" % [regno, GameState.abitanti],
		8, TESTO, 420))

	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	riga.add_theme_constant_override("separation", 8)
	col.add_child(riga)
	var gruppo := ButtonGroup.new()
	for i in GameState.famiglie.size():
		var carta := _carta(i)
		carta.button_group = gruppo
		carta.pressed.connect(_seleziona.bind(i))
		riga.add_child(carta)
		_carte.append(carta)

	_conferma = Button.new()
	_conferma.text = "Scegli una casata"
	_conferma.disabled = true
	_conferma.custom_minimum_size = Vector2(200, 20)
	_conferma.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_conferma.focus_mode = Control.FOCUS_NONE
	_conferma.pressed.connect(_conferma_scelta)
	col.add_child(_conferma)


func _carta(i: int) -> Button:
	var f: Dictionary = GameState.famiglie[i]
	var t := GameState.tratto(i)
	var carta := Button.new()
	carta.toggle_mode = true
	carta.focus_mode = Control.FOCUS_NONE
	carta.custom_minimum_size = Vector2(138, 150)
	var dentro := VBoxContainer.new()
	dentro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dentro.set_anchors_preset(Control.PRESET_FULL_RECT)
	dentro.offset_left = 6
	dentro.offset_right = -6
	dentro.offset_top = 6
	dentro.offset_bottom = -6
	dentro.add_theme_constant_override("separation", 3)
	carta.add_child(dentro)
	dentro.add_child(_testo("Casata %s" % f.casata, 10, ORO, 0))
	dentro.add_child(_testo("guidata da %s" % f.capo, 7, TESTO_CHIARO, 0))
	dentro.add_child(_testo("%s · %d persone" % [t.get("nome", ""), int(f.membri)], 8, TESTO, 0))
	dentro.add_child(_testo("Se guida: %s" % t.get("descrizione", ""), 7, Color("9fd18b"), 0))
	dentro.add_child(_testo(f.storia, 7, TESTO_CHIARO, 0))
	var motto := _testo("«%s»" % f.motto, 7, TESTO, 0)
	motto.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	dentro.add_child(motto)
	for l in dentro.get_children():
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return carta


func _seleziona(i: int) -> void:
	_scelta = i
	_conferma.disabled = false
	_conferma.text = "Guideranno i %s" % GameState.famiglie[i].casata


func _conferma_scelta() -> void:
	if _scelta < 0:
		return
	GameState.scegli_capo(_scelta)
	for figlio in _radice.get_children():
		if figlio is VBoxContainer:
			figlio.queue_free()
	_mostra_consiglio()


## Secondo passo: chi guida e chi siede nel consiglio.
func _mostra_consiglio() -> void:
	var col := _colonna()
	var guida: Dictionary = GameState.famiglie[GameState.capo]
	col.add_child(_testo("%s guida i sopravvissuti" % guida.capo, 14, ORO))
	var nomi: Array[String] = []
	for i in GameState.consiglieri():
		var f: Dictionary = GameState.famiglie[i]
		nomi.append("%s (%s)" % [f.capo, GameState.tratto(i).get("nome", "").to_lower()])
	col.add_child(_testo(
		"Le altre due casate non se ne vanno: %s siederanno nel tuo consiglio e ti daranno suggerimenti, ognuno sulla propria arte.\nUn giorno, quando conquisterai nuove terre, potrai affidarne una a loro come vassalli.\n\nPrima di tutto: cibo, legna e un tetto prima dell'inverno." % " e ".join(nomi),
		8, TESTO, 400))
	var via := Button.new()
	via.text = "Al lavoro"
	via.custom_minimum_size = Vector2(140, 20)
	via.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	via.focus_mode = Control.FOCUS_NONE
	via.pressed.connect(func():
		finito.emit()
		queue_free())
	col.add_child(via)


func _colonna() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	_radice.add_child(col)
	return col


func _testo(testo: String, dimensione: int, colore: Color, larghezza := 0) -> Label:
	var l := Label.new()
	l.text = testo
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", colore)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if larghezza > 0:
		l.custom_minimum_size.x = larghezza
		l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l
