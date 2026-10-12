"""Icon (teal house + camera lens + orange check) and sample interior photos for DEBUG showcase."""
import random, math, os
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.dirname(os.path.abspath(__file__)) + "/../Shikikin"
S = 4096; k = S / 1024
def r(v): return int(round(v * k))
img = Image.new("RGB", (S, S)); d = ImageDraw.Draw(img)
top, bot = (20, 140, 142), (6, 78, 86)
for y in range(S):
    t = y / (S - 1); d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i]-top[i]) * t) for i in range(3)))
# soft glow
glow = Image.new("L", (S, S), 0); ImageDraw.Draw(glow).ellipse([r(150), r(60), r(870), r(700)], fill=70)
img = Image.composite(Image.new("RGB", (S, S), (90, 200, 195)), img, glow.filter(ImageFilter.GaussianBlur(r(120))))
# shadow
sh = Image.new("L", (S, S), 0); sd = ImageDraw.Draw(sh)
house = [(r(512), r(170)), (r(860), r(470)), (r(790), r(470)), (r(790), r(850)), (r(234), r(850)), (r(234), r(470)), (r(164), r(470))]
sd.polygon([(x, y + r(22)) for x, y in house], fill=120)
img.paste((0, 40, 45), (0, 0), sh.filter(ImageFilter.GaussianBlur(r(26))))
d = ImageDraw.Draw(img)
d.polygon(house, fill=(250, 248, 240))
d.rounded_rectangle([r(234), r(470), r(790), r(850)], radius=r(20), fill=(250, 248, 240))
# camera lens
cx, cy = r(512), r(615)
for rad, col in [(190, (36, 52, 60)), (160, (14, 100, 106)), (118, (20, 30, 38)), (70, (24, 120, 130)), (40, (10, 20, 26))]:
    d.ellipse([cx - r(rad), cy - r(rad), cx + r(rad), cy + r(rad)], fill=col)
d.ellipse([cx - r(52), cy - r(70), cx - r(14), cy - r(32)], fill=(200, 240, 238))
# orange check badge
bx, by, br = r(770), r(800), r(130)
d.ellipse([bx - br, by - br, bx + br, by + br], fill=(238, 125, 50), outline=(250, 248, 240), width=r(18))
d.line([(bx - r(62), by + r(2)), (bx - r(15), by + r(50)), (bx + r(68), by - r(48))], fill=(255, 255, 255), width=r(30), joint="curve")
os.makedirs(OUT + "/Assets.xcassets/AppIcon.appiconset", exist_ok=True)
img.resize((1024, 1024), Image.LANCZOS).save(OUT + "/Assets.xcassets/AppIcon.appiconset/icon.png")
img.resize((1024, 1024), Image.LANCZOS).save("/workspace/shikikin/icon_1024.png")

def room(name, wall, floor, extra, seed):
    W, H = 1600, 1200; rnd = random.Random(seed)
    im = Image.new("RGB", (W, H), wall); dd = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H; dd.line([(0, y), (W, y)], fill=tuple(int(c * (1.04 - 0.12 * t)) for c in wall))
    fy = int(H * 0.68)
    for y in range(fy, H):
        t = (y - fy) / (H - fy); dd.line([(0, y), (W, y)], fill=tuple(int(c * (0.85 + 0.2 * t)) for c in floor))
    for i in range(-20, 40):  # floor boards in perspective
        x0 = W / 2 + i * 60; x1 = W / 2 + i * 200
        dd.line([(x0, fy), (x1, H)], fill=tuple(int(c * 0.8) for c in floor), width=3)
    dd.rectangle([0, fy - 18, W, fy], fill=(235, 232, 225))
    for _ in range(9000):
        x, y = rnd.randrange(W), rnd.randrange(fy)
        v = rnd.randint(-6, 6); p = im.getpixel((x, y)); im.putpixel((x, y), tuple(max(0, min(255, c + v)) for c in p))
    extra(dd, W, H, fy, rnd)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    im.save(f"{OUT}/Resources/{name}.jpg", quality=86)

def scuff(dd, W, H, fy, rnd):
    for _ in range(40):
        x, y = 700 + rnd.gauss(0, 50), 520 + rnd.gauss(0, 30)
        dd.ellipse([x, y, x + rnd.randint(4, 18), y + rnd.randint(3, 10)], fill=(150, 140, 125))
    dd.line([(640, 470), (820, 560)], fill=(130, 120, 110), width=4)
def scratch(dd, W, H, fy, rnd):
    for i in range(6):
        x = 600 + i * 30; dd.line([(x, 980), (x + 260, 1010 + rnd.randint(-10, 10))], fill=(110, 80, 50), width=3)
    dd.ellipse([1000, 940, 1090, 990], outline=(100, 72, 46), width=5)
def window(dd, W, H, fy, rnd):
    dd.rectangle([300, 120, 1300, fy - 30], fill=(205, 225, 240), outline=(200, 200, 200), width=24)
    dd.line([(800, 120), (800, fy - 30)], fill=(200, 200, 200), width=20)
    for x in range(820, 1290, 14): dd.line([(x, 140), (x, fy - 50)], fill=(150, 160, 165), width=1)
    dd.polygon([(1000, 300), (1080, 360), (1030, 420)], fill=(170, 175, 180))
def door(dd, W, H, fy, rnd):
    dd.rectangle([560, 80, 1040, fy], fill=(196, 160, 118), outline=(160, 125, 90), width=10)
    dd.ellipse([960, 440, 1000, 480], fill=(200, 200, 205))
    dd.line([(620, 300), (700, 340)], fill=(140, 105, 70), width=5)
def kitchen(dd, W, H, fy, rnd):
    dd.rectangle([150, 430, 1450, fy + 120], fill=(238, 238, 236), outline=(180, 180, 180), width=6)
    dd.rectangle([150, 410, 1450, 450], fill=(170, 172, 175))
    dd.rectangle([500, 380, 820, 430], fill=(150, 152, 156))
    dd.rectangle([150, 120, 1450, 330], fill=(232, 230, 226), outline=(190, 190, 190), width=6)
    for _ in range(25):
        x, y = 560 + rnd.gauss(0, 40), 395 + rnd.gauss(0, 6); dd.ellipse([x, y, x + 6, y + 4], fill=(90, 95, 92))
def plain(dd, W, H, fy, rnd):
    dd.rectangle([1150, 200, 1500, fy - 10], fill=(244, 242, 236), outline=(200, 196, 190), width=8)
    dd.ellipse([180, 260, 260, 300], fill=(205, 200, 185))
os.makedirs(OUT + "/Resources", exist_ok=True)
room("sample_wall", (236, 232, 222), (190, 150, 110), scuff, 1)
room("sample_floor", (236, 232, 222), (180, 135, 95), scratch, 2)
room("sample_window", (240, 237, 230), (186, 146, 105), window, 3)
room("sample_door", (238, 234, 226), (186, 146, 105), door, 4)
room("sample_kitchen", (242, 240, 236), (205, 200, 190), kitchen, 5)
room("sample_room", (238, 236, 230), (176, 136, 98), plain, 6)
