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
#include "falling-blocks/src/BlocksRules.h"
#include "minesweeper-race/src/MinesRules.h"
#include "chain-reaction/src/ChainRules.h"
using namespace arcade;
QQuickItem* item(QQuickItem* root,const QString& name){
    if(root->objectName()==name)return root;
    for(auto* child:root->childItems())if(auto* found=item(child,name))return found;
    return nullptr;
}
class ArcadeTests final:public QObject {
    Q_OBJECT
private slots:
    void blocksLinesRotationAndQueue(){
        BlocksRules g;g.reset(1);g.tick=60;auto& p=g.players[0];p.cells.fill(0);p.type=0;p.rotation=0;p.x=3;p.y=0;
        for(int x=0;x<10;++x)if(x<3||x>6)p.cells[150+x]=2;
        g.action(0,1);g.action(0,1);g.step();QCOMPARE(g.score[0],1);QVERIFY(!g.lost[0]);
        for(int c:p.cells)QCOMPARE(c,0); // A burst of drops consumed only one piece.
        p.type=0;p.rotation=1;p.x=-2;p.y=0;QVERIFY(g.fits(p,p.x,p.y,p.rotation));
        for(int i=0;i<6;++i)g.step();g.action(0,0);g.step();QVERIFY(g.fits(p,p.x,p.y,p.rotation));QCOMPARE(p.rotation,2);
        g.reset(1);g.action(0,1);g.step();QVERIFY(g.players[0].cells==QVector<int>(160));
        g.tick=60;g.score={11,11};
        for(auto& s:g.players){s.cells.fill(0);s.type=0;s.rotation=0;s.x=3;s.y=0;for(int x=0;x<10;++x)if(x<3||x>6)s.cells[150+x]=2;}
        g.action(0,1);g.action(1,1);g.step();QCOMPARE(g.winner,2);
    }
    void minesFairOpeningFlagsFloodAndBot(){
        MinesRules g;g.reset(7);QCOMPARE(g.visible[0],g.visible[1]);QCOMPARE(g.mines.count(1),12);QCOMPARE(g.numbers[40],0);QVERIFY(g.score[0]>0);
        int mine=g.mines.indexOf(1);g.tick=60;g.cursor[0]=mine;g.action(0,1);g.step();QCOMPARE(g.visible[0][mine],-2);
        for(int i=0;i<6;++i)g.step();g.action(0,0);g.step();QVERIFY(!g.lost[0]);
        // Changing hidden information must not change the bot's observable decisions.
        MinesRules b=g;b.mines.fill(0);b.numbers.fill(8);g.tick=b.tick=120;
        QCOMPARE(g.bot(1),b.bot(1));QCOMPARE(g.botAction(1),b.botAction(1));
        for(int p=0;p<2;++p){g.cursor[p]=mine;g.visible[p][mine]=-1;g.cooldown[p]=0;g.action(p,0);}g.step();QCOMPARE(g.winner,2);
        g.reset(42);g.tick=60;
        for(int c=0;c<81&&g.winner<0;++c)if(!g.mines[c]){g.cursor[0]=c;g.cooldown[0]=0;g.action(0,0);g.step();}
        QCOMPARE(g.score[0],69);QCOMPARE(g.winner,0);
    }
    void chainCascadeAttackAndGarbage(){
        ChainRules g;g.reset(7);QCOMPARE(g.players[0].cells,g.players[1].cells);QVERIFY(ChainRules::matches(g.players[0].cells).isEmpty());
        g.tick=60;auto& a=g.players[0];a.cells.fill(0);
        // Clear a bottom triple: staggered colour 2 falls into a second triple.
        a.cells[54]=a.cells[60]=a.cells[66]=1;a.cells[48]=2;a.cells[67]=2;a.cells[68]=2;a.cells[61]=5;
        g.step();QCOMPARE(a.chain,1);QCOMPARE(g.score[0],30);QCOMPARE(a.flash.size(),3);
        for(int i=0;i<12;++i)g.step();QCOMPARE(a.chain,2);QCOMPARE(g.score[0],90);QVERIFY(g.players[1].incoming>=1);QCOMPARE(a.cells[61],0);
        for(int i=0;i<80;++i)g.step();QVERIFY(g.players[1].cells.contains(5));
        g.reset(3);g.tick=60;for(auto& p:g.players){p.cells.fill(0);p.cells[0]=1;}
        g.action(0,1);g.action(1,1);g.step();QCOMPARE(g.winner,2);
    }
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
        for(auto kind:{Kind::Pong,Kind::Snake,Kind::Cycles,Kind::Blocks,Kind::Mines,Kind::Chain})for(quint32 seed:{1u,7u,4242u}){
            auto a=makeRules(kind),b=makeRules(kind);a->reset(seed);b->reset(seed);
            for(int t=0;t<6000&&a->view()["winner"]==-1;++t){
                for(int p=0;p<2;++p){int d=a->bot(p),action=a->botAction(p);a->input(p,d);b->input(p,d);a->action(p,action);b->action(p,action);}
                a->step();b->step();QCOMPARE(a->view(),b->view());QVERIFY(a->validView(a->view()));
            }
            QVERIFY(a->view()["winner"]!=-1);
            auto invalid=a->view();invalid["winner"]=99;QVERIFY(!a->validView(invalid));
            invalid=a->view();invalid["tick"]=1.5;QVERIFY(!a->validView(invalid));
            QVERIFY(QJsonDocument(a->view()).toJson(QJsonDocument::Compact).size()<15000);
            if(int(kind)>=3){invalid=a->view();auto players=invalid["players"].toArray();auto p=players[0].toObject();p["cells"]=QJsonArray{999};players[0]=p;invalid["players"]=players;QVERIFY(!a->validView(invalid));}
            qInfo().noquote()<<identity(kind).id<<seed<<QCryptographicHash::hash(QJsonDocument(a->view()).toJson(QJsonDocument::Compact),QCryptographicHash::Sha256).toHex();
        }
    }
    void uiAndLocalLifecycle_data(){
        QTest::addColumn<int>("kind");QTest::newRow("pong")<<0;QTest::newRow("snake")<<1;QTest::newRow("cycles")<<2;
        QTest::newRow("blocks")<<3;QTest::newRow("mines")<<4;QTest::newRow("chain")<<5;
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
        if(kind>=3){
            if(kind==4){
                const auto cells=game.scene()["players"].toList()[0].toMap()["cells"].toList();int target=0;while(cells[target].toInt()!=-1)++target;
                for(int p=0;p<2;++p)for(int n=0;n<20;++n){
                    int cursor=game.scene()["players"].toList()[p].toMap()["cursor"].toInt();if(cursor==target)break;
                    int d=cursor%9<target%9?1:cursor%9>target%9?3:cursor/9<target/9?2:0;
                    const int keys[2][4]={{Qt::Key_W,Qt::Key_D,Qt::Key_S,Qt::Key_A},{Qt::Key_Up,Qt::Key_Right,Qt::Key_Down,Qt::Key_Left}};
                    QTest::keyPress(window,Qt::Key(keys[p][d]));QTest::qWait(50);QTest::keyRelease(window,Qt::Key(keys[p][d]));QTest::qWait(30);
                }
            }
            auto before=game.scene();auto* action=item(window->contentItem(),"action0-1");QVERIFY(action);QVERIFY(action->isVisible());
            auto pos=action->mapToScene(QPointF(action->width()/2,action->height()/2)).toPoint();
            QTest::mouseClick(window,Qt::LeftButton,Qt::NoModifier,pos);QTest::keyClick(window,Qt::Key_Shift);QTest::qWait(90);
            auto first=game.scene()["players"].toList()[0].toMap(),second=game.scene()["players"].toList()[1].toMap();
            if(kind==3){QVERIFY(first["cells"]!=before["players"].toList()[0].toMap()["cells"]);QCOMPARE(first["cells"],second["cells"]);}
            if(kind==4){QCOMPARE(first["flags"].toInt(),1);QCOMPARE(second["flags"].toInt(),1);}
            if(kind==5){QVERIFY(first["cells"]!=before["players"].toList()[0].toMap()["cells"]);QCOMPARE(first["cells"],second["cells"]);}
            QTest::keyClick(window,Qt::Key_F);QTest::keyClick(window,Qt::Key_Return);QTest::qWait(50);
        }
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
