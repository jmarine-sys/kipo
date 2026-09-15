// Un color por categoria madre, para distinguirlas de un vistazo sin escribir
// su nombre en cada renglon (OD-27).
//
// Se deriva del nombre, no se guarda: cero trabajo para el usuario y siempre
// consistente. Si algun dia quiere elegirlos a mano, se agrega una columna y
// esto pasa a ser el valor por defecto.

const PALETA = [
  '#E4572E', // teja
  '#E09F3E', // ocre
  '#2E8B57', // verde
  '#17A398', // turquesa
  '#2E86AB', // azul
  '#6A4C93', // violeta
  '#C2407A', // frambuesa
  '#8D6E4A'  // tierra
];

/** Hash estable: el mismo nombre siempre da el mismo color, en cualquier sesion. */
export function colorCategoria(nombre: string | null | undefined): string {
  if (!nombre) return 'var(--text-dim)';
  let h = 0;
  for (let i = 0; i < nombre.length; i++) h = (h * 31 + nombre.charCodeAt(i)) | 0;
  return PALETA[Math.abs(h) % PALETA.length];
}
