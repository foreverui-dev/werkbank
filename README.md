# Werkbank

Berufe-Addon für World of Warcraft: Forever. Teil von [ForeverUI](https://foreverui.de).

- **Rezeptbuch:** alle herstellbaren Rezepte nach Beruf und Kategorie, Suche nach Rezept oder Zutat, Filter (gelernt, noch nicht gelernt, von meinen Charakteren, jetzt herstellbar, Favoriten), Schwierigkeit als Wort und Farbe, „3× möglich“ mit deinem Vorrat
- **Einkaufsliste:** Rezepte mit Anzahl draufsetzen, die Werkbank rechnet die Materialien zusammen und zieht ab, was in Taschen und Bank liegt
- **Zwischenprodukte:** Ein Klick auf ein herstellbares Material (z. B. Stoffballen) löst es in seine Zutaten auf
- **Berufe-Rechner:** Listen von [foreverui.de/berufe](https://foreverui.de/berufe/) importieren oder als Link dorthin mitnehmen
- **Mehrere Listen:** beliebig viele benannte Einkaufslisten, wahlweise pro Charakter oder eine gemeinsame für alle
- **Charakterübergreifend:** Taschen und Bank aller Charaktere eines Realms, wer welches Zwischenprodukt herstellen kann, Übersicht aller Charaktere mit Berufen
- **Tooltips:** wofür ein Material gebraucht wird, wie weit die Einkaufsliste ist, wer es herstellen kann und wie viele deine anderen Charaktere haben. An Mustern, Plänen und Formeln: wer es schon gelernt hat und wer es noch lernen könnte
- **Unterwegs:** beim Händler „Fehlendes kaufen“ (mit Rückfrage und Preis), in der Bank „Material holen“, Alt-Klick auf ein Material sucht im Auktionshaus, `/wb chat` teilt die fehlenden Materialien in Gruppe oder Gilde
- **Fortschritt:** Meldung beim Sammeln („Leinenstoff 7/10“), Meldung mit Ton, wenn alles da ist, nach dem Herstellen wird automatisch abgehakt
- **Minimap-Knopf:** Klick öffnet das Fenster, Rechtsklick die Optionen, ziehen zum Verschieben

## Bedienung

| | |
| --- | --- |
| `/wb` oder `/werkbank` | Fenster öffnen oder schließen |
| `/wb import` | Link aus dem Berufe-Rechner einfügen |
| `/wb link` | Liste als Link für foreverui.de |
| `/wb leeren` | Einkaufsliste leeren |
| `/wb tooltip` | Tooltip-Zeilen an oder aus |
| `/wb optionen` | Barrierefreiheit und weitere Optionen |
| `/wb vorlesen` | Einkaufsliste vorlesen |
| `/wb liste neu Name` · `weiter` · `zurueck` · `name Text` · `loeschen` | mehrere Einkaufslisten |
| `/wb gemeinsam` | eine Liste für alle Charaktere an oder aus |
| `/wb charaktere` | Übersicht deiner Charaktere |
| `/wb vergessen Name` | Charakter aus der Werkbank entfernen |
| `/wb chat gruppe` · `gilde` · `sagen` | fehlende Materialien in den Chat |
| `/wb kaufen` | beim offenen Händler fehlende Materialien kaufen |
| `/wb bank` | Materialien aus der offenen Bank holen |
| `/wb minimap` | Minimap-Knopf an oder aus |

Im Berufsfenster gibt es oben einen Knopf **Werkbank**: Klick setzt das gewählte Rezept auf die Liste (Anzahl aus dem Feld unten), Rechtsklick öffnet das Fenster.

In den Listen: Klick +1, Strg-Klick +5, Rechtsklick −1, Umschalt-Klick fügt einen Link in den Chat ein, Alt-Klick auf ein Rezept macht es zum Favoriten, Alt-Klick auf ein Material sucht es im Auktionshaus.

Taschen und Bank eines Charakters kennt die Werkbank, sobald er eingeloggt war und einmal die Bank geöffnet hat. Gezählt werden nur Gegenstände, die in Rezepten vorkommen.

## Barrierefreiheit

Im Fenster unter **Optionen** (oder `/wb optionen`):

- **Vorlesen:** Rezepte und Listeneinträge werden beim Darüberfahren oder Auswählen mit der Sprachausgabe des Spiels vorgelesen. `/wb vorlesen` liest die ganze Einkaufsliste vor, auch wenn die Option aus ist. Die Stimme stellt man im Spiel unter Barrierefreiheit › Text-zu-Sprache ein.
- **Hoher Kontrast:** fast undurchsichtiger Hintergrund, hellere Nebentexte.
- **Farbenblind-Modus:** Blau statt Grün, Orange statt Rot. Fehlende Mengen stehen immer auch als Wort da („fehlt 2“), nicht nur als Farbe.
- **Größe:** 100, 125, 150 oder 200 %, frei mit `/wb groesse 100-200`.
- **Tastatursteuerung im Fenster:** Pfeiltasten bewegen, Links/Rechts wechselt zwischen Rezeptbuch und Liste, Eingabe +1, Rücktaste −1, Tab nächster Beruf, Leertaste liest vor, Strg+F springt in die Suche, M macht das gewählte Rezept zum Favoriten, Esc schließt.

Tastenkürzel ohne Fenster gibt es unter Tastaturbelegung › AddOns › Werkbank: Fenster öffnen, gewähltes Rezept auf die Liste, Einkaufsliste vorlesen.

## Daten

Die Rezepte stammen aus der Battle.net-API von Blizzard Entertainment (Namespace `static-forever-eu`) und sind dieselben wie im Berufe-Rechner. `Data.lua` wird erzeugt, nicht von Hand bearbeitet:

```sh
node scripts/daten.mjs ../foreverui-web
```

Vorher im Webseiten-Repo `npm run daten` laufen lassen. Die Daten dürfen höchstens 30 Tage alt sein.

Die API liefert keine Fertigkeitsstufen pro Rezept, deshalb sind die Rezepte nur ungefähr nach Gegenstandsstufe sortiert.

## Entwickeln

```sh
lua5.1 tests/test.lua   # Logik mit einer Attrappe der Spiel-API prüfen
```

Zum Ausprobieren den Ordner als `Interface/AddOns/Werkbank` ins Spiel legen (Symlink genügt). Die Interface-Nummer in `Werkbank.toc` (16001 für Version 1.60.1) prüft man im Spiel mit `/dump select(4, GetBuildInfo())`.

## Lizenz

MIT, siehe `LICENSE`. Die Rezeptdaten in `Data.lua` stammen von Blizzard Entertainment.
