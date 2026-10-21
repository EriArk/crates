// SPDX-License-Identifier: GPL-3.0-or-later
#include "Timer.h"
#include <QFile>
#include <QDir>
#include <QSaveFile>
#include <QStandardPaths>
#include <QJsonDocument>
#include <QCryptographicHash>

Timer::Timer(QString endpoint,QString storage,QObject* parent):QObject(parent),endpoint_(endpoint),storage_(storage) {
    if(endpoint_.isEmpty())endpoint_=qEnvironmentVariable("TRAINEROS_SDK_ENDPOINT");
    if(endpoint_.isEmpty())endpoint_=QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)+"/traineros/platform-v1/endpoint.json";
    if(storage_.isEmpty())storage_=qEnvironmentVariable("TRAINEROS_PACKAGE_DATA");
    if(storage_.isEmpty())storage_=QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)+"/abysstail/session-timer";
    connect(&socket_,&QTcpSocket::connected,this,[this]{call("hello",{{"protocol",1},{"token",token_},{"app","art.abysstail.session-timer"}});token_.clear();});
    connect(&socket_,&QTcpSocket::readyRead,this,&Timer::receive);
    connect(&socket_,&QTcpSocket::disconnected,this,[this]{if(!stopping_)disconnectHost("TrainerOS disconnected. Timer paused.");});
    connect(&socket_,&QTcpSocket::errorOccurred,this,[this](auto){if(!stopping_)disconnectHost("TrainerOS is unavailable. Open it, then connect.");});
    deadline_.setSingleShot(true);deadline_.setInterval(4000);
    connect(&deadline_,&QTimer::timeout,this,[this]{disconnectHost("TrainerOS did not respond. Timer paused.");});
    tick_.setInterval(250);connect(&tick_,&QTimer::timeout,this,&Timer::step);clock_.start();tick_.start();
}
Timer::~Timer(){shutdown();}
QString Timer::time() const {
    const auto seconds=model_.elapsed/1000;
    return QString("%1:%2:%3").arg(seconds/3600,2,10,QChar('0')).arg(seconds/60%60,2,10,QChar('0')).arg(seconds%60,2,10,QChar('0'));
}
QString Timer::state() const {
    if(!ready_)return "Paused";
    if(model_.due())return "Time for a break";
    if(model_.running)return model_.followGame?"Tracking your game":"Timer running";
    if(model_.followGame&&!model_.gameRunning)return "Waiting for a running game";
    return model_.elapsed?"Paused":"Ready when you are";
}
QString Timer::action() const {return model_.due()?"Got it — remind me later":model_.running?"Pause timer":"Start timer";}
QString Timer::reminder() const {return model_.reminderMinutes?QString("Every %1 min").arg(model_.reminderMinutes):"Off";}
void Timer::connectHost(){
    if(ready_)return;
    disconnectHost("Connecting to TrainerOS…");
    QFile file(endpoint_);
    if(!file.open(QIODevice::ReadOnly)||file.size()>65536){connection_="Open TrainerOS and choose a Trainer, then connect.";emit changed();return;}
    const auto info=QJsonDocument::fromJson(file.readAll()).object();
    const int port=info["port"].toInt();
    if(info["protocol"]!=1||info["host"]!="127.0.0.1"||port<1||port>65535||info["token"].toString().isEmpty()){
        connection_="TrainerOS discovery is unavailable.";emit changed();return;
    }
    token_=info["token"].toString();stopping_=false;deadline_.start();socket_.connectToHost(QHostAddress::LocalHost,quint16(port));
}
void Timer::call(const QString& method,const QJsonObject& args){
    const auto id=QString::number(++sequence_);pending_[id]=method;
    if(!deadline_.isActive())deadline_.start();
    socket_.write(QJsonDocument(QJsonObject{{"id",id},{"method",method},{"params",args}}).toJson(QJsonDocument::Compact)+'\n');
}
void Timer::receive(){
    input_+=socket_.readAll();
    if(input_.size()>262144){disconnectHost("TrainerOS sent too much data. Timer paused.");return;}
    while(input_.contains('\n')){
        const auto end=input_.indexOf('\n');
        if(end>=65536){disconnectHost("Invalid TrainerOS response.");return;}
        const auto line=input_.left(end);input_.remove(0,end+1);QJsonParseError error;
        const auto doc=QJsonDocument::fromJson(line,&error);
        if(error.error!=QJsonParseError::NoError||!doc.isObject()){disconnectHost("Invalid TrainerOS response.");return;}
        packet(doc.object());
        if(socket_.state()!=QAbstractSocket::ConnectedState)return;
    }
}
void Timer::packet(const QJsonObject& value){
    const auto event=value["event"].toString();
    if(!event.isEmpty()){
        if(event=="context.revoked"||event=="host.stopping") {disconnectHost("Trainer changed or TrainerOS closed. Connect to continue.");return;}
        if(event=="context.changed"||event=="widget.activated")applyContext(value["context"].toObject());
        if(event=="widget.activated"&&value["id"]=="timer"&&ready_)activate();
        if(event=="lifecycle"&&value["name"]=="wake"){clock_.restart();model_.running=false;model_.pausedByUser=true;persist();refresh();}
        return;
    }
    const auto id=value["id"].toString();
    if(!pending_.contains(id)){disconnectHost("Unexpected TrainerOS response.");return;}
    const auto method=pending_.take(id);if(pending_.isEmpty())deadline_.stop();
    if(method=="widget.put")widgetPending_=false;
    if(value.contains("error")){
        const auto code=value["error"].toObject()["code"].toString();
        if(code=="stale_context"&&method=="widget.put"){lastWidget_.clear();call("context.get");return;}
        disconnectHost(code=="app_in_use"?"Session Timer is already open.":"TrainerOS could not connect this timer ("+code+").");return;
    }
    const auto result=value["result"].toObject();
    if(method=="hello"){
        const auto caps=result["capabilities"].toObject();
        if(result["protocol"]!=1||caps["context"]!=1||caps["ui.start.widget"]!=1){disconnectHost("This TrainerOS build needs widget support.");return;}
        call("context.subscribe");return;
    }
    if(method=="context.subscribe"||method=="context.get")applyContext(result["context"].toObject());
    if(method=="widget.put")refresh();
}
void Timer::applyContext(const QJsonObject& context){
    const auto owner=context["profile"].toString();
    if(owner.isEmpty()){disconnectHost("Choose a Trainer in TrainerOS, then connect.");return;}
    if(!owner_.isEmpty()&&owner!=owner_){disconnectHost("Trainer changed. Connect to continue.");return;}
    if(owner_.isEmpty()){
        owner_=owner;model_=TimerModel{};
        const auto hash=QString::fromLatin1(QCryptographicHash::hash(owner.toUtf8(),QCryptographicHash::Sha256).toHex());
        const auto dir=storage_+"/profiles/"+hash;
        if(!QDir().mkpath(dir)){disconnectHost("Cannot create timer storage.");return;}
        stateFile_=dir+"/timer.json";lock_=std::make_unique<QLockFile>(dir+"/timer.lock");
        if(!lock_->tryLock()){disconnectHost("This Trainer's timer is already open.");return;}
        QFile saved(stateFile_);
        if(saved.exists()&&(!saved.open(QIODevice::ReadOnly)||saved.size()>8192||!model_.load(QJsonDocument::fromJson(saved.readAll()).object()))){
            disconnectHost("Saved timer could not be read; it has been preserved.");return;
        }
        writable_=true;ready_=true;connection_="Available in Start → Edit → Add";clock_.restart();lastSaved_=model_.elapsed;
    }else step();
    context_=context;revision_=context["revision"].toString();
    model_.game(context["game"].toObject());persist();refresh();
}
bool Timer::persist(){
    if(!writable_)return true;
    QSaveFile file(stateFile_);
    const auto bytes=QJsonDocument(model_.save()).toJson(QJsonDocument::Compact);
    if(!file.open(QIODevice::WriteOnly)||file.write(bytes)!=bytes.size()||!file.commit()){
        model_.running=false;model_.pausedByUser=true;connection_="Cannot save timer progress. Check available storage.";emit changed();return false;
    }
    lastSaved_=model_.elapsed;return true;
}
void Timer::disconnectHost(const QString& message){
    stopping_=true;deadline_.stop();
    model_.running=false;model_.pausedByUser=true;persist();
    ready_=false;writable_=false;socket_.abort();token_.clear();input_.clear();pending_.clear();
    owner_.clear();stateFile_.clear();lock_.reset();context_={};revision_.clear();widgetPending_=false;lastWidget_.clear();
    connection_=message;clock_.restart();emit changed();
}
void Timer::shutdown(){tick_.stop();if(ready_)step();disconnectHost("Timer closed.");}
void Timer::step(){
    const auto elapsed=clock_.restart();
    // A suspended/stalled app cannot prove that these seconds were played.
    if(ready_&&elapsed<=2000)model_.advance(elapsed);
    else if(elapsed>2000){model_.running=false;model_.pausedByUser=true;}
    if(ready_&&model_.elapsed-lastSaved_>=5000)persist();
    refresh();
}
void Timer::refresh(){
    emit changed();
    if(!ready_||widgetPending_)return;
    const auto text=time()+"\n"+state()+"\n"+action();
    if(text==lastWidget_&&revision_==widgetRevision_)return;
    lastWidget_=text;widgetRevision_=revision_;widgetPending_=true;
    call("widget.put",{{"id","timer"},{"title","Session Timer"},{"text",text},{"revision",revision_}});
}
void Timer::activate(){if(!ready_)return;step();model_.activate();persist();refresh();}
void Timer::reset(){if(!ready_)return;step();model_.reset();persist();refresh();}
void Timer::cycleReminder(){if(!ready_)return;model_.reminderMinutes=(model_.reminderMinutes+15)%75;model_.nextReminder();persist();refresh();}
void Timer::toggleMode(){if(!ready_)return;step();model_.followGame=!model_.followGame;model_.running=false;model_.pausedByUser=false;model_.session.clear();model_.game(context_["game"].toObject());persist();refresh();}
