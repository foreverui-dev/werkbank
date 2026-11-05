# Werkbank

Berufe-Addon für World of Warcraft: Forever. Teil von [ForeverUI](https://foreverui.de).

- **Rezeptbuch:** alle herstellbaren Rezepte nach Beruf und Kategorie, mit Suche und Filter „gelernt / noch nicht gelernt“
- **Einkaufsliste:** Rezepte mit Anzahl draufsetzen, die Werkbank rechnet die Materialien zusammen und zieht ab, was in Taschen und Bank liegt
- **Zwischenprodukte:** Ein Klick auf ein herstellbares Material (z. B. Stoffballen) löst es in seine Zutaten auf
- **Berufe-Rechner:** Listen von [foreverui.de/berufe](https://foreverui.de/berufe/) importieren oder als Link dorthin mitnehmen
- **Tooltips:** wofür ein Material gebraucht wird, wie weit die Einkaufsliste ist und welche eigenen Charaktere einen Gegenstand herstellen können

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

Im Berufsfenster gibt es oben einen Knopf **Werkbank**: Klick setzt das gewählte Rezept auf die Liste (Anzahl aus dem Feld unten), Rechtsklick öffnet das Fenster.

In den Listen: Klick +1, Strg-Klick +5, Rechtsklick −1, Umschalt-Klick fügt einen Link in den Chat ein.

## Barrierefreiheit

Im Fenster unter **Optionen** (oder `/wb optionen`):

- **Vorlesen:** Rezepte und Listeneinträge werden beim Darüberfahren oder Auswählen mit der Sprachausgabe des Spiels vorgelesen. `/wb vorlesen` liest die ganze Einkaufsliste vor, auch wenn die Option aus ist. Die Stimme stellt man im Spiel unter Barrierefreiheit › Text-zu-Sprache ein.
- **Hoher Kontrast:** fast undurchsichtiger Hintergrund, hellere Nebentexte.
- **Farbenblind-Modus:** Blau statt Grün, Orange statt Rot. Fehlende Mengen stehen immer auch als Wort da („fehlt 2“), nicht nur als Farbe.
- **Größe:** 100, 125, 150 oder 200 %, frei mit `/wb groesse 100-200`.
- **Tastatursteuerung im Fenster:** Pfeiltasten bewegen, Links/Rechts wechselt zwischen Rezeptbuch und Liste, Eingabe +1, Rücktaste −1, Tab nächster Beruf, Leertaste liest vor, Strg+F springt in die Suche, Esc schließt.

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
