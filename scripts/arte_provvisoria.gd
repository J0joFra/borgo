class_name ArteProvvisoria
extends RefCounted
## Pixel art provvisoria generata in codice, così il gioco parte senza asset.
## Per usare grafica vera: metti in art/tiles/ i file terreno_primavera.png,
## terreno_estate.png, terreno_autunno.png, terreno_inverno.png (112×16 px,
## 7 tile da 16×16 nell'ordine di Mappa.Terreno).

const N_TILE := 7


static func atlante_terreno(stagione: int) -> Texture2D:
	var percorso := "res://art/tiles/terreno_%s.png" % GameState.CHIAVI_STAGIONI[stagione]
	if ResourceLoader.exists(percorso):
		return load(percorso)
	var img := Image.create(16 * N_TILE, 16, false, Image.FORMAT_RGBA8)
	var p := _palette(stagione)
	var rng := RandomNumberGenerator.new()
	for t in N_TILE:
		rng.seed = 1000 + t  # stessi dettagli in ogni stagione, cambia solo il colore
		_disegna_tile(img, t * 16, t, p, rng, stagione)
	return ImageTexture.create_from_image(img)


static func _palette(stagione: int) -> Dictionary:
	var p := {
		"tronco": Color("5a3a22"), "roccia": Color("8a8a8a"), "roccia_scura": Color("5e5e5e"),
		"roccia_chiara": Color("b0b0b0"), "acqua": Color("3f7fbf"), "acqua_chiara": Color("7fb3e0"),
		"sentiero": Color("b39465"), "sentiero_scuro": Color("8f7550"), "neve": Color("f4f8fb"),
		"fiore": Color("f2d24b"), "fiore2": Color("ffffff"),
	}
	match stagione:
		GameState.PRIMAVERA:
			p.merge({"erba": Color("5a9a3c"), "erba_scura": Color("477d30"), "erba_chiara": Color("7cb84f"),
				"chioma": Color("2f6b2f"), "chioma_scura": Color("1f4d25"), "chioma_chiara": Color("4a8a3a")})
		GameState.ESTATE:
			p.merge({"erba": Color("79a33a"), "erba_scura": Color("5f852d"), "erba_chiara": Color("9cbf4f"),
				"chioma": Color("3b7a2a"), "chioma_scura": Color("285a1f"), "chioma_chiara": Color("5a9a3a")})
			p.fiore2 = p.fiore
		GameState.AUTUNNO:
			p.merge({"erba": Color("9a8a3a"), "erba_scura": Color("7a6a2c"), "erba_chiara": Color("b8a050"),
				"chioma": Color("c0632a"), "chioma_scura": Color("8a3f1c"), "chioma_chiara": Color("e08a3a")})
			p.fiore = Color("a0522d")
			p.fiore2 = Color("c0632a")
		_:
			p.merge({"erba": Color("e8eef2"), "erba_scura": Color("c9d4dc"), "erba_chiara": Color("ffffff"),
				"chioma": Color("2d5a3a"), "chioma_scura": Color("1d3d28"), "chioma_chiara": Color("f4f8fb"),
				"acqua": Color("a9cbe0"), "acqua_chiara": Color("e0f0fa"), "sentiero": Color("d8d0c4"),
				"sentiero_scuro": Color("b8ad9c")}, true)
			p.fiore = p.erba_scura
			p.fiore2 = p.erba_scura
	return p


static func _disegna_tile(img: Image, ox: int, t: int, p: Dictionary, rng: RandomNumberGenerator, stagione: int) -> void:
	# Base d'erba punteggiata, usata da quasi tutti i tile.
	for y in 16:
		for x in 16:
			var r := rng.randf()
			var c: Color = p.erba
			if r < 0.08:
				c = p.erba_scura
			elif r < 0.12:
				c = p.erba_chiara
			img.set_pixel(ox + x, y, c)

	match t:
		1:  # erba con fiori
			for i in 4:
				var x := rng.randi_range(1, 14)
				var y := rng.randi_range(1, 14)
				img.set_pixel(ox + x, y, p.fiore if i % 2 == 0 else p.fiore2)
		2:  # bosco: un albero tondo
			for y in 16:
				for x in 16:
					var d := Vector2(x - 7.5, y - 6.5)
					if d.length() <= 5.8:
						var c: Color = p.chioma
						if d.x + d.y > 4.0:
							c = p.chioma_scura
						elif d.x + d.y < -5.0:
							c = p.chioma_chiara
						if stagione == GameState.INVERNO and d.y < -3.0:
							c = p.neve
						img.set_pixel(ox + x, y, c)
			for y in range(12, 16):
				img.set_pixel(ox + 7, y, p.tronco)
				img.set_pixel(ox + 8, y, p.tronco)
		3:  # acqua con riflessi
			for y in 16:
				for x in 16:
					img.set_pixel(ox + x, y, p.acqua)
			for i in 5:
				var x := rng.randi_range(0, 12)
				var y := rng.randi_range(1, 14)
				for k in 3:
					img.set_pixel(ox + x + k, y, p.acqua_chiara)
		4:  # roccia: un masso
			for y in 16:
				for x in 16:
					var d := Vector2((x - 7.5) / 6.5, (y - 8.5) / 5.5)
					if d.length() <= 1.0:
						var c: Color = p.roccia
						if d.x + d.y > 0.6:
							c = p.roccia_scura
						elif d.x + d.y < -0.8:
							c = p.roccia_chiara
						if stagione == GameState.INVERNO and d.y < -0.5:
							c = p.neve
						img.set_pixel(ox + x, y, c)
		5:  # collina: erba più scura con curve di livello
			for y in 16:
				for x in 16:
					if img.get_pixel(ox + x, y) == p.erba:
						img.set_pixel(ox + x, y, p.erba_scura)
			for x in 16:
				if x % 3 != 2:
					img.set_pixel(ox + x, 4 + int(abs(x - 8) / 4.0), p.roccia_scura)
					img.set_pixel(ox + x, 11 + int(abs(x - 8) / 4.0), p.roccia_scura)
		6:  # sentiero
			for y in 16:
				for x in 16:
					img.set_pixel(ox + x, y, p.sentiero_scuro if rng.randf() < 0.15 else p.sentiero)
