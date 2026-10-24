// SPDX-License-Identifier: GPL-3.0-or-later
#include "ArcadeGame.h"
#include <QRandomGenerator>
using namespace arcade;
ArcadeGame::ArcadeGame(Kind kind,QString endpoint,QObject* parent)
    :QObject(parent),identity_(identity(kind)),rules_(makeRules(kind)),bridge_(identity_,endpoint),avatars_("art.abysstail."+identity_.id+".avatar",endpoint){
    avatars_.sendRecord=[this](const QJsonObject& r){return bridge_.send(r);};
    connect(&bridge_,&ArcadeBridge::ready,&avatars_,[this](bool){avatars_.session(bridge_.peerMember());});
    connect(&bridge_,&ArcadeBridge::closed,&avatars_,&AvatarCards::clearPeer);
    connect(&bridge_,&ArcadeBridge::avatarRecord,&avatars_,&AvatarCards::receive);

    rules_->reset(1);view_=rules_->view();
    clock_.setInterval(33);clock_.setTimerType(Qt::PreciseTimer);
    connect(&clock_,&QTimer::timeout,this,&ArcadeGame::tick);
    deadline_.setSingleShot(true);deadline_.setInterval(10000);
    connect(&deadline_,&QTimer::timeout,this,[this]{fail("The other game did not finish connecting. Start again from Lobby.");});
    watchdog_.setInterval(1000);
    connect(&watchdog_,&QTimer::timeout,this,[this]{
        if(phase_!="play")return;
        if(received_.isValid()&&received_.elapsed()>5000){fail("The match stopped responding. Your Lobby is still available.");return;}
        if(!host_)send({{"type","alive"}});
    });
    connect(&bridge_,&ArcadeBridge::status,this,[this](const QString& text){status_=text;emit changed();});
    connect(&bridge_,&ArcadeBridge::closed,this,[this]{if(online_)stopped();});
    connect(&bridge_,&ArcadeBridge::ready,this,[this](bool host){
        if(phase_!="menu"){bridge_.closeChannel();return;}
        online_=true;couch_=false;phase_="waiting";
        host_=host;seat_=host?0:1;round_=0;sync_="start";deadline_.start();
        if(host_)startRound(QRandomGenerator::global()->generate());
    });
    connect(&bridge_,&ArcadeBridge::record,this,&ArcadeGame::receive);
}
ArcadeGame::~ArcadeGame(){bridge_.disconnect(this);}
QString ArcadeGame::result() const {
    const int winner=view_["winner"].toInt(-1);
    if(winner<0)return {};
    if(winner==2)return "A draw. One more?";
    if(online_)return winner==seat_?"You win!":"Your friend wins!";
    if(!couch_)return winner==0?"You win!":"The bot wins. Try again!";
    return winner==0?"Mint wins!":"Coral wins!";
}
void ArcadeGame::stopped(){
    clock_.stop();deadline_.stop();watchdog_.stop();phase_="menu";online_=false;sync_.clear();
    lastInput_=-1;emit changed();
}
void ArcadeGame::fail(const QString& reason){bridge_.closeChannel();stopped();status_=reason;emit changed();}
void ArcadeGame::local(bool couch){
    if(phase_!="menu")return;
    bridge_.disconnectHost();online_=false;couch_=couch;seat_=0;round_=0;
    startRound(QRandomGenerator::global()->generate());
}
void ArcadeGame::attach(){avatars_.start();if(phase_=="menu")bridge_.connectHost();}
void ArcadeGame::leave(){bridge_.closeChannel();stopped();attach();}
bool ArcadeGame::send(QJsonObject packet){
    packet["round"]=round_;
    if(bridge_.send(packet))return true;
    fail("The match could not send its update. Start again from Lobby.");return false;
}
void ArcadeGame::startRound(quint32 seed){
    ++round_;clock_.stop();watchdog_.stop();rules_->reset(seed);view_=rules_->view();
    localVote_=peerVote_=false;inputSeq_=peerSeq_=0;lastInput_=-1;
    if(online_){phase_="waiting";sync_="ready";deadline_.start();send({{"type","start"},{"seed",QString::number(seed)},{"state",view_}});}
    else begin();
    emit changed();
}
void ArcadeGame::begin(){
    sync_.clear();deadline_.stop();phase_="play";
    if(!online_||host_)clock_.start();
    if(online_){received_.start();watchdog_.start();}
    emit changed();
}
void ArcadeGame::tick(){
    if(phase_!="play")return;
    if(!online_&&!couch_){rules_->input(1,rules_->bot(1));rules_->action(1,rules_->botAction(1));}
    rules_->step();view_=rules_->view();
    const bool ended=view_["winner"].toInt()!=-1;
    if(online_&&(view_["tick"].toInt()%2==0||ended)){
        if(!send({{"type","state"},{"state",view_}}))return;
    }
    if(ended){phase_="result";clock_.stop();watchdog_.stop();}
    emit changed();
}
void ArcadeGame::input(int player,int direction){
    if(phase_!="play"||player<0||player>1||direction<-1||direction>3)return;
    if(!online_){if(player==0||couch_)rules_->input(player,direction);return;}
    if(player!=seat_||direction==lastInput_)return;
    lastInput_=direction;
    if(host_)rules_->input(0,direction);
    else send({{"type","input"},{"seq",inputSeq_++},{"direction",direction}});
}
void ArcadeGame::control(int player,int direction){
    if(player==0)input(online_?seat_:0,direction);
    else if(couch_)input(1,direction);
}
void ArcadeGame::neutral(){control(0,-1);control(1,-1);}
void ArcadeGame::action(int player,int action){
    if(phase_!="play"||identity_.primary.isEmpty()||action<0||action>1||player<0||player>1||(!couch_&&player!=0))return;
    if(!online_){rules_->action(player,action);return;}
    if(host_)rules_->action(0,action);
    else send({{"type","action"},{"seq",inputSeq_++},{"action",action}});
}
void ArcadeGame::pause(bool paused){
    neutral();
    if(online_)return;
    if(paused&&phase_=="play"){clock_.stop();phase_="paused";emit changed();}
    else if(!paused&&phase_=="paused"){phase_="play";clock_.start();emit changed();}
}
void ArcadeGame::rematch(){
    if(phase_!="result"||localVote_)return;
    if(!online_){startRound(QRandomGenerator::global()->generate());return;}
    localVote_=true;
    if(!send({{"type","rematch"}}))return;
    if(host_&&peerVote_)startRound(QRandomGenerator::global()->generate());
    emit changed();
}
void ArcadeGame::receive(const QJsonObject& p){
    auto invalid=[this]{fail("Incompatible match update. Return to Lobby for a fresh match.");};
    if(!online_){invalid();return;}
    const auto type=p["type"].toString();
    if(type=="start"){
        bool ok=false;const auto seed=p["seed"].toString().toULongLong(&ok);
        if(host_||!ok||seed>0xffffffffULL||p["round"]!=round_+1||!(sync_=="start"||(phase_=="result"&&localVote_&&peerVote_))){invalid();return;}
        rules_->reset(quint32(seed));
        if(p["state"]!=rules_->view()){invalid();return;}
        ++round_;view_=rules_->view();inputSeq_=peerSeq_=0;lastInput_=-1;localVote_=peerVote_=false;
        sync_="begin";phase_="waiting";deadline_.start();send({{"type","ready"}});emit changed();return;
    }
    if(p["round"]!=round_){invalid();return;}
    received_.restart();
    if(type=="ready"&&host_&&sync_=="ready"){if(send({{"type","begin"}}))begin();return;}
    if(type=="begin"&&!host_&&sync_=="begin"){begin();return;}
    // In-flight inputs/heartbeats may arrive just after the host ended the round.
    if(type=="alive"&&host_&&(phase_=="play"||phase_=="result"))return;
    if(type=="input"&&host_&&(phase_=="play"||phase_=="result")){
        if(p["seq"]!=peerSeq_++||!integer(p["direction"],-1,3)){invalid();return;}
        if(phase_=="play")rules_->input(1,p["direction"].toInt());return;
    }
    if(type=="action"&&host_&&(phase_=="play"||phase_=="result")&&!identity_.primary.isEmpty()){
        if(p["seq"]!=peerSeq_++||!integer(p["action"],0,1)){invalid();return;}
        if(phase_=="play")rules_->action(1,p["action"].toInt());return;
    }
    if(type=="state"&&!host_&&phase_=="play"){
        const auto next=p["state"].toObject();
        if(!rules_->validView(next)||next["tick"].toInt()<=view_["tick"].toInt()){invalid();return;}
        view_=next;
        if(view_["winner"].toInt()!=-1){phase_="result";watchdog_.stop();}
        emit changed();return;
    }
    if(type=="rematch"&&phase_=="result"&&!peerVote_){
        peerVote_=true;if(host_&&localVote_)startRound(QRandomGenerator::global()->generate());emit changed();return;
    }
    invalid();
}
