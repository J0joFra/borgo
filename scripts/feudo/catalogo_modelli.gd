class_name CatalogoModelli
extends RefCounted
## Trova i modelli 3D veri messi in art/models e li abbina agli edifici
## cercando nel nome del file le parole chiave di data/modelli.json.
## Accetta .gltf/.glb (scene) e .obj (mesh). Gli OBJ di KayKit sono divisi in pezzi
## già nella posizione giusta: "building_windmill_red.obj" è la base e
## "building_windmill_red_..._top_fan_red.obj" sono le parti, che vengono unite.
## Se per un edificio non c'è niente, il gioco usa la forma provvisoria in codice.
## "scala" in modelli.json dà a tutti la stessa scala; "riempimento" è il massimo dell'area occupata.

const ESTENSIONI := ["gltf", "glb", "obj"]

static var _trovati: Dictionary = {}  # chiave -> percorso del file principale ("" = niente)
static var _file: Array[String] = []
static var _pronto := false
static var _config: Dictionary = {}


static func percorso(tipo: String) -> String:
	return _percorso_per(_parole(tipo))


## Il modello di un edificio adattato all'area (in metri), o null se non c'è.
static func istanzia(tipo: String, larghezza: float, profondita: float) -> Node3D:
	return _istanzia_file(percorso(tipo), larghezza, profondita)


## Il primo modello che corrisponde a una delle parole, adattato all'area, o null.
static func istanzia_parole(parole: Array, larghezza: float, profondita: float) -> Node3D:
	return _istanzia_file(_percorso_per(parole), larghezza, profondita)


## Il modello del cantiere per l'avanzamento dato (0..1), o null.
static func istanzia_cantiere(progresso: float, larghezza: float, profondita: float) -> Node3D:
	_prepara()
	var fasi: Array = _config.get("cantiere", [])
	if fasi.is_empty():
		return null
	var i := clampi(int(progresso * fasi.size()), 0, fasi.size() - 1)
	return _istanzia_file(_percorso_per([fasi[i]]), larghezza, profondita)


static func numero_fasi_cantiere() -> int:
	_prepara()
	return maxi(1, _config.get("cantiere", []).size())


## Ingombro complessivo di tutte le mesh del nodo, nelle coordinate del nodo.
static func ingombro(nodo: Node) -> AABB:
	return _ingombro(nodo, Transform3D.IDENTITY)


# --- Ricerca -----------------------------------------------------------------

static func _parole(tipo: String) -> Array:
	_prepara()
	return _config.get("edifici", {}).get(tipo, [])


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
		if n.get_extension().to_lower() in ESTENSIONI:
			var p := cartella.path_join(n)
			if not p in _file:
				_file.append(p)


static func _percorso_per(parole: Array) -> String:
	_prepara()
	var chiave := "|".join(parole)
	if _trovati.has(chiave):
		return _trovati[chiave]
	var risultato := ""
	var preferito: String = str(_config.get("colore_preferito", "")).to_lower()
	for parola in parole:
		var candidati: Array[String] = []
		for p in _file:
			if str(parola).to_lower() in p.get_file().to_lower():
				candidati.append(p)
		if candidati.is_empty():
			continue
		# prima il colore della propria fazione, poi il nome più corto (la base, non i pezzi)
		candidati.sort_custom(func(a: String, b: String) -> bool:
			var pa := preferito != "" and preferito in a.to_lower()
			var pb := preferito != "" and preferito in b.to_lower()
			if pa != pb:
				return pa
			return a.get_file().length() < b.get_file().length())
		risultato = candidati[0]
		break
	_trovati[chiave] = risultato
	return risultato


# --- Costruzione del modello -------------------------------------------------

static func _istanzia_file(file: String, larghezza: float, profondita: float) -> Node3D:
	if file == "":
		return null
	var modello := _carica(file)
	if modello == null:
		return null
	var box := _ingombro(modello, Transform3D.IDENTITY)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return modello
	# il modello si gira prima di misurarlo, così un edificio lungo segue il lato lungo
	var contenitore := Node3D.new()
	contenitore.add_child(modello)
	var rotazione := deg_to_rad(float(_config.get("rotazione", 0.0)))
	var dim := Vector3(box.size.x, box.size.y, box.size.z)
	if is_equal_approx(absf(sin(rotazione)), 1.0):
		dim = Vector3(box.size.z, box.size.y, box.size.x)
	# scala unica per tutto il pacchetto (proporzioni giuste fra edifici),
	# ridotta solo se il modello non entra nell'area dell'edificio
	var riempimento: float = _config.get("riempimento", 0.9)
	var scala := minf(larghezza * riempimento / dim.x, profondita * riempimento / dim.z)
	var scala_pacchetto := float(_config.get("scala", 0.0))
	if scala_pacchetto > 0.0:
		scala = minf(scala, scala_pacchetto)
	var centro := box.get_center()
	modello.transform = Transform3D(Basis(Vector3.UP, rotazione).scaled(Vector3.ONE * scala), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, Vector3(-centro.x, -box.position.y, -centro.z))
	return contenitore


static func _carica(file: String) -> Node3D:
	if file.get_extension().to_lower() != "obj":
		var scena := load(file) as PackedScene
		return scena.instantiate() as Node3D if scena else null
	# OBJ: base più tutti i pezzi che iniziano con lo stesso nome
	var radice := Node3D.new()
	var base := file.get_basename().get_file()
	var cartella := file.get_base_dir()
	for p in _file:
		if p.get_base_dir() != cartella or p.get_extension().to_lower() != "obj":
			continue
		var nome := p.get_basename().get_file()
		if nome != base and not nome.begins_with(base + "_"):
			continue
		var mesh := load(p) as Mesh
		if mesh == null:
			continue
		var pezzo := MeshInstance3D.new()
		pezzo.mesh = mesh
		pezzo.name = nome
		var ruota := _asse_rotazione(nome)
		if ruota != Vector3.ZERO:
			# le parti che girano ruotano attorno al proprio centro
			var perno := Node3D.new()
			var c := mesh.get_aabb().get_center()
			perno.position = c
			pezzo.position = -c
			perno.set_meta("gira", ruota)
			perno.add_child(pezzo)
			radice.add_child(perno)
		else:
			radice.add_child(pezzo)
	return radice if radice.get_child_count() > 0 else null


## Parti che girano: pale dei mulini a vento (asse Z) e ruote ad acqua (asse X).
static func _asse_rotazione(nome: String) -> Vector3:
	var n := nome.to_lower()
	if n.ends_with("_fan") or "_fan_" in n:
		return Vector3.BACK
	if "_wheel" in n:
		return Vector3.RIGHT
	return Vector3.ZERO


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
