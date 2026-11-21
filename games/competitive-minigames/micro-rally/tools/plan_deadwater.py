#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline design drawing and graph estimates. Does not alter the playable map.

Requires Pillow. Reads the retained OSM reference and authored layout; writes
reviewable PNGs and route metrics beside them. Distances are planning estimates.
"""
from pathlib import Path
import heapq
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / 'docs/plans/deadwater-expanded'
layout = json.loads((ROOT / 'layout.json').read_text())
nodes = layout['nodes']
edges = [(a, b, r['kind']) for r in layout['roads'] for a, b in zip(r['nodes'], r['nodes'][1:])]

def length(a, b):
    return math.dist(nodes[a], nodes[b])

def distances(start, blocked=None):
    result = {start: 0.0}
    queue = [(0.0, start)]
    while queue:
        distance, node = heapq.heappop(queue)
        if distance > result[node]:
            continue
        for a, b, _ in edges:
            if frozenset((a, b)) == blocked:
                continue
            nxt = b if a == node else a if b == node else None
            if nxt is not None:
                candidate = distance + length(a, b)
                if candidate < result.get(nxt, math.inf):
                    result[nxt] = candidate
                    heapq.heappush(queue, (candidate, nxt))
    return result

all_distances = {n: distances(n) for n in nodes}
connected = all(len(d) == len(nodes) for d in all_distances.values())
bridges = [(a, b) for a, b, kind in edges if kind == 'bridge']
bridge_redundancy = {f'{a}-{b}': len(distances('W', frozenset((a, b)))) == len(nodes) for a, b in bridges}
grades = [abs(nodes[a][2] - nodes[b][2]) / math.dist(nodes[a][:2], nodes[b][:2]) for a, b, _ in edges]
spawn_separation = min(math.dist(nodes[a][:2], nodes[b][:2]) for i, a in enumerate(layout['spawns']) for b in layout['spawns'][i+1:])
longest = max((d, a, b) for a, values in all_distances.items() for b, d in values.items())
routes = [('W', 'F'), ('N0', 'Q4'), ('N7', 'Q0'), ('B', 'S3')]
metrics = {
    'status': 'design graph only; no driving, collisions or storm clipping simulated',
    'area_m2': 900 * 700, 'area_ratio_to_current': round(900 * 700 / (360 * 360), 3),
    'nodes': len(nodes), 'edges': len(edges), 'connected': connected,
    'connected_after_removing_each_bridge': bridge_redundancy,
    'max_endpoint_grade_percent': round(max(grades) * 100, 2),
    'minimum_spawn_separation_m': round(spawn_separation, 1),
    'longest_shortest_route_m': round(longest[0], 1), 'longest_route_endpoints': longest[1:],
    'route_estimates': [{'from': a, 'to': b, 'metres': round(all_distances[a][b], 1),
                        'seconds_at_10_to_18_mps': [round(all_distances[a][b] / 18), round(all_distances[a][b] / 10)]} for a, b in routes]
}
assert connected and all(bridge_redundancy.values())
assert len(set(layout['spawns'])) == 16 and spawn_separation >= 65
assert max(grades) <= .12
(ROOT / 'route-estimates.json').write_text(json.dumps(metrics, indent=2) + '\n')

def font(size, bold=False):
    for path in [('C:/Windows/Fonts/arialbd.ttf' if bold else 'C:/Windows/Fonts/arial.ttf'),
                 ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)

im = Image.new('RGB', (1680, 1130), '#12242b')
draw = ImageDraw.Draw(im)
scale = 1.48
def xy(p):
    return (35 + p[0] * scale, 70 + p[1] * scale)
def text(pos, value, size=19, fill='#f4ecd8', bold=False):
    draw.text(pos, value, font=font(size, bold), fill=fill, stroke_width=2, stroke_fill='#12242b')

draw.rectangle([xy((0, 0)), xy((900, 700))], fill='#496749', outline='#b7bea3', width=2)
# Broad land-use masses, not measured contour lines.
draw.polygon([xy(p) for p in [(0,0),(900,0),(900,260),(600,240),(410,260),(260,220),(0,260)]], fill='#314f3c')
draw.polygon([xy(p) for p in [(0,565),(300,540),(540,590),(550,700),(0,700)]], fill='#806448')
draw.polygon([xy(p) for p in [(490,445),(900,440),(900,700),(550,700)]], fill='#63634d')
draw.ellipse([xy((700,15)),xy((790,90))],fill='#3c8da8',outline='#80c3c9',width=3)
draw.line([xy(p) for p in layout['river']], fill='#233f40', width=34)
draw.line([xy(p) for p in layout['river']], fill='#4fa4b9', width=23)
palette={'main':'#d9c497','residential':'#aeb1a4','dirt':'#b88b54','bridge':'#f2db89'}
for a,b,kind in edges:
    points=[xy(nodes[a]),xy(nodes[b])]
    w=round(layout['widths_metres'][kind]*scale)
    draw.line(points,fill='#263b36',width=w+6)
    draw.line(points,fill=palette[kind],width=w)

def dist_segment(p, a, b):
    dx,dz=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-dx*t,p[1]-a[1]-dz*t)

# Proposed block frontage, varying roof types; these are not OSM building copies.
buildings=[]
for road in layout['roads']:
    if road['kind'] not in ['main','residential'] or 'bridge' in road['name'].lower():
        continue
    for na,nb in zip(road['nodes'],road['nodes'][1:]):
        a,b=nodes[na],nodes[nb]; dx,dz=b[0]-a[0],b[1]-a[1]; span=math.hypot(dx,dz)
        ux,uz=dx/span,dz/span
        for step in range(25,int(span)-15,20 if road['kind']=='main' else 34):
            for side in [-1,1]:
                p=(a[0]+ux*step-uz*24*side,a[1]+uz*step+ux*24*side)
                if any(dist_segment(p,nodes[c],nodes[d])<layout['widths_metres'][k]/2+10 for c,d,k in edges): continue
                if any(math.dist(p,q)<18 for q in buildings): continue
                if any(dist_segment(p,c,d)<23 for c,d in zip(layout['river'],layout['river'][1:])): continue
                buildings.append(p)
                shape=[xy((p[0]+ux*s+uz*t,p[1]+uz*s-ux*t)) for s,t in [(-8,-6),(8,-6),(8,6),(-8,6)]]
                color='#c77c50' if road['kind']=='main' else '#d2b576'
                draw.polygon(shape,fill=color,outline='#312f28',width=2)

for i,n in enumerate(layout['spawns']):
    px,py=xy(nodes[n]);draw.ellipse((px-13,py-13,px+13,py+13),fill='#1c7181',outline='#b9eff2',width=2)
    draw.text((px,py),str(i+1),anchor='mm',font=font(15,True),fill='white')
for i,n in enumerate(layout['final_candidates']):
    px,py=xy(nodes[n]); draw.ellipse((px-25,py-25,px+25,py+25),outline='#f7c64e',width=3)
    text((px+25,py-24),'F'+str(i+1),17,fill='#ffda73',bold=True)
for district in layout['districts']:
    px,py=xy(district['center']);text((px-75,py-16),district['name'],21,bold=True)
    text((px-75,py+11),district['height'],17)

text((35,17),'DEADWATER COUNTY / EXPANSION PLAN',30,bold=True)
text((900,25),'900 × 700 m  |  DESIGN, NOT GAMEPLAY',19)
lx=1400
for y,title,lines in [
    (90,'STREET HIERARCHY',['Main street: 16 m','Local street: 11 m','Dirt bypass: 9 m','Bridges: 14 m']),
    (290,'READ THE MAP',['Blue dots: 16 starts','F1–F4: final areas','Brick: shop frontages','Tan: homes / garages']),
    (485,'LAYOUT RULES',['4 river crossings','Looped hill routes','Rear service alleys*','Bridge underpasses*']),
    (680,'NOT YET VERIFIED',['* Detailed next pass','Storm-safe routes','Driving / jump landings','Handheld performance']),
    (885,'SCALE',['N ↑','0              100 m'])]:
    text((lx,y),title,18,bold=True)
    for i,line in enumerate(lines):text((lx,y+35+i*27),line,17)
draw.line([(lx,1000),(lx+148,1000)],fill='#f4ecd8',width=4)
text((35,1100),'Authored adaptation informed by Idaho Springs / reference data: © OpenStreetMap contributors, ODbL',16)
im.save(ROOT/'layout.png')

# Separate geographic evidence: no invented roads or heights in this reference.
osm=json.loads((ROOT/'idaho-springs-reference.json').read_text(encoding='utf-8'))
im=Image.new('RGB',(1500,900),'#172625');draw=ImageDraw.Draw(im)
def geo(p):return ((p[0]+105.528)/.028*1400+50,830-(p[1]-39.737)/.013*740)
for e in osm['features']:
    t=e['tags'];points=[geo(p) for p in e['geometry']]
    if len(points)<2:continue
    if 'building' in t:draw.polygon(points,fill='#b3946a')
    elif 'waterway' in t:draw.line(points,fill='#5ab7d6',width=7)
    elif 'highway' in t:draw.line(points,fill='#71827b' if t['highway'] not in ['path','footway','cycleway'] else '#365642',width=3)
for name in ['Miner Street','Colorado Boulevard','Virginia Canyon Road','Riverside Drive','High Street']:
    es=[e for e in osm['features'] if e['tags'].get('name')==name]
    if es:
        e=max(es,key=lambda v:len(v['geometry']));px,py=geo(e['geometry'][len(e['geometry'])//2]);text((min(px,1250),py),name,18)
text((30,20),'IDAHO SPRINGS / GEOGRAPHIC REFERENCE / NORTH UP',26,bold=True)
text((30,865),'Map data © OpenStreetMap contributors / ODbL / openstreetmap.org/copyright',18)
im.save(ROOT/'reference.png')
print(json.dumps(metrics,indent=2))
