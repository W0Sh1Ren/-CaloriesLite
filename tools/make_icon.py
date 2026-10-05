"""
生成应用图标资源（分层图标的前景 + 背景，以及快捷方式用的 startIcon）。

分层图标的关键约束：系统会把图标裁成圆形/圆角，**贴边的部分会被切掉**。
所以前景图不能直接铺满画布 —— 原图内容占 94.9%，直接换上去头发两侧会被裁掉。
这里把它缩到画布的 67%（与工程里原有的 foreground.png 一致的安全比例），
居中放到透明画布上。

背景层按用户要求做成**全透明**：图标就是那个角色本身，不要底色。
（分层图标允许背景层透明，系统会保留透明区域。）

本文件是唯一来源：改完重跑一次，会同时更新下面所有资源。
    python tools\\make_icon.py
改完想看效果：
    python tools\\make_preview.py

【原图位置】docs\\图标原图.png —— 已随项目提交，脚本用相对路径定位，
所以整个项目拷到别的机器/目录也能直接重跑。
"""
import os
from PIL import Image

# 相对本文件定位，不写死绝对路径：
#   tools/make_icon.py → 上两级是项目根，原图在 docs/ 下
_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
SRC = os.path.join(_ROOT, 'docs', '图标原图.png')

CANVAS = 1024
# 内容占画布的比例。与工程原有 foreground.png 的 67% 对齐（那个是安全的）。
# 调到 0.72~0.75 角色会更大，但圆角裁剪切边风险上升。
CONTENT_RATIO = 0.67

APP_SCOPE = os.path.join(_ROOT, 'AppScope', 'resources', 'base', 'media')
ENTRY = os.path.join(_ROOT, 'entry', 'src', 'main', 'resources', 'base', 'media')


def make_foreground(size: int, content_ratio: float) -> Image.Image:
    """把角色图缩放到 size 的 content_ratio，居中贴到透明画布上。"""
    src = Image.open(SRC).convert('RGBA')
    # 先按内容边界裁剪，再等比缩放 —— 否则原图自身的留白会让角色偏小/偏心
    bbox = src.getchannel('A').getbbox()
    if bbox:
        src = src.crop(bbox)

    target = int(size * content_ratio)
    # 用 LANCZOS 缩放：头像有大量细线条，低质量缩放会糊
    src = src.resize((target, target), Image.LANCZOS)

    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    off = (size - target) // 2
    canvas.paste(src, (off, off), src)
    return canvas


def make_background(size: int) -> Image.Image:
    """全透明背景层。想加底色就改这里（返回一个填充好颜色的 RGBA 图）。"""
    return Image.new('RGBA', (size, size), (0, 0, 0, 0))


def main() -> None:
    if not os.path.exists(SRC):
        raise SystemExit(f'找不到原图：{SRC}\n（应位于 docs/图标原图.png）')

    fg = make_foreground(CANVAS, CONTENT_RATIO)
    bg = make_background(CANVAS)

    # 两处 media 目录都要写：AppScope 是应用级图标，entry 是模块级
    #（只改一个会出现「某个地方还是旧图标」）
    for folder in (APP_SCOPE, ENTRY):
        fg.save(os.path.join(folder, 'foreground.png'), 'PNG', optimize=True)
        bg.save(os.path.join(folder, 'background.png'), 'PNG', optimize=True)
        print(f'written: {folder}')

    # 快捷方式/启动图标：不分层，直接就是角色本身（同样透明底）
    fg.save(os.path.join(ENTRY, 'startIcon.png'), 'PNG', optimize=True)
    print(f'written: {ENTRY}\\startIcon.png')

    # 自检
    print(f'foreground: {fg.size}  content bbox={fg.getchannel("A").getbbox()}')
    print(f'background: {bg.size}  alpha extrema={bg.getchannel("A").getextrema()}')


if __name__ == '__main__':
    main()
