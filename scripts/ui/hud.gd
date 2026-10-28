class_name Hud
extends CanvasLayer
## Interfaccia: barra delle risorse, menu di costruzione ai lati,
## pannello contestuale in basso, finestra Info e fine partita.
## Costruita in codice; le misure sono in pixel di una base 480×270, scalata sullo schermo vero.
## Layout a container ancorati (niente offset fissi), così si adatta a risoluzioni diverse.

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

# --- Palette semantica ---------------------------------------------------------
const COLORE_OK := Color("9fd18b")
const COLORE_ATTENZIONE := Color("f2d24b")
const COLORE_ERRORE := Color("ff6b5b")
const COLORE_INFO := Color("a0c0e0")
const TESTO := Color("f3e3c3")
const TESTO_ALLARME := COLORE_ERRORE  # alias storico

# --- Margini uniformi (in pixel base 480×270) -----------------------------------
const MARGINE := 4
const MARGINE_BARRA := 2
const SEPARAZIONE := 2

var _radice: Control
var _numeri: Dictionary = {}
var _icone: Dictionary = {}
var _mercato: PanelContainer
var _esercito: PanelContainer
var _esercito_testo: Label
var _conferma_coltura: PanelContainer
var _conferma_testo: Label
var _conferma_si: Button
var _conferma_no: Button
var _conferma_azione: Callable = Callable()
var _coltura_scelta := ""
var _truppe_righe: Dictionary = {}
var _mercato_notizia: Label
var _mercato_righe: Dictionary = {}
var _mercato_nota: Label
var _mercato_manuale: GridContainer
var _mercato_auto: VBoxContainer
var _mercato_auto_righe: Dictionary = {}
var _riserva: Label
var _btn_auto: Button
var _btn_colture: Dictionary = {}
var _strada := ""
var _strada_testo := ""
var _strada_valida := false
var _strada_titolo := "Strada"
var _btn_ruota: Button
var _pulsanti: Dictionary = {}
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
var _allarme: Label
var _tempo_avviso := 0.0
var _fine: PanelContainer
var _fine_titolo: Label
var _fine_testo: Label
var _carta: PanelContainer
var _carta_chi: Label
var _carta_titolo: Label
var _carta_testo: Label
var _carta_scelte: VBoxContainer

var _edificio := -1
var _piazzamento := ""
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
	_crea_avvisi()  # un solo contenitore per avviso + allarme, così non si sovrappongono
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


## ESC / tasto "indietro": chiude i pannelli aperti in ordine di priorità.
## Le carte evento e la schermata di fine partita richiedono una scelta e non si chiudono.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _carta.visible or _fine.visible:
		return
	if _conferma_coltura.visible:
		_chiudi_conferma()
		get_viewport().set_input_as_handled()
		return
	if _mercato.visible:
		_mercato.visible = false
	elif _esercito.visible:
		_esercito.visible = false
	elif _info.visible:
		_info.visible = false
	elif _consiglio.visible:
		_consiglio.visible = false
	elif _menu.visible:
		_chiudi_menu()
	elif _pannello.visible:
		chiudi_pannello.emit()
	else:
		return
	get_viewport().set_input_as_handled()


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


func mostra_strada(testo: String, valido: bool, titolo := "Strada") -> void:
	_strada = "nuova"
	_strada_titolo = titolo
	_strada_testo = testo
	_strada_valida = valido
	_piazzamento = ""
	_edificio = -1
	_aggiorna_pannello()


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


# --- Tema ------------------------------------------------------------------------

static func crea_tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = 8
	t.set_stylebox("panel", "PanelContainer", _riquadro(Color("3b2a1e"), Color("6b4a2e"), 6))
	t.set_stylebox("normal", "Button", _riquadro(Color("7a5634"), Color("a0784a"), 2))
	t.set_stylebox("hover", "Button", _riquadro(Color("8a6440"), Color("c09060"), 2))
	t.set_stylebox("pressed", "Button", _riquadro(Color("5a3e24"), Color("f2d24b"), 2))
	t.set_stylebox("hover_pressed", "Button", _riquadro(Color("5a3e24"), Color("f2d24b"), 2))
	t.set_stylebox("disabled", "Button", _riquadro(Color("4a4038"), Color("5a5048"), 2))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for nome in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(nome, "Button", TESTO)
	t.set_color("font_disabled_color", "Button", Color("8a8070"))
	t.set_color("font_color", "Label", TESTO)
	t.set_constant("separation", "VBoxContainer", SEPARAZIONE)
	t.set_constant("separation", "HBoxContainer", SEPARAZIONE)
	return t


