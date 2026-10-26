class_name Mappa
extends Node2D
## Terreno a tile 16×16, edifici piazzati e anteprima di piazzamento.

enum Terreno { ERBA, ERBA_FIORI, BOSCO, ACQUA, ROCCIA, COLLINA, SENTIERO }

const LATO := 64
const TILE := 16
const PER_NOME := {
	"bosco": Terreno.BOSCO, "acqua": Terreno.ACQUA,
	"roccia": Terreno.ROCCIA, "collina": Terreno.COLLINA,
}
const COSTRUIBILE := [Terreno.ERBA, Terreno.ERBA_FIORI, Terreno.COLLINA, Terreno.SENTIERO]

var terreno := PackedByteArray()
var _occupato: Dictionary = {}  # Vector2i -> id edificio
var _viste: Dictionary = {}     # id -> VistaEdificio
var _strato: TileMapLayer
var _atlante: TileSetAtlasSource
var _texture: Array[Texture2D] = []
var _edifici: Node2D
var _anteprima: Anteprima
var _selezionato := -1


func _ready() -> void:
	_strato = TileMapLayer.new()
	add_child(_strato)
	_edifici = Node2D.new()
	add_child(_edifici)
	_anteprima = Anteprima.new()
	_anteprima.visible = false
	add_child(_anteprima)
	GameState.building_added.connect(_crea_vista)
	GameState.building_removed.connect(_rimuovi_vista)
	GameState.season_changed.connect(_applica_stagione)
	GameState.changed.connect(_ridisegna_edifici)


