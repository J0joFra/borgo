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
signal mura
signal ruota_edificio
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
var _esercito: PanelContainer
var _esercito_testo: Label
var _conferma_coltura: PanelContainer
var _conferma_testo: Label
var _coltura_scelta := ""
var _truppe_righe: Dictionary = {}  # tipo -> [numero, arruola, congeda]
var _mercato_notizia: Label
var _mercato_righe: Dictionary = {}  # risorsa -> [scorta, tendenza, compra, vendi]
var _mercato_nota: Label
var _mercato_manuale: GridContainer
var _mercato_auto: VBoxContainer
var _mercato_auto_righe: Dictionary = {}  # risorsa -> [scorta, vendi_sopra, compra_sotto]
var _riserva: Label
var _btn_auto: Button
var _btn_colture: Dictionary = {}  # coltura -> Button
var _strada := ""  # "nuova" mentre si traccia una strada, "esistente" se ne è toccata una
var _strada_testo := ""
var _strada_valida := false
var _strada_titolo := "Strada"  # anche le mura usano questo pannello
var _btn_ruota: Button
var _pulsanti: Dictionary = {}  # testo -> Button dei lati (il tutorial li fa lampeggiare)
var _tutorial: PanelContainer
var _tutorial_titolo: Label
var _tutorial_testo: Label
var _tutorial_avanti: Button
var _lampeggia: Tween
var _btn_suggerimenti: Button
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
	_crea_esercito()
	_crea_conferma_coltura()
	_crea_carta()
	_crea_tutorial()
	_crea_fine()
	GameState.evento.connect(_mostra_carta)
	GameState.tutorial_cambiato.connect(_mostra_tutorial)
	GameState.suggerimento.connect(func(t): mostra_avviso("Suggerimento: " + t, 8.0))
	GameState.changed.connect(_aggiorna)
	GameState.season_changed.connect(func(_s, _a): _aggiorna())
	GameState.message.connect(mostra_avviso)
	GameState.consiglio.connect(_nuovo_consiglio)
	GameState.game_ended.connect(_mostra_fine)
	_aggiorna()
	if not GameState.evento_attivo.is_empty():
		_mostra_carta(GameState.evento_attivo)
	_mostra_tutorial(GameState.tutorial_passo)


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
func mostra_strada(testo: String, valido: bool, titolo := "Strada") -> void:
	_strada = "nuova"
	_strada_titolo = titolo
	_strada_testo = testo
	_strada_valida = valido
	_piazzamento = ""
	_edificio = -1
	_aggiorna_pannello()


## Una strada già fatta: si può togliere.
func mostra_strada_esistente(titolo := "Strada") -> void:
	_strada = "esistente"
	_strada_titolo = titolo
	_piazzamento = ""
	_edificio = -1
	_aggiorna_pannello()


