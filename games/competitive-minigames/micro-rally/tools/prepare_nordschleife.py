#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Bake the ordered OSM circuit and Mapzen HGT elevation into a portable data asset.
Run on server: --cache research/nordschleife --output <staging>/assets/nordschleife.
Input ordered.json is the connected clockwise chain of 53 OSM ways starting T13.
The generated geographic database is ODbL, separately from this GPL tool.
"""
import argparse, json, math, pathlib, struct, hashlib
p=argparse.ArgumentParser();p.add_argument('--cache',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
ways=json.loads((a.cache/'ordered.json').read_text());assert len(ways)==53
assert all(w['nodes'][-1]==ways[(i+1)%len(ways)]['nodes'][0] for i,w in enumerate(ways))
origin=ways[0]['geometry'][0];lat0=origin['lat'];lon0=origin['lon'];mx=111195.08*math.cos(math.radians(lat0));mz=111195.08
raw=[];marks=[]
for w in ways:
 marks.append((len(raw),w['tags'].get('name',''),w['id']))
 for q in w['geometry'][:-1]:raw.append(((q['lon']-lon0)*mx,-(q['lat']-lat0)*mz))
# Centripetal Catmull-Rom keeps the mapped corner order without uniform-spline overshoot.
def curve(i,t):
 q=[raw[(i+j)%len(raw)] for j in [-1,0,1,2]];ts=[0.0]
 for j in range(3):ts.append(ts[-1]+max(math.dist(q[j],q[j+1]),.001)**.5)
 at=ts[1]+t*(ts[2]-ts[1])
 def mix(x,y,l,h):return tuple(((h-at)*x[k]+(at-l)*y[k])/(h-l) for k in range(2))
 x=[mix(q[j],q[j+1],ts[j],ts[j+1]) for j in range(3)]
 y=[mix(x[j],x[j+1],ts[j],ts[j+2]) for j in range(2)]
 return mix(y[0],y[1],ts[1],ts[2])
dense=[];anchor_dist=[];dist=[0.0]
for i in range(len(raw)):
 anchor_dist.append(dist[-1])
 for j in range(max(3,math.ceil(math.dist(raw[i],raw[(i+1)%len(raw)])/2))):
  q=curve(i,j/max(3,math.ceil(math.dist(raw[i],raw[(i+1)%len(raw)])/2)))
  if dense:dist.append(dist[-1]+math.dist(dense[-1],q))
  dense.append(q)
dense.append(dense[0]);dist.append(dist[-1]+math.dist(dense[-2],dense[-1]));scale=20832/dist[-1]
tiles={}
for lon in [6,7]:
 path=a.cache/f'N50E00{lon}.hgt';b=path.read_bytes();n=math.isqrt(len(b)//2);assert n*n*2==len(b);tiles[lon]=(b,n)
def height(x,z):
 lat=lat0-z/mz;lon=lon0+x/mx;k=math.floor(lon);b,n=tiles[k];u=(lon-k)*(n-1);v=(51-lat)*(n-1);ix=int(u);iy=int(v);fx=u-ix;fy=v-iy
 def cell(xx,yy):return struct.unpack_from('>h',b,2*(yy*n+xx))[0]
 return (cell(ix,iy)*(1-fx)+cell(ix+1,iy)*fx)*(1-fy)+(cell(ix,iy+1)*(1-fx)+cell(ix+1,iy+1)*fx)*fy
route=[];cursor=0;count=4096
for i in range(count):
 d=i/count*dist[-1]
 while dist[cursor+1]<d:cursor+=1
 t=(d-dist[cursor])/(dist[cursor+1]-dist[cursor]);x,z=[dense[cursor][k]*(1-t)+dense[cursor+1][k]*t for k in range(2)]
 route.append([x*scale,height(x,z),z*scale])
heights=[sum(route[(i+j)%count][1]*(5-abs(j)) for j in range(-4,5))/25 for i in range(count)]
minimum=min(heights);maximum=max(heights)
for i in range(count):route[i][1]=heights[i]-minimum+20
sections=[];last=''
for index,name,way in marks:
 if not name or name==last or name=='Nürburgring Nordschleife':continue
 d=anchor_dist[index]*scale;sections.append({'name':name,'distance':round(d,2),'index':round(d/20832*count)%count,'way':way});last=name
banks=[]
for i,s in enumerate(sections):
 if s['name'] in ['Karussell','Mini-Karussell']:banks.append([s['distance'],sections[i+1]['distance'],.48 if s['name']=='Karussell' else .32])
step=64;ox=math.floor((min(q[0] for q in route)-256)/step)*step;oz=math.floor((min(q[2] for q in route)-256)/step)*step
nx=math.ceil((max(q[0] for q in route)+256-ox)/step)+1;nz=math.ceil((max(q[2] for q in route)+256-oz)/step)+1
values=[round(height((ox+x*step)/scale,(oz+z*step)/scale)-minimum+20,3) for z in range(nz) for x in range(nx)]
out={'attribution':'© OpenStreetMap contributors (ODbL); Terrain Tiles (Mapzen), Copernicus EU-DEM / USGS SRTM','license':'ODbL-1.0 for derived route database; elevation source terms in NOTICE.md','origin_wgs84':[lon0,lat0],'plan_scale':scale,'length_2d':20832,'raw_elevation_min':minimum,'raw_elevation_max':maximum,'route':[[round(v,4) for v in q] for q in route],'sections':sections,'banks':banks,'terrain':{'step':step,'origin':[ox,oz],'nx':nx,'nz':nz,'values':values},'sources':{'osm_sha256':hashlib.sha256((a.cache/'ordered.json').read_bytes()).hexdigest(),'dem':{f'N50E00{k}.hgt':hashlib.sha256(b).hexdigest() for k,(b,n) in tiles.items()}}}
(a.output/'circuit.json').write_text(json.dumps(out,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
(a.output/'osm-ways.json').write_bytes((a.cache/'ordered.json').read_bytes())
print(json.dumps({'points':count,'plan_scale':scale,'elevation_range':maximum-minimum,'banks':banks,'sections':[(s['name'],s['distance'],s['index']) for s in sections],'terrain_grid':[nx,nz]},ensure_ascii=False))
