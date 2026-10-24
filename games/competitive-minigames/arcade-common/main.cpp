// SPDX-License-Identifier: GPL-3.0-or-later
#include "ArcadeGame.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QKeyEvent>
#include <QFont>
#include <QImage>
#include <array>
#include "ControllerInput.h"

int main(int argc,char** argv){
    QGuiApplication app(argc,argv);
    const auto kind=arcade::Kind(ARCADE_KIND);
    app.setApplicationName(arcade::identity(kind).title);app.setOrganizationName("AbyssTail");app.setApplicationVersion("0.1.2");
#ifdef Q_OS_WIN
    app.setFont(QFont("Segoe UI"));
#else
    app.setFont(QFont("DejaVu Sans"));
#endif
    QCommandLineParser parser;parser.addHelpOption();parser.addVersionOption();
    parser.addOption({"endpoint","TrainerOS discovery file","path"});
    parser.addOption({"windowed","Run in a desktop window"});
    parser.addOption({"screenshot","Capture the menu and exit","path"});parser.process(app);
    ArcadeGame game(kind,parser.value("endpoint"));
    QQmlApplicationEngine engine;engine.rootContext()->setContextProperty("game",&game);
    engine.load(QUrl("qrc:/ui/Main.qml"));if(engine.rootObjects().isEmpty())return 1;
    auto* window=qobject_cast<QQuickWindow*>(engine.rootObjects().first());if(!window)return 1;
    if(!parser.isSet("windowed"))window->showFullScreen();
    QObject::connect(window,&QWindow::activeChanged,&game,[&]{if(!window->isActive())game.pause(true);});
    // Open IPC only after the first frame; registration never opens Lobby.
    QObject::connect(window,&QQuickWindow::frameSwapped,&game,[&game]{game.attach();},
                     Qt::ConnectionType(Qt::QueuedConnection|Qt::SingleShotConnection));
    ControllerInput controllers(window);
    if(parser.isSet("screenshot"))QTimer::singleShot(1200,window,[&]{app.exit(window->grabWindow().save(parser.value("screenshot"))?0:2);});
    return app.exec();
}
