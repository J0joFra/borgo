class_name IconaRisorsa
extends Control
## Un simbolino disegnato in codice per ogni risorsa (legna, pietra, cibo...), per le persone
## e per la felicità, così si riconoscono a colpo d'occhio nella barra, nel mercato e nelle carte.
## Disegnato su una griglia di 10×10 pixel della base 480×270.

const LATO := 10.0

# --- palette condivisa -------------------------------------------------------
const C_OMBRA       := Color(0.0, 0.0, 0.0, 0.18)
const C_CONTORNO    := Color("2a2018")
const C_LEGNA_SCURA := Color("6b4320")
const C_LEGNA       := Color("8b5a2b")
const C_LEGNA_CHIARA:= Color("b07a45")
const C_PIETRA_SCURA:= Color("6e6e6e")
const C_PIETRA      := Color("9a9a9a")
const C_PIETRA_CHIARA:=Color("cfcfcf")
const C_FERRO_SCURO := Color("3a4454")
const C_FERRO       := Color("5a6778")
const C_FERRO_CHIARO:=Color("9aa8bc")
const C_ORO_SCURO   := Color("8a6410")
const C_ORO         := Color("e5b53a")
const C_ORO_CHIARO  := Color("f7dc7a")
const C_VERDE_SCURO := Color("3f6b28")
const C_VERDE       := Color("5a9a3a")
const C_VERDE_CHIARO:= Color("8cc65a")
const C_ROSSO_SCURO := Color("8f2418")
const C_ROSSO       := Color("c0392b")
const C_ROSSO_CHIARO:=Color("e06a5a")
const C_GRANO       := Color("e0b84a")
const C_ORZO        := Color("d8c070")
const C_RAPA        := Color("8a5a9a")

var tipo := ""
var valore := 50.0  # per la faccina della felicità: 0..100


func _init(t := "", lato := LATO) -> void:
	tipo = t
	custom_minimum_size = Vector2(lato, lato)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = GameState.nome_risorsa(t)


const NOMI := {
	"legna": "Legna", "pietra": "Pietra", "cibo": "Cibo", "grano": "Grano", "orzo": "Orzo", "rape": "Rape",
	"semi_orzo": "Semi d'orzo", "semi_grano": "Semi di grano", "semi_rape": "Semi di rapa",
	"ferro": "Ferro", "utensili": "Utensili", "armi": "Armi", "oro": "Oro", "farina": "Farina", "pane": "Pane",
	"re": "Il re",
	"abitanti": "Abitanti / posti letto", "disponibili": "Persone senza lavoro", "felicita": "Felicità",
}


## Il disegno da usare per questa risorsa nel clima della partita (es. "rape" nel deserto: "datteri").
func tipo_disegno() -> String:
	return GameState.icona_di(tipo)


func imposta_valore(v: float) -> void:
	if not is_equal_approx(v, valore):
		valore = v
		queue_redraw()


