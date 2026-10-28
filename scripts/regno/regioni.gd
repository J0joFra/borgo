class_name Regioni
extends RefCounted
## Le regioni della mappa del regno, generate dal seme della partita: posizioni,
## nomi, risorsa speciale e proprietario. Le usano la mappa del regno e il mercato.


## {siti: Array[Vector2] (0..1), regioni: Array[Dictionary], mia: int}
## versione 1 (partite vecchie): la nostra regione è quella al centro; dalla 2 è una qualsiasi.
static func genera(seme: int, versione := -1) -> Dictionary:
	if versione < 0:
		versione = GameState.versione_mappa
	var dati: Dictionary = (load("res://data/regioni.json") as JSON).data
	var rng := RandomNumberGenerator.new()
	rng.seed = seme + 99
	var n := int(dati.numero)
	var siti: Array[Vector2] = []
	# punti ben distanziati: si scartano quelli troppo vicini agli altri
	while siti.size() < n:
		var p := Vector2(rng.randf_range(0.06, 0.94), rng.randf_range(0.08, 0.92))
		var ok := true
		for q in siti:
			if p.distance_to(q) < 0.18:
				ok = false
				break
		if ok:
			siti.append(p)
	# la regione del giocatore: una qualsiasi (nelle partite vecchie quella più vicina al centro)
	var mia := 0
	var migliore := 9.0
	for i in n:
		var d := siti[i].distance_to(Vector2(0.5, 0.5))
		if d < migliore:
			migliore = d
			mia = i
	if versione >= 2:
		mia = rng.randi() % n
	var nomi: Array = dati.nomi.duplicate()
	for i in range(nomi.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = nomi[i]
		nomi[i] = nomi[j]
		nomi[j] = tmp
	var regioni: Array[Dictionary] = []
	for i in n:
		var r := {"nome": nomi[i], "risorsa": dati.risorse[rng.randi() % dati.risorse.size()]}
		var proprietario: Dictionary
		if i == mia:
			proprietario = dati.giocatore
		else:
			var x := rng.randf()
			if x < 0.6:
				proprietario = dati.signori[rng.randi() % dati.signori.size()]
				r.tipo = "signore"
			elif x < 0.8:
				proprietario = dati.banditi
				r.tipo = "banditi"
			else:
				proprietario = dati.libera
				r.tipo = "libera"
		if i == mia:
			r.tipo = "mia"
		r.signore = proprietario.nome
		r.colore = Color(proprietario.colore)
		regioni.append(r)
	return {"siti": siti, "regioni": regioni, "mia": mia}


## I confini ondulati: ogni lato del poligono diviso in tratti brevi, ogni punto spostato da un
## rumore che dipende solo dalla posizione, così due regioni vicine si deformano allo stesso modo
## e restano attaccate. I lati sul bordo della carta restano dritti.
static func ondula(poligono: PackedVector2Array, area: Rect2, seme: int, ampiezza: float) -> PackedVector2Array:
	var rumore := FastNoiseLite.new()
	rumore.seed = seme
	rumore.frequency = 0.012
	rumore.fractal_octaves = 2
	var risultato := PackedVector2Array()
	for k in poligono.size():
		var p := poligono[k]
		var q := poligono[(k + 1) % poligono.size()]
		var sul_bordo := _sul_bordo(p, area) and _sul_bordo(q, area) and (absf(p.x - q.x) < 0.5 or absf(p.y - q.y) < 0.5)
		var tratti := maxi(1, int(p.distance_to(q) / 4.0))
		for t in tratti:
			var x := p.lerp(q, float(t) / tratti)
			if not sul_bordo and not _sul_bordo(x, area):
				x += Vector2(rumore.get_noise_2d(x.x, x.y), rumore.get_noise_2d(x.x + 731.0, x.y - 377.0)) * ampiezza
			risultato.append(x)
	return risultato


static func _sul_bordo(p: Vector2, area: Rect2) -> bool:
	return absf(p.x - area.position.x) < 0.5 or absf(p.x - area.end.x) < 0.5 \
		or absf(p.y - area.position.y) < 0.5 or absf(p.y - area.end.y) < 0.5
