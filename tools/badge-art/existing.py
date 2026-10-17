from draw import *
T=0.6
def bubbles(d,t=T):
    for i in range(7):
        ph=(t*0.35+i/7)%1
        x=0.56+0.05*math.sin(ph*9+i)+(i%2)*0.03; y=0.86-ph*0.8
        r=(0.008+0.012*(i%3))*(0.6+ph*0.6)
        d.oval(x,y,r,r,col=WHITE,a=0.85*(1-ph),stroke=0.004)
        d.oval(x-r*0.15,y-r*0.15,r*0.45,r*0.45,col=WHITE,a=0.7*(1-ph))
def headband(d,t=T):
    d.fill(d.path([('M',.417,.110),('Q',.5,.07,.583,.110),('L',.586,.133),('Q',.5,.093,.414,.133),('Z',)]),col=(.95,.25,.35))
    d.fill(d.path([('M',.421,.122),('Q',.5,.082,.579,.122)]),col=WHITE,a=.9,stroke=.006)
    fl=math.sin(t*6)*0.01
    d.fill(d.path([('M',.417,.120),('L',.378,.105+fl),('L',.385,.130+fl),('Z',),('M',.417,.125),('L',.381,.150-fl),('L',.392,.160-fl),('Z',)]),col=(.85,.18,.3))
def medal(d,t=T):
    d.fill(d.path([('M',.455,.235),('L',.49,.36),('L',.51,.36),('L',.545,.235),('L',.525,.235),('L',.5,.33),('L',.475,.235),('Z',)]),col=(.2,.45,.95))
    cx,cy,r=.5,.385,.042
    d.oval(cx,cy,r,r,shader=d.lin(cx-r,cy-r,cx+r,cy+r,[(1,.88,.4),(.85,.6,.1)]))
    d.oval(cx,cy,r,r,col=(.7,.48,.05),stroke=.004)
    sh=.5+.5*math.sin(t*2)
    d.oval(cx-r*.3,cy-r*.425,r*.25,r*.175,col=WHITE,a=.4+.4*sh)
def baby_ray(d,cx,cy,w=.15,h=.095,t=T,body=((.4,.82,.85),(.18,.6,.7)),tailc=(.2,.55,.62)):
    tail=d.path([('M',cx,cy+h*.45),('Q',cx-.015,cy+h,cx+.012*math.sin(t*3),cy+h*1.5)])
    d.fill(tail,col=tailc,stroke=.006)
    b=d.path([('M',cx,cy-h*.55),('Q',cx+w*.42,cy-h*.45,cx+w/2,cy),('Q',cx+w*.2,cy+h*.45,cx,cy+h*.5),('Q',cx-w*.2,cy+h*.45,cx-w/2,cy),('Q',cx-w*.42,cy-h*.45,cx,cy-h*.55),('Z',)])
    d.fill(b,shader=d.lin(cx,cy-h/2,cx,cy+h/2,list(body)))
    k=w/.15
    for ex in (-.018*k,.018*k):
        er=.008*k
        d.oval(ex+cx,cy-h*.18,er,er,col=(.08,.1,.15))
        d.oval(ex+cx+er*.1,cy-h*.18-er*.4,er*.3,er*.3,col=WHITE)
    d.fill(d.path([('M',cx-.012*k,cy-h*.02),('Q',cx,cy+h*.12,cx+.012*k,cy-h*.02)]),col=(.08,.12,.18),stroke=.004)
def baby(d,t=T):
    bob=math.sin(t*2.2)*.012
    baby_ray(d,.8+math.sin(t*.7)*.02,.66+bob,t=t)
EXISTING=[('bubbles','Bubble trail',bubbles),('headband','Run-day headband',headband),('medal','Race medal',medal),('baby','Baby ray buddy',baby)]
