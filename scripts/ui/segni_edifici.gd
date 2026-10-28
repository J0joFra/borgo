class_name SegniEdifici
extends Control
## I segni sopra gli edifici, disegnati sopra la mappa 3D:
## - un anello che si riempie fino alla prossima consegna del raccolto, con l'icona della risorsa;
## - un anello col martello per i cantieri;
## - una freccia verde se l'edificio si può migliorare adesso (si tocca per aprirlo);
## - un segnale rosso se l'edificio non è collegato alle strade (si tocca per collegarlo).

const RAGGIO := 7.0       # raggio dell'anello, in pixel della base 480×270
const PICCOLO := 4.6      # raggio dei segni tondi (freccia, strada)
const SFONDO := Color(0.08, 0.09, 0.11, 0.78)
const ORO := Color("e8c060")
const VERDE := Color("4cc46a")
const ROSSO := Color("e0503c")

var camera: Camera3D
var vista: VistaTerreno
var _icone: Dictionary = {}    # id edificio -> IconaRisorsa dentro l'anello
var _tocchi: Array = []        # [centro, raggio, "migliora"|"collega", id] dell'ultimo disegno


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Il segno toccato in questo punto dello schermo: {"azione": "migliora"|"collega", "id": id} o {}.
func segno_a(punto: Vector2) -> Dictionary:
	for t in _tocchi:
		if punto.distance_to(t[0]) <= float(t[1]) + 3.0:
			return {"azione": t[2], "id": t[3]}
	return {}


func _draw() -> void:
	_tocchi = []
	var usate := {}
	if camera == null or vista == null or not visible:
		_nascondi_icone(usate)
		return
	var schermo := get_viewport_rect().size
	for b in GameState.buildings:
		var d := GameState.def_di(b)
		var taglia := GameState.taglia_di(b)
		var sopra := vista.centro_area(b.cella, taglia) + Vector3(0, VistaTerreno.CELLA * (1.2 + 0.25 * maxi(taglia.x, taglia.y)), 0)
		if camera.is_position_behind(sopra):
			continue
		var p := camera.unproject_position(sopra)
		if p.x < -20 or p.y < -20 or p.x > schermo.x + 20 or p.y > schermo.y + 20:
			continue
		if b.progresso < 1.0:
			_anello(p, b.progresso, ORO)
			_martello(p)
			continue
		var stagionale: bool = d.get("a_fine_stagione", false) and int(b.lavoratori) > 0
		if stagionale:
			_anello(p, _avanzamento(), ORO)
			var r: String = d.get("produce", {}).keys()[0] if not d.get("produce", {}).is_empty() else ""
			_icona(b.id, r, p, usate)
		var lato := p + Vector2(RAGGIO + 2.0, -RAGGIO + 1.0) if stagionale else p
		if GameState.puo_migliorare(b):
			_freccia(lato)
			_tocchi.append([lato, PICCOLO, "migliora", b.id])
			lato += Vector2(0, PICCOLO * 2.0 + 1.5)
		if int(d.get("lavoratori", 0)) > 0 and not GameState.collegato(b):
			var q := lato if stagionale or GameState.puo_migliorare(b) else p
			_strada_mancante(q)
			_tocchi.append([q, PICCOLO, "collega", b.id])
	_nascondi_icone(usate)


## Quanto manca alla prossima consegna (0 appena consegnato, 1 alla consegna).
func _avanzamento() -> float:
	var meta := int(GameState.bil.tick_per_stagione) / 2
	var inizio := 0 if GameState.tick_in_stagione < meta else meta
	return clampf(float(GameState.tick_in_stagione - inizio) / float(GameState.prossima_consegna() - inizio), 0.0, 1.0)


func _anello(p: Vector2, quota: float, colore: Color) -> void:
	draw_circle(p, RAGGIO + 1.4, SFONDO)
	draw_arc(p, RAGGIO, 0.0, TAU, 32, Color(1, 1, 1, 0.15), 1.6, true)
	if quota > 0.0:
		draw_arc(p, RAGGIO, -PI / 2.0, -PI / 2.0 + TAU * quota, 32, colore, 1.6, true)


func _icona(id: int, risorsa: String, p: Vector2, usate: Dictionary) -> void:
	usate[id] = true
	var ic: IconaRisorsa = _icone.get(id)
	if ic == null or ic.tipo != risorsa:
		if ic:
			ic.queue_free()
		ic = IconaRisorsa.new(risorsa, RAGGIO * 1.3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		_icone[id] = ic
	ic.visible = true
	ic.size = Vector2.ONE * RAGGIO * 1.3
	ic.position = p - ic.size / 2.0


func _nascondi_icone(usate: Dictionary) -> void:
	for id in _icone.keys():
		if not usate.has(id):
			_icone[id].queue_free()
			_icone.erase(id)


func _martello(p: Vector2) -> void:
	draw_line(p + Vector2(-2.6, 2.6), p + Vector2(1.2, -1.2), Color("c89a60"), 1.3)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-0.4, -3.2), p + Vector2(1.6, -3.6),
		p + Vector2(3.4, -1.8), p + Vector2(2.8, -0.6), p + Vector2(0.6, -1.0)]), Color("d8dce0"))


func _freccia(p: Vector2) -> void:
	draw_circle(p, PICCOLO + 0.8, SFONDO)
	draw_circle(p, PICCOLO, VERDE)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3.0), p + Vector2(2.8, 0.2),
		p + Vector2(1.0, 0.2), p + Vector2(1.0, 2.8), p + Vector2(-1.0, 2.8), p + Vector2(-1.0, 0.2),
		p + Vector2(-2.8, 0.2)]), Color.WHITE)


## Un tratto di strada interrotto: manca il collegamento.
func _strada_mancante(p: Vector2) -> void:
	draw_circle(p, PICCOLO + 0.8, SFONDO)
	draw_circle(p, PICCOLO, ROSSO)
	draw_line(p + Vector2(-3.0, 1.6), p + Vector2(-0.8, 1.6), Color.WHITE, 1.2)
	draw_line(p + Vector2(0.8, 1.6), p + Vector2(3.0, 1.6), Color.WHITE, 1.2)
	draw_line(p + Vector2(0, -3.0), p + Vector2(0, -0.6), Color.WHITE, 1.2)
	draw_circle(p + Vector2(0, 0.4), 0.6, Color.WHITE)
