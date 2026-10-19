from draw import *
from existing import baby_ray
GOLD=[(1,.88,.4),(.85,.6,.1)]; GOLDLINE=(.7,.48,.05)
RED=(.95,.25,.35); RED2=(.85,.18,.3); BLUE=(.2,.45,.95); SYM=(.1,.45,.75); INK=(.08,.1,.15)
WLIGHT=(.55,.86,.96); WDEEP=(.1,.45,.75)

def sparkle(d,cx,cy,r,col=WHITE,a=1):
    k=r*.28
    d.fill(d.path([('M',cx,cy-r),('Q',cx+k*.3,cy-k*.3,cx+r,cy),('Q',cx+k*.3,cy+k*.3,cx,cy+r),('Q',cx-k*.3,cy+k*.3,cx-r,cy),('Q',cx-k*.3,cy-k*.3,cx,cy-r),('Z',)]),col=col,a=a)

def drop(d,cx,cy,r,a=1):
    d.fill(d.path([('M',cx,cy-r*2),('Q',cx+r*1.1,cy-r*.4,cx+r,cy),('Q',cx+r*.9,cy+r,cx,cy+r),('Q',cx-r*.9,cy+r,cx-r,cy),('Q',cx-r*1.1,cy-r*.4,cx,cy-r*2),('Z',)]),
           shader=d.lin(cx,cy-r*2,cx,cy+r,[(.75,.95,1,a),(.25,.62,.85,a)]))
    d.oval(cx-r*.35,cy-r*.2,r*.25,r*.35,col=WHITE,a=.8*a)

def water(d,top,amp,waves,bottom=.985,phase=0,alpha=.9,foam=True,x0=.03,x1=.97):
    # rounded-bottom pool of water with a sine surface
    d.c.saveLayer()
    n=48; pts=[]
    for i in range(n+1):
        x=x0+(x1-x0)*i/n
        pts.append((x, top+amp*math.sin(phase+waves*2*math.pi*(x-x0)/(x1-x0))))
    cmds=[('M',*pts[0])]+[('L',*p) for p in pts[1:]]+[('L',x1,bottom-.03),('Q',x1,bottom,x1-.03,bottom),('L',x0+.03,bottom),('Q',x0,bottom,x0,bottom-.03),('Z',)]
    d.fill(d.path(cmds),shader=d.lin(.5,top-amp,.5,bottom,[(*WLIGHT,alpha*.85),(*WDEEP,alpha)]))
    if foam:
        line=[('M',*pts[0])]+[('L',*p) for p in pts[1:]]
        d.fill(d.path(line),col=WDEEP,a=.55,stroke=.011)
        d.fill(d.path(line),col=WHITE,a=.95,stroke=.006)
    m=skia.Paint(AntiAlias=True); m.setBlendMode(skia.BlendMode.kDstIn)
    m.setShader(skia.GradientShader.MakeLinear([d.P(x0,0),d.P(x1,0)],[C(0,0,0,0),C(0,0,0,1),C(0,0,0,1),C(0,0,0,0)],[0,.16,.84,1]))
    d.c.drawRect(skia.Rect.MakeWH(d.s,d.s),m); d.c.restore()
    return pts

# 1. surge — ripple at 125%
def surge(d,t=0):
    cx,cy=.555,.905
    for i,(rx,a) in enumerate([(.06,.95),(.11,.75),(.165,.5),(.22,.28)]):
        ry=rx*.3
        d.oval(cx,cy,rx,ry,col=WDEEP,a=a*.6,stroke=.010)
        d.oval(cx,cy,rx,ry,col=WHITE,a=a,stroke=.005)
    drop(d,.47,.82,.011); drop(d,.645,.80,.013); drop(d,.60,.765,.008,a=.85)

