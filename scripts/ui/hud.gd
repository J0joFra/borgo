class_name Hud
extends CanvasLayer
## Interfaccia: barra delle risorse, menu di costruzione ai lati,
## pannello contestuale in basso, finestra Info e fine partita.
## Costruita in codice per ora; quando ci sarà la grafica vera si può rifare nell'editor.
## Le misure sono in pixel di una base 480×270, scalata sullo schermo vero.

signal costruisci(tipo: String)
signal conferma_piazzamento
signal annulla_piazzamento
signal cambia_lavoratori(id: int, delta: int)
signal demolisci(id: int)
signal migliora(id: int)
signal coltura(id: int, nome: String)
signal strade
signal rimuovi_strada
signal chiudi_pannello
signal ruota(direzione: int)
signal vai_al_regno
signal nuova_partita

const CATEGORIE := [["Case", "case"], ["Risorse", "risorse"], ["Cibo", "cibo"], ["Servizi", "servizi"], ["Difese", "difese"]]
const COLORI := {
	"legna": Color("8b5a2b"), "pietra": Color("9a9a9a"), "cibo": Color("c0392b"), "grano": Color("e0b84a"),
	"orzo": Color("d8c070"), "rape": Color("8a5a9a"),
	"ferro": Color("4a5568"), "utensili": Color("c8ccd0"), "oro": Color("e5b53a"),
	"abitanti": Color("e8c39e"), "felicita": Color("f2d24b"),
}
const NOMI_RISORSE := {
	"legna": "Legna", "pietra": "Pietra", "cibo": "Cibo", "grano": "Grano", "orzo": "Orzo", "rape": "Rape",
	"semi_orzo": "Semi d'orzo", "semi_grano": "Semi di grano", "semi_rape": "Semi di rapa",
	"ferro": "Ferro", "utensili": "Utensili", "armi": "Armi", "oro": "Oro",
}
const TESTO := Color("f3e3c3")
const TESTO_ALLARME := Color("ff6b5b")

var _radice: Control
var _numeri: Dictionary = {}  # chiave -> Label nella barra in alto
var _icone: Dictionary = {}   # chiave -> icona nella barra in alto
var _mercato: PanelContainer
var _mercato_notizia: Label
var _mercato_righe: Dictionary = {}  # risorsa -> [scorta, tendenza, compra, vendi]
var _mercato_nota: Label
var _btn_colture: Dictionary = {}  # coltura -> Button
var _strada := ""  # "nuova" mentre si traccia una strada, "esistente" se ne è toccata una
var _strada_testo := ""
var _strada_valida := false
var _tempo: Label
var _velocita: Array[Button] = []
var _menu: PanelContainer
var _menu_lista: VBoxContainer
var _categoria_aperta := ""
var _pannello: PanelContainer
var _titolo: Label
var _dettagli: Label
var _btn_meno: Button
var _btn_piu: Button
var _btn_demolisci: Button
var _btn_migliora: Button
var _btn_ok: Button
var _btn_annulla: Button
var _btn_chiudi: Button
var _info: PanelContainer
var _info_testo: Label
var _consiglio: PanelContainer
var _consiglio_testo: Label
var _tasse: Array[Button] = []
var _avviso: Label
var _allarme: Label  # banditi in arrivo
var _tempo_avviso := 0.0
var _fine: PanelContainer
var _fine_titolo: Label
var _fine_testo: Label
var _carta: PanelContainer
var _carta_chi: Label
var _carta_titolo: Label
var _carta_testo: Label
var _carta_scelte: VBoxContainer

var _edificio := -1          # id mostrato nel pannello, -1 = nessuno
var _piazzamento := ""       # tipo in piazzamento, "" = nessuno
var _piazzamento_valido := false
var _stima_piazzamento := ""


func _ready() -> void:
	_radice = Control.new()
	_radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.theme = crea_tema()
	add_child(_radice)
	_crea_barra()
	_crea_lati()
	_crea_avviso()  # prima dei pannelli, così gli avvisi stanno sotto di loro
	_crea_allarme()
	_crea_menu()
	_crea_pannello()
	_crea_info()
	_crea_consiglio()
	_crea_mercato()
	_crea_carta()
	_crea_fine()
	GameState.evento.connect(_mostra_carta)
	GameState.changed.connect(_aggiorna)
	GameState.season_changed.connect(func(_s, _a): _aggiorna())
	GameState.message.connect(mostra_avviso)
	GameState.consiglio.connect(_nuovo_consiglio)
	GameState.game_ended.connect(_mostra_fine)
	_aggiorna()
	if not GameState.evento_attivo.is_empty():
		_mostra_carta(GameState.evento_attivo)


