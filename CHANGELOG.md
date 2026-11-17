# Werkbank

## v1.6.0

Werkbank als Plugin für ForeverUI. Die Werkbank bleibt eigenständig und läuft weiter ohne ForeverUI.

1. Mit ForeverUI erscheinen die wichtigsten Optionen im ForeverUI-Fenster unter „Plugins“ (Werte bleiben in der Werkbank)
2. Mit eingeschaltetem ForeverUI-Interface übernimmt die Werkbank dessen Akzentfarbe, abschaltbar mit „Aussehen von ForeverUI übernehmen“
3. Neues Design „Klar“ wie in ForeverUI: Schalter statt Häkchen und flache Knöpfe in den Einstellungen
4. Leise ab Werk: keine Töne, Chat-Meldungen oder Fenster, die von selbst aufgehen. Alles lässt sich in den Optionen wieder einschalten, dort steht auch der Assistent. Bestehende Einstellungen werden dafür einmalig umgestellt

The Workbench as a ForeverUI plugin: its main options show up in the ForeverUI window under "Plugins", and with the ForeverUI interface turned on it uses the interface's accent colour. Without ForeverUI nothing changes. New “Clear” design as in ForeverUI: switches instead of checkboxes and flat buttons. Quiet by default: no sounds, chat messages or windows that open on their own; everything can be turned back on in the options.

## v1.5.0

Viele Wünsche aus der Community-Liste, soweit es sie auf WoW Forever gibt.

Werkstatt:

1. Neue Seite „Übersicht“: Liste, Aufträge, bereite Abklingzeiten, knappe Vorräte, Berufe mit nächstem Meilenstein
2. Kundenaufträge mit Kunde, Rezept, Anzahl, Lohn, Frist, Notiz, Priorität, Aufwand und Status
3. „Kunde bringt Material“, Materialprüfung und Gewinn je Auftrag
4. Aufträge sortieren (Frist, Priorität, Kunde, Status, Lohn, Aufwand, Beruf), kopieren, löschen, offene auf die Einkaufsliste
5. Kunden mit Kontaktweg, Anzahl, Summe und Verlauf; Erinnerung an fällige Aufträge beim Einloggen

Preise und Vorrat:

6. Auktionshauspreise werden bei jeder Suche gemerkt, Verlauf über 30 Tage mit Trend
7. Knopf „Liste abfragen“ im Auktionshaus sucht die fehlenden Materialien der Reihe nach
8. Materialkosten (auch über Zwischenprodukte) und Gewinn nach Gebühr auf der Rezeptseite, Warnung bei Verlust
9. „Selbst herstellen oder kaufen?“ im Material-Tooltip
10. Preisalarme mit Meldung, Bildschirmtext, Sprachausgabe und Ton
11. Mindestbestände mit Warnung und „Auffüllen“ auf die Einkaufsliste
12. Material-Tooltip auf der Liste: Preis, Mindestbestand, Taschen und Bank getrennt

Rezepte und Fortschritt:

13. Berufsziele für Fertigkeit oder Anzahl gelernter Rezepte, mit Meldung
14. „Noch 30 bis 150“ im Rezeptbuch, in der Seitenleiste und auf der Übersicht
15. 14 eigene Werkbank-Erfolge
16. Herstellungsverlauf (200 Einträge), Ertrag bei schwankender Menge, Verbrauch je Sitzung, Statistik je Beruf
17. Rezeptquellen werden gemerkt (Händler, Beute, Auktionshaus) und auf der Rezeptseite gezeigt
18. Benötigte Werkzeuge und Orte aus dem Berufsfenster auf der Rezeptseite
19. Alternativen: andere Rezepte, die denselben Gegenstand herstellen
20. Zwei Rezepte nebeneinander vergleichen
21. Neue Filter: „Beim Händler gesehen“, „Neu seit Datenupdate“, „Mit Gewinn“

Planen und Bedienung:

22. Vorlagen für wiederkehrende Listen
23. Prioritäten auf der Liste (Alt-Klick), Dringendes steht oben
24. Materialien nach Quelle oder nach Art ordnen
25. Seitenleiste zeigt deine eigenen Berufe, alle anderen über „Alle Berufe …“
26. Kompaktes Fenster ohne Seitenleiste
27. Neue Seite „Meldungen“ zum Abschalten der neuen Hinweise
28. Diagnose (Version, Spiel, Schnittstellen, Einstellungen) zum Kopieren auf der Fehlerseite
29. Import prüft die Einträge und meldet unbekannte Rezepte
30. Zahlen mit Tausenderpunkt
31. Neuer Discord-Link