func nascondi_pannello() -> void:
	_strada = ""
	_edificio = -1
	_piazzamento = ""
	_pannello.visible = false
	_conferma_coltura.visible = false


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
	# la barra ha tante voci: un carattere un po' più piccolo perché ci stiano tutte
	var tema_barra := crea_tema()
	tema_barra.default_font_size = 7
	barra.theme = tema_barra
	_radice.add_child(barra)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", 2)
	barra.add_child(riga)
	for chiave in GameState.RISORSE_VISIBILI + ["re", "abitanti", "disponibili", "felicita"]:
		var icona := _icona(chiave)
		_icone[chiave] = icona
		riga.add_child(icona)
		var l := Label.new()
		l.custom_minimum_size.x = 16 if chiave != "abitanti" else 26
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
		_pulsanti[c[0]] = b
	var strada := _bottone("Strade", 46, 30)
	_pulsanti["Strade"] = strada
	strada.pressed.connect(func(): _chiudi_menu(); strade.emit())
	sinistra.add_child(strada)

	var destra := VBoxContainer.new()
	destra.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	destra.offset_left = -50
	destra.offset_right = -4
	destra.offset_top = 24
	_radice.add_child(destra)
	var regno := _bottone("Regno", 46, 30)
	_pulsanti["Regno"] = regno
	regno.pressed.connect(func(): vai_al_regno.emit())
	destra.add_child(regno)
	var info := _bottone("Info", 46, 30)
	_pulsanti["Info"] = info
	info.pressed.connect(func(): _apri_finestra(_info))
	destra.add_child(info)
	var consiglio := _bottone("Consiglio", 46, 30)
	_pulsanti["Consiglio"] = consiglio
	consiglio.pressed.connect(func(): _apri_finestra(_consiglio))
	destra.add_child(consiglio)
	var mercato := _bottone("Mercato", 46, 30)
	_pulsanti["Mercato"] = mercato
	mercato.pressed.connect(func(): _apri_finestra(_mercato))
	destra.add_child(mercato)
	var esercito := _bottone("Esercito", 46, 30)
	_pulsanti["Esercito"] = esercito
	esercito.pressed.connect(func(): _apri_finestra(_esercito))
	destra.add_child(esercito)
	var giro := HBoxContainer.new()
	giro.add_theme_constant_override("separation", 2)
	destra.add_child(giro)
	for verso in [-1, 1]:
		var b := _bottone("<" if verso < 0 else ">", 22, 30)
		b.pressed.connect(func(): ruota.emit(verso))
		giro.add_child(b)


## Apre una delle finestre centrali (chiudendo le altre), o la chiude se era già aperta.
func _apri_finestra(finestra: PanelContainer) -> void:
	var era := finestra.visible
	for f in [_info, _consiglio, _mercato, _esercito]:
		f.visible = false
	finestra.visible = not era
	_aggiorna()


## Cambiare coltura a un campo va confermato: si riparte dalla semina.
func _crea_conferma_coltura() -> void:
	_conferma_coltura = PanelContainer.new()
	_conferma_coltura.set_anchors_preset(Control.PRESET_CENTER)
	_conferma_coltura.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_conferma_coltura.grow_vertical = Control.GROW_DIRECTION_BOTH
	_conferma_coltura.visible = false
	_radice.add_child(_conferma_coltura)
	var col := VBoxContainer.new()
	_conferma_coltura.add_child(col)
	_conferma_testo = Label.new()
	_conferma_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conferma_testo.custom_minimum_size.x = 220
	col.add_child(_conferma_testo)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(riga)
	var si := _bottone("Sì, cambia", 70, 18)
	si.pressed.connect(func():
		_conferma_coltura.visible = false
		coltura.emit(_edificio, _coltura_scelta))
	riga.add_child(si)
	var no := _bottone("No", 50, 18)
	no.pressed.connect(func():
		_conferma_coltura.visible = false
		_aggiorna())
	riga.add_child(no)


func _chiedi_coltura(nome: String) -> void:
	var b := GameState.trova(_edificio)
	if b.is_empty():
		return
	var adesso: String = b.get("coltura", "")
	if adesso == nome:
		_aggiorna()
		return
	_coltura_scelta = nome
	var testo := "Coltivare %s in questo campo?" % GameState.colture[nome].nome.to_lower()
	if adesso != "":
		testo = "Cambiare la coltura da %s a %s?" % [GameState.colture[adesso].nome.to_lower(), GameState.colture[nome].nome.to_lower()]
		if b.get("seminato", false):
			testo += "\nIl campo è già seminato: il raccolto in corso andrà perso."
	_conferma_testo.text = testo
	_conferma_coltura.visible = true
	_aggiorna()


