// SPDX-License-Identifier: GPL-3.0-or-later
#include "RacingRules.h"
#include <algorithm>
namespace arcade {
void RacingRules::reset(quint32 seed){
    tick=0;winner=-1;cars={Car{},Car{}};cars[0].lane=0;cars[1].lane=4;course.clear();
    // One shared course, indexed by distance. Every gate leaves at least one lane open.
    for(int i=0;i<25;++i){int mask=1<<(random(seed)%5);if(i>5)mask|=1<<(random(seed)%5);course.append(mask);}
}
void RacingRules::input(int p,int d){if(p<0||p>1||d<-1||d>3)return;if(cars[p].direction!=d)cars[p].repeat=0;cars[p].direction=d;}
void RacingRules::action(int p,int a){if(p>=0&&p<2&&a==0&&tick>=60&&winner<0)cars[p].requested=true;}
bool RacingRules::drafting(int p) const {const auto& a=cars[p];const auto& b=cars[1-p];return !a.crash&&!b.crash&&a.lane==b.lane&&b.distance-a.distance>=24&&b.distance-a.distance<=100;}
void RacingRules::step(){
    if(winner>=0)return;++tick;if(tick<=60)return;
    std::array<int,2> lanes{cars[0].lane,cars[1].lane},next{},speed{};
    for(int p=0;p<2;++p){auto& c=cars[p];

        if(c.requested){if(c.lives>0)c.boost=1-c.boost;c.requested=false;}
        if(c.crash){--c.crash;next[p]=c.distance;continue;}
        if((c.direction==1||c.direction==3)&&c.repeat--<=0){lanes[p]=qBound(0,c.lane+(c.direction==1?1:-1),4);c.repeat=7;}
        speed[p]=c.direction==2?1:c.boost?4:c.direction==0?3:2;next[p]=c.distance+speed[p];
    }
    // No side-ramming or overlapping lane changes. A following car can brake or pass.
    if(!cars[0].passable&&!cars[1].passable&&lanes[0]==lanes[1]&&std::abs(cars[0].distance-cars[1].distance)<24)lanes={cars[0].lane,cars[1].lane};
    for(int p=0;p<2;++p)cars[p].lane=lanes[p];
    if(lanes[0]==lanes[1]&&cars[0].distance!=cars[1].distance){int rear=cars[0].distance<cars[1].distance?0:1;
        if(!cars[0].passable&&!cars[1].passable)next[rear]=qMax(cars[rear].distance,qMin(next[rear],next[1-rear]-24));}
    for(int p=0;p<2;++p){auto& c=cars[p];c.distance=next[p];if(c.crash)continue;
        for(int i=0;i<course.size();++i){int at=120+i*90;
            if(i!=c.hitGate&&std::abs(c.distance-at)<=18&&(course[i]&(1<<c.lane))){c.hitGate=i;c.crash=18;c.passable=true;++c.crashes;--c.lives;break;}}
    }
    // Recovery never re-enables contact while the cars overlap.
    for(auto& c:cars)if(!c.crash&&(cars[0].lane!=cars[1].lane||std::abs(cars[0].distance-cars[1].distance)>=24))c.passable=false;
    if(!cars[0].lives||!cars[1].lives){winner=!cars[0].lives&&!cars[1].lives?2:!cars[0].lives?1:0;}
    else if(cars[0].distance>=2000||cars[1].distance>=2000){
        if(cars[0].distance>=2000&&cars[1].distance>=2000){
            // Compare fractions of the final step, without floating-point rounding.
            int a=(2000-(next[0]-speed[0]))*speed[1],b=(2000-(next[1]-speed[1]))*speed[0];winner=a==b?2:a<b?0:1;
        }else winner=cars[0].distance>=2000?0:1;
    }else if(tick>=3660)winner=cars[0].distance==cars[1].distance?2:cars[0].distance>cars[1].distance?0:1;
}
int RacingRules::bot(int p) const {
    const auto& c=cars[p];int blocked=0;
    for(int i=0;i<course.size();++i)if(120+i*90>=c.distance-18&&120+i*90<c.distance+100&&i!=c.hitGate){blocked=course[i];break;}
    int target=c.lane;if(blocked&(1<<target)){int best=6;for(int lane=0;lane<5;++lane)if(!(blocked&(1<<lane))&&std::abs(lane-c.lane)<best){target=lane;best=std::abs(lane-c.lane);}}
    if(drafting(p)&&cars[1-p].distance-c.distance<45&&target==c.lane)for(int lane=0;lane<5;++lane)if(lane!=target&&!(blocked&(1<<lane))){target=lane;break;}
    return c.lane<target?1:c.lane>target?3:0;
}
int RacingRules::botAction(int p) const {return bot(p)==0&&!cars[p].boost?0:-1;}
QJsonObject RacingRules::view() const {
    QJsonArray list,gates;for(int mask:course)gates.append(mask);
    for(int p=0;p<2;++p){const auto& c=cars[p];list.append(QJsonObject{{"lane",c.lane},{"distance",c.distance},{"crash",c.crash},{"crashes",c.crashes},{"boost",c.boost},{"lives",c.lives},{"draft",drafting(p)},{"passable",c.passable}});}
    return {{"tick",tick},{"winner",winner},{"s0",cars[0].distance},{"s1",cars[1].distance},{"players",list},{"course",gates}};
}
bool RacingRules::validView(const QJsonObject& s) const {
    if(!baseView(s)||!integer(s["tick"],0,3660)||!s["players"].isArray()||s["players"].toArray().size()!=2||!s["course"].isArray()||s["course"].toArray().size()!=25)return false;
    for(auto mask:s["course"].toArray())if(!integer(mask,1,30))return false;
    for(int i=0;i<2;++i){auto p=s["players"].toArray()[i].toObject();if(!integer(p["lane"],0,4)||!integer(p["distance"],0,2003)||s[i==0?"s0":"s1"]!=p["distance"]||!integer(p["crash"],0,18)||!integer(p["crashes"],0,3)||!integer(p["boost"],0,1)||!integer(p["lives"],0,3)||p["lives"].toInt()+p["crashes"].toInt()!=3||!p["draft"].isBool()||!p["passable"].isBool())return false;}
    return true;
}
}
