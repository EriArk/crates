// SPDX-License-Identifier: GPL-3.0-or-later
#include "MinesRules.h"
namespace arcade {
QVector<int> MinesRules::neighbors(int cell){QVector<int> result;for(int dy=-1;dy<=1;++dy)for(int dx=-1;dx<=1;++dx){int x=cell%9+dx,y=cell/9+dy;if((dx||dy)&&x>=0&&x<9&&y>=0&&y<9)result.append(y*9+x);}return result;}
void MinesRules::reset(quint32 seed){
    resetBase();cursor={40,40};mines.fill(0);numbers.fill(0);auto safe=neighbors(40);safe.append(40);
    QVector<int> candidates;for(int i=0;i<81;++i)if(!safe.contains(i))candidates.append(i);
    for(int i=0;i<12;++i){int index=random(seed)%candidates.size();mines[candidates.takeAt(index)]=1;}
    for(int i=0;i<81;++i)for(int n:neighbors(i))numbers[i]+=mines[n];
    for(int p=0;p<2;++p){visible[p]=QVector<int>(81,-1);reveal(p,40);}
}
void MinesRules::reveal(int p,int cell){
    auto& v=visible[p];if(v[cell]!=-1)return;
    if(mines[cell]){v[cell]=-3;lost[p]=true;return;}
    QVector<int> queue{cell};while(!queue.isEmpty()){int c=queue.takeLast();if(v[c]!=-1||mines[c])continue;v[c]=numbers[c];++score[p];if(!numbers[c])for(int n:neighbors(c))if(v[n]==-1)queue.append(n);}
}
void MinesRules::move(int p,int d){int x=cursor[p]%9,y=cursor[p]/9;if(d==0)y=qMax(0,y-1);if(d==1)x=qMin(8,x+1);if(d==2)y=qMin(8,y+1);if(d==3)x=qMax(0,x-1);cursor[p]=y*9+x;}
void MinesRules::act(int p,int a){
    if(lost[p])return;int c=cursor[p];auto& v=visible[p];
    if(a==1){if(v[c]==-1)v[c]=-2;else if(v[c]==-2)v[c]=-1;return;}
    if(v[c]==-1)reveal(p,c);
    else if(v[c]>0){int flags=0;for(int n:neighbors(c))flags+=v[n]==-2;
        if(flags==v[c])for(int n:neighbors(c)){reveal(p,n);if(lost[p])break;}}
}
std::pair<int,int> MinesRules::choice(int p) const {
    // Only visible numbers/flags: the practice bot cannot inspect the mine map.
    const auto& v=visible[p];
    for(int c=0;c<81;++c)if(v[c]>=0){int flags=0;QVector<int> covered;for(int n:neighbors(c)){flags+=v[n]==-2;if(v[n]==-1)covered.append(n);}
        if(!covered.isEmpty()){if(flags==v[c])return {covered.first(),0};if(flags+covered.size()==v[c])return {covered.first(),1};}}
    for(int offset=0;offset<81;++offset){int c=(cursor[p]+offset)%81;if(v[c]==-1)return {c,0};}
    return {cursor[p],-1};
}
int MinesRules::bot(int p) const {if(tick<60||tick%6)return -1;auto [c,a]=choice(p);int here=cursor[p];return here%9<c%9?1:here%9>c%9?3:here/9<c/9?2:here/9>c/9?0:-1;}
int MinesRules::botAction(int p) const {if(tick<60||tick%24)return -1;auto [c,a]=choice(p);return c==cursor[p]?a:-1;}
QJsonObject MinesRules::view() const {
    auto s=base(9,9);QJsonArray list;for(int p=0;p<2;++p){auto cells=visible[p];if(winner>=0)for(int i=0;i<81;++i)if(mines[i]&&cells[i]!=-2)cells[i]=-3;
        int flags=0;for(int v:visible[p])flags+=v==-2;
        list.append(QJsonObject{{"cells",cellsJson(cells)},{"cursor",cursor[p]},{"flags",flags},{"lost",lost[p]}});}
    s["players"]=list;return s;
}
bool MinesRules::validView(const QJsonObject& s) const {if(!validBase(s,9,9))return false;for(auto value:s["players"].toArray()){auto p=value.toObject();if(!validCells(p["cells"],81,-3,8)||!integer(p["cursor"],0,80)||!integer(p["flags"],0,81)||!p["lost"].isBool())return false;}return true;}
}
