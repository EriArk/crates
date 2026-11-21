#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the four original THREAD garments in each set, in SDK bind-pose metres."""
import json
import math
from collections import defaultdict
from pathlib import Path
import struct

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'outfits'
TAU = math.tau
SLOTS = ('Top', 'Bottom', 'Boots', 'Hat')
PALETTE = {
    'linen':'e4cda2', 'cream':'fff0ce', 'oat':'bba27f', 'pine':'24564b',
    'moss':'4f8463', 'fern':'81a37b', 'teal':'2c716f', 'saffron':'d69a48',
    'ink':'30334e', 'indigo':'464579', 'iris':'77659b', 'lilac':'b3a2cd',
    'wine':'813e50', 'brick':'b65f4e', 'plum':'5c3545', 'slate':'405455',
    'umber':'5e4237', 'hide':'96613f', 'tan':'c68a56', 'sole':'403432',
    'brass':'edbf68', 'silver':'dfdddd', 'gem':'58c5bf'
}


class Tailor:
    def __init__(self):
        self.slot = 'Top'
        self.parts = {slot: defaultdict(list) for slot in SLOTS}

    def surface(self, rows, material, wrap=True, caps=False):
        """Stitch a grid with shared smooth normals within each sewn panel."""
        vertices = [v for row in rows for v in row]
        count = len(rows[0])
        indices = []
        for j in range(len(rows)-1):
            for i in range(count if wrap else count-1):
                a = j*count+i
                b = j*count+(i+1)%count
                indices.extend((a,b,b+count,a,b+count,a+count))
        if caps:
            for row,reverse in [(0,True),(len(rows)-1,False)]:
                offset = row*count
                start = len(vertices)
                vertices.extend(vertices[offset:offset+count])
                for i in range(1,count-1):
                    tri = [start,start+i,start+i+1]
                    indices.extend(reversed(tri) if reverse else tri)
        normals = [[0.,0.,0.] for _ in vertices]
        for a,b,c in zip(indices[::3],indices[1::3],indices[2::3]):
            u = [vertices[b][k]-vertices[a][k] for k in range(3)]
            v = [vertices[c][k]-vertices[a][k] for k in range(3)]
            n = [u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            for idx in (a,b,c):
                for k in range(3):
                    normals[idx][k] += n[k]
        normals = [tuple(x/(math.hypot(*n) or 1) for x in n) for n in normals]
        self.parts[self.slot][material].append((vertices,normals,indices))

    def loft(self, rings, color, *, count=32, shape=1., folds=0., hem=None, arc=None, caps=True):
        # Each ring gives y, half-width, half-depth, and optional x/z centre.
        rows = []
        for j,(y,w,d,*offset) in enumerate(rings):
            x,z = offset or (0.,.009)
            row=[]
            for i in range(count if arc is None else count+1):
                a = TAU*i/count if arc is None else arc[0]+(arc[1]-arc[0])*i/count
                s,c = math.sin(a),math.cos(a)
                wave = 1+folds*math.cos(10*a+.15*j)
                row.append((x+w*math.copysign(abs(s)**shape,s)*wave,
                            y+(hem(a) if j==0 and hem else 0),
                            z+d*math.copysign(abs(c)**shape,c)*wave))
            rows.append(row)
        self.surface(rows,color,wrap=arc is None,caps=caps and arc is None)

    def band(self, rings, bottom, top, color, ease=.003, **options):
        """Cut facings and bindings from the same profile as the underlying cloth."""
        profile=[(*ring[:3],*(ring[3:] or (0.,.009))) for ring in rings]
        def at(y):
            for a,b in zip(profile,profile[1:]):
                if a[0]<=y<=b[0]:
                    blend=(y-a[0])/(b[0]-a[0])
                    w,d,x,z=[a[k]+(b[k]-a[k])*blend for k in range(1,5)]
                    return y,w+ease,d+ease,x,z
            raise ValueError(y)
        heights=[bottom]+[r[0] for r in profile if bottom<r[0]<top]+[top]
        self.loft([at(y) for y in heights],color,caps=False,**options)

    def cord(self, points, radius, color):
        rows=[]
        for i,p in enumerate(points):
            before,after=points[max(0,i-1)],points[min(len(points)-1,i+1)]
            tangent=unit(tuple(b-a for a,b in zip(before,after)))
            ref=(0,0,1) if abs(tangent[2])<.8 else (0,1,0)
            u=unit(cross(tangent,ref))
            v=cross(u,tangent)
            rows.append([tuple(p[k]+radius*(u[k]*math.sin(TAU*j/8)+v[k]*math.cos(TAU*j/8))
                               for k in range(3)) for j in range(8)])
        self.surface(rows,color,caps=True)

    def stone(self, x,y,z,w,h,d,color):
        self.loft([(y-h,.001,.001,x,z),(y-h*.15,w,d,x,z),
                   (y+h*.42,w*.74,d*.8,x,z),(y+h,.001,.001,x,z)],color,count=8)

    def pouch(self,x,y,z):
        self.loft([(y-.036,.030,.010,x,z),(y-.027,.043,.026,x,z),
                   (y+.024,.044,.026,x,z),(y+.034,.038,.019,x,z)],'hide',shape=.56)
        self.loft([(y-.003,.032,.028,x,z),(y+.014,.045,.029,x,z),
                   (y+.032,.044,.026,x,z)],'tan',shape=.55)
        self.stone(x,y+.005,z+.029,.006,.006,.003,'brass')


def unit(v):
    length=math.hypot(*v)
    return tuple(x/length for x in v)


def cross(a,b):
    return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])