static func _riquadro(sfondo: Color, bordo: Color, margine := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = sfondo
	s.border_color = bordo
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.set_content_margin_all(margine)
	return s


func _bottone(testo: String, larghezza := 0, altezza := 16, motivo := "") -> Button:
	var b := Button.new()
	b.text = testo
	b.custom_minimum_size = Vector2(larghezza, altezza)
	b.focus_mode = Control.FOCUS_NONE
	if motivo != "":
		b.tooltip_text = motivo
	return b


func _icona(chiave: String, lato := 10.0) -> Control:
	var c := CenterContainer.new()
	c.add_child(IconaRisorsa.new(chiave, lato))
	return c


## Un pannello centrale che si chiude con un bottone "Chiudi": struttura comune a info,
## consiglio, mercato, esercito. Ritorna il VBox in cui aggiungere il contenuto.
func _pannello_centrale(titolo: String) -> Array:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(centro)
	var pannello := PanelContainer.new()
	pannello.custom_minimum_size = Vector2(320, 0)
	pannello.visible = false
	centro.add_child(pannello)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	pannello.add_child(col)
	if titolo != "":
		var t := Label.new()
		t.text = titolo
		t.add_theme_font_size_override("font_size", 10)
		col.add_child(t)
	return [pannello, col]


# --- Barra risorse ----------------------------------------------------------------

func _crea_barra() -> void:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# margini interni: 2px come da base 480×270
	var sb := _riquadro(Color("3b2a1e"), Color("6b4a2e"), MARGINE_BARRA)
	barra.add_theme_stylebox_override("panel", sb)
	_radice.add_child(barra)
	var riga := HBoxContainer.new()
	riga.add_theme_constant_override("separation", SEPARAZIONE)
	barra.add_child(riga)
	for chiave in GameState.RISORSE_VISIBILI + ["re", "abitanti", "disponibili", "felicita"]:
		var icona := _icona(chiave, 8.0)
		_icone[chiave] = icona
		riga.add_child(icona)
		var l := Label.new()
		l.custom_minimum_size.x = 16 if chiave != "abitanti" else 26
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.clip_text = true
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
		var b := _bottone(["||", "x1", "x2", "x3"][i], 14, 12,
			"Metti in pausa" if i == 0 else "Velocità x%d" % i)
		b.toggle_mode = true
		b.pressed.connect(_imposta_velocita.bind(i))
		riga.add_child(b)
		_velocita.append(b)


# --- Lati -------------------------------------------------------------------------

func _crea_lati() -> void:
	# Sinistra: ancorata in alto a sinistra, margine uniforme, contenuto in alto
	var mc_s := MarginContainer.new()
	mc_s.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mc_s.add_theme_constant_override("margin_left", MARGINE)
	mc_s.add_theme_constant_override("margin_top", MARGINE + 20)  # sotto la barra
	mc_s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(mc_s)
	var sinistra := VBoxContainer.new()
	sinistra.add_theme_constant_override("separation", SEPARAZIONE)
	sinistra.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mc_s.add_child(sinistra)
	for c in CATEGORIE:
		var b := _bottone(c[0], 46, 30, "Costruisci: %s" % c[0].to_lower())
		b.pressed.connect(_apri_categoria.bind(c[1]))
		sinistra.add_child(b)
		_pulsanti[c[0]] = b
	var strada := _bottone("Strade", 46, 30, "Traccia una strada (1 pietra per lato)")
	_pulsanti["Strade"] = strada
	strada.pressed.connect(func(): _chiudi_menu(); strade.emit())
	sinistra.add_child(strada)

	# Destra: ancorata in alto a destra, margine uniforme
	var mc_d := MarginContainer.new()
	mc_d.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mc_d.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mc_d.add_theme_constant_override("margin_right", MARGINE)
	mc_d.add_theme_constant_override("margin_top", MARGINE + 20)
	mc_d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(mc_d)
	var destra := VBoxContainer.new()
	destra.add_theme_constant_override("separation", SEPARAZIONE)
	destra.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	destra.size_flags_horizontal = Control.SIZE_SHRINK_END
	mc_d.add_child(destra)
	var regno := _bottone("Regno", 46, 30, "Mappa del regno: spie, alleanze, attacchi")
	_pulsanti["Regno"] = regno
	regno.pressed.connect(func(): vai_al_regno.emit())
	destra.add_child(regno)
	var info := _bottone("Info", 46, 30, "Statistiche, tasse, opzioni")
	_pulsanti["Info"] = info
	info.pressed.connect(func(): _apri_finestra(_info))
	destra.add_child(info)
	var consiglio := _bottone("Consiglio", 46, 30, "I consiglieri e i loro pareri")
	_pulsanti["Consiglio"] = consiglio
	consiglio.pressed.connect(func(): _apri_finestra(_consiglio))
	destra.add_child(consiglio)
	var mercato := _bottone("Mercato", 46, 30, "Compra e vendi risorse")
	_pulsanti["Mercato"] = mercato
	mercato.pressed.connect(func(): _apri_finestra(_mercato))
	destra.add_child(mercato)
	var esercito := _bottone("Esercito", 46, 30, "Soldati, formazioni, missioni")
	_pulsanti["Esercito"] = esercito
	esercito.pressed.connect(func(): _apri_finestra(_esercito))
	destra.add_child(esercito)
	var giro := HBoxContainer.new()
	giro.add_theme_constant_override("separation", SEPARAZIONE)
	destra.add_child(giro)
	for verso in [-1, 1]:
		var b := _bottone("<" if verso < 0 else ">", 22, 30,
			"Ruota la vista a sinistra" if verso < 0 else "Ruota la vista a destra")
		b.pressed.connect(func(): ruota.emit(verso))
		giro.add_child(b)


# --- Finestre centrali ------------------------------------------------------------

func _apri_finestra(finestra: PanelContainer) -> void:
	var era := finestra.visible
	for f in [_info, _consiglio, _mercato, _esercito]:
		f.visible = false
	finestra.visible = not era
	_aggiorna()


# --- Conferma generica ------------------------------------------------------------

func _crea_conferma_coltura() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(centro)
	_conferma_coltura = PanelContainer.new()
	_conferma_coltura.custom_minimum_size = Vector2(220, 0)
	_conferma_coltura.visible = false
	centro.add_child(_conferma_coltura)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_conferma_coltura.add_child(col)
	_conferma_testo = Label.new()
	_conferma_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conferma_testo.custom_minimum_size.x = 220
	col.add_child(_conferma_testo)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(riga)
	_conferma_si = _bottone("Sì", 70, 18)
	_conferma_si.pressed.connect(_conferma)
	riga.add_child(_conferma_si)
	_conferma_no = _bottone("No", 50, 18)
	_conferma_no.pressed.connect(_chiudi_conferma)
	riga.add_child(_conferma_no)


func _chiedi_conferma(testo: String, azione: Callable, etichetta_si := "Sì") -> void:
	_conferma_testo.text = testo
	_conferma_si.text = etichetta_si
	_conferma_azione = azione
	_conferma_coltura.visible = true


func _conferma() -> void:
	_conferma_coltura.visible = false
	var a := _conferma_azione
	_conferma_azione = Callable()
	if a.is_valid():
		a.call()
	_aggiorna()


func _chiudi_conferma() -> void:
	_conferma_coltura.visible = false
	_conferma_azione = Callable()
	_aggiorna()


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
	_chiedi_conferma(testo, func(): coltura.emit(_edificio, nome), "Sì, cambia")


func _chiedi_demolizione() -> void:
	if _strada == "esistente":
		_chiedi_conferma("Rimuovere %s?" % _strada_titolo.to_lower(),
			func(): rimuovi_strada.emit(), "Sì, rimuovi")
		return
	var b := GameState.trova(_edificio)
	if b.is_empty():
		return
	var nome: String = GameState.def_di(b).nome
	_chiedi_conferma("Demolire %s?\nNon si può annullare." % nome.to_lower(),
		func(): demolisci.emit(_edificio), "Sì, demolisci")


# --- Esercito ----------------------------------------------------------------------

func _crea_esercito() -> void:
	var r := _pannello_centrale("Esercito")
	_esercito = r[0]
	var col: VBoxContainer = r[1]
	_esercito_testo = Label.new()
	_esercito_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_esercito_testo.custom_minimum_size.x = 300
	col.add_child(_esercito_testo)
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
		var congeda := _bottone("Congeda", 0, 15, "Rimanda a casa i soldati di questo tipo")
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
		celle[1].tooltip_text = perche if perche != "" else "Costo: %s" % ", ".join(costo)
		celle[2].disabled = int(presenti.get(tipo, 0)) <= 0
		celle[2].tooltip_text = "" if not celle[2].disabled else "Nessun soldato di questo tipo da congedare"


# --- Menu costruzione --------------------------------------------------------------

func _crea_menu() -> void:
	# Ancorato sotto la colonna sinistra, ma con un margine a sinistra per non coprirla
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mc.add_theme_constant_override("margin_left", 54)
	mc.add_theme_constant_override("margin_top", MARGINE + 20)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(mc)
	_menu = PanelContainer.new()
	_menu.visible = false
	_menu.custom_minimum_size.x = 150
	mc.add_child(_menu)
	_menu_lista = VBoxContainer.new()
	_menu.add_child(_menu_lista)


# --- Pannello contestuale (in basso) -----------------------------------------------

func _crea_pannello() -> void:
	# Ancorato in basso al centro: larghezza flessibile, contenuto che va a capo
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	mc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mc.add_theme_constant_override("margin_bottom", MARGINE)
	mc.add_theme_constant_override("margin_left", MARGINE)
	mc.add_theme_constant_override("margin_right", MARGINE)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(mc)
	_pannello = PanelContainer.new()
	_pannello.custom_minimum_size = Vector2(320, 0)
	_pannello.visible = false
	mc.add_child(_pannello)
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 2)
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
	_btn_meno = _bottone("-", 18, 18, "Togli un lavoratore")
	_btn_meno.pressed.connect(func(): cambia_lavoratori.emit(_edificio, -1))
	_btn_piu = _bottone("+", 18, 18, "Aggiungi un lavoratore")
	_btn_piu.pressed.connect(func(): cambia_lavoratori.emit(_edificio, 1))
	_btn_demolisci = _bottone("Demolisci", 0, 18, "Demolisci l'edificio (chiede conferma)")
	_btn_demolisci.pressed.connect(_chiedi_demolizione)
	_btn_migliora = _bottone("Migliora", 0, 18, "Passa al livello successivo")
	_btn_migliora.pressed.connect(func(): migliora.emit(_edificio))
	_btn_ruota = _bottone("Ruota", 0, 18, "Ruota l'edificio di 90°")
	_btn_ruota.pressed.connect(func(): ruota_edificio.emit())
	_btn_ok = _bottone("Costruisci", 0, 18, "Conferma il piazzamento")
	_btn_ok.pressed.connect(func(): conferma_piazzamento.emit())
	_btn_annulla = _bottone("Annulla", 0, 18, "Annulla il piazzamento (o premi ESC)")
	_btn_annulla.pressed.connect(func(): annulla_piazzamento.emit())
	_btn_chiudi = _bottone("X", 18, 18, "Chiudi (o premi ESC)")
	_btn_chiudi.pressed.connect(func(): chiudi_pannello.emit())
	_btn_chiudi.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sopra.add_child(_btn_chiudi)
	for nome in GameState.nomi_colture():
		var bc := _bottone(GameState.colture[nome].nome, 0, 18, "Coltiva %s in questo campo" % GameState.colture[nome].nome.to_lower())
		bc.toggle_mode = true
		bc.pressed.connect(_chiedi_coltura.bind(nome))
		_btn_colture[nome] = bc
		riga.add_child(bc)
	for b in [_btn_meno, _btn_piu, _btn_migliora, _btn_demolisci, _btn_ruota, _btn_ok, _btn_annulla]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		riga.add_child(b)


