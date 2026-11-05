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

Im Berufsfenster gibt es oben einen Knopf **Werkbank**: Klick setzt das gewählte Rezept auf die Liste (Anzahl aus dem Feld unten), Rechtsklick öffnet das Fenster.

In den Listen: Klick +1, Strg-Klick +5, Rechtsklick −1, Umschalt-Klick fügt einen Link in den Chat ein.

## Daten

Die Rezepte stammen aus der Battle.net-API von Blizzard Entertainment (Namespace `static-forever-eu`) und sind dieselben wie im Berufe-Rechner. `Data.lua` wird erzeugt, nicht von Hand bearbeitet:

```sh
node scripts/daten.mjs ../foreverui-web
```

Vorher im Webseiten-Repo `npm run daten` laufen lassen. Die Daten dürfen höchstens 30 Tage alt sein, der Release-Workflow bricht sonst ab.

Die API liefert keine Fertigkeitsstufen pro Rezept, deshalb sind die Rezepte nur ungefähr nach Gegenstandsstufe sortiert.

## Entwickeln

```sh
lua5.1 tests/test.lua   # Logik mit einer Attrappe der Spiel-API prüfen
```

Zum Ausprobieren den Ordner als `Interface/AddOns/Werkbank` ins Spiel legen (Symlink genügt). Die Interface-Nummer in `Werkbank.toc` (16001 für Version 1.60.1) prüft man im Spiel mit `/dump select(4, GetBuildInfo())`.

## Veröffentlichen

1. Projekt auf CurseForge und Wago anlegen und die IDs in `Werkbank.toc` eintragen:
   ```
   ## X-Curse-Project-ID: 123456
   ## X-Wago-ID: abcdef12
   ```
2. Version in `CHANGELOG.md` eintragen.
3. Tag setzen und pushen: `git tag v1.0.0 && git push origin v1.0.0`

Der Workflow `release.yml` baut das Paket und lädt es mit den Org-Secrets `CF_API_KEY` und `WAGO_API_TOKEN` hoch. Ohne IDs in der TOC entsteht nur ein GitHub-Release.

## Lizenz

MIT, siehe `LICENSE`. Die Rezeptdaten in `Data.lua` stammen von Blizzard Entertainment.
