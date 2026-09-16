// Trae cotizaciones del dolar y la serie UVA, y las emite como SQL.
//
//   node scripts/cotizaciones.mjs hoy            -> solo el dia de hoy
//   node scripts/cotizaciones.mjs desde 2026-01-01
//
// Emite SQL por la salida estandar en vez de conectarse a la base: asi la misma
// herramienta sirve para mirar que va a hacer antes de ejecutarlo, y el flujo de
// GitHub la encadena con psql reusando el secreto que ya existe para el respaldo.
//
// Fuente: api.argentinadatos.com — devuelve cualquier fecha pasada y cubre las
// seis cotizaciones. Verificado el 2026-09-16.

const API = 'https://api.argentinadatos.com/v1';

// Como se llama cada cotizacion alla y como se llama aca
const CASAS = {
  oficial: 'oficial',
  blue: 'blue',
  bolsa: 'mep',
  contadoconliqui: 'ccl',
  cripto: 'cripto',
  mayorista: 'mayorista'
};

const modo = process.argv[2] ?? 'hoy';
const desde = process.argv[3] ?? null;

function iso(d) {
  return d.toISOString().slice(0, 10);
}

/** Todas las fechas entre dos, inclusive. */
function rango(a, b) {
  const out = [];
  for (let d = new Date(a + 'T00:00:00Z'); iso(d) <= b; d.setUTCDate(d.getUTCDate() + 1)) {
    out.push(iso(d));
  }
  return out;
}

async function json(url) {
  const r = await fetch(url);
  if (!r.ok) return null;
  return r.json();
}

function sql(valor) {
  return typeof valor === 'string' ? `'${valor.replace(/'/g, "''")}'` : valor;
}

/**
 * Una fila por libro: las cotizaciones son universales pero la tabla es por
 * libro, porque asi la politica de RLS es la misma en todas las tablas y no
 * necesita excepciones.
 */
function emitir(fecha, base, quote, rate, source) {
  return `insert into fx_rate (ledger_id, on_date, base, quote, rate, source)
select l.id, ${sql(fecha)}, ${sql(base)}, ${sql(quote)}, ${rate}, ${sql(source)} from ledger l
on conflict (ledger_id, on_date, base, quote, source) do update set rate = excluded.rate;`;
}

const hoy = iso(new Date());
const fechas = modo === 'desde' && desde ? rango(desde, hoy) : [hoy];
const lineas = [];

// ---- dolar -----------------------------------------------------------------
// Se guarda el PROMEDIO de compra y venta. Tomar una de las dos puntas seria
// elegir un lado -comprar o vender- y aca no se esta operando: se esta midiendo.
for (const fecha of fechas) {
  const [a, m, d] = fecha.split('-');
  for (const [casa, fuente] of Object.entries(CASAS)) {
    const r = await json(`${API}/cotizaciones/dolares/${casa}/${a}/${m}/${d}`);
    if (!r || r.compra == null || r.venta == null) continue;
    const promedio = (Number(r.compra) + Number(r.venta)) / 2;
    if (!promedio) continue;
    lineas.push(emitir(fecha, 'USD', 'ARS', promedio, fuente));
  }
}

// ---- UVA -------------------------------------------------------------------
// La serie viene entera en una sola llamada, asi que se pide una vez y se filtra.
const uva = await json(`${API}/finanzas/indices/uva`);
if (uva) {
  const desdeUva = fechas[0];
  for (const punto of uva) {
    if (punto.fecha < desdeUva || punto.fecha > hoy) continue;
    lineas.push(emitir(punto.fecha, 'UVA', 'ARS', punto.valor, 'uva'));
  }
}

if (!lineas.length) {
  console.error('No se obtuvo ninguna cotizacion');
  process.exit(1);
}

console.log('-- generado por scripts/cotizaciones.mjs — no editar a mano');
console.log(`-- ${lineas.length} cotizaciones, de ${fechas[0]} a ${hoy}`);
console.log('begin;');
console.log(lineas.join('\n'));
console.log('commit;');
console.error(`  ${lineas.length} cotizaciones listas (${fechas.length} fecha/s)`);
