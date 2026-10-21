// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include "Model.h"
class TimerTests : public QObject {
    Q_OBJECT
private slots:
    void manualPauseAndReminder(){
        TimerModel m;m.reminderMinutes=15;m.nextReminder();m.activate();m.advance(900000);
        QVERIFY(m.due());m.activate();QVERIFY(m.running);QVERIFY(!m.due());
        m.activate();m.advance(10000);QCOMPARE(m.elapsed,900000);m.reset();QCOMPARE(m.elapsed,0);QVERIFY(!m.running);
    }
    void followsLiveSessionNotSelection(){
        TimerModel m;m.followGame=true;
        m.game({{"id","selected-only"},{"state","preparing"}});m.advance(2000);QCOMPARE(m.elapsed,0);
        QJsonObject game{{"state","running"},{"session","one"},{"minimized",false}};
        m.game(game);m.advance(1000);QCOMPARE(m.elapsed,1000);
        game["minimized"]=true;m.game(game);m.advance(1000);QCOMPARE(m.elapsed,1000);
        game["minimized"]=false;m.game(game);QVERIFY(m.running);
        m.activate();m.game(game);QVERIFY(!m.running);
        game["session"]="two";m.game(game);QVERIFY(m.running);QCOMPARE(m.elapsed,0);
        game["state"]="idle";m.game(game);QVERIFY(!m.running);
    }
    void restartDoesNotInventElapsedTime(){
        TimerModel m;m.followGame=true;m.reminderMinutes=30;
        QJsonObject game{{"state","running"},{"session","one"}};m.game(game);m.advance(12345);
        TimerModel restored;QVERIFY(restored.load(m.save()));QCOMPARE(restored.elapsed,12345);QVERIFY(!restored.running);
        restored.game(game);QVERIFY(!restored.running);restored.activate();QVERIFY(restored.running);
        auto corrupt=m.save();corrupt["elapsedMs"]=-1;QVERIFY(!restored.load(corrupt));QCOMPARE(restored.elapsed,12345);
    }
};
QTEST_GUILESS_MAIN(TimerTests)
#include "TimerTests.moc"