func _process(delta: float) -> void:
	if _tempo_avviso > 0.0:
		_tempo_avviso -= delta
		_avviso.modulate.a = clampf(_tempo_avviso, 0.0, 1.0)
	if _edificio >= 0 and _pannello.visible:
		var b := GameState.trova(_edificio)
		if not b.is_empty() and b.progresso < 1.0:
			_aggiorna_pannello()


# --- API usata da main.gd ----------------------------------------------------

func mostra_edificio(id: int) -> void:
	_strada = ""
	_edificio = id
	_piazzamento = ""
	_chiudi_menu()
	_aggiorna_pannello()


func mostra_piazzamento(tipo: String, valido: bool, stima := "") -> void:
	_strada = ""
	_piazzamento = tipo
	_piazzamento_valido = valido
	_stima_piazzamento = stima
	_edificio = -1
	_aggiorna_pannello()


## Mentre si traccia una strada: quante celle, quanta pietra, se si può.
func mostra_strada(testo: String, valido: bool) -> void:
	_strada = "nuova"
	_strada_testo = testo
	_strada_valida = valido
	_piazzamento = ""
	_edificio = -1
	_aggiorna_pannello()


## Una strada già fatta: si può togliere.
func mostra_strada_esistente() -> void:
	_strada = "esistente"
	_piazzamento = ""
	_edificio = -1
	_aggiorna_pannello()


func nascondi_pannello() -> void:
	_strada = ""
	_edificio = -1
	_piazzamento = ""
	_pannello.visible = false


func mostra_avviso(testo: String, durata := 3.5) -> void:
	_avviso.text = testo
	_tempo_avviso = durata
	_avviso.modulate.a = 1.0


# --- Costruzione dell'interfaccia --------------------------------------------