# --- Info -------------------------------------------------------------------------

func _crea_info() -> void:
	var r := _pannello_centrale("Info")
	_info = r[0]
	var col: VBoxContainer = r[1]
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
		var b := _bottone(livello.capitalize(), 40, 16,
			"Tasse %s: più oro, ma la felicità scende" % livello if livello != "normali" else "Tasse normali: equilibrio")
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
	_btn_suggerimenti = _bottone("", 0, 16, "Mostra un suggerimento ogni tanto")
	_btn_suggerimenti.toggle_mode = true
	_btn_suggerimenti.pressed.connect(func():
		GameState.imposta_opzione("suggerimenti", _btn_suggerimenti.button_pressed)
		_aggiorna())
	col.add_child(_btn_suggerimenti)
	var audio := HBoxContainer.new()
	col.add_child(audio)
	for chiave in ["musica", "effetti"]:
		var b := _bottone("Musica" if chiave == "musica" else "Effetti sonori", 0, 16,
			"Attiva o disattiva la musica" if chiave == "musica" else "Attiva o disattiva gli effetti sonori")
		b.toggle_mode = true
		b.button_pressed = GameState.opzioni[chiave]
		b.toggled.connect(func(v): GameState.imposta_opzione(chiave, v))
		audio.add_child(b)
	var tutorial := _bottone("Rivedi il tutorial", 0, 16, "Ricomincia il tutorial dall'inizio")
	tutorial.pressed.connect(func(): _info.visible = false; GameState.inizia_tutorial())
	col.add_child(tutorial)
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _info.visible = false)
	col.add_child(chiudi)