# 2. tide — spring tide at 150% (full moon + big swell)
def moon(d,cx,cy,r):
    d.oval(cx,cy,r*1.55,r*1.55,col=(1,.95,.7),a=.25)
    d.oval(cx,cy,r,r,shader=d.lin(cx-r,cy-r,cx+r,cy+r,[(1,.98,.85),(.96,.84,.5)]))
    d.oval(cx,cy,r,r,col=(.82,.66,.3),stroke=.004)
    for (dx,dy,rr) in [(-.3,-.15,.22),(.25,.25,.16),(.2,-.35,.11)]:
        d.oval(cx+dx*r,cy+dy*r,rr*r,rr*r,col=(.86,.72,.4),a=.55)
    d.oval(cx-r*.35,cy-r*.45,r*.25,r*.15,col=WHITE,a=.7)
def tide(d,t=0):
    moon(d,.835,.095,.05)
    pts=water(d,.835,.022,2.0,phase=1.2)
    # a curling crest on the left
    d.fill(d.path([('M',.10,.835),('Q',.14,.77,.215,.80),('Q',.17,.80,.16,.835),('Z',)]),shader=d.lin(.1,.77,.2,.84,[(*WLIGHT,1),(*WDEEP,1)]))
    d.fill(d.path([('M',.10,.835),('Q',.14,.77,.215,.80)]),col=WHITE,a=.95,stroke=.006)
    for x,y,r in [(.22,.77,.008),(.25,.79,.005),(.70,.80,.006)]:
        d.oval(x,y,r,r,col=WHITE,a=.9)
    # tide-mark arrows (up)
    for x in (.30,.70):
        d.fill(d.path([('M',x,.93),('L',x,.875),('M',x-.018,.893),('L',x,.873),('L',x+.018,.893)]),col=WHITE,a=.9,stroke=.007)

# 3. flood — flood tide at 200%: water risen high, sparkles
def flood(d,t=0):
    pts=water(d,.62,.018,2.5,phase=.4,alpha=.62)
    for x,y,r in [(.3,.78,.012),(.66,.72,.009),(.42,.9,.01),(.74,.88,.014),(.2,.9,.008)]:
        d.oval(x,y,r,r,col=WHITE,a=.85,stroke=.004)
        d.oval(x-r*.25,y-r*.25,r*.35,r*.35,col=WHITE,a=.7)
    for (x,y) in [(.16,.585),(.84,.585)]:
        for k,(dx,dy) in enumerate([(-.03,-.03),(0,-.045),(.03,-.03)]):
            d.oval(x+dx,y+dy,.008,.008,col=WHITE,a=.95)
            d.oval(x+dx,y+dy,.008,.008,col=WDEEP,a=.5,stroke=.003)
    for (x,y,r,c) in [(.17,.10,.035,(1,.88,.4)),(.85,.07,.028,WHITE),(.87,.34,.03,(1,.88,.4)),(.12,.36,.022,WHITE),(.70,.03,.018,(1,.88,.4))]:
        sparkle(d,x,y,r*1.15,col=GOLDLINE if c!=WHITE else WDEEP,a=.35); sparkle(d,x,y,r,col=c)

# 4. over3 — extra-mile mark: a milestone with a little flag
def over3(d,t=0):
    # dotted swim trail
    for i in range(9):
        u=i/8
        x=.12+u*.33; y=.95-.05*math.sin(u*math.pi)-u*.03
        d.oval(x+.08,y,.006,.006,col=WHITE,a=.9); d.oval(x+.08,y,.006,.006,col=WDEEP,a=.45,stroke=.002)
    cx,base,w,h=.2,.93,.15,.2
    stone=d.path([('M',cx-w/2,base),('L',cx-w/2,base-h+w/2),('Q',cx-w/2,base-h,cx,base-h),('Q',cx+w/2,base-h,cx+w/2,base-h+w/2),('L',cx+w/2,base),('Z',)])
    d.fill(stone,shader=d.lin(cx-w/2,base-h,cx+w/2,base,[(.93,.96,.99),(.62,.72,.84)]))
    d.fill(stone,col=(.3,.42,.58),stroke=.005)
    d.text('3',cx,base-h*.42,.11,SYM)
    d.oval(cx-w*.22,base-h*.82,w*.12,h*.05,col=WHITE,a=.8)
    # flag
    px=cx+w*.18
    d.fill(d.path([('M',px,base-h+.005),('L',px,base-h-.085)]),col=(.35,.3,.28),stroke=.006)
    d.fill(d.path([('M',px,base-h-.085),('Q',px+.04,base-h-.095,px+.075,base-h-.07),('Q',px+.04,base-h-.055,px,base-h-.045),('Z',)]),col=RED)
    d.fill(d.path([('M',px+.003,base-h-.07),('Q',px+.035,base-h-.077,px+.06,base-h-.069)]),col=WHITE,a=.85,stroke=.004)