def trousers(t,style):
    t.slot='Bottom'
    color={'traveller':'slate','mage':'ink','merchant':'plum'}[style]
    for side in (-1,1):
        def leg(y,w,d,x,z):
            return (y,w,d,side*x,z)
        roomy=1.16 if style=='merchant' else 1.
        rings=[leg(.068,.036,.039,.085,-.020),leg(.135,.046,.047,.080,-.022),
               leg(.205,.049,.053,.069,-.008),leg(.234,.044,.051,.065,-.003),
               leg(.28,.052*roomy,.064*roomy,.062,.008),leg(.35,.060*roomy,.071*roomy,.055,.01),
               leg(.411,.061,.082,.051,.008),leg(.461,.047,.067,.045,.012)]
        t.loft(rings,color,folds=.035)
    t.loft([(.398,.105,.082),(.43,.112,.087),(.48,.099,.087)],color)


def footwear(t,style):
    t.slot='Boots'
    leather,trim,height={'traveller':('hide','tan',.222),'mage':('indigo','lilac',.164),
                         'merchant':('umber','brick',.104)}[style]
    for side in (-1,1):
        def shoe(y,w,d,x,z):
            return (y,w,d,side*x,z)
        sole=[shoe(.001,.050,.089,.09,.025),shoe(.009,.054,.093,.09,.025),
              shoe(.017,.053,.092,.09,.025)]
        t.loft(sole,'sole',shape=.78)
        t.loft([sole[-1],shoe(.021,.053,.091,.09,.025)],'tan',shape=.78)
        upper=[shoe(.020,.052,.092,.09,.025),shoe(.031,.052,.092,.09,.025),
                shoe(.045,.050,.078,.089,.011),shoe(.063,.041,.058,.085,-.006),
                shoe(.078,.046,.053,.084,-.018)]
        # The boot follows the same angled calf as the breeches. Extra ease
        # around each section keeps the trouser leg inside even from behind.
        shaft=[(.103,.049,.056,.082,-.020),(.135,.055,.061,.080,-.021),
               (.165,.057,.063,.076,-.016),(.203,.059,.065,.070,-.009),
               (.222,.058,.065,.067,-.006)]
        for y,w,d,x,z in shaft:
            if y<height:upper.append(shoe(y,w,d,x,z))
        _,w,d,x,z=next(r for r in shaft if r[0]>=height or math.isclose(r[0],.222))
        upper.append(shoe(height,w+.001,d+.001,x,z))
        t.loft(upper,leather,shape=.85)
        t.band(upper,height-.018,height,trim,ease=.005,shape=.85)
        if style=='traveller':
            for y in (.096,.15):
                t.band(upper,y,y+.013,'umber',ease=.005,shape=.85)
                t.stone(side*.122,y+.006,.011,.007,.008,.004,'brass')
        elif style=='merchant':
            t.band(upper,.04,.05,'hide',ease=.003,shape=.85)
            t.stone(side*.09,.048,.084,.015,.008,.004,'brass')
        else:
            t.stone(side*.078,height-.014,.044,.01,.017,.006,'silver')


def sleeves(t,style):
    shade={'traveller':'moss','mage':'iris','merchant':'linen'}[style]
    trim={'traveller':'umber','mage':'ink','merchant':'brick'}[style]
    for side in (-1,1):
        def arm(y,w,d,x,z=0):
            return (y,w,d,x*side,z)
        cuff=.425 if style!='merchant' else .49
        rings=[arm(cuff,.034 if style!='mage' else .05,.036 if style!='mage' else .05,
                    .176 if cuff<.45 else .144),
                arm(.508,.038,.042,.137),arm(.55,.051,.05,.115),
                arm(.594,.052,.049,.091),arm(.637,.04,.047,.074),
                arm(.661,.026,.032,.066)]
        t.loft(rings,shade,folds=.024)
        t.band(rings,cuff,cuff+.025,trim,ease=.003,folds=.024)
        if style=='mage':
            t.band(rings,cuff+.005,cuff+.010,'silver',ease=.005,folds=.024)