## Il tema in legno e pergamena di tutta l'interfaccia (usato anche dal prologo).
static func crea_tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	t.set_stylebox("panel", "PanelContainer", _riquadro(Color("3b2a1e"), Color("6b4a2e")))
	t.set_stylebox("normal", "Button", _riquadro(Color("7a5634"), Color("a0784a")))
	t.set_stylebox("hover", "Button", _riquadro(Color("8a6440"), Color("c09060")))
	t.set_stylebox("pressed", "Button", _riquadro(Color("5a3e24"), Color("f2d24b")))
	t.set_stylebox("hover_pressed", "Button", _riquadro(Color("5a3e24"), Color("f2d24b")))
	t.set_stylebox("disabled", "Button", _riquadro(Color("4a4038"), Color("5a5048")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for nome in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(nome, "Button", TESTO)
	t.set_color("font_disabled_color", "Button", Color("8a8070"))
	t.set_color("font_color", "Label", TESTO)
	t.set_constant("separation", "VBoxContainer", 2)
	t.set_constant("separation", "HBoxContainer", 3)
	return t


static func _riquadro(sfondo: Color, bordo: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = sfondo
	s.border_color = bordo
	s.set_border_width_all(1)
	s.set_content_margin_all(3)
	return s


func _bottone(testo: String, larghezza := 0, altezza := 16) -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(larghezza, altezza)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _icona(chiave: String, lato := 10.0) -> Control:
	var c := CenterContainer.new()
	c.add_child(IconaRisorsa.new(chiave, lato))
	return c


func _crea_barra() -> void:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_radice.add_child(barra)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 2)
	barra.add_child(riga)
	for chiave in GameState.RISORSE_VISIBILI + ["abitanti", "disponibili", "felicita"]:
		var icona := _icona(chiave)
		_icone[chiave] = icona
		riga.add_child(icona)
		var l := Label.new()
		l.custom_minimum_size.x = 18 if chiave != "abitanti" else 28
		l.tooltip_text = IconaRisorsa.NOMI.get(chiave, chiave)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		riga.add_child(l)
		_numeri[chiave] = l
	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(spazio)
	_tempo = Label.new()
	riga.add_child(_tempo)
	for i in 4:
		var b := _bottone(["||", "x1", "x2", "x3"][i], 14, 12)
		b.toggle_mode = true
		b.pressed.connect(_imposta_velocita.bind(i))
		riga.add_child(b)
		_velocita.append(b)


func _crea_lati() -> void:
	var sinistra := VBoxContainer.new()
	sinistra.position = Vector2(4, 24)
	_radice.add_child(sinistra)
	for c in CATEGORIE:
		var b := _bottone(c[0], 46, 30)
		b.pressed.connect(_apri_categoria.bind(c[1]))
		sinistra.add_child(b)
	var strada := _bottone("Strade", 46, 30)
	strada.pressed.connect(func(): _chiudi_menu(); strade.emit())
	sinistra.add_child(strada)

	var destra := VBoxContainer.new()
	destra.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	destra.offset_left = -50
	destra.offset_right = -4
	destra.offset_top = 24
	_radice.add_child(destra)
	var regno := _bottone("Regno", 46, 30)
	regno.pressed.connect(func(): vai_al_regno.emit())
	destra.add_child(regno)
	var info := _bottone("Info", 46, 30)
	info.pressed.connect(func(): _info.visible = not _info.visible; _consiglio.visible = false; _aggiorna())
	destra.add_child(info)
	var consiglio := _bottone("Consiglio", 46, 30)
	consiglio.pressed.connect(func(): _consiglio.visible = not _consiglio.visible; _info.visible = false; _aggiorna())
	destra.add_child(consiglio)
	var mercato := _bottone("Mercato", 46, 30)
	mercato.pressed.connect(func(): _mercato.visible = not _mercato.visible; _info.visible = false; _consiglio.visible = false; _aggiorna())
	destra.add_child(mercato)
	var giro := HBoxContainer.new()
	giro.add_theme_constant_override("separation", 2)
	destra.add_child(giro)
	for verso in [-1, 1]:
		var b := _bottone("<" if verso < 0 else ">", 22, 30)
		b.pressed.connect(func(): ruota.emit(verso))
		giro.add_child(b)


func _crea_menu() -> void:
	_menu = PanelContainer.new()
	_menu.position = Vector2(54, 24)
	_menu.visible = false
	_radice.add_child(_menu)
	_menu_lista = VBoxContainer.new()
	_menu.add_child(_menu_lista)


func _crea_pannello() -> void:
	_pannello = PanelContainer.new()
	_pannello.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_pannello.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pannello.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pannello.offset_left = -160
	_pannello.offset_right = 160
	_pannello.offset_top = -56
	_pannello.offset_bottom = -4
	_pannello.visible = false
	_radice.add_child(_pannello)
	var colonna := VBoxContainer.new()
	_pannello.add_child(colonna)
	var sopra := HBoxContainer.new()
	colonna.add_child(sopra)
	var testi := VBoxContainer.new()
	testi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sopra.add_child(testi)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_END
	colonna.add_child(riga)
	_titolo = Label.new()
	testi.add_child(_titolo)
	_dettagli = Label.new()
	_dettagli.modulate = Color(1, 1, 1, 0.8)
	_dettagli.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dettagli.custom_minimum_size.x = 280
	testi.add_child(_dettagli)
	_btn_meno = _bottone("-", 18, 18)
	_btn_meno.pressed.connect(func(): cambia_lavoratori.emit(_edificio, -1))
	_btn_piu = _bottone("+", 18, 18)
	_btn_piu.pressed.connect(func(): cambia_lavoratori.emit(_edificio, 1))
	_btn_demolisci = _bottone("Demolisci", 0, 18)
	_btn_demolisci.pressed.connect(func():
		if _strada == "esistente":
			rimuovi_strada.emit()
		else:
			demolisci.emit(_edificio))
	_btn_migliora = _bottone("Migliora", 0, 18)
	_btn_migliora.pressed.connect(func(): migliora.emit(_edificio))
	_btn_ok = _bottone("Costruisci", 0, 18)
	_btn_ok.pressed.connect(func(): conferma_piazzamento.emit())
	_btn_annulla = _bottone("Annulla", 0, 18)
	_btn_annulla.pressed.connect(func(): annulla_piazzamento.emit())
	_btn_chiudi = _bottone("X", 18, 18)
	_btn_chiudi.pressed.connect(func(): chiudi_pannello.emit())
	_btn_chiudi.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sopra.add_child(_btn_chiudi)
	for nome in GameState.nomi_colture():
		var bc := _bottone(GameState.colture[nome].nome, 0, 18)
		bc.toggle_mode = true
		bc.pressed.connect(func(): coltura.emit(_edificio, nome))
		_btn_colture[nome] = bc
		riga.add_child(bc)
	for b in [_btn_meno, _btn_piu, _btn_migliora, _btn_demolisci, _btn_ok, _btn_annulla]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		riga.add_child(b)


func _crea_info() -> void:
	_info = PanelContainer.new()
	_info.set_anchors_preset(Control.PRESET_CENTER)
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.grow_vertical = Control.GROW_DIRECTION_BOTH
	_info.visible = false
	_radice.add_child(_info)
	var col := VBoxContainer.new()
	_info.add_child(col)
	_info_testo = Label.new()
	col.add_child(_info_testo)
	var riga := HBoxContainer.new()
	col.add_child(riga)
	var l := Label.new()
	l.text = "Tasse:"
	riga.add_child(l)
	for livello in ["basse", "normali", "alte"]:
		var b := _bottone(livello.capitalize(), 40)
		b.toggle_mode = true
		b.pressed.connect(func(): GameState.tasse = livello; _aggiorna())
		riga.add_child(b)
		_tasse.append(b)
	var legenda := HBoxContainer.new()
	col.add_child(legenda)
	for chiave in GameState.RISORSE_VISIBILI + ["abitanti", "disponibili", "felicita"]:
		legenda.add_child(_icona(chiave, 8.0))
		var n := Label.new()
		n.text = IconaRisorsa.NOMI.get(chiave, chiave).split(" ")[0].to_lower()
		legenda.add_child(n)
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _info.visible = false)
	col.add_child(chiudi)


func _crea_consiglio() -> void:
	_consiglio = PanelContainer.new()
	_consiglio.set_anchors_preset(Control.PRESET_CENTER)
	_consiglio.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_consiglio.grow_vertical = Control.GROW_DIRECTION_BOTH
	_consiglio.visible = false
	_radice.add_child(_consiglio)
	var col := VBoxContainer.new()
	_consiglio.add_child(col)
	_consiglio_testo = Label.new()
	_consiglio_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consiglio_testo.custom_minimum_size.x = 320
	col.add_child(_consiglio_testo)
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _consiglio.visible = false)
	col.add_child(chiudi)


