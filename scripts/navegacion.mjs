// Comprueba que a cada pantalla se PUEDA LLEGAR, y en cuantos pasos.
//
// Existe porque ya falle dos veces en lo mismo. Los gastos recurrentes se
// construyeron enteros y eran inalcanzables: la unica puerta era una tarjeta que
// aparece cuando ya cargaste uno. Y la cartera quedo a tres clicks detras de la
// administracion de cuentas, siendo la pantalla que contesta la pregunta central
// del proyecto.
//
// La primera vez lo "audite" contando enlaces por ruta. Contar enlaces no es
// recorrer caminos: una ruta puede tener tres enlaces y estar los tres dentro de
// un {#if} que nadie cumple, o colgando de una pantalla a la que tampoco se
// llega. Esto hace lo otro: recorre el grafo desde la barra de navegacion.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const RAIZ = 'src/routes';
const LAYOUT = join(RAIZ, '+layout.svelte');

// /login no cuelga de ningun enlace a proposito: se llega por redireccion cuando
// no hay sesion. Es la unica excepcion legitima.
// Se llegan por redireccion a proposito, no por enlace:
//   /login     cuando no hay sesion
//   /comenzar  cuando no hay ninguna cuenta todavia (ADR-027)
const SIN_ENLACE = new Set(['/login', '/comenzar']);
// Dos, no tres. El defecto real que motivo este script era una pantalla a TRES
// clicks: con el limite en 3 habria pasado en verde y no habria servido de nada.
const MAX_PASOS = 2;

function archivos(dir) {
  return readdirSync(dir).flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? archivos(p) : [p];
  });
}

const paginas = archivos(RAIZ).filter((f) => f.endsWith('+page.svelte'));
const rutaDe = (f) => f.replace(RAIZ, '').replace('/+page.svelte', '') || '/';
const rutas = paginas.map(rutaDe).sort();

// De que pantalla sale un enlace a cual.
const enlaces = new Map();
const agregar = (de, a) => {
  if (de === a) return;
  if (!enlaces.has(de)) enlaces.set(de, new Set());
  enlaces.get(de).add(a);
};

for (const f of paginas) {
  const origen = rutaDe(f);
  for (const [, destino] of readFileSync(f, 'utf8').matchAll(/href="(\/[a-z/-]*)"/g)) {
    agregar(origen, destino);
  }
}

// La barra de navegacion es el punto de partida: lo que un dedo alcanza sin
// haber entrado a ningun lado.
const layout = readFileSync(LAYOUT, 'utf8');
const barra = [...layout.matchAll(/href: '(\/[a-z/-]*)'/g)].map((m) => m[1]);
for (const [, destino] of layout.matchAll(/href="(\/[a-z/-]*)"/g)) barra.push(destino);
const salida = [...new Set(barra)];

if (!salida.length) {
  console.error('No se encontro ninguna pestania en el layout: el grafo no arranca.');
  process.exit(1);
}

const pasos = new Map(salida.map((r) => [r, 1]));
const cola = [...salida];
while (cola.length) {
  const a = cola.shift();
  for (const b of enlaces.get(a) ?? []) {
    if (!pasos.has(b)) { pasos.set(b, pasos.get(a) + 1); cola.push(b); }
  }
}

let malas = 0;
for (const r of rutas) {
  const d = pasos.get(r);
  if (SIN_ENLACE.has(r)) { console.log(`  ${r.padEnd(24)} por redireccion`); continue; }
  if (!d) { console.log(`  ${r.padEnd(24)} INALCANZABLE`); malas++; continue; }
  const etiqueta = d === 1 ? 'en la barra' : `${d} clicks`;
  console.log(`  ${r.padEnd(24)} ${etiqueta}${d > MAX_PASOS ? '  DEMASIADO LEJOS' : ''}`);
  if (d > MAX_PASOS) malas++;
}

if (malas) {
  console.error(`\n${malas} pantalla/s sin camino razonable desde la barra.`);
  process.exit(1);
}
console.log(`  ${rutas.length} pantallas, todas a ${MAX_PASOS} clicks o menos`);
