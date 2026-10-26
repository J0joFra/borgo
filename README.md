# Borgo

City builder medievale in 3D low-poly per mobile in orizzontale, fatto con **Godot 4.4**.
Il design completo è nel documento "Borgo — Game Design Document".

![Il prologo: chi guiderà i sopravvissuti?](docs/prologo.png)
![Una carta evento raccontata da un consigliere](docs/carta_evento.png)
![Banditi in arrivo con le torce: la gente corre alla dimora](docs/banditi.png)
![Tasse della stagione e difesa nel pannello Info](docs/info_tasse.png)
![Dopo un anno il falò diventa la piazza; la gente cammina lungo le strade](docs/piazza.png)
![Le tende reggono una stagione: servono case vere](docs/tende.png)
![Il falò, la torre del signore e le tende](docs/falo.png)
![Campo di rape: coltura, semi e resa](docs/colture.png)
![Il mercato del regno](docs/mercato.png)
![Il forestale ripianta il bosco](docs/forestale.png)
![Dove mettere un campo: la terra fertile si colora](docs/zone.png)
![Il bosco tagliato dal taglialegna e il fiume](docs/disboscamento.png)
![Il feudo con i modelli KayKit](docs/feudo.png)
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

Una partita nuova comincia con il **prologo**: il Regno di Valmora è caduto e, attorno a un falò, restano tre famiglie.
Scegli quale casata guiderà i sopravvissuti; le altre due diventano il tuo **consiglio** e ti danno suggerimenti
(pulsante "Consiglio" e avvisi in alto). Dalle partite successive il gioco parte dalla **mappa del regno**:
tocca la tua regione (bordata di rosso) per entrare nel **feudo**.
Nel feudo si torna al regno con il pulsante "Regno" o rimpicciolendo oltre lo zoom minimo.

| | Telefono | Computer |
| --- | --- | --- |
| Muovere la visuale | trascina con un dito | trascina col mouse |
| Zoom | pizzica | rotellina |
| Ruotare di 90° | pulsanti `<` `>` | pulsanti o tasti Q / E |
| Selezionare, piazzare | tocca | clic |

## Cosa c'è già

- **Prologo**: tre casate pescate a caso fra sei (data/famiglie.json), ognuna con capofamiglia, storia, motto e un tratto
  che vale se guida (es. Boscaioli +20% legna, Costruttori cantieri più veloci). Si parte con un falò e una tenda per famiglia,
  con la bandiera del suo colore.
- **Carte evento**: quasi ogni stagione un consigliere racconta qualcosa che succede (profughi alle porte, lupi nel bosco,
  la festa del raccolto, un inverno rigido, le nozze del barone...) e tu scegli cosa fare. Il tempo si ferma finché non
  scegli; le scelte che non puoi permetterti sono spente. Alcune hanno effetti che durano qualche stagione
  (un edificio rallentato, raccolti migliori, più legna per scaldarsi, tassa del re dimezzata). Racconta il consigliere
  esperto di quella materia. Le carte sono in `data/eventi.json` e se ne aggiungono facilmente.
- **Banditi e difese** (dal Borgo in poi, o comunque dal terzo anno): ogni tanto una banda viene avvistata al confine.
  Un consigliere avvisa da dove arriva, quanti sono e quanto siamo forti; in alto resta il conto alla rovescia.
  I banditi (con le torce) camminano verso la dimora e la gente corre a rifugiarsi lì, dritta, senza seguire le strade.
  La difesa è la somma di milizia (tutti gli abitanti), guardie nelle **torri di guardia** (valgono molto di più, ×1,5 se
  armate) e **palizzate**. L'**armeria** fa armi con ferro e legna. La torre avvista la banda prima: più giorni per
  prepararsi. Se vinciamo la gente festeggia; se perdiamo rubano una parte delle scorte (tanto più quanto eravamo deboli),
  qualcuno muore e, se eravamo molto deboli, bruciano un edificio (restano le rovine da sgomberare).
- **Tasse a ogni stagione**: a fine stagione si incassa oro secondo la media fra risorse, popolazione e gradimento.
  La media cade in una fascia (bassa, media, buona, massima) e ogni stagione ha le sue monete per fascia: in primavera,
  estate e autunno 1-2-3-4, in inverno 2-3-4-5, per ogni 10 abitanti. Tasse basse ne danno la metà (ma la gente è più
  contenta), alte una volta e mezza. In autunno si paga anche il re. Il pannello Info mostra fascia e voci.
- **Crescita fino al Borgo**: finché si è Villaggio la gente arriva più facilmente, così in circa un anno e mezzo, due
  (con case, cibo e un magazzino) si diventa Borgo e si sbloccano mulino, armeria, difese e il resto.
- **Raccoglitori e piante selvatiche**: vicino a una macchia di orzo, grano o rape selvatici, nella stagione di quella
  pianta il raccoglitore porta 2 raccolti su 3 di quella pianta e 1 di cibo; fuori stagione, o lontano dalle piante, solo cibo.
- **Consiglio**: i due consiglieri guardano il villaggio e suggeriscono cosa fare, ognuno sulla sua arte (cibo, legna,
  case, oro, felicità, costruire); non ripetono mai lo stesso consiglio. In futuro potranno diventare vassalli delle terre conquistate.
- **Dimora del signore**: scelta la guida, la tenda della sua famiglia diventa una torre a forma di castello attaccata al falò:
  il centro del feudo. Si migliora in "Torre del signore".
