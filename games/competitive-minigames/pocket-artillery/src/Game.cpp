// SPDX-License-Identifier: GPL-3.0-or-later
#include "Game.h"
#include <QRandomGenerator>

Game::Game(QString endpoint,QObject* parent):QObject(parent),bridge_(endpoint),avatars_("art.abysstail.pocket-artillery.avatar",endpoint){
    avatars_.sendRecord=[this](const QJsonObject& r){return bridge_.send(r);};
    connect(&bridge_,&Bridge::ready,&avatars_,[this](bool){avatars_.session(bridge_.peerMember());});
    connect(&bridge_,&Bridge::closed,&avatars_,&AvatarCards::clearPeer);
    connect(&bridge_,&Bridge::avatarRecord,&avatars_,&AvatarCards::receive);

    connect(&bridge_,&Bridge::status,this,[this](QString text){connection_=text;emit changed();});
    connect(&bridge_,&Bridge::closed,this,[this]{if(online_){flight_.stop();handshake_.stop();phase_="menu";online_=false;sync_.clear();emit changed();}});
    connect(&bridge_,&Bridge::ready,this,[this](bool host){
        if(phase_!="menu"){bridge_.closeChannel();return;}
        online_=true;phase_="waiting";
        host_=host;seat_=host?0:1;round_=0;sync_="start";handshake_.start();
        if(host_)startRound(QRandomGenerator::global()->generate());
    });
    connect(&bridge_,&Bridge::record,this,&Game::receive);
    handshake_.setSingleShot(true);handshake_.setInterval(10000);
    connect(&handshake_,&QTimer::timeout,this,[this]{bridge_.closeChannel();connection_="The other game did not finish connecting. Start again from Lobby.";phase_="menu";online_=false;emit changed();});
    flight_.setInterval(24);
    flight_.setTimerType(Qt::PreciseTimer);
    connect(&flight_,&QTimer::timeout,this,[this]{++frame_;if(frame_>=shot_.path.size()+42)finishFlight();else emit changed();});
}
QString Game::message() const{
    if(phase_=="menu")return "Small tanks. Big craters.";
    if(phase_=="waiting")return "Preparing your match...";
    if(phase_=="result")return world_.winner==2?"A draw — one more round?":QString("%1 wins the duel!").arg(world_.winner==0?"Mint":"Coral");
    if(phase_=="flight")return frame_<shot_.path.size()?"Shell in flight…":shot_.hit?"Impact!":"Shot wide";
    if(phase_=="handoff")return QString("Pass the controls to %1").arg(world_.turn==0?"Mint":"Coral");
    if(online_)return world_.turn==seat_?"Your turn — line up a shot":"Your friend is aiming…";
    return QString("%1's turn — line up a shot").arg(world_.turn==0?"Mint":"Coral");
}
QVariantMap Game::scene() const{
    const bool airborne=phase_=="flight"&&frame_<shot_.path.size();
    const auto& w=airborne?display_:world_;
    QVariantList terrain;for(auto y:w.ground)terrain.append(y);
    QVariantList trail;
    const int count=phase_=="flight"?std::min(frame_+1,int(shot_.path.size())):int(shot_.path.size());
    for(int i=0;i<count;i+=2)trail.append(QVariantMap{{"x",shot_.path[i].x()},{"y",shot_.path[i].y()}});
    const QPoint shell=shot_.path.isEmpty()?QPoint(-100,-100):shot_.path[std::min(frame_,int(shot_.path.size())-1)];
    int arcTop=-20;for(const auto& point:shot_.path)arcTop=std::min(arcTop,point.y()-35);
    return {{"terrain",terrain},{"hp0",w.hp[0]},{"hp1",w.hp[1]},{"y0",w.floor(120)},{"y1",w.floor(840)},
        {"turn",world_.turn},{"ply",world_.ply},{"trail",trail},{"shellX",shell.x()},{"shellY",shell.y()},
        {"shooter",display_.turn},{"shotAngle",shotAngle_},{"shotPower",shotPower_},{"flightFrame",frame_},
        {"muzzleY",display_.floor(World::x(display_.turn))},{"damage0",display_.hp[0]-world_.hp[0]},{"damage1",display_.hp[1]-world_.hp[1]},
        {"arcTop",arcTop},{"impactX",shot_.impact.x()},{"impactY",shot_.impact.y()},{"hit",shot_.hit},{"round",round_},{"impactAge",phase_=="flight"?std::max(-1,frame_-int(shot_.path.size())):-1}};
}
void Game::local(){bridge_.disconnectHost();online_=false;round_=0;startRound(QRandomGenerator::global()->generate());}
void Game::attach(){avatars_.start();if(phase_=="menu")bridge_.connectHost();}
void Game::leave(){flight_.stop();handshake_.stop();bridge_.closeChannel();phase_="menu";online_=false;sync_.clear();shot_={};emit changed();attach();}
void Game::aim(int delta){if(canFire()){angle_=std::clamp(angle_+delta*5,10,80);emit changed();}}
void Game::charge(int delta){if(canFire()){power_=std::clamp(power_+delta*5,20,100);emit changed();}}
void Game::acceptTurn(){if(phase_=="handoff"){phase_="aim";emit changed();}}
bool Game::send(QJsonObject record){
    record["round"]=round_;
    if(bridge_.send(record))return true;
    invalid();return false;
}
void Game::invalid(){
    bridge_.closeChannel();flight_.stop();handshake_.stop();online_=false;phase_="menu";sync_.clear();
    connection_="The match could not stay in sync. Return to Lobby for a fresh duel.";emit changed();
}
void Game::startRound(quint32 seed){
    ++round_;world_=World(seed);world_.turn=(round_-1)%2;display_=world_;shot_={};angle_=45;power_=85;
    localVote_=peerVote_=false;flight_.stop();
    if(online_){
        sync_="ready";phase_="waiting";handshake_.start();
        if(!send({{"type","start"},{"seed",QString::number(seed)},{"hash",world_.digest()}}))return;
    }else phase_="handoff";
    emit changed();
}
void Game::begin(){sync_.clear();handshake_.stop();phase_="aim";emit changed();}
void Game::animate(const World& before,const World::Shot& shot,int angle,int power){display_=before;shot_=shot;shotAngle_=angle;shotPower_=power;frame_=0;phase_="flight";flight_.start();emit changed();}
void Game::finishFlight(){flight_.stop();display_=world_;phase_=world_.winner!=-1?"result":online_?"aim":"handoff";emit changed();}
void Game::fire(){
    if(!canFire())return;
    const auto before=world_;const auto shot=world_.fire(angle_,power_);
    if(online_&&!send({{"type","shot"},{"ply",before.ply},{"angle",angle_},{"power",power_},{"before",before.digest()},{"after",world_.digest()}}))return;
    animate(before,shot,angle_,power_);
}
void Game::rematch(){
    if(phase_!="result"||localVote_)return;
    if(!online_){startRound(QRandomGenerator::global()->generate());return;}
    localVote_=true;
    if(!send({{"type","rematch"},{"hash",world_.digest()}}))return;
    if(host_&&peerVote_)startRound(QRandomGenerator::global()->generate());
    emit changed();
}
void Game::receive(const QJsonObject& r){
    if(!online_){invalid();return;}
    const auto type=r["type"].toString();
    if(type=="start"){
        bool ok=false;const auto seed=r["seed"].toString().toULongLong(&ok);
        if(host_||!ok||seed>0xffffffffULL||r["round"]!=round_+1||!(sync_=="start"||(world_.winner!=-1&&localVote_&&peerVote_))){invalid();return;}
        round_++;world_=World(quint32(seed));world_.turn=(round_-1)%2;display_=world_;shot_={};flight_.stop();angle_=45;power_=85;
        localVote_=peerVote_=false;phase_="waiting";sync_="begin";handshake_.start();
        if(r["hash"]!=world_.digest()){invalid();return;}
        send({{"type","ready"},{"hash",world_.digest()}});emit changed();return;
    }
    if(r["round"]!=round_){invalid();return;}
    if(type=="ready"&&host_&&sync_=="ready"&&r["hash"]==world_.digest()){
        if(send({{"type","begin"},{"hash",world_.digest()}}))begin();return;
    }
    if(type=="begin"&&!host_&&sync_=="begin"&&r["hash"]==world_.digest()){begin();return;}
    if(type=="shot"&&sync_.isEmpty()&&(phase_=="aim"||phase_=="flight")&&world_.winner==-1&&world_.turn!=seat_){
        const int angle=r["angle"].toInt(-1),power=r["power"].toInt(-1);
        if(r["angle"]!=angle||r["power"]!=power||r["ply"]!=world_.ply||!World::valid(angle,power)||r["before"]!=world_.digest()){invalid();return;}
        auto next=world_;const auto shot=next.fire(angle,power);
        if(r["after"]!=next.digest()){invalid();return;}
        const auto before=world_;world_=next;animate(before,shot,angle,power);return;
    }
    if(type=="rematch"&&world_.winner!=-1&&!peerVote_&&sync_.isEmpty()&&r["hash"]==world_.digest()){
        peerVote_=true;if(host_&&localVote_)startRound(QRandomGenerator::global()->generate());emit changed();return;
    }
    invalid();
}