func _aggiorna_consiglio() -> void:
	if GameState.capo < 0:
		_consiglio_testo.text = "Il consiglio si riunirà quando avrai scelto chi guida."
		return
	var guida: Dictionary = GameState.famiglie[GameState.capo]
	var righe: Array[String] = []
	righe.append("Guida: %s, casata %s (%s: %s)" % [guida.capo, guida.casata,
		GameState.tratto(GameState.capo).get("nome", ""), GameState.tratto(GameState.capo).get("descrizione", "")])
	for i in GameState.consiglieri():
		var f: Dictionary = GameState.famiglie[i]
		righe.append("")
		righe.append("%s, casata %s (%s)" % [f.capo, f.casata, GameState.tratto(i).get("nome", "").to_lower()])
		righe.append("   " + Consiglio.per(i))
	righe.append("")
	righe.append("Quando conquisterai nuove terre potrai nominare i consiglieri tuoi vassalli.")
	_consiglio_testo.text = "\n".join(righe)


func _crea_mercato() -> void:
	_mercato = PanelContainer.new()
	_mercato.set_anchors_preset(Control.PRESET_CENTER)
	_mercato.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mercato.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mercato.visible = false
	_radice.add_child(_mercato)
	var col := VBoxContainer.new()
	_mercato.add_child(col)
	_mercato_notizia = Label.new()
	_mercato_notizia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mercato_notizia.custom_minimum_size.x = 330
	col.add_child(_mercato_notizia)
	var griglia := GridContainer.new()
	griglia.columns = 6
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 1)
	col.add_child(griglia)
	for r in GameState.mercato.risorse() if GameState.mercato else []:
		griglia.add_child(_icona(r, 9.0))
		var nome := Label.new()
		nome.text = NOMI_RISORSE.get(r, r)
		nome.custom_minimum_size.x = 64
		griglia.add_child(nome)
		var scorta := Label.new()
		scorta.custom_minimum_size.x = 28
		griglia.add_child(scorta)
		var tendenza := Label.new()
		tendenza.custom_minimum_size.x = 30
		griglia.add_child(tendenza)
		var compra := _bottone("", 100, 14)
		compra.pressed.connect(func(): GameState.compra(r))
		griglia.add_child(compra)
		var vendi := _bottone("", 100, 14)
		vendi.pressed.connect(func(): GameState.vendi(r))
		griglia.add_child(vendi)
		_mercato_righe[r] = [scorta, tendenza, compra, vendi]
	_mercato_nota = Label.new()
	_mercato_nota.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_mercato_nota)
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _mercato.visible = false)
	col.add_child(chiudi)


func _aggiorna_mercato() -> void:
	var m := GameState.mercato
	_mercato_notizia.text = "Mercato del regno · %s" % m.notizia()
	var lotto := m.lotto()
	for r in _mercato_righe:
		var riga: Array = _mercato_righe[r]
		riga[0].text = str(int(GameState.risorse.get(r, 0.0)))
		var t := m.tendenza(r, GameState.stagione)
		riga[1].text = "sale" if t > 0 else ("scende" if t < 0 else "")
		riga[1].add_theme_color_override("font_color", TESTO_ALLARME if t > 0 else Color("9fd18b"))
		var costo := GameState.costo_lotto(r)
		var ricavo := GameState.ricavo_lotto(r)
		riga[2].text = "Compra %d · %d oro" % [lotto, costo]
		riga[2].disabled = GameState.risorse.oro < costo or GameState.risorse[r] + lotto > GameState.capacita()
		riga[3].text = "Vendi %d · %d oro" % [lotto, ricavo]
		riga[3].disabled = GameState.risorse[r] < lotto
	_mercato_nota.text = "Hai %d oro. Con un mercato costruito si compra e si vende a prezzi migliori." % int(GameState.risorse.oro) \
		if not GameState.ha_mercato() else "Hai %d oro. Il tuo mercato ti fa avere prezzi migliori." % int(GameState.risorse.oro)


