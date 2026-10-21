// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPoint>
#include <QVector>
#include <array>
#include <algorithm>

// All game rules use integers. Rendering never feeds back into the simulation.
struct World {
    static constexpr int Width=960, Height=400, Samples=193;
    std::array<int,Samples> ground{};
    std::array<int,2> hp{100,100};
    int turn=0, ply=0, winner=-1;
    quint32 seed=1;
    static int x(int player) { return player==0?120:840; }
    int floor(int px) const { return ground[std::clamp(px/5,0,Samples-1)]; }
    static int sqrtInt(int n) { int r=0; while((r+1)*(r+1)<=n)++r; return r; }
    explicit World(quint32 s=1):seed(s) {
        quint32 rng=s?s:1;
        int y=280,target=280;
        for(int i=0;i<Samples;++i){
            if(i%16==0){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;target=230+int(rng%91);}
            y+=std::clamp(target-y,-3,3);ground[i]=y;
        }
        for(int p=0;p<2;++p){const int y0=floor(x(p));for(int i=x(p)/5-5;i<=x(p)/5+5;++i)ground[i]=y0;}
    }
    struct Shot { QVector<QPoint> path; QPoint impact; bool hit=false; };
    static bool valid(int angle,int power) {return angle>=10&&angle<=80&&angle%5==0&&power>=20&&power<=100&&power%5==0;}
    Shot fire(int angle,int power) {
        Shot result;
        if(winner!=-1||!valid(angle,power))return result;
        constexpr int sin5[]{0,872,1736,2588,3420,4226,5000,5736,6428,7071,7660,8192,8660,9063,9397,9659,9848,9962,10000};
        const int direction=turn==0?1:-1;
        const int sx=sin5[(90-angle)/5],sy=sin5[angle/5];
        int px=x(turn)*1000+direction*43*sx/10;
        int py=(floor(x(turn))-25)*1000-43*sy/10;
        const int vx=direction*power*180*sx/10000;
        int vy=-power*180*sy/10000;
        // Substeps prevent fast shells tunnelling through tank bodies or slopes.
        for(int step=0;step<600&&!result.hit;++step){
            for(int sub=0;sub<4;++sub){
                px+=vx/4;py+=vy/4;
                const QPoint point(px/1000,py/1000);
                if(point.x()<0||point.x()>=Width||point.y()>Height){step=600;break;}
                bool tank=false;
                for(int p=0;p<2;++p)if(std::abs(point.x()-x(p))<=31&&std::abs(point.y()-(floor(x(p))-21))<=21)tank=true;
                if(point.y()>=floor(point.x())||tank){result.hit=true;result.impact=point;result.path.append(point);break;}
            }
            if(step<600&&!result.hit)result.path.append({px/1000,py/1000});
            vy+=350;
        }
        if(result.hit){
            const auto impact=result.impact;
            std::array<int,2> oldFloor{floor(x(0)),floor(x(1))};
            for(int p=0;p<2;++p){
                const int dx=x(p)-impact.x(),dy=oldFloor[p]-21-impact.y();
                const int distance=sqrtInt(dx*dx+dy*dy);
                hp[p]-=std::max(0,72-distance);
            }
            constexpr int radius=44;
            for(int i=0;i<Samples;++i){const int dx=i*5-impact.x();
                if(std::abs(dx)<radius)ground[i]=std::clamp(std::max(ground[i],impact.y()+sqrtInt(radius*radius-dx*dx)),0,Height-12);
            }
            for(int p=0;p<2;++p){hp[p]-=std::max(0,floor(x(p))-oldFloor[p]-18)/2;hp[p]=std::clamp(hp[p],0,100);}
        }
        ++ply;turn=1-turn;
        if(hp[0]==0||hp[1]==0)winner=hp[0]==hp[1]?2:hp[0]>0?0:1;
        else if(ply>=60)winner=2;
        return result;
    }
    QString digest() const {
        QJsonArray terrain;for(auto h:ground)terrain.append(h);
        const QJsonObject state{{"seed",QString::number(seed)},{"ground",terrain},{"hp",QJsonArray{hp[0],hp[1]}},{"turn",turn},{"ply",ply},{"winner",winner}};
        return QString::fromLatin1(QCryptographicHash::hash(QJsonDocument(state).toJson(QJsonDocument::Compact),QCryptographicHash::Sha256).toHex());
    }
};
