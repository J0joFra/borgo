class_name Soldato
extends Node3D
## Un soldato sul campo di battaglia, con i personaggi KayKit Adventurers (CC0, Kay Lousberg):
## cavaliere, barbaro, ladro e ladro col cappuccio, con le armi giuste per il tipo di unità e il
## mantello del colore della propria parte. Sa stare fermo, camminare, attaccare, essere colpito
## e cadere. Se i modelli non ci sono, crea() restituisce null e il campo usa le figure in codice.
## Gli stessi personaggi, senza armi o con gli attrezzi del mestiere, sono gli abitanti del borgo
## (crea_con): camminano, stanno fermi, lavorano.

const CARTELLA := "res://art/models/kaykit/personaggi/"
const ALTEZZA := 1.3  # quanto è alto un soldato, nelle misure dell'unità
## tipo di unità -> [modello, pezzi da mostrare (armi, elmo, mantello), attacco, fermo]
const TIPI := {
	"fanti": ["Knight", ["Knight_Helmet", "Knight_Cape", "Round_Shield", "1H_Sword"], "1H_Melee_Attack_Stab", "Idle"],
	"spadaccini": ["Knight", ["Knight_Helmet", "Knight_Cape", "Badge_Shield", "1H_Sword"], "1H_Melee_Attack_Slice_Diagonal", "Idle"],
	"cavalieri": ["Knight", ["Knight_Helmet", "Knight_Cape", "Rectangle_Shield", "1H_Sword"], "1H_Melee_Attack_Chop", "Sit_Chair_Idle"],
	"arcieri": ["Rogue_Hooded", ["Rogue_Cape", "1H_Crossbow"], "1H_Ranged_Shoot", "Idle"],
	"balestrieri": ["Rogue", ["Rogue_Cape", "2H_Crossbow"], "2H_Ranged_Shoot", "Idle"],
	"vassalli": ["Barbarian", ["Barbarian_Hat", "Barbarian_Cape", "1H_Axe", "Barbarian_Round_Shield"], "1H_Melee_Attack_Chop", "Idle"],
	"predoni": ["Rogue_Hooded", ["Rogue_Cape", "Knife", "Knife_Offhand"], "Dualwield_Melee_Attack_Stab", "Idle"],
	"contadini": ["Barbarian", ["2H_Axe"], "2H_Melee_Attack_Chop", "2H_Melee_Idle"],
	"briganti": ["Rogue_Hooded", ["Rogue_Cape", "2H_Crossbow"], "2H_Ranged_Shoot", "Idle"],
	"capobanda": ["Barbarian", ["Barbarian_Hat", "Barbarian_Cape", "2H_Axe"], "2H_Melee_Attack_Spin", "2H_Melee_Idle"],
	"milizia": ["Barbarian", ["Barbarian_Round_Shield", "1H_Axe"], "1H_Melee_Attack_Chop", "Idle"],
	"cacciatori": ["Rogue", ["Rogue_Cape", "1H_Crossbow"], "1H_Ranged_Shoot", "Idle"],
}
## Aspetti diversi per le figure della stessa unità: [modello, pezzi] (le armi restano quelle del tipo).
const VARIANTI := {
	"predoni": [["Rogue_Hooded", ["Rogue_Cape", "Knife", "Knife_Offhand"]], ["Rogue", ["Rogue_Cape", "Knife", "Knife_Offhand"]], ["Rogue_Hooded", ["Knife", "Knife_Offhand"]]],
	"contadini": [["Barbarian", ["2H_Axe"]], ["Barbarian", ["Barbarian_Hat", "2H_Axe"]], ["Barbarian", ["Barbarian_Cape", "2H_Axe"]]],
	"vassalli": [["Barbarian", ["Barbarian_Hat", "Barbarian_Cape", "1H_Axe", "Barbarian_Round_Shield"]], ["Barbarian", ["Barbarian_Cape", "1H_Axe", "Barbarian_Round_Shield"]]],
	"milizia": [["Barbarian", ["Barbarian_Round_Shield", "1H_Axe"]], ["Barbarian", ["Barbarian_Hat", "Barbarian_Round_Shield", "1H_Axe"]], ["Barbarian", ["Barbarian_Cape", "Barbarian_Round_Shield", "1H_Axe"]]],
	"briganti": [["Rogue_Hooded", ["Rogue_Cape", "2H_Crossbow"]], ["Rogue", ["2H_Crossbow"]]],
	"cacciatori": [["Rogue", ["Rogue_Cape", "1H_Crossbow"]], ["Rogue_Hooded", ["1H_Crossbow"]]],
	"fanti": [["Knight", ["Knight_Helmet", "Knight_Cape", "Round_Shield", "1H_Sword"]], ["Knight", ["Knight_Helmet", "Knight_Cape", "Rectangle_Shield", "1H_Sword"]]],
	"spadaccini": [["Knight", ["Knight_Helmet", "Knight_Cape", "Badge_Shield", "1H_Sword"]], ["Knight", ["Knight_Helmet", "Knight_Cape", "Spike_Shield", "1H_Sword"]], ["Knight", ["Knight_Cape", "Badge_Shield", "1H_Sword"]]],
}
const GRANDI := {"capobanda": 1.25}  # chi è più grosso degli altri
const IN_GIRO := ["Idle", "2H_Melee_Idle", "Sit_Chair_Idle", "Sit_Floor_Idle", "Walking_A", "Running_A"]