func _crea_esercito() -> void:
	_esercito = PanelContainer.new()
	_esercito.set_anchors_preset(Control.PRESET_CENTER)
	_esercito.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_esercito.grow_vertical = Control.GROW_DIRECTION_BOTH
	_esercito.visible = false
	_radice.add_child(_esercito)
	var col := VBoxContainer.new()
	_esercito.add_child(col)
	_esercito_testo = Label.new()
	_esercito_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_esercito_testo.custom_minimum_size.x = 300
	col.add_child(_esercito_testo)
	# Una riga per tipo di soldato: quali si possono arruolare dipende dall'armeria.
	var griglia := GridContainer.new()
	griglia.columns = 4
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 1)
	col.add_child(griglia)
	for tipo in GameState.TIPI_SOLDATI:
		var nome := Label.new()
		nome.text = GameState.bil.battaglia.unita[tipo].nome
		nome.custom_minimum_size.x = 64
		griglia.add_child(nome)
		var numero := Label.new()
		numero.custom_minimum_size.x = 40
		griglia.add_child(numero)
		var arruola := _bottone("", 0, 15)
		arruola.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arruola.pressed.connect(func(): GameState.arruola(tipo))
		griglia.add_child(arruola)
		var congeda := _bottone("Congeda", 0, 15)
		congeda.pressed.connect(func(): GameState.congeda(tipo))
		griglia.add_child(congeda)
		_truppe_righe[tipo] = [numero, arruola, congeda]
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _esercito.visible = false)
	col.add_child(chiudi)


func _aggiorna_esercito() -> void:
	var e: Dictionary = GameState.bil.esercito
	var righe: Array[String] = []
	righe.append("Soldati: %d (%d formazioni su %d posti in caserma) · a casa %d, in marcia %d" % [GameState.soldati,
		GameState.formazioni(), GameState.formazioni_massime(), GameState.soldati_presenti(), GameState.soldati_in_marcia()])
	righe.append("Ogni formazione è di %d persone senza lavoro e mangia %d cibo al mese: ora %d cibo al mese (%d a stagione)." % [
		int(e.per_formazione), int(e.tipi.fanti.cibo_al_mese), GameState.cibo_esercito_al_mese(), GameState.cibo_esercito_al_mese() * int(e.mesi_per_stagione)])
	righe.append("In difesa ogni soldato vale %d (x%.1f con le armi); in attacco l'esercito vale %d." % [int(e.difesa_per_soldato),
		float(GameState.bil.banditi.bonus_armi), roundi(GameState.forza_esercito(GameState.soldati_presenti()))])
	for m in GameState.missioni:
		var r: Dictionary = GameState.regni[m.regione]
		var cosa: String = {"spia": "Spia verso", "alleanza": "Messaggero verso", "attacco": "Esercito (%d) in marcia su" % int(m.get("soldati", 0))}[m.tipo]
		righe.append("%s %s: %d giorni" % [cosa, r.nome, int(m.mancano)])
	if not GameState.diplomazia_possibile():
		righe.append("Dal Borgo in poi, sulla mappa del Regno, si mandano spie, si cercano alleanze e si attacca.")
	else:
		righe.append("Spie, alleanze e attacchi: tocca \"Regno\" e poi una regione sulla mappa.")
	_esercito_testo.text = "\n".join(righe)
	var presenti := GameState.truppe_presenti()
	for tipo in _truppe_righe:
		var celle: Array = _truppe_righe[tipo]
		var t: Dictionary = e.tipi[tipo]
		celle[0].text = "%d (%d)" % [int(GameState.truppe.get(tipo, 0)), int(presenti.get(tipo, 0))]
		var perche := GameState.perche_non_arruolare(tipo)
		var costo: Array[String] = []
		for r in t.costo:
			costo.append("%d %s" % [int(t.costo[r]), r])
		var testo := "Arruola %d" % int(e.per_formazione)
		if perche != "":
			testo += " (%s)" % perche
		elif not costo.is_empty():
			testo += " (%s)" % ", ".join(costo)
		celle[1].text = testo
		celle[1].disabled = perche != ""
		celle[2].disabled = int(presenti.get(tipo, 0)) <= 0


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
	_btn_ruota = _bottone("Ruota", 0, 18)
	_btn_ruota.pressed.connect(func(): ruota_edificio.emit())
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
		bc.pressed.connect(_chiedi_coltura.bind(nome))
		_btn_colture[nome] = bc
		riga.add_child(bc)
	for b in [_btn_meno, _btn_piu, _btn_migliora, _btn_demolisci, _btn_ruota, _btn_ok, _btn_annulla]:
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
	_info_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_testo.custom_minimum_size.x = 420
	_info_testo.add_theme_font_size_override("font_size", 7)
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
	_btn_suggerimenti = _bottone("", 0, 16)
	_btn_suggerimenti.toggle_mode = true
	_btn_suggerimenti.pressed.connect(func():
		GameState.imposta_opzione("suggerimenti", _btn_suggerimenti.button_pressed)
		_aggiorna())
	col.add_child(_btn_suggerimenti)
	var audio := HBoxContainer.new()
	col.add_child(audio)
	for chiave in ["musica", "effetti"]:
		var b := _bottone("Musica" if chiave == "musica" else "Effetti sonori", 0, 16)
		b.toggle_mode = true
		b.button_pressed = GameState.opzioni[chiave]
		b.toggled.connect(func(v): GameState.imposta_opzione(chiave, v))
		audio.add_child(b)
	var tutorial := _bottone("Rivedi il tutorial", 0, 16)
	tutorial.pressed.connect(func(): _info.visible = false; GameState.inizia_tutorial())
	col.add_child(tutorial)
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
		var terra := GameState.vassallo_di(i)
		righe.append("%s, casata %s (%s)%s" % [f.capo, f.casata, GameState.tratto(i).get("nome", "").to_lower(),
			"" if terra == "" else " · vassallo di " + terra])
		righe.append("   " + Consiglio.per(i))
	righe.append("")
	righe.append("Quando conquisti una regione, un consigliere ne diventa vassallo e la governa per te.")
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
	_btn_auto = _bottone("Automatico", 0, 14)
	_btn_auto.toggle_mode = true
	_btn_auto.toggled.connect(func(v): _mercato_manuale.visible = not v; _mercato_auto.visible = v; _aggiorna())
	col.add_child(_btn_auto)
	var griglia := GridContainer.new()
	griglia.columns = 6
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 1)
	col.add_child(griglia)
	_mercato_manuale = griglia
	_crea_mercato_auto(col)
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
		compra.pressed.connect(func(): Audio.effetto("moneta" if GameState.compra(r) else "errore"))
		griglia.add_child(compra)
		var vendi := _bottone("", 100, 14)
		vendi.pressed.connect(func(): Audio.effetto("moneta" if GameState.vendi(r) else "errore"))
		griglia.add_child(vendi)
		_mercato_righe[r] = [scorta, tendenza, compra, vendi]
	_mercato_nota = Label.new()
	_mercato_nota.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_mercato_nota)
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _mercato.visible = false)
	col.add_child(chiudi)