func _nuovo_consiglio(famiglia: int, testo: String) -> void:
	mostra_avviso("%s: %s" % [GameState.famiglie[famiglia].capo, testo], 7.0)


func _crea_avviso() -> void:
	_avviso = Label.new()
	_avviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_avviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_avviso.offset_top = 22
	_avviso.offset_left = -170
	_avviso.offset_right = 170
	_avviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_avviso.add_theme_constant_override("outline_size", 3)
	_avviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avviso.modulate.a = 0.0
	_radice.add_child(_avviso)


func _crea_allarme() -> void:
	_allarme = Label.new()
	_allarme.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_allarme.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_allarme.offset_top = 46
	_allarme.offset_left = -170
	_allarme.offset_right = 170
	_allarme.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_allarme.add_theme_color_override("font_color", Color("ffb0a0"))
	_allarme.add_theme_color_override("font_outline_color", Color("3a0a08"))
	_allarme.add_theme_constant_override("outline_size", 3)
	_allarme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_allarme.visible = false
	_radice.add_child(_allarme)


func _crea_fine() -> void:
	_fine = PanelContainer.new()
	_fine.set_anchors_preset(Control.PRESET_CENTER)
	_fine.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fine.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fine.visible = false
	_radice.add_child(_fine)
	var col := VBoxContainer.new()
	_fine.add_child(col)
	_fine_titolo = Label.new()
	_fine_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fine_titolo)
	_fine_testo = Label.new()
	_fine_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fine_testo)
	var b := _bottone("Nuova partita", 0, 20)
	b.pressed.connect(func(): nuova_partita.emit())
	col.add_child(b)


# --- Aggiornamenti -----------------------------------------------------------

func _aggiorna() -> void:
	var tps: float = GameState.bil.tick_per_stagione
	for r in GameState.RISORSE_VISIBILI:
		var mostra := _da_mostrare(r)
		_numeri[r].visible = mostra
		_icone[r].visible = mostra
		var valore: float = GameState.risorse.get(r, 0.0)
		var delta: float = GameState.ultimo_delta.get(r, 0.0)
		_numeri[r].text = str(int(valore))
		# Rosso se al ritmo attuale la risorsa finisce entro 2 stagioni.
		var allarme := delta < 0.0 and valore / -delta < 2.0 * tps
		if r == "cibo" and GameState.tick_fame > 0:
			allarme = true
		_numeri[r].add_theme_color_override("font_color", TESTO_ALLARME if allarme else TESTO)
	_numeri.abitanti.text = "%d/%d" % [GameState.abitanti, GameState.alloggi()]
	_numeri.abitanti.add_theme_color_override("font_color", TESTO_ALLARME if GameState.senza_casa() > 0 else TESTO)
	_numeri.disponibili.text = str(GameState.disoccupati())
	_numeri.felicita.text = str(int(GameState.felicita))
	_allarme.visible = not GameState.banditi.is_empty()
	if _allarme.visible:
		var dif: Dictionary = GameState.difesa()
		_allarme.text = "Banditi da %s tra %d giorni · loro %d, noi %d" % [GameState.banditi.da, int(GameState.banditi.mancano),
			roundi(GameState.banditi.forza), roundi(dif.totale)]
	_numeri.felicita.add_theme_color_override("font_color", TESTO_ALLARME if GameState.felicita < 35.0 else TESTO)
	(_icone.felicita.get_child(0) as IconaRisorsa).imposta_valore(GameState.felicita)
	_tempo.text = "%s, anno %d" % [GameState.STAGIONI[GameState.stagione], GameState.anno]
	for i in _velocita.size():
		_velocita[i].set_pressed_no_signal(i == GameState.velocita)
	if GameState.evento_attivo.is_empty():
		_carta.visible = false
	if _pannello.visible:
		_aggiorna_pannello()
	if _menu.visible:
		_riempi_menu()
	if _info.visible:
		_aggiorna_info()
	if _consiglio.visible:
		_aggiorna_consiglio()
	if _mercato.visible:
		_aggiorna_mercato()


## Nella barra in alto solo ciò che conta adesso: le risorse di base sempre,
## i raccolti se ne hai o li coltivi, ferro e attrezzi dal Borgo in poi.
func _da_mostrare(r: String) -> bool:
	if r in ["legna", "pietra", "cibo", "oro"]:
		return true
	if GameState.risorse.get(r, 0.0) >= 1.0:
		return true
	# ferro, utensili, armi e raccolti: solo se c'è chi li produce o li usa
	for b in GameState.buildings:
		var d: Dictionary = GameState.edifici[b.tipo]
		if GameState.coltura_di(b).get("risorsa", "") == r or d.get("produce", {}).has(r) or d.get("consuma", {}).has(r):
			return true
		if r == "armi" and d.has("difesa_per_guardia"):
			return true
	return false


