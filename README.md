# Borgo

City builder medievale in 3D low-poly per mobile in orizzontale, fatto con **Godot 4.4**.
Il design completo è nel documento "Borgo — Game Design Document".

![Il menu principale](docs/menu.png)
![Il prologo: chi guiderà i sopravvissuti?](docs/prologo.png)
![La battaglia sul campo come il feudo](docs/battaglia.png)
![L'assedio di una città: mura, torri, case, e un fante salito con le scale](docs/assedio.png)
![Vittoria: l'esercito nemico è distrutto](docs/battaglia_fine.png)
![Il tutorial dopo il prologo](docs/tutorial.png)
![Il primo inverno senza cibo: il castello apre le porte](docs/primo_inverno.png)
![Una carta evento raccontata da un consigliere](docs/carta_evento.png)
![Banditi in arrivo con le torce: la gente corre alla dimora](docs/banditi.png)
![Tasse della stagione e difesa nel pannello Info](docs/info_tasse.png)
![Mura in pietra con le torri e la caserma](docs/mura.png)
![Gli arcieri sulla torre e i banditi che arrivano](docs/arcieri.png)
![Una regione conquistata e il suo vassallo](docs/vassalli.png)
![Un ponte sul fiume](docs/ponte.png)
![Una passerella sul lago e la caserma con i soldati](docs/caserma.png)
![La scheda di un regno vicino: spie, alleanze, attacco](docs/regni.png)
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

Il gioco si apre sul **menu principale** (un piccolo diorama del borgo che gira): Continua (con anno, casata e
livello della partita salvata), Nuova partita (chiede conferma se ce n'è una salvata), Opzioni (tutorial nelle
partite nuove, suggerimenti, schermo intero), **Prova battaglia** e Crediti. Prova battaglia serve a provare le
battaglie senza giocare una partita: si sceglie contro chi (signore, banditi, terra libera), quanti soldati, armi e
uomini dei vassalli abbiamo e quanti uomini ha il nemico, poi si combatte; alla fine si torna alla prova e la
partita salvata non cambia. Dalla mappa del regno il pulsante "Menu" ci riporta.

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
- **Tutorial**: dopo il prologo un riquadro in alto a destra guida i primi passi (taglialegna, raccoglitore, lavoratori,
  strade, case, cava, campo, consiglio); il pulsante da usare lampeggia e il passo avanza da solo quando lo fai.
  Si può saltare, e rivedere dal pannello Info.
- **Suggerimenti**: ogni tanto, finito il tutorial, compare un consiglio su come si gioca (più spesso i primi due anni).
  Si spengono dal pannello Info. Testi del tutorial e dei suggerimenti in `data/tutorial.json`.
- **Il primo inverno**: se il cibo finisce, la guida raduna tutti nel suo castello e divide le sue scorte (+50 cibo,
  una volta sola). Per tutto il primo anno nessuno se ne va per la fame o per lo scontento.
- **Carte evento**: quasi ogni stagione un consigliere racconta qualcosa che succede (profughi alle porte, lupi nel bosco,
  la festa del raccolto, un inverno rigido, le nozze del barone...) e tu scegli cosa fare. Il tempo si ferma finché non
  scegli; le scelte che non puoi permetterti sono spente. Alcune hanno effetti che durano qualche stagione
  (un edificio rallentato, raccolti migliori, più legna per scaldarsi, tassa del re dimezzata). Racconta il consigliere
  esperto di quella materia. Le carte sono in `data/eventi.json` e se ne aggiungono facilmente.
  Escono solo carte in cui almeno una scelta si può fare; se nel frattempo le risorse cambiano, compare
  "Non possiamo fare niente" e la carta si chiude senza effetti.
- **Banditi e difese** (dal Borgo in poi, o comunque dal terzo anno): ogni tanto una banda viene avvistata al confine.
  Un consigliere avvisa da dove arriva, quanti sono e quanto siamo forti; in alto resta il conto alla rovescia.
  I banditi (con le torce) camminano verso la dimora, girando attorno a laghi e fiumi (passano solo sui ponti), e la gente corre a rifugiarsi lì, dritta, senza seguire le strade.
  La **torre di guardia**, appena finita, ha **2 arcieri** in cima che non si tolgono e non tolgono lavoratori. Tirano
  ai banditi che passano entro **3 celle per lato** (toccando la torre si vede il riquadro): ogni giorno nel raggio
  la banda perde forza e si vedono le frecce e i banditi che cadono; i loro arcieri rispondono e possono uccidere i
  nostri (ne sale uno nuovo a ogni stagione). Se le frecce bastano, la banda scappa prima di arrivare. Gli arcieri
  combattono anche nella battaglia finale se il centro del borgo è nel loro raggio. La torre avvista la banda prima.
  La difesa è la somma di milizia, arcieri, soldati, **palizzate**, **mura**, alleati e truppe dei vassalli.
  L'**armeria** addestra i soldati (vedi Esercito).
- **Mura in pietra** (menu Difese, dal Borgo): si tracciano come le strade ma occupano le celle, 4 pietra l'una. Ogni
  cella dà un po' di difesa; se le mura **chiudono il borgo** tutto attorno (i banditi non trovano un passaggio) la
  difesa vale il 50% in più. Dove una strada passa fra due celle di mura si apre una **porta**: la gente passa, ma in
  guerra le porte restano chiuse. I banditi camminano attorno ad acqua e mura. Se vinciamo la gente festeggia; se perdiamo rubano una parte delle scorte (tanto più quanto eravamo deboli),
  qualcuno muore e, se eravamo molto deboli, bruciano un edificio (restano le rovine da sgomberare).
- **Esercito** (pulsante "Esercito"): i soldati **non sono abitanti**. L'**armeria** li addestra **uno alla volta** da
  una coda (si paga quando li si mette in coda; "Togli l'ultimo" restituisce il materiale); più gente lavora
  nell'armeria e più è migliorata, più in fretta. Sopra l'armeria un anello mostra l'avanzamento.
  | Livello armeria | Soldati | Costo | Giorni |
  |---|---|---|---|
  | 1 Armeria | lancieri | 2 legna, 1 pietra | 3 |
  | 2 Armeria fornita | spadaccini · arcieri | 1 legna, 2 ferro · 3 legna | 4 · 4 |
  | 3 Arsenale | balestrieri | 2 legna, 2 ferro | 5 |
  | 4 Grande arsenale | cavalieri | 3 ferro, 5 oro | 7 |

  La **caserma** tiene i soldati: 10, poi migliorandola 15, 20 e 25. L'esercito costa **una volta l'anno, all'arrivo
  dell'inverno**: i soldati / 10 arrotondato, metà in cibo e metà in oro (se è dispari l'oro paga uno in più; es. 88
  soldati → 9 → 4 cibo e 5 oro). Se non si paga tutto, se ne va la parte non pagata. I soldati a casa difendono dai
  banditi con la forza del loro tipo e si vedono attorno alla caserma; servono per attaccare gli altri regni.
  Tipi, costi e giorni sono in `bilanciamento.json` (`esercito.tipi`).
- **Regni vicini** (dal Borgo, sulla mappa del Regno): toccando un'altra regione si apre la sua scheda.
  - **Spia** (15 oro, torna dopo un mese): dice quanto è forte il regno e cosa pensa di noi; a volte viene scoperta.
  - **Alleanza** (dono di 30 oro, solo con un signore): più è amichevole, più è facile che accetti. Un alleato manda
    rinforzi contro i banditi e un piccolo dono ogni stagione.
  - **Attacco e battaglia** (in stile Humankind): parte tutto l'esercito a casa e arriva dopo un mese. Allora si apre
    il **campo di battaglia**: un piccolo diorama a quadretti come il terreno del feudo (le diagonali contano come un passo), con i colori del suolo, gli alberi e la luce del clima della regione e della stagione, colline a gradoni, boschetti e stagni: le nostre unità a sinistra (lancieri,
    spadaccini, arcieri, balestrieri, cavalieri; uomini dei vassalli), quelle nemiche a destra a difesa della loro
    **bandiera** (cavalieri e balestrieri dei signori, predoni, contadini armati). Prima lo **schieramento**: si tocca
    una nostra unità e poi una cella della zona azzurra (sulle nostre unità si scambiano), poi "Inizia la battaglia".
    Tocchi un'unità: le celle chiare sono dove può andare (boschi e colline costano 2 mosse), i nemici rossi quelli
    che può attaccare. Il **primo tocco su un nemico mostra le perdite previste** con i bonus, il secondo attacca.
    Corpo a corpo il difensore risponde, da lontano no. Regole: **altura** (dalla collina +25%, dal basso in mischia
    -15%, e si tira più lontano), **fianchi** (+10% per ogni altra nostra unità attorno al bersaglio, fino a 3),
    **supporto** (+10% in difesa per ogni compagno accanto, fino a 3), **lance contro cavalli** (×1,5), il bosco
    difende. Ogni unità ha la barra degli uomini rimasti. "Fine turno" fa muovere il nemico: difende la bandiera e
    attacca chi si avvicina, e dal 5° turno va all'assalto. **Non c'è limite di turni**: si vince distruggendo il loro
    esercito o tenendo la loro bandiera per un turno; si perde se cadono tutti i nostri. Si può sempre ritirarsi.
    **Assedio**: contro un signore la bandiera sta dentro le sue difese, che dipendono da **quanto è cresciuto il suo
    feudo**: **palizzata** di legno (villaggio, porta da 10, difesa ×1,25), **mura di pietra** (borgo, porta da 20,
    difesa ×1,5), **castello con le torri** e le case dentro le mura (città, porta da 30; dalle torri si tira due celle
    più lontano). Sulle mura stanno i difensori a piedi (i cavalli mai): colpiscono dall'alto e chi tira arriva una
    cella più lontano. Per entrare: sfondare la **porta** corpo a corpo (le frecce non la aprono, e lei non risponde),
    oppure **le scale**: un fante (lancieri o spadaccini) accanto a un bosco **abbatte un albero** (il bosco diventa
    radura), il turno dopo **costruisce le scale** e da lì può salire sulle mura. Gli assediati non escono all'assalto.
  - **I feudi dei signori crescono come il nostro**: ognuno ha i suoi abitanti, che a ogni stagione si avvicinano a
    quanti ne ha il nostro borgo (chi più in fretta, chi meno, e un po' ogni anno anche se noi restiamo piccoli; non
    calano mai). Dagli abitanti vengono il livello (villaggio, borgo, città, con le stesse soglie del nostro),
    l'esercito (0,3 soldati per abitante) e le difese dell'assedio. La spia racconta quanti sono e come sono difesi.
    Vincendo la regione è nostra e la governa un **vassallo**. Conquistare un covo di banditi fa arrivare meno incursioni.
    Perdendo torna solo una parte dei soldati.
  - **Vassalli** (scheda di una regione conquistata): la governa un consigliere libero oppure un cavaliere ("Affida a").
    Ogni stagione manda un tributo: oro, la risorsa della regione e qualcosa nell'arte della sua casata (es. i boscaioli
    più legna). Si sceglie quanto chiedere: **basso** (meno roba, la lealtà sale), **normale**, **alto** (di più, ma la
    lealtà scende). Più è leale, più truppe manda contro i banditi e in guerra. Sotto il 30% di lealtà può **ribellarsi**:
    la regione torna libera e, se era un consigliere, la sua casata lascia il consiglio.
  Spie, messaggeri ed esercito viaggiano mentre il tempo scorre nel feudo; sulla mappa si vede la linea del viaggio.
