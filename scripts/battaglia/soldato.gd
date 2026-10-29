class_name Soldato
extends Node3D
## Un soldato sul campo di battaglia, con i personaggi KayKit Adventurers (CC0, Kay Lousberg):
## cavaliere, barbaro, ladro e ladro col cappuccio, con le armi giuste per il tipo di unità e il
## mantello del colore della propria parte. Sa stare fermo, camminare, attaccare, essere colpito
## e cadere. Se i modelli non ci sono, crea() restituisce null e il campo usa le figure in codice.

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
}
const IN_GIRO := ["Idle", "2H_Melee_Idle", "Sit_Chair_Idle", "Walking_A", "Running_A"]

static var _scene: Dictionary = {}  # modello -> PackedScene (o null)

var tipo := ""
var _anim: AnimationPlayer
var _fermo := "Idle"
var _attacco := ""
var _caduto := false


## Un soldato del tipo dato, o null se i modelli non ci sono.
static func crea(tipo_unita: String, mantello: Color, cavallo: Mesh = null) -> Soldato:
	var d: Array = TIPI.get(tipo_unita, TIPI.fanti)
	var scena := _scena(str(d[0]))
	if scena == null:
		return null
	var s := Soldato.new()
	s.tipo = tipo_unita
	s._attacco = str(d[2])
	s._fermo = str(d[3])
	var modello := scena.instantiate() as Node3D
	var scala := ALTEZZA / 2.45
	modello.scale = Vector3.ONE * scala
	if cavallo:
		var m := MeshInstance3D.new()
		m.mesh = cavallo
		s.add_child(m)
		modello.position = Vector3(0, 0.62, -0.05)
		modello.scale *= 0.85
	s.add_child(modello)
	s._prepara(modello, d[1], mantello)
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
		riposo()
		# non tutti insieme: ognuno parte da un punto diverso dell'animazione
		_anim.seek(randf() * 1.5, true)


func _suona(nome: String, velocita := 1.0) -> void:
	if _anim and not _caduto and _anim.has_animation(nome):
		_anim.play(nome, 0.15, velocita)


func riposo() -> void:
	_suona(_fermo)


func cammina() -> void:
	_suona("Sit_Chair_Idle" if tipo == "cavalieri" else "Walking_A", 1.3)


func attacca() -> void:
	_suona(_attacco, 1.2)
	if _anim and not _caduto:
		_anim.queue(_fermo)


func colpito() -> void:
	_suona("Hit_A")
	if _anim and not _caduto:
		_anim.queue(_fermo)


## Cade a terra e poi sparisce.
func muori() -> void:
	_suona("Death_A")
	_caduto = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "scale", Vector3(1, 0.05, 1), 0.35)
	tw.tween_callback(queue_free)
