import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont
W,H=2880,1800
RAW='raw/'
def font(sz,w=b"Bold"):
    f=ImageFont.truetype('/System/Library/Fonts/SFNSRounded.ttf',sz)
    try: f.set_variation_by_name(w)
    except Exception: pass
    return f
def bg():
    top=(214,238,252); mid=(150,208,245); bot=(10,115,230)
    im=Image.new('RGB',(W,H)); px=ImageDraw.Draw(im)
    for y in range(H):
        t=y/H
        c=[int(top[i]+(mid[i]-top[i])*t/0.6) for i in range(3)] if t<0.6 else [int(mid[i]+(bot[i]-mid[i])*(t-0.6)/0.4) for i in range(3)]
        px.line([(0,y),(W,y)],fill=tuple(c))
    ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    for k,(base,amp,col) in enumerate([(1380,40,(90,190,250,110)),(1470,34,(30,140,240,130)),(1570,28,(4,100,215,170))]):
        pts=[(x, base+amp*math.sin(x/W*2*math.pi*1.5+k*1.3)) for x in range(0,W+1,8)]+[(W,H),(0,H)]
        d.polygon(pts,fill=col)
    for (x,y,r) in [(300,1500,14),(420,1420,9),(2560,1450,12),(2650,1560,8),(2480,1640,18)]:
        d.ellipse([x-r,y-r,x+r,y+r],outline=(255,255,255,150),width=3)
    return Image.alpha_composite(im.convert('RGBA'),ov)
def rounded(img,r):
    m=Image.new('L',img.size,0); ImageDraw.Draw(m).rounded_rectangle([0,0,img.size[0]-1,img.size[1]-1],r,fill=255)
    out=img.convert('RGBA'); a=out.getchannel('A'); from PIL import ImageChops
    out.putalpha(ImageChops.multiply(a,m)); return out
def make(raw,head,sub,out,maxh=1360,maxw=2300,radius=24):
    im=bg(); shot=Image.open(RAW+raw).convert('RGBA')
    if raw=='popover.png':
        b=Image.new('RGBA',shot.size,(246,250,253,255)); b.alpha_composite(shot); shot=b
    s=min(maxh/shot.height,maxw/shot.width,1.0); shot=shot.resize((round(shot.width*s),round(shot.height*s)),Image.LANCZOS)
    shot=rounded(shot,round(radius*s*2))
    x=(W-shot.width)//2; y=380+(H-380-60-shot.height)//2
    sh=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(sh).rounded_rectangle([x,y+30,x+shot.width,y+shot.height+30],40,fill=(5,40,90,110))
    sh=sh.filter(ImageFilter.GaussianBlur(45)); im=Image.alpha_composite(im,sh)
    im.alpha_composite(shot,(x,y))
    d=ImageDraw.Draw(im); f=font(124); g=font(56,b"Medium")
    d.text((W//2,150),head,font=f,fill=(8,52,110),anchor='mm')
    d.text((W//2,275),sub,font=g,fill=(40,95,150),anchor='mm')
    im.convert('RGB').save(out,optimize=True)
make('welcome.png','Meet Rayna, your hydration buddy','A happy stingray who lives in your menu bar.','01-welcome.png')
make('popover.png','One tap per glass','Watch Rayna\u2019s ring fill as you sip through the day.','02-menubar.png',maxh=1240,radius=12)
make('settings.png','Gentle reminders, quiet when you want','Set your goal, nudge interval and quiet hours.','03-settings.png')
make('journey.png','Track your journey','Streaks, unlockable extras and a weekly recap.','04-journey.png')
