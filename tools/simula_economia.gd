extends Node
## Simulazione dell'economia, senza grafica: un giocatore automatico "ragionevole" gioca qualche anno
## (case quando servono, cibo quando scarseggia, legna e pietra quando mancano, migliora quando può)
## e stampa le risorse a ogni stagione. Serve a bilanciare i numeri di data/bilanciamento.json.
##   godot --headless --path . res://tools/simula_economia.tscn
## Variabili: SIM_ANNI (default 5), SIM_SEMI (default 3 partite), SIM_CLIMA (default temperato).

var _centro := Vector2i.ZERO


func _ready() -> void:
	var anni := int(OS.get_environment("SIM_ANNI")) if OS.get_environment("SIM_ANNI") != "" else 5
	var semi := int(OS.get_environment("SIM_SEMI")) if OS.get_environment("SIM_SEMI") != "" else 3
	GameState.clima_forzato = OS.get_environment("SIM_CLIMA") if OS.get_environment("SIM_CLIMA") != "" else "temperato"
	for s in semi:
		_partita(100 + s * 17, anni)
	GameState.cancella_salvataggio()
	get_tree().quit()


func _partita(seme: int, anni: int) -> void:
	GameState.ricomincia()
	GameState.in_corso = false
	GameState.nuova_partita(seme)
	GameState.terreno = TerrenoFeudo.new(GameState.seme_mappa)
	for b in GameState.buildings:
		GameState.terreno.occupa(b)
	GameState._prepara_accampamento()
	var vicina := GameState.terreno.selvatica_piu_vicina(TerrenoFeudo.centro_feudo())
	if vicina != "":
		GameState.risorse[GameState.colture[vicina].semi] = float(GameState.colture.semi_iniziali)
	GameState.in_corso = true
	GameState.scegli_capo(0)
	GameState.tutorial_passo = -1
	GameState._tick_evento = 999  # niente carte evento: si guarda solo l'economia
	GameState.bil.banditi.dall_anno = 99  # e niente banditi
	GameState.bil.banditi.dal_livello = 99
	GameState.banditi = {}
	GameState.bil.feudi.probabilita_proposta = 0.0  # niente messaggeri dei signori
	_centro = TerrenoFeudo.centro_feudo()
	print("\n=== partita %d (clima %s) ===" % [seme, GameState.clima])
	if not GameState.message.is_connected(_messaggio):
		GameState.message.connect(_messaggio)
	print("stag  anno | abit/allog lib | cibo  legna pietra oro  ferro | fel | fame freddo | edifici")
	var tps := int(GameState.bil.tick_per_stagione)
	var giorni_fame := 0
	var giorni_freddo := 0
	var tot_fame := 0
	var tot_freddo := 0
	var massimo := 0
	for stagione_n in anni * 4:
		for t in tps:
			if t % 5 == 0:
				_decidi()
			# come nel gioco: il tempo scorre (cantieri compresi) e ogni tick_secondi passa un giorno
			GameState.nel_feudo = true
			GameState.velocita = 1
			var giorno := GameState.tick_in_stagione
			while GameState.tick_in_stagione == giorno and not GameState.finita:
				GameState._process(float(GameState.bil.tick_secondi) / 4.0)
			if GameState._fame:
				giorni_fame += 1
			if GameState._freddo:
				giorni_freddo += 1
			if GameState.finita:
				print("PARTITA FINITA: anno %d" % GameState.anno)
				print("RIASSUNTO seme %d: abitanti max %d, alla fine 0 (finita), giorni di fame %d, di freddo %d" % [seme, massimo, tot_fame + giorni_fame, tot_freddo + giorni_freddo])
				return
		var r := GameState.risorse
		print("%-5s %4d | %3d/%-3d %3d | %4d %5d %6d %4d %5d | %3d | %4d %6d | %s" % [
			GameState.STAGIONI[(GameState.stagione + 3) % 4].substr(0, 5), GameState.anno, GameState.abitanti, GameState.alloggi(),
			GameState.disoccupati(), int(r.cibo + r.grano + r.orzo + r.rape), int(r.legna), int(r.pietra), int(r.oro), int(r.ferro),
			int(GameState.felicita), giorni_fame, giorni_freddo, _conta()])
		tot_fame += giorni_fame
		tot_freddo += giorni_freddo
		massimo = maxi(massimo, GameState.abitanti)
		giorni_fame = 0
		giorni_freddo = 0
	print("RIASSUNTO seme %d: abitanti max %d, alla fine %d (%s), giorni di fame %d, di freddo %d" % [seme, massimo, GameState.abitanti,
		GameState.bil.livelli[GameState.livello].nome, tot_fame, tot_freddo])


func _conta() -> String:
	var n := {}
	for b in GameState.buildings:
		n[b.tipo] = int(n.get(b.tipo, 0)) + 1
	var parti: Array[String] = []
	for k in ["casa", "raccoglitore", "pescatore", "cacciatore", "campo", "taglialegna", "cava", "magazzino", "mulino", "forno", "mercato", "chiesa", "taverna"]:
		if n.has(k):
			parti.append("%s%d" % [k.substr(0, 4), n[k]])
	return " ".join(parti)


