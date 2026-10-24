// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include <QProcess>
#include "platform/sdk/PlatformHost.h"
#include "platform/sdk/SdkNetwork.h"
#include "features/device/ControlsDashboard.h"
using namespace trainer;
class HostIntegration final:public QObject {
    Q_OBJECT
private slots:
    void twoGodotClients(){
        const auto python=qEnvironmentVariable("TRAINEROS_TEST_RECORD_PYTHON");
        const auto godot=qEnvironmentVariable("GOLF_TEST_GODOT");
        const auto project=qEnvironmentVariable("GOLF_TEST_PROJECT");
        QVERIFY(!python.isEmpty()&&!godot.isEmpty()&&!project.isEmpty());
        QTemporaryDir dir;QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir.path());
        LobbyCoordinator a,b;LobbyRuntime ar(a),br(b);
        a.configure("1","Host",true);b.configure("2","Guest",true);ar.configure("1",true);br.configure("2",true);
        connect(&a,&LobbyCoordinator::outgoing,&b,[&](QString peer,QJsonObject packet){if(peer=="2")b.receive("1","Host",packet);});
        connect(&b,&LobbyCoordinator::outgoing,&a,[&](QString peer,QJsonObject packet){if(peer=="1")a.receive("2","Guest",packet);});
        const auto helper=QString::fromUtf8(SDK_SOURCE)+"/packaging/emulators/melonds/secure-channel.py";
        SdkNetwork an(a,ar,python,helper,"127.0.0.1"),bn(b,br,python,helper,"127.0.0.1");
        ControlsDashboard ad,bd;ad.setOwner("alice");bd.setOwner("bob");
        PlatformHost ah(ad),bh(bd);ah.setNetwork(&an);bh.setNetwork(&bn);ah.setContext({{"profile","alice"}});bh.setContext({{"profile","bob"}});
        const auto ae=dir.filePath("a/endpoint.json"),be=dir.filePath("b/endpoint.json");QVERIFY(ah.start(ae));QVERIFY(bh.start(be));
        QVERIFY(a.create("private"));QVERIFY(a.invite("2"));b.answer(true);
        QProcess ga,gb;ga.setProcessChannelMode(QProcess::MergedChannels);gb.setProcessChannelMode(QProcess::MergedChannels);
        const auto ra=dir.filePath("a.json"),rb=dir.filePath("b.json");
        auto start=[&](QProcess& proc,const QString& ep,const QString& report){proc.start(godot,{"--headless","--path",project,"--script","tests/network_peer.gd","--","--sdk-endpoint="+ep,"--report="+report});return proc.waitForStarted();};
        QVERIFY(start(ga,ae,ra));QVERIFY(start(gb,be,rb));
        auto cleanup=qScopeGuard([&]{for(auto* p:{&ga,&gb}){if(p->state()!=QProcess::NotRunning){p->kill();p->waitForFinished();}qInfo().noquote()<<p->readAll();}});
        QTRY_COMPARE_WITH_TIMEOUT(an.activities().size(),1,10000);QTRY_COMPARE_WITH_TIMEOUT(bn.activities().size(),1,10000);
        const auto activity=an.activities().first().toMap();
        QVERIFY(a.selectGame({activity["id"].toString(),activity["title"].toString(),activity["platform"].toString(),activity["mode"].toString(),2,QJsonObject::fromVariantMap(activity["runtime"].toMap())}));
        QVERIFY(ar.prepare());QVERIFY(br.prepare());QVERIFY(a.ready(true));QVERIFY(b.ready(true));QVERIFY(a.start());
        auto report=[](const QString& path){QFile f(path);if(!f.open(QIODevice::ReadOnly))return QJsonObject{};return QJsonDocument::fromJson(f.readAll()).object();};
        QTRY_COMPARE_WITH_TIMEOUT(report(ra)["stage"].toString(),"rematch",30000);
        QTRY_COMPARE_WITH_TIMEOUT(report(rb)["stage"].toString(),"rematch",10000);
        QCOMPARE(report(ra)["result"],report(rb)["result"]);QCOMPARE(report(ra)["scores"],report(rb)["scores"]);QCOMPARE(report(ra)["starter"].toInt(),1);
        ah.setContext({{"profile","new-owner"}});
        QTRY_COMPARE_WITH_TIMEOUT(report(ra)["stage"].toString(),"revoked",5000);QTRY_COMPARE_WITH_TIMEOUT(report(rb)["stage"].toString(),"revoked",10000);
        QTRY_COMPARE(ga.state(),QProcess::NotRunning);QTRY_COMPARE(gb.state(),QProcess::NotRunning);
        QCOMPARE(ga.exitCode(),0);QCOMPARE(gb.exitCode(),0);QCOMPARE(a.state()["members"].toArray().size(),2);
        qInfo()<<"Two Godot processes: 3 holes, equal result, mutual rematch, alternating starter, profile revocation, retained lobby passed";
        a.leave();b.leave();
    }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("Golf");HostIntegration tests;return QTest::qExec(&tests,argc,argv);}
#include "HostIntegration.moc"
