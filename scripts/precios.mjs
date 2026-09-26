// Trae el precio de los activos que TENES y los emite como SQL.
//
//   psql "$DB" -At -F $'\t' -c "$CONSULTA" | node scripts/precios.mjs > precios.sql
//   ... | node scripts/precios.mjs desde 2026-09-16 > precios.sql
//
// Mismo patron que cotizaciones.mjs: emite SQL por la salida estandar en vez de
// escribir en la base. Asi se puede mirar que va a hacer antes de ejecutarlo.
//
// La diferencia con las cotizaciones es POR QUE corre todos los dias: las del
// dolar se pueden pedir hacia atras, son dato publico. Los precios de los
// activos NO -verificado el 2026-09-16: data912 no tiene endpoint historico y
// BYMA solo publica la rueda del dia-. El precio de hoy que no se guarda hoy no
// se recupera nunca (OD-31).
//
// RECUPERAR HACIA ATRAS: se puede, pero solo para cripto.
//
//   Binance  /api/v3/klines  -> cierre diario de cualquier fecha  (verificado)
//   BYMA     /cedears-history -> 401, pide autenticacion
//
// Asi que un dia perdido de cripto se recupera con `desde` y uno de CEDEARs no.
// Esto corrige lo que OD-31 daba por parejo para todos los activos.
//
// ENTRADA: TSV por stdin, una linea por instrumento:
//   kind \t symbol \t simbolo_en_la_fuente \t quote_currency
//
// El tercer campo es coalesce(underlying_symbol, symbol): un CEDEAR se puede
// llamar "AAPL-CEDEAR" en tu libro y "AAPL" en BYMA.

// Quien cotiza que, definido UNA vez. Se importa el .ts directo: node le quita
// los tipos desde la 22 -verificado contra node:22.23.3-, y el modulo no importa
// nada, que es justo la condicion para que este script pueda leerlo.
import { fuenteDe } from '../src/lib/ledger/precios.ts';

const BYMA = 'https://open.bymadata.com.ar/vanoms-be-core/rest/api/bymadata/free';
const DATA912 = 'https://data912.com/live';

// Que endpoint tiene cada familia. Se consultan TODOS y se busca el simbolo en
// el que le corresponde primero: los simbolos no se repiten entre familias, pero
// preferir la propia evita una coincidencia desafortunada el dia que pase.
const FAMILIAS = {
  cedear: ['arg_cedears'],
  etf:    ['arg_cedears'],
  stock:  ['arg_stocks'],
  bond:   ['arg_bonds', 'arg_corp']
};
const BINANCE = 'https://api.binance.com/api/v3/ticker/price';
const BINANCE_HIST = 'https://api.binance.com/api/v3/klines';

/**
 * La fecha DEL MERCADO, no la del reloj del servidor.
 *
 * Los cron de GitHub llegan tarde: el respaldo esta programado 06:17 UTC y
 * aterriza cerca de las 11:45. Con ese retraso, una corrida de las 21:00 UTC
 * puede ejecutarse pasada la medianoche y estampar el precio con la fecha del
 * dia SIGUIENTE, corriendo la serie entera un dia sin que nada falle.
 *
 * En hora argentina eso no pasa: las 02:00 UTC son las 23:00 del dia anterior,
 * que es el dia de la rueda al que ese precio pertenece.
 */
function fechaLocal(d = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Argentina/Buenos_Aires',
    year: 'numeric', month: '2-digit', day: '2-digit'
  }).format(d);
}

const hoy = fechaLocal();
const desde = process.argv[2] === 'desde' ? process.argv[3] : null;

/** Lee el TSV de la entrada estandar. */
async function leerEntrada() {
  const trozos = [];
  for await (const t of process.stdin) trozos.push(t);
  return trozos.join('')
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean)
    .map((l) => {
      const [kind, symbol, feed, moneda] = l.split('\t');
      return { kind, symbol, feed: feed || symbol, moneda };
    });
}

/**
 * fetch con reintentos.
 *
 * BYMA devuelve la respuesta cortada a la mitad si no se pide comprimida —se
 * verifico: 2196 filas con --compressed, JSON truncado sin el-. Un JSON.parse
 * que falla es ruidoso y por eso es seguro; lo que habria sido grave es que
 * parseara a medias. Por las dudas, se reintenta y se valida el tamanio.
 */
async function pedir(url, opciones = {}, intentos = 3) {
  let ultimo;
  for (let i = 0; i < intentos; i++) {
    try {
      const r = await fetch(url, {
        ...opciones,
        headers: {
          'User-Agent': 'kipo/1.0',
          'Accept-Encoding': 'gzip, deflate',
          ...(opciones.headers ?? {})
        }
      });
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      return await r.json();
    } catch (e) {
      ultimo = e;
      await new Promise((ok) => setTimeout(ok, 1000 * (i + 1)));
    }
  }
  throw new Error(`${url}: ${ultimo.message}`);
}

