// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include "platform/sdk/PlatformHost.h"
#include "platform/sdk/SdkNetwork.h"
#include "features/device/ControlsDashboard.h"
#include "features/trainer/AvatarAssets.h"
#include "ArcadeGame.h"
#include "tanks/src/TanksRules.h"
#include <vector>
#include <algorithm>
#include <QScopeGuard>
using namespace trainer;
using namespace arcade;
class HostTests final:public QObject {
    Q_OBJECT
private slots:
    void sixteenTanksThroughSdk(){
        const auto python=qEnvironmentVariable("TRAINEROS_TEST_RECORD_PYTHON");QVERIFY(!python.isEmpty());
        QTemporaryDir dir;QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir.path());
        struct Node {LobbyCoordinator lobby;LobbyRuntime runtime{lobby};ControlsDashboard controls;PlatformHost host{controls};std::unique_ptr<SdkNetwork> network;std::unique_ptr<ArcadeGame> game;};
        std::vector<std::unique_ptr<Node>> nodes;QStringList ids;
        for(int i=0;i<16;++i){ids<<QString::number(100+i);auto n=std::make_unique<Node>();n->lobby.configure(ids[i],"P"+QString::number(i),true);n->runtime.configure(ids[i],true);
            n->network=std::make_unique<SdkNetwork>(n->lobby,n->runtime,python,QString::fromUtf8(SDK_SOURCE)+"/packaging/emulators/melonds/secure-channel.py","127.0.0.1");
            n->network->setInstalledActivities({QVariantMap{{"app","art.abysstail.tanks"},{"title","Brick Tanks"},{"protocol","tanks.3"},{"seats",16},{"local","crates:tanks"}}});
            n->controls.setOwner(ids[i]);n->host.setContext({{"profile",ids[i]}});n->host.setNetwork(n->network.get());
            const auto endpoint=dir.filePath(ids[i]+"/endpoint.json");QVERIFY(n->host.start(endpoint));n->game=std::make_unique<ArcadeGame>(Kind::Tanks,endpoint);
            auto* node=n.get();n->network->launchInstalled=[node](QString local){if(local!="crates:tanks")return false;node->game->attach();return true;};nodes.push_back(std::move(n));}
        for(int i=0;i<16;++i)connect(&nodes[i]->lobby,&LobbyCoordinator::outgoing,this,[&,i](QString target,QJsonObject packet){int j=ids.indexOf(target);if(j>=0)nodes[j]->lobby.receive(ids[i],"P"+QString::number(i),packet);});
        const auto cleanup=qScopeGuard([&]{for(auto& n:nodes)n->lobby.disconnect();});
        QVERIFY(nodes[0]->lobby.create("private"));for(int i=1;i<16;++i){QVERIFY(nodes[0]->lobby.invite(ids[i]));nodes[i]->lobby.answer(true);}
        auto start=[&]{const auto a=nodes[0]->network->activities().first().toMap();if(!nodes[0]->lobby.selectGame({a["id"].toString(),a["title"].toString(),"Apps","sdk.records.v1",16,QJsonObject::fromVariantMap(a["runtime"].toMap())}))return false;
            for(auto& n:nodes)if(!n->runtime.prepare())return false;for(auto& n:nodes)if(!n->lobby.ready(true))return false;return nodes[0]->lobby.start();};
        QVERIFY(start());QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->game->phase()=="play";}),60000);
        QSet<int> seats;for(auto& n:nodes){seats.insert(n->game->seat());QCOMPARE(n->game->scene()["players"].toList().size(),16);}QCOMPARE(seats.size(),16);
        QTimer drive;connect(&drive,&QTimer::timeout,this,[&]{if(nodes[0]->game->phase()!="play")return;
            const auto state=nodes[0]->game->scene();TanksRules brain;brain.reset(1,16);brain.tick=state["tick"].toInt();
            auto cells=state["cells"].toList();for(int i=0;i<cells.size();++i)brain.cells[i]=cells[i].toInt();
            const auto players=state["players"].toList();for(int i=0;i<16;++i){auto p=players[i].toMap();brain.tanks[i].pos={p["x"].toInt(),p["y"].toInt()};brain.tanks[i].face=p["face"].toInt();brain.tanks[i].cooldown=p["cooldown"].toInt();}
            for(auto& n:nodes){int seat=n->game->seat();n->game->control(0,brain.bot(seat));if(brain.botAction(seat)==0)n->game->action(0,0);}
        });drive.start(130);
        QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->game->phase()=="result";}),150000);drive.stop();
        for(auto& n:nodes)QCOMPARE(n->game->scene(),nodes[0]->game->scene());
        for(int i=0;i<15;++i)nodes[i]->game->rematch();QTest::qWait(200);QCOMPARE(nodes[0]->game->phase(),"result");nodes[15]->game->rematch();
        QTRY_VERIFY(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->game->phase()=="play";}));
        nodes[8]->game->leave();QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->game->phase()=="menu";}),10000);
        QCOMPARE(nodes[0]->lobby.state()["members"].toArray().size(),16);
        QVERIFY(start());QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->game->phase()=="play";}),60000);
        QJsonObject result;QVERIFY(nodes[3]->network->request("art.abysstail.tanks","activity.get",{},result).isEmpty());
        const auto channel=result["session"].toObject()["channel"].toString();
        const auto forged=QJsonDocument(QJsonObject{{"type","state"},{"round",1},{"state",QJsonObject{{"winner",3}}}}).toJson(QJsonDocument::Compact).toBase64();
        QVERIFY(nodes[3]->network->request("art.abysstail.tanks","network.send",{{"channel",channel},{"data",QString::fromLatin1(forged)}},result).isEmpty());
        QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->game->phase()=="menu";}),10000);
        QCOMPARE(nodes[0]->game->scene()["winner"].toInt(),-1);for(auto& n:nodes)n->lobby.leave();
    }
    void matchLifecycle_data(){QTest::addColumn<int>("kind");QTest::newRow("pong")<<0;QTest::newRow("snake")<<1;QTest::newRow("cycles")<<2;
        QTest::newRow("blocks")<<3;QTest::newRow("mines")<<4;QTest::newRow("chain")<<5;QTest::newRow("racing")<<6;QTest::newRow("tanks")<<7;}
    void matchLifecycle(){
        QFETCH(int,kind);const auto python=qEnvironmentVariable("TRAINEROS_TEST_RECORD_PYTHON");QVERIFY(!python.isEmpty());
        QTemporaryDir dir;QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir.path());
        LobbyCoordinator a,b;LobbyRuntime ar(a),br(b);a.configure("1","Host",true);b.configure("2","Guest",true);ar.configure("1",true);br.configure("2",true);
        connect(&a,&LobbyCoordinator::outgoing,&b,[&](QString peer,QJsonObject packet){if(peer=="2")b.receive("1","Host",packet);});
        connect(&b,&LobbyCoordinator::outgoing,&a,[&](QString peer,QJsonObject packet){if(peer=="1")a.receive("2","Guest",packet);});
        const auto helper=QString::fromUtf8(SDK_SOURCE)+"/packaging/emulators/melonds/secure-channel.py";
        SdkNetwork an(a,ar,python,helper,"127.0.0.1"),bn(b,br,python,helper,"127.0.0.1");
        ControlsDashboard ad,bd;ad.setOwner("alice");bd.setOwner("bob");PlatformHost ah(ad),bh(bd);ah.setNetwork(&an);bh.setNetwork(&bn);
        ah.setContext({{"profile","alice"}});bh.setContext({{"profile","bob"}});
        QJsonObject avatarA,avatarB;
        if(kind==0){
            auto appearance=AvatarAssets::defaults();avatarA=AvatarAssets::resolve(appearance,{},dir.filePath("avatar-a"));
            appearance["hair"]="bob";appearance["hairColor"]="#d8b468";
            avatarB=AvatarAssets::resolve(appearance,{},dir.filePath("avatar-b"));
            QVERIFY(!avatarA.contains("error"));QVERIFY(!avatarB.contains("error"));
            avatarA["profile"]="alice";avatarB["profile"]="bob";ah.setAvatar(avatarA,true);bh.setAvatar(avatarB,true);
        }
        const auto ae=dir.filePath("a/endpoint.json"),be=dir.filePath("b/endpoint.json");QVERIFY(ah.start(ae));QVERIFY(bh.start(be));
        QVERIFY(a.create("private"));QVERIFY(a.invite("2"));b.answer(true);
        ArcadeGame ga(Kind(kind),ae),gb(Kind(kind),be);
        const auto slug=identity(Kind(kind)).id;
        const QVariantList installed{QVariantMap{{"app","art.abysstail."+slug},{"title",slug},{"protocol",identity(Kind(kind)).id+((Kind(kind)==Kind::Racing||Kind(kind)==Kind::Tanks)?".3":".2")},{"seats",kind==7?16:2},{"local","crates:"+slug}}};
        an.setInstalledActivities(installed);bn.setInstalledActivities(installed);
        int launches=0;
        an.launchInstalled=[&](QString local){if(local!="crates:"+slug)return false;++launches;ga.attach();return true;};
        bn.launchInstalled=[&](QString local){if(local!="crates:"+slug)return false;++launches;gb.attach();return true;};
        QSignalSpy openedA(&an,&SdkNetwork::openLobbyRequested),openedB(&bn,&SdkNetwork::openLobbyRequested);
        QCOMPARE(ga.phase(),"menu");QCOMPARE(gb.phase(),"menu");
        QString lastA,lastB;
        connect(&ga,&ArcadeGame::changed,&ga,[&]{const auto value=ga.phase()+": "+ga.status();if(value!=lastA){lastA=value;qInfo().noquote()<<"host"<<value;}});
        connect(&gb,&ArcadeGame::changed,&gb,[&]{const auto value=gb.phase()+": "+gb.status();if(value!=lastB){lastB=value;qInfo().noquote()<<"guest"<<value;}});
        QTRY_COMPARE(an.activities().size(),1);QTRY_COMPARE(bn.activities().size(),1);
        const auto activity=an.activities().first().toMap();
        auto launch=[&]{return a.selectGame({activity["id"].toString(),activity["title"].toString(),activity["platform"].toString(),activity["mode"].toString(),activity["seats"].toInt(),QJsonObject::fromVariantMap(activity["runtime"].toMap())})&&ar.prepare()&&br.prepare()&&a.ready(true)&&b.ready(true)&&a.start();};
        QVERIFY(launch());QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"play",30000);QTRY_COMPARE(gb.phase(),"play");
        QCOMPARE(launches,2);QCOMPARE(openedA.count(),0);QCOMPARE(openedB.count(),0);
        QCOMPARE(ga.seat(),0);QCOMPARE(gb.seat(),1);
        if(kind==0){
            auto* cardsA=qobject_cast<AvatarCards*>(ga.avatars());auto* cardsB=qobject_cast<AvatarCards*>(gb.avatars());
            QVERIFY(cardsA&&cardsB);
            QTRY_VERIFY_WITH_TIMEOUT(!cardsA->peer().isEmpty(),30000);QTRY_VERIFY_WITH_TIMEOUT(!cardsB->peer().isEmpty(),30000);
            QCOMPARE(cardsA->local()["appearance"].toMap(),avatarA["appearance"].toObject().toVariantMap());
            QCOMPARE(cardsA->peer()["appearance"].toMap(),avatarB["appearance"].toObject().toVariantMap());
            QCOMPARE(cardsB->peer()["appearance"].toMap(),avatarA["appearance"].toObject().toVariantMap());
            QVERIFY(cardsA->local()["appearance"]!=cardsA->peer()["appearance"]);
        }
        ga.control(0,kind==7?1:0);gb.control(0,kind==7?3:2); // Input from both sides traverses the game contract.
        QTRY_VERIFY_WITH_TIMEOUT(gb.scene()["tick"].toInt()>66,5000);
        if(kind==0){QVERIFY(ga.scene()["p0"].toInt()<270);QVERIFY(ga.scene()["p1"].toInt()>270);}
        QTimer drive;int target=0;
        if(kind>=3){
            ga.neutral();gb.neutral();
            if(kind==6){ga.control(0,0);gb.control(0,0);}
            connect(&drive,&QTimer::timeout,&gb,[&]{
                if(gb.phase()!="play")return;
                if(kind==7){
                    auto guest=gb.scene()["players"].toList()[1].toMap();int x=guest["x"].toInt(),y=guest["y"].toInt();
                    int hostX=ga.scene()["players"].toList()[0].toMap()["x"].toInt();
                    if(target==0){ga.action(0,0);gb.control(0,0);if(y==2)target=1;}
                    if(target==1){if(std::abs(x-hostX)<=1)target=2;else gb.control(0,x>hostX?3:1);}
                    if(target==2){gb.control(0,std::abs(x-hostX)>1?(x>hostX?3:1):2);gb.action(0,0);}return;
                }
                if(kind!=4){ga.action(0,kind>=6?0:1);gb.action(0,kind>=6?0:1);return;}
                // Guest walks/reveals the board through actual ordered SDK action records.
                const auto player=gb.scene()["players"].toList()[1].toMap();const int cursor=player["cursor"].toInt();
                if(cursor==target){gb.neutral();gb.action(0,0);target=(target+1)%81;}
                else gb.control(0,cursor%9<target%9?1:cursor%9>target%9?3:cursor/9<target/9?2:0);
            });drive.start(250);
        }
        // Tanks has a 120-second rules limit when neither player lands enough hits.
        QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"result",kind==7?150000:90000);QTRY_COMPARE(gb.phase(),"result");QCOMPARE(ga.scene(),gb.scene());
        drive.stop();
        ga.rematch();QTest::qWait(150);QCOMPARE(ga.phase(),"result");gb.rematch();
        QTRY_COMPARE(ga.phase(),"play");QTRY_COMPARE(gb.phase(),"play");QVERIFY(ga.scene()["tick"].toInt()<60);
        ga.leave();QTRY_COMPARE(gb.phase(),"menu");QTRY_COMPARE(a.state()["phase"].toString(),"gathering");QCOMPARE(a.state()["members"].toArray().size(),2);
        QVERIFY(launch());QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"play",30000);QTRY_COMPARE(gb.phase(),"play");
        ah.setContext({{"profile","other"}});QTRY_COMPARE(ga.phase(),"menu");QTRY_COMPARE(gb.phase(),"menu");QCOMPARE(a.state()["members"].toArray().size(),2);
        // A peer cannot assign a winner or write a host snapshot.
        gb.local();QTest::qWait(100);QCOMPARE(bn.activities().size(),1);ArcadeBridge bad(identity(Kind(kind)),be);bool began=false;
        connect(&bad,&ArcadeBridge::record,&bad,[&](QJsonObject packet){
            if(packet["type"]=="start")bad.send({{"type","ready"},{"round",packet["round"]}});
            if(packet["type"]=="begin"){began=true;if(kind>=3)bad.send({{"type","action"},{"round",1},{"seq",0},{"action",99}});
                else bad.send({{"type","state"},{"round",1},{"state",QJsonObject{{"winner",1}}}});}
        });
        connect(&bad,&ArcadeBridge::groupRecord,&bad,[&](QString,QJsonObject packet){
            if(packet["type"]=="start")bad.sendGroup({{"type","ready"},{"round",packet["round"]}});
            if(packet["type"]=="begin"){began=true;bad.sendGroup({{"type","action"},{"round",1},{"seq",0},{"action",99}});}
        });
        bn.launchInstalled=[&](QString){bad.connectHost();return true;};ga.attach();bad.connectHost();QTRY_VERIFY(bad.registered());QTRY_COMPARE(an.activities().size(),1);QTRY_COMPARE(bn.activities().size(),1);
        QVERIFY(launch());QTRY_VERIFY_WITH_TIMEOUT(began,30000);QTRY_COMPARE(ga.phase(),"menu");
        QCOMPARE(ga.scene()["winner"].toInt(),-1);QCOMPARE(a.state()["members"].toArray().size(),2);
        a.leave();b.leave();
    }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("Arcade");HostTests test;return QTest::qExec(&test,argc,argv);}
#include "HostTests.moc"
