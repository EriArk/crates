// SPDX-License-Identifier: GPL-3.0-or-later
#include "TanksRules.h"
#include <algorithm>
#include <limits>
namespace arcade {
QPoint TanksRules::delta(int d){static const QPoint ds[]={{0,-1},{1,0},{0,1},{-1,0}};return ds[d];}
static bool touching(QPoint a,QPoint b){return std::abs(a.x()-b.x())<3&&std::abs(a.y()-b.y())<3;}
static bool hits(QPoint a,QPoint b){return std::abs(a.x()-b.x())<=1&&std::abs(a.y()-b.y())<=1;}
void TanksRules::reset(quint32 seed){reset(seed,2);}
void TanksRules::reset(quint32 seed,int players){
    players=std::clamp(players,2,MaxPlayers);tick=0;winner=-1;bullets.clear();
    tanks=QVector<Tank>(players);scores=QVector<int>(players);cells=QVector<int>(Width*Height);
    botTick_=QVector<int>(players,-1);botDirection_=QVector<int>(players,-1);
    for(int y=0;y<Height;++y)for(int x=0;x<Width;++x)if(!x||!y||x==Width-1||y==Height-1)cells[y*Width+x]=Steel;
    // Mirrored districts with broad streets. Water blocks tanks, not shells;
    // bushes are passable scenery, never invisible competitive cover.
    auto plot=[&](int x,int y,int w,int h,int tile){for(int dy=0;dy<h;++dy)for(int dx=0;dx<w;++dx){cells[(y+dy)*Width+x+dx]=tile;cells[(y+dy)*Width+Width-1-x-dx]=tile;}};
    for(int y:{8,17,26,35})for(int x:{10,22}){
        int tile=1+int(random(seed)%4);plot(x,y,4,3,tile);
        if(tile==Brick){plot(x,y+3,1,2,Brick);plot(x+3,y+3,1,2,Brick);}}
    spawns_={{5,22},{55,22},{5,5},{55,39},{5,39},{55,5},{17,4},{43,40},
             {30,4},{30,40},{43,4},{17,40},{4,13},{56,31},{4,31},{56,13}};
    for(int y=20;y<=24;++y)for(int x=1;x<Width-1;++x)cells[y*Width+x]=Ground;
    for(int y=1;y<Height-1;++y)for(int x=28;x<=32;++x)cells[y*Width+x]=Ground;
    for(int p=0;p<players;++p){tanks[p].pos=spawns_[p];tanks[p].face=p%2?3:1;}
}
bool TanksRules::clear(QPoint pos) const {
    if(pos.x()<2||pos.x()>Width-3||pos.y()<2||pos.y()>Height-3)return false;
    for(int dy=-1;dy<=1;++dy)for(int dx=-1;dx<=1;++dx){int t=cells[(pos.y()+dy)*Width+pos.x()+dx];if(t==Brick||t==Steel||t==Water)return false;}return true;
}
void TanksRules::input(int p,int d){if(p>=0&&p<tanks.size()&&d>=-1&&d<4)tanks[p].direction=d;}
void TanksRules::action(int p,int a){if(p>=0&&p<tanks.size()&&a==0&&tick>=60&&winner<0)tanks[p].fire=true;}
void TanksRules::respawn(int p){
    QPoint best=tanks[p].pos;int bestDistance=-1;
    for(int i=0;i<spawns_.size();++i){auto at=spawns_[(p+i)%spawns_.size()];if(!clear(at))continue;int distance=100000;
        for(int q=0;q<tanks.size();++q)if(q!=p){if(touching(at,tanks[q].pos)){distance=-1;break;}distance=std::min(distance,(at-tanks[q].pos).manhattanLength());}
        if(distance>bestDistance){best=at;bestDistance=distance;}}
    auto& t=tanks[p];t.pos=best;t.face=p%2?3:1;t.shield=45;t.cooldown=15;t.fire=false;botTick_[p]=-1;
}
void TanksRules::step(){
    if(winner>=0)return;++tick;if(tick<=60)return;
    QVector<QPoint> next;for(const auto& t:tanks)next.append(t.pos);
    for(int p=0;p<tanks.size();++p){auto& t=tanks[p];if(t.shield)--t.shield;if(t.cooldown)--t.cooldown;
        if(t.direction>=0){t.face=t.direction;if(tick%4==0){auto at=t.pos+delta(t.face);if(clear(at))next[p]=at;}}}
    // Resolve all conflicts together, including a tank stopped by a third tank.
    bool changed=true;while(changed){changed=false;QVector<bool> blocked(tanks.size());
        for(int p=0;p<tanks.size();++p)for(int q=p+1;q<tanks.size();++q)
            if(touching(next[p],next[q])||(touching(next[p],tanks[q].pos)&&touching(next[q],tanks[p].pos)))blocked[p]=blocked[q]=true;
        for(int p=0;p<tanks.size();++p)if(blocked[p]&&next[p]!=tanks[p].pos){next[p]=tanks[p].pos;changed=true;}}
    for(int p=0;p<tanks.size();++p){auto& t=tanks[p];t.pos=next[p];if(t.fire){if(!t.cooldown){bullets.append({t.pos+delta(t.face)*2,t.face,p});t.cooldown=12;t.shield=0;}t.fire=false;}}
    if(tick%2==0){
        QVector<Bullet> moved;QVector<QPoint> previous;QVector<int> killer(tanks.size(),-1),broken;
        for(auto b:bullets){QPoint old=b.pos;bool alive=true;
            for(int part=0;part<2&&alive;++part){if(part)b.pos+=delta(b.direction);
                if(b.pos.x()<0||b.pos.x()>=Width||b.pos.y()<0||b.pos.y()>=Height){alive=false;break;}
                int at=b.pos.y()*Width+b.pos.x();if(cells[at]==Brick||cells[at]==Steel){if(cells[at]==Brick)broken.append(at);alive=false;}
                else for(int p=0;p<tanks.size();++p)if(p!=b.owner&&hits(b.pos,tanks[p].pos)){if(!tanks[p].shield&&killer[p]<0)killer[p]=b.owner;alive=false;break;}}
            if(alive&&--b.life>0){moved.append(b);previous.append(old);}}
        QVector<bool> cancel(moved.size());for(int i=0;i<moved.size();++i)for(int j=i+1;j<moved.size();++j)
            if(moved[i].owner!=moved[j].owner&&(moved[i].pos==moved[j].pos||(moved[i].pos==previous[j]&&moved[j].pos==previous[i])))cancel[i]=cancel[j]=true;
        bullets.clear();for(int i=0;i<moved.size();++i)if(!cancel[i])bullets.append(moved[i]);for(int at:broken)cells[at]=Ground;
        for(int p=0;p<tanks.size();++p)if(killer[p]>=0)++scores[killer[p]];
        int leaders=0;for(int p=0;p<tanks.size();++p)if(scores[p]>=3){winner=p;++leaders;}
        if(leaders>1)winner=tanks.size();
        if(winner<0)for(int p=0;p<tanks.size();++p)if(killer[p]>=0)respawn(p);
    }
    if(winner<0&&tick>=3660){int best=-1,leaders=0;for(int p=0;p<scores.size();++p){if(scores[p]>best){best=scores[p];winner=p;leaders=1;}else if(scores[p]==best)++leaders;}if(leaders>1)winner=tanks.size();}
}
int TanksRules::bot(int p) const {
    if(p<0||p>=tanks.size())return -1;if(botTick_[p]==tick/4)return botDirection_[p];
    const auto& t=tanks[p];int enemy=-1,best=std::numeric_limits<int>::max();
    for(int q=0;q<tanks.size();++q)if(q!=p){int d=(t.pos-tanks[q].pos).manhattanLength();if(d<best){best=d;enemy=q;}}
    auto goal=tanks[enemy].pos;
    auto firingDirection=[&](QPoint pos){int x=goal.x()-pos.x(),y=goal.y()-pos.y();int d=std::abs(y)<=1?(x>0?1:3):std::abs(x)<=1?(y>0?2:0):-1;
        if(d<0)return -1;for(auto at=pos+delta(d)*2;at.x()>0&&at.x()<Width-1&&at.y()>0&&at.y()<Height-1;at+=delta(d)){
            if(cells[at.y()*Width+at.x()]==Steel)return -1;if(hits(at,goal))return d;}return -1;};
    auto finish=[&](int d){botTick_[p]=tick/4;botDirection_[p]=d;return d;};
    int aim=firingDirection(t.pos);if(aim>=0)return finish(aim);
    QVector<int> first(Width*Height,-2),queue{t.pos.y()*Width+t.pos.x()};first[queue[0]]=-1;
    for(int head=0;head<queue.size();++head){int at=queue[head];QPoint pos(at%Width,at/Width);
        if(head&&firingDirection(pos)>=0)return finish(first[at]);
        for(int d=0;d<4;++d){auto n=pos+delta(d);if(!clear(n))continue;bool occupied=false;for(int q=0;q<tanks.size();++q)if(q!=p&&touching(n,tanks[q].pos)){occupied=true;break;}if(occupied)continue;
            int k=n.y()*Width+n.x();if(first[k]!=-2)continue;first[k]=head?first[at]:d;queue.append(k);}}
    int dx=goal.x()-t.pos.x(),dy=goal.y()-t.pos.y();return finish(std::abs(dx)>std::abs(dy)?(dx>0?1:3):(dy>0?2:0));
}
int TanksRules::botAction(int p) const {return p>=0&&p<tanks.size()&&!tanks[p].cooldown&&bot(p)==tanks[p].face?0:-1;}
QJsonObject TanksRules::view() const {
    QJsonArray board,players,shots;for(int cell:cells)board.append(cell);
    for(int p=0;p<tanks.size();++p){const auto& t=tanks[p];players.append(QJsonObject{{"x",t.pos.x()},{"y",t.pos.y()},{"face",t.face},{"shield",t.shield},{"cooldown",t.cooldown},{"score",scores[p]}});}
    for(auto b:bullets)shots.append(QJsonArray{b.pos.x(),b.pos.y(),b.direction,b.owner});
    return {{"tick",tick},{"winner",winner},{"s0",scores.value(0)},{"s1",scores.value(1)},{"width",Width},{"height",Height},{"cells",board},{"players",players},{"bullets",shots}};
}
bool TanksRules::validView(const QJsonObject& s) const {
    const auto players=s["players"].toArray();int count=players.size();
    if(count<2||count>MaxPlayers||!integer(s["winner"],-1,count)||!integer(s["tick"],0,3660)||s["width"]!=Width||s["height"]!=Height||!s["cells"].isArray()||s["cells"].toArray().size()!=Width*Height||!s["bullets"].isArray()||s["bullets"].toArray().size()>192)return false;
    for(auto c:s["cells"].toArray())if(!integer(c,Ground,Bush))return false;
    for(auto v:players){auto p=v.toObject();if(!integer(p["x"],2,Width-3)||!integer(p["y"],2,Height-3)||!integer(p["face"],0,3)||!integer(p["shield"],0,45)||!integer(p["cooldown"],0,15)||!integer(p["score"],0,MaxPlayers+2))return false;}
    if(s["s0"]!=players[0].toObject()["score"]||s["s1"]!=players[1].toObject()["score"])return false;
    for(auto v:s["bullets"].toArray()){auto b=v.toArray();if(b.size()!=4||!integer(b[0],0,Width-1)||!integer(b[1],0,Height-1)||!integer(b[2],0,3)||!integer(b[3],0,count-1))return false;}
    return true;
}
}
