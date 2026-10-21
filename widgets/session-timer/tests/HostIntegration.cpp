// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QProcess>
#include <QTemporaryDir>
#include <QSettings>
#include <QJsonDocument>
#include <QFile>
#include <QDirIterator>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include "Timer.h"
#include "platform/sdk/PlatformHost.h"
#include "features/device/ControlsDashboard.h"
using namespace trainer;
QString executable;
class HostIntegration:public QObject {
    Q_OBJECT
private slots:
    void windowControls(){
        QTemporaryDir temp;QVERIFY(temp.isValid());
        QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,temp.path());
        ControlsDashboard board;board.setOwner("controls");PlatformHost host(board);
        host.setContext({{"profile","controls"},{"game",QJsonObject{{"state","idle"}}}});
        const auto endpoint=temp.filePath("endpoint.json");QVERIFY(host.start(endpoint));
        Timer timer(endpoint,temp.filePath("data"));QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("timer",&timer);engine.load(QUrl("qrc:/ui/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);
        timer.connectHost();QTRY_VERIFY(timer.ready());
        QTest::keyClick(window,Qt::Key_Return);QCOMPARE(timer.state(),"Timer running");
        QTest::keyClick(window,Qt::Key_Return);QCOMPARE(timer.action(),"Start timer");
        QTest::keyClick(window,Qt::Key_Right);QTest::keyClick(window,Qt::Key_Return);QCOMPARE(timer.time(),"00:00:00");
        QTest::keyClick(window,Qt::Key_Right);QTest::keyClick(window,Qt::Key_Return);QVERIFY(timer.followGame());
        QTest::keyClick(window,Qt::Key_Right);QTest::keyClick(window,Qt::Key_Return);QCOMPARE(timer.reminder(),"Every 15 min");
        // Touch/mouse use the same QML action as keyboard/controller navigation.
        timer.toggleMode();window->setWidth(640);window->setHeight(400);QTest::qWait(100);
        QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,QPoint(100,260));
        QCOMPARE(timer.state(),"Timer running");
        QVERIFY(window->grabWindow().save("session-timer-640.png"));
        window->close();timer.shutdown();
    }
    void realExternalApp(){
        QTemporaryDir temp;QVERIFY(temp.isValid());
        QSettings::setDefaultFormat(QSettings::IniFormat);
        QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,temp.path());
        ControlsDashboard dashboard;dashboard.setOwner("alice");PlatformHost host(dashboard);
        host.setContext({{"profile","alice"},{"game",QJsonObject{{"state","idle"}}}});
        const auto endpoint=temp.filePath("endpoint.json"),data=temp.filePath("data");
        QVERIFY(host.start(endpoint));
        const auto key=QString("sdk:art.abysstail.session-timer:timer");
        QProcess app;auto env=QProcessEnvironment::systemEnvironment();
        env.insert("QT_QPA_PLATFORM","offscreen");env.insert("QT_QUICK_BACKEND","software");app.setProcessEnvironment(env);
        auto start=[&](bool screenshot){
            QStringList args{"--windowed","--endpoint",endpoint,"--data-dir",data};
            if(screenshot)args<<"--screenshot"<<QDir::current().filePath("session-timer.png");
            app.start(executable,args);return app.waitForStarted();
        };
        QVERIFY(start(true));
        QTRY_COMPARE_WITH_TIMEOUT(dashboard.available().size(),1,10000);
        dashboard.edit();dashboard.pick();dashboard.restore(key);dashboard.edit();dashboard.activate(key);
        QTRY_VERIFY(dashboard.widgets().first().toMap()["text"].toString().contains("Timer running"));
        QTRY_VERIFY(dashboard.widgets().first().toMap()["text"].toString().contains("00:00:01"));
        QTRY_COMPARE_WITH_TIMEOUT(app.state(),QProcess::NotRunning,10000);
        QVERIFY2(app.exitCode()==0,app.readAllStandardError().constData());
        QTRY_COMPARE(dashboard.pages(),1);
        QVERIFY(start(false));
        QTRY_COMPARE_WITH_TIMEOUT(dashboard.pages(),2,10000);
        dashboard.changePage(1);
        const auto text=dashboard.widgets().first().toMap()["text"].toString();
        QVERIFY2(text.contains("Paused"),qPrintable(text));QVERIFY(!text.contains("00:00:00"));
        dashboard.activate(key);QTRY_VERIFY(dashboard.widgets().first().toMap()["text"].toString().contains("Timer running"));
        // New owner revokes this process, never silently adopts it.
        dashboard.setOwner("bob");host.setContext({{"profile","bob"},{"game",QJsonObject{{"state","idle"}}}});
        QTRY_VERIFY(dashboard.available().isEmpty());QTRY_COMPARE(dashboard.pages(),1);
        app.kill();QVERIFY(app.waitForFinished(5000));
        QVERIFY(start(false));QTRY_COMPARE_WITH_TIMEOUT(dashboard.available().size(),1,10000);
        dashboard.edit();dashboard.pick();dashboard.restore(key);dashboard.edit();
        QVERIFY(dashboard.widgets().first().toMap()["text"].toString().contains("00:00:00"));
        app.kill();app.waitForFinished(3000);QTRY_COMPARE(dashboard.pages(),1);
        int states=0;QDirIterator it(data,{"timer.json"},QDir::Files,QDirIterator::Subdirectories);
        while(it.hasNext()){it.next();++states;}QCOMPARE(states,2);
    }
};
int main(int argc,char**argv){qputenv("QT_QPA_PLATFORM","offscreen");qputenv("QT_QUICK_BACKEND","software");QGuiApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("SessionTimerHost");
    if(argc!=2)return 2;executable=QString::fromLocal8Bit(argv[1]);HostIntegration test;
    return QTest::qExec(&test,QStringList{argv[0],"-o","host-results.txt,txt"});}
#include "HostIntegration.moc"
