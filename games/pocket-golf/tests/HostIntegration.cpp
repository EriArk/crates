// SPDX-License-Identifier: GPL-3.0-or-later
#include <QtTest>
#include <QTemporaryDir>
#include <QSettings>
#include <QProcess>
#include <QScopeGuard>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include "features/accounts/BackendAccount.h"
#include <vector>
#include <algorithm>
#include "platform/sdk/PlatformHost.h"
#include "platform/sdk/SdkNetwork.h"
#include "features/device/ControlsDashboard.h"
#include "features/trainer/AvatarAssets.h"
using namespace trainer;
class HostIntegration final:public QObject {
    Q_OBJECT
private slots:
    void groupGolf_data(){QTest::addColumn<int>("count");for(int n:{2,4,5,8})QTest::newRow(qPrintable(QString::number(n)))<<n;}
    void groupGolf(){
        QFETCH(int,count);
        const auto python=qEnvironmentVariable("TRAINEROS_TEST_RECORD_PYTHON"),godot=qEnvironmentVariable("GOLF_TEST_GODOT"),project=qEnvironmentVariable("GOLF_TEST_PROJECT");
        QVERIFY(!python.isEmpty()&&!godot.isEmpty()&&!project.isEmpty());
        QTemporaryDir dir;QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,dir.path());
        struct Node {LobbyCoordinator lobby;LobbyRuntime runtime{lobby};ControlsDashboard controls;PlatformHost host{controls};BackendAccount account;QNetworkAccessManager http;QByteArray saved;std::unique_ptr<SdkNetwork> network;QProcess process;QString endpoint,report;QByteArray output;bool registered=false;};
        const auto fixtures=qEnvironmentVariable("GOLF_TEST_BACKEND_FIXTURES");
        const bool casual=qEnvironmentVariableIsSet("GOLF_TEST_CASUAL");
        std::vector<std::unique_ptr<Node>> nodes;QStringList ids;
        for(int i=0;i<count;++i){ids<<QString::number(100+i);auto n=std::make_unique<Node>();n->lobby.configure(ids[i],"P"+QString::number(i),true);n->runtime.configure(ids[i],true);
            n->network=std::make_unique<SdkNetwork>(n->lobby,n->runtime,python,QString::fromUtf8(SDK_SOURCE)+"/packaging/emulators/melonds/secure-channel.py","127.0.0.1");
            n->network->setInstalledActivities({QVariantMap{{"app","art.abysstail.pocket-golf"},{"title","Pocket Golf"},{"protocol","pocket-golf.8"},{"seats",8},{"local","crates:pocket-golf"}}});
            n->controls.setOwner(ids[i]);n->host.setContext({{"profile",ids[i]}});n->host.setNetwork(n->network.get());
            if(!fixtures.isEmpty()&&!(casual&&i==count-1)){
                QFile input(fixtures+"/player-"+QString::number(i)+".json");QVERIFY(input.open(QIODevice::ReadOnly));
                const auto config=QJsonDocument::fromJson(input.readAll()).object();
                QCOMPARE(config["origin"].toString(),QString("http://127.0.0.1:19091"));
                auto* node=n.get();node->saved=QJsonDocument(QJsonObject{{"refresh_token",config["refresh_token"]}}).toJson();
                node->account.setServices({[node,this](QByteArray method,QString path,QJsonObject body,QByteArray auth,BackendAccount::Reply done){
                    QNetworkRequest request(QUrl("http://127.0.0.1:19091"+path));request.setHeader(QNetworkRequest::ContentTypeHeader,"application/json");request.setTransferTimeout(15000);
                    if(!auth.isEmpty())request.setRawHeader("Authorization","Bearer "+auth);
                    auto* reply=node->http.sendCustomRequest(request,method,body.isEmpty()?QByteArray():QJsonDocument(body).toJson(QJsonDocument::Compact));
                    connect(reply,&QNetworkReply::finished,this,[reply,done=std::move(done)]{done(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(),QJsonDocument::fromJson(reply->readAll()).object());reply->deleteLater();});
                },[node](QString,auto done){done(true,node->saved);},[node](QString,QByteArray bytes,auto done){node->saved=bytes;done(true);},{}});
                node->host.setBackend(&node->account);node->account.configure(ids[i]);
                QTRY_COMPARE_WITH_TIMEOUT(node->account.snapshot()["state"].toString(),QString("signed_in"),15000);
                node->host.setContext({{"profile",ids[i]},{"account",node->account.snapshot()}});
            }
            if(count==4||count==8){auto a=AvatarAssets::defaults();a["shirtColor"]=AvatarAssets::choices("shirtColor")[i%6];a["hair"]=AvatarAssets::choices("hair")[i/6];
                auto descriptor=AvatarAssets::resolve(a,{},dir.filePath("avatar-"+ids[i]));QVERIFY(!descriptor.contains("error"));descriptor["profile"]=ids[i];n->host.setAvatar(descriptor,true);}
            n->endpoint=dir.filePath(ids[i]+"/endpoint.json");n->report=dir.filePath(ids[i]+".json");QVERIFY(n->host.start(n->endpoint));
            n->process.setProcessChannelMode(QProcess::MergedChannels);
            auto environment=QProcessEnvironment::systemEnvironment();environment.insert("XDG_DATA_HOME",dir.filePath(ids[i]+"/data"));n->process.setProcessEnvironment(environment);
            connect(&n->process,&QProcess::readyReadStandardOutput,this,[node=n.get()]{auto bytes=node->process.readAllStandardOutput();node->output+=bytes;node->registered=node->output.contains("Connected to TrainerOS.");qInfo().noquote()<<bytes;});
            auto* node=n.get();n->network->launchInstalled=[node,godot,project](QString local){if(local!="crates:pocket-golf")return false;if(node->process.state()!=QProcess::NotRunning)return true;
                node->process.start(godot,{"--headless","--path",project,"--script","tests/network_peer.gd","--","--sdk-endpoint="+node->endpoint,"--report="+node->report});return node->process.waitForStarted();};nodes.push_back(std::move(n));}
        for(int i=0;i<count;++i)connect(&nodes[i]->lobby,&LobbyCoordinator::outgoing,this,[&,i](QString target,QJsonObject packet){int j=ids.indexOf(target);if(j>=0)nodes[j]->lobby.receive(ids[i],"P"+QString::number(i),packet);});
        const auto cleanup=qScopeGuard([&]{for(auto& n:nodes){if(n->process.state()!=QProcess::NotRunning){n->process.kill();n->process.waitForFinished();}qInfo().noquote()<<n->process.readAll();n->lobby.disconnect();}});
        qInfo()<<"Creating group";QVERIFY(nodes[0]->lobby.create("private"));for(int i=1;i<count;++i){QVERIFY(nodes[0]->lobby.invite(ids[i]));nodes[i]->lobby.answer(true);}
        const auto a=nodes[0]->network->activities().first().toMap();
        // Warm the eight simultaneous desktop engines before timing SDK admission.
        // Cold installed launch remains covered by the smaller cases and retained eight-game run.
        if(count==8){for(auto& n:nodes)QVERIFY(n->network->launchInstalled("crates:pocket-golf"));
            QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[](const auto& n){return n->registered;}),90000);}
        qInfo()<<"Selecting game";QVERIFY(nodes[0]->lobby.selectGame({a["id"].toString(),a["title"].toString(),"Apps","sdk.records.v1",8,QJsonObject::fromVariantMap(a["runtime"].toMap())}));
        qInfo()<<"Preparing group";for(auto& n:nodes)QVERIFY(n->runtime.prepare());for(auto& n:nodes)QVERIFY(n->lobby.ready(true));QVERIFY(nodes[0]->lobby.start());qInfo()<<"Launched group";
        auto report=[](const QString& path){QFile f(path);if(!f.open(QIODevice::ReadOnly))return QJsonObject{};return QJsonDocument::fromJson(f.readAll()).object();};
        QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[&](const auto& n){return report(n->report)["stage"]=="rematch";}),120000);
        QSet<int> seats;for(auto& n:nodes){const auto r=report(n->report);QCOMPARE(r["result"],report(nodes[0]->report)["result"]);QCOMPARE(r["scores"],report(nodes[0]->report)["scores"]);QCOMPARE(r["starter"].toInt(),1);seats.insert(r["seat"].toInt());}QCOMPARE(seats.size(),count);
        if(!fixtures.isEmpty()&&!casual)for(auto& n:nodes){const auto r=report(n->report);QCOMPARE(r["decision"].toString(),QString("confirmed"));QVERIFY(!r["server_match"].toString().isEmpty());QCOMPARE(r["server_match"],report(nodes[0]->report)["server_match"]);QVERIFY(r["next_match"]!=r["server_match"]);QVERIFY(r["board_rows"].toInt()>=r["roster"].toArray().size());}
        else for(auto& n:nodes)QVERIFY(report(n->report)["next_match"].toString().isEmpty());
        nodes[count-1]->host.setContext({{"profile","other"}});
        QTRY_VERIFY_WITH_TIMEOUT(std::all_of(nodes.begin(),nodes.end(),[&](const auto& n){return report(n->report)["stage"]=="revoked";}),15000);
        for(auto& n:nodes){QTRY_COMPARE_WITH_TIMEOUT(n->process.state(),QProcess::NotRunning,30000);QCOMPARE(n->process.exitCode(),0);}QCOMPARE(nodes[0]->lobby.state()["members"].toArray().size(),count);
        qInfo()<<"GOLF SDK/TLS PASS players="<<count<<"three holes, identical scores, all-player rematch, rotated starter, revocation, retained lobby";
        for(auto& n:nodes)n->lobby.leave();
    }
    void boardPortraits(){
        const auto godot=qEnvironmentVariable("GOLF_TEST_GODOT"),project=qEnvironmentVariable("GOLF_TEST_PROJECT");
        QTemporaryDir dir;ControlsDashboard controls;controls.setOwner("owner");PlatformHost host(controls);host.setContext({{"profile","owner"}});
        auto avatar=AvatarAssets::resolve(AvatarAssets::defaults(),{},dir.filePath("avatars"));QVERIFY(!avatar.contains("error"));avatar["profile"]="owner";host.setAvatar(avatar,true);
        const auto endpoint=dir.filePath("endpoint.json");QVERIFY(host.start(endpoint));
        QProcess proc;proc.setProcessChannelMode(QProcess::MergedChannels);
        auto env=QProcessEnvironment::systemEnvironment();env.insert("TRAINEROS_SDK_ENDPOINT",endpoint);env.insert("GOLF_TEST_BOARD_PORTRAITS","1");proc.setProcessEnvironment(env);
        proc.start(godot,{"--path",project,"--audio-driver","Dummy","--rendering-method","gl_compatibility","--script","tests/scorecards_ui_test.gd"});QVERIFY(proc.waitForStarted());
        const auto cleanup=qScopeGuard([&]{if(proc.state()!=QProcess::NotRunning){proc.kill();proc.waitForFinished();}qInfo().noquote()<<proc.readAll();});
        QTRY_COMPARE_WITH_TIMEOUT(proc.state(),QProcess::NotRunning,120000);QCOMPARE(proc.exitCode(),0);
    }
    void randomStockRival(){
        const auto godot=qEnvironmentVariable("GOLF_TEST_GODOT"),project=qEnvironmentVariable("GOLF_TEST_PROJECT");
        QTemporaryDir dir;ControlsDashboard controls;controls.setOwner("owner");PlatformHost host(controls);host.setContext({{"profile","owner"}});
        auto avatar=AvatarAssets::resolve(AvatarAssets::defaults(),{},dir.filePath("avatars"));QVERIFY(!avatar.contains("error"));avatar["profile"]="owner";host.setAvatar(avatar,true);
        const auto endpoint=dir.filePath("endpoint.json");QVERIFY(host.start(endpoint));
        QProcess proc;proc.setProcessChannelMode(QProcess::MergedChannels);
        proc.start(godot,{"--headless","--path",project,"--script","tests/stock_rival_test.gd","--","--sdk-endpoint="+endpoint});QVERIFY(proc.waitForStarted());
        const auto cleanup=qScopeGuard([&]{if(proc.state()!=QProcess::NotRunning){proc.kill();proc.waitForFinished();}qInfo().noquote()<<proc.readAll();});
        QTRY_COMPARE_WITH_TIMEOUT(proc.state(),QProcess::NotRunning,60000);QCOMPARE(proc.exitCode(),0);
    }
};
int main(int argc,char** argv){QCoreApplication app(argc,argv);app.setOrganizationName("CratesTests");app.setApplicationName("Golf");HostIntegration tests;return QTest::qExec(&tests,argc,argv);}
#include "HostIntegration.moc"