def body(t,style):
    t.slot='Top'
    sleeves(t,style)
    base={'traveller':'teal','mage':'indigo','merchant':'wine'}[style]
    hem={'traveller':.352,'mage':.229,'merchant':.415}[style]
    width={'traveller':.139,'mage':.166,'merchant':.116}[style]
    rings=[(hem,width,.116),(min(hem+.035,.426),width-.008,.114),(.451,.113,.098),
           (.493,.092,.087),(.556,.098,.094),(.618,.116,.090),
           (.65,.098,.072),(.682,.055,.049)]
    t.loft(rings,base,folds=.022)
    edge='fern' if style=='traveller' else 'lilac' if style=='mage' else 'brick'
    t.band(rings,hem+.003,hem+.013,edge,folds=.022)
    if style=='traveller':
        # Short split-front rain cape, ochre scarf and leather map case.
        t.loft([(.55,.152,.112),(.61,.139,.105),(.655,.111,.083),(.684,.064,.057)],'pine',
               arc=(.38,TAU-.38),folds=.035,hem=lambda a:-.084*(1-math.cos(a))/2)
        t.loft([(.651,.109,.083),(.667,.095,.081),(.684,.081,.072),(.697,.064,.054)],'saffron',folds=.04)
        t.cord([(-.077,.639,.079),(-.045,.58,.104),(.002,.522,.103),(.057,.462,.10),(.087,.427,.082)],.011,'hide')
        t.pouch(.077,.411,.095)
        t.cord([(-.043,.63,.096),(0,.615,.106),(.042,.632,.096)],.003,'brass')
        t.stone(.042,.632,.097,.006,.006,.003,'brass')
        # Rolled blanket across the back of the cape.
        t.cord([(-.098,.517,-.107),(.0,.522,-.113),(.098,.517,-.107)],.032,'oat')
        for x in (-.066,.066):
            t.cord([(x-.006,.52,-.11),(x+.006,.52,-.11)],.034,'umber')
    elif style=='mage':
        # Lighter embroidered facing runs down the flared, open-front coat.
        t.loft([(hem+.017,.167,.122),(.31,.146,.12),(.434,.116,.103),(.493,.096,.092),
                (.556,.101,.10),(.618,.12,.096),(.65,.101,.079)],'iris',arc=(-.27,.27))
        t.loft([(.591,.154,.114),(.636,.134,.099),(.676,.077,.068),(.697,.058,.052)],
               'ink',arc=(.21,TAU-.21),hem=lambda a:-.054*(1-math.cos(a))/2,folds=.035)
        # An embroidered eight-point compass below the back yoke.
        for angle in range(8):
            a=TAU*angle/8
            t.cord([(0,.530,-.087),(.018*math.sin(a),.530+.025*math.cos(a),-.086)],.002,'lilac')
        jewels=[(-.016,.31,.134),(.014,.348,.132),(-.011,.388,.126),(.011,.425,.117)]
        t.cord(jewels,.0023,'silver')
        for x,y,z in jewels:
            t.stone(x,y,z,.005,.008,.003,'silver')
        t.stone(0,.63,.107,.014,.021,.006,'brass')
        t.stone(0,.633,.113,.008,.014,.004,'gem')
    else:
        # Cream shirtfront between lapels, double row of brass buttons, work apron.
        t.band(rings,.512,.675,'linen',ease=.005,arc=(-.35,.35))
        for side in (-1,1):
            t.cord([(side*.052,.663,.072),(side*.049,.618,.092),(side*.024,.565,.108)],.008,'brick')
            for y,z in [(.535,.099),(.566,.104),(.6,.099)]:
                t.stone(side*.046,y,z,.005,.005,.003,'brass')
        t.loft([(.317,.150,.138),(.395,.148,.134),(.425,.144,.131),(.451,.125,.116),(.472,.112,.106)],
               'oat',arc=(-.87,.87),folds=.018,hem=lambda a:.016*abs(a))
        t.loft([(.33,.152,.140),(.339,.152,.140)],'brick',arc=(-.82,.82))
        t.pouch(-.087,.428,.083)
        for x,h in [(.062,.036),(.079,.045)]:
            t.cord([(x,.467,.095),(x,.467-h,.108)],.0028,'brass')
            t.cord([(x,.467-h,.108),(x+.009,.47-h,.109)],.003,'brass')
    t.band(rings,.471,.495,'umber' if style!='mage' else 'ink',ease=.007,folds=.022)
    t.stone(0,.482,.112,.016,.011,.004,'brass' if style!='mage' else 'silver')


