// SPDX-License-Identifier: GPL-3.0-or-later
#include "BlocksRules.h"
#include <algorithm>
#include <limits>
namespace arcade {
QVector<QPoint> BlocksRules::shape(int type,int rotation){
    static const QVector<QPoint> shapes[]={{{0,1},{1,1},{2,1},{3,1}},{{1,0},{2,0},{1,1},{2,1}},{{1,0},{0,1},{1,1},{2,1}},
        {{1,0},{2,0},{0,1},{1,1}},{{0,0},{1,0},{1,1},{2,1}},{{0,0},{0,1},{1,1},{2,1}},{{2,0},{0,1},{1,1},{2,1}}};
    auto cells=shapes[type];if(type==1)return cells;
    for(int r=0;r<rotation;++r)for(auto& cell:cells)cell=QPoint((type==0?3:2)-cell.y(),cell.x());
    return cells;
}
bool BlocksRules::fits(const Player& p,int x,int y,int rotation) const {
    for(auto c:shape(p.type,rotation)){c+=QPoint(x,y);if(c.x()<0||c.x()>=10||c.y()<0||c.y()>=16||p.cells[c.y()*10+c.x()])return false;}return true;
}
void BlocksRules::reset(quint32 seed){
    resetBase();for(int p=0;p<2;++p){players[p]=Player{};players[p].rng=seed?seed:1;players[p].next=random(players[p].rng)%7;spawn(p);}
}
void BlocksRules::spawn(int p){auto& s=players[p];s.type=s.next;s.next=random(s.rng)%7;s.rotation=0;s.x=3;s.y=0;s.fall=0;if(!fits(s,s.x,s.y,s.rotation))lost[p]=true;}
void BlocksRules::lock(int p){
    auto& s=players[p];for(auto c:shape(s.type,s.rotation))s.cells[(s.y+c.y())*10+s.x+c.x()]=s.type+1;
    for(int y=15;y>=0;--y){bool full=true;for(int x=0;x<10;++x)full&=s.cells[y*10+x]!=0;
        if(full){for(int row=y;row>0;--row)for(int x=0;x<10;++x)s.cells[row*10+x]=s.cells[(row-1)*10+x];for(int x=0;x<10;++x)s.cells[x]=0;++score[p];++y;}}
    spawn(p);
}
void BlocksRules::move(int p,int d){
    if(lost[p])return;auto& s=players[p];
    if(d==1||d==3){int x=s.x+(d==1?1:-1);if(fits(s,x,s.y,s.rotation))s.x=x;}
    if(d==2&&fits(s,s.x,s.y+1,s.rotation))++s.y;
}
void BlocksRules::act(int p,int a){
    if(lost[p])return;auto& s=players[p];
    if(a==0){for(int dx:{0,-1,1,-2,2})if(fits(s,s.x+dx,s.y,(s.rotation+1)%4)){s.x+=dx;s.rotation=(s.rotation+1)%4;break;}}
    else{while(fits(s,s.x,s.y+1,s.rotation))++s.y;lock(p);}
}
void BlocksRules::advance(){for(int p=0;p<2;++p)if(!lost[p]){auto& s=players[p];if(++s.fall>=24){s.fall=0;if(fits(s,s.x,s.y+1,s.rotation))++s.y;else lock(p);}}}
std::pair<int,int> BlocksRules::plan(int p) const {
    const auto& s=players[p];int best=std::numeric_limits<int>::max();std::pair<int,int> result{s.x,s.rotation};
    for(int r=0;r<4;++r)for(int x=-2;x<10;++x){
        if(!fits(s,x,s.y,r))continue;int y=s.y;while(fits(s,x,y+1,r))++y;auto cells=s.cells;
        for(auto c:shape(s.type,r))cells[(y+c.y())*10+x+c.x()]=1;
        int lines=0;for(int row=15;row>=0;--row){bool full=true;for(int col=0;col<10;++col)full&=cells[row*10+col]!=0;
            if(full){++lines;for(int j=row;j>0;--j)for(int col=0;col<10;++col)cells[j*10+col]=cells[(j-1)*10+col];for(int col=0;col<10;++col)cells[col]=0;++row;}}
        int cost=-lines*90,previous=0;for(int col=0;col<10;++col){int height=0;bool seen=false;for(int row=0;row<16;++row){if(cells[row*10+col]){if(!seen)height=16-row;seen=true;}else if(seen)cost+=60;}cost+=height*5;if(col)cost+=std::abs(height-previous)*3;previous=height;}
        if(cost<best){best=cost;result={x,r};}
    }return result;
}
int BlocksRules::bot(int p) const {if(tick%6||tick<60)return -1;auto [x,r]=plan(p);return players[p].x<x?1:players[p].x>x?3:-1;}
int BlocksRules::botAction(int p) const {if(tick%12||tick<60)return -1;auto [x,r]=plan(p);return players[p].rotation!=r?0:players[p].x==x?1:-1;}
QJsonObject BlocksRules::view() const {
    auto s=base(10,16);QJsonArray list;for(int p=0;p<2;++p){const auto& v=players[p];QJsonArray active,ghost;int y=v.y;while(fits(v,v.x,y+1,v.rotation))++y;
        for(auto c:shape(v.type,v.rotation)){active.append((v.y+c.y())*10+v.x+c.x());ghost.append((y+c.y())*10+v.x+c.x());}
        list.append(QJsonObject{{"cells",cellsJson(v.cells)},{"active",active},{"ghost",ghost},{"type",v.type},{"next",v.next},{"lost",lost[p]}});}
    s["players"]=list;return s;
}
bool BlocksRules::validView(const QJsonObject& s) const {
    if(!validBase(s,10,16))return false;for(auto value:s["players"].toArray()){auto p=value.toObject();if(!validCells(p["cells"],160,0,7)||!validCells(p["active"],4,0,159)||!validCells(p["ghost"],4,0,159)||!integer(p["type"],0,6)||!integer(p["next"],0,6)||!p["lost"].isBool())return false;}return true;
}
}
