// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickItem>
#include <QTemporaryDir>
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QTcpServer>
#include "ArcadeGame.h"
#include "pong/src/PongRules.h"
#include "snake-arena/src/SnakeRules.h"
#include "light-cycles/src/CyclesRules.h"
using namespace arcade;
QQuickItem* item(QQuickItem* root,const QString& name){
    if(root->objectName()==name)return root;
    for(auto* child:root->childItems())if(auto* found=item(child,name))return found;
    return nullptr;
}
class ArcadeTests final:public QObject {
    Q_OBJECT
private slots:
    void lateClosedChannelResponseDoesNotRevokeRejoin(){
        QTemporaryDir dir;QTcpServer server;QVERIFY(server.listen(QHostAddress::LocalHost));
        QFile endpoint(dir.filePath("endpoint.json"));QVERIFY(endpoint.open(QIODevice::WriteOnly));
        endpoint.write(QJsonDocument(QJsonObject{{"protocol",1},{"host","127.0.0.1"},{"port",server.serverPort()},{"token","fixture"}}).toJson());endpoint.close();
        ArcadeBridge bridge(identity(Kind::Pong),endpoint.fileName());bridge.connectHost();
        QTRY_VERIFY(server.hasPendingConnections());auto* socket=server.nextPendingConnection();QByteArray buffer;QString heldRequest;
        auto write=[&](QJsonObject value){socket->write(QJsonDocument(value).toJson(QJsonDocument::Compact)+'\n');};
        auto drain=[&]{
            buffer+=socket->readAll();while(buffer.contains('\n')){
                const auto at=buffer.indexOf('\n');const auto packet=QJsonDocument::fromJson(buffer.left(at)).object();buffer.remove(0,at+1);
                if(packet["method"]=="network.send"){heldRequest=packet["id"].toString();continue;}
                QJsonObject result;
                if(packet["method"]=="hello")result={{"protocol",1},{"capabilities",QJsonObject{{"lobby.activity",1},{"network.records",1}}}};
                write({{"id",packet["id"]},{"result",result}});
            }
        };
        connect(socket,&QTcpSocket::readyRead,&server,drain);drain();QTRY_VERIFY(bridge.registered());
        auto ready=[&](QString channel){write({{"event","network.ready"},{"session",QJsonObject{{"channel",channel},{"host",true},{"protocol","pong.1"},{"delivery","reliable-ordered"}}}});};
        ready("old");QTRY_COMPARE(bridge.channel(),"old");QVERIFY(bridge.send({{"type","state"}}));QTRY_VERIFY(!heldRequest.isEmpty());
        bridge.closeChannel();ready("new");QTRY_COMPARE(bridge.channel(),"new");
        write({{"id",heldRequest},{"error",QJsonObject{{"code","channel_unavailable"}}}});QTest::qWait(100);
        QVERIFY(bridge.registered());QCOMPARE(bridge.channel(),"new");
    }
    void pongCollisionAndScoring(){
        PongRules game;game.reset(7);game.tick=60;game.serve=0;game.x=50;game.y=270;game.vx=-7;game.vy=0;
        game.step();QVERIFY(game.vx>0);QCOMPARE(game.scores[1],0);
        game.x=2;game.y=20;game.vx=-7;game.vy=0;game.scores[1]=4;game.step();
        QCOMPARE(game.scores[1],5);QCOMPARE(game.winner,1);
        auto end=game.view();game.step();QCOMPARE(game.view(),end);
        game.reset(1);game.input(0,0);for(int i=0;i<120;++i)game.step();QCOMPARE(game.paddles[0],55);
        game.input(0,-1);const int before=game.paddles[0];game.step();QCOMPARE(game.paddles[0],before);
    }
    void snakeGrowthAndSimultaneousCollision(){
        SnakeRules game;game.reset(7);game.tick=64;game.food=game.body[0][0]+1;
        game.input(0,3);game.step(); // Reversal is ignored.
        QCOMPARE(game.direction[0],1);QCOMPARE(game.body[0].size(),4);QVERIFY(game.food!=game.body[0][0]);
        game.reset(8);game.tick=64;game.body[0]={5+5*24,4+5*24,3+5*24};game.body[1]={7+5*24,8+5*24,9+5*24};game.food=0;
        game.step();QCOMPARE(game.winner,2);QCOMPARE(game.body[0][0],5+5*24);
        game.reset(9);game.tick=64;game.body[0]={0,1,2};game.direction[0]=3;game.pending[0]=3;game.food=100;
        game.step();QCOMPARE(game.winner,1);
    }
    void permanentTrailsAndHeadOnDraw(){
        CyclesRules game;game.reset(1);game.tick=63;const auto old=game.head;
        game.input(0,3);game.step();QCOMPARE(game.direction[0],1);QCOMPARE(game.cells[old[0]],1);
        QCOMPARE(game.cells[game.head[0]],1);QVERIFY(game.head[0]!=old[0]);
        game.reset(2);game.tick=63;game.cells.fill(0);game.head={100,102};game.cells[100]=1;game.cells[102]=2;
        game.step();QCOMPARE(game.winner,2);
        game.reset(2);game.tick=63;game.cells[game.head[0]+1]=2;game.step();QCOMPARE(game.winner,1);
    }
    void seededMatchesAndSnapshotValidation(){
        for(auto kind:{Kind::Pong,Kind::Snake,Kind::Cycles})for(quint32 seed:{1u,7u,4242u}){
            auto a=makeRules(kind),b=makeRules(kind);a->reset(seed);b->reset(seed);
            for(int t=0;t<6000&&a->view()["winner"]==-1;++t){
                for(int p=0;p<2;++p){int d=a->bot(p);a->input(p,d);b->input(p,d);}
                a->step();b->step();QCOMPARE(a->view(),b->view());QVERIFY(a->validView(a->view()));
            }
            QVERIFY(a->view()["winner"]!=-1);
            auto invalid=a->view();invalid["winner"]=99;QVERIFY(!a->validView(invalid));
            invalid=a->view();invalid["tick"]=1.5;QVERIFY(!a->validView(invalid));
            qInfo().noquote()<<identity(kind).id<<seed<<QCryptographicHash::hash(QJsonDocument(a->view()).toJson(QJsonDocument::Compact),QCryptographicHash::Sha256).toHex();
        }
    }
    void uiAndLocalLifecycle_data(){
        QTest::addColumn<int>("kind");QTest::newRow("pong")<<0;QTest::newRow("snake")<<1;QTest::newRow("cycles")<<2;
    }
    void uiAndLocalLifecycle(){
        QFETCH(int,kind);QTemporaryDir directory;ArcadeGame game(Kind(kind),directory.filePath("missing.json"));
        game.join();QCOMPARE(game.phase(),"menu");QVERIFY(!game.online());
        QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);
        window->resize(640,480);QTest::qWait(150);QVERIFY(window->grabWindow().save(game.slug()+"-menu-small.png"));
        // Navigate the real menu into couch play, then exercise both control owners.
        QTest::keyClick(window,Qt::Key_Down);QTest::keyClick(window,Qt::Key_Return);
        QCOMPARE(game.phase(),"play");QVERIFY(game.couch());
        QTest::qWait(2100);
        auto* up=item(window->contentItem(),"control0-0");QVERIFY(up);QVERIFY(up->isEnabled());
        auto pos=up->mapToScene(QPointF(up->width()/2,up->height()/2)).toPoint();
        QTest::mousePress(window,Qt::LeftButton,Qt::NoModifier,pos);QTest::qWait(80);QTest::mouseRelease(window,Qt::LeftButton,Qt::NoModifier,pos);
        QTest::keyPress(window,Qt::Key_Down);QTest::qWait(80);QTest::keyRelease(window,Qt::Key_Down);
        if(kind==0){QVERIFY(game.scene()["p0"].toInt()<270);QVERIFY(game.scene()["p1"].toInt()>270);}
        if(kind==0){
            auto* down=item(window->contentItem(),"control1-2");QVERIFY(down);
            const auto other=down->mapToScene(QPointF(down->width()/2,down->height()/2)).toPoint();
            const int first=game.scene()["p0"].toInt(),second=game.scene()["p1"].toInt();
            auto* device=QTest::createTouchDevice();
            QTest::touchEvent(window,device).press(0,pos,window).press(1,other,window).commit();QTest::qWait(100);
            QTest::touchEvent(window,device).release(0,pos,window).release(1,other,window).commit();
            QVERIFY(game.scene()["p0"].toInt()<first);QVERIFY(game.scene()["p1"].toInt()>second);
        }
        QTest::keyClick(window,Qt::Key_Escape);QCOMPARE(game.phase(),"paused");const auto paused=game.scene();QTest::qWait(100);QCOMPARE(game.scene(),paused);
        QTest::keyClick(window,Qt::Key_Escape);QCOMPARE(game.phase(),"play");
        QTest::qWait(100);QVERIFY(window->grabWindow().save(game.slug()+"-play-small.png"));
        window->resize(960,640);QTest::qWait(100);QVERIFY(window->grabWindow().save(game.slug()+"-play.png"));
        QTest::keyClick(window,Qt::Key_Escape);QTest::keyClick(window,Qt::Key_Return);QCOMPARE(game.phase(),"menu");
        game.local();QVERIFY(!game.couch());QCOMPARE(game.phase(),"play");game.leave();
    }
};
int main(int argc,char** argv){QGuiApplication app(argc,argv);ArcadeTests test;return QTest::qExec(&test,argc,argv);}
#include "ArcadeTests.moc"