- **Popolazione**: la gente arriva un po' alla volta se c'è posto, più spesso se il villaggio è felice e pieno di scorte
  (e di legna prima dell'inverno). Con la fame la felicità scende piano e ogni tanto qualcuno se ne va; idem se si è scontenti.
- **Colture con semi**: orzo (primavera-estate), grano (estate-autunno), rape (autunno-inverno: crescono anche con la neve).
  Il campo si semina all'inizio della prima stagione della coltura, consumando semi, e al raccolto ne restituisce di più.
  Sulla mappa ci sono macchie di **piante selvatiche**: si parte con i semi di quella più vicina al falò; un campo messo sopra
  la sua pianta selvatica non chiede semi e rende di più; il raccoglitore vicino alle piante selvatiche raccoglie semi.
- **Mercato del regno** (pulsante "Mercato"): si compra e si vende a lotti di 10. I prezzi seguono le regioni della mappa
  (più regioni producono una cosa, meno costa), oscillano a ogni stagione e cambiano con gli eventi del regno (carestie,
  incendi, nuove miniere...). D'inverno il cibo rincara. Con un edificio "mercato" si fanno prezzi migliori.
- **Forestale**: ripianta gli alberi nelle radure lasciate dai taglialegna (poi sui prati); in un anno tornano bosco.
- **Strade** (pulsante "Strade"): tocchi l'inizio e la fine, il percorso è a L. Costano 1 pietra per cella in piano e 2 in salita;
  sulle strade non si costruisce. Toccando una strada la si può togliere. Un edificio con lavoratori che non tocca una strada
  collegata alla piazza (o che non è attaccato alla piazza o alla dimora) lavora il **2% in meno**: il pannello lo dice.
  All'inizio dalla dimora parte già una strada corta, l'inizio del borgo.
- **Piazza**: dopo il primo anno il falò diventa la piazza del borgo (un pozzo sul selciato), il centro delle strade.
- **Tende e senzatetto**: le tende reggono una sola stagione, poi si strappano: bisogna costruire case. Chi resta
  senza un tetto aspetta al massimo mezza stagione, poi se ne va.
- **Abitanti che camminano**: ognuno ha una casa e, se lavora, va e viene dal suo edificio; i disoccupati stanno attorno
  al falò (poi in piazza). Se vicino a partenza e arrivo c'è una strada, camminano lungo le strade.
- **Simboli**: ogni risorsa ha il suo simbolino (legna, pietra, mela, spiga, rapa, lingotto, martello, moneta), così come
  abitanti/posti letto, persone senza lavoro e la felicità (una faccina che sorride o si imbroncia).
- **Zone del territorio**: ogni cella ha una fertilità (più alta vicino all'acqua, la terra fertile è un verde più scuro).
  Taglialegna, cava, cacciatore e raccoglitore rendono di più con tanto bosco o tante rocce attorno; il pescatore rende di
  più sul lago che sul fiume, ma d'inverno il lago gela e la pesca crolla; il campo rende in base alla fertilità.
  Mentre scegli dove costruire, le celle che contano si colorano e il pannello mostra la resa stimata.
- **Disboscamento**: il taglialegna abbatte il bosco attorno; un bosco grande rende tanto ma sparisce in 3 anni (restano i ceppi).
- **Miglioramenti** a due livelli: case, magazzini e tutti gli edifici della natura. Costano legna e
  **pietra**, che ora serve anche per case, magazzini e quasi tutti gli edifici.
- **Campi** disponibili da subito: il grano si raccoglie in autunno e sfama quando il cibo finisce (con mulino e forno vale il doppio).
- **Mondo esteso**: il feudo (48×48 celle) sta al centro di un mondo di 112×112; oltre la linea gialla del confine
  ci sono le terre dei vicini, che si vedono ma dove non si costruisce.
- **Mappa del regno**: 10 regioni stile carta antica, ognuna con nome, risorsa speciale e proprietario. Zoom animato per entrare nel feudo.
- **Feudo in 3D** con modelli KayKit, telecamera isometrica con zoom e rotazione, stagioni visibili (erba, chiome, neve, luce).
- **Economia**: tick ogni 2 secondi, filiere, lavoratori, felicità, livelli, tasse al re, vittoria e sconfitta, salvataggio automatico.

**Da fare**: conquista delle regioni e vassalli, mura in pietra, audio.

## Dove cambiare le cose

| Cosa | File |
| --- | --- |
| Costi, produzione, zone, miglioramenti degli edifici | `data/edifici.json` |
| Ritmo, felicità, tasse, livelli | `data/bilanciamento.json` |
| Nomi, risorse e signori delle regioni | `data/regioni.json` |
| Casate, tratti, nome del regno caduto | `data/famiglie.json` |
| Colture: stagioni, resa, semi | `data/colture.json` |
| Mercato: prezzi, margini, eventi del regno | `data/mercato.json` |
| Carte evento: testi, scelte, effetti | `data/eventi.json` |
| Simbolini delle risorse | `scripts/ui/icona_risorsa.gd` |
| Banditi, tasse stagionali, crescita prima del Borgo | `data/bilanciamento.json` (`banditi`, `tasse_stagionali`, `crescita_prima_del_borgo`) |
| Banditi che si vedono sul feudo | `scripts/feudo/banditi.gd` |
| Regole del mercato | `scripts/mercato.gd` |
| Regioni della mappa (condivise da mappa e mercato) | `scripts/regno/regioni.gd` |
| Consigli dei consiglieri | `scripts/consiglio.gd` |
| Prologo davanti al falò | `scripts/ui/prologo.gd` |
| Regole della partita | `scripts/game_state.gd` (autoload `GameState`) |
| Terreno e regole di piazzamento | `scripts/feudo/terreno.gd` |
| Fiume, fertilità, zone, disboscamento, piantine, piante selvatiche, strade | `scripts/feudo/terreno.gd` |
| Disegno del terreno, alberi, ceppi, zone colorate | `scripts/feudo/vista_terreno.gd` |
| Abitanti che camminano | `scripts/feudo/abitanti.gd` |
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