func _imposta_velocita(v: int) -> void:
	if not GameState.evento_attivo.is_empty():
		_aggiorna()
		return  # finché la carta è aperta il tempo resta fermo
	GameState.velocita = v
	_aggiorna()


func _apri_categoria(categoria: String) -> void:
	if _menu.visible and _categoria_aperta == categoria:
		_chiudi_menu()
		return
	_categoria_aperta = categoria
	_menu.visible = true
	_riempi_menu()


func _chiudi_menu() -> void:
	_menu.visible = false
	_categoria_aperta = ""


func _riempi_menu() -> void:
	# Aggiorna i bottoni esistenti invece di ricrearli, così un tocco in corso non si perde.
	var tipi: Array[String] = []
	for tipo in GameState.edifici:
		if GameState.edifici[tipo].categoria == _categoria_aperta:
			tipi.append(tipo)
	while _menu_lista.get_child_count() < tipi.size():
		var b := _bottone("", 150, 16)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_scegli_dal_menu.bind(b))
		_menu_lista.add_child(b)
	for i in _menu_lista.get_child_count():
		var b: Button = _menu_lista.get_child(i)
		b.visible = i < tipi.size()
		if not b.visible:
			continue
		var tipo := tipi[i]
		var d: Dictionary = GameState.edifici[tipo]
		b.set_meta("tipo", tipo)
		if GameState.sbloccato(tipo):
			b.text = "%s  ·  %s" % [d.nome, GameState.testo_costo(tipo)]
			b.disabled = not GameState.puo_permettersi(tipo)
		else:
			b.text = "%s  (serve %s)" % [d.nome, GameState.bil.livelli[int(d.livello)].nome]
			b.disabled = true


func _scegli_dal_menu(b: Button) -> void:
	_chiudi_menu()
	costruisci.emit(b.get_meta("tipo"))


func _aggiorna_pannello() -> void:
	for x in [_btn_meno, _btn_piu, _btn_migliora, _btn_demolisci, _btn_ok, _btn_annulla, _btn_chiudi] + _btn_colture.values():
		x.visible = false
	if _strada != "":
		_pannello.visible = true
		_titolo.text = "Strada"
		if _strada == "esistente":
			_dettagli.text = "La gente cammina lungo le strade. Gli edifici che toccano una strada collegata alla piazza non hanno il ritardo del 2%."
			_btn_demolisci.text = "Rimuovi"
			_btn_demolisci.visible = true
			_btn_chiudi.visible = true
		else:
			_dettagli.text = _strada_testo
			_btn_ok.visible = true
			_btn_ok.disabled = not _strada_valida
			_btn_annulla.visible = true
		return
	_btn_demolisci.text = "Demolisci"
	if _piazzamento != "":
		var d: Dictionary = GameState.edifici[_piazzamento]
		_titolo.text = "%s  ·  %s" % [d.nome, GameState.testo_costo(_piazzamento)]
		_dettagli.text = GameState.testo_effetto(_piazzamento) if _piazzamento_valido else "Posizione non valida: tocca un'altra zona"
		if _piazzamento_valido and _stima_piazzamento != "":
			_dettagli.text = _stima_piazzamento
		_btn_ok.visible = true
		_btn_ok.disabled = not (_piazzamento_valido and GameState.puo_permettersi(_piazzamento))
		_btn_annulla.visible = true
		_pannello.visible = true
		return
	var b := GameState.trova(_edificio)
	if b.is_empty():
		nascondi_pannello()
		return
	var d := GameState.def_di(b)
	_pannello.visible = true
	_btn_demolisci.visible = not d.get("fisso", false)
	_btn_chiudi.visible = true
	if b.progresso < 1.0:
		_titolo.text = "%s  ·  in costruzione %d%%" % [d.nome, int(b.progresso * 100)]
		_dettagli.text = GameState.testo_effetto(b.tipo)
		return
	var testo := GameState.testo_effetto(b.tipo)
	var stima := GameState.stima_produzione(b.tipo, b.cella, int(b.get("livello", 1)))
	if stima != "":
		testo = stima
	if d.get("coltura", false):
		testo = GameState.stima_produzione(b.tipo, b.cella, int(b.get("livello", 1)), b.get("coltura", ""))
		testo += "\n" + _stato_campo(b)
		for nome in _btn_colture:
			_btn_colture[nome].visible = true
			_btn_colture[nome].set_pressed_no_signal(nome == b.get("coltura", ""))
	var prossimo := GameState.prossimo_miglioramento(b)
	if not prossimo.is_empty():
		_btn_migliora.visible = true
		_btn_migliora.text = "Migliora (%s)" % GameState._elenco(prossimo.costo)
		_btn_migliora.disabled = not GameState.puo_migliorare(b)
		testo += "\nProssimo livello: %s" % prossimo.nome
	if d.has("difesa_per_guardia"):
		testo = "Ogni guardia vale %d di difesa (x%.1f con le armi); avvista i banditi prima: più giorni per prepararsi" % [int(d.difesa_per_guardia), float(GameState.bil.banditi.bonus_armi)]
	elif d.has("difesa"):
		testo = "Difesa +%.1f contro i banditi" % float(d.difesa)
	elif b.tipo == "rovine":
		testo = "Bruciato dai banditi. Demolisci per sgomberare le rovine."
	if int(d.lavoratori) > 0 and not GameState.collegato(b):
		testo += "\nNon collegato alla piazza: -%d%% di lavoro (serve una strada che lo tocchi)" % roundi(float(GameState.bil.strade.malus_non_collegato) * 100)
	var durata := int(GameState.edifici[b.tipo].get("durata_stagioni", 0))
	if durata > 0:
		testo += "\nRegge una stagione: si strappa a fine %s. Costruisci case vere." % GameState.STAGIONI[(GameState.stagione + maxi(0, durata - 1 - int(b.get("eta", 0)))) % 4].to_lower()
	_titolo.text = d.nome
	if int(d.lavoratori) > 0:
		_titolo.text += "  ·  %d/%d lavoratori" % [b.lavoratori, d.lavoratori]
		_btn_meno.visible = true
		_btn_meno.disabled = b.lavoratori == 0
		_btn_piu.visible = true
		_btn_piu.disabled = b.lavoratori >= int(d.lavoratori) or GameState.disoccupati() == 0
	_dettagli.text = testo


