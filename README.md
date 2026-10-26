# Borgo

City builder medievale in pixel art per mobile in orizzontale, fatto con **Godot 4.4**.
Il design completo è nel documento "Borgo — Game Design Document".

## Come aprirlo

1. Scarica Godot 4.4 (versione standard, non .NET) da <https://godotengine.org/download>.
2. Nel Project Manager: **Importa** → scegli la cartella `borgo` (il file `project.godot`).
3. Premi **F5** per giocare.

Sul computer si gioca col mouse: trascina per muovere, rotellina per lo zoom, clic per selezionare.
Sul telefono: trascina con un dito, pizzica per lo zoom, tocca per selezionare.

## Cosa c'è già (milestone 1-3 del documento, più qualcosa della 4)

- Mappa 64×64 generata a caso, con bosco, lago, rocce e colline sempre vicini al centro.
- Grafica provvisoria generata in codice; le tile cambiano colore con le stagioni (neve d'inverno).
- Telecamera con trascinamento e zoom a scatti interi, per pixel sempre nitidi.
- Menu di costruzione ai lati, anteprima verde/rossa, cantieri con barra di avanzamento.
- Tick ogni 2 secondi: produzione, filiere (grano → farina → pane, ferro → utensili), consumo di cibo, legna d'inverno.
- Lavoratori con + e −, felicità, arrivo delle famiglie, livelli Villaggio → Borgo → Città.
- Tasse al re in autunno, sconfitta e vittoria (completare il maniero).
- Velocità pausa/x1/x2/x3, salvataggio automatico a fine stagione e quando l'app va in pausa.

**Da fare** (milestone 4-6): carte evento, banditi, caserma e mura, sentieri obbligatori, abitanti che camminano, musica, tutorial.

## Dove cambiare le cose

| Cosa | File |
| --- | --- |
| Costi, produzione, taglie degli edifici | `data/edifici.json` |
| Ritmo, felicità, tasse, livelli | `data/bilanciamento.json` |
| Regole della partita | `scripts/game_state.gd` (autoload `GameState`) |
| Terreno, piazzamento, bonus di vicinanza | `scripts/map.gd` |
| Disegno provvisorio degli edifici | `scripts/vista_edificio.gd` |
| Interfaccia | `scripts/ui/hud.gd` |
| Gesti touch e mouse | `scripts/main.gd` |

### Mettere la grafica vera

- **Terreno**: crea 4 immagini da 112×16 px (7 tile da 16×16: erba, erba con fiori, bosco, acqua, roccia, collina, sentiero)
  e salvale come `art/tiles/terreno_primavera.png`, `terreno_estate.png`, `terreno_autunno.png`, `terreno_inverno.png`.
  Il gioco le usa al posto di quelle generate.
- **Edifici**: per ora sono disegnati con rettangoli in `vista_edificio.gd`; quando hai gli sprite, sostituisci `_draw()` con uno `Sprite2D`.
- **Font**: il font di default va bene per provare; per un look pixel scarica un font come *m5x7* e impostalo nel tema in `hud.gd` (`_crea_tema`).

Asset gratuiti utili: Kenney "Tiny Town" (CC0), itch.io (cerca "16x16 medieval village"), palette da Lospec.

## Test

```
godot --headless --path . res://tools/test_logica.tscn
```

Controlla produzione, fame, inverno, tasse, livelli e salvataggio. Stampa `TEST: OK` se tutto torna.

## Esportare su Android

1. In Godot: **Editor → Gestisci modelli di esportazione → Scarica**.
2. Installa Android Studio (serve l'SDK) e imposta i percorsi in **Editor → Impostazioni editor → Esporta → Android**.
3. **Progetto → Esporta → Aggiungi → Android**, poi esporta l'APK e installalo sul telefono, oppure usa il pulsante di deploy con il telefono collegato via USB.

L'orientamento è già bloccato in orizzontale (`sensor_landscape`).
