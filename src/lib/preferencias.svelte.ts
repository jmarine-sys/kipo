/**
 * Preferencias de quien usa la app. Viven en el navegador de cada persona: son
 * comodidad, no dato del dominio, así que no van a la base.
 *
 * Se aplican como atributos en <html> y no como clases en un componente, por dos
 * motivos: el CSS puede reaccionar desde la raíz sin que ningún componente tenga
 * que enterarse, y un script diminuto en app.html puede ponerlas ANTES del
 * primer pintado, así no se ve el destello del tema equivocado al abrir.
 */

export type Tema = 'auto' | 'claro' | 'oscuro';

const CLAVE = 'kipo:prefs';

export const prefs = $state({
  tema: 'auto' as Tema,
  privado: false
});

function guardar() {
  try {
    localStorage.setItem(CLAVE, JSON.stringify({ tema: prefs.tema, privado: prefs.privado }));
  } catch {
    /* modo privado del navegador: se pierde la preferencia, no la funcionalidad */
  }
}

function aplicar() {
  const raiz = document.documentElement;
  if (prefs.tema === 'auto') delete raiz.dataset.tema;
  else raiz.dataset.tema = prefs.tema;

  if (prefs.privado) raiz.dataset.privado = 'si';
  else delete raiz.dataset.privado;
}

/** Lee lo guardado. El script de app.html ya lo aplicó; esto sincroniza el estado. */
export function cargarPreferencias() {
  try {
    const crudo = localStorage.getItem(CLAVE);
    if (crudo) {
      const o = JSON.parse(crudo) as Partial<typeof prefs>;
      if (o.tema === 'claro' || o.tema === 'oscuro' || o.tema === 'auto') prefs.tema = o.tema;
      if (typeof o.privado === 'boolean') prefs.privado = o.privado;
    }
  } catch { /* sin memoria: quedan los valores por defecto */ }
  aplicar();
}

export function elegirTema(t: Tema) {
  prefs.tema = t;
  aplicar();
  guardar();
}

export function alternarPrivado() {
  prefs.privado = !prefs.privado;
  aplicar();
  guardar();
}
