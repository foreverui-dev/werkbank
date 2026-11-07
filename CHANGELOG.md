# Werkbank

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
