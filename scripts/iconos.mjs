// Genera los iconos y el favicon desde la marca original.  node scripts/iconos.mjs
//
// La fuente es static/marca/kipo_.svg, el vector del disenador. No se redibuja
// nada: se separa en dos capas, como funcionan los iconos adaptativos de Android.
//
//   FRENTE  el bolsillo con la moneda, solo
//   FONDO   el menta, generado aca
//
// El archivo original trae las dos cosas fusionadas: un rectangulo blanco que
// cubre el lienzo, encima un cuadrado menta redondeado, y encima el dibujo. Si se
// escala tal cual, se escala tambien el fondo, y el dibujo termina ocupando la
// mitad del icono aunque el archivo llene el cuadro. Por eso se quitan los dos
// rellenos y se compone de nuevo.

import sharp from 'sharp';
import { readFileSync, writeFileSync } from 'node:fs';

const MENTA = '#B6E2D7';
const FUENTE = 'static/marca/kipo_.svg';
const VB = { w: 1847, h: 2048 };   // el viewBox del original

const original = readFileSync(FUENTE, 'utf8');

// Se busca cada capa por lo que ES -su geometria y su color-, y se exige que
// aparezca: un script que no encuentra lo que busca tiene que gritar, no seguir.
const CAPAS = [
  ['el rectangulo blanco de fondo', /<path[^>]*d="M 0 0 L 1847 0 L 1847 2048 L 0 2048 L 0 0 z"[^>]*\/>/],
  ['el cuadrado menta',             /<path[^>]*fill="rgb\(182,\s*226,\s*215\)"[^>]*\/>/]
];

let dibujo = original;
for (const [nombre, patron] of CAPAS) {
  if (!patron.test(dibujo)) {
    throw new Error(`No se encontro ${nombre} en ${FUENTE}. Si cambio el archivo de marca, hay que actualizar el patron.`);
  }
  dibujo = dibujo.replace(patron, '');
}

/** El contenido del <svg>, sin la etiqueta: para poder reencuadrarlo. */
const contenido = dibujo.replace(/<\/?svg[^>]*>/g, '').trim();

// ---------------------------------------------------------------------------
// Donde cae el dibujo dentro del viewBox original. Se mide rasterizando a escala
// 1:1 con el viewBox, asi los pixeles son unidades de usuario.
// ---------------------------------------------------------------------------
const plano = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${VB.w} ${VB.h}" width="${VB.w}" height="${VB.h}">${contenido}</svg>`;
const { info } = await sharp(Buffer.from(plano))
  .trim({ threshold: 1 })
  .toBuffer({ resolveWithObject: true });

const caja = {
  x: info.trimOffsetLeft ? -info.trimOffsetLeft : 0,
  y: info.trimOffsetTop ? -info.trimOffsetTop : 0,
  w: info.width,
  h: info.height
};
console.log(`  el dibujo ocupa ${caja.w}x${caja.h} dentro de ${VB.w}x${VB.h}`);

/**
 * Compone el icono: menta de fondo y el dibujo centrado, escalado para que su
 * lado mayor ocupe `parte` del lienzo.
 * @param {number} parte  0-1
 * @param {number|null} redondeo  radio de esquina, o null para ir a sangre
 */
function componer(parte, redondeo) {
  const S = 512;
  const k = (S * parte) / Math.max(caja.w, caja.h);
  const tx = (S - caja.w * k) / 2 - caja.x * k;
  const ty = (S - caja.h * k) / 2 - caja.y * k;
  const fondo = redondeo === null
    ? `<rect width="${S}" height="${S}" fill="${MENTA}"/>`
    : `<rect width="${S}" height="${S}" rx="${redondeo}" fill="${MENTA}"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${S} ${S}">
  ${fondo}
  <g transform="translate(${tx.toFixed(2)} ${ty.toFixed(2)}) scale(${k.toFixed(5)})">${contenido}</g>
</svg>`;
}

const ESCALA_ANY = 0.80;   // con esquinas redondeadas queda margen suficiente
const ESCALA_MASK = 0.68;  // ver la verificacion contra la zona segura mas abajo

const salidas = [
  ['static/icon-192.png', 192, componer(ESCALA_ANY, 112)],
  ['static/icon-512.png', 512, componer(ESCALA_ANY, 112)],
  ['static/apple-touch-icon.png', 180, componer(ESCALA_ANY, 112)],
  ['static/icon-maskable-512.png', 512, componer(ESCALA_MASK, null)]
];

for (const [ruta, size, svg] of salidas) {
  await sharp(Buffer.from(svg), { density: 900 })
    .resize(size, size)
    .png({ compressionLevel: 9 })
    .toFile(ruta);
  console.log(`  ${ruta}  ${size}x${size}`);
}

// El favicon: CUADRADO y recortado al dibujo. El original es vertical
// (1847x2048), y a 16 pixeles en una pestania eso deja aire arriba y abajo que
// achica el dibujo justo donde menos lugar hay.
writeFileSync('static/favicon.svg', componer(ESCALA_ANY, 112));
console.log('  static/favicon.svg  (cuadrado, recortado al dibujo)');