func _stato_campo(b: Dictionary) -> String:
	var c := GameState.coltura_di(b)
	if c.is_empty():
		return ""
	if b.get("seminato", false):
		return "Seminato a %s: si raccoglie a fine %s." % [c.nome.to_lower(), c.stagioni[c.stagioni.size() - 1]]
	if b.get("senza_semi", false):
		return "Fermo: mancano i semi di %s (si comprano al mercato)." % c.nome.to_lower()
	return "Si semina all'inizio della %s." % c.stagioni[0]


func _aggiorna_info() -> void:
	var righe: Array[String] = []
	var livelli: Array = GameState.bil.livelli
	righe.append("Livello: %s" % livelli[GameState.livello].nome)
	if GameState.livello + 1 < livelli.size():
		var manca := GameState.requisiti_mancanti(GameState.livello + 1)
		righe.append("Per diventare %s servono: %s" % [livelli[GameState.livello + 1].nome, ", ".join(manca)])
	righe.append("Abitanti %d (alloggi %d) · al lavoro %d · disoccupati %d" % [
		GameState.abitanti, GameState.alloggi(), GameState.lavoratori_assegnati(), GameState.disoccupati()])
	if GameState.senza_casa() > 0:
		righe.append("Senza casa: %d · se ne vanno tra %d giorni se non trovano un tetto" % [GameState.senza_casa(),
			maxi(1, int(GameState.bil.senza_casa.tick_prima_di_andarsene) - GameState.tick_senza_casa)])
	if not GameState.modificatori.is_empty():
		var effetti: Array[String] = []
		for m in GameState.modificatori:
			effetti.append("%s (%d stagion%s)" % [_testo_modificatore(m), int(m.stagioni), "e" if int(m.stagioni) == 1 else "i"])
		righe.append("Effetti in corso: " + ", ".join(effetti))
	var fattori := GameState.fattori_felicita()
	var voci: Array[String] = []
	for k in fattori:
		voci.append("%s %+d" % [k, fattori[k]])
	righe.append("Felicità %d → %s" % [int(GameState.felicita), ", ".join(voci)])
	righe.append("Nuovi arrivi: attrattiva %d%% (felicità sopra %d e scorte abbondanti, posti liberi %d)" % [
		int(GameState.calcola_attrattiva() * 100), int(GameState.bil.crescita.soglia_arrivi), maxi(0, GameState.alloggi() - GameState.abitanti)])
	var v := GameState.valutazione_tasse()
	righe.append("Tasse a fine stagione: %d oro, fascia %s (risorse %d%%, popolazione %d%%, gradimento %d%%)" % [v.monete,
		GameState.NOMI_FASCE[v.fascia], roundi(v.risorse * 100), roundi(v.popolazione * 100), roundi(v.gradimento * 100)])
	righe.append("Tassa al re in autunno: %d oro · capacità magazzino %d" % [GameState.tassa_del_re(), GameState.capacita()])
	var dif := GameState.difesa()
	righe.append("Difesa %d: milizia %d, guardie %d (forza %d), palizzate %d%s" % [roundi(dif.totale), roundi(dif.milizia),
		dif.guardie, roundi(dif.forza_guardie), roundi(dif.palizzate),
		"" if GameState.banditi_possibili() else " · i banditi arriveranno quando saremo un Borgo"])
	_info_testo.text = "\n".join(righe)
	for i in _tasse.size():
		_tasse[i].set_pressed_no_signal(["basse", "normali", "alte"][i] == GameState.tasse)


