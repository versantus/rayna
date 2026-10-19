import skia, math, os
S = 512
# Nunito variable font. Override with RAYNA_FONT on a machine that keeps it elsewhere.
FONT = os.environ.get(
    'RAYNA_FONT',
    '/usr/share/fonts/truetype/sand-box/google/Nunito/Nunito-VariableFont_wght.ttf',
)
def C(r,g,b,a=1.0): return skia.Color4f(r,g,b,a).toColor()
WHITE=(1,1,1)
class D:
    def __init__(self, canvas, s=S):
        self.c=canvas; self.s=s
    def P(self,x,y): return skia.Point(x*self.s,y*self.s)
    def paint(self, col=None, a=1.0, stroke=None, shader=None):
        p=skia.Paint(AntiAlias=True)
        if shader is not None: p.setShader(shader)
        else: p.setColor(C(*col,a))
        if stroke is not None:
            p.setStyle(skia.Paint.kStroke_Style); p.setStrokeWidth(max(1,stroke*self.s)); p.setStrokeCap(skia.Paint.kRound_Cap); p.setStrokeJoin(skia.Paint.kRound_Join)
        return p
    def lin(self, x0,y0,x1,y1, cols):
        return skia.GradientShader.MakeLinear([self.P(x0,y0),self.P(x1,y1)],[C(*c) for c in cols])
    def path(self, cmds):
        p=skia.Path()
        for c in cmds:
            op=c[0]; pts=[self.P(*c[i:i+2]) for i in range(1,len(c),2)]
            if op=='M': p.moveTo(pts[0])
            elif op=='L': p.lineTo(pts[0])
            elif op=='Q': p.quadTo(pts[0],pts[1])   # control, end
            elif op=='C': p.cubicTo(pts[0],pts[1],pts[2])
            elif op=='Z': p.close()
        return p
    def oval(self,cx,cy,rx,ry,**kw):
        self.c.drawOval(skia.Rect.MakeLTRB((cx-rx)*self.s,(cy-ry)*self.s,(cx+rx)*self.s,(cy+ry)*self.s), self.paint(**kw))
    def fill(self,path,**kw): self.c.drawPath(path,self.paint(**kw))
    def text(self,t,cx,cy,size,col,a=1,weight=900):
        tf=skia.Typeface.MakeFromFile(FONT)
        try:
            fm=skia.FontMgr.RefDefault(); 
        except Exception: pass
        f=skia.Font(tf,size*self.s); f.setEmbolden(True)
        w=f.measureText(t); m=f.getMetrics()
        self.c.drawString(t,cx*self.s-w/2,cy*self.s-(m.fAscent+m.fDescent)/2,f,self.paint(col,a))

def render(fn, bg=None, out=None, s=S):
    surf=skia.Surface(s,s); cv=surf.getCanvas(); cv.clear(skia.ColorTRANSPARENT)
    if bg:
        img=skia.Image.open(bg); cv.drawImageRect(img, skia.Rect.MakeWH(s,s), skia.SamplingOptions(skia.FilterMode.kLinear, skia.MipmapMode.kLinear))
    fn(D(cv,s))
    if out: surf.makeImageSnapshot().save(out, skia.kPNG)
    return surf
