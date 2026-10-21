// SPDX-License-Identifier: GPL-3.0-or-later
#include "Rules.h"
#include "../pong/src/PongRules.h"
#include "../snake-arena/src/SnakeRules.h"
#include "../light-cycles/src/CyclesRules.h"
namespace arcade {
Identity identity(Kind kind) {
    switch(kind){
    case Kind::Pong:return {"pong","Pong","A small court. A good rivalry.","Move up / down. First to 5 points wins.\nAfter 3 minutes, the higher score wins.",kind};
    case Kind::Snake:return {"snake-arena","Snake Arena","A snack. A turn. A narrow escape.","Turn in four directions. Eat fruit to grow.\nAvoid walls and snakes. After 2 minutes, longest wins.",kind};
    case Kind::Cycles:return {"light-cycles","Light Cycles","Make a turn. Leave a wall.","Turn in four directions. Your trail stays behind.\nAvoid every wall and outlast your rival.",kind};
    }return {};
}
std::unique_ptr<Rules> makeRules(Kind kind) {
    if(kind==Kind::Pong)return std::make_unique<PongRules>();
    if(kind==Kind::Snake)return std::make_unique<SnakeRules>();
    return std::make_unique<CyclesRules>();
}
}
