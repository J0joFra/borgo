# Borgo

City builder medievale in 3D low-poly per mobile in orizzontale, fatto con **Godot 4.4**.
Il design completo è nel documento "Borgo — Game Design Document".

![Il feudo](docs/feudo.png)
![La mappa del regno](docs/regno.png)

## Come aprirlo

1. Scarica Godot 4.4 (versione standard, non .NET) da <https://godotengine.org/download>.
2. Nel Project Manager: **Importa** → scegli il file `project.godot` di questa cartella.
3. Premi **F5** per giocare.

Il gioco parte dalla **mappa del regno**: tocca la tua regione (bordata di rosso) per entrare nel **feudo**.
Nel feudo si torna al regno con il pulsante "Regno" o rimpicciolendo oltre lo zoom minimo.

| | Telefono | Computer |
| --- | --- | --- |
| Muovere la visuale | trascina con un dito | trascina col mouse |
| Zoom | pizzica | rotellina |
| Ruotare di 90° | pulsanti `<` `>` | pulsanti o tasti Q / E |
| Selezionare, piazzare | tocca | clic |

## Cosa c'è già

- **Mappa del regno**: 10 regioni stile carta antica (celle di Voronoi), ognuna con nome, risorsa speciale e proprietario. Zoom animato per entrare nel feudo.
- **Feudo in 3D**: diorama 48×48 celle con bordi a "fetta di terra", boschi, laghi, colline e rocce generati a caso. Telecamera isometrica ortografica con 3 livelli di zoom e rotazione.
- **Stagioni visibili**: erba e chiome cambiano colore, d'inverno nevica, la luce cambia tono.
- **Edifici low-poly provvisori** fatti con forme semplici: case con tetto, mulino con le pale che girano, chiesa con campanile, maniero con torri, mercato con bancarelle, campi che cambiano con le stagioni, cantieri con barra di avanzamento.
- **Economia** (invariata dal prototipo 2D): tick ogni 2 secondi, filiere, lavoratori, felicità, livelli, tasse al re, vittoria e sconfitta, salvataggio automatico.

**Da fare**: carte evento, banditi e difese, espansione nel regno, sentieri, abitanti che camminano, audio, modelli veri.

## Dove cambiare le cose

| Cosa | File |
| --- | --- |
| Costi, produzione, taglie, forma degli edifici | `data/edifici.json` |
| Ritmo, felicità, tasse, livelli | `data/bilanciamento.json` |
| Nomi, risorse e signori delle regioni | `data/regioni.json` |
| Regole della partita | `scripts/game_state.gd` (autoload `GameState`) |
| Terreno e regole di piazzamento | `scripts/feudo/terreno.gd` |
| Disegno del terreno, alberi, colori delle stagioni | `scripts/feudo/vista_terreno.gd` |
| Modelli degli edifici | `scripts/feudo/edificio_3d.gd` |
| Telecamera | `scripts/feudo/camera_iso.gd` |
| Gesti e scena del feudo | `scripts/feudo/feudo.gd` |
| Mappa del regno | `scripts/regno/regno.gd` |
| Interfaccia | `scripts/ui/hud.gd` |

La logica di gioco lavora su una griglia 2D di celle; il 3D è solo la sua rappresentazione.

### Mettere i modelli veri (KayKit)

Il gioco cerca da solo i modelli in `art/models/` e li usa al posto delle forme provvisorie.
Ogni modello viene centrato, appoggiato a terra e scalato per stare nell'area dell'edificio.

1. Scarica gratis **KayKit Medieval Hexagon Pack** da <https://kaylousberg.itch.io/kaykit-medieval-hexagon>
   ("Download Now", poi "No thanks, just take me to the downloads"). Licenza CC0.
2. Scompatta lo zip e copia la cartella dei modelli `gltf` (quella con le sottocartelle `buildings`, `decoration`…)
   dentro `art/models/` del progetto, ad esempio `art/models/kaykit/`.
3. Apri il progetto in Godot: importa i file da solo (la prima volta ci mette un po'). Premi F5.

Quale file va a quale edificio lo decide `data/modelli.json`: per ogni edificio c'è un elenco di parole
cercate nel nome del file, in ordine (es. la chiesa cerca `church`). `colore_preferito` sceglie la variante
di colore della fazione (`red`, `blue`, `green`, `yellow`). Se un edificio non trova nulla resta la forma
provvisoria, quindi puoi aggiungere modelli un po' alla volta. Il campo resta sempre provvisorio,
perché cambia colore con le stagioni.

Se un modello è girato dalla parte sbagliata, cambia `rotazione` (in gradi); se è troppo grande o piccolo,
`riempimento` (0,9 = occupa il 90% dell'area).

## Test

```
godot --headless --path . res://tools/test_logica.tscn
```

Controlla produzione, fame, inverno, tasse, livelli, salvataggio e regole del terreno. Stampa `TEST: OK` se tutto torna.

`tools/prova_visiva.tscn` gioca da solo qualche minuto e salva screenshot in `user://` (serve una finestra, non `--headless`).

## Esportare su Android

1. In Godot: **Editor → Gestisci modelli di esportazione → Scarica**.
2. Installa Android Studio (serve l'SDK) e imposta i percorsi in **Editor → Impostazioni editor → Esporta → Android**.
3. **Progetto → Esporta → Aggiungi → Android**, poi esporta l'APK, oppure usa il pulsante di deploy con il telefono collegato via USB.

L'orientamento è già bloccato in orizzontale. Il renderer è "Compatibility", il più adatto ai telefoni economici.
