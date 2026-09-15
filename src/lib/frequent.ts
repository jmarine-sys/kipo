// Cuenta cuánto se usa cada categoría, para que las de siempre queden a un toque.
// Vive en el navegador de cada persona: es una comodidad, no un dato del dominio.
// Por eso todo va envuelto en try/catch — en modo privado localStorage puede fallar.

const KEY = 'kipo:freq';

type Counts = Record<string, number>;

function read(): Counts {
  try {
    return JSON.parse(localStorage.getItem(KEY) ?? '{}') as Counts;
  } catch {
    return {};
  }
}

export function bump(id: string) {
  try {
    const c = read();
    c[id] = (c[id] ?? 0) + 1;
    localStorage.setItem(KEY, JSON.stringify(c));
  } catch { /* sin memoria: se pierde el orden, no la funcionalidad */ }
}

/** Ordena por uso descendente; lo nunca usado queda al final, en su orden original. */
export function byUse<T extends { id: string }>(items: T[]): T[] {
  const c = read();
  return [...items].sort((a, b) => (c[b.id] ?? 0) - (c[a.id] ?? 0));
}

export function used(id: string): boolean {
  return (read()[id] ?? 0) > 0;
}