static var _scene: Dictionary = {}  # modello -> PackedScene (o null)

var tipo := ""
var _anim: AnimationPlayer
var _fermo := "Idle"
var _attacco := ""
var _caduto := false
var _lavoro := ""  # l'animazione che ripete mentre lavora (abbattere, raccogliere...)


## Un soldato del tipo dato (nell'aspetto numero "variante"), o null se i modelli non ci sono.
static func crea(tipo_unita: String, mantello: Color, cavallo: Mesh = null, variante := 0) -> Soldato:
	var d: Array = TIPI.get(tipo_unita, TIPI.fanti)
	var modello := str(d[0])
	var pezzi: Array = d[1]
	if VARIANTI.has(tipo_unita):
		var v: Array = VARIANTI[tipo_unita][variante % VARIANTI[tipo_unita].size()]
		modello = str(v[0])
		pezzi = v[1]
	return crea_con(modello, pezzi, mantello, str(d[3]), str(d[2]), tipo_unita, cavallo, float(GRANDI.get(tipo_unita, 1.0)))


## Un personaggio qualsiasi: modello (Knight, Barbarian, Rogue, Rogue_Hooded), i pezzi da mostrare,
## il mantello, l'animazione da fermo e quella d'attacco; alto ALTEZZA × altezza.
static func crea_con(nome_modello: String, pezzi: Array, mantello: Color, fermo := "Idle", attacco := "", tipo_unita := "", cavallo: Mesh = null, altezza := 1.0) -> Soldato:
	var scena := _scena(nome_modello)
	if scena == null:
		return null
	var s := Soldato.new()
	s.tipo = tipo_unita
	s._attacco = attacco
	s._fermo = fermo
	var modello := scena.instantiate() as Node3D
	var scala := ALTEZZA * altezza / 2.45
	modello.scale = Vector3.ONE * scala
	if cavallo:
		var m := MeshInstance3D.new()
		m.mesh = cavallo
		s.add_child(m)
		modello.position = Vector3(0, 0.62, -0.05)
		modello.scale *= 0.85
	s.add_child(modello)
	s._prepara(modello, pezzi, mantello)
	return s


static func _scena(nome: String) -> PackedScene:
	if not _scene.has(nome):
		var percorso := CARTELLA + nome + ".glb"
		_scene[nome] = load(percorso) as PackedScene if ResourceLoader.exists(percorso) else null
	return _scene[nome]