## Una decisione ogni pochi giorni, come farebbe un giocatore attento.
func _decidi() -> void:
	var r := GameState.risorse
	var cibo: float = r.cibo + r.grano + r.orzo + r.rape
	var consumo_stagione := GameState.abitanti * float(GameState.bil.cibo_per_abitante_tick) * float(GameState.bil.tick_per_stagione)
	# posti di lavoro liberi negli edifici già fatti: prima si riempiono quelli
	var posti_liberi := 0
	for b in GameState.buildings:
		posti_liberi += maxi(0, int(GameState.def_di(b).lavoratori) - int(b.lavoratori))
	var liberi := GameState.disoccupati() - posti_liberi
	var lavoratori_cibo := 0
	for b in GameState.buildings:
		var d := GameState.def_di(b)
		if d.get("produce", {}).has("cibo") or d.get("coltura", false):
			lavoratori_cibo += int(b.lavoratori)
	# 1) case per chi è senza tetto (o sta per arrivare)
	if GameState.alloggi() < GameState.abitanti + 2:
		_costruisci("casa")
	# 2) cibo: almeno un edificio del cibo ogni 5 abitanti, e di più se le scorte calano
	if liberi >= 2 and (cibo < consumo_stagione * 0.8 or lavoratori_cibo < GameState.abitanti / 3):
		for tipo in ["raccoglitore", "pescatore", "cacciatore", "campo"]:
			if _costruisci(tipo):
				liberi -= 2
				break
	# 3) legna e pietra (solo se c'è chi ci lavora)
	if liberi >= 2 and (_quanti("taglialegna") < 1 + GameState.abitanti / 12 or r.legna < 30):
		if _costruisci("taglialegna"):
			liberi -= 2
	if liberi >= 3 and (_quanti("cava") < 1 + GameState.abitanti / 20 or r.pietra < 15):
		_costruisci("cava")
	# 4) magazzino quando le scorte toccano il tetto, poi i servizi del Borgo
	if r.legna > GameState.capacita() * 0.85 or r.pietra > GameState.capacita() * 0.85 or _quanti("magazzino") == 0:
		_costruisci("magazzino")
	if GameState.livello >= 1:
		for tipo in ["mercato", "chiesa", "taverna"]:
			if _quanti(tipo) == 0:
				_costruisci(tipo)
	# 5) lavoratori: si riempiono i posti, prima il cibo
	for priorita in [["raccoglitore", "pescatore", "cacciatore", "campo"], ["taglialegna", "cava"], []]:
		for b in GameState.buildings:
			if priorita.is_empty() or b.tipo in priorita:
				while GameState.disoccupati() > 0 and b.progresso >= 1.0 and b.lavoratori < int(GameState.def_di(b).lavoratori):
					var prima: int = b.lavoratori
					GameState.aggiungi_lavoratore(b.id)
					if b.lavoratori == prima:
						break
	if GameState.anno >= 2 and _quanti("forestale") < _quanti("taglialegna") / 2 and liberi >= 1:
		_costruisci("forestale")
	# 6) miglioramenti quando avanza materiale
	if r.legna > 40 and r.pietra > 30:
		for b in GameState.buildings:
			if GameState.puo_migliorare(b) and (b.tipo in ["casa", "raccoglitore", "pescatore", "campo", "taglialegna", "cava", "magazzino"]):
				GameState.migliora(b.id)
				break


func _quanti(tipo: String) -> int:
	return GameState.buildings.filter(func(b): return b.tipo == tipo).size()


func _costruisci(tipo: String) -> bool:
	if not GameState.sbloccato(tipo) or not GameState.puo_permettersi(tipo):
		return false
	# non più di un cantiere alla volta per tipo
	for b in GameState.buildings:
		if b.tipo == tipo and b.progresso < 1.0:
			return false
	if GameState.edifici[tipo].has("zona"):
		var posto_b := GameState.terreno.trova_posto(tipo, _centro)
		# chi dipende dalla zona (bosco, rocce, acqua, fertilità) va dove rende di più
		var migliore := posto_b
		var resa_m := -1.0
		for y in range(_centro.y - 12, _centro.y + 12, 2):
			for x in range(_centro.x - 12, _centro.x + 12, 2):
				var c := Vector2i(x, y)
				if GameState.terreno.posizione_valida(tipo, c):
					var rs := GameState.terreno.resa(tipo, c, GameState.stagione)
					if rs > resa_m:
						resa_m = rs
						migliore = c
		return migliore.x >= 0 and not GameState.piazza(tipo, migliore, 1.0).is_empty()
	var posto := GameState.terreno.trova_posto(tipo, _centro)
	if posto.x < 0:
		return false
	return not GameState.piazza(tipo, posto, 1.0).is_empty()


func _messaggio(testo: String) -> void:
	for parola in ["bruci", "incendi", "spedizione", "bandit", "andat", "crollat", "strappa", "lasciato"]:
		if parola in testo.to_lower():
			print("   · anno %d %s: %s" % [GameState.anno, GameState.STAGIONI[GameState.stagione], testo])
			return