- **Il re**: in alto, accanto all'oro, la corona mostra la tassa che il re vorrà in autunno (rossa se non basta l'oro).
  Diventati **Borgo** ci si stacca dal regno: niente più tasse, ma il re ci guarda con diffidenza (la corona mostra
  cosa pensa di noi). Ogni tanto manda un messo a chiedere un tributo: pagando si calma, rifiutando si arrabbia; se
  diventa molto ostile manda il suo esercito, che arriva come i banditi (ma più forte).
- **Tributo delle case**: ogni casa abitata paga ogni stagione 1 moneta se ospita fino a 4 persone, 2 fino a 6,
  3 fino a 8.
- **Miglioramenti**: case fino a 8 abitanti (Casa grande 6, Casa in pietra 8); tutte le strutture con lavoratori si
  migliorano due volte, fino a 4 posti di lavoro, e ogni livello rende di più (+30%, poi +60%). Costano legna e pietra.
  **Ogni lavoratore produce la sua parte** (es. raccoglitore: 20 cibo a testa a stagione) e il livello la moltiplica:
  migliorare non fa mai rendere meno, e ogni posto in più occupato aggiunge produzione (raccoglitore al massimo:
  4 × 20 × 1,6 = 128 cibo). Anche taverna, chiesa e mercato migliorati danno più felicità.
