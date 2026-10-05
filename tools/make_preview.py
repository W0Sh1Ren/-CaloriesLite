"""
图标预览：把生成好的图标在几种背景下合成一张对比图。

用来在装机前确认「透明底是否真的透明」「角色有没有被裁到」——
生成图标后跑一次：
    python tools\\make_preview.py
产物：docs\\图标预览.png
"""
import os
from PIL import Image, ImageDraw

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
ENTRY = os.path.join(_ROOT, 'entry', 'src', 'main', 'resources', 'base', 'media')
OUT = os.path.join(_ROOT, 'docs', '图标预览.png')

S = 300  # 每个样例的边长


def checker(size: int, cell: int = 20) -> Image.Image:
    """透明格底，用来确认哪些区域真的是透明的。"""
    im = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, size, cell):
        for x in range(0, size, cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle([x, y, x + cell - 1, y + cell - 1], fill=(220, 220, 220, 255))
    return im


def circle(im: Image.Image) -> Image.Image:
    """按系统圆形裁剪。"""
    size = im.size[0]
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def main() -> None:
    fg = Image.open(os.path.join(ENTRY, 'foreground.png')).convert('RGBA')
    small = fg.resize((S, S), Image.LANCZOS)

    variants = []

    # 1. 透明格底：确认背景真的透明
    v = checker(S)
    v.paste(small, (0, 0), small)
    variants.append(v)

    # 2. 浅色底（app 背景色）
    v = Image.new('RGBA', (S, S), (245, 248, 246, 255))
    v.paste(small, (0, 0), small)
    variants.append(v)

    # 3. 深色底
    v = Image.new('RGBA', (S, S), (32, 34, 38, 255))
    v.paste(small, (0, 0), small)
    variants.append(v)

    # 4. 圆形裁剪 + 浅色底：确认没被切到
    cir = circle(small)
    v = Image.new('RGBA', (S, S), (245, 248, 246, 255))
    v.paste(cir, (0, 0), cir)
    variants.append(v)

    gap = 10
    sheet = Image.new('RGBA', (S * len(variants) + gap * (len(variants) + 1), S + gap * 2),
                      (128, 128, 128, 255))
    for i, im in enumerate(variants):
        sheet.paste(im, (gap + i * (S + gap), gap), im)

    sheet.convert('RGB').save(OUT, 'PNG')
    print(f'written: {OUT}')


if __name__ == '__main__':
    main()