/**
 * El mercado local: CEDEARs, acciones, bonos y obligaciones negociables.
 *
 * FUENTE PRINCIPAL data912, RESPALDO BYMA, y el orden es al reves del que decidio
 * ADR-025. La razon es dura y verificada el 2026-09-18 contra la cartera real:
 * BYMA no publica las OBLIGACIONES NEGOCIABLES en su API libre. De los 16 papeles
 * del usuario, BYMA cubria 12 y data912 los 16.
 *
 * Elegir "BYMA para lo que puede y data912 para el resto" seria peor: dos fuentes
 * para el mismo trabajo son dos formas de romperse y dos formatos que mantener.
 * Asi que data912 va primero para todo, y BYMA queda de respaldo REAL para las
 * familias que si publica — si data912 desaparece, solo se pierden las ON.
 *
 * El precio se guarda TAL COMO SE COTIZA. Un bono cotiza por cada 100 nominales
 * y eso NO se corrige aca: lo sabe el instrumento (`quote_size`), porque si la
 * division viviera en este script, un precio cargado a mano entraria cien veces
 * arriba.
 */
async function deMercadoLocal(pedidos) {
  if (!pedidos.length) return [];

  const mapas = new Map();
  const caidos = [];
  for (const ep of new Set(Object.values(FAMILIAS).flat())) {
    try {
      const filas = await pedir(`${DATA912}/${ep}`);
      const m = new Map();
      for (const f of filas ?? []) {
        const precio = Number(f.c) || Number(f.px_bid) || 0;
        if (f.symbol && precio) m.set(f.symbol, precio);
      }
      mapas.set(ep, m);
    } catch (e) {
      caidos.push(`${ep}: ${e.message}`);
    }
  }

  const out = [];
  const sinResolver = [];
  for (const p of pedidos) {
    const donde = FAMILIAS[p.kind] ?? Object.values(FAMILIAS).flat();
    let precio = 0;
    for (const ep of donde) { precio = mapas.get(ep)?.get(p.feed) ?? 0; if (precio) break; }
    if (precio) out.push({ ...p, precio, moneda: 'ARS', fuente: 'data912' });
    else sinResolver.push(p);
  }

  // Respaldo: lo que data912 no resolvio y BYMA si publica.
  if (sinResolver.length) {
    const deBYMA = await deBymaRespaldo(sinResolver);
    out.push(...deBYMA);
  }

  if (!out.length && caidos.length) {
    throw new Error(`ninguna fuente respondio (${caidos.join('; ')})`);
  }
  return out;
}

/**
 * BYMA, solo para lo que data912 no pudo.
 *
 * Tres endpoints, uno por familia. No publica obligaciones negociables: probados
 * el 2026-09-18, `corporate-bonds` y `negotiable-obligations` devuelven 401.
 *
 * Cada simbolo aparece DOS veces, una por plazo de liquidacion: se prefiere el
 * menor y da igual cual, lo que importa es elegir siempre el mismo. Y se filtra
 * por denominationCcy = 'ARS' porque los mismos papeles cotizan ademas en USD
 * (sufijo D) y en cable (sufijo C): mezclarlos seria valuar una posicion en pesos
 * con un precio en dolares.
 */
