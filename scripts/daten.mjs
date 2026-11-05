// Erzeugt Data.lua aus den Daten des Berufe-Rechners von foreverui.de.
//
// Aufruf:  node scripts/daten.mjs [Pfad zu foreverui-web]
// Standard: ../foreverui-web
//
// Gelesen werden src/data/berufe.json und src/data/items.json. Beide holt dort
// `npm run daten` aus der Battle.net-API (Namespace static-forever-eu).
// Laut Blizzard-Bedingungen dürfen die Daten höchstens 30 Tage alt sein, also vor
// jedem Release neu erzeugen.

import { readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

const ROOT = new URL('..', import.meta.url).pathname;
const WEB = resolve(process.argv[2] ?? join(ROOT, '../foreverui-web'));

const berufeRaw = JSON.parse(await readFile(join(WEB, 'src/data/berufe.json'), 'utf8'));
const itemsRaw = JSON.parse(await readFile(join(WEB, 'src/data/items.json'), 'utf8'));
const items = new Map(itemsRaw.items.map((i) => [i.id, i]));

// Wie auf der Webseite: Rezepte, deren Ergebnis oder Zutaten es in Forever nicht gibt, fallen weg
const machbar = (r) => (!r.item || items.has(r.item)) && r.zutaten.every(([id]) => items.has(id));
const rezepte = new Map(
  Object.entries(berufeRaw.rezepte)
    .filter(([, r]) => machbar(r))
    .map(([id, r]) => [+id, r]),
);

const fixCase = (s) =>
  s === s.toUpperCase() ? s.toLowerCase().replace(/(^|\s)(\S)/g, (_, a, b) => a + b.toUpperCase()).replace(/ Der /g, ' der ') : s;
const level = (rid) => {
  const it = items.get(rezepte.get(rid)?.item ?? -1);
  return it ? (it.ilvl ?? it.req ?? 0) : 0;
};

const berufe = [];
const berufOf = new Map();
for (const b of berufeRaw.berufe) {
  const kategorien = b.kategorien
    .map((k) => ({ name: fixCase(k.name), rezepte: k.rezepte.filter((rid) => rezepte.has(rid)).sort((x, y) => level(x) - level(y)) }))
    .filter((k) => k.rezepte.length);
  const anzahl = kategorien.reduce((s, k) => s + k.rezepte.length, 0);
  if (!anzahl) continue;
  for (const k of kategorien) for (const rid of k.rezepte) berufOf.set(rid, b.id);
  berufe.push({ ...b, kategorien, anzahl });
}
berufe.sort((a, b) => (a.art === b.art ? a.name.localeCompare(b.name, 'de') : a.art === 'haupt' ? -1 : 1));

// ---------- Lua schreiben ----------
const str = (s) => `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')}"`;
const out = [];
const datum = berufeRaw.fetchedAt.slice(0, 10);
out.push('-- Automatisch erzeugt von scripts/daten.mjs, nicht von Hand ändern.');
out.push('-- Quelle: Battle.net-API von Blizzard Entertainment (static-forever-eu), Stand ' + datum + '.');
out.push('local _, ns = ...');
out.push('local B, R, I = {}, {}, {}');
out.push(`ns.daten = { stand = ${str(datum)}, berufe = B, rezepte = R, items = I }`);
out.push('');
out.push('-- Berufe: id, slug (Adresse auf foreverui.de), name, art, symbol, kategorien { name, { rezepte } }');
for (const b of berufe) {
  const kats = b.kategorien.map((k) => `{${str(k.name)},{${k.rezepte.join(',')}}}`).join(',');
  out.push(`B[#B+1]={id=${b.id},slug=${str(b.slug)},name=${str(b.name)},art=${str(b.art)},icon=${b.ic ?? 'nil'},kat={${kats}}}`);
}
out.push('');
out.push('-- Rezepte: [id] = { name, ergebnis (oder false), menge (Zahl oder {min,max}), { zutat, anzahl, ... }, beruf, symbol }');
const used = new Set();
for (const [rid, r] of [...rezepte].sort((a, b) => a[0] - b[0])) {
  if (!berufOf.has(rid)) continue;
  if (r.item) used.add(r.item);
  const z = r.zutaten.flatMap(([id, n]) => (used.add(id), [id, n])).join(',');
  const m = Array.isArray(r.menge) ? `{${r.menge.join(',')}}` : r.menge;
  const ic = !r.item && r.ic ? `,${r.ic}` : '';
  out.push(`R[${rid}]={${str(r.n)},${r.item ?? 'false'},${m},{${z}},${berufOf.get(rid)}${ic}}`);
}
out.push('');
out.push('-- Gegenstände: [id] = { name, qualität, symbol }');
for (const id of [...used].sort((a, b) => a - b)) {
  const it = items.get(id);
  out.push(`I[${id}]={${str(it.n)},${it.q ?? 1},${it.ic ?? 'nil'}}`);
}
out.push('');

await writeFile(join(ROOT, 'Data.lua'), out.join('\n'));
const n = [...rezepte.keys()].filter((rid) => berufOf.has(rid)).length;
console.log(`Data.lua: ${berufe.length} Berufe, ${n} Rezepte, ${used.size} Gegenstände, Stand ${datum}.`);
