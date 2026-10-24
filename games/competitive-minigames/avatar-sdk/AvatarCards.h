// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QUrl>
#include <QVariantMap>
#include <functional>

// Optional avatar consumer, independent of game registration and local play.
// The caller binds sendRecord to its admitted reliable channel and feeds only
// authenticated peer records. Never send descriptors or filesystem paths.
class AvatarCards final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap local READ local NOTIFY changed)
    Q_PROPERTY(QVariantMap peer READ peer NOTIFY changed)
public:
    explicit AvatarCards(QString app, QString endpoint={}, QObject* parent=nullptr)
        :QObject(parent),app_(app),endpoint_(endpoint) {
        connect(&socket_,&QTcpSocket::connected,this,[this]{request("hello",{{"protocol",1},{"token",token_},{"app",app_}});token_.clear();});
        connect(&socket_,&QTcpSocket::readyRead,this,&AvatarCards::read);
        connect(&socket_,&QTcpSocket::disconnected,this,&AvatarCards::stop);
        connect(&socket_,&QTcpSocket::errorOccurred,this,[this](auto){stop();});
        timer_.setInterval(100);
        connect(&timer_,&QTimer::timeout,this,[this]{
            for(const auto& p:pending_)if(clock_.elapsed()>p.deadline){stop();return;}
            if(connecting_&&clock_.elapsed()>5000){stop();return;}
            if(!member_.isEmpty()&&sendPending_&&sendRecord&&sendRecord({{"namespace","traineros.avatar.v1"},{"recipe",recipe_}}))sendPending_=false;
            if(!member_.isEmpty()&&!queued_.isEmpty()&&inFlight_.isEmpty()&&recipeCap_&&clock_.elapsed()>=retryAt_){
                inFlight_=QString::number(generation_);request("avatar.resolve",{{"recipe",queued_}});queued_={};retryAt_=clock_.elapsed()+1000;
            }
        });
    }
    ~AvatarCards() override {socket_.disconnect(this);socket_.abort();}
    QVariantMap local() const{return local_;}
    QVariantMap peer() const{return peer_;}
    std::function<bool(const QJsonObject&)> sendRecord;
    void start(){
        if(socket_.state()!=QAbstractSocket::UnconnectedState)return;
        QString path=endpoint_.isEmpty()?qEnvironmentVariable("TRAINEROS_SDK_ENDPOINT"):endpoint_;
        if(path.isEmpty())path=QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)+"/traineros/platform-v1/endpoint.json";
        QFile f(path);if(!f.open(QIODevice::ReadOnly)||f.size()>65536)return;
        const auto d=QJsonDocument::fromJson(f.readAll()).object();int port=d["port"].toInt();
        if(d["protocol"]!=1||d["host"]!="127.0.0.1"||port<1||port>65535||d["token"].toString().isEmpty())return;
        clock_.start();timer_.start();token_=d["token"].toString();connecting_=true;socket_.connectToHost(QHostAddress::LocalHost,quint16(port));
    }
    void session(QString member){clearPeer();member_=member;sendPending_=true;}
    void clearPeer(){++generation_;member_.clear();queued_={};received_.clear();peer_={};emit changed();}
    void receive(const QJsonObject& value){
        if(member_.isEmpty()||value["namespace"]!="traineros.avatar.v1"||!value["recipe"].isObject()||QJsonDocument(value).toJson(QJsonDocument::Compact).size()>2048)return;
        auto recipe=value["recipe"].toObject();auto bytes=QJsonDocument(recipe).toJson(QJsonDocument::Compact);
        if(bytes==received_)return;
        received_=bytes;++generation_;queued_=recipe;peer_={};emit changed();
    }
signals:
    void changed();
