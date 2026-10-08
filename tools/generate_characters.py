"""Original integer-grid modular sprites. Regenerate with Python; no image inputs."""
from pathlib import Path
import math
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/characters"
OUT.mkdir(exist_ok=True)
W, H = 48, 80
DIRECTIONS = ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"]
CLIPS = {"idle": 1, "walk": 8, "talk": 6, "interact": 6, "sit": 1, "sleep": 1}
SKINS = ["e9bc94", "ebc5a2", "e0b59a", "d5a27d"]
OUTFITS = {
    "sage": ("738f87", "35474b", "352e2b", "e4dcc3"),
    "ochre": ("c68a59", "35474b", "352e2b", "e4dcc3"),
    "landlord": ("665577", "454350", "352e2b", "e1d9c6"),
    "neighbour": ("9f6859", "40464a", "352e2b", "e1d9c6"),
    "navy": ("3d5267", "9f865f", "352e2b", "814a4b"),
}

def shade(color, factor):
    return "".join(f"{max(0,min(255,round(int(color[i:i+2],16)*factor))):02x}" for i in (0,2,4))

class Pixels:
    def __init__(self): self.p = {}
    def rect(self,x,y,w,h,c):
        for yy in range(round(y), round(y+h)):
            for xx in range(round(x), round(x+w)):
                if 0<=xx<W and 0<=yy<H: self.p[xx,yy]=c
    def ellipse(self,x,y,rx,ry,c):
        for yy in range(math.floor(y-ry),math.ceil(y+ry)+1):
            for xx in range(math.floor(x-rx),math.ceil(x+rx)+1):
                if ((xx-x)/rx)**2+((yy-y)/ry)**2<=1: self.rect(xx,yy,1,1,c)
    def line(self,a,b,width,c):
        n=max(abs(round(b[0]-a[0])),abs(round(b[1]-a[1])),1)
        for i in range(n+1):
            x=a[0]+(b[0]-a[0])*i/n; y=a[1]+(b[1]-a[1])*i/n
            self.ellipse(round(x),round(y),max(1,width/2),max(1,width/2),c)
    def svg(self,ox,oy):
        result=[]
        for y in range(H):
            x=0
            while x<W:
                c=self.p.get((x,y)); start=x; x+=1
                if c is None: continue
                while x<W and self.p.get((x,y))==c: x+=1
                result.append(f'<rect x="{ox+start}" y="{oy+y}" width="{x-start}" height="1" fill="#{c}"/>')
        return "".join(result)

BOB=[0,1,0,-1,0,1,0,-1]

def body(outfit,skin,direction,clip,frame):
    p=Pixels(); coat,trouser,shoe,shirt=OUTFITS[outfit]
    angle=direction*math.pi/4; dx,dy=math.cos(angle),math.sin(angle)
    side=abs(dx)>.8; back=dy<-.1
    bob=BOB[frame] if clip=="walk" else (1 if clip in ("talk","interact") and frame in (2,5) else 0)
    hip=(24,49+bob); shoulder_y=27+bob
    if clip=="sit": hip=(24,49); shoulder_y=30
    # Far limbs first, near limbs last. Direction is a real projected gait, not mirroring.
    for leg in [-1,1]:
        phase=frame*math.tau/8+(math.pi if leg==-1 else 0)
        stride=math.cos(phase)*7 if clip=="walk" else 0
        lift=max(0,math.sin(phase))*4 if clip=="walk" else 0
        spread=leg*(2 if side else 4)
        x=24+spread+dx*stride; y=73+dy*stride*.35-lift
        if clip=="sit": x=24+spread+dx*8; y=68+dy*4
        knee=(24+spread+dx*stride*.45,61-lift*.6)
        col=shade(trouser,.76 if leg==-1 else 1)
        p.line((24+spread,hip[1]),knee,6,shade(col,.75))
        p.line(knee,(x,y-3),6,shade(col,.75))
        p.line((24+spread,hip[1]),knee,4,col)
        p.line(knee,(x,y-3),4,shade(col,1.1))
        p.ellipse(x+dx*2,y,4,2,shade(shoe,.75));p.rect(x-3,y-1,7,2,shoe)
    width=12 if side else (17 if abs(dy)>.8 else 15)
    left=24-width/2
    p.rect(left-1,shoulder_y,width+2,23,shade(coat,.65))
    p.rect(left,shoulder_y+1,width,21,coat)
    p.rect(left+1,shoulder_y+3,3,17,shade(coat,1.13))
    p.rect(left+width-3,shoulder_y+3,2,18,shade(coat,.8))
    p.rect(left,shoulder_y+20,width,3,shade(coat,.82))
    p.rect(21,shoulder_y-3,6,4,skin)
    if not back:
        center=24+dx*3
        p.rect(center-3,shoulder_y,6,10,shirt)
        p.rect(center-2,shoulder_y+1,4,7,shade(shirt,1.08))
        p.line((center-4,shoulder_y),(center-2,shoulder_y+7),2,shade(coat,.75))
        p.line((center+4,shoulder_y),(center+2,shoulder_y+7),2,shade(coat,.75))
        for y in [39,44]: p.rect(center, y+bob,1,1,"d8c7a1")
        if outfit=="landlord": p.rect(center-1,shoulder_y+2,2,8,"7c4541")
        if outfit=="navy":
            p.rect(left+2,43+bob,4,3,shade(coat,.7));p.rect(left+width-6,43+bob,4,3,shade(coat,.7))
    # Arms use jointed silhouettes, with different talk and work gestures.
    for arm in [-1,1]:
        ax=24+arm*(width/2+1)
        elbow=(ax+arm,38+bob); hand=(ax,48+bob)
        if clip=="walk":
            swing=-math.cos(frame*math.tau/8)*arm*6
            elbow=(ax+dx*swing*.5,38+bob+dy*swing*.25)
            hand=(ax+dx*swing,47+bob+dy*swing*.5)
        elif clip=="talk":
            gestures=[(0,0),(5,-6),(8,-12),(4,-7),(0,-3),(-2,-7)]
            gx,gy=gestures[(frame+(3 if arm==-1 else 0))%6]
            elbow=(ax+arm*3,37+bob+gy*.35)
            hand=(ax+arm*gx+dx*2,47+bob+gy)
        elif clip=="interact":
            reach=[0,3,6,6,3,0][frame]
            elbow=(ax+dx*4,37+bob)
            hand=(ax+dx*(7+reach),41+bob+dy*reach*.5)
        col=shade(coat,.85 if arm==-1 else 1)
        p.line((ax,29+bob),elbow,5,shade(coat,.65));p.line(elbow,hand,5,shade(coat,.65))
        p.line((ax,29+bob),elbow,3,col);p.line(elbow,hand,3,col)
        p.ellipse(hand[0],hand[1],2,2,shade(skin,.8));p.rect(hand[0]-1,hand[1]-1,3,3,skin)
    return p

