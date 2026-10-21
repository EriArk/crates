// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Rules.h"
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QJsonObject>
#include <QHash>

// Optional Platform SDK v1 consumer. Owns discovery/auth/framing/credit, not gameplay.
class ArcadeBridge final:public QObject {
    Q_OBJECT
public:
    explicit ArcadeBridge(arcade::Identity identity,QString endpoint={},QObject* parent=nullptr);
    ~ArcadeBridge() override;
    void connectHost();
    void openLobby();
    void closeChannel();
    void disconnectHost();
    bool send(const QJsonObject& record);
    bool registered() const{return registered_;}
    QString channel() const{return channel_;}
signals:
    void status(QString text);
    void ready(bool host);
    void record(QJsonObject value);
    void closed();
private:
    arcade::Identity identity_;
    QTcpSocket socket_;
    QTimer deadline_;
    QString endpoint_,token_,channel_;
    struct Request {QString method,channel;};
    QHash<QString,Request> pending_;
    QByteArray input_;
    quint64 request_=0,receiveSequence_=0;
    bool registered_=false,closing_=false;
    void call(const QString& method,const QJsonObject& args={});
    void receive();
    void packet(const QJsonObject& value);
    void fail(const QString& reason);
};
