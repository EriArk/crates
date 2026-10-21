// SPDX-License-Identifier: GPL-3.0-or-later
#include "SnakeRules.h"
#include <QSet>
#include <cmath>
namespace arcade {
void SnakeRules::reset(quint32 value) {
    tick=0;winner=-1;seed=value;direction={1,3};pending=direction;
    body[0]={4+5*W,3+5*W,2+5*W};body[1]={19+10*W,20+10*W,21+10*W};spawnFood();
}
int SnakeRules::next(int cell,int dir) const {
    int x=cell%W,y=cell/W;x+=dir==1?1:dir==3?-1:0;y+=dir==2?1:dir==0?-1:0;
    return x<0||x>=W||y<0||y>=H?-1:y*W+x;
}
void SnakeRules::spawnFood() {
    QVector<int> free;
    for(int i=0;i<W*H;++i)if(!body[0].contains(i)&&!body[1].contains(i))free.append(i);
    food=free.isEmpty()?-1:free[int(random(seed)%free.size())];
}
void SnakeRules::input(int p,int dir) {
    if(p>=0&&p<2&&dir>=0&&dir<4&&dir!=(direction[p]+2)%4)pending[p]=dir;
}
void SnakeRules::step() {
    if(winner!=-1)return;
    ++tick;if(tick<=60||tick%5)return;
    direction=pending;
    const std::array<int,2> heads{next(body[0][0],direction[0]),next(body[1][0],direction[1])};
    std::array<bool,2> dead{false,false};
    for(int p=0;p<2;++p){
        dead[p]=heads[p]<0||heads[p]==heads[1-p];
        for(int q=0;q<2;++q){
            // A tail vacates simultaneously unless that snake eats this tick.
            const int occupied=int(body[q].size())-(heads[q]==food?0:1);
            for(int i=0;i<occupied;++i)if(heads[p]==body[q][i])dead[p]=true;
        }
    }
    if(dead[0]||dead[1]){winner=dead[0]==dead[1]?2:dead[0]?1:0;return;}
    bool eaten=false;
    for(int p=0;p<2;++p){body[p].prepend(heads[p]);if(heads[p]!=food)body[p].removeLast();else eaten=true;}
    if(eaten)spawnFood();
    if(food<0||tick>=30*120)winner=body[0].size()==body[1].size()?2:body[0].size()>body[1].size()?0:1;
}
int SnakeRules::bot(int p) const {
    int best=-100000,result=direction[p];
    for(int d=0;d<4;++d){
        if(d==(direction[p]+2)%4)continue;
        const int n=next(body[p][0],d);if(n<0||body[0].contains(n)||body[1].contains(n))continue;
        int exits=0;for(int e=0;e<4;++e){const int v=next(n,e);if(v>=0&&!body[0].contains(v)&&!body[1].contains(v))++exits;}
        const int score=exits*8-std::abs(n%W-food%W)-std::abs(n/W-food/W);
        if(score>best){best=score;result=d;}
    }return result;
}
QJsonObject SnakeRules::view() const {
    QJsonArray a,b;for(int v:body[0])a.append(v);for(int v:body[1])b.append(v);
    return {{"tick",tick},{"winner",winner},{"width",W},{"height",H},{"a",a},{"b",b},{"food",food},
            {"d0",direction[0]},{"d1",direction[1]},{"s0",int(body[0].size())-3},{"s1",int(body[1].size())-3}};
}
bool SnakeRules::validView(const QJsonObject& s) const {
    if(!baseView(s)||s["width"]!=W||s["height"]!=H||!integer(s["food"],-1,W*H-1)
        ||!integer(s["d0"],0,3)||!integer(s["d1"],0,3))return false;
    QSet<int> cells;
    for(const auto& key:{"a","b"}){
        if(!s[key].isArray())return false;
        const auto list=s[key].toArray();if(list.size()<3||list.size()>W*H)return false;
        for(const auto v:list){if(!integer(v,0,W*H-1)||cells.contains(v.toInt()))return false;cells.insert(v.toInt());}
    }
    return s["s0"]==s["a"].toArray().size()-3&&s["s1"]==s["b"].toArray().size()-3
        &&(s["food"]==-1||!cells.contains(s["food"].toInt()));
}
}
