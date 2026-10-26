class_name TerrenoFeudo
extends RefCounted
## Logica del terreno del feudo: tipo e altezza di ogni cella, celle occupate,
## regole di piazzamento. Nessuna grafica: la disegna VistaTerreno.

enum Tipo { ERBA, ERBA_FIORI, BOSCO, ACQUA, ROCCIA, COLLINA, SENTIERO }

const LATO := 48
const PER_NOME := {
	"bosco": Tipo.BOSCO, "acqua": Tipo.ACQUA,
	"roccia": Tipo.ROCCIA, "collina": Tipo.COLLINA,
}
const COSTRUIBILE := [Tipo.ERBA, Tipo.ERBA_FIORI, Tipo.COLLINA, Tipo.SENTIERO]
const ALTEZZE := {Tipo.ACQUA: -0.35, Tipo.ROCCIA: 0.45, Tipo.COLLINA: 0.6}

var seme: int
var celle := PackedByteArray()
var _occupato: Dictionary = {}  # Vector2i -> id edificio


func _init(s: int) -> void:
	seme = s
	_genera()


func _genera() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var acqua := FastNoiseLite.new()
	acqua.seed = seme
	acqua.frequency = 0.07
	var bosco := FastNoiseLite.new()
	bosco.seed = seme + 1
	bosco.frequency = 0.1

	celle.resize(LATO * LATO)
	for y in LATO:
		for x in LATO:
			var a := acqua.get_noise_2d(x, y)
			var t := Tipo.ERBA
			if a < -0.45:
				t = Tipo.ACQUA
			elif a > 0.5:
				t = Tipo.ROCCIA
			elif a > 0.36:
				t = Tipo.COLLINA
			elif bosco.get_noise_2d(x, y) > 0.25:
				t = Tipo.BOSCO
			elif rng.randf() < 0.15:
				t = Tipo.ERBA_FIORI
			celle[y * LATO + x] = t

	# Garantisce bosco, lago e roccia a pochi passi dal centro, in direzioni casuali.
	var centro := Vector2(LATO / 2.0, LATO / 2.0)
	var angolo := rng.randf() * TAU
	_macchia(centro + Vector2.from_angle(angolo) * 10.0, 5.0, Tipo.BOSCO)
	_macchia(centro + Vector2.from_angle(angolo + 2.1) * 10.0, 3.5, Tipo.ACQUA)
	var monte := centro + Vector2.from_angle(angolo + 4.2) * 11.0
	_macchia(monte, 4.5, Tipo.COLLINA)
	_macchia(monte, 2.0, Tipo.ROCCIA)
	_macchia(centro, 5.0, Tipo.ERBA)


func _macchia(centro: Vector2, raggio: float, t: int) -> void:
	for y in range(int(centro.y - raggio), int(centro.y + raggio) + 1):
		for x in range(int(centro.x - raggio), int(centro.x + raggio) + 1):
			if x >= 0 and y >= 0 and x < LATO and y < LATO and centro.distance_to(Vector2(x, y)) <= raggio:
				celle[y * LATO + x] = t


# --- Lettura -----------------------------------------------------------------

func dentro(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < LATO and c.y < LATO


func tipo_a(c: Vector2i) -> int:
	return celle[c.y * LATO + c.x] if dentro(c) else -1


func altezza(c: Vector2i) -> float:
	return ALTEZZE.get(tipo_a(c), 0.0)


func edificio_a(c: Vector2i) -> int:
	return _occupato.get(c, -1)


# --- Occupazione -------------------------------------------------------------

func occupa(b: Dictionary) -> void:
	var taglia: Array = GameState.edifici[b.tipo].taglia
	for y in int(taglia[1]):
		for x in int(taglia[0]):
			_occupato[b.cella + Vector2i(x, y)] = b.id


func libera(b: Dictionary) -> void:
	for c in _occupato.keys():
		if _occupato[c] == b.id:
			_occupato.erase(c)


# --- Regole di piazzamento ---------------------------------------------------

func posizione_valida(tipo: String, cella: Vector2i) -> bool:
	var d: Dictionary = GameState.edifici[tipo]
	var richiesto: int = PER_NOME.get(d.get("su", ""), -1)
	var quota := altezza(cella)
	for y in int(d.taglia[1]):
		for x in int(d.taglia[0]):
			var c := cella + Vector2i(x, y)
			var t := tipo_a(c)
			if t < 0 or _occupato.has(c) or altezza(c) != quota:
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
			if tipo_a(Vector2i(x, y)) == cercato:
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
