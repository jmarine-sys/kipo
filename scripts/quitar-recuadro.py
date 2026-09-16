#!/usr/bin/env python3
"""Quita el recuadro de fondo de un SVG, sin tocar el resto.

    python3 scripts/quitar-recuadro.py static/marca/kipo-saludo.svg

Muchos exportadores ponen un rectangulo del tamanio del lienzo detras del dibujo.
En la aplicacion se ve como un recuadro blanco alrededor de la mascota.

No alcanza con borrar el <path> entero: svgo fusiona todos los caminos del mismo
color, asi que ese path suele traer el recuadro Y los brillos del dibujo juntos.
Hay que sacar solo el PRIMER subcamino, si es el que cubre el lienzo.
"""
import re, sys

# Un numero SVG: puede venir pegado al anterior, porque ".25.25" son dos numeros
# -el segundo punto hace de separador-. Esa notacion compacta es la que rompia
# la primera version de esta expresion.
N = r'\s*,?\s*(-?(?:\d*\.\d+|\d+))'

RECUADRO = re.compile(
    # M x y h ancho v alto H x z     (la forma que genera svgo)
    rf'^M{N}{N}\s*h{N}\s*v{N}\s*H{N}\s*[Zz]'
    # o la forma larga con L
    rf'|^M{N}{N}(?:\s*[Ll]{N}{N}){{2,3}}\s*[Zz]'
)

for ruta in sys.argv[1:]:
    s = open(ruta, encoding='utf-8').read()
    vb = [float(x) for x in re.search(r'viewBox="([\d.\s-]+)"', s).group(1).split()]
    cambios = 0

    def revisar(m):
        global cambios
        d = m.group(1)
        r = RECUADRO.match(d.strip())
        if not r:
            return m.group(0)
        # Los numeros salen de los grupos que capturo la expresion, no de volver a
        # escanear el texto: ".25.25" son dos numeros y un escaneo ingenuo lee uno
        # solo, invalido.
        nums = [abs(float(x)) for x in r.groups() if x is not None]
        if not any(abs(n - vb[2]) < vb[2] * 0.05 for n in nums):
            return m.group(0)
        cambios += 1
        return m.group(0).replace(d, d[r.end():].lstrip(), 1)

    s2 = re.sub(r'\sd="([^"]+)"', lambda m: revisar(m), s)
    if cambios:
        open(ruta, 'w', encoding='utf-8').write(s2)
        print(f"  {ruta}: recuadro quitado")
    else:
        print(f"  {ruta}: no encontre recuadro de fondo (ya esta limpio)")
