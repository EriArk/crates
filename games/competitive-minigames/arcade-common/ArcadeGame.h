// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "ArcadeBridge.h"
#include <QElapsedTimer>
#include <QVariantMap>

class ArcadeGame final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString title READ title CONSTANT)
    Q_PROPERTY(QString slug READ slug CONSTANT)
    Q_PROPERTY(QString subtitle READ subtitle CONSTANT)
    Q_PROPERTY(QString instructions READ instructions CONSTANT)
    Q_PROPERTY(QString primaryAction READ primaryAction CONSTANT)
    Q_PROPERTY(QString secondaryAction READ secondaryAction CONSTANT)
    Q_PROPERTY(QString phase READ phase NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantMap scene READ scene NOTIFY changed)
    Q_PROPERTY(bool online READ online NOTIFY changed)
    Q_PROPERTY(bool couch READ couch NOTIFY changed)
    Q_PROPERTY(bool voted READ voted NOTIFY changed)
    Q_PROPERTY(int seat READ seat NOTIFY changed)
    Q_PROPERTY(QString result READ result NOTIFY changed)
public:
    explicit ArcadeGame(arcade::Kind kind,QString endpoint={},QObject* parent=nullptr);
    ~ArcadeGame() override;
    QString title() const{return identity_.title;}
    QString slug() const{return identity_.id;}
    QString subtitle() const{return identity_.subtitle;}
    QString instructions() const{return identity_.instructions;}
    QString primaryAction() const{return identity_.primary;}
    QString secondaryAction() const{return identity_.secondary;}
    QString phase() const{return phase_;}
    QString status() const{return status_;}
    QVariantMap scene() const{return view_.toVariantMap();}
    bool online() const{return online_;}
    bool couch() const{return couch_;}
    bool voted() const{return localVote_;}
    int seat() const{return seat_;}
    QString result() const;
    Q_INVOKABLE void local(bool couch=false);
    Q_INVOKABLE void join();
    Q_INVOKABLE void lobby();
    Q_INVOKABLE void leave();
    Q_INVOKABLE void rematch();
    Q_INVOKABLE void input(int player,int direction);
    Q_INVOKABLE void neutral();
    Q_INVOKABLE void pause(bool paused);
    // Device-facing input path: pad 0 owns the local seat; pad 1 is couch only.
    Q_INVOKABLE void control(int localPlayer,int direction);
    Q_INVOKABLE void action(int localPlayer,int action);
signals:
    void changed();
private:
    arcade::Identity identity_;
    std::unique_ptr<arcade::Rules> rules_;
    ArcadeBridge bridge_;
    QTimer clock_,deadline_,watchdog_;
    QElapsedTimer received_;
    QJsonObject view_;
    QString phase_="menu",status_="Play offline, or meet your friend in TrainerOS Lobby.",sync_;
    bool online_=false,couch_=false,host_=false,localVote_=false,peerVote_=false;
    int seat_=0,round_=0,inputSeq_=0,peerSeq_=0,lastInput_=-1;
    void tick();
    void startRound(quint32 seed);
    void begin();
    void receive(const QJsonObject& packet);
    bool send(QJsonObject packet);
    void fail(const QString& reason);
    void stopped();
};
