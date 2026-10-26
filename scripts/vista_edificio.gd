class_name VistaEdificio
extends Node2D
## Disegno provvisorio di un edificio in pixel art (solo rettangoli).
## Da sostituire con uno Sprite2D quando ci saranno gli sprite veri.

const MURO := Color("d9bf94")
const MURO_SCURO := Color("a88d64")
const PORTA := Color("4a2e1a")
const FINESTRA := Color("f2d27a")
const NEVE := Color("f4f8fb")

var b: Dictionary
var selezionata := false


func _process(_delta: float) -> void:
	if b.progresso < 1.0:
		queue_redraw()


func _draw() -> void:
	var d: Dictionary = GameState.edifici[b.tipo]
	var w := int(d.taglia[0]) * Mappa.TILE
	var h := int(d.taglia[1]) * Mappa.TILE
	if b.progresso < 1.0:
		_disegna_cantiere(w, h)
	elif d.get("forma", "") == "campo":
		_disegna_campo(w, h)
	else:
		_disegna_casa(w, h, Color(d.colore), d.get("forma", "") == "mulino")
		if int(d.lavoratori) > 0 and b.lavoratori == 0:
			draw_rect(Rect2(w - 5, 1, 4, 4), Color("e03c31"))  # nessuno ci lavora
	if selezionata:
		draw_rect(Rect2(0.5, 0.5, w - 1, h - 1), Color("ffe066"), false, 1.0)


func _disegna_casa(w: int, h: int, tetto: Color, mulino: bool) -> void:
	var muro_y := int(h * 0.45)
	draw_rect(Rect2(3, h - 3, w - 4, 2), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(2, muro_y, w - 4, h - muro_y - 3), MURO)
	draw_rect(Rect2(2, h - 5, w - 4, 2), MURO_SCURO)
	# tetto a gradini, un pixel di sporgenza per lato
	var righe := muro_y - 1
	for i in righe:
		var rientro := int(float(righe - 1 - i) / righe * (w / 2.0 - 2))
		var colore := tetto.darkened(0.25) if i == righe - 1 else tetto
		if GameState.stagione == GameState.INVERNO and i < righe / 2:
			colore = NEVE
		draw_rect(Rect2(1 + rientro, 1 + i, w - 2 - 2 * rientro, 1), colore)
	# porta e finestre
	draw_rect(Rect2(w / 2 - 2, h - 9, 4, 6), PORTA)
	if w >= 32:
		draw_rect(Rect2(5, muro_y + 3, 3, 3), FINESTRA)
		draw_rect(Rect2(w - 8, muro_y + 3, 3, 3), FINESTRA)
	if mulino:
		var c := Vector2(w / 2.0, muro_y - 2)
		draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), PORTA, 2.0)
		draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), PORTA, 2.0)


func _disegna_campo(w: int, h: int) -> void:
	var terra := Color("7a5a36")
	var spiga: Color = GameState.edifici[b.tipo].colore
	spiga = Color(spiga)
	match GameState.stagione:
		GameState.PRIMAVERA:
			spiga = Color("7cb84f")
		GameState.INVERNO:
			spiga = NEVE
	draw_rect(Rect2(1, 1, w - 2, h - 2), terra)
	for y in range(3, h - 2, 3):
		draw_rect(Rect2(2, y, w - 4, 1), spiga)


func _disegna_cantiere(w: int, h: int) -> void:
	var legno := Color("8b5a2b")
	draw_rect(Rect2(2, h - 6, w - 4, 3), Color("6b5a44"))
	for x in range(3, w - 2, 6):
		draw_rect(Rect2(x, int(h * 0.35), 1, int(h * 0.65) - 5), legno)
	draw_rect(Rect2(2, int(h * 0.35), w - 4, 1), legno)
	draw_rect(Rect2(2, 1, w - 4, 3), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(2, 1, (w - 4) * b.progresso, 3), Color("ffe066"))
