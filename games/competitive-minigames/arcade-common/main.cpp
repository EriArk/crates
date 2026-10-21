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
#define SDL_MAIN_HANDLED
#include <SDL.h>

int main(int argc,char** argv){
    QGuiApplication app(argc,argv);
    const auto kind=arcade::Kind(ARCADE_KIND);
    app.setApplicationName(arcade::identity(kind).title);app.setOrganizationName("AbyssTail");app.setApplicationVersion("0.1.0");
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
    SDL_SetMainReady();SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER);
    std::array<SDL_GameController*,2> pads{};
    std::array<SDL_JoystickID,2> ids{-1,-1};
    auto add=[&](int index){
        if(!SDL_IsGameController(index))return;
        const auto id=SDL_JoystickGetDeviceInstanceID(index);
        if(ids[0]==id||ids[1]==id)return;
        for(int i=0;i<2;++i)if(!pads[i]){pads[i]=SDL_GameControllerOpen(index);if(pads[i])ids[i]=id;break;}
    };
    for(int i=0;i<SDL_NumJoysticks();++i)add(i);
    auto key=[&](int value,bool pressed){QKeyEvent event(pressed?QEvent::KeyPress:QEvent::KeyRelease,value,Qt::NoModifier);QCoreApplication::sendEvent(window,&event);};
    QTimer poll;
    QObject::connect(&poll,&QTimer::timeout,[&]{SDL_Event event;while(SDL_PollEvent(&event)){
        if(event.type==SDL_QUIT){app.quit();continue;}
        if(event.type==SDL_CONTROLLERDEVICEADDED){add(event.cdevice.which);continue;}
        if(event.type==SDL_CONTROLLERDEVICEREMOVED){for(int i=0;i<2;++i)if(ids[i]==event.cdevice.which){game.control(i,-1);game.pause(true);SDL_GameControllerClose(pads[i]);pads[i]=nullptr;ids[i]=-1;}continue;}
        if(!window->isActive())continue;
        if(event.type!=SDL_CONTROLLERBUTTONDOWN&&event.type!=SDL_CONTROLLERBUTTONUP)continue;
        const int player=event.cbutton.which==ids[0]?0:event.cbutton.which==ids[1]?1:-1;
        if(player<0)continue;
        const bool pressed=event.type==SDL_CONTROLLERBUTTONDOWN;
        int direction=-2;
        switch(event.cbutton.button){
        case SDL_CONTROLLER_BUTTON_DPAD_UP:direction=0;break;
        case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:direction=1;break;
        case SDL_CONTROLLER_BUTTON_DPAD_DOWN:direction=2;break;
        case SDL_CONTROLLER_BUTTON_DPAD_LEFT:direction=3;break;
        case SDL_CONTROLLER_BUTTON_A:if(player==0||game.couch())key(game.phase()=="play"&&game.couch()&&player==0?Qt::Key_F:Qt::Key_Return,pressed);break;
        case SDL_CONTROLLER_BUTTON_X:if(game.phase()=="play"&&(player==0||game.couch()))key(game.couch()&&player==0?Qt::Key_G:Qt::Key_Shift,pressed);break;
        case SDL_CONTROLLER_BUTTON_B:key(Qt::Key_Escape,pressed);break;
        case SDL_CONTROLLER_BUTTON_START:key(Qt::Key_Escape,pressed);break;
        }
        if(direction>=0){
            if(game.phase()=="play"){
                const std::array<int,4> arrows{Qt::Key_Up,Qt::Key_Right,Qt::Key_Down,Qt::Key_Left};
                const std::array<int,4> wasd{Qt::Key_W,Qt::Key_D,Qt::Key_S,Qt::Key_A};
                if(player==0)key(game.couch()?wasd[direction]:arrows[direction],pressed);
                else if(game.couch())key(arrows[direction],pressed);
            }
            else if(player==0&&pressed)key(direction==0||direction==3?Qt::Key_Up:Qt::Key_Down,true);
        }
    }});poll.start(8);
    if(parser.isSet("screenshot"))QTimer::singleShot(1200,window,[&]{app.exit(window->grabWindow().save(parser.value("screenshot"))?0:2);});
    const int result=app.exec();
    for(auto* pad:pads)if(pad)SDL_GameControllerClose(pad);
    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);return result;
}
