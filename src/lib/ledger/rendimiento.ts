/**
 * XIRR — el rendimiento anualizado ponderado por dinero.
 *
 * Responde "¿cuánto rindió lo MÍO?", teniendo en cuenta cuándo puso cada peso.
 * Es la métrica correcta para un objetivo personal del tipo "quiero 10% anual".
 *
 * La otra candidata, TWR, responde "¿qué tan bueno fue el activo?" e ignora los
 * aportes. Sirve para comparar contra un índice, no para saber si cumpliste.
 *
 * Convención de signos, que es donde se equivoca todo el mundo:
 *
 *   NEGATIVO  plata que salió de tu bolsillo   (comprar, aportar)
 *   POSITIVO  plata que volvió a tu bolsillo   (vender, cobrar, y el VALOR DE HOY
 *                                                de lo que todavía tenés)
 *
 * El valor actual entra como un flujo positivo con la fecha de hoy: es lo que
 * recibirías si vendieras todo ahora.
 */

export interface Flujo {
  /** AAAA-MM-DD */
  fecha: string;
  monto: number;
}

const DIAS_ANIO = 365;

function dias(desde: string, hasta: string): number {
  const a = Date.parse(desde + 'T00:00:00Z');
  const b = Date.parse(hasta + 'T00:00:00Z');
  return (b - a) / 86_400_000;
}

/** Valor presente neto a una tasa dada. En la raíz —donde da cero— está el XIRR. */
function vpn(flujos: Flujo[], r: number, origen: string): number {
  let s = 0;
  for (const f of flujos) {
    s += f.monto / Math.pow(1 + r, dias(origen, f.fecha) / DIAS_ANIO);
  }
  return s;
}

/**
 * La tasa anual que hace que todos los flujos se cancelen.
 * Devuelve null cuando no hay respuesta posible, en vez de un número inventado:
 *
 *   - menos de dos flujos
 *   - todos del mismo signo (sin aportes o sin retornos no hay rendimiento)
 *   - no converge
 */
export function xirr(flujos: Flujo[]): number | null {
  if (flujos.length < 2) return null;

  const hayPositivo = flujos.some((f) => f.monto > 0);
  const hayNegativo = flujos.some((f) => f.monto < 0);
  if (!hayPositivo || !hayNegativo) return null;

  const orden = [...flujos].sort((a, b) => (a.fecha < b.fecha ? -1 : 1));
  const origen = orden[0].fecha;

  // Todo el mismo día: no hay tiempo transcurrido, no hay tasa anual posible.
  if (orden.every((f) => f.fecha === origen)) return null;

  // Bisección, no Newton-Raphson. Es más lenta y no importa —son unas decenas de
  // flujos— pero SIEMPRE converge si la raíz está acotada, mientras que Newton
  // puede irse a cualquier lado con flujos irregulares, que son justamente los
  // de una cartera real.
  let bajo = -0.9999;   // por debajo de -100% la fórmula no tiene sentido
  let alto = 10;        // 1000% anual: si lo supera, algo está mal cargado

  let vBajo = vpn(orden, bajo, origen);
  let vAlto = vpn(orden, alto, origen);

  // Si no cambia de signo en el intervalo, la raíz no está adentro.
  if (vBajo * vAlto > 0) {
    // se estira una vez hacia arriba por si el rendimiento es enorme
    alto = 100;
    vAlto = vpn(orden, alto, origen);
    if (vBajo * vAlto > 0) return null;
  }

  for (let i = 0; i < 200; i++) {
    const medio = (bajo + alto) / 2;
    const v = vpn(orden, medio, origen);
    if (Math.abs(v) < 1e-9 || alto - bajo < 1e-12) return medio;
    if (v * vBajo < 0) {
      alto = medio;
    } else {
      bajo = medio;
      vBajo = v;
    }
  }
  return (bajo + alto) / 2;
}

/**
 * Ganancia absoluta: lo que tenés hoy más lo que sacaste, menos lo que pusiste.
 * Es la única métrica que se explica sola, y por eso va primero (brief §13).
 */
export function gananciaAbsoluta(flujos: Flujo[]): number {
  return flujos.reduce((t, f) => t + f.monto, 0);
}

/** Cuánto se puso en total. Sirve de denominador para el porcentaje simple. */
export function totalAportado(flujos: Flujo[]): number {
  return flujos.filter((f) => f.monto < 0).reduce((t, f) => t - f.monto, 0);
}

/** Cuántos días lleva la inversión más vieja. */
export function antiguedadDias(flujos: Flujo[], hasta: string): number {
  if (!flujos.length) return 0;
  const primera = flujos.map((f) => f.fecha).sort()[0];
  return Math.max(0, Math.round(dias(primera, hasta)));
}
