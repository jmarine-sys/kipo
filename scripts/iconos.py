#!/usr/bin/env python3
"""Genera los iconos de la PWA.  python3 scripts/iconos.py

Android solo instala una WebAPK de verdad -la que va al cajon de aplicaciones y
oculta la barra de direcciones- si el manifest declara iconos PNG de 192 y 512
que SE PUEDAN DECODIFICAR. Si faltan, Chrome degrada a un acceso directo y no
avisa por que.
"""
from PIL import Image, ImageDraw

AZUL   = (37, 99, 235)
BLANCO = (255, 255, 255)
SS     = 4  # supersampling, para que los bordes no queden dentados


def marca(d: ImageDraw.ImageDraw, size: int, escala: float, cx: float, cy: float):
    """La 'k' de kipo, en el espacio de 64 unidades del favicon."""
    u = size * escala / 64
    ox, oy = cx - 32 * u, cy - 32 * u
    p = lambda x, y: (ox + x * u, oy + y * u)
    grosor = max(1, int(6 * u))

    for a, b in [((20, 16), (20, 48)), ((20, 32), (36, 16)), ((20, 32), (38, 48))]:
        d.line([p(*a), p(*b)], fill=BLANCO, width=grosor)
    # extremos redondeados: Pillow no tiene line-cap, se dibujan a mano
    for x, y in [(20, 16), (20, 48), (20, 32), (36, 16), (38, 48)]:
        px, py = p(x, y)
        r = grosor / 2
        d.ellipse([px - r, py - r, px + r, py + r], fill=BLANCO)


def icono(size: int, maskable: bool) -> Image.Image:
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if maskable:
        # A pantalla completa: la mascara del sistema recorta la forma que quiera.
        # La marca ocupa el 60% central para sobrevivir a cualquier recorte.
        d.rectangle([0, 0, s, s], fill=AZUL)
        marca(d, s, 0.60, s / 2, s / 2)
    else:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=AZUL)
        marca(d, s, 0.86, s / 2, s / 2)

    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    salidas = [
        ("static/icon-192.png",          192, False),
        ("static/icon-512.png",          512, False),
        ("static/icon-maskable-512.png", 512, True),
        ("static/apple-touch-icon.png",  180, False),
    ]
    for ruta, size, mask in salidas:
        icono(size, mask).save(ruta, "PNG", optimize=True)
        print(f"  {ruta}  {size}x{size}{'  (maskable)' if mask else ''}")
