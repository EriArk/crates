// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include "platform/sdk/PlatformHost.h"
#include "platform/sdk/SdkNetwork.h"
#include "features/device/ControlsDashboard.h"
#include "ArcadeGame.h"
using namespace trainer;
using namespace arcade;
class HostTests final:public QObject {
    Q_OBJECT
private slots:
    void matchLifecycle_data(){QTest::addColumn<int>("kind");QTest::newRow("pong")<<0;QTest::newRow("snake")<<1;QTest::newRow("cycles")<<2;
        QTest::newRow("blocks")<<3;QTest::newRow("mines")<<4;QTest::newRow("chain")<<5;}
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
        const auto ae=dir.filePath("a/endpoint.json"),be=dir.filePath("b/endpoint.json");QVERIFY(ah.start(ae));QVERIFY(bh.start(be));
        QVERIFY(a.create("private"));QVERIFY(a.invite("2"));b.answer(true);
        ArcadeGame ga(Kind(kind),ae),gb(Kind(kind),be);ga.join();gb.join();
        QString lastA,lastB;
        connect(&ga,&ArcadeGame::changed,&ga,[&]{const auto value=ga.phase()+": "+ga.status();if(value!=lastA){lastA=value;qInfo().noquote()<<"host"<<value;}});
        connect(&gb,&ArcadeGame::changed,&gb,[&]{const auto value=gb.phase()+": "+gb.status();if(value!=lastB){lastB=value;qInfo().noquote()<<"guest"<<value;}});
        QTRY_COMPARE(an.activities().size(),1);QTRY_COMPARE(bn.activities().size(),1);
        const auto activity=an.activities().first().toMap();
        auto launch=[&]{return a.selectGame({activity["id"].toString(),activity["title"].toString(),activity["platform"].toString(),activity["mode"].toString(),2,QJsonObject::fromVariantMap(activity["runtime"].toMap())})&&ar.prepare()&&br.prepare()&&a.ready(true)&&b.ready(true)&&a.start();};
        QVERIFY(launch());QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"play",30000);QTRY_COMPARE(gb.phase(),"play");
        QCOMPARE(ga.seat(),0);QCOMPARE(gb.seat(),1);
        ga.control(0,0);gb.control(0,2); // Input from both sides traverses the game contract.
        QTRY_VERIFY_WITH_TIMEOUT(gb.scene()["tick"].toInt()>66,5000);
        if(kind==0){QVERIFY(ga.scene()["p0"].toInt()<270);QVERIFY(ga.scene()["p1"].toInt()>270);}
        QTimer drive;int target=0;
        if(kind>=3){
            ga.neutral();gb.neutral();
            connect(&drive,&QTimer::timeout,&gb,[&]{
                if(gb.phase()!="play")return;
                if(kind!=4){ga.action(0,1);gb.action(0,1);return;}
                // Guest walks/reveals the board through actual ordered SDK action records.
                const auto player=gb.scene()["players"].toList()[1].toMap();const int cursor=player["cursor"].toInt();
                if(cursor==target){gb.neutral();gb.action(0,0);target=(target+1)%81;}
                else gb.control(0,cursor%9<target%9?1:cursor%9>target%9?3:cursor/9<target/9?2:0);
            });drive.start(250);
        }
        QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"result",90000);QTRY_COMPARE(gb.phase(),"result");QCOMPARE(ga.scene(),gb.scene());
        drive.stop();
        ga.rematch();QTest::qWait(150);QCOMPARE(ga.phase(),"result");gb.rematch();
        QTRY_COMPARE(ga.phase(),"play");QTRY_COMPARE(gb.phase(),"play");QVERIFY(ga.scene()["tick"].toInt()<60);
        ga.leave();QTRY_COMPARE(gb.phase(),"menu");QTRY_COMPARE(a.state()["phase"].toString(),"gathering");QCOMPARE(a.state()["members"].toArray().size(),2);
        ga.join();gb.join();QVERIFY(launch());QTRY_VERIFY_WITH_TIMEOUT(ga.phase()=="play"||ga.phase()=="menu",30000);QCOMPARE(ga.phase(),"play");QTRY_COMPARE(gb.phase(),"play");
        ah.setContext({{"profile","other"}});QTRY_COMPARE(ga.phase(),"menu");QTRY_COMPARE(gb.phase(),"menu");QCOMPARE(a.state()["members"].toArray().size(),2);
        // A peer cannot assign a winner or write a host snapshot.
        gb.local();QTRY_VERIFY(bn.activities().isEmpty());ArcadeBridge bad(identity(Kind(kind)),be);bool began=false;
        connect(&bad,&ArcadeBridge::record,&bad,[&](QJsonObject packet){
            if(packet["type"]=="start")bad.send({{"type","ready"},{"round",packet["round"]}});
            if(packet["type"]=="begin"){began=true;if(kind>=3)bad.send({{"type","action"},{"round",1},{"seq",0},{"action",99}});
                else bad.send({{"type","state"},{"round",1},{"state",QJsonObject{{"winner",1}}}});}
        });
        ga.join();bad.connectHost();QTRY_COMPARE(an.activities().size(),1);QTRY_COMPARE(bn.activities().size(),1);
        QVERIFY(launch());QTRY_VERIFY_WITH_TIMEOUT(began,30000);QTRY_COMPARE(ga.phase(),"menu");
        QCOMPARE(ga.scene()["winner"].toInt(),-1);QCOMPARE(a.state()["members"].toArray().size(),2);
        a.leave();b.leave();
    }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("Arcade");HostTests test;return QTest::qExec(&test,argc,argv);}
#include "HostTests.moc"
