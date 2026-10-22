// SPDX-License-Identifier: GPL-3.0-or-later
#include "Game.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QKeyEvent>
#include <QImage>
#include <QFont>
#include "../../arcade-common/ControllerInput.h"

int main(int argc,char** argv){
    QGuiApplication app(argc,argv);
    app.setApplicationName("Pocket Artillery");app.setOrganizationName("AbyssTail");app.setApplicationVersion("0.1.2");
#ifdef Q_OS_WIN
    app.setFont(QFont("Segoe UI"));
#else
    app.setFont(QFont("DejaVu Sans"));
#endif
    QCommandLineParser parser;parser.addHelpOption();parser.addVersionOption();
    parser.addOption({"endpoint","TrainerOS SDK discovery file","path"});

    parser.addOption({"windowed","Run in a desktop window"});
    parser.addOption({"screenshot","Save a development screenshot, then exit","path"});
    parser.process(app);
    Game game(parser.value("endpoint"));
    QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);
    engine.load(QUrl("qrc:/ui/Main.qml"));if(engine.rootObjects().isEmpty())return 1;
    auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    if(!window)return 1;
    if(!parser.isSet("windowed"))window->showFullScreen();


    ControllerInput controllers(window);
    if(parser.isSet("screenshot"))QTimer::singleShot(1800,window,[&]{const auto frame=window->grabWindow();app.exit(!frame.isNull()&&frame.save(parser.value("screenshot"))?0:2);});
    return app.exec();
}