func _crea_consiglio() -> void:
	var r := _pannello_centrale("Consiglio")
	_consiglio = r[0]
	var col: VBoxContainer = r[1]
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


# --- Mercato ----------------------------------------------------------------------

func _crea_mercato() -> void:
	var r := _pannello_centrale("Mercato")
	_mercato = r[0]
	var col: VBoxContainer = r[1]
	_mercato_notizia = Label.new()
	_mercato_notizia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mercato_notizia.custom_minimum_size.x = 330
	col.add_child(_mercato_notizia)
	_btn_auto = _bottone("Automatico", 0, 14)
	_btn_auto.toggle_mode = true
	_btn_auto.tooltip_text = "Compra e vendi da solo secondo le soglie che imposti"
	_btn_auto.toggled.connect(func(v): _mercato_manuale.visible = not v; _mercato_auto.visible = v; _aggiorna())
	col.add_child(_btn_auto)
	var griglia := GridContainer.new()
	griglia.columns = 6
	griglia.add_theme_constant_override("h_separation", 4)
	griglia.add_theme_constant_override("v_separation", 1)
	col.add_child(griglia)
	_mercato_manuale = griglia
	_crea_mercato_auto(col)
	for r2 in GameState.mercato.risorse() if GameState.mercato else []:
		griglia.add_child(_icona(r2, 9.0))
		var nome := Label.new()
		nome.text = NOMI_RISORSE.get(r2, r2)
		nome.custom_minimum_size.x = 64
		griglia.add_child(nome)
		var scorta := Label.new()
		scorta.custom_minimum_size.x = 28
		scorta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		griglia.add_child(scorta)
		var tendenza := Label.new()
		tendenza.custom_minimum_size.x = 30
		tendenza.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		griglia.add_child(tendenza)
		var compra := _bottone("", 100, 14)
		compra.pressed.connect(func(): Audio.effetto("moneta" if GameState.compra(r2) else "errore"))
		griglia.add_child(compra)
		var vendi := _bottone("", 100, 14)
		vendi.pressed.connect(func(): Audio.effetto("moneta" if GameState.vendi(r2) else "errore"))
		griglia.add_child(vendi)
		_mercato_righe[r2] = [scorta, tendenza, compra, vendi]
	_mercato_nota = Label.new()
	_mercato_nota.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_mercato_nota)
	var chiudi := _bottone("Chiudi")
	chiudi.pressed.connect(func(): _mercato.visible = false)
	col.add_child(chiudi)


