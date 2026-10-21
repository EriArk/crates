// SPDX-License-Identifier: GPL-3.0-or-later
#include "PongRules.h"
#include <algorithm>
#include <cmath>
namespace arcade {
void PongRules::reset(quint32 value) {
    seed=value;tick=0;winner=-1;x=480;y=270;vx=(random(seed)&1)?7:-7;vy=3;
    serve=30;paddles={270,270};directions={-1,-1};scores={0,0};
}
void PongRules::input(int p,int d) { if(p>=0&&p<2)directions[p]=(d==0||d==2)?d:-1; }
void PongRules::step() {
    if(winner!=-1)return;
    ++tick;
    if(tick<=60)return;
    for(int p=0;p<2;++p)paddles[p]=std::clamp(paddles[p]+(directions[p]==0?-8:directions[p]==2?8:0),55,485);
    if(serve>0){--serve;return;}
    const int oldX=x;x+=vx;y+=vy;
    if(y<10){y=20-y;vy=std::abs(vy);}if(y>530){y=1060-y;vy=-std::abs(vy);}
    int hit=-1;
    if(vx<0&&oldX>=48&&x<=48&&std::abs(y-paddles[0])<=59)hit=0;
    if(vx>0&&oldX<=912&&x>=912&&std::abs(y-paddles[1])<=59)hit=1;
    if(hit!=-1){
        x=hit==0?48:912;vx=(hit==0?1:-1)*std::min(14,std::abs(vx)+1);
        vy=std::clamp((y-paddles[hit])/7,-7,7);if(vy==0)vy=(random(seed)&1)?2:-2;
    }
    if(x<0||x>960){
        const int scorer=x<0?1:0;++scores[scorer];
        if(scores[scorer]>=5){winner=scorer;return;}
        x=480;y=270;vx=scorer==0?-7:7;vy=(random(seed)&1)?3:-3;serve=30;
    }
    if(tick>=30*180)winner=scores[0]==scores[1]?2:scores[0]>scores[1]?0:1;
}
int PongRules::bot(int p) const {
    const int target=((p==0&&vx<0)||(p==1&&vx>0))?y:270;
    return target<paddles[p]-24?0:target>paddles[p]+24?2:-1;
}
QJsonObject PongRules::view() const {
    return {{"tick",tick},{"winner",winner},{"x",x},{"y",y},{"p0",paddles[0]},{"p1",paddles[1]},
            {"s0",scores[0]},{"s1",scores[1]},{"serve",serve},{"width",960},{"height",540}};
}
bool PongRules::validView(const QJsonObject& s) const {
    return baseView(s)&&integer(s["x"],-20,980)&&integer(s["y"],0,540)&&integer(s["p0"],55,485)
        &&integer(s["p1"],55,485)&&integer(s["s0"],0,5)&&integer(s["s1"],0,5)&&integer(s["serve"],0,30)
        &&s["width"]==960&&s["height"]==540;
}
}
