class_name Regioni
extends RefCounted
## Le regioni della mappa del regno, generate dal seme della partita: posizioni,
## nomi, risorsa speciale e proprietario. Le usano la mappa del regno e il mercato.


## {siti: Array[Vector2] (0..1), regioni: Array[Dictionary], mia: int}
static func genera(seme: int) -> Dictionary:
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
	# la regione del giocatore è quella più vicina al centro
	var mia := 0
	var migliore := 9.0
	for i in n:
		var d := siti[i].distance_to(Vector2(0.5, 0.5))
		if d < migliore:
			migliore = d
			mia = i
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
			elif x < 0.8:
				proprietario = dati.banditi
			else:
				proprietario = dati.libera
		r.signore = proprietario.nome
		r.colore = Color(proprietario.colore)
		regioni.append(r)
	return {"siti": siti, "regioni": regioni, "mia": mia}
