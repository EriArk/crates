// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QJsonObject>
#include <QString>

// Elapsed intervals are supplied by the live process, never inferred from a save timestamp.
struct TimerModel {
    qint64 elapsed = 0, reminderAt = 0;
    int reminderMinutes = 0;
    bool running = false, followGame = false, pausedByUser = false, gameRunning = false;
    QString session;
    bool due() const { return reminderMinutes > 0 && elapsed >= reminderAt; }
    void nextReminder() { reminderAt = elapsed + qint64(reminderMinutes) * 60000; }
    void advance(qint64 milliseconds) {
        if (running && milliseconds > 0) elapsed += milliseconds;
    }
    void activate() {
        if (due()) { nextReminder(); return; }
        pausedByUser = running;
        running = !running && (!followGame || gameRunning);
    }
    void reset() { elapsed = 0; running = false; pausedByUser = true; nextReminder(); }
    void game(const QJsonObject& value) {
        const auto next = value["session"].toString();
        gameRunning = value["state"] == "running" && !value["minimized"].toBool() && !next.isEmpty();
        if (!followGame) return;
        if (!next.isEmpty() && next != session && value["state"] == "running") {
            elapsed = 0; pausedByUser = false; nextReminder(); session = next;
        }
        running = gameRunning && !pausedByUser;
    }
    QJsonObject save() const {
        return {{"schema",1},{"elapsedMs",double(elapsed)},{"reminderAtMs",double(reminderAt)},
            {"reminderMinutes",reminderMinutes},{"followGame",followGame},{"session",session}};
    }
    bool load(const QJsonObject& data) {
        const double ms=data["elapsedMs"].toDouble(-1), at=data["reminderAtMs"].toDouble(-1);
        const int minutes=data["reminderMinutes"].toInt(-1);
        if(data["schema"]!=1 || ms<0 || ms>315360000000.0 || at<0 || at>315364000000.0
            || (minutes!=0 && minutes!=15 && minutes!=30 && minutes!=45 && minutes!=60)
            || !data["followGame"].isBool() || !data["session"].isString() || data["session"].toString().size()>128) return false;
        elapsed=qint64(ms); reminderAt=qint64(at); reminderMinutes=minutes;
        followGame=data["followGame"].toBool(); session=data["session"].toString();
        running=false; pausedByUser=true; gameRunning=false;
        return true;
    }
};