## Il mercato automatico: per ogni risorsa "vendi oltre" (l'eccesso si vende da solo) e
## "compra sotto" (se scende sotto, si compra), più l'oro da tenere sempre da parte.
func _crea_mercato_auto(col: VBoxContainer) -> void:
	_mercato_auto = VBoxContainer.new()
	_mercato_auto.visible = false
	col.add_child(_mercato_auto)
	var griglia := GridContainer.new()
	griglia.columns = 10
	griglia.add_theme_constant_override("h_separation", 3)
	griglia.add_theme_constant_override("v_separation", 1)
	_mercato_auto.add_child(griglia)
	for testo in ["", "", "Hai", "", "", "Vendi oltre", "", "", "Compra sotto", ""]:
		var l := Label.new()
		l.text = testo
		l.add_theme_font_size_override("font_size", 7)
		griglia.add_child(l)
	for r in GameState.mercato.risorse() if GameState.mercato else []:
		griglia.add_child(_icona(r, 9.0))
		var nome := Label.new()
		nome.text = NOMI_RISORSE.get(r, r)
		nome.custom_minimum_size.x = 60
		griglia.add_child(nome)
		var scorta := Label.new()
		scorta.custom_minimum_size.x = 26
		griglia.add_child(scorta)
		var vuoto := Control.new()
		vuoto.custom_minimum_size.x = 16
		griglia.add_child(vuoto)
		var celle := [scorta]
		for chiave in ["vendi_sopra", "compra_sotto"]:
			var meno := _bottone("−", 16, 13)
			meno.pressed.connect(_soglia.bind(r, chiave, -1))
			griglia.add_child(meno)
			var valore := Label.new()
			valore.custom_minimum_size.x = 30
			valore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			griglia.add_child(valore)
			celle.append(valore)
			var piu := _bottone("+", 16, 13)
			piu.pressed.connect(_soglia.bind(r, chiave, 1))
			griglia.add_child(piu)
		_mercato_auto_righe[r] = celle
	var riga := HBoxContainer.new()
	_mercato_auto.add_child(riga)
	var l2 := Label.new()
	l2.text = "Oro da tenere sempre da parte:"
	riga.add_child(l2)
	var meno_r := _bottone("−", 16, 13)
	meno_r.pressed.connect(func(): GameState.riserva_oro = maxi(0, GameState.riserva_oro - 10); _aggiorna())
	riga.add_child(meno_r)
	_riserva = Label.new()
	_riserva.custom_minimum_size.x = 30
	_riserva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	riga.add_child(_riserva)
	var piu_r := _bottone("+", 16, 13)
	piu_r.pressed.connect(func(): GameState.riserva_oro += 10; _aggiorna())
	riga.add_child(piu_r)


