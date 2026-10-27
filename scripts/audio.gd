extends Node
## Autoload "Audio": musica di sottofondo (con dissolvenza fra un brano e l'altro) ed effetti.
## I suoni sono in art/audio, generati da tools/genera_audio.py. Ascolta i segnali di GameState
## e fa un piccolo "toc" su ogni pulsante. Musica ed effetti si accendono e spengono dalle opzioni.

const CARTELLA := "res://art/audio/"
const VOLUME_MUSICA := -10.0  # dB
const VOLUME_EFFETTI := -4.0
const VOCI := 8  # effetti che possono suonare insieme

var _musica: Array[AudioStreamPlayer] = []  # due lettori, per la dissolvenza
var _attivo := 0
var _brano := ""
var _voci: Array[AudioStreamPlayer] = []
var _prossima_voce := 0
var _cache: Dictionary = {}
var _ultimo: Dictionary = {}  # effetto -> quando è stato suonato (per non sovrapporre troppi uguali)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_musica.append(p)
	for i in VOCI:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_EFFETTI
		add_child(p)
		_voci.append(p)
	get_tree().node_added.connect(_nodo_aggiunto)
	GameState.building_added.connect(func(b):
		if b.progresso < 1.0:
			effetto("costruisci"))
	GameState.building_finished.connect(func(_id): effetto("completato"))
	GameState.season_changed.connect(func(_s, _a): effetto("campana"))
	GameState.evento.connect(func(_c): effetto("pagina"))
	GameState.banditi_avvistati.connect(func(_d): effetto("corno"))
	GameState.incursione.connect(func(e): effetto("scontro"); effetto("vittoria" if e.vinto else "sconfitta", 0.8))
	GameState.battaglia_finita.connect(func(e): effetto("vittoria" if e.riuscita else "sconfitta"))
	GameState.game_ended.connect(func(v, _m): effetto("vittoria" if v else "sconfitta"))


## Ogni pulsante fa un piccolo tocco di legno.
func _nodo_aggiunto(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).pressed.connect(func(): effetto("click"))


func _carica(nome: String) -> AudioStream:
	if not _cache.has(nome):
		var percorso := CARTELLA + nome + ".ogg"
		_cache[nome] = load(percorso) if ResourceLoader.exists(percorso) else null
	return _cache[nome]


## Cambia la musica (feudo, regno, battaglia): il brano vecchio sfuma, il nuovo entra piano.
func musica(nome: String) -> void:
	if nome == _brano:
		return
	_brano = nome
	var vecchio := _musica[_attivo]
	_attivo = 1 - _attivo
	var nuovo := _musica[_attivo]
	var flusso := _carica("musica_" + nome)
	var tw := create_tween().set_parallel()
	tw.tween_property(vecchio, "volume_db", -80.0, 1.5)
	if flusso and GameState.opzioni.get("musica", true):
		if flusso is AudioStreamOggVorbis:
			(flusso as AudioStreamOggVorbis).loop = true
		nuovo.stream = flusso
		nuovo.volume_db = -40.0
		nuovo.play()
		tw.tween_property(nuovo, "volume_db", VOLUME_MUSICA, 2.0)
	tw.chain().tween_callback(vecchio.stop)


## Accende o spegne la musica (dalle opzioni).
func aggiorna_musica() -> void:
	var brano := _brano
	_brano = ""
	if GameState.opzioni.get("musica", true):
		musica(brano)
	else:
		for p in _musica:
			p.stop()
		_brano = brano


## Suona un effetto (click, costruisci, completato, moneta, campana, pagina, corno, scontro,
## freccia, vittoria, sconfitta, errore).
func effetto(nome: String, volume := 1.0) -> void:
	if not GameState.opzioni.get("effetti", true):
		return
	var adesso := Time.get_ticks_msec()
	if adesso - int(_ultimo.get(nome, -1000)) < 60:
		return
	_ultimo[nome] = adesso
	var flusso := _carica("effetto_" + nome)
	if flusso == null:
		return
	var p := _voci[_prossima_voce]
	_prossima_voce = (_prossima_voce + 1) % VOCI
	p.stream = flusso
	p.volume_db = VOLUME_EFFETTI + linear_to_db(volume)
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
