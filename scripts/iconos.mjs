// Genera los iconos de la PWA desde la marca original.   node scripts/iconos.mjs
//
// La fuente es static/marca/kipo_.svg, el vector que hizo el disenador.
// No se redibuja nada: solo se quita el fondo blanco, se recorta al arte y se
// compone sobre el menta de la marca.
//
// Android solo instala una WebAPK de verdad -la que va al cajon de aplicaciones y
// oculta la barra de direcciones- si estos PNG existen y se pueden decodificar.
// Si faltan, degrada a un acceso directo y no dice por que.

import sharp from 'sharp';
import { readFileSync, writeFileSync } from 'node:fs';

const MENTA = '#B6E2D7';          // el fondo del icono, tomado del propio SVG
const FUENTE = 'static/marca/kipo_.svg';

// El SVG trae un rectangulo blanco de 1847x2048 cubriendo todo. Se quita para que
// las esquinas queden transparentes: en un lanzador oscuro, ese blanco se veria
// como cuatro muescas.
// Se busca por el ATRIBUTO d -el rectangulo que cubre el lienzo entero- y no por
// el color: es lo unico que identifica al fondo sin ambiguedad.
const original = readFileSync(FUENTE, 'utf8');
const FONDO = /<path[^>]*d="M 0 0 L 1847 0 L 1847 2048 L 0 2048 L 0 0 z"[^>]*\/>/;

if (!FONDO.test(original)) {
  // Antes esto fallaba en silencio y los iconos salian con las esquinas blancas.
  // Un script que no encuentra lo que busca tiene que gritar, no seguir.
  throw new Error(
    'No se encontro el rectangulo de fondo en ' + FUENTE + '. ' +
    'Si cambio el archivo de marca, hay que actualizar este patron.'
  );
}

const sinFondo = original.replace(FONDO, '');
writeFileSync('static/favicon.svg', sinFondo);

/** Rasteriza y recorta al arte, para que no queden margenes muertos. */
async function arte(px) {
  return sharp(Buffer.from(sinFondo), { density: 900 })
    .resize({ height: px })
    .trim({ threshold: 1 })       // saca el margen transparente sobrante
    .png()
    .toBuffer();
}

/**
 * @param {number} size   lado del PNG
 * @param {number} escala cuanto ocupa el arte dentro del cuadro (0-1)
 * @param {boolean} sangre  fondo menta a sangre (maskable) o transparente (any)
 */
async function icono(size, escala, sangre) {
  const interior = Math.round(size * escala);
  const arteBuf = await arte(interior);
  const meta = await sharp(arteBuf).metadata();

  const lienzo = sangre
    ? sharp({
        create: { width: size, height: size, channels: 4,
                  background: MENTA }
      })
    : sharp({
        create: { width: size, height: size, channels: 4,
                  background: { r: 0, g: 0, b: 0, alpha: 0 } }
      });

  return lienzo
    .composite([{
      input: arteBuf,
      left: Math.round((size - meta.width) / 2),
      top: Math.round((size - meta.height) / 2)
    }])
    .png({ compressionLevel: 9 })
    .toBuffer();
}

const salidas = [
  // El arte ya trae su propio cuadrado redondeado menta: ocupa casi todo el cuadro.
  ['static/icon-192.png', 192, 0.98, false],
  ['static/icon-512.png', 512, 0.98, false],
  ['static/apple-touch-icon.png', 180, 0.98, false],
  // Maskable: menta a sangre y el arte al 72%, porque la zona segura es el 80%
  // central y Samsung recorta en circulo.
  ['static/icon-maskable-512.png', 512, 0.72, true]
];

for (const [ruta, size, escala, sangre] of salidas) {
  writeFileSync(ruta, await icono(size, escala, sangre));
  console.log(`  ${ruta}  ${size}x${size}${sangre ? '  (maskable)' : ''}`);
}
console.log('  static/favicon.svg  (el mismo vector, sin el fondo blanco)');