- **Musica e suoni**: tre musiche (il borgo, la mappa e il menu, la battaglia) ed effetti per pulsanti, cantieri,
  edifici finiti, monete, campana delle stagioni, carte, corno dei banditi, frecce, spade, vittoria e sconfitta.
  Si spengono dalle Opzioni o dal pannello Info. Tutto è generato da `tools/genera_audio.py` (niente file esterni).
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
  La coltura di un campo si cambia con una conferma (se era già seminato, il raccolto in corso si perde).
  Il campo si semina all'inizio della prima stagione della coltura, consumando semi, e al raccolto ne restituisce di più.
  Sulla mappa ci sono macchie di **piante selvatiche**: si parte con i semi di quella più vicina al falò; un campo messo sopra
  la sua pianta selvatica non chiede semi e rende di più; il raccoglitore vicino alle piante selvatiche raccoglie semi.
- **Mercato del regno** (pulsante "Mercato"): si compra e si vende a lotti di 10. I prezzi seguono le regioni della mappa
  (più regioni producono una cosa, meno costa), oscillano a ogni stagione e cambiano con gli eventi del regno (carestie,
  incendi, nuove miniere...). D'inverno il cibo rincara. Con un edificio "mercato" si fanno prezzi migliori.
  Con il mercato costruito si apre la scheda **Automatico**: per ogni risorsa si sceglie "vendi oltre" (es. grano oltre
  200: l'eccesso si vende da solo) e "compra sotto" (se scende sotto, si compra), più l'oro da tenere sempre da parte.
  Lo fa **a ogni cambio di stagione**, ai prezzi nuovi: prima vende tutto l'eccesso, poi compra quel che manca (senza
  toccare la riserva d'oro, che parte da 0). Un messaggio dice cosa ha fatto e, se non ha potuto comprare, perché
  (oro insufficiente o magazzino pieno).
- **Forestale**: ripianta gli alberi nelle radure lasciate dai taglialegna (poi sui prati); in un anno tornano bosco.
- **Strade** (pulsante "Strade"): non occupano celle, corrono **lungo i bordi fra una cella e l'altra**: così gli
  edifici si possono accostare e la strada passa loro accanto. Basta **toccare un edificio o un punto**: la strada
  parte da sola dalla rete già collegata e cerca il percorso più conveniente, girando attorno a case, bosco, rocce e
  bordi di collina (se non c'è passaggio lo dice). Un edificio non collegato ha il pulsante **Collega** e, sulla mappa,
  un segnale rosso da toccare: mostrano subito la strada da fare. Partono dal falò o dalla piazza, dalla dimora del signore o da una torre di guardia: un edificio con
  lavoratori che non è collegato a una di queste (con una strada, o toccandole) lavora il **2% in meno**.
  1 pietra per tratto in piano, 2 in salita; non si fanno lungo il bordo di una collina (a metà del gradino). Fra due celle di fiume la strada è un **ponte** (3 legna e 2 pietra), fra
  due di lago una **passerella** (3 legna, al massimo 3 tratti di fila). Una strada non può passare dentro un edificio.
  Toccando un tratto di strada lo si può togliere. All'inizio dalla dimora parte già una strada corta.
- **Segni sopra gli edifici**: un anello che si riempie fino alla prossima consegna del raccolto (con l'icona della
  risorsa), un anello col martello sui cantieri, una **freccia verde** dove si può migliorare adesso (toccandola si
  apre l'edificio) e un **segnale rosso** dove manca la strada (toccandolo la si traccia).
- **Telefono**: sugli schermi touch si accende da sola l'**interfaccia grande** (×1,3: pulsanti e testi più grossi;
  si cambia nelle Opzioni del menu o nell'Info). Le finestre hanno la X in alto e scorrono se lo schermo è basso;
  toccando un numero della barra in alto se ne leggono i dettagli; i pulsanti ai bordi stanno dentro l'area sicura
  (notch); col telefono in verticale un velo chiede di girarlo.
- **Interfaccia** scura e minimale, pensata per il telefono in orizzontale: risorse e tempo in due capsule in alto,
  pulsanti tondi a icona ai lati (tenendoli premuti compare il nome), pannelli semitrasparenti con l'oro come accento.
- **Ruotare gli edifici**: mentre si piazza, pulsante "Ruota" (o tasto R) per girarlo di 90°.
  Anche dopo: nel pannello di un edificio, **Gira** lo ruota sul posto e **Sposta** lo sposta fino a 2 caselle in ogni
  direzione (anteprima verde o rossa, riquadro delle caselle permesse; si può girare mentre lo si sposta).
- **Demolire** ridà la metà dei materiali spesi per l'edificio, miglioramenti compresi (la conferma dice quanto).
- **Piazza**: dopo il primo anno il falò diventa la piazza del borgo (un pozzo sul selciato), il centro delle strade.
- **Tende e senzatetto**: le tende reggono una sola stagione, poi si strappano: bisogna costruire case. Chi resta
  senza un tetto aspetta al massimo mezza stagione, poi se ne va.
- **Abitanti che camminano**: ognuno ha una casa e, se lavora, va e viene dal suo edificio; i disoccupati stanno attorno
  al falò (poi in piazza). Se vicino a partenza e arrivo c'è una strada, camminano lungo le strade.
- **Simboli**: ogni risorsa ha il suo simbolino (legna, pietra, mela, spiga, rapa, lingotto, martello, moneta), così come
  abitanti/posti letto, persone senza lavoro e la felicità (una faccina che sorride o si imbroncia).
- **Forma del feudo**: dalle partite nuove il feudo non è più un quadrato al centro del mondo, ma una forma
  tondeggiante con il bordo ondulato, in un punto che cambia da partita a partita.
- **Climi**: ogni regione del Regno ha un clima (più freddo a nord, più caldo a sud): **temperato**, **savana**,
  **deserto** o **tundra**, scritto sulla mappa. Il feudo prende il clima della sua regione: edifici, risorse e regole
  sono gli stessi, ma si adattano. Cambiano i nomi (nel deserto la casa è una casa di fango, il mercato un suq, il
  raccoglitore raccoglie datteri), le colture con le loro stagioni (savana: miglio, sorgo e arachidi; deserto: ceci,
  frumento e datteri; tundra: segale), le zone (palmeto, oasi e rocce rosse nel deserto; boscaglia di acacie, pozze e
  altopiano in savana; taiga, torbiera e rocce gelate nella tundra), i colori del suolo e gli alberi (acacie, baobab,
  palme, betulle, abeti). In savana e nel deserto non nevica. Tutto è in `data/climi.json`.
  Ci sono anche foresta pluviale, montagna, mediterraneo, steppa e cinque climi fantastici più rari (foresta di
  cristallo, deserto di cenere, giungla di funghi, tundra lunare, savana di cristalli). Per aggiungerne uno basta un
  blocco nuovo nel file, con `fascia` (fredda, temperata, calda, arida) e `peso`; i test controllano che sia completo.
- **Biomi**: attorno all'accampamento c'è la prateria; in tre direzioni diverse una **pineta** (bosco fitto di conifere,
  taglialegna +25%, caccia +15%, campi -15%), una **palude** (stagni e canne, pesca +25%, raccolta +20%, campi -20%) e
  delle **rupi** (colline e rocce, cava e miniera +30%, campi -25%). I valori sono in `bilanciamento.json` (`biomi`);
  il pannello dell'edificio dice l'effetto del bioma. Le partite salvate prima restano com'erano (versione della mappa 1).
- **Zone del territorio**: ogni cella ha una fertilità (più alta vicino all'acqua, la terra fertile è un verde più scuro).
  Taglialegna, cava, cacciatore e raccoglitore rendono di più con tanto bosco o tante rocce attorno; il pescatore rende di
  più sul lago che sul fiume, ma d'inverno il lago gela e la pesca crolla; il campo rende in base alla fertilità.
  Mentre scegli dove costruire, le celle che contano si colorano e il pannello mostra la resa stimata.
- **Raccolto di stagione**: taglialegna, cava, miniera, raccoglitore, cacciatore e pescatore mettono da parte
  (il pannello dell'edificio dice quanto hanno raccolto finora) e portano tutto in magazzino **a metà e a fine
  stagione**; quello che non ci sta va perso. Mulino, forno, fabbro e armeria invece lavorano giorno per giorno.
  Si parte con 80 cibo, abbastanza per arrivare al primo raccolto.
- **Disboscamento**: il taglialegna abbatte il bosco attorno; un bosco grande rende tanto ma sparisce in 3 anni.
  Dove ha tagliato restano i ceppi per una stagione; poi la cella è libera e ci si può costruire.
- **Campi** disponibili da subito: il grano si raccoglie in autunno e sfama quando il cibo finisce (con mulino e forno vale il doppio).
- **Mondo esteso**: il feudo (48×48 celle) sta al centro di un mondo di 112×112; oltre la linea gialla del confine
  ci sono le terre dei vicini, che si vedono ma dove non si costruisce.
- **Mappa del regno**: 10 regioni stile carta antica con i confini ondulati, ognuna con nome, risorsa speciale e
  proprietario; la nostra può stare in un punto qualsiasi della carta. Zoom animato per entrare nel feudo.
- **Feudo in 3D** con modelli KayKit, telecamera isometrica con zoom e rotazione, stagioni visibili (erba, chiome, neve, luce).
- **Economia**: tick ogni 2 secondi, filiere, lavoratori, felicità, livelli, tasse al re, vittoria e sconfitta, salvataggio automatico.

**Da fare**: altre carte evento, bilanciamento con partite vere.

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
| Menu principale | `scripts/menu.gd` |
| Battaglie: regole | `scripts/battaglia/logica.gd` (valori in `bilanciamento.json`, sezione `battaglia`) |
| Battaglie: campo 3D e comandi | `scripts/battaglia/campo.gd` |
| Musica ed effetti | `scripts/audio.gd` (autoload `Audio`), suoni generati da `tools/genera_audio.py` |
| Mappa del regno | `scripts/regno/regno.gd` |
| Interfaccia | `scripts/ui/hud.gd` (tema in `Hud.crea_tema()`), icone dei pulsanti in `scripts/ui/icona_ui.gd` |
| Segni sopra gli edifici | `scripts/ui/segni_edifici.gd` |
| Climi: nomi, colture, suolo, alberi | `data/climi.json` |

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
`tools/prova_rapida.tscn` fa lo stesso in pochi secondi con una partita già avviata: utile per ritoccare la grafica
(`BORGO_UI_GRANDE=1` per l'interfaccia grande, `PROVA_CLIMA=deserto` per un clima).

`tools/simula_economia.tscn` gioca da solo qualche anno senza grafica, con un giocatore automatico ragionevole, e stampa
le risorse a ogni stagione: serve a bilanciare i numeri (`SIM_ANNI`, `SIM_SEMI`, `SIM_CLIMA`).

## Esportare su Android

1. In Godot: **Editor → Gestisci modelli di esportazione → Scarica**.
2. Installa Android Studio (serve l'SDK) e imposta i percorsi in **Editor → Impostazioni editor → Esporta → Android**.
3. **Progetto → Esporta → Aggiungi → Android**, poi esporta l'APK, oppure usa il pulsante di deploy con il telefono collegato via USB.

L'orientamento è già bloccato in orizzontale. Il renderer è "Compatibility", il più adatto ai telefoni economici e al browser.