## Passa alla soglia successiva o precedente (spento, 20, 50, 100...).
func _soglia(r: String, chiave: String, verso: int) -> void:
	var soglie: Array = GameState.bil.mercato_automatico.soglie
	var adesso := int(GameState.mercato_auto.get(r, {}).get(chiave, 0))
	var i := 0
	for k in soglie.size():
		if int(soglie[k]) <= adesso:
			i = k
	GameState.imposta_auto(r, chiave, int(soglie[clampi(i + verso, 0, soglie.size() - 1)]))


func _aggiorna_mercato() -> void:
	var m := GameState.mercato
	for r in _mercato_auto_righe:
		var celle: Array = _mercato_auto_righe[r]
		var a: Dictionary = GameState.mercato_auto.get(r, {})
		celle[0].text = str(int(GameState.risorse.get(r, 0.0)))
		celle[1].text = str(int(a.get("vendi_sopra", 0))) if int(a.get("vendi_sopra", 0)) > 0 else "—"
		celle[2].text = str(int(a.get("compra_sotto", 0))) if int(a.get("compra_sotto", 0)) > 0 else "—"
	_riserva.text = str(GameState.riserva_oro)
	_btn_auto.disabled = not GameState.ha_mercato()
	_btn_auto.text = "Automatico" if GameState.ha_mercato() else "Automatico (serve un edificio mercato)"
	if not GameState.ha_mercato() and _btn_auto.button_pressed:
		_btn_auto.button_pressed = false
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
	# il re: quanto vuole in autunno, oppure (da indipendenti) cosa pensa di noi
	if GameState.indipendente():
		var cosa := GameState.testo_atteggiamento(GameState.re_atteggiamento)
		_numeri.re.text = {"amichevole": "amico", "tranquillo": "calmo", "diffidente": "diffida", "ostile": "ostile"}.get(cosa, cosa)
		_numeri.re.tooltip_text = "Siamo un borgo libero: niente tasse al re, che è %s verso di noi" % cosa
		_numeri.re.add_theme_color_override("font_color", TESTO_ALLARME if GameState.re_atteggiamento <= -60 else TESTO)
	else:
		var dovuto := GameState.tassa_del_re()
		var quando := GameState.stagioni_al_re()
		_numeri.re.text = str(dovuto)
		_numeri.re.tooltip_text = "Tassa al re: %d oro %s" % [dovuto, "a fine stagione" if quando == 0 else "tra %d stagion%s, in autunno" % [quando, "e" if quando == 1 else "i"]]
		_numeri.re.add_theme_color_override("font_color", TESTO_ALLARME if GameState.risorse.oro < dovuto else TESTO)
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
	# il tutorial si fa da parte mentre c'è una carta da leggere
	_tutorial.visible = GameState.tutorial_passo >= 0 and not _carta.visible
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
	if _esercito.visible:
		_aggiorna_esercito()


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
		if r == "armi" and d.has("arcieri"):
			return true
	return false


