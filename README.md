# Borgo

City builder medievale in 3D low-poly per mobile in orizzontale, fatto con **Godot 4.4**.
Il design completo è nel documento "Borgo — Game Design Document".

![Il feudo](docs/feudo.png)
![La mappa del regno](docs/regno.png)

## Provare il gioco

**Nel browser (anteprima):** a ogni push su `main` il workflow "Anteprima web" esporta il gioco e lo pubblica su
<https://j0jofra.github.io/borgo/>. Funziona anche dal telefono. Va attivato una volta sola:
**Settings → Pages → Source: GitHub Actions**. (Su un repository privato GitHub Pages richiede un piano a pagamento;
altrimenti rendi pubblico il repository.)

**In Godot:**

1. Installa [GitHub Desktop](https://desktop.github.com/) e clona questo repository (**File → Clone repository → borgo**).
2. Scarica Godot 4.4 (versione standard, non .NET) da <https://godotengine.org/download>.
3. Nel Project Manager di Godot: **Importa** → scegli il file `project.godot` nella cartella clonata. Premi **F5** per giocare.

**Tenere GitHub e Godot allineati:** Godot lavora sui file della cartella clonata, non su GitHub.
- Per avere sul tuo PC le modifiche arrivate su GitHub: in GitHub Desktop **Fetch origin**, poi **Pull origin**.
  Torna su Godot: si accorge da solo dei file cambiati e li reimporta (se una scena era aperta, chiudila e riaprila).
- Per mandare su GitHub le tue modifiche: in GitHub Desktop scrivi un messaggio, **Commit to main**, poi **Push origin**.

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

### Modelli 3D (KayKit)

Gli edifici usano il **KayKit Medieval Hexagon Pack** (CC0, di Kay Lousberg) in `art/models/kaykit/`:

| Cartella | Contenuto |
| --- | --- |
| `buildings/red`, `blue`, `green`, `yellow` | edifici nei 4 colori delle fazioni |
| `buildings/neutral` | cantieri, campo di grano, mura, ponti |
| `props` | casse, barili, tende, bandiere |
| `nature` | alberi, rocce, colline, montagne |
| `info` | licenza, guida e immagini del pacchetto (Godot la ignora) |

Il gioco cerca i modelli da solo: `data/modelli.json` dice, per ogni edificio, quale parola cercare nel nome del file
(es. la chiesa cerca `building_church`). Si possono cambiare liberamente:

- `colore_preferito`: il colore della tua fazione (`red`, `blue`, `green`, `yellow`).
- `scala`: quanti metri vale un'unità del pacchetto (4 = una casa grande come 2×2 celle). Uguale per tutti, così le proporzioni restano giuste.
- `riempimento`: se un modello è più grande della sua area viene rimpicciolito fino a questa quota (0,92 = 92%).
- `rotazione`: gira tutti i modelli (in gradi).
- `cantiere`: i modelli mostrati durante la costruzione, uno per fase.

Gli OBJ di KayKit sono divisi in pezzi (es. mulino: base, tetto, pale): il gioco li unisce e fa girare pale e ruote.
Se per un edificio non trova nulla usa la forma provvisoria in codice. Alberi e rocce del terreno restano quelli
generati in codice, perché cambiano colore con le stagioni; anche il campo di grano KayKit resta dorato tutto l'anno.

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

L'orientamento è già bloccato in orizzontale. Il renderer è "Compatibility", il più adatto ai telefoni economici e al browser.