func _draw() -> void:
	# tutto è disegnato su 10×10 e scalato alla misura del controllo
	var k := minf(size.x, size.y) / LATO
	draw_set_transform((size - Vector2.ONE * LATO * k) / 2.0, 0.0, Vector2(k, k))
	_ombra()
	match GameState.icona_di(tipo):
		"datteri":
			# un grappolo di datteri su un rametto
			draw_line(Vector2(5, 0.8), Vector2(5, 3.4), C_LEGNA_SCURA, 0.8)
			for p in [Vector2(3.4, 4.2), Vector2(6.6, 4.2), Vector2(5, 5.0), Vector2(3.0, 6.6), Vector2(7.0, 6.6), Vector2(5, 7.4), Vector2(4.0, 8.8), Vector2(6.0, 8.8)]:
				draw_circle(p, 1.25, Color("7a3a1e"))
				draw_circle(p - Vector2(0.4, 0.4), 0.45, Color("b0603a"))
		"banane":
			# un casco di banane gialle
			for i in 3:
				var off := float(i - 1) * 1.8
				var punti := PackedVector2Array()
				for passo in 7:
					var t := float(passo) / 6.0
					punti.append(Vector2(2.6 + off + t * 4.4, 8.4 - sin(t * PI) * 3.6 - t * 3.0))
				draw_polyline(punti, Color("e8c838"), 1.7, true)
			draw_line(Vector2(7.2, 2.4), Vector2(8.2, 1.2), Color("6a5a2a"), 0.9)
		"olive":
			draw_line(Vector2(1.6, 2.2), Vector2(8.6, 5.4), C_LEGNA_SCURA, 0.6)
			_poligono([Vector2(3.2, 2.6), Vector2(5.4, 1.6), Vector2(4.6, 3.6)], C_VERDE)
			for p in [Vector2(3.6, 5.6), Vector2(6.2, 7.0), Vector2(7.6, 4.4)]:
				draw_circle(p, 1.35, Color("4a5a2a"))
				draw_circle(p - Vector2(0.4, 0.4), 0.45, Color("8a9a5a"))
		"girasoli":
			draw_line(Vector2(5, 9.6), Vector2(5, 5), C_VERDE_SCURO, 0.9)
			for petalo in 10:
				var a := TAU * petalo / 10.0
				draw_circle(Vector2(5, 4.4) + Vector2.from_angle(a) * 2.6, 1.0, Color("f0c020"))
			draw_circle(Vector2(5, 4.4), 1.9, Color("6a3a1a"))
			draw_circle(Vector2(4.6, 4.0), 0.5, Color("9a6a3a"))
		"cristalli", "gemme":
			var c := Color("a0d0ff") if tipo_disegno() == "cristalli" else Color("e070c0")
			_poligono([Vector2(5, 0.8), Vector2(7.6, 4.0), Vector2(5, 9.2), Vector2(2.4, 4.0)], c)
			_poligono([Vector2(5, 0.8), Vector2(5, 9.2), Vector2(2.4, 4.0)], c.lightened(0.3))
			_poligono([Vector2(7.2, 5.6), Vector2(9.2, 7.2), Vector2(8.0, 9.4), Vector2(6.6, 8.0)], c.darkened(0.2))
		"frutti":
			for p in [Vector2(3.6, 6.0), Vector2(6.6, 6.4), Vector2(5.0, 3.8)]:
				draw_circle(p, 2.0, Color("ff9a5a"))
				draw_circle(p - Vector2(0.6, 0.6), 0.6, Color("ffd0a0"))
		"cenere":
			_poligono([Vector2(1, 9), Vector2(3.4, 5.0), Vector2(5.6, 6.0), Vector2(7.4, 4.2), Vector2(9.2, 9)], Color("5a5a5a"))
			draw_circle(Vector2(4.2, 7.6), 0.6, Color("e05a2a"))
			draw_circle(Vector2(6.8, 7.2), 0.5, Color("f08a3a"))
		"grano nero":
			_spiga(Color("4a3a3a"))
		"radici":
			draw_line(Vector2(5, 1), Vector2(5, 5), Color("8a5a3a"), 1.2)
			for d in [Vector2(-3, 4), Vector2(3, 4), Vector2(-1.2, 4.6), Vector2(1.6, 4.4)]:
				draw_line(Vector2(5, 5), Vector2(5, 5) + d, Color("a06a3a"), 0.8)
			draw_circle(Vector2(5, 2.2), 1.2, Color("e05a2a"))
		"spore":
			for p in [Vector2(3, 3), Vector2(6.6, 2.6), Vector2(4.6, 6), Vector2(7.6, 6.8), Vector2(2.4, 7.8)]:
				draw_circle(p, 1.1, Color("c8a0e0"))
				draw_circle(p, 0.45, Color("f0e0ff"))
		"funghi":
			draw_rect(Rect2(4.0, 5.0, 2.0, 4.2), Color("e8e0d0"))
			_poligono([Vector2(1, 5.4), Vector2(2.4, 2.2), Vector2(5, 1.2), Vector2(7.6, 2.2), Vector2(9, 5.4)], Color("c03a3a"))
			draw_circle(Vector2(3.6, 3.4), 0.6, Color.WHITE)
			draw_circle(Vector2(6.4, 3.0), 0.5, Color.WHITE)
		"arachidi":
			# due baccelli di arachide
			for c in [Vector2(3.6, 4.0), Vector2(6.4, 6.4)]:
				draw_circle(c + Vector2(-1.0, -0.8), 1.6, Color("c8a070"))
				draw_circle(c + Vector2(1.0, 0.8), 1.6, Color("c8a070"))
				draw_circle(c, 1.1, Color("b08a5a"))
				draw_circle(c + Vector2(-1.4, -1.2), 0.5, Color("e0c090"))
		"ceci":
			for p in [Vector2(3, 4), Vector2(6.6, 3.6), Vector2(4.6, 7), Vector2(7.6, 7.2), Vector2(2.6, 7.6)]:
				draw_circle(p, 1.5, Color("c8a868"))
				draw_circle(p - Vector2(0.4, 0.4), 0.6, Color("ecd8a8"))
				draw_circle(p + Vector2(0.6, -0.6), 0.25, Color("8a6a3a"))
		"legna":
			_tronco(Vector2(1.0, 5.4), C_LEGNA)
			_tronco(Vector2(2.4, 2.4), C_LEGNA_CHIARA)
		"pietra":
			# masso sfaccettato
			_poligono([Vector2(1, 8.6), Vector2(1.6, 4.2), Vector2(4.6, 1.8),
					   Vector2(8.4, 3.2), Vector2(9.2, 8.6)], C_PIETRA)
			_poligono([Vector2(1.6, 4.2), Vector2(4.6, 1.8), Vector2(5.6, 4.6),
					   Vector2(2.8, 6.2)], C_PIETRA_CHIARA)
			_poligono([Vector2(5.6, 4.6), Vector2(8.4, 3.2), Vector2(9.2, 8.6),
					   Vector2(6.0, 8.0)], C_PIETRA_SCURA)
			draw_line(Vector2(5.6, 4.6), Vector2(6.0, 8.0), C_CONTORNO, 0.4)
		"cibo":
			# mela con foglia e riflesso
			draw_circle(Vector2(5, 6), 3.5, C_ROSSO)
			draw_circle(Vector2(6.1, 6.6), 2.6, C_ROSSO_SCURO)
			draw_circle(Vector2(4.0, 5.0), 1.1, C_ROSSO_CHIARO)
			draw_line(Vector2(5, 3), Vector2(5.5, 1.2), Color("5a3a1a"), 1.0)
			_poligono([Vector2(5.5, 2.2), Vector2(8.2, 1.0), Vector2(7.2, 3.0)], C_VERDE)
			draw_line(Vector2(5.6, 2.1), Vector2(7.4, 1.4), C_VERDE_CHIARO, 0.5)
		"grano", "orzo", "semi_grano", "semi_orzo":
			var c := C_GRANO if tipo.ends_with("grano") else C_ORZO
			if tipo.begins_with("semi"):
				_semi(c)
			else:
				_spiga(c)
		"rape", "semi_rape":
			if tipo == "semi_rape":
				_semi(Color("b07ac0"))
			else:
				# foglie verdi con venatura
				_poligono([Vector2(2.4, 1.2), Vector2(4.0, 0.4), Vector2(5.2, 4.2)], C_VERDE)
				_poligono([Vector2(7.6, 1.2), Vector2(6.0, 0.4), Vector2(4.8, 4.2)], C_VERDE_CHIARO)
				draw_line(Vector2(3.4, 1.2), Vector2(4.8, 3.8), C_VERDE_SCURO, 0.4)
				draw_line(Vector2(6.6, 1.2), Vector2(5.0, 3.8), C_VERDE_SCURO, 0.4)
				# bulbo
				draw_circle(Vector2(5, 6.3), 3.0, C_RAPA)
				draw_circle(Vector2(5, 7.4), 2.2, Color("f0e8dc"))
				draw_circle(Vector2(4.2, 6.0), 0.8, C_RAPA.lightened(0.35))
				draw_line(Vector2(5, 9.2), Vector2(5, 10), Color("e8e0d8"), 1.0)
		"ferro":
			# lingotto con riflesso
			_poligono([Vector2(1, 8.2), Vector2(2.4, 4.0), Vector2(7.6, 4.0),
					   Vector2(9, 8.2)], C_FERRO)
			_poligono([Vector2(2.4, 4.0), Vector2(7.6, 4.0), Vector2(7.0, 5.0),
					   Vector2(3.0, 5.0)], C_FERRO_CHIARO)
			draw_line(Vector2(2.6, 5.4), Vector2(7.4, 5.4), C_FERRO_SCURO, 0.6)
			draw_line(Vector2(3.0, 6.6), Vector2(4.6, 6.6), C_FERRO_CHIARO, 0.6)
		"utensili":
			# martello
			draw_line(Vector2(2.2, 8.8), Vector2(6.4, 4.6), C_LEGNA_SCURA, 1.6)
			draw_line(Vector2(2.4, 8.6), Vector2(6.2, 4.8), C_LEGNA_CHIARA, 0.6)
			_poligono([Vector2(4.0, 2.0), Vector2(7.0, 1.0), Vector2(9.0, 3.0),
					   Vector2(8.0, 5.8), Vector2(6.4, 4.6)], C_FERRO_CHIARO)
			_poligono([Vector2(4.0, 2.0), Vector2(7.0, 1.0), Vector2(7.0, 2.2),
					   Vector2(4.6, 3.0)], Color("c8ccd0").lightened(0.15))
			draw_line(Vector2(4.2, 2.6), Vector2(8.2, 3.4), C_FERRO_SCURO, 0.5)
		"armi":
			# spada: lama, guardia, impugnatura, pomolo
			_poligono([Vector2(8.8, 0.6), Vector2(9.4, 1.2), Vector2(4.0, 6.6),
					   Vector2(3.4, 6.0)], Color("d8dce0"))
			draw_line(Vector2(8.9, 1.0), Vector2(4.0, 5.9), Color("f2f4f8"), 0.5)
			draw_line(Vector2(4.0, 6.6), Vector2(8.8, 0.6), C_CONTORNO, 0.35)
			draw_line(Vector2(2.0, 4.6), Vector2(5.4, 8.0), C_ORO_SCURO, 1.4)
			draw_line(Vector2(2.1, 4.7), Vector2(5.3, 7.9), C_ORO_CHIARO, 0.5)
			draw_line(Vector2(3.7, 6.3), Vector2(1.4, 8.6), C_LEGNA_SCURA, 1.3)
			draw_circle(Vector2(1.2, 8.8), 0.9, C_ORO)
			draw_circle(Vector2(1.2, 8.8), 0.45, C_ORO_CHIARO)
		"oro":
			draw_circle(Vector2(5, 5), 4.0, C_ORO_SCURO)
			draw_circle(Vector2(5, 5), 3.4, C_ORO)
			draw_circle(Vector2(4.2, 4.2), 1.6, C_ORO_CHIARO)
			draw_line(Vector2(5, 3), Vector2(5, 7), C_ORO_SCURO, 1.0)
			draw_line(Vector2(3, 5), Vector2(7, 5), C_ORO_SCURO, 1.0)
		"re":
			# corona con gemme e riflesso
			_poligono([Vector2(1, 8.2), Vector2(1, 3.0), Vector2(3, 5.6),
					   Vector2(5, 1.8), Vector2(7, 5.6), Vector2(9, 3.0),
					   Vector2(9, 8.2)], C_ORO)
			draw_line(Vector2(1, 3.0), Vector2(5, 1.8), C_ORO_CHIARO, 0.6)
			draw_line(Vector2(5, 1.8), Vector2(9, 3.0), C_ORO_CHIARO, 0.6)
			draw_rect(Rect2(1, 7.0, 8, 1.6), C_ORO_SCURO)
			draw_line(Vector2(1.2, 7.4), Vector2(8.8, 7.4), C_ORO_CHIARO, 0.4)
			draw_circle(Vector2(5, 6.0), 1.0, C_ROSSO)
			draw_circle(Vector2(5, 5.7), 0.4, C_ROSSO_CHIARO)
			draw_circle(Vector2(3, 6.2), 0.55, Color("4a80c0"))
			draw_circle(Vector2(7, 6.2), 0.55, Color("4a80c0"))
		"abitanti":
			_persona(Vector2(3.4, 0), Color("6a7a9a"), true)
			_persona(Vector2(6.6, 1.0), Color("7a4a3a"), false)
		"disponibili":
			_persona(Vector2(4.5, 0), Color("8a8070"), false)
			draw_circle(Vector2(8, 2.6), 1.9, C_VERDE_SCURO)
			draw_circle(Vector2(8, 2.6), 1.6, C_VERDE_CHIARO)
			draw_line(Vector2(7.2, 2.6), Vector2(8.6, 2.6), C_VERDE_SCURO, 0.5)
			draw_line(Vector2(8.0, 1.8), Vector2(8.0, 3.4), C_VERDE_SCURO, 0.5)
		"felicita":
			_faccina()
		_:
			draw_rect(Rect2(2, 2, 6, 6), Color("c8b48a"))
			draw_rect(Rect2(2, 2, 6, 6), C_CONTORNO, false, 0.4)


