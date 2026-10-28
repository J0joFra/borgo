extends Control
## Prova battaglia (dal menu principale): si sceglie il nemico e quanti uomini ha ciascuno,
## poi si combatte sul campo a esagoni. Non serve una partita e non la cambia: utile per
## provare le battaglie senza dover far crescere il borgo.

const PERGAMENA := Color("1b1f26")  # sfondo scuro, come l'interfaccia
const INCHIOSTRO := Color("3b2a1e")
const NEMICI := [["signore", "Un signore (cavalieri e balestrieri)"], ["banditi", "Un covo di banditi (predoni)"],
	["libera", "Una terra libera (contadini armati)"]]
## [chiave, nome, minimo, massimo, passo]
const VALORI := [["fanti", "Lancieri", 0, 40, 5], ["arcieri", "Arcieri", 0, 30, 5], ["balestrieri", "Balestrieri", 0, 30, 5],
	["cavalieri", "Cavalieri", 0, 30, 5], ["armi", "Armi (lancieri armati)", 0, 40, 5],
	["vassalli", "Uomini dei vassalli", 0, 30, 5], ["nemici", "Uomini del nemico", 5, 60, 5]]

var _p: Dictionary
var _numeri: Dictionary = {}  # chiave -> Label
var _nemico: Dictionary = {}  # tipo -> Button


func _ready() -> void:
	GameState.nel_feudo = false
	Audio.musica("battaglia")
	_p = GameState.prova_battaglia.duplicate()
	for v in VALORI:
		if not _p.has(v[0]):
			_p[v[0]] = v[2]
	theme = Hud.crea_tema()
	var sfondo := ColorRect.new()
	sfondo.color = PERGAMENA
	sfondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sfondo)
	var pannello := PanelContainer.new()
	pannello.set_anchors_preset(Control.PRESET_CENTER)
	pannello.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pannello.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(pannello)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	pannello.add_child(col)
	var titolo := Label.new()
	titolo.text = "Prova battaglia"
	titolo.add_theme_font_size_override("font_size", 14)
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titolo)
	var nota := Label.new()
	nota.text = "Scegli i due eserciti e combatti sul campo a esagoni. Non serve una partita e non la cambia."
	nota.add_theme_font_size_override("font_size", 7)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 300
	col.add_child(nota)

	var l := Label.new()
	l.text = "Contro chi:"
	col.add_child(l)
	var riga_n := HBoxContainer.new()
	col.add_child(riga_n)
	for n in NEMICI:
		var b := Button.new()
		b.text = n[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 7)
		b.pressed.connect(func(): _p.nemico = n[0]; _aggiorna())
		riga_n.add_child(b)
		_nemico[n[0]] = b

	for v in VALORI:
		var riga := HBoxContainer.new()
		col.add_child(riga)
		var nome := Label.new()
		nome.text = v[1]
		nome.custom_minimum_size.x = 150
		riga.add_child(nome)
		var meno := _piccolo("−")
		meno.pressed.connect(func(): _cambia(v, -1))
		riga.add_child(meno)
		var numero := Label.new()
		numero.custom_minimum_size.x = 30
		numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		riga.add_child(numero)
		_numeri[v[0]] = numero
		var piu := _piccolo("+")
		piu.pressed.connect(func(): _cambia(v, 1))
		riga.add_child(piu)

	var sotto := HBoxContainer.new()
	sotto.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(sotto)
	var combatti := Button.new()
	combatti.text = "Combatti!"
	combatti.custom_minimum_size = Vector2(110, 24)
	combatti.focus_mode = Control.FOCUS_NONE
	combatti.pressed.connect(_combatti)
	sotto.add_child(combatti)
	var menu := Button.new()
	menu.text = "Torna al menu"
	menu.custom_minimum_size = Vector2(90, 24)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	sotto.add_child(menu)
	_aggiorna()


func _piccolo(testo: String) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(22, 18)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _cambia(v: Array, verso: int) -> void:
	_p[v[0]] = clampi(int(_p[v[0]]) + verso * int(v[4]), int(v[2]), int(v[3]))
	_aggiorna()


func _aggiorna() -> void:
	for k in _nemico:
		_nemico[k].set_pressed_no_signal(k == _p.nemico)
	for k in _numeri:
		_numeri[k].text = str(int(_p[k]))


func _combatti() -> void:
	if int(_p.fanti) + int(_p.arcieri) + int(_p.balestrieri) + int(_p.cavalieri) <= 0:
		_p.fanti = 5  # almeno qualcuno deve combattere
	GameState.inizia_prova_battaglia(_p)
	get_tree().change_scene_to_file("res://scenes/battaglia.tscn")