# --- Carte evento --------------------------------------------------------------

func _crea_carta() -> void:
	_carta = PanelContainer.new()
	_carta.set_anchors_preset(Control.PRESET_CENTER)
	_carta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_carta.grow_vertical = Control.GROW_DIRECTION_BOTH
	_carta.add_theme_stylebox_override("panel", _riquadro(Color("e9dcbc"), Color("6b4a2e")))
	_carta.visible = false
	_radice.add_child(_carta)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.custom_minimum_size.x = 260
	_carta.add_child(col)
	var inchiostro := Color("3b2a1e")
	_carta_chi = Label.new()
	_carta_chi.add_theme_color_override("font_color", Color("7a4a2a"))
	col.add_child(_carta_chi)
	_carta_titolo = Label.new()
	_carta_titolo.add_theme_font_size_override("font_size", 12)
	_carta_titolo.add_theme_color_override("font_color", inchiostro)
	col.add_child(_carta_titolo)
	_carta_testo = Label.new()
	_carta_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_carta_testo.add_theme_color_override("font_color", inchiostro)
	col.add_child(_carta_testo)
	_carta_scelte = VBoxContainer.new()
	col.add_child(_carta_scelte)


## Una carta evento: la racconta un consigliere, il tempo è fermo finché non si sceglie.
func _mostra_carta(carta: Dictionary) -> void:
	nascondi_pannello()
	_chiudi_menu()
	_info.visible = false
	_consiglio.visible = false
	_mercato.visible = false
	var n := int(carta.get("narratore", -1))
	if n >= 0:
		var f: Dictionary = GameState.famiglie[n]
		_carta_chi.text = "%s, del consiglio, racconta:" % f.capo
	else:
		_carta_chi.text = "Dal villaggio:"
	_carta_titolo.text = carta.titolo
	_carta_testo.text = "«%s»" % carta.testo
	for c in _carta_scelte.get_children():
		c.queue_free()
	for i in carta.scelte.size():
		var scelta: Dictionary = carta.scelte[i]
		var b := _bottone("", 0, 20)
		var effetti := _testo_effetti(scelta.effetti)
		b.text = scelta.testo if effetti == "" else "%s   (%s)" % [scelta.testo, effetti]
		b.disabled = not GameState.scelta_possibile(i)
		if b.disabled:
			b.text += " · non abbiamo abbastanza"
		b.pressed.connect(func():
			_carta.visible = false
			GameState.scegli_evento(i))
		_carta_scelte.add_child(b)
	_carta.visible = true
	_aggiorna()


func _testo_effetti(e: Dictionary) -> String:
	var parti: Array[String] = []
	var r: Dictionary = e.get("risorse", {})
	for k in r:
		parti.append("%+d %s" % [int(r[k]), NOMI_RISORSE.get(k, k).to_lower()])
	if e.has("abitanti"):
		parti.append("%+d abitanti" % int(e.abitanti))
	if e.has("felicita"):
		parti.append("%+d felicità" % int(e.felicita))
	if e.has("distruggi"):
		parti.append("perdiamo una %s" % GameState.edifici[e.distruggi].nome.to_lower())
	if e.has("modificatore"):
		var m: Dictionary = e.modificatore
		parti.append("%s per %d stagion%s" % [_testo_modificatore(m), int(m.stagioni), "e" if int(m.stagioni) == 1 else "i"])
	return ", ".join(parti)


func _testo_modificatore(m: Dictionary) -> String:
	if m.has("edificio"):
		return "%s %+d%%" % [GameState.edifici[m.edificio].nome.to_lower(), roundi((float(m.molt) - 1.0) * 100)]
	if m.has("coltura"):
		return "raccolti %+d%%" % roundi((float(m.molt) - 1.0) * 100)
	if m.has("riscaldamento"):
		return "legna per scaldarsi %+d%%" % roundi((float(m.riscaldamento) - 1.0) * 100)
	if m.has("tassa_re"):
		return "tassa del re %+d%%" % roundi((float(m.tassa_re) - 1.0) * 100)
	return ""


func _mostra_fine(vittoria: bool, motivo: String) -> void:
	_carta.visible = false
	nascondi_pannello()
	_chiudi_menu()
	_info.visible = false
	_consiglio.visible = false
	_fine_titolo.text = "Vittoria!" if vittoria else "Partita persa"
	_fine_testo.text = motivo
	_fine.visible = true
