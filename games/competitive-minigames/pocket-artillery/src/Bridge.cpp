// SPDX-License-Identifier: GPL-3.0-or-later
#include "Bridge.h"
#include <QFile>
#include <QStandardPaths>
#include <QJsonDocument>

Bridge::Bridge(QString endpoint,QObject* parent):QObject(parent),endpoint_(endpoint){
    if(endpoint_.isEmpty())endpoint_=qEnvironmentVariable("TRAINEROS_SDK_ENDPOINT");
    if(endpoint_.isEmpty())endpoint_=QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)+"/traineros/platform-v1/endpoint.json";
    connect(&socket_,&QTcpSocket::connected,this,[this]{call("hello",{{"protocol",1},{"token",token_},{"app","art.abysstail.pocket-artillery"}});token_.clear();});
    connect(&socket_,&QTcpSocket::readyRead,this,&Bridge::receive);
    connect(&socket_,&QTcpSocket::disconnected,this,[this]{if(!closing_)fail("TrainerOS disconnected. Local play is available.");});
    connect(&socket_,&QTcpSocket::errorOccurred,this,[this](auto){if(!closing_)fail("Open TrainerOS to play with a friend.");});
    deadline_.setSingleShot(true);deadline_.setInterval(5000);
    connect(&deadline_,&QTimer::timeout,this,[this]{fail("TrainerOS did not respond. Reconnect to try again.");});
}
Bridge::~Bridge(){
    // QTcpSocket emits disconnected during destruction. Stop callbacks before
    // the buffers and request map (declared after it) are destroyed.
    closing_=true;socket_.disconnect(this);socket_.abort();
}
void Bridge::connectHost(){
    if(registered_){openLobby();return;}
    disconnectHost();
    QFile file(endpoint_);
    if(!file.open(QIODevice::ReadOnly)||file.size()>65536){fail("Open TrainerOS to play with a friend.");return;}
    const auto info=QJsonDocument::fromJson(file.readAll()).object();const int port=info["port"].toInt();
    if(info["protocol"]!=1||info["host"]!="127.0.0.1"||port<1||port>65535||info["token"].toString().isEmpty()){fail("TrainerOS discovery is unavailable.");return;}
    closing_=false;token_=info["token"].toString();deadline_.start();socket_.connectToHost(QHostAddress::LocalHost,quint16(port));
    emit status("Connecting to TrainerOS…");
}
void Bridge::disconnectHost(){
    closing_=true;deadline_.stop();socket_.abort();pending_.clear();input_.clear();token_.clear();registered_=false;
    if(!channel_.isEmpty()){channel_.clear();emit closed();}
}
void Bridge::fail(const QString& reason){
    const bool hadChannel=!channel_.isEmpty();
    disconnectHost();
    if(!hadChannel)emit closed();
    emit status(reason);
}
void Bridge::call(const QString& method,const QJsonObject& args){
    const auto id=QString::number(++request_);pending_[id]=method;
    if(!deadline_.isActive())deadline_.start();
    socket_.write(QJsonDocument(QJsonObject{{"id",id},{"method",method},{"params",args}}).toJson(QJsonDocument::Compact)+'\n');
}
void Bridge::openLobby(){if(registered_)call("activity.open");}
void Bridge::closeChannel(){if(!channel_.isEmpty()){call("network.close",{{"channel",channel_}});channel_.clear();emit closed();}}
bool Bridge::send(const QJsonObject& record){
    if(channel_.isEmpty()||pending_.size()>32)return false;
    const auto bytes=QJsonDocument(record).toJson(QJsonDocument::Compact);
    if(bytes.size()>16384)return false;
    call("network.send",{{"channel",channel_},{"data",QString::fromLatin1(bytes.toBase64())}});return true;
}
void Bridge::receive(){
    input_+=socket_.readAll();if(input_.size()>262144){fail("Invalid TrainerOS frame.");return;}
    while(input_.contains('\n')){
        const auto end=input_.indexOf('\n');if(end>=65536){fail("Invalid TrainerOS frame.");return;}
        auto line=input_.left(end);input_.remove(0,end+1);QJsonParseError error;
        const auto doc=QJsonDocument::fromJson(line,&error);
        if(error.error!=QJsonParseError::NoError||!doc.isObject()){fail("Invalid TrainerOS response.");return;}
        packet(doc.object());if(closing_)return;
    }
}
void Bridge::packet(const QJsonObject& value){
    const auto event=value["event"].toString();
    if(!event.isEmpty()){
        if(event=="host.stopping"||event=="context.revoked"){fail("Trainer changed or TrainerOS closed. Reconnect to continue.");return;}
        if(event=="network.ready"){
            const auto s=value["session"].toObject();
            if(!channel_.isEmpty()||s["protocol"]!="pocket-artillery.1"||s["delivery"]!="reliable-ordered"||s["channel"].toString().isEmpty()){fail("Incompatible game session.");return;}
            if(!s["host"].isBool()){fail("Invalid game role.");return;}
            channel_=s["channel"].toString();receiveSequence_=0;emit ready(s["host"].toBool());return;
        }
        if(event=="network.closed"){
            if(value["channel"]==channel_){channel_.clear();emit closed();emit status("Match disconnected. Your Lobby is still available.");}return;
        }
        if(event=="network.data"){
            if(channel_.isEmpty()||value["channel"]!=channel_)return;
            const auto seq=value["sequence"].toString();
            if(seq!=QString::number(receiveSequence_++)){fail("Game record arrived out of order.");return;}
            const auto bytes=QByteArray::fromBase64(value["data"].toString().toLatin1(),QByteArray::AbortOnBase64DecodingErrors);
            QJsonParseError error;const auto doc=QJsonDocument::fromJson(bytes,&error);
            if(bytes.size()>16384||error.error!=QJsonParseError::NoError||!doc.isObject()){fail("Invalid game record.");return;}
            const auto channel=channel_;emit record(doc.object());
            // Consumption acknowledges validation, not animation or delivery of a reply.
            if(channel_==channel)call("network.consume",{{"channel",channel},{"sequence",seq}});
        }
        return;
    }
    const auto id=value["id"].toString();if(!pending_.contains(id)){fail("Unexpected TrainerOS response.");return;}
    const auto method=pending_.take(id);if(pending_.isEmpty())deadline_.stop();
    if(value.contains("error")){fail("TrainerOS: "+value["error"].toObject()["code"].toString()+". Reconnect to try again.");return;}
    const auto result=value["result"].toObject();
    if(method=="hello"){
        const auto caps=result["capabilities"].toObject();
        if(result["protocol"]!=1||caps["lobby.activity"]!=1||caps["network.records"]!=1){fail("This TrainerOS build needs native game networking support.");return;}
        call("activity.register",{{"title","Pocket Artillery"},{"protocol","pocket-artillery.1"}});
    }else if(method=="activity.register"){
        registered_=true;emit status("Both players: open Pocket Artillery, choose it in Lobby, Ready, then host starts.");openLobby();
    }
}
