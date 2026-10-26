class_name CatalogoModelli
extends RefCounted
## Trova i modelli 3D veri (.gltf / .glb) messi in art/models e li abbina agli edifici
## cercando nel nome del file le parole chiave di data/modelli.json.
## Pensato per i pacchetti KayKit, ma funziona con qualsiasi modello ben nominato.
## Se per un edificio non c'è niente, il gioco usa la forma provvisoria in codice.

static var _scene: Dictionary = {}  # tipo -> PackedScene (o null se non trovato)
static var _file: Array[String] = []
static var _pronto := false
static var _config: Dictionary = {}


## Il modello per un tipo di edificio, o null se non c'è.
static func scena(tipo: String) -> PackedScene:
	_prepara()
	if not _scene.has(tipo):
		_scene[tipo] = _cerca(tipo)
	return _scene[tipo]


static func percorso(tipo: String) -> String:
	var s := scena(tipo)
	return s.resource_path if s else ""


## Istanzia il modello e lo adatta all'area dell'edificio: centrato, appoggiato a terra,
## scalato in modo uniforme per stare in larghezza × profondità (in metri).
static func istanzia(tipo: String, larghezza: float, profondita: float) -> Node3D:
	var s := scena(tipo)
	if s == null:
		return null
	var modello := s.instantiate() as Node3D
	if modello == null:
		return null
	var box := _ingombro(modello, Transform3D.IDENTITY)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return modello
	var riempimento: float = _config.get("riempimento", 0.9)
	var scala := minf(larghezza * riempimento / box.size.x, profondita * riempimento / box.size.z)
	var contenitore := Node3D.new()
	contenitore.add_child(modello)
	modello.scale = Vector3.ONE * scala
	var centro := box.get_center()
	modello.position = Vector3(-centro.x, -box.position.y, -centro.z) * scala
	modello.rotation_degrees.y = float(_config.get("rotazione", 0.0))
	return contenitore


static func _prepara() -> void:
	if _pronto:
		return
	_pronto = true
	var json := load("res://data/modelli.json") as JSON
	_config = json.data if json else {}
	_elenca(_config.get("cartella", "res://art/models"))


## Tutti i file di modello sotto una cartella. Nei giochi esportati gli originali
## non ci sono più, restano i file ".import": si toglie il suffisso.
static func _elenca(cartella: String) -> void:
	var dir := DirAccess.open(cartella)
	if dir == null:
		return
	for sotto in dir.get_directories():
		_elenca(cartella.path_join(sotto))
	for nome in dir.get_files():
		var n := nome.trim_suffix(".import").trim_suffix(".remap")
		if n.get_extension().to_lower() in ["gltf", "glb"]:
			var p := cartella.path_join(n)
			if not p in _file:
				_file.append(p)


static func _cerca(tipo: String) -> PackedScene:
	var parole: Array = _config.get("edifici", {}).get(tipo, [])
	var preferito: String = str(_config.get("colore_preferito", "")).to_lower()
	for parola in parole:
		var candidati: Array[String] = []
		for p in _file:
			if str(parola).to_lower() in p.get_file().to_lower():
				candidati.append(p)
		if candidati.is_empty():
			continue
		# a parità di parola: prima il colore della propria fazione, poi il nome più corto
		candidati.sort_custom(func(a: String, b: String) -> bool:
			var pa := preferito != "" and preferito in a.get_file().to_lower()
			var pb := preferito != "" and preferito in b.get_file().to_lower()
			if pa != pb:
				return pa
			return a.get_file().length() < b.get_file().length())
		var s := load(candidati[0]) as PackedScene
		if s:
			return s
	return null


## Ingombro complessivo di tutte le mesh del modello, nelle coordinate del modello.
static func _ingombro(nodo: Node, tr: Transform3D) -> AABB:
	var risultato := AABB()
	var vuoto := true
	var qui := tr
	if nodo is Node3D:
		qui = tr * (nodo as Node3D).transform
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh:
		risultato = qui * (nodo as MeshInstance3D).get_aabb()
		vuoto = false
	for figlio in nodo.get_children():
		var b := _ingombro(figlio, qui)
		if b.size == Vector3.ZERO and b.position == Vector3.ZERO:
			continue
		risultato = b if vuoto else risultato.merge(b)
		vuoto = false
	return risultato
