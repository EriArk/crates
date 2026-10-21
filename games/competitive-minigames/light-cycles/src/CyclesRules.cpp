// SPDX-License-Identifier: GPL-3.0-or-later
#include "CyclesRules.h"
#include <QVector>
namespace arcade {
void CyclesRules::reset(quint32 seed) {
    tick=0;winner=-1;cells.fill(0);direction={1,3};pending=direction;
    const int row=4+int(random(seed)%10);head={3+row*W,24+(H-1-row)*W};
    cells[head[0]]=1;cells[head[1]]=2;
}
int CyclesRules::next(int cell,int dir) const {
    int x=cell%W,y=cell/W;x+=dir==1?1:dir==3?-1:0;y+=dir==2?1:dir==0?-1:0;
    return x<0||x>=W||y<0||y>=H?-1:y*W+x;
}
void CyclesRules::input(int p,int d) {if(p>=0&&p<2&&d>=0&&d<4&&d!=(direction[p]+2)%4)pending[p]=d;}
void CyclesRules::step() {
    if(winner!=-1)return;
    ++tick;if(tick<=60||tick%4)return;
    direction=pending;
    const std::array<int,2> n{next(head[0],direction[0]),next(head[1],direction[1])};
    const bool a=n[0]<0||(n[0]>=0&&cells[n[0]]!=0)||n[0]==n[1];
    const bool b=n[1]<0||(n[1]>=0&&cells[n[1]]!=0)||n[0]==n[1];
    if(a||b){winner=a==b?2:a?1:0;return;}
    head=n;cells[head[0]]=1;cells[head[1]]=2;
}
int CyclesRules::bot(int p) const {
    int best=-1,result=direction[p];
    for(int d=0;d<4;++d){
        if(d==(direction[p]+2)%4)continue;
        const int start=next(head[p],d);if(start<0||cells[start])continue;
        auto seen=cells;QVector<int> queue{start};seen[start]=3;
        for(int i=0;i<queue.size();++i)for(int k=0;k<4;++k){const int n=next(queue[i],k);if(n>=0&&!seen[n]){seen[n]=3;queue.append(n);}}
        if(queue.size()>best){best=int(queue.size());result=d;}
    }return result;
}
QJsonObject CyclesRules::view() const {
    QJsonArray grid;int a=0,b=0;for(int v:cells){grid.append(v);a+=v==1;b+=v==2;}
    return {{"tick",tick},{"winner",winner},{"width",W},{"height",H},{"cells",grid},
            {"h0",head[0]},{"h1",head[1]},{"d0",direction[0]},{"d1",direction[1]},{"s0",a},{"s1",b}};
}
bool CyclesRules::validView(const QJsonObject& s) const {
    if(!baseView(s)||s["width"]!=W||s["height"]!=H||!s["cells"].isArray()||s["cells"].toArray().size()!=W*H
        ||!integer(s["h0"],0,W*H-1)||!integer(s["h1"],0,W*H-1)||!integer(s["d0"],0,3)||!integer(s["d1"],0,3))return false;
    int a=0,b=0;for(const auto v:s["cells"].toArray()){if(!integer(v,0,2))return false;a+=v==1;b+=v==2;}
    const auto grid=s["cells"].toArray();
    return s["s0"]==a&&s["s1"]==b&&grid[s["h0"].toInt()]==1&&grid[s["h1"].toInt()]==2;
}
}