func _imposta_velocita(v: int) -> void:
	if not GameState.evento_attivo.is_empty() or not GameState.battaglia.is_empty():
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
	if _categoria_aperta == "difese":
		tipi.append(MURA)  # le mura si tracciano come le strade
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
		b.set_meta("tipo", tipo)
		if tipo == MURA:
			var dal := int(GameState.bil.mura.dal_livello)
			b.text = "Mura in pietra  ·  %d pietra per cella" % TerrenoFeudo.COSTO_MURA if GameState.livello >= dal \
				else "Mura in pietra  (serve %s)" % GameState.bil.livelli[dal].nome
			b.disabled = GameState.livello < dal
			continue
		var d: Dictionary = GameState.edifici[tipo]
		if GameState.sbloccato(tipo):
			b.text = "%s  ·  %s" % [d.nome, GameState.testo_costo(tipo)]
			b.disabled = not GameState.puo_permettersi(tipo)
		else:
			b.text = "%s  (serve %s)" % [d.nome, GameState.bil.livelli[int(d.livello)].nome]
			b.disabled = true


const MURA := "__mura"


func _scegli_dal_menu(b: Button) -> void:
	_chiudi_menu()
	if b.get_meta("tipo") == MURA:
		mura.emit()
	else:
		costruisci.emit(b.get_meta("tipo"))


func _aggiorna_pannello() -> void:
	for x in [_btn_meno, _btn_piu, _btn_migliora, _btn_demolisci, _btn_ruota, _btn_ok, _btn_annulla, _btn_chiudi] + _btn_colture.values():
		x.visible = false
	if _strada != "":
		_pannello.visible = true
		_titolo.text = _strada_titolo
		if _strada == "esistente":
			if _strada_titolo == "Mura":
				_dettagli.text = "Mura in pietra: difendono il borgo (+%.1f per cella) e se lo chiudono tutto attorno la difesa vale il %d%% in più. In guerra le porte restano chiuse." % [
					float(GameState.bil.mura.difesa_per_cella), roundi(float(GameState.bil.mura.bonus_cinta) * 100)]
			else:
				_dettagli.text = "Le strade corrono sui bordi delle celle e partono da falò o piazza, dimora o torri di guardia. La gente ci cammina; chi non è collegato lavora il 2% in meno."
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
		_btn_ruota.visible = true
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
	if d.has("arcieri"):
		testo = "Arcieri sulla torre: %d su %d. Tirano ai banditi che passano entro %d celle (riquadro giallo); se il centro del borgo è nel raggio combattono anche lì (%d ciascuno, x%.1f con le armi). Avvistano i banditi prima. Se un arciere muore, ne sale uno nuovo a ogni stagione." % [
			int(b.get("arcieri", 0)), int(d.arcieri), int(d.raggio_tiro), int(d.difesa_per_arciere), float(GameState.bil.banditi.bonus_armi)]
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
	righe.append("Tributo delle case: %d oro a stagione (1 per casa fino a 4 posti, 2 fino a 6, 3 fino a 8)" % GameState.tributo_case())
	if GameState.indipendente():
		righe.append("Il re: siamo indipendenti, niente tasse; è %s verso di noi · capacità magazzino %d" % [
			GameState.testo_atteggiamento(GameState.re_atteggiamento), GameState.capacita()])
	else:
		righe.append("Tassa al re in autunno: %d oro (diventando Borgo non la pagheremo più) · capacità magazzino %d" % [GameState.tassa_del_re(), GameState.capacita()])
	var dif := GameState.difesa()
	righe.append("Difesa %d: milizia %d, arcieri %d (forza %d), soldati %d (forza %d), palizzate %d, mura %d%s, alleati %d, vassalli %d%s" % [roundi(dif.totale), roundi(dif.milizia),
		dif.arcieri, roundi(dif.forza_arcieri), dif.soldati, roundi(dif.forza_soldati), roundi(dif.palizzate), roundi(dif.mura),
		" (cinta chiusa: +%d%%)" % roundi(float(GameState.bil.mura.bonus_cinta) * 100) if dif.cinta else "", roundi(dif.alleati), roundi(dif.vassalli),
		"" if GameState.banditi_possibili() else " · i banditi arriveranno quando saremo un Borgo"])
	_info_testo.text = "\n".join(righe)
	for i in _tasse.size():
		_tasse[i].set_pressed_no_signal(["basse", "normali", "alte"][i] == GameState.tasse)
	_btn_suggerimenti.set_pressed_no_signal(GameState.suggerimenti_attivi)
	_btn_suggerimenti.text = "Suggerimenti ogni tanto: %s" % ("sì" if GameState.suggerimenti_attivi else "no")