func _prepara(modello: Node3D, pezzi: Array, mantello: Color) -> void:
	for n in modello.find_children("*", "BoneAttachment3D", true, false):
		n.visible = n.name in pezzi
		if "Cape" in n.name:
			for m in n.get_children():
				if m is MeshInstance3D:
					var mat := StandardMaterial3D.new()
					mat.albedo_color = mantello
					mat.roughness = 0.9
					(m as MeshInstance3D).material_override = mat
		# i lancieri: al posto della spada una lancia lunga
		if tipo == "fanti" and n.name == "1H_Sword":
			for m in n.get_children():
				(m as Node3D).visible = false
			var k := LowPoly.Costruttore.new()
			k.forma(LowPoly.cilindro(0.06, 0.06, 3.6, 5), LowPoly.t(Vector3(0, 0.8, 0)), Color("7a5a36"))
			k.forma(LowPoly.cilindro(0.14, 0.0, 0.5, 4), LowPoly.t(Vector3(0, 2.85, 0)), Color("c8ccd0"))
			var lancia := MeshInstance3D.new()
			lancia.mesh = k.mesh()
			n.add_child(lancia)
	_anim = modello.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for nome in IN_GIRO:
			if _anim.has_animation(nome):
				_anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
		_anim.animation_finished.connect(func(_n: StringName) -> void:
			if _lavoro != "" and not _caduto:
				_anim.play(_lavoro))
		riposo()
		# non tutti insieme: ognuno parte da un punto diverso dell'animazione
		_anim.seek(randf() * 1.5, true)


func _suona(nome: String, velocita := 1.0) -> void:
	if _anim and not _caduto and _anim.has_animation(nome):
		_anim.play(nome, 0.15, velocita)


func riposo() -> void:
	_lavoro = ""
	_suona(_fermo)


func cammina(velocita := 1.3) -> void:
	_lavoro = ""
	_suona("Sit_Chair_Idle" if tipo == "cavalieri" else "Walking_A", velocita)


## Ripete un'animazione finché non fa altro (abbattere un albero, raccogliere, bere...).
func lavora(nome: String) -> void:
	if _anim == null or not _anim.has_animation(nome):
		riposo()
		return
	_lavoro = nome
	_suona(nome)


## Siede a terra (attorno al falò).
func siedi() -> void:
	_lavoro = ""
	_suona("Sit_Floor_Idle")


## La velocità delle animazioni (segue quella del gioco; 0 = in pausa).
func ritmo(v: float) -> void:
	if _anim:
		_anim.speed_scale = v


func sta_camminando() -> bool:
	return _anim != null and _anim.current_animation in ["Walking_A", "Running_A"]


func attacca() -> void:
	_suona(_attacco, 1.2)
	if _anim and not _caduto:
		_anim.queue(_fermo)


func colpito() -> void:
	_suona("Hit_A")
	if _anim and not _caduto:
		_anim.queue(_fermo)


## Cade a terra e poi sparisce (liberato, o solo nascosto se qualcuno lo tiene in un elenco).
func muori(libera := true) -> void:
	_suona("Death_A")
	_caduto = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "scale", Vector3(1, 0.05, 1), 0.35)
	tw.tween_callback(queue_free if libera else hide)


## Corre (in fuga).
func corri(velocita := 1.0) -> void:
	_lavoro = ""
	_suona("Running_A", velocita)


## Mette in mano (nell'attacco dell'osso dato, es. "Knife") un oggetto fatto in codice al posto dell'arma.
func metti_in_mano(osso: String, mesh: Mesh) -> void:
	for n in find_children(osso, "BoneAttachment3D", true, false):
		n.visible = true
		for figlio in n.get_children():
			(figlio as Node3D).visible = false
		var m := MeshInstance3D.new()
		m.mesh = mesh
		n.add_child(m)


## Aggiunge un oggetto addosso (es. il sacco del bottino sulla schiena), nelle misure del personaggio.
func porta(mesh: Mesh, dove: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = dove
	add_child(m)