def headwear(t,style):
    t.slot='Hat'
    if style=='mage':
        crown=[(.924,.201,.203),(.934,.207,.211),(.944,.194,.199),
                (.952,.156,.159),(.988,.135,.139), (1.044,.10,.102,.012,-.012),
                (1.099,.067,.069,.03,-.021),(1.14,.035,.038,.056,-.024),
                (1.154,.014,.016,.086,-.023),(1.147,.004,.005,.109,-.019)]
        t.loft(crown,'indigo',folds=.025,
               hem=lambda a:.014*math.sin(a-.45))
        t.band(crown,.949,.974,'ink',ease=.005,folds=.025)
        t.stone(.035,.961,.159,.012,.015,.006,'brass')
    elif style=='traveller':
        crown=[(.919,.174,.179),(.928,.181,.187),(.942,.162,.166),
                (.984,.158,.165), (1.026,.132,.135,-.012,-.014),
                (1.037,.063,.073,-.039,-.043),(1.03,.005,.01,-.085,-.079)]
        t.loft(crown,'pine',
               hem=lambda a:.018*math.sin(a))
        t.band(crown,.939,.954,'hide',ease=.004)
        t.cord([(-.13,.95,.103),(-.16,.992,.08),(-.176,1.037,.044)],.003,'brass')
        t.loft([(.967,.004,.004,-.147,.087),(.993,.017,.008,-.16,.069),
                (1.025,.015,.007,-.174,.048),(1.05,.001,.001,-.181,.035)],'saffron')
    else:
        crown=[(.926,.154,.16),(.939,.166,.171),(.96,.186,.18,-.017,-.003),
                (1.003,.173,.173,-.023,-.007),(1.035,.127,.132,-.023,-.015),
                (1.046,.018,.021,-.019,-.023)]
        t.loft(crown,'brick',folds=.028)
        t.band(crown,.926,.946,'plum',ease=.005,folds=.028)
        t.stone(-.095,.944,.147,.011,.012,.005,'brass')


def write(t, name):
    data=bytearray()
    views=[]; accessors=[]; meshes=[]; nodes=[]; materials=[]
    def accessor(values, fmt, kind, component, bounds=False):
        while len(data)%4:data.append(0)
        offset=len(data)
        for value in values:data.extend(struct.pack('<'+fmt,*value))
        views.append(dict(buffer=0,byteOffset=offset,byteLength=len(data)-offset))
        desc=dict(bufferView=len(views)-1,componentType=component,count=len(values),type=kind)
        if bounds:
            desc.update(min=list(map(min,zip(*values))),max=list(map(max,zip(*values))))
        accessors.append(desc)
        return len(accessors)-1
    for key,hexcolor in PALETTE.items():
        srgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
        linear=[((c+.055)/1.055)**2.4 if c>.04045 else c/12.92 for c in srgb]
        metal=key in ('silver','brass')
        materials.append(dict(name=key,doubleSided=True,pbrMetallicRoughness=dict(
            baseColorFactor=linear+[1],metallicFactor=.30 if metal else 0,roughnessFactor=.44 if metal else .86)))
    for slot,groups in t.parts.items():
        primitives=[]
        for color,parts in groups.items():
            pos=[];norm=[];idx=[]
            for v,n,i in parts:
                idx.extend((k+len(pos),) for k in i)
                pos.extend(v);norm.extend(n)
            primitives.append(dict(attributes=dict(POSITION=accessor(pos,'fff','VEC3',5126,True),
                NORMAL=accessor(norm,'fff','VEC3',5126)),indices=accessor(idx,'H','SCALAR',5123),
                material=list(PALETTE).index(color)))
        meshes.append(dict(name=slot,primitives=primitives))
        nodes.append(dict(name=slot,mesh=len(meshes)-1))
    while len(data)%4:data.append(0)
    doc=dict(asset=dict(version='2.0',generator='THREAD'),scene=0,scenes=[dict(nodes=list(range(4)))],
             nodes=nodes,meshes=meshes,materials=materials,buffers=[dict(byteLength=len(data))],
             bufferViews=views,accessors=accessors)
    meta=json.dumps(doc,separators=(',',':')).encode()
    meta+=b' '*(-len(meta)%4)
    (OUT/(name+'.glb')).write_bytes(struct.pack('<4sII',b'glTF',2,28+len(meta)+len(data))+
        struct.pack('<I4s',len(meta),b'JSON')+meta+struct.pack('<I4s',len(data),b'BIN\0')+data)


if __name__=='__main__':
    for name in ('traveller','mage','merchant'):
        tailor=Tailor()
        body(tailor,name);trousers(tailor,name);footwear(tailor,name);headwear(tailor,name)
        write(tailor,name)
