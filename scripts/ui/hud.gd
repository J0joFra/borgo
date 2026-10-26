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
signal chiudi_pannello
signal ruota(direzione: int)
signal vai_al_regno
signal nuova_partita

const CATEGORIE := [["Case", "case"], ["Risorse", "risorse"], ["Cibo", "cibo"], ["Servizi", "servizi"]]
const COLORI := {
	"legna": Color("8b5a2b"), "pietra": Color("9a9a9a"), "cibo": Color("c0392b"), "grano": Color("e0b84a"),
	"ferro": Color("4a5568"), "utensili": Color("c8ccd0"), "oro": Color("e5b53a"),
	"abitanti": Color("e8c39e"), "felicita": Color("f2d24b"),
}
const TESTO := Color("f3e3c3")
const TESTO_ALLARME := Color("ff6b5b")

var _radice: Control
var _numeri: Dictionary = {}  # chiave -> Label nella barra in alto
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
var _tempo_avviso := 0.0
var _fine: PanelContainer
var _fine_titolo: Label
var _fine_testo: Label

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
	_crea_menu()
	_crea_pannello()
	_crea_info()
	_crea_consiglio()
	_crea_avviso()
	_crea_fine()
	GameState.changed.connect(_aggiorna)
	GameState.season_changed.connect(func(_s, _a): _aggiorna())
	GameState.message.connect(mostra_avviso)
	GameState.consiglio.connect(_nuovo_consiglio)
	GameState.game_ended.connect(_mostra_fine)
	_aggiorna()


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
	_edificio = id
	_piazzamento = ""
	_chiudi_menu()
	_aggiorna_pannello()


func mostra_piazzamento(tipo: String, valido: bool, stima := "") -> void:
	_piazzamento = tipo
	_piazzamento_valido = valido
	_stima_piazzamento = stima
	_edificio = -1
	_aggiorna_pannello()


func nascondi_pannello() -> void:
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


func _icona(colore: Color) -> Control:
	var c := CenterContainer.new()
	var r := ColorRect.new()
	r.color = colore
	r.custom_minimum_size = Vector2(6, 6)
	c.add_child(r)
	return c


func _crea_barra() -> void:
	var barra := PanelContainer.new()
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_radice.add_child(barra)
	var riga := HBoxContainer.new()
	barra.add_child(riga)
	for chiave in GameState.RISORSE_VISIBILI + ["abitanti", "felicita"]:
		riga.add_child(_icona(COLORI[chiave]))
		var l := Label.new()
		l.custom_minimum_size.x = 22 if chiave != "abitanti" else 30
		riga.add_child(l)
		_numeri[chiave] = l
	var spazio := Control.new()
	spazio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(spazio)
	_tempo = Label.new()
	riga.add_child(_tempo)
	for i in 4:
		var b := _bottone(["||", "x1", "x2", "x3"][i], 16, 12)
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
	_btn_demolisci.pressed.connect(func(): demolisci.emit(_edificio))
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
	for chiave in COLORI:
		legenda.add_child(_icona(COLORI[chiave]))
		var n := Label.new()
		n.text = chiave
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
		var valore: float = GameState.risorse.get(r, 0.0)
		var delta: float = GameState.ultimo_delta.get(r, 0.0)
		_numeri[r].text = str(int(valore))
		# Rosso se al ritmo attuale la risorsa finisce entro 2 stagioni.
		var allarme := delta < 0.0 and valore / -delta < 2.0 * tps
		if r == "cibo" and GameState.tick_fame > 0:
			allarme = true
		_numeri[r].add_theme_color_override("font_color", TESTO_ALLARME if allarme else TESTO)
	_numeri.abitanti.text = "%d/%d" % [GameState.abitanti, GameState.alloggi()]
	_numeri.felicita.text = str(int(GameState.felicita))
	_tempo.text = "%s, anno %d" % [GameState.STAGIONI[GameState.stagione], GameState.anno]
	for i in _velocita.size():
		_velocita[i].set_pressed_no_signal(i == GameState.velocita)
	if _pannello.visible:
		_aggiorna_pannello()
	if _menu.visible:
		_riempi_menu()
	if _info.visible:
		_aggiorna_info()
	if _consiglio.visible:
		_aggiorna_consiglio()


func _imposta_velocita(v: int) -> void:
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
	for x in [_btn_meno, _btn_piu, _btn_migliora, _btn_demolisci, _btn_ok, _btn_annulla, _btn_chiudi]:
		x.visible = false
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
	var prossimo := GameState.prossimo_miglioramento(b)
	if not prossimo.is_empty():
		_btn_migliora.visible = true
		_btn_migliora.text = "Migliora: %s (%s)" % [prossimo.nome, GameState._elenco(prossimo.costo)]
		_btn_migliora.disabled = not GameState.puo_migliorare(b)
	_titolo.text = d.nome
	if int(d.lavoratori) > 0:
		_titolo.text += "  ·  %d/%d lavoratori" % [b.lavoratori, d.lavoratori]
		_btn_meno.visible = true
		_btn_meno.disabled = b.lavoratori == 0
		_btn_piu.visible = true
		_btn_piu.disabled = b.lavoratori >= int(d.lavoratori) or GameState.disoccupati() == 0
	_dettagli.text = testo


func _aggiorna_info() -> void:
	var righe: Array[String] = []
	var livelli: Array = GameState.bil.livelli
	righe.append("Livello: %s" % livelli[GameState.livello].nome)
	if GameState.livello + 1 < livelli.size():
		var manca := GameState.requisiti_mancanti(GameState.livello + 1)
		righe.append("Per diventare %s servono: %s" % [livelli[GameState.livello + 1].nome, ", ".join(manca)])
	righe.append("Abitanti %d (alloggi %d) · al lavoro %d · disoccupati %d" % [
		GameState.abitanti, GameState.alloggi(), GameState.lavoratori_assegnati(), GameState.disoccupati()])
	var fattori := GameState.fattori_felicita()
	var voci: Array[String] = []
	for k in fattori:
		voci.append("%s %+d" % [k, fattori[k]])
	righe.append("Felicità %d → %s" % [int(GameState.felicita), ", ".join(voci)])
	righe.append("Tasse al re in autunno: %d oro · capacità magazzino %d" % [GameState.tassa_del_re(), GameState.capacita()])
	_info_testo.text = "\n".join(righe)
	for i in _tasse.size():
		_tasse[i].set_pressed_no_signal(["basse", "normali", "alte"][i] == GameState.tasse)


func _mostra_fine(vittoria: bool, motivo: String) -> void:
	nascondi_pannello()
	_chiudi_menu()
	_info.visible = false
	_consiglio.visible = false
	_fine_titolo.text = "Vittoria!" if vittoria else "Partita persa"
	_fine_testo.text = motivo
	_fine.visible = true