def head(person,direction,expression):
    p=Pixels();skin=SKINS[person-1]
    hair=["473831","8d4c39","b9b1a7","665950"][person-1]
    dx=round(math.cos(direction*math.pi/4));dy=round(math.sin(direction*math.pi/4))
    side=direction in (0,4);back=direction in (5,6,7)
    cx=24+dx;cy=14
    p.ellipse(cx,cy,7 if side else 8,9,shade(skin,.7))
    p.ellipse(cx,cy,6 if side else 7,8,skin)
    p.rect(cx-4,cy+3,8,6,skin)
    p.ellipse(cx-1,cy-5,8,6,shade(hair,.75))
    p.ellipse(cx-1,cy-6,7,5,hair)
    p.rect(cx-6,cy-8,4,3,shade(hair,1.12))
    if back:
        p.ellipse(cx,cy+1,7,8,hair)
        p.rect(cx-5,cy+4,10,3,shade(hair,.8))
        p.rect(cx-4,cy-3,3,5,shade(hair,1.1))
        if dx: p.rect(cx+dx*6,cy+2,2,4,shade(skin,.85))
    else:
        p.rect(cx-7,cy-4,3,9,hair)
        if person==2: p.rect(cx+5,cy-3,3,11,hair);p.rect(cx-8,cy,3,9,hair)
        if person==3: p.rect(cx-5,cy-7,8,3,skin) # receding silver hair
        if person==4: p.ellipse(cx-5,cy-4,4,5,hair)
        nose_x=cx+dx*6
        if side: p.rect(nose_x,cy,3 if dx>0 else -0+2,3,shade(skin,1.07))
        eyes=[cx+dx*3] if side else [cx-3+dx,cx+3+dx]
        for x in eyes:
            p.rect(x,cy-2,2,1,shade(hair,.65))
            p.rect(x,cy,1,1 if expression==1 else 2,"39312f")
        p.rect(cx+dx*3-2,cy+5,3,1,"986657")
        if expression in (2,3): p.rect(cx+dx*3-1,cy+5,2,2 if expression==2 else 1,"633d36")
        if person==3: p.rect(cx-3,cy+4,5,1,shade(hair,.8))
    return p

def atlas(path,columns,frames,draw):
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{W*columns}" height="{H*8}" viewBox="0 0 {W*columns} {H*8}" shape-rendering="crispEdges">']
    for d in range(8):
        for f in range(frames): parts.append(draw(d,f).svg(f*W,d*H))
    parts.append('</svg>');path.write_text("".join(parts))

if __name__=="__main__":
    for person in range(1,5):
        atlas(OUT/f"head_{person}.svg",4,4,lambda d,f:head(person,d,f))
        for outfit in OUTFITS:
            for clip,frames in CLIPS.items():
                atlas(OUT/f"body_{outfit}_{person}_{clip}.svg",8,frames,lambda d,f:body(outfit,SKINS[person-1],d,clip,f))
    (OUT/"manifest.json").write_text(json.dumps({"cell":[W,H],"directions":DIRECTIONS,"clips":CLIPS,"outfits":list(OUTFITS),"characters":{"person.newcomer_a":{"head":1,"outfit":"sage"},"person.newcomer_b":{"head":2,"outfit":"ochre"},"person.landlord":{"head":3,"outfit":"landlord"},"person.neighbour":{"head":4,"outfit":"neighbour"}},"bob":BOB},indent=2)+"\n")
    print("Generated 4 heads, 5 outfits in 4 skin palettes, 8 directions and 6 clips")