# 5. over7 — week ribbon (rosette with tails)
def over7(d,t=0):
    cx,cy,r=.5,.37,.055
    for sx,ang in ((-1,.0),(1,0)):
        x0=cx+sx*.012
        d.fill(d.path([('M',x0-.016,cy+.01),('L',x0+sx*.03-.02,cy+.13),('L',x0+sx*.03,cy+.11),('L',x0+sx*.03+.02,cy+.13),('L',x0+.016,cy+.01),('Z',)]),col=RED2 if sx<0 else RED)
    n=16; cmds=[]
    for i in range(n*2+1):
        a=i*math.pi/n; rr=r if i%2==0 else r*1.13
        x=cx+rr*math.cos(a); y=cy+rr*math.sin(a)
        cmds.append(('M' if i==0 else 'L',x,y))
    cmds.append(('Z',))
    ros=d.path(cmds)
    d.fill(ros,shader=d.lin(cx-r,cy-r,cx+r,cy+r,[(.4,.62,1),(.15,.35,.85)]))
    d.fill(ros,col=(.1,.25,.65),stroke=.003)
    d.oval(cx,cy,r*.7,r*.7,col=WHITE)
    d.oval(cx,cy,r*.7,r*.7,col=(1,.82,.3),stroke=.006)
    d.text('7',cx,cy+.002,.06,SYM)
    d.oval(cx-r*.35,cy-r*.5,r*.25,r*.13,col=WHITE,a=.6)

# 6. over30 — crown
def over30(d,t=0):
    L,R=.414,.586
    crown=d.path([('M',L,.133),('Q',.5,.093,R,.133),('L',.60,.05),('L',.555,.085),('L',.5,.025),('L',.445,.085),('L',.40,.05),('Z',)])
    d.fill(crown,shader=d.lin(.42,.03,.58,.13,GOLD))
    d.fill(crown,col=GOLDLINE,stroke=.005)
    d.fill(d.path([('M',.417,.118),('Q',.5,.078,.583,.118)]),col=GOLDLINE,a=.8,stroke=.004)
    for x,y in [(.40,.045),(.5,.02),(.60,.045)]:
        d.oval(x,y,.011,.011,col=WHITE); d.oval(x,y,.011,.011,col=(.75,.7,.65),stroke=.003)
    d.oval(.5,.083,.013,.016,col=RED); d.oval(.497,.078,.004,.005,col=WHITE,a=.9)
    for x,y in [(.45,.103),(.55,.103)]:
        d.oval(x,y,.009,.009,col=BLUE); d.oval(x-.002,y-.003,.003,.003,col=WHITE,a=.9)
    d.fill(d.path([('M',.43,.115),('L',.415,.07)]),col=WHITE,a=.55,stroke=.005)
    sparkle(d,.64,.03,.018,col=WHITE); sparkle(d,.36,.025,.013,col=(1,.95,.7))

