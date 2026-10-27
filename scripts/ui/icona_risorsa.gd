class_name IconaRisorsa
extends Control
## Un simbolino disegnato in codice per ogni risorsa (legna, pietra, cibo...), per le persone
## e per la felicità, così si riconoscono a colpo d'occhio nella barra, nel mercato e nelle carte.
## Disegnato su una griglia di 10×10 pixel della base 480×270.

const LATO := 10.0

var tipo := ""
var valore := 50.0  # per la faccina della felicità: 0..100


func _init(t := "", lato := LATO) -> void:
	tipo = t
	custom_minimum_size = Vector2(lato, lato)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = NOMI.get(t, t)


const NOMI := {
	"legna": "Legna", "pietra": "Pietra", "cibo": "Cibo", "grano": "Grano", "orzo": "Orzo", "rape": "Rape",
	"semi_orzo": "Semi d'orzo", "semi_grano": "Semi di grano", "semi_rape": "Semi di rapa",
	"ferro": "Ferro", "utensili": "Utensili", "armi": "Armi", "oro": "Oro", "farina": "Farina", "pane": "Pane",
	"re": "Il re",
	"abitanti": "Abitanti / posti letto", "disponibili": "Persone senza lavoro", "felicita": "Felicità",
}


func imposta_valore(v: float) -> void:
	if not is_equal_approx(v, valore):
		valore = v
		queue_redraw()


func _draw() -> void:
	# tutto è disegnato su 10×10 e scalato alla misura del controllo
	var k := minf(size.x, size.y) / LATO
	draw_set_transform((size - Vector2.ONE * LATO * k) / 2.0, 0.0, Vector2(k, k))
	match tipo:
		"legna":
			_tronco(Vector2(1, 5.5), Color("8b5a2b"))
			_tronco(Vector2(2.5, 2.5), Color("a06a35"))
		"pietra":
			_poligono([Vector2(1, 8.5), Vector2(2, 4), Vector2(5, 2), Vector2(8.5, 3.5), Vector2(9, 8.5)], Color("9a9a9a"))
			_poligono([Vector2(2, 4), Vector2(5, 2), Vector2(6, 5), Vector2(3, 6)], Color("c4c4c4"))
		"cibo":
			draw_circle(Vector2(5, 6), 3.5, Color("c0392b"))
			draw_circle(Vector2(4, 5), 1.0, Color("e06a5a"))
			draw_line(Vector2(5, 3), Vector2(5.5, 1), Color("5a3a1a"), 1.0)
			_poligono([Vector2(5.5, 2), Vector2(8, 1), Vector2(7, 3)], Color("5a9a3a"))
		"grano", "orzo", "semi_grano", "semi_orzo":
			var c := Color("e0b84a") if tipo.ends_with("grano") else Color("d8c070")
			if tipo.begins_with("semi"):
				_semi(c)
			else:
				_spiga(c)
		"rape", "semi_rape":
			if tipo == "semi_rape":
				_semi(Color("b07ac0"))
			else:
				_poligono([Vector2(2.5, 1), Vector2(4, 0.5), Vector2(5.2, 4)], Color("5a9a3a"))
				_poligono([Vector2(7.5, 1), Vector2(6, 0.5), Vector2(4.8, 4)], Color("6aaa4a"))
				draw_circle(Vector2(5, 6.3), 3.0, Color("8a5a9a"))
				draw_circle(Vector2(5, 7.3), 2.2, Color("e8e0d8"))
				draw_line(Vector2(5, 9), Vector2(5, 10), Color("e8e0d8"), 1.0)
		"ferro":
			_poligono([Vector2(1, 8), Vector2(2.5, 4), Vector2(7.5, 4), Vector2(9, 8)], Color("4a5568"))
			_poligono([Vector2(2.5, 4), Vector2(7.5, 4), Vector2(7, 5), Vector2(3, 5)], Color("7a8598"))
		"utensili":
			draw_line(Vector2(2, 9), Vector2(6.5, 4.5), Color("8b5a2b"), 1.5)
			_poligono([Vector2(4, 2), Vector2(7, 1), Vector2(9, 3), Vector2(8, 6), Vector2(6.5, 4.5)], Color("c8ccd0"))
		"armi":
			# una spada: lama, guardia, impugnatura
			_poligono([Vector2(8.6, 0.8), Vector2(9.2, 1.4), Vector2(4, 6.6), Vector2(3.4, 6)], Color("d8dce0"))
			draw_line(Vector2(2.2, 4.6), Vector2(5.4, 7.8), Color("a8801a"), 1.2)
			draw_line(Vector2(3.6, 6.4), Vector2(1.4, 8.6), Color("5a3a1a"), 1.3)
			draw_circle(Vector2(1.2, 8.8), 0.8, Color("a8801a"))
		"oro":
			draw_circle(Vector2(5, 5), 4.0, Color("a8801a"))
			draw_circle(Vector2(5, 5), 3.2, Color("e5b53a"))
			draw_line(Vector2(5, 3), Vector2(5, 7), Color("a8801a"), 1.0)
		"re":
			# una corona
			_poligono([Vector2(1, 8), Vector2(1, 3), Vector2(3, 5.5), Vector2(5, 2), Vector2(7, 5.5), Vector2(9, 3), Vector2(9, 8)], Color("e5b53a"))
			draw_rect(Rect2(1, 7, 8, 1.6), Color("a8801a"))
			draw_circle(Vector2(5, 6), 0.8, Color("c0392b"))
		"abitanti":
			_persona(Vector2(3.5, 0), Color("6a7a9a"))
			_persona(Vector2(6.5, 1), Color("7a4a3a"))
		"disponibili":
			_persona(Vector2(4.5, 0), Color("8a8070"))
			draw_circle(Vector2(8, 2.5), 1.8, Color("9fd18b"))
		"felicita":
			_faccina()
		_:
			draw_rect(Rect2(2, 2, 6, 6), Color("c8b48a"))