func genera(seme: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var acqua := FastNoiseLite.new()
	acqua.seed = seme
	acqua.frequency = 0.06
	var bosco := FastNoiseLite.new()
	bosco.seed = seme + 1
	bosco.frequency = 0.09

	terreno.resize(LATO * LATO)
	for y in LATO:
		for x in LATO:
			var a := acqua.get_noise_2d(x, y)
			var t := Terreno.ERBA
			if a < -0.45:
				t = Terreno.ACQUA
			elif a > 0.5:
				t = Terreno.ROCCIA
			elif a > 0.36:
				t = Terreno.COLLINA
			elif bosco.get_noise_2d(x, y) > 0.25:
				t = Terreno.BOSCO
			elif rng.randf() < 0.15:
				t = Terreno.ERBA_FIORI
			terreno[y * LATO + x] = t

	# Garantisce bosco, lago e roccia a pochi passi dal centro, in direzioni casuali.
	var centro := Vector2(LATO / 2.0, LATO / 2.0)
	var angolo := rng.randf() * TAU
	_macchia(centro + Vector2.from_angle(angolo) * 13.0, 6.0, Terreno.BOSCO)
	_macchia(centro + Vector2.from_angle(angolo + 2.1) * 13.0, 4.0, Terreno.ACQUA)
	var monte := centro + Vector2.from_angle(angolo + 4.2) * 14.0
	_macchia(monte, 5.5, Terreno.COLLINA)
	_macchia(monte, 2.5, Terreno.ROCCIA)
	_macchia(centro, 6.0, Terreno.ERBA)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	_atlante = TileSetAtlasSource.new()
	_atlante.texture_region_size = Vector2i(TILE, TILE)
	_texture.clear()
	for s in 4:
		_texture.append(ArteProvvisoria.atlante_terreno(s))
	_atlante.texture = _texture[GameState.stagione]
	for i in ArteProvvisoria.N_TILE:
		_atlante.create_tile(Vector2i(i, 0))
	ts.add_source(_atlante, 0)
	_strato.tile_set = ts
	for y in LATO:
		for x in LATO:
			_strato.set_cell(Vector2i(x, y), 0, Vector2i(terreno[y * LATO + x], 0))


func _macchia(centro: Vector2, raggio: float, t: int) -> void:
	for y in range(int(centro.y - raggio), int(centro.y + raggio) + 1):
		for x in range(int(centro.x - raggio), int(centro.x + raggio) + 1):
			if x >= 0 and y >= 0 and x < LATO and y < LATO and centro.distance_to(Vector2(x, y)) <= raggio:
				terreno[y * LATO + x] = t


## Ricrea le viste degli edifici dopo un caricamento.
func ricostruisci_edifici() -> void:
	for b in GameState.buildings:
		_crea_vista(b)


# --- Coordinate --------------------------------------------------------------

func dimensione_px() -> Vector2:
	return Vector2(LATO * TILE, LATO * TILE)


func centro_px() -> Vector2:
	return dimensione_px() / 2.0


func cella_da_schermo(p: Vector2) -> Vector2i:
	var mondo := get_canvas_transform().affine_inverse() * p
	return Vector2i((mondo / TILE).floor())


func terreno_a(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= LATO or c.y >= LATO:
		return -1
	return terreno[c.y * LATO + c.x]


func edificio_a(c: Vector2i) -> int:
	return _occupato.get(c, -1)


# --- Regole di piazzamento ---------------------------------------------------

func posizione_valida(tipo: String, cella: Vector2i) -> bool:
	var d: Dictionary = GameState.edifici[tipo]
	var richiesto: int = PER_NOME.get(d.get("su", ""), -1)
	for y in int(d.taglia[1]):
		for x in int(d.taglia[0]):
			var c := cella + Vector2i(x, y)
			var t := terreno_a(c)
			if t < 0 or _occupato.has(c):
				return false
			if richiesto >= 0 and t != richiesto:
				return false
			if richiesto < 0 and not t in COSTRUIBILE:
				return false
	return true


## 1.0 se la risorsa naturale richiesta è entro il raggio, altrimenti il malus.
func bonus(tipo: String, cella: Vector2i) -> float:
	var d: Dictionary = GameState.edifici[tipo]
	if not d.has("vicino"):
		return 1.0
	var cercato: int = PER_NOME[d.vicino]
	var v: Dictionary = GameState.bil.vicinanza
	var r := int(v.raggio)
	for y in range(cella.y - r, cella.y + int(d.taglia[1]) + r):
		for x in range(cella.x - r, cella.x + int(d.taglia[0]) + r):
			if terreno_a(Vector2i(x, y)) == cercato:
				return 1.0
	return float(v.malus_lontano)


## Cerca a spirale il posto valido più vicino a una cella.
func trova_posto(tipo: String, vicino_a: Vector2i) -> Vector2i:
	for raggio in 20:
		for y in range(-raggio, raggio + 1):
			for x in range(-raggio, raggio + 1):
				if maxi(absi(x), absi(y)) != raggio:
					continue
				var c := vicino_a + Vector2i(x, y)
				if posizione_valida(tipo, c):
					return c
	return Vector2i(-1, -1)


# --- Viste -------------------------------------------------------------------

func mostra_anteprima(tipo: String, cella: Vector2i) -> bool:
	var valida := posizione_valida(tipo, cella)
	var taglia: Array = GameState.edifici[tipo].taglia
	_anteprima.position = Vector2(cella * TILE)
	_anteprima.dimensione = Vector2(taglia[0], taglia[1]) * TILE
	_anteprima.valida = valida
	_anteprima.visible = true
	_anteprima.queue_redraw()
	return valida


func nascondi_anteprima() -> void:
	_anteprima.visible = false


func seleziona(id: int) -> void:
	_selezionato = id
	for k in _viste:
		_viste[k].selezionata = k == id
		_viste[k].queue_redraw()


func _crea_vista(b: Dictionary) -> void:
	var vista := VistaEdificio.new()
	vista.b = b
	vista.position = Vector2(b.cella * TILE)
	_edifici.add_child(vista)
	_viste[b.id] = vista
	var taglia: Array = GameState.edifici[b.tipo].taglia
	for y in int(taglia[1]):
		for x in int(taglia[0]):
			_occupato[b.cella + Vector2i(x, y)] = b.id


func _rimuovi_vista(id: int) -> void:
	if _viste.has(id):
		_viste[id].queue_free()
		_viste.erase(id)
	for c in _occupato.keys():
		if _occupato[c] == id:
			_occupato.erase(c)
	if _selezionato == id:
		_selezionato = -1


func _applica_stagione(stagione: int, _anno: int) -> void:
	_atlante.texture = _texture[stagione]
	_ridisegna_edifici()


func _ridisegna_edifici() -> void:
	for v in _viste.values():
		v.queue_redraw()
