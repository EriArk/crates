// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QJsonObject>
#include <QHash>

// Optional Platform SDK v1 consumer. Owns discovery/auth/framing/credit, not gameplay.
class Bridge final:public QObject {
    Q_OBJECT
public:
    explicit Bridge(QString endpoint={},QObject* parent=nullptr);
    ~Bridge() override;
    QString peerMember() const {return peer_;}
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
    void avatarRecord(QJsonObject value);
    void closed();
private:
    QTcpSocket socket_;
    QTimer deadline_;
    QString endpoint_,token_,channel_,peer_;
    QHash<QString,QString> pending_;
    QByteArray input_;
    quint64 request_=0,receiveSequence_=0;
    bool registered_=false,closing_=false;
    void call(const QString& method,const QJsonObject& args={});
    void receive();
    void packet(const QJsonObject& value);
    void fail(const QString& reason);
};
