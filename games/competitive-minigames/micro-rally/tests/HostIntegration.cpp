// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from Pocket Golf's host integration harness; real SDK and TLS helpers,
// substituted provider signaling only. No user accounts/devices are touched.
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include <QProcess>
#include <QScopeGuard>
#include <vector>
#include <algorithm>
#include "platform/sdk/PlatformHost.h"
#include "platform/sdk/SdkNetwork.h"
#include "features/device/ControlsDashboard.h"
using namespace trainer;
class HostIntegration final:public QObject {
    Q_OBJECT
private slots:
    void groupRace_data(){QTest::addColumn<int>("count");for(int n:{2,16})QTest::newRow(qPrintable(QString::number(n)))<<n;}
    void groupRace(){
        QFETCH(int,count);
        const auto python=qEnvironmentVariable("TRAINEROS_TEST_RECORD_PYTHON"),godot=qEnvironmentVariable("RALLY_TEST_GODOT"),project=qEnvironmentVariable("RALLY_TEST_PROJECT");
        QVERIFY(!python.isEmpty()&&!godot.isEmpty()&&!project.isEmpty());
        QTemporaryDir dir;QVERIFY(dir.isValid());qputenv("HOME",dir.path().toUtf8());QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir.path());
        struct Node {LobbyCoordinator lobby;LobbyRuntime runtime{lobby};ControlsDashboard controls;PlatformHost host{controls};std::unique_ptr<SdkNetwork> network;QProcess process;QString endpoint,report;QByteArray output;bool registered=false;};
        std::vector<std::unique_ptr<Node>> nodes;QStringList ids;
        for(int i=0;i<count;++i){
            ids<<QString::number(100+i);auto n=std::make_unique<Node>();n->lobby.configure(ids[i],"P"+QString::number(i),true);n->runtime.configure(ids[i],true);
            n->network=std::make_unique<SdkNetwork>(n->lobby,n->runtime,python,QString::fromUtf8(SDK_SOURCE)+"/packaging/emulators/melonds/secure-channel.py","127.0.0.1");
            n->network->setInstalledActivities({QVariantMap{{"app","art.abysstail.micro-rally"},{"title","Micro Rally"},{"protocol","micro-rally.1"},{"seats",16},{"local","crates:micro-rally"}}});
            n->controls.setOwner(ids[i]);n->host.setContext({{"profile",ids[i]}});n->host.setNetwork(n->network.get());
            n->endpoint=dir.filePath(ids[i]+"/endpoint.json");n->report=dir.filePath(ids[i]+".json");QString error;QVERIFY2(n->host.start(n->endpoint,&error),qPrintable(error));
            n->process.setProcessChannelMode(QProcess::MergedChannels);
            connect(&n->process,&QProcess::readyReadStandardOutput,this,[node=n.get()]{auto bytes=node->process.readAllStandardOutput();node->output+=bytes;node->registered=node->output.contains("RALLY attached");qInfo().noquote()<<bytes;});
            auto* node=n.get();n->network->launchInstalled=[node,godot,project](QString local){
                if(local!="crates:micro-rally")return false;if(node->process.state()!=QProcess::NotRunning)return true;
                node->process.start(godot,{"--headless","--path",project,"--script","tests/network_peer.gd","--","--sdk-endpoint="+node->endpoint,"--report="+node->report});return node->process.waitForStarted();};
            nodes.push_back(std::move(n));
        }
        for(int i=0;i<count;++i)connect(&nodes[i]->lobby,&LobbyCoordinator::outgoing,this,[&,i](QString target,QJsonObject packet){int j=ids.indexOf(target);if(j>=0)nodes[j]->lobby.receive(ids[i],"P"+QString::number(i),packet);});
        const auto cleanup=qScopeGuard([&]{for(auto& n:nodes){if(n->process.state()!=QProcess::NotRunning){n->process.kill();n->process.waitForFinished();}qInfo().noquote()<<n->process.readAll();n->lobby.disconnect();}});
        QVERIFY(nodes[0]->lobby.create("private"));for(int i=1;i<count;++i){QVERIFY(nodes[0]->lobby.invite(ids[i]));nodes[i]->lobby.answer(true);}
        // Warm the 16 scene imports before timing SDK admission. Two-player case is cold.
        if(count==16){for(auto& n:nodes)QVERIFY(n->network->launchInstalled("crates:micro-rally"));
            QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->registered;}),120000);}
        const auto a=nodes[0]->network->activities().first().toMap();
        QVERIFY(nodes[0]->lobby.selectGame({a["id"].toString(),a["title"].toString(),"Apps","sdk.records.v1",16,QJsonObject::fromVariantMap(a["runtime"].toMap())}));
        for(auto& n:nodes)QVERIFY(n->runtime.prepare());for(auto& n:nodes)QVERIFY(n->lobby.ready(true));QVERIFY(nodes[0]->lobby.start());
        auto report=[](const QString& path){QFile f(path);if(!f.open(QIODevice::ReadOnly))return QJsonObject{};return QJsonDocument::fromJson(f.readAll()).object();};
        QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[&](const auto& n){return report(n->report)["stage"]=="rematch";}),480000);
        QSet<int> seats;for(auto& n:nodes){const auto r=report(n->report);QCOMPARE(r["result"],report(nodes[0]->report)["result"]);QVERIFY(r["progress"].toInt()>15);seats.insert(r["local"].toInt());QVERIFY(!n->output.contains("SCRIPT ERROR:"));}QCOMPARE(seats.size(),count);
        nodes[count-1]->host.setContext({{"profile","other"}});
        QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[&](const auto& n){return report(n->report)["stage"]=="revoked";}),20000);
        for(int i=0;i<count;++i)QCOMPARE(report(nodes[i]->report)["registered"].toBool(),i!=count-1);
        for(auto& n:nodes){QTRY_COMPARE_WITH_TIMEOUT(n->process.state(),QProcess::NotRunning,30000);QCOMPARE(n->process.exitCode(),0);}
        QCOMPARE(nodes[0]->lobby.state()["members"].toArray().size(),count);
        qInfo()<<"RALLY SDK/TLS PASS players="<<count<<"same result, rematch, profile revocation, retained lobby; terminal fixture="<<(count==16);
        for(auto& n:nodes)n->lobby.leave();
    }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("Rally");HostIntegration tests;return QTest::qExec(&tests,argc,argv);}
#include "HostIntegration.moc"