async function deBymaRespaldo(pedidos) {
  const ENDPOINTS = { cedear: 'cedears', etf: 'cedears', stock: 'leading-equity', bond: 'public-bonds' };
  const cache = new Map();
  const out = [];

  for (const p of pedidos) {
    const ep = ENDPOINTS[p.kind];
    if (!ep) { p.falta = `${p.kind}: BYMA no publica esa familia`; continue; }

    if (!cache.has(ep)) {
      try {
        const cruda = await pedir(`${BYMA}/${ep}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ excludeZeroPxAndQty: true, T1: false, T0: false })
        });
        const filas = Array.isArray(cruda) ? cruda : (cruda.data ?? []);
        const m = new Map();
        for (const f of filas) {
          if (f.denominationCcy !== 'ARS') continue;
          const previo = m.get(f.symbol);
          if (!previo || String(f.settlementType) < String(previo.settlementType)) m.set(f.symbol, f);
        }
        cache.set(ep, m);
      } catch (e) {
        cache.set(ep, new Map());
      }
    }

    const f = cache.get(ep).get(p.feed);
    // settlementPrice es el ultimo operado. Si el papel no opero hoy viene en 0
    // y se usa el cierre anterior: un precio viejo es peor que uno nuevo, pero
    // infinitamente mejor que inventar uno.
    const precio = f ? (Number(f.settlementPrice) || Number(f.previousClosingPrice) || 0) : 0;
    if (!precio) { p.falta = 'ninguna fuente lo cotiza hoy'; continue; }
    out.push({ ...p, precio, moneda: 'ARS', fuente: 'byma' });
  }
  return out;
}

/**
 * Cripto de Binance, en USDT.
 *
 * Es la fuente correcta para ESTE portafolio y no solo una mas: el usuario opera
 * en Binance, asi que el precio de Binance es el que efectivamente obtendria.
 * Un indice global seria mas "neutral" y menos cierto.
 *
 * USDT no es exactamente USD -flota unas decimas alrededor del dolar-. Se acepta
 * la aproximacion porque la alternativa es sumar una conversion mas, con su
 * propia fuente que puede caerse, para corregir un 0,1%.
 */
async function deBinance(pedidos) {
  const out = [];
  for (const p of pedidos) {
    const par = `${p.feed.toUpperCase()}USDT`;
    try {
      if (desde) {
        // Una vela diaria por fecha. El cierre de la vela es el precio del dia;
        // el tiempo de apertura es lo que define A QUE dia pertenece.
        const t0 = Date.parse(`${desde}T00:00:00Z`);
        const velas = await pedir(`${BINANCE_HIST}?symbol=${par}&interval=1d&startTime=${t0}&limit=1000`);
        if (!velas?.length) { p.falta = `${par} sin historico desde ${desde}`; continue; }
        for (const v of velas) {
          const precio = Number(v[4]);
          if (!precio) continue;
          out.push({
            ...p, precio, moneda: p.moneda, fuente: 'binance',
            fecha: fechaLocal(new Date(v[0]))
          });
        }
      } else {
        const r = await pedir(`${BINANCE}?symbol=${par}`);
        const precio = Number(r.price);
        if (!precio) { p.falta = `${par} sin precio`; continue; }
        out.push({ ...p, precio, moneda: p.moneda, fuente: 'binance' });
      }
    } catch {
      p.falta = `${par} no existe en Binance`;
    }
  }
  return out;
}

function sql(v) {
  return typeof v === 'string' ? `'${v.replace(/'/g, "''")}'` : v;
}

/**
 * Se busca el instrumento por symbol dentro del libro, no por id: el script no
 * sabe -ni tiene por que saber- que id tiene cada cosa. `unique (ledger_id,
 * symbol)` garantiza que no haya ambiguedad.
 */
function emitir(p) {
  return `insert into price (ledger_id, instrument_id, on_date, price, currency, source)
select i.ledger_id, i.id, ${sql(p.fecha ?? hoy)}, ${p.precio}, ${sql(p.moneda)}, ${sql(p.fuente)}
  from instrument i where i.symbol = ${sql(p.symbol)} and i.archived_at is null
on conflict (instrument_id, on_date, source)
do update set price = excluded.price, currency = excluded.currency;`;
}

// ---------------------------------------------------------------------------

const pedidos = await leerEntrada();
if (!pedidos.length) {
  console.error('Sin instrumentos en la entrada: no hay nada que cotizar.');
  process.exit(0);
}

// Un precio en la moneda equivocada es peor que ningun precio: valuaria una
// posicion en pesos con un numero en dolares y nadie lo notaria.
//
// El reparto NO se decide aca: lo decide `src/lib/ledger/precios.ts`, que es el
// mismo modulo con el que la pantalla de inversiones le dice al usuario si esa
// posicion va a cotizar sola. Estaba escrito en los dos lados y ya se habian
// separado -este cotiza bonos en pesos y la pantalla los daba por manuales-.
const enPesos = pedidos.filter((p) => fuenteDe(p) === 'byma');
const enDolares = pedidos.filter((p) => fuenteDe(p) === 'binance');

for (const p of pedidos) {
  if (!fuenteDe(p)) {
    p.falta = `${p.kind} en ${p.moneda}: ninguna fuente configurada`;
  }
}

const resultados = [];
const errores = [];

// En modo `desde` BYMA no participa: no tiene de donde sacar el pasado. Decirlo
// es mejor que intentarlo y guardar el precio de HOY con fecha de ayer, que es
// la forma silenciosa de arruinar una serie.
if (desde && enPesos.length) {
  for (const p of enPesos) p.falta = `${p.kind} no se puede recuperar hacia atras: solo se publica la rueda del dia`;
}

for (const [nombre, fn, lote] of [
  ['Mercado local', deMercadoLocal, desde ? [] : enPesos],
  ['Binance', deBinance, enDolares]
]) {
  if (!lote.length) continue;
  try {
    resultados.push(...(await fn(lote)));
  } catch (e) {
    errores.push(`${nombre}: ${e.message}`);
  }
}

const sinPrecio = pedidos.filter((p) => p.falta);
for (const p of sinPrecio) console.error(`  sin precio  ${p.symbol} — ${p.falta}`);
for (const e of errores) console.error(`  FUENTE CAIDA  ${e}`);

if (resultados.length) {
  console.log('-- generado por scripts/precios.mjs — no editar a mano');
  console.log(desde
    ? `-- ${resultados.length} precios, desde ${desde} hasta ${hoy}`
    : `-- ${resultados.length} precios del ${hoy}`);
  console.log('begin;');
  console.log(resultados.map(emitir).join('\n'));
  console.log('commit;');
}

console.error(`  ${resultados.length} precios de ${pedidos.length} instrumento/s (${desde ? `desde ${desde}` : hoy})`);

// Una fuente caida es un fallo: el dia que no se guarda no vuelve. Un simbolo
// suelto sin precio no lo es —un papel puede no operar— pero queda dicho arriba.
if (errores.length) process.exit(1);