# --- disegno ombra -----------------------------------------------------------
func _ombra() -> void:
	# piccola ombra ellittica sotto l'icona, per staccarla dallo sfondo
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ridisegnata in coordinate locali 10×10 → riporto il transform della griglia
	# (la ombra è chiamata prima del transform: la disegno qui dentro la griglia)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# NB: _draw ha già impostato il transform della griglia prima di chiamare _ombra?
	# No: _ombra viene chiamata DOPO draw_set_transform. Quindi siamo già in 10×10.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- helper ------------------------------------------------------------------
func _tronco(p: Vector2, c: Color) -> void:
	# tronco con venature
	draw_rect(Rect2(p, Vector2(7, 2.6)), c)
	draw_rect(Rect2(p, Vector2(7, 2.6)), C_CONTORNO, false, 0.3)
	# venature chiare
	draw_line(p + Vector2(0.6, 0.9), p + Vector2(6.4, 0.9), c.lightened(0.25), 0.4)
	draw_line(p + Vector2(0.6, 1.7), p + Vector2(6.4, 1.7), c.darkened(0.15), 0.4)
	# sezione circolare (anelli)
	draw_circle(p + Vector2(7, 1.3), 1.3, Color("e8c890"))
	draw_circle(p + Vector2(7, 1.3), 1.0, c.darkened(0.1))
	draw_circle(p + Vector2(7, 1.3), 0.55, Color("e8c890"))
	draw_circle(p + Vector2(7, 1.3), 0.25, c.darkened(0.3))


