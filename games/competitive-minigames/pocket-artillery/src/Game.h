// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "AvatarCards.h"
#include "World.h"
#include "Bridge.h"
#include <QVariantList>

class Game final:public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* avatars READ avatars CONSTANT)
    Q_PROPERTY(QString phase READ phase NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(QString connection READ connection NOTIFY changed)
    Q_PROPERTY(bool online READ online NOTIFY changed)
    Q_PROPERTY(bool canFire READ canFire NOTIFY changed)
    Q_PROPERTY(bool voted READ voted NOTIFY changed)
    Q_PROPERTY(int seat READ seat NOTIFY changed)
    Q_PROPERTY(int angle READ angle NOTIFY changed)
    Q_PROPERTY(int power READ power NOTIFY changed)
    Q_PROPERTY(QVariantMap scene READ scene NOTIFY changed)
public:
    explicit Game(QString endpoint={},QObject* parent=nullptr);
    QString phase() const{return phase_;}
    QString message() const;
    QString connection() const{return connection_;}
    bool online() const{return online_;}
    bool voted() const{return localVote_;}
    bool canFire() const{return phase_=="aim"&&world_.winner==-1&&(!online_||world_.turn==seat_);}
    int seat() const{return seat_;}
    int angle() const{return angle_;}
    int power() const{return power_;}
    QVariantMap scene() const;
    const World& world() const{return world_;}
    Q_INVOKABLE void local();
    void attach();
    QObject* avatars(){return &avatars_;}
    Q_INVOKABLE void leave();
    Q_INVOKABLE void aim(int delta);
    Q_INVOKABLE void charge(int delta);
    Q_INVOKABLE void fire();
    Q_INVOKABLE void acceptTurn();
    Q_INVOKABLE void rematch();
signals:
    void changed();
private:
    Bridge bridge_;
    AvatarCards avatars_;
    World world_,display_;
    World::Shot shot_;
    QTimer flight_,handshake_;
    int frame_=0,angle_=45,power_=85,seat_=0,round_=0,shotAngle_=45,shotPower_=85;
    bool online_=false,host_=false,localVote_=false,peerVote_=false;
    QString phase_="menu",connection_="Play on one device, or invite a friend through TrainerOS.",sync_;
    void startRound(quint32 seed);
    void begin();
    void receive(const QJsonObject& record);
    bool send(QJsonObject record);
    void invalid();
    void animate(const World& before,const World::Shot& shot,int angle,int power);
    void finishFlight();
};
