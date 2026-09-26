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
// DOS limites, no uno.
//
// La primera version exigia dos clicks para TODO, y esa regla estaba mal: acorta
// el camino a la pantalla de ajustes al mismo precio que al de registrar un
// gasto, y el lugar en la barra es finito. Aplicada a todo, amontona en el
// camino rapido cosas que se tocan una vez por anio.
//
// Lo que importa no es la distancia sino QUE esta lejos. Asi que la lista de
// abajo dice que pantallas son del uso diario -esas, a dos clicks- y el resto
// tiene tres. Ninguna puede ser inalcanzable.
//
// El defecto que motivo el script sigue atrapado: la cartera estaba a TRES y
// esta en la lista.
const CAMINO_RAPIDO = new Set([
  '/',             // el resumen del mes
  '/nuevo',        // registrar: el 90% del uso
  '/movimientos',  // revisar lo cargado
  '/cartera',      // la pregunta central del proyecto
  '/recurrentes',  // lo que se viene
  '/cuentas'       // ajustar un saldo, ver cuanto hay
]);
const MAX_RAPIDO = 2;
const MAX_PASOS  = 3;

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

/**
 * Las rutas que declara un modulo de $lib.
 *
 * Una pantalla puede enlazar con `href={f.ruta}`, donde la ruta vive en una
 * estructura compartida —asi estan las familias de inversion y las pestanias de
 * la barra—. Mirando solo los `href="..."` literales, esos caminos no existen
 * para este chequeo y una pantalla perfectamente alcanzable figura como
 * inalcanzable. Eso es un falso positivo, y un chequeo que miente se desactiva.
 */
function rutasDeModulo(mod) {
  try {
    const texto = readFileSync(mod, 'utf8');
    return [...texto.matchAll(/(?:ruta|href)\s*:\s*'(\/[a-z/-]*)'/g)].map((m) => m[1]);
  } catch {
    return [];
  }
}

for (const f of paginas) {
  const origen = rutaDe(f);
  const texto = readFileSync(f, 'utf8');

  // Se acepta lo que venga despues de `?` o `#`: `/nuevo?volver=/movimientos`
  // lleva a /nuevo igual. Sin esto el boton flotante no contaba como enlace y
  // /nuevo figuraba a dos clicks estando en la barra.
  for (const [, destino] of texto.matchAll(/href="(\/[a-z/-]*)(?:[?#][^"]*)?"/g)) {
    agregar(origen, destino);
  }

  // Y las que le llegan por lo que importa de $lib.
  for (const [, mod] of texto.matchAll(/from '\$lib\/([a-zA-Z0-9/._-]+)'/g)) {
    const base = join('src/lib', mod.replace(/\.(ts|js|svelte)$/, ''));
    for (const cand of [`${base}.ts`, `${base}.svelte`, base]) {
      const rutas = rutasDeModulo(cand);
      if (rutas.length) { for (const d of rutas) agregar(origen, d); break; }
    }
  }
}

// La barra de navegacion es el punto de partida: lo que un dedo alcanza sin
// haber entrado a ningun lado.
const layout = readFileSync(LAYOUT, 'utf8');
const barra = [...layout.matchAll(/href: '(\/[a-z/-]*)'/g)].map((m) => m[1]);
for (const [, destino] of layout.matchAll(/href="(\/[a-z/-]*)(?:[?#{][^"]*)?"/g)) barra.push(destino);
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
  const tope = CAMINO_RAPIDO.has(r) ? MAX_RAPIDO : MAX_PASOS;
  const etiqueta = d === 1 ? 'en la barra' : `${d} clicks`;
  const marca = d > tope ? (tope === MAX_RAPIDO ? '  DEMASIADO LEJOS (uso diario)' : '  DEMASIADO LEJOS') : '';
  console.log(`  ${r.padEnd(24)} ${etiqueta}${marca}`);
  if (d > tope) malas++;
}

if (malas) {
  console.error(`\n${malas} pantalla/s sin camino razonable desde la barra.`);
  process.exit(1);
}
console.log(`  ${rutas.length} pantallas: las de uso diario a ${MAX_RAPIDO} clicks, el resto a ${MAX_PASOS}`);