# --- Tutorial -------------------------------------------------------------------

## Il riquadro del tutorial, in alto a destra: un passo alla volta. Il pulsante da usare lampeggia.
func _crea_tutorial() -> void:
	_tutorial = PanelContainer.new()
	_tutorial.add_theme_stylebox_override("panel", _riquadro(Color("e9dcbc"), Color("6b4a2e")))
	_tutorial.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tutorial.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tutorial.offset_right = -54
	_tutorial.offset_top = 58
	_tutorial.visible = false
	_radice.add_child(_tutorial)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 130
	col.add_theme_constant_override("separation", 1)
	_tutorial.add_child(col)
	var inchiostro := Color("3b2a1e")
	_tutorial_titolo = Label.new()
	_tutorial_titolo.add_theme_color_override("font_color", Color("7a4a2a"))
	col.add_child(_tutorial_titolo)
	_tutorial_testo = Label.new()
	_tutorial_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_testo.custom_minimum_size.x = 130
	_tutorial_testo.add_theme_color_override("font_color", inchiostro)
	_tutorial_testo.add_theme_font_size_override("font_size", 6)
	_tutorial_titolo.add_theme_font_size_override("font_size", 7)
	col.add_child(_tutorial_testo)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(riga)
	var salta := _bottone("Salta", 0, 12)
	salta.pressed.connect(func(): GameState.salta_tutorial())
	riga.add_child(salta)
	_tutorial_avanti = _bottone("Avanti", 0, 12)
	_tutorial_avanti.pressed.connect(func(): GameState.avanti_tutorial())
	riga.add_child(_tutorial_avanti)


func _mostra_tutorial(passo: int) -> void:
	if _lampeggia:
		_lampeggia.kill()
		_lampeggia = null
	for b in _pulsanti.values():
		b.modulate = Color.WHITE
	_tutorial.visible = passo >= 0
	if passo < 0:
		return
	var p: Dictionary = GameState.dati_tutorial[passo]
	_tutorial_titolo.text = "Tutorial %d/%d · %s" % [passo + 1, GameState.dati_tutorial.size(), p.titolo]
	_tutorial_testo.text = p.testo
	var manuale: bool = p.get("condizione", "") == ""
	_tutorial_avanti.visible = manuale
	_tutorial_avanti.text = "Fine" if passo == GameState.dati_tutorial.size() - 1 else "Avanti"
	var nome: String = p.get("evidenzia", "")
	if _pulsanti.has(nome):
		var b: Button = _pulsanti[nome]
		_lampeggia = create_tween().set_loops()
		_lampeggia.tween_property(b, "modulate", Color(1.6, 1.4, 0.6), 0.45)
		_lampeggia.tween_property(b, "modulate", Color.WHITE, 0.45)


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
	_esercito.visible = false
	var n := int(carta.get("narratore", -1))
	if n >= 0 and n == GameState.capo:
		_carta_chi.text = "%s, tuo signore e guida, annuncia:" % GameState.famiglie[n].capo
	elif n >= 0:
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
	if GameState.evento_senza_scelta():
		# mai bloccati: se non possiamo permetterci niente, si lascia perdere
		var niente := _bottone("Non possiamo fare niente: lasciamo perdere", 0, 20)
		niente.pressed.connect(func():
			_carta.visible = false
			GameState.scegli_evento(-1))
		_carta_scelte.add_child(niente)
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