func _crea_mercato_auto(col: VBoxContainer) -> void:
	_mercato_auto = VBoxContainer.new()
	_mercato_auto.visible = false
	col.add_child(_mercato_auto)
	var spiega := Label.new()
	spiega.text = "Compra e vende da solo a ogni cambio di stagione, ai prezzi nuovi."
	spiega.add_theme_font_size_override("font_size", 7)
	_mercato_auto.add_child(spiega)
	# undici risorse non stanno nello schermo: la tabella scorre, riserva e Chiudi restano visibili
	var scorre := ScrollContainer.new()
	scorre.custom_minimum_size.y = 130
	scorre.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mercato_auto.add_child(scorre)
	var griglia := GridContainer.new()
	griglia.columns = 10
	griglia.add_theme_constant_override("h_separation", 3)
	griglia.add_theme_constant_override("v_separation", 1)
	griglia.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorre.add_child(griglia)
	for testo in ["", "", "Hai", "", "", "Vendi oltre", "", "", "Compra sotto", ""]:
		var l := Label.new()
		l.text = testo
		l.add_theme_font_size_override("font_size", 7)
		griglia.add_child(l)
	for r2 in GameState.mercato.risorse() if GameState.mercato else []:
		griglia.add_child(_icona(r2, 9.0))
		var nome := Label.new()
		nome.text = NOMI_RISORSE.get(r2, r2)
		nome.custom_minimum_size.x = 60
		griglia.add_child(nome)
		var scorta := Label.new()
		scorta.custom_minimum_size.x = 26
		scorta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		griglia.add_child(scorta)
		var vuoto := Control.new()
		vuoto.custom_minimum_size.x = 16
		griglia.add_child(vuoto)
		var celle := [scorta]
		for chiave in ["vendi_sopra", "compra_sotto"]:
			var meno := _bottone("−", 16, 11, "Soglia più bassa")
			meno.pressed.connect(_soglia.bind(r2, chiave, -1))
			griglia.add_child(meno)
			var valore := Label.new()
			valore.custom_minimum_size.x = 30
			valore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			griglia.add_child(valore)
			celle.append(valore)
			var piu := _bottone("+", 16, 11, "Soglia più alta")
			piu.pressed.connect(_soglia.bind(r2, chiave, 1))
			griglia.add_child(piu)
		_mercato_auto_righe[r2] = celle
	var riga := HBoxContainer.new()
	_mercato_auto.add_child(riga)
	var l2 := Label.new()
	l2.text = "Oro da tenere sempre da parte:"
	riga.add_child(l2)
	var meno_r := _bottone("−", 16, 11, "Tieni da parte meno oro")
	meno_r.pressed.connect(func(): GameState.riserva_oro = maxi(0, GameState.riserva_oro - 10); _aggiorna())
	riga.add_child(meno_r)
	_riserva = Label.new()
	_riserva.custom_minimum_size.x = 30
	_riserva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	riga.add_child(_riserva)
	var piu_r := _bottone("+", 16, 11, "Tieni da parte più oro")
	piu_r.pressed.connect(func(): GameState.riserva_oro += 10; _aggiorna())
	riga.add_child(piu_r)


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
	var ha := GameState.ha_mercato()
	_btn_auto.disabled = not ha
	_btn_auto.text = "Automatico" if ha else "Automatico (serve un mercato)"
	_btn_auto.tooltip_text = "Compra e vendi da solo secondo le soglie che imposti" if ha \
		else "Serve un edificio mercato per attivare il commercio automatico"
	if not ha and _btn_auto.button_pressed:
		_btn_auto.button_pressed = false
	_mercato_notizia.text = "Mercato del regno · %s" % m.notizia()
	var lotto := m.lotto()
	for r in _mercato_righe:
		var riga: Array = _mercato_righe[r]
		riga[0].text = str(int(GameState.risorse.get(r, 0.0)))
		var t := m.tendenza(r, GameState.stagione)
		riga[1].text = "▲" if t > 0 else ("▼" if t < 0 else "—")
		riga[1].add_theme_color_override("font_color", COLORE_ERRORE if t > 0 else (COLORE_OK if t < 0 else Color(1, 1, 1, 0.4)))
		var costo := GameState.costo_lotto(r)
		var ricavo := GameState.ricavo_lotto(r)
		var unit := float(costo) / lotto
		riga[2].text = "Compra %d · %d oro (%.1f/u)" % [lotto, costo, unit]
		riga[2].disabled = GameState.risorse.oro < costo or GameState.risorse[r] + lotto > GameState.capacita()
		riga[2].tooltip_text = "Non hai abbastanza oro" if GameState.risorse.oro < costo \
			else ("Magazzino pieno: %d/%d" % [GameState.risorse[r], GameState.capacita()] if GameState.risorse[r] + lotto > GameState.capacita() else "")
		var unit_v := float(ricavo) / lotto
		riga[3].text = "Vendi %d · %d oro (%.1f/u)" % [lotto, ricavo, unit_v]
		riga[3].disabled = GameState.risorse[r] < lotto
		riga[3].tooltip_text = "Ti servono almeno %d %s" % [lotto, NOMI_RISORSE.get(r, r).to_lower()] if riga[3].disabled else ""
	_mercato_nota.text = "Hai %d oro. Con un mercato costruito si compra e si vende a prezzi migliori." % int(GameState.risorse.oro) \
		if not ha else "Hai %d oro. Il tuo mercato ti fa avere prezzi migliori." % int(GameState.risorse.oro)