# 7. personalBest — trophy on the ray
def personalBest(d,t=0):
    d.c.save(); k=1.3; d.c.translate(.5*d.s*(1-k),.30*d.s*(1-k)); d.c.scale(k,k)
    cx=.5; top=.255
    # handles
    for sx in (-1,1):
        h=d.path([('M',cx+sx*.045,top+.012),('C',cx+sx*.085,top+.005,cx+sx*.085,top+.06,cx+sx*.03,top+.07)])
        d.fill(h,col=GOLDLINE,stroke=.013); d.fill(h,col=(1,.85,.35),stroke=.007)
    cup=d.path([('M',cx-.052,top),('L',cx+.052,top),('Q',cx+.05,top+.075,cx+.012,top+.088),('L',cx+.01,top+.115),('L',cx-.01,top+.115),('L',cx-.012,top+.088),('Q',cx-.05,top+.075,cx-.052,top),('Z',)])
    d.fill(cup,shader=d.lin(cx-.05,top,cx+.05,top+.1,GOLD)); d.fill(cup,col=GOLDLINE,stroke=.004)
    d.oval(cx,top,.052,.009,col=(.8,.55,.1)); d.oval(cx,top,.052,.009,col=GOLDLINE,stroke=.003)
    # base
    d.fill(d.path([('M',cx-.03,top+.115),('L',cx+.03,top+.115),('L',cx+.036,top+.135),('L',cx-.036,top+.135),('Z',)]),shader=d.lin(cx,top+.11,cx,top+.135,GOLD))
    d.fill(d.path([('M',cx-.045,top+.135),('L',cx+.045,top+.135),('L',cx+.045,top+.162),('L',cx-.045,top+.162),('Z',)]),shader=d.lin(cx,top+.135,cx,top+.162,[(.25,.5,.95),(.12,.3,.7)]))
    d.text('PB',cx,top+.149,.022,WHITE)
    sparkle(d,cx,top+.042,.02,col=WHITE)
    d.fill(d.path([('M',cx-.036,top+.012),('Q',cx-.034,top+.05,cx-.016,top+.066)]),col=WHITE,a=.6,stroke=.006)
    # confetti
    import random; rnd=random.Random(7)
    for (x,y) in [(.33,.27),(.36,.38),(.66,.26),(.64,.40),(.30,.33),(.70,.33),(.42,.24),(.58,.235)]:
        c=rnd.choice([RED,BLUE,(1,.82,.3),(.3,.8,.6)]); a=rnd.uniform(0,math.pi)
        dx,dy=.009*math.cos(a),.009*math.sin(a)
        d.fill(d.path([('M',x-dx,y-dy),('L',x+dx,y+dy)]),col=c,stroke=.008)
    d.c.restore()

# 8. podWave — pod of rays all above the waterline
def podWave(d,t=0):
    water(d,.93,.008,3,bottom=.995,phase=0,alpha=.85)
    tints=[((.4,.82,.85),(.18,.6,.7),(.2,.55,.62)),
           ((.5,.68,1),(.25,.42,.85),(.22,.38,.75)),
           ((.5,.9,.72),(.2,.66,.52),(.18,.55,.45)),
           ((.8,.66,.98),(.55,.38,.85),(.48,.32,.72))]
    spots=[(.155,.60,.13),(.845,.56,.13),(.25,.79,.12),(.75,.78,.12)]
    for (x,y,w),(c1,c2,tc) in zip(spots,tints):
        baby_ray(d,x,y,w=w,h=w*.63,body=(c1,c2),tailc=tc,t=1.0)
    for x in (.16,.84,.5):
        d.fill(d.path([('M',x-.02,.905),('Q',x,.885,x+.02,.905)]),col=WHITE,a=.9,stroke=.004)

NEW=[('surge','Ripple','125% of goal',surge),('tide','Spring tide','150% of goal',tide),('flood','Flood tide','200% of goal',flood),
     ('over3','Extra mile','3 days over goal',over3),('over7','Week of extra','7 days over goal',over7),('over30','Month of extra','30 days over goal',over30),
     ('personalBest','Personal best','biggest day yet',personalBest),('podWave','Pod wave','whole pod over goal',podWave)]