## v1.4.0

50 neue Funktionen.

Rezeptbuch:

1. Filter „Bringt noch Punkte“ (orange, gelb und grün gelernte Rezepte)
2. Sortierung nach Kategorie, Name, Schwierigkeit oder „wie oft möglich“
3. Kategorien per Klick auf- und zuklappen
4. Jede Kategorie zeigt, wie viele Rezepte gelernt sind
5. Suche in allen Berufen auf einmal
6. Suche mit mehreren Wörtern („leder stiefel“)
7. Detailseite für jedes Rezept (Mittelklick, Strg-Rechtsklick oder Taste D)
8. „Verwendet in“ auf der Detailseite und `/wb wofuer`
9. Eigene Notizen zu Rezepten, auch im Tooltip
10. Anzahl direkt eingeben
11. „Zufall“: schlägt ein Rezept vor, am liebsten eins, das du gleich herstellen kannst
12. „Im Berufsfenster“ wählt das Rezept im offenen Berufsfenster aus

Einkaufsliste:

13. Rückgängig (bis zu 30 Schritte, auch Strg+Z)
14. Liste kopieren
15. Alle Listen zusammenführen
16. Liste eines anderen Charakters übernehmen
17. Fortschrittsbalken und Prozent am Listennamen
18. „bereit“ bei Rezepten, deren Materialien schon da sind
19. Materialien nach Quelle gruppiert: Händler, selbst herstellbar, bei deinen Charakteren, Sammeln/Auktionshaus, schon da
20. Händlerpreise werden beim Besuch gemerkt
21. Kostenschätzung für die Händlerware
22. Händler und Ort im Tooltip („Händlerin Hilde, Sturmwind – 10 Kupfer“)
23. Option: Zwischenprodukte automatisch selbst herstellen, wenn einer deiner Charaktere es kann
24. Liste als Text zum Kopieren
25. Sicherung aller Listen als Text, wieder einfügbar
26. Menü am Listennamen mit allen Listenbefehlen

Unterwegs:

27. Tracker: kleines Fenster mit den fehlenden Materialien und dem Fortschritt (`/wb tracker`, Mittelklick am Minimap-Knopf, Tastenkürzel)
28. Meldungen auf Wunsch mitten auf dem Bildschirm
29. Post-Helfer: „Für Twink“ hängt an, was ein anderer Charakter für seine Liste braucht
30. Beim Einloggen: Hinweis, wenn ein anderer Charakter etwas braucht, das du hast
31. Bank-Hinweis, wenn dort Material für die Liste liegt
32. Alt-Klick auf einen Gegenstand im Chat setzt sein Rezept auf die Liste
33. Händler-Hinweis auf Rezepte, die noch keiner deiner Charaktere kennt
34. Muster in der Beute: wer es schon kennt oder lernen kann
35. Berufsfenster: Knopf „Liste herstellen“
36. Berufsfenster: Hinweis, was von der Liste jetzt herstellbar ist

Charaktere und Fortschritt:

37. Abklingzeiten (Transmutation, Mondstoff) aller Charaktere
38. Meldung, wenn eine Abklingzeit wieder bereit ist
39. Gold aller Charaktere auf dem Realm
40. Berufe aller Charaktere im Vergleich
41. `/wb wer Gegenstand`: wer kann es herstellen, wer hat es
42. Option: Flüsteranfragen „!werkbank Name“ beantworten
43. Stufenaufstieg im Beruf wird gemeldet
44. Hinweis, wenn es Zeit für den Lehrer ist
45. Meilensteine 75, 150, 225 und 300 mit Glückwunsch
46. Statistik: Hergestelltes gesamt, heute, je Charakter, Top 10
47. Sitzungsstatistik: gesammelte Materialien
48. Sammlung: wie viele Rezepte jeder Charakter je Beruf gelernt hat

Zugang und Hilfe:

49. Einrichtungsassistent beim ersten Start (Willkommen, Barrierefreiheit, Funktionen, Darstellung), jederzeit unter Hilfe
50. Fehlerprotokoll mit Seite „Fehler melden“ zum Kopieren

Dazu: Option „Weniger Bewegung“, zwei neue Tastenkürzel (Tracker, Rückgängig).

## v1.3.0

Neues Aussehen im einheitlichen ForeverUI-Design (wie Forever Meter):