func _spiga(c: Color) -> void:
	# gambo
	draw_line(Vector2(5, 3), Vector2(5, 10), c.darkened(0.35), 1.0)
	# chicchi su due file con leggera sovrapposizione
	for i in 3:
		var y := 2.0 + i * 2.0
		_poligono([Vector2(5, y), Vector2(3, y + 1), Vector2(5, y + 2.5)], c)
		_poligono([Vector2(5, y), Vector2(7, y + 1), Vector2(5, y + 2.5)], c.lightened(0.15))
		# puntino di luce sul chicco
		draw_circle(Vector2(4.2, y + 1.2), 0.25, c.lightened(0.45))
		draw_circle(Vector2(5.8, y + 1.2), 0.25, c.lightened(0.45))
	# punta
	draw_circle(Vector2(5, 1.5), 1.0, c)
	draw_circle(Vector2(5, 1.5), 0.4, c.lightened(0.4))


func _semi(c: Color) -> void:
	for p in [Vector2(3, 4), Vector2(6.5, 3.5), Vector2(4.5, 7), Vector2(7.5, 7)]:
		draw_circle(p, 1.4, c.darkened(0.2))
		draw_circle(p - Vector2(0.3, 0.3), 0.7, c.lightened(0.25))
		draw_circle(p + Vector2(0.4, 0.4), 0.3, c.darkened(0.35))


