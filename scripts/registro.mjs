// El registro tiene que poder creerse, empezando por sus propios numeros.
//
// Su regla 6 lo dice: "un item que ya esta resuelto pero sigue marcado abierto es
// peor que uno abierto: ensenia al lector a desconfiar del registro entero. Eso
// incluye el conteo del encabezado."
//
// Este chequeo existe porque ese conteo se desincronizo cuatro veces en tres
// dias. Lo verificaba con un script de una sola vez, escrito a mano cada vez, y
// una de esas veces el script fallo DESPUES de escribir el archivo: el registro
// quedo inconsistente y el commit salio igual.
import { readFileSync, readdirSync } from 'node:fs';

const REG = 'docs/ODs.md';
const texto = readFileSync(REG, 'utf8');
const fallos = [];

const filas = [...texto.matchAll(/^\| (OD-\d+) \|([^|]*)\|([^|]*)\|\s*(DECIDED|OPEN|LEANING|NEEDS-INPUT)\s*\|/gm)];
if (!filas.length) { console.error('No se encontro ninguna fila OD-: el formato cambio.'); process.exit(1); }

const estados = {};
for (const f of filas) estados[f[4]] = (estados[f[4]] ?? 0) + 1;
const abiertos = filas.filter((f) => f[4] === 'OPEN').map((f) => f[1]);

// 1. El encabezado dice la verdad.
for (const [estado, n] of Object.entries(estados)) {
  const re = new RegExp(`\\*\\*(\\d+) \\\`${estado}\\\`\\*\\*`);
  const m = texto.match(re);
  if (!m) fallos.push(`el encabezado no dice cuantos ${estado} hay`);
  else if (Number(m[1]) !== n) fallos.push(`el encabezado dice ${m[1]} ${estado} y hay ${n}`);
}
const total = filas.length;
if (!texto.includes(`De los ${estados.OPEN ?? 0} \`OPEN\``)) {
  fallos.push(`el resumen no arranca con "De los ${estados.OPEN ?? 0} \`OPEN\`"`);
}

// 2. Cada abierto aparece EXACTAMENTE una vez en el resumen, y los grupos suman.
const desde = texto.indexOf(`De los ${estados.OPEN ?? 0} \`OPEN\``);
const hasta = texto.indexOf('## How it is maintained');
if (desde > 0 && hasta > desde) {
  const resumen = texto.slice(desde, hasta);
  for (const od of abiertos) {
    const n = (resumen.match(new RegExp(od, 'g')) ?? []).length;
    if (n !== 1) fallos.push(`${od} aparece ${n} veces en el resumen (tiene que ser 1)`);
  }
  const suma = [...resumen.matchAll(/\((\d+)\):/g)].reduce((t, m) => t + Number(m[1]), 0);
  if (suma !== abiertos.length) fallos.push(`los grupos del resumen suman ${suma} y hay ${abiertos.length} abiertos`);
}

// 3. Los numeros que el registro dice de SI MISMO, contados de verdad.
//
// Decia "30 migraciones" con 32 en disco, "165 aserciones" con 173, y "14
// pantallas" cuando habia 15. Ninguno de los tres se lee como sospechoso: se
// leen como datos. La regla 6 del registro dice que un item cerrado marcado
// abierto ensenia a desconfiar de todo lo demas, y una cifra vieja hace lo
// mismo, solo que mas callada. Se comprueba lo que se puede contar sin correr
// nada; la cuenta de aserciones ya no vive aca, la imprime verificar.sh.
const contar = (dir, filtro) => readdirSync(dir, { recursive: true })
  .filter((f) => filtro.test(String(f))).length;

const migraciones = contar('supabase/migrations', /\.sql$/);
const pantallas = contar('src/routes', /\+page\.svelte$/);

for (const [n, que] of [[migraciones, 'migraciones'], [pantallas, 'pantallas']]) {
  const m = texto.match(new RegExp(`(\\d+) ${que}`));
  if (!m) fallos.push(`el resumen ya no dice cuantas ${que} hay`);
  else if (Number(m[1]) !== n) fallos.push(`el resumen dice ${m[1]} ${que} y hay ${n}`);
}

// 3. Un ADR referenciado tiene que existir.
const adrs = new Set([...readFileSync('docs/ADRs.md', 'utf8').matchAll(/^## (ADR-\d+)/gm)].map((m) => m[1]));
for (const m of texto.matchAll(/ADRs\.md#adr-(\d+)/g)) {
  const id = `ADR-${m[1]}`;
  if (!adrs.has(id)) fallos.push(`el registro apunta a ${id}, que no existe`);
}

if (fallos.length) {
  for (const f of fallos) console.error(`  ${f}`);
  console.error(`\n${fallos.length} inconsistencia/s en ${REG}.`);
  process.exit(1);
}
console.log(`  ${total} items: ${Object.entries(estados).map(([k, v]) => `${v} ${k}`).join(', ')} — el encabezado coincide`);