- Ein Hauptfenster mit Seitenleiste: Berufe, Charaktere, Austausch mit foreverui.de, Barrierefreiheit, Funktionen, Darstellung, Neuigkeiten, Bedienung, Discord und Feedback
- Dunkle Flächen, feine Ränder, Kopfband und Auswahl in der Akzentfarbe
- Akzentfarbe zur Wahl: Gold, Klasse, Eis, Glut, Wald, Silber (wirkt sofort)
- Fenstergröße über den Griff unten rechts veränderbar, wird gemerkt
- Suche und Filter oben rechts, „Schließen“ unten rechts
- Optionen als Schalter mit Erklärung in zwei Spalten, je Seite „Seite zurücksetzen“
- Import, Link, Charakterübersicht und Umbenennen sind keine eigenen Fenster mehr, sondern Seiten im Hauptfenster
- Barrierefreiheit: „Alles größer“ (125 %), hoher Kontrast mit weißem Text, Tab wechselt durch die Seitenleiste

## v1.2.0

Charakterübergreifend:

- Vorrat aller Charaktere auf dem Realm (Taschen und Bank) in der Einkaufsliste und in Tooltips
- Wahlweise eine gemeinsame Einkaufsliste für alle Charaktere (`/wb gemeinsam`)
- Filter „Von meinen Charakteren gelernt“
- Charakterübersicht mit Berufen und gelernten Rezepten (`/wb charaktere`, `/wb vergessen Name`)
- Bei Zwischenprodukten steht, welcher deiner Charaktere sie herstellen kann
- Tooltips an Mustern, Plänen und Formeln: wer es gelernt hat und wer es noch lernen könnte

Planen und Sammeln:

- Mehrere benannte Einkaufslisten, umschalten mit den Knöpfen über der Liste oder `/wb liste`
- Meldung mit Ton und Sprachausgabe, sobald alle Materialien da sind
- Fortschritt beim Sammeln im Chat („Leinenstoff 7/10“)
- Nach dem Herstellen wird das Rezept automatisch auf der Liste abgehakt

Unterwegs:

- Händler: Knopf „Fehlendes kaufen“ mit Preis und Rückfrage
- Auktionshaus: Alt-Klick auf ein Material sucht danach
- Bank: Knopf „Material holen“ legt alles Nötige in die Taschen
- `/wb chat gruppe|gilde|sagen` teilt die fehlenden Materialien

Rezeptbuch:

- Favoriten (Alt-Klick oder Taste M) mit eigenem Filter
- Suche findet Rezepte auch über ihre Zutaten
- Schwierigkeit als Wort und Farbe (orange, gelb, grün, grau)
- Filter „Jetzt herstellbar“
- Anzeige, wie oft ein Rezept mit deinem Vorrat möglich ist
- Minimap-Knopf (ausblendbar)

Behoben: Vorlesen von Materialien in der Einkaufsliste löste einen Fehler aus.

## v1.1.0

- Barrierefreiheit: neues Optionsfenster (`/wb optionen` oder Knopf „Optionen“)
- Vorlesen mit der Sprachausgabe des Spiels: Rezepte, Listeneinträge und die ganze Einkaufsliste (`/wb vorlesen`)
- Hoher Kontrast: fast undurchsichtiger Hintergrund, hellere Nebentexte
- Farbenblind-Modus: Blau statt Grün, Orange statt Rot; fehlende Mengen stehen zusätzlich als Wort da
- Größe von 100 bis 200 %
- Tastatursteuerung im Fenster: Pfeiltasten, Eingabe, Rücktaste, Tab, Leertaste zum Vorlesen, Strg+F für die Suche
- Tastenkürzel ohne Fenster: Werkbank öffnen, gewähltes Rezept auf die Liste, Einkaufsliste vorlesen

## v1.0.0

- Rezeptbuch mit allen herstellbaren Rezepten von WoW Forever, nach Beruf und Kategorie, mit Suche
- Einkaufsliste: Materialien zusammenrechnen, Vorrat aus Taschen und Bank abziehen
- Zwischenprodukte wahlweise selbst herstellen statt kaufen
- Austausch mit dem Berufe-Rechner auf foreverui.de (Import und Link)
- Tooltips: Zutat für welche Berufe, Stand der Einkaufsliste, wer von deinen Charakteren es herstellen kann
- Gelernte Rezepte werden beim Öffnen des Berufsfensters erfasst