func _persona(p: Vector2, tunica: Color, cappello: bool) -> void:
	# testa
	draw_circle(p + Vector2(0, 2.2), 1.6, Color("e8b890"))
	draw_circle(p + Vector2(-0.5, 2.0), 0.45, Color("2a2018"))  # capelli
	# corpo (tunica)
	_poligono([p + Vector2(-2.3, 9.5), p + Vector2(-1.3, 4.3),
			   p + Vector2(1.3, 4.3), p + Vector2(2.3, 9.5)], tunica)
	# riflesso sulla tunica
	draw_line(p + Vector2(-1.8, 8.8), p + Vector2(-1.0, 4.8),
			  tunica.lightened(0.25), 0.5)
	# cintura
	draw_line(p + Vector2(-1.9, 7.2), p + Vector2(1.9, 7.2), C_CONTORNO, 0.5)
	if cappello:
		draw_line(p + Vector2(-1.4, 1.0), p + Vector2(1.4, 1.0), C_CONTORNO, 1.0)
		draw_rect(Rect2(p + Vector2(-0.9, 0.2), Vector2(1.8, 1.0)), tunica.darkened(0.3))


func _faccina() -> void:
	var c := C_ROSSO
	if valore >= 60.0:
		c = C_VERDE_CHIARO
	elif valore >= 35.0:
		c = Color("f2d24b")
	# bordo scuro, faccia, riflesso in alto a sinistra
	draw_circle(Vector2(5, 5), 4.5, c.darkened(0.4))
	draw_circle(Vector2(5, 5), 3.8, c)
	draw_circle(Vector2(3.8, 3.8), 1.4, c.lightened(0.35))
	# occhi con riflesso
	var occhio := Color("2a1e14")
	draw_rect(Rect2(3.1, 3.3, 1.05, 1.4), occhio)
	draw_rect(Rect2(5.85, 3.3, 1.05, 1.4), occhio)
	draw_rect(Rect2(3.35, 3.55, 0.35, 0.4), Color.WHITE)
	draw_rect(Rect2(6.1, 3.55, 0.35, 0.4), Color.WHITE)
	# guance (più visibili quando è felice)
	var intensita_guance := clampf((valore - 40.0) / 60.0, 0.0, 1.0)
	if intensita_guance > 0.01:
		var gc := Color(0.9, 0.35, 0.35, 0.55 * intensita_guance)
		draw_circle(Vector2(2.6, 5.9), 0.8, gc)
		draw_circle(Vector2(7.4, 5.9), 0.8, gc)
	# bocca: curva che va da smorfia a sorriso
	var curva := clampf((valore - 47.0) / 40.0, -1.0, 1.0)
	var punti := PackedVector2Array()
	for i in 7:
		var x := 2.8 + i * 0.73
		var t := (x - 5.0) / 2.2
		var y := 6.6 + curva * (1.0 - t * t) * 1.2
		punti.append(Vector2(x, y))
	draw_polyline(punti, occhio, 0.9)
	# fossette agli angoli della bocca se molto felice
	if valore >= 75.0:
		draw_circle(Vector2(2.9, 6.4), 0.25, occhio)
		draw_circle(Vector2(7.1, 6.4), 0.25, occhio)


func _poligono(punti: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(punti), c)
