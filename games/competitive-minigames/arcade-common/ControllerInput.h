// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QGuiApplication>
#include <QQuickWindow>
#include <QTimer>
#include <QVariant>
#include <array>
#include <algorithm>
#include <cmath>
#define SDL_MAIN_HANDLED
#include <SDL.h>

// Qt owns the window. SDL must collect input without an SDL video window;
// foreground admission, neutralisation and held-button edges belong here.
class ControllerInput final : public QObject {
public:
    explicit ControllerInput(QQuickWindow* window):QObject(window),window_(window){
        SDL_SetMainReady();
        SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS,"1");
        available_=SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER)==0;
        if(!available_)qWarning("SDL controller initialization failed: %s",SDL_GetError());
        for(int i=0;i<SDL_NumJoysticks();++i)add(i);
        window_->installEventFilter(this);
        connect(window_,&QWindow::activeChanged,this,[this]{if(!window_->isActive())release();else poll();});
        connect(&timer_,&QTimer::timeout,this,[this]{poll();});timer_.start(8);
    }
    ~ControllerInput() override {
        timer_.stop();for(auto& p:pads_)if(p.pad)SDL_GameControllerClose(p.pad);
        if(available_)SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
    }
    void poll(){
        if(!available_)return;
        SDL_Event event;while(SDL_PollEvent(&event)){
            if(event.type==SDL_QUIT)QGuiApplication::quit();
            else if(event.type==SDL_CONTROLLERDEVICEADDED)add(event.cdevice.which);
            else if(event.type==SDL_CONTROLLERDEVICEREMOVED){
                for(int i=0;i<2;++i)if(pads_[i].id==event.cdevice.which){
                    invoke("padDirection",i,-1);invoke("padLost",i,0);
                    SDL_GameControllerClose(pads_[i].pad);pads_[i]=Pad{};
                }
                updateCount();
                for(int i=0;i<SDL_NumJoysticks();++i)add(i);
            }
        }
        for(int i=0;i<2;++i){
            auto& p=pads_[i];if(!p.pad)continue;
            const int x=SDL_GameControllerGetAxis(p.pad,SDL_CONTROLLER_AXIS_LEFTX);
            const int y=SDL_GameControllerGetAxis(p.pad,SDL_CONTROLLER_AXIS_LEFTY);
            int d=-1;
            // Hysteresis avoids drift/chatter near the dead zone. D-pad wins.
            const int threshold=p.direction<0?16000:10000;
            if(std::max(std::abs(x),std::abs(y))>threshold)d=std::abs(x)>std::abs(y)?(x>0?1:3):(y>0?2:0);
            const SDL_GameControllerButton directions[]{SDL_CONTROLLER_BUTTON_DPAD_UP,SDL_CONTROLLER_BUTTON_DPAD_RIGHT,SDL_CONTROLLER_BUTTON_DPAD_DOWN,SDL_CONTROLLER_BUTTON_DPAD_LEFT};
            for(int n=0;n<4;++n)if(SDL_GameControllerGetButton(p.pad,directions[n]))d=n;
            std::array<bool,4> buttons{};
            const SDL_GameControllerButton actions[]{SDL_CONTROLLER_BUTTON_A,SDL_CONTROLLER_BUTTON_X,SDL_CONTROLLER_BUTTON_B,SDL_CONTROLLER_BUTTON_START};
            bool any=false;for(int n=0;n<4;++n){buttons[n]=SDL_GameControllerGetButton(p.pad,actions[n]);any|=buttons[n];}
            if(!window_->isActive()){p.blocked=true;continue;}
            if(p.blocked){if(d<0&&!any)p.blocked=false;else continue;}
            if(d!=p.direction){
                if(d>=0)usePad(p.pad);
                p.direction=d;p.repeat=0;invoke("padDirection",i,d);
            }else if(d>=0&&++p.repeat>=42&&(p.repeat-42)%16==0)invoke("padRepeat",i,d);
            for(int n=0;n<4;++n)if(buttons[n]&&!p.buttons[n]){usePad(p.pad);invoke("padButton",i,n);}
            if(buttons[0]){if(++p.actionRepeat%16==0)invoke("padActionRepeat",i,0);}else p.actionRepeat=0;
            p.buttons=buttons;
        }
    }
protected:
    bool eventFilter(QObject*,QEvent* event) override {
        if(event->type()==QEvent::KeyPress)window_->setProperty("touchControls",false);
        if(event->type()==QEvent::TouchBegin)window_->setProperty("touchControls",true);
        return false;
    }
private:
    struct Pad {SDL_GameController* pad=nullptr;SDL_JoystickID id=-1;int direction=-1,repeat=0,actionRepeat=0;bool blocked=false;std::array<bool,4> buttons{};};
    QQuickWindow* window_;QTimer timer_;std::array<Pad,2> pads_{};bool available_=false;
    void invoke(const char* method,int player,int value){QMetaObject::invokeMethod(window_,method,Q_ARG(QVariant,player),Q_ARG(QVariant,value));}
    void updateCount(){int n=0;for(auto& p:pads_)if(p.pad)++n;window_->setProperty("padCount",n);if(!n)window_->setProperty("touchControls",true);}
    void add(int index){
        if(!SDL_IsGameController(index))return;
        const auto id=SDL_JoystickGetDeviceInstanceID(index);
        for(auto& p:pads_)if(p.id==id)return;
        for(auto& p:pads_)if(!p.pad){p.pad=SDL_GameControllerOpen(index);if(p.pad){p.id=id;usePad(p.pad);updateCount();}return;}
    }
    void release(){for(int i=0;i<2;++i){auto& p=pads_[i];p.direction=-1;p.buttons={};p.blocked=true;invoke("padDirection",i,-1);}invoke("padLost",0,0);}
    void usePad(SDL_GameController* pad){
        QString primary="A",secondary="X",back="B";
        switch(SDL_GameControllerGetType(pad)){
        case SDL_CONTROLLER_TYPE_PS3:case SDL_CONTROLLER_TYPE_PS4:case SDL_CONTROLLER_TYPE_PS5:primary=QString::fromUtf8("×");secondary=QString::fromUtf8("□");back=QString::fromUtf8("○");break;
        case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_PRO:
#if SDL_VERSION_ATLEAST(2,24,0)
        case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_LEFT:case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT:case SDL_CONTROLLER_TYPE_NINTENDO_SWITCH_JOYCON_PAIR:
#endif
            // SDL defaults to label-based Nintendo mappings. Respect a user's
            // positional mapping override instead of displaying swapped labels.
            if(!SDL_GetHintBoolean(SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS,SDL_TRUE)){primary="B";secondary="Y";back="A";}
            break;
        default:break;
        }
        window_->setProperty("primaryGlyph",primary);window_->setProperty("secondaryGlyph",secondary);window_->setProperty("backGlyph",back);
        window_->setProperty("touchControls",false);
    }
};
