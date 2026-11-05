// Erzeugt Daten/Quests.lua aus der Battle.net Game Data API (Namespace static-forever-<region>).
// Aufruf: BLIZZARD_CLIENT_ID=... BLIZZARD_CLIENT_SECRET=... node scripts/questdaten.mjs [region]
// Gibt nur Fortschritt und Zahlen aus, niemals Token oder Zugangsdaten.
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const region = (process.argv[2] || 'eu').toLowerCase();
const NS = `static-forever-${region}`;
const OUT = fileURLToPath(new URL('../Daten/Quests.lua', import.meta.url));
const { BLIZZARD_CLIENT_ID: id, BLIZZARD_CLIENT_SECRET: secret } = process.env;
if (!id || !secret) {
  console.error('BLIZZARD_CLIENT_ID und BLIZZARD_CLIENT_SECRET als Umgebungsvariablen setzen.');
  process.exit(1);
}

const tokenRes = await fetch('https://oauth.battle.net/token', {
  method: 'POST',
  headers: {
    Authorization: 'Basic ' + Buffer.from(`${id}:${secret}`).toString('base64'),
    'Content-Type': 'application/x-www-form-urlencoded',
  },
  body: 'grant_type=client_credentials',
});
if (!tokenRes.ok) {
  console.error(`Token-Abruf fehlgeschlagen: HTTP ${tokenRes.status}`);
  process.exit(1);
}
const { access_token } = await tokenRes.json();

// Ohne locale-Parameter liefert die API alle Sprachen in einem Abruf.
async function api(path, tries = 4) {
  const url = `https://${region}.api.blizzard.com${path}?namespace=${NS}`;
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url, { headers: { Authorization: `Bearer ${access_token}` } });
      if (res.ok) return res.json();
      if (res.status === 404) return null;
    } catch {}
    await new Promise((r) => setTimeout(r, 1000 * 2 ** i));
  }
  throw new Error(`Abruf fehlgeschlagen: ${path}`);
}

async function pool(items, n, fn) {
  const out = new Array(items.length);
  let next = 0, done = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i]);
      if (++done % 500 === 0) console.log(`  ${done}/${items.length}`);
    }
  }));
  return out;
}

const loc = (name) => ({ de: name?.de_DE || name?.en_US || '', en: name?.en_US || name?.en_GB || name?.de_DE || '' });

// 1) Gebiete, Kategorien und Typen
const [areaIdx, catIdx, typeIdx] = await Promise.all([
  api('/data/wow/quest/area/index'),
  api('/data/wow/quest/category/index'),
  api('/data/wow/quest/type/index'),
]);
const areas = {}, cats = {}, types = {};
for (const t of typeIdx.types) types[t.id] = loc(t.name);
const questGroup = new Map(); // questId -> { area?, cat? }
console.log(`Gebiete: ${areaIdx.areas.length}, Kategorien: ${catIdx.categories.length}`);
await pool(areaIdx.areas, 8, async (a) => {
  const d = await api(`/data/wow/quest/area/${a.id}`);
  areas[a.id] = loc(a.name);
  for (const q of d?.quests || []) questGroup.set(q.id, { ...questGroup.get(q.id), area: a.id });
});
await pool(catIdx.categories, 8, async (c) => {
  const d = await api(`/data/wow/quest/category/${c.id}`);
  cats[c.id] = loc(c.name);
  for (const q of d?.quests || []) questGroup.set(q.id, { ...questGroup.get(q.id), cat: c.id });
});

// 2) Einzelne Quests
const ids = [...questGroup.keys()].sort((a, b) => a - b);
console.log(`Quests: ${ids.length}`);
const reps = {};
const reqKeys = new Map();
const quests = (await pool(ids, 10, async (qid) => {
  const q = await api(`/data/wow/quest/${qid}`);
  if (!q) return null;
  for (const k of Object.keys(q.requirements || {})) reqKeys.set(k, (reqKeys.get(k) || 0) + 1);
  const fac = q.requirements?.faction?.type;
  const repList = (q.rewards?.reputations || []).map((r) => {
    reps[r.reward.id] = loc(r.reward.name);
    return [r.reward.id, r.value];
  });
  const g = questGroup.get(qid);
  return {
    id: qid,
    area: q.area?.id ?? g.area ?? 0,
    cat: q.category?.id ?? g.cat ?? 0,
    fac: fac === 'ALLIANCE' ? 'A' : fac === 'HORDE' ? 'H' : '',
    type: q.type?.id ?? 0,
    xp: q.rewards?.experience ?? 0,
    name: loc(q.title),
    reps: repList,
    // Bitmasken wie im Spiel: Bit (ID-1) für UnitClass/UnitRace
    classes: (q.requirements?.classes || []).reduce((m, c) => m + 2 ** (c.id - 1), 0),
    races: (q.requirements?.races || []).reduce((m, r) => m + 2 ** (r.id - 1), 0),
  };
})).filter(Boolean);
for (const q of quests) if (q.area && !areas[q.area]) areas[q.area] = { de: '', en: '' };

// 3) Lua schreiben
const s = (v) => JSON.stringify(v ?? '').replace(/\\u([0-9a-f]{4})/gi, (m, h) => String.fromCharCode(parseInt(h, 16)));
const pair = (o) => `{${s(o.de)},${s(o.en)}}`;
const tbl = (obj) => Object.keys(obj).map(Number).sort((a, b) => a - b).map((k) => `[${k}]=${pair(obj[k])},`).join('\n');
const stand = new Date().toISOString().slice(0, 10);
let lua = `-- Automatisch erzeugt von scripts/questdaten.mjs, nicht von Hand bearbeiten.
-- Quelle: Blizzard Entertainment, Battle.net Game Data API (${NS}), Stand ${stand}.
-- Quest: { gebiet, kategorie, fraktion, typ, ep, {deDE, enUS}, klassenmaske, volksmaske, {rufID, wert, ...} }
local _, QK = ...
QK.datenStand = ${s(stand)}
QK.gebiete = {
${tbl(areas)}
}
QK.kategorien = {
${tbl(cats)}
}
QK.typen = {
${tbl(types)}
}
QK.fraktionen = {
${tbl(reps)}
}
QK.quests = {
`;
for (const q of quests) {
  const r = q.reps.length ? `,{${q.reps.flat().join(',')}}` : '';
  lua += `[${q.id}]={${q.area},${q.cat},${s(q.fac)},${q.type},${q.xp},${pair(q.name)},${q.classes},${q.races}${r}},\n`;
}
lua += '}\n';
writeFileSync(OUT, lua);
console.log(`Geschrieben: ${quests.length} Quests, ${Object.keys(areas).length} Gebiete, ${(lua.length / 1024).toFixed(0)} KB`);
console.log('Anforderungen in den Daten:', Object.fromEntries(reqKeys));
