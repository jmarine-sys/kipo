const FMT = new Map<string, Intl.NumberFormat>();

function fmt(unit: string): Intl.NumberFormat {
  let f = FMT.get(unit);
  if (!f) {
    const isMoney = unit === 'ARS' || unit === 'USD' || unit === 'USDT';
    f = new Intl.NumberFormat('es-AR', {
      style: isMoney && unit !== 'USDT' ? 'currency' : 'decimal',
      currency: isMoney ? (unit === 'USDT' ? 'USD' : unit) : undefined,
      minimumFractionDigits: isMoney ? 2 : 0,
      // cripto puede necesitar 8; los CEDEARs son enteros
      maximumFractionDigits: isMoney ? 2 : 8
    });
    FMT.set(unit, f);
  }
  return f;
}

/** Formatea un monto en su unidad. Las unidades que no son moneda salen con su simbolo al lado. */
export function money(amount: number | string, unit = 'ARS'): string {
  const n = typeof amount === 'string' ? Number(amount) : amount;
  if (!Number.isFinite(n)) return '—';
  const s = fmt(unit).format(n);
  return unit === 'ARS' || unit === 'USD' ? s : `${s} ${unit}`;
}

/** Igual que money() pero siempre con signo explicito. Para deltas. */
export function signed(amount: number | string, unit = 'ARS'): string {
  const n = typeof amount === 'string' ? Number(amount) : amount;
  return (n > 0 ? '+' : '') + money(n, unit);
}

export function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export function monthRange(d = new Date()): { from: string; to: string; label: string } {
  const y = d.getFullYear();
  const m = d.getMonth();
  const p = (n: number) => String(n).padStart(2, '0');
  const last = new Date(y, m + 1, 0).getDate();
  return {
    from: `${y}-${p(m + 1)}-01`,
    to: `${y}-${p(m + 1)}-${p(last)}`,
    label: new Intl.DateTimeFormat('es-AR', { month: 'long', year: 'numeric' }).format(d)
  };
}

export function shortDate(iso: string): string {
  const [y, m, d] = iso.split('-').map(Number);
  return new Intl.DateTimeFormat('es-AR', { day: 'numeric', month: 'short' })
    .format(new Date(y, m - 1, d));
}
