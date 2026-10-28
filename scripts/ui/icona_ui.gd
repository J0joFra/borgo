class_name IconaUi
extends Control
## Le icone dei pulsanti dell'interfaccia (costruire, menu, velocità), disegnate in codice a tratto
## chiaro su una griglia 10×10, nello stile scuro e minimale dell'interfaccia.

const LATO := 10.0
const SPESSORE := 0.9

var tipo := ""
var colore := Color("ece6da")


func _init(t := "", lato := 14.0) -> void:
	tipo = t
	custom_minimum_size = Vector2(lato, lato)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var k := minf(size.x, size.y) / LATO
	draw_set_transform((size - Vector2.ONE * LATO * k) / 2.0, 0.0, Vector2(k, k))
	match tipo:
		"case":
			_linee([Vector2(1.5, 5), Vector2(5, 1.8), Vector2(8.5, 5)])
			_linee([Vector2(2.6, 4.2), Vector2(2.6, 8.6), Vector2(7.4, 8.6), Vector2(7.4, 4.2)])
			_linee([Vector2(4.2, 8.6), Vector2(4.2, 6.2), Vector2(5.8, 6.2), Vector2(5.8, 8.6)])
		"risorse":
			# ascia
			_linea(Vector2(2.2, 8.6), Vector2(7.0, 2.6))
			_pieno([Vector2(5.6, 1.4), Vector2(8.8, 2.4), Vector2(8.2, 5.0), Vector2(6.6, 3.4)])
		"cibo":
			# spiga: gambo e chicchi a goccia
			_linea(Vector2(5, 9), Vector2(5, 3))
			for i in 3:
				var y := 3.4 + i * 1.9
				_pieno([Vector2(4.6, y + 1.2), Vector2(2.6, y), Vector2(3.4, y - 1.0)])
				_pieno([Vector2(5.4, y + 1.2), Vector2(7.4, y), Vector2(6.6, y - 1.0)])
			_pieno([Vector2(5, 0.8), Vector2(5.8, 2.6), Vector2(5, 3.4), Vector2(4.2, 2.6)])
		"servizi":
			# pozzo: tetto, pali, secchio
			_linee([Vector2(1.6, 3.6), Vector2(5, 1.4), Vector2(8.4, 3.6)])
			_linea(Vector2(2.8, 3.2), Vector2(2.8, 8.6))
			_linea(Vector2(7.2, 3.2), Vector2(7.2, 8.6))
			_linee([Vector2(1.8, 6.2), Vector2(8.2, 6.2), Vector2(8.2, 8.6), Vector2(1.8, 8.6), Vector2(1.8, 6.2)])
			_linea(Vector2(5, 3.4), Vector2(5, 4.6))
		"difese":
			# scudo
			_linee([Vector2(5, 1.2), Vector2(8.4, 2.4), Vector2(8.0, 6.0), Vector2(5, 8.8),
				Vector2(2.0, 6.0), Vector2(1.6, 2.4), Vector2(5, 1.2)])
			_linea(Vector2(5, 2.6), Vector2(5, 7.2))
		"strade":
			# strada in prospettiva con la riga di mezzo
			_linea(Vector2(3.6, 1.4), Vector2(1.4, 8.8))
			_linea(Vector2(6.4, 1.4), Vector2(8.6, 8.8))
			_linea(Vector2(5, 1.8), Vector2(5, 3.0))
			_linea(Vector2(5, 4.4), Vector2(5, 5.8))
			_linea(Vector2(5, 7.2), Vector2(5, 8.6))
		"regno":
			# mappa piegata
			_linee([Vector2(1.2, 2.4), Vector2(3.8, 1.4), Vector2(6.2, 2.4), Vector2(8.8, 1.4), Vector2(8.8, 7.6),
				Vector2(6.2, 8.6), Vector2(3.8, 7.6), Vector2(1.2, 8.6), Vector2(1.2, 2.4)])
			_linea(Vector2(3.8, 1.4), Vector2(3.8, 7.6))
			_linea(Vector2(6.2, 2.4), Vector2(6.2, 8.6))
		"info":
			draw_arc(Vector2(5, 5), 3.9, 0, TAU, 24, colore, SPESSORE, true)
			draw_circle(Vector2(5, 3.0), 0.6, colore)
			_linea(Vector2(5, 4.4), Vector2(5, 7.2))
		"consiglio":
			# fumetto
			_linee([Vector2(1.4, 2.0), Vector2(8.6, 2.0), Vector2(8.6, 6.6), Vector2(4.6, 6.6), Vector2(2.6, 8.6),
				Vector2(2.8, 6.6), Vector2(1.4, 6.6), Vector2(1.4, 2.0)])
			for x in [3.2, 5.0, 6.8]:
				draw_circle(Vector2(x, 4.3), 0.55, colore)
		"mercato":
			# bilancia
			_linea(Vector2(5, 1.4), Vector2(5, 8.4))
			_linea(Vector2(3.2, 8.6), Vector2(6.8, 8.6))
			_linea(Vector2(1.8, 2.6), Vector2(8.2, 2.6))
			_linee([Vector2(1.0, 5.6), Vector2(1.8, 2.8), Vector2(2.6, 5.6)])
			_linee([Vector2(7.4, 5.6), Vector2(8.2, 2.8), Vector2(9.0, 5.6)])
			_linea(Vector2(0.8, 5.6), Vector2(2.8, 5.6))
			_linea(Vector2(7.2, 5.6), Vector2(9.2, 5.6))
		"esercito":
			# spade incrociate
			_linea(Vector2(1.6, 1.6), Vector2(7.6, 7.6))
			_linea(Vector2(8.4, 1.6), Vector2(2.4, 7.6))
			_linea(Vector2(5.8, 8.4), Vector2(8.4, 5.8))
			_linea(Vector2(1.6, 5.8), Vector2(4.2, 8.4))
		"sinistra", "destra":
			# un arco sopra e la punta da una parte: gira la vista
			draw_arc(Vector2(5, 6), 3.2, PI, TAU, 20, colore, SPESSORE, true)
			var x := 8.2 if tipo == "destra" else 1.8
			_pieno([Vector2(x - 1.5, 5.4), Vector2(x + 1.5, 5.4), Vector2(x, 7.6)])
		"pausa":
			draw_rect(Rect2(2.8, 2.2, 1.6, 5.6), colore)
			draw_rect(Rect2(5.6, 2.2, 1.6, 5.6), colore)
		"x1":
			_pieno([Vector2(3.4, 2.2), Vector2(7.4, 5), Vector2(3.4, 7.8)])
		"x2":
			_pieno([Vector2(1.6, 2.6), Vector2(5, 5), Vector2(1.6, 7.4)])
			_pieno([Vector2(5, 2.6), Vector2(8.4, 5), Vector2(5, 7.4)])
		"x3":
			_pieno([Vector2(0.6, 3.0), Vector2(3.4, 5), Vector2(0.6, 7.0)])
			_pieno([Vector2(3.6, 3.0), Vector2(6.4, 5), Vector2(3.6, 7.0)])
			_pieno([Vector2(6.6, 3.0), Vector2(9.4, 5), Vector2(6.6, 7.0)])
		"sposta":
			# quattro frecce: si sposta in ogni direzione
			_linea(Vector2(5, 1.6), Vector2(5, 8.4))
			_linea(Vector2(1.6, 5), Vector2(8.4, 5))
			_pieno([Vector2(5, 0.6), Vector2(6.4, 2.2), Vector2(3.6, 2.2)])
			_pieno([Vector2(5, 9.4), Vector2(6.4, 7.8), Vector2(3.6, 7.8)])
			_pieno([Vector2(0.6, 5), Vector2(2.2, 3.6), Vector2(2.2, 6.4)])
			_pieno([Vector2(9.4, 5), Vector2(7.8, 3.6), Vector2(7.8, 6.4)])
		"chiudi":
			_linea(Vector2(2.6, 2.6), Vector2(7.4, 7.4))
			_linea(Vector2(7.4, 2.6), Vector2(2.6, 7.4))
		_:
			draw_circle(Vector2(5, 5), 2.0, colore)


func _linea(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, colore, SPESSORE, true)


func _linee(punti: Array) -> void:
	draw_polyline(PackedVector2Array(punti), colore, SPESSORE, true)


func _pieno(punti: Array) -> void:
	draw_colored_polygon(PackedVector2Array(punti), colore)