func _nuovo_consiglio(famiglia: int, testo: String) -> void:
	mostra_avviso("%s: %s" % [GameState.famiglie[famiglia].capo, testo], 7.0)


# --- Avvisi (in alto, in colonna) ---------------------------------------------------

func _crea_avvisi() -> void:
	# Un solo contenitore al centro in alto: avviso sopra, allarme sotto.
	# Così non si sovrappongono mai, e il tutorial (ancorato a destra) non li copre.
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mc.add_theme_constant_override("margin_top", MARGINE + 18)  # sotto la barra
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(mc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(col)
	_avviso = Label.new()
	_avviso.custom_minimum_size.x = 340  # con l'a capo automatico serve una larghezza
	_avviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_avviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_avviso.add_theme_constant_override("outline_size", 3)
	_avviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avviso.modulate.a = 0.0
	col.add_child(_avviso)
	_allarme = Label.new()
	_allarme.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_allarme.add_theme_color_override("font_color", COLORE_ERRORE.lightened(0.25))
	_allarme.add_theme_color_override("font_outline_color", Color("3a0a08"))
	_allarme.add_theme_constant_override("outline_size", 3)
	_allarme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_allarme.visible = false
	col.add_child(_allarme)


# --- Fine partita ------------------------------------------------------------------

func _crea_fine() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(centro)
	_fine = PanelContainer.new()
	_fine.custom_minimum_size = Vector2(280, 0)
	_fine.visible = false
	centro.add_child(_fine)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_fine.add_child(col)
	_fine_titolo = Label.new()
	_fine_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fine_titolo.add_theme_font_size_override("font_size", 12)
	col.add_child(_fine_titolo)
	_fine_testo = Label.new()
	_fine_testo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fine_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_fine_testo)
	var b := _bottone("Nuova partita", 0, 20, "Ricomincia da capo")
	b.pressed.connect(func(): nuova_partita.emit())
	col.add_child(b)


# --- Aggiornamenti ----------------------------------------------------------------

