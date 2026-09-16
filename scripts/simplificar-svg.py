#!/usr/bin/env python3
"""Simplifica un SVG sin redibujarlo.

    python3 scripts/simplificar-svg.py entrada.svg salida.svg [--umbral N] [--minimo N]

Tres operaciones, ninguna toca la geometria: la silueta queda intacta.

  1. APLANA GRADIENTES   cada gradiente pasa a ser el promedio de sus paradas.
  2. FUSIONA COLORES     los que estan a menos de --umbral de distancia RGB.
  3. DESCARTA PATHS      los mas chicos, donde vive la textura (--minimo).

Sobre el criterio del punto 2, que costo dos intentos:

  por cantidad de paths  ->  INCORRECTO. El fondo suele ser UN path que cubre
                             medio dibujo; quedaba afuera y se perdia el fondo.
  por area en pixeles    ->  INCORRECTO. El contorno es una linea fina que cubre
                             casi nada; quedaba afuera y el dibujo perdia el
                             contorno.
  por cercania (este)    ->  lo que separa una textura de un contorno no es su
                             tamano, es que la textura es casi el mismo color que
                             su vecino y el contorno no se parece a nada. Un color
                             aislado sobrevive aunque ocupe cuatro pixeles.
"""
import re, math, os, argparse, subprocess, tempfile
from collections import Counter


def a_rgb(c):
    m = re.match(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)', c)
    if m:
        return tuple(int(x) for x in m.groups())
    m = re.match(r'#([0-9a-fA-F]{6})$', c)
    if m:
        return tuple(int(m.group(1)[i:i + 2], 16) for i in (0, 2, 4))
    return None


def de_rgb(t):
    return f'rgb({t[0]},{t[1]},{t[2]})'


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def area_por_color(svg, paleta):
    """Cuantos pixeles ocupa cada color al dibujarlo de verdad."""
    from PIL import Image
    with tempfile.NamedTemporaryFile('w', suffix='.svg', delete=False, encoding='utf-8') as f:
        f.write(svg)
        ruta = f.name
    png = ruta + '.png'
    subprocess.run(['convert', '-background', 'none', ruta, '-resize', '260x260', png],
                   check=True, capture_output=True)
    im = Image.open(png).convert('RGB')
    cuenta = Counter()
    for q in im.getdata():
        cuenta[min(paleta, key=lambda c: dist(c, q))] += 1
    os.unlink(ruta)
    os.unlink(png)
    return cuenta


def numeros(d):
    return len(re.findall(r'-?\d+\.?\d*', d))


ap = argparse.ArgumentParser()
ap.add_argument('entrada')
ap.add_argument('salida')
ap.add_argument('--umbral', type=int, default=28,
                help='distancia RGB por debajo de la cual dos colores se funden')
ap.add_argument('--minimo', type=int, default=0,
                help='descartar paths con menos de N numeros en su atributo d')
ap.add_argument('--quitar', action='append', default=[],
                help='descartar todo path de este color (ej: --quitar "#FFFFFF"). Repetible')
a = ap.parse_args()

svg = open(a.entrada, encoding='utf-8').read()

# ---- 1. aplanar gradientes -------------------------------------------------
grads = {}
for g in re.finditer(r'<(linear|radial)Gradient[^>]*id="([^"]+)"(.*?)</\1Gradient>', svg, re.S):
    paradas = [c for c in (a_rgb(x) for x in re.findall(r'stop-color="([^"]+)"', g.group(3))) if c]
    if paradas:
        grads[g.group(2)] = tuple(sum(c[i] for c in paradas) // len(paradas) for i in range(3))
for gid, col in grads.items():
    svg = svg.replace(f'url(#{gid})', de_rgb(col))
svg = re.sub(r'<defs>.*?</defs>', '', svg, flags=re.S)

# ---- 2. fusionar colores cercanos ------------------------------------------
usos = Counter()
for m in re.finditer(r'fill="([^"]+)"', svg):
    c = a_rgb(m.group(1))
    if c:
        usos[c] += 1

areas = area_por_color(svg, list(usos))
# del mas presente al menos: los grandes absorben a sus vecinos, no al reves
principales, mapa = [], {}
for c, _ in areas.most_common():
    cerca = next((p for p in principales if dist(c, p) <= a.umbral), None)
    if cerca:
        mapa[c] = cerca
    else:
        principales.append(c)
        mapa[c] = c
for c in usos:
    mapa.setdefault(c, min(principales, key=lambda p: dist(c, p)))

svg = re.sub(r'fill="([^"]+)"',
             lambda m: f'fill="{de_rgb(mapa[a_rgb(m.group(1))])}"' if a_rgb(m.group(1)) else m.group(0),
             svg)

# ---- 2b. quitar colores enteros --------------------------------------------
# Tipicamente el rectangulo blanco que muchos exportadores ponen de fondo: en la
# aplicacion se ve como un recuadro blanco alrededor de la mascota.
sacados = 0
for col in a.quitar:
    rgb = a_rgb(col)
    if not rgb:
        raise SystemExit(f'No entiendo el color {col}')
    objetivo = de_rgb(mapa.get(rgb, rgb))
    def sacar(m):
        global sacados
        if f'fill="{objetivo}"' in m.group(0):
            sacados += 1
            return ''
        return m.group(0)
    svg = re.sub(r'<path\b[^>]*?(?:/\s*>|>\s*</path>)', sacar, svg, flags=re.S)

# ---- 3. descartar los paths mas chicos -------------------------------------
quitados = 0
if a.minimo:
    def filtrar(m):
        global quitados
        d = re.search(r'\sd="([^"]*)"', m.group(0))
        if d and numeros(d.group(1)) < a.minimo:
            quitados += 1
            return ''
        return m.group(0)
    # los paths vienen auto-cerrados o con </path>: hay que contemplar los dos
    svg = re.sub(r'<path\b[^>]*?(?:/\s*>|>\s*</path>)', filtrar, svg, flags=re.S)

open(a.salida, 'w', encoding='utf-8').write(svg)

total = max(1, sum(areas.values()))
print(f"  gradientes aplanados: {len(grads)}")
print(f"  colores: {len(usos)} → {len(principales)}   (umbral {a.umbral})")
for c in principales[:7]:
    print(f"    {de_rgb(c):22s} {areas[c] * 100 // total:3d}%")
print(f"  paths quitados por color: {sacados}")
print(f"  paths descartados por chicos: {quitados}")
