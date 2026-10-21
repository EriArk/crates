// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include "platform/sdk/PlatformHost.h"
#include "platform/sdk/SdkNetwork.h"
#include "features/device/ControlsDashboard.h"
#include "Game.h"
using namespace trainer;

class HostIntegration final:public QObject {
    Q_OBJECT
private slots:
    void completeDuelRematchAndRejoin(){
        const auto python=qEnvironmentVariable("TRAINEROS_TEST_RECORD_PYTHON");
        QVERIFY2(!python.isEmpty(),"Set TRAINEROS_TEST_RECORD_PYTHON to the secure helper venv");
        QTemporaryDir dir;QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir.path());
        LobbyCoordinator a,b;LobbyRuntime ar(a),br(b);
        a.configure("1","Host",true);b.configure("2","Guest",true);ar.configure("1",true);br.configure("2",true);
        // Only provider signaling is a fixture; game records traverse real TLS helper processes.
        connect(&a,&LobbyCoordinator::outgoing,&b,[&](QString peer,QJsonObject packet){if(peer=="2")b.receive("1","Host",packet);});
        connect(&b,&LobbyCoordinator::outgoing,&a,[&](QString peer,QJsonObject packet){if(peer=="1")a.receive("2","Guest",packet);});
        const auto helper=QString::fromUtf8(SDK_SOURCE)+"/packaging/emulators/melonds/secure-channel.py";
        SdkNetwork an(a,ar,python,helper,"127.0.0.1"),bn(b,br,python,helper,"127.0.0.1");
        ControlsDashboard ad,bd;ad.setOwner("alice");bd.setOwner("bob");
        PlatformHost ah(ad),bh(bd);ah.setNetwork(&an);bh.setNetwork(&bn);ah.setContext({{"profile","alice"}});bh.setContext({{"profile","bob"}});
        const auto ae=dir.filePath("a/endpoint.json"),be=dir.filePath("b/endpoint.json");QVERIFY(ah.start(ae));QVERIFY(bh.start(be));
        QVERIFY(a.create("private"));QVERIFY(a.invite("2"));b.answer(true);
        Game ga(ae),gb(be);ga.join();gb.join();
        QTRY_COMPARE_WITH_TIMEOUT(an.activities().size(),1,10000);QTRY_COMPARE_WITH_TIMEOUT(bn.activities().size(),1,10000);
        const auto activity=an.activities().first().toMap();
        auto launch=[&]{return a.selectGame({activity["id"].toString(),activity["title"].toString(),activity["platform"].toString(),activity["mode"].toString(),2,QJsonObject::fromVariantMap(activity["runtime"].toMap())})&&ar.prepare()&&br.prepare()&&a.ready(true)&&b.ready(true)&&a.start();};
        QVERIFY(launch());QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"aim",30000);QTRY_COMPARE_WITH_TIMEOUT(gb.phase(),"aim",10000);
        QCOMPARE(ga.seat(),0);QCOMPARE(gb.seat(),1);QCOMPARE(ga.world().digest(),gb.world().digest());
        gb.fire();QCOMPARE(gb.world().ply,0); // Non-owner cannot shoot.
        int turns=0;
        while(ga.world().winner==-1&&turns++<60){
            Game& current=ga.world().turn==0?ga:gb;
            QTRY_VERIFY_WITH_TIMEOUT(current.canFire(),5000);
            int best=-10000,angle=45,power=85;
            for(int aim=10;aim<=80;aim+=5)for(int strength=20;strength<=100;strength+=5){
                auto copy=current.world();copy.fire(aim,strength);const int me=current.seat(),peer=1-me;
                const int score=(current.world().hp[peer]-copy.hp[peer])*3-(current.world().hp[me]-copy.hp[me])*4;
                if(score>best){best=score;angle=aim;power=strength;}
            }
            current.aim((angle-current.angle())/5);current.charge((power-current.power())/5);current.fire();
            QTRY_COMPARE_WITH_TIMEOUT(ga.world().ply,turns,5000);QTRY_COMPARE_WITH_TIMEOUT(gb.world().ply,turns,5000);
            QCOMPARE(ga.world().digest(),gb.world().digest());
        }
        QVERIFY(ga.world().winner!=-1);QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"result",5000);QTRY_COMPARE_WITH_TIMEOUT(gb.phase(),"result",5000);
        ga.rematch();QTest::qWait(200);QCOMPARE(ga.phase(),"result");QCOMPARE(gb.phase(),"result");
        gb.rematch();QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"aim",5000);QTRY_COMPARE_WITH_TIMEOUT(gb.phase(),"aim",5000);
        QCOMPARE(ga.world().ply,0);QCOMPARE(ga.world().turn,1);QCOMPARE(ga.world().digest(),gb.world().digest());
        ga.leave();QTRY_COMPARE_WITH_TIMEOUT(gb.phase(),"menu",5000);QTRY_COMPARE(a.state()["phase"].toString(),"gathering");QCOMPARE(a.state()["members"].toArray().size(),2);
        ga.join();gb.join();QVERIFY(launch());QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"aim",30000);QTRY_COMPARE_WITH_TIMEOUT(gb.phase(),"aim",5000);
        QCOMPARE(ga.world().ply,0);QCOMPARE(ga.world().turn,0);
        ah.setContext({{"profile","new-owner"}});QTRY_COMPARE(ga.phase(),"menu");QTRY_COMPARE_WITH_TIMEOUT(gb.phase(),"menu",10000);
        QVERIFY(!ga.canFire());QCOMPARE(a.state()["members"].toArray().size(),2);
        // A peer can send arbitrary records. A fabricated result must end the duel,
        // not authorize state replacement or a ranked victory.
        gb.local();QTRY_VERIFY(bn.activities().isEmpty());
        Bridge bad(be);bool began=false,forgeOwnedTurn=false;
        connect(&bad,&Bridge::record,&bad,[&](QJsonObject packet){
            if(packet["type"]=="start")bad.send({{"type","ready"},{"round",packet["round"]},{"hash",packet["hash"]}});
            if(packet["type"]=="begin"){
                began=true;
                if(!forgeOwnedTurn)bad.send({{"type","shot"},{"round",1},{"ply",0},{"angle",45},{"power",85},{"before",ga.world().digest()},{"after","fabricated"}});
            }
            if(forgeOwnedTurn&&packet["type"]=="shot")
                bad.send({{"type","shot"},{"round",1},{"ply",1},{"angle",45},{"power",85},{"before",ga.world().digest()},{"after","fabricated"}});
        });
        ga.join();bad.connectHost();QTRY_COMPARE(an.activities().size(),1);QTRY_COMPARE(bn.activities().size(),1);
        QVERIFY(launch());QTRY_VERIFY_WITH_TIMEOUT(began,30000);QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"menu",5000);
        QCOMPARE(ga.world().ply,0);QVERIFY(ga.connection().contains("sync"));QCOMPARE(a.state()["members"].toArray().size(),2);
        // Now forge a result on a legitimate turn: validation must reject it
        // without committing the candidate state, independently of turn ownership.
        QTRY_VERIFY(bad.channel().isEmpty());QTRY_COMPARE(a.state()["phase"].toString(),"gathering");
        forgeOwnedTurn=true;began=false;ga.join();bad.connectHost();QVERIFY(launch());
        QTRY_VERIFY_WITH_TIMEOUT(began,30000);QTRY_VERIFY(ga.canFire());
        auto expected=ga.world();expected.fire(ga.angle(),ga.power());ga.fire();
        QTRY_COMPARE_WITH_TIMEOUT(ga.phase(),"menu",5000);
        QCOMPARE(ga.world().digest(),expected.digest());QVERIFY(ga.connection().contains("sync"));
        QCOMPARE(a.state()["members"].toArray().size(),2);
        a.leave();b.leave();
    }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("Artillery");HostIntegration tests;return QTest::qExec(&tests,argc,argv);}
#include "HostIntegration.moc"
