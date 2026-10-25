// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QFont>
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
#include "mini-racing/src/RacingRules.h"
#include "tanks/src/TanksRules.h"
#include "VirtualPad.h"
using namespace arcade;
QQuickItem* item(QQuickItem* root,const QString& name){
    if(root->objectName()==name)return root;
    for(auto* child:root->childItems())if(auto* found=item(child,name))return found;
    return nullptr;
}
class ArcadeTests final:public QObject {
    Q_OBJECT
private slots:
    void roundStartPreservesSnapshotSchema(){
        // Group map bookkeeping must not insert cells:null into legacy duels:
        // peers compare the seeded initial state exactly before starting.
        for(int kind=0;kind<8;++kind){ArcadeGame game{Kind(kind)};auto keys=game.scene().keys();game.local();QCOMPARE(game.scene().keys(),keys);game.leave();}
    }
    void tanksOwnScrollingViewport(){
        ArcadeGame game{Kind::Tanks};QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);window->setProperty("touchControls",false);window->resize(1280,720);game.local();
        QTRY_VERIFY_WITH_TIMEOUT(game.scene()["tick"].toInt()>=65,5000);
        auto* board=item(window->contentItem(),"tanksBoard");QVERIFY(board);QCOMPARE(board->property("views").toInt(),1);
        QVariant local,other;QVERIFY(QMetaObject::invokeMethod(board,"camera",Q_RETURN_ARG(QVariant,local),Q_ARG(QVariant,0)));
        QVERIFY(QMetaObject::invokeMethod(board,"camera",Q_RETURN_ARG(QVariant,other),Q_ARG(QVariant,1)));
        QCOMPARE(local.toMap()["x"].toDouble(),0.0);QVERIFY(other.toMap()["x"].toDouble()>0);
        QVERIFY(game.scene()["width"].toInt()>40);QVERIFY(game.scene()["height"].toInt()>22);
        QVERIFY(window->grabWindow().save("tanks-single-play.png"));game.leave();
    }
    void tanksLargeMapSixteenSeatsAndLoad(){
        for(int count:{2,4,8,16}){
            TanksRules g;g.reset(42,count);QCOMPARE(g.tanks.size(),count);QVERIFY(g.validView(g.view()));
            for(int p=0;p<count;++p){QVERIFY(g.clear(g.tanks[p].pos));for(int q=0;q<p;++q)QVERIFY((g.tanks[p].pos-g.tanks[q].pos).manhattanLength()>=3);}
            QVector<qint64> samples;int peakBytes=0,peakFull=0;QElapsedTimer clock;
            for(int frame=0;frame<1800;++frame){
                if(g.winner>=0)g.reset(42+frame,count);
                clock.start();for(int p=0;p<count;++p){g.input(p,g.bot(p));g.action(p,g.botAction(p));}g.step();
                auto state=g.view();QVERIFY(g.validView(state));
                peakFull=std::max(peakFull,int(QJsonDocument(state).toJson(QJsonDocument::Compact).size()));
                state.remove("cells");state["changes"]=QJsonArray{};
                auto bytes=QJsonDocument(state).toJson(QJsonDocument::Compact);peakBytes=std::max(peakBytes,int(bytes.size()));
                samples.append(clock.nsecsElapsed());
            }
            std::sort(samples.begin(),samples.end());
            qInfo()<<"Tanks workload"<<count<<"players; simulation+AI+validation+JSON us p50/p95/p99/max"
                <<samples[900]/1000<<samples[1710]/1000<<samples[1782]/1000<<samples.last()/1000
                <<"peak snapshot/full bytes"<<peakBytes<<peakFull;
            QVERIFY(peakFull<16000);QVERIFY(peakBytes<8000);
        }
        TanksRules g;g.reset(7,16);g.tick=61;g.cells.fill(0);
        g.tanks[0].pos={10,10};g.tanks[0].face=1;g.cells[10*TanksRules::Width+12]=TanksRules::Water;
        QVERIFY(!g.clear({11,10}));g.action(0,0);g.step();QVERIFY(!g.bullets.isEmpty());
        g.cells[10*TanksRules::Width+12]=TanksRules::Bush;QVERIFY(g.clear({11,10}));
        auto invalid=g.view();invalid["width"]=60;QVERIFY(!g.validView(invalid));
        invalid=g.view();auto players=invalid["players"].toArray();players.append(players[0]);invalid["players"]=players;QVERIFY(!g.validView(invalid));
        g.reset(1,3);g.tick=63;g.cells.fill(0);g.tanks[0].pos={10,10};g.tanks[1].pos={13,10};g.tanks[2].pos={16,10};
        g.input(0,1);g.input(1,1);g.input(2,3);g.step();
        QCOMPARE(g.tanks[0].pos,QPoint(10,10));QCOMPARE(g.tanks[1].pos,QPoint(13,10));QCOMPARE(g.tanks[2].pos,QPoint(16,10));
    }
    void portraitCacheAndBrickPixels(){
        ArcadeGame game{Kind::Racing};QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
        window->setProperty("touchControls",false);game.local();QTest::qWait(100);
        auto* portrait=item(window->contentItem(),"avatarPortrait");QVERIFY(portrait);
        const int generation=portrait->property("generation").toInt();
        for(int i=0;i<30;++i)portrait->setProperty("descriptor",QVariantMap{});
        QCOMPARE(portrait->property("generation").toInt(),generation);
        QTemporaryDir tmp;QImage source(32,32,QImage::Format_ARGB32);source.fill(Qt::red);
        for(int y=0;y<32;++y)for(int x=16;x<32;++x)source.setPixelColor(x,y,Qt::white);
        const QString path=tmp.filePath("portrait.png");QVERIFY(source.save(path));
        portrait->setProperty("capture",QVariantMap{{"url",QUrl::fromLocalFile(path)}});
        QTest::qWait(180);QVERIFY(portrait->property("brickStyle").toBool());
        // Re-evaluating a descriptor must preserve the existing snapshot.
        portrait->setProperty("descriptor",QVariantMap{});QVERIFY(portrait->property("capture").isValid());
        auto* loader=item(portrait,"portraitRenderer");QVERIFY(loader);QVERIFY(!loader->property("active").toBool());
        window->setProperty("touchControls",false);game.local();QTest::qWait(100);
        auto image=window->grabWindow();QVERIFY(image.save("brick-portrait-cache.png"));
        double factor=double(image.width())/window->width();
        QPointF dark=portrait->mapToScene(QPointF(portrait->width()*0.25,portrait->height()*0.5));
        QPointF light=portrait->mapToScene(QPointF(portrait->width()*0.75,portrait->height()*0.5));
        QCOMPARE(image.pixelColor(qRound(dark.x()*factor),qRound(dark.y()*factor)),QColor("#34432c"));
        QCOMPARE(image.pixelColor(qRound(light.x()*factor),qRound(light.y()*factor)),QColor("#adb991"));
        // A closed menu must not instantiate an invisible 3D renderer.
        portrait->setVisible(false);
        portrait->setProperty("descriptor",QVariantMap{{"source",QUrl("file:///unused-hidden-portrait.glb")}});
        QVERIFY(portrait->property("rendering").toBool());QVERIFY(!loader->property("active").toBool());
        portrait->setProperty("descriptor",QVariantMap{});portrait->setVisible(true);
    }
    void controllerBackend_data(){uiAndLocalLifecycle_data();}
    void controllerBackend(){
        QFETCH(int,kind);ArcadeGame game{Kind(kind)};
        QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
        ControllerInput input(window);VirtualPad first;VirtualPad second;
        QVERIFY(first.joystick&&second.joystick);window->requestActivate();QTRY_VERIFY(window->isActive());
        QTRY_COMPARE(window->property("padCount").toInt(),2);QVERIFY(!window->property("touchControls").toBool());
        QTest::qWait(70);first.axis(0,24000);first.axis(0,0);QCOMPARE(window->property("selected").toInt(),1);
        first.tap(SDL_CONTROLLER_BUTTON_A);QCOMPARE(game.phase(),"play");QVERIFY(game.couch());
        QTRY_VERIFY_WITH_TIMEOUT(game.scene()["tick"].toInt()>=65,6000);first.axis(0,-26000);second.axis(0,26000);QTest::qWait(180);
        // Cycles must leave the short vertical approach before the pause assertions:
        // a random starting row can otherwise hit the wall while taps are awaited.
        if(kind==2){first.axis(26000,0);second.axis(-26000,0);}
        first.axis(0,0);second.axis(0,0);
        if(kind==0){QVERIFY(game.scene()["p0"].toInt()<270);QVERIFY(game.scene()["p1"].toInt()>270);const int y=game.scene()["p0"].toInt();first.axis(8000,8000);QTest::qWait(120);QCOMPARE(game.scene()["p0"].toInt(),y);first.axis(0,0);}
        if(kind!=4){first.tap(SDL_CONTROLLER_BUTTON_A);second.tap(SDL_CONTROLLER_BUTTON_A);}
        first.tap(SDL_CONTROLLER_BUTTON_X);second.tap(SDL_CONTROLLER_BUTTON_X);
        first.tap(SDL_CONTROLLER_BUTTON_START);QCOMPARE(game.phase(),"paused");
        const auto paused=game.scene();second.axis(0,26000);second.tap(SDL_CONTROLLER_BUTTON_A);QCOMPARE(game.scene(),paused);
        second.axis(0,0);first.tap(SDL_CONTROLLER_BUTTON_B);QCOMPARE(game.phase(),"play");
        window->resize(640,480);QTest::qWait(80);QVERIFY(window->grabWindow().save(game.slug()+"-pad-640.png"));
        window->resize(1280,720);QTest::qWait(80);QVERIFY(window->grabWindow().save(game.slug()+"-pad-1280.png"));
        first.tap(SDL_CONTROLLER_BUTTON_B);first.tap(SDL_CONTROLLER_BUTTON_A);QCOMPARE(game.phase(),"menu");
    }
    void controllerFocusAndHotplug(){
        ArcadeGame game{Kind::Pong};QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());ControllerInput input(window);
        auto first=std::make_unique<VirtualPad>();VirtualPad second;window->requestActivate();QTRY_VERIFY(window->isActive());QTRY_COMPARE(window->property("padCount").toInt(),2);
        game.local(true);QTRY_VERIFY_WITH_TIMEOUT(game.scene()["tick"].toInt()>=65,6000);first->axis(0,-26000);
        QQuickWindow other;other.show();other.requestActivate();QTRY_VERIFY(!window->isActive());QCOMPARE(game.phase(),"paused");
        window->requestActivate();QTRY_VERIFY(window->isActive());game.pause(false);int y=game.scene()["p0"].toInt();QTest::qWait(100);QCOMPARE(game.scene()["p0"].toInt(),y);
        first->axis(0,0);first->axis(0,26000);QTest::qWait(100);QVERIFY(game.scene()["p0"].toInt()>y);
        first.reset();QTRY_COMPARE(window->property("padCount").toInt(),1);QCOMPARE(game.phase(),"paused");
        second.tap(SDL_CONTROLLER_BUTTON_A);QCOMPARE(game.phase(),"play");int before=game.scene()["p1"].toInt();second.axis(0,26000);QTest::qWait(100);QVERIFY(game.scene()["p1"].toInt()>before);second.axis(0,0);
    }
    void racingSharedCourseDraftContactRecoveryAndFinish(){
        RacingRules g;g.reset(7);g.tick=60;g.cars[0].distance=40;g.cars[1].distance=80;g.cars[0].lane=g.cars[1].lane=1;
        QVERIFY(g.drafting(0));QVERIFY(!g.drafting(1));g.step();
        g.cars[0].distance=6;g.cars[1].distance=30;g.input(0,0);g.input(1,2);g.step();QCOMPARE(g.cars[1].distance-g.cars[0].distance,24);
        g.cars[0].lane=0;g.cars[1].lane=2;g.cars[0].distance=g.cars[1].distance=40;g.input(0,1);g.input(1,3);g.step();
        QCOMPARE(g.cars[0].lane,0);QCOMPARE(g.cars[1].lane,2);
        g.reset(1);g.tick=60;g.course.fill(1);g.cars[0].distance=101;g.step();QCOMPARE(g.cars[0].crashes,1);QCOMPARE(g.cars[0].crash,18);
        int before=g.cars[0].distance;for(int i=0;i<18;++i)g.step();QCOMPARE(g.cars[0].distance,before);QCOMPARE(g.cars[0].crashes,1);
        g.step();QVERIFY(g.cars[0].distance>before);QCOMPARE(g.cars[0].crashes,1);
        g.reset(1);g.tick=60;g.cars[0].passable=true;g.cars[0].crash=1;g.cars[0].distance=g.cars[1].distance=40;g.cars[1].lane=0;
        g.step();QVERIFY(g.cars[0].passable);g.input(0,1);g.step();QVERIFY(!g.cars[0].passable);QCOMPARE(g.cars[0].lane,1);
        g.reset(1);g.tick=60;g.cars[0].distance=1999;g.cars[1].distance=1998;g.input(0,2);g.input(1,0);g.step();QCOMPARE(g.winner,1);
        g.reset(1);g.tick=60;g.cars[0].distance=g.cars[1].distance=1999;g.step();QCOMPARE(g.winner,2);
    }
    void racingFiveLanesUnlimitedBoostAndLives(){
        RacingRules g;g.reset(7);g.tick=60;g.course.fill(1);g.cars[0].lane=2;g.cars[1].lane=4;
        g.action(0,0);g.step();QCOMPARE(g.cars[0].boost,1);
        for(int i=0;i<300;++i)g.step();QCOMPARE(g.cars[0].boost,1);QCOMPARE(g.cars[0].lives,3);
        g.action(0,0);g.step();QCOMPARE(g.cars[0].boost,0);
        g.reset(1);g.tick=60;g.course.fill(1);g.cars[1].distance=1000;g.input(0,1);
        for(int i=0;i<40;++i)g.step();QCOMPARE(g.cars[0].lane,4);
        g.input(0,3);for(int i=0;i<40;++i)g.step();QCOMPARE(g.cars[0].lane,0);
        g.reset(1);g.tick=60;g.course.fill(1);g.cars[1].lane=4;
        for(int hit=0;hit<3;++hit){g.cars[0].crash=0;g.cars[0].distance=101+90*hit;g.step();QCOMPARE(g.cars[0].lives,2-hit);QVERIFY(g.validView(g.view()));}
        QCOMPARE(g.winner,1);
        g.reset(1);g.tick=60;g.course.fill(17);for(auto& c:g.cars){c.distance=101;c.lives=1;c.crashes=2;}
        g.step();QCOMPARE(g.winner,2);
        auto invalid=g.view();auto players=invalid["players"].toArray();auto car=players[0].toObject();car["lives"]=3;players[0]=car;invalid["players"]=players;QVERIFY(!g.validView(invalid));
    }
    void boundedRasterAndReadableLayout_data(){uiAndLocalLifecycle_data();}
    void boundedRasterAndReadableLayout(){
        QFETCH(int,kind);ArcadeGame game{Kind(kind)};QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));QVERIFY(!engine.rootObjects().isEmpty());
        auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);
        window->setProperty("touchControls",false);
        QSizeF raster;double ratio=0;
        for(QSize size:{QSize(1280,720),QSize(1920,1080),QSize(2560,1440)}){
            window->resize(size);QTest::qWait(80);
            auto* canvas=item(window->contentItem(),"boardCanvas");auto* stage=item(window->contentItem(),"gameStage");
            QVERIFY(canvas&&stage);QVERIFY(canvas->width()<=960&&canvas->height()<=540);
            auto* field=item(window->contentItem(),"playfield");QVERIFY(field);
            QCOMPARE(field->position(),QPointF(0,0));QCOMPARE(field->size(),stage->size());
            window->setProperty("touchControls",true);QTest::qWait(10);QCOMPARE(field->size(),stage->size());window->setProperty("touchControls",false);
            if(raster.isEmpty())raster=canvas->size();else QCOMPARE(canvas->size(),raster);
            auto* button=item(window->contentItem(),"practiceButton");QVERIFY(button);
            double current=button->mapRectToScene(button->boundingRect()).height()/size.height();
            if(ratio==0)ratio=current;else QVERIFY(qAbs(current-ratio)<0.001);
            QVERIFY(current>=0.08);
            QVERIFY(window->grabWindow().save(game.slug()+"-menu-"+QString::number(size.height())+".png"));
        }
        game.local();window->resize(1280,720);QTest::qWait(200);QVERIFY(window->grabWindow().save(game.slug()+"-handheld.png"));game.leave();
    }
    void tanksCoverMuzzleCollisionShieldsAndSimultaneousHits(){
        TanksRules g;g.reset(1);g.tick=61;g.tanks[0].pos={4,9};g.tanks[0].face=1;g.cells[9*TanksRules::Width+6]=1;
        g.action(0,0);g.action(0,0);g.step();QCOMPARE(g.cells[9*TanksRules::Width+6],0);QVERIFY(g.bullets.isEmpty());QCOMPARE(g.tanks[0].cooldown,12);
        g.cells[9*TanksRules::Width+6]=2;g.tanks[0].cooldown=0;g.action(0,0);g.step();g.step();QCOMPARE(g.cells[9*TanksRules::Width+6],2);QVERIFY(g.bullets.isEmpty());
        g.reset(1);g.tick=63;g.tanks[0].pos={10,2};g.tanks[1].pos={13,2};g.input(0,1);g.input(1,3);g.step();QCOMPARE(g.tanks[0].pos,QPoint(10,2));QCOMPARE(g.tanks[1].pos,QPoint(13,2));
        g.reset(1);g.tick=61;g.tanks[1].shield=20;g.bullets.append({g.tanks[1].pos-QPoint(1,0),1,0});g.step();QCOMPARE(g.scores[0],0);
        g.tanks[1].shield=0;g.bullets.append({g.tanks[1].pos-QPoint(1,0),1,0});g.step();g.step();QCOMPARE(g.scores[0],1);QCOMPARE(g.tanks[1].shield,45);
        g.action(1,0);g.tanks[1].cooldown=0;g.step();QCOMPARE(g.tanks[1].shield,0);
        g.reset(1);g.tick=61;g.scores={2,2};g.tanks[0].shield=g.tanks[1].shield=0;
        g.bullets.append({g.tanks[1].pos-QPoint(1,0),1,0});g.bullets.append({g.tanks[0].pos+QPoint(1,0),3,1});g.step();QCOMPARE(g.winner,2);
        g.reset(1);g.tick=61;g.bullets={{{10,2},1,0},{{11,2},3,1}};g.step();QVERIFY(g.bullets.isEmpty());
    }
    void tanksFlanksStayOpenAndPracticeBotCanEngage(){
        for(quint32 seed:{1u,7u,4242u}){
            TanksRules g;g.reset(seed);
            for(int x=2;x<=TanksRules::Width-3;++x){QVERIFY(g.clear({x,2}));QVERIFY(g.clear({x,TanksRules::Height-3}));}
            for(int y=0;y<TanksRules::Height;++y)for(int x=0;x<TanksRules::Width;++x)QCOMPARE(g.cells[y*TanksRules::Width+x],g.cells[y*TanksRules::Width+TanksRules::Width-1-x]);
            for(int t=0;t<3660&&g.winner<0;++t){g.input(1,g.bot(1));g.action(1,g.botAction(1));g.step();}
            QVERIFY(g.scores[1]>0);QCOMPARE(g.winner,1);
        }
    }
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
        auto ready=[&](QString channel){write({{"event","network.ready"},{"session",QJsonObject{{"channel",channel},{"peer","peer"},{"host",true},{"protocol","pong.2"},{"delivery","reliable-ordered"}}}});};
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
        for(auto kind:{Kind::Pong,Kind::Snake,Kind::Cycles,Kind::Blocks,Kind::Mines,Kind::Chain,Kind::Racing,Kind::Tanks})for(quint32 seed:{1u,7u,4242u}){
            auto a=makeRules(kind),b=makeRules(kind);a->reset(seed);b->reset(seed);
            for(int t=0;t<6000&&a->view()["winner"]==-1;++t){
                for(int p=0;p<2;++p){int d=a->bot(p),action=a->botAction(p);a->input(p,d);b->input(p,d);a->action(p,action);b->action(p,action);}
                a->step();b->step();QCOMPARE(a->view(),b->view());QVERIFY(a->validView(a->view()));
            }
            QVERIFY(a->view()["winner"]!=-1);
            auto invalid=a->view();invalid["winner"]=99;QVERIFY(!a->validView(invalid));
            invalid=a->view();invalid["tick"]=1.5;QVERIFY(!a->validView(invalid));
            QVERIFY(QJsonDocument(a->view()).toJson(QJsonDocument::Compact).size()<15000);
            if(int(kind)>=3&&int(kind)<=5){invalid=a->view();auto players=invalid["players"].toArray();auto p=players[0].toObject();p["cells"]=QJsonArray{999};players[0]=p;invalid["players"]=players;QVERIFY(!a->validView(invalid));}
            if(kind==Kind::Racing){invalid=a->view();invalid["course"]=QJsonArray{7};QVERIFY(!a->validView(invalid));}
            if(kind==Kind::Tanks){invalid=a->view();invalid["bullets"]=QJsonArray{QJsonObject{{"x",999}}};QVERIFY(!a->validView(invalid));}
            qInfo().noquote()<<identity(kind).id<<seed<<QCryptographicHash::hash(QJsonDocument(a->view()).toJson(QJsonDocument::Compact),QCryptographicHash::Sha256).toHex();
        }
    }
    void uiAndLocalLifecycle_data(){
        QTest::addColumn<int>("kind");QTest::newRow("pong")<<0;QTest::newRow("snake")<<1;QTest::newRow("cycles")<<2;
        QTest::newRow("blocks")<<3;QTest::newRow("mines")<<4;QTest::newRow("chain")<<5;
        QTest::newRow("racing")<<6;QTest::newRow("tanks")<<7;
    }
    void uiAndLocalLifecycle(){
        QFETCH(int,kind);QTemporaryDir directory;ArcadeGame game(Kind(kind),directory.filePath("missing.json"));
        game.attach();QCOMPARE(game.phase(),"menu");QVERIFY(!game.online());
        QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);engine.load(QUrl("qrc:/ui/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());QVERIFY(window);
        window->resize(640,480);QTest::qWait(150);QVERIFY(window->grabWindow().save(game.slug()+"-menu-small.png"));
        // Navigate the real menu into couch play, then exercise both control owners.
        QTest::keyClick(window,Qt::Key_Down);QTest::keyClick(window,Qt::Key_Return);
        QCOMPARE(game.phase(),"play");QVERIFY(game.couch());
        QTRY_VERIFY_WITH_TIMEOUT(game.scene()["tick"].toInt()>=65,6000);
        if(kind>=3&&kind<=5){
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
        if(kind>=6){
            auto* secondary=item(window->contentItem(),"action0-1");QVERIFY(secondary);QVERIFY(!secondary->isVisible());
            auto* a=item(window->contentItem(),"action0-0");auto* b=item(window->contentItem(),"action1-0");QVERIFY(a&&b);
            auto ap=a->mapToScene(QPointF(a->width()/2,a->height()/2)).toPoint(),bp=b->mapToScene(QPointF(b->width()/2,b->height()/2)).toPoint();
            auto* device=QTest::createTouchDevice();QTest::touchEvent(window,device).press(0,ap,window).press(1,bp,window).commit();QTest::qWait(30);
            QTest::touchEvent(window,device).release(0,ap,window).release(1,bp,window).commit();QTest::qWait(70);
            for(auto player:game.scene()["players"].toList())QVERIFY(player.toMap()[kind==6?"boost":"cooldown"].toInt()>0);
        }
        auto* up=item(window->contentItem(),"control0-0");QVERIFY(up);QVERIFY(up->isEnabled());
        auto pos=up->mapToScene(QPointF(up->width()/2,up->height()/2)).toPoint();
        QTest::mousePress(window,Qt::LeftButton,Qt::NoModifier,pos);
        if(kind==0){QTRY_VERIFY_WITH_TIMEOUT(game.scene()["p0"].toInt()<270,1500);}else QTest::qWait(80);
        QTest::mouseRelease(window,Qt::LeftButton,Qt::NoModifier,pos);
        QTest::keyPress(window,Qt::Key_Down);
        if(kind==0){QTRY_VERIFY_WITH_TIMEOUT(game.scene()["p1"].toInt()>270,1500);}else QTest::qWait(80);
        QTest::keyRelease(window,Qt::Key_Down);
        if(kind==0){QVERIFY(game.scene()["p0"].toInt()<270);QVERIFY(game.scene()["p1"].toInt()>270);}
        if(kind==0){
            auto* down=item(window->contentItem(),"control0-2");auto* otherUp=item(window->contentItem(),"control1-0");QVERIFY(down&&otherUp);
            const auto touchFirst=down->mapToScene(QPointF(down->width()/2,down->height()/2)).toPoint();
            const auto other=otherUp->mapToScene(QPointF(otherUp->width()/2,otherUp->height()/2)).toPoint();
            const int first=game.scene()["p0"].toInt(),second=game.scene()["p1"].toInt();
            auto* device=QTest::createTouchDevice();
            QTest::touchEvent(window,device).press(0,touchFirst,window).press(1,other,window).commit();
            QTRY_VERIFY_WITH_TIMEOUT(game.scene()["p0"].toInt()>first&&game.scene()["p1"].toInt()<second,1500);
            QTest::touchEvent(window,device).release(0,touchFirst,window).release(1,other,window).commit();
        }
        QTest::keyClick(window,Qt::Key_Escape);QCOMPARE(game.phase(),"paused");const auto paused=game.scene();QTest::qWait(100);QCOMPARE(game.scene(),paused);
        QTest::keyClick(window,Qt::Key_Escape);QCOMPARE(game.phase(),"play");
        QTest::qWait(100);QVERIFY(window->grabWindow().save(game.slug()+"-play-small.png"));
        window->resize(960,640);QTest::qWait(100);QVERIFY(window->grabWindow().save(game.slug()+"-play.png"));
        QTest::keyClick(window,Qt::Key_Escape);QTest::keyClick(window,Qt::Key_Return);QCOMPARE(game.phase(),"menu");
        game.local();QVERIFY(!game.couch());QCOMPARE(game.phase(),"play");game.leave();
    }
};
int main(int argc,char** argv){QGuiApplication app(argc,argv);
#ifdef Q_OS_WIN
app.setFont(QFont("Segoe UI"));
#else
app.setFont(QFont("DejaVu Sans"));
#endif
ArcadeTests test;return QTest::qExec(&test,argc,argv);}
#include "ArcadeTests.moc"