func _tronco(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p, Vector2(7, 2.6)), c)
	draw_circle(p + Vector2(7, 1.3), 1.3, Color("e0b884"))
	draw_circle(p + Vector2(7, 1.3), 0.5, c.darkened(0.2))


func _spiga(c: Color) -> void:
	draw_line(Vector2(5, 3), Vector2(5, 10), c.darkened(0.3), 1.0)
	for i in 3:
		var y := 2.0 + i * 2.0
		_poligono([Vector2(5, y), Vector2(3, y + 1), Vector2(5, y + 2.5)], c)
		_poligono([Vector2(5, y), Vector2(7, y + 1), Vector2(5, y + 2.5)], c.lightened(0.15))
	draw_circle(Vector2(5, 1.5), 1.0, c)


func _semi(c: Color) -> void:
	for p in [Vector2(3, 4), Vector2(6.5, 3.5), Vector2(4.5, 7), Vector2(7.5, 7)]:
		draw_circle(p, 1.4, c.darkened(0.15))
		draw_circle(p - Vector2(0.4, 0.4), 0.5, c.lightened(0.3))


func _persona(p: Vector2, tunica: Color) -> void:
	draw_circle(p + Vector2(0, 2.2), 1.6, Color("e0b08a"))
	_poligono([p + Vector2(-2.3, 9.5), p + Vector2(-1.3, 4.3), p + Vector2(1.3, 4.3), p + Vector2(2.3, 9.5)], tunica)


func _faccina() -> void:
	var c := Color("e35b4a")
	if valore >= 60.0:
		c = Color("8cc65a")
	elif valore >= 35.0:
		c = Color("f2d24b")
	draw_circle(Vector2(5, 5), 4.5, c.darkened(0.35))
	draw_circle(Vector2(5, 5), 3.8, c)
	var occhio := Color("3b2a1e")
	draw_rect(Rect2(3.2, 3.3, 1, 1.3), occhio)
	draw_rect(Rect2(5.8, 3.3, 1, 1.3), occhio)
	# la bocca va dal sorriso alla smorfia
	var curva := clampf((valore - 47.0) / 40.0, -1.0, 1.0)
	var punti := PackedVector2Array()
	for i in 5:
		var x := 3.0 + i
		var t := (x - 5.0) / 2.0
		punti.append(Vector2(x, 6.6 + curva * (1.0 - t * t) * 1.2))
	draw_polyline(punti, occhio, 0.9)


func _poligono(punti: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(punti), c)
