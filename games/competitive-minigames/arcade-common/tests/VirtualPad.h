// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "../ControllerInput.h"
#include <QtTest>
// Uses SDL's actual joystick backend and controller mapping, not Qt key injection.
struct VirtualPad {
    int device=-1;SDL_Joystick* joystick=nullptr;
    VirtualPad(){device=SDL_JoystickAttachVirtual(SDL_JOYSTICK_TYPE_GAMECONTROLLER,6,SDL_CONTROLLER_BUTTON_MAX,0);if(device>=0)joystick=SDL_JoystickOpen(device);}
    ~VirtualPad(){if(joystick){const auto id=SDL_JoystickInstanceID(joystick);SDL_JoystickClose(joystick);for(int i=0;i<SDL_NumJoysticks();++i)if(SDL_JoystickGetDeviceInstanceID(i)==id){SDL_JoystickDetachVirtual(i);break;}}}
    void axis(int x,int y){SDL_JoystickSetVirtualAxis(joystick,0,Sint16(x));SDL_JoystickSetVirtualAxis(joystick,1,Sint16(y));QTest::qWait(35);}
    void button(int b,bool down){SDL_JoystickSetVirtualButton(joystick,b,down);QTest::qWait(35);}
    void tap(int b){button(b,true);button(b,false);}
};