private:
    struct Pending {QString method; qint64 deadline;};
    QTcpSocket socket_;QTimer timer_;QElapsedTimer clock_;
    QString app_,endpoint_,token_,profile_,member_,inFlight_;
    QByteArray input_,received_;QHash<QString,Pending> pending_;
    QVariantMap local_,peer_;QJsonObject recipe_,queued_;
    quint64 serial_=0,generation_=0;qint64 retryAt_=0;
    bool connecting_=false,recipeCap_=false,sendPending_=false,stopping_=false;
    void stop(){
        if(stopping_)return;stopping_=true;
        if(!member_.isEmpty()&&sendRecord)sendRecord({{"namespace","traineros.avatar.v1"},{"recipe",QJsonObject{}}});
        socket_.abort();pending_.clear();input_.clear();token_.clear();profile_.clear();inFlight_.clear();recipeCap_=false;connecting_=false;
        local_={};recipe_={};clearPeer();sendPending_=true;timer_.stop();stopping_=false;
    }
    void request(QString method,QJsonObject params={}){
        auto id=QString::number(++serial_);pending_[id]={method,clock_.elapsed()+(method=="avatar.resolve"?30000:5000)};
        socket_.write(QJsonDocument(QJsonObject{{"id",id},{"method",method},{"params",params}}).toJson(QJsonDocument::Compact)+'\n');
    }
    static QVariantMap descriptor(const QJsonObject& d){
        const auto path=d["glb"].toString();QFile file(path);
        if(d["schema"]!=1||d["rig"]!="trainer-humanoid-54-v1"||!QFileInfo(path).isAbsolute()||!path.endsWith(".glb")||!file.open(QIODevice::ReadOnly)||file.size()>67108864)return {};
        if(QString::fromLatin1(QCryptographicHash::hash(file.readAll(),QCryptographicHash::Sha256).toHex())!=d["sha256"].toString())return {};
        auto preview=d["preview"].toString();
        if(!QFileInfo(preview).isAbsolute()||!preview.endsWith(".glb")||!QFileInfo(preview).isFile()||QFileInfo(preview).size()>67108864)preview=path;
        auto result=d.toVariantMap();result["source"]=QUrl::fromLocalFile(preview);return result;
    }
    void appearance(const QJsonObject& d){
        if(d["profile"].toString()!=profile_){stop();return;}
        local_=descriptor(d);recipe_=local_.isEmpty()?QJsonObject{}:d["recipe"].toObject();sendPending_=true;emit changed();
    }
    void read(){
        input_+=socket_.readAll();if(input_.size()>262144){stop();return;}
        while(input_.contains('\n')){
            auto n=input_.indexOf('\n');if(n>=65536){stop();return;}
            QJsonParseError error;auto doc=QJsonDocument::fromJson(input_.left(n),&error);input_.remove(0,n+1);
            if(error.error!=QJsonParseError::NoError||!doc.isObject()){stop();return;}
            auto p=doc.object();auto event=p["event"].toString();
            if(!event.isEmpty()){
                if(event=="context.revoked"||event=="host.stopping"){stop();return;}
                if(event=="avatar.changed")appearance(p["avatar"].toObject());
                continue;
            }
            auto id=p["id"].toString();if(!pending_.contains(id)){stop();return;}
            auto method=pending_.take(id).method;auto result=p["result"].toObject();
            if(method=="avatar.resolve"){
                auto generation=inFlight_;inFlight_.clear();
                if(generation==QString::number(generation_)&&!member_.isEmpty()){
                    peer_=p.contains("error")?QVariantMap{}:descriptor(result["avatar"].toObject());emit changed();
                }continue;
            }
            if(p.contains("error")){
                if(method=="avatar.subscribe"&&p["error"].toObject()["code"]=="avatar_not_ready")continue;
                stop();return;
            }
            if(method=="hello"){
                connecting_=false;auto caps=result["capabilities"].toObject();profile_=result["context"].toObject()["profile"].toString();recipeCap_=caps["avatar.recipe"]==1;
                if(caps["avatar.local"]!=1||profile_.isEmpty()){stop();return;}request("avatar.subscribe");
            }else if(method=="avatar.subscribe")appearance(result["avatar"].toObject());
        }
        if(input_.size()>=65536)stop();
    }
};
