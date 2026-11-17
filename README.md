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
- **Detailseite und Notizen:** Mittelklick auf ein Rezept zeigt Zutaten, Vorrat, Händler, wer es kann, wofür es gebraucht wird, eigene Notiz und Anzahl
- **Planen:** Rückgängig, Listen kopieren, zusammenführen und von anderen Charakteren übernehmen, Sicherung als Text, Materialien nach Quelle gruppiert, Händlerpreise und Kostenschätzung
- **Tracker:** kleines Fenster mit den fehlenden Materialien (`/wb tracker`)
- **Fortschritt:** Abklingzeiten, Statistik, Sammlung, Gold aller Charaktere, Stufenaufstiege und Meilensteine
- **Einrichtungsassistent** in den Optionen (öffnet sich nicht von selbst) und **Fehlerprotokoll** unter Hilfe
- **Minimap-Knopf:** Klick öffnet das Fenster, Rechtsklick die Optionen, ziehen zum Verschieben
- **Übersicht:** Liste, offene Aufträge, bereite Abklingzeiten, knappe Vorräte, Berufe und nächste Meilensteine auf einen Blick
- **Aufträge:** Kundenaufträge mit Anzahl, Lohn, Frist, Notiz, Priorität, Aufwand und Status, „Kunde bringt Material“, Materialprüfung, Gewinn, Kunden mit Kontaktweg und Verlauf, Erinnerung bei fälligen Aufträgen
- **Preise:** merkt sich Auktionshauspreise bei jeder Suche, Knopf „Liste abfragen“ im Auktionshaus, Materialkosten und Gewinn je Rezept, Preisverlauf und Trend, Preisalarme, „selbst herstellen oder kaufen?“
- **Vorrat:** Mindestbestände mit Warnung und „Auffüllen“, Vorlagen für wiederkehrende Listen, Prioritäten auf der Liste, Materialien nach Quelle oder Art geordnet
- **Ziele und Erfolge:** Berufsziele (Fertigkeit oder Anzahl Rezepte), eigene Werkbank-Erfolge, Herstellungsverlauf, Ertrag, Verbrauch und Statistik je Beruf
- **Rezepte vergleichen** und Rezeptquellen (Händler, Beute, Auktionshaus), neue Rezepte seit dem letzten Datenupdate
- **Kompaktes Fenster** ohne Seitenleiste und **Diagnose** zum Kopieren für Fehlermeldungen

## Aussehen

Die Werkbank folgt dem einheitlichen ForeverUI-Design: ein Hauptfenster mit Seitenleiste links (Werkstatt, Berufe, Planen, Zugang, Hilfe) und dem Inhalt rechts. Unter Zugang › Darstellung lassen sich Akzentfarbe (Gold, Klasse, Eis, Glut, Wald, Silber) und Größe wählen, die Fenstergröße ändert der Griff unten rechts.

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
| `/wb tracker` | Tracker an oder aus |
| `/wb rueckgaengig` | letzte Änderung an der Liste zurücknehmen |
| `/wb rezept Name` | Detailseite eines Rezepts |
| `/wb wer Gegenstand` · `wofuer Gegenstand` | wer kann es herstellen, wofür wird es gebraucht |
| `/wb zufall` | zufälliges Rezept vorschlagen |
| `/wb kopieren` · `zusammenfuehren` · `uebernehmen Name` | Listen kopieren, zusammenführen, übernehmen |
| `/wb abklingzeiten` · `statistik` · `sammlung` · `fehler` · `assistent` | Seiten öffnen |
| `/wb uebersicht` · `auftraege` · `preise` · `ziele` · `diagnose` | Seiten öffnen |
| `/wb auftrag Kunde; Rezept; Anzahl; Lohn; Frist; Notiz` | Kundenauftrag anlegen (Frist z. B. `24.12.` oder `+3`) |
| `/wb kunde Name Kontaktweg` | Kontakt oder Notiz zu einem Kunden |
| `/wb alarm Gegenstand 20s` | Preisalarm, ohne Preis entfernen |
| `/wb mindest Gegenstand 40` | Mindestbestand, 0 entfernt ihn |
| `/wb ziel Beruf 225` · `ziel Beruf 40 rezepte` | Berufsziel |
| `/wb vorlage speichern Name` · `laden Name` | Listen-Vorlagen |
| `/wb vergleich Rezept A; Rezept B` | zwei Rezepte vergleichen |
| `/wb kompakt` | kompaktes Fenster an oder aus |
| `/wb abfragen` | im Auktionshaus das nächste fehlende Material suchen |

Im Berufsfenster gibt es oben einen Knopf **Werkbank**: Klick setzt das gewählte Rezept auf die Liste (Anzahl aus dem Feld unten), Rechtsklick öffnet das Fenster.

In den Listen: Klick +1, Strg-Klick +5, Rechtsklick −1, Umschalt-Klick fügt einen Link in den Chat ein, Alt-Klick auf ein Rezept macht es zum Favoriten, Alt-Klick auf ein Material sucht es im Auktionshaus.

Taschen und Bank eines Charakters kennt die Werkbank, sobald er eingeloggt war und einmal die Bank geöffnet hat. Gezählt werden nur Gegenstände, die in Rezepten vorkommen.

## Barrierefreiheit

Im Fenster unter **Zugang › Barrierefreiheit** (oder `/wb optionen`):

- **Vorlesen:** Rezepte und Listeneinträge werden beim Darüberfahren oder Auswählen mit der Sprachausgabe des Spiels vorgelesen. `/wb vorlesen` liest die ganze Einkaufsliste vor, auch wenn die Option aus ist. Die Stimme stellt man im Spiel unter Barrierefreiheit › Text-zu-Sprache ein.
- **Hoher Kontrast:** fast undurchsichtiger Hintergrund, hellere Nebentexte.
- **Farbenblind-Modus:** Blau statt Grün, Orange statt Rot. Fehlende Mengen stehen immer auch als Wort da („fehlt 2“), nicht nur als Farbe.
- **Alles größer:** 125 %; unter Darstellung auch 150 oder 200 %, frei mit `/wb groesse 100-200`.
- **Tastatursteuerung im Fenster:** Pfeiltasten bewegen, Links/Rechts wechselt zwischen Rezeptbuch und Liste, Eingabe +1, Rücktaste −1, Tab nächster Eintrag der Seitenleiste, Leertaste liest vor, Strg+F springt in die Suche, M macht das gewählte Rezept zum Favoriten, Esc schließt.

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
