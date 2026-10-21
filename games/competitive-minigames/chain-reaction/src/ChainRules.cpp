// SPDX-License-Identifier: GPL-3.0-or-later
#include "ChainRules.h"
#include <algorithm>
namespace arcade {
QVector<int> ChainRules::matches(const QVector<int>& cells){
    QVector<int> found;for(int i=0;i<72;++i)if(cells[i]>0&&cells[i]<5){
        if(i%6<4&&cells[i]==cells[i+1]&&cells[i]==cells[i+2])for(int j=0;j<3;++j)if(!found.contains(i+j))found.append(i+j);
        if(i/6<10&&cells[i]==cells[i+6]&&cells[i]==cells[i+12])for(int j=0;j<3;++j)if(!found.contains(i+j*6))found.append(i+j*6);
    }return found;
}
void ChainRules::gravity(QVector<int>& cells){for(int x=0;x<6;++x){int bottom=11;for(int y=11;y>=0;--y)if(cells[y*6+x]){int v=cells[y*6+x];cells[y*6+x]=0;cells[bottom--*6+x]=v;}}}
void ChainRules::reset(quint32 seed){
    resetBase();for(int p=0;p<2;++p){players[p]=Player{};players[p].rng=seed?seed:1;for(int n=0;n<5;++n)row(p,false);players[p].cursor=57;}
}
void ChainRules::row(int p,bool garbage){
    auto& s=players[p];for(int x=0;x<6;++x)if(s.cells[x]){lost[p]=true;return;}
    for(int i=0;i<66;++i)s.cells[i]=s.cells[i+6];
    const int hole=garbage?int(random(s.rng)%6):-1;
    for(int x=0;x<6;++x){int v=1+random(s.rng)%4;if(!garbage){
        for(int tries=0;tries<4;++tries){if((x>=2&&s.cells[66+x-1]==v&&s.cells[66+x-2]==v)||(s.cells[60+x]==v&&s.cells[54+x]==v))v=v%4+1;else break;}}
        s.cells[66+x]=garbage?(x==hole?0:5):v;
    }s.cursor=qMax(s.cursor%6,s.cursor-6);
}
void ChainRules::move(int p,int d){auto& s=players[p];int x=s.cursor%6,y=s.cursor/6;if(d==0)y=qMax(0,y-1);if(d==1)x=qMin(4,x+1);if(d==2)y=qMin(11,y+1);if(d==3)x=qMax(0,x-1);s.cursor=y*6+x;}
void ChainRules::act(int p,int a){
    auto& s=players[p];if(lost[p]||s.delay)return;
    if(a==1){row(p,false);s.raise=0;return;}
    if(s.cells[s.cursor]!=5&&s.cells[s.cursor+1]!=5)std::swap(s.cells[s.cursor],s.cells[s.cursor+1]);
}
void ChainRules::advance(){
    std::array<int,2> attack{};
    for(int p=0;p<2;++p){auto& s=players[p];if(lost[p])continue;
        if(s.delay){if(--s.delay==0){auto remove=s.flash;for(int c:s.flash)for(int n:{c-6,c+6,c-1,c+1})if(n>=0&&n<72&&(std::abs(n-c)==6||n/6==c/6)&&s.cells[n]==5&&!remove.contains(n))remove.append(n);
            for(int c:remove)s.cells[c]=0;s.flash.clear();gravity(s.cells);}else continue;}
        gravity(s.cells);auto found=matches(s.cells);
        if(!found.isEmpty()){++s.chain;s.flash=found;s.delay=12;score[p]+=int(found.size())*10*s.chain;
            attack[p]=qMin(3,qMax(0,int(found.size())-3)/3+qMax(0,s.chain-1));continue;}
        s.chain=0;
        if(s.grace>0)--s.grace;
        if(s.incoming&&s.grace==0){row(p,true);--s.incoming;s.grace=30;}
        if(++s.raise>=240){row(p,false);s.raise=0;}
    }
    for(int p=0;p<2;++p)if(attack[p]){auto& other=players[1-p];other.incoming=qMin(12,other.incoming+attack[p]);other.grace=qMax(other.grace,60);}
}
std::pair<int,int> ChainRules::choice(int p) const {
    const auto& s=players[p];int best=0,target=s.cursor;
    for(int c=0;c<71;++c)if(c%6<5&&s.cells[c]!=5&&s.cells[c+1]!=5&&s.cells[c]!=s.cells[c+1]){auto cells=s.cells;std::swap(cells[c],cells[c+1]);gravity(cells);int gain=matches(cells).size();if(gain>best){best=gain;target=c;}}
    return {target,best?0:1};
}
int ChainRules::bot(int p) const {if(tick<60||tick%6||players[p].delay)return -1;auto [c,a]=choice(p);int here=players[p].cursor;return here%6<c%6?1:here%6>c%6?3:here/6<c/6?2:here/6>c/6?0:-1;}
int ChainRules::botAction(int p) const {if(tick<60||tick%30||players[p].delay)return -1;auto [c,a]=choice(p);return c==players[p].cursor?a:-1;}
QJsonObject ChainRules::view() const {auto s=base(6,12);QJsonArray list;for(int p=0;p<2;++p){const auto& v=players[p];list.append(QJsonObject{{"cells",cellsJson(v.cells)},{"flash",cellsJson(v.flash)},{"cursor",v.cursor},{"chain",v.chain},{"incoming",v.incoming},{"raise",v.raise},{"lost",lost[p]}});}s["players"]=list;return s;}
bool ChainRules::validView(const QJsonObject& s) const {if(!validBase(s,6,12))return false;for(auto value:s["players"].toArray()){auto p=value.toObject();if(!validCells(p["cells"],72,0,5)||!integer(p["cursor"],0,70)||p["cursor"].toInt()%6==5||!integer(p["chain"],0,72)||!integer(p["incoming"],0,12)||!integer(p["raise"],0,239)||!p["lost"].isBool()||!p["flash"].isArray()||p["flash"].toArray().size()>72)return false;for(auto c:p["flash"].toArray())if(!integer(c,0,71))return false;}return true;}
}
