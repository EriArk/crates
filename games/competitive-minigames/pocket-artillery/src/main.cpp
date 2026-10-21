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
#define SDL_MAIN_HANDLED
#include <SDL.h>

int main(int argc,char** argv){
    QGuiApplication app(argc,argv);
    app.setApplicationName("Pocket Artillery");app.setOrganizationName("AbyssTail");app.setApplicationVersion("0.1.0");
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


    SDL_SetMainReady();SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER);SDL_GameController* pad=nullptr;
    auto reopen=[&]{if(pad)SDL_GameControllerClose(pad);pad=nullptr;for(int i=0;i<SDL_NumJoysticks();++i)if(SDL_IsGameController(i)){pad=SDL_GameControllerOpen(i);break;}};
    reopen();QTimer input;
    QObject::connect(&input,&QTimer::timeout,[&]{SDL_Event e;while(SDL_PollEvent(&e)){
        if(e.type==SDL_QUIT){app.quit();continue;}
        if(e.type==SDL_CONTROLLERDEVICEADDED||e.type==SDL_CONTROLLERDEVICEREMOVED){reopen();continue;}
        if(!window->isActive()||(e.type!=SDL_CONTROLLERBUTTONDOWN&&e.type!=SDL_CONTROLLERBUTTONUP))continue;
        int key=0;switch(e.cbutton.button){
            case SDL_CONTROLLER_BUTTON_DPAD_UP:key=Qt::Key_Up;break;
            case SDL_CONTROLLER_BUTTON_DPAD_DOWN:key=Qt::Key_Down;break;
            case SDL_CONTROLLER_BUTTON_DPAD_LEFT:key=Qt::Key_Left;break;
            case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:key=Qt::Key_Right;break;
            case SDL_CONTROLLER_BUTTON_A:key=Qt::Key_Return;break;
            case SDL_CONTROLLER_BUTTON_B:key=Qt::Key_Escape;break;
        }
        if(key){QKeyEvent event(e.type==SDL_CONTROLLERBUTTONDOWN?QEvent::KeyPress:QEvent::KeyRelease,key,Qt::NoModifier);QCoreApplication::sendEvent(window,&event);}
    }});input.start(16);
    if(parser.isSet("screenshot"))QTimer::singleShot(1800,window,[&]{const auto frame=window->grabWindow();app.exit(!frame.isNull()&&frame.save(parser.value("screenshot"))?0:2);});
    const auto result=app.exec();if(pad)SDL_GameControllerClose(pad);SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);return result;
}