func _aggiorna() -> void:
	var tps: float = GameState.bil.tick_per_stagione
	var rimasti := maxf(1.0, tps - GameState.tick_in_stagione)
	var arrivo := GameState.previsione_raccolti()
	for r in GameState.RISORSE_VISIBILI:
		var mostra := _da_mostrare(r)
		_numeri[r].visible = mostra
		_icone[r].visible = mostra
		var valore: float = GameState.risorse.get(r, 0.0)
		var delta: float = GameState.ultimo_delta.get(r, 0.0)
		_numeri[r].text = str(int(valore))
		# rosso se finisce prima che arrivi il raccolto, o se anche col raccolto non basta per la stagione dopo
		var a_fine: float = valore + delta * rimasti + float(arrivo.get(r, 0.0))
		var allarme := delta < 0.0 and (valore + delta * rimasti < 0.0 or a_fine + delta * tps < 0.0)
		if r == "cibo" and GameState.tick_fame > 0:
			allarme = true
		_numeri[r].add_theme_color_override("font_color", COLORE_ERRORE if allarme else TESTO)
		var nome: String = NOMI_RISORSE.get(r, r)
		_numeri[r].tooltip_text = "%s\nHai: %d\nVariazione: %+.1f a stagione" % [nome, int(valore), delta * tps]
		if float(arrivo.get(r, 0.0)) >= 1.0:
			_numeri[r].tooltip_text += "\nIn arrivo a fine stagione: circa %d" % int(arrivo[r])
	_numeri.abitanti.text = "%d/%d" % [GameState.abitanti, GameState.alloggi()]
	_numeri.abitanti.add_theme_color_override("font_color", COLORE_ERRORE if GameState.senza_casa() > 0 else TESTO)
	_numeri.abitanti.tooltip_text = "Abitanti: %d\nPosti letto: %d\nSenza casa: %d" % [GameState.abitanti, GameState.alloggi(), GameState.senza_casa()]
	_numeri.disponibili.text = str(GameState.disoccupati())
	_numeri.disponibili.tooltip_text = "Persone senza lavoro: %d\nServono case e posti di lavoro" % GameState.disoccupati()
	if GameState.indipendente():
		var cosa := GameState.testo_atteggiamento(GameState.re_atteggiamento)
		_numeri.re.text = {"amichevole": "amico", "tranquillo": "calmo", "diffidente": "diffida", "ostile": "ostile"}.get(cosa, cosa)
		_numeri.re.tooltip_text = "Siamo un borgo libero: niente tasse al re, che è %s verso di noi" % cosa
		_numeri.re.add_theme_color_override("font_color", COLORE_ERRORE if GameState.re_atteggiamento <= -60 else TESTO)
	else:
		var dovuto := GameState.tassa_del_re()
		var quando := GameState.stagioni_al_re()
		_numeri.re.text = str(dovuto)
		_numeri.re.tooltip_text = "Tassa al re: %d oro %s" % [dovuto, "a fine stagione" if quando == 0 else "tra %d stagion%s, in autunno" % [quando, "e" if quando == 1 else "i"]]
		_numeri.re.add_theme_color_override("font_color", COLORE_ERRORE if GameState.risorse.oro < dovuto else TESTO)
	_numeri.felicita.text = str(int(GameState.felicita))
	_numeri.felicita.tooltip_text = "Felicità: %d/100\nSotto 35 la gente se ne va" % int(GameState.felicita)
	_allarme.visible = not GameState.banditi.is_empty()
	if _allarme.visible:
		var dif: Dictionary = GameState.difesa()
		_allarme.text = "Banditi da %s tra %d giorni · loro %d, noi %d" % [GameState.banditi.da, int(GameState.banditi.mancano),
			roundi(GameState.banditi.forza), roundi(dif.totale)]
	_numeri.felicita.add_theme_color_override("font_color", COLORE_ERRORE if GameState.felicita < 35.0 else TESTO)
	(_icone.felicita.get_child(0) as IconaRisorsa).imposta_valore(GameState.felicita)
	_tempo.text = "%s, anno %d" % [GameState.STAGIONI[GameState.stagione], GameState.anno]
	for i in _velocita.size():
		_velocita[i].set_pressed_no_signal(i == GameState.velocita)
	if GameState.evento_attivo.is_empty():
		_carta.visible = false
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


