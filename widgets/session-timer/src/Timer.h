// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "Model.h"
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QElapsedTimer>
#include <QLockFile>
#include <QJsonObject>
#include <QHash>
#include <memory>

class Timer final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString time READ time NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString action READ action NOTIFY changed)
    Q_PROPERTY(QString connection READ connection NOTIFY changed)
    Q_PROPERTY(QString reminder READ reminder NOTIFY changed)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(bool followGame READ followGame NOTIFY changed)
    Q_PROPERTY(bool breakDue READ breakDue NOTIFY changed)
public:
    explicit Timer(QString endpoint={}, QString storage={}, QObject* parent=nullptr);
    ~Timer() override;
    QString time() const;
    QString state() const;
    QString action() const;
    QString connection() const { return connection_; }
    QString reminder() const;
    bool ready() const { return ready_; }
    bool followGame() const { return model_.followGame; }
    bool breakDue() const { return model_.due(); }
    Q_INVOKABLE void connectHost();
    Q_INVOKABLE void activate();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void cycleReminder();
    Q_INVOKABLE void toggleMode();
    void shutdown();
signals:
    void changed();
private:
    QTcpSocket socket_;
    QTimer tick_, deadline_;
    QElapsedTimer clock_;
    QString endpoint_, storage_, owner_, stateFile_, connection_="Connecting to TrainerOS…", token_;
    QString revision_, lastWidget_, widgetRevision_;
    QByteArray input_;
    QJsonObject context_;
    QHash<QString,QString> pending_;
    TimerModel model_;
    std::unique_ptr<QLockFile> lock_;
    quint64 sequence_=0;
    qint64 lastSaved_=0;
    bool ready_=false, stopping_=false, writable_=false, widgetPending_=false;
    void receive();
    void packet(const QJsonObject& value);
    void call(const QString& method, const QJsonObject& args={});
    void applyContext(const QJsonObject& context);
    void disconnectHost(const QString& message);
    void refresh();
    bool persist();
    void step();
};
