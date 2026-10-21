// SPDX-License-Identifier: GPL-3.0-or-later
#include "TanksRules.h"
#include <algorithm>
namespace arcade {
QPoint TanksRules::delta(int d){static const QPoint ds[]={{0,-1},{1,0},{0,1},{-1,0}};return ds[d];}
static bool touching(QPoint a,QPoint b){return std::abs(a.x()-b.x())<3&&std::abs(a.y()-b.y())<3;}
static bool hits(QPoint a,QPoint b){return std::abs(a.x()-b.x())<=1&&std::abs(a.y()-b.y())<=1;}
void TanksRules::reset(quint32 seed){
    tick=0;winner=-1;scores={};bullets.clear();cells=QVector<int>(25*19);
    for(int y=0;y<19;++y)for(int x=0;x<25;++x)if(!x||!y||x==24||y==18)cells[y*25+x]=2;
    // Symmetric cover; the open middle and top/bottom corridors connect both sides.
    for(int y:{4,12})for(int x:{7,15})for(int dy=0;dy<3;++dy)for(int dx=0;dx<3;++dx)cells[(y+dy)*25+x+dx]=1;
    for(int y=8;y<=10;++y)for(int x=11;x<=13;++x)cells[y*25+x]=2;
    if(random(seed)%2)for(int x:{10,14})cells[9*25+x]=2;
    tanks={Tank{},Tank{}};tanks[0].pos={3,9};tanks[1].pos={21,9};tanks[1].face=3;
}
bool TanksRules::clear(QPoint pos) const {if(pos.x()<2||pos.x()>22||pos.y()<2||pos.y()>16)return false;
    for(int dy=-1;dy<=1;++dy)for(int dx=-1;dx<=1;++dx)if(cells[(pos.y()+dy)*25+pos.x()+dx])return false;return true;}
void TanksRules::input(int p,int d){if(p>=0&&p<2&&d>=-1&&d<4)tanks[p].direction=d;}
void TanksRules::action(int p,int a){if(p>=0&&p<2&&a==0&&tick>=60&&winner<0)tanks[p].fire=true;}
void TanksRules::respawn(int p){auto& t=tanks[p];
    for(int y:{9,3,15})for(int x:{p==0?3:21,p==0?21:3})if(clear({x,y})&&!touching({x,y},tanks[1-p].pos)){t.pos={x,y};t.face=p==0?1:3;t.shield=45;t.cooldown=15;t.fire=false;return;}
}
void TanksRules::step(){
    if(winner>=0)return;++tick;if(tick<=60)return;
    std::array<QPoint,2> next{tanks[0].pos,tanks[1].pos};
    for(int p=0;p<2;++p){auto& t=tanks[p];if(t.shield)--t.shield;if(t.cooldown)--t.cooldown;
        if(t.direction>=0){t.face=t.direction;if(tick%4==0){auto at=t.pos+delta(t.face);if(clear(at))next[p]=at;}}}
    if(touching(next[0],next[1])||(touching(next[0],tanks[1].pos)&&touching(next[1],tanks[0].pos)))next={tanks[0].pos,tanks[1].pos};
    for(int p=0;p<2;++p){auto& t=tanks[p];t.pos=next[p];if(t.fire){if(!t.cooldown){bullets.append({t.pos+delta(t.face)*2,t.face,p});t.cooldown=12;t.shield=0;}t.fire=false;}}
    if(tick%2==0){
        QVector<Bullet> moved;QVector<QPoint> previous;std::array<bool,2> hit{};QVector<int> broken;
        for(auto b:bullets){QPoint old=b.pos;
            // Inspect the muzzle before moving: a shot cannot tunnel through adjacent cover.
            bool alive=true;for(int part=0;part<2&&alive;++part){if(part)b.pos+=delta(b.direction);
                if(b.pos.x()<0||b.pos.x()>=25||b.pos.y()<0||b.pos.y()>=19){alive=false;break;}
                int at=b.pos.y()*25+b.pos.x();if(cells[at]){if(cells[at]==1)broken.append(at);alive=false;}
                else if(hits(b.pos,tanks[1-b.owner].pos)){if(!tanks[1-b.owner].shield)hit[1-b.owner]=true;alive=false;}}
            if(alive&&--b.life>0){moved.append(b);previous.append(old);}
        }
        QVector<bool> cancel(moved.size());for(int i=0;i<moved.size();++i)for(int j=i+1;j<moved.size();++j)if(moved[i].owner!=moved[j].owner&&(moved[i].pos==moved[j].pos||(moved[i].pos==previous[j]&&moved[j].pos==previous[i])))cancel[i]=cancel[j]=true;
        bullets.clear();for(int i=0;i<moved.size();++i)if(!cancel[i])bullets.append(moved[i]);for(int at:broken)cells[at]=0;
        for(int p=0;p<2;++p)if(hit[p])++scores[1-p];
        if(scores[0]>=3||scores[1]>=3)winner=scores[0]>=3&&scores[1]>=3?2:scores[0]>=3?0:1;
        else for(int p=0;p<2;++p)if(hit[p])respawn(p);
    }
    if(winner<0&&tick>=3660)winner=scores[0]==scores[1]?2:scores[0]>scores[1]?0:1;
}
int TanksRules::bot(int p) const {
    const auto& t=tanks[p];auto goal=tanks[1-p].pos;int dx=goal.x()-t.pos.x(),dy=goal.y()-t.pos.y();
    auto firingDirection=[&](QPoint pos){
        int x=goal.x()-pos.x(),y=goal.y()-pos.y();int d=std::abs(y)<=1?(x>0?1:3):std::abs(x)<=1?(y>0?2:0):-1;
        if(d<0)return -1;for(auto at=pos+delta(d)*2;at.x()>0&&at.x()<24&&at.y()>0&&at.y()<18;at+=delta(d)){
            if(cells[at.y()*25+at.x()]==2)return -1;if(hits(at,goal))return d;}return -1;
    };
    int aim=firingDirection(t.pos);if(aim>=0)return aim;
    // Shortest traversable route to an aligned firing position. Bricks are shot if necessary.
    QVector<int> distance(475,-1),first(475,-1),queue{t.pos.y()*25+t.pos.x()};distance[queue[0]]=0;
    for(int head=0;head<queue.size();++head){int at=queue[head];QPoint pos(at%25,at/25);
        if(head&&firingDirection(pos)>=0)return first[at];
        for(int d=0;d<4;++d){auto n=pos+delta(d);if(!clear(n)||touching(n,goal))continue;int k=n.y()*25+n.x();if(distance[k]>=0)continue;distance[k]=distance[at]+1;first[k]=head?first[at]:d;queue.append(k);}}
    return std::abs(dx)>std::abs(dy)?(dx>0?1:3):(dy>0?2:0);
}
int TanksRules::botAction(int p) const {const auto& t=tanks[p];return !t.cooldown&&bot(p)==t.face?0:-1;}
QJsonObject TanksRules::view() const {
    QJsonArray board,players,shots;for(int cell:cells)board.append(cell);
    for(auto t:tanks)players.append(QJsonObject{{"x",t.pos.x()},{"y",t.pos.y()},{"face",t.face},{"shield",t.shield},{"cooldown",t.cooldown}});
    for(auto b:bullets)shots.append(QJsonObject{{"x",b.pos.x()},{"y",b.pos.y()},{"direction",b.direction},{"owner",b.owner}});
    return {{"tick",tick},{"winner",winner},{"s0",scores[0]},{"s1",scores[1]},{"cells",board},{"players",players},{"bullets",shots}};
}
bool TanksRules::validView(const QJsonObject& s) const {
    if(!baseView(s)||!integer(s["tick"],0,3660)||!integer(s["s0"],0,3)||!integer(s["s1"],0,3)||!s["cells"].isArray()||s["cells"].toArray().size()!=475||!s["players"].isArray()||s["players"].toArray().size()!=2||!s["bullets"].isArray()||s["bullets"].toArray().size()>32)return false;
    for(auto c:s["cells"].toArray())if(!integer(c,0,2))return false;
    for(auto v:s["players"].toArray()){auto p=v.toObject();if(!integer(p["x"],2,22)||!integer(p["y"],2,16)||!integer(p["face"],0,3)||!integer(p["shield"],0,45)||!integer(p["cooldown"],0,12+3))return false;}
    for(auto v:s["bullets"].toArray()){auto b=v.toObject();if(!integer(b["x"],0,24)||!integer(b["y"],0,18)||!integer(b["direction"],0,3)||!integer(b["owner"],0,1))return false;}
    return true;
}
}