func _da_mostrare(r: String) -> bool:
	if r in ["legna", "pietra", "cibo", "oro"]:
		return true
	if GameState.risorse.get(r, 0.0) >= 1.0:
		return true
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
		return
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
	var tipi: Array[String] = []
	for tipo in GameState.edifici:
		if GameState.edifici[tipo].categoria == _categoria_aperta:
			tipi.append(tipo)
	if _categoria_aperta == "difese":
		tipi.append(MURA)
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
			b.tooltip_text = "" if not b.disabled else "Serve il livello %s" % GameState.bil.livelli[dal].nome
			continue
		var d: Dictionary = GameState.edifici[tipo]
		if GameState.sbloccato(tipo):
			b.text = "%s  ·  %s" % [d.nome, GameState.testo_costo(tipo)]
			b.disabled = not GameState.puo_permettersi(tipo)
			b.tooltip_text = "" if not b.disabled else "Non hai abbastanza risorse"
		else:
			b.text = "%s  (serve %s)" % [d.nome, GameState.bil.livelli[int(d.livello)].nome]
			b.disabled = true
			b.tooltip_text = "Serve il livello %s" % GameState.bil.livelli[int(d.livello)].nome


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
	_btn_chiudi.visible = true
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
		else:
			_dettagli.text = _strada_testo
			_btn_ok.visible = true
			_btn_ok.disabled = not _strada_valida
			_btn_ok.tooltip_text = "" if _strada_valida else "Percorso non valido: controlla il messaggio sotto"
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
		var puo := _piazzamento_valido and GameState.puo_permettersi(_piazzamento)
		_btn_ok.disabled = not puo
		_btn_ok.tooltip_text = "" if puo else ("Posizione non valida" if not _piazzamento_valido else "Non hai abbastanza risorse")
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
	if d.get("a_fine_stagione", false):
		var pronto: Dictionary = b.get("pronto", {})
		var parti: Array[String] = []
		for r in pronto:
			if float(pronto[r]) >= 1.0:
				parti.append("%d %s" % [int(pronto[r]), NOMI_RISORSE.get(r, r).to_lower()])
		testo += "\nRaccolto finora: %s · arriva in magazzino a fine stagione" % (", ".join(parti) if not parti.is_empty() else "niente")
	var prossimo := GameState.prossimo_miglioramento(b)
	if not prossimo.is_empty():
		_btn_migliora.visible = true
		_btn_migliora.text = "Migliora (%s)" % GameState._elenco(prossimo.costo)
		_btn_migliora.disabled = not GameState.puo_migliorare(b)
		_btn_migliora.tooltip_text = "" if not _btn_migliora.disabled else "Non hai abbastanza risorse"
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
		_btn_piu.tooltip_text = "" if not _btn_piu.disabled else ("Tutti i posti sono occupati" if b.lavoratori >= int(d.lavoratori) else "Nessun disoccupato disponibile")
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

func _crea_tutorial() -> void:
	# Ancorato in alto a destra, con margine destro (niente più offset_right = -54)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mc.add_theme_constant_override("margin_right", MARGINE + 50)  # lascia spazio ai bottoni di destra
	mc.add_theme_constant_override("margin_top", MARGINE + 26)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(mc)
	_tutorial = PanelContainer.new()
	_tutorial.add_theme_stylebox_override("panel", _riquadro(Color("e9dcbc"), Color("6b4a2e"), 4))
	_tutorial.custom_minimum_size.x = 130
	_tutorial.visible = false
	mc.add_child(_tutorial)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 130
	col.add_theme_constant_override("separation", 1)
	_tutorial.add_child(col)
	var inchiostro := Color("3b2a1e")
	_tutorial_titolo = Label.new()
	_tutorial_titolo.add_theme_color_override("font_color", Color("7a4a2a"))
	_tutorial_titolo.add_theme_font_size_override("font_size", 7)
	col.add_child(_tutorial_titolo)
	_tutorial_testo = Label.new()
	_tutorial_testo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_testo.custom_minimum_size.x = 130
	_tutorial_testo.add_theme_color_override("font_color", inchiostro)
	_tutorial_testo.add_theme_font_size_override("font_size", 6)
	col.add_child(_tutorial_testo)
	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(riga)
	var salta := _bottone("Salta", 0, 12, "Salta il tutorial")
	salta.pressed.connect(func(): GameState.salta_tutorial())
	riga.add_child(salta)
	_tutorial_avanti = _bottone("Avanti", 0, 12, "Vai al passo successivo")
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


# --- Carte evento ----------------------------------------------------------------

func _crea_carta() -> void:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radice.add_child(centro)
	_carta = PanelContainer.new()
	_carta.add_theme_stylebox_override("panel", _riquadro(Color("e9dcbc"), Color("6b4a2e"), 6))
	_carta.custom_minimum_size.x = 260
	_carta.visible = false
	centro.add_child(_carta)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
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
			b.tooltip_text = "Non hai abbastanza risorse per questa scelta"
		b.pressed.connect(func():
			_carta.visible = false
			GameState.scegli_evento(i))
		_carta_scelte.add_child(b)
	if GameState.evento_senza_scelta():
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
