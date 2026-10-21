// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <array>
#include <QVector>

namespace arcade {
// Held directions and discrete actions are consumed only by the simulation clock.
// Each seat has a bounded one-action queue, a shared cadence and no wall-clock rules.
class PuzzleRules : public Rules {
public:
    int tick=0,winner=-1;
    std::array<int,2> direction{-1,-1},queued{-1,-1},repeat{},cooldown{},score{};
    std::array<bool,2> lost{};
    void input(int p,int d) override {
        if(p<0||p>1||d<-1||d>3)return;
        if(direction[p]!=d)repeat[p]=0;
        direction[p]=d;
    }
    void action(int p,int a) override {
        if(p>=0&&p<2&&a>=0&&a<2&&tick>=60&&winner<0&&cooldown[p]==0&&queued[p]<0)queued[p]=a;
    }
    void step() override {
        if(winner>=0)return;
        ++tick;if(tick<=60)return;
        for(int p=0;p<2;++p){
            if(cooldown[p]>0)--cooldown[p];
            if(direction[p]>=0&&repeat[p]--<=0){move(p,direction[p]);repeat[p]=5;}
            if(queued[p]>=0){const int a=queued[p];queued[p]=-1;act(p,a);cooldown[p]=6;}
        }
        advance();
        const bool done0=score[0]>=target(),done1=score[1]>=target();
        if(lost[0]||lost[1])winner=lost[0]&&lost[1]?2:lost[0]?1:0;
        else if(done0||done1)winner=done0&&done1?2:done0?0:1;
        else if(tick>=5460)winner=score[0]==score[1]?2:score[0]>score[1]?0:1;
    }
protected:
    void resetBase(){tick=0;winner=-1;direction={-1,-1};queued={-1,-1};repeat={};cooldown={};score={};lost={};}
    virtual void move(int p,int d)=0;
    virtual void act(int p,int a)=0;
    virtual void advance()=0;
    virtual int target() const=0;
    QJsonObject base(int width,int height) const {
        return {{"tick",tick},{"winner",winner},{"width",width},{"height",height},{"s0",score[0]},{"s1",score[1]},{"target",target()}};
    }
    bool validBase(const QJsonObject& s,int width,int height) const {
        return baseView(s)&&integer(s["tick"],0,5460)&&s["width"]==width&&s["height"]==height&&s["target"]==target()
            &&integer(s["s0"],0,100000)&&integer(s["s1"],0,100000)&&s["players"].isArray()&&s["players"].toArray().size()==2;
    }
};
inline QJsonArray cellsJson(const QVector<int>& cells){QJsonArray a;for(int cell:cells)a.append(cell);return a;}
inline bool validCells(const QJsonValue& value,int size,int low,int high){
    if(!value.isArray()||value.toArray().size()!=size)return false;
    for(auto cell:value.toArray())if(!integer(cell,low,high))return false;
    return true;
}
}
