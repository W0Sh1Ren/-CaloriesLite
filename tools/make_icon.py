"""
生成应用图标资源（分层图标的前景 + 背景，以及快捷方式用的 startIcon）。

═══════════════════════════════════════════════════════════════════
【素材】icon\\薄荷绿能量美食相机图标.png

它**不是**一张透明底的素材图，而是一张**做好的 App 图标**：
薄荷绿圆角方块 + 白色相机 + 沙拉碗 + 火焰角标。

于是有两个必须处理的点：

  ① **白底**。四角是近纯白（254,254,254）。分层图标里不处理的话
     会露出一个白色方块。做法是把「连到画布边缘的白色」抠成透明。

     ⚠️ 为什么强调「连到画布边缘」：直接按颜色判白会把**图案内部的
     白色**（相机机身、碗里的白）也一起抠掉，整张图就毁了。
     所以用洪水填充（flood fill）从四边往内扩，只吃「外面的白」。

  ② **自带圆角，且内容占 92%**。系统还会再裁一次圆角，
     两层圆角叠加会「露白角」。所以缩到画布的 CONTENT_RATIO，
     四周留出安全区，让系统的裁剪落在透明区上。

【背景层】按用户要求保持全透明。

【改完重跑】python tools\\make_icon.py
【看效果】  python tools\\make_preview.py
═══════════════════════════════════════════════════════════════════
"""
import os
from collections import deque
from PIL import Image

# 相对本文件定位，不写死绝对路径：
#   tools/make_icon.py → 上一级是项目根，素材在 icon/ 下
_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
SRC = os.path.join(_ROOT, 'icon', '薄荷绿能量美食相机图标.png')

CANVAS = 1024
# 内容占画布的比例。
# 0.80：比角色头像那版（0.67）大 —— 这张图自带圆角，缩太小会显得空；
#       又明显小于 1.0，给系统的圆角裁剪留出安全区。
# 觉得四周太空就调到 0.86，露白角就调回 0.76。
CONTENT_RATIO = 0.80

APP_SCOPE = os.path.join(_ROOT, 'AppScope', 'resources', 'base', 'media')
ENTRY = os.path.join(_ROOT, 'entry', 'src', 'main', 'resources', 'base', 'media')

# 判定为「背景白」的阈值：三通道都不低于它才算白
WHITE_MIN = 238


def strip_outer_white(src: Image.Image) -> Image.Image:
    """
    把「从画布四边连进来的白色」抠成透明，返回 RGBA。

    用从边界出发的洪水填充，而不是全图按颜色判白 ——
    后者会把图案内部的白色（相机机身、碗）也抠掉。
    """
    src = src.convert('RGBA')
    W, H = src.size
    px = src.load()

    def is_white(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        return a > 0 and r >= WHITE_MIN and g >= WHITE_MIN and b >= WHITE_MIN

    visited = bytearray(W * H)
    q = deque()

    # 种子：四条边上的白像素
    for x in range(W):
        for y in (0, H - 1):
            if is_white(x, y) and not visited[y * W + x]:
                visited[y * W + x] = 1
                q.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if is_white(x, y) and not visited[y * W + x]:
                visited[y * W + x] = 1
                q.append((x, y))

    # 四邻域向外扩展，只吃掉与边界连通的白
    while q:
        x, y = q.popleft()
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < W and 0 <= ny < H:
                idx = ny * W + nx
                if not visited[idx] and is_white(nx, ny):
                    visited[idx] = 1
                    q.append((nx, ny))
    return src


def make_foreground(size: int, content_ratio: float) -> Image.Image:
    """去白底 → 按 alpha 边界裁剪 → 等比缩放 → 居中贴到透明画布。"""
    src = strip_outer_white(Image.open(SRC))

    # 白底去掉后，alpha 的边界就是圆角方块的外缘
    bbox = src.getchannel('A').getbbox()
    if bbox:
        src = src.crop(bbox)

    target = int(size * content_ratio)
    # LANCZOS：图标有大量细线条与圆角，低质量缩放会有锯齿
    src = src.resize((target, target), Image.LANCZOS)

    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    off = (size - target) // 2
    canvas.paste(src, (off, off), src)
    return canvas


def make_background(size: int) -> Image.Image:
    """全透明背景层。想加底色就改这里。"""
    return Image.new('RGBA', (size, size), (0, 0, 0, 0))


def main() -> None:
    if not os.path.exists(SRC):
        raise SystemExit(f'找不到素材：{SRC}\n（应位于 icon/ 下）')

    fg = make_foreground(CANVAS, CONTENT_RATIO)
    bg = make_background(CANVAS)

    # 两处 media 目录都要写：AppScope 是应用级图标，entry 是模块级
    #（只改一个会出现「某个地方还是旧图标」）
    for folder in (APP_SCOPE, ENTRY):
        fg.save(os.path.join(folder, 'foreground.png'), 'PNG', optimize=True)
        bg.save(os.path.join(folder, 'background.png'), 'PNG', optimize=True)
        print(f'written: {folder}')

    # 快捷方式/启动图标：不分层，直接就是这张图（同样透明底）
    fg.save(os.path.join(ENTRY, 'startIcon.png'), 'PNG', optimize=True)
    print(f'written: {ENTRY}\\startIcon.png')

    print(f'foreground: {fg.size}  content bbox={fg.getchannel("A").getbbox()}')
    print(f'background: {bg.size}  alpha extrema={bg.getchannel("A").getextrema()}')


if __name__ == '__main__':
    main()
