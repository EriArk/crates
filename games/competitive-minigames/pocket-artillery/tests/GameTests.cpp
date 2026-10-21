// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QFont>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QTcpServer>
#include <QTemporaryDir>

QQuickItem* visualItem(QQuickItem* parent,const QString& name){
    if(parent->objectName()==name)return parent;
    for(auto* child:parent->childItems())if(auto* found=visualItem(child,name))return found;
    return nullptr;
}
#include "Game.h"
#include "../../arcade-common/tests/VirtualPad.h"

class GameTests final:public QObject {
    Q_OBJECT
private slots:
    void controllerAndReadableFlight(){
        Game game;QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());ControllerInput input(window);VirtualPad pad;
        QVERIFY(pad.joystick);window->requestActivate();QTRY_VERIFY(window->isActive());QTRY_COMPARE(window->property("padCount").toInt(),1);
        QTest::qWait(70);pad.tap(SDL_CONTROLLER_BUTTON_A);pad.tap(SDL_CONTROLLER_BUTTON_A);QVERIFY(game.canFire());
        pad.axis(-25000,0);pad.axis(0,0);QCOMPARE(game.angle(),40);
        pad.button(SDL_CONTROLLER_BUTTON_DPAD_UP,true);pad.button(SDL_CONTROLLER_BUTTON_DPAD_UP,false);QCOMPARE(game.power(),90);
        window->resize(640,480);QTest::qWait(80);QVERIFY(window->grabWindow().save("artillery-pad-640.png"));
        window->resize(1280,720);QTest::qWait(80);QVERIFY(window->grabWindow().save("artillery-pad-1280.png"));
        int best=-1,angle=45,power=85;
        for(int a=10;a<=80;a+=5)for(int p=20;p<=100;p+=5){auto world=game.world();auto shot=world.fire(a,p);const int damage=game.world().hp[1]-world.hp[1];if(shot.hit&&damage>best){best=damage;angle=a;power=p;}}
        QVERIFY(best>0);game.aim((angle-game.angle())/5);game.charge((power-game.power())/5);
        pad.tap(SDL_CONTROLLER_BUTTON_A);QCOMPARE(game.phase(),"flight");QTest::qWait(650);QCOMPARE(game.phase(),"flight");
        QTRY_VERIFY_WITH_TIMEOUT(game.scene()["impactAge"].toInt()>=0,8000);QVERIFY(game.scene()["hit"].toBool());QTest::qWait(180);QVERIFY(window->grabWindow().save("artillery-impact.png"));
        QTRY_COMPARE_WITH_TIMEOUT(game.phase(),"handoff",1000);
        pad.tap(SDL_CONTROLLER_BUTTON_START);QVERIFY(window->property("asking").toBool());pad.tap(SDL_CONTROLLER_BUTTON_A);QCOMPARE(game.phase(),"menu");
    }
    void unavailableHostReturnsToLocalPlay(){
        QTemporaryDir directory;
        Game game(directory.filePath("missing.json"));
        game.join();QCOMPARE(game.phase(),"menu");QVERIFY(!game.online());
        game.local();game.acceptTurn();QVERIFY(game.canFire());

        QTcpServer server;QVERIFY(server.listen(QHostAddress::LocalHost));
        const auto endpoint=directory.filePath("endpoint.json");
        QFile file(endpoint);QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(QJsonDocument(QJsonObject{{"protocol",1},{"host","127.0.0.1"},{"port",server.serverPort()},{"token","test"}}).toJson());file.close();
        Game disconnected(endpoint);disconnected.join();
        QTRY_VERIFY(server.hasPendingConnections());
        auto* client=server.nextPendingConnection();client->disconnectFromHost();
        QTRY_COMPARE(disconnected.phase(),"menu");QVERIFY(!disconnected.online());
        disconnected.local();disconnected.acceptTurn();QVERIFY(disconnected.canFire());
    }
    void rulesAndDeterminism(){
        World a(12345),b(12345);QCOMPARE(a.digest(),b.digest());
        const auto initial=a.digest();QVERIFY(a.fire(44,80).path.isEmpty());QCOMPARE(a.digest(),initial);
        int hits=0;
        for(int i=0;i<60&&a.winner==-1;++i){
            const int angle=10+(i*7%15)*5,power=20+(i*3%17)*5;
            const auto shot=a.fire(angle,power);b.fire(angle,power);hits+=shot.hit;
            QCOMPARE(a.digest(),b.digest());QCOMPARE(a.ply,i+1);QCOMPARE(a.turn,(i+1)%2);
            for(auto h:a.ground)QVERIFY(h>=0&&h<=388);
            for(auto hp:a.hp)QVERIFY(hp>=0&&hp<=100);
        }
        QVERIFY(hits>0);QVERIFY(a.winner!=-1);const auto finished=a.digest();
        QVERIFY(a.fire(45,85).path.isEmpty());QCOMPARE(a.digest(),finished);
        // Golden digest is written by tests for cross-platform comparison.
        qInfo().noquote()<<"integer-rules digest"<<a.digest();
    }
    void destructiveWinningShot(){
        World world(478);int damaged=0;
        while(world.winner==-1&&world.ply<12){
            int best=-10000,angle=45,power=85;
            for(int a=10;a<=80;a+=5)for(int p=20;p<=100;p+=5){
                auto candidate=world;candidate.fire(a,p);
                int score=(world.hp[1-world.turn]-candidate.hp[1-world.turn])*3-(world.hp[world.turn]-candidate.hp[world.turn])*4;
                if(score>best){best=score;angle=a;power=p;}
            }
            const auto before=world.ground;world.fire(angle,power);if(before!=world.ground)++damaged;
        }
        QVERIFY(damaged>0);QVERIFY(world.winner==0||world.winner==1);
    }
    void localUiAndInputs(){
        Game game;QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);
        window->resize(640,440);QTest::qWait(100);
        auto* health=visualItem(window->contentItem(),"health0");QVERIFY(health);
        QCOMPARE(health->property("text").toString(),"MINT  100");
        QVERIFY(window->grabWindow().save("menu-small.png"));
        QTest::keyClick(window,Qt::Key_Return);QCOMPARE(game.phase(),"handoff");
        QTest::keyClick(window,Qt::Key_Return);QVERIFY(game.canFire());
        QTest::keyClick(window,Qt::Key_Left);QCOMPARE(game.angle(),40);
        QTest::keyClick(window,Qt::Key_Up);QCOMPARE(game.power(),90);
        QTest::qWait(100);QVERIFY(window->grabWindow().save("duel-small.png"));
        auto* fire=window->findChild<QQuickItem*>("fireButton");QVERIFY(fire);
        auto pos=fire->mapToScene(QPointF(fire->width()/2,fire->height()/2)).toPoint();
        QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,pos);QCOMPARE(game.world().ply,1);
        game.fire();QCOMPARE(game.world().ply,1); // Holding fire cannot take the other player's turn.
        QTRY_COMPARE_WITH_TIMEOUT(game.phase(),"handoff",5000);QCOMPARE(game.world().turn,1);
        QTest::keyClick(window,Qt::Key_Escape);QCOMPARE(game.phase(),"handoff");
        QTest::keyClick(window,Qt::Key_Escape);QCOMPARE(game.phase(),"handoff"); // Back cancels confirmation.
        QTest::keyClick(window,Qt::Key_Escape);QTest::keyClick(window,Qt::Key_Return);QCOMPARE(game.phase(),"menu");
        QVERIFY(!game.canFire());
    }
};
int main(int argc,char** argv){QGuiApplication app(argc,argv);
#ifdef Q_OS_WIN
app.setFont(QFont("Segoe UI"));
#else
app.setFont(QFont("DejaVu Sans"));
#endif
GameTests tests;return QTest::qExec(&tests,argc,argv);}
#include "GameTests.moc"
