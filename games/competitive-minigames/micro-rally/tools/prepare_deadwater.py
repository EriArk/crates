#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Bake the authored county into a portable height field; no Godot required.
Input/layout data: ODbL-1.0, see assets/deadwater/NOTICE.txt.
"""
import json, math, struct
from PIL import Image, ImageDraw
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
plan=json.loads((ROOT/'docs/plans/deadwater-expanded/layout.json').read_text())
OUT=ROOT/'assets/deadwater'; OUT.mkdir(exist_ok=True)
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a))); return t*t*(3-2*t)
def mix(a,b,t): return [x+(y-x)*t for x,y in zip(a,b)]
def point(p): return [p[0]-450,p[2],p[1]-350]
nodes={k:point(p) for k,p in plan['nodes'].items()}
river=[[x-450,z-350] for x,z in plan['river']]
def projection(p,a,b):
    dx,dz=b[0]-a[0],b[-1]-a[-1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[-1]-a[-1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-dx*t,p[-1]-a[-1]-dz*t),t
def water_distance(p): return min(projection(p,a,b)[0] for a,b in zip(river,river[1:]))
roads=[]
for r in plan['roads']:
    pts=[nodes[k] for k in r['nodes']]; samples=[]
    for i in range(len(pts)-1):
        a,b=pts[i:i+2]; before=pts[max(0,i-1)]; after=pts[min(len(pts)-1,i+2)]
        # Catmull-Rom goes through each junction; branch endpoints share its height.
        count=max(1,math.ceil(math.dist(a,b)/4))
        for step in range(count):
            t=step/count
            if r['kind']=='bridge': p=mix(a,b,t)
            else:p=[.5*((2*a[c])+(-before[c]+b[c])*t+(2*before[c]-5*a[c]+4*b[c]-after[c])*t*t+(-before[c]+3*a[c]-3*b[c]+after[c])*t*t*t) for c in range(3)]
            samples.append([round(v,3) for v in p])
    samples.append(pts[-1])
    roads.append({'name':r['name'],'kind':r['kind'],'width':plan['widths_metres'][r['kind']],'points':samples})

# A continuous north-bank service track passes physically beneath three bridges.
# Offset normals keep it on dry land; a separate ramp at each end reaches town.
low=[]
for i,(a,b) in enumerate(zip(river,river[1:])):
    dx,dz=b[0]-a[0],b[1]-a[1]; length=math.hypot(dx,dz)
    for step in range(math.ceil(length/4)):
        p=mix(a,b,step/math.ceil(length/4)); p=[p[0]+dz/length*23,p[1]-dx/length*23]
        if -355<=p[0]<=300: low.append([round(p[0],3),1.0,round(p[1],3)])
# Round discontinuities at river bends with explicit connecting segments.
roads.append({'name':'Lower river service','kind':'lower','width':10,'points':low})
for name,a,b in [('West descent',nodes['W'],low[0]),('East descent',low[-1],nodes['H5'])]:
    roads.append({'name':name,'kind':'dirt','width':11,'points':[mix(a,b,i/40) for i in range(41)]})
bridges=[]
for road in roads:
    if road['kind']!='bridge':continue
    pts=road['points']; wet=[i for i,p in enumerate(pts) if water_distance(p)<54]
    first=max(0,min(wet)-2);last=min(len(pts)-1,max(wet)+2)
    a,b=pts[first],pts[last]
    # Exact flat top, approached on graded embankments. Lower road is kept clear.
    bridges.append({'a':a,'b':b,'width':road['width'],'name':road['name']})
    road['deck_range']=[first,last]

# Shallow maintained crossings prevent the river from trapping the last safe bank.
# They are distinct ground routes; the elevated bridges retain their upper decks.
for i,(a,b) in enumerate(zip(river,river[1:])):
    if i in [0,1,3,4,6]:
        center=mix(a,b,.5);dx,dz=b[0]-a[0],b[1]-a[1];ln=math.hypot(dx,dz);normal=[-dz/ln,dx/ln]
        pts=[]
        for j in range(-24,25):
            distance=j*4;pts.append([center[0]+normal[0]*distance,12*smooth(12,85,abs(distance)),center[1]+normal[1]*distance])
        roads.append({'name':'Shallow crossing '+str(i),'kind':'ford','width':13,'points':pts})

# An oblique bank ramp and a second western ford close the two late-zone detours.
ramp=[[0,1,32],[-70,6,70],nodes['B']]
points=[]
for a,b in zip(ramp,ramp[1:]):
    count=math.ceil(math.dist(a,b)/4)
    points.extend(mix(a,b,i/count) for i in range(count))
points.append(ramp[-1]);roads.append({'name':'Central bank ramp','kind':'dirt','width':11,'points':points})
a,b=river[1:3];center=mix(a,b,.85);dx,dz=b[0]-a[0],b[1]-a[1];ln=math.hypot(dx,dz);normal=[-dz/ln,dx/ln]
roads.append({'name':'West lower crossing','kind':'ford','width':20,'points':[[center[0]+normal[0]*j*4,12*smooth(12,85,abs(j*4)),center[1]+normal[1]*j*4] for j in range(-24,25)]})

a=[-24.5,2.75,45.3];b=nodes['C']
roads.append({'name':'Town bank exit','kind':'dirt','width':12,'grade_priority':True,'points':[mix(a,b,i/20) for i in range(21)]})

# Spatial bins bound height queries independently of the total road count.
segments=[]; bins={}
for road in roads:
    for i,(a,b) in enumerate(zip(road['points'],road['points'][1:])):
        if road['kind']=='bridge' and road['deck_range'][0]<=i<road['deck_range'][1]:continue
        idx=len(segments);segments.append((a,b,road['width']/2,road['kind']))
        for x in range(math.floor((min(a[0],b[0])-30)/32),math.floor((max(a[0],b[0])+30)/32)+1):
            for z in range(math.floor((min(a[2],b[2])-30)/32),math.floor((max(a[2],b[2])+30)/32)+1):bins.setdefault((x,z),[]).append(idx)
def height(x,z):
    dist=water_distance([x,z])
    h=12+23*(1-smooth(-220,-35,z))+15*smooth(180,350,z)
    h+=(2*math.sin(x*.018)*math.sin(z*.016))*smooth(65,140,dist)
    h*=smooth(20,95,dist)
    best=None
    for idx in bins.get((math.floor(x/32),math.floor(z/32)),[]):
        a,b,w,kind=segments[idx]; d,t=projection([x,z],a,b)
        # Signed distance keeps overlapping shoulders from snapping to the first road.
        score=d-w
        if best is None or score<best[0]: best=(score,a[1]+(b[1]-a[1])*t,w,d,kind)
    if best and best[0]<18:
        h=h+(best[1]-h)*(1-smooth(2,18,best[0]))
    # An authored graded connection takes precedence through its full tyre lane.
    # Blend the surrounding shoulder, not the centreline, into crossing terrain.
    for road in roads:
        if not road.get('grade_priority'):continue
        a,b=road['points'][0],road['points'][-1];distance,t=projection([x,z],a,b)
        weight=1-smooth(road['width']/2,road['width']/2+10,distance)
        h+=(a[1]+(b[1]-a[1])*t-h)*weight
    return h
origin=[-482,-382]; step=4;nx=242;nz=192
heights=[height(origin[0]+x*step,origin[1]+z*step) for z in range(nz) for x in range(nx)]
(OUT/'terrain.f32').write_bytes(struct.pack('<'+'f'*len(heights),*heights))
def sample(x,z):
    fx=(x-origin[0])/step;fz=(z-origin[1])/step;ix=max(0,min(nx-2,int(fx)));iz=max(0,min(nz-2,int(fz)));u=max(0,min(1,fx-ix));v=max(0,min(1,fz-iz))
    a=heights[iz*nx+ix];b=heights[iz*nx+ix+1];c=heights[(iz+1)*nx+ix+1];d=heights[(iz+1)*nx+ix]
    return a+(b-a)*u+(c-b)*v if u>=v else a+(c-d)*u+(d-a)*v

def near_road(p):
    return min(projection(p,a,b)[0]-r['width']/2 for r in roads for a,b in zip(r['points'],r['points'][1:]))
buildings=[]
for ri,r in enumerate(roads):
    if r['kind'] not in ['main','residential']:continue
    spacing=22 if r['kind']=='main' else 42
    for i in range(5,len(r['points'])-5,max(1,spacing//4)):
        a=r['points'][i];b=r['points'][i+1];dx,dz=b[0]-a[0],b[2]-a[2];ln=math.hypot(dx,dz)
        if ln<.01:continue
        for side in [-1,1]:
            p=[a[0]-dz/ln*27*side,0,a[2]+dx/ln*27*side]
            if abs(p[0])>425 or abs(p[2])>325 or water_distance(p)<35:continue
            if near_road(p)<17 or any(math.dist(p[::2],q['position'][::2])<38 for q in buildings):continue
            kind='shop' if r['kind']=='main' else 'warehouse' if p[2]>95 and p[0]>40 else 'house'
            w,d,h=([15,15,9] if kind=='shop' else [22,18,8] if kind=='warehouse' else [12,14,7])
            yaw=math.atan2(dx,dz)+math.pi/2
            p[1]=sample(p[0],p[2]);buildings.append({'position':p,'size':[w,h,d],'yaw':yaw,'kind':kind,'variant':(i+ri)%4})
data={'revision':2,'bounds':[-450,-350,900,700],'terrain':{'origin':origin,'step':step,'nx':nx,'nz':nz},'roads':roads,'bridges':bridges,'river':river,'buildings':buildings,'nodes':nodes,'spawns':[nodes[n] for n in plan['spawns']],
      'finals':[nodes[n] for n in ['N1','N3','S3','Q1']], 'source':'Authored adaptation of Idaho Springs; ODbL-1.0; see NOTICE.txt'}
(OUT/'county.json').write_text(json.dumps(data,separators=(',',':'))+'\n',newline='\n')
# Project paint onto the SAME terrain triangles: overlay meshes can intersect
# curved height fields and expose cracks even when their vertices are above them.
scale=2
paint=Image.new('RGB',((nx-1)*step*scale,(nz-1)*step*scale),(0,0,0));draw=ImageDraw.Draw(paint)
def pixel(p): return ((p[0]-origin[0])*scale,(p[2]-origin[1])*scale)
for road in sorted(roads,key=lambda r:0 if r['kind'] in ['dirt','lower','ford'] else 1):
    color=(0,255,0) if road['kind'] in ['dirt','lower','ford'] else (255,0,0)
    width=round(road['width']*scale)
    for i,(a,b) in enumerate(zip(road['points'],road['points'][1:])):
        if road['kind']=='bridge' and road['deck_range'][0]<=i<road['deck_range'][1]: continue
        draw.line([pixel(a),pixel(b)],fill=color,width=width)
        x,z=pixel(a);draw.ellipse((x-width/2,z-width/2,x+width/2,z+width/2),fill=color)
paint.save(OUT/'road-mask.png')
(OUT/'NOTICE.txt').write_text('Deadwater County map data\nCopyright OpenStreetMap contributors and TrainerOS contributors.\nODbL 1.0: https://opendatacommons.org/licenses/odbl/1-0/\nhttps://www.openstreetmap.org/copyright\nAuthored adaptation informed by Idaho Springs, not a geographic replica.\nSource and modifications: docs/plans/deadwater-expanded and tools/prepare_deadwater.py in https://github.com/EriArk/crates\nOriginal generated geometry code remains GPL-3.0-or-later.\n')
print(json.dumps({'terrain_vertices':nx*nz,'roads':len(roads),'bridges':len(bridges),'buildings':len(buildings)}))
